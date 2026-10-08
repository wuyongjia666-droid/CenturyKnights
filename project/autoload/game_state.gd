extends Node
## 全局状态：资源、人物、第零章旗标、存档

signal state_changed
signal log_added(text: String)

const _StoryStateScript = preload("res://scripts/core/story_state.gd")
var rng := RandomNumberGenerator.new()
var story = _StoryStateScript.new()

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
const HOLDING_DEFS := {
	"reed_ford": {"name": "苇原渡", "desc": "护商旧道属地", "food": 3, "silver": 3, "quest": "q_escort"},
	"stone_slope": {"name": "石垒坡", "desc": "清匪后的丘地佃庄", "food": 2, "silver": 5, "quest": "q_bandit"},
	"fog_vale": {"name": "雾谷药田", "desc": "药草租佃", "food": 1, "silver": 3, "herb": 1, "quest": "q_herb"},
	"tide_bridge": {"name": "断潮渡哨", "desc": "河卫守桥契约地", "food": 2, "silver": 4, "rep": 1, "quest": "q_bridge"},
}
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

func family_members() -> Array:
	var out: Array = []
	for c in characters.values():
		if c.alive and (c.is_leader or c.spouse_id != "" or c.is_child or c.parent_ids.size() > 0):
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
		cost = 25 + candidate.rank_index() * 15
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

func refresh_marriage_candidates() -> void:
	marriage_candidates.clear()
	for i in 3:
		marriage_candidates.append(CharacterFactory.make_marriage_candidate(rng))

func _init_quests() -> void:
	quests = [
		{"id": "q_escort", "name": "护商·苇原道", "stars": 1, "months": 1, "silver": 30, "rep": 6, "battle": false,
			"desc": "商队要走苇原旧道。旗帜一亮，劫匪多半让路——自动结算，换银与灰烬邦声望。"},
		{"id": "q_bandit", "name": "清匪·石垒坡", "stars": 2, "months": 1, "silver": 45, "rep": 10, "battle": true, "map": "quest_bandit",
			"desc": "石垒坡有人收「过路银」。真实战棋清剿：编队出战，打赢才算。"},
		{"id": "q_drill", "name": "演习·灰场", "stars": 1, "months": 1, "silver": 20, "rep": 4, "battle": false,
			"desc": "堡内灰场拉练。耗时一月，全员小额经验，士气微升。"},
		{"id": "q_herb", "name": "采药·雾谷", "stars": 1, "months": 1, "silver": 15, "rep": 3, "battle": false,
			"desc": "雾谷药草正旺。归来药材+2（自动），并得薄银。"},
		{"id": "q_bridge", "name": "守桥·断潮渡", "stars": 2, "months": 1, "silver": 40, "rep": 8, "battle": false,
			"desc": "河卫邦请人值夜守桥。不必开战，换声望与银——陆桥耳目会记住灰旗。"},
		{"id": "q_rumor", "name": "探听·烽火夜话", "stars": 1, "months": 1, "silver": 10, "rep": 5, "battle": false,
			"desc": "酒馆夜话里有春令与匪线的碎片。耗时换声望，偶得铁料线索（银少）。"},
		{"id": "q_hill_war", "name": "主线支援·石垒坡", "stars": 3, "months": 1, "silver": 60, "rep": 12, "battle": true, "map": "ch1_hill",
			"desc": "第一章：丘林交错的石垒坡清剿。打赢记入陆桥烽火。"},
		{"id": "q_ford_war", "name": "主线支援·断潮渡", "stars": 3, "months": 1, "silver": 55, "rep": 12, "battle": true, "map": "ch1_ford",
			"desc": "第一章：宽滩断潮渡值夜战。河卫邦会记住灰旗。"},
		{"id": "q_fog_war", "name": "主线支援·雾谷", "stars": 3, "months": 1, "silver": 58, "rep": 12, "battle": true, "map": "ch1_fog",
			"desc": "第一章：密林雾谷夜袭。弓手危险，阵型勿散。"},
		{"id": "q_forge_war", "name": "主线支援·炉火关", "stars": 3, "months": 1, "silver": 65, "rep": 12, "battle": true, "map": "ch3_forge",
			"desc": "第三章：炉火关试锋。可用战技破旗斩/穿林箭。"},
		{"id": "q_shrine_war", "name": "主线支援·祠堂外廊", "stars": 3, "months": 1, "silver": 65, "rep": 12, "battle": true, "map": "ch3_shrine",
			"desc": "第三章：祠堂外廊。适合铁壁与灰焰祷言。"},
	]


const BUILDING_NAMES := {
	"hall": "议事厅",
	"barracks": "校场",
	"market": "市集",
	"forge": "工坊",
	"shrine": "祠堂",
}
const BUILDING_MAX := 5
const BUILDING_COST := {
	# level -> cost to upgrade TO that level
	2: {"silver": 80, "iron": 3, "food": 10},
	3: {"silver": 160, "iron": 6, "food": 20},
	4: {"silver": 280, "iron": 10, "food": 35},
	5: {"silver": 450, "iron": 16, "food": 55},
}

func building_level(id: String) -> int:
	return int(buildings.get(id, 1))

func max_deploy() -> int:
	# 厅堂 Lv1–5 → 4–8 人
	return 3 + building_level("hall")

func train_cost() -> int:
	var base = 15
	var disc = (building_level("barracks") - 1) * 3
	if bool(house_mods.get("drill_discount", false)):
		disc += 2
	return maxi(8, base - disc)

func forge_craft_cost() -> Dictionary:
	var lv = building_level("forge")
	return {"iron": maxi(1, 3 - mini(lv, 3)), "silver": maxi(8, 24 - lv * 4)}

func market_buy_prices() -> Dictionary:
	var lv = building_level("market")
	var cut = lv - 1
	if bool(house_mods.get("trade_route", false)):
		cut += 1
	if bool(house_mods.get("market_edge", false)):
		cut += 1
	return {"food": maxi(1, 2 - cut), "iron": maxi(5, 8 - cut), "herb": maxi(4, 6 - cut)}

func market_sell_prices() -> Dictionary:
	var lv = building_level("market")
	var bump = lv - 1
	if bool(house_mods.get("trade_route", false)):
		bump += 1
	return {"food": 1 + bump, "iron": 5 + bump, "herb": 4 + bump}


func _all_buildings_at_least(lv: int) -> bool:
	for id in BUILDING_NAMES.keys():
		if building_level(id) < lv:
			return false
	return true

func _enlisted_children_count() -> int:
	var n = 0
	for c in characters.values():
		if not c.alive or not c.in_roster:
			continue
		if c.parent_ids.size() > 0 or str(c.id).begins_with("child"):
			n += 1
	return n


func holding_unlocked(hid: String) -> bool:
	return holdings.has(hid)

func holding_level(hid: String) -> int:
	if not holdings.has(hid):
		return 0
	return int(holdings[hid].get("level", 1))

func unlock_holding(hid: String) -> String:
	if hid not in HOLDING_DEFS:
		return ""
	if holdings.has(hid):
		return ""
	holdings[hid] = {"level": 1, "steward_id": ""}
	var nm = str(HOLDING_DEFS[hid].get("name", hid))
	add_lineage_event("属地开垦：%s" % nm)
	mark_dirty()
	return "属地解锁：%s（月结产出）" % nm

