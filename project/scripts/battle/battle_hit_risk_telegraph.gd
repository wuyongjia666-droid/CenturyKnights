class_name BattleHitRiskTelegraph
extends RefCounted
## Y1-A T-P30: when aimed strike hit chance is low, telegraph risk on the
## defender so a bad trade is readable before confirm.

const META := "m_hit_risk_telegraph"
const LINE_W := 2.6
const FILL_A := 0.16
const RISK_HIT := 50  ## inclusive: hit% <= this is risky


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


static func hit_chance(host) -> int:
	if not active(host):
		return 100
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var atk = host.units[ai]
	var def = host.units[di]
	var tid := "plain"
	if host.terrain != null and def.pos.y < host.terrain.size() and def.pos.x < host.terrain[def.pos.y].size():
		tid = str(host.terrain[def.pos.y][def.pos.x])
	var extras := {}
	if host.has_method("_combat_extras"):
		extras = host._combat_extras(ai, di)
	var pv: Dictionary = BattleRules.preview(atk.char, def.char, tid, extras)
	return int(pv.hit)


static func will_risk(host) -> bool:
	if not active(host):
		return false
	return hit_chance(host) <= RISK_HIT


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


static func refresh(host) -> bool:
	if host == null:
		return false
	if not will_risk(host):
		clear(host)
		if host.overlay:
			host.overlay.queue_redraw()
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var prev := -1
	if host.has_meta(META):
		prev = int(host.get_meta(META).get("foe", -1))
	var chance := hit_chance(host)
	host.set_meta(META, {
		"foe": di,
		"stand": host.units[ai].pos,
		"foe_pos": host.units[di].pos,
		"hit": chance,
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
	if not will_risk(host):
		return
	var di := int(host.preview_attack_ui)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.68 + 0.32 * sin(float(host.get("_sel_pulse")) * 6.5)
	var half_w: float = BattlePick.contour_half_w()
	var tone := Color(1.0, 0.62, 0.18)  # amber risk
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	var body: Rect2 = marks.body
	overlay.draw_rect(body, Color(tone, FILL_A * pulse))
	# Dashed-feel ring via two arcs with gap (simple: thinner outer).
	overlay.draw_arc(marks.mid, float(marks.mid_r) * 1.18, 0.15, PI - 0.15, 20, Color(tone, 0.90 * pulse), LINE_W)
	overlay.draw_arc(marks.mid, float(marks.mid_r) * 1.18, PI + 0.15, TAU - 0.15, 20, Color(tone, 0.90 * pulse), LINE_W)
	var chance := hit_chance(host)
	var label := "%s %d%%" % [Locale.t("shell_hit_risk_mark"), chance]
	var label_pos: Vector2 = marks.mid + Vector2(-22.0, -float(marks.mid_r) - 14.0)
	overlay.draw_string(
		UIKit.font("mono"),
		label_pos,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(tone, 0.98 * pulse)
	)
