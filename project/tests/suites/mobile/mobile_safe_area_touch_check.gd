extends Node
## Y1-A T-P1-2 (runtime): real safe-area inset + real camera pan/zoom on a live battle.
## Named mobile_* so ci_godot_run.sh sets CK_FORCE_MOBILE=1 (MobileChrome is live).
## Every touch goes through Viewport.push_input → GUI → battle._gui_input, i.e. the same
## path a finger takes on device; positions are computed from the board's real global
## transform, so a double-applied inset / root scale fails here.
## CK_SAFE_INSETS simulates the notch; the device value still needs a phone (see audit doc).

var _battle: Control
var _p := -1
var _e := -1

func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL mobile safe area touch: ", err)
		get_tree().quit(1)
		return
	print("MOBILE SAFE AREA TOUCH PASS")
	get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _pure()
	if err == "":
		err = await _setup()
	if err == "":
		err = await _stage_tap_zoom()
	if err == "":
		err = await _stage_pan_drag()
	if err == "":
		err = await _stage_flip()
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
	return err

func _setup() -> String:
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
	# Notch on the left edge (landscape), in window px.
	OS.set_environment("CK_SAFE_INSETS", "120,0,0,24")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle()
	var ins: Dictionary = _battle.get_meta("mobile_insets", {})
	if float(ins.get("left", 0.0)) < 100.0:
		return "safe inset not applied to battle root: %s" % str(ins)
	if _battle.get_global_transform().origin.x < 100.0:
		return "battle root not shifted into the safe rect: %s" % str(_battle.get_global_transform())
	print("SAFE root xform=", _battle.get_global_transform(), " insets=", ins)
	if not _arrange():
		return "deploy missing player/enemy"
	await _settle()
	return ""

func _stage_tap_zoom() -> String:
	# 1) Tap the player unit at its on-screen position → selected.
	await _tap(_screen_of(_battle.units[_p].pos))
	if _battle.selected != _p:
		return "tap under safe inset missed unit: selected=%s want=%s" % [_battle.selected, _p]
	# 2) Pinch zoom in with the unit selected; lifting must NOT commit a move.
	var before: Vector2i = _battle.units[_p].pos
	var z0: float = _battle._board_zoom
	await _pinch(_screen_of(Vector2i(6, 4)), 80.0, 260.0)
	if _battle._board_zoom <= z0 + 0.05:
		return "pinch did not zoom: %s → %s" % [z0, _battle._board_zoom]
	if _battle.units[_p].pos != before:
		return "pinch release committed a move: %s → %s" % [before, _battle.units[_p].pos]
	# 3) Zoom clamp: absurd pinches stay inside [ZOOM_MIN, ZOOM_MAX].
	var mid := _battle.get_global_rect().get_center()
	for _i in 4:
		await _pinch(mid, 60.0, 360.0)
	print("SAFE zoom after spread=", _battle._board_zoom)
	if absf(_battle._board_zoom - BattlePick.ZOOM_MAX) > 0.001:
		return "zoom not clamped at max: %s" % _battle._board_zoom
	for _i in 6:
		await _pinch(mid, 360.0, 60.0)
	print("SAFE zoom after squeeze=", _battle._board_zoom)
	if absf(_battle._board_zoom - BattlePick.ZOOM_MIN) > 0.001:
		return "zoom not clamped at min: %s" % _battle._board_zoom
	await _pinch(mid, 100.0, 190.0)
	print("SAFE zoom=", _battle._board_zoom, " pan=", _battle._board_pan)
	# 4) After zoom + pan the tap still lands: deselect, re-tap the unit.
	_battle._cancel_selection()
	await _drag(_screen_of(Vector2i(8, 5)), _screen_of(Vector2i(8, 5)) + Vector2(-90, -40))
	await _tap(_screen_of(_battle.units[_p].pos))
	if _battle.selected != _p:
		return "tap after pan/zoom missed unit: selected=%s" % _battle.selected
	return ""