func upgrade_holding(hid: String) -> Dictionary:
	if not holdings.has(hid):
		return {"ok": false, "msg": "尚未拥有此属地"}
	var lv = holding_level(hid)
	if lv >= 3:
		return {"ok": false, "msg": "属地已满级"}
	var cost_s = 40 * lv
	var cost_f = 8 * lv
	if silver < cost_s or food < cost_f:
		return {"ok": false, "msg": "需 %d银/%d粮" % [cost_s, cost_f]}
	silver -= cost_s
	food -= cost_f
	holdings[hid]["level"] = lv + 1
	log_event("属地升级：%s → Lv%d" % [HOLDING_DEFS[hid].name, lv + 1])
	var amb = check_ambitions()
	mark_dirty()
	return {"ok": true, "msg": "%s 升至 Lv%d%s" % [HOLDING_DEFS[hid].name, lv + 1, ("；" + " / ".join(amb)) if amb else ""]}


func assign_steward(hid: String, cid: String) -> Dictionary:
	if not holdings.has(hid):
		return {"ok": false, "msg": "属地未开垦"}
	var c: CKCharacter = characters.get(cid)
	if c == null or not c.alive or not c.in_roster:
		return {"ok": false, "msg": "须选花名册成员"}
	# 一人一属地
	for other in holdings.keys():
		if str(holdings[other].get("steward_id", "")) == cid:
			holdings[other]["steward_id"] = ""
	holdings[hid]["steward_id"] = cid
	log_event("%s 出任 %s 庄头" % [c.name, HOLDING_DEFS[hid].name])
	mark_dirty()
	return {"ok": true, "msg": "%s 就任 %s 庄头（月结+成，且本月抗劫）" % [c.name, HOLDING_DEFS[hid].name]}

func clear_steward(hid: String) -> void:
	if holdings.has(hid):
		holdings[hid]["steward_id"] = ""
		mark_dirty()

func holding_patrol_boost(hid: String) -> int:
	if not holdings.has(hid):
		return 0
	return int(holdings[hid].get("patrol_boost", 0))

func holding_patrol_cd(hid: String) -> int:
	if not holdings.has(hid):
		return 0
	return int(holdings[hid].get("patrol_cd", 0))

func patrol_holding(hid: String) -> Dictionary:
	## 单属地巡防路线：花费较少，仅强化该地抗劫，并返回 vignette 标记
	if not holdings.has(hid):
		return {"ok": false, "msg": "属地未开垦"}
	var def = HOLDING_DEFS.get(hid, {})
	var nm = str(def.get("name", hid))
	if holding_patrol_cd(hid) > 0:
		return {"ok": false, "msg": "%s 巡防冷却中（%d 月）" % [nm, holding_patrol_cd(hid)]}
	var cost_s = 18 + holding_level(hid) * 6
	var cost_f = 3 + holding_level(hid)
	if silver < cost_s or food < cost_f:
		return {"ok": false, "msg": "需 %d 银 / %d 粮" % [cost_s, cost_f]}
	silver -= cost_s
	food -= cost_f
	holdings[hid]["patrol_boost"] = maxi(holding_patrol_boost(hid), 2)
	holdings[hid]["patrol_cd"] = 2
	holdings[hid]["last_patrol"] = Calendar.label() if Calendar else ""
	estate_quiet_months += 1
	morale = mini(100, morale + 1)
	log_event("巡防路线·%s：-%d银/-%d粮，抗劫 2 月" % [nm, cost_s, cost_f])
	add_lineage_event("巡防路线抵达%s——田埂灯火一夜未熄" % nm)
	var amb = check_ambitions()
	mark_dirty()
	var extra = ("；" + " / ".join(amb)) if amb else ""
	return {"ok": true, "msg": "%s 巡防完成%s" % [nm, extra], "hid": hid, "vignette": true}

func patrol_holdings() -> Dictionary:
	## 全堡巡防：所有已开垦属地各走一圈（贵），全局抗劫
	if holdings.is_empty():
		return {"ok": false, "msg": "尚无开垦属地"}
	if patrol_cooldown > 0:
		return {"ok": false, "msg": "全堡巡防休息中（尚余 %d 月）" % patrol_cooldown}
	var cost_s = 25 + unlocked_holdings_count() * 8
	var cost_f = 4 + unlocked_holdings_count()
	if silver < cost_s or food < cost_f:
		return {"ok": false, "msg": "需 %d 银 / %d 粮" % [cost_s, cost_f]}
	silver -= cost_s
	food -= cost_f
	patrol_boost_months = maxi(patrol_boost_months, 2)
	patrol_cooldown = 2
	for hid in holdings.keys():
		holdings[hid]["patrol_boost"] = maxi(holding_patrol_boost(hid), 2)
		holdings[hid]["last_patrol"] = Calendar.label() if Calendar else ""
	estate_quiet_months += 1
	morale = mini(100, morale + 2)
	log_event("四野巡防：花费 %d银/%d粮，各属地抗劫强化 2 月" % [cost_s, cost_f])
	add_lineage_event("主动巡防：旗丁走田埂，劫影暂避")
	var amb = check_ambitions()
	mark_dirty()
	var extra = ("；" + " / ".join(amb)) if amb else ""
	return {"ok": true, "msg": "全堡巡防完成：抗劫 2 月，安静%d%s" % [estate_quiet_months, extra], "vignette": true, "hid": ""}

func tick_patrol_month() -> void:
	if patrol_cooldown > 0:
		patrol_cooldown -= 1
	if patrol_boost_months > 0:
		patrol_boost_months -= 1
	for hid in holdings.keys():
		var b = int(holdings[hid].get("patrol_boost", 0))
		if b > 0:
			holdings[hid]["patrol_boost"] = b - 1
		var cd = int(holdings[hid].get("patrol_cd", 0))
		if cd > 0:
			holdings[hid]["patrol_cd"] = cd - 1


func steward_of(hid: String) -> CKCharacter:
	if not holdings.has(hid):
		return null
	var cid = str(holdings[hid].get("steward_id", ""))
	if cid == "":
		return null
	return characters.get(cid)


func holding_focus(hid: String) -> String:
	if not holdings.has(hid):
		return "grain"
	var f = str(holdings[hid].get("focus", "grain"))
	if f == "":
		return "grain"
	return f

func set_holding_focus(hid: String, focus: String) -> Dictionary:
	## 属地经营偏向：粮作 / 钱作 / 戍卫 — 真代价决策
	if not holdings.has(hid):
		return {"ok": false, "msg": "属地未开垦"}
	if focus not in ["grain", "cash", "fortify"]:
		return {"ok": false, "msg": "未知偏向"}
	var cd = int(holdings[hid].get("focus_cd", 0))
	if cd > 0:
		return {"ok": false, "msg": "改作冷却中（余%d月）" % cd}
	if silver < 10:
		return {"ok": false, "msg": "改作需 10 银"}
	silver -= 10
	holdings[hid]["focus"] = focus
	holdings[hid]["focus_cd"] = 2
	var cn = {"grain": "粮作", "cash": "钱作", "fortify": "戍卫"}.get(focus, focus)
	log_event("%s 改作 → %s" % [HOLDING_DEFS[hid].name, cn])
	add_lineage_event("属地改作：%s→%s" % [HOLDING_DEFS[hid].name, cn])
	mark_dirty()
	return {"ok": true, "msg": "%s 改为「%s」（月结结构变化；冷却2月）" % [HOLDING_DEFS[hid].name, cn]}

