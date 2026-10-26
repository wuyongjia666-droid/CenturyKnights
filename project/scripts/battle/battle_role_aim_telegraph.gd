class_name BattleRoleAimTelegraph
extends RefCounted
## Y1-A T-P56: when aimed strike has a role matchup label, telegraph
## advantage edge before confirm.

const META := "m_role_aim_telegraph"
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


static func role_label(host) -> String:
	if not active(host):
		return ""
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var atk = host.units[ai].char
	var def = host.units[di].char
	return str(BattleRules.role_mods(atk, def).get("label", ""))


static func will_mark(host) -> bool:
	if not active(host):
		return false
	return role_label(host) != ""


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
		"label": role_label(host),
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
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 5.5)
	var half_w: float = BattlePick.contour_half_w()
	# Violet matchup tone.
	var tone := Color(0.78, 0.55, 0.95)
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	overlay.draw_rect(marks.body, Color(tone, 0.55 + 0.25 * pulse), false, LINE_W)
	# Diamond tip above cell.
	var b: Rect2 = marks.body
	var cx := b.position.x + b.size.x * 0.5
	var ty := b.position.y - 2.0
	var tip := Vector2(cx, ty - 5.0)
	var left := Vector2(cx - 5.0, ty)
	var right := Vector2(cx + 5.0, ty)
	var bot := Vector2(cx, ty + 5.0)
	overlay.draw_line(tip, left, Color(tone, 0.95 * pulse), LINE_W, true)
	overlay.draw_line(tip, right, Color(tone, 0.95 * pulse), LINE_W, true)
	overlay.draw_line(bot, left, Color(tone, 0.85 * pulse), LINE_W * 0.9, true)
	overlay.draw_line(bot, right, Color(tone, 0.85 * pulse), LINE_W * 0.9, true)
	var label := Locale.t("shell_role_aim_mark")
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
