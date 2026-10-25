extends Node
## Y1-A T-P3: combat camera drag/pan conflict + landscape confirm — touch-path E2E
## under CK_FORCE_MOBILE. Proves soft-empty beside selected pans (no commit), strict
## figure press unit-drags, selected-only sticky, and landscape Confirm stack policy.

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var err := _check()
	if err == "":
		print("COMBAT CAMERA TOUCH PATH PASS")
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
		err = _path_soft_empty_pans()
	if err == "":
		err = _path_strict_unit_drag()
	if err == "":
		err = _path_selected_sticky_slop()
	if err == "":
		err = _landscape_confirm_policy()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err

func _source() -> String:
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var bar := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_mobile_bar.gd")
	if pick.find("strict_hits_selected") < 0 or conf.find("strict_hits_selected") < 0:
		return "strict unit-drag origin not wired"
	if ctrl.find("near_selected_unit") < 0:
		return "selected sticky not wired"
	if ctrl.find("BattleTouchConfirm.is_unit_drag(self, g)") < 0:
		return "pan arm missing is_unit_drag gate"
	if bar.find("0.58") < 0 or bar.find("landscape_confirm_stack") < 0:
		return "landscape confirm T-P3 missing"
	if bar.find("ConfirmPrimary") < 0 or bar.find("ux_confirm_dest_move") < 0:
		return "named confirm / dest hint missing"
	var ux := FileAccess.get_file_as_string("res://data/locale/ux.csv")
	if ux.find("ux_confirm_dest_move") < 0 or ux.find("ux_confirm_dest_attack") < 0:
		return "locale dest hint keys missing"
	return ""

func _path_soft_empty_pans() -> String:
	## Press on soft-empty neighbour of selected → drag past slop → pan (not unit-drag);
	## drag_end must not commit.
	var host := _FakeBattleHost.new()
	host.setup_selected_at(Vector2i(2, 2))
	var origin_screen := host.screen_at_cell(Vector2i(3, 2))  # empty neighbour
	# Soft would resolve to selected; strict must not.
	if BattlePick.strict_hits_selected(host, origin_screen, 0):
		return "soft-empty should not strict-hit selected"
	if not BattlePick.near_selected_unit(host, origin_screen, 0):
		# soft may or may not depending on distance; centre of (3,2) is 1.0 cell away
		# from (2,2) centre — SOFT_R=0.90 may miss. Use eccentric closer point.
		origin_screen = host.ORIGIN + Vector2(2.5 + 0.85, 2.5) * float(host.CELL)
		if not BattlePick.near_living_unit(host, origin_screen):
			return "could not place soft-near empty press"
	var g_pan := {"kind": "pan", "origin": origin_screen, "pos": origin_screen + Vector2(40, 0),
		"delta": Vector2(40, 0), "multi": false}
	if BattleTouchConfirm.is_unit_drag(host, g_pan):
		return "soft-empty press must classify as map-pan, not unit-drag"
	# Simulate router: sticky micro-wobble stays tap; large drag becomes pan.
	var r := InputRouter.new()
	r.sticky_fn = func(o: Vector2) -> bool: return BattlePick.near_selected_unit(host, o, 0)
	var sticky_need: float = r._slop_for(origin_screen) + 12.0
	r.push(_touch(0, true, origin_screen), 1000)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = origin_screen + Vector2(sticky_need, 8)
	drag.relative = Vector2(sticky_need, 8)
	var mid: Array = r.push(drag, 1050)
	var saw_pan := false
	for g in mid:
		if str(g.get("kind", "")) == "pan":
			saw_pan = true
			if BattleTouchConfirm.is_unit_drag(host, g):
				return "router pan from soft-empty classified unit-drag"
	if not saw_pan:
		return "soft-empty large drag must promote to pan (need=%s)" % sticky_need
	var up: Array = r.push(_touch(0, false, drag.position), 1100)
	for g2 in up:
		if str(g2.get("kind", "")) == "drag_end":
			if BattleTouchConfirm.is_unit_drag(host, g2):
				return "drag_end after soft-empty pan must not unit-drag"
			BattleTouchConfirm.end_gesture(host)
	if host.move_committed:
		return "map-pan must not commit a move"
	return ""

