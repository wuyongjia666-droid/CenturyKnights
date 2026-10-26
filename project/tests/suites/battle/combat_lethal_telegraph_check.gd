extends Node
## Y1-A T-P29: aimed strike with floor dmg >= foe HP telegraphs lethal. Real battle E2E.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

var _battle: Control
var _player_i := -1
var _foe_i := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL lethal telegraph: ", err)
		get_tree().quit(1)
		return
	print("COMBAT LETHAL TELEGRAPH PASS")
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
	var tele := FileAccess.get_file_as_string("res://scripts/battle/battle_lethal_telegraph.gd")
	if ctrl.find("BattleLethalTelegraph.draw(self, overlay)") < 0:
		return "controller missing lethal draw"
	if ctrl.find("BattleLethalTelegraph.refresh(self)") < 0:
		return "controller missing lethal refresh"
	if touch.find("BattleLethalTelegraph.clear(host)") < 0:
		return "touch clear missing lethal clear"
	if touch.find("BattleLethalTelegraph.refresh(host)") < 0:
		return "touch missing lethal refresh"
	if tele.find("BattleRules.preview") < 0:
		return "must use BattleRules.preview for floor dmg"
	if tele.find("Locale.t(\"shell_lethal_mark\")") < 0:
		return "lethal mark must be Locale.t"
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
	_battle.units[_player_i].char.recalc_hp()
	_battle.units[_player_i].char.hp = _battle.units[_player_i].char.max_hp
	_battle.units[_foe_i].pos = near
	_battle.units[_foe_i].char.job_id = "light_inf"
	_battle.units[_foe_i].char.recalc_hp()
	# Floor dmg for light_inf vs light_inf is typically >1; force low HP for certain lethal.
	_battle.units[_foe_i].char.hp = 1
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
	var hit := BattleLethalTelegraph.refresh(_battle)
	if not hit or not BattleLethalTelegraph.will_lethal(_battle):
		return "expected lethal vs hp=1 foe floor=%d" % BattleLethalTelegraph.floor_damage(_battle)
	if not _battle.has_meta(BattleLethalTelegraph.META):
		return "lethal meta missing"
	# Raise foe HP above any reasonable floor → clear.
	_battle.units[_foe_i].char.hp = 9999
	var no := BattleLethalTelegraph.refresh(_battle)
	if no or BattleLethalTelegraph.will_lethal(_battle):
		return "should clear when foe tanky"
	if _battle.has_meta(BattleLethalTelegraph.META):
		return "meta should clear when not lethal"
	# Restore lethal and cancel via touch clear.
	_battle.units[_foe_i].char.hp = 1
	BattleLethalTelegraph.refresh(_battle)
	if not _battle.has_meta(BattleLethalTelegraph.META):
		return "meta missing after restore"
	BattleTouchConfirm.clear(_battle)
	if _battle.has_meta(BattleLethalTelegraph.META):
		return "touch clear should drop lethal meta"
	if int(_battle.preview_attack_ui) >= 0:
		return "preview should clear with touch clear"
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
