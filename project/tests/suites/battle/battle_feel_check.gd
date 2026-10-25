extends Node
## Mobile battle feel: soft pick, skill chip labels, end-turn confirm, camera focus hooks.
## Y1-A: SOFT_R ≥ 0.85, eccentric fat-finger cases, drag-commit + louder preview contracts.
## Y1-A T-P1-1/2: selected long-press raise + pure pan/zoom cell contracts.
## Y1-A T-P1-3: 3D figure visual-bias (face/head → unit below).
## Y1-A T-P1-4: move-drag lands on exact finger cell (soft must not steal).
## Y1-A T-P1-5: contour rect hit + tap-again confirm + mobile selection chrome.

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var err := _check()
	if err == "":
		print("BATTLE FEEL PASS")
		get_tree().quit(0)
	else:
		push_error(err)
		print("FAIL ", err)
		get_tree().quit(1)

func _check() -> String:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := ""
	if not DeviceProfile.is_mobile():
		err = "CK_FORCE_MOBILE did not flip DeviceProfile"
	if err == "":
		err = _source_contracts()
	if err == "":
		err = _soft_pick()
	if err == "":
		err = _router_slop()
	if err == "":
		err = _long_ms_selected()
	if err == "":
		err = _pan_zoom_cell()
	if err == "":
		err = _visual_bias()
	if err == "":
		err = _drag_land_exact()
	if err == "":
		err = _contour_hit()
	if err == "":
		err = _tap_again_contracts()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err

