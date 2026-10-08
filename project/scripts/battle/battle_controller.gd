extends Control
## 灰旗战棋：8x6 教程图，移动/攻击/待命，敌 AI，规则透视
## 输入 FSM：IDLE → SELECTED → (MOVE) → ATTACK_AIM → 单位 done

var CELL: int = 56
var ORIGIN: Vector2 = Vector2(40, 80)
## v8.6: the board is the hero — cell size fits the map into the left stage (max 104px)
const BOARD_AREA := Rect2(24, 76, 856, 620)
const RAIL_X := 904.0
const RAIL_W := 352.0
var _ground: ColorRect
## v8.6 3D combat cutscenes: pure recorder (tactics logic untouched) -> queued overlay playback
const CombatCutsceneScript = preload("res://scripts/battle/combat_cutscene.gd")
var _combat_rec: Array = []
var _cut_queue: Array = []
var _cut_playing := false
const TERRAIN_IDS := {"plain": 0, "forest": 1, "hill": 2, "water": 3, "fort": 4, "bridge": 5}
var MAP_W: int = 8
var MAP_H: int = 6
var map_id: String = "ch0_pass"
var map_name: String = "隘口之夜"

var terrain: Array = []
var units: Array = []
var turn_team: String = "player"
var selected: int = -1
var move_cells: Dictionary = {}
var attack_mode: bool = false
var moved_this_select: bool = false
var log_label: Label
var info_label: RichTextLabel
var phase_label: Label
var overlay: Node2D
var map_draw: Node2D
var rng := RandomNumberGenerator.new()
var battle_over: bool = false
var _bg: ColorRect
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _zoc_hover_kind: String = ""  # "", "lock3", "leave2", "zoc"
var _banner_tex: TextureRect
var _unit_panel: PanelContainer
var _portrait: TextureRect
const UnitCardScript = preload("res://scripts/ui/unit_card.gd")
var _unit_card: Control
## v8.5 authored FX draw sizes (px) — 56px cells; 128px sources downsampled for crisp reads
const FX_SIZE := {"slash": 80.0, "heal": 84.0, "crit": 108.0, "lock": 80.0, "shield": 80.0, "spark": 76.0}
var _info_traits: HBoxContainer
var _dmg_fx: Array = []  # {pos, text, age, col}
var _turn_flash: float = 0.0
var _sel_pulse: float = 0.0
var _btn_atk: Button
var _btn_wait: Button
var _btn_end: Button
var _slash_fx: Array = []  # {pos, age, frame}
var _lock_burst_fx: Array = []  # {pos, age}
var _move_dust_fx: Array = []  # {pos, age}
var _shake: float = 0.0
var _trauma: float = 0.0  # game-feel trauma 0..1
var _shake_t: float = 0.0
var skill_mode: bool = false
var active_skill_id: String = ""
var _banter_idx: int = 0
var _banter_kill: int = 0
var _banter_played: Dictionary = {}
var _btn_skill: Button
var _skill_hint: Label


const ESCORT_BANTER_TURN := [
	"【镖行】管事：护车！别让他们摸到辕木。",
	"【镖行】老旗手：路引还在，旗就不能倒。",
	"【镖行】斥候：左翼有伏弓气味——压低身子。",
	"【镖行】苇原·灯影：车轮声一乱，就是劫道开手。",
]
const ESCORT_BANTER_KILL := [
	"【镖行】劫镖毛贼：……路引……不该撕……",
	"【镖行】劫道悍匪：灰旗……也护货？",
	"【镖行】关口伏弓：关印……不在你们手里……",
	"【镖行】老旗手：一匪倒，镖路清一寸。",
	"【镖行】管事：别追太深——车还在中间。",
]
const HARBOR_BANTER_TURN := [
	"【渔港】管事：护缆！别让他们摸到桩木。",
	"【渔港】老旗手：潮笺还在，旗就不能倒。",
	"【渔港】斥候：礁后有伏弓气味——压低身子。",
	"【渔港】苇原·灯影：浪声一乱，就是水匪开手。",
	"【渔港】斥候：东礁有影——别把背对着水。",
	"【渔港】管事：缆要双人守。一人守，必断。",
	"【渔港】老旗手：灯在，船才认得姓。",
]
const HARBOR_BANTER_KILL := [
	"【渔港】渔港水匪：……缆……不该割……",
	"【渔港】礁口伏弓：灯桩……不在你们手里……",
	"【渔港】老旗手：一匪倒，港路清一寸。",
	"【渔港】管事：别追太深——船还在桥间。",
	"【渔港】港匪头目：潮笺……是假的……",
	"【渔港】春令使者：沉的是匪，不是港。",
]
const HARBOR_BANTER_START := [
	"【渔港】春令使者：这一仗验的是姓，不是潮。",
	"【渔港】系统：港灯已升。护船优先于斩杀。",
	"【渔港】管事：水边开战——先站稳，再挥刀。",
]
const PAPER_BANTER_TURN := [
	"【纸坊】管事：护帘！别让墨溅上未干的纸。",
	"【纸坊】老旗手：笺角还在，旗就不能倒。",
	"【纸坊】斥候：浆槽有人泼沙——先清桥。",
	"【纸坊】苇原·灯影：纸一响，就是撕帘开手。",
	"【纸坊】管事：轻步进。重步震裂湿纸。",
]
const PAPER_BANTER_KILL := [
	"【纸坊】纸坊毛贼：……帘……不该撕……",
	"【纸坊】浆槽伏弓：印纽……不在你们手里……",
	"【纸坊】老旗手：一贼倒，纸路清一寸。",
	"【纸坊】管事：别追太深——帘还在架上。",
	"【纸坊】纸坊匪首：白纸……写不出假姓……",
]
const PAPER_BANTER_START := [
	"【纸坊】春令使者：这一仗验的是姓，不是墨。",
	"【纸坊】系统：纸帘已升。护纸优先于斩杀。",
	"【纸坊】管事：禁火。一星火，满坊尽废。",
	"【纸坊】老旗手：诏板未立，旗也不算立。",
]
const COPPER_BANTER_TURN := [
	"【铜市】管事：护炉！别让他们泼灭火。",
	"【铜市】老旗手：炉票还在，旗就不能倒。",
	"【铜市】斥候：矿道有伏弓气味——压低身子。",
	"【铜市】苇原·灯影：火星一乱，就是盗铜开手。",
	"【铜市】管事：顺火推进。逆火灼己。",
	"【铜市】斥候：甲库东垒有影——别把背对着架。",
	"【铜市】老旗手：渣道一堵，炉就喘不上气。",
]
const COPPER_BANTER_KILL := [
	"【铜市】铜市悍匪：……炉……不该熄……",
	"【铜市】矿道伏弓：烙铁……不在你们手里……",
	"【铜市】老旗手：一匪倒，铜路清一寸。",
	"【铜市】管事：别追太深——炉还在中间。",
	"【铜市】铜市匪首：假锭……铸不出真甲……",
	"【铜市】春令使者：砸的是贼，不是炉。",
]
const COPPER_BANTER_START := [
	"【铜市】春令使者：这一仗验的是姓，不是火。",
	"【铜市】系统：铜炉已升。护火优先于斩杀。",
	"【铜市】管事：护甲未成，先别浪战。",
	"【铜市】老旗手：甲未合，旗也不算立。",
]
const LANTERN_BANTER_TURN := [
	"【灯市】管事：护灯！别让他们泼灭火。",
	"【灯市】老旗手：灯花笺还在，旗就不能倒。",
	"【灯市】斥候：油库有贼气味——压低身子。",
	"【灯市】苇原·灯影：灯一灭，就是盗油开手。",
	"【灯市】管事：顺灯推进。逆风燎己。",
	"【灯市】斥候：灯塔东垒有影——别把背对着火。",
	"【灯市】老旗手：油道一断，塔就喘不上气。",
]
const LANTERN_BANTER_KILL := [
	"【灯市】灯市毛贼：……灯……不该灭……",
	"【灯市】油库伏弓：笼底……不在你们手里……",
	"【灯市】老旗手：一贼倒，灯路清一寸。",
	"【灯市】管事：别追太深——灯还在街上。",
	"【灯市】灯市匪首：空笼……照不出真姓……",
	"【灯市】春令使者：灭的是贼，不是夜。",
]
const LANTERN_BANTER_START := [
	"【灯市】春令使者：这一仗验的是姓，不是火。",
	"【灯市】系统：灯笼已升。护火优先于斩杀。",
	"【灯市】管事：夜未明，先别浪战。",
	"【灯市】老旗手：塔灯未立，夜也不算明。",
]
const GRAIN_BANTER_TURN := [
	"【粮仓】管事：护囤！别让他们纵火。",
	"【粮仓】老旗手：仓票还在，旗就不能倒。",
	"【粮仓】斥候：碾坊有贼气味——压低身子。",
	"【粮仓】苇原·灯影：火一亮，就是盗粮开手。",
	"【粮仓】管事：禁火推进。一星火，满仓尽废。",
	"【粮仓】春令使者：开仓验的是姓，不是斗。",
	"【粮仓】斥候：漕路北桥优先——路断了义仓开不了。",
]
const GRAIN_BANTER_KILL := [
	"【粮仓】粮仓悍匪：……囤……不该烧……",
	"【粮仓】碾坊伏弓：仓门……不在你们手里……",
	"【粮仓】老旗手：一匪倒，粮路清一寸。",
	"【粮仓】管事：别追太深——粮还在中间。",
	"【粮仓】粮仓匪首：空票……养不活真姓……",
]
const GRAIN_BANTER_START := [
	"【粮仓】春令使者：这一仗验的是姓，不是斗。",
	"【粮仓】系统：粮囤已升。护粮优先于斩杀。",
	"【粮仓】管事：民未饱，先别浪战。",
]
const SNOW_BANTER_TURN := [
	"【雪栈】管事：护火！别让他们埋炭。",
	"【雪栈】老旗手：暖票还在，旗就不能倒。",
	"【雪栈】斥候：栈道有贼气味——压低身子。",
	"【雪栈】苇原·灯影：火一灭，就是劫暖开手。",
	"【雪栈】管事：禁灭推进。一星灭，满岭尽冻。",
	"【雪栈】春令使者：雪市验的是姓，不是炭。",
	"【雪栈】斥候：炭道北桥优先——道断了暖驿开不了。",
]
const SNOW_BANTER_KILL := [
	"【雪栈】雪栈悍匪：……炭……不该埋……",
	"【雪栈】冰廊伏弓：栈门……不在你们手里……",
	"【雪栈】老旗手：一匪倒，暖路清一寸。",
	"【雪栈】管事：别追太深——炭还在中间。",
	"【雪栈】雪栈匪首：空票……养不活真姓……",
]
const SNOW_BANTER_START := [
	"【雪栈】春令使者：这一仗验的是姓，不是雪。",
	"【雪栈】系统：雪栈已升。护暖优先于斩杀。",
	"【雪栈】管事：民未暖，先别浪战。",
]
const BAMBOO_BANTER_TURN := [
	"【竹海】管事：护径！别让他们纵火。",
	"【竹海】老旗手：笋票还在，旗就不能倒。",
	"【竹海】斥候：篁径有贼气味——压低身子。",
	"【竹海】苇原·灯影：火一亮，就是劫径开手。",
	"【竹海】管事：禁火推进。一星火，满海尽盲。",
	"【竹海】斥候：筏渡桥位错开——别按旧图硬冲。",
	"【竹海】老旗手：曲尺祠两臂都要顾，丢一臂等于丢半海。",
	"【竹海】春令使者：望楼夹丘不利浪冲，先清索再登。",
]
const BAMBOO_BANTER_KILL := [
	"【竹海】竹海悍匪：……径……不该烧……",
	"【竹海】篁廊伏弓：篁门……不在你们手里……",
	"【竹海】老旗手：一匪倒，径清一寸。",
	"【竹海】管事：别追太深——笋还在中间。",
	"【竹海】竹海匪首：空票……养不活真姓……",
	"【竹海】斥候：筏工倒了，渡口清一桥。",
	"【竹海】苇原·灯影：祠匪既除，篁笺可验。",
]
const BAMBOO_BANTER_START := [
	"【竹海】春令使者：这一仗验的是姓，不是笋。",
	"【竹海】系统：竹海已升。护径优先于斩杀。",
	"【竹海】管事：民未出林，先别浪战。",
	"【竹海】老旗手：菱心垒要留治疗位——席终不收半旗。",
]
const RELAY_BANTER_TURN := [
	"【驿道】管事：护符！别让他们撕牌。",
	"【驿道】老旗手：符牌还在，旗就不能倒。",
	"【驿道】斥候：换马槽有贼气味——压低身子。",
	"【驿道】苇原·灯影：火一亮，就是劫符开手。",
	"【驿道】管事：禁火推进。一星火，满道尽盲。",
	"【驿道】斥候：斜丘不利硬冲——沿脊迂回。",
	"【驿道】老旗手：水环六桥，择一桥再夺牌，别全压。",
	"【驿道】春令使者：十字印台在心，先清臂再夺纽。",
	"【驿道】斥候：递路蛇水——弯桥先占，直线必湿。",
	"【驿道】老旗手：夜驿林环双垒，先西后东。",
	"【驿道】管事：丘环八向，别被角射撕开阵线。",
]
const RELAY_BANTER_KILL := [
	"【驿道】驿道悍匪：……符……不该撕……",
	"【驿道】递路伏弓：站门……不在你们手里……",
	"【驿道】老旗手：一匪倒，递路清一寸。",
	"【驿道】管事：别追太深——马还在槽里。",
	"【驿道】驿道匪首：空牌……递不出真姓……",
	"【驿道】斥候：截递的倒了，符匣可护。",
]
const RELAY_BANTER_START := [
	"【驿道】春令使者：这一仗验的是姓，不是马。",
	"【驿道】系统：驿道已升。护符优先于斩杀。",
	"【驿道】管事：信未出站，先别浪战。",
	"【驿道】老旗手：双院先近后远——远院空着也别急。",
]
const BELL_BANTER_TURN := [
	"【钟鼓】管事：护钟！别让他们哑声。",
	"【钟鼓】老旗手：声票还在，旗就不能倒。",
	"【钟鼓】斥候：鼓廊有贼气味——压低身子。",
	"【钟鼓】苇原·灯影：火一亮，就是劫声开手。",
	"【钟鼓】管事：禁火推进。一星火，满城尽哑。",
	"【钟鼓】斥候：夹丘不利浪冲——沿廊上钟楼。",
	"【钟鼓】老旗手：水环八桥，择桥再登，别全压。",
	"【钟鼓】春令使者：角丘有伏射，先清角再夺场心。",
	"【钟鼓】斥候：回廊凹字——外廊清完还要进内庭。",
	"【钟鼓】老旗手：竖井撞钟先清厢，硬冲北室必挨射。",
	"【钟鼓】管事：棋丘格交错，落脚先想第二步。",
	"【钟鼓】春令使者：套心席终——水桥、丘环、心垒三层都要过。",
]
const BELL_BANTER_KILL := [
	"【钟鼓】钟楼悍匪：……钟……不该哑……",
	"【钟鼓】鼓廊伏弓：楼门……不在你们手里……",
	"【钟鼓】老旗手：一匪倒，警声清一寸。",
	"【钟鼓】管事：别追太深——锤还在架上。",
	"【钟鼓】钟楼匪首：空票……警不醒真姓……",
	"【钟鼓】斥候：哑钟的倒了，锤可护。",
]
const BELL_BANTER_START := [
	"【钟鼓】春令使者：这一仗验的是姓，不是锤。",
	"【钟鼓】系统：钟鼓已升。护声优先于斩杀。",
	"【钟鼓】管事：城未警，先别浪战。",
	"【钟鼓】老旗手：双廊先合桥——断一廊等于半城哑。",
]

const RAIN_BANTER_TURN := [
	"【雨巷】管事：护伞！别让他们撕票。",
	"【雨巷】老旗手：檐票还在，旗就不能倒。",
	"【雨巷】斥候：窄廊有贼气味——压低身子。",
	"【雨巷】苇原·灯影：火一亮，就是劫伞开手。",
	"【雨巷】管事：禁火推进。一星火，满街尽湿。",
	"【雨巷】斥候：三廊择一——别分兵浪冲。",
	"【雨巷】老旗手：积水洼多，踩洼等于送死。",
	"【雨巷】春令使者：环棚先外后心，伞心在干处。",
	"【雨巷】斥候：三槽水道桥稀——错桥要绕远。",
	"【雨巷】管事：半水半街，印台那边别被水截断。",
	"【雨巷】斥候：浮岛雨市——择桥登岛，别涉水浪冲。",
	"【雨巷】老旗手：檐沟斜桥沿线走，水平硬冲必湿。",
	"【雨巷】管事：长檐下积水，落脚先看洼。",
	"【雨巷】春令使者：螺心席终——水槽三折，桥桥要核。",
]
const RAIN_BANTER_KILL := [
	"【雨巷】雨巷悍匪：……伞……不该撕……",
	"【雨巷】檐廊伏弓：巷口……不在你们手里……",
	"【雨巷】老旗手：一匪倒，檐路清一寸。",
	"【雨巷】管事：别追太深——伞还在架上。",
	"【雨巷】雨巷匪首：空票……遮不住真姓……",
	"【雨巷】斥候：撕票的倒了，伞可护。",
]
const RAIN_BANTER_START := [
	"【雨巷】春令使者：这一仗验的是姓，不是伞。",
	"【雨巷】系统：雨巷已升。护伞优先于斩杀。",
	"【雨巷】管事：人未干，先别浪战。",
	"【雨巷】老旗手：窄廊不利横队——纵列推进。",
]

const INK_BANTER_TURN := [
	"【砚市】管事：护砚！别让他们糊墨。",
	"【砚市】老旗手：墨票还在，旗就不能倒。",
	"【砚市】斥候：砚坑有贼气味——压低身子。",
	"【砚市】苇原·灯影：火一亮，就是劫墨开手。",
	"【砚市】管事：禁火推进。一星火，满案尽糊。",
	"【砚市】斥候：丘环十二向——择口推进，别分兵。",
	"【砚市】老旗手：墨池六桥，择桥登岛，别涉墨。",
	"【砚市】春令使者：双案合桥，心案才拿得稳。",
	"【砚市】斥候：印房丘套——破外丘再夺心。",
	"【砚市】斥候：棋摊环心——先清外摊再夺心块。",
	"【砚市】老旗手：研墨丘环，桥通岛石，错桥绕远。",
	"【砚市】管事：双柱捺印，合桥再夺心垒。",
	"【砚市】春令使者：墨溅辐射席终——桥桥要核，别涉墨。",
]
const INK_BANTER_KILL := [
	"【砚市】砚坑悍匪：……砚……不该砸……",
	"【砚市】墨池伏弓：坑口……不在你们手里……",
	"【砚市】老旗手：一匪倒，墨路清一寸。",
	"【砚市】管事：别追太深——砚还在案上。",
	"【砚市】砚坑匪首：空票……写不清真姓……",
	"【砚市】斥候：糊墨的倒了，砚可护。",
]
const INK_BANTER_START := [
	"【砚市】春令使者：这一仗验的是姓，不是石。",
	"【砚市】系统：砚市已升。护墨优先于斩杀。",
	"【砚市】管事：字未清，先别浪战。",
	"【砚市】老旗手：丘环不利横队——择口纵列。",
]

const HIVE_BANTER_TURN := [
	"【蜂场】管事：护脾！别让他们撕票。",
	"【蜂场】老旗手：蜜票还在，旗就不能倒。",
	"【蜂场】斥候：蜂巢有贼气味——压低身子。",
	"【蜂场】苇原·灯影：火一亮，就是劫蜜开手。",
	"【蜂场】管事：禁火推进。一星火，满陌尽蛰。",
	"【蜂场】斥候：簇房四组——先近后远，别分兵。",
	"【蜂场】老旗手：花陌曲径，别抄近路踏花。",
	"【蜂场】春令使者：烟熏双障，择桥再进心垒。",
	"【蜂场】斥候：蜜房格垒疏密交错，落脚先想第二步。",
	"【蜂场】斥候：蜜市环瓣——先清外瓣再夺心房。",
	"【蜂场】老旗手：蜂涌四围，中廊是活路，别被钉死。",
	"【蜂场】管事：蜂后丘环，择桥登心，别硬冲。",
	"【蜂场】春令使者：满格席终——心巢居中，疏密都要顾。",
]
const HIVE_BANTER_KILL := [
	"【蜂场】蜂场悍匪：……脾……不该烧……",
	"【蜂场】花陌伏弓：巢口……不在你们手里……",
	"【蜂场】老旗手：一匪倒，蜜路清一寸。",
	"【蜂场】管事：别追太深——脾还在房里。",
	"【蜂场】蜂场匪首：空票……甜不住真姓……",
	"【蜂场】斥候：撕票的倒了，脾可护。",
]
const HIVE_BANTER_START := [
	"【蜂场】春令使者：这一仗验的是姓，不是刺。",
	"【蜂场】系统：蜂场已升。护蜜优先于斩杀。",
	"【蜂场】管事：人未甜，先别浪战。",
	"【蜂场】老旗手：簇房不利横队——择簇纵列。",
]