func start_caravan(kind: String) -> Dictionary:
	## 陆桥商队：投资上路，月结检定，到期交割
	if int(caravan.get("turns_left", 0)) > 0:
		return {"ok": false, "msg": "已有商队在途"}
	if kind not in ["grain", "iron", "spice"]:
		return {"ok": false, "msg": "航线：grain/iron/spice"}
	var cost = {"grain": 35, "iron": 45, "spice": 55}.get(kind, 40)
	if silver < cost:
		return {"ok": false, "msg": "需 %d 银上路" % cost}
	silver -= cost
	caravan = {"kind": kind, "turns_left": 3, "invested": cost}
	house_mods["caravan_active"] = true
	var cn = {"grain": "粮运", "iron": "铁运", "spice": "香料险运"}.get(kind, kind)
	log_event("商队出发：%s（投资%d）" % [cn, cost])
	add_lineage_event("陆桥商队：%s 上路" % cn)
	mark_dirty()
	return {"ok": true, "msg": "商队「%s」上路，约 3 月交割（途中有劫险）" % cn}


func escort_caravan() -> Dictionary:
	## 商队护运：花银买平安——中长环真决策
	if int(caravan.get("turns_left", 0)) <= 0:
		return {"ok": false, "msg": "无在途商队"}
	if bool(caravan.get("escorted", false)):
		return {"ok": false, "msg": "已雇护运"}
	if silver < 12:
		return {"ok": false, "msg": "护运需 12 银"}
	silver -= 12
	caravan["escorted"] = true
	add_lineage_event("商队护运：花 12 银买路平安")
	mark_dirty()
	return {"ok": true, "msg": "护运已雇：途中遇劫大降"}

func tick_caravan_month() -> Array:
	var msgs: Array = []
	# focus cd tick
	for hid in holdings.keys():
		var cd = int(holdings[hid].get("focus_cd", 0))
		if cd > 0:
			holdings[hid]["focus_cd"] = cd - 1
	if int(caravan.get("turns_left", 0)) <= 0:
		return msgs
	caravan["turns_left"] = int(caravan["turns_left"]) - 1
	var kind = str(caravan.get("kind", "grain"))
	var invested = int(caravan.get("invested", 40))
	# mid risk
	var raid = 0.12
	if bool(house_mods.get("trade_route", false)):
		raid *= 0.6
	if bool(house_mods.get("market_edge", false)):
		raid *= 0.75
	if alliance_duty_months > 0:
		raid *= 0.7  # 义役护路
	if bool(caravan.get("escorted", false)):
		raid *= 0.25
	if rng.randf() < raid:
		var loss = int(invested * 0.45)
		silver = maxi(0, silver - loss)
		msgs.append("商队遇劫：损银 %d（航线仍在）" % loss)
		add_lineage_event(msgs[-1])
		morale = maxi(0, morale - 2)
	else:
		msgs.append("商队平安过月：余 %d 月" % int(caravan["turns_left"]))
	if int(caravan["turns_left"]) <= 0:
		var payout = int(invested * {"grain": 1.7, "iron": 1.9, "spice": 2.3}.get(kind, 1.8))
		silver += payout
		if kind == "grain":
			food += 8
		elif kind == "iron":
			iron += 4
		elif kind == "spice":
			herb += 3
			add_rep("riverland", 1)
		msgs.append("商队交割：收回约 %d 银并卸货" % payout)
		add_lineage_event(msgs[-1])
		caravan = {}
		house_mods.erase("caravan_active")
	mark_dirty()
	return msgs

func start_alliance_duty() -> Dictionary:
	## 联姻义役：6 月每月付 5 银，换护路+声望+士气
	if alliance_duty_months > 0:
		return {"ok": false, "msg": "义役进行中（余%d月）" % alliance_duty_months}
	var leader = get_leader()
	if leader == null or leader.spouse_id == "":
		return {"ok": false, "msg": "需先联姻"}
	alliance_duty_months = 6
	house_mods["alliance_duty"] = true
	add_lineage_event("联姻义役：六个月护路共济")
	mark_dirty()
	return {"ok": true, "msg": "义役起誓：每月 5 银，护商路、升声望（共 6 月）"}

func tick_alliance_duty_month() -> Array:
	var msgs: Array = []
	if alliance_duty_months <= 0:
		return msgs
	if silver >= 5:
		silver -= 5
		morale = mini(100, morale + 1)
		add_rep("ashland", 1)
		msgs.append("联姻义役：付 5 银 → 士气+1 声望+（余%d月）" % (alliance_duty_months - 1))
	else:
		morale = maxi(0, morale - 3)
		msgs.append("联姻义役欠缴：士气-3（余%d月）" % (alliance_duty_months - 1))
		add_lineage_event("义役欠缴")
	alliance_duty_months -= 1
	if alliance_duty_months <= 0:
		house_mods.erase("alliance_duty")
		house_mods["alliance_duty_done"] = true
		add_rep("riverland", 2)
		msgs.append("义役圆满：河卫声望+2，商路更稳")
		add_lineage_event(msgs[-1])
	mark_dirty()
	return msgs

func holding_yield_preview(hid: String) -> Dictionary:
	var def = HOLDING_DEFS.get(hid, {})
	var lv = maxi(1, holding_level(hid))
	var mul = lv
	var st = steward_of(hid)
	var trait_bonus = 0
	if st != null:
		mul += 1  # 庄头加成一档产出
		# 能干庄头：指挥/技术高或正面禀性再加产
		if int(st.stats.get("ldr", 0)) >= 12 or int(st.stats.get("skl", 0)) >= 12:
			trait_bonus += 1
		for tr in st.traits:
			if str(tr) in ["diligent", "iron_gut", "brave", "shrewd", "loyal"]:
				trait_bonus += 1
				break
		mul += trait_bonus
	if bool(house_mods.get("estate_bonus", false)):
		mul += 1  # 四野旗庄：属地月结+1成
	if bool(house_mods.get("estate_patrol", false)):
		mul += 0  # 巡逻主要抗劫，产出在 monthly 另记
	var food_v = int(def.get("food", 0)) * mul
	var sil_v = int(def.get("silver", 0)) * mul
	var herb_v = int(def.get("herb", 0)) * mul
	var focus = holding_focus(hid)
	if focus == "grain":
		food_v = int(food_v * 1.5)
		sil_v = int(sil_v * 0.75)
	elif focus == "cash":
		sil_v = int(sil_v * 1.5)
		food_v = int(food_v * 0.75)
	elif focus == "fortify":
		food_v = int(food_v * 0.8)
		sil_v = int(sil_v * 0.8)
		herb_v = int(herb_v * 0.8)
	return {
		"food": food_v,
		"silver": sil_v,
		"herb": herb_v,
		"rep": int(def.get("rep", 0)) * mul,
		"steward": st != null,
		"trait_bonus": trait_bonus,
		"focus": focus,
	}

