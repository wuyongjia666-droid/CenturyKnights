extends Node
## Y1-A T-P25: Tab in attack_mode cycles in-reach foes (preview + camera). Real battle E2E.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

var _battle: Control
var _player_i := -1
var _foe_a := -1
var _foe_b := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL attack cycle: ", err)
		get_tree().quit(1)
		return
	print("COMBAT ATTACK CYCLE PASS")
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
		err = await _e2e_cycle()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if err != "":
		return err
	err = await _boot(false)
	if err == "":
		err = await _e2e_cycle()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err


func _source_contracts() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var cycle := FileAccess.get_file_as_string("res://scripts/battle/battle_attack_cycle.gd")
	var touch := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if ctrl.find("BattleAttackCycle.apply_next(self)") < 0:
		return "controller missing BattleAttackCycle.apply_next"
	if ctrl.find("BattleAttackCycle.apply_prev(self)") < 0:
		return "controller missing BattleAttackCycle.apply_prev"
	if ctrl.find("KEY_TAB") < 0:
		return "controller missing KEY_TAB"
	# Attack mode Tab must prefer cycle over formation.
	var tab_i := ctrl.find("KEY_TAB:")
	if tab_i < 0:
		return "KEY_TAB block missing"
	var tab_chunk := ctrl.substr(tab_i, 420)
	if tab_chunk.find("if attack_mode") < 0:
		return "KEY_TAB must gate on attack_mode"
	if tab_chunk.find("BattleAttackCycle") < 0:
		return "KEY_TAB attack_mode path missing AttackCycle"
	if ctrl.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	if touch.find("BattleAttackCycle.clear(host)") < 0:
		return "touch clear does not drop attack cycle"
	if cycle.find("BattleRules.in_weapon_range") < 0:
		return "attack cycle must use BattleRules.in_weapon_range"
	if cycle.find("BattleCombatFrame.follow_cells") < 0:
		return "attack cycle must use BattleCombatFrame"
	if cycle.find("EmptyHost") >= 0:
		return "EmptyHost in attack cycle forbidden"
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
	_foe_a = -1
	_foe_b = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player" and _player_i < 0:
			_player_i = i
		elif str(u.team) == "enemy":
			if _foe_a < 0:
				_foe_a = i
			elif _foe_b < 0:
				_foe_b = i
	if _player_i < 0 or _foe_a < 0:
		return "deploy missing player/enemy"
	var th: int = _battle.terrain.size()
	var tw: int = _battle.terrain[0].size() if th > 0 else 8
	var stand := Vector2i(mini(3, tw - 1), mini(2, th - 1))
	var near := Vector2i(mini(stand.x + 1, tw - 1), stand.y)
	var near2 := Vector2i(stand.x, mini(stand.y + 1, th - 1))
	if near == stand:
		near = Vector2i(stand.x, mini(stand.y + 1, th - 1))
		near2 = Vector2i(mini(stand.x + 1, tw - 1), stand.y)
	_battle.units[_player_i].pos = stand
	_battle.units[_player_i].done = false
	_battle.units[_player_i].char.job_id = "light_inf"
	_battle.units[_player_i].char.recalc_hp()
	_battle.units[_player_i].char.hp = _battle.units[_player_i].char.max_hp
	_battle.units[_foe_a].pos = near
	_battle.units[_foe_a].char.hp = maxi(int(_battle.units[_foe_a].char.hp), 10)
	if _foe_b >= 0:
		_battle.units[_foe_b].pos = near2
		_battle.units[_foe_b].char.hp = maxi(int(_battle.units[_foe_b].char.hp), 10)
	_battle.selected = _player_i
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle.attack_mode = false
	_battle.moved_this_select = false
	_battle.move_cells = {}
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _e2e_cycle() -> String:
	_battle._select_player(_player_i)
	await _settle(3)
	_battle.units[_player_i].char.job_id = "light_inf"
	_battle.units[_player_i].char.recalc_hp()
	_battle.units[_player_i].char.hp = _battle.units[_player_i].char.max_hp
	_battle._enter_attack_mode()
	await _settle(4)
	# Enter frames via Aim only; first Tab seeds preview (keeps touch_confirm second-tap).
	BattleAttackCycle.apply_next(_battle)
	await _settle(4)
	var err := _assert_seeded()
	if err == "" and BattleAttackCycle.threatened_indices(_battle).size() >= 2:
		err = _assert_tab_cycle()
	if err == "":
		err = _assert_clear()
	return err


func _assert_seeded() -> String:
	if not BattleAttackCycle.active(_battle):
		return "attack cycle not active after _enter_attack_mode"
	var idxs: Array[int] = BattleAttackCycle.threatened_indices(_battle)
	if not idxs.has(_foe_a):
		return "foe_a not threatened: %s" % idxs
	if _foe_b >= 0 and not idxs.has(_foe_b):
		return "foe_b not threatened: %s" % idxs
	var first: int = idxs[0]
	if int(_battle.preview_attack_ui) != first:
		return "first Tab did not seed first foe want %s got %s" % [first, _battle.preview_attack_ui]
	if not _battle.has_meta(BattleAttackCycle.META):
		return "first Tab did not stamp cycle meta"
	return ""


func _assert_tab_cycle() -> String:
	var idxs: Array[int] = BattleAttackCycle.threatened_indices(_battle)
	var second: int = BattleAttackCycle.apply_next(_battle)
	if second != idxs[1]:
		return "next expected %s got %s" % [idxs[1], second]
	if int(_battle.preview_attack_ui) != second:
		return "preview not advanced"
	var back: int = BattleAttackCycle.apply_prev(_battle)
	if back != idxs[0]:
		return "prev expected %s got %s" % [idxs[0], back]
	_battle.preview_attack_ui = idxs[idxs.size() - 1]
	var wrap: int = BattleAttackCycle.apply_next(_battle)
	if wrap != idxs[0]:
		return "wrap expected %s got %s" % [idxs[0], wrap]
	return ""


func _assert_clear() -> String:
	BattleTouchConfirm.clear(_battle, false)
	if _battle.has_meta(BattleAttackCycle.META):
		return "clear left attack cycle meta"
	if int(_battle.preview_attack_ui) != -1:
		return "clear left preview_attack_ui"
	_battle.attack_mode = false
	if BattleAttackCycle.active(_battle):
		return "attack_mode=false should suppress cycle"
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