const FLUTE_BANTER_TURN := [
	"【笛楼】管事：护笛！别让他们哑声。",
	"【笛楼】老旗手：声票还在，旗就不能倒。",
	"【笛楼】斥候：音廊有贼气味——压低身子。",
	"【笛楼】苇原·灯影：火一亮，就是劫声开手。",
	"【笛楼】管事：禁火推进。一星火，满楼尽哑。",
	"【笛楼】斥候：竖井不利浪冲——先清厢再登室。",
	"【笛楼】老旗手：双廊合桥，错一桥声过不去。",
	"【笛楼】春令使者：凹字回音——外廊清完还要进内庭。",
	"【笛楼】斥候：台口翼丘有伏射，先清翼再夺心。",
	"【笛楼】斥候：笛市列架——先清外摊再夺心架。",
	"【笛楼】老旗手：谱架三层，桥错落，别按一层硬冲。",
	"【笛楼】管事：独奏水环，择桥登台，别涉水。",
	"【笛楼】春令使者：丘环席终——心台居中，桥桥要核。",
]
const FLUTE_BANTER_KILL := [
	"【笛楼】笛楼悍匪：……笛……不该哑……",
	"【笛楼】音廊伏弓：楼口……不在你们手里……",
	"【笛楼】老旗手：一匪倒，曲声清一寸。",
	"【笛楼】管事：别追太深——笛还在架上。",
	"【笛楼】笛楼匪首：空票……奏不清真姓……",
	"【笛楼】斥候：哑笛的倒了，管可护。",
]
const FLUTE_BANTER_START := [
	"【笛楼】春令使者：这一仗验的是姓，不是管。",
	"【笛楼】系统：笛楼已升。护声优先于斩杀。",
	"【笛楼】管事：曲未成，先别浪战。",
	"【笛楼】老旗手：竖井不利横队——纵列上厢。",
]

const SHADOW_BANTER_TURN := [
	"【影戏】管事：护灯！别让他们散影。",
	"【影戏】老旗手：影票还在，旗就不能倒。",
	"【影戏】斥候：影幕有贼气味——压低身子。",
	"【影戏】苇原·灯影：火一亮，就是劫影开手。",
	"【影戏】管事：禁火推进。一星火，满幕尽散。",
	"【影戏】斥候：横屏中隔——择口绕进，别硬撞幕。",
	"【影戏】老旗手：四厢夹廊，中廊是活路。",
	"【影戏】春令使者：棋灯格交错，落脚先想第二步。",
	"【影戏】斥候：后台曲尺——外廊清完还要进内室。",
	"【影戏】斥候：影市棚廊——三列要择口。",
	"【影戏】管事：匣架竖廊，别砸匣纽。",
	"【影戏】老旗手：独影水镜，桥心是活路。",
	"【影戏】春令使者：夜幕林环，心台要护灯。",
]
const SHADOW_BANTER_KILL := [
	"【影戏】影戏悍匪：……灯……不该灭……",
	"【影戏】幕廊伏弓：幕口……不在你们手里……",
	"【影戏】老旗手：一匪倒，影路清一寸。",
	"【影戏】管事：别追太深——灯还在架上。",
	"【影戏】影戏匪首：空票……照不清真姓……",
	"【影戏】斥候：散影的倒了，灯可护。",
]
const SHADOW_BANTER_START := [
	"【影戏】春令使者：这一仗验的是姓，不是幕。",
	"【影戏】系统：影戏已升。护灯优先于斩杀。",
	"【影戏】管事：影未成，先别浪战。",
	"【影戏】老旗手：幕下不利横队——择口纵列。",
]
const SALT_BANTER_TURN := [
	"【盐滩】管事：护壳！别让他们踏碎盐皮。",
	"【盐滩】老旗手：卤渠还在，旗就不能倒。",
	"【盐滩】斥候：盐滩有贼气味——压低身子。",
	"【盐滩】苇原·灯影：卤一浑，就是劫盐开手。",
	"【盐滩】管事：禁乱踏。一脚碎壳，满滩尽白。",
	"【盐滩】斥候：卤渠中隔——择桥绕进，别硬蹚。",
	"【盐滩】老旗手：晒盘棋格，中盘是活路。",
	"【盐滩】春令使者：丘格交错，落脚先想第二步。",
	"【盐滩】斥候：盐堆软壳——外丘清完还要进心垒。",
	"【盐滩】斥候：盐市棚廊——三列要择口。",
	"【盐滩】管事：盐架竖廊，别砸架纽。",
	"【盐滩】老旗手：独晒水镜，桥心是活路。",
	"【盐滩】春令使者：夜卤丘环，心台要护壳。",
]
const SALT_BANTER_KILL := [
	"【盐滩】盐滩悍匪：……壳……不该碎……",
	"【盐滩】卤渠伏弓：滩口……不在你们手里……",
	"【盐滩】老旗手：一匪倒，卤路清一寸。",
	"【盐滩】管事：别追太深——盐还在盘上。",
	"【盐滩】盐滩匪首：空壳……晒不清真姓……",
	"【盐滩】斥候：碎壳的倒了，盐可护。",
]
const SALT_BANTER_START := [
	"【盐滩】春令使者：这一仗验的是姓，不是盐。",
	"【盐滩】系统：盐滩已升。护壳优先于斩杀。",
	"【盐滩】管事：盐未成，先别浪战。",
	"【盐滩】老旗手：卤下不利横队——择桥纵列。",
]
const DYE_BANTER_TURN := [
	"【染坊】管事：护色！别让他们翻缸。",
	"【染坊】老旗手：晾竿还在，旗就不能倒。",
	"【染坊】斥候：染坊有贼气味——压低身子。",
	"【染坊】苇原·灯影：色一浑，就是劫布开手。",
	"【染坊】管事：禁乱踏。一脚翻缸，满坊尽花。",
	"【染坊】斥候：染缸中隔——择桥绕进，别硬蹚。",
	"【染坊】老旗手：榨色棋格，中盘是活路。",
	"【染坊】春令使者：水格交错，落脚先想第二步。",
	"【染坊】斥候：晾竿湿布——外格清完还要进心垒。",
	"【染坊】斥候：色市棚廊——三列要择口。",
	"【染坊】管事：织架竖廊，别砸架纽。",
	"【染坊】老旗手：独染水镜，桥心是活路。",
	"【染坊】春令使者：夜色林环，心台要护色。",
]
const DYE_BANTER_KILL := [
	"【染坊】染坊悍匪：……缸……不该翻……",
	"【染坊】染缸伏弓：坊口……不在你们手里……",
	"【染坊】老旗手：一匪倒，色路清一寸。",
	"【染坊】管事：别追太深——布还在竿上。",
	"【染坊】染坊匪首：空色……染不清真姓……",
	"【染坊】斥候：翻缸的倒了，色可护。",
]
const DYE_BANTER_START := [
	"【染坊】春令使者：这一仗验的是姓，不是色。",
	"【染坊】系统：染坊已升。护色优先于斩杀。",
	"【染坊】管事：色未成，先别浪战。",
	"【染坊】老旗手：缸下不利横队——择桥纵列。",
]
const DRUM_BANTER_TURN := [
	"【鼓楼】管事：护拍！别让他们砸面。",
	"【鼓楼】老旗手：鼓廊还在，旗就不能倒。",
	"【鼓楼】斥候：鼓楼有贼气味——压低身子。",
	"【鼓楼】苇原·灯影：拍一乱，就是劫鼓开手。",
	"【鼓楼】管事：禁乱砸。一锤破面，满楼尽哑。",
	"【鼓楼】斥候：鼓廊横贯——择口绕进，别硬撞。",
	"【鼓楼】老旗手：夜鼓棋格，中格是活路。",
	"【鼓楼】春令使者：丘环交错，落脚先想第二步。",
	"【鼓楼】斥候：擂台软面——外丘清完还要进心垒。",
	"【鼓楼】斥候：鼓市棚廊——三列要择口。",
	"【鼓楼】管事：鼓架竖廊，别砸架纽。",
	"【鼓楼】老旗手：独擂水镜，桥心是活路。",
	"【鼓楼】春令使者：夜擂林环，心台要护拍。",
]
const DRUM_BANTER_KILL := [
	"【鼓楼】鼓楼悍匪：……面……不该破……",
	"【鼓楼】鼓廊伏弓：楼口……不在你们手里……",
	"【鼓楼】老旗手：一匪倒，拍路清一寸。",
	"【鼓楼】管事：别追太深——鼓还在架上。",
	"【鼓楼】鼓楼匪首：空鼓……擂不清真姓……",
	"【鼓楼】斥候：砸面的倒了，鼓可护。",
]
const DRUM_BANTER_START := [
	"【鼓楼】春令使者：这一仗验的是姓，不是鼓。",
	"【鼓楼】系统：鼓楼已升。护拍优先于斩杀。",
	"【鼓楼】管事：拍未成，先别浪战。",
	"【鼓楼】老旗手：廊下不利横队——择口纵列。",
]
const INCENSE_BANTER_TURN := [
	"【香市】管事：护烟！别让他们翻炉。",
	"【香市】老旗手：香堂还在，旗就不能倒。",
	"【香市】斥候：香市有贼气味——压低身子。",
	"【香市】苇原·灯影：烟一乱，就是劫香开手。",
	"【香市】管事：禁乱翻。一炉倾灰，满市尽散。",
	"【香市】斥候：香堂中隔——择桥绕进，别硬蹚。",
	"【香市】老旗手：灰台炉格，中台是活路。",
	"【香市】春令使者：丘格交错，落脚先想第二步。",
	"【香市】斥候：烟径软灰——外丘清完还要进心垒。",
	"【香市】斥候：香摊棚廊——三列要择口。",
	"【香市】管事：香架竖廊，别砸架纽。",
	"【香市】老旗手：独香水镜，桥心是活路。",
	"【香市】春令使者：夜香林环，心台要护烟。",
]
const INCENSE_BANTER_KILL := [
	"【香市】香市悍匪：……炉……不该翻……",
	"【香市】香堂伏弓：市口……不在你们手里……",
	"【香市】老旗手：一匪倒，烟路清一寸。",
	"【香市】管事：别追太深——香还在架上。",
	"【香市】香市匪首：空烟……闻不清真姓……",
	"【香市】斥候：翻炉的倒了，香可护。",
]
const INCENSE_BANTER_START := [
	"【香市】春令使者：这一仗验的是姓，不是香。",
	"【香市】系统：香市已升。护烟优先于斩杀。",
	"【香市】管事：烟未成，先别浪战。",
	"【香市】老旗手：炉下不利横队——择桥纵列。",
]
const TIDE_BANTER_TURN := [
	"【潮汐】管事：护迹！别让他们踏碎潮壳。",
	"【潮汐】老旗手：潮渠还在，旗就不能倒。",
	"【潮汐】斥候：潮滩有贼气味——压低身子。",
	"【潮汐】苇原·灯影：潮一乱，就是劫道开手。",
	"【潮汐】管事：禁乱踏。一脚碎壳，满滩尽退。",
	"【潮汐】斥候：潮渠双渠——择桥绕进，别硬蹚。",
	"【潮汐】老旗手：夜潮双岸，中岸是活路。",
	"【潮汐】春令使者：水格交错，落脚先想第二步。",
	"【潮汐】斥候：礁脉软壳——外格清完还要进心垒。",
	"【潮汐】斥候：潮市棚廊——三列要择口。",
	"【潮汐】管事：潮架竖廊，别砸架纽。",
	"【潮汐】老旗手：独潮水镜，桥心是活路。",
	"【潮汐】春令使者：夜退林环，心台要护迹。",
]
const TIDE_BANTER_KILL := [
	"【潮汐】潮滩悍匪：……壳……不该碎……",
	"【潮汐】潮渠伏弓：滩口……不在你们手里……",
	"【潮汐】老旗手：一匪倒，潮路清一寸。",
	"【潮汐】管事：别追太深——迹还在滩上。",
	"【潮汐】潮滩匪首：空潮……退不清真姓……",
	"【潮汐】斥候：碎壳的倒了，迹可护。",
]
const TIDE_BANTER_START := [
	"【潮汐】春令使者：这一仗验的是姓，不是潮。",
	"【潮汐】系统：潮汐已升。护迹优先于斩杀。",
	"【潮汐】管事：迹未成，先别浪战。",
	"【潮汐】老旗手：潮下不利横队——择桥纵列。",
]
const PORCELAIN_BANTER_TURN := [
	"【瓷市】管事：护釉！别让他们砸架。",
	"【瓷市】老旗手：窑廊还在，旗就不能倒。",
	"【瓷市】斥候：瓷市有贼气味——压低身子。",
	"【瓷市】苇原·灯影：釉一裂，就是劫瓷开手。",
	"【瓷市】管事：禁乱砸。一锤碎坯，满市尽裂。",
	"【瓷市】斥候：窑廊中隔——择桥绕进，别硬撞。",
	"【瓷市】老旗手：瓷架棋格，中架是活路。",
	"【瓷市】春令使者：釉池交错，落脚先想第二步。",
	"【瓷市】斥候：釉池软坯——外格清完还要进心垒。",
]
const PORCELAIN_BANTER_KILL := [
	"【瓷市】瓷市悍匪：……坯……不该碎……",
	"【瓷市】窑廊伏弓：市口……不在你们手里……",
	"【瓷市】老旗手：一匪倒，釉路清一寸。",
	"【瓷市】管事：别追太深——瓷还在架上。",
	"【瓷市】瓷市匪首：空釉……烧不清真姓……",
	"【瓷市】斥候：砸架的倒了，瓷可护。",
]
const PORCELAIN_BANTER_START := [
	"【瓷市】春令使者：这一仗验的是姓，不是瓷。",
	"【瓷市】系统：瓷市已升。护釉优先于斩杀。",
	"【瓷市】管事：釉未成，先别浪战。",
	"【瓷市】老旗手：窑下不利横队——择桥纵列。",
]
const ESCORT_BANTER_START := [
	"【镖行】春令使者：这一仗验的是姓，不是刀。",
	"【镖行】系统：镖旗已升。护货优先于斩杀。",
]

func _map_theme() -> String:
	return str(BattleMaps.get_map(map_id).get("theme", ""))

func _is_escort_map() -> bool:
	return _map_theme() == "escort"

func _is_harbor_map() -> bool:
	return _map_theme() == "harbor"

func _theme_banter(kind: String) -> void:
	var theme = _map_theme()
	if theme != "escort" and theme != "harbor" and theme != "paper" and theme != "copper" and theme != "lantern" and theme != "grain" and theme != "snow" and theme != "bamboo" and theme != "relay" and theme != "bell" and theme != "rain" and theme != "ink" and theme != "hive" and theme != "flute" and theme != "shadow" and theme != "salt" and theme != "dye" and theme != "drum" and theme != "incense" and theme != "tide" and theme != "porcelain":
		return
	var key = theme + kind + str(_banter_idx if kind == "turn" else _banter_kill)
	if _banter_played.has(key):
		return
	var pool: Array = []
	if theme == "escort":
		pool = ESCORT_BANTER_TURN if kind == "turn" else (ESCORT_BANTER_KILL if kind == "kill" else ESCORT_BANTER_START)
	elif theme == "harbor":
		pool = HARBOR_BANTER_TURN if kind == "turn" else (HARBOR_BANTER_KILL if kind == "kill" else HARBOR_BANTER_START)
	elif theme == "paper":
		pool = PAPER_BANTER_TURN if kind == "turn" else (PAPER_BANTER_KILL if kind == "kill" else PAPER_BANTER_START)
	elif theme == "copper":
		pool = COPPER_BANTER_TURN if kind == "turn" else (COPPER_BANTER_KILL if kind == "kill" else COPPER_BANTER_START)
	elif theme == "lantern":
		pool = LANTERN_BANTER_TURN if kind == "turn" else (LANTERN_BANTER_KILL if kind == "kill" else LANTERN_BANTER_START)
	elif theme == "grain":
		pool = GRAIN_BANTER_TURN if kind == "turn" else (GRAIN_BANTER_KILL if kind == "kill" else GRAIN_BANTER_START)
	elif theme == "snow":
		pool = SNOW_BANTER_TURN if kind == "turn" else (SNOW_BANTER_KILL if kind == "kill" else SNOW_BANTER_START)
	elif theme == "bamboo":
		pool = BAMBOO_BANTER_TURN if kind == "turn" else (BAMBOO_BANTER_KILL if kind == "kill" else BAMBOO_BANTER_START)
	elif theme == "relay":
		pool = RELAY_BANTER_TURN if kind == "turn" else (RELAY_BANTER_KILL if kind == "kill" else RELAY_BANTER_START)
	elif theme == "bell":
		pool = BELL_BANTER_TURN if kind == "turn" else (BELL_BANTER_KILL if kind == "kill" else BELL_BANTER_START)
	elif theme == "rain":
		pool = RAIN_BANTER_TURN if kind == "turn" else (RAIN_BANTER_KILL if kind == "kill" else RAIN_BANTER_START)
	elif theme == "ink":
		pool = INK_BANTER_TURN if kind == "turn" else (INK_BANTER_KILL if kind == "kill" else INK_BANTER_START)
	elif theme == "hive":
		pool = HIVE_BANTER_TURN if kind == "turn" else (HIVE_BANTER_KILL if kind == "kill" else HIVE_BANTER_START)
	elif theme == "flute":
		pool = FLUTE_BANTER_TURN if kind == "turn" else (FLUTE_BANTER_KILL if kind == "kill" else FLUTE_BANTER_START)
	elif theme == "shadow":
		pool = SHADOW_BANTER_TURN if kind == "turn" else (SHADOW_BANTER_KILL if kind == "kill" else SHADOW_BANTER_START)
	elif theme == "salt":
		pool = SALT_BANTER_TURN if kind == "turn" else (SALT_BANTER_KILL if kind == "kill" else SALT_BANTER_START)
	elif theme == "dye":
		pool = DYE_BANTER_TURN if kind == "turn" else (DYE_BANTER_KILL if kind == "kill" else DYE_BANTER_START)
	elif theme == "drum":
		pool = DRUM_BANTER_TURN if kind == "turn" else (DRUM_BANTER_KILL if kind == "kill" else DRUM_BANTER_START)
	elif theme == "incense":
		pool = INCENSE_BANTER_TURN if kind == "turn" else (INCENSE_BANTER_KILL if kind == "kill" else INCENSE_BANTER_START)
	elif theme == "tide":
		pool = TIDE_BANTER_TURN if kind == "turn" else (TIDE_BANTER_KILL if kind == "kill" else TIDE_BANTER_START)
	elif theme == "porcelain":
		pool = PORCELAIN_BANTER_TURN if kind == "turn" else (PORCELAIN_BANTER_KILL if kind == "kill" else PORCELAIN_BANTER_START)
	else:
		pool = []
	if pool.is_empty():
		return
	var line = ""
	if kind == "turn":
		line = str(pool[_banter_idx % pool.size()])
		_banter_idx += 1
	elif kind == "kill":
		line = str(pool[_banter_kill % pool.size()])
		_banter_kill += 1
		if theme == "escort":
			Sfx.escort_whip()
		elif theme == "harbor":
			Sfx.wave_splash()
		elif theme == "paper":
			Sfx.paper_tear()
		elif theme == "copper":
			Sfx.anvil_clang()
		elif theme == "lantern":
			Sfx.lamp_flicker()
		elif theme == "grain":
			Sfx.grain_pour()
		elif theme == "snow":
			Sfx.frost_crackle()
		elif theme == "bamboo":
			Sfx.bamboo_creak()
		elif theme == "relay":
			Sfx.post_horn()
		elif theme == "bell":
			Sfx.bell_toll()
		elif theme == "rain":
			Sfx.rain_patter()
		elif theme == "ink":
			Sfx.ink_drip()
		elif theme == "hive":
			Sfx.bee_buzz()
		elif theme == "flute":
			Sfx.flute_tone()
		elif theme == "shadow":
			Sfx.shadow_whoosh()
		elif theme == "salt":
			Sfx.salt_crunch()
		elif theme == "dye":
			Sfx.dye_splash()
		elif theme == "drum":
			Sfx.drum_thump()
		elif theme == "incense":
			Sfx.incense_hiss()
		elif theme == "tide":
			Sfx.tide_wash()
		elif theme == "porcelain":
			Sfx.porcelain_chime()
	else:
		line = str(pool[0] if _banter_idx == 0 else pool[mini(1, pool.size()-1)])
		if theme == "escort":
			Sfx.escort_horn()
		elif theme == "harbor":
			Sfx.wave_splash()
		elif theme == "paper":
			Sfx.paper_tear()
		elif theme == "copper":
			Sfx.anvil_clang()
		elif theme == "lantern":
			Sfx.lamp_flicker()
		elif theme == "grain":
			Sfx.grain_pour()
		elif theme == "snow":
			Sfx.frost_crackle()
		elif theme == "bamboo":
			Sfx.bamboo_creak()
		elif theme == "relay":
			Sfx.post_horn()
		elif theme == "bell":
			Sfx.bell_toll()
		elif theme == "rain":
			Sfx.rain_patter()
		elif theme == "ink":
			Sfx.ink_drip()
		elif theme == "hive":
			Sfx.bee_buzz()
		elif theme == "flute":
			Sfx.flute_tone()
		elif theme == "shadow":
			Sfx.shadow_whoosh()
		elif theme == "salt":
			Sfx.salt_crunch()
		elif theme == "dye":
			Sfx.dye_splash()
		elif theme == "drum":
			Sfx.drum_thump()
		elif theme == "incense":
			Sfx.incense_hiss()
		elif theme == "tide":
			Sfx.tide_wash()
		elif theme == "porcelain":
			Sfx.porcelain_chime()
	_banter_played[key] = true
	_log(line)

func _escort_banter(kind: String) -> void:
	_theme_banter(kind)

func _ready() -> void:
	rng.randomize()
	Music.play_battle()
	# v8 biome battle plate (fallback legacy backdrop)
	var _AtlasArt = preload("res://scripts/art/atlas_art.gd")
	var _bb_path: String = str(_AtlasArt.battle_backdrop_for_map(str(GameState.get_meta("battle_map", map_id))))
	if _bb_path != "":
		var bbg := TextureRect.new()
		bbg.texture = load(_bb_path)
		bbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bbg.stretch_mode = TextureRect.STRETCH_SCALE
		bbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bbg.z_index = -8
		bbg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bbg.modulate = Color(0.55, 0.62, 0.72, 0.30)
		add_child(bbg)
		move_child(bbg, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_init_map()
	_deploy()
	_start_player_turn()
	queue_redraw()
	set_process(true)

func _process(delta: float) -> void:
	UnitArt.tick(delta)
	_sel_pulse += delta
	if _turn_flash > 0.0:
		_turn_flash = maxf(0.0, _turn_flash - delta)
	var alive_fx: Array = []
	for fx in _dmg_fx:
		fx.age += delta
		if fx.age < 1.1:
			alive_fx.append(fx)
	_dmg_fx = alive_fx
	var alive_s: Array = []
	for s in _slash_fx:
		s.age += delta
		if s.age < 0.48:
			alive_s.append(s)
	_slash_fx = alive_s
	var alive_lb: Array = []
	for lb in _lock_burst_fx:
		lb.age += delta
		if lb.age < 0.55:
			alive_lb.append(lb)
	_lock_burst_fx = alive_lb
	var alive_md: Array = []
	for md in _move_dust_fx:
		md.age += delta
		if md.age < 0.4:
			alive_md.append(md)
	_move_dust_fx = alive_md
	# Trauma shake（二次曲线，非每帧乱抖）
	if _shake > 0.0:
		_trauma = clampf(_trauma + _shake * 0.08, 0.0, 1.0)
		_shake = 0.0
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * 1.35)
		var shake = _trauma * _trauma
		_shake_t += delta * 30.0
		position = Vector2(10.0 * shake * sin(_shake_t * 1.7), 7.0 * shake * sin(_shake_t * 2.3))
	else:
		position = Vector2.ZERO
	if overlay:
		overlay.queue_redraw()
	if map_draw and _sel_pulse:
		map_draw.queue_redraw()

