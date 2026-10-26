class_name BattleCounterTelegraph
extends RefCounted
## Y1-A T-P26: when an aimed foe can counter, telegraph retaliate danger
## (attacker chrome + foe chip) and keep both figures framed.

const META := "m_counter_telegraph"
const LINE_W := 3.2
const FILL_A := 0.20


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


static func will_counter(host) -> bool:
	if not active(host):
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var atk = host.units[ai]
	var def = host.units[di]
	var height := 0
	if host.has_method("_height_at"):
		height = int(host._height_at(def.pos))
	return BattleRules.can_counter(atk.char, def.char, atk.pos, def.pos, height)


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


## Call after preview_attack_ui changes (aim / cycle / tap).
static func refresh(host) -> bool:
	if host == null:
		return false
	if not will_counter(host):
		clear(host)
		if host.overlay:
			host.overlay.queue_redraw()
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var stand: Vector2i = host.units[ai].pos
	var foe_pos: Vector2i = host.units[di].pos
	var prev_foe := -1
	if host.has_meta(META):
		prev_foe = int(host.get_meta(META).get("foe", -1))
	host.set_meta(META, {
		"foe": di,
		"stand": stand,
		"foe_pos": foe_pos,
		"msec": Time.get_ticks_msec(),
	})
	# Frame both only when the aimed counter target changes.
	if prev_foe != di:
		BattleCombatFrame.follow_cells(
			host,
			[stand, foe_pos],
			BattleCombatFrame.forecast_band(DeviceProfile.is_mobile())
		)
	if host.overlay:
		host.overlay.queue_redraw()
	return true


static func draw(host, overlay) -> void:
	if overlay == null or host == null:
		return
	if not will_counter(host):
		return
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 5.5)
	var half_w: float = BattlePick.contour_half_w()
	var tone := Color(0.78, 0.42, 0.95)  # retaliate violet
	# Attacker: danger-of-return ring on mid.
	var atk_marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[ai].pos, half_w, 1.0)
	overlay.draw_arc(atk_marks.mid, float(atk_marks.mid_r) * 1.12, 0.0, TAU, 36, Color(tone, 0.95 * pulse), LINE_W)
	var atk_body: Rect2 = atk_marks.body
	overlay.draw_rect(atk_body, Color(tone, FILL_A * pulse))
	overlay.draw_rect(atk_body, Color(tone, 0.90 * pulse), false, LINE_W * 0.85)
	# Defender: retaliate chip wash.
	var def_marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	overlay.draw_arc(def_marks.mid, float(def_marks.mid_r) * 1.06, 0.0, TAU, 36, Color(tone, 0.88 * pulse), LINE_W * 0.9)
	var def_body: Rect2 = def_marks.body
	overlay.draw_rect(def_body, Color(tone, FILL_A * 0.85 * pulse))
	# Tiny "反击" marker above defender mid (mono font).
	var label_pos: Vector2 = def_marks.mid + Vector2(-14.0, -float(def_marks.mid_r) - 10.0)
	overlay.draw_string(UIKit.font("mono"), label_pos, "反击", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(tone, 0.98 * pulse))
