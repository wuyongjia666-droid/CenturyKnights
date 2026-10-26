class_name BattleCritAimTelegraph
extends RefCounted
## Y1-A T-P50: when aimed strike crit% is high, telegraph the
## lucky blow before confirm.

const META := "m_crit_aim_telegraph"
const LINE_W := 2.4
const FILL_A := 0.14
const CRIT_MARK := 20


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
	var terrain = host.get("terrain")
	if terrain != null and def.pos.y >= 0 and def.pos.y < terrain.size():
		var row = terrain[def.pos.y]
		if def.pos.x >= 0 and def.pos.x < row.size():
			tid = str(row[def.pos.x])
	var extras := {}
	if host.has_method("_combat_extras"):
		extras = host._combat_extras(ai, di)
	var pv: Dictionary = BattleRules.preview(atk.char, def.char, tid, extras)
	return int(pv.crit)


static func is_crit_mark(host) -> bool:
	if not active(host):
		return false
	return crit_chance(host) >= CRIT_MARK


static func will_mark(host) -> bool:
	return is_crit_mark(host)


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
	if not will_mark(host):
		return
	var di := int(host.preview_attack_ui)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 6.0)
	var half_w: float = BattlePick.contour_half_w()
	# Hot rose crit mark.
	var tone := Color(0.98, 0.35, 0.55)
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	overlay.draw_rect(marks.body, Color(tone, 0.55 + 0.25 * pulse), false, LINE_W)
	# Star spark (two diagonals) at top-right.
	var b: Rect2 = marks.body
	var sx := b.position.x + b.size.x - 2.0
	var sy := b.position.y + 2.0
	overlay.draw_line(Vector2(sx - 5.0, sy - 5.0), Vector2(sx + 5.0, sy + 5.0), Color(tone, 0.95 * pulse), LINE_W, true)
	overlay.draw_line(Vector2(sx - 5.0, sy + 5.0), Vector2(sx + 5.0, sy - 5.0), Color(tone, 0.95 * pulse), LINE_W, true)
	var label := Locale.t("shell_crit_aim_mark")
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
