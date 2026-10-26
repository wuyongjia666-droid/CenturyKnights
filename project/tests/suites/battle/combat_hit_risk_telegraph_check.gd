extends Node
## Y1-A T-P30: aimed low-hit strike telegraphs risk. Real battle E2E.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

var _battle: Control
var _player_i := -1
var _foe_i := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL hit-risk telegraph: ", err)
		get_tree().quit(1)
		return
	print("COMBAT HIT RISK TELEGRAPH PASS")
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
	var tele := FileAccess.get_file_as_string("res://scripts/battle/battle_hit_risk_telegraph.gd")
	if ctrl.find("BattleHitRiskTelegraph.draw(self, overlay)") < 0:
		return "controller missing hit-risk draw"
	if ctrl.find("BattleHitRiskTelegraph.refresh(self)") < 0:
		return "controller missing hit-risk refresh"
	if touch.find("BattleHitRiskTelegraph.clear(host)") < 0:
		return "touch clear missing hit-risk clear"
	if touch.find("BattleHitRiskTelegraph.refresh(host)") < 0:
		return "touch missing hit-risk refresh"
	if tele.find("BattleRules.preview") < 0:
		return "must use BattleRules.preview for hit%"
	if tele.find("Locale.t(\"shell_hit_risk_mark\")") < 0:
		return "risk mark must be Locale.t"
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
	_foe_i = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player" and _player_i < 0:
			_player_i = i
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
	if _player_i < 0 or _foe_i < 0:
		return "deploy missing"
	var th: int = _battle.terrain.size()
	var tw: int = _battle.terrain[0].size() if th > 0 else 8
	var stand := Vector2i(mini(3, tw - 1), mini(2, th - 1))
	var near := Vector2i(mini(stand.x + 1, tw - 1), stand.y)
	if near == stand:
		near = Vector2i(stand.x, mini(stand.y + 1, th - 1))
	_battle.units[_player_i].pos = stand
	_battle.units[_player_i].done = false
	_battle.units[_player_i].char.job_id = "light_inf"
	_battle.units[_player_i].char.stats["skl"] = 0
	_battle.units[_player_i].char.stats["agi"] = 0
	_battle.units[_player_i].char.temp_hit_bonus = -20
	_battle.units[_foe_i].pos = near
	_battle.units[_foe_i].char.job_id = "light_inf"
	_battle.units[_foe_i].char.stats["agi"] = 40
	_battle.units[_foe_i].char.stats["per"] = 40
	_battle.units[_foe_i].char.hp = maxi(10, int(_battle.units[_foe_i].char.hp))
	if near.y < _battle.terrain.size() and near.x < _battle.terrain[near.y].size():
		_battle.terrain[near.y][near.x] = "fort"
	_battle.selected = -1
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
	if not bool(_battle.attack_mode):
		return "attack_mode not on"
	_battle.preview_attack_ui = _foe_i
	var hit := BattleHitRiskTelegraph.refresh(_battle)
	var chance := BattleHitRiskTelegraph.hit_chance(_battle)
	if chance > BattleHitRiskTelegraph.RISK_HIT:
		return "setup failed to force low hit got %d" % chance
	if not hit or not BattleHitRiskTelegraph.will_risk(_battle):
		return "expected risk telegraph hit=%d" % chance
	if not _battle.has_meta(BattleHitRiskTelegraph.META):
		return "risk meta missing"
	# Restore accuracy → clear.
	_battle.units[_player_i].char.stats["skl"] = 40
	_battle.units[_player_i].char.stats["agi"] = 40
	_battle.units[_player_i].char.temp_hit_bonus = 0
	_battle.units[_foe_i].char.stats["agi"] = 0
	_battle.units[_foe_i].char.stats["per"] = 0
	if _battle.units[_foe_i].pos.y < _battle.terrain.size():
		_battle.terrain[_battle.units[_foe_i].pos.y][_battle.units[_foe_i].pos.x] = "plain"
	var no := BattleHitRiskTelegraph.refresh(_battle)
	if no or BattleHitRiskTelegraph.will_risk(_battle):
		return "should clear when hit is safe got %d" % BattleHitRiskTelegraph.hit_chance(_battle)
	if _battle.has_meta(BattleHitRiskTelegraph.META):
		return "meta should clear when safe"
	# Re-risk and touch-clear.
	_battle.units[_player_i].char.stats["skl"] = 0
	_battle.units[_player_i].char.stats["agi"] = 0
	_battle.units[_player_i].char.temp_hit_bonus = -20
	_battle.units[_foe_i].char.stats["agi"] = 40
	_battle.units[_foe_i].char.stats["per"] = 40
	_battle.terrain[_battle.units[_foe_i].pos.y][_battle.units[_foe_i].pos.x] = "fort"
	_battle.preview_attack_ui = _foe_i
	BattleHitRiskTelegraph.refresh(_battle)
	if not _battle.has_meta(BattleHitRiskTelegraph.META):
		return "meta missing after restore"
	BattleTouchConfirm.clear(_battle)
	if _battle.has_meta(BattleHitRiskTelegraph.META):
		return "touch clear should drop risk meta"
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
