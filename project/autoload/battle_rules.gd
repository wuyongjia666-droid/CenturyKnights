extends Node
## 灰旗战棋规则：命中/伤害/地形（含规则透视 X3）

const TERRAIN := {
	"plain": {"name": "平地", "move_cost": 1, "avo_bonus": 0, "color": Color(0.45, 0.55, 0.38)},
	"forest": {"name": "林", "move_cost": 2, "avo_bonus": 15, "color": Color(0.22, 0.42, 0.28)},
	"hill": {"name": "丘", "move_cost": 2, "avo_bonus": 10, "color": Color(0.55, 0.48, 0.35)},
	"water": {"name": "水", "move_cost": 3, "avo_bonus": 5, "color": Color(0.28, 0.45, 0.62)},
	"bridge": {"name": "桥", "move_cost": 1, "avo_bonus": 0, "color": Color(0.58, 0.48, 0.36)},
	"fort": {"name": "垒", "move_cost": 2, "avo_bonus": 20, "color": Color(0.50, 0.42, 0.40)},
}

var preview_enabled: bool = true

func terrain_info(tid: String) -> Dictionary:
	return TERRAIN.get(tid, TERRAIN["plain"])

func calc_hit(attacker: CKCharacter, defender: CKCharacter, terrain_id: String) -> int:
	var hit = attacker.derived_hit()
	var avo = defender.derived_avo() + int(terrain_info(terrain_id).get("avo_bonus", 0))
	if "brave" in attacker.traits and _is_melee(attacker):
		hit += 5
	if "keen_eye" in attacker.traits and not _is_melee(attacker):
		hit += 5
	if "night_owl" in defender.traits and terrain_id == "forest":
		avo += 5
	var level_diff = attacker.level - defender.level
	hit += level_diff * 2
	return clampi(hit - avo, 5, 99)

func calc_damage_range(attacker: CKCharacter, defender: CKCharacter) -> Vector2i:
	var raw = maxi(1, attacker.derived_atk() - int(defender.derived_def() / 2.0))
	return Vector2i(maxi(1, raw - 1), raw + 1)

func roll_attack(attacker: CKCharacter, defender: CKCharacter, terrain_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var hit_chance = calc_hit(attacker, defender, terrain_id)
	var dmg_range = calc_damage_range(attacker, defender)
	var hit = rng.randi_range(1, 100) <= hit_chance
	var crit = false
	var dmg = 0
	if hit:
		dmg = rng.randi_range(dmg_range.x, dmg_range.y)
		if rng.randi_range(1, 100) <= attacker.derived_crit():
			crit = true
			dmg = int(dmg * 1.5)
		defender.hp = maxi(0, defender.hp - dmg)
	return {
		"hit": hit,
		"crit": crit,
		"damage": dmg,
		"hit_chance": hit_chance,
		"dmg_range": dmg_range,
		"killed": defender.hp <= 0,
	}

func preview(attacker: CKCharacter, defender: CKCharacter, terrain_id: String) -> Dictionary:
	return {
		"hit": calc_hit(attacker, defender, terrain_id),
		"dmg": calc_damage_range(attacker, defender),
		"crit": attacker.derived_crit(),
	}

func _is_melee(c: CKCharacter) -> bool:
	var job = GameState.get_job(c.job_id)
	return str(job.get("atk_type", "melee")) == "melee"

## 曼哈顿距离移动范围（简化，含地形耗）
func move_costs(map_terrain: Array, start: Vector2i, move_pts: int) -> Dictionary:
	# map_terrain[y][x] = terrain id
	var h = map_terrain.size()
	var w = map_terrain[0].size() if h > 0 else 0
	var best: Dictionary = {}  # Vector2i -> cost
	var q: Array = [[start, 0]]
	best[start] = 0
	while not q.is_empty():
		var cur = q.pop_front()
		var pos: Vector2i = cur[0]
		var cost: int = cur[1]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var np = pos + d
			if np.x < 0 or np.y < 0 or np.x >= w or np.y >= h:
				continue
			var tid = map_terrain[np.y][np.x]
			var step = int(terrain_info(tid).get("move_cost", 1))
			var nc = cost + step
			if nc > move_pts:
				continue
			if best.has(np) and best[np] <= nc:
				continue
			best[np] = nc
			q.append([np, nc])
	return best
