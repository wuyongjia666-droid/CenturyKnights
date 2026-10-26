extends Node
## Y1-A T-P28: cancel stack preview → mode → select. Real battle E2E.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

var _battle: Control
var _player_i := -1
var _foe_i := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL cancel depth: ", err)
		get_tree().quit(1)
		return
	print("COMBAT ATTACK CANCEL DEPTH PASS")
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
	var bar := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_mobile_bar.gd")
	var depth := FileAccess.get_file_as_string("res://scripts/battle/battle_attack_cancel_depth.gd")
	if ctrl.find("BattleAttackCancelDepth.step(self)") < 0:
		return "controller missing cancel depth step"
	if ctrl.find("KEY_ESCAPE") < 0:
		return "controller missing KEY_ESCAPE"
	if bar.find("BattleAttackCancelDepth.step(host)") < 0:
		return "mobile bar cancel not depth-aware"
	if depth.find("preview") < 0 or depth.find("_exit_modes") < 0:
		return "depth missing layered steps"
	if depth.find("EmptyHost") >= 0 or ctrl.find("EmptyHost") >= 0:
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
	_battle.units[_player_i].char.recalc_hp()
	_battle.units[_player_i].char.hp = _battle.units[_player_i].char.max_hp
	_battle.units[_foe_i].pos = near
	_battle.units[_foe_i].char.hp = maxi(10, int(_battle.units[_foe_i].char.hp))
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
	await _settle(2)
	var err := _assert_preview_step()
	if err == "":
		err = _assert_mode_step()
	if err == "":
		err = _assert_select_step()
	return err


func _assert_preview_step() -> String:
	var s1 := BattleAttackCancelDepth.step(_battle)
	if s1 != "preview":
		return "first cancel should drop preview got %s" % s1
	if int(_battle.preview_attack_ui) != -1:
		return "preview not cleared"
	if not bool(_battle.attack_mode):
		return "attack_mode should survive preview cancel"
	if int(_battle.selected) != _player_i:
		return "selection lost after preview cancel"
	return ""


func _assert_mode_step() -> String:
	var s2 := BattleAttackCancelDepth.step(_battle)
	if s2 != "mode":
		return "second cancel should exit mode got %s" % s2
	if bool(_battle.attack_mode):
		return "attack_mode should be off"
	if int(_battle.selected) != _player_i:
		return "selection lost after mode cancel"
	if _battle.move_cells.is_empty():
		return "move range should republish after mode exit"
	return ""


func _assert_select_step() -> String:
	var s3 := BattleAttackCancelDepth.step(_battle)
	if s3 != "select":
		return "third cancel should deselect got %s" % s3
	if int(_battle.selected) >= 0:
		return "selection should be cleared"
	var s4 := BattleAttackCancelDepth.step(_battle)
	if s4 != "noop":
		return "fourth cancel should noop got %s" % s4
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
