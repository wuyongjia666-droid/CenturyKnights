class_name CKCharacter
extends RefCounted

## 灰烬旗角色数据（可序列化）

var id: String = ""
var name: String = ""
var gender: String = "m"  # m/f
var age: int = 20
var is_leader: bool = false
var is_child: bool = false
var in_roster: bool = true
var alive: bool = true
var retired: bool = false
## v8.6: stable identity for the named cast ("leader", "dengying", "militia_a", "militia_b").
## Portraits / tokens / 3D models key by this — never by name substring (random names collide).
var cast_key: String = ""

# 六维
var stats: Dictionary = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
var apt_min: Dictionary = {}
var apt_max: Dictionary = {}

var job_id: String = "light_inf"
var level: int = 1
var exp: int = 0
var rank: String = "knight"  # knight/baron/count/duke

# 血胤：{bloodline_id: weight}
var blood_mix: Dictionary = {"common_ash": 1.0}
## v8.9 lineage facts the blood % cannot say: exile (diaspora id), pretend ({claimed, true, exposed}), verified.
var blood_meta: Dictionary = {}
var traits: Array = []  # trait ids
var appearance: Dictionary = {"hair": "ink_black", "eyes": "slate", "brow": "straight", "scar": "none"}
## v8.7 genome (CKGenome): diploid loci + polygenic face/body; acquired marks persist for life (not inherited)
var genome: Dictionary = {}
var scars: Array = []  # slots: cheek_l, cheek_r, brow_l, brow_r, chin, neck
var honors: Array = []  # frost_pin (baron), rime_circlet (count), crown_line (duke), titles

var hp: int = 30
var max_hp: int = 30
var injured: bool = false
var salary: int = 8
var spouse_id: String = ""
var parent_ids: Array = []  # [father, mother]
var children_ids: Array = []
var pregnant_months: int = -1  # -1 = not; 0+ = months remaining until birth
var birthday_month: int = 1
var weapon_id: String = ""
var faction: String = "player"  # player/enemy/ally
var skills: Array = []  # skill ids unlocked
var skill_uses: Dictionary = {}  # id -> remaining this battle
var skill_cd: Dictionary = {}  # id -> turns remaining before reusable
var unlocked_skills: Array = []  # tier2+ manually unlocked via skill tree
var temp_def_buff: int = 0
var temp_hit_bonus: int = 0
var temp_crit_bonus: int = 0
var temp_ignore_zoc: bool = false
var temp_leave_free: bool = false  # 本回合脱离不耗额外移力
var temp_combat_lock: int = 0  # 交战锁定剩余回合（攻/受击后）；脱离代价加重，反击优先
var temp_terrain_ward: bool = false  # 占地利：地形加成翻倍
var temp_zoc_aura: int = 0  # 控带额外耗移
var temp_exposed: int = 0  # 被破防，受击时防降低


const STAT_KEYS := ["str", "vit", "skl", "agi", "per", "wil"]
const RANK_ORDER := ["knight", "baron", "viscount", "count", "duke"]
const RANK_NAMES := {"knight": "勋士", "baron": "男爵", "viscount": "子爵", "count": "伯爵", "duke": "侯爵"}

func derived_atk() -> int:
	var job = _job()
	var base = int(job.get("base_atk", 5))
	var wbonus = 0
	if weapon_id == "ash_blade_fine":
		wbonus = 3
	elif weapon_id != "" and not World.is_world_item(weapon_id):
		wbonus = 2
	return base + int(stats.get("str", 8) / 2) + wbonus + World.gear_bonus(self, "atk")

func derived_def() -> int:
	var job = _job()
	var base = int(job.get("base_def", 3))
	return base + int(stats.get("vit", 8) / 3) + temp_def_buff - temp_exposed + World.gear_bonus(self, "def")

func derived_hit() -> int:
	return 70 + int(stats.get("skl", 8)) + int(stats.get("agi", 8) / 2) + temp_hit_bonus + World.gear_bonus(self, "hit")

func derived_avo() -> int:
	return int(stats.get("agi", 8)) + int(stats.get("per", 8) / 2) + World.gear_bonus(self, "avo")

func derived_crit() -> int:
	var c = 5 + int(stats.get("skl", 8) / 3)
	if "lucky" in traits:
		c += 3
	return c + temp_crit_bonus + World.gear_bonus(self, "crit")

func derived_move() -> int:
	return int(_job().get("move", 4)) + World.gear_bonus(self, "move")

func recalc_hp() -> void:
	var mod = 1.0
	if "sturdy" in traits:
		mod += 0.08
	max_hp = int((20 + stats.get("vit", 8) * 2 + level * 2) * mod) + World.gear_bonus(self, "hp")
	hp = mini(hp, max_hp)
	if hp <= 0:
		hp = max_hp

func _job() -> Dictionary:
	return GameState.get_job(job_id)

func rank_index() -> int:
	return RANK_ORDER.find(rank)

func rank_name() -> String:
	return RANK_NAMES.get(rank, rank)

func primary_bloodline() -> String:
	var best := ""
	var best_w := -1.0
	for k in blood_mix.keys():
		if float(blood_mix[k]) > best_w:
			best_w = float(blood_mix[k])
			best = k
	return best

