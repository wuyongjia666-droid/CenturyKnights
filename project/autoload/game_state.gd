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
var data_chapter2: Dictionary = {}
var data_chapter3: Dictionary = {}
var data_chapter4: Dictionary = {}
var data_chapter5: Dictionary = {}
var data_chapter6: Dictionary = {}
var data_chapter7: Dictionary = {}
var data_chapter8: Dictionary = {}
var data_chapter9: Dictionary = {}
var data_chapter10: Dictionary = {}
var data_chapter11: Dictionary = {}
var data_chapter12: Dictionary = {}
var data_chapter13: Dictionary = {}
var data_chapter14: Dictionary = {}
var data_chapter15: Dictionary = {}
var data_chapter16: Dictionary = {}
var data_chapter17: Dictionary = {}
var data_chapter18: Dictionary = {}
var data_chapter19: Dictionary = {}
var data_chapter20: Dictionary = {}
var data_chapter21: Dictionary = {}
var data_rivals: Dictionary = {}
var rival_stances: Dictionary = {}  # house_id -> stance override
var rival_deals: Dictionary = {}  # house_id -> {turns_left, kind, reward}
var data_skills: Dictionary = {}
var chapter1_beat: String = "1.0"
var chapter2_beat: String = "2.0"
var chapter3_beat: String = "3.0"
var chapter4_beat: String = "4.0"
var chapter5_beat: String = "5.0"
var chapter6_beat: String = "6.0"
var chapter7_beat: String = "7.0"
var chapter8_beat: String = "8.0"
var chapter9_beat: String = "9.0"
var chapter10_beat: String = "10.0"
var chapter11_beat: String = "11.0"
var chapter12_beat: String = "12.0"
var chapter13_beat: String = "13.0"
var chapter14_beat: String = "14.0"
var chapter15_beat: String = "15.0"
var chapter16_beat: String = "16.0"
var chapter17_beat: String = "17.0"
var chapter18_beat: String = "18.0"
var chapter19_beat: String = "19.0"
var chapter20_beat: String = "20.0"
var chapter21_beat: String = "21.0"
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
var lineage_log: Array = []  # deeper marriage/lineage event strings
var lineage_path: Dictionary = {}  # child_id -> "martial"|"scholar"|"merchant"

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
	data_chapter2 = _read_json("res://data/chapter2.json")
	data_chapter3 = _read_json("res://data/chapter3.json")
	data_chapter4 = _read_json("res://data/chapter4.json")
	data_chapter5 = _read_json("res://data/chapter5.json")
	data_chapter6 = _read_json("res://data/chapter6.json")
	data_chapter7 = _read_json("res://data/chapter7.json")
	data_chapter8 = _read_json("res://data/chapter8.json")
	data_chapter9 = _read_json("res://data/chapter9.json")
	data_chapter10 = _read_json("res://data/chapter10.json")
	data_chapter11 = _read_json("res://data/chapter11.json")
	data_chapter12 = _read_json("res://data/chapter12.json")
	data_chapter13 = _read_json("res://data/chapter13.json")
	data_chapter14 = _read_json("res://data/chapter14.json")
	data_chapter15 = _read_json("res://data/chapter15.json")
	data_chapter16 = _read_json("res://data/chapter16.json")
	data_chapter17 = _read_json("res://data/chapter17.json")
	data_chapter18 = _read_json("res://data/chapter18.json")
	data_chapter19 = _read_json("res://data/chapter19.json")
	data_chapter20 = _read_json("res://data/chapter20.json")
	data_chapter21 = _read_json("res://data/chapter21.json")
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
	chapter0_beat = "0.0"
	chapter1_beat = "1.0"
	chapter2_beat = "2.0"
	chapter3_beat = "3.0"
	chapter4_beat = "4.0"
	chapter5_beat = "5.0"
	chapter6_beat = "6.0"
	chapter7_beat = "7.0"
	chapter8_beat = "8.0"
	chapter9_beat = "9.0"
	chapter10_beat = "10.0"
	chapter11_beat = "11.0"
	chapter12_beat = "12.0"
	chapter13_beat = "13.0"
	chapter14_beat = "14.0"
	chapter15_beat = "15.0"
	chapter16_beat = "16.0"
	chapter17_beat = "17.0"
	chapter18_beat = "18.0"
	chapter19_beat = "19.0"
	chapter20_beat = "20.0"
	chapter21_beat = "21.0"
	rival_stances = {"shuoying": "hostile", "qinghe": "wary", "lantern": "neutral"}
	rival_deals.clear()
	skill_points = 1
	chapter0_flags = {}
	event_log.clear()
	dynasty_journal = ""
	lineage_log.clear()
	lineage_path.clear()
	reputation = {"ashland": 0, "riverland": 0}
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
		{"id": "q_forge_war", "name": "主线支援·炉火关", "stars": 3, "months": 1, "silver": 65, "rep": 12, "battle": true, "map": "ch3_forge",
			"desc": "第三章：炉火关试锋。可用战技破旗斩/穿林箭。"},
		{"id": "q_shrine_war", "name": "主线支援·祠堂外廊", "stars": 3, "months": 1, "silver": 65, "rep": 12, "battle": true, "map": "ch3_shrine",
			"desc": "第三章：祠堂外廊。适合铁壁与灰焰祷言。"},
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

