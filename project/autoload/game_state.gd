extends Node
## 全局状态：资源、人物、第零章旗标、存档

signal state_changed
signal log_added(text: String)

const _StoryStateScript = preload("res://scripts/core/story_state.gd")
var rng := RandomNumberGenerator.new()
var story = _StoryStateScript.new()

const _EconomyScript = preload("res://scripts/company/economy_state.gd")
const _LoadoutScript = preload("res://scripts/battle/enemy_loadout.gd")
const _FamilyScript = preload("res://scripts/characters/family_state.gd")
const HOLDING_DEFS = _EconomyScript.HOLDING_DEFS
const BUILDING_NAMES = _EconomyScript.BUILDING_NAMES
const BUILDING_MAX = _EconomyScript.BUILDING_MAX
const BUILDING_COST = _EconomyScript.BUILDING_COST

# 数据缓存
var data_bloodlines: Dictionary = {}
var data_traits: Dictionary = {}
var data_jobs: Dictionary = {}
var data_names: Dictionary = {}
var data_appearance: Dictionary = {}
var data_maps: Dictionary = {}
var data_enemy_skills: Dictionary = {}
var data_rivals: Dictionary = {}
var rival_stances: Dictionary = {}  # house_id -> stance override
var rival_deals: Dictionary = {}  # house_id -> {turns_left, kind, reward}
var data_skills: Dictionary = {}
var last_deal_events: Array = []
var skill_points: int = 0

# 游戏状态
var started: bool = false
var surname: String = "灰旗"
var crest_color: String = "#c9a227"
var silver: int = 120
var food: int = 40
var iron: int = 5
var herb: int = 3
var morale: int = 70
var characters: Dictionary = {}  # id -> CKCharacter
var tavern_candidates: Array = []
var marriage_candidates: Array = []
var quests: Array = []
var event_log: Array = []
var settings: Dictionary = {
	"rules_preview": true,
	"text_speed": 1.0,
	"tutorial_highlight": true,
	"reduced_motion": false,
}
# 诸邦声望 0-100；档位由数值映射
var reputation: Dictionary = {"ashland": 0, "riverland": 0}
var shrine_level: int = 1
## 城堡工事等级（厅堂/校场/市集/工坊/祠堂）——经营深度核心
var buildings: Dictionary = {"hall": 1, "barracks": 1, "market": 1, "forge": 1, "shrine": 1}
## 联姻/岁月留下的家族修正（持久机械后果）
var house_mods: Dictionary = {}
## 已完成委任（首通奖励只发一次）
var quest_done: Dictionary = {}
## 退役顾问加成：{stat_key: bonus}
var advisor_bonus: Dictionary = {}
var ambition_done: Dictionary = {}  # 堡志中长期目标
## 属地/庄园（单堡多属地经营感）
var holdings: Dictionary = {}  # id -> {level, steward_id, focus, focus_cd}
var caravan: Dictionary = {}  # {kind, turns_left, invested} 陆桥商队
var alliance_duty_months: int = 0  # 联姻义役剩余月
var doctrine_months: int = 0
var estate_quiet_months: int = 0  # 连续无劫掠月数
var patrol_cooldown: int = 0  # 全堡巡防冷却（月）
var patrol_boost_months: int = 0  # 主动巡防抗劫剩余月
var deploy_ids: Array = []
var dirty: bool = false
var dynasty_journal: String = ""
var lineage_log: Array = []  # deeper marriage/lineage event strings
var lineage_path: Dictionary = {}  # child_id -> "martial"|"scholar"|"merchant"

const SAVE_PATH := "user://century_knights_save.json"
const SAVE_SCHEMA := "v9.1"
const REP_TIERS := [
	{"id": "none", "min": 0},
	{"id": "known", "min": 10},
	{"id": "friendly", "min": 30},
	{"id": "trusted", "min": 55},
	{"id": "respected", "min": 80},
]

func _ready() -> void:
	rng.randomize()
	_load_data()
	BattleRules.preview_enabled = settings.get("rules_preview", true)
	CKGenomePortrait.set_bloodline_clause_hook(Callable(CKBloodline, "portrait_clause"))

func _exit_tree() -> void:
	# static hooks must not outlive the engine's script teardown
	CKGenomePortrait.set_bloodline_clause_hook(Callable())
	CKBloodline.people.clear()

## Legacy chapter fields stay addressable for the 235 chapter scripts.
func _get(property: StringName):
	var parsed: Dictionary = _story_prop(String(property))
	if parsed.is_empty():
		return null
	if parsed["kind"] == "flags":
		return story.flags
	if parsed["kind"] == "data":
		return story.chapter_data(int(parsed["id"]))
	return story.beat(int(parsed["id"]))

func _set(property: StringName, value) -> bool:
	var parsed: Dictionary = _story_prop(String(property))
	if parsed.is_empty():
		return false
	if parsed["kind"] == "flags":
		story.flags = value.duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
		return true
	if parsed["kind"] == "data":
		story.set_chapter_data(int(parsed["id"]), value)
		return true
	story.set_beat(int(parsed["id"]), str(value))
	return true

