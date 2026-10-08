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

## Single source for numbers the battle HUD prints. Changing these changes the panel copy.
const LEAVE_COST_DEFAULT := 1
const LEAVE_COST_ENGAGED := 2
const LEAVE_COST_LOCK := 3
const FOLLOW_UP_AGI := 4
const FLANK_HIT := 15
const FLANK_DMG := 1
const HIT_MIN := 5
const HIT_MAX := 99
const CRIT_MULT := 1.5

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
	return int(attacker.stats.get("agi", 8)) >= int(defender.stats.get("agi", 8)) + FOLLOW_UP_AGI

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
	var tmul = float(extras.get("terrain_mul", 1.0))
	var avo = defender.derived_avo() + int(int(terrain_info(terrain_id).get("avo_bonus", 0)) * tmul)
	if "brave" in attacker.traits and _is_melee(attacker):
		hit += 5
	if "keen_eye" in attacker.traits and not _is_melee(attacker):
		hit += 5
	if "night_owl" in defender.traits and terrain_id == "forest":
		avo += 5
	var level_diff = attacker.level - defender.level
	hit += level_diff * 2
	if extras.get("flank", false):
		hit += FLANK_HIT
	var rm = extras.get("role", role_mods(attacker, defender))
	hit += int(rm.get("hit_mod", 0))
	hit += int(extras.get("hit_mod", 0))
	return clampi(hit - avo, HIT_MIN, HIT_MAX)

func calc_damage_range(attacker: CKCharacter, defender: CKCharacter, terrain_id: String = "plain", extras: Dictionary = {}) -> Vector2i:
	var tmul = float(extras.get("terrain_mul", 1.0))
	var tdef = int(int(terrain_info(terrain_id).get("def_bonus", 0)) * tmul) + int(extras.get("flat_def", 0))
	var rm = extras.get("role", role_mods(attacker, defender))
	var def_eff = defender.derived_def() + tdef + int(rm.get("def_mod", 0))
	var raw = maxi(1, attacker.derived_atk() - int(def_eff / 2.0))
	raw += int(rm.get("dmg_mod", 0))
	if extras.get("flank", false):
		raw += FLANK_DMG
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
			dmg = int(dmg * CRIT_MULT)
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
	var tmul = float(extras.get("terrain_mul", 1.0))
	var tdef = int(int(terrain_info(terrain_id).get("def_bonus", 0)) * tmul) + int(extras.get("flat_def", 0))
	if tdef > 0:
		tags.append("地形防+%d" % tdef)
	if tmul > 1.0:
		tags.append("地利")
	if int(extras.get("flat_def", 0)) > 0:
		tags.append("锁垒")
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

## 是否与任一控制源相邻（控制地带 ZoC）
func in_zoc(cell: Vector2i, zoc_sources: Array) -> bool:
	for src in zoc_sources:
		var s: Vector2i = src
		if absi(s.x - cell.x) + absi(s.y - cell.y) == 1:
			return true
	return false

## 移动范围：地形耗 + 敌军阻挡 + 控制地带
## - 进入控带后不可继续穿行（经典 ZoC）
## - 从控带/交战格离开到非控带：额外 leave_zoc_cost（脱离代价）
## - zoc_extra_cost：方阵等强化「入控」额外耗
## leave_free：无视脱离代价（脱离战技）
func move_costs(map_terrain: Array, start: Vector2i, move_pts: int, blocked: Array = [], zoc_sources: Array = [], ignore_zoc: bool = false, zoc_extra_cost: int = 0, leave_zoc_cost: int = 1, leave_free: bool = false) -> Dictionary:
	var h = map_terrain.size()
	var w = map_terrain[0].size() if h > 0 else 0
	var block_set: Dictionary = {}
	for b in blocked:
		block_set[b] = true
	var best: Dictionary = {}
	var q: Array = [[start, 0]]
	best[start] = 0
	var start_engaged = in_zoc(start, zoc_sources)
	while not q.is_empty():
		var cur = q.pop_front()
		var pos: Vector2i = cur[0]
		var cost: int = cur[1]
		# 非起点且已在控带：不可继续扩展（被咬住）
		if not ignore_zoc and pos != start and in_zoc(pos, zoc_sources):
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var np = pos + d
			if np.x < 0 or np.y < 0 or np.x >= w or np.y >= h:
				continue
			if block_set.has(np):
				continue
			var tid = map_terrain[np.y][np.x]
			var step = int(terrain_info(tid).get("move_cost", 1))
			if not ignore_zoc:
				var from_z = in_zoc(pos, zoc_sources) or (pos == start and start_engaged)
				var to_z = in_zoc(np, zoc_sources)
				# 脱离：控带 → 非控带
				if from_z and not to_z and not leave_free and leave_zoc_cost > 0:
					step += leave_zoc_cost
				# 入控额外（方阵锁喉等）
				if to_z and zoc_extra_cost > 0:
					step += zoc_extra_cost
			var nc = cost + step
			if nc > move_pts:
				continue
			if best.has(np) and best[np] <= nc:
				continue
			best[np] = nc
			q.append([np, nc])
	return best

## HUD copy. Numbers come from the leave-cost constants so the panel cannot drift.
## Colors are Frost tokens. BBCode is built at runtime so the source holds no hex literal.
func engagement_note(locked: bool, engaged: bool, leave_free: bool, ignore_zoc: bool) -> String:
	var eng := ""
	if locked:
		eng = _rich(UIKit.DANGER, "〔交战锁定·脱离+%d移·反击优先〕" % LEAVE_COST_LOCK)
	elif engaged:
		eng = _rich(UIKit.DANGER, "〔交战中·脱离+%d移〕" % LEAVE_COST_ENGAGED)
	if leave_free:
		eng += _rich(UIKit.ACCENT, "〔抽身：脱离不耗〕")
	elif ignore_zoc:
		eng += _rich(UIKit.ACCENT, "〔破控：无视地带〕")
	return eng


func _rich(c: Color, body: String) -> String:
	return "[color=#%s]%s[/color]\n" % [c.to_html(false), body]

func leave_cost_for(locked: bool, engaged: bool) -> int:
	if locked:
		return LEAVE_COST_LOCK
	if engaged:
		return LEAVE_COST_ENGAGED
	return LEAVE_COST_DEFAULT

func is_engaged(cell: Vector2i, zoc_sources: Array) -> bool:
	return in_zoc(cell, zoc_sources)

func zoc_cells(map_w: int, map_h: int, zoc_sources: Array) -> Dictionary:
	var out: Dictionary = {}
	for src in zoc_sources:
		var s: Vector2i = src
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var np = s + d
			if np.x < 0 or np.y < 0 or np.x >= map_w or np.y >= map_h:
				continue
			out[np] = true
	return out
