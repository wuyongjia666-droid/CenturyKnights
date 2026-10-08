class_name DangerZone
extends RefCounted
## Enemy move ∪ attack cells. Movement uses BattleRules.move_costs, so a ZoC
## tile can be entered and then stops the walk; cells only reachable by
## walking through that tile stay out of the set.

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


static func collect(host) -> Dictionary:
	var focus := int(host.danger_focus)
	var out := {}
	for i in host.units.size():
		var u = host.units[i]
		if str(u.team) != "enemy" or u.char.hp <= 0:
			continue
		if focus >= 0 and i != focus:
			continue
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
		var attack_range := 1 if _melee(u.char) else 2
		var part := from_stand(host.terrain, u.pos, u.char.derived_move(), blocked, zoc, attack_range)
		for cell in part.keys():
			out[cell] = true
	return out


static func _melee(c: CKCharacter) -> bool:
	return str(GameState.get_job(c.job_id).get("atk_type", "melee")) == "melee"