func _story_prop(key: String) -> Dictionary:
	if key == "chapter0_flags":
		return {"kind": "flags"}
	if key.begins_with("data_chapter"):
		var num := key.substr(12)
		if num.is_valid_int():
			var id := int(num)
			if id >= 0 and id < CKStoryState.CHAPTER_COUNT:
				return {"kind": "data", "id": id}
		return {}
	if key.begins_with("chapter") and key.ends_with("_beat"):
		var num := key.substr(7, key.length() - 12)
		if num.is_valid_int():
			var id := int(num)
			if id >= 0 and id < CKStoryState.CHAPTER_COUNT:
				return {"kind": "beat", "id": id}
	return {}


func _load_data() -> void:
	# v8.9: the 31 nation lines are canonical; the v8.7 file only fills ids the v89 data lacks
	data_bloodlines = _read_json("res://data/bloodlines.json")
	var v89: Array = _read_json("res://data/bloodlines_v89.json").get("lines", [])
	if not v89.is_empty():
		var have := {}
		for b in v89:
			have[str(b.get("id", ""))] = true
		for b in data_bloodlines.get("bloodlines", []):
			if not have.has(str(b.get("id", ""))):
				v89.append(b)
		data_bloodlines = {"bloodlines": v89}
	data_traits = _read_json("res://data/traits.json")
	data_jobs = _read_json("res://data/jobs.json")
	data_names = _read_json("res://data/names.json")
	data_appearance = _read_json("res://data/appearance.json")
	data_maps = _read_json("res://data/maps.json")
	data_enemy_skills = _read_json("res://data/enemy_skill_tables.json")
	data_rivals = _read_json("res://data/rival_houses.json")
	data_skills = _read_json("res://data/skills.json")

