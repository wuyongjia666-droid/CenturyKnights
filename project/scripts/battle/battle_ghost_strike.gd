class_name BattleGhostStrike
extends RefCounted
## Y1-A T-P20: move-ghost strike peek + camera.
##
## A latched move ghost still showed attack feedback from the unit's current
## feet. Enemies that would fall under the weapon only after the step stayed
## unmarked, and the camera kept framing the old stand. This helper:
## - lists living enemies inside BattleRules weapon reach from the ghost stand
## - paints mid-ring / body chrome on those figures (tile wash stays elsewhere)
## - settles the camera on ghost + nearest threatened foe without fighting a
##   unit drag (ck_unit_drag)
## BoardInset: refresh m_info_block from MobileSideCol before follow_cells
## so ghost peek shares notch+info+edge (same as ActionSettle / skill follow).


const META := "m_ghost_strike"
const BODY_FILL_A := 0.18
const LINE_W := 3.0


static func stand_of(host) -> Vector2i:
	if host == null:
		return Vector2i(-1, -1)
	if str(host.get("turn_team")) != "player" or bool(host.get("battle_over")):
		return Vector2i(-1, -1)
	var ui := int(host.get("selected"))
	var units = host.get("units")
	if units == null or ui < 0 or ui >= units.size():
		return Vector2i(-1, -1)
	var u = units[ui]
	if str(u.team) != "player" or bool(u.done) or int(u.char.hp) <= 0:
		return Vector2i(-1, -1)
	var ghost: Vector2i = host.preview_move_cell
	if ghost.x < 0:
		return Vector2i(-1, -1)
	return ghost


static func threatened_indices(host) -> Array[int]:
	var out: Array[int] = []
	var stand := stand_of(host)
	if stand.x < 0:
		return out
	var ui := int(host.selected)
	var su = host.units[ui]
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


static func after_preview(host) -> void:
	if host == null:
		return
	if host.has_meta("ck_unit_drag"):
		return
	var stand := stand_of(host)
	if stand.x < 0:
		if host.has_meta(META):
			host.remove_meta(META)
		return
	var foes := threatened_cells(host)
	var cells: Array = [stand]
	for c in foes:
		cells.append(c)
	# Refresh live info column so BoardInset cuts the same chrome as
	# ActionSettle / skill follow (stale m_info_block left figures under the side col).
	_refresh_info_block(host)
	var applied := BattleCombatFrame.follow_cells(host, cells, 0.0)
	host.set_meta(META, {
		"stand": stand,
		"foes": foes,
		"delta": applied,
	})

static func _refresh_info_block(host) -> void:
	if host == null:
		return
	var col := host.get_node_or_null("MobileSideCol") as Control
	if col == null:
		col = host.find_child("MobileSideCol", true, false) as Control
	if col == null:
		col = host.get_node_or_null("SideCol") as Control
	if col != null and col.size.x > 1.0 and col.size.y > 1.0:
		host.set_meta("m_info_block", Rect2(col.position, col.size))

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
		overlay.draw_arc(marks.mid, float(marks.mid_r), 0.0, TAU, 36, Color(tone, 0.92 * pulse), LINE_W)
		var body: Rect2 = marks.body
		overlay.draw_rect(body, Color(tone, BODY_FILL_A * pulse))
		overlay.draw_rect(body, Color(tone, 0.90 * pulse), false, LINE_W)
