extends Node
## Mobile battle feel: soft pick, skill chip labels, end-turn confirm, camera focus hooks.
## Y1-A: SOFT_R ≥ 0.85, eccentric fat-finger cases, drag-commit + louder preview contracts.
## Y1-A T-P1-1/2: selected long-press raise + pure pan/zoom cell contracts.
## Y1-A T-P1-3: 3D figure visual-bias (face/head → unit below).
## Y1-A T-P1-4: move-drag lands on exact finger cell (soft must not steal).
## Y1-A T-P1-5: contour rect hit + tap-again confirm + mobile selection chrome.
## Y1-A T-P2: re-tap/empty deselect + mobile-wider contour + select haptic + rail.
## Y1-A T-P3: strict unit-drag vs map-pan + selected sticky + landscape confirm stack.

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
		err = _source_contracts_tp3()
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
	if err == "":
		err = _deselect_contracts()
	if err == "":
		err = _mobile_contour_widen()
	if err == "":
		err = _strict_drag_origin()
	if err == "":
		err = _selected_sticky_policy()
	if err == "":
		err = _landscape_confirm_stack()
	if err == "":
		err = _tp4_focus_follow_juice()
	if err == "":
		err = _tp5_select_feel()
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
	if ctrl.find("mobile_sel") < 0 or ctrl.find("BattlePick.contour_half_w()") < 0:
		return "mobile selection chrome missing contour halo"
	if ctrl.find("lp_cell := BattlePick.resolve(self, pos)") < 0:
		return "long_press must soft/contour resolve like taps"
	# Y1-A T-P2
	if conf.find("try_deselect") < 0:
		return "BattleTouchConfirm.try_deselect missing"
	if ctrl.find("BattleTouchConfirm.try_deselect(self, ui)") < 0:
		return "click_cell missing try_deselect wire"
	if ctrl.find("UIFX.haptic(12)") < 0:
		return "select missing mobile haptic"
	if pick.find("contour_half_w") < 0 or pick.find("CONTOUR_HALF_W_MOBILE") < 0:
		return "battle_pick missing mobile contour widen"
	if ctrl.find("BattlePick.contour_half_w()") < 0:
		return "selection chrome not using contour_half_w"
	if ctrl.find("MOBILE_RAIL_W := 196") < 0:
		return "landscape rail not widened for T-P2"
	if bar.find("0.55") < 0:
		return "landscape confirm thumb zone not lowered"
	return ""

func _source_contracts_tp3() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var bar := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_mobile_bar.gd")
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if bar.find("0.58") < 0:
		return "landscape confirm thumb zone not sunk (T-P3 0.58)"
	if bar.find("landscape_confirm_stack") < 0 or bar.find("ConfirmPrimary") < 0:
		return "landscape confirm stack / named primary missing"
	if bar.find("ConfirmHint") < 0 or bar.find("ux_confirm_dest_move") < 0:
		return "confirm dest hint missing"
	if pick.find("strict_unit_pos") < 0 or pick.find("strict_hits_selected") < 0:
		return "battle_pick missing T-P3 strict unit-drag helpers"
	if pick.find("near_selected_unit") < 0:
		return "battle_pick missing near_selected_unit"
	if ctrl.find("near_selected_unit") < 0:
		return "sticky_fn not narrowed to selected unit (T-P3)"
	if conf.find("strict_hits_selected") < 0:
		return "unit-drag origin not on strict_hits_selected"
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
	if BattlePick.CONTOUR_HALF_W_MOBILE < BattlePick.CONTOUR_HALF_W:
		return "mobile contour must be >= desktop"
	# T-P5: allow ≤0.55 so adjacent figure AABBs overlap; prefer_team stops steal.
	if BattlePick.CONTOUR_HALF_W_MOBILE > 0.55:
		return "mobile contour too wide (steals neighbour): %s" % BattlePick.CONTOUR_HALF_W_MOBILE
	if BattlePick.CONTOUR_HALF_W_MOBILE < 0.50:
		return "mobile contour must be >0.5 so adjacent bodies overlap: %s" % BattlePick.CONTOUR_HALF_W_MOBILE
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