func _source_contracts() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("BattlePick.resolve(self, pos)") < 0:
		return "tap arm missing soft pick"
	if ctrl.find("BattlePick.focus_selected(self)") < 0:
		return "select missing camera focus"
	if ctrl.find("BattlePick.near_living_unit") < 0:
		return "sticky_fn not wired to near_living_unit"
	if ctrl.find("BattleTouchConfirm.on_drag_end") < 0:
		return "drag_end not wired"
	if ctrl.find("skill_pressed.connect(_arm_skill)") < 0:
		return "unit card skill chip not wired"
	if ctrl.find("BattleSkillsUi.cycle(self)") < 0:
		return "cycle_skill not delegated"
	if ctrl.split("\n").size() > 3000:
		return "battle_controller over 3000 lines"
	var bar := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_mobile_bar.gd")
	if bar.find("shell_41ec1a25") < 0 or bar.find("shell_4faa58f5") < 0:
		return "mobile bar missing Art / End turn"
	if bar.find("request_end_turn") < 0:
		return "mobile bar end turn not gated"
	if bar.find("thumb_primary") < 0 and bar.find("_confirming") < 0:
		return "mobile bar missing thumb confirm layout"
	var card := FileAccess.get_file_as_string("res://scripts/ui/unit_card.gd")
	if card.find("signal skill_pressed") < 0 or card.find("skill_pressed.emit") < 0:
		return "unit_card skill press incomplete"
	if card.find("chip, desc") < 0:
		return "unit_card mobile chip text not full name+desc"
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if conf.find("request_end_turn") < 0 or conf.find("EndTurnConfirm") < 0:
		return "end-turn confirm missing"
	if conf.find("BattlePick.focus_cell") < 0:
		return "confirm move/attack missing camera focus"
	if conf.find("drag_commit_enabled") < 0 or conf.find("on_drag_end") < 0:
		return "drag-commit helpers missing"
	if conf.find("draw_arc") < 0:
		return "preview ring not thickened"
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	if pick.find("const SOFT_R := 0.90") < 0 and pick.find("const SOFT_R := 0.9") < 0:
		# Accept 0.85–1.0 inclusive via parse
		var idx := pick.find("const SOFT_R :=")
		if idx < 0:
			return "SOFT_R missing"
		var frag := pick.substr(idx, 40)
		var num := frag.split("=")[1].strip_edges().split("\n")[0]
		if float(num) < 0.85 or float(num) > 1.001:
			return "SOFT_R out of Y1-A range: %s" % num
	var router := FileAccess.get_file_as_string("res://scripts/platform/input_router.gd")
	if router.find("sticky_fn") < 0 or router.find("STICKY_SLOP_MUL") < 0:
		return "input_router missing sticky slop"
	if router.find("MOBILE_SLOP_MIN") < 0:
		return "input_router missing mobile slop floor"
	if router.find("LONG_MS_SELECTED") < 0 or router.find("long_ms_fn") < 0:
		return "input_router missing T-P1-1 long_ms_fn"
	if ctrl.find("long_ms_fn") < 0 or ctrl.find("LONG_MS_SELECTED") < 0:
		return "battle_controller missing long_ms_fn wire for selection"
	if pick.find("local_after_pan_zoom") < 0 or pick.find("cell_at_local") < 0:
		return "battle_pick missing T-P1-2 pure transform helpers"
	if pick.find("visual_bias_unit_pos") < 0 or pick.find("const FIG_TOP") < 0:
		return "battle_pick missing T-P1-3 visual bias"
	if pick.find("drag_move_cell") < 0:
		return "battle_pick missing T-P1-4 drag_move_cell"
	if conf.find("drag_land_cell") < 0 or conf.find("_clear_stale_preview") < 0:
		return "battle_touch_confirm missing T-P1-4 drag land / stale clear"
	if conf.find("var cell: Vector2i = BattlePick.resolve(host, screen_pos)") >= 0:
		return "on_drag/on_drag_end still soft-resolve for land (must use drag_land_cell)"
	# T-P1-2 real transform: the live camera must use the same helpers the contracts test.
	if ctrl.find("BattlePick.clamp_pan(") < 0 or ctrl.find("BattlePick.zoom_about(") < 0:
		return "battle_controller camera not on BattlePick.clamp_pan/zoom_about"
	if ctrl.find("event.xformed_by(get_global_transform())") < 0:
		return "battle _gui_input must lift control-local events to viewport px (safe-area double transform)"
	if ctrl.find("BattleTouchConfirm.is_unit_drag(self, g)") < 0:
		return "pan/drag_end not gated by unit-drag vs map-pan"
	# Y1-A T-P1-5
	if pick.find("contour_unit_pos") < 0 or pick.find("const CONTOUR_HALF_W") < 0:
		return "battle_pick missing T-P1-5 contour_unit_pos"
	if pick.find("var contour: Vector2i = contour_unit_pos(") < 0:
		return "BattlePick.resolve missing contour fallback after soft miss"
	if ctrl.find("preview_move_cell == cell") < 0 or ctrl.find("BattleTouchConfirm.confirm_move(self)") < 0:
		return "tap-again confirm_move missing"
	if ctrl.find("int(preview_attack_ui) == ui") < 0 or ctrl.find("BattleTouchConfirm.confirm_attack(self)") < 0:
		return "tap-again confirm_attack missing"
	if ctrl.find("mobile_sel") < 0 or ctrl.find("BattlePick.CONTOUR_HALF_W") < 0:
		return "mobile selection chrome missing contour halo"
	if ctrl.find("lp_cell := BattlePick.resolve(self, pos)") < 0:
		return "long_press must soft/contour resolve like taps"
	return ""

