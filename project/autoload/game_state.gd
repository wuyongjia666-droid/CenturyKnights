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
var data_chapter22: Dictionary = {}
var data_chapter23: Dictionary = {}
var data_chapter24: Dictionary = {}
var data_chapter25: Dictionary = {}
var data_chapter26: Dictionary = {}
var data_chapter27: Dictionary = {}
var data_chapter28: Dictionary = {}
var data_chapter29: Dictionary = {}
var data_chapter30: Dictionary = {}
var data_chapter31: Dictionary = {}
var data_chapter32: Dictionary = {}
var data_chapter33: Dictionary = {}
var data_chapter34: Dictionary = {}
var data_chapter35: Dictionary = {}
var data_chapter36: Dictionary = {}
var data_chapter37: Dictionary = {}
var data_chapter38: Dictionary = {}
var data_chapter39: Dictionary = {}
var data_chapter40: Dictionary = {}
var data_chapter41: Dictionary = {}
var data_chapter42: Dictionary = {}
var data_chapter43: Dictionary = {}
var data_chapter44: Dictionary = {}
var data_chapter45: Dictionary = {}
var data_chapter46: Dictionary = {}
var data_chapter47: Dictionary = {}
var data_chapter48: Dictionary = {}
var data_chapter49: Dictionary = {}
var data_chapter50: Dictionary = {}
var data_chapter51: Dictionary = {}
var data_chapter52: Dictionary = {}
var data_chapter53: Dictionary = {}
var data_chapter54: Dictionary = {}
var data_chapter55: Dictionary = {}
var data_chapter56: Dictionary = {}
var data_chapter57: Dictionary = {}
var data_chapter58: Dictionary = {}
var data_chapter59: Dictionary = {}
var data_chapter60: Dictionary = {}
var data_chapter61: Dictionary = {}
var data_chapter62: Dictionary = {}
var data_chapter63: Dictionary = {}
var data_chapter64: Dictionary = {}
var data_chapter65: Dictionary = {}
var data_chapter66: Dictionary = {}
var data_chapter67: Dictionary = {}
var data_chapter68: Dictionary = {}
var data_chapter69: Dictionary = {}
var data_chapter70: Dictionary = {}
var data_chapter71: Dictionary = {}
var data_chapter72: Dictionary = {}
var data_chapter73: Dictionary = {}
var data_chapter74: Dictionary = {}
var data_chapter75: Dictionary = {}
var data_chapter76: Dictionary = {}
var data_chapter77: Dictionary = {}
var data_chapter78: Dictionary = {}
var data_chapter79: Dictionary = {}
var data_chapter80: Dictionary = {}
var data_chapter81: Dictionary = {}
var data_chapter82: Dictionary = {}
var data_chapter83: Dictionary = {}
var data_chapter84: Dictionary = {}
var data_chapter85: Dictionary = {}
var data_chapter86: Dictionary = {}
var data_chapter87: Dictionary = {}
var data_chapter88: Dictionary = {}
var data_chapter89: Dictionary = {}
var data_chapter90: Dictionary = {}
var data_chapter91: Dictionary = {}
var data_chapter92: Dictionary = {}
var data_chapter93: Dictionary = {}
var data_chapter94: Dictionary = {}
var data_chapter95: Dictionary = {}
var data_chapter96: Dictionary = {}
var data_chapter97: Dictionary = {}
var data_chapter98: Dictionary = {}
var data_chapter99: Dictionary = {}
var data_chapter100: Dictionary = {}
var data_chapter101: Dictionary = {}
var data_chapter102: Dictionary = {}
var data_chapter103: Dictionary = {}
var data_chapter104: Dictionary = {}
var data_chapter105: Dictionary = {}
var data_chapter106: Dictionary = {}
var data_chapter107: Dictionary = {}
var data_chapter108: Dictionary = {}
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
var chapter22_beat: String = "22.0"
var chapter23_beat: String = "23.0"
var chapter24_beat: String = "24.0"
var chapter25_beat: String = "25.0"
var chapter26_beat: String = "26.0"
var chapter27_beat: String = "27.0"
var chapter28_beat: String = "28.0"
var chapter29_beat: String = "29.0"
var chapter30_beat: String = "30.0"
var chapter31_beat: String = "31.0"
var chapter32_beat: String = "32.0"
var chapter33_beat: String = "33.0"
var chapter34_beat: String = "34.0"
var chapter35_beat: String = "35.0"
var chapter36_beat: String = "36.0"
var chapter37_beat: String = "37.0"
var chapter38_beat: String = "38.0"
var chapter39_beat: String = "39.0"
var chapter40_beat: String = "40.0"
var chapter41_beat: String = "41.0"
var chapter42_beat: String = "42.0"
var chapter43_beat: String = "43.0"
var chapter44_beat: String = "44.0"
var chapter45_beat: String = "45.0"
var chapter46_beat: String = "46.0"
var chapter47_beat: String = "47.0"
var chapter48_beat: String = "48.0"
var chapter49_beat: String = "49.0"
var chapter50_beat: String = "50.0"
var chapter51_beat: String = "51.0"
var chapter52_beat: String = "52.0"
var chapter53_beat: String = "53.0"
var chapter54_beat: String = "54.0"
var chapter55_beat: String = "55.0"
var chapter56_beat: String = "56.0"
var chapter57_beat: String = "57.0"
var chapter58_beat: String = "58.0"
var chapter59_beat: String = "59.0"
var chapter60_beat: String = "60.0"
var chapter61_beat: String = "61.0"
var chapter62_beat: String = "62.0"
var chapter63_beat: String = "63.0"
var chapter64_beat: String = "64.0"
var chapter65_beat: String = "65.0"
var chapter66_beat: String = "66.0"
var chapter67_beat: String = "67.0"
var chapter68_beat: String = "68.0"
var chapter69_beat: String = "69.0"
var chapter70_beat: String = "70.0"
var chapter71_beat: String = "71.0"
var chapter72_beat: String = "72.0"
var chapter73_beat: String = "73.0"
var chapter74_beat: String = "74.0"
var chapter75_beat: String = "75.0"
var chapter76_beat: String = "76.0"
var chapter77_beat: String = "77.0"
var chapter78_beat: String = "78.0"
var chapter79_beat: String = "79.0"
var chapter80_beat: String = "80.0"
var chapter81_beat: String = "81.0"
var chapter82_beat: String = "82.0"
var chapter83_beat: String = "83.0"
var chapter84_beat: String = "84.0"
var chapter85_beat: String = "85.0"
var chapter86_beat: String = "86.0"
var chapter87_beat: String = "87.0"
var chapter88_beat: String = "88.0"
var chapter89_beat: String = "89.0"
var chapter90_beat: String = "90.0"
var chapter91_beat: String = "91.0"
var chapter92_beat: String = "92.0"
var chapter93_beat: String = "93.0"
var chapter94_beat: String = "94.0"
var chapter95_beat: String = "95.0"
var chapter96_beat: String = "96.0"
var chapter97_beat: String = "97.0"
var chapter98_beat: String = "98.0"
var chapter99_beat: String = "99.0"
var chapter100_beat: String = "100.0"
var chapter101_beat: String = "101.0"
var chapter102_beat: String = "102.0"
var chapter103_beat: String = "103.0"
var chapter104_beat: String = "104.0"
var chapter105_beat: String = "105.0"
var chapter106_beat: String = "106.0"
var chapter107_beat: String = "107.0"
var chapter108_beat: String = "108.0"
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
	data_chapter22 = _read_json("res://data/chapter22.json")
	data_chapter23 = _read_json("res://data/chapter23.json")
	data_chapter24 = _read_json("res://data/chapter24.json")
	data_chapter25 = _read_json("res://data/chapter25.json")
	data_chapter26 = _read_json("res://data/chapter26.json")
	data_chapter27 = _read_json("res://data/chapter27.json")
	data_chapter28 = _read_json("res://data/chapter28.json")
	data_chapter29 = _read_json("res://data/chapter29.json")
	data_chapter30 = _read_json("res://data/chapter30.json")
	data_chapter31 = _read_json("res://data/chapter31.json")
	data_chapter32 = _read_json("res://data/chapter32.json")
	data_chapter33 = _read_json("res://data/chapter33.json")
	data_chapter34 = _read_json("res://data/chapter34.json")
	data_chapter35 = _read_json("res://data/chapter35.json")
	data_chapter36 = _read_json("res://data/chapter36.json")
	data_chapter37 = _read_json("res://data/chapter37.json")
	data_chapter38 = _read_json("res://data/chapter38.json")
	data_chapter39 = _read_json("res://data/chapter39.json")
	data_chapter40 = _read_json("res://data/chapter40.json")
	data_chapter41 = _read_json("res://data/chapter41.json")
	data_chapter42 = _read_json("res://data/chapter42.json")
	data_chapter43 = _read_json("res://data/chapter43.json")
	data_chapter44 = _read_json("res://data/chapter44.json")
	data_chapter45 = _read_json("res://data/chapter45.json")
	data_chapter46 = _read_json("res://data/chapter46.json")
	data_chapter47 = _read_json("res://data/chapter47.json")
	data_chapter48 = _read_json("res://data/chapter48.json")
	data_chapter49 = _read_json("res://data/chapter49.json")
	data_chapter50 = _read_json("res://data/chapter50.json")
	data_chapter51 = _read_json("res://data/chapter51.json")
	data_chapter52 = _read_json("res://data/chapter52.json")
	data_chapter53 = _read_json("res://data/chapter53.json")
	data_chapter54 = _read_json("res://data/chapter54.json")
	data_chapter55 = _read_json("res://data/chapter55.json")
	data_chapter56 = _read_json("res://data/chapter56.json")
	data_chapter57 = _read_json("res://data/chapter57.json")
	data_chapter58 = _read_json("res://data/chapter58.json")
	data_chapter59 = _read_json("res://data/chapter59.json")
	data_chapter60 = _read_json("res://data/chapter60.json")
	data_chapter61 = _read_json("res://data/chapter61.json")
	data_chapter62 = _read_json("res://data/chapter62.json")
	data_chapter63 = _read_json("res://data/chapter63.json")
	data_chapter64 = _read_json("res://data/chapter64.json")
	data_chapter65 = _read_json("res://data/chapter65.json")
	data_chapter66 = _read_json("res://data/chapter66.json")
	data_chapter67 = _read_json("res://data/chapter67.json")
	data_chapter68 = _read_json("res://data/chapter68.json")
	data_chapter69 = _read_json("res://data/chapter69.json")
	data_chapter70 = _read_json("res://data/chapter70.json")
	data_chapter71 = _read_json("res://data/chapter71.json")
	data_chapter72 = _read_json("res://data/chapter72.json")
	data_chapter73 = _read_json("res://data/chapter73.json")
	data_chapter74 = _read_json("res://data/chapter74.json")
	data_chapter75 = _read_json("res://data/chapter75.json")
	data_chapter76 = _read_json("res://data/chapter76.json")
	data_chapter77 = _read_json("res://data/chapter77.json")
	data_chapter78 = _read_json("res://data/chapter78.json")
	data_chapter79 = _read_json("res://data/chapter79.json")
	data_chapter80 = _read_json("res://data/chapter80.json")
	data_chapter81 = _read_json("res://data/chapter81.json")
	data_chapter82 = _read_json("res://data/chapter82.json")
	data_chapter83 = _read_json("res://data/chapter83.json")
	data_chapter84 = _read_json("res://data/chapter84.json")
	data_chapter85 = _read_json("res://data/chapter85.json")
	data_chapter86 = _read_json("res://data/chapter86.json")
	data_chapter87 = _read_json("res://data/chapter87.json")
	data_chapter88 = _read_json("res://data/chapter88.json")
	data_chapter89 = _read_json("res://data/chapter89.json")
	data_chapter90 = _read_json("res://data/chapter90.json")
	data_chapter91 = _read_json("res://data/chapter91.json")
	data_chapter92 = _read_json("res://data/chapter92.json")
	data_chapter93 = _read_json("res://data/chapter93.json")
	data_chapter94 = _read_json("res://data/chapter94.json")
	data_chapter95 = _read_json("res://data/chapter95.json")
	data_chapter96 = _read_json("res://data/chapter96.json")
	data_chapter97 = _read_json("res://data/chapter97.json")
	data_chapter98 = _read_json("res://data/chapter98.json")
	data_chapter99 = _read_json("res://data/chapter99.json")
	data_chapter100 = _read_json("res://data/chapter100.json")
	data_chapter101 = _read_json("res://data/chapter101.json")
	data_chapter102 = _read_json("res://data/chapter102.json")
	data_chapter103 = _read_json("res://data/chapter103.json")
	data_chapter104 = _read_json("res://data/chapter104.json")
	data_chapter105 = _read_json("res://data/chapter105.json")
	data_chapter106 = _read_json("res://data/chapter106.json")
	data_chapter107 = _read_json("res://data/chapter107.json")
	data_chapter108 = _read_json("res://data/chapter108.json")
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
	chapter22_beat = "22.0"
	chapter23_beat = "23.0"
	chapter24_beat = "24.0"
	chapter25_beat = "25.0"
	chapter26_beat = "26.0"
	chapter27_beat = "27.0"
	chapter28_beat = "28.0"
	chapter29_beat = "29.0"
	chapter30_beat = "30.0"
	chapter31_beat = "31.0"
	chapter32_beat = "32.0"
	chapter33_beat = "33.0"
	chapter34_beat = "34.0"
	chapter35_beat = "35.0"
	chapter36_beat = "36.0"
	chapter37_beat = "37.0"
	chapter38_beat = "38.0"
	chapter39_beat = "39.0"
	chapter40_beat = "40.0"
	chapter41_beat = "41.0"
	chapter42_beat = "42.0"
	chapter43_beat = "43.0"
	chapter44_beat = "44.0"
	chapter45_beat = "45.0"
	chapter46_beat = "46.0"
	chapter47_beat = "47.0"
	chapter48_beat = "48.0"
	chapter49_beat = "49.0"
	chapter50_beat = "50.0"
	chapter51_beat = "51.0"
	chapter52_beat = "52.0"
	chapter53_beat = "53.0"
	chapter54_beat = "54.0"
	chapter55_beat = "55.0"
	chapter56_beat = "56.0"
	chapter57_beat = "57.0"
	chapter58_beat = "58.0"
	chapter59_beat = "59.0"
	chapter60_beat = "60.0"
	chapter61_beat = "61.0"
	chapter62_beat = "62.0"
	chapter63_beat = "63.0"
	chapter64_beat = "64.0"
	chapter65_beat = "65.0"
	chapter66_beat = "66.0"
	chapter67_beat = "67.0"
	chapter68_beat = "68.0"
	chapter69_beat = "69.0"
	chapter70_beat = "70.0"
	chapter71_beat = "71.0"
	chapter72_beat = "72.0"
	chapter73_beat = "73.0"
	chapter74_beat = "74.0"
	chapter75_beat = "75.0"
	chapter76_beat = "76.0"
	chapter77_beat = "77.0"
	chapter78_beat = "78.0"
	chapter79_beat = "79.0"
	chapter80_beat = "80.0"
	chapter81_beat = "81.0"
	chapter82_beat = "82.0"
	chapter83_beat = "83.0"
	chapter84_beat = "84.0"
	chapter85_beat = "85.0"
	chapter86_beat = "86.0"
	chapter87_beat = "87.0"
	chapter88_beat = "88.0"
	chapter89_beat = "89.0"
	chapter90_beat = "90.0"
	chapter91_beat = "91.0"
	chapter92_beat = "92.0"
	chapter93_beat = "93.0"
	chapter94_beat = "94.0"
	chapter95_beat = "95.0"
	chapter96_beat = "96.0"
	chapter97_beat = "97.0"
	chapter98_beat = "98.0"
	chapter99_beat = "99.0"
	chapter100_beat = "100.0"
	chapter101_beat = "101.0"
	chapter102_beat = "102.0"
	chapter103_beat = "103.0"
	chapter104_beat = "104.0"
	chapter105_beat = "105.0"
	chapter106_beat = "106.0"
	chapter107_beat = "107.0"
	chapter108_beat = "108.0"
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
		"chapter22_beat": chapter22_beat,
		"chapter23_beat": chapter23_beat,
		"chapter24_beat": chapter24_beat,
		"chapter25_beat": chapter25_beat,
		"chapter26_beat": chapter26_beat,
		"chapter27_beat": chapter27_beat,
		"chapter28_beat": chapter28_beat,
		"chapter29_beat": chapter29_beat,
		"chapter30_beat": chapter30_beat,
		"chapter31_beat": chapter31_beat,
		"chapter32_beat": chapter32_beat,
		"chapter33_beat": chapter33_beat,
		"chapter34_beat": chapter34_beat,
		"chapter35_beat": chapter35_beat,
		"chapter36_beat": chapter36_beat,
		"chapter37_beat": chapter37_beat,
		"chapter38_beat": chapter38_beat,
		"chapter39_beat": chapter39_beat,
		"chapter40_beat": chapter40_beat,
		"chapter41_beat": chapter41_beat,
		"chapter42_beat": chapter42_beat,
		"chapter43_beat": chapter43_beat,
		"chapter44_beat": chapter44_beat,
		"chapter45_beat": chapter45_beat,
		"chapter46_beat": chapter46_beat,
		"chapter47_beat": chapter47_beat,
		"chapter48_beat": chapter48_beat,
		"chapter49_beat": chapter49_beat,
		"chapter50_beat": chapter50_beat,
		"chapter51_beat": chapter51_beat,
		"chapter52_beat": chapter52_beat,
		"chapter53_beat": chapter53_beat,
		"chapter54_beat": chapter54_beat,
		"chapter55_beat": chapter55_beat,
		"chapter56_beat": chapter56_beat,
		"chapter57_beat": chapter57_beat,
		"chapter58_beat": chapter58_beat,
		"chapter59_beat": chapter59_beat,
		"chapter60_beat": chapter60_beat,
		"chapter61_beat": chapter61_beat,
		"chapter62_beat": chapter62_beat,
		"chapter63_beat": chapter63_beat,
		"chapter64_beat": chapter64_beat,
		"chapter65_beat": chapter65_beat,
		"chapter66_beat": chapter66_beat,
		"chapter67_beat": chapter67_beat,
		"chapter68_beat": chapter68_beat,
		"chapter69_beat": chapter69_beat,
		"chapter70_beat": chapter70_beat,
		"chapter71_beat": chapter71_beat,
		"chapter72_beat": chapter72_beat,
		"chapter73_beat": chapter73_beat,
		"chapter74_beat": chapter74_beat,
		"chapter75_beat": chapter75_beat,
		"chapter76_beat": chapter76_beat,
		"chapter77_beat": chapter77_beat,
		"chapter78_beat": chapter78_beat,
		"chapter79_beat": chapter79_beat,
		"chapter80_beat": chapter80_beat,
		"chapter81_beat": chapter81_beat,
		"chapter82_beat": chapter82_beat,
		"chapter83_beat": chapter83_beat,
		"chapter84_beat": chapter84_beat,
		"chapter85_beat": chapter85_beat,
		"chapter86_beat": chapter86_beat,
		"chapter87_beat": chapter87_beat,
		"chapter88_beat": chapter88_beat,
		"chapter89_beat": chapter89_beat,
		"chapter90_beat": chapter90_beat,
		"chapter91_beat": chapter91_beat,
		"chapter92_beat": chapter92_beat,
		"chapter93_beat": chapter93_beat,
		"chapter94_beat": chapter94_beat,
		"chapter95_beat": chapter95_beat,
		"chapter96_beat": chapter96_beat,
		"chapter97_beat": chapter97_beat,
		"chapter98_beat": chapter98_beat,
		"chapter99_beat": chapter99_beat,
		"chapter100_beat": chapter100_beat,
		"chapter101_beat": chapter101_beat,
		"chapter102_beat": chapter102_beat,
		"chapter103_beat": chapter103_beat,
		"chapter104_beat": chapter104_beat,
		"chapter105_beat": chapter105_beat,
		"chapter106_beat": chapter106_beat,
		"chapter107_beat": chapter107_beat,
		"chapter108_beat": chapter108_beat,
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
	chapter22_beat = str(data.get("chapter22_beat", "22.0"))
	chapter23_beat = str(data.get("chapter23_beat", "23.0"))
	chapter24_beat = str(data.get("chapter24_beat", "24.0"))
	chapter25_beat = str(data.get("chapter25_beat", "25.0"))
	chapter26_beat = str(data.get("chapter26_beat", "26.0"))
	chapter27_beat = str(data.get("chapter27_beat", "27.0"))
	chapter28_beat = str(data.get("chapter28_beat", "28.0"))
	chapter29_beat = str(data.get("chapter29_beat", "29.0"))
	chapter30_beat = str(data.get("chapter30_beat", "30.0"))
	chapter31_beat = str(data.get("chapter31_beat", "31.0"))
	chapter32_beat = str(data.get("chapter32_beat", "32.0"))
	chapter33_beat = str(data.get("chapter33_beat", "33.0"))
	chapter34_beat = str(data.get("chapter34_beat", "34.0"))
	chapter35_beat = str(data.get("chapter35_beat", "35.0"))
	chapter36_beat = str(data.get("chapter36_beat", "36.0"))
	chapter37_beat = str(data.get("chapter37_beat", "37.0"))
	chapter38_beat = str(data.get("chapter38_beat", "38.0"))
	chapter39_beat = str(data.get("chapter39_beat", "39.0"))
	chapter40_beat = str(data.get("chapter40_beat", "40.0"))
	chapter41_beat = str(data.get("chapter41_beat", "41.0"))
	chapter42_beat = str(data.get("chapter42_beat", "42.0"))
	chapter43_beat = str(data.get("chapter43_beat", "43.0"))
	chapter44_beat = str(data.get("chapter44_beat", "44.0"))
	chapter45_beat = str(data.get("chapter45_beat", "45.0"))
	chapter46_beat = str(data.get("chapter46_beat", "46.0"))
	chapter47_beat = str(data.get("chapter47_beat", "47.0"))
	chapter48_beat = str(data.get("chapter48_beat", "48.0"))
	chapter49_beat = str(data.get("chapter49_beat", "49.0"))
	chapter50_beat = str(data.get("chapter50_beat", "50.0"))
	chapter51_beat = str(data.get("chapter51_beat", "51.0"))
	chapter52_beat = str(data.get("chapter52_beat", "52.0"))
	chapter53_beat = str(data.get("chapter53_beat", "53.0"))
	chapter54_beat = str(data.get("chapter54_beat", "54.0"))
	chapter55_beat = str(data.get("chapter55_beat", "55.0"))
	chapter56_beat = str(data.get("chapter56_beat", "56.0"))
	chapter57_beat = str(data.get("chapter57_beat", "57.0"))
	chapter58_beat = str(data.get("chapter58_beat", "58.0"))
	chapter59_beat = str(data.get("chapter59_beat", "59.0"))
	chapter60_beat = str(data.get("chapter60_beat", "60.0"))
	chapter61_beat = str(data.get("chapter61_beat", "61.0"))
	chapter62_beat = str(data.get("chapter62_beat", "62.0"))
	chapter63_beat = str(data.get("chapter63_beat", "63.0"))
	chapter64_beat = str(data.get("chapter64_beat", "64.0"))
	chapter65_beat = str(data.get("chapter65_beat", "65.0"))
	chapter66_beat = str(data.get("chapter66_beat", "66.0"))
	chapter67_beat = str(data.get("chapter67_beat", "67.0"))
	chapter68_beat = str(data.get("chapter68_beat", "68.0"))
	chapter69_beat = str(data.get("chapter69_beat", "69.0"))
	chapter70_beat = str(data.get("chapter70_beat", "70.0"))
	chapter71_beat = str(data.get("chapter71_beat", "71.0"))
	chapter72_beat = str(data.get("chapter72_beat", "72.0"))
	chapter73_beat = str(data.get("chapter73_beat", "73.0"))
	chapter74_beat = str(data.get("chapter74_beat", "74.0"))
	chapter75_beat = str(data.get("chapter75_beat", "75.0"))
	chapter76_beat = str(data.get("chapter76_beat", "76.0"))
	chapter77_beat = str(data.get("chapter77_beat", "77.0"))
	chapter78_beat = str(data.get("chapter78_beat", "78.0"))
	chapter79_beat = str(data.get("chapter79_beat", "79.0"))
	chapter80_beat = str(data.get("chapter80_beat", "80.0"))
	chapter81_beat = str(data.get("chapter81_beat", "81.0"))
	chapter82_beat = str(data.get("chapter82_beat", "82.0"))
	chapter83_beat = str(data.get("chapter83_beat", "83.0"))
	chapter84_beat = str(data.get("chapter84_beat", "84.0"))
	chapter85_beat = str(data.get("chapter85_beat", "85.0"))
	chapter86_beat = str(data.get("chapter86_beat", "86.0"))
	chapter87_beat = str(data.get("chapter87_beat", "87.0"))
	chapter88_beat = str(data.get("chapter88_beat", "88.0"))
	chapter89_beat = str(data.get("chapter89_beat", "89.0"))
	chapter90_beat = str(data.get("chapter90_beat", "90.0"))
	chapter91_beat = str(data.get("chapter91_beat", "91.0"))
	chapter92_beat = str(data.get("chapter92_beat", "92.0"))
	chapter93_beat = str(data.get("chapter93_beat", "93.0"))
	chapter94_beat = str(data.get("chapter94_beat", "94.0"))
	chapter95_beat = str(data.get("chapter95_beat", "95.0"))
	chapter96_beat = str(data.get("chapter96_beat", "96.0"))
	chapter97_beat = str(data.get("chapter97_beat", "97.0"))
	chapter98_beat = str(data.get("chapter98_beat", "98.0"))
	chapter99_beat = str(data.get("chapter99_beat", "99.0"))
	chapter100_beat = str(data.get("chapter100_beat", "100.0"))
	chapter101_beat = str(data.get("chapter101_beat", "101.0"))
	chapter102_beat = str(data.get("chapter102_beat", "102.0"))
	chapter103_beat = str(data.get("chapter103_beat", "103.0"))
	chapter104_beat = str(data.get("chapter104_beat", "104.0"))
	chapter105_beat = str(data.get("chapter105_beat", "105.0"))
	chapter106_beat = str(data.get("chapter106_beat", "106.0"))
	chapter107_beat = str(data.get("chapter107_beat", "107.0"))
	chapter108_beat = str(data.get("chapter108_beat", "108.0"))
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
