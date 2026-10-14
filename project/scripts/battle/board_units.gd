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
	l.path_fn = func(u, a: Vector2i, c: Vector2i) -> Array: return path(b, u, a, c)
	l.cell_px_fn = func(cell: Vector2i) -> Vector2: return feet_px(b, cell)
	return l

static func cell_px(b, cell: Vector2i) -> Vector2:
	return b.ORIGIN + Vector2(cell) * b.CELL + Vector2(b.CELL / 2, b.CELL / 2)

## Board-local cell centre → layer-local feet point.
static func feet_px(b, cell: Vector2i) -> Vector2:
	var c: Vector2 = b.ORIGIN + Vector2(cell) * b.CELL + Vector2(b.CELL / 2, b.CELL * 0.62)
	return b._unit_layer.get_global_transform().affine_inverse() * (b.map_draw.get_global_transform() * c)

static func sync(b, delta: float) -> void:
	b._fx_delay = 0.0
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
	var swing := "crit" if result.get("crit", false) else "attack"
	b._fx_delay = l.impact_delay(atk, swing)  # 2D sparks / numbers land on the impact frame
	l.act(atk, swing, cell_px(b, def.pos), cell_px(b, atk.pos))
	l.act(def, "hit" if result.hit else "dodge", cell_px(b, atk.pos), cell_px(b, def.pos), maxf(0.01, b._fx_delay))

## P2: 2D fx anchors lift to the 3D figure (numbers above the head, sparks at the chest).
static func fx_lift(b, cells: float) -> Vector2:
	return Vector2(0, -b.CELL * cells) if b._unit_layer != null else Vector2.ZERO

## P2 damage number: outlined, punch-in scale, larger over 3D figures.
static func draw_dmg_text(b, fx, yoff: float, col: Color, a: float) -> void:
	var k: float = b._k()
	var dfs := int((22 if b._unit_layer != null else 18) * sqrt(k) * (1.0 + 0.35 * clampf(1.0 - fx.age / 0.15, 0.0, 1.0)))
	var at: Vector2 = fx.pos + Vector2(-12, yoff) * k
	b.overlay.draw_string_outline(UIKit.font("bold"), at, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, 5, Color(0.02, 0.02, 0.04, a * 0.9))
	b.overlay.draw_string(UIKit.font("bold"), at, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, col)

## Cells walked from a to b (BFS around terrain blocks and foes; allies may be passed). Excludes a.
static func path(bb, u, a: Vector2i, b: Vector2i) -> Array:
	if a == b:
		return []
	var blocked := {}
	for cell in bb._terrain_blocked():
		blocked[cell] = true
	for o in bb.units:
		if o.char.hp > 0 and str(o.team) != str(u.team):
			blocked[o.pos] = true
	blocked.erase(b)
	var prev := {a: a}
	var q: Array = [a]
	var guard := 0
	while not q.is_empty() and guard < 600:
		guard += 1
		var cur: Vector2i = q.pop_front()
		if cur == b:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + d
			if not bb._in_bounds(nx) or blocked.has(nx) or prev.has(nx):
				continue
			prev[nx] = cur
			q.append(nx)
	if not prev.has(b):
		return [Vector2i(b.x, a.y), b] if a.x != b.x and a.y != b.y else [b]  # knockback / teleport: L-step
	var out: Array = []
	var c := b
	while c != a:
		out.push_front(c)
		c = prev[c]
	return out