func _deselect_contracts() -> String:
	## Pure policy mirror: re-tap selected OR empty (no preview) must deselect on mobile.
	## Hosts cancel via _cancel_selection; we only assert the boolean gate shape.
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not BattleTouchConfirm.enabled():
		return "touch confirm must enable under CK_FORCE_MOBILE"
	# Fake host with the fields try_deselect reads.
	var host := _FakeBattle.new()
	host.selected = 2
	host.units = [{"team": "player"}, {"team": "player"}, {"team": "player"}]
	host.attack_mode = false
	host.preview_move_cell = Vector2i(-1, -1)
	host.preview_attack_ui = -1
	host.cancelled = false
	if not BattleTouchConfirm.try_deselect(host, 2):
		return "re-tap selected must deselect"
	if not host.cancelled:
		return "re-tap did not call cancel"
	host.cancelled = false
	host.selected = 1
	if not BattleTouchConfirm.try_deselect(host, -1):
		return "empty tap must deselect when no preview"
	if not host.cancelled:
		return "empty deselect did not call cancel"
	host.cancelled = false
	host.selected = 1
	host.preview_move_cell = Vector2i(3, 4)
	if BattleTouchConfirm.try_deselect(host, -1):
		return "empty tap must NOT deselect while preview lives (clear handles it)"
	host.preview_move_cell = Vector2i(-1, -1)
	host.attack_mode = true
	if BattleTouchConfirm.try_deselect(host, -1):
		return "empty tap must NOT deselect in attack mode"
	# Other ally tap is not deselect (caller selects instead).
	host.attack_mode = false
	if BattleTouchConfirm.try_deselect(host, 0):
		return "other-ally tap must not deselect via try_deselect"
	return ""


func _mobile_contour_widen() -> String:
	## Under CK_FORCE_MOBILE, shoulder that misses desktop half-w still hits.
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if abs(BattlePick.contour_half_w() - BattlePick.CONTOUR_HALF_W_MOBILE) > 0.001:
		return "mobile contour_half_w wrong: %s" % BattlePick.contour_half_w()
	var origin := Vector2(40, 80)
	var cell_px := 56.0
	var units: Array = [{"char": {"hp": 10}, "pos": Vector2i(2, 2)}]
	# Just outside desktop 0.42, inside mobile half_w.
	var mid_y: float = 2.0 + (BattlePick.FIG_TOP + BattlePick.FIG_FEET) * 0.5
	var edge: Vector2 = origin + Vector2(2.5 + 0.45, mid_y) * cell_px
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var desk_hit: Vector2i = BattlePick.contour_unit_pos(origin, cell_px, units, edge)
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var mob_hit: Vector2i = BattlePick.contour_unit_pos(origin, cell_px, units, edge)
	if desk_hit == Vector2i(2, 2):
		return "desktop contour unexpectedly hit 0.45 offset (half_w drifted?)"
	if mob_hit != Vector2i(2, 2):
		return "mobile contour missed 0.45 shoulder: %s" % str(mob_hit)
	return ""