func reset_battle_skills(roster_chars: Array) -> void:
	for c in roster_chars:
		if c == null:
			continue
		c.temp_def_buff = 0
		c.temp_hit_bonus = 0
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
	mark_dirty()
	return {"ok": true, "msg": "解锁成功：" + get_skill(sid).get("name", sid)}


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
	for hid in rival_deals.keys():
		var d: Dictionary = rival_deals[hid]
		var left = int(d.get("turns_left", 0)) - 1
		d["turns_left"] = left
		# mid-contract events while still running
		if left > 0:
			var kind = str(d.get("kind", ""))
			var roll = int(Calendar.month) + hid.length() + left
			if roll % 3 == 0:
				match kind:
					"trade":
						silver += 8
						evs.append("契约中期·商路红利：银+8（%s）" % hid)
					"intel":
						add_rep("ashland", 1)
						evs.append("契约中期·情报碎片：声望微升（%s）" % hid)
					"truce":
						evs.append("契约中期·停战巡哨：边境暂安（%s）" % hid)
				add_lineage_event(evs[-1])
			elif roll % 5 == 0:
				# friction event — optional small cost or stance warn
				if kind == "trade" and silver >= 5:
					silver -= 5
					evs.append("契约中期·商路摩擦：银-5（%s，可改约/毁约）" % hid)
					add_lineage_event(evs[-1])
				elif kind == "truce":
					evs.append("契约中期·停战生隙：建议审视改约（%s）" % hid)
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

func save_game() -> bool:
	var data = {
		"version": 1,
		"surname": surname,
		"crest_color": crest_color,
		"silver": silver, "food": food, "iron": iron, "herb": herb, "morale": morale,
		"year": Calendar.year, "month": Calendar.month,
		"chapter0_beat": chapter0_beat,
		"chapter1_beat": chapter1_beat,
		"chapter2_beat": chapter2_beat,
		"chapter3_beat": chapter3_beat,
		"chapter4_beat": chapter4_beat,
		"chapter5_beat": chapter5_beat,
		"chapter6_beat": chapter6_beat,
		"chapter7_beat": chapter7_beat,
		"chapter8_beat": chapter8_beat,
		"chapter9_beat": chapter9_beat,
		"chapter10_beat": chapter10_beat,
		"chapter11_beat": chapter11_beat,
		"chapter12_beat": chapter12_beat,
		"chapter13_beat": chapter13_beat,
		"chapter14_beat": chapter14_beat,
		"chapter15_beat": chapter15_beat,
		"chapter16_beat": chapter16_beat,
		"chapter17_beat": chapter17_beat,
		"chapter18_beat": chapter18_beat,
		"chapter19_beat": chapter19_beat,
		"chapter20_beat": chapter20_beat,
		"chapter21_beat": chapter21_beat,
		"rival_stances": rival_stances.duplicate(true),
		"rival_deals": rival_deals.duplicate(true),
		"skill_points": skill_points,
		"chapter0_flags": chapter0_flags,
		"reputation": reputation,
		"settings": settings,
		"deploy_ids": deploy_ids,
		"dynasty_journal": dynasty_journal,
		"lineage_log": lineage_log.duplicate(true),
		"lineage_path": lineage_path.duplicate(true),
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
	chapter2_beat = str(data.get("chapter2_beat", "2.0"))
	chapter3_beat = str(data.get("chapter3_beat", "3.0"))
	chapter4_beat = str(data.get("chapter4_beat", "4.0"))
	chapter5_beat = str(data.get("chapter5_beat", "5.0"))
	chapter6_beat = str(data.get("chapter6_beat", "6.0"))
	chapter7_beat = str(data.get("chapter7_beat", "7.0"))
	chapter8_beat = str(data.get("chapter8_beat", "8.0"))
	chapter9_beat = str(data.get("chapter9_beat", "9.0"))
	chapter10_beat = str(data.get("chapter10_beat", "10.0"))
	chapter11_beat = str(data.get("chapter11_beat", "11.0"))
	chapter12_beat = str(data.get("chapter12_beat", "12.0"))
	chapter13_beat = str(data.get("chapter13_beat", "13.0"))
	chapter14_beat = str(data.get("chapter14_beat", "14.0"))
	chapter15_beat = str(data.get("chapter15_beat", "15.0"))
	chapter16_beat = str(data.get("chapter16_beat", "16.0"))
	chapter17_beat = str(data.get("chapter17_beat", "17.0"))
	chapter18_beat = str(data.get("chapter18_beat", "18.0"))
	chapter19_beat = str(data.get("chapter19_beat", "19.0"))
	chapter20_beat = str(data.get("chapter20_beat", "20.0"))
	chapter21_beat = str(data.get("chapter21_beat", "21.0"))
	rival_stances = data.get("rival_stances", {"shuoying": "hostile", "qinghe": "wary", "lantern": "neutral"}).duplicate(true)
	rival_deals = data.get("rival_deals", {}).duplicate(true)
	skill_points = int(data.get("skill_points", 0))
	chapter0_flags = data.get("chapter0_flags", {})
	reputation = data.get("reputation", {"ashland": 0, "riverland": 0})
	settings = data.get("settings", settings)
	deploy_ids = data.get("deploy_ids", [])
	dynasty_journal = str(data.get("dynasty_journal", ""))
	lineage_log = data.get("lineage_log", []).duplicate(true)
	lineage_path = data.get("lineage_path", {}).duplicate(true)
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
