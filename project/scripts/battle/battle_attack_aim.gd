class_name BattleAttackAim
extends RefCounted
## Y1-A T-P23: entering attack mode frames the nearest in-reach foe and paints
## stronger body chrome on all threatened enemies (tile wash already exists).

const META := "m_attack_aim"
const BODY_FILL_A := 0.22
const LINE_W := 3.5


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
	return true


static func stand_of(host) -> Vector2i:
	if not active(host):
		return Vector2i(-1, -1)
	return host.units[int(host.selected)].pos


static func threatened_indices(host) -> Array[int]:
	var out: Array[int] = []
	var stand := stand_of(host)
	if stand.x < 0:
		return out
	var su = host.units[int(host.selected)]
	var tid := "plain"
	var height := 0
	if host.has_method("_in_bounds") and host._in_bounds(stand):
		tid = str(host.terrain[stand.y][stand.x])
	if host.has_method("_height_at"):
		height = int(host._height_at(stand))
	for i in host.units.size():
		var foe = host.units[i]
		if str(foe.team) != "enemy" or int(foe.char.hp) <= 0:
			continue
		var d: int = absi(foe.pos.x - stand.x) + absi(foe.pos.y - stand.y)
		if BattleRules.in_weapon_range(su.char, d, tid, height):
			out.append(i)
	return out


static func nearest_index(host) -> int:
	var stand := stand_of(host)
	if stand.x < 0:
		return -1
	var best := -1
	var best_d := 9999
	for i in threatened_indices(host):
		var p: Vector2i = host.units[i].pos
		var d: int = absi(p.x - stand.x) + absi(p.y - stand.y)
		if d < best_d or (d == best_d and (best < 0 or i < best)):
			best_d = d
			best = i
	return best


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


## Call right after attack_mode flips true.
static func after_enter(host) -> void:
	if host == null:
		return
	if not active(host):
		clear(host)
		return
	var stand := stand_of(host)
	var idxs: Array[int] = threatened_indices(host)
	if idxs.is_empty():
		clear(host)
		# Still settle on the attacker so the player sees the empty range.
		BattleCombatFrame.follow_cells(host, [stand], 0.0)
		host.set_meta(META, {"stand": stand, "foes": [], "nearest": -1, "msec": Time.get_ticks_msec()})
		return
	var nearest := nearest_index(host)
	var cells: Array = [stand]
	for i in idxs:
		cells.append(host.units[i].pos)
	var applied := BattleCombatFrame.follow_cells(host, cells, BattleCombatFrame.forecast_band(DeviceProfile.is_mobile()))
	var foes: Array[Vector2i] = []
	for i in idxs:
		foes.append(host.units[i].pos)
	host.set_meta(META, {
		"stand": stand,
		"foes": foes,
		"nearest": nearest,
		"delta": applied,
		"msec": Time.get_ticks_msec(),
	})
	if host.overlay:
		host.overlay.queue_redraw()


static func draw(host, overlay) -> void:
	if overlay == null or host == null or not active(host):
		return
	var idxs: Array[int] = threatened_indices(host)
	if idxs.is_empty():
		return
	var nearest := nearest_index(host)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.72 + 0.28 * sin(float(host.get("_sel_pulse")) * 6.0)
	var half_w: float = BattlePick.contour_half_w()
	for i in idxs:
		var cell: Vector2i = host.units[i].pos
		var marks := BattleSelectChrome.chrome_marks(origin, cell_px, cell, half_w, 1.0)
		var tone := UIKit.DANGER
		var thick: float = LINE_W + (1.2 if i == nearest else 0.0)
		var fill_a: float = BODY_FILL_A * pulse * (1.25 if i == nearest else 1.0)
		overlay.draw_arc(marks.mid, float(marks.mid_r) * (1.08 if i == nearest else 1.0), 0.0, TAU, 40, Color(tone, 0.96 * pulse), thick)
		var body: Rect2 = marks.body
		overlay.draw_rect(body, Color(tone, fill_a))
		overlay.draw_rect(body, Color(tone, 0.94 * pulse), false, thick)
