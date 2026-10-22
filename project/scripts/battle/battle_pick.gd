class_name BattlePick
extends RefCounted
## Soft hit-test for fat-finger taps. Prefer the nearest living unit when the
## finger lands near a cell edge or slightly off the token.
##
## Y1-A T-P0-2: SOFT_R raised from 0.62 → 0.90 so eccentric fat-finger taps on
## a neighbouring empty cell still resolve to the unit.

## Fraction of a cell: anything closer than this counts as that unit.
const SOFT_R := 0.90


static func nearest_unit_pos(origin: Vector2, cell_px: float, units: Array, local: Vector2, soft_r: float = SOFT_R) -> Vector2i:
	if cell_px < 1.0:
		return Vector2i(-1, -1)
	var best_i := -1
	var best_d2 := (soft_r * cell_px) * (soft_r * cell_px)
	for i in units.size():
		var u = units[i]
		if u.char.hp <= 0:
			continue
		var center: Vector2 = origin + Vector2(u.pos) * cell_px + Vector2(cell_px, cell_px) * 0.5
		var d2: float = center.distance_squared_to(local)
		if d2 <= best_d2:
			best_d2 = d2
			best_i = i
	if best_i >= 0:
		return units[best_i].pos
	return Vector2i(-1, -1)


static func resolve(host, screen_pos: Vector2) -> Vector2i:
	var exact: Vector2i = host._pointer_to_cell(screen_pos)
	if exact.x >= 0 and host._unit_at(exact) >= 0:
		return exact
	var local: Vector2 = _board_local(host, screen_pos)
	var hit: Vector2i = nearest_unit_pos(host.ORIGIN, float(host.CELL), host.units, local)
	if hit.x >= 0:
		return hit
	return exact


## True when a soft-pick would land on a living unit (used by InputRouter sticky_fn).
static func near_living_unit(host, screen_pos: Vector2) -> bool:
	var cell: Vector2i = resolve(host, screen_pos)
	if cell.x < 0:
		return false
	return host._unit_at(cell) >= 0


static func _board_local(host, screen_pos: Vector2) -> Vector2:
	var z: float = host._board_zoom if host._board_zoom > 0.001 else 1.0
	return (host._screen_to_local(screen_pos) - host._board_pan) / z


static func focus_cell(host, cell: Vector2i) -> void:
	if not DeviceProfile.is_mobile():
		return
	if not host._in_bounds(cell):
		return
	var stage: Rect2 = host.get_meta("m_board_area", host.BOARD_AREA)
	var z: float = host._board_zoom if host._board_zoom > 0.001 else 1.0
	var cell_px: float = float(host.CELL) * z
	var origin: Vector2 = host.ORIGIN * z
	var center: Vector2 = origin + Vector2(cell) * cell_px + Vector2(cell_px, cell_px) * 0.5
	# Bias slightly left so the unit sits clear of the right command rail.
	var target: Vector2 = stage.get_center() + Vector2(-stage.size.x * 0.08, 0.0)
	host._board_pan += target - (center + host._board_pan)
	host._clamp_board_pan()
	host._apply_board_xform()


static func focus_selected(host) -> void:
	if host.selected < 0 or host.selected >= host.units.size():
		return
	focus_cell(host, host.units[host.selected].pos)
