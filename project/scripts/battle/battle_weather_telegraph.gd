class_name BattleWeatherTelegraph
extends RefCounted
## Y1-A T-P38: when aimed strike has weather_hit ≠0 (e.g. rain vs ranged),
## telegraph weather penalty before confirm.

const META := "m_weather_telegraph"
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


static func weather_delta(host) -> int:
	if not active(host):
		return 0
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var extras := {}
	if host.has_method("_combat_extras"):
		extras = host._combat_extras(ai, di)
	return int(extras.get("weather_hit", 0))


static func will_mark(host) -> bool:
	if not active(host):
		return false
	return weather_delta(host) != 0


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
	var delta := weather_delta(host)
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
	var delta := weather_delta(host)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 5.0)
	var half_w: float = BattlePick.contour_half_w()
	var tone := Color(0.42, 0.68, 0.95) if delta < 0 else Color(0.95, 0.85, 0.40)
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[ai].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	var mid: Vector2 = marks.mid
	var r := float(marks.mid_r) * 1.1
	# Rain slash (penalty) or sun disc (bonus).
	if delta < 0:
		overlay.draw_line(mid + Vector2(-r * 0.7, -r * 0.5), mid + Vector2(r * 0.2, r * 0.7), Color(tone, 0.9 * pulse), LINE_W, true)
		overlay.draw_line(mid + Vector2(-r * 0.2, -r * 0.7), mid + Vector2(r * 0.7, r * 0.5), Color(tone, 0.85 * pulse), LINE_W, true)
	else:
		overlay.draw_circle(mid, r * 0.55, Color(tone, 0.45 * pulse))
		overlay.draw_arc(mid, r * 0.55, 0.0, TAU, 24, Color(tone, 0.95 * pulse), LINE_W, true)
	var label := "%s %+d" % [Locale.t("shell_weather_mark"), delta]
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
