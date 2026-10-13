class_name BattleEscort
extends RefCounted
## Opening review A-01: an ally escort NPC (objective.type == "escort") walks itself toward
## exit_tile before each enemy phase: up to STEP cells, and it holds still while a living enemy
## is within FEAR cells. Once the field is clear it walks the rest of the way at once.

const STEP := 3
const FEAR := 2


static func step(battle: Node) -> int:
	var m: Dictionary = BattleMaps.get_map(str(battle.get("map_id")))
	var obj: Dictionary = m.get("objective", {})
	if str(obj.get("type", "")) != "escort":
		return 0
	var tag := str(obj.get("npc", ""))
	var ex = obj.get("exit_tile", [-1, -1])
	var goal := Vector2i(int(ex[0]), int(ex[1]))
	var units: Array = battle.get("units")
	var npc = null
	for u in units:
		if str(u.get("tag", "")) == tag and u.char.hp > 0:
			npc = u
	if npc == null or npc.pos == goal:
		return 0
	var foes := 0
	for u in units:
		if str(u.team) == "enemy" and u.char.hp > 0:
			foes += 1
			if absi(u.pos.x - npc.pos.x) + absi(u.pos.y - npc.pos.y) <= FEAR:
				battle.call("_log", Locale.t("escort_wait") % npc.char.name)
				return 0
	var path := path_to(battle, npc.pos, goal)
	if path.is_empty():
		return 0
	var n := path.size() if foes == 0 else mini(STEP, path.size())
	npc.pos = path[n - 1]
	battle.call("_log", Locale.t("escort_walk") % npc.char.name)
	return n


static func path_to(battle: Node, from: Vector2i, goal: Vector2i) -> Array:
	var w: int = int(battle.get("MAP_W"))
	var h: int = int(battle.get("MAP_H"))
	var terrain: Array = battle.get("terrain")
	var units: Array = battle.get("units")
	var taken := {}
	for u in units:
		if u.char.hp > 0 and u.pos != from:
			taken[u.pos] = true
	var prev := {from: from}
	var queue: Array = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == goal:
			break
		for d in [Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0)]:
			var nx: Vector2i = c + d
			if nx.x < 0 or nx.y < 0 or nx.x >= w or nx.y >= h or prev.has(nx) or taken.has(nx):
				continue
			if not _walkable(terrain, nx):
				continue
			prev[nx] = c
			queue.append(nx)
	if not prev.has(goal):
		return []
	var out: Array = []
	var cur := goal
	while cur != from:
		out.push_front(cur)
		cur = prev[cur]
	return out


static func _walkable(terrain: Array, c: Vector2i) -> bool:
	if c.y >= terrain.size():
		return true
	var row = terrain[c.y]
	if c.x >= row.size():
		return true
	var t = row[c.x]
	return not (str(t) == "water" or str(t) == "3")


## Bridge-lamp marker on the escort exit cell so the goal is visible on the board.
static func paint(battle: Node, canvas: CanvasItem, origin: Vector2, cell_px: float) -> void:
	var obj: Dictionary = BattleMaps.get_map(str(battle.get("map_id"))).get("objective", {})
	if str(obj.get("type", "")) != "escort" or canvas == null:
		return
	var ex = obj.get("exit_tile", [-1, -1])
	var rect := Rect2(origin + Vector2(float(ex[0]), float(ex[1])) * cell_px, Vector2(cell_px, cell_px))
	var glow := Color(1.0, 0.82, 0.38)
	canvas.draw_rect(rect.grow(-3.0), Color(glow, 0.22))
	canvas.draw_rect(rect.grow(-3.0), Color(glow, 0.9), false, 2.0)
	var c := rect.get_center()
	canvas.draw_line(c + Vector2(0, cell_px * 0.32), c + Vector2(0, -cell_px * 0.12), Color(0.25, 0.2, 0.15), 3.0)
	canvas.draw_circle(c + Vector2(0, -cell_px * 0.2), cell_px * 0.13, glow)
