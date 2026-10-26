class_name BattleOpeningTelegraph
extends RefCounted
## Y1-A T-P37: when aimed strike is the attacker's first blow this battle
## (extras.opening), telegraph opening edge before confirm.

const META := "m_opening_telegraph"
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


static func is_opening(host) -> bool:
	if not active(host):
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var extras := {}
	if host.has_method("_combat_extras"):
		extras = host._combat_extras(ai, di)
	return bool(extras.get("opening", false))


static func will_mark(host) -> bool:
	return is_opening(host)


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
	host.set_meta(META, {
		"foe": di,
		"stand": host.units[ai].pos,
		"foe_pos": host.units[di].pos,
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
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 5.4)
	var half_w: float = BattlePick.contour_half_w()
	var tone := Color(0.55, 0.92, 0.78)
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[ai].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	var mid: Vector2 = marks.mid
	var r := float(marks.mid_r) * 1.15
	# Leading wedge (opening / first strike).
	var wedge := PackedVector2Array([
		mid + Vector2(0.0, -r),
		mid + Vector2(r * 0.85, r * 0.55),
		mid + Vector2(-r * 0.85, r * 0.55),
	])
	overlay.draw_colored_polygon(wedge, Color(tone, 0.50 * pulse))
	overlay.draw_polyline(wedge + PackedVector2Array([wedge[0]]), Color(tone, 0.95 * pulse), LINE_W, true)
	var label := Locale.t("shell_opening_mark")
	var label_pos: Vector2 = mid + Vector2(-18.0, -float(marks.mid_r) - 14.0)
	overlay.draw_string(
		UIKit.font("mono"),
		label_pos,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(tone, 0.98 * pulse)
	)