func _read_json(path: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Missing data: " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func get_bloodline(id: String) -> Dictionary:
	for b in data_bloodlines.get("bloodlines", []):
		if b.get("id") == id:
			return b
	return {"id": id, "name": id, "stat_min": {}, "stat_max": {}}

func get_trait(id: String) -> Dictionary:
	for t in data_traits.get("traits", []):
		if t.get("id") == id:
			return t
	return {"id": id, "name": id}

func get_job(id: String) -> Dictionary:
	for j in data_jobs.get("jobs", []):
		if j.get("id") == id:
			return j
	return {"id": id, "name": id, "base_atk": 5, "base_def": 3, "move": 4}

func get_leader() -> CKCharacter:
	for c in characters.values():
		if c.is_leader:
			return c
	return null

func roster() -> Array:
	var out: Array = []
	for c in characters.values():
		if c.alive and c.in_roster and not c.retired:
			out.append(c)
	return out


func mark_dirty() -> void:
	dirty = true
	state_changed.emit()

func log_event(text: String) -> void:
	event_log.append("[%s] %s" % [Calendar.label(), text])
	if event_log.size() > 80:
		event_log = event_log.slice(event_log.size() - 80)
	log_added.emit(text)

func get_rep_tier(realm: String) -> String:
	var v = int(reputation.get(realm, 0))
	var tier = "none"
	for t in REP_TIERS:
		if v >= int(t["min"]):
			tier = t["id"]
	return tier

func get_rep_name(realm: String) -> String:
	return Lineage.REP_NAMES.get(get_rep_tier(realm), "?")

func add_rep(realm: String, amount: int) -> void:
	reputation[realm] = clampi(int(reputation.get(realm, 0)) + amount, 0, 100)

func new_game(leader_given: String, leader_surname: String, color: String) -> void:
	started = true
	Calendar.reset()
	silver = 120
	food = 40
	iron = 5
	herb = 3
	morale = 70
	characters.clear()
	story.reset()
	rival_stances = {"shuoying": "hostile", "qinghe": "wary", "lantern": "neutral"}
	rival_deals.clear()
	skill_points = 1
	event_log.clear()
	dynasty_journal = ""
	lineage_log.clear()
	lineage_path.clear()
	reputation = {"ashland": 0, "riverland": 0}
	buildings = {"hall": 1, "barracks": 1, "market": 1, "forge": 1, "shrine": 1}
	shrine_level = 1
	house_mods = {}
	quest_done = {}
	advisor_bonus = {}
	ambition_done = {}
	holdings = {}
	caravan = {}
	alliance_duty_months = 0
	doctrine_months = 0
	estate_quiet_months = 0
	patrol_cooldown = 0
	patrol_boost_months = 0
	surname = leader_surname
	crest_color = color
	var leader = CharacterFactory.make_leader(leader_given, leader_surname, color)
	characters[leader.id] = leader
	var ally = CharacterFactory.make_ally_tutor()
	characters[ally.id] = ally
	deploy_ids = [leader.id, ally.id]
	grant_job_skills(leader)
	grant_job_skills(ally)
	refresh_tavern()
	refresh_marriage_candidates()
	_init_quests()
	World.reset()  # v8.7 playable atlas: position, reputation, markets, boards
	log_event("灰烬旗立团：「%s」" % leader.name)
	mark_dirty()

func set_beat(beat_id: String) -> void:
	story.set_beat(0, beat_id)
	mark_dirty()

func flag(key: String) -> bool:
	return bool(story.flags.get(key, false))

func set_flag(key: String, val: bool = true) -> void:
	story.flags[key] = val
	mark_dirty()

func refresh_tavern() -> void:
	tavern_candidates.clear()
	for i in 3:
		tavern_candidates.append(CharacterFactory.make_tavern_candidate(rng))

func recruit(candidate: CKCharacter, cost: int = -1) -> Dictionary:
	if cost < 0:
		cost = CKEconomyState.recruit_price(self, candidate)
	if silver < cost:
		return {"ok": false, "msg": Locale.t("not_enough_silver")}
	silver -= cost
	candidate.in_roster = true
	characters[candidate.id] = candidate
	tavern_candidates.erase(candidate)
	set_flag("recruited")
	log_event("招募 %s（-%d 银）" % [candidate.name, cost])
	mark_dirty()
	check_ambitions()
	return {"ok": true, "msg": "招募成功", "cost": cost}


func exp_to_next(level: int) -> int:
	return 36 + maxi(1, level) * 14

## Turn stored exp into levels without touching the campaign RNG. Merit for titles reads level.
func settle_exp(c: CKCharacter) -> int:
	if c == null:
		return 0
	var ups := 0
	while c.level < 20 and c.exp >= exp_to_next(c.level):
		c.exp -= exp_to_next(c.level)
		c.level += 1
		ups += 1
		var fork := RandomNumberGenerator.new()
		fork.seed = hash("%s|lv|%d" % [c.id, c.level])
		var key: String = CKCharacter.STAT_KEYS[fork.randi() % CKCharacter.STAT_KEYS.size()]
		var cap := int(c.apt_max.get(key, 20))
		if cap <= 0:
			cap = 20
		c.stats[key] = mini(cap, int(c.stats.get(key, 8)) + 1)
	if ups > 0:
		c.recalc_hp()
		log_event("%s 升至 %d 级" % [c.name, c.level])
	return ups


## v8.9 祠堂验血：family and roster members not yet verified. Reveals carriers, unmasks pretenders.
func verify_bloodlines_at_shrine() -> Dictionary:
	var todo: Array = []
	for c in characters.values():
		if c.alive and (c.in_roster or c.is_leader or c.spouse_id != "" or c.is_child) and not bool(c.blood_meta.get("verified", false)):
			todo.append(c)
	var cost := CKBloodline.verify_cost(building_level("shrine"))
	if todo.is_empty():
		return {"ok": false, "msg": "族中人人都已验过血"}
	var n := mini(todo.size(), silver / maxi(1, cost))
	if n <= 0:
		return {"ok": false, "msg": "银币不足（验血每人 %d 银）" % cost}
	var lines: Array = []
	var tally := {}
	for i in n:
		var c: CKCharacter = todo[i]
		var r := CKBloodline.verify_and_record(c, characters)
		lines.append(str(r.get("line_zh", "")))
		lineage_log.append(str(r.get("line_zh", "")))
		var vz := str(r.get("verdict_zh", ""))
		tally[vz] = int(tally.get(vz, 0)) + 1
		grant_job_skills(c)
	silver -= n * cost
	log_event("祠堂验血 %d 人（-%d 银）" % [n, n * cost])
	mark_dirty()
	var bits: Array = []
	for k in tally.keys():
		bits.append("%s %d" % [k, int(tally[k])])
	return {"ok": true, "count": n, "cost": n * cost, "lines": lines, "tally": tally,
		"msg": "验血 %d 人：%s（-%d 银，详见族谱纪事）" % [n, " · ".join(bits), n * cost]}


func try_promote(cid: String, job_id: String) -> Dictionary:
	var c: CKCharacter = characters.get(cid)
	var job = get_job(job_id)
	if c == null or job.is_empty():
		return {"ok": false, "msg": "无效"}
	var req: Dictionary = job.get("req", {})
	for k in req.keys():
		if k in CKCharacter.STAT_KEYS:
			if int(c.stats.get(k, 0)) < int(req[k]):
				return {"ok": false, "msg": "属性不足：%s 需 %d" % [Locale.t("stat_" + k), req[k]]}
		elif k == "iron":
			if iron < int(req[k]):
				return {"ok": false, "msg": "铁料不足"}
		elif k == "herb":
			if herb < int(req[k]):
				return {"ok": false, "msg": "药材不足"}
	if req.has("iron"):
		iron -= int(req["iron"])
	if req.has("herb"):
		herb -= int(req["herb"])
	c.job_id = job_id
	c.recalc_hp()
	grant_job_skills(c)
	log_event("%s 转职为 %s，战技已更新" % [c.name, job.get("name", job_id)])
	mark_dirty()
	return {"ok": true, "msg": "转职成功：" + job.get("name", job_id)}


func reset_battle_skills(roster_chars: Array) -> void:
	for c in roster_chars:
		if c == null:
			continue
		c.temp_def_buff = 0
		c.temp_hit_bonus = 0
		c.temp_crit_bonus = 0
		c.temp_ignore_zoc = false
		c.temp_leave_free = false
		c.temp_combat_lock = 0
		c.temp_terrain_ward = false
		c.temp_zoc_aura = 0
		c.temp_exposed = 0
		c.skill_uses.clear()
		c.skill_cd.clear()
		for sid in _all_known_skills(c):
			var sk = get_skill(sid)
			c.skill_uses[sid] = int(sk.get("uses", 1))
			c.skill_cd[sid] = 0

func _all_known_skills(c: CKCharacter) -> Array:
	var out: Array = []
	for sid in c.skills:
		if sid not in out:
			out.append(sid)
	for sid in c.unlocked_skills:
		if sid not in out:
			out.append(sid)
	return out

func tick_skill_cooldowns(roster_chars: Array) -> void:
	for c in roster_chars:
		if c == null:
			continue
		for sid in c.skill_cd.keys():
			var v = int(c.skill_cd[sid])
			if v > 0:
				c.skill_cd[sid] = v - 1

func can_unlock_skill(c: CKCharacter, sid: String) -> Dictionary:
	var sk = get_skill(sid)
	if sk.is_empty() or not sk.has("name"):
		return {"ok": false, "msg": "无此战技"}
	if int(sk.get("tier", 1)) <= 1:
		return {"ok": false, "msg": "一阶战技随职业自动学会"}
	if sid in c.unlocked_skills or sid in c.skills:
		return {"ok": false, "msg": "已学会"}
	var jobs: Array = sk.get("jobs", [])
	if c.job_id not in jobs:
		return {"ok": false, "msg": "职业不符"}
	var req = str(sk.get("req_skill", ""))
	if req != "" and req not in c.skills and req not in c.unlocked_skills:
		return {"ok": false, "msg": "需先掌握：" + get_skill(req).get("name", req)}
	if skill_points < 1:
		return {"ok": false, "msg": "战技点不足（胜仗与章节可获得）"}
	return {"ok": true, "msg": "可解锁"}

func unlock_skill(c: CKCharacter, sid: String) -> Dictionary:
	var check = can_unlock_skill(c, sid)
	if not check.get("ok"):
		return check
	skill_points -= 1
	c.unlocked_skills.append(sid)
	if sid not in c.skills:
		c.skills.append(sid)
	log_event("%s 解锁战技「%s」" % [c.name, get_skill(sid).get("name", sid)])
	var ams = check_ambitions()
	mark_dirty()
	var extra = ("；" + " / ".join(ams)) if ams else ""
	return {"ok": true, "msg": "解锁成功：" + get_skill(sid).get("name", sid) + extra}


func set_rival_stance(house_id: String, stance: String) -> void:
	rival_stances[house_id] = stance
	add_lineage_event("敌宅立场：%s → %s" % [house_id, stance])
	mark_dirty()

func get_rival_stance(house_id: String) -> String:
	if rival_stances.has(house_id):
		return str(rival_stances[house_id])
	for h in data_rivals.get("houses", []):
		if str(h.get("id")) == house_id:
			return str(h.get("stance", "neutral"))
	return "neutral"

## 授旗道路：自动授予相关一阶战技（并微调职业）
func grant_path_skills(c: CKCharacter, path: String) -> Array:
	var granted: Array = []
	if c == null or path == "":
		return granted
	var prefer_jobs := {
		"martial": ["warrior", "heavy_inf", "light_inf", "squire"],
		"scholar": ["priest", "apprentice"],
		"merchant": ["light_cavalry", "squire", "hunter"]
	}
	var prefer_trees := {
		"martial": ["melee", "cavalry"],
		"scholar": ["faith"],
		"merchant": ["range", "cavalry"]
	}
	# soft job nudge if still default light_inf child
	var jobs: Array = prefer_jobs.get(path, [])
	if c.job_id == "light_inf" and jobs.size() > 0:
		c.job_id = str(jobs[0])
	grant_job_skills(c)
	var trees: Array = prefer_trees.get(path, [])
	for s in data_skills.get("skills", []):
		if int(s.get("tier", 1)) > 1:
			continue
		if str(s.get("tree", "")) not in trees:
			continue
		# allow if job matches OR path strongly aligns
		var sid = str(s.get("id"))
		var sjobs: Array = s.get("jobs", [])
		if c.job_id not in sjobs and path != "scholar":
			# still grant 1-2 iconic skills for path even if job mismatch
			if sid not in ["power_strike", "rush", "piercing_shot", "ward_chant", "lance_thrust", "smite"]:
				continue
		if sid not in c.skills:
			c.skills.append(sid)
			granted.append(sid)
	# Path T2: unlock one matching tier-2 if req met and points allow (free path unlock once)
	var t2_key = "path_t2_" + c.id + "_" + path
	if not flag(t2_key):
		for s2 in data_skills.get("skills", []):
			if int(s2.get("tier", 1)) < 2:
				continue
			if str(s2.get("tree", "")) not in trees:
				continue
			var sid2 = str(s2.get("id"))
			if sid2 in c.skills or sid2 in c.unlocked_skills:
				continue
			var req = str(s2.get("req_skill", ""))
			if req != "" and req not in c.skills and req not in c.unlocked_skills:
				continue
			var jobs2: Array = s2.get("jobs", [])
			if c.job_id not in jobs2:
				continue
			c.unlocked_skills.append(sid2)
			if sid2 not in c.skills:
				c.skills.append(sid2)
			granted.append(sid2)
			set_flag(t2_key)
			log_event("%s 道路解锁二阶「%s」" % [c.name, s2.get("name", sid2)])
			break
	mark_dirty()
	return granted

func start_rival_deal(house_id: String, kind: String, turns: int = 3, price: int = 25) -> Dictionary:
	if silver < price:
		return {"ok": false, "msg": "银两不足"}
	if rival_deals.has(house_id) and int(rival_deals[house_id].get("turns_left", 0)) > 0:
		return {"ok": false, "msg": "该宅已有进行中的契约"}
	silver -= price
	rival_deals[house_id] = {"kind": kind, "turns_left": turns, "price": price}
	add_lineage_event("敌宅契约开始：%s · %s（%d月）" % [house_id, kind, turns])
	mark_dirty()
	return {"ok": true, "msg": "契约已立：%s，余 %d 月" % [kind, turns]}


func renegotiate_rival_deal(house_id: String, new_kind: String, extra_cost: int = 15) -> Dictionary:
	if not rival_deals.has(house_id) or int(rival_deals[house_id].get("turns_left", 0)) <= 0:
		return {"ok": false, "msg": "无进行中契约可改"}
	if silver < extra_cost:
		return {"ok": false, "msg": "改约需要额外银两"}
	silver -= extra_cost
	var d: Dictionary = rival_deals[house_id]
	var oldk = str(d.get("kind"))
	d["kind"] = new_kind
	d["turns_left"] = maxi(2, int(d.get("turns_left", 2)))
	rival_deals[house_id] = d
	add_lineage_event("敌宅改约：%s %s→%s" % [house_id, oldk, new_kind])
	mark_dirty()
	return {"ok": true, "msg": "已改约为「%s」，余 %d 月" % [new_kind, d["turns_left"]]}

func breach_rival_deal(house_id: String) -> Dictionary:
	if not rival_deals.has(house_id) or int(rival_deals[house_id].get("turns_left", 0)) <= 0:
		return {"ok": false, "msg": "无契约可毁"}
	var kind = str(rival_deals[house_id].get("kind"))
	rival_deals.erase(house_id)
	# stance penalty
	var st = get_rival_stance(house_id)
	var nxt = {"cordial": "neutral", "neutral": "wary", "wary": "hostile", "hostile": "hostile"}.get(st, "hostile")
	set_rival_stance(house_id, nxt)
	silver += 10  # reclaim partial
	add_lineage_event("敌宅毁约：%s（原%s）→立场%s" % [house_id, kind, nxt])
	mark_dirty()
	return {"ok": true, "msg": "已毁约。收回部分银两，立场变为敌意一侧。"}

func tick_rival_deals() -> Array:
	var evs: Array = []
	var done: Array = []
	last_deal_events = []
	for hid in rival_deals.keys():
		var d: Dictionary = rival_deals[hid]
		var left = int(d.get("turns_left", 0)) - 1
		d["turns_left"] = left
		# mid-contract events while still running (deeper table)
		if left > 0:
			var kind = str(d.get("kind", ""))
			var roll = int(Calendar.month) + hid.length() + left + int(d.get("mid_ticks", 0))
			d["mid_ticks"] = int(d.get("mid_ticks", 0)) + 1
			var phase = roll % 7
			if phase == 0:
				match kind:
					"trade":
						silver += 12; food += 2
						evs.append("契约中期·商路红利：银+12 粮+2（%s）" % hid)
					"intel":
						add_rep("ashland", 2)
						add_rep("riverland", 1)
						evs.append("契约中期·双邦情报：灰烬/河卫声望微升（%s）" % hid)
					"truce":
						morale = mini(100, morale + 3)
						evs.append("契约中期·停战巡哨：士气+3（%s）" % hid)
				add_lineage_event(evs[-1])
			elif phase == 1:
				match kind:
					"trade":
						if silver >= 8:
							silver -= 8
							evs.append("契约中期·关税加码：银-8（%s，可改约）" % hid)
						else:
							evs.append("契约中期·商路吃紧：银不足抵税（%s）" % hid)
					"intel":
						evs.append("契约中期·情报真伪难辨：建议改约核验（%s）" % hid)
					"truce":
						var st = get_rival_stance(hid)
						if st == "cordial":
							set_rival_stance(hid, "neutral")
							evs.append("契约中期·停战生隙：立场退至并立（%s）" % hid)
						else:
							evs.append("契约中期·边境小摩擦：停战仍在（%s）" % hid)
				if evs.size() > 0:
					add_lineage_event(evs[-1])
			elif phase == 2:
				match kind:
					"trade":
						iron += 1
						evs.append("契约中期·铁货过境：铁+1（%s）" % hid)
					"intel":
						herb += 1
						evs.append("契约中期·药草线报：药+1（%s）" % hid)
					"truce":
						silver += 5
						evs.append("契约中期·互市小开：银+5（%s）" % hid)
				add_lineage_event(evs[-1])
			elif phase == 4 and kind == "intel":
				add_skill_point(1)
				evs.append("契约中期·密函破译：战技点+1（%s）" % hid)
				add_lineage_event(evs[-1])
		if left <= 0:
			var kind = str(d.get("kind", ""))
			match kind:
				"trade":
					silver += 50
					evs.append("契约兑现·商路：银+50（%s）" % hid)
				"intel":
					add_skill_point(1)
					evs.append("契约兑现·情报：战技点+1（%s）" % hid)
				"truce":
					set_rival_stance(hid, "cordial")
					evs.append("契约兑现·停战：立场并席（%s）" % hid)
				_:
					evs.append("契约到期（%s）" % hid)
			done.append(hid)
		else:
			rival_deals[hid] = d
	for hid2 in done:
		rival_deals.erase(hid2)
		add_lineage_event(evs[-1] if evs.size() > 0 else "契约结束")
	last_deal_events = evs.duplicate()
	# stamp last_event onto still-active deals
	for hid3 in rival_deals.keys():
		var dd: Dictionary = rival_deals[hid3]
		for msg in evs:
			if str(msg).find(str(hid3)) >= 0:
				dd["last_event"] = str(msg)
				rival_deals[hid3] = dd
				break
	mark_dirty()
	return evs

func add_lineage_event(text: String) -> void:
	lineage_log.append({"t": Calendar.label() if Calendar else "", "text": text})
	if lineage_log.size() > 40:
		lineage_log.pop_front()
	log_event(text)

func add_skill_point(n: int = 1) -> void:
	skill_points += n
	mark_dirty()


## v8.7 saves have no genome and no court fields. v8.8 saves have a v2 genome without signature loci.
## Current saves already carry blood_meta; migration only fills what is missing.
func migrate_save_data(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return data
	var schema := str(data.get("schema", ""))
	var legacy := schema in ["v8.7", "v8.8", "8.7", "8.8"] or schema == ""
	if not legacy and schema == SAVE_SCHEMA:
		return data
	var from := schema if schema != "" else "v8.7"
	var saw_genome := false
	var saw_sig := false
	for id in data.get("characters", {}).keys():
		var row: Dictionary = data["characters"][id]
		if typeof(row.get("genome", {})) == TYPE_DICTIONARY and not (row.get("genome", {}) as Dictionary).is_empty():
			saw_genome = true
			if (row["genome"] as Dictionary).has("sig"):
				saw_sig = true
		row = _migrate_character_row(row)
		data["characters"][id] = row
	for bucket in ["tavern", "marriage"]:
		var arr: Array = data.get(bucket, [])
		for i in arr.size():
			if typeof(arr[i]) == TYPE_DICTIONARY:
				arr[i] = _migrate_character_row(arr[i])
		data[bucket] = arr
	if schema == "":
		from = "v8.8" if saw_genome and not saw_sig else ("v9.0" if saw_sig else "v8.7")
	var world: Dictionary = data.get("world_v87", {}) if typeof(data.get("world_v87", {})) == TYPE_DICTIONARY else {}
	if typeof(world.get("royal_courts", {})) != TYPE_DICTIONARY or (world.get("royal_courts", {}) as Dictionary).is_empty():
		if from in ["v8.7", "v8.8"]:
			world["royal_courts"] = CKCourt.blank_courts(int(data.get("year", 1)) * 17 + 3)
	data["world_v87"] = world
	data["migrated_from"] = from
	data["schema"] = SAVE_SCHEMA
	data["version"] = 1
	return data

func _migrate_character_row(row: Dictionary) -> Dictionary:
	if typeof(row.get("blood_meta")) != TYPE_DICTIONARY:
		row["blood_meta"] = {}
	var meta: Dictionary = row["blood_meta"]
	if not meta.has("verified"):
		meta["verified"] = false
	if not meta.has("verdict"):
		meta["verdict"] = ""
	if typeof(meta.get("rites")) != TYPE_ARRAY:
		meta["rites"] = []
	if str(meta.get("title", "")) == "":
		var rank := str(row.get("rank", "knight"))
		meta["title"] = rank if rank in CKCharacter.RANK_ORDER else "knight"
	if not meta.has("lamp_seat"):
		meta["lamp_seat"] = ""
	row["blood_meta"] = meta
	if str(row.get("age_stage", "")) == "":
		row["age_stage"] = CKGenomePortrait.stage_for_age(int(row.get("age", 20)))
	if typeof(row.get("honors")) != TYPE_ARRAY:
		row["honors"] = []
	if typeof(row.get("genome")) != TYPE_DICTIONARY:
		row["genome"] = {}
	return row

func save_game() -> bool:
	var data = {
		"version": 1,
		"schema": SAVE_SCHEMA,
		"surname": surname,
		"crest_color": crest_color,
		"silver": silver, "food": food, "iron": iron, "herb": herb, "morale": morale,
		"year": Calendar.year, "month": Calendar.month,
		"story": {"beats": story.export_beats()},
		"rival_stances": rival_stances.duplicate(true),
		"rival_deals": rival_deals.duplicate(true),
		"skill_points": skill_points,
		"chapter0_flags": story.flags.duplicate(true),
		"reputation": reputation,
		"settings": settings,
		"deploy_ids": deploy_ids,
		"dynasty_journal": dynasty_journal,
		"lineage_log": lineage_log.duplicate(true),
		"lineage_path": lineage_path.duplicate(true),
		"event_log": event_log,
		"shrine_level": shrine_level,
		"buildings": buildings.duplicate(true),
		"house_mods": house_mods.duplicate(true),
		"quest_done": quest_done.duplicate(true),
		"advisor_bonus": advisor_bonus.duplicate(true),
		"ambition_done": ambition_done.duplicate(true),
		"holdings": holdings.duplicate(true),
		"caravan": caravan.duplicate(true),
		"alliance_duty_months": alliance_duty_months,
		"doctrine_months": doctrine_months,
		"estate_quiet_months": estate_quiet_months,
		"patrol_cooldown": patrol_cooldown,
		"patrol_boost_months": patrol_boost_months,
		"characters": {},
		"tavern": [],
		"marriage": [],
		"quests": quests,
		"started": started,
		"world_v87": World.to_save(),
	}
	for id in characters.keys():
		data["characters"][id] = characters[id].to_dict()
	for c in tavern_candidates:
		data["tavern"].append(c.to_dict())
	for c in marriage_candidates:
		data["marriage"].append(c.to_dict())
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	dirty = false
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return apply_save_data(data)

func apply_save_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	data = migrate_save_data(data)
	started = bool(data.get("started", true))
	surname = str(data.get("surname", "灰旗"))
	crest_color = str(data.get("crest_color", "#c9a227"))
	silver = int(data.get("silver", 0))
	food = int(data.get("food", 0))
	iron = int(data.get("iron", 0))
	herb = int(data.get("herb", 0))
	morale = int(data.get("morale", 50))
	Calendar.year = int(data.get("year", 1))
	Calendar.month = int(data.get("month", 1))
	story.import_save(data)
	rival_stances = data.get("rival_stances", {"shuoying": "hostile", "qinghe": "wary", "lantern": "neutral"}).duplicate(true)
	rival_deals = data.get("rival_deals", {}).duplicate(true)
	skill_points = int(data.get("skill_points", 0))
	reputation = data.get("reputation", {"ashland": 0, "riverland": 0})
	settings = data.get("settings", settings)
	deploy_ids = data.get("deploy_ids", [])
	dynasty_journal = str(data.get("dynasty_journal", ""))
	lineage_log = data.get("lineage_log", []).duplicate(true)
	lineage_path = data.get("lineage_path", {}).duplicate(true)
	event_log = data.get("event_log", [])
	shrine_level = int(data.get("shrine_level", 1))
	buildings = data.get("buildings", {"hall": 1, "barracks": 1, "market": 1, "forge": 1, "shrine": shrine_level}).duplicate(true)
	if not buildings.has("shrine"):
		buildings["shrine"] = shrine_level
	else:
		shrine_level = int(buildings.get("shrine", shrine_level))
	house_mods = data.get("house_mods", {}).duplicate(true)
	quest_done = data.get("quest_done", {}).duplicate(true)
	advisor_bonus = data.get("advisor_bonus", {}).duplicate(true)
	ambition_done = data.get("ambition_done", {}).duplicate(true)
	holdings = data.get("holdings", {}).duplicate(true)
	var _cv = data.get("caravan", {})
	caravan = _cv.duplicate(true) if typeof(_cv) == TYPE_DICTIONARY else {}
	alliance_duty_months = int(data.get("alliance_duty_months", 0))
	doctrine_months = int(data.get("doctrine_months", 0))
	estate_quiet_months = int(data.get("estate_quiet_months", 0))
	patrol_cooldown = int(data.get("patrol_cooldown", 0))
	patrol_boost_months = int(data.get("patrol_boost_months", 0))
	quests = data.get("quests", quests)
	characters.clear()
	for id in data.get("characters", {}).keys():
		characters[id] = CKCharacter.from_dict(data["characters"][id])
		characters[id].ensure_genome()
	tavern_candidates.clear()
	for d in data.get("tavern", []):
		tavern_candidates.append(CKCharacter.from_dict(d))
	marriage_candidates.clear()
	for d in data.get("marriage", []):
		marriage_candidates.append(CKCharacter.from_dict(d))
	var _wd = data.get("world_v87", {})
	World.from_save(_wd if typeof(_wd) == TYPE_DICTIONARY else {})
	BattleRules.preview_enabled = settings.get("rules_preview", true)
	mark_dirty()
	return true

func family_members() -> Array:
	return CKFamilyState.family_members(self)

func refresh_marriage_candidates() -> void:
	CKFamilyState.refresh_marriage_candidates(self)

func _init_quests() -> void:
	CKEconomyState._init_quests(self)

func building_level(id: String) -> int:
	return CKEconomyState.building_level(self, id)

func max_deploy() -> int:
	return CKEconomyState.max_deploy(self)

func train_cost() -> int:
	return CKEconomyState.train_cost(self)

func forge_craft_cost() -> Dictionary:
	return CKEconomyState.forge_craft_cost(self)

func market_buy_prices() -> Dictionary:
	return CKEconomyState.market_buy_prices(self)

func market_sell_prices() -> Dictionary:
	return CKEconomyState.market_sell_prices(self)

func _all_buildings_at_least(lv: int) -> bool:
	return CKEconomyState._all_buildings_at_least(self, lv)

func _enlisted_children_count() -> int:
	return CKEconomyState._enlisted_children_count(self)

func holding_unlocked(hid: String) -> bool:
	return CKEconomyState.holding_unlocked(self, hid)

func holding_level(hid: String) -> int:
	return CKEconomyState.holding_level(self, hid)

func unlock_holding(hid: String) -> String:
	return CKEconomyState.unlock_holding(self, hid)

func upgrade_holding(hid: String) -> Dictionary:
	return CKEconomyState.upgrade_holding(self, hid)

func assign_steward(hid: String, cid: String) -> Dictionary:
	return CKEconomyState.assign_steward(self, hid, cid)

func clear_steward(hid: String) -> void:
	CKEconomyState.clear_steward(self, hid)

func holding_patrol_boost(hid: String) -> int:
	return CKEconomyState.holding_patrol_boost(self, hid)

func holding_patrol_cd(hid: String) -> int:
	return CKEconomyState.holding_patrol_cd(self, hid)

func patrol_holding(hid: String) -> Dictionary:
	return CKEconomyState.patrol_holding(self, hid)

func patrol_holdings() -> Dictionary:
	return CKEconomyState.patrol_holdings(self)

func tick_patrol_month() -> void:
	CKEconomyState.tick_patrol_month(self)

func steward_of(hid: String) -> CKCharacter:
	return CKEconomyState.steward_of(self, hid)

func holding_focus(hid: String) -> String:
	return CKEconomyState.holding_focus(self, hid)

func set_holding_focus(hid: String, focus: String) -> Dictionary:
	return CKEconomyState.set_holding_focus(self, hid, focus)

func start_caravan(kind: String) -> Dictionary:
	return CKEconomyState.start_caravan(self, kind)

func escort_caravan() -> Dictionary:
	return CKEconomyState.escort_caravan(self)

func tick_caravan_month() -> Array:
	return CKEconomyState.tick_caravan_month(self)

func start_alliance_duty() -> Dictionary:
	return CKEconomyState.start_alliance_duty(self)

func tick_alliance_duty_month() -> Array:
	return CKEconomyState.tick_alliance_duty_month(self)

func holding_yield_preview(hid: String) -> Dictionary:
	return CKEconomyState.holding_yield_preview(self, hid)

func holdings_monthly_yield() -> String:
	return CKEconomyState.holdings_monthly_yield(self)

func unlocked_holdings_count() -> int:
	return CKEconomyState.unlocked_holdings_count(self)

func total_holding_levels() -> int:
	return CKEconomyState.total_holding_levels(self)

func ambition_list() -> Array:
	return CKEconomyState.ambition_list(self)

func check_ambitions() -> Array:
	return CKEconomyState.check_ambitions(self)

func upgrade_building(id: String) -> Dictionary:
	return CKEconomyState.upgrade_building(self, id)

func building_summary() -> String:
	return CKEconomyState.building_summary(self)

func accept_quest(qid: String) -> Dictionary:
	return CKEconomyState.accept_quest(self, qid)

func apply_quest_first_clear(qid: String) -> String:
	return CKEconomyState.apply_quest_first_clear(self, qid)

func on_battle_quest_victory() -> void:
	CKEconomyState.on_battle_quest_victory(self)

func tick_doctrine_and_marriage_month() -> Array:
	return CKFamilyState.tick_doctrine_and_marriage_month(self)

func apply_monthly_upkeep() -> String:
	return CKEconomyState.apply_monthly_upkeep(self)

func apply_harvest() -> String:
	return CKEconomyState.apply_harvest(self)

func heal_at_shrine() -> String:
	return CKEconomyState.heal_at_shrine(self)

func train(cid: String) -> Dictionary:
	return CKEconomyState.train(self, cid)

func craft_weapon(cid: String) -> Dictionary:
	return CKEconomyState.craft_weapon(self, cid)

func market_buy(item: String, qty: int = 1) -> Dictionary:
	return CKEconomyState.market_buy(self, item, qty)

func market_sell(item: String, qty: int = 1) -> Dictionary:
	return CKEconomyState.market_sell(self, item, qty)

func get_skill(sid: String) -> Dictionary:
	return CKEnemyLoadout.get_skill(self, sid)

func skills_for_job(job_id: String) -> Array:
	return CKEnemyLoadout.skills_for_job(self, job_id)

func battle_difficulty_from_map(map_id: String) -> int:
	return CKEnemyLoadout.battle_difficulty_from_map(self, map_id)

func enemy_skill_table_for(map_id: String) -> Dictionary:
	return CKEnemyLoadout.enemy_skill_table_for(self, map_id)

func _grant_theme_skill(c: CKCharacter, elite: bool, template_id: String, granted: Array) -> void:
	CKEnemyLoadout._grant_theme_skill(self, c, elite, template_id, granted)

func _apply_skill_list(c: CKCharacter, sids: Array) -> void:
	CKEnemyLoadout._apply_skill_list(self, c, sids)

func _skills_from_table_entry(entry) -> Array:
	return CKEnemyLoadout._skills_from_table_entry(self, entry)

func _elite_from_table_entry(entry) -> Array:
	return CKEnemyLoadout._elite_from_table_entry(self, entry)

func grant_battle_enemy_skills(c: CKCharacter, elite: bool = false, difficulty: int = 1, map_id: String = "", template_id: String = "") -> void:
	CKEnemyLoadout.grant_battle_enemy_skills(self, c, elite, difficulty, map_id, template_id)

func grant_job_skills(c: CKCharacter) -> void:
	CKEnemyLoadout.grant_job_skills(self, c)

func build_dynasty_journal() -> String:
	return CKFamilyState.build_dynasty_journal(self)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
