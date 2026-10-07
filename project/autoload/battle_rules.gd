extends Node
## 灰旗战棋规则：地形防/回避、夹击、兵种克制、连击、反击、规则透视

const TERRAIN := {
	"plain": {"name": "平地", "move_cost": 1, "avo_bonus": 0, "def_bonus": 0, "color": Color(0.45, 0.55, 0.38)},
	"forest": {"name": "林", "move_cost": 2, "avo_bonus": 15, "def_bonus": 1, "color": Color(0.22, 0.42, 0.28)},
	"hill": {"name": "丘", "move_cost": 2, "avo_bonus": 10, "def_bonus": 2, "color": Color(0.55, 0.48, 0.35)},
	"water": {"name": "水", "move_cost": 3, "avo_bonus": 5, "def_bonus": 0, "color": Color(0.28, 0.45, 0.62)},
	"bridge": {"name": "桥", "move_cost": 1, "avo_bonus": 0, "def_bonus": 0, "color": Color(0.58, 0.48, 0.36)},
	"fort": {"name": "垒", "move_cost": 2, "avo_bonus": 20, "def_bonus": 3, "color": Color(0.50, 0.42, 0.40)},
}

var preview_enabled: bool = true

func terrain_info(tid: String) -> Dictionary:
	return TERRAIN.get(tid, TERRAIN["plain"])

func job_role(job_id: String) -> String:
	var job = GameState.get_job(job_id)
	var at = str(job.get("atk_type", "melee"))
	var mid = str(job.get("id", job_id))
	if mid in ["heavy_inf", "warrior"]:
		return "tank"
	if mid in ["light_cavalry", "squire"]:
		return "cavalry"
	if at == "ranged":
		return "ranger"
	if at == "magic":
		return "mage"
	return "skirmisher"

func role_label(role: String) -> String:
	return {
		"tank": "重装",
		"cavalry": "骑突",
		"ranger": "远射",
		"mage": "秘术",
		"skirmisher": "轻步",
	}.get(role, "步战")

## 兵种克制：命中修正、伤害修正、防御修正（对防守方）
func role_mods(attacker: CKCharacter, defender: CKCharacter) -> Dictionary:
	var ar = job_role(attacker.job_id)
	var dr = job_role(defender.job_id)
	var hit_mod := 0
	var dmg_mod := 0
	var def_mod := 0
	var label := ""
	# 近战压远程（贴身优势）
	if ar in ["skirmisher", "tank", "cavalry"] and dr == "ranger":
		dmg_mod += 2
		label = "近压远"
	# 远程风筝近战
	if ar == "ranger" and dr in ["skirmisher", "cavalry"]:
		hit_mod += 8
		label = "远射克"
	# 秘术破甲（重装）
	if ar == "mage" and dr == "tank":
		dmg_mod += 3
		label = "秘破甲"
	# 重装扛轻骑/轻步
	if dr == "tank" and ar in ["skirmisher", "cavalry"]:
		def_mod += 2
		label = "铁壁承"
	# 骑突撕秘术/轻装
	if ar == "cavalry" and dr in ["mage", "skirmisher"]:
		dmg_mod += 2
		hit_mod += 5
		label = "骑突"
	return {"hit_mod": hit_mod, "dmg_mod": dmg_mod, "def_mod": def_mod, "label": label}

func has_flank(attacker_pos: Vector2i, defender_pos: Vector2i, units: Array, attacker_team: String, attacker_index: int = -1) -> bool:
	for i in units.size():
		if i == attacker_index:
			continue
		var u = units[i]
		if u.team != attacker_team:
			continue
		if u.char.hp <= 0:
			continue
		if _manhattan(u.pos, defender_pos) == 1:
			return true
	return false

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func can_follow_up(attacker: CKCharacter, defender: CKCharacter) -> bool:
	return int(attacker.stats.get("agi", 8)) >= int(defender.stats.get("agi", 8)) + 4