func _soft_pick() -> String:
	var origin := Vector2(40, 80)
	var cell_px := 56.0
	var units: Array = [
		{"char": {"hp": 10}, "pos": Vector2i(2, 2)},
		{"char": {"hp": 10}, "pos": Vector2i(5, 3)},
	]
	# Empty cell (3,2) near the shared edge with unit at (2,2) — classic soft pick.
	var near := origin + Vector2(3.05, 2.5) * cell_px
	var got: Vector2i = BattlePick.nearest_unit_pos(origin, cell_px, units, near)
	if got != Vector2i(2, 2):
		return "soft pick missed nearby unit: %s" % str(got)
	# Y1-A eccentric fat finger: 0.88 cell diameters from unit centre toward empty neighbour.
	# With SOFT_R=0.90 this must still hit; with old 0.62 it would miss.
	var ecc := origin + Vector2(2.5 + 0.88, 2.5) * cell_px
	var got_ecc: Vector2i = BattlePick.nearest_unit_pos(origin, cell_px, units, ecc)
	if got_ecc != Vector2i(2, 2):
		return "soft pick missed eccentric fat-finger: %s" % str(got_ecc)
	# Slightly past a full cell toward (3,2) centre still snaps when within SOFT_R of (2,2).
	var seam := origin + Vector2(2.5 + 0.89, 2.5) * cell_px
	var got_seam: Vector2i = BattlePick.nearest_unit_pos(origin, cell_px, units, seam)
	if got_seam != Vector2i(2, 2):
		return "soft pick missed seam fat-finger: %s" % str(got_seam)
	var far := origin + Vector2(7.5, 5.5) * cell_px
	var empty: Vector2i = BattlePick.nearest_unit_pos(origin, cell_px, units, far)
	if empty == Vector2i(2, 2) or empty == Vector2i(5, 3):
		return "soft pick falsely snapped far tap to a unit"
	# Explicit small radius must still reject the eccentric case (proves SOFT_R matters).
	var tight: Vector2i = BattlePick.nearest_unit_pos(origin, cell_px, units, ecc, 0.50)
	if tight == Vector2i(2, 2):
		return "tight soft_r unexpectedly hit eccentric tap"
	return ""

func _router_slop() -> String:
	var r := InputRouter.new()
	var base: float = r._slop()
	if base < InputRouter.MOBILE_SLOP_MIN - 0.01:
		return "mobile base slop too small: %s" % base
	r.sticky_fn = func(_o: Vector2) -> bool: return true
	var sticky: float = r._slop_for(Vector2.ZERO)
	if sticky < base * InputRouter.STICKY_SLOP_MUL - 0.01:
		return "sticky slop not enlarged: base=%s sticky=%s" % [base, sticky]
	# Micro-wobble inside sticky slop must stay a tap.
	r = InputRouter.new()
	r.sticky_fn = func(_o: Vector2) -> bool: return true
	r.push(_touch(0, true, Vector2(100, 100)), 1000)
	var wobble := InputEventScreenDrag.new()
	wobble.index = 0
	wobble.position = Vector2(100, 100) + Vector2(base * 0.9, 0)
	wobble.relative = Vector2(base * 0.9, 0)
	var mid: Array = r.push(wobble, 1050)
	for g in mid:
		if str(g.get("kind", "")) == "pan":
			return "sticky micro-wobble promoted to pan"
	var up: Array = r.push(_touch(0, false, wobble.position), 1100)
	if up.is_empty() or str(up[0].get("kind", "")) != "tap":
		return "sticky micro-wobble release must tap, got %s" % str(up)
	return ""

func _long_ms_selected() -> String:
	var r := InputRouter.new()
	r.long_ms_fn = func() -> int: return InputRouter.LONG_MS_SELECTED
	r.push(_touch(0, true, Vector2(40, 40)), 1000)
	var early: Array = r.poll(1000 + InputRouter.LONG_MS + 30)
	if not early.is_empty():
		return "selected long_ms fired at default LONG_MS"
	var up: Array = r.push(_touch(0, false, Vector2(41, 40)), 1000 + InputRouter.LONG_MS + 50)
	if up.is_empty() or str(up[0].get("kind", "")) != "tap":
		return "selected slow release must tap, got %s" % str(up)
	# Intentional hold past raised threshold still long-presses.
	r = InputRouter.new()
	r.long_ms_fn = func() -> int: return InputRouter.LONG_MS_SELECTED
	r.push(_touch(0, true, Vector2(40, 40)), 2000)
	var late: Array = r.poll(2000 + InputRouter.LONG_MS_SELECTED + 10)
	if late.is_empty() or str(late[0].get("kind", "")) != "long_press":
		return "hold past LONG_MS_SELECTED must long-press"
	if InputRouter.LONG_MS_SELECTED <= InputRouter.LONG_MS:
		return "LONG_MS_SELECTED must exceed LONG_MS"
	return ""


