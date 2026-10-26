class_name BattleHeightTelegraph
extends RefCounted
## Y1-A T-P36: when aimed strike has height hit delta, telegraph high/low
## ground so elevation edge is readable before confirm.

const META := "m_height_telegraph"
const LINE_W := 2.4
const FILL_A := 0.14


static func active(host) -> bool:
	if host == null:
		return false
	if str(host.get("turn_team")) != "player" or bool(host.get("battle_over")):
		return false
	if not bool(host.get("attack_mode")):
		return false
	var ui := int(host.get("selected"))
	var units = host.get("units")
	if units == null or ui < 0 or ui >= units.size():
		return false
	var u = units[ui]
	if str(u.team) != "player" or bool(u.done) or int(u.char.hp) <= 0:
		return false
	var foe_i := int(host.get("preview_attack_ui"))
	if foe_i < 0 or foe_i >= units.size():
		return false
	var foe = units[foe_i]
	if str(foe.team) != "enemy" or int(foe.char.hp) <= 0:
		return false
	return true


static func height_delta(host) -> int:
	if not active(host):
		return 0
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var extras := {}
	if host.has_method("_combat_extras"):
		extras = host._combat_extras(ai, di)
	return int(extras.get("height_hit", 0))


static func will_mark(host) -> bool:
	if not active(host):
		return false
	return height_delta(host) != 0


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


static func refresh(host) -> bool:
	if host == null:
		return false
	if not will_mark(host):
		clear(host)
		if host.overlay:
			host.overlay.queue_redraw()
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var prev := -1
	if host.has_meta(META):
		prev = int(host.get_meta(META).get("foe", -1))
	var delta := height_delta(host)
	host.set_meta(META, {
		"foe": di,
		"stand": host.units[ai].pos,
		"foe_pos": host.units[di].pos,
		"delta": delta,
		"msec": Time.get_ticks_msec(),
	})
	if prev != di:
		BattleCombatFrame.follow_cells(
			host,
			[host.units[ai].pos, host.units[di].pos],
			BattleCombatFrame.forecast_band(DeviceProfile.is_mobile())
		)
	if host.overlay:
		host.overlay.queue_redraw()
	return true


static func draw(host, overlay) -> void:
	if overlay == null or host == null:
		return
	if not will_mark(host):
		return
	var ai := int(host.selected)
	var delta := height_delta(host)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 5.2)
	var half_w: float = BattlePick.contour_half_w()
	# High ground on attacker; low ground paints cooler on attacker too.
	var tone := Color(0.95, 0.72, 0.28) if delta > 0 else Color(0.45, 0.62, 0.95)
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[ai].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	var mid: Vector2 = marks.mid
	var r := float(marks.mid_r) * 1.2
	# Chevron up (advantage) or down (disadvantage).
	var tip_y := -r if delta > 0 else r
	var chev := PackedVector2Array([
		mid + Vector2(0.0, tip_y),
		mid + Vector2(-r * 0.7, tip_y * -0.15),
		mid + Vector2(r * 0.7, tip_y * -0.15),
	])
	overlay.draw_colored_polygon(chev, Color(tone, 0.55 * pulse))
	overlay.draw_polyline(chev + PackedVector2Array([chev[0]]), Color(tone, 0.95 * pulse), LINE_W, true)
	var label := ("%s %+d" % [Locale.t("shell_height_high_mark"), delta]) if delta > 0 else ("%s %+d" % [Locale.t("shell_height_low_mark"), delta])
	var label_pos: Vector2 = mid + Vector2(-22.0, -float(marks.mid_r) - 14.0)
	overlay.draw_string(
		UIKit.font("mono"),
		label_pos,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(tone, 0.98 * pulse)
	)
