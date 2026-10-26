class_name BattleLethalTelegraph
extends RefCounted
## Y1-A T-P29: when aimed strike's floor damage >= foe HP, telegraph lethal
## on the defender so a finishing blow is readable before confirm.

const META := "m_lethal_telegraph"
const LINE_W := 2.8
const FILL_A := 0.22


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


static func floor_damage(host) -> int:
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
	return int(pv.dmg.x)


static func will_lethal(host) -> bool:
	if not active(host):
		return false
	var def = host.units[int(host.preview_attack_ui)]
	return floor_damage(host) >= int(def.char.hp)


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


static func refresh(host) -> bool:
	if host == null:
		return false
	if not will_lethal(host):
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
		"floor": floor_damage(host),
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
	if not will_lethal(host):
		return
	var di := int(host.preview_attack_ui)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 8.0)
	var half_w: float = BattlePick.contour_half_w()
	var tone := Color(0.95, 0.22, 0.28)  # finishing crimson
	var marks := BattleSelectChrome.chrome_marks(origin, cell_px, host.units[di].pos, half_w, 1.0)
	var body: Rect2 = marks.body
	overlay.draw_rect(body, Color(tone, FILL_A * pulse))
	# Cross slash = finishing blow.
	overlay.draw_line(body.position, body.position + body.size, Color(tone, 0.95 * pulse), LINE_W)
	overlay.draw_line(
		body.position + Vector2(body.size.x, 0.0),
		body.position + Vector2(0.0, body.size.y),
		Color(tone, 0.95 * pulse),
		LINE_W
	)
	overlay.draw_arc(marks.mid, float(marks.mid_r) * 1.12, 0.0, TAU, 32, Color(tone, 0.88 * pulse), LINE_W)
	var label_pos: Vector2 = marks.mid + Vector2(-10.0, -float(marks.mid_r) - 14.0)
	overlay.draw_string(
		UIKit.font("mono"),
		label_pos,
		Locale.t("shell_lethal_mark"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color(tone, 0.98 * pulse)
	)
