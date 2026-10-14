class_name CKBoardUnits
extends RefCounted
## Bridge between the 2D battle controller and the route-C live 3D unit layer
## (CKUnitLayer3D). Kept out of battle_controller.gd (line budget).

static func attach(b) -> CKUnitLayer3D:
	if not CKUnitLayer3D.enabled():
		return null
	var l := CKUnitLayer3D.new()
	l.name = "UnitLayer3D"
	b.add_child(l)
	return l

static func cell_px(b, cell: Vector2i) -> Vector2:
	return b.ORIGIN + Vector2(cell) * b.CELL + Vector2(b.CELL / 2, b.CELL / 2)

## Board-local cell centre → layer-local feet point.
static func feet_px(b, cell: Vector2i) -> Vector2:
	var c: Vector2 = b.ORIGIN + Vector2(cell) * b.CELL + Vector2(b.CELL / 2, b.CELL * 0.62)
	return b._unit_layer.get_global_transform().affine_inverse() * (b.map_draw.get_global_transform() * c)

static func sync(b, delta: float) -> void:
	var cpx: float = float(b.CELL) * b.map_draw.get_global_transform().get_scale().x
	var entries: Array = []
	for u in b.units:
		var vis: bool = not (str(u.team) == "enemy" and not b._players_see(u.pos))
		entries.append({"u": u, "px": feet_px(b, u.pos), "cell_px": cpx, "visible": vis, "cell": u.pos})
	b._unit_layer.sync(entries, delta)

## Faction disc under a live 3D unit. Returns false when there is no 3D layer (draw the token).
static func draw_base(b, center: Vector2, r: float, u) -> bool:
	if b._unit_layer == null:
		return false
	var side := Color(0.36, 0.90, 0.78) if str(u.team) != "enemy" else Color(0.95, 0.36, 0.32)
	var feet: Vector2 = center + Vector2(0, b.CELL * 0.12)
	var pts := PackedVector2Array()
	for a in 29:
		var ang := TAU * a / 28.0
		pts.append(feet + Vector2(cos(ang) * r * 1.05, sin(ang) * r * 0.42))
	var done := bool(u.done)
	b.map_draw.draw_colored_polygon(pts, Color(side, 0.26 if not done else 0.10))
	b.map_draw.draw_polyline(pts, Color(side, 0.95 if not done else 0.40), maxf(1.5, r * 0.09), true)
	return true

static func on_strike(b, atk, def, result: Dictionary) -> void:
	var l: CKUnitLayer3D = b._unit_layer
	l.act(atk, "crit" if result.get("crit", false) else "attack", cell_px(b, def.pos), cell_px(b, atk.pos))
	l.act(def, "hit" if result.hit else "dodge", cell_px(b, atk.pos), cell_px(b, def.pos))
