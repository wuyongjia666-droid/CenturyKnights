class_name BattleFlankTelegraph
extends RefCounted
## Y1-A T-P32: when aimed strike has flank (ally adjacent to foe), telegraph
## on the defender so the bonus is readable before confirm.

const META := "m_flank_telegraph"
const LINE_W := 2.5
const FILL_A := 0.15


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


static func will_flank(host) -> bool:
	if not active(host):
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var atk = host.units[ai]
	var def = host.units[di]
	return BattleRules.has_flank(atk.pos, def.pos, host.units, str(atk.team), ai)


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


static func refresh(host) -> bool:
	if host == null:
		return false
	if not will_flank(host):
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
	if not will_flank(host):
		return
	var di := int(host.preview_attack_ui)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.72 + 0.28 * sin(float(host.get("_sel_pulse")) * 7.5)
	var half_w: float = BattlePick.contour_half_w()
	var tone := Color(0.35, 0.85, 0.95)  # cyan flank
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	# Twin chevrons = two sides.
	var mid: Vector2 = marks.mid
	var r := float(marks.mid_r)
	for side in [-1.0, 1.0]:
		var a: Vector2 = mid + Vector2(side * r * 0.15, -r * 0.95)
		var b: Vector2 = mid + Vector2(side * r * 1.05, 0.0)
		var c: Vector2 = mid + Vector2(side * r * 0.15, r * 0.95)
		overlay.draw_line(a, b, Color(tone, 0.95 * pulse), LINE_W)
		overlay.draw_line(b, c, Color(tone, 0.95 * pulse), LINE_W)
	var label_pos: Vector2 = mid + Vector2(-14.0, -r - 14.0)
	overlay.draw_string(
		UIKit.font("mono"),
		label_pos,
		Locale.t("shell_flank_mark"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color(tone, 0.98 * pulse)
	)
