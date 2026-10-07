extends Node
## 全局状态：资源、人物、第零章旗标、存档

signal state_changed
signal log_added(text: String)

var rng := RandomNumberGenerator.new()

# 数据缓存
var data_bloodlines: Dictionary = {}
var data_traits: Dictionary = {}
var data_jobs: Dictionary = {}
var data_chapter0: Dictionary = {}
var data_names: Dictionary = {}
var data_appearance: Dictionary = {}
var data_maps: Dictionary = {}
var data_chapter1: Dictionary = {}
var chapter1_beat: String = "1.0"

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
var chapter0_beat: String = "0.0"
var chapter0_flags: Dictionary = {}
var event_log: Array = []
var settings: Dictionary = {
	"rules_preview": true,
	"text_speed": 1.0,
	"tutorial_highlight": true,
}
# 诸邦声望 0-100；档位由数值映射
var reputation: Dictionary = {"ashland": 0, "riverland": 0}
var shrine_level: int = 1
var deploy_ids: Array = []
var dirty: bool = false
var dynasty_journal: String = ""

const SAVE_PATH := "user://century_knights_save.json"
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

func _load_data() -> void:
	data_bloodlines = _read_json("res://data/bloodlines.json")
	data_traits = _read_json("res://data/traits.json")
	data_jobs = _read_json("res://data/jobs.json")
	data_chapter0 = _read_json("res://data/chapter0.json")
	data_names = _read_json("res://data/names.json")
	data_appearance = _read_json("res://data/appearance.json")
	data_maps = _read_json("res://data/maps.json")
	data_chapter1 = _read_json("res://data/chapter1.json")

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
	chapter0_beat = "0.0"
	chapter1_beat = "1.0"
	chapter0_flags = {}
	event_log.clear()
	dynasty_journal = ""
	reputation = {"ashland": 0, "riverland": 0}
	surname = leader_surname
	crest_color = color
	var leader = CharacterFactory.make_leader(leader_given, leader_surname, color)
	characters[leader.id] = leader
	var ally = CharacterFactory.make_ally_tutor()
	characters[ally.id] = ally
	deploy_ids = [leader.id, ally.id]
	refresh_tavern()
	refresh_marriage_candidates()
	_init_quests()
	log_event("灰烬旗立团：「%s」" % leader.name)
	mark_dirty()

func set_beat(beat_id: String) -> void:
	chapter0_beat = beat_id
	mark_dirty()

func flag(key: String) -> bool:
	return bool(chapter0_flags.get(key, false))

func set_flag(key: String, val: bool = true) -> void:
	chapter0_flags[key] = val
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
	]

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
		return {"ok": true, "battle": true, "quest": q}
	# 自动任务
	var evs = Calendar.advance(int(q.get("months", 1)))
	silver += int(q["silver"])
	add_rep("ashland", int(q["rep"]))
	if str(q.get("id", "")) == "q_herb":
		herb += 2
	if str(q.get("id", "")) == "q_drill":
		morale = mini(100, morale + 3)
	if str(q.get("id", "")) == "q_bridge":
		add_rep("riverland", 4)
	for c in roster():
		c.exp += 8 * int(q["stars"])
	log_event("完成任务「%s」+ %d 银" % [q["name"], q["silver"]])
	mark_dirty()
	return {"ok": true, "battle": false, "quest": q, "events": evs}

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
	return msg

func apply_harvest() -> String:
	var prod = 25 + shrine_level * 8
	food += prod
	silver += 15
	var msg = "丰收结算：+%d 粮，+15 银（祠堂 Lv%d）" % [prod, shrine_level]
	log_event(msg)
	# 祠堂治愈临时伤
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

func train(cid: String) -> Dictionary:
	var c: CKCharacter = characters.get(cid)
	if c == null:
		return {"ok": false, "msg": "无此人"}
	if silver < 15:
		return {"ok": false, "msg": Locale.t("not_enough_silver")}
	silver -= 15
	Calendar.advance(1)
	var key = CKCharacter.STAT_KEYS[rng.randi() % CKCharacter.STAT_KEYS.size()]
	c.stats[key] = mini(int(c.apt_max.get(key, 20)), int(c.stats[key]) + 1)
	if rng.randf() < 0.25:
		var all_t = data_traits.get("traits", [])
		var t = all_t[rng.randi() % all_t.size()]
		if t["id"] not in c.traits and t.get("polarity") == "pos":
			c.traits.append(t["id"])
			log_event("%s 训练领悟禀性「%s」" % [c.name, t["name"]])
	c.recalc_hp()
	mark_dirty()
	return {"ok": true, "msg": "%s 的%s +1" % [c.name, Locale.t("stat_" + key)]}

func craft_weapon(cid: String) -> Dictionary:
	if iron < 2 or silver < 20:
		return {"ok": false, "msg": "需要 2 铁与 20 银"}
	var c: CKCharacter = characters.get(cid)
	if c == null:
		return {"ok": false, "msg": "选择角色"}
	iron -= 2
	silver -= 20
	c.weapon_id = "ash_blade"
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
	var prices = {"food": 2, "iron": 8, "herb": 6}
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
	var prices = {"food": 1, "iron": 5, "herb": 4}
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
	log_event("%s 转职为 %s" % [c.name, job.get("name", job_id)])
	mark_dirty()
	return {"ok": true, "msg": "转职成功：" + job.get("name", job_id)}

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

func save_game() -> bool:
	var data = {
		"version": 1,
		"surname": surname,
		"crest_color": crest_color,
		"silver": silver, "food": food, "iron": iron, "herb": herb, "morale": morale,
		"year": Calendar.year, "month": Calendar.month,
		"chapter0_beat": chapter0_beat,
		"chapter1_beat": chapter1_beat,
		"chapter0_flags": chapter0_flags,
		"reputation": reputation,
		"settings": settings,
		"deploy_ids": deploy_ids,
		"dynasty_journal": dynasty_journal,
		"event_log": event_log,
		"shrine_level": shrine_level,
		"characters": {},
		"tavern": [],
		"marriage": [],
		"quests": quests,
		"started": started,
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
	chapter0_beat = str(data.get("chapter0_beat", "0.0"))
	chapter1_beat = str(data.get("chapter1_beat", "1.0"))
	chapter0_flags = data.get("chapter0_flags", {})
	reputation = data.get("reputation", {"ashland": 0, "riverland": 0})
	settings = data.get("settings", settings)
	deploy_ids = data.get("deploy_ids", [])
	dynasty_journal = str(data.get("dynasty_journal", ""))
	event_log = data.get("event_log", [])
	shrine_level = int(data.get("shrine_level", 1))
	quests = data.get("quests", quests)
	characters.clear()
	for id in data.get("characters", {}).keys():
		characters[id] = CKCharacter.from_dict(data["characters"][id])
	tavern_candidates.clear()
	for d in data.get("tavern", []):
		tavern_candidates.append(CKCharacter.from_dict(d))
	marriage_candidates.clear()
	for d in data.get("marriage", []):
		marriage_candidates.append(CKCharacter.from_dict(d))
	BattleRules.preview_enabled = settings.get("rules_preview", true)
	mark_dirty()
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