func holdings_monthly_yield() -> String:
	if holdings.is_empty():
		return ""
	var sf = 0
	var ss = 0
	var sh = 0
	var sr = 0
	var names: Array = []
	var raids: Array = []
	for hid in holdings.keys():
		var def = HOLDING_DEFS.get(hid, {})
		var pv = holding_yield_preview(hid)
		# 劫掠检定：无庄头且士气偏低时有风险
		var st = steward_of(hid)
		var raid_chance = 0.0
		if st == null:
			raid_chance = 0.28 if morale < 55 else 0.08
		else:
			# 庄头抗劫：基础很低；忠勇/精干更低
			raid_chance = 0.03
			if int(st.stats.get("ldr", 0)) >= 12:
				raid_chance *= 0.5
			if "loyal" in st.traits or "brave" in st.traits:
				raid_chance *= 0.5
		if bool(house_mods.get("estate_patrol", false)):
			raid_chance *= 0.35
		if holding_focus(hid) == "fortify":
			raid_chance *= 0.4
		if patrol_boost_months > 0:
			raid_chance *= 0.25  # 全堡巡防期
		if holding_patrol_boost(hid) > 0:
			raid_chance *= 0.3  # 本属地巡防路线
		if raid_chance > 0.0 and rng.randf() < raid_chance:
			raids.append(str(def.get("name", hid)))
			continue  # 本月无收成
		sf += int(pv.food)
		ss += int(pv.silver)
		sh += int(pv.herb)
		sr += int(pv.rep)
		var tag = "庄" if st else ""
		names.append("%sLv%d%s" % [def.get("name", hid), holding_level(hid), tag])
	food += sf
	silver += ss
	herb += sh
	if sr > 0:
		add_rep("ashland", sr)
		add_rep("riverland", maxi(0, sr - 1))
	var msg = "属地收成：%s → 粮+%d 银+%d%s" % ["、".join(names) if names else "无", sf, ss, (" 药+%d" % sh) if sh else ""]
	if raids:
		msg += "；劫掠：%s（无庄头/士气不稳）" % "、".join(raids)
		morale = maxi(0, morale - 3 * raids.size())
		add_lineage_event("属地劫掠：" + "、".join(raids))
		estate_quiet_months = 0
	elif not holdings.is_empty():
		estate_quiet_months += 1
		if estate_quiet_months >= 3:
			msg += "；四野安静（连续%d月无劫）" % estate_quiet_months
			# 戍卫偏向属地：安静期微加银（中长经营反馈）
			var fort_n = 0
			for hid2 in holdings.keys():
				if holding_focus(hid2) == "fortify":
					fort_n += 1
			if fort_n > 0 and estate_quiet_months % 3 == 0:
				var bonus = fort_n
				silver += bonus
				msg += "；戍卫安境银+%d" % bonus
	return msg

func unlocked_holdings_count() -> int:
	return holdings.size()

func total_holding_levels() -> int:
	var n = 0
	for hid in holdings.keys():
		n += holding_level(hid)
	return n

func ambition_list() -> Array:
	## UI：列出堡志与完成状态
	return [
		{"id": "fort_tier3", "name": "灰旗威仪", "desc": "全部工事达到 Lv3", "done": bool(ambition_done.get("fort_tier3", false)), "reward": "战技点+2，丰收声望"},
		{"id": "fort_tier5", "name": "百年旗堡", "desc": "全部工事达到 Lv5", "done": bool(ambition_done.get("fort_tier5", false)), "reward": "战技点+3，月结旗堡俸"},
		{"id": "warlord", "name": "陆桥战勋", "desc": "战棋委任首通累计 5 次", "done": bool(ambition_done.get("warlord", false)), "reward": "战技点+1，开战银+10"},
		{"id": "warlord_x", "name": "百战旗影", "desc": "战棋委任首通累计 10 次", "done": bool(ambition_done.get("warlord_x", false)), "reward": "战技点+2，开战银再+10"},
		{"id": "heirs_two", "name": "双嗣承旗", "desc": "至少两名子嗣授旗入队", "done": bool(ambition_done.get("heirs_two", false)), "reward": "声望+8，战技点+1"},
		{"id": "vow_house", "name": "家训既立", "desc": "完成联姻誓约并选定家训", "done": bool(ambition_done.get("vow_house", false)), "reward": "家训永久生效"},
		{"id": "estate_two", "name": "两岸租佃", "desc": "解锁至少 2 处属地", "done": bool(ambition_done.get("estate_two", false)), "reward": "战技点+1，银+40"},
		{"id": "estate_all", "name": "四野旗庄", "desc": "解锁全部 4 处属地", "done": bool(ambition_done.get("estate_all", false)), "reward": "战技点+2，属地月结+1成"},
		{"id": "estate_deep", "name": "深耕三稔", "desc": "属地总等级合计 ≥ 8", "done": bool(ambition_done.get("estate_deep", false)), "reward": "战技点+1，粮+30"},
		{"id": "silver_hoard", "name": "库银盈柜", "desc": "银币一度达到 300", "done": bool(ambition_done.get("silver_hoard", false)), "reward": "战技点+1，市集永久微利"},
		{"id": "roster_six", "name": "六旗同升", "desc": "花名册满员达 6 人", "done": bool(ambition_done.get("roster_six", false)), "reward": "战技点+1，士气+10"},
		{"id": "skill_adept", "name": "战技通识", "desc": "任意一人解锁 3 个二阶及以上战技", "done": bool(ambition_done.get("skill_adept", false)), "reward": "战技点+2"},
		{"id": "estate_steward", "name": "庄头遍野", "desc": "至少 2 处属地派驻庄头", "done": bool(ambition_done.get("estate_steward", false)), "reward": "战技点+1，士气+5"},
		{"id": "estate_patrol", "name": "四野巡防", "desc": "属地连续 3 月无劫掠（须已开垦）", "done": bool(ambition_done.get("estate_patrol", false)), "reward": "战技点+1，属地抗劫强化"},
		{"id": "doctrine_year", "name": "家训周岁", "desc": "立家训后度过 12 个月", "done": bool(ambition_done.get("doctrine_year", false)), "reward": "家训月结翻倍一个月记"},
		{"id": "forge_fine", "name": "精刃满匣", "desc": "花名册至少 3 人持精灰刃", "done": bool(ambition_done.get("forge_fine", false)), "reward": "战技点+1，铁+4"},
	]

