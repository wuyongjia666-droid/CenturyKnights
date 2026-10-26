extends Node
## Y1-A T-P27: aimed strike with AGI follow-up telegraphs 追击. Real battle E2E.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

var _battle: Control
var _player_i := -1
var _foe_slow := -1
var _foe_fast := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL followup telegraph: ", err)
		get_tree().quit(1)
		return
	print("COMBAT FOLLOWUP TELEGRAPH PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _source_contracts()
	if err != "":
		return err
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	err = await _boot(true)
	if err == "":
		err = await _e2e()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if err != "":
		return err
	err = await _boot(false)
	if err == "":
		err = await _e2e()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err


func _source_contracts() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var touch := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	var tele := FileAccess.get_file_as_string("res://scripts/battle/battle_followup_telegraph.gd")
	if ctrl.find("BattleFollowUpTelegraph.draw(self, overlay)") < 0:
		return "controller missing followup draw"
	if ctrl.find("BattleFollowUpTelegraph.refresh(self)") < 0:
		return "controller missing followup refresh"
	if touch.find("BattleFollowUpTelegraph.clear(host)") < 0:
		return "touch clear missing followup clear"
	if touch.find("BattleFollowUpTelegraph.refresh(host)") < 0:
		return "touch missing followup refresh"
	if tele.find("BattleRules.can_follow_up") < 0:
		return "must use BattleRules.can_follow_up"
	if tele.find("EmptyHost") >= 0 or ctrl.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	return ""


func _boot(mobile: bool) -> String:
	await _set_window(PHONE if mobile else DESK)
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.set_meta("battle_map", "obj_rout")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	if not _battle.has_method("_click_cell") or not ("units" in _battle):
		return "battle controller script failed to attach"
	if mobile:
		var insets := {"left": 80.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
		var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
		MobileLayout.apply_root(_battle, fitted)
		_battle.set_meta("mobile_insets", insets)
		if _battle.has_method("apply_mobile_layout"):
			_battle.apply_mobile_layout()
		await _settle(8)
	return _arrange()


func _arrange() -> String:
	_battle.turn_team = "player"
	_battle.battle_over = false
	_player_i = -1
	_foe_slow = -1
	_foe_fast = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player" and _player_i < 0:
			_player_i = i
		elif str(u.team) == "enemy":
			if _foe_slow < 0:
				_foe_slow = i
			elif _foe_fast < 0:
				_foe_fast = i
	if _player_i < 0 or _foe_slow < 0:
		return "deploy missing player/enemy"
	var th: int = _battle.terrain.size()
	var tw: int = _battle.terrain[0].size() if th > 0 else 8
	var stand := Vector2i(mini(3, tw - 1), mini(2, th - 1))
	var near := Vector2i(mini(stand.x + 1, tw - 1), stand.y)
	var near2 := Vector2i(stand.x, mini(stand.y + 1, th - 1))
	if near == stand:
		near = near2
		near2 = Vector2i(mini(stand.x + 1, tw - 1), stand.y)
	_battle.units[_player_i].pos = stand
	_battle.units[_player_i].done = false
	_battle.units[_player_i].char.job_id = "light_inf"
	_battle.units[_player_i].char.stats["agi"] = 14
	_battle.units[_player_i].char.recalc_hp()
	_battle.units[_player_i].char.hp = _battle.units[_player_i].char.max_hp
	_battle.units[_foe_slow].pos = near
	_battle.units[_foe_slow].char.job_id = "light_inf"
	_battle.units[_foe_slow].char.stats["agi"] = 6  # gap 8 ≥ FOLLOW_UP_AGI 4
	_battle.units[_foe_slow].char.recalc_hp()
	_battle.units[_foe_slow].char.hp = maxi(10, int(_battle.units[_foe_slow].char.hp))
	if _foe_fast >= 0:
		_battle.units[_foe_fast].pos = near2
		_battle.units[_foe_fast].char.job_id = "light_inf"
		_battle.units[_foe_fast].char.stats["agi"] = 14  # gap 0 → no follow-up
		_battle.units[_foe_fast].char.recalc_hp()
		_battle.units[_foe_fast].char.hp = maxi(10, int(_battle.units[_foe_fast].char.hp))
	_battle.selected = _player_i
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle.attack_mode = false
	_battle.moved_this_select = false
	_battle.move_cells = {}
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _e2e() -> String:
	_battle._select_player(_player_i)
	await _settle(3)
	_battle._enter_attack_mode()
	await _settle(3)
	_battle.preview_attack_ui = _foe_slow
	var hit := BattleFollowUpTelegraph.refresh(_battle)
	await _settle(3)
	if not hit or not BattleFollowUpTelegraph.will_follow_up(_battle):
		return "slow foe should telegraph follow-up"
	if not _battle.has_meta(BattleFollowUpTelegraph.META):
		return "meta missing"
	if _foe_fast >= 0:
		_battle.preview_attack_ui = _foe_fast
		var no := BattleFollowUpTelegraph.refresh(_battle)
		await _settle(2)
		if no or BattleFollowUpTelegraph.will_follow_up(_battle):
			return "equal-AGI foe should NOT follow-up"
		if _battle.has_meta(BattleFollowUpTelegraph.META):
			return "meta should clear without follow-up"
	BattleTouchConfirm.clear(_battle, false)
	if _battle.has_meta(BattleFollowUpTelegraph.META):
		return "clear left followup meta"
	_battle.attack_mode = false
	_battle.preview_attack_ui = _foe_slow
	if BattleFollowUpTelegraph.active(_battle):
		return "attack_mode=false should suppress"
	return ""


func _set_window(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
		await _settle(2)
