class_name BattleSelectChrome
extends RefCounted
## Y1-A T-P11: selected-unit chrome + landscape info-panel pin.
## Foot disc, mid-figure ring, and body rect share one geometry (chrome_marks)
## so the highlight cannot drift from BattlePick's figure span.
## Kept out of battle_controller (3000-line gate).


## Radii in cells. Larger than the T-P5 rings so the selection reads under a thumb.
const FOOT_R_CELLS := 0.46
const MID_R_CELLS := 0.40
const FOOT_FILL_A := 0.40
const BODY_FILL_A := 0.22
const LINE_W := 3.5


## Pure geometry the drawer and the fail-suite both use.
## foot sits on FIG_FEET, mid on the figure midline, body is the contour AABB.
static func chrome_marks(origin: Vector2, cell_px: float, cell: Vector2i, half_w: float, burst: float) -> Dictionary:
	var b := maxf(burst, 1.0)
	var feet := origin + Vector2(cell) * cell_px + Vector2(cell_px * 0.5, cell_px * BattlePick.FIG_FEET)
	var mid_y := (BattlePick.FIG_TOP + BattlePick.FIG_FEET) * 0.5
	var mid := origin + Vector2(cell) * cell_px + Vector2(cell_px * 0.5, cell_px * mid_y)
	var body := Rect2(
		origin + Vector2(cell) * cell_px + Vector2(cell_px * (0.5 - half_w), cell_px * BattlePick.FIG_TOP),
		Vector2(cell_px * half_w * 2.0, cell_px * (BattlePick.FIG_FEET - BattlePick.FIG_TOP)))
	return {
		"foot": feet,
		"foot_r": cell_px * FOOT_R_CELLS * b,
		"mid": mid,
		"mid_r": cell_px * MID_R_CELLS * b,
		"body": body,
		"foot_fill_a": FOOT_FILL_A,
		"body_fill_a": BODY_FILL_A * b,
		"line_w": LINE_W * b,
	}


static func draw_selected(host, overlay) -> void:
	if overlay == null:
		return
	if host.selected < 0 or host.selected >= host.units.size():
		return
	var u = host.units[host.selected]
	if u.char.hp <= 0:
		return
	var sel_pos: Vector2i = u.pos
	var cell_px := float(host.CELL)
	var cell_c: Vector2 = host.ORIGIN + Vector2(sel_pos) * cell_px + Vector2(cell_px, cell_px) * 0.5 - Vector2(1, 1)
	var mobile_sel := DeviceProfile.is_mobile()
	var rs := cell_px * (1.55 if mobile_sel else 1.32)
	var player := str(u.team) == "player"
	var scol := Color(1, 1, 1, 0.95) if player else Color(1.0, 0.62, 0.62, 0.95)
	if mobile_sel:
		var burst: float = BattlePick.select_burst_scale(host)
		var marks: Dictionary = chrome_marks(host.ORIGIN, cell_px, sel_pos, BattlePick.contour_half_w(), burst)
		var pulse_a := 0.70 + 0.30 * sin(float(host._sel_pulse) * 6.0)
		var tone := UIKit.ACCENT if player else UIKit.DANGER
		overlay.draw_circle(marks.foot, float(marks.foot_r), Color(tone, float(marks.foot_fill_a) * pulse_a))
		overlay.draw_arc(marks.foot, float(marks.foot_r), 0.0, TAU, 40, Color(scol, 0.98), float(marks.line_w))
		overlay.draw_arc(marks.mid, float(marks.mid_r), 0.0, TAU, 40, Color(scol, 0.92), maxf(2.5, float(marks.line_w) - 0.5))
		var body: Rect2 = marks.body
		overlay.draw_rect(body, Color(scol, float(marks.body_fill_a)))
		overlay.draw_rect(body, Color(scol, 0.94), false, float(marks.line_w))
	var sfi := int(float(host._sel_pulse) * 12.0) % 8
	var sp := "res://assets/art/fx/select_dense_%d.png" % sfi
	if ResourceLoader.exists(sp) and host.has_method("_tex"):
		overlay.draw_texture_rect(host._tex(sp), Rect2(cell_c - Vector2(rs, rs) * 0.5, Vector2(rs, rs)), false, scol)


## In-range foe tap on a phone starts the attack preview (second tap confirms).
## Desktop stays on the Attack button / inspect path.
static func mobile_direct_attack(host, su, cell: Vector2i) -> bool:
	if not DeviceProfile.is_mobile():
		return false
	if bool(host.attack_mode):
		return false
	if bool(su.done) or str(su.team) != "player":
		return false
	return bool(host._can_attack_from(su, cell))


## Pin the landscape side column onto the selected-unit card.
static func reveal_landscape(host) -> void:
	if not DeviceProfile.is_mobile():
		return
	if not host.has_method("_mobile_landscape") or not bool(host._mobile_landscape()):
		return
	if host.has_method("is_inside_tree") and not host.is_inside_tree():
		return
	var sc := host.get_node_or_null("MobileSideCol") as ScrollContainer
	var panel: Control = host.get("_unit_panel") as Control
	if sc == null or panel == null:
		return
	_pin_side_scroll.call_deferred(sc, panel)


static func _pin_side_scroll(sc: ScrollContainer, panel: Control) -> void:
	if not is_instance_valid(sc) or not is_instance_valid(panel):
		return
	var y := panel.position.y
	var tries := int(sc.get_meta("_ck_pin_tries", 0))
	if y < 1.0 and panel.get_parent() != null and panel.get_index() > 0 and tries < 4:
		sc.set_meta("_ck_pin_tries", tries + 1)
		_pin_side_scroll.call_deferred(sc, panel)
		return
	sc.set_meta("_ck_pin_tries", 0)
	sc.scroll_vertical = int(maxi(0, int(y) - 4))