func check_ambitions() -> Array:
	var msgs: Array = []
	if not bool(ambition_done.get("fort_tier3", false)) and _all_buildings_at_least(3):
		ambition_done["fort_tier3"] = true
		house_mods["ash_prestige"] = true
		add_skill_point(2)
		msgs.append("堡志「灰旗威仪」达成：战技点+2")
		add_lineage_event("堡志：灰旗威仪")
	if not bool(ambition_done.get("fort_tier5", false)) and _all_buildings_at_least(5):
		ambition_done["fort_tier5"] = true
		house_mods["century_fort"] = true
		add_skill_point(3)
		silver += 80
		msgs.append("堡志「百年旗堡」达成：战技点+3，银+80")
		add_lineage_event("堡志：百年旗堡")
	if not bool(ambition_done.get("warlord", false)) and int(house_mods.get("war_memory", 0)) >= 5:
		ambition_done["warlord"] = true
		house_mods["warlord_purse"] = true
		add_skill_point(1)
		msgs.append("堡志「陆桥战勋」达成：战技点+1")
		add_lineage_event("堡志：陆桥战勋")
	if not bool(ambition_done.get("heirs_two", false)) and _enlisted_children_count() >= 2:
		ambition_done["heirs_two"] = true
		add_rep("ashland", 8)
		add_skill_point(1)
		msgs.append("堡志「双嗣承旗」达成：声望与战技点")
		add_lineage_event("堡志：双嗣承旗")
	if not bool(ambition_done.get("vow_house", false)) and str(house_mods.get("doctrine", "")) != "":
		ambition_done["vow_house"] = true
		msgs.append("堡志「家训既立」达成")
		add_lineage_event("堡志：家训既立·%s" % house_mods.get("doctrine", ""))
	if not bool(ambition_done.get("warlord_x", false)) and int(house_mods.get("war_memory", 0)) >= 10:
		ambition_done["warlord_x"] = true
		house_mods["warlord_purse"] = true
		house_mods["warlord_purse2"] = true
		add_skill_point(2)
		msgs.append("堡志「百战旗影」达成：战技点+2")
		add_lineage_event("堡志：百战旗影")
	if not bool(ambition_done.get("estate_two", false)) and unlocked_holdings_count() >= 2:
		ambition_done["estate_two"] = true
		add_skill_point(1)
		silver += 40
		msgs.append("堡志「两岸租佃」达成：银+40，战技点+1")
		add_lineage_event("堡志：两岸租佃")
	if not bool(ambition_done.get("estate_all", false)) and unlocked_holdings_count() >= 4:
		ambition_done["estate_all"] = true
		house_mods["estate_bonus"] = true
		add_skill_point(2)
		msgs.append("堡志「四野旗庄」达成：属地月结增强")
		add_lineage_event("堡志：四野旗庄")
	if not bool(ambition_done.get("estate_deep", false)) and total_holding_levels() >= 8:
		ambition_done["estate_deep"] = true
		add_skill_point(1)
		food += 30
		msgs.append("堡志「深耕三稔」达成：粮+30")
		add_lineage_event("堡志：深耕三稔")
	if not bool(ambition_done.get("silver_hoard", false)) and silver >= 300:
		ambition_done["silver_hoard"] = true
		house_mods["market_edge"] = true
		add_skill_point(1)
		msgs.append("堡志「库银盈柜」达成：市集微利")
		add_lineage_event("堡志：库银盈柜")
	if not bool(ambition_done.get("roster_six", false)) and roster().size() >= 6:
		ambition_done["roster_six"] = true
		add_skill_point(1)
		morale = mini(100, morale + 10)
		msgs.append("堡志「六旗同升」达成")
		add_lineage_event("堡志：六旗同升")
	if not bool(ambition_done.get("skill_adept", false)):
		for c in roster():
			var n2 = 0
			for sid in c.unlocked_skills:
				var sk = get_skill(sid)
				if int(sk.get("tier", 1)) >= 2:
					n2 += 1
			if n2 >= 3:
				ambition_done["skill_adept"] = true
				add_skill_point(2)
				msgs.append("堡志「战技通识」达成：%s" % c.name)
				add_lineage_event("堡志：战技通识·%s" % c.name)
				break
	if not bool(ambition_done.get("estate_steward", false)):
		var sc = 0
		for hid in holdings.keys():
			if str(holdings[hid].get("steward_id", "")) != "":
				sc += 1
		if sc >= 2:
			ambition_done["estate_steward"] = true
			add_skill_point(1)
			morale = mini(100, morale + 5)
			msgs.append("堡志「庄头遍野」达成")
			add_lineage_event("堡志：庄头遍野")
	if not bool(ambition_done.get("estate_patrol", false)) and estate_quiet_months >= 3 and not holdings.is_empty():
		ambition_done["estate_patrol"] = true
		house_mods["estate_patrol"] = true
		add_skill_point(1)
		morale = mini(100, morale + 4)
		msgs.append("堡志「四野巡防」达成：属地抗劫强化")
		add_lineage_event("堡志：四野巡防")
	if not bool(ambition_done.get("doctrine_year", false)) and doctrine_months >= 12:
		ambition_done["doctrine_year"] = true
		house_mods["doctrine_mature"] = true
		add_skill_point(1)
		msgs.append("堡志「家训周岁」达成：家训月结增强")
		add_lineage_event("堡志：家训周岁")
	if not bool(ambition_done.get("forge_fine", false)):
		var nf = 0
		for c in roster():
			if c.weapon_id == "ash_blade_fine":
				nf += 1
		if nf >= 3:
			ambition_done["forge_fine"] = true
			add_skill_point(1)
			iron += 4
			msgs.append("堡志「精刃满匣」达成")
			add_lineage_event("堡志：精刃满匣")
	if msgs:
		mark_dirty()
	return msgs

func upgrade_building(id: String) -> Dictionary:
	if id not in BUILDING_NAMES:
		return {"ok": false, "msg": "无此工事"}
	var lv = building_level(id)
	if lv >= BUILDING_MAX:
		return {"ok": false, "msg": "%s 已至满级" % BUILDING_NAMES[id]}
	var next_lv = lv + 1
	var cost: Dictionary = BUILDING_COST.get(next_lv, {})
	var need_s = int(cost.get("silver", 0))
	var need_i = int(cost.get("iron", 0))
	var need_f = int(cost.get("food", 0))
	if bool(house_mods.get("hall_discount", false)) and id == "hall":
		need_s = int(need_s * 0.75)
	if silver < need_s or iron < need_i or food < need_f:
		return {"ok": false, "msg": "不足：需 %d银/%d铁/%d粮" % [need_s, need_i, need_f]}
	silver -= need_s
	iron -= need_i
	food -= need_f
	buildings[id] = next_lv
	if id == "shrine":
		shrine_level = next_lv
	var fx = ""
	match id:
		"hall":
			fx = "出战编队上限 → %d" % max_deploy()
			if next_lv >= 4:
				fx += "；月结厅堂津贴"
		"barracks":
			fx = "演武花费 → %d 银；月结士气" % train_cost()
			if next_lv >= 4:
				fx += "；演武双加更易"
		"market":
			fx = "市集买卖价改善"
			if next_lv >= 4:
				fx += "；月结商税"
		"forge":
			fx = "打造更省料"
			if next_lv >= 4:
				fx += "；精灰刃"
		"shrine":
			fx = "丰收与祈愈增强"
			if next_lv >= 4:
				fx += "；月结微愈"
	log_event("工事升级：%s → Lv%d（%s）" % [BUILDING_NAMES[id], next_lv, fx])
	var amb = check_ambitions()
	var amb_s = ("；" + " / ".join(amb)) if amb else ""
	mark_dirty()
	return {"ok": true, "msg": "%s 升至 Lv%d。%s%s" % [BUILDING_NAMES[id], next_lv, fx, amb_s]}