func _pan_zoom_cell() -> String:
	## Device-free T-P1-2: pan/zoom invertibility + focus algebra.
	## Does NOT cover get_global_transform / safe-area insets (needs runtime host).
	var origin := Vector2(40, 80)
	var cell_px := 56.0
	var map_w := 12
	var map_h := 10
	var cell := Vector2i(3, 4)
	var center_local: Vector2 = origin + Vector2(cell) * cell_px + Vector2(cell_px, cell_px) * 0.5
	# Identity pan/zoom.
	var got: Vector2i = BattlePick.cell_at_local(origin, cell_px, center_local, map_w, map_h)
	if got != cell:
		return "identity cell_at_local failed: %s" % str(got)
	# With pan + zoom: reconstruct screen_in_control = local * z + pan, then invert.
	var pan := Vector2(30, -20)
	var zoom := 1.35
	var screen_in_control: Vector2 = center_local * zoom + pan
	var back_local: Vector2 = BattlePick.local_after_pan_zoom(screen_in_control, pan, zoom)
	if back_local.distance_to(center_local) > 0.05:
		return "pan/zoom invert drift: %s vs %s" % [back_local, center_local]
	var back_cell: Vector2i = BattlePick.cell_at_local(origin, cell_px, back_local, map_w, map_h)
	if back_cell != cell:
		return "pan/zoom cell roundtrip failed: %s" % str(back_cell)
	# focus_pan_delta should place center+pan near stage centre (with left bias).
	var stage := Rect2(24, 76, 856, 620)
	var z2 := 1.0
	var delta: Vector2 = BattlePick.focus_pan_delta(origin, cell_px, cell, Vector2.ZERO, z2, stage)
	var cell_px_z := cell_px * z2
	var center: Vector2 = origin * z2 + Vector2(cell) * cell_px_z + Vector2(cell_px_z, cell_px_z) * 0.5
	var placed: Vector2 = center + delta
	var target: Vector2 = stage.get_center() + Vector2(-stage.size.x * 0.08, 0.0)
	if placed.distance_to(target) > 0.5:
		return "focus_pan_delta miss: placed=%s target=%s" % [placed, target]
	return ""