## v8.5: texture cache. A texture load()ed for the first time inside _draw records as a
## white placeholder on the GL renderer (seen in real renders) — warm FX here, cache everything.
var _tex_cache: Dictionary = {}

func _tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = t
	return t

func _warm_fx_cache() -> void:
	var kinds := ["hit", "slash", "heal", "crit", "lock", "shield", "spark", "dmg_pop", "turn_flash", "zoc_pulse", "select"]
	for k in kinds:
		for i in range(8):
			_tex("res://assets/art/fx/%s_dense_%d.png" % [k, i])
			_tex("res://assets/art/fx/%s_%d.png" % [k, i])
	for i in range(6):
		_tex("res://assets/art/fx/hit_spark_%d.png" % i)
		_tex("res://assets/art/fx/move_dust_%d.png" % i)
	for w in ["select_wash", "move_wash", "attack_wash"]:
		_tex("res://assets/art/fx/%s.png" % w)
	for u in ["zoc_hatch_safe", "zoc_hatch_zoc", "zoc_hatch_leave", "zoc_hatch_lock", "zoc_chip_lock3", "zoc_chip_leave2", "zoc_leave_legend"]:
		_tex("res://assets/art/ui/%s.png" % u)

func _k() -> float:
	return float(CELL) / 56.0

func _build_ui() -> void:
	## v8.6 layout (Stitch 06 战棋战斗 HUD): board stage left (hero), thin turn bar on top,
	## right rail = selected-unit card · intel · compact log · command console. Nothing floats on the board.
	_warm_fx_cache()
	_bg = ColorRect.new()
	_bg.color = Color(UIKit.BG, 0.72)
	_bg.set_anchors_preset(PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	add_child(UIKit._vignette())

	# turn bar: phase (headline) · map · controls hint — on clean ink, always readable
	var top := HBoxContainer.new()
	top.position = Vector2(24, 18)
	top.add_theme_constant_override("separation", 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.color = UIKit.ACCENT
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(dot)
	UIFX.breathe(dot, 0.2, 1.6)
	phase_label = Label.new()
	phase_label.text = "玩家回合"
	phase_label.add_theme_font_size_override("font_size", 22)
	phase_label.add_theme_color_override("font_color", UIKit.TEXT)
	phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(phase_label)
	var tip = UIKit.make_dim_label("左键 选中 / 移动　·　攻击模式后点敌军　·　右键 取消")
	tip.add_theme_color_override("font_color", UIKit.TEXT_FAINT)
	tip.add_theme_font_size_override("font_size", 12)
	tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.name = "ControlsTip"
	top.add_child(tip)

	_ground = ColorRect.new()
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground)

	map_draw = Node2D.new()
	map_draw.draw.connect(_draw_map)
	add_child(map_draw)

	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)

	# --- right rail
	_unit_panel = UIKit.make_panel()
	_unit_panel.position = Vector2(RAIL_X, 76)
	_unit_panel.custom_minimum_size = Vector2(RAIL_W, 0)
	_unit_panel.size = Vector2(RAIL_W, 0)
	add_child(_unit_panel)
	var left_info := VBoxContainer.new()
	left_info.add_theme_constant_override("separation", 12)
	_unit_panel.add_child(left_info)
	_unit_card = UnitCardScript.new(RAIL_W - 44.0)
	left_info.add_child(_unit_card)
	_portrait = _unit_card.portrait
	_info_traits = HBoxContainer.new()
	_info_traits.add_theme_constant_override("separation", 4)
	left_info.add_child(_info_traits)
	left_info.add_child(UIKit.hairline())
	info_label = RichTextLabel.new()
	info_label.custom_minimum_size = Vector2(RAIL_W - 44.0, 0)
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.scroll_active = false
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.add_theme_color_override("default_color", UIKit.TEXT_DIM)
	info_label.add_theme_font_size_override("normal_font_size", 12)
	info_label.add_theme_font_size_override("bold_font_size", 13)
	left_info.add_child(info_label)

	var log_panel = UIKit.make_glass(12, 0.55)
	log_panel.name = "LogPanel"
	log_panel.position = Vector2(RAIL_X, 470)
	log_panel.custom_minimum_size = Vector2(RAIL_W, 96)
	log_panel.size = Vector2(RAIL_W, 96)
	log_panel.clip_contents = true
	add_child(log_panel)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	log_panel.add_child(lv)
	lv.add_child(UIKit.eyebrow("战报", UIKit.TEXT_FAINT))
	log_label = Label.new()
	log_label.custom_minimum_size = Vector2(RAIL_W - 44, 44)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.clip_text = true
	log_label.max_lines_visible = 3
	log_label.add_theme_font_size_override("font_size", 12)
	log_label.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	lv.add_child(log_label)

	# command console
	_skill_hint = UIKit.make_dim_label("")
	_skill_hint.position = Vector2(RAIL_X + 2, 578)
	_skill_hint.custom_minimum_size = Vector2(RAIL_W, 18)
	_skill_hint.size = Vector2(RAIL_W, 18)
	_skill_hint.clip_text = true
	_skill_hint.add_theme_font_size_override("font_size", 12)
	add_child(_skill_hint)
	var row := HBoxContainer.new()
	row.position = Vector2(RAIL_X, 602)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_btn_atk = UIKit.make_button("攻击", 112)
	_btn_atk.pressed.connect(_enter_attack_mode)
	row.add_child(_btn_atk)
	_btn_skill = UIKit.make_button("战技", 112)
	_btn_skill.pressed.connect(_cycle_skill)
	row.add_child(_btn_skill)
	_btn_wait = UIKit.make_button(Locale.t("wait"), 112)
	_btn_wait.pressed.connect(_wait_selected)
	row.add_child(_btn_wait)
	var row2 := HBoxContainer.new()
	row2.position = Vector2(RAIL_X, 652)
	row2.add_theme_constant_override("separation", 8)
	add_child(row2)
	_btn_end = UIKit.make_accent_button(Locale.t("end_turn"), 232)
	_btn_end.custom_minimum_size = Vector2(232, 44)
	_btn_end.pressed.connect(_end_player_turn)
	row2.add_child(_btn_end)
	var b_prev = CheckButton.new()
	b_prev.text = Locale.t("rules_preview")
	b_prev.add_theme_font_size_override("font_size", 12)
	b_prev.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	b_prev.button_pressed = BattleRules.preview_enabled
	b_prev.toggled.connect(func(on): BattleRules.preview_enabled = on)
	row2.add_child(b_prev)

func _layout_board() -> void:
	CELL = int(clampf(floorf(minf(BOARD_AREA.size.x / float(MAP_W), BOARD_AREA.size.y / float(MAP_H))), 44.0, 104.0))
	var bs := Vector2(MAP_W, MAP_H) * CELL
	ORIGIN = (BOARD_AREA.position + (BOARD_AREA.size - bs) * 0.5).floor()
	_build_ground()

func _biome_ground() -> Array:
	## [base texture id, grade]
	var _AtlasArt = preload("res://scripts/art/atlas_art.gd")
	var bio := str(_AtlasArt.biome_for_map(map_id))
	match bio:
		"snow":
			return ["snow", Vector3(0.92, 0.97, 1.04)]
		"archive", "forge", "fort", "urban", "shrine":
			return ["stone", Vector3(0.96, 0.98, 1.03)]
		"harbor":
			return ["stone", Vector3(0.90, 0.98, 1.05)]
		"pass", "hill":
			return ["dust", Vector3(0.97, 0.98, 1.02)]
		"nightcamp":
			return ["dust", Vector3(0.74, 0.80, 0.96)]
		"fog":
			return ["grass", Vector3(0.88, 0.94, 1.02)]
		"marsh":
			return ["grass", Vector3(0.90, 1.0, 0.96)]
	return ["grass", Vector3(0.96, 1.0, 1.02)]