func _tp4_focus_follow_juice() -> String:
	## Y1-A T-P4: smooth focus algebra + margin nudge + attack preview juice contracts.
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if pick.find("focus_nudge_delta") < 0 or pick.find("focus_follow_preview") < 0:
		return "battle_pick missing T-P4 focus follow helpers"
	if pick.find("FOCUS_SMOOTH_SEC") < 0 or pick.find("_tween_board_pan") < 0:
		return "battle_pick missing T-P4 smooth focus tween"
	if conf.find("attack_preview_juice") < 0 or conf.find("focus_follow_preview") < 0:
		return "battle_touch_confirm missing T-P4 attack juice / follow wire"
	var origin := Vector2(40, 80)
	var cell_px := 56.0
	var stage := Rect2(24, 76, 400, 300)
	var cell := Vector2i(2, 2)
	# Inside inset → nudge ZERO.
	var mid_pan := BattlePick.focus_pan_delta(origin, cell_px, cell, Vector2.ZERO, 1.0, stage)
	# After full focus, cell is centred; nudge from that pan must be ~0.
	var zero_nudge: Vector2 = BattlePick.focus_nudge_delta(origin, cell_px, cell, mid_pan, 1.0, stage)
	if zero_nudge.length() > 0.5:
		return "nudge after centre focus should be ~0: %s" % zero_nudge
	# Far pan leaves cell off-stage → nudge non-zero and shorter than full re-centre.
	var far_pan := Vector2(800, 0)
	var nudge: Vector2 = BattlePick.focus_nudge_delta(origin, cell_px, cell, far_pan, 1.0, stage)
	var full: Vector2 = BattlePick.focus_pan_delta(origin, cell_px, cell, far_pan, 1.0, stage)
	if nudge.length_squared() < 1.0:
		return "off-stage cell must nudge"
	if nudge.length() > full.length() + 0.01:
		return "nudge must not exceed full focus delta"
	var lerped: Vector2 = BattlePick.focus_pan_lerp(Vector2.ZERO, Vector2(10, 0), 0.5)
	if absf(lerped.x - 5.0) > 0.01:
		return "focus_pan_lerp mid failed: %s" % lerped
	var juice0: Dictionary = BattleTouchConfirm.attack_preview_juice(56.0, 0.0)
	var juice1: Dictionary = BattleTouchConfirm.attack_preview_juice(56.0, 1.0)
	if float(juice1.ring_r) <= float(juice0.ring_r):
		return "attack juice ring must grow with pulse"
	if float(juice1.halo_a) <= float(juice0.halo_a):
		return "attack juice halo alpha must rise with pulse"
	if float(juice0.chev_len) < 1.0 or float(juice0.aim_w) < 1.0:
		return "attack juice missing chevron / aim width"
	return ""


class _FakeBattle:
	var selected: int = -1
	var units: Array = []
	var attack_mode: bool = false
	var preview_move_cell: Vector2i = Vector2i(-1, -1)
	var preview_attack_ui: int = -1
	var cancelled: bool = false
	func _cancel_selection() -> void:
		cancelled = true
		selected = -1

func _tp5_select_feel() -> String:
	## T-P5 contracts: team-prefer soft, select lock, burst stamp via focus_selected.
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var origin := Vector2(0, 0)
	var cell := 40.0
	var units: Array = [
		{"char": {"hp": 8}, "pos": Vector2i(1, 1), "team": "player"},
		{"char": {"hp": 8}, "pos": Vector2i(2, 1), "team": "bandit"},
	]
	var a: Vector2 = origin + Vector2(1, 1) * cell + Vector2(cell, cell) * 0.5
	var b: Vector2 = origin + Vector2(2, 1) * cell + Vector2(cell, cell) * 0.5
	var finger: Vector2 = a.lerp(b, 0.65)
	var hit: Vector2i = BattlePick.nearest_unit_pos(origin, cell, units, finger, BattlePick.SOFT_R, "player")
	if hit != Vector2i(1, 1):
		return "T-P5 scrum prefer player failed"
	var host_burst := {"selected": 0, "units": [{"pos": Vector2i(1, 1), "char": {"hp": 5}}]}
	# Duck as Object via meta on a RefCounted stand-in
	var rc := RefCounted.new()
	rc.set_meta("m_select_burst_msec", Time.get_ticks_msec())
	if not BattlePick.select_lock_active(rc):
		return "T-P5 select_lock_active false at t0"
	if BattlePick.select_burst_scale(rc) <= 1.0:
		return "T-P5 select_burst_scale should exceed 1 at t0"
	var pick_src := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	if pick_src.find("SELECT_LOCK_MSEC") < 0:
		return "T-P5 SELECT_LOCK_MSEC missing"
	var conf_src := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if conf_src.find("select_lock_active") < 0:
		return "T-P5 try_deselect lock missing"
	if conf_src.find("reject_invalid_tap") < 0:
		return "T-P5 invalid-target reject missing"
	if pick_src.find("contour_unit_pos(origin: Vector2, cell_px: float, units: Array, local: Vector2, prefer_team") < 0:
		return "T-P5 contour prefer_team missing"
	return ""


