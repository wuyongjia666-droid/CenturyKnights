extends Node
## Mobile battle feel: soft pick, skill chip labels, end-turn confirm, camera focus hooks.
## Y1-A: SOFT_R ≥ 0.85, eccentric fat-finger cases, drag-commit + louder preview contracts.

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

func _touch(index: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	return e
