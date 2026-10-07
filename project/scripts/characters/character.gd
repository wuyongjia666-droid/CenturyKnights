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
var traits: Array = []  # trait ids
var appearance: Dictionary = {"hair": "ink_black", "eyes": "slate", "brow": "straight", "scar": "none"}

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
var temp_def_buff: int = 0
var temp_hit_bonus: int = 0


const STAT_KEYS := ["str", "vit", "skl", "agi", "per", "wil"]
const RANK_ORDER := ["knight", "baron", "count", "duke"]
const RANK_NAMES := {"knight": "骑士", "baron": "男爵", "count": "伯爵", "duke": "公爵"}

func derived_atk() -> int:
	var job = _job()
	var base = int(job.get("base_atk", 5))
	return base + int(stats.get("str", 8) / 2) + (2 if weapon_id != "" else 0)

func derived_def() -> int:
	var job = _job()
	var base = int(job.get("base_def", 3))
	return base + int(stats.get("vit", 8) / 3) + temp_def_buff

func derived_hit() -> int:
	return 70 + int(stats.get("skl", 8)) + int(stats.get("agi", 8) / 2) + temp_hit_bonus

func derived_avo() -> int:
	return int(stats.get("agi", 8)) + int(stats.get("per", 8) / 2)

func derived_crit() -> int:
	var c = 5 + int(stats.get("skl", 8) / 3)
	if "lucky" in traits:
		c += 3
	return c

func derived_move() -> int:
	return int(_job().get("move", 4))

func recalc_hp() -> void:
	var mod = 1.0
	if "sturdy" in traits:
		mod += 0.08
	max_hp = int((20 + stats.get("vit", 8) * 2 + level * 2) * mod)
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
		"weapon_id": weapon_id, "faction": faction, "skills": skills.duplicate(),
	}

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
	return c
