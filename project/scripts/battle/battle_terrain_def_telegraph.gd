class_name BattleTerrainDefTelegraph
extends RefCounted
## Y1-A T-P34: when aimed defender stands on terrain with def_bonus,
## telegraph the ground shield so cover is readable before confirm.

const META := "m_terrain_def_telegraph"
const LINE_W := 2.4
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


static func terrain_id(host) -> String:
	if not active(host):
		return "plain"
	var di := int(host.preview_attack_ui)
	var def = host.units[di]
	if host.terrain == null or def.pos.y >= host.terrain.size() or def.pos.x >= host.terrain[def.pos.y].size():
		return "plain"
	return str(host.terrain[def.pos.y][def.pos.x])


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


static func will_cover(host) -> bool:
	if not active(host):
		return false
	return def_bonus(host) > 0


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


static func refresh(host) -> bool:
	if host == null:
		return false
	if not will_cover(host):
		clear(host)
		if host.overlay:
			host.overlay.queue_redraw()
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var prev := -1
	if host.has_meta(META):
		prev = int(host.get_meta(META).get("foe", -1))
	var bonus := def_bonus(host)
	var tid := terrain_id(host)
	host.set_meta(META, {
		"foe": di,
		"stand": host.units[ai].pos,
		"foe_pos": host.units[di].pos,
		"tid": tid,
		"def": bonus,
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
	if not will_cover(host):
		return
	var di := int(host.preview_attack_ui)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 4.8)
	var half_w: float = BattlePick.contour_half_w()
	var tone := Color(0.42, 0.68, 0.48)  # earth cover green
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	var body: Rect2 = marks.body
	overlay.draw_rect(body, Color(tone, FILL_A * pulse))
	# Foot hexagon-ish shield: bottom chevron plate under body.
	var mid: Vector2 = marks.mid
	var foot_y := body.position.y + body.size.y + 2.0
	var hw := body.size.x * 0.42
	var shield := PackedVector2Array([
		Vector2(mid.x - hw, foot_y),
		Vector2(mid.x + hw, foot_y),
		Vector2(mid.x + hw * 0.7, foot_y + 10.0),
		Vector2(mid.x, foot_y + 14.0),
		Vector2(mid.x - hw * 0.7, foot_y + 10.0),
	])
	overlay.draw_colored_polygon(shield, Color(tone, 0.55 * pulse))
	overlay.draw_polyline(shield + PackedVector2Array([shield[0]]), Color(tone, 0.95 * pulse), LINE_W, true)
	var bonus := def_bonus(host)
	var label := "%s +%d" % [Locale.t("shell_terrain_def_mark"), bonus]
	var label_pos: Vector2 = mid + Vector2(-20.0, -float(marks.mid_r) - 14.0)
	overlay.draw_string(
		UIKit.font("mono"),
		label_pos,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(tone, 0.98 * pulse)
	)
