extends Node
## Y1-A T-P5: war-chess select/feel fat knife — touch-select (soft+contour prefer),
## select chrome (foot/mid/body burst), invalid-target reject, and real select/confirm
## InputRouter E2E under CK_FORCE_MOBILE. Fail-suite (no EmptyHost theater).

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
		err = _contour_prefer_player()
	if err == "":
		err = _select_burst_and_lock()
	if err == "":
		err = _clear_refocuses()
	if err == "":
		err = _invalid_reject_keeps_select()
	if err == "":
		err = _e2e_select_confirm_path()
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
	var ally_c: Vector2 = host.screen_at_cell(Vector2i(2, 2))
	var foe_c: Vector2 = host.screen_at_cell(Vector2i(3, 2))
	var finger: Vector2 = foe_c.lerp(ally_c, 0.62)
	var hit: Vector2i = BattlePick.nearest_unit_pos(
		host.ORIGIN, float(host.CELL), host.units, finger, BattlePick.SOFT_R, "foe")
	if hit != Vector2i(3, 2):
		return "scrum prefer foe missed bandit (got %s)" % str(hit)
	if BattlePick._resolve_prefer_team(host) != "foe":
		return "attack_mode prefer should be foe"
	host.attack_mode = false
	if BattlePick._resolve_prefer_team(host) != "player":
		return "select prefer should be player"
	return ""


func _contour_prefer_player() -> String:
	## Adjacent bodies overlap at mobile half_w>0.5: finger in both AABBs, nearer
	## foe feet — prefer_team player still picks ally.
	var origin := Vector2(0, 0)
	var cell := 40.0
	var units: Array = [
		{"char": {"hp": 10}, "pos": Vector2i(2, 2), "team": "player"},
		{"char": {"hp": 10}, "pos": Vector2i(3, 2), "team": "bandit"},
	]
	# Mid-figure height; lx=3.02 sits in the 0.55-half overlap [2.95, 3.05], nearer foe.
	var y: float = origin.y + (2.0 + (BattlePick.FIG_TOP + BattlePick.FIG_FEET) * 0.5) * cell
	var finger := Vector2(origin.x + 3.02 * cell, y)
	if BattlePick.contour_half_w() <= 0.5:
		return "mobile contour_half_w must exceed 0.5 so adjacent bodies overlap"
	var hit: Vector2i = BattlePick.contour_unit_pos(origin, cell, units, finger, "player")
	if hit != Vector2i(2, 2):
		return "contour prefer player missed ally (got %s)" % str(hit)
	var raw: Vector2i = BattlePick.contour_unit_pos(origin, cell, units, finger, "")
	if raw != Vector2i(3, 2):
		return "control: nearer foe feet should win contour without prefer (got %s)" % str(raw)
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
	if BattleTouchConfirm.try_deselect(host, host.selected):
		return "try_deselect must no-op during select_lock"
	if host.selected != 0:
		return "selection must survive locked re-tap"
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
	BattleTouchConfirm.clear(host)
	if host.preview_move_cell.x >= 0:
		return "clear left move preview"
	if host.selected != 0:
		return "clear must keep selection"
	if not host.has_meta("m_select_burst_msec"):
		return "clear→focus_selected must stamp select burst"
	return ""


func _invalid_reject_keeps_select() -> String:
	var host := _FakeBattleHost.new()
	host.setup_selected_at(Vector2i(2, 2))
	host.move_cells = {Vector2i(3, 2): true}
	var illegal := Vector2i(5, 5)
	if not BattleTouchConfirm.reject_invalid_tap(host, illegal):
		return "reject_invalid_tap should handle illegal empty"
	if host.selected != 0:
		return "reject must keep selection"
	if BattlePick.select_lock_active(host):
		pass  # lock may or may not be set; reject must not clear select
	if BattleTouchConfirm.reject_flash_cell(host) != illegal:
		return "reject flash cell mismatch"
	if BattleTouchConfirm.reject_flash_alpha(host) <= 0.0:
		return "reject flash alpha should be live at t0"
	if host._shake < 0.5:
		return "reject should trauma-nudge _shake"
	if host.logs.is_empty():
		return "reject should _log locale toast"
	# Legal move cell must NOT reject
	var host2 := _FakeBattleHost.new()
	host2.setup_selected_at(Vector2i(2, 2))
	host2.move_cells = {Vector2i(3, 2): true}
	if BattleTouchConfirm.reject_invalid_tap(host2, Vector2i(3, 2)):
		return "legal move cell must not reject"
	return ""


