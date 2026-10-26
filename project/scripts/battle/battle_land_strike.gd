class_name BattleLandStrike
extends RefCounted
## Y1-A T-P22: after a confirmed move, peek enemies in weapon reach from the
## landed feet — body chrome + camera frame (tile wash already exists elsewhere).
## Complements T-P20 ghost peek (pre-confirm); this is the post-land handoff.

const META := "m_land_strike"
const BODY_FILL_A := 0.20
const LINE_W := 3.0


static func active(host) -> bool:
	if host == null:
		return false
	if str(host.get("turn_team")) != "player" or bool(host.get("battle_over")):
		return false
	if bool(host.get("attack_mode")):
		return false
	if not bool(host.get("moved_this_select")):
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


static func threatened_cells(host) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in threatened_indices(host):
		cells.append(host.units[i].pos)
	return cells


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


## Call after confirm_move has landed the unit (moved_this_select true).
static func after_land(host) -> void:
	if host == null:
		return
	if host.has_meta("ck_unit_drag"):
		return
	var stand := stand_of(host)
	if stand.x < 0:
		clear(host)
		return
	var foes := threatened_cells(host)
	if foes.is_empty():
		clear(host)
		return
	var cells: Array = [stand]
	for c in foes:
		cells.append(c)
	var applied := BattleCombatFrame.follow_cells(host, cells, 0.0)
	host.set_meta(META, {
		"stand": stand,
		"foes": foes,
		"delta": applied,
		"msec": Time.get_ticks_msec(),
	})
	if host.overlay:
		host.overlay.queue_redraw()


static func draw(host, overlay) -> void:
	if overlay == null or host == null:
		return
	var stand := stand_of(host)
	if stand.x < 0:
		return
	var foes := threatened_cells(host)
	if foes.is_empty():
		return
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.70 + 0.30 * sin(float(host.get("_sel_pulse")) * 5.5)
	var half_w: float = BattlePick.contour_half_w()
	for cell in foes:
		var marks := BattleSelectChrome.chrome_marks(origin, cell_px, cell, half_w, 1.0)
		var tone := UIKit.DANGER
		overlay.draw_arc(marks.mid, float(marks.mid_r) * 1.05, 0.0, TAU, 36, Color(tone, 0.95 * pulse), LINE_W)
		var body: Rect2 = marks.body
		overlay.draw_rect(body, Color(tone, BODY_FILL_A * pulse))
		overlay.draw_rect(body, Color(tone, 0.92 * pulse), false, LINE_W)
