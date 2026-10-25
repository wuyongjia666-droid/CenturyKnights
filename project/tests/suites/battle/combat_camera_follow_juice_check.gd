extends Node
## Y1-A T-P4: combat camera focus follow + attack preview juice — path E2E under
## CK_FORCE_MOBILE. Soft-follow settles on confirm (not mid unit-drag); juice + algebra on duck host.

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var err := _check()
	if err == "":
		print("COMBAT CAMERA FOLLOW JUICE PASS")
		get_tree().quit(0)
	else:
		push_error(err)
		print("FAIL ", err)
		get_tree().quit(1)

func _check() -> String:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _source()
	if err == "":
		err = _algebra()
	if err == "":
		err = _path_move_follow()
	if err == "":
		err = _path_attack_juice_wire()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err

func _source() -> String:
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if pick.find("focus_follow_preview") < 0 or pick.find("focus_nudge_delta") < 0:
		return "focus follow helpers missing"
	if pick.find("FOCUS_SMOOTH_SEC") < 0 or pick.find("_tween_board_pan") < 0:
		return "smooth focus tween missing"
	if pick.find("cancel_focus_tween") < 0:
		return "focus tween cancel missing (gesture must own pan)"
	if conf.find("BattlePick.focus_follow_preview(host)") < 0:
		return "confirm missing focus_follow_preview settle wire"
	if conf.find("never mid unit-drag") < 0 and conf.find("do not soft-follow mid unit-drag") < 0:
		return "missing pan≠drag guard comment on soft-follow"
	if conf.find("attack_preview_juice") < 0 or conf.find("draw_line") < 0:
		return "attack preview juice / aim line missing"
	if conf.find("attack_preview_pulse") < 0:
		return "attack preview pulse missing"
	# Select still focuses; confirm still focuses (T-P1+) — T-P4 keeps those hooks.
	if ctrl.find("BattlePick.focus_selected(self)") < 0:
		return "select missing camera focus"
	if conf.find("BattlePick.focus_cell(host") < 0:
		return "confirm move/attack missing camera focus"
	return ""

func _algebra() -> String:
	var origin := Vector2(40, 80)
	var cell_px := 56.0
	var stage := Rect2(24, 76, 360, 280)
	var cell := Vector2i(1, 1)
	var centred: Vector2 = BattlePick.focus_pan_delta(origin, cell_px, cell, Vector2.ZERO, 1.0, stage)
	if BattlePick.focus_nudge_delta(origin, cell_px, cell, centred, 1.0, stage).length() > 0.5:
		return "centred cell must not nudge"
	var off: Vector2 = BattlePick.focus_nudge_delta(origin, cell_px, cell, Vector2(900, 400), 1.0, stage)
	if off.length_squared() < 1.0:
		return "far pan must nudge cell back into inset"
	var a := BattlePick.focus_pan_lerp(Vector2(0, 0), Vector2(20, 10), 0.25)
	if absf(a.x - 5.0) > 0.01 or absf(a.y - 2.5) > 0.01:
		return "focus_pan_lerp failed: %s" % a
	var j0: Dictionary = BattleTouchConfirm.attack_preview_juice(64.0, 0.0)
	var j1: Dictionary = BattleTouchConfirm.attack_preview_juice(64.0, 1.0)
	if float(j1.ring_r) <= float(j0.ring_r) or float(j1.halo_a) <= float(j0.halo_a):
		return "juice pulse must widen ring and raise halo"
	if float(j0.chev_len) < 8.0:
		return "chevron length too small"
	return ""

func _path_move_follow() -> String:
	## Drag to a legal cell that sits off the stage inset → pan must soft-nudge.
	var host := _FakeBattleHost.new()
	host.setup_selected_at(Vector2i(1, 1))
	host.move_cells = {Vector2i(8, 1): true}
	# Stage is narrow; cell (8,1) centre is far right of inset with pan=0.
	var land := host.screen_at_cell(Vector2i(8, 1))
	var pan_before: Vector2 = host._board_pan
	BattleTouchConfirm.on_drag(host, land)
	if host.preview_move_cell != Vector2i(8, 1):
		return "move drag must ghost legal cell: %s" % str(host.preview_move_cell)
	# Mid-drag must NOT pan (safe-area unit-drag contract); settle via follow helper.
	if host._board_pan != pan_before:
		return "unit/move drag must not pan mid-gesture (got %s)" % host._board_pan
	BattlePick.focus_follow_preview(host)
	if host._board_pan == pan_before:
		# If algebra says nudge is zero for this stage layout, fail with detail.
		var stage: Rect2 = host._stage
		var expect: Vector2 = BattlePick.focus_nudge_delta(
			host._board_origin, float(host._board_cell), Vector2i(8, 1), pan_before, 1.0, stage)
		if expect.length_squared() < 1.0:
			return "fixture stage too large — cell (8,1) unexpectedly inside inset"
		return "focus_follow_preview did not move pan (expect delta %s)" % expect
	return ""