func _build_ground() -> void:
	if _ground == null:
		return
	var sh = load("res://shaders/board_ground.gdshader")
	if sh == null:
		return
	var img := Image.create(MAP_W, MAP_H, false, Image.FORMAT_R8)
	for y in MAP_H:
		for x in MAP_W:
			var tid := str(terrain[y][x]) if y < terrain.size() and x < terrain[y].size() else "plain"
			img.set_pixel(x, y, Color(float(int(TERRAIN_IDS.get(tid, 0)) * 32) / 255.0, 0, 0))
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var bg: Array = _biome_ground()
	var tdir := "res://assets/art/terrain_v86/"
	mat.set_shader_parameter("t_base", load(tdir + str(bg[0]) + ".png"))
	mat.set_shader_parameter("t_forest", load(tdir + "forest.png"))
	mat.set_shader_parameter("t_hill", load(tdir + "hill.png"))
	mat.set_shader_parameter("t_water", load(tdir + "water.png"))
	mat.set_shader_parameter("t_fort", load(tdir + "fort.png"))
	mat.set_shader_parameter("t_bridge", load(tdir + "bridge.png"))
	mat.set_shader_parameter("t_noise", load(tdir + "noise.png"))
	mat.set_shader_parameter("idmap", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("grid", Vector2(MAP_W, MAP_H))
	mat.set_shader_parameter("cell_px", float(CELL))
	mat.set_shader_parameter("grade", bg[1])
	_ground.material = mat
	_ground.position = ORIGIN
	_ground.size = Vector2(MAP_W, MAP_H) * CELL
	# soft drop shadow + 1px stroke around the board stage
	var sh_node := get_node_or_null("BoardFrame")
	if sh_node:
		sh_node.queue_free()
	var frame := Panel.new()
	frame.name = "BoardFrame"
	var fs := StyleBoxFlat.new()
	fs.draw_center = false
	fs.border_color = UIKit.STROKE
	fs.set_border_width_all(1)
	fs.set_corner_radius_all(4)
	fs.shadow_color = Color(0, 0, 0, 0.55)
	fs.shadow_size = 28
	fs.shadow_offset = Vector2(0, 12)
	fs.expand_margin_left = 1
	fs.expand_margin_right = 1
	fs.expand_margin_top = 1
	fs.expand_margin_bottom = 1
	frame.add_theme_stylebox_override("panel", fs)
	frame.position = ORIGIN
	frame.size = _ground.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	move_child(frame, _ground.get_index())

func _player_skills(ui: int) -> Array:
	if ui < 0 or ui >= units.size():
		return []
	var c: CKCharacter = units[ui].char
	var out: Array = []
	for sid in c.skills:
		var left = int(c.skill_uses.get(sid, 0))
		var cd = int(c.skill_cd.get(sid, 0))
		if left > 0 and cd <= 0:
			out.append(sid)
	return out

func _cycle_skill() -> void:
	if selected < 0 or selected >= units.size():
		_log("请先选中己方单位再选战技")
		return
	var su = units[selected]
	if su.team != "player" or su.done:
		_log("当前单位无法使用战技")
		return
	var avail = _player_skills(selected)
	if avail.is_empty():
		_log("本场战技已用尽或未学会——去演武场转职可解锁")
		skill_mode = false
		active_skill_id = ""
		_update_skill_hint()
		return
	# cycle
	if active_skill_id == "" or active_skill_id not in avail:
		active_skill_id = avail[0]
	else:
		var idx = avail.find(active_skill_id)
		idx = (idx + 1) % avail.size()
		active_skill_id = avail[idx]
	var sk = GameState.get_skill(active_skill_id)
	var typ = str(sk.get("type", "offense"))
	if typ == "support":
		# instant heal adjacent
		_cast_support_skill(selected, active_skill_id)
		return
	if typ == "buff":
		_cast_buff_skill(selected, active_skill_id)
		return
	# offense: arm for next attack
	skill_mode = true
	attack_mode = true
	if sk.get("ignore_zoc"):
		su.char.temp_ignore_zoc = true
		if not moved_this_select:
			move_cells = _compute_move_cells(selected)
			attack_mode = false
			_log("破控冲锋就绪：可无视控制地带移动后再攻击 — %s" % sk.get("desc", ""))
		else:
			move_cells.clear()
			_log("战技已就绪：%s — %s" % [sk.get("name", ""), sk.get("desc", "")])
	else:
		move_cells.clear()
		_log("战技已就绪：%s — %s" % [sk.get("name", ""), sk.get("desc", "")])
	_update_skill_hint()
	overlay.queue_redraw()
	_refresh_info()

func _update_skill_hint() -> void:
	if _skill_hint == null:
		return
	if selected >= 0 and selected < units.size() and units[selected].team == "player":
		var parts: Array = []
		for sid in units[selected].char.skills:
			var sk = GameState.get_skill(sid)
			var left = int(units[selected].char.skill_uses.get(sid, 0))
			var cd = int(units[selected].char.skill_cd.get(sid, 0))
			if cd > 0:
				parts.append("%sCD%d" % [sk.get("name", sid), cd])
			else:
				parts.append("%s×%d" % [sk.get("name", sid), left])
		var armed = ""
		if active_skill_id != "":
			armed = "　【将释放：%s】" % GameState.get_skill(active_skill_id).get("name", active_skill_id)
		_skill_hint.text = ("战技：" + " · ".join(parts) if parts else "战技：无") + armed
	else:
		_skill_hint.text = "选中单位后点「战技」循环选择；进攻技在攻击时消耗。"

func _consume_skill(c: CKCharacter, sid: String) -> void:
	var left = int(c.skill_uses.get(sid, 0))
	c.skill_uses[sid] = maxi(0, left - 1)
	var sk = GameState.get_skill(sid)
	c.skill_cd[sid] = int(sk.get("cooldown", 1))
	skill_mode = false
	active_skill_id = ""
	_update_skill_hint()

func _cast_support_skill(ui: int, sid: String) -> void:
	Sfx.skill()
	if Sfx.has_method("heal"):
		Sfx.heal()
	var sk = GameState.get_skill(sid)
	var u = units[ui]
	var healed = 0
	for j in units.size():
		var o = units[j]
		if o.team != "player" or o.char.hp <= 0:
			continue
		if _manhattan(u.pos, o.pos) <= 1:
			var amt = rng.randi_range(int(sk.get("heal_min", 8)), int(sk.get("heal_max", 12)))
			o.char.hp = mini(o.char.max_hp, o.char.hp + amt)
			healed += 1
			_spawn_dmg(o.pos, "+%d" % amt, Color(0.4, 0.9, 0.5))
			_spawn_slash(o.pos, "heal")
	if sk.get("party_def_buff"):
		var add = int(sk.get("party_def_buff"))
		for ou in units:
			if ou.team == "player" and ou.char.hp > 0:
				ou.char.temp_def_buff = maxi(ou.char.temp_def_buff, add)
		_spawn_dmg(u.pos, "圣域", Color(0.7, 0.85, 1.0))
	_consume_skill(u.char, sid)
	u.done = true
	selected = -1
	Sfx.confirm()
	_log("%s 释放「%s」，治疗 %d 人" % [u.char.name, sk.get("name", ""), healed])
	map_draw.queue_redraw()
	_refresh_info()
	_check_end()

func _cast_buff_skill(ui: int, sid: String) -> void:
	var sk = GameState.get_skill(sid)
	var u = units[ui]
	if sk.get("def_buff"):
		u.char.temp_def_buff = int(sk.get("def_buff"))
	if sk.get("next_hit_bonus"):
		u.char.temp_hit_bonus = int(sk.get("next_hit_bonus"))
	if sk.get("next_crit_bonus"):
		u.char.temp_crit_bonus = int(sk.get("next_crit_bonus"))
	if sk.get("zoc_aura"):
		u.char.temp_zoc_aura = int(sk.get("zoc_aura"))
	if sk.get("ignore_zoc"):
		u.char.temp_ignore_zoc = true
	if sk.get("leave_free"):
		u.char.temp_leave_free = true
	if sk.get("clear_combat_lock"):
		u.char.temp_combat_lock = 0
		_spawn_dmg(u.pos, "拆锁", Color(0.5, 0.85, 1.0))
		_spawn_slash(u.pos, "spark")
	if sk.get("terrain_ward"):
		u.char.temp_terrain_ward = true
		_spawn_dmg(u.pos, "地利", Color(0.55, 0.9, 0.55))
		_spawn_slash(u.pos, "shield")
	if sk.get("leave_free") or sk.get("clear_combat_lock") or sk.get("ignore_zoc"):
		# 立刻刷新移动：可支付脱离 / 拆锁后重算
		if ui == selected:
			move_cells = _compute_move_cells(ui)
			attack_mode = false
	if sk.get("party_def_buff"):
		var add = int(sk.get("party_def_buff"))
		for ou in units:
			if ou.team == "player" and ou.char.hp > 0:
				ou.char.temp_def_buff = maxi(ou.char.temp_def_buff, add)
	if sk.get("self_def_penalty"):
		u.char.temp_def_buff = maxi(-99, u.char.temp_def_buff - int(sk.get("self_def_penalty")))
	_consume_skill(u.char, sid)
	var note = ""
	if sk.get("zoc_aura"):
		note = "（控带强化）"
	_log("%s 释放「%s」%s" % [u.char.name, sk.get("name", ""), note])
	Sfx.confirm()
	Sfx.skill()
	_refresh_info()
	map_draw.queue_redraw()
	overlay.queue_redraw()

func _enter_attack_mode() -> void:
	if selected < 0 or selected >= units.size():
		_log("请先选中己方单位再进入攻击模式")
		return
	var su = units[selected]
	if su.team != "player" or su.done:
		_log("当前选中单位无法攻击")
		return
	attack_mode = true
	move_cells.clear()
	overlay.queue_redraw()
	_refresh_info()
	_log("攻击模式：点击射程内敌人")

func _init_map() -> void:
	map_id = str(GameState.get_meta("battle_map", "ch0_pass"))
	var m: Dictionary = BattleMaps.get_map(map_id)
	map_name = str(m.get("name", map_id))
	MAP_W = int(m.get("w", 8))
	MAP_H = int(m.get("h", 6))
	terrain.clear()
	var grid: Array = m.get("terrain", [])
	if grid.is_empty():
		for y in MAP_H:
			var row: Array = []
			for x in MAP_W:
				row.append("plain")
			terrain.append(row)
	else:
		for y in grid.size():
			terrain.append(grid[y].duplicate())
	_layout_board()
	if phase_label:
		phase_label.text = "%s · 玩家回合" % map_name

func _deploy() -> void:
	units.clear()
	var m: Dictionary = BattleMaps.get_map(map_id)
	var ids: Array = GameState.deploy_ids.duplicate()
	if ids.is_empty():
		for c in GameState.roster():
			ids.append(c.id)
			if ids.size() >= 4:
				break
	# 双嗣校场：真人子嗣分列双方
	var heir_a_id = str(GameState.get_meta("heir_clash_a", ""))
	var heir_b_id = str(GameState.get_meta("heir_clash_b", ""))
	var is_heir_clash = bool(m.get("heir_clash", false)) or map_id == "ch_heir_clash"
	if is_heir_clash and heir_a_id != "":
		ids = [heir_a_id]
		# 团长 + 花名册支援（最多凑满 player_spots）
		var leader = GameState.get_leader()
		if leader and leader.id != heir_a_id and leader.id != heir_b_id:
			ids.append(leader.id)
		for c in GameState.roster():
			if c.id == heir_a_id or c.id == heir_b_id:
				continue
			if leader and c.id == leader.id:
				continue
			if c.id not in ids:
				ids.append(c.id)
			if ids.size() >= 4:
				break
	var spots: Array = []
	for s in m.get("player_spots", [[1,4],[2,5],[0,5],[3,4]]):
		spots.append(Vector2i(int(s[0]), int(s[1])))
	var i = 0
	for cid in ids:
		if i >= spots.size():
			break
		var c: CKCharacter = GameState.characters.get(cid)
		if c == null or not c.alive:
			continue
		# 校场临时满血
		if is_heir_clash:
			c.hp = c.max_hp
		units.append({"char": c, "pos": spots[i], "team": "player", "done": false})
		i += 1
	# 双嗣校场：并席/中立敌宅可派援手填我方空位
	if is_heir_clash and i < spots.size():
		var ally_houses: Array = []
		for hid2 in ["qinghe", "lantern", "shuoying"]:
			var st2 = GameState.get_rival_stance(hid2)
			if st2 in ["cordial", "neutral"]:
				ally_houses.append(hid2)
		var ai = 0
		while i < spots.size() and ai < ally_houses.size():
			var ally = CharacterFactory.make_house_support(str(ally_houses[ai]), true, rng)
			units.append({"char": ally, "pos": spots[i], "team": "player", "done": false})
			i += 1
			ai += 1
	# tutorial militia pad to 4 for ch0_pass only
	if bool(m.get("tutorial_militia", false)):
		var militia_slot := 0
		while i < mini(4, spots.size()):
			units.append({
				"char": CharacterFactory.make_tutorial_militia(militia_slot),
				"pos": spots[i],
				"team": "player",
				"done": false,
			})
			militia_slot += 1
			i += 1
	var enemy_spots: Array = []
	for s in m.get("enemy_spots", [[6,1],[5,2]]):
		enemy_spots.append(Vector2i(int(s[0]), int(s[1])))
	var templates: Array = m.get("enemy_templates", ["bandit_weak","bandit_weak"])
	var ei = 0
	if is_heir_clash and heir_b_id != "":
		var hb: CKCharacter = GameState.characters.get(heir_b_id)
		if hb and hb.alive and ei < enemy_spots.size():
			hb.hp = hb.max_hp
			units.append({"char": hb, "pos": enemy_spots[ei], "team": "enemy", "done": false})
			ei += 1
		# 敌方支援：敌意/戒备敌宅膀臂优先，否则匪军
		var hostile_houses: Array = []
		for hid in ["shuoying", "qinghe", "lantern"]:
			var st = GameState.get_rival_stance(hid)
			if st in ["hostile", "wary"]:
				hostile_houses.append(hid)
		var si = 0
		var support_tmpls = ["bandit", "bandit_archer", "bandit_weak"]
		while ei < enemy_spots.size():
			var e2: CKCharacter
			if si < hostile_houses.size():
				e2 = CharacterFactory.make_house_support(str(hostile_houses[si]), false, rng)
			else:
				var ti = (si - hostile_houses.size()) % support_tmpls.size()
				e2 = CharacterFactory.make_enemy(str(support_tmpls[ti]), rng)
			units.append({"char": e2, "pos": enemy_spots[ei], "team": "enemy", "done": false})
			ei += 1
			si += 1
	else:
		for ti in templates.size():
			if ei >= enemy_spots.size():
				break
			var tmpl = str(templates[ti])
			var e = CharacterFactory.make_enemy(tmpl, rng)
			if e.appearance.get("hair","") == "" or e.faction == "enemy":
				e.appearance = {"hair": "ink_black", "eyes": "dusk", "brow": "thick", "scar": "cheek"}
			units.append({"char": e, "pos": enemy_spots[ei], "team": "enemy", "done": false, "template": tmpl})
			ei += 1
	_log("%s：我军 %d · 敌军 %d" % [map_name, i, ei])
	_theme_banter("start")
	if _is_escort_map():
		Sfx.cart_rattle()
	elif _is_harbor_map():
		Sfx.wave_splash()
	var chars: Array = []
	for u in units:
		if u.team == "enemy":
			var elite = u.char.is_leader or str(u.char.name).find("首") >= 0 or str(u.char.name).find("头目") >= 0 or str(u.char.name).find("匪首") >= 0 or u.char.level >= 4
			var diff = GameState.battle_difficulty_from_map(map_id)
			var tmpl = str(u.get("template", ""))
			GameState.grant_battle_enemy_skills(u.char, elite, diff, map_id, tmpl)
		else:
			GameState.grant_job_skills(u.char)
		chars.append(u.char)
	GameState.reset_battle_skills(chars)
	_show_lock_tip_once()
	if _lock_practice_pending():
		_show_lock_practice_banner()
	var _diff = GameState.battle_difficulty_from_map(map_id)
	_log("敌军战技档：%d（地图 %s）" % [_diff, map_id])
	_refresh_info()

func _draw_map() -> void:
	## v8.6: ground is the shader (_ground). Here: hover cell outline, token shadows, tokens, HP, CD pips, names.
	var k := _k()
	if _in_bounds(_hover_cell):
		var hr = Rect2(ORIGIN + Vector2(_hover_cell) * CELL, Vector2(CELL, CELL))
		map_draw.draw_rect(hr, Color(1, 1, 1, 0.07))
		map_draw.draw_rect(hr.grow(-0.5), Color(0.85, 0.95, 1.0, 0.55), false, 1.0)
	var fnt := UIKit.font("regular")
	var fb := UIKit.font("bold")
	# units
	for i in units.size():
		var u = units[i]
		if u.char.hp <= 0:
			continue
		var p: Vector2i = u.pos
		var center = ORIGIN + Vector2(p) * CELL + Vector2(CELL / 2, CELL / 2)
		var tr := 20.0 * k
		# soft contact shadow (3 stacked ellipses)
		for si in range(3):
			var sr := tr * (1.05 + 0.16 * si)
			var pts := PackedVector2Array()
			for a in range(20):
				var ang := TAU * a / 20.0
				pts.append(center + Vector2(cos(ang) * sr, sin(ang) * sr * 0.42 + tr * 0.78))
			map_draw.draw_colored_polygon(pts, Color(0, 0, 0, 0.20 - 0.05 * si))
		UnitArt.draw_token_on(map_draw, center, u.char, u.team, tr, u.done)
		if int(u.char.temp_combat_lock) > 0:
			UnitArt.draw_lock_ring(map_draw, center, 22.0 * k)
		# HP bar (slim token bar)
		var hp_ratio = float(u.char.hp) / float(maxi(1, u.char.max_hp))
		var bar_w = 36.0 * k
		var bar_pos = center + Vector2(-bar_w * 0.5, tr + 6.0 * k)
		map_draw.draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_w + 2, 6)), Color(0.02, 0.03, 0.05, 0.85))
		var hp_col = UIKit.OK if u.team == "player" else UIKit.DANGER
		map_draw.draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_ratio, 4)), hp_col)
		# CD meters: per-skill pip with initial + fill
		if u.team == "player":
			var cd_items: Array = []
			for sid in u.char.skills:
				var cdv = int(u.char.skill_cd.get(sid, 0))
				var sk = GameState.get_skill(sid)
				var nm = str(sk.get("name", sid))
				var initial = nm.substr(0, 1) if nm.length() > 0 else "?"
				var max_cd = maxf(1.0, float(sk.get("cooldown", 3)))
				cd_items.append({"cd": cdv, "max": max_cd, "ch": initial, "ready": cdv <= 0})
			if cd_items.size() > 0:
				var cd_y = bar_pos.y + 7.0
				var pip_w = 12.0
				var gap = 2.0
				var total_w = cd_items.size() * (pip_w + gap) - gap
				var sx0 = center.x - total_w * 0.5
				for ci in cd_items.size():
					var it = cd_items[ci]
					var sx = sx0 + ci * (pip_w + gap)
					var ready = bool(it["ready"])
					var fill = 1.0 if ready else clampf(1.0 - float(it["cd"]) / float(it["max"]), 0.0, 1.0)
					map_draw.draw_rect(Rect2(Vector2(sx, cd_y), Vector2(pip_w, 12)), Color(0.03, 0.04, 0.06, 0.88))
					var col = Color(UIKit.OK, 0.9) if ready else Color(UIKit.ACCENT, 0.75)
					map_draw.draw_rect(Rect2(Vector2(sx, cd_y + 12 * (1.0 - fill)), Vector2(pip_w, 12 * fill)), Color(col, 0.35))
					var tcol = UIKit.TEXT if ready else UIKit.TEXT_DIM
					map_draw.draw_string(fnt, Vector2(sx + 1, cd_y + 10), str(it["ch"]), HORIZONTAL_ALIGNMENT_CENTER, pip_w - 2, 9, tcol)
		# name pill above token — only for selected / hovered (unit card carries the rest; keeps the board clean)
		if i != selected and p != _hover_cell:
			continue
		var nm2 = str(u.char.name)
		if nm2.length() > 4:
			nm2 = nm2.substr(0, 4)
		var fsz := 12
		var tw := fb.get_string_size(nm2, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var np: Vector2 = center + Vector2(-tw * 0.5, -tr - 10.0 * k)
		map_draw.draw_rect(Rect2(np + Vector2(-6, -13), Vector2(tw + 12, 18)), Color(0.03, 0.04, 0.06, 0.62))
		map_draw.draw_rect(Rect2(np + Vector2(-6, 4), Vector2(tw + 12, 1)), Color(UIKit.OK if u.team == "player" else UIKit.DANGER, 0.8))
		map_draw.draw_string(fb, np, nm2, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, UIKit.TEXT)
		# 选中脉冲环
		if i == selected:
			var pulse = 0.5 + 0.5 * sin(_sel_pulse * 6.0)
			map_draw.draw_arc(center, tr + 4.0 + pulse * 2.0, 0, TAU, 40, Color(UIKit.ACCENT, 0.9), 1.5, true)

func _draw_overlay() -> void:
	# 敌军控制地带（ZoC）浅红提示
	if turn_team == "player":
		var zcells = BattleRules.zoc_cells(MAP_W, MAP_H, _enemy_positions("player"))
		for pos in zcells.keys():
			var rz = Rect2(ORIGIN + Vector2(pos) * CELL, Vector2(CELL - 2, CELL - 2))
			overlay.draw_rect(rz, Color(UIKit.DANGER, 0.09))
	if not attack_mode:
		var foes_ov = _enemy_positions("player")
		var locked_ov = false
		var start_eng = false
		if selected >= 0 and selected < units.size():
			var su = units[selected]
			if su.team == "player":
				locked_ov = int(su.char.temp_combat_lock) > 0
				start_eng = locked_ov or BattleRules.is_engaged(su.pos, foes_ov)
		for pos in move_cells.keys():
			var r = Rect2(ORIGIN + Vector2(pos) * CELL, Vector2(CELL - 2, CELL - 2))
			var in_z = BattleRules.in_zoc(pos, foes_ov)
			var leaving = start_eng and (not in_z) and selected >= 0 and pos != units[selected].pos
			var col: Color
			var edge: Color
			var tag := ""
			if locked_ov and leaving:
				col = Color(0.85, 0.25, 0.75, 0.48)   # 锁定脱离 cost3
				edge = Color(1.0, 0.55, 0.95, 0.95)
				tag = "锁3"
			elif leaving:
				col = Color(0.95, 0.65, 0.20, 0.48)   # 控带脱离 cost2
				edge = Color(1.0, 0.85, 0.35, 0.95)
				tag = "脱2"
			elif in_z:
				col = Color(0.95, 0.45, 0.25, 0.42)
				edge = Color(1.0, 0.65, 0.30, 0.75)
				tag = "控"
			else:
				col = Color(0.25, 0.55, 0.95, 0.38)
				edge = Color(0.4, 0.7, 1.0, 0.55)
			var hovered = (pos == _hover_cell)
			var pulse = 0.55 + 0.45 * sin(_sel_pulse * (7.0 if hovered else 4.0))
			col.a = clampf(col.a * (1.15 if hovered else 1.0) * (0.85 + 0.25 * pulse), 0.2, 0.85)
			edge.a = clampf((0.95 if hovered else edge.a) * (0.75 + 0.35 * pulse), 0.4, 1.0)
			overlay.draw_rect(r, col)
			var ew = 3.5 if hovered else 2.0
			overlay.draw_rect(r, edge, false, ew)
			# 色觉友好：高对比 hatch + 悬停脉冲透明度
			var hatch := ""
			if locked_ov and leaving:
				hatch = "res://assets/art/ui/zoc_hatch_lock3.png"
			elif leaving:
				hatch = "res://assets/art/ui/zoc_hatch_leave2.png"
			elif in_z:
				hatch = "res://assets/art/ui/zoc_hatch_zoc.png"
			else:
				hatch = "res://assets/art/ui/zoc_hatch_safe.png"
			if hatch != "" and ResourceLoader.exists(hatch):
				var ht: Texture2D = _tex(hatch)
				var ha = (0.55 + 0.45 * pulse) if hovered else (0.75 + 0.25 * pulse)
				overlay.draw_texture_rect(ht, r, false, Color(1, 1, 1, clampf(ha, 0.4, 1.0)))
				if hovered and tag != "":
					var pf = "res://assets/art/fx/zoc_pulse_%d.png" % (int(_sel_pulse * 10.0) % 6)
					if ResourceLoader.exists(pf):
						overlay.draw_texture_rect(_tex(pf), r.grow(4.0), false, Color(1, 1, 1, 0.55 + 0.35 * pulse))
			if tag != "":
				var chip_path = ""
				if tag == "锁3":
					chip_path = "res://assets/art/ui/zoc_chip_lock3.png"
				elif tag == "脱2":
					chip_path = "res://assets/art/ui/zoc_chip_leave2.png"
				elif tag == "控":
					chip_path = "res://assets/art/ui/zoc_chip_zoc.png"
				var tp = ORIGIN + Vector2(pos) * CELL + Vector2(CELL - 22, 2)
				var csz = 20.0 if hovered else 18.0
				if chip_path != "" and ResourceLoader.exists(chip_path):
					overlay.draw_texture_rect(_tex(chip_path), Rect2(tp, Vector2(csz, csz)), false)
				else:
					overlay.draw_rect(Rect2(tp, Vector2(18, 14)), Color(0.05, 0.05, 0.08, 0.75))
		# 图例：纯图标芯片（无长文字）
		if not move_cells.is_empty():
			var lx = ORIGIN.x + 10.0
			var ly = ORIGIN.y + MAP_H * CELL - 58.0
			if ResourceLoader.exists("res://assets/art/ui/zoc_leave_legend.png"):
				var ltex = _tex("res://assets/art/ui/zoc_leave_legend.png")
				overlay.draw_texture(ltex, Vector2(lx, ly))
	if selected >= 0 and selected < units.size():
		var u = units[selected]
		if u.team == "player" and not u.done:
			var max_r = 1 if _is_melee(u.char) else 2
			for y in MAP_H:
				for x in MAP_W:
					var ap = Vector2i(x, y)
					var d = _manhattan(u.pos, ap)
					if d < 1 or d > max_r:
						continue
					var ui = _unit_at(ap)
					if ui < 0:
						continue
					var ou = units[ui]
					if ou.team != "player" and ou.char.hp > 0:
						var r2 = Rect2(ORIGIN + Vector2(ap) * CELL, Vector2(CELL - 2, CELL - 2))
						var a = 0.45 if attack_mode else 0.25
						overlay.draw_rect(r2, Color(0.95, 0.2, 0.2, a))
						overlay.draw_rect(r2, Color(1.0, 0.4, 0.3, 0.8), false, 2.0)
	# v8.5 选中准星（authored select_dense 8帧循环）
	if selected >= 0 and selected < units.size() and units[selected].char.hp > 0:
		var sfi = int(_sel_pulse * 12.0) % 8
		var sp = "res://assets/art/fx/select_dense_%d.png" % sfi
		if ResourceLoader.exists(sp):
			var cpos = ORIGIN + Vector2(units[selected].pos) * CELL + Vector2(CELL, CELL) * 0.5 - Vector2(1, 1)
			var rs := float(CELL) * 1.32
			var scol = Color(1, 1, 1, 0.95) if units[selected].team == "player" else Color(1.0, 0.62, 0.62, 0.95)
			overlay.draw_texture_rect(_tex(sp), Rect2(cpos - Vector2(rs, rs) * 0.5, Vector2(rs, rs)), false, scol)
	# slash + hit_spark 分层（game-feel）
	for s in _slash_fx:
		var fi = mini(5, int(s.age / 0.08))
		var kind = str(s.get("kind", "slash"))
		# v8.4 dense 128px frames first, then legacy 64px
		var path = "res://assets/art/fx/%s_dense_%d.png" % [kind, fi]
		if not ResourceLoader.exists(path):
			path = "res://assets/art/fx/%s_%d.png" % [kind, fi]
		if not ResourceLoader.exists(path):
			path = "res://assets/art/fx/slash_dense_%d.png" % fi
		if not ResourceLoader.exists(path):
			path = "res://assets/art/fx/slash_%d.png" % fi
		if ResourceLoader.exists(path):
			var fs: float = float(FX_SIZE.get(kind, 84.0)) * _k()
			overlay.draw_texture_rect(_tex(path), Rect2(s.pos - Vector2(fs, fs) * 0.5, Vector2(fs, fs)), false)
		if kind in ["slash", "crit", "spark"]:
			var spark = "res://assets/art/fx/hit_dense_%d.png" % fi
			if not ResourceLoader.exists(spark):
				spark = "res://assets/art/fx/hit_spark_%d.png" % fi
			if ResourceLoader.exists(spark):
				var hs := 72.0 * _k()
				overlay.draw_texture_rect(_tex(spark), Rect2(s.pos - Vector2(hs, hs) * 0.5, Vector2(hs, hs)), false, Color(1, 1, 1, 0.9))
	# 交战锁定爆发环
	for lb in _lock_burst_fx:
		var fi3 = mini(5, int(lb.age / 0.09))
		var lp = "res://assets/art/fx/lock_dense_%d.png" % fi3
		if not ResourceLoader.exists(lp):
			lp = "res://assets/art/fx/lock_%d.png" % fi3
		if ResourceLoader.exists(lp):
			var a3 = clampf(1.0 - lb.age / 0.55, 0.0, 1.0)
			overlay.draw_texture_rect(_tex(lp), Rect2(lb.pos - Vector2(40, 40) * _k(), Vector2(80, 80) * _k()), false, Color(1, 1, 1, a3))
	# 伤害飘字 + dmg_pop 底板
	for fx in _dmg_fx:
		var a = clampf(1.0 - fx.age / 1.1, 0.0, 1.0)
		var yoff = -fx.age * 36.0
		var col: Color = fx.col
		col.a = a
		var fi2 = mini(5, int(fx.age / 0.12))
		var pop = "res://assets/art/fx/dmg_pop_dense_%d.png" % fi2
		if not ResourceLoader.exists(pop):
			pop = "res://assets/art/fx/dmg_pop_%d.png" % fi2
		if ResourceLoader.exists(pop):
			overlay.draw_texture_rect(_tex(pop), Rect2(fx.pos + Vector2(-24, yoff - 32) * _k(), Vector2(48, 48) * _k()), false, Color(1, 1, 1, a * 0.9))
		overlay.draw_string(UIKit.font("bold"), fx.pos + Vector2(-12, yoff) * _k(), fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * sqrt(_k())), col)
	# 回合横幅
	if _turn_flash > 0.0:
		var a2 = clampf(_turn_flash / 0.9, 0.0, 1.0)
		var txt = "—— 玩家回合 ——" if turn_team == "player" else "—— 敌方回合 ——"
		var tfi = mini(5, int((0.9 - _turn_flash) / 0.15))
		var tfp = "res://assets/art/fx/turn_flash_dense_%d.png" % tfi
		if not ResourceLoader.exists(tfp):
			tfp = "res://assets/art/fx/turn_flash_%d.png" % tfi
		var bc := ORIGIN + Vector2(MAP_W, MAP_H) * CELL * 0.5
		var bandc: Color = UIKit.ACCENT if turn_team == "player" else UIKit.DANGER
		overlay.draw_rect(Rect2(Vector2(ORIGIN.x, bc.y - 34), Vector2(MAP_W * CELL, 68)), Color(0.03, 0.04, 0.06, 0.72 * a2))
		overlay.draw_rect(Rect2(Vector2(ORIGIN.x, bc.y - 34), Vector2(MAP_W * CELL, 1)), Color(bandc, 0.6 * a2))
		overlay.draw_rect(Rect2(Vector2(ORIGIN.x, bc.y + 33), Vector2(MAP_W * CELL, 1)), Color(bandc, 0.6 * a2))
		if ResourceLoader.exists(tfp):
			overlay.draw_texture_rect(_tex(tfp), Rect2(bc - Vector2(150, 48), Vector2(96, 96)), false, Color(1, 1, 1, a2 * 0.9))
		var tf := UIKit.font("regular")
		var tsz := tf.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		overlay.draw_string(tf, bc + Vector2(-tsz.x * 0.5, 9), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(UIKit.TEXT, a2))
	# 地形悬停提示
	if _in_bounds(_hover_cell):
		var sw = "res://assets/art/fx/attack_wash.png" if attack_mode else ("res://assets/art/fx/move_wash.png" if ResourceLoader.exists("res://assets/art/fx/move_wash.png") else "res://assets/art/fx/select_wash.png")
		if ResourceLoader.exists(sw):
			var hr = Rect2(ORIGIN + Vector2(_hover_cell) * CELL, Vector2(CELL - 2, CELL - 2))
			overlay.draw_texture_rect(_tex(sw), hr.grow(2.0), false, Color(1, 1, 1, 0.55 + 0.25 * sin(_sel_pulse * 6.0)))
		var tid = terrain[_hover_cell.y][_hover_cell.x]
		var ti = BattleRules.terrain_info(tid)
		var tip = "%s　回避+%d　防+%d　移耗%d" % [ti.name, ti.avo_bonus, ti.get("def_bonus", 0), ti.move_cost]
		var tfont := UIKit.font("regular")
		var tws := tfont.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var tip_pos = ORIGIN + Vector2(_hover_cell.x * CELL, _hover_cell.y * CELL) + Vector2(10, -10)
		tip_pos.x = clampf(tip_pos.x, ORIGIN.x + 6, ORIGIN.x + MAP_W * CELL - tws - 16)
		tip_pos.y = maxf(tip_pos.y, ORIGIN.y + 18)
		overlay.draw_rect(Rect2(tip_pos + Vector2(-8, -15), Vector2(tws + 16, 22)), Color(0.06, 0.08, 0.11, 0.9))
		overlay.draw_rect(Rect2(tip_pos + Vector2(-8, -15), Vector2(tws + 16, 22)), Color(1, 1, 1, 0.14), false, 1.0)
		overlay.draw_string(tfont, tip_pos, tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIKit.TEXT)


func _zoc_cell_kind(pos: Vector2i) -> String:
	## 悬停格的控带代价类型（用于音效电报）
	if attack_mode or move_cells.is_empty():
		return ""
	if not move_cells.has(pos):
		return ""
	var foes_ov = _enemy_positions("player")
	var locked_ov = false
	var start_eng = false
	if selected >= 0 and selected < units.size():
		var su = units[selected]
		if su.team == "player":
			locked_ov = int(su.char.temp_combat_lock) > 0
			start_eng = locked_ov or BattleRules.is_engaged(su.pos, foes_ov)
	var in_z = BattleRules.in_zoc(pos, foes_ov)
	var leaving = start_eng and (not in_z) and selected >= 0 and pos != units[selected].pos
	if locked_ov and leaving:
		return "lock3"
	if leaving:
		return "leave2"
	if in_z:
		return "zoc"
	return ""

