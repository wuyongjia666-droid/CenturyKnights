class_name BattleLethalAimTelegraph
extends RefCounted
## Y1-A T-P45: when aimed foe would die to expected damage, telegraph
## the kill before confirm.

const META := "m_lethal_aim_telegraph"
const LINE_W := 2.6
const FILL_A := 0.16


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


static func is_lethal(host) -> bool:
	if not active(host):
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var atk = host.units[ai]
	var def = host.units[di]
	var tid := "plain"
	var terrain = host.get("terrain")
	if terrain != null and def.pos.y >= 0 and def.pos.y < terrain.size():
		var row = terrain[def.pos.y]
		if def.pos.x >= 0 and def.pos.x < row.size():
			tid = str(row[def.pos.x])
	var extras := {}
	if host.has_method("_combat_extras"):
		extras = host._combat_extras(ai, di)
	var expect := float(BattleRules.expected_damage(atk.char, def.char, tid, extras))
	return expect >= float(def.char.hp)


static func will_mark(host) -> bool:
	return is_lethal(host)


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
	var di := int(host.preview_attack_ui)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.68 + 0.32 * sin(float(host.get("_sel_pulse")) * 6.0)
	var half_w: float = BattlePick.contour_half_w()
	# Blood-gold kill mark.
	var tone := Color(0.98, 0.78, 0.28)
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	overlay.draw_rect(marks.body, Color(tone, 0.60 + 0.28 * pulse), false, LINE_W)
	# Cross slash through body (lethal).
	var b: Rect2 = marks.body
	overlay.draw_line(
		b.position + Vector2(2.0, 2.0),
		b.position + b.size - Vector2(2.0, 2.0),
		Color(tone, 0.92 * pulse),
		LINE_W * 1.1,
		true
	)
	overlay.draw_line(
		b.position + Vector2(b.size.x - 2.0, 2.0),
		b.position + Vector2(2.0, b.size.y - 2.0),
		Color(Color(0.95, 0.35, 0.28), 0.88 * pulse),
		LINE_W,
		true
	)
	var label := Locale.t("shell_lethal_aim_mark")
	var tp: Vector2 = marks.body.position + Vector2(4.0, -2.0)
	overlay.draw_string(
		UIKit.font("mono"),
		tp,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(tone, 0.98 * pulse)
	)