func bloodline_display() -> String:
	var parts: Array = []
	for k in blood_mix.keys():
		var bl = GameState.get_bloodline(k)
		var pct = int(round(float(blood_mix[k]) * 100))
		parts.append("%s %d%%" % [bl.get("name", k), pct])
	return " / ".join(parts)

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "gender": gender, "age": age,
		"is_leader": is_leader, "is_child": is_child, "in_roster": in_roster,
		"alive": alive, "retired": retired, "stats": stats.duplicate(),
		"apt_min": apt_min.duplicate(), "apt_max": apt_max.duplicate(),
		"job_id": job_id, "level": level, "exp": exp, "rank": rank,
		"blood_mix": blood_mix.duplicate(), "traits": traits.duplicate(),
		"appearance": appearance.duplicate(), "hp": hp, "max_hp": max_hp,
		"injured": injured, "salary": salary, "spouse_id": spouse_id,
		"parent_ids": parent_ids.duplicate(), "children_ids": children_ids.duplicate(),
		"pregnant_months": pregnant_months, "birthday_month": birthday_month,
		"weapon_id": weapon_id, "faction": faction, "cast_key": cast_key, "skills": skills.duplicate(), "unlocked_skills": unlocked_skills.duplicate(),
		"genome": genome.duplicate(true), "scars": scars.duplicate(), "honors": honors.duplicate(),
		"blood_meta": blood_meta.duplicate(true),
	}

## v8.7: founders / pre-v8.7 saves get a genome lazily (deterministic per id, keeps the visible legacy look)
func ensure_genome() -> void:
	if not genome.is_empty():
		if not genome.has("sig"):
			CKBloodline.upgrade_genome(self)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id + "|" + name)
	genome = CKGenome.founder(blood_mix, appearance, rng, gender)
	var legacy_scar := str(appearance.get("scar", "none"))
	if scars.is_empty() and legacy_scar in ["cheek", "brow"]:
		scars.append("cheek_l" if legacy_scar == "cheek" else "brow_r")
	CKGenome.sync_appearance(self)

## acquired: battle scar (crit at low HP / survived a fall) - persists, never inherited
func add_scar(rng: RandomNumberGenerator) -> String:
	var slots := ["cheek_l", "cheek_r", "brow_l", "brow_r", "chin", "neck"]
	var free: Array = slots.filter(func(x): return x not in scars)
	if free.is_empty() or scars.size() >= 3:
		return ""
	var s: String = free[rng.randi() % free.size()]
	scars.append(s)
	appearance["scar"] = scars[0]
	return s

static func from_dict(d: Dictionary) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = str(d.get("id", ""))
	c.name = str(d.get("name", ""))
	c.gender = str(d.get("gender", "m"))
	c.age = int(d.get("age", 20))
	c.is_leader = bool(d.get("is_leader", false))
	c.is_child = bool(d.get("is_child", false))
	c.in_roster = bool(d.get("in_roster", true))
	c.alive = bool(d.get("alive", true))
	c.retired = bool(d.get("retired", false))
	c.cast_key = str(d.get("cast_key", ""))
	if c.cast_key == "":
		# migrate pre-v8.6 saves: exact cast identities only (id prefix + exact name), never substrings
		if c.is_leader:
			c.cast_key = "leader"
		elif c.id.begins_with("ally") and c.name == "苇原·灯影":
			c.cast_key = "dengying"
	c.stats = d.get("stats", c.stats).duplicate()
	c.apt_min = d.get("apt_min", {}).duplicate()
	c.apt_max = d.get("apt_max", {}).duplicate()
	c.job_id = str(d.get("job_id", "light_inf"))
	c.level = int(d.get("level", 1))
	c.exp = int(d.get("exp", 0))
	c.rank = str(d.get("rank", "knight"))
	c.blood_mix = d.get("blood_mix", {"common_ash": 1.0}).duplicate()
	c.traits = d.get("traits", []).duplicate()
	c.appearance = d.get("appearance", c.appearance).duplicate()
	c.hp = int(d.get("hp", 30))
	c.max_hp = int(d.get("max_hp", 30))
	c.injured = bool(d.get("injured", false))
	c.salary = int(d.get("salary", 8))
	c.spouse_id = str(d.get("spouse_id", ""))
	c.parent_ids = d.get("parent_ids", []).duplicate()
	c.children_ids = d.get("children_ids", []).duplicate()
	c.pregnant_months = int(d.get("pregnant_months", -1))
	c.birthday_month = int(d.get("birthday_month", 1))
	c.weapon_id = str(d.get("weapon_id", ""))
	c.faction = str(d.get("faction", "player"))
	c.skills = d.get("skills", []).duplicate()
	c.unlocked_skills = d.get("unlocked_skills", []).duplicate()
	c.genome = d.get("genome", {}).duplicate(true)
	c.scars = d.get("scars", []).duplicate()
	c.honors = d.get("honors", []).duplicate()
	c.blood_meta = d.get("blood_meta", {}).duplicate(true)
	return c