func _zoc_hover_audio(cell: Vector2i) -> void:
	var kind = _zoc_cell_kind(cell)
	if kind == _zoc_hover_kind:
		return
	_zoc_hover_kind = kind
	if kind == "":
		return
	# 空间感：距选中单位越远音量越低（前端式距离衰减，非短 tick 一律）
	var dist := 1.0
	if selected >= 0 and selected < units.size():
		dist = float(_manhattan(units[selected].pos, cell))
	var vol = clampf(-3.0 - dist * 2.2, -18.0, -2.0)
	var world = ORIGIN + Vector2(cell) * CELL + Vector2(CELL * 0.5, CELL * 0.5)
	if selected >= 0 and selected < units.size():
		var lp = ORIGIN + Vector2(units[selected].pos) * CELL + Vector2(CELL * 0.5, CELL * 0.5)
		Sfx.set_listener_origin(lp)
	if kind == "lock3":
		vol = clampf(vol + 2.0, -16.0, -1.0)  # 锁脱更响
		Sfx.play_spatial("zoc_pulse", world, vol)
	elif kind == "leave2":
		Sfx.play_spatial("zoc_leave", world, vol)
	elif kind == "zoc":
		Sfx.play_spatial("zoc_leave", world, vol - 1.5)

func _gui_input(event: InputEvent) -> void:
	if battle_over:
		return
	if event is InputEventMouseMotion:
		var cell = _mouse_to_cell(event.position)
		if cell != _hover_cell:
			_hover_cell = cell
			_zoc_hover_audio(cell)
			map_draw.queue_redraw()
			if overlay:
				overlay.queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_selection()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if turn_team != "player":
			return
		var cell2 = _mouse_to_cell(event.position)
		if cell2.x < 0:
			return
		_click_cell(cell2)

func simulate_board_click(cell: Vector2i) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = cell_to_local(cell)
	_gui_input(ev)

func cell_to_local(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * CELL + Vector2(CELL * 0.5, CELL * 0.5)

func _cancel_selection() -> void:
	selected = -1
	move_cells.clear()
	attack_mode = false
	skill_mode = false
	active_skill_id = ""
	moved_this_select = false
	_refresh_info()
	_update_skill_hint()
	overlay.queue_redraw()
	map_draw.queue_redraw()

func _mouse_to_cell(pos: Vector2) -> Vector2i:
	var local = pos - ORIGIN
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var c = Vector2i(int(local.x / CELL), int(local.y / CELL))
	if not _in_bounds(c):
		return Vector2i(-1, -1)
	return c

func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < MAP_W and c.y < MAP_H

func _unit_at(pos: Vector2i) -> int:
	for i in units.size():
		if units[i].char.hp > 0 and units[i].pos == pos:
			return i
	return -1

func _select_player(ui: int) -> void:
	selected = ui
	attack_mode = false
	skill_mode = false
	active_skill_id = ""
	moved_this_select = false
	move_cells = _compute_move_cells(ui)
	_refresh_info()
	_update_skill_hint()
	overlay.queue_redraw()
	map_draw.queue_redraw()

func _can_attack_from(su: Dictionary, cell: Vector2i) -> bool:
	var d = _manhattan(su.pos, cell)
	if d < 1:
		return false
	if _is_melee(su.char):
		return d == 1
	return d <= 2

func _click_cell(cell: Vector2i) -> void:
	var ui = _unit_at(cell)
	if selected >= 0 and selected < units.size():
		var su = units[selected]
		if su.team == "player" and not su.done:
			if ui >= 0 and units[ui].team == "enemy" and units[ui].char.hp > 0:
				if attack_mode:
					if _can_attack_from(su, cell):
						var extras = _combat_extras(selected, ui)
						var pv = BattleRules.preview(su.char, units[ui].char, terrain[cell.y][cell.x], extras)
						_spawn_dmg(cell, "命中%d%%" % int(pv.hit), Color(0.9, 0.92, 1.0))
						_log("预判：命中 %d%%　伤 %d–%d%s" % [int(pv.hit), int(pv.dmg.x), int(pv.dmg.y), (" · " + "·".join(pv.tags)) if pv.tags else ""])
						_do_attack(selected, ui)
						return
					_log("目标超出攻击范围")
					return
				_refresh_info_for(ui)
				return
			if ui < 0 and not attack_mode and not moved_this_select and move_cells.has(cell):
				su.pos = cell
				moved_this_select = true
				move_cells.clear()
				_spawn_move_dust(cell)
				_refresh_info()
				map_draw.queue_redraw()
				overlay.queue_redraw()
				Sfx.move()
				_log("%s 移动至 (%d,%d)" % [su.char.name, cell.x, cell.y])
				return
			if ui >= 0 and units[ui].team == "player" and not units[ui].done and ui != selected:
				_select_player(ui)
				return
			if attack_mode and ui < 0:
				_log("攻击模式中：请点击敌人或右键取消")
			return
	if ui >= 0 and units[ui].team == "player" and not units[ui].done:
		_select_player(ui)
	elif ui >= 0:
		selected = ui
		move_cells.clear()
		attack_mode = false
		moved_this_select = false
		_refresh_info()
		overlay.queue_redraw()
		map_draw.queue_redraw()

func _is_melee(c: CKCharacter) -> bool:
	return str(GameState.get_job(c.job_id).get("atk_type", "melee")) == "melee"

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _enemy_positions(for_team: String) -> Array:
	var out: Array = []
	for u in units:
		if u.char.hp <= 0:
			continue
		if u.team != for_team:
			out.append(u.pos)
	return out

func _ally_zoc_extra(for_team: String) -> int:
	# 方阵锁喉：己方单位提供的控带额外耗
	var extra = 0
	for u in units:
		if u.team == for_team and u.char.hp > 0:
			extra = maxi(extra, int(u.char.temp_zoc_aura))
	return extra

func _compute_move_cells(ui: int) -> Dictionary:
	var u = units[ui]
	var foes = _enemy_positions(u.team)
	var ignore = bool(u.char.temp_ignore_zoc)
	var leave_free = bool(u.char.temp_leave_free)
	var zoc_extra = 0
	# 敌方移动时吃我方方阵/钉地
	if u.team == "enemy":
		zoc_extra = _ally_zoc_extra("player")
	elif u.team == "player":
		zoc_extra = _ally_zoc_extra("enemy")  # 敌军若有强化控带（少见）
	var leave_cost = 1
	if int(u.char.temp_combat_lock) > 0:
		leave_cost = 3  # 交战锁定：脱离更贵
	elif BattleRules.is_engaged(u.pos, foes):
		leave_cost = 2  # 控带内脱离也更沉
	var mv = BattleRules.move_costs(terrain, u.pos, u.char.derived_move(), foes, foes, ignore, zoc_extra, leave_cost, leave_free)
	for ou in units:
		if ou.char.hp > 0 and ou.pos != u.pos:
			mv.erase(ou.pos)
	return mv

func _spawn_dmg(cell: Vector2i, text: String, col: Color) -> void:
	var center = ORIGIN + Vector2(cell) * CELL + Vector2(CELL / 2, CELL / 2)
	_dmg_fx.append({"pos": center, "text": text, "age": 0.0, "col": col})


func _spawn_move_dust(cell: Vector2i) -> void:
	var center = ORIGIN + Vector2(cell) * CELL + Vector2(CELL / 2, CELL / 2)
	_move_dust_fx.append({"pos": center, "age": 0.0})

func _spawn_lock_burst(cell: Vector2i) -> void:
	var center = ORIGIN + Vector2(cell) * CELL + Vector2(CELL / 2, CELL / 2)
	_lock_burst_fx.append({"pos": center, "age": 0.0})
	_shake = maxf(_shake, 2.2)

func _spawn_slash(cell: Vector2i, kind: String = "slash") -> void:
	var center = ORIGIN + Vector2(cell) * CELL + Vector2(CELL / 2, CELL / 2)
	_slash_fx.append({"pos": center, "age": 0.0, "kind": kind})
	_shake = 3.5

func _do_attack(ai: int, di: int) -> void:
	_combat_rec = []
	var _hp0a: int = int(units[ai].char.hp)
	var _hp0d: int = int(units[di].char.hp)
	_resolve_strike(ai, di, true)
	var atk = units[ai]
	var def = units[di]
	# 交战锁定：攻/受击双方咬住（脱离代价加重，反击优先）
	_apply_combat_lock(ai, di)
	_spawn_lock_burst(atk.pos)
	_spawn_lock_burst(def.pos)
	# 连击：敏差足够且目标仍存活
	if def.char.hp > 0 and BattleRules.can_follow_up(atk.char, def.char):
		_log("连击！敏差触发第二击")
		_spawn_dmg(def.pos, "连击", Color(0.95, 0.75, 0.35))
		_resolve_strike(ai, di, false)
	# 反击：存活且射程覆盖——锁定单位反击命中+10
	if def.char.hp > 0 and BattleRules.can_counter(atk.char, def.char, atk.pos, def.pos):
		var bonus = 0
		if int(def.char.temp_combat_lock) > 0:
			def.char.temp_hit_bonus += 10
			bonus = 10
			_log("%s 交战锁定反击！" % def.char.name)
			_spawn_dmg(atk.pos, "锁反", Color(1.0, 0.45, 0.35))
		else:
			_log("%s 反击！" % def.char.name)
			_spawn_dmg(atk.pos, "反击", Color(0.85, 0.55, 0.95))
		_resolve_strike(di, ai, false)
		if bonus > 0:
			def.char.temp_hit_bonus = maxi(0, def.char.temp_hit_bonus - bonus)
	atk.done = true
	selected = -1
	move_cells.clear()
	attack_mode = false
	skill_mode = false
	active_skill_id = ""
	moved_this_select = false
	_refresh_info()
	map_draw.queue_redraw()
	overlay.queue_redraw()
	_queue_cutscene(ai, di, _hp0a, _hp0d)
	_check_end()

func _cutscenes_enabled() -> bool:
	return DisplayServer.get_name() != "headless" and bool(GameState.get_meta("cutscenes_on", true))

func _queue_cutscene(ai: int, di: int, hp0a: int, hp0d: int) -> void:
	if not _cutscenes_enabled() or _combat_rec.is_empty():
		_combat_rec = []
		return
	var atk = units[ai]
	var def = units[di]
	var a_side := "right" if atk.team == "player" else "left"   # FE convention: our side on the right
	var d_side := "left" if a_side == "right" else "right"
	var strikes: Array = []
	var fc := {a_side: {}, d_side: {}}
	for r in _combat_rec:
		var from: String = a_side if int(r.a) == ai else d_side
		strikes.append({"from": from, "hit": r.hit, "crit": r.crit, "dmg": r.dmg, "killed": r.killed, "skill": r.skill, "hp_after": r.hp_after})
		if fc[from].is_empty():
			fc[from] = {"hit": r.hit_chance, "dmg": r.dmg if r.hit else "—"}
	var tid := str(terrain[def.pos.y][def.pos.x])
	var bg: Array = _biome_ground()
	var ground: String = tid if tid in ["forest", "hill", "fort", "bridge"] else str(bg[0])
	var gv: Vector3 = bg[1]
	var _AtlasArt = preload("res://scripts/art/atlas_art.gd")
	var rec := {
		a_side: {"char": atk.char, "team": atk.team, "template": str(atk.get("template", "")), "hp0": hp0a,
			"hit": fc[a_side].get("hit", "—"), "dmg": fc[a_side].get("dmg", "—"), "crit": atk.char.derived_crit()},
		d_side: {"char": def.char, "team": def.team, "template": str(def.get("template", "")), "hp0": hp0d,
			"hit": fc[d_side].get("hit", "—"), "dmg": fc[d_side].get("dmg", "—"), "crit": def.char.derived_crit()},
		"strikes": strikes, "ground": ground, "grade": Color(gv.x, gv.y, gv.z),
		"backdrop": str(_AtlasArt.battle_backdrop_for_map(map_id)),
		"title": "%s · %s" % [map_name, str(BattleRules.terrain_info(tid).get("name", tid))],
	}
	_combat_rec = []
	_cut_queue.append(rec)
	if not _cut_playing:
		_drain_cutscenes()

func play_cutscene_record(rec: Dictionary) -> void:
	_cut_queue.append(rec)
	if not _cut_playing:
		_drain_cutscenes()

func _drain_cutscenes() -> void:
	_cut_playing = true
	while not _cut_queue.is_empty():
		var r: Dictionary = _cut_queue.pop_front()
		var cs = CombatCutsceneScript.new()
		cs.setup(r)
		add_child(cs)
		await cs.finished
	_cut_playing = false

func _combat_extras(ai: int, di: int) -> Dictionary:
	var atk = units[ai]
	var def = units[di]
	var flank = BattleRules.has_flank(atk.pos, def.pos, units, atk.team, ai)
	var extras = {"flank": flank}
	# 占地利：防守方地形加成翻倍感（via def_bonus_mul）
	if def.char.temp_terrain_ward:
		extras["terrain_mul"] = 2.0
		var tid = terrain[def.pos.y][def.pos.x]
		if tid in ["fort", "forest"]:
			extras["flat_def"] = 2
	# 交战锁定中的防守：堡垒格额外硬抗
	if int(def.char.temp_combat_lock) > 0:
		var tid2 = terrain[def.pos.y][def.pos.x]
		if tid2 == "fort":
			extras["flat_def"] = int(extras.get("flat_def", 0)) + 1
	return extras

func _apply_combat_lock(ai: int, di: int) -> void:
	# 双方进入交战锁定（再交战刷新至 2）
	for idx in [ai, di]:
		if idx < 0 or idx >= units.size():
			continue
		var u = units[idx]
		if u.char.hp <= 0:
			continue
		u.char.temp_combat_lock = maxi(u.char.temp_combat_lock, 3)  # 再交战刷新锁定（三回合感）
		_spawn_dmg(u.pos, "锁定", Color(1.0, 0.4, 0.35))
		_spawn_slash(u.pos, "lock")
	if not has_meta("lock_beat_fired") and _is_lock_tutorial_map():
		set_meta("lock_beat_fired", true)
		_log("〔教学拍〕锁定已触发——看棋子外圈红环；脱离将更贵，反击更准。练习完成，可以结束回合。")
		_spawn_dmg(units[ai].pos if ai >= 0 else units[di].pos, "教学·锁定", Color(1.0, 0.7, 0.4))
		_clear_lock_practice_banner()
		_show_lock_tip_panel("练习完成", "交战锁定已体验。之后正式对局也会出现此效果。", 2, 4.0)

func _resolve_strike(ai: int, di: int, allow_skill: bool) -> void:

	var atk = units[ai]
	var def = units[di]
	if atk.char.hp <= 0 or def.char.hp <= 0:
		return
	var _hp_before: int = int(def.char.hp)
	var tid = terrain[def.pos.y][def.pos.x]
	var extras = _combat_extras(ai, di)
	var skill_id = ""
	var sk = {}
	if allow_skill and skill_mode and active_skill_id != "" and (atk.team == "player" or atk.team == "enemy"):
		skill_id = active_skill_id
		sk = GameState.get_skill(skill_id)
		if sk.get("ignore_terrain_avo"):
			tid = "plain"
		extras["hit_mod"] = int(sk.get("hit_mod", 0))
	var result = BattleRules.roll_attack(atk.char, def.char, tid, rng, extras)
	if skill_id != "" and sk.get("type") == "offense":
		# 战技：撤销普通掷骰伤害后，按技能倍率重掷
		if result.hit:
			def.char.hp = mini(def.char.max_hp, def.char.hp + int(result.damage))
		var hit_chance = BattleRules.calc_hit(atk.char, def.char, tid, extras) + int(sk.get("hit_mod", 0))
		hit_chance = clampi(hit_chance, 5, 99)
		var hit = rng.randi_range(1, 100) <= hit_chance
		var dmg_range = BattleRules.calc_damage_range(atk.char, def.char, tid, extras)
		var dmg = 0
		var crit = false
		if hit:
			dmg = rng.randi_range(dmg_range.x, dmg_range.y)
			dmg = int(round(dmg * float(sk.get("dmg_mul", 1.0))))
			if int(sk.get("vs_tank_bonus", 0)) > 0 and BattleRules.job_role(def.char.job_id) == "tank":
				dmg += int(sk.get("vs_tank_bonus", 0))
			if rng.randi_range(1, 100) <= atk.char.derived_crit():
				crit = true
				Sfx.crit()
				_spawn_slash(def.pos, "crit")
				if _unit_panel:
					UIFX.flash_modulate(_unit_panel, Color(1.35, 1.15, 0.7), 0.2)
					UIFX.shake_control(_unit_panel, 5.0, 0.2)
				dmg = int(dmg * 1.5)
			def.char.hp = maxi(0, def.char.hp - dmg)
		result = {"hit": hit, "crit": crit, "damage": dmg, "hit_chance": hit_chance, "dmg_range": dmg_range, "killed": def.char.hp <= 0, "flank": extras.get("flank", false), "role_label": str(BattleRules.role_mods(atk.char, def.char).get("label", "")), "terrain_def": int(BattleRules.terrain_info(tid).get("def_bonus", 0))}
		_consume_skill(atk.char, skill_id)
		_log("战技「%s」！" % sk.get("name", skill_id))
		if int(sk.get("self_def_penalty", 0)) > 0:
			atk.char.temp_def_buff = -int(sk.get("self_def_penalty", 0))
	if atk.char.temp_hit_bonus != 0:
		atk.char.temp_hit_bonus = 0
	var tags: Array = []
	if result.get("flank", false):
		tags.append("夹击")
		_spawn_dmg(def.pos, "夹击", Color(1.0, 0.55, 0.2))
	if str(result.get("role_label", "")) != "":
		tags.append(str(result.role_label))
	if int(result.get("terrain_def", 0)) > 0:
		tags.append("垒防" if tid == "fort" else "地形防")
	var tag_s = ("〔" + "·".join(tags) + "〕") if tags else ""
	var msg = "%s → %s%s：" % [atk.char.name, def.char.name, tag_s]
	if result.hit:
		Sfx.hit()
		_spawn_slash(def.pos, "crit" if result.crit else "slash")
		if result.crit:
			_spawn_slash(def.pos, "spark")
		if _unit_panel:
			UIFX.punch(_unit_panel, 0.04)
		msg += "命中 %d%s（掷骰相对命中率 %d%%）" % [result.damage, "（暴击）" if result.crit else "", int(result.hit_chance)]
		var col = Color(1.0, 0.85, 0.3) if result.crit else Color(1.0, 0.45, 0.35)
		_spawn_dmg(def.pos, ("暴%d" % result.damage) if result.crit else ("-%d" % result.damage), col)
		_shake = maxf(_shake, 0.28 if result.crit else 0.12)
		if result.killed:
			msg += " · 击退！"
			_spawn_dmg(def.pos, "击破", Color(1.0, 0.9, 0.5))
			if def.team == "enemy":
				_theme_banter("kill")
			if def.team == "player":
				def.char.injured = true
	else:
		Sfx.miss()
		msg += "未命中（命中率 %d%%）" % result.hit_chance
		_spawn_dmg(def.pos, "未中", Color(0.7, 0.75, 0.85))
	_combat_rec.append({"a": ai, "d": di, "hit": bool(result.hit), "crit": bool(result.get("crit", false)), "dmg": int(result.get("damage", 0)),
		"killed": def.char.hp <= 0, "skill": str(sk.get("name", skill_id)) if skill_id != "" else "", "hp_before": _hp_before,
		"hp_after": int(def.char.hp), "hit_chance": int(result.get("hit_chance", 0))})
	if result.hit and skill_id != "" and sk.get("type") == "offense":
		if float(sk.get("drain_pct", 0)) > 0:
			var heal = maxi(1, int(result.damage * float(sk.get("drain_pct", 0))))
			atk.char.hp = mini(atk.char.max_hp, atk.char.hp + heal)
			_spawn_dmg(atk.pos, "+%d" % heal, Color(0.9, 0.4, 0.55))
			msg += " · 吸血%d" % heal
		if int(sk.get("expose", 0)) > 0:
			def.char.temp_exposed = maxi(def.char.temp_exposed, int(sk.get("expose", 0)))
			_spawn_dmg(def.pos, "破防", Color(0.9, 0.6, 0.3))
			msg += " · 破防"
		if int(sk.get("push", 0)) > 0:
			if _try_push(ai, di):
				msg += " · 击退"
				_spawn_dmg(def.pos, "击退", Color(0.7, 0.8, 1.0))
		if float(sk.get("cleave_pct", 0)) > 0:
			var cleave_dmg = maxi(1, int(result.damage * float(sk.get("cleave_pct", 0))))
			for j in units.size():
				if j == di:
					continue
				var o = units[j]
				if o.team == def.team and o.char.hp > 0 and _manhattan(def.pos, o.pos) == 1:
					o.char.hp = maxi(0, o.char.hp - cleave_dmg)
					_spawn_dmg(o.pos, "溅-%d" % cleave_dmg, Color(1.0, 0.5, 0.25))
					_spawn_slash(o.pos)
					msg += " · 溅射%s" % o.char.name
					if o.char.hp <= 0 and o.team == "player":
						o.char.injured = true
					break
	if atk.char.temp_crit_bonus != 0 and allow_skill:
		atk.char.temp_crit_bonus = 0
	_log(msg)

func _try_push(ai: int, di: int) -> bool:
	var atk = units[ai]
	var def = units[di]
	var dx = signi(def.pos.x - atk.pos.x)
	var dy = signi(def.pos.y - atk.pos.y)
	if dx == 0 and dy == 0:
		return false
	var np = def.pos + Vector2i(dx, dy)
	if not _in_bounds(np):
		return false
	if _unit_at(np) >= 0:
		return false
	def.pos = np
	map_draw.queue_redraw()
	return true

func _wait_selected() -> void:
	if selected < 0:
		return
	var u = units[selected]
	if u.team != "player" or u.done:
		return
	u.done = true
	selected = -1
	move_cells.clear()
	attack_mode = false
	moved_this_select = false
	_log("%s 待命" % u.char.name)
	map_draw.queue_redraw()
	overlay.queue_redraw()
	_refresh_info()

func _start_player_turn() -> void:
	turn_team = "player"
	phase_label.text = "%s · 我方行动" % map_name
	phase_label.add_theme_color_override("font_color", UIKit.TEXT)
	_turn_flash = 0.9
	Sfx.turn()
	var pcs: Array = []
	for u in units:
		if u.team == "player":
			u.done = false
			# 铁壁姿态持续到己方下回合开始时清除
			u.char.temp_def_buff = 0
			u.char.temp_exposed = 0
			u.char.temp_zoc_aura = 0
			u.char.temp_ignore_zoc = false
			u.char.temp_leave_free = false
			u.char.temp_terrain_ward = false
			if u.char.temp_combat_lock > 0:
				u.char.temp_combat_lock -= 1
			pcs.append(u.char)
	GameState.tick_skill_cooldowns(pcs)
	selected = -1
	move_cells.clear()
	attack_mode = false
	skill_mode = false
	active_skill_id = ""
	moved_this_select = false
	_theme_banter("turn")
	map_draw.queue_redraw()
	overlay.queue_redraw()
	_update_skill_hint()

func _end_player_turn() -> void:
	if battle_over:
		return
	if _lock_practice_pending():
		_log("〔强制练习〕请先攻击一名敌人，体验交战锁定——尚未可结束回合。")
		_show_lock_practice_banner()
		Sfx.miss()
		return
	turn_team = "enemy"
	phase_label.text = "%s · 敌方行动" % map_name
	phase_label.add_theme_color_override("font_color", UIKit.DANGER)
	_turn_flash = 0.9
	for u in units:
		if u.team == "enemy":
			u.char.temp_exposed = 0
			if u.char.temp_combat_lock > 0:
				u.char.temp_combat_lock -= 1
	selected = -1
	move_cells.clear()
	attack_mode = false
	moved_this_select = false
	overlay.queue_redraw()
	await get_tree().create_timer(0.35).timeout
	_enemy_ai()
	if not battle_over:
		_start_player_turn()


func _show_lock_tip_once() -> void:
	if has_meta("lock_tip_shown"):
		return
	set_meta("lock_tip_shown", true)
	var tutorial = bool(BattleMaps.get_map(map_id).get("tutorial_militia", false)) or map_id.begins_with("ch0")
	if tutorial:
		_run_lock_tutorial_sequence()
	else:
		_show_lock_tip_panel(
			"交战锁定",
			"攻/受击后双方进入锁定：脱离+2移，锁定反击命中+10。抽身/拆锁可解。",
			0,
			8.0
		)

func _show_lock_tip_panel(title: String, body: String, step: int, auto_sec: float) -> Control:
	var panel = UIKit.make_panel()
	panel.position = Vector2(RAIL_X, 462)  # v8.6: rail slot over the log — never on the board
	panel.custom_minimum_size = Vector2(RAIL_W, 96)
	panel.add_theme_stylebox_override("panel", UIKit.glass(12, 0.94, true))
	panel.z_index = 20
	panel.name = "LockTipPanel"
	add_child(panel)
	# v8.5: legacy gold lock_tip_step plates retired (off-vibe, stretched) -> design-system chrome:
	# frosted panel + authored coral lock glyph + step pips
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 14)
	panel.add_child(hrow)
	var glyph := TextureRect.new()
	glyph.texture = _tex("res://assets/art/fx/lock_dense_3.png")
	glyph.custom_minimum_size = Vector2(44, 44)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(glyph)
	UIFX.breathe(glyph, 0.04, 1.6)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	hrow.add_child(vb)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 6)
	for pi in range(3):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(22 if pi == step else 10, 4)
		pip.color = UIKit.DANGER if pi == step else Color(UIKit.TEXT_DIM, 0.5)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	vb.add_child(pips)
	var t = UIKit.make_label(title, true)
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", UIKit.DANGER)
	vb.add_child(t)
	var d = UIKit.make_dim_label(body)
	d.add_theme_font_size_override("font_size", 12)
	d.custom_minimum_size = Vector2(RAIL_W - 110, 0)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(d)
	if auto_sec > 0.0:
		get_tree().create_timer(auto_sec).timeout.connect(func():
			if is_instance_valid(panel):
				panel.queue_free()
		)
	return panel