func building_summary() -> String:
	var parts: Array = []
	for id in ["hall", "barracks", "market", "forge", "shrine"]:
		parts.append("%s Lv%d" % [BUILDING_NAMES[id], building_level(id)])
	return " · ".join(parts)

func accept_quest(qid: String) -> Dictionary:
	var q = null
	for item in quests:
		if item["id"] == qid:
			q = item
			break
	if q == null:
		return {"ok": false, "msg": "任务不存在"}
	if q.get("battle", false):
		if q.get("map"):
			set_meta("battle_map", str(q.get("map")))
		set_meta("active_quest_id", qid)
		return {"ok": true, "battle": true, "quest": q}
	# 自动任务
	var evs = Calendar.advance(int(q.get("months", 1)))
	silver += int(q["silver"])
	add_rep("ashland", int(q["rep"]))
	if str(q.get("id", "")) == "q_herb":
		herb += 2
	if str(q.get("id", "")) == "q_drill":
		morale = mini(100, morale + 3 + building_level("barracks"))
	if str(q.get("id", "")) == "q_bridge":
		add_rep("riverland", 4)
	for c in roster():
		c.exp += 8 * int(q["stars"])
		settle_exp(c)
	var first = apply_quest_first_clear(qid)
	log_event("完成任务「%s」+ %d 银%s" % [q["name"], q["silver"], ("；" + first) if first else ""])
	mark_dirty()
	return {"ok": true, "battle": false, "quest": q, "events": evs, "first_clear": first}

func apply_quest_first_clear(qid: String) -> String:
	if bool(quest_done.get(qid, false)):
		return ""
	quest_done[qid] = true
	var msg := ""
	match qid:
		"q_escort":
			house_mods["hall_discount"] = true
			var uh = unlock_holding("reed_ford")
			msg = "首通：议事厅升级费用 -25%" + (("；" + uh) if uh else "")
		"q_bridge":
			house_mods["trade_route"] = true
			var uh2 = unlock_holding("tide_bridge")
			msg = "首通：开通河卫商路（市集更划算，丰收+银）" + (("；" + uh2) if uh2 else "")
		"q_drill":
			house_mods["drill_discount"] = true
			msg = "首通：校场演武再减价"
		"q_rumor":
			house_mods["spring_insight"] = true
			add_skill_point(1)
			msg = "首通：春令耳目 +1 战技点"
		"q_herb":
			house_mods["herb_garden"] = true
			var uh3 = unlock_holding("fog_vale")
			msg = "首通：雾谷药圃（丰收+药）" + (("；" + uh3) if uh3 else "")
		"q_bandit":
			house_mods["war_memory"] = int(house_mods.get("war_memory", 0)) + 1
			morale = mini(100, morale + 2)
			var uh4 = unlock_holding("stone_slope")
			msg = "首通战勋：士气+2" + (("；" + uh4) if uh4 else "")
		"q_hill_war", "q_ford_war", "q_fog_war", "q_forge_war", "q_shrine_war":
			house_mods["war_memory"] = int(house_mods.get("war_memory", 0)) + 1
			morale = mini(100, morale + 2)
			msg = "首通战勋：士气+2，战勋记 %d" % int(house_mods["war_memory"])
		_:
			msg = "首通记入陆桥簿"
	if msg != "":
		add_lineage_event("委任首通：「%s」——%s" % [qid, msg])
	for am in check_ambitions():
		if msg:
			msg += "；" + am
		else:
			msg = am
	return msg

func on_battle_quest_victory() -> void:
	var qid = str(get_meta("active_quest_id", ""))
	if qid == "":
		return
	var first = apply_quest_first_clear(qid)
	if first:
		log_event(first)
	remove_meta("active_quest_id")

func tick_doctrine_and_marriage_month() -> Array:
	var msgs: Array = []
	tick_patrol_month()
	if patrol_boost_months > 0:
		msgs.append("巡防仍在：抗劫剩余 %d 月" % patrol_boost_months)
	var doctrine = str(house_mods.get("doctrine", ""))
	if doctrine != "":
		doctrine_months += 1
		var mul = 2 if bool(house_mods.get("doctrine_mature", false)) else 1
		match doctrine:
			"strict":
				morale = mini(100, morale + 1 * mul)
				msgs.append("家训·严教：士气+%d（第 %d 月）" % [1 * mul, doctrine_months])
			"mercy":
				food += 1 * mul
				morale = mini(100, morale + 1 * mul)
				msgs.append("家训·仁恤：粮+%d 士气+%d（第 %d 月）" % [1 * mul, 1 * mul, doctrine_months])
			"trade", "commerce":
				silver += 2 * mul
				msgs.append("家训·商本：银+%d（第 %d 月）" % [2 * mul, doctrine_months])
			_:
				msgs.append("家训仍在：第 %d 月" % doctrine_months)
		var amb = check_ambitions()
		for a in amb:
			msgs.append(a)
	# 联姻月结：配偶在花名册则微升士气/声望
	var leader = get_leader()
	if leader and leader.spouse_id != "" and characters.has(leader.spouse_id):
		var sp: CKCharacter = characters[leader.spouse_id]
		if sp.alive:
			morale = mini(100, morale + 1)
			if sp.in_roster:
				silver += 1
				msgs.append("联姻月结：%s 同席 → 士气+1 银+1" % sp.name)
			else:
				msgs.append("联姻月结：%s 守堡 → 士气+1" % sp.name)
			add_lineage_event(msgs[-1] if msgs else "联姻月结")
	# 血胤月泽：子嗣/配偶血胤浓度带来永久感的微收益
	var blood_bonus = 0
	for c in characters.values():
		if not c.alive:
			continue
		if c.is_child or c.spouse_id != "" or c.is_leader:
			for bk in c.blood_mix.keys():
				if float(c.blood_mix[bk]) >= 0.45:
					blood_bonus += 1
					break
	if blood_bonus > 0:
		var gain = mini(3, blood_bonus)
		silver += gain
		msgs.append("血胤月泽：族谱浓度 → 银+%d" % gain)
		if blood_bonus >= 3:
			morale = mini(100, morale + 1)
	for m in tick_caravan_month():
		msgs.append(m)
	for m2 in tick_alliance_duty_month():
		msgs.append(m2)
	mark_dirty()
	return msgs

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

