class_name BattleFollowUpTelegraph
extends RefCounted
## Y1-A T-P27: when aimed strike can follow-up (AGI gap), telegraph 追击
## on the attacker so the second hit is readable before confirm.

const META := "m_followup_telegraph"
const LINE_W := 3.0
const FILL_A := 0.18


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


static func will_follow_up(host) -> bool:
	if not active(host):
		return false
	var atk = host.units[int(host.selected)]
	var def = host.units[int(host.preview_attack_ui)]
	return BattleRules.can_follow_up(atk.char, def.char)


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


static func refresh(host) -> bool:
	if host == null:
		return false
	if not will_follow_up(host):
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
	if not will_follow_up(host):
		return
	var ai := int(host.selected)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.72 + 0.28 * sin(float(host.get("_sel_pulse")) * 7.0)
	var half_w: float = BattlePick.contour_half_w()
	var tone := Color(1.0, 0.78, 0.28)  # follow-up gold
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[ai].pos, half_w, 1.0)
	# Double ring = two hits.
	overlay.draw_arc(marks.mid, float(marks.mid_r) * 1.05, 0.0, TAU, 36, Color(tone, 0.92 * pulse), LINE_W)
	overlay.draw_arc(marks.mid, float(marks.mid_r) * 1.22, 0.0, TAU, 36, Color(tone, 0.70 * pulse), LINE_W * 0.75)
	var body: Rect2 = marks.body
	overlay.draw_rect(body, Color(tone, FILL_A * pulse))
	var label_pos: Vector2 = marks.mid + Vector2(-14.0, -float(marks.mid_r) - 12.0)
	overlay.draw_string(UIKit.font("mono"), label_pos, "追击", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(tone, 0.98 * pulse))
