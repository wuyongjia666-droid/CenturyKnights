class_name BattleLinkTelegraph
extends RefCounted
## Y1-A T-P40: when aimed strike has bond link offers (extras.link_names),
## telegraph partner link before confirm.

const META := "m_link_telegraph"
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


static func link_names(host) -> Array:
	if not active(host):
		return []
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var extras := {}
	if host.has_method("_combat_extras"):
		extras = host._combat_extras(ai, di)
	var names = extras.get("link_names", [])
	return names if names is Array else []


static func will_mark(host) -> bool:
	return not link_names(host).is_empty()


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
	var names := link_names(host)
	host.set_meta(META, {
		"foe": di,
		"stand": host.units[ai].pos,
		"foe_pos": host.units[di].pos,
		"names": names,
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
	var names := link_names(host)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 5.1)
	var half_w: float = BattlePick.contour_half_w()
	var tone := Color(0.95, 0.55, 0.72)
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[ai].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	var mid: Vector2 = marks.mid
	var r := float(marks.mid_r) * 1.1
	# Twin beads (bond link).
	overlay.draw_circle(mid + Vector2(-r * 0.35, 0.0), r * 0.32, Color(tone, 0.55 * pulse))
	overlay.draw_circle(mid + Vector2(r * 0.35, 0.0), r * 0.32, Color(tone, 0.55 * pulse))
	overlay.draw_line(mid + Vector2(-r * 0.35, 0.0), mid + Vector2(r * 0.35, 0.0), Color(tone, 0.95 * pulse), LINE_W, true)
	var partner := str(names[0]) if not names.is_empty() else ""
	var label := "%s %s" % [Locale.t("shell_link_mark"), partner]
	var label_pos: Vector2 = mid + Vector2(-28.0, -float(marks.mid_r) - 14.0)
	overlay.draw_string(
		UIKit.font("mono"),
		label_pos,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(tone, 0.98 * pulse)
	)
