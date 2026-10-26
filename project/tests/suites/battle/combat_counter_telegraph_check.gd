extends Node
## Y1-A T-P26: aimed foe that can_counter gets retaliate telegraph. Real battle E2E.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

var _battle: Control
var _player_i := -1
var _foe_near := -1
var _foe_far := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL counter telegraph: ", err)
		get_tree().quit(1)
		return
	print("COMBAT COUNTER TELEGRAPH PASS")
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
	var tele := FileAccess.get_file_as_string("res://scripts/battle/battle_counter_telegraph.gd")
	if ctrl.find("BattleCounterTelegraph.draw(self, overlay)") < 0:
		return "controller overlay missing counter telegraph draw"
	if ctrl.find("BattleCounterTelegraph.refresh(self)") < 0:
		return "controller missing refresh on aim"
	if touch.find("BattleCounterTelegraph.clear(host)") < 0:
		return "touch clear missing counter telegraph clear"
	if touch.find("BattleCounterTelegraph.refresh(host)") < 0:
		return "touch missing refresh on aim"
	if tele.find("BattleRules.can_counter") < 0:
		return "telegraph must use BattleRules.can_counter"
	if tele.find("BattleCombatFrame.follow_cells") < 0:
		return "telegraph must frame both figures"
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
	_foe_near = -1
	_foe_far = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player" and _player_i < 0:
			_player_i = i
		elif str(u.team) == "enemy":
			if _foe_near < 0:
				_foe_near = i
			elif _foe_far < 0:
				_foe_far = i
	if _player_i < 0 or _foe_near < 0:
		return "deploy missing player/enemy"
	var th: int = _battle.terrain.size()
	var tw: int = _battle.terrain[0].size() if th > 0 else 8
	var stand := Vector2i(mini(3, tw - 1), mini(2, th - 1))
	var near := Vector2i(mini(stand.x + 1, tw - 1), stand.y)
	var far := Vector2i(mini(stand.x + 3, tw - 1), stand.y)
	if near == stand:
		near = Vector2i(stand.x, mini(stand.y + 1, th - 1))
	if far == stand or far == near:
		far = Vector2i(stand.x, mini(stand.y + 3, th - 1))
	_battle.units[_player_i].pos = stand
	_battle.units[_player_i].done = false
	_battle.units[_player_i].char.job_id = "light_inf"
	_battle.units[_player_i].char.recalc_hp()
	_battle.units[_player_i].char.hp = _battle.units[_player_i].char.max_hp
	# Near foe: melee so dist=1 can counter.
	_battle.units[_foe_near].pos = near
	_battle.units[_foe_near].char.job_id = "light_inf"
	_battle.units[_foe_near].char.recalc_hp()
	_battle.units[_foe_near].char.hp = maxi(int(_battle.units[_foe_near].char.hp), 10)
	if _foe_far >= 0:
		_battle.units[_foe_far].pos = far
		_battle.units[_foe_far].char.job_id = "light_inf"
		_battle.units[_foe_far].char.recalc_hp()
		_battle.units[_foe_far].char.hp = maxi(int(_battle.units[_foe_far].char.hp), 10)
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
	await _settle(4)
	# Aim near melee foe → counter expected.
	_battle.preview_attack_ui = _foe_near
	var hit := BattleCounterTelegraph.refresh(_battle)
	await _settle(4)
	if not hit:
		return "near melee foe should telegraph counter"
	if not BattleCounterTelegraph.will_counter(_battle):
		return "will_counter false for adjacent melee"
	if not _battle.has_meta(BattleCounterTelegraph.META):
		return "meta missing after counter refresh"
	if int(_battle.get_meta(BattleCounterTelegraph.META).get("foe", -2)) != _foe_near:
		return "meta foe wrong"
	# Far foe at dist>=3: melee cannot counter.
	if _foe_far >= 0:
		_battle.preview_attack_ui = _foe_far
		var far_hit := BattleCounterTelegraph.refresh(_battle)
		await _settle(2)
		if far_hit or BattleCounterTelegraph.will_counter(_battle):
			return "far melee foe should NOT counter"
		if _battle.has_meta(BattleCounterTelegraph.META):
			return "meta should clear when no counter"
	BattleTouchConfirm.clear(_battle, false)
	if _battle.has_meta(BattleCounterTelegraph.META):
		return "clear left counter meta"
	_battle.attack_mode = false
	_battle.preview_attack_ui = _foe_near
	if BattleCounterTelegraph.active(_battle):
		return "attack_mode=false should suppress telegraph"
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
