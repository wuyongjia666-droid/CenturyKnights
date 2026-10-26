class_name BattleLockAimTelegraph
extends RefCounted
## Y1-A T-P43: when aim involves a combat-locked unit (temp_combat_lock>0),
## telegraph the bind on that body before confirm.

const META := "m_lock_aim_telegraph"
const LINE_W := 2.4
const FILL_A := 0.16


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


static func locked_indices(host) -> Array:
	var out: Array = []
	if not active(host):
		return out
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	if int(host.units[ai].char.temp_combat_lock) > 0:
		out.append(ai)
	if int(host.units[di].char.temp_combat_lock) > 0:
		out.append(di)
	return out


static func will_mark(host) -> bool:
	return not locked_indices(host).is_empty()


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


static func refresh(host) -> bool:
	if host == null:
		return false
	var idxs := locked_indices(host)
	if idxs.is_empty():
		clear(host)
		if host.overlay:
			host.overlay.queue_redraw()
		return false
	var ai := int(host.selected)
	var di := int(host.preview_attack_ui)
	var prev := []
	if host.has_meta(META):
		prev = host.get_meta(META).get("idxs", [])
	host.set_meta(META, {
		"idxs": idxs.duplicate(),
		"foe": di,
		"stand": host.units[ai].pos,
		"foe_pos": host.units[di].pos,
		"msec": Time.get_ticks_msec(),
	})
	if prev != idxs:
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
	var idxs := locked_indices(host)
	if idxs.is_empty():
		return
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 5.6)
	var half_w: float = BattlePick.contour_half_w()
	var tone := Color(0.92, 0.35, 0.78)
	var label := Locale.t("shell_lock_aim_mark")
	for ui in idxs:
		var marks := BattleSelectChrome.chrome_marks(
			origin, cell_px, host.units[ui].pos, half_w, 1.0
		)
		overlay.draw_rect(marks.body, Color(tone, FILL_A * pulse))
		overlay.draw_rect(marks.body, Color(tone, 0.55 + 0.25 * pulse), false, LINE_W)
		var mid: Vector2 = marks.mid
		var r := float(marks.mid_r) * 0.95
		# Diamond bind mark.
		var diamond := PackedVector2Array([
			mid + Vector2(0.0, -r),
			mid + Vector2(r, 0.0),
			mid + Vector2(0.0, r),
			mid + Vector2(-r, 0.0),
		])
		overlay.draw_colored_polygon(diamond, Color(tone, 0.40 * pulse))
		overlay.draw_polyline(
			diamond + PackedVector2Array([diamond[0]]),
			Color(tone, 0.95 * pulse),
			LINE_W,
			true
		)
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