func _run_lock_tutorial_sequence() -> void:
	## 教学三拍：咬住 → 脱离代价 → 拆锁/反击
	var steps: Array = [
		{"t": "① 交战锁定·咬住", "b": "攻或受击后，双方棋子外圈出现锁定环——这就是「咬住」。"},
		{"t": "② 脱离更贵", "b": "锁定中离开交战格额外消耗 +2 移力（高于普通交战 +1）。想走，先算步数。"},
		{"t": "③ 锁反与拆锁", "b": "锁定单位反击命中+10。用战技「抽身一步 / 拆锁突围」可解除锁定。"},
	]
	_show_lock_tip_panel(str(steps[0].t), str(steps[0].b), 0, 0.0)
	get_tree().create_timer(3.2).timeout.connect(func():
		var old = get_node_or_null("LockTipPanel")
		if old: old.queue_free()
		_show_lock_tip_panel(str(steps[1].t), str(steps[1].b), 1, 0.0)
	)
	get_tree().create_timer(6.4).timeout.connect(func():
		var old2 = get_node_or_null("LockTipPanel")
		if old2: old2.queue_free()
		var p = _show_lock_tip_panel(str(steps[2].t), str(steps[2].b), 2, 0.0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var host: Node = p.get_child(0).get_child(1) if p.get_child_count() > 0 and p.get_child(0).get_child_count() > 1 else p
		host.add_child(row)
		var dismiss = UIKit.make_accent_button("开始隘口教学", 140)
		dismiss.pressed.connect(func():
			if is_instance_valid(p):
				p.queue_free()
		)
		row.add_child(dismiss)
		get_tree().create_timer(10.0).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free()
		)
	)
	_log("教学：交战锁定三拍提示已展开")



func _is_lock_tutorial_map() -> bool:
	var md = BattleMaps.get_map(map_id)
	if bool(md.get("tutorial_militia", false)) or map_id.begins_with("ch0"):
		return true
	# 中盘二次强制锁定演练（如 ch2_night）
	return bool(md.get("lock_drill", false))

func _lock_practice_pending() -> bool:
	return _is_lock_tutorial_map() and not has_meta("lock_beat_fired")

func _show_lock_practice_banner() -> void:
	if has_meta("lock_practice_banner"):
		return
	set_meta("lock_practice_banner", true)
	## v8.6: slim coral pill in the turn bar — the board stays clear
	var panel = UIKit.make_glass(18, 0.82)
	var pst: StyleBoxFlat = UIKit.glass(18, 0.82)
	pst.border_color = Color(UIKit.DANGER, 0.55)
	pst.content_margin_top = 6
	pst.content_margin_bottom = 6
	pst.content_margin_left = 14
	pst.content_margin_right = 14
	pst.shadow_size = 0
	panel.add_theme_stylebox_override("panel", pst)
	panel.position = Vector2(372, 12)
	panel.custom_minimum_size = Vector2(508, 0)
	panel.z_index = 18
	var ct := find_child("ControlsTip", true, false)
	if ct:
		ct.visible = false
	panel.name = "LockPracticeBanner"
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	panel.add_child(vb)
	var title = "【强制练习】交战锁定"
	var tip = "先选中单位 → 攻击模式 → 攻击一名敌人，触发锁定后才能结束回合。"
	if bool(BattleMaps.get_map(map_id).get("lock_drill", false)) and not map_id.begins_with("ch0"):
		if map_id.begins_with("ch6"):
			title = "【终局演练】交战锁定决战复习"
			tip = "托孤堡垒：终局再练锁定。攻击敌人触发红环后，才能结束回合——此后全靠判断。"
		elif map_id.begins_with("ch5") or map_id.begins_with("ch4"):
			title = "【后期演练】交战锁定总复习"
			tip = "断桥守夜：再次强制练习锁定。攻击敌人触发红环后，才能结束回合。"
		else:
			title = "【中盘演练】交战锁定复习"
			tip = "夜袭中再练一次锁定：攻击敌人触发红环锁定后，方可结束回合。"
	var t = UIKit.make_label(title)
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", UIKit.DANGER)
	vb.add_child(t)
	var tl = UIKit.make_dim_label(tip)
	tl.add_theme_font_size_override("font_size", 11)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(478, 0)
	vb.add_child(tl)
	panel.tooltip_text = tip

func _clear_lock_practice_banner() -> void:
	var p = get_node_or_null("LockPracticeBanner")
	if p:
		p.queue_free()
	var ct := find_child("ControlsTip", true, false)
	if ct:
		ct.visible = true

func _enemy_known_skills(c: CKCharacter) -> Array:
	var out: Array = []
	for sid in c.skills:
		if sid not in out:
			out.append(sid)
	for sid in c.unlocked_skills:
		if sid not in out:
			out.append(sid)
	return out

func _enemy_skill_ready(c: CKCharacter, sid: String) -> bool:
	if int(c.skill_uses.get(sid, 0)) <= 0:
		return false
	if int(c.skill_cd.get(sid, 0)) > 0:
		return false
	return true

func _enemy_try_skills(ui: int) -> void:
	var u = units[ui]
	var c: CKCharacter = u.char
	# 1) 残血被锁 → 抽身/拆锁
	if int(c.temp_combat_lock) > 0 and float(c.hp) / float(maxi(1, c.max_hp)) < 0.85:
		for sid in ["disengage_step", "lock_breaker"]:
			if sid in _enemy_known_skills(c) and _enemy_skill_ready(c, sid):
				_cast_buff_skill_for_team(ui, sid)
				_log("%s 敌技「%s」" % [c.name, GameState.get_skill(sid).get("name", sid)])
				await get_tree().create_timer(0.2).timeout
				return
	# 2) 站在林/垒 → 占地利
	var tid = terrain[u.pos.y][u.pos.x]
	if tid in ["fort", "forest", "hill"]:
		if "terrain_ward" in _enemy_known_skills(c) and _enemy_skill_ready(c, "terrain_ward"):
			_cast_buff_skill_for_team(ui, "terrain_ward")
			_log("%s 敌技「占地利」" % c.name)
			await get_tree().create_timer(0.18).timeout
			return
	# 3) 铁壁 / 锁定猎物
	for sid in ["guard_stance", "mark_prey", "hold_phalanx", "anchor_guard", "iron_wall", "ember_seal", "mark_death", "terrain_ward"]:
		if sid in _enemy_known_skills(c) and _enemy_skill_ready(c, sid):
			# 仅当附近有玩家时浪费增益不值
			var near = false
			for ou in units:
				if ou.team == "player" and ou.char.hp > 0 and _manhattan(u.pos, ou.pos) <= 3:
					near = true
					break
			if near:
				_cast_buff_skill_for_team(ui, sid)
				_log("%s 敌技「%s」" % [c.name, GameState.get_skill(sid).get("name", sid)])
				await get_tree().create_timer(0.18).timeout
				return
	# 4) 治疗类：友军残血
	for sid in _enemy_known_skills(c):
		var sk = GameState.get_skill(sid)
		if str(sk.get("type", "")) != "support":
			continue
		if not _enemy_skill_ready(c, sid):
			continue
		var need = false
		for ou in units:
			if ou.team == "enemy" and ou.char.hp > 0 and ou.char.hp < ou.char.max_hp * 0.6:
				if _manhattan(u.pos, ou.pos) <= 1:
					need = true
					break
		if need:
			_cast_support_skill_for_team(ui, sid, "enemy")
			await get_tree().create_timer(0.22).timeout
			return

func _cast_buff_skill_for_team(ui: int, sid: String) -> void:
	# 复用玩家增益逻辑（不依赖 selected）
	var sk = GameState.get_skill(sid)
	var u = units[ui]
	if sk.get("def_buff"):
		u.char.temp_def_buff = int(sk.get("def_buff"))
	if sk.get("next_hit_bonus"):
		u.char.temp_hit_bonus = int(sk.get("next_hit_bonus"))
	if sk.get("next_crit_bonus"):
		u.char.temp_crit_bonus = int(sk.get("next_crit_bonus"))
	if sk.get("zoc_aura"):
		u.char.temp_zoc_aura = int(sk.get("zoc_aura"))
	if sk.get("ignore_zoc"):
		u.char.temp_ignore_zoc = true
	if sk.get("leave_free"):
		u.char.temp_leave_free = true
	if sk.get("clear_combat_lock"):
		u.char.temp_combat_lock = 0
		_spawn_dmg(u.pos, "拆锁", Color(0.5, 0.85, 1.0))
		_spawn_slash(u.pos, "spark")
	if sk.get("terrain_ward"):
		u.char.temp_terrain_ward = true
		_spawn_dmg(u.pos, "地利", Color(0.55, 0.9, 0.55))
		_spawn_slash(u.pos, "shield")
	if sk.get("party_def_buff"):
		var add = int(sk.get("party_def_buff"))
		var team = u.team
		for ou in units:
			if ou.team == team and ou.char.hp > 0:
				ou.char.temp_def_buff = maxi(ou.char.temp_def_buff, add)
	_consume_skill(u.char, sid)
	_spawn_slash(u.pos, "shield")
	Sfx.skill()
	map_draw.queue_redraw()

func _cast_support_skill_for_team(ui: int, sid: String, team: String) -> void:
	var sk = GameState.get_skill(sid)
	var u = units[ui]
	var healed = 0
	for j in units.size():
		var o = units[j]
		if o.team != team or o.char.hp <= 0:
			continue
		if _manhattan(u.pos, o.pos) <= 1:
			var amt = rng.randi_range(int(sk.get("heal_min", 8)), int(sk.get("heal_max", 12)))
			o.char.hp = mini(o.char.max_hp, o.char.hp + amt)
			healed += 1
			_spawn_dmg(o.pos, "+%d" % amt, Color(0.4, 0.9, 0.5))
			_spawn_slash(o.pos, "heal")
	_consume_skill(u.char, sid)
	_log("%s 敌疗「%s」×%d" % [u.char.name, sk.get("name", ""), healed])
	Sfx.skill()
	map_draw.queue_redraw()


func _enemy_arm_offense(ai: int, di: int) -> void:
	var u = units[ai]
	var best_sid = ""
	var best_sc = -1.0
	for sid in _enemy_known_skills(u.char):
		if not _enemy_skill_ready(u.char, sid):
			continue
		var sk = GameState.get_skill(sid)
		if str(sk.get("type", "")) != "offense":
			continue
		var sc = 1.0 + float(sk.get("dmg_mul", 1.0)) + float(sk.get("hit_mod", 0)) * 0.02
		if units[di].char.hp <= u.char.derived_atk():
			sc += 2.0  # 斩杀感
		if sc > best_sc:
			best_sc = sc
			best_sid = sid
	if best_sid != "" and rng.randf() < 0.80:
		skill_mode = true
		active_skill_id = best_sid
		_log("%s 蓄力「%s」" % [u.char.name, GameState.get_skill(best_sid).get("name", best_sid)])
		_spawn_dmg(u.pos, "技", Color(0.95, 0.7, 0.4))


func _tick_skill_cds(team: String) -> void:
	for u in units:
		if u.team != team or u.char.hp <= 0:
			continue
		for sid in u.char.skill_cd.keys():
			var v = int(u.char.skill_cd[sid])
			if v > 0:
				u.char.skill_cd[sid] = v - 1

func _enemy_ai() -> void:
	var ecs: Array = []
	for u in units:
		if u.team == "enemy" and u.char.hp > 0:
			ecs.append(u.char)
	GameState.tick_skill_cooldowns(ecs)
	for i in units.size():
		var u = units[i]
		if u.team != "enemy" or u.char.hp <= 0:
			continue
		# 敌方自动释放战技（增益优先，再进攻）
		await _enemy_try_skills(i)
		if battle_over:
			return
		if units[i].char.hp <= 0:
			continue
		u = units[i]
		# 被锁且残血：优先抽身到高防格（不主动贴战）
		var locked_self = int(u.char.temp_combat_lock) > 0
		var mv = _compute_move_cells(i)
		if not mv.has(u.pos):
			mv[u.pos] = 0
		var best_score := -9999.0
		var best_pos: Vector2i = u.pos
		var best_target := -1
		var melee = _is_melee(u.char)
		var foes_player = _enemy_positions("enemy")  # player positions as ZoC sources for enemy
		for pos in mv.keys():
			var stand_tid = terrain[pos.y][pos.x]
			var tinfo = BattleRules.terrain_info(stand_tid)
			var stand_bonus = float(tinfo.get("def_bonus", 0)) * 2.6 + float(tinfo.get("avo_bonus", 0)) * 0.12
			if stand_tid in ["fort", "forest", "hill"]:
				stand_bonus += 2.0
			# 占位卡住敌方 Cont：邻格有残血玩家则加分
			for j2 in units.size():
				var tj = units[j2]
				if tj.team == "player" and tj.char.hp > 0 and _manhattan(pos, tj.pos) == 1:
					if float(tj.char.hp) / float(maxi(1, tj.char.max_hp)) < 0.55:
						stand_bonus += 2.4
					break
			# 脱离锁定惩罚：离开交战格更贵，AI 更不愿无意义挪动
			if locked_self and pos != u.pos:
				var still_eng = BattleRules.is_engaged(pos, foes_player)
				if not still_eng:
					var hp_ok = float(u.char.hp) / float(maxi(1, u.char.max_hp))
					stand_bonus -= 5.0 if hp_ok < 0.5 else 6.5  # 血厚时更不愿浪费锁脱
				elif stand_tid == "fort":
					stand_bonus += 5.5  # 锁住时占垒
				elif stand_tid in ["forest", "hill"]:
					stand_bonus += 2.2
			elif (not locked_self) and BattleRules.is_engaged(u.pos, foes_player) and pos != u.pos:
				if not BattleRules.is_engaged(pos, foes_player):
					stand_bonus -= 2.4  # 控带脱离 leave_cost=2 对齐
			for j in units.size():
				var t = units[j]
				if t.team != "player" or t.char.hp <= 0:
					continue
				var d = _manhattan(pos, t.pos)
				var can_hit = (d == 1) if melee else (d >= 1 and d <= 2)
				if not can_hit:
					var approach = -float(d) * 2.0
					if not melee and d == 1:
						approach -= 4.0
					# 残血被锁：偏向高防撤退格
					if locked_self and float(u.char.hp) / float(maxi(1, u.char.max_hp)) < 0.55:
						approach = stand_bonus * 3.0 - float(d) * 0.25
					var sc2 = approach + stand_bonus
					if sc2 > best_score and best_target < 0:
						best_score = sc2
						best_pos = pos
					continue
				var old = u.pos
				u.pos = pos
				var extras = {"flank": BattleRules.has_flank(pos, t.pos, units, "enemy", i)}
				u.pos = old
				var tid = terrain[t.pos.y][t.pos.x]
				var expect = BattleRules.expected_damage(u.char, t.char, tid, extras)
				if expect >= t.char.hp:
					expect += 20.0
					if locked_self and pos == u.pos:
						expect += 3.0  # 锁定中原地击杀更优
				var hp_frac = float(t.char.hp) / float(maxi(1, t.char.max_hp))
				expect += (1.0 - hp_frac) * 4.5
				if extras.get("flank", false):
					expect += 4.8
				if not melee and d == 2:
					expect += 2.5
				# 优先咬住已锁定的目标（延长交战）
				if int(t.char.temp_combat_lock) > 0:
					expect += 4.2
				# 已与自己交战相邻：续咬
				if locked_self and _manhattan(u.pos, t.pos) == 1:
					expect += 2.0
				# 威胁残血友军的敌人优先压住
				var threat = false
				for ou in units:
					if ou.team == "enemy" and ou.char.hp > 0 and float(ou.char.hp)/float(maxi(1,ou.char.max_hp)) < 0.50:
						if _manhattan(t.pos, ou.pos) <= 3:
							threat = true
							break
				if threat:
					expect += 4.2
					if BattleRules.is_engaged(pos, foes_player):
						expect += 2.0  # 占控带压残血
				# 攻击会刷新己方锁定——残血时略减
				if locked_self and float(u.char.hp) / float(maxi(1, u.char.max_hp)) < 0.35:
					expect -= 2.5
				expect += stand_bonus
				if expect > best_score:
					best_score = expect
					best_pos = pos
					best_target = j
		if best_pos != u.pos:
			u.pos = best_pos
			_spawn_move_dust(best_pos)
			_log("%s 机动至 (%d,%d)" % [u.char.name, best_pos.x, best_pos.y])
			map_draw.queue_redraw()
		if best_target >= 0:
			var d2 = _manhattan(u.pos, units[best_target].pos)
			var ok = (d2 == 1) if melee else (d2 >= 1 and d2 <= 2)
			if ok:
				var tgt = units[best_target]
				# 敌方进攻战技
				_enemy_arm_offense(i, best_target)
				var pv = BattleRules.preview(u.char, tgt.char, terrain[tgt.pos.y][tgt.pos.x], _combat_extras(i, best_target))
				_spawn_dmg(tgt.pos, "%d%%" % int(pv.hit), Color(0.85, 0.85, 0.95))
				_do_attack(i, best_target)
				skill_mode = false
				active_skill_id = ""
				await get_tree().create_timer(0.28).timeout
				if battle_over:
					return
				continue
		map_draw.queue_redraw()
		await get_tree().create_timer(0.18).timeout
		if battle_over:
			return

func _check_end() -> void:
	var pc = 0
	var ec = 0
	for u in units:
		if u.char.hp <= 0:
			continue
		if u.team == "player":
			pc += 1
		else:
			ec += 1
	if ec == 0:
		_finish(true)
	elif pc == 0:
		_finish(false)

