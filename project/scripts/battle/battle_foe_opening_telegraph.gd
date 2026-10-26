class_name BattleFoeOpeningTelegraph
extends RefCounted
## Y1-A T-P41: when aimed foe has not struck yet this battle (extras.foe_opening),
## telegraph soft-target / first-exposure before confirm.

const META := "m_foe_opening_telegraph"
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


static func is_foe_opening(host) -> bool:
	if not active(host):
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var extras := {}
	if host.has_method("_combat_extras"):
		extras = host._combat_extras(ai, di)
	return bool(extras.get("foe_opening", false))


static func will_mark(host) -> bool:
	return is_foe_opening(host)


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
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 5.1)
	var half_w: float = BattlePick.contour_half_w()
	# Cool teal: soft exposure (vs warm opening on self)
	var tone := Color(0.35, 0.85, 0.78)
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	overlay.draw_rect(marks.body, Color(tone, 0.55 + 0.25 * pulse), false, LINE_W)
	var label := Locale.t("shell_foe_opening_mark")
	var font: Font = ThemeDB.fallback_font
	var fs := 13 if DeviceProfile.is_mobile() else 12
	var tp: Vector2 = marks.body.position + Vector2(4.0, -2.0)
	overlay.draw_string(font, tp + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.55))
	overlay.draw_string(font, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(tone, 0.95))
