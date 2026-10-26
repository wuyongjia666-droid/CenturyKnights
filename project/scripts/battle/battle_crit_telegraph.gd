class_name BattleCritTelegraph
extends RefCounted
## Y1-A T-P31: when aimed strike crit chance is high, telegraph on the
## attacker so a lucky blow is readable before confirm.

const META := "m_crit_telegraph"
const LINE_W := 2.4
const FILL_A := 0.14
const CRIT_MARK := 20  ## inclusive: crit% >= this sparks


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


static func crit_chance(host) -> int:
	if not active(host):
		return 0
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
	return int(pv.crit)


static func will_crit_mark(host) -> bool:
	if not active(host):
		return false
	return crit_chance(host) >= CRIT_MARK


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


static func refresh(host) -> bool:
	if host == null:
		return false
	if not will_crit_mark(host):
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
		"crit": crit_chance(host),
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
	if not will_crit_mark(host):
		return
	var ai := int(host.selected)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 9.0)
	var half_w: float = BattlePick.contour_half_w()
	var tone := Color(1.0, 0.88, 0.35)  # crit spark gold
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[ai].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	# Star-ish: four short rays from mid.
	var mid: Vector2 = marks.mid
	var ray := float(marks.mid_r) * 1.35
	for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
		var tip: Vector2 = mid + Vector2(cos(ang), sin(ang)) * ray
		overlay.draw_line(mid + Vector2(cos(ang), sin(ang)) * (ray * 0.45), tip, Color(tone, 0.95 * pulse), LINE_W)
	overlay.draw_arc(mid, float(marks.mid_r) * 0.55, 0.0, TAU, 20, Color(tone, 0.85 * pulse), LINE_W * 0.8)
	var chance := crit_chance(host)
	var label := "%s %d%%" % [Locale.t("shell_crit_mark"), chance]
	var label_pos: Vector2 = mid + Vector2(-18.0, -float(marks.mid_r) - 16.0)
	overlay.draw_string(
		UIKit.font("mono"),
		label_pos,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(tone, 0.98 * pulse)
	)