func _stage_pan_drag() -> String:
	# 5) Map pan that ends on a legal move cell must NOT move the unit (pan ≠ drag-commit).
	var before: Vector2i = _battle.units[_p].pos
	var dest := _legal_dest()
	if dest.x < 0:
		return "no legal move cell"
	_battle._board_zoom = 1.0
	_battle._board_pan = Vector2.ZERO
	_battle._apply_board_xform()
	await _settle()
	var pan0: Vector2 = _battle._board_pan
	var far := _empty_far_cell()
	var a := _screen_of(far)
	await _drag(a, a + (_screen_of(dest) - _screen_of(far)).limit_length(140.0))
	if _battle.units[_p].pos != before:
		return "map pan committed a move to %s" % str(_battle.units[_p].pos)
	if _battle._board_pan.distance_to(pan0) < 4.0:
		return "map pan did not move the board"
	# 6) Drag that starts on the selected unit is a unit drag: board stays, release commits.
	dest = _legal_dest()
	var pan1: Vector2 = _battle._board_pan
	var dest_px := _screen_of(dest)
	await _drag(_screen_of(_battle.units[_p].pos), dest_px, false)
	if _battle._board_pan.distance_to(pan1) > 0.5:
		return "unit drag panned the board"
	if _battle.preview_move_cell != dest:
		return "unit drag ghost not on dest: %s want %s" % [_battle.preview_move_cell, dest]
	_touch(0, false, dest_px)
	await _settle()
	if _battle.units[_p].pos != dest:
		return "unit drag did not commit: pos=%s want=%s" % [_battle.units[_p].pos, dest]
	# 7) Pan bounds: a huge fling keeps PAN_KEEP_PX of board inside the stage.
	await _drag(Vector2(300, 300), Vector2(300, 300) + Vector2(5000, 4000))
	return _bounds()

func _stage_flip() -> String:
	# 8) 180° flip: notch moves to the right without a size change → poll re-applies.
	OS.set_environment("CK_SAFE_INSETS", "0,0,120,24")
	await get_tree().create_timer(MobileChrome.SAFE_POLL_S + 0.3).timeout
	await _settle()
	var ins: Dictionary = _battle.get_meta("mobile_insets", {})
	if float(ins.get("right", 0.0)) < 100.0 or float(ins.get("left", 0.0)) > 0.5:
		return "rotation flip did not re-apply insets: %s" % str(ins)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bar: Control = _battle._mobile_bar
	if bar and bar.get_global_rect().end.x > vp.x - 100.0:
		return "command rail sits under the right notch after flip: %s" % str(bar.get_global_rect())
	_battle._cancel_selection()
	BattlePick.focus_cell(_battle, _battle.units[_p].pos)
	await _settle()
	var flip_px := _screen_of(_battle.units[_p].pos)
	if not _battle.get_global_rect().has_point(flip_px) or flip_px.x > vp.x - 200.0:
		return "unit not on-screen after focus: %s" % flip_px
	await _tap(flip_px)
	if _battle.selected != _p:
		return "tap after notch flip missed unit: sel=%s ptc=%s" % [_battle.selected, _battle._pointer_to_cell(flip_px)]
	return ""

func _pure() -> String:
	var r := Rect2(0, 0, 2400, 1080)
	if MobileChrome.safe_changed(r, r):
		return "safe_changed false positive"
	if not MobileChrome.safe_changed(r, Rect2(0, 0, 2280, 1080)):
		return "safe_changed missed width change"
	if not MobileChrome.safe_changed(Rect2(120, 0, 2280, 1080), Rect2(0, 0, 2280, 1080)):
		return "safe_changed missed 180° flip"
	OS.set_environment("CK_SAFE_INSETS", "100,10,30,40")
	var s := DeviceProfile.safe_area(Vector2(2400, 1080))
	OS.set_environment("CK_SAFE_INSETS", "")
	if s != Rect2(100, 10, 2270, 1030):
		return "CK_SAFE_INSETS parse: %s" % str(s)
	var z: Dictionary = BattlePick.zoom_about(Vector2(10, 20), 1.0, 1.5, Vector2(300, 200))
	# Board point under focal before: (300-10, 200-20)/1 → after: pan + p*1.5 must equal focal.
	var p := Vector2(290, 180)
	if (z.pan + p * float(z.zoom)).distance_to(Vector2(300, 200)) > 0.01:
		return "zoom_about drifted focal"
	if float(BattlePick.zoom_about(Vector2.ZERO, 2.0, 9.0, Vector2.ZERO).zoom) != BattlePick.ZOOM_MAX:
		return "zoom_about max clamp"
	if float(BattlePick.zoom_about(Vector2.ZERO, 1.0, 0.01, Vector2.ZERO).zoom) != BattlePick.ZOOM_MIN:
		return "zoom_about min clamp"
	var st := Rect2(8, 52, 900, 660)
	var cp := BattlePick.clamp_pan(Vector2(99999, -99999), 1.0, Vector2(10, 60), Vector2(800, 600), st)
	if absf(cp.x - (st.end.x - BattlePick.PAN_KEEP_PX - 10)) > 0.01:
		return "clamp_pan right bound: %s" % str(cp)
	if absf(cp.y - (st.position.y + BattlePick.PAN_KEEP_PX - 60 - 600)) > 0.01:
		return "clamp_pan top bound: %s" % str(cp)
	return ""

