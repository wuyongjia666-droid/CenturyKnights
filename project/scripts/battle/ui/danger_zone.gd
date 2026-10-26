class_name DangerZone
extends RefCounted
## Enemy move ∪ attack cells. Movement uses BattleRules.move_costs, so a ZoC
## tile can be entered and then stops the walk; cells only reachable by
## walking through that tile stay out of the set.
## Y1-A T-P19: collect uses BattleRules.attack_reach / min_range / height so
## long_range and hill bonuses match the painted player attack ring.

static func reach(terrain: Array, origin: Vector2i, move_pts: int, blocked: Array, zoc_sources: Array) -> Dictionary:
	return BattleRules.move_costs(
		terrain, origin, move_pts, blocked, zoc_sources,
		false, 0, BattleRules.LEAVE_COST_DEFAULT, false
	)


static func from_stand(terrain: Array, origin: Vector2i, move_pts: int, blocked: Array, zoc_sources: Array, attack_range: int) -> Dictionary:
	var stands := reach(terrain, origin, move_pts, blocked, zoc_sources)
	var height := terrain.size()
	var width := 0
	if height > 0:
		width = int(terrain[0].size())
	var out := {}
	for stand in stands.keys():
		out[stand] = true
		for dy in range(-attack_range, attack_range + 1):
			for dx in range(-attack_range, attack_range + 1):
				var man := absi(dx) + absi(dy)
				if man < 1 or man > attack_range:
					continue
				var cell: Vector2i = stand + Vector2i(dx, dy)
				if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
					continue
				out[cell] = true
	return out


## Layered wash: stands the foe can occupy vs cells they can only strike.
static func layers_for_unit(host, u) -> Dictionary:
	var blocked: Array = []
	var zoc: Array = []
	for other in host.units:
		if other.char.hp <= 0:
			continue
		if str(other.team) == "enemy":
			if other.pos != u.pos:
				blocked.append(other.pos)
			continue
		blocked.append(other.pos)
		zoc.append(other.pos)
	var stands := reach(host.terrain, u.pos, u.char.derived_move(), blocked, zoc)
	var strike := {}
	var map_w := int(host.MAP_W)
	var map_h := int(host.MAP_H)
	for stand in stands.keys():
		var s: Vector2i = stand
		if s.y < 0 or s.y >= host.terrain.size():
			continue
		var row = host.terrain[s.y]
		if s.x < 0 or s.x >= row.size():
			continue
		var tid := str(row[s.x])
		var h := 0
		if host.has_method("_height_at"):
			h = int(host._height_at(s))
		var reach_n := BattleRules.attack_reach(u.char, tid, h)
		var min_r := BattleRules.min_range(u.char)
		var y0 := maxi(0, s.y - reach_n)
		var y1 := mini(map_h, s.y + reach_n + 1)
		var x0 := maxi(0, s.x - reach_n)
		var x1 := mini(map_w, s.x + reach_n + 1)
		for y in range(y0, y1):
			for x in range(x0, x1):
				var dist := absi(x - s.x) + absi(y - s.y)
				if dist < min_r or dist > reach_n:
					continue
				strike[Vector2i(x, y)] = true
	return {"stands": stands, "strike": strike}


static func from_unit(host, u) -> Dictionary:
	var layers: Dictionary = layers_for_unit(host, u)
	var out: Dictionary = {}
	for cell in layers.stands.keys():
		out[cell] = true
	for cell in layers.strike.keys():
		out[cell] = true
	return out


static func collect(host) -> Dictionary:
	var focus := int(host.danger_focus)
	var out := {}
	for i in host.units.size():
		var u = host.units[i]
		if str(u.team) != "enemy" or u.char.hp <= 0:
			continue
		if focus >= 0 and i != focus:
			continue
		var part := from_unit(host, u)
		for cell in part.keys():
			out[cell] = true
	return out


static func collect_layers(host) -> Dictionary:
	var focus := int(host.danger_focus)
	var stands := {}
	var strike := {}
	for i in host.units.size():
		var u = host.units[i]
		if str(u.team) != "enemy" or u.char.hp <= 0:
			continue
		if focus >= 0 and i != focus:
			continue
		var layers: Dictionary = layers_for_unit(host, u)
		for cell in layers.stands.keys():
			stands[cell] = true
		for cell in layers.strike.keys():
			if not stands.has(cell):
				strike[cell] = true
	return {"stands": stands, "strike": strike}


static func _melee(c: CKCharacter) -> bool:
	return str(GameState.get_job(c.job_id).get("atk_type", "melee")) == "melee"