func _path_strict_unit_drag() -> String:
	## Press on selected exact cell → pan gesture → is_unit_drag true; on_drag ghosts.
	var host := _FakeBattleHost.new()
	host.setup_selected_at(Vector2i(2, 2))
	host.move_cells = {Vector2i(3, 2): true, Vector2i(4, 2): true}
	var origin_screen := host.screen_at_cell(Vector2i(2, 2))
	if not BattlePick.strict_hits_selected(host, origin_screen, 0):
		return "exact selected must strict-hit"
	var g := {"kind": "pan", "origin": origin_screen, "pos": origin_screen + Vector2(30, 0),
		"delta": Vector2(30, 0), "multi": false}
	if not BattleTouchConfirm.is_unit_drag(host, g):
		return "exact selected press must be unit-drag"
	# Drag to legal cell — ghost preview (no live overlay required).
	var land := host.screen_at_cell(Vector2i(4, 2))
	BattleTouchConfirm.on_drag(host, land)
	if host.preview_move_cell != Vector2i(4, 2):
		return "unit-drag on_drag must ghost legal cell: %s" % str(host.preview_move_cell)
	# Multi/pinch never unit-drags.
	BattleTouchConfirm.end_gesture(host)
	var g_multi := {"kind": "pan", "origin": origin_screen, "pos": land, "delta": Vector2(10, 0), "multi": true}
	if BattleTouchConfirm.is_unit_drag(host, g_multi):
		return "pinch multi must never unit-drag"
	return ""

func _path_selected_sticky_slop() -> String:
	## With selected sticky_fn: micro-wobble on selected stays tap; press on other unit
	## uses base slop (easier pan).
	var host := _FakeBattleHost.new()
	host.setup_selected_at(Vector2i(2, 2))
	host.units.append({"char": {"hp": 10}, "pos": Vector2i(5, 3), "team": "enemy", "done": false})
	var r := InputRouter.new()
	r.sticky_fn = func(o: Vector2) -> bool: return BattlePick.near_selected_unit(host, o, 0)
	var on_sel := host.screen_at_cell(Vector2i(2, 2))
	var base: float = r._slop()
	var sticky: float = r._slop_for(on_sel)
	if sticky < base * InputRouter.STICKY_SLOP_MUL - 0.01:
		return "selected origin must get sticky slop"
	var on_other := host.screen_at_cell(Vector2i(5, 3))
	var other_slop: float = r._slop_for(on_other)
	if other_slop > base + 0.01:
		return "other-unit press must NOT sticky while selected: %s vs base %s" % [other_slop, base]
	# Micro-wobble on selected stays tap.
	r.push(_touch(0, true, on_sel), 2000)
	var wob := InputEventScreenDrag.new()
	wob.index = 0
	wob.position = on_sel + Vector2(base * 0.9, 0)
	wob.relative = Vector2(base * 0.9, 0)
	for g in r.push(wob, 2050):
		if str(g.get("kind", "")) == "pan":
			return "selected sticky micro-wobble promoted to pan"
	var up: Array = r.push(_touch(0, false, wob.position), 2100)
	if up.is_empty() or str(up[0].get("kind", "")) != "tap":
		return "selected sticky release must tap, got %s" % str(up)
	return ""

func _landscape_confirm_policy() -> String:
	var stack: PackedStringArray = BattleMobileBar.landscape_confirm_stack()
	if stack.is_empty() or str(stack[stack.size() - 1]) != "confirm" or str(stack[0]) != "cancel":
		return "landscape Confirm must sit at thumb bottom: %s" % str(stack)
	return ""

func _touch(index: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	return e

class _FakeBattleHost:
	var ORIGIN: Vector2 = Vector2(40, 80)
	var CELL: int = 56
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
	var move_committed: bool = false

	func setup_selected_at(pos: Vector2i) -> void:
		units = [{"char": {"hp": 10, "name": "Hero"}, "pos": pos, "team": "player", "done": false}]
		selected = 0

	func screen_at_cell(cell: Vector2i) -> Vector2:
		return ORIGIN + Vector2(cell) * float(CELL) + Vector2(CELL, CELL) * 0.5

	func _screen_to_local(p: Vector2) -> Vector2:
		return p

	func _pointer_to_cell(screen_pos: Vector2) -> Vector2i:
		var local: Vector2 = BattlePick.local_after_pan_zoom(_screen_to_local(screen_pos), _board_pan, _board_zoom)
		return BattlePick.cell_at_local(ORIGIN, float(CELL), local, 12, 10)

	func _unit_at(pos: Vector2i) -> int:
		for i in units.size():
			if units[i].char.hp > 0 and units[i].pos == pos:
				return i
		return -1

	func _cancel_selection() -> void:
		selected = -1