func apply_monthly_upkeep() -> String:
	var wage = 0
	var mouths = 0
	for c in characters.values():
		if not c.alive:
			continue
		if c.in_roster:
			wage += c.salary
			mouths += 1
		elif c.is_child:
			mouths += 1
	silver -= wage
	var food_need = maxi(1, mouths)
	food -= food_need
	# A century of harvests with no sink became a grain ocean. Surplus above two years of rations spoils.
	var granary := maxi(120, mouths * 24)
	if food > granary:
		food = granary + int(float(food - granary) * 0.82)
	var msg = "月结：工资 -%d 银，粮 -%d" % [wage, food_need]
	if silver < 0:
		morale = maxi(0, morale - 15)
		msg += "；银币见红，士气下降"
		silver = 0
	if food < 0:
		morale = maxi(0, morale - 20)
		food = 0
		msg += "；缺粮，士气大降"
		# 儿童负面
		for c in characters.values():
			if c.is_child and c.alive and rng.randf() < 0.4:
				if "malnourished" not in c.traits:
					c.traits.append("malnourished")
					log_event("%s 因缺粮获得「营养不良」" % c.name)
	elif food >= 10 and morale < 90:
		morale = mini(100, morale + 2)
	# 校场常训
	if building_level("barracks") >= 2:
		morale = mini(100, morale + building_level("barracks") - 1)
		msg += "；校场鼓点士气+%d" % (building_level("barracks") - 1)
	# 退役顾问暗助
	for k in advisor_bonus.keys():
		var leader = get_leader()
		if leader and k in CKCharacter.STAT_KEYS and rng.randf() < 0.15:
			leader.stats[k] = mini(int(leader.apt_max.get(k, 20)), int(leader.stats[k]) + 1)
			msg += "；顾问指点 %s+1" % Locale.t("stat_" + k)
			leader.recalc_hp()
			break
	return msg

func apply_harvest() -> String:
	shrine_level = building_level("shrine")
	var prod = 22 + shrine_level * 6 + building_level("hall") * 2
	food += prod
	var sil = 22 + building_level("market") * 6
	if bool(house_mods.get("trade_route", false)):
		sil += 10
	if bool(house_mods.get("vow_trade", false)):
		sil += 8
	silver += sil
	var extra := ""
	if bool(house_mods.get("herb_garden", false)):
		herb += 1
		extra += "，药+1"
	if bool(house_mods.get("vow_banner", false)):
		add_rep("ashland", 2)
		extra += "，旗饰声望+2"
	if bool(house_mods.get("ash_prestige", false)):
		add_rep("ashland", 2)
		extra += "，威仪声望+2"
	if bool(house_mods.get("century_fort", false)):
		silver += 12
		extra += "，旗堡+12银"
	var msg = "丰收结算：+%d 粮，+%d 银（祠堂 Lv%d / 厅 Lv%d）%s" % [prod, sil, shrine_level, building_level("hall"), extra]
	log_event(msg)
	for c in roster():
		if c.injured:
			c.injured = false
			log_event("祠堂治愈 %s 的临时伤" % c.name)
	return msg

func heal_at_shrine() -> String:
	var n = 0
	for c in roster():
		if c.injured or c.hp < c.max_hp:
			c.injured = false
			c.hp = c.max_hp
			n += 1
	log_event("祠堂祈愈：%d 人康复" % n)
	mark_dirty()
	return "已清临时伤并回满生命（%d 人）" % n

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

func train(cid: String) -> Dictionary:
	var c: CKCharacter = characters.get(cid)
	if c == null:
		return {"ok": false, "msg": "无此人"}
	var cost = train_cost()
	if silver < cost:
		return {"ok": false, "msg": Locale.t("not_enough_silver")}
	silver -= cost
	Calendar.advance(1)
	var key = CKCharacter.STAT_KEYS[rng.randi() % CKCharacter.STAT_KEYS.size()]
	# 顾问偏向
	if not advisor_bonus.is_empty() and rng.randf() < 0.35:
		key = str(advisor_bonus.keys()[0])
	var gain = 1
	if building_level("barracks") >= 3 and rng.randf() < (0.5 if building_level("barracks") >= 4 else 0.35):
		gain = 2
	c.stats[key] = mini(int(c.apt_max.get(key, 20)), int(c.stats[key]) + gain)
	if rng.randf() < 0.25:
		var all_t = data_traits.get("traits", [])
		var t = all_t[rng.randi() % all_t.size()]
		if t["id"] not in c.traits and t.get("polarity") == "pos":
			c.traits.append(t["id"])
			log_event("%s 训练领悟禀性「%s」" % [c.name, t["name"]])
	c.recalc_hp()
	mark_dirty()
	return {"ok": true, "msg": "%s 的%s +%d（花费 %d 银）" % [c.name, Locale.t("stat_" + key), gain, cost]}

func craft_weapon(cid: String) -> Dictionary:
	var cost = forge_craft_cost()
	if iron < int(cost.iron) or silver < int(cost.silver):
		return {"ok": false, "msg": "需要 %d 铁与 %d 银" % [cost.iron, cost.silver]}
	var c: CKCharacter = characters.get(cid)
	if c == null:
		return {"ok": false, "msg": "选择角色"}
	iron -= int(cost.iron)
	silver -= int(cost.silver)
	if World.is_world_item(c.weapon_id):  # v8.7: a world weapon goes back to the armory, not the scrap heap
		World.armory[c.weapon_id] = int(World.armory.get(c.weapon_id, 0)) + 1
	c.weapon_id = "ash_blade_fine" if building_level("forge") >= 4 else "ash_blade"
	# 负重检查（简化）
	var burden = 4
	var cap = 5 + int(c.stats.get("vit", 8) / 2)
	var warn = ""
	if burden > cap:
		warn = "（负重超限警告）"
	log_event("%s 装备灰刃%s" % [c.name, warn])
	mark_dirty()
	return {"ok": true, "msg": "打造完成：灰刃 +2 攻" + warn}

func market_buy(item: String, qty: int = 1) -> Dictionary:
	var prices = market_buy_prices()
	if item not in prices:
		return {"ok": false, "msg": "无此物资"}
	var cost = prices[item] * qty
	if silver < cost:
		return {"ok": false, "msg": Locale.t("not_enough_silver")}
	silver -= cost
	set(item, int(get(item)) + qty)
	mark_dirty()
	return {"ok": true, "msg": "购入 %s x%d" % [Locale.t(item), qty]}

func market_sell(item: String, qty: int = 1) -> Dictionary:
	var prices = market_sell_prices()
	if int(get(item)) < qty:
		return {"ok": false, "msg": "库存不足"}
	set(item, int(get(item)) - qty)
	silver += prices[item] * qty
	mark_dirty()
	return {"ok": true, "msg": "卖出 %s x%d" % [Locale.t(item), qty]}

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


func get_skill(sid: String) -> Dictionary:
	for s in data_skills.get("skills", []):
		if s.get("id") == sid:
			return s
	return {"id": sid, "name": sid}

func skills_for_job(job_id: String) -> Array:
	var out: Array = []
	for s in data_skills.get("skills", []):
		var jobs: Array = s.get("jobs", [])
		if job_id in jobs:
			out.append(s)
	return out


func battle_difficulty_from_map(map_id: String) -> int:
	## 0=教学 1=前中期 2=中期 3=后期 4=终局/精锐图
	var mid = map_id.to_lower()
	if mid.begins_with("ch0") or mid.find("tutorial") >= 0:
		return 0
	var ch := 0
	# ch12_foo / ch_heir → parse leading digits after ch
	var i = 0
	if mid.begins_with("ch"):
		var num = ""
		for j in range(2, mini(mid.length(), 5)):
			var chs = mid.substr(j, 1)
			if chs.is_valid_int():
				num += chs
			else:
				break
		if num != "":
			ch = int(num)
	if mid.find("heir") >= 0 or mid.find("boss") >= 0 or mid.find("bloodseal") >= 0:
		return maxi(ch / 3, 3)
	if ch <= 0:
		return 1
	if ch <= 2:
		return 1
	if ch <= 4:
		return 2
	if ch <= 6:
		return 3
	return 4

