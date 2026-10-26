extends Node
## Y1-A T-P53: height-aim telegraph. Real battle E2E.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

var _battle: Control
var _player_i := -1
var _foe_i := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL height aim telegraph: ", err)
		get_tree().quit(1)
		return
	print("COMBAT HEIGHT AIM TELEGRAPH PASS")
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
	var tele := FileAccess.get_file_as_string("res://scripts/battle/battle_height_aim_telegraph.gd")
	if ctrl.find("BattleHeightAimTelegraph.draw(self, overlay)") < 0:
		return "controller missing height-aim draw"
	if ctrl.find("BattleHeightAimTelegraph.refresh(self)") < 0:
		return "controller missing height-aim refresh"
	if touch.find("BattleHeightAimTelegraph.clear(host)") < 0:
		return "touch clear missing height-aim clear"
	if touch.find("BattleHeightAimTelegraph.refresh(host)") < 0:
		return "touch missing height-aim refresh"
	if tele.find("height_hit") < 0:
		return "must use height_hit"
	if tele.find("Locale.t(\"shell_height_aim_high_mark\")") < 0:
		return "height-aim high mark must be Locale.t"
	if tele.find("Locale.t(\"shell_height_aim_low_mark\")") < 0:
		return "height-aim low mark must be Locale.t"
	if tele.find("EmptyHost") >= 0 or ctrl.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	if ctrl.split("\n").size() > 3000:
		return "battle_controller over 3000 lines"
	for ch in tele:
		var o := ch.unicode_at(0)
		if o >= 0x4E00 and o <= 0x9FFF:
			return "height-aim telegraph has CJK literal"
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


func _ensure_height_grid() -> void:
	var th: int = _battle.terrain.size()
	var tw: int = _battle.terrain[0].size() if th > 0 else 8
	if _battle.height_grid.size() != th:
		_battle.height_grid.clear()
		for y in th:
			var row: Array = []
			for x in tw:
				row.append(0)
			_battle.height_grid.append(row)


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
	var foe_pos := Vector2i(mini(stand.x + 1, tw - 1), stand.y)
	if foe_pos == stand:
		foe_pos = Vector2i(stand.x, mini(stand.y + 1, th - 1))
	_battle.units[_player_i].pos = stand
	_battle.units[_player_i].done = false
	_battle.units[_foe_i].pos = foe_pos
	_ensure_height_grid()
	# Attacker high → positive height_hit
	_battle.height_grid[stand.y][stand.x] = 2
	_battle.height_grid[foe_pos.y][foe_pos.x] = 0
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
	_battle.preview_attack_ui = _foe_i
	var hit := BattleHeightAimTelegraph.refresh(_battle)
	if not hit or not BattleHeightAimTelegraph.will_mark(_battle):
		return "expected height-aim telegraph (delta=%d)" % BattleHeightAimTelegraph.height_delta(_battle)
	if not _battle.has_meta(BattleHeightAimTelegraph.META):
		return "height-aim meta missing"
	# Flatten
	var stand: Vector2i = _battle.units[_player_i].pos
	var foe_pos: Vector2i = _battle.units[_foe_i].pos
	_battle.height_grid[stand.y][stand.x] = 0
	_battle.height_grid[foe_pos.y][foe_pos.x] = 0
	var no := BattleHeightAimTelegraph.refresh(_battle)
	if no or BattleHeightAimTelegraph.will_mark(_battle):
		return "should clear when height flat"
	if _battle.has_meta(BattleHeightAimTelegraph.META):
		return "meta should clear"
	# Restore + touch clear
	_battle.height_grid[stand.y][stand.x] = 2
	_battle.preview_attack_ui = _foe_i
	BattleHeightAimTelegraph.refresh(_battle)
	BattleTouchConfirm.clear(_battle)
	if _battle.has_meta(BattleHeightAimTelegraph.META):
		return "touch clear should drop height-aim meta"
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