func _path_attack_juice_wire() -> String:
	## Attack latch changes preview_attack_ui and follows the defender cell.
	var host := _FakeBattleHost.new()
	host.setup_selected_at(Vector2i(1, 1))
	host.attack_mode = true
	host.units.append({"char": {"hp": 10, "name": "Foe"}, "pos": Vector2i(8, 2), "team": "enemy", "done": false})
	host.can_attack_cells = {Vector2i(8, 2): true}
	var pan_before: Vector2 = host._board_pan
	BattleTouchConfirm.on_drag(host, host.screen_at_cell(Vector2i(8, 2)))
	if int(host.preview_attack_ui) != 1:
		return "attack drag must latch enemy ui: %s" % str(host.preview_attack_ui)
	if host._board_pan != pan_before:
		return "attack drag must not pan mid-gesture"
	BattlePick.focus_follow_preview(host)
	if host._board_pan == pan_before:
		var expect: Vector2 = BattlePick.focus_nudge_delta(
			host._board_origin, float(host._board_cell), Vector2i(8, 2), pan_before, 1.0, host._stage)
		if expect.length_squared() < 1.0:
			return "fixture stage too large for attack follow"
		return "attack latch must soft-follow defender"
	# Juice dictionary stable under CK_FORCE_MOBILE.
	var juice: Dictionary = BattleTouchConfirm.attack_preview_juice(float(host._board_cell), 0.8)
	if float(juice.ring_r) < float(host._board_cell) * 0.5:
		return "attack juice ring too small"
	return ""

class _FakeBattleHost:
	var _board_origin: Vector2 = Vector2(40, 80)
	var _board_cell: int = 56
	## Narrow stage so cell x=8 sits outside the 0.18 inset (forces a nudge).
	var _stage: Rect2 = Rect2(24, 76, 280, 220)
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
	var can_attack_cells: Dictionary = {}
	var overlay = null
	var _mobile_bar = null
	var _board_pan: Vector2 = Vector2.ZERO
	var _board_zoom: float = 1.0

	func _get(property: StringName) -> Variant:
		if property == &"ORIGIN":
			return _board_origin
		if property == &"CELL":
			return _board_cell
		if property == &"BOARD_AREA":
			return _stage
		return null

	func setup_selected_at(pos: Vector2i) -> void:
		units = [{"char": {"hp": 10, "name": "Hero"}, "pos": pos, "team": "player", "done": false}]
		selected = 0
		set_meta("m_board_area", _stage)

	func screen_at_cell(cell: Vector2i) -> Vector2:
		return _board_origin + Vector2(cell) * float(_board_cell) + Vector2(_board_cell, _board_cell) * 0.5

	func _screen_to_local(p: Vector2) -> Vector2:
		return p

	func _pointer_to_cell(screen_pos: Vector2) -> Vector2i:
		var local: Vector2 = BattlePick.local_after_pan_zoom(_screen_to_local(screen_pos), _board_pan, _board_zoom)
		return BattlePick.cell_at_local(_board_origin, float(_board_cell), local, 16, 12)

	func _unit_at(pos: Vector2i) -> int:
		for i in units.size():
			if units[i].char.hp > 0 and units[i].pos == pos:
				return i
		return -1

	func _in_bounds(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < 16 and c.y < 12

	func _can_attack_from(_su, cell: Vector2i) -> bool:
		return can_attack_cells.has(cell)

	func _clamp_board_pan() -> void:
		_board_pan = BattlePick.clamp_pan(_board_pan, _board_zoom, _board_origin, Vector2(16, 12) * float(_board_cell), _stage)

	func _apply_board_xform() -> void:
		pass

	func get_node_or_null(_path: NodePath) -> Node:
		# ForecastPanel.refresh early-outs when the panel node is absent.
		return null