func can_counter(attacker: CKCharacter, defender: CKCharacter, atk_pos: Vector2i, def_pos: Vector2i) -> bool:
	if defender.hp <= 0:
		return false
	var dist = _manhattan(atk_pos, def_pos)
	var djob = GameState.get_job(defender.job_id)
	var at = str(djob.get("atk_type", "melee"))
	if at == "melee":
		return dist == 1
	if at == "ranged" or at == "magic":
		return dist >= 1 and dist <= 2
	return false

func calc_hit(attacker: CKCharacter, defender: CKCharacter, terrain_id: String, extras: Dictionary = {}) -> int:
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
	if extras.get("flank", false):
		hit += 15
	var rm = extras.get("role", role_mods(attacker, defender))
	hit += int(rm.get("hit_mod", 0))
	hit += int(extras.get("hit_mod", 0))
	return clampi(hit - avo, 5, 99)

func calc_damage_range(attacker: CKCharacter, defender: CKCharacter, terrain_id: String = "plain", extras: Dictionary = {}) -> Vector2i:
	var tdef = int(terrain_info(terrain_id).get("def_bonus", 0))
	var rm = extras.get("role", role_mods(attacker, defender))
	var def_eff = defender.derived_def() + tdef + int(rm.get("def_mod", 0))
	var raw = maxi(1, attacker.derived_atk() - int(def_eff / 2.0))
	raw += int(rm.get("dmg_mod", 0))
	if extras.get("flank", false):
		raw += 1
	raw += int(extras.get("dmg_mod", 0))
	return Vector2i(maxi(1, raw - 1), maxi(1, raw + 1))

func roll_attack(attacker: CKCharacter, defender: CKCharacter, terrain_id: String, rng: RandomNumberGenerator, extras: Dictionary = {}) -> Dictionary:
	var rm = role_mods(attacker, defender)
	extras = extras.duplicate()
	extras["role"] = rm
	var hit_chance = calc_hit(attacker, defender, terrain_id, extras)
	var dmg_range = calc_damage_range(attacker, defender, terrain_id, extras)
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
		"flank": bool(extras.get("flank", false)),
		"role_label": str(rm.get("label", "")),
		"terrain_def": int(terrain_info(terrain_id).get("def_bonus", 0)),
	}

func preview(attacker: CKCharacter, defender: CKCharacter, terrain_id: String, extras: Dictionary = {}) -> Dictionary:
	var rm = role_mods(attacker, defender)
	extras = extras.duplicate()
	extras["role"] = rm
	var tags: Array = []
	if extras.get("flank", false):
		tags.append("夹击")
	if str(rm.get("label", "")) != "":
		tags.append(str(rm["label"]))
	var tdef = int(terrain_info(terrain_id).get("def_bonus", 0))
	if tdef > 0:
		tags.append("地形防+%d" % tdef)
	if can_follow_up(attacker, defender):
		tags.append("连击")
	return {
		"hit": calc_hit(attacker, defender, terrain_id, extras),
		"dmg": calc_damage_range(attacker, defender, terrain_id, extras),
		"crit": attacker.derived_crit(),
		"tags": tags,
		"flank": bool(extras.get("flank", false)),
		"follow_up": can_follow_up(attacker, defender),
		"role_label": str(rm.get("label", "")),
	}

## AI 评分用：预估对目标的期望伤害（不掷骰）
func expected_damage(attacker: CKCharacter, defender: CKCharacter, terrain_id: String, extras: Dictionary = {}) -> float:
	var pv = preview(attacker, defender, terrain_id, extras)
	var mid = (pv.dmg.x + pv.dmg.y) * 0.5
	var expect = mid * (pv.hit / 100.0)
	if pv.follow_up:
		expect *= 1.65
	if extras.get("flank", false):
		expect *= 1.1
	return expect

func _is_melee(c: CKCharacter) -> bool:
	var job = GameState.get_job(c.job_id)
	return str(job.get("atk_type", "melee")) == "melee"

## 曼哈顿距离移动范围（含地形耗）
func move_costs(map_terrain: Array, start: Vector2i, move_pts: int) -> Dictionary:
	var h = map_terrain.size()
	var w = map_terrain[0].size() if h > 0 else 0
	var best: Dictionary = {}
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