func enemy_skill_table_for(map_id: String) -> Dictionary:
	var root = data_enemy_skills.get("maps", data_enemy_skills)
	if root.has(map_id):
		return root[map_id]
	# chapter wildcard: ch5_* → try nothing; fall to diff defaults
	return {}

func _grant_theme_skill(c: CKCharacter, elite: bool, template_id: String, granted: Array) -> void:
	if not elite or template_id == "":
		return
	var sid := CKTacticsAI.theme_skill(str(UnitModel.parse_enemy_template(template_id).get("theme", "")))
	if sid != "" and not (sid in granted):
		granted.append(sid)

func _apply_skill_list(c: CKCharacter, sids: Array) -> void:
	for sid in sids:
		var id = str(sid)
		if id == "":
			continue
		var sk = get_skill(id)
		if sk.is_empty():
			continue
		if id not in c.skills:
			c.skills.append(id)
		if id not in c.unlocked_skills:
			c.unlocked_skills.append(id)

func _skills_from_table_entry(entry) -> Array:
	# by_template 值可以是 Array 或 {skills, elite_skills}
	if typeof(entry) == TYPE_ARRAY:
		return entry
	if typeof(entry) == TYPE_DICTIONARY:
		return entry.get("skills", [])
	return []

func _elite_from_table_entry(entry) -> Array:
	if typeof(entry) == TYPE_DICTIONARY:
		return entry.get("elite_skills", [])
	return []

func grant_battle_enemy_skills(c: CKCharacter, elite: bool = false, difficulty: int = 1, map_id: String = "", template_id: String = "") -> void:
	## 优先 per-map 表 / 全局 _by_template；再回退难度曲线
	grant_job_skills(c)
	var root = data_enemy_skills.get("maps", data_enemy_skills)
	var table = enemy_skill_table_for(map_id) if map_id != "" else {}
	var granted: Array = []
	var used_table := false
	if not table.is_empty():
		used_table = true
		var by_t: Dictionary = table.get("by_template", {})
		if template_id != "" and by_t.has(template_id):
			var entry = by_t[template_id]
			granted.append_array(_skills_from_table_entry(entry))
			if elite:
				granted.append_array(_elite_from_table_entry(entry))
		else:
			granted.append_array(table.get("default", []))
		if elite:
			granted.append_array(table.get("elite", []))
	# 全局模板表补全（地图未写到的模板）
	if template_id != "" and granted.is_empty():
		var glob: Dictionary = root.get("_by_template", {})
		if glob.has(template_id):
			used_table = true
			var gentry = glob[template_id]
			granted.append_array(_skills_from_table_entry(gentry))
			if elite:
				granted.append_array(_elite_from_table_entry(gentry))
		if used_table:
			_grant_theme_skill(c, elite, template_id, granted)
			_apply_skill_list(c, granted)
			return
	# 回退：_defaults by diff
	var defaults = root.get("_defaults", {})
	var key = "diff_%d" % clampi(difficulty, 0, 4)
	var dtab: Dictionary = defaults.get(key, {})
	if not dtab.is_empty():
		var granted2: Array = []
		granted2.append_array(dtab.get("default", []))
		if elite:
			granted2.append_array(dtab.get("elite", []))
		_grant_theme_skill(c, elite, template_id, granted2)
		_apply_skill_list(c, granted2)
		return
	# 最终回退：旧曲线（稳定选取）
	if difficulty <= 0 and not elite:
		return
	var t2: Array = []
	var t3: Array = []
	for s in skills_for_job(c.job_id):
		var tier = int(s.get("tier", 1))
		var sid = str(s.get("id"))
		if tier == 2:
			t2.append(sid)
		elif tier >= 3:
			t3.append(sid)
	for sid in ["lock_breaker", "terrain_ward", "anchor_guard", "disengage_step"]:
		var sk = get_skill(sid)
		if sk.is_empty():
			continue
		var jobs = sk.get("jobs", [])
		if (jobs.is_empty() or c.job_id in jobs) and sid not in t2 and int(sk.get("tier", 1)) == 2:
			t2.append(sid)
	var need_t2 := 0
	var need_t3 := 0
	match difficulty:
		0:
			need_t2 = 1 if elite else 0
		1:
			need_t2 = 1 if elite else 0
		2:
			need_t2 = 1
			need_t3 = 1 if elite else 0
		3:
			need_t2 = 2
			need_t3 = 1 if elite else 0
		_:
			need_t2 = 2
			need_t3 = 2 if elite else 1
	t2.sort()
	t3.sort()
	var salt = abs(hash(c.id)) % 7
	if t2.size() > 0:
		var start = salt % t2.size()
		for k in need_t2:
			var sid2 = str(t2[(start + k) % t2.size()])
			_apply_skill_list(c, [sid2])
	if t3.size() > 0 and need_t3 > 0:
		var start3 = salt % t3.size()
		for k in need_t3:
			var sid3 = str(t3[(start3 + k) % t3.size()])
			_apply_skill_list(c, [sid3])
	var themed: Array = []
	_grant_theme_skill(c, elite, template_id, themed)
	if not themed.is_empty():
		_apply_skill_list(c, themed)

func grant_job_skills(c: CKCharacter) -> void:
	if c == null:
		return
	for s in skills_for_job(c.job_id):
		var sid = str(s.get("id"))
		if int(s.get("tier", 1)) > 1:
			continue  # 二阶需战技树解锁
		if sid not in c.skills:
			c.skills.append(sid)
	for sid in c.unlocked_skills:
		if sid not in c.skills:
			c.skills.append(sid)
	CKBloodline.sync_signature_skills(c)

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

func build_dynasty_journal() -> String:
	var leader = get_leader()
	var spouse_name = "（未成婚）"
	var child_summary = "（无子嗣）"
	if leader and leader.spouse_id != "" and characters.has(leader.spouse_id):
		spouse_name = characters[leader.spouse_id].name
	var kids: Array = []
	for c in characters.values():
		if c.is_child or (leader and c.id in leader.children_ids):
			kids.append("%s〔%s〕" % [c.name, c.bloodline_display()])
	if kids.size() > 0:
		child_summary = "、".join(kids)
	dynasty_journal = "【王朝手记·第零章】\n团长：%s\n配偶：%s\n子嗣：%s\n岁时：%s\n声望：灰烬邦 %s / 河卫邦 %s\n\n破旗立团，隘口一战，酒馆添人，春令成婚，初啼入谱，秋收簿清。灰烬旗的第一页，已用血与粮写就。" % [
		leader.name if leader else "?",
		spouse_name,
		child_summary,
		Calendar.label(),
		get_rep_name("ashland"),
		get_rep_name("riverland"),
	]
	set_flag("chapter0_done")
	mark_dirty()
	return dynasty_journal

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

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
