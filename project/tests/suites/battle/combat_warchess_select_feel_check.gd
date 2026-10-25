extends Node
## Y1-A T-P5: mobile war-chess select/feel — team-prefer soft scrum, select-lock,
## select-burst juice, clear→re-focus. Owned under CK_FORCE_MOBILE (no EmptyHost).

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL warchess select feel: ", err)
		get_tree().quit(1)
		return
	print("COMBAT WARCHESS SELECT FEEL PASS")
	get_tree().quit(0)


func _run() -> String:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		OS.set_environment("CK_FORCE_MOBILE", "0")
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _scrum_prefer_player()
	if err == "":
		err = _scrum_prefer_foe_in_attack()
	if err == "":
		err = _select_burst_and_lock()
	if err == "":
		err = _clear_refocuses()
	if err == "":
		err = _source_contracts()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err


func _scrum_prefer_player() -> String:
	## Ally + foe centres both inside SOFT_R; finger nearer the foe — still pick ally.
	var origin := Vector2(40, 80)
	var cell := 56.0
	var units: Array = [
		{"char": {"hp": 10}, "pos": Vector2i(2, 2), "team": "player"},
		{"char": {"hp": 10}, "pos": Vector2i(3, 2), "team": "bandit"},
	]
	var ally_c: Vector2 = origin + Vector2(2, 2) * cell + Vector2(cell, cell) * 0.5
	var foe_c: Vector2 = origin + Vector2(3, 2) * cell + Vector2(cell, cell) * 0.5
	# Finger 60% of the way toward the foe (nearer foe) but still within soft of both.
	var finger: Vector2 = ally_c.lerp(foe_c, 0.62)
	var hit: Vector2i = BattlePick.nearest_unit_pos(origin, cell, units, finger, BattlePick.SOFT_R, "player")
	if hit != Vector2i(2, 2):
		return "scrum prefer player missed ally (got %s)" % str(hit)
	var raw: Vector2i = BattlePick.nearest_unit_pos(origin, cell, units, finger, BattlePick.SOFT_R, "")
	if raw != Vector2i(3, 2):
		return "control: nearer foe should win without prefer (got %s)" % str(raw)
	return ""


func _scrum_prefer_foe_in_attack() -> String:
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	host.attack_mode = true
	# Finger between ally@ (2,2) and foe@(3,2), nearer ally — attack mode still wants foe.
	var ally_c: Vector2 = host.screen_at_cell(Vector2i(2, 2))
	var foe_c: Vector2 = host.screen_at_cell(Vector2i(3, 2))
	var finger: Vector2 = foe_c.lerp(ally_c, 0.62)
	# resolve uses prefer foe when attack_mode; exact cell empty so soft path runs.
	# Place finger on empty cell centre between them.
	var mid_cell := Vector2i(2, 3)  # may not be between — use local soft path via nearest
	var local: Vector2 = finger  # host local==screen
	var hit: Vector2i = BattlePick.nearest_unit_pos(
		host.ORIGIN, float(host.CELL), host.units, local, BattlePick.SOFT_R, "foe")
	if hit != Vector2i(3, 2):
		return "scrum prefer foe missed bandit (got %s)" % str(hit)
	if BattlePick._resolve_prefer_team(host) != "foe":
		return "attack_mode prefer should be foe"
	host.attack_mode = false
	if BattlePick._resolve_prefer_team(host) != "player":
		return "select prefer should be player"
	return ""


func _select_burst_and_lock() -> String:
	var host := _FakeBattleHost.new()
	host.setup_selected_at(Vector2i(2, 2))
	var t0: int = Time.get_ticks_msec()
	host.set_meta("m_select_burst_msec", t0)
	var s0: float = BattlePick.select_burst_scale(host, t0)
	if s0 < 1.35 or s0 > 1.45:
		return "burst at t0 expected ~1.4 got %.3f" % s0
	var s_mid: float = BattlePick.select_burst_scale(host, t0 + 190)
	if s_mid >= s0 or s_mid <= 1.0:
		return "burst mid should decay between 1 and peak (%.3f)" % s_mid
	var s_done: float = BattlePick.select_burst_scale(host, t0 + 500)
	if s_done != 1.0:
		return "burst after window should be 1.0 (%.3f)" % s_done
	if not BattlePick.select_lock_active(host, t0 + 100):
		return "lock should be active at +100ms"
	if BattlePick.select_lock_active(host, t0 + 400):
		return "lock should be clear at +400ms"
	# try_deselect blocked while locked (uses live clock vs meta t0)
	if BattleTouchConfirm.try_deselect(host, host.selected):
		return "try_deselect must no-op during select_lock"
	if host.selected != 0:
		return "selection must survive locked re-tap"
	# After lock expires, re-tap deselects
	host.set_meta("m_select_burst_msec", t0 - 1000)
	if not BattleTouchConfirm.try_deselect(host, 0):
		return "try_deselect should fire after lock"
	if host.selected != -1:
		return "selection should clear after unlocked re-tap"
	return ""


