class_name BattleCounterAimTelegraph
extends RefCounted
## Y1-A T-P47: when aimed foe can counter, telegraph the return
## strike before confirm.

const META := "m_counter_aim_telegraph"
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


static func can_retaliate(host) -> bool:
	if not active(host):
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var atk = host.units[ai]
	var def = host.units[di]
	var h := 0
	if host.has_method("_height_at"):
		h = int(host._height_at(def.pos))
	return bool(BattleRules.can_counter(atk.char, def.char, atk.pos, def.pos, h))


static func will_mark(host) -> bool:
	return can_retaliate(host)


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
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 5.4)
	var half_w: float = BattlePick.contour_half_w()
	# Amber retaliate mark.
	var tone := Color(0.95, 0.62, 0.22)
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	overlay.draw_rect(marks.body, Color(tone, 0.55 + 0.25 * pulse), false, LINE_W)
	# Reverse chevron (foe → attacker hint): two short diagonals at bottom.
	var b: Rect2 = marks.body
	var cx := b.position.x + b.size.x * 0.5
	var by := b.position.y + b.size.y + 2.0
	overlay.draw_line(
		Vector2(cx - 7.0, by - 5.0),
		Vector2(cx, by + 1.0),
		Color(tone, 0.95 * pulse),
		LINE_W * 1.2,
		true
	)
	overlay.draw_line(
		Vector2(cx + 7.0, by - 5.0),
		Vector2(cx, by + 1.0),
		Color(tone, 0.95 * pulse),
		LINE_W * 1.2,
		true
	)
	var label := Locale.t("shell_counter_aim_mark")
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