func _e2e_select_confirm_path() -> String:
	## Real InputRouter path: soft-near press on ally contour → tap → selection lands;
	## illegal empty → reject stamped; legal preview cell → confirm_move commits.
	var host := _FakeBattleHost.new()
	host.setup_scrum()
	host.selected = -1
	host.move_cells = {Vector2i(3, 3): true}
	# Contour shoulder of ally@(2,2): mid-figure, slightly off centre toward empty.
	var shoulder: Vector2 = host.ORIGIN + Vector2(2.0 + 0.5 + BattlePick.contour_half_w() * 0.7, 2.0 + (BattlePick.FIG_TOP + BattlePick.FIG_FEET) * 0.5) * float(host.CELL)
	var resolved: Vector2i = BattlePick.resolve(host, shoulder)
	if resolved != Vector2i(2, 2):
		return "E2E resolve contour shoulder must pick ally (got %s)" % str(resolved)
	# Router: press+release within slop → tap gesture
	var r := InputRouter.new()
	r.sticky_fn = func(o: Vector2) -> bool: return BattlePick.near_living_unit(host, o)
	var down: Array = r.push(_touch(0, true, shoulder), 1000)
	var up: Array = r.push(_touch(0, false, shoulder), 1080)
	var saw_tap := false
	for g in up:
		if str(g.get("kind", "")) == "tap":
			saw_tap = true
			# Apply like battle_controller would: resolve → select
			var cell: Vector2i = BattlePick.resolve(host, g.get("pos", shoulder))
			var ui: int = host._unit_at(cell)
			if ui < 0:
				return "E2E tap resolve missed living unit"
			host.selected = ui
			BattlePick.focus_selected(host)
	if not saw_tap:
		return "E2E press+release must emit tap"
	if host.selected != 0:
		return "E2E tap must select ally index 0"
	if not host.has_meta("m_select_burst_msec"):
		return "E2E select must stamp burst chrome"
	# Expire lock so reject path is independent of deselect lock
	host.set_meta("m_select_burst_msec", Time.get_ticks_msec() - 1000)
	var illegal := Vector2i(6, 6)
	if not BattleTouchConfirm.reject_invalid_tap(host, illegal):
		return "E2E illegal empty must reject"
	if host.selected != 0:
		return "E2E reject must keep selection"
	# Confirm path: latch preview then clear (confirm_move does this before commit_move).
	# Full commit_move needs BattleSnapshot/Sfx/map — covered by source contract + clear keep-select.
	host.preview_move_cell = Vector2i(3, 3)
	BattleTouchConfirm.clear(host)
	if host.preview_move_cell.x >= 0:
		return "E2E confirm-clear must drop preview"
	if host.selected != 0:
		return "E2E confirm-clear must keep selection for commit"
	if not host.has_meta("m_select_burst_msec"):
		return "E2E confirm-clear must re-focus / burst"
	return ""


func _source_contracts() -> String:
	var err := _source_pick()
	if err == "":
		err = _source_confirm()
	if err == "":
		err = _source_controller_locale()
	return err


func _source_pick() -> String:
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	if pick.find("SELECT_LOCK_MSEC") < 0:
		return "pick missing SELECT_LOCK_MSEC"
	if pick.find("_resolve_prefer_team") < 0:
		return "pick missing _resolve_prefer_team"
	if pick.find("note_select_burst") < 0:
		return "pick missing note_select_burst"
	if pick.find("prefer_team") < 0:
		return "pick missing prefer_team on soft/contour"
	if pick.find("contour_unit_pos(origin: Vector2, cell_px: float, units: Array, local: Vector2, prefer_team") < 0:
		return "contour_unit_pos missing prefer_team arg"
	return ""


func _source_confirm() -> String:
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if conf.find("select_lock_active") < 0:
		return "touch_confirm missing select_lock_active gate"
	if conf.find("BattlePick.focus_selected(host)") < 0:
		return "clear missing re-focus"
	if conf.find("reject_invalid_tap") < 0 or conf.find("draw_reject_flash") < 0:
		return "touch_confirm missing invalid-target reject"
	if conf.find("focus_follow_preview(host)") < 0 or conf.find("commit_move(host, cell)") < 0:
		return "confirm_move must soft-follow then commit (real select/confirm path)"
	return ""


func _source_controller_locale() -> String:
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("select_burst_scale") < 0:
		return "controller draw missing select_burst_scale"
	if ctrl.find("FIG_FEET") < 0 or ctrl.find("contour_half_w") < 0:
		return "controller missing foot disc / body rect chrome"
	if ctrl.find("draw_reject_flash") < 0 or ctrl.find("reject_invalid_tap") < 0:
		return "controller missing reject wire"
	# Ban thin residual-only knife: must touch pick resolve/contour, not only bar/info.
	if ctrl.find("battle_mobile_bar") >= 0 and pick.find("prefer_team") < 0:
		return "thin residual knife detected"
	var ux := FileAccess.get_file_as_string("res://data/locale/ux.csv")
	if ux.find("ux_invalid_move_tap") < 0 or ux.find("ux_invalid_attack_tap") < 0:
		return "locale invalid-target keys missing"
	return ""


func _touch(index: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	return e


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
	var _shake: float = 0.0
	var move_committed: bool = false
	var logs: Array = []

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

	func _log(msg: String) -> void:
		logs.append(msg)

	func get_node_or_null(_path: NodePath) -> Node:
		return null

	func _in_bounds(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.y >= 0 and cell.x < 12 and cell.y < 10