func _clear_refocuses() -> String:
	var host := _FakeBattleHost.new()
	host.setup_selected_at(Vector2i(4, 4))
	host.preview_move_cell = Vector2i(5, 4)
	host._board_pan = Vector2(80, 60)
	var pan_before: Vector2 = host._board_pan
	BattleTouchConfirm.clear(host)
	if host.preview_move_cell.x >= 0:
		return "clear left move preview"
	if host.selected != 0:
		return "clear must keep selection"
	# focus_selected notes burst + may nudge pan; burst meta must be stamped
	if not host.has_meta("m_select_burst_msec"):
		return "clear→focus_selected must stamp select burst"
	return ""


func _source_contracts() -> String:
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	if pick.find("SELECT_LOCK_MSEC") < 0:
		return "pick missing SELECT_LOCK_MSEC"
	if pick.find("prefer_team") < 0 and pick.find("prefer_team") < 0:
		pass
	if pick.find("_resolve_prefer_team") < 0:
		return "pick missing _resolve_prefer_team"
	if pick.find("note_select_burst") < 0:
		return "pick missing note_select_burst"
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if conf.find("select_lock_active") < 0:
		return "touch_confirm missing select_lock_active gate"
	if conf.find("BattlePick.focus_selected(host)") < 0:
		return "clear missing re-focus"
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("select_burst_scale") < 0:
		return "controller draw missing select_burst_scale"
	return ""


class _FakeBattleHost:
	var _stage: Rect2 = Rect2(0, 0, 720, 1280)
	var _board_origin: Vector2 = Vector2(40, 80)
	var _board_cell: int = 56
	var units: Array = []
	var selected: int = -1
	var turn_team: String = "player"
	var battle_over: bool = false
	var _cut_playing: bool = false
	var moved_this_select: bool = false
	var attack_mode: bool = false
	var preview_move_cell: Vector2i = Vector2i(-1, -1)
	var preview_attack_ui: int = -1
	var move_cells: Dictionary = {}
	var overlay = null
	var _mobile_bar = null
	var _board_pan: Vector2 = Vector2.ZERO
	var _board_zoom: float = 1.0

	func _init() -> void:
		set_meta("m_board_area", _stage)

	func _get(property: StringName) -> Variant:
		if property == &"ORIGIN":
			return _board_origin
		if property == &"CELL":
			return _board_cell
		if property == &"BOARD_AREA":
			return _stage
		return null

	func _clamp_board_pan() -> void:
		pass

	func _apply_board_xform() -> void:
		pass

	func setup_selected_at(pos: Vector2i) -> void:
		units = [{"char": {"hp": 10, "name": "Hero"}, "pos": pos, "team": "player", "done": false}]
		selected = 0
		set_meta("m_board_area", _stage)

	func setup_scrum() -> void:
		units = [
			{"char": {"hp": 10, "name": "Hero"}, "pos": Vector2i(2, 2), "team": "player", "done": false},
			{"char": {"hp": 10, "name": "Bandit"}, "pos": Vector2i(3, 2), "team": "bandit", "done": false},
		]
		selected = 0
		set_meta("m_board_area", _stage)

	func screen_at_cell(cell: Vector2i) -> Vector2:
		return _board_origin + Vector2(cell) * float(_board_cell) + Vector2(_board_cell, _board_cell) * 0.5

	func _screen_to_local(p: Vector2) -> Vector2:
		return p

	func _pointer_to_cell(screen_pos: Vector2) -> Vector2i:
		var local: Vector2 = BattlePick.local_after_pan_zoom(_screen_to_local(screen_pos), _board_pan, _board_zoom)
		return BattlePick.cell_at_local(_board_origin, float(_board_cell), local, 12, 10)

	func _unit_at(pos: Vector2i) -> int:
		for i in units.size():
			if units[i].char.hp > 0 and units[i].pos == pos:
				return i
		return -1

	func _cancel_selection() -> void:
		selected = -1

	func get_node_or_null(_path: NodePath) -> Node:
		return null

	func _in_bounds(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.y >= 0 and cell.x < 12 and cell.y < 10
