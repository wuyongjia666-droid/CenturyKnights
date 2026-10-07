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
var data_enemy_skills: Dictionary = {}
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
var data_chapter109: Dictionary = {}
var data_chapter110: Dictionary = {}
var data_chapter111: Dictionary = {}
var data_chapter112: Dictionary = {}
var data_chapter113: Dictionary = {}
var data_chapter114: Dictionary = {}
var data_chapter115: Dictionary = {}
var data_chapter116: Dictionary = {}
var data_chapter117: Dictionary = {}
var data_chapter118: Dictionary = {}
var data_chapter119: Dictionary = {}
var data_chapter120: Dictionary = {}
var data_chapter121: Dictionary = {}
var data_chapter122: Dictionary = {}
var data_chapter123: Dictionary = {}
var data_chapter124: Dictionary = {}
var data_chapter125: Dictionary = {}
var data_chapter126: Dictionary = {}
var data_chapter127: Dictionary = {}
var data_chapter128: Dictionary = {}
var data_chapter129: Dictionary = {}
var data_chapter130: Dictionary = {}
var data_chapter131: Dictionary = {}
var data_chapter132: Dictionary = {}
var data_chapter133: Dictionary = {}
var data_chapter134: Dictionary = {}
var data_chapter135: Dictionary = {}
var data_chapter136: Dictionary = {}
var data_chapter137: Dictionary = {}
var data_chapter138: Dictionary = {}
var data_chapter139: Dictionary = {}
var data_chapter140: Dictionary = {}
var data_chapter141: Dictionary = {}
var data_chapter142: Dictionary = {}
var data_chapter143: Dictionary = {}
var data_chapter144: Dictionary = {}
var data_chapter145: Dictionary = {}
var data_chapter146: Dictionary = {}
var data_chapter147: Dictionary = {}
var data_chapter148: Dictionary = {}
var data_chapter149: Dictionary = {}
var data_chapter150: Dictionary = {}
var data_chapter151: Dictionary = {}
var data_chapter152: Dictionary = {}
var data_chapter153: Dictionary = {}
var data_chapter154: Dictionary = {}
var data_chapter155: Dictionary = {}
var data_chapter156: Dictionary = {}
var data_chapter157: Dictionary = {}
var data_chapter158: Dictionary = {}
var data_chapter159: Dictionary = {}
var data_chapter160: Dictionary = {}
var data_chapter161: Dictionary = {}
var data_chapter162: Dictionary = {}
var data_chapter163: Dictionary = {}
var data_chapter164: Dictionary = {}
var data_chapter165: Dictionary = {}
var data_chapter166: Dictionary = {}
var data_chapter167: Dictionary = {}
var data_chapter168: Dictionary = {}
var data_chapter169: Dictionary = {}
var data_chapter170: Dictionary = {}
var data_chapter171: Dictionary = {}
var data_chapter172: Dictionary = {}
var data_chapter173: Dictionary = {}
var data_chapter174: Dictionary = {}
var data_chapter175: Dictionary = {}
var data_chapter176: Dictionary = {}
var data_chapter177: Dictionary = {}
var data_chapter178: Dictionary = {}
var data_chapter179: Dictionary = {}
var data_chapter180: Dictionary = {}
var data_chapter181: Dictionary = {}
var data_chapter182: Dictionary = {}
var data_chapter183: Dictionary = {}
var data_chapter184: Dictionary = {}
var data_chapter185: Dictionary = {}
var data_chapter186: Dictionary = {}
var data_chapter187: Dictionary = {}
var data_chapter188: Dictionary = {}
var data_chapter189: Dictionary = {}
var data_chapter190: Dictionary = {}
var data_chapter191: Dictionary = {}
var data_chapter192: Dictionary = {}
var data_chapter193: Dictionary = {}
var data_chapter194: Dictionary = {}
var data_chapter195: Dictionary = {}
var data_chapter196: Dictionary = {}
var data_chapter197: Dictionary = {}
var data_chapter198: Dictionary = {}
var data_chapter199: Dictionary = {}
var data_chapter200: Dictionary = {}
var data_chapter201: Dictionary = {}
var data_chapter202: Dictionary = {}
var data_chapter203: Dictionary = {}
var data_chapter204: Dictionary = {}
var data_chapter205: Dictionary = {}
var data_chapter206: Dictionary = {}
var data_chapter207: Dictionary = {}
var data_chapter208: Dictionary = {}
var data_chapter209: Dictionary = {}
var data_chapter210: Dictionary = {}
var data_chapter211: Dictionary = {}
var data_chapter212: Dictionary = {}
var data_chapter213: Dictionary = {}
var data_chapter214: Dictionary = {}
var data_chapter215: Dictionary = {}
var data_chapter216: Dictionary = {}
var data_chapter217: Dictionary = {}
var data_chapter218: Dictionary = {}
var data_chapter219: Dictionary = {}
var data_chapter220: Dictionary = {}
var data_chapter221: Dictionary = {}
var data_chapter222: Dictionary = {}
var data_chapter223: Dictionary = {}
var data_chapter224: Dictionary = {}
var data_chapter225: Dictionary = {}
var data_chapter226: Dictionary = {}
var data_chapter227: Dictionary = {}
var data_chapter228: Dictionary = {}
var data_chapter229: Dictionary = {}
var data_chapter230: Dictionary = {}
var data_chapter231: Dictionary = {}
var data_chapter232: Dictionary = {}
var data_chapter233: Dictionary = {}
var data_chapter234: Dictionary = {}
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
var chapter109_beat: String = "109.0"
var chapter110_beat: String = "110.0"
var chapter111_beat: String = "111.0"
var chapter112_beat: String = "112.0"
var chapter113_beat: String = "113.0"
var chapter114_beat: String = "114.0"
var chapter115_beat: String = "115.0"
var chapter116_beat: String = "116.0"
var chapter117_beat: String = "117.0"
var chapter118_beat: String = "118.0"
var chapter119_beat: String = "119.0"
var chapter120_beat: String = "120.0"
var chapter121_beat: String = "121.0"
var chapter122_beat: String = "122.0"
var chapter123_beat: String = "123.0"
var chapter124_beat: String = "124.0"
var chapter125_beat: String = "125.0"
var chapter126_beat: String = "126.0"
var chapter127_beat: String = "127.0"
var chapter128_beat: String = "128.0"
var chapter129_beat: String = "129.0"
var chapter130_beat: String = "130.0"
var chapter131_beat: String = "131.0"
var chapter132_beat: String = "132.0"
var chapter133_beat: String = "133.0"
var chapter134_beat: String = "134.0"
var chapter135_beat: String = "135.0"
var chapter136_beat: String = "136.0"
var chapter137_beat: String = "137.0"
var chapter138_beat: String = "138.0"
var chapter139_beat: String = "139.0"
var chapter140_beat: String = "140.0"
var chapter141_beat: String = "141.0"
var chapter142_beat: String = "142.0"
var chapter143_beat: String = "143.0"
var chapter144_beat: String = "144.0"
var chapter145_beat: String = "145.0"
var chapter146_beat: String = "146.0"
var chapter147_beat: String = "147.0"
var chapter148_beat: String = "148.0"
var chapter149_beat: String = "149.0"
var chapter150_beat: String = "150.0"
var chapter151_beat: String = "151.0"
var chapter152_beat: String = "152.0"
var chapter153_beat: String = "153.0"
var chapter154_beat: String = "154.0"
var chapter155_beat: String = "155.0"
var chapter156_beat: String = "156.0"
var chapter157_beat: String = "157.0"
var chapter158_beat: String = "158.0"
var chapter159_beat: String = "159.0"
var chapter160_beat: String = "160.0"
var chapter161_beat: String = "161.0"
var chapter162_beat: String = "162.0"
var chapter163_beat: String = "163.0"
var chapter164_beat: String = "164.0"
var chapter165_beat: String = "165.0"
var chapter166_beat: String = "166.0"
var chapter167_beat: String = "167.0"
var chapter168_beat: String = "168.0"
var chapter169_beat: String = "169.0"
var chapter170_beat: String = "170.0"
var chapter171_beat: String = "171.0"
var chapter172_beat: String = "172.0"
var chapter173_beat: String = "173.0"
var chapter174_beat: String = "174.0"
var chapter175_beat: String = "175.0"
var chapter176_beat: String = "176.0"
var chapter177_beat: String = "177.0"
var chapter178_beat: String = "178.0"
var chapter179_beat: String = "179.0"
var chapter180_beat: String = "180.0"
var chapter181_beat: String = "181.0"
var chapter182_beat: String = "182.0"
var chapter183_beat: String = "183.0"
var chapter184_beat: String = "184.0"
var chapter185_beat: String = "185.0"
var chapter186_beat: String = "186.0"
var chapter187_beat: String = "187.0"
var chapter188_beat: String = "188.0"
var chapter189_beat: String = "189.0"
var chapter190_beat: String = "190.0"
var chapter191_beat: String = "191.0"
var chapter192_beat: String = "192.0"
var chapter193_beat: String = "193.0"
var chapter194_beat: String = "194.0"
var chapter195_beat: String = "195.0"
var chapter196_beat: String = "196.0"
var chapter197_beat: String = "197.0"
var chapter198_beat: String = "198.0"
var chapter199_beat: String = "199.0"
var chapter200_beat: String = "200.0"
var chapter201_beat: String = "201.0"
var chapter202_beat: String = "202.0"
var chapter203_beat: String = "203.0"
var chapter204_beat: String = "204.0"
var chapter205_beat: String = "205.0"
var chapter206_beat: String = "206.0"
var chapter207_beat: String = "207.0"
var chapter208_beat: String = "208.0"
var chapter209_beat: String = "209.0"
var chapter210_beat: String = "210.0"
var chapter211_beat: String = "211.0"
var chapter212_beat: String = "212.0"
var chapter213_beat: String = "213.0"
var chapter214_beat: String = "214.0"
var chapter215_beat: String = "215.0"
var chapter216_beat: String = "216.0"
var chapter217_beat: String = "217.0"
var chapter218_beat: String = "218.0"
var chapter219_beat: String = "219.0"
var chapter220_beat: String = "220.0"
var chapter221_beat: String = "221.0"
var chapter222_beat: String = "222.0"
var chapter223_beat: String = "223.0"
var chapter224_beat: String = "224.0"
var chapter225_beat: String = "225.0"
var chapter226_beat: String = "226.0"
var chapter227_beat: String = "227.0"
var chapter228_beat: String = "228.0"
var chapter229_beat: String = "229.0"
var chapter230_beat: String = "230.0"
var chapter231_beat: String = "231.0"
var chapter232_beat: String = "232.0"
var chapter233_beat: String = "233.0"
var chapter234_beat: String = "234.0"
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
var holdings: Dictionary = {}  # id -> {level, steward_id}
var doctrine_months: int = 0
var estate_quiet_months: int = 0  # 连续无劫掠月数
var patrol_cooldown: int = 0  # 全堡巡防冷却（月）
var patrol_boost_months: int = 0  # 主动巡防抗劫剩余月
const HOLDING_DEFS := {
	"reed_ford": {"name": "苇原渡", "desc": "护商旧道属地", "food": 3, "silver": 2, "quest": "q_escort"},
	"stone_slope": {"name": "石垒坡", "desc": "清匪后的丘地佃庄", "food": 2, "silver": 4, "quest": "q_bandit"},
	"fog_vale": {"name": "雾谷药田", "desc": "药草租佃", "food": 1, "silver": 2, "herb": 1, "quest": "q_herb"},
	"tide_bridge": {"name": "断潮渡哨", "desc": "河卫守桥契约地", "food": 2, "silver": 3, "rep": 1, "quest": "q_bridge"},
}
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
	data_enemy_skills = _read_json("res://data/enemy_skill_tables.json")
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
	data_chapter109 = _read_json("res://data/chapter109.json")
	data_chapter110 = _read_json("res://data/chapter110.json")
	data_chapter111 = _read_json("res://data/chapter111.json")
	data_chapter112 = _read_json("res://data/chapter112.json")
	data_chapter113 = _read_json("res://data/chapter113.json")
	data_chapter114 = _read_json("res://data/chapter114.json")
	data_chapter115 = _read_json("res://data/chapter115.json")
	data_chapter116 = _read_json("res://data/chapter116.json")
	data_chapter117 = _read_json("res://data/chapter117.json")
	data_chapter118 = _read_json("res://data/chapter118.json")
	data_chapter119 = _read_json("res://data/chapter119.json")
	data_chapter120 = _read_json("res://data/chapter120.json")
	data_chapter121 = _read_json("res://data/chapter121.json")
	data_chapter122 = _read_json("res://data/chapter122.json")
	data_chapter123 = _read_json("res://data/chapter123.json")
	data_chapter124 = _read_json("res://data/chapter124.json")
	data_chapter125 = _read_json("res://data/chapter125.json")
	data_chapter126 = _read_json("res://data/chapter126.json")
	data_chapter127 = _read_json("res://data/chapter127.json")
	data_chapter128 = _read_json("res://data/chapter128.json")
	data_chapter129 = _read_json("res://data/chapter129.json")
	data_chapter130 = _read_json("res://data/chapter130.json")
	data_chapter131 = _read_json("res://data/chapter131.json")
	data_chapter132 = _read_json("res://data/chapter132.json")
	data_chapter133 = _read_json("res://data/chapter133.json")
	data_chapter134 = _read_json("res://data/chapter134.json")
	data_chapter135 = _read_json("res://data/chapter135.json")
	data_chapter136 = _read_json("res://data/chapter136.json")
	data_chapter137 = _read_json("res://data/chapter137.json")
	data_chapter138 = _read_json("res://data/chapter138.json")
	data_chapter139 = _read_json("res://data/chapter139.json")
	data_chapter140 = _read_json("res://data/chapter140.json")
	data_chapter141 = _read_json("res://data/chapter141.json")
	data_chapter142 = _read_json("res://data/chapter142.json")
	data_chapter143 = _read_json("res://data/chapter143.json")
	data_chapter144 = _read_json("res://data/chapter144.json")
	data_chapter145 = _read_json("res://data/chapter145.json")
	data_chapter146 = _read_json("res://data/chapter146.json")
	data_chapter147 = _read_json("res://data/chapter147.json")
	data_chapter148 = _read_json("res://data/chapter148.json")
	data_chapter149 = _read_json("res://data/chapter149.json")
	data_chapter150 = _read_json("res://data/chapter150.json")
	data_chapter151 = _read_json("res://data/chapter151.json")
	data_chapter152 = _read_json("res://data/chapter152.json")
	data_chapter153 = _read_json("res://data/chapter153.json")
	data_chapter154 = _read_json("res://data/chapter154.json")
	data_chapter155 = _read_json("res://data/chapter155.json")
	data_chapter156 = _read_json("res://data/chapter156.json")
	data_chapter157 = _read_json("res://data/chapter157.json")
	data_chapter158 = _read_json("res://data/chapter158.json")
	data_chapter159 = _read_json("res://data/chapter159.json")
	data_chapter160 = _read_json("res://data/chapter160.json")
	data_chapter161 = _read_json("res://data/chapter161.json")
	data_chapter162 = _read_json("res://data/chapter162.json")
	data_chapter163 = _read_json("res://data/chapter163.json")
	data_chapter164 = _read_json("res://data/chapter164.json")
	data_chapter165 = _read_json("res://data/chapter165.json")
	data_chapter166 = _read_json("res://data/chapter166.json")
	data_chapter167 = _read_json("res://data/chapter167.json")
	data_chapter168 = _read_json("res://data/chapter168.json")
	data_chapter169 = _read_json("res://data/chapter169.json")
	data_chapter170 = _read_json("res://data/chapter170.json")
	data_chapter171 = _read_json("res://data/chapter171.json")
	data_chapter172 = _read_json("res://data/chapter172.json")
	data_chapter173 = _read_json("res://data/chapter173.json")
	data_chapter174 = _read_json("res://data/chapter174.json")
	data_chapter175 = _read_json("res://data/chapter175.json")
	data_chapter176 = _read_json("res://data/chapter176.json")
	data_chapter177 = _read_json("res://data/chapter177.json")
	data_chapter178 = _read_json("res://data/chapter178.json")
	data_chapter179 = _read_json("res://data/chapter179.json")
	data_chapter180 = _read_json("res://data/chapter180.json")
	data_chapter181 = _read_json("res://data/chapter181.json")
	data_chapter182 = _read_json("res://data/chapter182.json")
	data_chapter183 = _read_json("res://data/chapter183.json")
	data_chapter184 = _read_json("res://data/chapter184.json")
	data_chapter185 = _read_json("res://data/chapter185.json")
	data_chapter186 = _read_json("res://data/chapter186.json")
	data_chapter187 = _read_json("res://data/chapter187.json")
	data_chapter188 = _read_json("res://data/chapter188.json")
	data_chapter189 = _read_json("res://data/chapter189.json")
	data_chapter190 = _read_json("res://data/chapter190.json")
	data_chapter191 = _read_json("res://data/chapter191.json")
	data_chapter192 = _read_json("res://data/chapter192.json")
	data_chapter193 = _read_json("res://data/chapter193.json")
	data_chapter194 = _read_json("res://data/chapter194.json")
	data_chapter195 = _read_json("res://data/chapter195.json")
	data_chapter196 = _read_json("res://data/chapter196.json")
	data_chapter197 = _read_json("res://data/chapter197.json")
	data_chapter198 = _read_json("res://data/chapter198.json")
	data_chapter199 = _read_json("res://data/chapter199.json")
	data_chapter200 = _read_json("res://data/chapter200.json")
	data_chapter201 = _read_json("res://data/chapter201.json")
	data_chapter202 = _read_json("res://data/chapter202.json")
	data_chapter203 = _read_json("res://data/chapter203.json")
	data_chapter204 = _read_json("res://data/chapter204.json")
	data_chapter205 = _read_json("res://data/chapter205.json")
	data_chapter206 = _read_json("res://data/chapter206.json")
	data_chapter207 = _read_json("res://data/chapter207.json")
	data_chapter208 = _read_json("res://data/chapter208.json")
	data_chapter209 = _read_json("res://data/chapter209.json")
	data_chapter210 = _read_json("res://data/chapter210.json")
	data_chapter211 = _read_json("res://data/chapter211.json")
	data_chapter212 = _read_json("res://data/chapter212.json")
	data_chapter213 = _read_json("res://data/chapter213.json")
	data_chapter214 = _read_json("res://data/chapter214.json")
	data_chapter215 = _read_json("res://data/chapter215.json")
	data_chapter216 = _read_json("res://data/chapter216.json")
	data_chapter217 = _read_json("res://data/chapter217.json")
	data_chapter218 = _read_json("res://data/chapter218.json")
	data_chapter219 = _read_json("res://data/chapter219.json")
	data_chapter220 = _read_json("res://data/chapter220.json")
	data_chapter221 = _read_json("res://data/chapter221.json")
	data_chapter222 = _read_json("res://data/chapter222.json")
	data_chapter223 = _read_json("res://data/chapter223.json")
	data_chapter224 = _read_json("res://data/chapter224.json")
	data_chapter225 = _read_json("res://data/chapter225.json")
	data_chapter226 = _read_json("res://data/chapter226.json")
	data_chapter227 = _read_json("res://data/chapter227.json")
	data_chapter228 = _read_json("res://data/chapter228.json")
	data_chapter229 = _read_json("res://data/chapter229.json")
	data_chapter230 = _read_json("res://data/chapter230.json")
	data_chapter231 = _read_json("res://data/chapter231.json")
	data_chapter232 = _read_json("res://data/chapter232.json")
	data_chapter233 = _read_json("res://data/chapter233.json")
	data_chapter234 = _read_json("res://data/chapter234.json")
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
	chapter109_beat = "109.0"
	chapter110_beat = "110.0"
	chapter111_beat = "111.0"
	chapter112_beat = "112.0"
	chapter113_beat = "113.0"
	chapter114_beat = "114.0"
	chapter115_beat = "115.0"
	chapter116_beat = "116.0"
	chapter117_beat = "117.0"
	chapter118_beat = "118.0"
	chapter119_beat = "119.0"
	chapter120_beat = "120.0"
	chapter121_beat = "121.0"
	chapter122_beat = "122.0"
	chapter123_beat = "123.0"
	chapter124_beat = "124.0"
	chapter125_beat = "125.0"
	chapter126_beat = "126.0"
	chapter127_beat = "127.0"
	chapter128_beat = "128.0"
	chapter129_beat = "129.0"
	chapter130_beat = "130.0"
	chapter131_beat = "131.0"
	chapter132_beat = "132.0"
	chapter133_beat = "133.0"
	chapter134_beat = "134.0"
	chapter135_beat = "135.0"
	chapter136_beat = "136.0"
	chapter137_beat = "137.0"
	chapter138_beat = "138.0"
	chapter139_beat = "139.0"
	chapter140_beat = "140.0"
	chapter141_beat = "141.0"
	chapter142_beat = "142.0"
	chapter143_beat = "143.0"
	chapter144_beat = "144.0"
	chapter145_beat = "145.0"
	chapter146_beat = "146.0"
	chapter147_beat = "147.0"
	chapter148_beat = "148.0"
	chapter149_beat = "149.0"
	chapter150_beat = "150.0"
	chapter151_beat = "151.0"
	chapter152_beat = "152.0"
	chapter153_beat = "153.0"
	chapter154_beat = "154.0"
	chapter155_beat = "155.0"
	chapter156_beat = "156.0"
	chapter157_beat = "157.0"
	chapter158_beat = "158.0"
	chapter159_beat = "159.0"
	chapter160_beat = "160.0"
	chapter161_beat = "161.0"
	chapter162_beat = "162.0"
	chapter163_beat = "163.0"
	chapter164_beat = "164.0"
	chapter165_beat = "165.0"
	chapter166_beat = "166.0"
	chapter167_beat = "167.0"
	chapter168_beat = "168.0"
	chapter169_beat = "169.0"
	chapter170_beat = "170.0"
	chapter171_beat = "171.0"
	chapter172_beat = "172.0"
	chapter173_beat = "173.0"
	chapter174_beat = "174.0"
	chapter175_beat = "175.0"
	chapter176_beat = "176.0"
	chapter177_beat = "177.0"
	chapter178_beat = "178.0"
	chapter179_beat = "179.0"
	chapter180_beat = "180.0"
	chapter181_beat = "181.0"
	chapter182_beat = "182.0"
	chapter183_beat = "183.0"
	chapter184_beat = "184.0"
	chapter185_beat = "185.0"
	chapter186_beat = "186.0"
	chapter187_beat = "187.0"
	chapter188_beat = "188.0"
	chapter189_beat = "189.0"
	chapter190_beat = "190.0"
	chapter191_beat = "191.0"
	chapter192_beat = "192.0"
	chapter193_beat = "193.0"
	chapter194_beat = "194.0"
	chapter195_beat = "195.0"
	chapter196_beat = "196.0"
	chapter197_beat = "197.0"
	chapter198_beat = "198.0"
	chapter199_beat = "199.0"
	chapter200_beat = "200.0"
	chapter201_beat = "201.0"
	chapter202_beat = "202.0"
	chapter203_beat = "203.0"
	chapter204_beat = "204.0"
	chapter205_beat = "205.0"
	chapter206_beat = "206.0"
	chapter207_beat = "207.0"
	chapter208_beat = "208.0"
	chapter209_beat = "209.0"
	chapter210_beat = "210.0"
	chapter211_beat = "211.0"
	chapter212_beat = "212.0"
	chapter213_beat = "213.0"
	chapter214_beat = "214.0"
	chapter215_beat = "215.0"
	chapter216_beat = "216.0"
	chapter217_beat = "217.0"
	chapter218_beat = "218.0"
	chapter219_beat = "219.0"
	chapter220_beat = "220.0"
	chapter221_beat = "221.0"
	chapter222_beat = "222.0"
	chapter223_beat = "223.0"
	chapter224_beat = "224.0"
	chapter225_beat = "225.0"
	chapter226_beat = "226.0"
	chapter227_beat = "227.0"
	chapter228_beat = "228.0"
	chapter229_beat = "229.0"
	chapter230_beat = "230.0"
	chapter231_beat = "231.0"
	chapter232_beat = "232.0"
	chapter233_beat = "233.0"
	chapter234_beat = "234.0"
	rival_stances = {"shuoying": "hostile", "qinghe": "wary", "lantern": "neutral"}
	rival_deals.clear()
	skill_points = 1
	chapter0_flags = {}
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
	return {
		"food": int(def.get("food", 0)) * mul,
		"silver": int(def.get("silver", 0)) * mul,
		"herb": int(def.get("herb", 0)) * mul,
		"rep": int(def.get("rep", 0)) * mul,
		"steward": st != null,
		"trait_bonus": trait_bonus,
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
			"trade":
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
	mark_dirty()
	return msgs

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
	var prod = 25 + shrine_level * 8 + building_level("hall") * 3
	food += prod
	var sil = 15 + building_level("market") * 5
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
		"chapter109_beat": chapter109_beat,
		"chapter110_beat": chapter110_beat,
		"chapter111_beat": chapter111_beat,
		"chapter112_beat": chapter112_beat,
		"chapter113_beat": chapter113_beat,
		"chapter114_beat": chapter114_beat,
		"chapter115_beat": chapter115_beat,
		"chapter116_beat": chapter116_beat,
		"chapter117_beat": chapter117_beat,
		"chapter118_beat": chapter118_beat,
		"chapter119_beat": chapter119_beat,
		"chapter120_beat": chapter120_beat,
		"chapter121_beat": chapter121_beat,
		"chapter122_beat": chapter122_beat,
		"chapter123_beat": chapter123_beat,
		"chapter124_beat": chapter124_beat,
		"chapter125_beat": chapter125_beat,
		"chapter126_beat": chapter126_beat,
		"chapter127_beat": chapter127_beat,
		"chapter128_beat": chapter128_beat,
		"chapter129_beat": chapter129_beat,
		"chapter130_beat": chapter130_beat,
		"chapter131_beat": chapter131_beat,
		"chapter132_beat": chapter132_beat,
		"chapter133_beat": chapter133_beat,
		"chapter134_beat": chapter134_beat,
		"chapter135_beat": chapter135_beat,
		"chapter136_beat": chapter136_beat,
		"chapter137_beat": chapter137_beat,
		"chapter138_beat": chapter138_beat,
		"chapter139_beat": chapter139_beat,
		"chapter140_beat": chapter140_beat,
		"chapter141_beat": chapter141_beat,
		"chapter142_beat": chapter142_beat,
		"chapter143_beat": chapter143_beat,
		"chapter144_beat": chapter144_beat,
		"chapter145_beat": chapter145_beat,
		"chapter146_beat": chapter146_beat,
		"chapter147_beat": chapter147_beat,
		"chapter148_beat": chapter148_beat,
		"chapter149_beat": chapter149_beat,
		"chapter150_beat": chapter150_beat,
		"chapter151_beat": chapter151_beat,
		"chapter152_beat": chapter152_beat,
		"chapter153_beat": chapter153_beat,
		"chapter154_beat": chapter154_beat,
		"chapter155_beat": chapter155_beat,
		"chapter156_beat": chapter156_beat,
		"chapter157_beat": chapter157_beat,
		"chapter158_beat": chapter158_beat,
		"chapter159_beat": chapter159_beat,
		"chapter160_beat": chapter160_beat,
		"chapter161_beat": chapter161_beat,
		"chapter162_beat": chapter162_beat,
		"chapter163_beat": chapter163_beat,
		"chapter164_beat": chapter164_beat,
		"chapter165_beat": chapter165_beat,
		"chapter166_beat": chapter166_beat,
		"chapter167_beat": chapter167_beat,
		"chapter168_beat": chapter168_beat,
		"chapter169_beat": chapter169_beat,
		"chapter170_beat": chapter170_beat,
		"chapter171_beat": chapter171_beat,
		"chapter172_beat": chapter172_beat,
		"chapter173_beat": chapter173_beat,
		"chapter174_beat": chapter174_beat,
		"chapter175_beat": chapter175_beat,
		"chapter176_beat": chapter176_beat,
		"chapter177_beat": chapter177_beat,
		"chapter178_beat": chapter178_beat,
		"chapter179_beat": chapter179_beat,
		"chapter180_beat": chapter180_beat,
		"chapter181_beat": chapter181_beat,
		"chapter182_beat": chapter182_beat,
		"chapter183_beat": chapter183_beat,
		"chapter184_beat": chapter184_beat,
		"chapter185_beat": chapter185_beat,
		"chapter186_beat": chapter186_beat,
		"chapter187_beat": chapter187_beat,
		"chapter188_beat": chapter188_beat,
		"chapter189_beat": chapter189_beat,
		"chapter190_beat": chapter190_beat,
		"chapter191_beat": chapter191_beat,
		"chapter192_beat": chapter192_beat,
		"chapter193_beat": chapter193_beat,
		"chapter194_beat": chapter194_beat,
		"chapter195_beat": chapter195_beat,
		"chapter196_beat": chapter196_beat,
		"chapter197_beat": chapter197_beat,
		"chapter198_beat": chapter198_beat,
		"chapter199_beat": chapter199_beat,
		"chapter200_beat": chapter200_beat,
		"chapter201_beat": chapter201_beat,
		"chapter202_beat": chapter202_beat,
		"chapter203_beat": chapter203_beat,
		"chapter204_beat": chapter204_beat,
		"chapter205_beat": chapter205_beat,
		"chapter206_beat": chapter206_beat,
		"chapter207_beat": chapter207_beat,
		"chapter208_beat": chapter208_beat,
		"chapter209_beat": chapter209_beat,
		"chapter210_beat": chapter210_beat,
		"chapter211_beat": chapter211_beat,
		"chapter212_beat": chapter212_beat,
		"chapter213_beat": chapter213_beat,
		"chapter214_beat": chapter214_beat,
		"chapter215_beat": chapter215_beat,
		"chapter216_beat": chapter216_beat,
		"chapter217_beat": chapter217_beat,
		"chapter218_beat": chapter218_beat,
		"chapter219_beat": chapter219_beat,
		"chapter220_beat": chapter220_beat,
		"chapter221_beat": chapter221_beat,
		"chapter222_beat": chapter222_beat,
		"chapter223_beat": chapter223_beat,
		"chapter224_beat": chapter224_beat,
		"chapter225_beat": chapter225_beat,
		"chapter226_beat": chapter226_beat,
		"chapter227_beat": chapter227_beat,
		"chapter228_beat": chapter228_beat,
		"chapter229_beat": chapter229_beat,
		"chapter230_beat": chapter230_beat,
		"chapter231_beat": chapter231_beat,
		"chapter232_beat": chapter232_beat,
		"chapter233_beat": chapter233_beat,
		"chapter234_beat": chapter234_beat,
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
		"buildings": buildings.duplicate(true),
		"house_mods": house_mods.duplicate(true),
		"quest_done": quest_done.duplicate(true),
		"advisor_bonus": advisor_bonus.duplicate(true),
		"ambition_done": ambition_done.duplicate(true),
		"holdings": holdings.duplicate(true),
		"doctrine_months": doctrine_months,
		"estate_quiet_months": estate_quiet_months,
		"patrol_cooldown": patrol_cooldown,
		"patrol_boost_months": patrol_boost_months,
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
	chapter109_beat = str(data.get("chapter109_beat", "109.0"))
	chapter110_beat = str(data.get("chapter110_beat", "110.0"))
	chapter111_beat = str(data.get("chapter111_beat", "111.0"))
	chapter112_beat = str(data.get("chapter112_beat", "112.0"))
	chapter113_beat = str(data.get("chapter113_beat", "113.0"))
	chapter114_beat = str(data.get("chapter114_beat", "114.0"))
	chapter115_beat = str(data.get("chapter115_beat", "115.0"))
	chapter116_beat = str(data.get("chapter116_beat", "116.0"))
	chapter117_beat = str(data.get("chapter117_beat", "117.0"))
	chapter118_beat = str(data.get("chapter118_beat", "118.0"))
	chapter119_beat = str(data.get("chapter119_beat", "119.0"))
	chapter120_beat = str(data.get("chapter120_beat", "120.0"))
	chapter121_beat = str(data.get("chapter121_beat", "121.0"))
	chapter122_beat = str(data.get("chapter122_beat", "122.0"))
	chapter123_beat = str(data.get("chapter123_beat", "123.0"))
	chapter124_beat = str(data.get("chapter124_beat", "124.0"))
	chapter125_beat = str(data.get("chapter125_beat", "125.0"))
	chapter126_beat = str(data.get("chapter126_beat", "126.0"))
	chapter127_beat = str(data.get("chapter127_beat", "127.0"))
	chapter128_beat = str(data.get("chapter128_beat", "128.0"))
	chapter129_beat = str(data.get("chapter129_beat", "129.0"))
	chapter130_beat = str(data.get("chapter130_beat", "130.0"))
	chapter131_beat = str(data.get("chapter131_beat", "131.0"))
	chapter132_beat = str(data.get("chapter132_beat", "132.0"))
	chapter133_beat = str(data.get("chapter133_beat", "133.0"))
	chapter134_beat = str(data.get("chapter134_beat", "134.0"))
	chapter135_beat = str(data.get("chapter135_beat", "135.0"))
	chapter136_beat = str(data.get("chapter136_beat", "136.0"))
	chapter137_beat = str(data.get("chapter137_beat", "137.0"))
	chapter138_beat = str(data.get("chapter138_beat", "138.0"))
	chapter139_beat = str(data.get("chapter139_beat", "139.0"))
	chapter140_beat = str(data.get("chapter140_beat", "140.0"))
	chapter141_beat = str(data.get("chapter141_beat", "141.0"))
	chapter142_beat = str(data.get("chapter142_beat", "142.0"))
	chapter143_beat = str(data.get("chapter143_beat", "143.0"))
	chapter144_beat = str(data.get("chapter144_beat", "144.0"))
	chapter145_beat = str(data.get("chapter145_beat", "145.0"))
	chapter146_beat = str(data.get("chapter146_beat", "146.0"))
	chapter147_beat = str(data.get("chapter147_beat", "147.0"))
	chapter148_beat = str(data.get("chapter148_beat", "148.0"))
	chapter149_beat = str(data.get("chapter149_beat", "149.0"))
	chapter150_beat = str(data.get("chapter150_beat", "150.0"))
	chapter151_beat = str(data.get("chapter151_beat", "151.0"))
	chapter152_beat = str(data.get("chapter152_beat", "152.0"))
	chapter153_beat = str(data.get("chapter153_beat", "153.0"))
	chapter154_beat = str(data.get("chapter154_beat", "154.0"))
	chapter155_beat = str(data.get("chapter155_beat", "155.0"))
	chapter156_beat = str(data.get("chapter156_beat", "156.0"))
	chapter157_beat = str(data.get("chapter157_beat", "157.0"))
	chapter158_beat = str(data.get("chapter158_beat", "158.0"))
	chapter159_beat = str(data.get("chapter159_beat", "159.0"))
	chapter160_beat = str(data.get("chapter160_beat", "160.0"))
	chapter161_beat = str(data.get("chapter161_beat", "161.0"))
	chapter162_beat = str(data.get("chapter162_beat", "162.0"))
	chapter163_beat = str(data.get("chapter163_beat", "163.0"))
	chapter164_beat = str(data.get("chapter164_beat", "164.0"))
	chapter165_beat = str(data.get("chapter165_beat", "165.0"))
	chapter166_beat = str(data.get("chapter166_beat", "166.0"))
	chapter167_beat = str(data.get("chapter167_beat", "167.0"))
	chapter168_beat = str(data.get("chapter168_beat", "168.0"))
	chapter169_beat = str(data.get("chapter169_beat", "169.0"))
	chapter170_beat = str(data.get("chapter170_beat", "170.0"))
	chapter171_beat = str(data.get("chapter171_beat", "171.0"))
	chapter172_beat = str(data.get("chapter172_beat", "172.0"))
	chapter173_beat = str(data.get("chapter173_beat", "173.0"))
	chapter174_beat = str(data.get("chapter174_beat", "174.0"))
	chapter175_beat = str(data.get("chapter175_beat", "175.0"))
	chapter176_beat = str(data.get("chapter176_beat", "176.0"))
	chapter177_beat = str(data.get("chapter177_beat", "177.0"))
	chapter178_beat = str(data.get("chapter178_beat", "178.0"))
	chapter179_beat = str(data.get("chapter179_beat", "179.0"))
	chapter180_beat = str(data.get("chapter180_beat", "180.0"))
	chapter181_beat = str(data.get("chapter181_beat", "181.0"))
	chapter182_beat = str(data.get("chapter182_beat", "182.0"))
	chapter183_beat = str(data.get("chapter183_beat", "183.0"))
	chapter184_beat = str(data.get("chapter184_beat", "184.0"))
	chapter185_beat = str(data.get("chapter185_beat", "185.0"))
	chapter186_beat = str(data.get("chapter186_beat", "186.0"))
	chapter187_beat = str(data.get("chapter187_beat", "187.0"))
	chapter188_beat = str(data.get("chapter188_beat", "188.0"))
	chapter189_beat = str(data.get("chapter189_beat", "189.0"))
	chapter190_beat = str(data.get("chapter190_beat", "190.0"))
	chapter191_beat = str(data.get("chapter191_beat", "191.0"))
	chapter192_beat = str(data.get("chapter192_beat", "192.0"))
	chapter193_beat = str(data.get("chapter193_beat", "193.0"))
	chapter194_beat = str(data.get("chapter194_beat", "194.0"))
	chapter195_beat = str(data.get("chapter195_beat", "195.0"))
	chapter196_beat = str(data.get("chapter196_beat", "196.0"))
	chapter197_beat = str(data.get("chapter197_beat", "197.0"))
	chapter198_beat = str(data.get("chapter198_beat", "198.0"))
	chapter199_beat = str(data.get("chapter199_beat", "199.0"))
	chapter200_beat = str(data.get("chapter200_beat", "200.0"))
	chapter201_beat = str(data.get("chapter201_beat", "201.0"))
	chapter202_beat = str(data.get("chapter202_beat", "202.0"))
	chapter203_beat = str(data.get("chapter203_beat", "203.0"))
	chapter204_beat = str(data.get("chapter204_beat", "204.0"))
	chapter205_beat = str(data.get("chapter205_beat", "205.0"))
	chapter206_beat = str(data.get("chapter206_beat", "206.0"))
	chapter207_beat = str(data.get("chapter207_beat", "207.0"))
	chapter208_beat = str(data.get("chapter208_beat", "208.0"))
	chapter209_beat = str(data.get("chapter209_beat", "209.0"))
	chapter210_beat = str(data.get("chapter210_beat", "210.0"))
	chapter211_beat = str(data.get("chapter211_beat", "211.0"))
	chapter212_beat = str(data.get("chapter212_beat", "212.0"))
	chapter213_beat = str(data.get("chapter213_beat", "213.0"))
	chapter214_beat = str(data.get("chapter214_beat", "214.0"))
	chapter215_beat = str(data.get("chapter215_beat", "215.0"))
	chapter216_beat = str(data.get("chapter216_beat", "216.0"))
	chapter217_beat = str(data.get("chapter217_beat", "217.0"))
	chapter218_beat = str(data.get("chapter218_beat", "218.0"))
	chapter219_beat = str(data.get("chapter219_beat", "219.0"))
	chapter220_beat = str(data.get("chapter220_beat", "220.0"))
	chapter221_beat = str(data.get("chapter221_beat", "221.0"))
	chapter222_beat = str(data.get("chapter222_beat", "222.0"))
	chapter223_beat = str(data.get("chapter223_beat", "223.0"))
	chapter224_beat = str(data.get("chapter224_beat", "224.0"))
	chapter225_beat = str(data.get("chapter225_beat", "225.0"))
	chapter226_beat = str(data.get("chapter226_beat", "226.0"))
	chapter227_beat = str(data.get("chapter227_beat", "227.0"))
	chapter228_beat = str(data.get("chapter228_beat", "228.0"))
	chapter229_beat = str(data.get("chapter229_beat", "229.0"))
	chapter230_beat = str(data.get("chapter230_beat", "230.0"))
	chapter231_beat = str(data.get("chapter231_beat", "231.0"))
	chapter232_beat = str(data.get("chapter232_beat", "232.0"))
	chapter233_beat = str(data.get("chapter233_beat", "233.0"))
	chapter234_beat = str(data.get("chapter234_beat", "234.0"))
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
	doctrine_months = int(data.get("doctrine_months", 0))
	estate_quiet_months = int(data.get("estate_quiet_months", 0))
	patrol_cooldown = int(data.get("patrol_cooldown", 0))
	patrol_boost_months = int(data.get("patrol_boost_months", 0))
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