func _bounds() -> String:
	var stage: Rect2 = _battle.get_meta("m_board_area", _battle.BOARD_AREA)
	var z: float = _battle._board_zoom
	var tl: Vector2 = _battle._board_pan + _battle.ORIGIN * z
	var board := Rect2(tl, Vector2(_battle.MAP_W, _battle.MAP_H) * float(_battle.CELL) * z)
	var keep := BattlePick.PAN_KEEP_PX - 0.5
	var inter := board.intersection(stage)
	if inter.size.x < keep or inter.size.y < keep:
		return "pan bounds lost the board: board=%s stage=%s" % [board, stage]
	return ""

func _arrange() -> bool:
	# Opening battle-story barks sit on a full-rect overlay that (rightly) eats taps; not under test.
	var story := _battle.get_node_or_null("BattleStoryLayer")
	if story:
		story.free()
	for i in _battle.units.size():
		var u = _battle.units[i]
		if u.team == "player" and _p < 0:
			_p = i
			u.pos = Vector2i(3, 3)
			u.done = false
		elif u.team == "enemy" and _e < 0:
			_e = i
			u.pos = Vector2i(_battle.MAP_W - 1, 0)
		elif u.team == "player":
			u.pos = Vector2i(0, _battle.MAP_H - 1)
			u.done = true
		else:
			u.char.hp = 0
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	_battle._board_pan = Vector2.ZERO
	_battle._board_zoom = 1.0
	_battle._apply_board_xform()
	GameState.board_input_blocked = false
	return _p >= 0 and _e >= 0

func _legal_dest() -> Vector2i:
	var here: Vector2i = _battle.units[_p].pos
	for c in _battle.move_cells.keys() if _battle.move_cells is Dictionary else _battle.move_cells:
		var cell: Vector2i = c
		if cell != here and (cell - here).length() >= 1.5 and _battle._unit_at(cell) < 0:
			return cell
	return Vector2i(-1, -1)

func _empty_far_cell() -> Vector2i:
	var here: Vector2i = _battle.units[_p].pos
	var best := Vector2i(-1, -1)
	for y in _battle.MAP_H:
		for x in _battle.MAP_W:
			var c := Vector2i(x, y)
			if _battle._unit_at(c) >= 0 or (c - here).length() < 3.0:
				continue
			var s: Vector2 = _screen_of(c)
			if get_viewport().get_visible_rect().grow(-60).has_point(s) and _battle.get_global_rect().has_point(s):
				return c
	return best

func _screen_of(cell: Vector2i) -> Vector2:
	## Board cell centre → viewport px through the real node transforms.
	return _battle._board_xform.get_global_transform() * _battle.cell_to_local(cell)

func _settle() -> void:
	for _i in 4:
		await get_tree().process_frame

func _push(ev: InputEvent) -> void:
	# Positions are viewport (canvas) px; in_local_coords skips the window→viewport stretch.
	get_viewport().push_input(ev, true)

func _touch(i: int, down: bool, pos: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.pressed = down
	e.position = pos
	_push(e)

func _drag_ev(i: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	e.relative = rel
	_push(e)

func _tap(pos: Vector2) -> void:
	_touch(0, true, pos)
	await get_tree().process_frame
	_touch(0, false, pos)
	await _settle()

func _drag(a: Vector2, b: Vector2, release: bool = true) -> void:
	_touch(0, true, a)
	await get_tree().process_frame
	var prev := a
	for k in range(1, 13):
		var p := a.lerp(b, float(k) / 12.0)
		_drag_ev(0, p, p - prev)
		prev = p
		await get_tree().process_frame
	if release:
		_touch(0, false, b)
		await _settle()

func _pinch(c: Vector2, d0: float, d1: float) -> void:
	var ax := Vector2(1, 0)
	_touch(0, true, c - ax * d0 * 0.5)
	_touch(1, true, c + ax * d0 * 0.5)
	await get_tree().process_frame
	for k in range(1, 9):
		var d := lerpf(d0, d1, float(k) / 8.0)
		_drag_ev(0, c - ax * d * 0.5, Vector2.ZERO)
		_drag_ev(1, c + ax * d * 0.5, Vector2.ZERO)
		await get_tree().process_frame
	_touch(1, false, c + ax * d1 * 0.5)
	await get_tree().process_frame
	_touch(0, false, c - ax * d1 * 0.5)
	await _settle()
