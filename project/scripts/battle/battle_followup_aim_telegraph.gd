class_name BattleFollowupAimTelegraph
extends RefCounted
## Y1-A T-P48: when attacker can_follow_up on aimed foe, telegraph
## the second strike before confirm.

const META := "m_followup_aim_telegraph"
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


static func is_followup(host) -> bool:
	if not active(host):
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var atk = host.units[ai]
	var def = host.units[di]
	return bool(BattleRules.can_follow_up(atk.char, def.char))


static func will_mark(host) -> bool:
	return is_followup(host)


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
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 5.8)
	var half_w: float = BattlePick.contour_half_w()
	# Violet follow-up mark.
	var tone := Color(0.72, 0.48, 0.98)
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	overlay.draw_rect(marks.body, Color(tone, 0.55 + 0.25 * pulse), false, LINE_W)
	# Twin strike ticks (x2) at top edge.
	var b: Rect2 = marks.body
	var ty := b.position.y - 2.0
	overlay.draw_line(
		Vector2(b.position.x + 4.0, ty),
		Vector2(b.position.x + 10.0, ty - 6.0),
		Color(tone, 0.95 * pulse),
		LINE_W * 1.2,
		true
	)
	overlay.draw_line(
		Vector2(b.position.x + 12.0, ty),
		Vector2(b.position.x + 18.0, ty - 6.0),
		Color(tone, 0.95 * pulse),
		LINE_W * 1.2,
		true
	)
	var label := Locale.t("shell_followup_aim_mark")
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