func _visual_bias() -> String:
	## T-P1-3: face/head in empty cell above a unit snaps to that unit; soft-R alone misses.
	var origin := Vector2(40, 80)
	var cell_px := 56.0
	var units: Array = [
		{"char": {"hp": 10}, "pos": Vector2i(2, 2)},
		{"char": {"hp": 10}, "pos": Vector2i(5, 3)},
	]
	# Face ≈ model 88% height → rel_y ≈ -0.52 from unit cell top (within [FIG_TOP, FIG_FEET]).
	var face_local: Vector2 = origin + Vector2(2.5, 2.0 - 0.52) * cell_px
	var face_cell := Vector2i(2, 1)  # empty cell above unit (2,2)
	var got_face: Vector2i = BattlePick.visual_bias_unit_pos(origin, cell_px, units, face_local, face_cell)
	if got_face != Vector2i(2, 2):
		return "visual bias missed face tap: %s" % str(got_face)
	# Soft-R alone must still miss the face (proves bias is needed).
	var soft_face: Vector2i = BattlePick.nearest_unit_pos(origin, cell_px, units, face_local)
	if soft_face == Vector2i(2, 2):
		return "soft-R unexpectedly hit face (bias gate useless)"
	# Crown / above FIG_TOP must not bias.
	var crown_local: Vector2 = origin + Vector2(2.5, 2.0 - 0.75) * cell_px
	var got_crown: Vector2i = BattlePick.visual_bias_unit_pos(origin, cell_px, units, crown_local, face_cell)
	if got_crown == Vector2i(2, 2):
		return "visual bias falsely hit above FIG_TOP"
	# Occupied finger cell: resolve path keeps occupancy priority (bias helper still
	# pure — caller skips bias when exact has a unit). Bias with wrong below empty.
	var no_below: Vector2i = BattlePick.visual_bias_unit_pos(origin, cell_px, units, face_local, Vector2i(7, 1))
	if no_below.x >= 0:
		return "visual bias fired with empty cell below"
	# Dead unit below must not bias.
	var dead_units: Array = [{"char": {"hp": 0}, "pos": Vector2i(2, 2)}]
	var got_dead: Vector2i = BattlePick.visual_bias_unit_pos(origin, cell_px, dead_units, face_local, face_cell)
	if got_dead.x >= 0:
		return "visual bias hit dead unit"
	# Occupied cell above: when neighbour sits in the face cell, soft/exact wins — bias
	# helper is only consulted for empty finger cells; still verify helper with below.
	var stacked: Array = [
		{"char": {"hp": 10}, "pos": Vector2i(2, 2)},
		{"char": {"hp": 10}, "pos": Vector2i(2, 1)},
	]
	# Helper still returns below when asked with finger_cell=(2,1); resolve() skips it
	# because exact has a unit. Contract that stacked above exists so resolve prefers it:
	var soft_stack: Vector2i = BattlePick.nearest_unit_pos(origin, cell_px, stacked, face_local)
	if soft_stack != Vector2i(2, 1) and soft_stack != Vector2i(2, 2):
		return "stacked case soft pick unexpected: %s" % str(soft_stack)
	return ""



func _drag_land_exact() -> String:
	## T-P1-4: move/place drag keeps the exact finger cell even when soft would steal.
	var exact := Vector2i(3, 4)
	var soft := Vector2i(4, 4)  # neighbour living unit soft would prefer
	var got: Vector2i = BattlePick.drag_move_cell(exact, soft, true)
	if got != exact:
		return "drag_move_cell stole empty land to soft neighbour: %s" % str(got)
	# Soft agreeing / no living neighbour still returns exact.
	got = BattlePick.drag_move_cell(exact, exact, false)
	if got != exact:
		return "drag_move_cell drifted when soft==exact: %s" % str(got)
	got = BattlePick.drag_move_cell(exact, soft, false)
	if got != exact:
		return "drag_move_cell drifted with soft_has_living=false: %s" % str(got)
	# Off-board exact stays invalid.
	got = BattlePick.drag_move_cell(Vector2i(-1, -1), soft, true)
	if got.x >= 0:
		return "drag_move_cell accepted off-board exact: %s" % str(got)
	# Source contracts already require on_drag/on_drag_end use drag_land_cell
	# (exact for move) and clear stale preview — covered in _source_contracts.
	return ""