func _touch(index: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	return e


func _strict_drag_origin() -> String:
	## Soft-empty neighbour of selected must NOT arm unit-drag; exact/contour must.
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var host := _FakePickHost.new()
	host.setup_selected_at(Vector2i(2, 2))
	var soft_empty: Vector2 = (host.ORIGIN as Vector2) + Vector2(2.5 + 0.85, 2.5) * float(host.CELL as int)
	if not BattlePick.near_living_unit(host, soft_empty):
		return "soft-empty fixture must soft-hit selected"
	if BattlePick.strict_hits_selected(host, soft_empty, 0):
		return "soft-empty must not strict-hit selected"
	var g_soft := {"kind": "pan", "origin": soft_empty, "pos": soft_empty + Vector2(40, 0),
		"delta": Vector2(40, 0), "multi": false}
	if BattleTouchConfirm.is_unit_drag(host, g_soft):
		return "soft-empty press must not classify as unit-drag"
	BattleTouchConfirm.end_gesture(host)
	var exact := host.screen_at_cell(Vector2i(2, 2))
	if not BattlePick.strict_hits_selected(host, exact, 0):
		return "exact selected must strict-hit"
	var g_exact := {"kind": "pan", "origin": exact, "pos": exact + Vector2(30, 0),
		"delta": Vector2(30, 0), "multi": false}
	if not BattleTouchConfirm.is_unit_drag(host, g_exact):
		return "exact selected press must be unit-drag"
	BattleTouchConfirm.end_gesture(host)
	# Contour shoulder still strict-hits.
	var mid_y: float = 2.0 + (BattlePick.FIG_TOP + BattlePick.FIG_FEET) * 0.5
	var shoulder: Vector2 = (host.ORIGIN as Vector2) + Vector2(2.5 + 0.35, mid_y) * float(host.CELL as int)
	if not BattlePick.strict_hits_selected(host, shoulder, 0):
		return "contour shoulder must strict-hit selected"
	return ""


func _selected_sticky_policy() -> String:
	## While selected, sticky only on selected — other living unit keeps base slop.
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var host := _FakePickHost.new()
	host.setup_selected_at(Vector2i(2, 2))
	host.units.append({"char": {"hp": 10}, "pos": Vector2i(5, 3), "team": "enemy", "done": false})
	var r := InputRouter.new()
	r.sticky_fn = func(o: Vector2) -> bool:
		if host.selected >= 0:
			return BattlePick.near_selected_unit(host, o, host.selected)
		return BattlePick.near_living_unit(host, o)
	var base: float = r._slop()
	var on_sel := host.screen_at_cell(Vector2i(2, 2))
	if r._slop_for(on_sel) < base * InputRouter.STICKY_SLOP_MUL - 0.01:
		return "selected origin must get sticky slop"
	var on_other := host.screen_at_cell(Vector2i(5, 3))
	if r._slop_for(on_other) > base + 0.01:
		return "other-unit press must not sticky while selected"
	if BattlePick.near_selected_unit(host, on_other, 0):
		return "near_selected_unit falsely hit other unit"
	if not BattlePick.near_living_unit(host, on_other):
		return "near_living_unit must still see other unit"
	return ""


func _landscape_confirm_stack() -> String:
	var stack: PackedStringArray = BattleMobileBar.landscape_confirm_stack()
	if stack.size() < 3:
		return "landscape stack too short: %s" % str(stack)
	if str(stack[0]) != "cancel":
		return "landscape Cancel must be top (away from thumb): %s" % str(stack)
	if str(stack[stack.size() - 1]) != "confirm":
		return "landscape Confirm must be thumb-bottom: %s" % str(stack)
	if str(stack[1]) != "hint":
		return "landscape dest hint missing mid-stack: %s" % str(stack)
	var bar := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_mobile_bar.gd")
	if bar.find("maxi(108") < 0 and bar.find("maxi(108,") < 0:
		return "Confirm primary min height ≥108 missing"
	return ""


class _FakePickHost:
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

	func _get(property: StringName) -> Variant:
		# Duck-type battle_controller ORIGIN/CELL for BattlePick without gdlint class-variable-name.
		if property == &"ORIGIN":
			return _board_origin
		if property == &"CELL":
			return _board_cell
		return null

	func setup_selected_at(pos: Vector2i) -> void:
		units = [{"char": {"hp": 10, "name": "Hero"}, "pos": pos, "team": "player", "done": false}]
		selected = 0

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