func _finish(win: bool) -> void:
	if battle_over:
		return
	battle_over = true
	if win:
		GameState.set_flag("battle_done")
		var purse = 35
		if bool(GameState.house_mods.get("warlord_purse", false)):
			purse += 10
		if bool(GameState.house_mods.get("warlord_purse2", false)):
			purse += 10
		GameState.silver += purse
		GameState.add_rep("ashland", 8)
		for u in units:
			if u.team == "player" and u.char.hp > 0:
				u.char.exp += 15
			elif u.team == "player":
				u.char.hp = maxi(1, int(u.char.max_hp * 0.3))
				u.char.injured = true
		Sfx.win()
		if not bool(BattleMaps.get_map(map_id).get("tutorial_militia", false)):
			Sfx.fanfare()
		_log("【胜利】%s肃清。+%d 银。" % [map_name, purse])
		_mark_map_victory()
		GameState.on_battle_quest_victory()
		if not bool(BattleMaps.get_map(map_id).get("tutorial_militia", false)):
			GameState.add_skill_point(1)
			_log("获得战技点 +1（当前 %d）" % GameState.skill_points)
		# 战勋旁注微奖
		if int(GameState.house_mods.get("war_memory", 0)) > 0:
			GameState.silver += mini(10, int(GameState.house_mods.war_memory) * 2)
		phase_label.text = "★ " + Locale.t("battle_win") + " ★"
		phase_label.add_theme_color_override("font_color", UIKit.ACCENT)
	else:
		Sfx.lose()
		_log("【败北】可重试，进度旗标保留。")
		phase_label.text = Locale.t("battle_lose")
		phase_label.add_theme_color_override("font_color", UIKit.DANGER)
		for u in units:
			if u.team == "player":
				u.char.hp = u.char.max_hp
	GameState.save_game()
	# 胜负大面板
	var end_panel = UIKit.make_panel()
	end_panel.add_theme_stylebox_override("panel", UIKit.glass(16, 0.92, true))
	end_panel.custom_minimum_size = Vector2(480, 0)
	end_panel.position = ORIGIN + Vector2(MAP_W, MAP_H) * CELL * 0.5 - Vector2(240, 60)
	end_panel.z_index = 30
	add_child(end_panel)
	var vb := VBoxContainer.new()
	end_panel.add_child(vb)
	var result_l = UIKit.make_label("胜利 — 灰旗仍在风里。" if win else "败北 — 旗可再举。", true)
	result_l.add_theme_font_size_override("font_size", 22)
	result_l.add_theme_color_override("font_color", UIKit.ACCENT if win else UIKit.DANGER)
	vb.add_child(result_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	if win:
		var b = UIKit.make_accent_button("返回章节", 160)
		b.pressed.connect(func():
			var path = str(GameState.get_meta("battle_return", "res://scenes/story/chapter0.tscn"))
			get_tree().change_scene_to_file(path)
		)
		row.add_child(b)
	else:
		var r = UIKit.make_accent_button("重新挑战", 160)
		r.pressed.connect(func(): get_tree().reload_current_scene())
		row.add_child(r)
		var b = UIKit.make_button("返回章节", 160)
		b.pressed.connect(func():
			get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
		)
		row.add_child(b)


func _mark_map_victory() -> void:
	if map_id == "ch0_pass":
		GameState.set_flag("battle_done")
	elif map_id == "ch1_hill":
		GameState.set_flag("ch1_hill_done")
	elif map_id == "ch1_ford":
		GameState.set_flag("ch1_ford_done")
	elif map_id == "ch1_fog":
		GameState.set_flag("ch1_fog_done")
	elif map_id == "ch2_night":
		GameState.set_flag("ch2_night_done")
	elif map_id == "ch3_forge":
		GameState.set_flag("ch3_forge_done")
	elif map_id == "ch3_shrine":
		GameState.set_flag("ch3_shrine_done")
	elif map_id == "ch4_gate":
		GameState.set_flag("ch4_gate_done")
	elif map_id == "ch5_river":
		GameState.set_flag("ch5_river_done")
	elif map_id == "ch5_feast":
		GameState.set_flag("ch5_feast_done")
	elif map_id == "ch5_bridge":
		GameState.set_flag("ch5_bridge_done")
	elif map_id == "ch6_archive":
		GameState.set_flag("ch6_archive_done")
	elif map_id == "ch6_redoubt":
		GameState.set_flag("ch6_redoubt_done")
	elif map_id == "ch6_bloodseal":
		GameState.set_flag("ch6_bloodseal_done")
	elif map_id == "ch7_field":
		GameState.set_flag("ch7_field_done")
	elif map_id == "ch8_harbor":
		GameState.set_flag("ch8_harbor_done")
	elif map_id == "ch8_quay":
		GameState.set_flag("ch8_quay_done")
	elif map_id == "ch8_treaty":
		GameState.set_flag("ch8_treaty_done")
	elif map_id == "ch9_caravan":
		GameState.set_flag("ch9_caravan_done")
	elif map_id == "ch10_echo":
		GameState.set_flag("ch10_echo_done")
	elif map_id == "ch10_banner":
		GameState.set_flag("ch10_banner_done")
	elif map_id == "ch10_seal":
		GameState.set_flag("ch10_seal_done")
	elif map_id == "ch11_gate":
		GameState.set_flag("ch11_gate_done")
	elif map_id == "ch12_granary":
		GameState.set_flag("ch12_granary_done")
	elif map_id == "ch12_ambush":
		GameState.set_flag("ch12_ambush_done")
	elif map_id == "ch12_rival":
		GameState.set_flag("ch12_rival_done")
	elif map_id == "ch13_heir":
		GameState.set_flag("ch13_heir_done")
	elif map_id == "ch14_torch":
		GameState.set_flag("ch14_torch_done")
	elif map_id == "ch14_margin":
		GameState.set_flag("ch14_margin_done")
	elif map_id == "ch14_cohold":
		GameState.set_flag("ch14_cohold_done")
	elif map_id == "ch15_finale":
		GameState.set_flag("ch15_finale_done")
	elif map_id == "ch_heir_clash":
		GameState.set_flag("ch_heir_clash_done")
		_restore_heir_clash_hp()  # heir_clash_restore
	elif map_id == "ch16_sea":
		GameState.set_flag("ch16_sea_done")
	elif map_id == "ch16_grass":
		GameState.set_flag("ch16_grass_done")
	elif map_id == "ch16_beacon":
		GameState.set_flag("ch16_beacon_done")
	elif map_id == "ch17_ford":
		GameState.set_flag("ch17_ford_done")
	elif map_id == "ch17_keep":
		GameState.set_flag("ch17_keep_done")
	elif map_id == "ch18_gate":
		GameState.set_flag("ch18_gate_done")
	elif map_id == "ch19_shore":
		GameState.set_flag("ch19_shore_done")
	elif map_id == "ch19_reef":
		GameState.set_flag("ch19_reef_done")
	elif map_id == "ch19_isle":
		GameState.set_flag("ch19_isle_done")
	elif map_id == "ch20_wall":
		GameState.set_flag("ch20_wall_done")
	elif map_id == "ch20_spire":
		GameState.set_flag("ch20_spire_done")
	elif map_id == "ch21_finale":
		GameState.set_flag("ch21_finale_done")
	elif map_id == "ch22_pass":
		GameState.set_flag("ch22_pass_done")
	elif map_id == "ch22_camp":
		GameState.set_flag("ch22_camp_done")
	elif map_id == "ch23_frost":
		GameState.set_flag("ch23_frost_done")
	elif map_id == "ch23_watch":
		GameState.set_flag("ch23_watch_done")
	elif map_id == "ch24_seal":
		GameState.set_flag("ch24_seal_done")
	elif map_id == "ch25_plain":
		GameState.set_flag("ch25_plain_done")
	elif map_id == "ch25_ridge":
		GameState.set_flag("ch25_ridge_done")
	elif map_id == "ch26_snow":
		GameState.set_flag("ch26_snow_done")
	elif map_id == "ch26_peak":
		GameState.set_flag("ch26_peak_done")
	elif map_id == "ch27_finale":
		GameState.set_flag("ch27_finale_done")
	elif map_id == "ch28_marsh":
		GameState.set_flag("ch28_marsh_done")
	elif map_id == "ch28_ferry":
		GameState.set_flag("ch28_ferry_done")
	elif map_id == "ch29_field":
		GameState.set_flag("ch29_field_done")
	elif map_id == "ch29_barn":
		GameState.set_flag("ch29_barn_done")
	elif map_id == "ch30_seal":
		GameState.set_flag("ch30_seal_done")
	elif map_id == "ch31_gorge":
		GameState.set_flag("ch31_gorge_done")
	elif map_id == "ch31_forge":
		GameState.set_flag("ch31_forge_done")
	elif map_id == "ch32_star":
		GameState.set_flag("ch32_star_done")
	elif map_id == "ch32_tower":
		GameState.set_flag("ch32_tower_done")
	elif map_id == "ch33_finale":
		GameState.set_flag("ch33_finale_done")
	elif map_id == "ch34_dawn":
		GameState.set_flag("ch34_dawn_done")
	elif map_id == "ch34_cross":
		GameState.set_flag("ch34_cross_done")
	elif map_id == "ch35_bell":
		GameState.set_flag("ch35_bell_done")
	elif map_id == "ch35_keep":
		GameState.set_flag("ch35_keep_done")
	elif map_id == "ch36_seal":
		GameState.set_flag("ch36_seal_done")
	elif map_id == "ch37_plain":
		GameState.set_flag("ch37_plain_done")
	elif map_id == "ch37_ridge":
		GameState.set_flag("ch37_ridge_done")
	elif map_id == "ch38_gate":
		GameState.set_flag("ch38_gate_done")
	elif map_id == "ch38_hall":
		GameState.set_flag("ch38_hall_done")
	elif map_id == "ch39_finale":
		GameState.set_flag("ch39_finale_done")
	elif map_id == "ch40_mist":
		GameState.set_flag("ch40_mist_done")
	elif map_id == "ch40_ford":
		GameState.set_flag("ch40_ford_done")
	elif map_id == "ch41_cairn":
		GameState.set_flag("ch41_cairn_done")
	elif map_id == "ch41_vault":
		GameState.set_flag("ch41_vault_done")
	elif map_id == "ch42_seal":
		GameState.set_flag("ch42_seal_done")
	elif map_id == "ch43_tide":
		GameState.set_flag("ch43_tide_done")
	elif map_id == "ch43_reef":
		GameState.set_flag("ch43_reef_done")
	elif map_id == "ch44_tower":
		GameState.set_flag("ch44_tower_done")
	elif map_id == "ch44_spire":
		GameState.set_flag("ch44_spire_done")
	elif map_id == "ch45_finale":
		GameState.set_flag("ch45_finale_done")
	elif map_id == "ch46_ember":
		GameState.set_flag("ch46_ember_done")
	elif map_id == "ch46_ash":
		GameState.set_flag("ch46_ash_done")
	elif map_id == "ch47_crown":
		GameState.set_flag("ch47_crown_done")
	elif map_id == "ch47_hearth":
		GameState.set_flag("ch47_hearth_done")
	elif map_id == "ch48_seal":
		GameState.set_flag("ch48_seal_done")
	elif map_id == "ch49_cinder":
		GameState.set_flag("ch49_cinder_done")
	elif map_id == "ch49_kiln":
		GameState.set_flag("ch49_kiln_done")
	elif map_id == "ch50_gate":
		GameState.set_flag("ch50_gate_done")
	elif map_id == "ch50_hall":
		GameState.set_flag("ch50_hall_done")
	elif map_id == "ch51_finale":
		GameState.set_flag("ch51_finale_done")
	elif map_id == "ch52_dawn":
		GameState.set_flag("ch52_dawn_done")
	elif map_id == "ch52_bridge":
		GameState.set_flag("ch52_bridge_done")
	elif map_id == "ch53_mirror":
		GameState.set_flag("ch53_mirror_done")
	elif map_id == "ch53_isle":
		GameState.set_flag("ch53_isle_done")
	elif map_id == "ch54_seal":
		GameState.set_flag("ch54_seal_done")
	elif map_id == "ch55_gale":
		GameState.set_flag("ch55_gale_done")
	elif map_id == "ch55_pass":
		GameState.set_flag("ch55_pass_done")
	elif map_id == "ch56_court":
		GameState.set_flag("ch56_court_done")
	elif map_id == "ch56_throne":
		GameState.set_flag("ch56_throne_done")
	elif map_id == "ch57_finale":
		GameState.set_flag("ch57_finale_done")
	elif map_id == "ch58_ember":
		GameState.set_flag("ch58_ember_done")
	elif map_id == "ch58_tide":
		GameState.set_flag("ch58_tide_done")
	elif map_id == "ch59_frost":
		GameState.set_flag("ch59_frost_done")
	elif map_id == "ch59_night":
		GameState.set_flag("ch59_night_done")
	elif map_id == "ch60_seal":
		GameState.set_flag("ch60_seal_done")
	elif map_id == "ch61_ash":
		GameState.set_flag("ch61_ash_done")
	elif map_id == "ch61_banner":
		GameState.set_flag("ch61_banner_done")
	elif map_id == "ch62_court":
		GameState.set_flag("ch62_court_done")
	elif map_id == "ch62_throne":
		GameState.set_flag("ch62_throne_done")
	elif map_id == "ch63_finale":
		GameState.set_flag("ch63_finale_done")
	elif map_id == "ch64_canal":
		GameState.set_flag("ch64_canal_done")
	elif map_id == "ch64_bazaar":
		GameState.set_flag("ch64_bazaar_done")
	elif map_id == "ch65_bell":
		GameState.set_flag("ch65_bell_done")
	elif map_id == "ch65_mute":
		GameState.set_flag("ch65_mute_done")
	elif map_id == "ch66_wellseal":
		GameState.set_flag("ch66_wellseal_done")
	elif map_id == "ch67_salt":
		GameState.set_flag("ch67_salt_done")
	elif map_id == "ch67_wharf":
		GameState.set_flag("ch67_wharf_done")
	elif map_id == "ch68_paper":
		GameState.set_flag("ch68_paper_done")
	elif map_id == "ch68_ink":
		GameState.set_flag("ch68_ink_done")
	elif map_id == "ch69_finale":
		GameState.set_flag("ch69_finale_done")
	elif map_id == "ch70_kiln":
		GameState.set_flag("ch70_kiln_done")
	elif map_id == "ch70_sagger":
		GameState.set_flag("ch70_sagger_done")
	elif map_id == "ch71_glaze":
		GameState.set_flag("ch71_glaze_done")
	elif map_id == "ch71_bisque":
		GameState.set_flag("ch71_bisque_done")
	elif map_id == "ch72_kilnseal":
		GameState.set_flag("ch72_kilnseal_done")
	elif map_id == "ch73_chimney":
		GameState.set_flag("ch73_chimney_done")
	elif map_id == "ch73_kilngod":
		GameState.set_flag("ch73_kilngod_done")
	elif map_id == "ch74_hearth":
		GameState.set_flag("ch74_hearth_done")
	elif map_id == "ch74_cool":
		GameState.set_flag("ch74_cool_done")
	elif map_id == "ch75_finale":
		GameState.set_flag("ch75_finale_done")
	elif map_id == "ch76_stage":
		GameState.set_flag("ch76_stage_done")
	elif map_id == "ch76_gallery":
		GameState.set_flag("ch76_gallery_done")
	elif map_id == "ch77_check":
		GameState.set_flag("ch77_check_done")
	elif map_id == "ch77_drum":
		GameState.set_flag("ch77_drum_done")
	elif map_id == "ch78_playseal":
		GameState.set_flag("ch78_playseal_done")
	elif map_id == "ch79_backstage":
		GameState.set_flag("ch79_backstage_done")
	elif map_id == "ch79_mirror":
		GameState.set_flag("ch79_mirror_done")
	elif map_id == "ch80_lamps":
		GameState.set_flag("ch80_lamps_done")
	elif map_id == "ch80_curtain":
		GameState.set_flag("ch80_curtain_done")
	elif map_id == "ch81_finale":
		GameState.set_flag("ch81_finale_done")
	elif map_id == "ch82_mulberry":
		GameState.set_flag("ch82_mulberry_done")
	elif map_id == "ch82_cocoon":
		GameState.set_flag("ch82_cocoon_done")
	elif map_id == "ch83_reel":
		GameState.set_flag("ch83_reel_done")
	elif map_id == "ch83_loom":
		GameState.set_flag("ch83_loom_done")
	elif map_id == "ch84_silkseal":
		GameState.set_flag("ch84_silkseal_done")
	elif map_id == "ch85_bake":
		GameState.set_flag("ch85_bake_done")
	elif map_id == "ch85_dye":
		GameState.set_flag("ch85_dye_done")
	elif map_id == "ch86_warp":
		GameState.set_flag("ch86_warp_done")
	elif map_id == "ch86_bolt":
		GameState.set_flag("ch86_bolt_done")
	elif map_id == "ch87_finale":
		GameState.set_flag("ch87_finale_done")
	elif map_id == "ch88_terrace":
		GameState.set_flag("ch88_terrace_done")
	elif map_id == "ch88_heap":
		GameState.set_flag("ch88_heap_done")
	elif map_id == "ch89_steam":
		GameState.set_flag("ch89_steam_done")
	elif map_id == "ch89_roast":
		GameState.set_flag("ch89_roast_done")
	elif map_id == "ch90_teaseal":
		GameState.set_flag("ch90_teaseal_done")
	elif map_id == "ch91_wither":
		GameState.set_flag("ch91_wither_done")
	elif map_id == "ch91_scent":
		GameState.set_flag("ch91_scent_done")
	elif map_id == "ch92_permit":
		GameState.set_flag("ch92_permit_done")
	elif map_id == "ch92_post":
		GameState.set_flag("ch92_post_done")
	elif map_id == "ch93_finale":
		GameState.set_flag("ch93_finale_done")
	elif map_id == "ch94_herb":
		GameState.set_flag("ch94_herb_done")
	elif map_id == "ch94_mortar":
		GameState.set_flag("ch94_mortar_done")
	elif map_id == "ch95_clinic":
		GameState.set_flag("ch95_clinic_done")
	elif map_id == "ch95_store":
		GameState.set_flag("ch95_store_done")
	elif map_id == "ch96_dose":
		GameState.set_flag("ch96_dose_done")
	elif map_id == "ch97_decoct":
		GameState.set_flag("ch97_decoct_done")
	elif map_id == "ch97_point":
		GameState.set_flag("ch97_point_done")
	elif map_id == "ch98_canon":
		GameState.set_flag("ch98_canon_done")
	elif map_id == "ch98_gourd":
		GameState.set_flag("ch98_gourd_done")
	elif map_id == "ch99_finale":
		GameState.set_flag("ch99_finale_done")
	elif map_id == "ch100_stable":
		GameState.set_flag("ch100_stable_done")
	elif map_id == "ch100_hoof":
		GameState.set_flag("ch100_hoof_done")
	elif map_id == "ch101_ring":
		GameState.set_flag("ch101_ring_done")
	elif map_id == "ch101_bit":
		GameState.set_flag("ch101_bit_done")
	elif map_id == "ch102_brand":
		GameState.set_flag("ch102_brand_done")
	elif map_id == "ch103_market":
		GameState.set_flag("ch103_market_done")
	elif map_id == "ch103_rein":
		GameState.set_flag("ch103_rein_done")
	elif map_id == "ch104_saddle":
		GameState.set_flag("ch104_saddle_done")
	elif map_id == "ch104_gallop":
		GameState.set_flag("ch104_gallop_done")
	elif map_id == "ch105_finale":
		GameState.set_flag("ch105_finale_done")
	elif map_id == "ch106_qu":
		GameState.set_flag("ch106_qu_done")
	elif map_id == "ch106_cellar":
		GameState.set_flag("ch106_cellar_done")
	elif map_id == "ch107_mash":
		GameState.set_flag("ch107_mash_done")
	elif map_id == "ch107_banner":
		GameState.set_flag("ch107_banner_done")
	elif map_id == "ch108_seal":
		GameState.set_flag("ch108_seal_done")
	elif map_id == "ch109_brew":
		GameState.set_flag("ch109_brew_done")
	elif map_id == "ch109_vat":
		GameState.set_flag("ch109_vat_done")
	elif map_id == "ch110_tap":
		GameState.set_flag("ch110_tap_done")
	elif map_id == "ch110_toast":
		GameState.set_flag("ch110_toast_done")
	elif map_id == "ch111_finale":
		GameState.set_flag("ch111_finale_done")
	elif map_id == "ch112_yard":
		GameState.set_flag("ch112_yard_done")
	elif map_id == "ch112_road":
		GameState.set_flag("ch112_road_done")
	elif map_id == "ch113_camp":
		GameState.set_flag("ch113_camp_done")
	elif map_id == "ch113_pass":
		GameState.set_flag("ch113_pass_done")
	elif map_id == "ch114_seal":
		GameState.set_flag("ch114_seal_done")
	elif map_id == "ch115_convoy":
		GameState.set_flag("ch115_convoy_done")
	elif map_id == "ch115_ambush":
		GameState.set_flag("ch115_ambush_done")
	elif map_id == "ch116_way":
		GameState.set_flag("ch116_way_done")
	elif map_id == "ch116_escort":
		GameState.set_flag("ch116_escort_done")
	elif map_id == "ch117_finale":
		GameState.set_flag("ch117_finale_done")
	elif map_id == "ch118_pier":
		GameState.set_flag("ch118_pier_done")
	elif map_id == "ch118_net":
		GameState.set_flag("ch118_net_done")
	elif map_id == "ch119_tide":
		GameState.set_flag("ch119_tide_done")
	elif map_id == "ch119_reef":
		GameState.set_flag("ch119_reef_done")
	elif map_id == "ch120_seal":
		GameState.set_flag("ch120_seal_done")
	elif map_id == "ch121_fishmarket":
		GameState.set_flag("ch121_fishmarket_done")
	elif map_id == "ch121_cable":
		GameState.set_flag("ch121_cable_done")
	elif map_id == "ch122_wharf":
		GameState.set_flag("ch122_wharf_done")
	elif map_id == "ch122_beacon":
		GameState.set_flag("ch122_beacon_done")
	elif map_id == "ch123_finale":
		GameState.set_flag("ch123_finale_done")
	elif map_id == "ch124_mill":
		GameState.set_flag("ch124_mill_done")
	elif map_id == "ch124_pulp":
		GameState.set_flag("ch124_pulp_done")
	elif map_id == "ch125_screen":
		GameState.set_flag("ch125_screen_done")
	elif map_id == "ch125_dry":
		GameState.set_flag("ch125_dry_done")
	elif map_id == "ch126_seal":
		GameState.set_flag("ch126_seal_done")
	elif map_id == "ch127_press":
		GameState.set_flag("ch127_press_done")
	elif map_id == "ch127_ink":
		GameState.set_flag("ch127_ink_done")
	elif map_id == "ch128_archive":
		GameState.set_flag("ch128_archive_done")
	elif map_id == "ch128_edict":
		GameState.set_flag("ch128_edict_done")
	elif map_id == "ch129_finale":
		GameState.set_flag("ch129_finale_done")
	elif map_id == "ch130_forge":
		GameState.set_flag("ch130_forge_done")
	elif map_id == "ch130_ore":
		GameState.set_flag("ch130_ore_done")
	elif map_id == "ch131_anvil":
		GameState.set_flag("ch131_anvil_done")
	elif map_id == "ch131_mold":
		GameState.set_flag("ch131_mold_done")
	elif map_id == "ch132_seal":
		GameState.set_flag("ch132_seal_done")
	elif map_id == "ch133_copmarket":
		GameState.set_flag("ch133_copmarket_done")
	elif map_id == "ch133_slag":
		GameState.set_flag("ch133_slag_done")
	elif map_id == "ch134_armory":
		GameState.set_flag("ch134_armory_done")
	elif map_id == "ch134_plate":
		GameState.set_flag("ch134_plate_done")
	elif map_id == "ch135_finale":
		GameState.set_flag("ch135_finale_done")
	elif map_id == "ch136_street":
		GameState.set_flag("ch136_street_done")
	elif map_id == "ch136_wick":
		GameState.set_flag("ch136_wick_done")
	elif map_id == "ch137_booth":
		GameState.set_flag("ch137_booth_done")
	elif map_id == "ch137_oil":
		GameState.set_flag("ch137_oil_done")
	elif map_id == "ch138_seal":
		GameState.set_flag("ch138_seal_done")
	elif map_id == "ch139_fair":
		GameState.set_flag("ch139_fair_done")
	elif map_id == "ch139_oilroad":
		GameState.set_flag("ch139_oilroad_done")
	elif map_id == "ch140_tower":
		GameState.set_flag("ch140_tower_done")
	elif map_id == "ch140_vigil":
		GameState.set_flag("ch140_vigil_done")
	elif map_id == "ch141_finale":
		GameState.set_flag("ch141_finale_done")
	elif map_id == "ch142_silo":
		GameState.set_flag("ch142_silo_done")
	elif map_id == "ch142_mill":
		GameState.set_flag("ch142_mill_done")
	elif map_id == "ch143_barn":
		GameState.set_flag("ch143_barn_done")
	elif map_id == "ch143_scale":
		GameState.set_flag("ch143_scale_done")
	elif map_id == "ch144_seal":
		GameState.set_flag("ch144_seal_done")
	elif map_id == "ch145_open":
		GameState.set_flag("ch145_open_done")
	elif map_id == "ch145_canal":
		GameState.set_flag("ch145_canal_done")
	elif map_id == "ch146_charity":
		GameState.set_flag("ch146_charity_done")
	elif map_id == "ch146_guard":
		GameState.set_flag("ch146_guard_done")
	elif map_id == "ch147_finale":
		GameState.set_flag("ch147_finale_done")
	elif map_id == "ch148_lodge":
		GameState.set_flag("ch148_lodge_done")
	elif map_id == "ch148_trail":
		GameState.set_flag("ch148_trail_done")
	elif map_id == "ch149_icehouse":
		GameState.set_flag("ch149_icehouse_done")
	elif map_id == "ch149_warm":
		GameState.set_flag("ch149_warm_done")
	elif map_id == "ch150_seal":
		GameState.set_flag("ch150_seal_done")
	elif map_id == "ch151_snowfair":
		GameState.set_flag("ch151_snowfair_done")
	elif map_id == "ch151_charcoal":
		GameState.set_flag("ch151_charcoal_done")
	elif map_id == "ch152_inn":
		GameState.set_flag("ch152_inn_done")
	elif map_id == "ch152_hold":
		GameState.set_flag("ch152_hold_done")
	elif map_id == "ch153_finale":
		GameState.set_flag("ch153_finale_done")
	elif map_id == "ch154_sea":
		GameState.set_flag("ch154_sea_done")
	elif map_id == "ch154_path":
		GameState.set_flag("ch154_path_done")
	elif map_id == "ch155_market":
		GameState.set_flag("ch155_market_done")
	elif map_id == "ch155_tower":
		GameState.set_flag("ch155_tower_done")
	elif map_id == "ch156_seal":
		GameState.set_flag("ch156_seal_done")
	elif map_id == "ch157_grove":
		GameState.set_flag("ch157_grove_done")
	elif map_id == "ch157_raft":
		GameState.set_flag("ch157_raft_done")
	elif map_id == "ch158_altar":
		GameState.set_flag("ch158_altar_done")
	elif map_id == "ch158_watch":
		GameState.set_flag("ch158_watch_done")
	elif map_id == "ch159_finale":
		GameState.set_flag("ch159_finale_done")
	elif map_id == "ch160_post":
		GameState.set_flag("ch160_post_done")
	elif map_id == "ch160_swap":
		GameState.set_flag("ch160_swap_done")
	elif map_id == "ch161_express":
		GameState.set_flag("ch161_express_done")
	elif map_id == "ch161_token":
		GameState.set_flag("ch161_token_done")
	elif map_id == "ch162_seal":
		GameState.set_flag("ch162_seal_done")
	elif map_id == "ch163_market":
		GameState.set_flag("ch163_market_done")
	elif map_id == "ch163_relayroad":
		GameState.set_flag("ch163_relayroad_done")
	elif map_id == "ch164_nightpost":
		GameState.set_flag("ch164_nightpost_done")
	elif map_id == "ch164_guardpost":
		GameState.set_flag("ch164_guardpost_done")
	elif map_id == "ch165_finale":
		GameState.set_flag("ch165_finale_done")
	elif map_id == "ch166_belltower":
		GameState.set_flag("ch166_belltower_done")
	elif map_id == "ch166_drum":
		GameState.set_flag("ch166_drum_done")
	elif map_id == "ch167_watchbell":
		GameState.set_flag("ch167_watchbell_done")
	elif map_id == "ch167_square":
		GameState.set_flag("ch167_square_done")
	elif map_id == "ch168_seal":
		GameState.set_flag("ch168_seal_done")
	elif map_id == "ch169_fair":
		GameState.set_flag("ch169_fair_done")
	elif map_id == "ch169_echo":
		GameState.set_flag("ch169_echo_done")
	elif map_id == "ch170_strike":
		GameState.set_flag("ch170_strike_done")
	elif map_id == "ch170_nightwatch":
		GameState.set_flag("ch170_nightwatch_done")
	elif map_id == "ch171_finale":
		GameState.set_flag("ch171_finale_done")
	elif map_id == "ch172_alley":
		GameState.set_flag("ch172_alley_done")
	elif map_id == "ch172_eaves":
		GameState.set_flag("ch172_eaves_done")
	elif map_id == "ch173_umbrella":
		GameState.set_flag("ch173_umbrella_done")
	elif map_id == "ch173_drain":
		GameState.set_flag("ch173_drain_done")
	elif map_id == "ch174_seal":
		GameState.set_flag("ch174_seal_done")
	elif map_id == "ch175_market":
		GameState.set_flag("ch175_market_done")
	elif map_id == "ch175_gutter":
		GameState.set_flag("ch175_gutter_done")
	elif map_id == "ch176_shelter":
		GameState.set_flag("ch176_shelter_done")
	elif map_id == "ch176_hold":
		GameState.set_flag("ch176_hold_done")
	elif map_id == "ch177_finale":
		GameState.set_flag("ch177_finale_done")
	elif map_id == "ch178_quarry":
		GameState.set_flag("ch178_quarry_done")
	elif map_id == "ch178_inkwell":
		GameState.set_flag("ch178_inkwell_done")
	elif map_id == "ch179_desk":
		GameState.set_flag("ch179_desk_done")
	elif map_id == "ch179_sealroom":
		GameState.set_flag("ch179_sealroom_done")
	elif map_id == "ch180_seal":
		GameState.set_flag("ch180_seal_done")
	elif map_id == "ch181_market":
		GameState.set_flag("ch181_market_done")
	elif map_id == "ch181_grind":
		GameState.set_flag("ch181_grind_done")
	elif map_id == "ch182_press":
		GameState.set_flag("ch182_press_done")
	elif map_id == "ch182_vault":
		GameState.set_flag("ch182_vault_done")
	elif map_id == "ch183_finale":
		GameState.set_flag("ch183_finale_done")
	elif map_id == "ch184_hive":
		GameState.set_flag("ch184_hive_done")
	elif map_id == "ch184_meadow":
		GameState.set_flag("ch184_meadow_done")
	elif map_id == "ch185_smoker":
		GameState.set_flag("ch185_smoker_done")
	elif map_id == "ch185_comb":
		GameState.set_flag("ch185_comb_done")
	elif map_id == "ch186_seal":
		GameState.set_flag("ch186_seal_done")
	elif map_id == "ch187_fair":
		GameState.set_flag("ch187_fair_done")
	elif map_id == "ch187_swarm":
		GameState.set_flag("ch187_swarm_done")
	elif map_id == "ch188_queen":
		GameState.set_flag("ch188_queen_done")
	elif map_id == "ch188_guard":
		GameState.set_flag("ch188_guard_done")
	elif map_id == "ch189_finale":
		GameState.set_flag("ch189_finale_done")
	elif map_id == "ch190_tower":
		GameState.set_flag("ch190_tower_done")
	elif map_id == "ch190_gallery":
		GameState.set_flag("ch190_gallery_done")
	elif map_id == "ch191_echo":
		GameState.set_flag("ch191_echo_done")
	elif map_id == "ch191_stage":
		GameState.set_flag("ch191_stage_done")
	elif map_id == "ch192_seal":
		GameState.set_flag("ch192_seal_done")
	elif map_id == "ch193_fair":
		GameState.set_flag("ch193_fair_done")
	elif map_id == "ch193_score":
		GameState.set_flag("ch193_score_done")
	elif map_id == "ch194_solo":
		GameState.set_flag("ch194_solo_done")
	elif map_id == "ch194_night":
		GameState.set_flag("ch194_night_done")
	elif map_id == "ch195_finale":
		GameState.set_flag("ch195_finale_done")
	elif map_id == "ch196_screen":
		GameState.set_flag("ch196_screen_done")
	elif map_id == "ch196_booth":
		GameState.set_flag("ch196_booth_done")
	elif map_id == "ch197_lamp":
		GameState.set_flag("ch197_lamp_done")
	elif map_id == "ch197_backstage":
		GameState.set_flag("ch197_backstage_done")
	elif map_id == "ch198_seal":
		GameState.set_flag("ch198_seal_done")
	elif map_id == "ch199_fair":
		GameState.set_flag("ch199_fair_done")
	elif map_id == "ch199_box":
		GameState.set_flag("ch199_box_done")
	elif map_id == "ch200_solo":
		GameState.set_flag("ch200_solo_done")
	elif map_id == "ch200_night":
		GameState.set_flag("ch200_night_done")
	elif map_id == "ch201_finale":
		GameState.set_flag("ch201_finale_done")
	elif map_id == "ch202_flat":
		GameState.set_flag("ch202_flat_done")
	elif map_id == "ch202_canal":
		GameState.set_flag("ch202_canal_done")
	elif map_id == "ch203_pile":
		GameState.set_flag("ch203_pile_done")
	elif map_id == "ch203_pan":
		GameState.set_flag("ch203_pan_done")
	elif map_id == "ch204_seal":
		GameState.set_flag("ch204_seal_done")
	elif map_id == "ch205_fair":
		GameState.set_flag("ch205_fair_done")
	elif map_id == "ch205_rack":
		GameState.set_flag("ch205_rack_done")
	elif map_id == "ch206_solo":
		GameState.set_flag("ch206_solo_done")
	elif map_id == "ch206_night":
		GameState.set_flag("ch206_night_done")
	elif map_id == "ch207_finale":
		GameState.set_flag("ch207_finale_done")
	elif map_id == "ch208_yard":
		GameState.set_flag("ch208_yard_done")
	elif map_id == "ch208_vat":
		GameState.set_flag("ch208_vat_done")
	elif map_id == "ch209_rack":
		GameState.set_flag("ch209_rack_done")
	elif map_id == "ch209_press":
		GameState.set_flag("ch209_press_done")
	elif map_id == "ch210_seal":
		GameState.set_flag("ch210_seal_done")
	elif map_id == "ch211_fair":
		GameState.set_flag("ch211_fair_done")
	elif map_id == "ch211_loom":
		GameState.set_flag("ch211_loom_done")
	elif map_id == "ch212_solo":
		GameState.set_flag("ch212_solo_done")
	elif map_id == "ch212_night":
		GameState.set_flag("ch212_night_done")
	elif map_id == "ch213_finale":
		GameState.set_flag("ch213_finale_done")
	elif map_id == "ch214_tower":
		GameState.set_flag("ch214_tower_done")
	elif map_id == "ch214_gallery":
		GameState.set_flag("ch214_gallery_done")
	elif map_id == "ch215_beat":
		GameState.set_flag("ch215_beat_done")
	elif map_id == "ch215_night":
		GameState.set_flag("ch215_night_done")
	elif map_id == "ch216_seal":
		GameState.set_flag("ch216_seal_done")
	elif map_id == "ch217_fair":
		GameState.set_flag("ch217_fair_done")
	elif map_id == "ch217_rack":
		GameState.set_flag("ch217_rack_done")
	elif map_id == "ch218_solo":
		GameState.set_flag("ch218_solo_done")
	elif map_id == "ch218_night":
		GameState.set_flag("ch218_night_done")
	elif map_id == "ch219_finale":
		GameState.set_flag("ch219_finale_done")
	elif map_id == "ch220_market":
		GameState.set_flag("ch220_market_done")
	elif map_id == "ch220_hall":
		GameState.set_flag("ch220_hall_done")
	elif map_id == "ch221_smoke":
		GameState.set_flag("ch221_smoke_done")
	elif map_id == "ch221_ash":
		GameState.set_flag("ch221_ash_done")
	elif map_id == "ch222_seal":
		GameState.set_flag("ch222_seal_done")
	elif map_id == "ch223_fair":
		GameState.set_flag("ch223_fair_done")
	elif map_id == "ch223_rack":
		GameState.set_flag("ch223_rack_done")
	elif map_id == "ch224_solo":
		GameState.set_flag("ch224_solo_done")
	elif map_id == "ch224_night":
		GameState.set_flag("ch224_night_done")
	elif map_id == "ch225_finale":
		GameState.set_flag("ch225_finale_done")
	elif map_id == "ch226_flat":
		GameState.set_flag("ch226_flat_done")
	elif map_id == "ch226_channel":
		GameState.set_flag("ch226_channel_done")
	elif map_id == "ch227_reef":
		GameState.set_flag("ch227_reef_done")
	elif map_id == "ch227_night":
		GameState.set_flag("ch227_night_done")
	elif map_id == "ch228_seal":
		GameState.set_flag("ch228_seal_done")
	elif map_id == "ch229_fair":
		GameState.set_flag("ch229_fair_done")
	elif map_id == "ch229_rack":
		GameState.set_flag("ch229_rack_done")
	elif map_id == "ch230_solo":
		GameState.set_flag("ch230_solo_done")
	elif map_id == "ch230_night":
		GameState.set_flag("ch230_night_done")
	elif map_id == "ch231_finale":
		GameState.set_flag("ch231_finale_done")
	elif map_id == "ch232_yard":
		GameState.set_flag("ch232_yard_done")
	elif map_id == "ch232_kiln":
		GameState.set_flag("ch232_kiln_done")
	elif map_id == "ch233_glaze":
		GameState.set_flag("ch233_glaze_done")
	elif map_id == "ch233_shelf":
		GameState.set_flag("ch233_shelf_done")
	elif map_id == "ch234_seal":
		GameState.set_flag("ch234_seal_done")
	# quest maps also count as battle_done for generic chains
	if map_id.begins_with("quest"):
		GameState.set_flag("battle_done")

func _refresh_info_for(ui: int) -> void:
	if ui < 0 or ui >= units.size():
		_refresh_info()
		return
	var u = units[ui]
	var c: CKCharacter = u.char
	_portrait.texture = UnitArt.portrait(c, 96)
	if _unit_card: _unit_card.set_unit(c, u.team)
	var _nm := str(c.name)
	if (u.team == "enemy" or c.faction == "enemy") and (_nm.find("匪首") >= 0 or _nm.find("头目") >= 0 or _nm.find("Boss") >= 0):
		if _portrait:
			UIFX.boss_threat(_portrait)
	var tid = terrain[u.pos.y][u.pos.x]
	var tinfo = BattleRules.terrain_info(tid)
	var role2 = BattleRules.role_label(BattleRules.job_role(c.job_id))
	info_label.text = "[b]%s[/b]（%s·%s） HP %d/%d\n攻 %d 防 %d\n地形：%s（回避+%d 防+%d）\n（仍选中我军，可继续移动/攻击）" % [
		c.name, "我军" if u.team == "player" else "敌军", role2,
		c.hp, c.max_hp, c.derived_atk(), c.derived_def(),
		tinfo["name"], tinfo.get("avo_bonus", 0), tinfo.get("def_bonus", 0),
	]


func _fill_info_traits(c: CKCharacter) -> void:
	if _info_traits == null:
		return
	for ch in _info_traits.get_children():
		ch.queue_free()
	if c == null:
		return
	for tr in c.traits:
		var ic = UIKit.trait_icon_rect(str(tr), 26.0)
		var td = GameState.get_trait(str(tr))
		ic.tooltip_text = str(td.get("name", tr))
		_info_traits.add_child(ic)

func _refresh_info() -> void:
	if selected < 0 or selected >= units.size():
		info_label.text = "[b]选择己方单位开始行动[/b]\n目标：歼灭全部敌人。\n蓝格可移动 · 红格为可攻目标 · 攻击模式后点敌。"
		if GameState.get_leader():
			_portrait.texture = UnitArt.portrait(GameState.get_leader(), 96)
			if _unit_card: _unit_card.set_unit(GameState.get_leader(), "player")
			_fill_info_traits(GameState.get_leader())
		else:
			_portrait.texture = UnitArt.banner(96, 96, false)
			if _unit_card: _unit_card.set_unit(null)
			_fill_info_traits(null)
		return
	var u = units[selected]
	var c: CKCharacter = u.char
	_portrait.texture = UnitArt.portrait(c, 96)
	if _unit_card: _unit_card.set_unit(c, u.team)
	_fill_info_traits(c)
	var tid = terrain[u.pos.y][u.pos.x]
	var tinfo = BattleRules.terrain_info(tid)
	var mode = ""
	if u.team == "player" and not u.done:
		if attack_mode:
			mode = "[color=#e07070]【攻击模式】点击红格敌人[/color]\n"
		elif moved_this_select:
			mode = "[color=#c9a227]【已移动】可攻击 / 待命[/color]\n"
		else:
			mode = "[color=#6db0e0]【已选中】点击蓝格移动，或开攻击模式[/color]\n"
	var role = BattleRules.role_label(BattleRules.job_role(c.job_id))
	var foes = _enemy_positions(u.team)
	var engaged = BattleRules.is_engaged(u.pos, foes)
	var locked = int(c.temp_combat_lock) > 0
	var eng = ""
	if locked:
		eng = "[color=#ff6b4a]〔交战锁定·脱离+2移·反击优先〕[/color]\n"
	elif engaged:
		eng = "[color=#e07070]〔交战中·脱离+1移〕[/color]\n"
	if c.temp_leave_free:
		eng += "[color=#8ecae6]〔抽身：脱离不耗〕[/color]\n"
	elif c.temp_ignore_zoc:
		eng += "[color=#c9a227]〔破控：无视地带〕[/color]\n"
	var txt = mode + eng + "[b]%s[/b]（%s·%s） HP %d/%d\n攻 %d 防 %d 命中 %d 回避 %d 移动 %d\n地形：%s（回避+%d 防+%d）\n" % [
		c.name, "我军" if u.team == "player" else "敌军", role,
		c.hp, c.max_hp, c.derived_atk(), c.derived_def(), c.derived_hit(), c.derived_avo(), c.derived_move(),
		tinfo["name"], tinfo["avo_bonus"], tinfo.get("def_bonus", 0),
	]
	if BattleRules.preview_enabled and u.team == "player":
		for j in units.size():
			var e = units[j]
			if e.team == "enemy" and e.char.hp > 0 and _manhattan(u.pos, e.pos) <= 2:
				var ex = {"flank": BattleRules.has_flank(u.pos, e.pos, units, "player", selected)}
				var pv = BattleRules.preview(c, e.char, terrain[e.pos.y][e.pos.x], ex)
				var tagjoin = "·".join(pv.tags) if pv.tags else ""
				txt += "透视→%s：命中 %d%% 伤害 %d–%d 暴%d%%%s\n" % [
					e.char.name, pv.hit, pv.dmg.x, pv.dmg.y, pv.crit,
					(" 〔" + tagjoin + "〕") if tagjoin else "",
				]
	info_label.text = txt

func _log(t: String) -> void:
	var lines := (t + "\n" + log_label.text).split("\n")
	log_label.text = "\n".join(lines.slice(0, mini(lines.size(), 12)))


func _restore_heir_clash_hp() -> void:
	for key in ["heir_clash_a", "heir_clash_b"]:
		var cid = str(GameState.get_meta(key, ""))
		if cid == "":
			continue
		var c: CKCharacter = GameState.characters.get(cid)
		if c:
			c.hp = c.max_hp
			c.alive = true
	GameState.add_lineage_event("双嗣校场终了：双方回堡养伤，名册旁注已更新。")
	GameState.remove_meta("heir_clash_a")
	GameState.remove_meta("heir_clash_b")