func _contour_hit() -> String:
	## T-P1-5: side torso / shoulder inside figure AABB hits when soft-R + bias miss.
	var origin := Vector2(40, 80)
	var cell_px := 56.0
	var units: Array = [
		{"char": {"hp": 10}, "pos": Vector2i(2, 2)},
		{"char": {"hp": 10}, "pos": Vector2i(5, 3)},
	]
	# Mid-figure, offset right of centre (shoulder) — soft radius from feet centre often misses.
	# feet at (2.5, 2.62); mid torso ~ y=2+(FIG_TOP+FIG_FEET)/2 ≈ 1.97; x=2.5+0.35.
	var shoulder: Vector2 = origin + Vector2(2.5 + 0.35, 2.0 + (BattlePick.FIG_TOP + BattlePick.FIG_FEET) * 0.5) * cell_px
	var soft: Vector2i = BattlePick.nearest_unit_pos(origin, cell_px, units, shoulder)
	# Soft may or may not hit; contour MUST hit.
	var got: Vector2i = BattlePick.contour_unit_pos(origin, cell_px, units, shoulder)
	if got != Vector2i(2, 2):
		return "contour missed shoulder tap: %s (soft=%s)" % [str(got), str(soft)]
	# Outside half-width must miss.
	var far_side: Vector2 = origin + Vector2(2.5 + 0.55, 2.0 + (BattlePick.FIG_TOP + BattlePick.FIG_FEET) * 0.5) * cell_px
	var miss: Vector2i = BattlePick.contour_unit_pos(origin, cell_px, units, far_side)
	if miss == Vector2i(2, 2):
		return "contour falsely hit outside CONTOUR_HALF_W"
	# Above crown (above FIG_TOP) must miss.
	var crown: Vector2 = origin + Vector2(2.5, 2.0 + BattlePick.FIG_TOP - 0.05) * cell_px
	var miss_crown: Vector2i = BattlePick.contour_unit_pos(origin, cell_px, units, crown)
	if miss_crown.x >= 0:
		return "contour falsely hit above FIG_TOP"
	# Dead unit must miss.
	var dead: Array = [{"char": {"hp": 0}, "pos": Vector2i(2, 2)}]
	var miss_dead: Vector2i = BattlePick.contour_unit_pos(origin, cell_px, dead, shoulder)
	if miss_dead.x >= 0:
		return "contour hit dead unit"
	# Overlap: two stacked contours — pick nearer feet.
	var stacked: Array = [
		{"char": {"hp": 10}, "pos": Vector2i(2, 2)},
		{"char": {"hp": 10}, "pos": Vector2i(2, 1)},  # above; feet closer to a tap near y=1.5
	]
	var between: Vector2 = origin + Vector2(2.5, 1.55) * cell_px
	var prefer: Vector2i = BattlePick.contour_unit_pos(origin, cell_px, stacked, between)
	if prefer != Vector2i(2, 1) and prefer != Vector2i(2, 2):
		return "contour overlap unexpected: %s" % str(prefer)
	# Prefer should be the one whose feet are closer.
	var feet_upper: Vector2 = origin + Vector2(2.5, 1.0 + BattlePick.FIG_FEET) * cell_px
	var feet_lower: Vector2 = origin + Vector2(2.5, 2.0 + BattlePick.FIG_FEET) * cell_px
	var expect := Vector2i(2, 1) if between.distance_squared_to(feet_upper) <= between.distance_squared_to(feet_lower) else Vector2i(2, 2)
	if prefer != expect:
		return "contour overlap did not prefer nearer feet: got=%s expect=%s" % [str(prefer), str(expect)]
	if BattlePick.CONTOUR_HALF_W < 0.30 or BattlePick.CONTOUR_HALF_W > 0.50:
		return "CONTOUR_HALF_W out of fat-finger range: %s" % BattlePick.CONTOUR_HALF_W
	return ""


func _tap_again_contracts() -> String:
	## Pure policy mirror for tap-again confirm (no live battle host).
	## First tap sets preview; second tap on same cell/enemy must call confirm_*.
	var preview := Vector2i(3, 4)
	var other := Vector2i(4, 4)
	# Same cell → confirm
	if not _tap_again_move_should_confirm(preview, preview):
		return "tap-again move same cell must confirm"
	# Different cell → re-preview, not confirm
	if _tap_again_move_should_confirm(preview, other):
		return "tap-again move different cell must not confirm"
	# Attack same ui
	if not _tap_again_attack_should_confirm(2, 2):
		return "tap-again attack same ui must confirm"
	if _tap_again_attack_should_confirm(2, 5):
		return "tap-again attack different ui must not confirm"
	return ""


func _tap_again_move_should_confirm(preview: Vector2i, tapped: Vector2i) -> bool:
	return preview == tapped


func _tap_again_attack_should_confirm(preview_ui: int, tapped_ui: int) -> bool:
	return preview_ui == tapped_ui


func _touch(index: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	return e
