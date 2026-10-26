class_name BattleTerrainDefAimTelegraph
extends RefCounted
## Y1-A T-P52: when aimed foe stands on cover terrain (def_bonus>0),
## telegraph the ground edge before confirm.

const META := "m_terrain_def_aim_telegraph"
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


static func terrain_id(host) -> String:
	if not active(host):
		return "plain"
	var def = host.units[int(host.preview_attack_ui)]
	var terrain = host.get("terrain")
	if terrain == null or def.pos.y < 0 or def.pos.y >= terrain.size():
		return "plain"
	var row = terrain[def.pos.y]
	if def.pos.x < 0 or def.pos.x >= row.size():
		return "plain"
	return str(row[def.pos.x])


static func def_bonus(host) -> int:
	if not active(host):
		return 0
	var tid := terrain_id(host)
	var info: Dictionary = BattleRules.terrain_info(tid)
	var tmul := 1.0
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	if host.has_method("_combat_extras"):
		var extras: Dictionary = host._combat_extras(ai, di)
		tmul = float(extras.get("terrain_mul", 1.0))
	return int(int(info.get("def_bonus", 0)) * tmul)


static func will_mark(host) -> bool:
	if not active(host):
		return false
	return def_bonus(host) > 0


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
		"tid": terrain_id(host),
		"bonus": def_bonus(host),
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
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 5.0)
	var half_w: float = BattlePick.contour_half_w()
	# Moss cover mark.
	var tone := Color(0.42, 0.78, 0.48)
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
	overlay.draw_rect(marks.body, Color(tone, 0.55 + 0.25 * pulse), false, LINE_W)
	# Ground shelf under cell.
	var b: Rect2 = marks.body
	var y := b.position.y + b.size.y + 2.0
	overlay.draw_line(
		Vector2(b.position.x + 1.0, y),
		Vector2(b.position.x + b.size.x - 1.0, y),
		Color(tone, 0.95 * pulse),
		LINE_W * 1.4,
		true
	)
	var label := Locale.t("shell_terrain_def_aim_mark")
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
