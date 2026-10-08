class_name UnitArt
extends RefCounted
## 优先加载预绘 PNG 图集；缺失时回退程序绘制

static var _cache: Dictionary = {}
static var _banner_frame: int = 0
static var _token_phase: float = 0.0
static var _face_owner: Dictionary = {}  # slot -> character id
static var _face_assign: Dictionary = {}  # character id -> slot
const FACE_SLOTS := 768
## 农场板已 stamp 进开放寻址表；性别/角色优先尝试这些槽
const FARM_FACE_SLOTS_M := [24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 348, 349, 350, 351, 376, 377, 378, 379, 380, 381, 382, 383, 384, 385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 399, 420, 421, 422, 423, 424, 425, 426, 427, 428, 429, 430, 431, 432, 433, 434, 435, 436, 437, 438, 439, 464, 465, 466, 467, 468, 469, 470, 471, 472, 473, 474, 475, 476, 477, 478, 479, 480, 481, 482, 483, 484, 485, 486, 487, 508, 509, 510, 511, 512, 513, 514, 515, 516, 517, 518, 519, 520, 521, 522, 523, 524, 525, 526, 527, 750, 751, 753, 754, 760, 762, 764, 765, 766]
const FARM_FACE_SLOTS_F := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 312, 313, 314, 315, 316, 317, 318, 319, 320, 321, 322, 323, 324, 325, 326, 327, 328, 329, 330, 331, 352, 353, 354, 355, 356, 357, 358, 359, 360, 361, 362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375, 400, 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 415, 416, 417, 418, 419, 440, 441, 442, 443, 444, 445, 446, 447, 448, 449, 450, 451, 452, 453, 454, 455, 456, 457, 458, 459, 460, 461, 462, 463, 488, 489, 490, 491, 492, 493, 494, 495, 496, 497, 498, 499, 500, 501, 502, 503, 504, 505, 506, 507, 752, 755, 761, 763]
const FARM_FACE_BY_TAG := {
	"alchemist": [9, 33, 97, 121, 185, 209, 273, 297, 361, 385, 449, 473],
	"archer": [53, 73, 141, 161, 229, 249, 317, 337, 405, 425, 493, 513],
	"ash_priest": [23, 47, 111, 135, 199, 223, 287, 311, 375, 399, 463, 487],
	"banner": [67, 87, 155, 175, 243, 263, 331, 351, 419, 439, 507, 527],
	"bard": [10, 34, 98, 122, 186, 210, 274, 298, 362, 386, 450, 474],
	"captain": [61, 81, 149, 169, 237, 257, 325, 345, 413, 433, 501, 521],
	"cartwright": [21, 45, 109, 133, 197, 221, 285, 309, 373, 397, 461, 485],
	"cavalry": [58, 78, 146, 166, 234, 254, 322, 342, 410, 430, 498, 518],
	"child": [62, 82, 150, 170, 238, 258, 326, 346, 414, 434, 502, 522],
	"diplomat": [12, 36, 100, 124, 188, 212, 276, 300, 364, 388, 452, 476],
	"duelist": [2, 26, 90, 114, 178, 202, 266, 290, 354, 378, 442, 466],
	"elder": [57, 77, 145, 165, 233, 253, 321, 341, 409, 429, 497, 517],
	"executioner": [11, 35, 99, 123, 187, 211, 275, 299, 363, 387, 451, 475],
	"fisher": [0, 24, 88, 112, 176, 200, 264, 288, 352, 376, 440, 464],
	"glassblower": [20, 44, 108, 132, 196, 220, 284, 308, 372, 396, 460, 484],
	"guard": [51, 71, 139, 159, 227, 247, 315, 335, 403, 423, 491, 511],
	"heavy": [59, 79, 147, 167, 235, 255, 323, 343, 411, 431, 499, 519],
	"herbalist": [14, 38, 102, 126, 190, 214, 278, 302, 366, 390, 454, 478],
	"hunter": [50, 70, 138, 158, 226, 246, 314, 334, 402, 422, 490, 510],
	"iron_sergeant": [19, 43, 107, 131, 195, 219, 283, 307, 371, 395, 459, 483],
	"lantern": [22, 46, 110, 134, 198, 222, 286, 310, 374, 398, 462, 486],
	"medic": [64, 84, 152, 172, 240, 260, 328, 348, 416, 436, 504, 524],
	"merchant": [55, 75, 143, 163, 231, 251, 319, 339, 407, 427, 495, 515],
	"mid": [63, 83, 151, 171, 239, 259, 327, 347, 415, 435, 503, 523],
	"monk": [54, 74, 142, 162, 230, 250, 318, 338, 406, 426, 494, 514],
	"monk_old": [16, 40, 104, 128, 192, 216, 280, 304, 368, 392, 456, 480],
	"novice": [8, 32, 96, 120, 184, 208, 272, 296, 360, 384, 448, 472],
	"orphan": [13, 37, 101, 125, 189, 213, 277, 301, 365, 389, 453, 477],
	"outrider": [6, 30, 94, 118, 182, 206, 270, 294, 358, 382, 446, 470],
	"pirate": [15, 39, 103, 127, 191, 215, 279, 303, 367, 391, 455, 479],
	"quartermaster": [4, 28, 92, 116, 180, 204, 268, 292, 356, 380, 444, 468],
	"ranger": [1, 25, 89, 113, 177, 201, 265, 289, 353, 377, 441, 465],
	"recruit_raw": [17, 41, 105, 129, 193, 217, 281, 305, 369, 393, 457, 481],
	"sapper": [5, 29, 93, 117, 181, 205, 269, 293, 357, 381, 445, 469],
	"scholar": [56, 76, 144, 164, 232, 252, 320, 340, 408, 428, 496, 516],
	"scout": [66, 86, 154, 174, 242, 262, 330, 350, 418, 438, 506, 526],
	"skirm": [60, 80, 148, 168, 236, 256, 324, 344, 412, 432, 500, 520],
	"smith": [65, 85, 153, 173, 241, 261, 329, 349, 417, 437, 505, 525],
	"spear": [52, 72, 140, 160, 228, 248, 316, 336, 404, 424, 492, 512],
	"squire": [49, 69, 137, 157, 225, 245, 313, 333, 401, 421, 489, 509],
	"standard": [3, 27, 91, 115, 179, 203, 267, 291, 355, 379, 443, 467],
	"veteran_bow": [18, 42, 106, 130, 194, 218, 282, 306, 370, 394, 458, 482],
	"warden": [7, 31, 95, 119, 183, 207, 271, 295, 359, 383, 447, 471],
	"youth": [48, 68, 136, 156, 224, 244, 312, 332, 400, 420, 488, 508],
}


static func clear_cache() -> void:
	_cache.clear()
	# 保留脸槽指派，避免同局内跳脸；新开档可另清

static func terrain_tile(tid: String) -> Texture2D:
	var path = "res://assets/art/tiles/%s.png" % tid
	var ck = "tile|" + tid
	if _cache.has(ck):
		return _cache[ck]
	var tex = _try_load(path)
	if tex != null:
		_cache[ck] = tex
	return tex

static func draw_lock_ring(ci: CanvasItem, center: Vector2, radius: float = 22.0) -> void:
	var frame = _banner_frame % 6
	var path = "res://assets/art/fx/lock_%d.png" % frame
	var tex = _try_load(path)
	if tex != null:
		var sz = Vector2(radius * 2.4, radius * 2.4)
		ci.draw_texture_rect(tex, Rect2(center - sz * 0.5, sz), false)
	else:
		ci.draw_arc(center, radius, 0, TAU, 28, Color(1.0, 0.35, 0.28, 0.85), 2.0)

static func tick(delta: float) -> void:
	_token_phase += delta
	if _token_phase >= 0.48:
		_token_phase = 0.0
		_banner_frame = (_banner_frame + 1) % 6

static func crest_color() -> Color:
	return Color(str(GameState.crest_color))

static func _crest_hex() -> String:
	var c = str(GameState.crest_color).trim_prefix("#").to_lower()
	return c

static func hair_color(appearance: Dictionary) -> Color:
	var hid = str(appearance.get("hair", "ink_black"))
	for a in GameState.data_appearance.get("alleles", {}).get("hair", []):
		if a.get("id") == hid:
			return Color(str(a.get("color", "#1a1a1a")))
	return Color("#5c4033")

static func eye_color(appearance: Dictionary) -> Color:
	var eid = str(appearance.get("eyes", "slate"))
	for a in GameState.data_appearance.get("alleles", {}).get("eyes", []):
		if a.get("id") == eid:
			return Color(str(a.get("color", "#5a6570")))
	return Color("#5a6570")

static func _try_load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			_cache[path] = tex
			return tex
	return null

static func _cast(c) -> String:
	## v8.6: named-cast identity by stable cast_key (id-keyed), never name substrings
	return str(c.cast_key) if "cast_key" in c else ""

static func _portrait_key(c: CKCharacter) -> String:
	# v8.5: named core cast -> v8 hero / bust plates (thumb 220x270: right size for cards, no
	# minification aliasing). The old *_face_plate cartoons were pre-v8 placeholders.
	var g8 := "f" if str(c.gender) == "f" else "m"
	var v8n := ""
	if c.is_leader:
		v8n = "v8_hero_leader_%s" % g8
	elif _cast(c) == "dengying":
		v8n = "v8_bust_%s_hunter" % g8
	elif _cast(c) == "militia_a":
		v8n = "v8_bust_%s_spear" % g8
	elif _cast(c) == "militia_b":
		v8n = "v8_bust_%s_guard" % g8
	if v8n != "":
		for cand in ["res://assets/art/portraits/thumb_%s.png" % v8n, "res://assets/art/portraits/%s.png" % v8n]:
			if ResourceLoader.exists(cand):
				return cand
	# 具名角色优先 face_plate（美术升档）
	var named_plate := ""
	if c.is_leader:
		named_plate = "leader_default_face_plate"
	elif _cast(c) == "dengying":
		named_plate = "ally_dengying_face_plate"
	elif _cast(c) == "militia_a":
		named_plate = "militia_a_face_plate"
	elif _cast(c) == "militia_b":
		named_plate = "militia_b_face_plate"
	if named_plate != "":
		var pp = "res://assets/art/portraits/%s.png" % named_plate
		if ResourceLoader.exists(pp):
			return pp
	if c.is_leader:
		var p = "res://assets/art/portraits/leader_default.png"
		if ResourceLoader.exists(p):
			return p
	if _cast(c) == "dengying":
		return "res://assets/art/portraits/ally_dengying.png"
	if _cast(c) == "militia_a":
		return "res://assets/art/portraits/militia_a.png"
	if _cast(c) == "militia_b":
		return "res://assets/art/portraits/militia_b.png"
	if str(c.name).find("镖路匪首") >= 0:
		return _boss_portrait("escort")
	if str(c.name).find("港匪头目") >= 0:
		return _boss_portrait("harbor")
	if str(c.name).find("礁口伏弓") >= 0:
		return "res://assets/art/portraits/harbor_archer.png"
	if str(c.name).find("渔港水匪") >= 0:
		return "res://assets/art/portraits/harbor_thug.png"
	if str(c.name).find("瓷市匪首") >= 0:
		return _boss_portrait("porcelain")
	if str(c.name).find("窑廊伏弓") >= 0:
		return "res://assets/art/portraits/porcelain_archer.png"
	if str(c.name).find("瓷市悍匪") >= 0:
		return "res://assets/art/portraits/porcelain_thug.png"
	if str(c.name).find("潮滩匪首") >= 0:
		return _boss_portrait("tide")
	if str(c.name).find("潮渠伏弓") >= 0:
		return "res://assets/art/portraits/tide_archer.png"
	if str(c.name).find("潮滩悍匪") >= 0:
		return "res://assets/art/portraits/tide_thug.png"
	if str(c.name).find("香市匪首") >= 0:
		return _boss_portrait("incense")
	if str(c.name).find("香堂伏弓") >= 0:
		return "res://assets/art/portraits/incense_archer.png"
	if str(c.name).find("香市悍匪") >= 0:
		return "res://assets/art/portraits/incense_thug.png"
	if str(c.name).find("鼓楼匪首") >= 0:
		return _boss_portrait("drum")
	if str(c.name).find("鼓廊伏弓") >= 0:
		return "res://assets/art/portraits/drum_archer.png"
	if str(c.name).find("鼓楼悍匪") >= 0:
		return "res://assets/art/portraits/drum_thug.png"
	if str(c.name).find("染坊匪首") >= 0:
		return _boss_portrait("dye")
	if str(c.name).find("染缸伏弓") >= 0:
		return "res://assets/art/portraits/dye_archer.png"
	if str(c.name).find("染坊悍匪") >= 0:
		return "res://assets/art/portraits/dye_thug.png"
	if str(c.name).find("盐滩匪首") >= 0:
		return _boss_portrait("salt")
	if str(c.name).find("卤渠伏弓") >= 0:
		return "res://assets/art/portraits/salt_archer.png"
	if str(c.name).find("盐滩悍匪") >= 0:
		return "res://assets/art/portraits/salt_thug.png"
	if str(c.name).find("影戏匪首") >= 0:
		return _boss_portrait("shadow")
	if str(c.name).find("幕廊伏弓") >= 0:
		return "res://assets/art/portraits/shadow_archer.png"
	if str(c.name).find("影戏悍匪") >= 0:
		return "res://assets/art/portraits/shadow_thug.png"
	if str(c.name).find("笛楼匪首") >= 0:
		return _boss_portrait("flute")
	if str(c.name).find("音廊伏弓") >= 0:
		return "res://assets/art/portraits/flute_archer.png"
	if str(c.name).find("笛楼悍匪") >= 0:
		return "res://assets/art/portraits/flute_thug.png"
	if str(c.name).find("蜂场匪首") >= 0:
		return _boss_portrait("hive")
	if str(c.name).find("花陌伏弓") >= 0:
		return "res://assets/art/portraits/hive_archer.png"
	if str(c.name).find("蜂场悍匪") >= 0:
		return "res://assets/art/portraits/hive_thug.png"
	if str(c.name).find("砚坑匪首") >= 0:
		return _boss_portrait("ink")
	if str(c.name).find("墨池伏弓") >= 0:
		return "res://assets/art/portraits/ink_archer.png"
	if str(c.name).find("砚坑悍匪") >= 0:
		return "res://assets/art/portraits/ink_thug.png"
	if str(c.name).find("雨巷匪首") >= 0:
		return _boss_portrait("rain")
	if str(c.name).find("檐廊伏弓") >= 0:
		return "res://assets/art/portraits/rain_archer.png"
	if str(c.name).find("雨巷悍匪") >= 0:
		return "res://assets/art/portraits/rain_thug.png"
	if str(c.name).find("钟楼匪首") >= 0:
		return _boss_portrait("bell")
	if str(c.name).find("鼓廊伏弓") >= 0:
		return "res://assets/art/portraits/bell_archer.png"
	if str(c.name).find("钟楼悍匪") >= 0:
		return "res://assets/art/portraits/bell_thug.png"
	if str(c.name).find("驿道匪首") >= 0:
		return _boss_portrait("relay")
	if str(c.name).find("递路伏弓") >= 0:
		return "res://assets/art/portraits/relay_archer.png"
	if str(c.name).find("驿道悍匪") >= 0:
		return "res://assets/art/portraits/relay_thug.png"
	if str(c.name).find("竹海匪首") >= 0:
		return _boss_portrait("bamboo")
	if str(c.name).find("篁廊伏弓") >= 0:
		return "res://assets/art/portraits/bamboo_archer.png"
	if str(c.name).find("竹海悍匪") >= 0:
		return "res://assets/art/portraits/bamboo_thug.png"
	if str(c.name).find("雪栈匪首") >= 0:
		return _boss_portrait("snow")
	if str(c.name).find("冰廊伏弓") >= 0:
		return "res://assets/art/portraits/snow_archer.png"
	if str(c.name).find("雪栈悍匪") >= 0:
		return "res://assets/art/portraits/snow_thug.png"
	if str(c.name).find("粮仓匪首") >= 0:
		return _boss_portrait("grain")
	if str(c.name).find("碾坊伏弓") >= 0:
		return "res://assets/art/portraits/grain_archer.png"
	if str(c.name).find("粮仓悍匪") >= 0:
		return "res://assets/art/portraits/grain_thug.png"
	if str(c.name).find("灯市匪首") >= 0:
		return _boss_portrait("lamp")
	if str(c.name).find("油库伏弓") >= 0:
		return "res://assets/art/portraits/lamp_archer.png"
	if str(c.name).find("灯市毛贼") >= 0:
		return "res://assets/art/portraits/lamp_thug.png"
	if str(c.name).find("铜市匪首") >= 0:
		return _boss_portrait("copper")
	if str(c.name).find("矿道伏弓") >= 0:
		return "res://assets/art/portraits/copper_archer.png"
	if str(c.name).find("铜市悍匪") >= 0:
		return "res://assets/art/portraits/copper_thug.png"
	if str(c.name).find("纸坊匪首") >= 0:
		return _boss_portrait("paper")
	if str(c.name).find("浆槽伏弓") >= 0:
		return "res://assets/art/portraits/paper_archer.png"
	if str(c.name).find("纸坊毛贼") >= 0:
		return "res://assets/art/portraits/paper_thief.png"
	if str(c.name).find("关口伏弓") >= 0:
		return "res://assets/art/portraits/escort_archer.png"
	if str(c.name).find("劫镖") >= 0 or str(c.name).find("劫道") >= 0:
		return "res://assets/art/portraits/escort_raider.png"
	if c.faction == "enemy" or str(c.name).find("匪") >= 0:
		return "res://assets/art/portraits/bandit.png"
	var hair = str(c.appearance.get("hair", "ash_brown"))
	var eyes = str(c.appearance.get("eyes", "slate"))
	var g = str(c.gender)
	var job = str(c.job_id)
	# map tier2 jobs to base atlas keys
	var job_map = {"warrior":"heavy_inf","archer":"hunter","priest":"apprentice","light_cavalry":"squire"}
	if job_map.has(job):
		job = job_map[job]
	return "res://assets/art/portraits/%s_%s_%s_%s.png" % [hair, eyes, g, job]

static var _cartoon_re: RegEx = null

static func _is_cartoon_key(path: String) -> bool:
	var f := path.get_file()
	if f.begins_with("thumb_v8_") or f.begins_with("v8_") or f.begins_with("v84_") or path.find("qwen_v830") >= 0:
		return false
	if _cartoon_re == null:
		_cartoon_re = RegEx.create_from_string("_(f|m)_(hunter|heavy_inf|light_inf|archer|priest|apprentice|squire|warrior|light_cavalry)\\.png$")
	if _cartoon_re.search(f) != null:
		return true
	if f.begins_with("hire_") and f.ends_with("_plate.png"):
		return true
	if f.ends_with("_face_plate.png") or f in ["tank_plate.png", "ranger_plate.png", "mage_plate.png", "leader_plate.png", "skirm_plate.png", "leader_default.png"]:
		return true
	return false

static func _v83_elite_for(path: String) -> String:
	## v8.5: enemy portraits (bandit / {theme}_{thug,archer} / {theme}_boss[_face_plate]) are pre-v8
	## procedural cartoons -> v8.3 dedicated elite plates (coral silhouettes) until enemy busts are farmed.
	var f := path.get_file().get_basename()
	var key := ""
	if f == "bandit":
		key = "bandit_captain"
	elif f.ends_with("_boss_face_plate"):
		key = f.trim_suffix("_face_plate")
	elif f.ends_with("_boss") or f.ends_with("_thug") or f.ends_with("_archer") or f.ends_with("_raider") or f.ends_with("_thief"):
		key = f
	if key == "":
		return ""
	var ep := "res://assets/art/farm_inbox/qwen_v830/v83_elite_%s.png" % key
	return ep if ResourceLoader.exists(ep) else ""

## "genome" when a farmed unit_id plate exists; otherwise the legacy named / hireuniq / bust chain.
static func portrait_kind(c: CKCharacter, size: int = 96) -> String:
	if CKGenomePortrait.texture(c) != null:
		return "genome"
	var path := _portrait_key(c)
	var elite := _v83_elite_for(path)
	if elite != "":
		path = elite
	if not _is_cartoon_key(path) and ResourceLoader.exists(path):
		return "named"
	var uid := _face_uid(c)
	if ResourceLoader.exists("res://assets/art/portraits/hireuniq_%03d.png" % uid):
		return "hireuniq"
	var g := "f" if str(c.gender) == "f" else "m"
	var role := "skirmisher"
	if Engine.get_main_loop():
		role = BattleRules.job_role(c.job_id)
	var v8b: String = str({"skirmisher": "spear", "tank": "guard", "ranger": "archer", "mage": "scholar", "cavalry": "cavalry", "healer": "medic", "support": "medic"}.get(role, "duelist"))
	if ResourceLoader.exists("res://assets/art/portraits/thumb_v8_bust_%s_%s.png" % [g, v8b]):
		return "bust"
	var age := int(c.age)
	var geno := ""
	if age <= 22:
		geno = "v84_geno_youth_%s_vow" % g
	elif age >= 50:
		geno = "v84_geno_elder_%s_seal" % g
	elif c.is_leader or str(c.job_id) in ["squire", "light_cavalry"]:
		geno = "v84_geno_heir_%s_close" % g
	else:
		geno = "v84_geno_mid_%s_house" % g
	var gp := "res://assets/art/portraits/%s.png" % geno
	if size <= 240 and ResourceLoader.exists("res://assets/art/portraits/thumb_%s.png" % geno):
		gp = "res://assets/art/portraits/thumb_%s.png" % geno
	if ResourceLoader.exists(gp):
		return "geno"
	return "proc"

static func portrait(c: CKCharacter, size: int = 96) -> Texture2D:
	# v8.9: paper-doll is retired. One Qwen plate per unit_id when the farm has ingested it.
	# Checked before the legacy cache so a late ingest still wins. Missing plates fall through
	# to named cast art, then hireuniq, then the bust/geno chain.
	var gtex: Texture2D = CKGenomePortrait.texture(c)
	if gtex != null:
		return gtex
	var path = _portrait_key(c)
	var _elite := _v83_elite_for(path)
	if _elite != "":
		path = _elite
	var ck = "p|" + path + "|" + str(c.id)
	if _cache.has(ck):
		return _cache[ck]
	# v8.5: pre-v8 cartoon keys (allele-combo plates, hire_/role plates, old *_face_plate) must not
	# shadow the 781 farmed hireuniq faces — renders showed every recruit/candidate as a cartoon.
	var tex2 = null if _is_cartoon_key(path) else _try_load(path)
	if tex2 != null:
		_cache[ck] = tex2
		return tex2
	# 个人脸优先：hireuniq 为手绘感唯一底，再轻染等位色
	var uid = _face_uid(c)
	var uniq_p = "res://assets/art/portraits/hireuniq_%03d.png" % uid
	var utex = _try_load(uniq_p)
	if utex != null:
		return _fingerprint_portrait(utex, c)
	# 回退：等位组合板
	var g = "f" if str(c.gender) == "f" else "m"
	var hair = str(c.appearance.get("hair", "ash_brown"))
	var eyes = str(c.appearance.get("eyes", "slate"))
	var scar = str(c.appearance.get("scar", "none"))
	var brow = str(c.appearance.get("brow", "straight"))
	if scar == "":
		scar = "none"
	if brow == "":
		brow = "straight"
	var face_p = "res://assets/art/portraits/hireface_%s_%s_%s_%s_%s.png" % [hair, eyes, g, scar, brow]
	var ft = null  # v8.5: hireface_* are cartoon allele plates — skipped
	if ft != null:
		return _fingerprint_portrait(ft, c)
	# 雇佣/花名册：角色×性别板（回退）
	var role = BattleRules.job_role(c.job_id) if Engine.get_main_loop() else "skirmisher"
	var hire_p = "res://assets/art/portraits/hire_%s_%s_plate.png" % [role, g]
	var ht = null  # v8.5: hire_*_plate cartoon — skipped
	# v8.5: role-matched v8 bust before geno/procedural
	var v8b = {"skirmisher": "spear", "tank": "guard", "ranger": "archer", "mage": "scholar", "cavalry": "cavalry", "healer": "medic", "support": "medic"}.get(role, "duelist")
	var v8bp = "res://assets/art/portraits/thumb_v8_bust_%s_%s.png" % [g, v8b]
	var v8bt = _try_load(v8bp)
	if v8bt != null:
		return _fingerprint_portrait(v8bt, c)
	if ht != null:
		_cache["hire|" + role + "|" + g + "|" + str(size)] = ht
		return ht
	# 兵种板绘（回退）
	var plate = {
		"heavy_inf": "tank_plate", "warrior": "tank_plate",
		"hunter": "ranger_plate", "archer": "ranger_plate",
		"apprentice": "mage_plate", "priest": "mage_plate",
		"squire": "leader_plate", "light_cavalry": "leader_plate",
		"light_inf": "skirm_plate",
	}.get(c.job_id, "")
	if c.is_leader:
		plate = "leader_plate"
	if plate != "":
		var pp = "res://assets/art/portraits/%s.png" % plate
		var pt = null  # v8.5: role plates are cartoon — skipped
		if pt != null:
			_cache["plate|" + plate + "|" + str(size)] = pt
			return pt
	# v8.4 genealogy / vow busts by age+gender
	var _g := str(c.gender)
	var _age := int(c.age)
	var _geno := ""
	if _age <= 22:
		_geno = "v84_geno_youth_%s_vow" % _g
	elif _age >= 50:
		_geno = "v84_geno_elder_%s_seal" % _g
	elif c.is_leader or str(c.job_id) in ["squire", "light_cavalry"]:
		_geno = "v84_geno_heir_%s_close" % _g
	else:
		_geno = "v84_geno_mid_%s_house" % _g
	var _gp := "res://assets/art/portraits/%s.png" % _geno
	# v8.5: card/list sizes use the pre-downscaled 220x270 thumb (crisper, lighter)
	var _thumb := "res://assets/art/portraits/thumb_%s.png" % _geno
	if size <= 240 and ResourceLoader.exists(_thumb):
		_gp = _thumb
	if ResourceLoader.exists(_gp):
		var _gt = _try_load(_gp)
		if _gt != null:
			_cache["geno|" + _geno + "|" + str(size)] = _gt
			return _gt
	return _proc_portrait(c, size)

static func _token_key(c: CKCharacter, team: String, frame: int) -> String:
	if c.is_leader:
		return "res://assets/art/tokens/leader_default_%s_f%d.png" % [team, frame]
	if _cast(c) == "dengying":
		return "res://assets/art/tokens/ally_dengying_%s_f%d.png" % [team, frame]
	if _cast(c) == "militia_a":
		return "res://assets/art/tokens/militia_a_%s_f%d.png" % [team, frame]
	if _cast(c) == "militia_b":
		return "res://assets/art/tokens/militia_b_%s_f%d.png" % [team, frame]
	if str(c.name).find("镖路匪首") >= 0:
		return "res://assets/art/tokens/escort_boss_enemy_f%d.png" % frame
	if str(c.name).find("港匪头目") >= 0:
		return "res://assets/art/tokens/harbor_boss_enemy_f%d.png" % frame
	if str(c.name).find("礁口伏弓") >= 0:
		return "res://assets/art/tokens/harbor_archer_enemy_f%d.png" % frame
	if str(c.name).find("渔港水匪") >= 0:
		return "res://assets/art/tokens/harbor_thug_enemy_f%d.png" % frame
	if str(c.name).find("瓷市匪首") >= 0:
		return "res://assets/art/tokens/porcelain_boss_enemy_f%d.png" % frame
	if str(c.name).find("窑廊伏弓") >= 0:
		return "res://assets/art/tokens/porcelain_archer_enemy_f%d.png" % frame
	if str(c.name).find("瓷市悍匪") >= 0:
		return "res://assets/art/tokens/porcelain_thug_enemy_f%d.png" % frame
	if str(c.name).find("潮滩匪首") >= 0:
		return "res://assets/art/tokens/tide_boss_enemy_f%d.png" % frame
	if str(c.name).find("潮渠伏弓") >= 0:
		return "res://assets/art/tokens/tide_archer_enemy_f%d.png" % frame
	if str(c.name).find("潮滩悍匪") >= 0:
		return "res://assets/art/tokens/tide_thug_enemy_f%d.png" % frame
	if str(c.name).find("香市匪首") >= 0:
		return "res://assets/art/tokens/incense_boss_enemy_f%d.png" % frame
	if str(c.name).find("香堂伏弓") >= 0:
		return "res://assets/art/tokens/incense_archer_enemy_f%d.png" % frame
	if str(c.name).find("香市悍匪") >= 0:
		return "res://assets/art/tokens/incense_thug_enemy_f%d.png" % frame
	if str(c.name).find("鼓楼匪首") >= 0:
		return "res://assets/art/tokens/drum_boss_enemy_f%d.png" % frame
	if str(c.name).find("鼓廊伏弓") >= 0:
		return "res://assets/art/tokens/drum_archer_enemy_f%d.png" % frame
	if str(c.name).find("鼓楼悍匪") >= 0:
		return "res://assets/art/tokens/drum_thug_enemy_f%d.png" % frame
	if str(c.name).find("染坊匪首") >= 0:
		return "res://assets/art/tokens/dye_boss_enemy_f%d.png" % frame
	if str(c.name).find("染缸伏弓") >= 0:
		return "res://assets/art/tokens/dye_archer_enemy_f%d.png" % frame
	if str(c.name).find("染坊悍匪") >= 0:
		return "res://assets/art/tokens/dye_thug_enemy_f%d.png" % frame
	if str(c.name).find("盐滩匪首") >= 0:
		return "res://assets/art/tokens/salt_boss_enemy_f%d.png" % frame
	if str(c.name).find("卤渠伏弓") >= 0:
		return "res://assets/art/tokens/salt_archer_enemy_f%d.png" % frame
	if str(c.name).find("盐滩悍匪") >= 0:
		return "res://assets/art/tokens/salt_thug_enemy_f%d.png" % frame
	if str(c.name).find("影戏匪首") >= 0:
		return "res://assets/art/tokens/shadow_boss_enemy_f%d.png" % frame
	if str(c.name).find("幕廊伏弓") >= 0:
		return "res://assets/art/tokens/shadow_archer_enemy_f%d.png" % frame
	if str(c.name).find("影戏悍匪") >= 0:
		return "res://assets/art/tokens/shadow_thug_enemy_f%d.png" % frame
	if str(c.name).find("笛楼匪首") >= 0:
		return "res://assets/art/tokens/flute_boss_enemy_f%d.png" % frame
	if str(c.name).find("音廊伏弓") >= 0:
		return "res://assets/art/tokens/flute_archer_enemy_f%d.png" % frame
	if str(c.name).find("笛楼悍匪") >= 0:
		return "res://assets/art/tokens/flute_thug_enemy_f%d.png" % frame
	if str(c.name).find("蜂场匪首") >= 0:
		return "res://assets/art/tokens/hive_boss_enemy_f%d.png" % frame
	if str(c.name).find("花陌伏弓") >= 0:
		return "res://assets/art/tokens/hive_archer_enemy_f%d.png" % frame
	if str(c.name).find("蜂场悍匪") >= 0:
		return "res://assets/art/tokens/hive_thug_enemy_f%d.png" % frame
	if str(c.name).find("砚坑匪首") >= 0:
		return "res://assets/art/tokens/ink_boss_enemy_f%d.png" % frame
	if str(c.name).find("墨池伏弓") >= 0:
		return "res://assets/art/tokens/ink_archer_enemy_f%d.png" % frame
	if str(c.name).find("砚坑悍匪") >= 0:
		return "res://assets/art/tokens/ink_thug_enemy_f%d.png" % frame
	if str(c.name).find("雨巷匪首") >= 0:
		return "res://assets/art/tokens/rain_boss_enemy_f%d.png" % frame
	if str(c.name).find("檐廊伏弓") >= 0:
		return "res://assets/art/tokens/rain_archer_enemy_f%d.png" % frame
	if str(c.name).find("雨巷悍匪") >= 0:
		return "res://assets/art/tokens/rain_thug_enemy_f%d.png" % frame
	if str(c.name).find("钟楼匪首") >= 0:
		return "res://assets/art/tokens/bell_boss_enemy_f%d.png" % frame
	if str(c.name).find("鼓廊伏弓") >= 0:
		return "res://assets/art/tokens/bell_archer_enemy_f%d.png" % frame
	if str(c.name).find("钟楼悍匪") >= 0:
		return "res://assets/art/tokens/bell_thug_enemy_f%d.png" % frame
	if str(c.name).find("驿道匪首") >= 0:
		return "res://assets/art/tokens/relay_boss_enemy_f%d.png" % frame
	if str(c.name).find("递路伏弓") >= 0:
		return "res://assets/art/tokens/relay_archer_enemy_f%d.png" % frame
	if str(c.name).find("驿道悍匪") >= 0:
		return "res://assets/art/tokens/relay_thug_enemy_f%d.png" % frame
	if str(c.name).find("竹海匪首") >= 0:
		return "res://assets/art/tokens/bamboo_boss_enemy_f%d.png" % frame
	if str(c.name).find("篁廊伏弓") >= 0:
		return "res://assets/art/tokens/bamboo_archer_enemy_f%d.png" % frame
	if str(c.name).find("竹海悍匪") >= 0:
		return "res://assets/art/tokens/bamboo_thug_enemy_f%d.png" % frame
	if str(c.name).find("雪栈匪首") >= 0:
		return "res://assets/art/tokens/snow_boss_enemy_f%d.png" % frame
	if str(c.name).find("冰廊伏弓") >= 0:
		return "res://assets/art/tokens/snow_archer_enemy_f%d.png" % frame
	if str(c.name).find("雪栈悍匪") >= 0:
		return "res://assets/art/tokens/snow_thug_enemy_f%d.png" % frame
	if str(c.name).find("粮仓匪首") >= 0:
		return "res://assets/art/tokens/grain_boss_enemy_f%d.png" % frame
	if str(c.name).find("碾坊伏弓") >= 0:
		return "res://assets/art/tokens/grain_archer_enemy_f%d.png" % frame
	if str(c.name).find("粮仓悍匪") >= 0:
		return "res://assets/art/tokens/grain_thug_enemy_f%d.png" % frame
	if str(c.name).find("灯市匪首") >= 0:
		return "res://assets/art/tokens/lamp_boss_enemy_f%d.png" % frame
	if str(c.name).find("油库伏弓") >= 0:
		return "res://assets/art/tokens/lamp_archer_enemy_f%d.png" % frame
	if str(c.name).find("灯市毛贼") >= 0:
		return "res://assets/art/tokens/lamp_thug_enemy_f%d.png" % frame
	if str(c.name).find("铜市匪首") >= 0:
		return "res://assets/art/tokens/copper_boss_enemy_f%d.png" % frame
	if str(c.name).find("矿道伏弓") >= 0:
		return "res://assets/art/tokens/copper_archer_enemy_f%d.png" % frame
	if str(c.name).find("铜市悍匪") >= 0:
		return "res://assets/art/tokens/copper_thug_enemy_f%d.png" % frame
	if str(c.name).find("纸坊匪首") >= 0:
		return "res://assets/art/tokens/paper_boss_enemy_f%d.png" % frame
	if str(c.name).find("浆槽伏弓") >= 0:
		return "res://assets/art/tokens/paper_archer_enemy_f%d.png" % frame
	if str(c.name).find("纸坊毛贼") >= 0:
		return "res://assets/art/tokens/paper_thief_enemy_f%d.png" % frame
	if str(c.name).find("关口伏弓") >= 0:
		return "res://assets/art/tokens/escort_archer_enemy_f%d.png" % frame
	if str(c.name).find("劫镖") >= 0 or str(c.name).find("劫道") >= 0:
		return "res://assets/art/tokens/escort_raider_enemy_f%d.png" % frame
	# v8.2 per-job tokens → role tokens (contemporary fantasy)
	var _job = str(c.job_id)
	var _side = "enemy" if (team == "enemy" or c.faction == "enemy") else "ally"
	if c.is_leader and _side == "ally":
		var _lead = "res://assets/art/tokens/v8_job_squire_ally.png"
		if ResourceLoader.exists("res://assets/art/tokens/v8_job_leader_ally.png"):
			_lead = "res://assets/art/tokens/v8_job_leader_ally.png"
		elif ResourceLoader.exists("res://assets/art/tokens/v8_role_leader.png"):
			_lead = "res://assets/art/tokens/v8_role_leader.png"
		if ResourceLoader.exists(_lead):
			return _lead
	var _jp = "res://assets/art/tokens/v8_job_%s_%s.png" % [_job, _side]
	if ResourceLoader.exists(_jp):
		return _jp
	var _v8role = BattleRules.job_role(c.job_id) if Engine.get_main_loop() else "skirmisher"
	if c.is_leader:
		_v8role = "leader"
	if _side == "enemy":
		var _ep = "res://assets/art/tokens/hire_%s_enemy_f%d.png" % [_v8role, frame % 4]
		if ResourceLoader.exists(_ep):
			return _ep
		var _eb = "res://assets/art/tokens/v82_enemy_boss.png"
		if ResourceLoader.exists(_eb) and (str(c.name).find("匪首") >= 0 or str(c.name).find("头目") >= 0):
			return _eb
	else:
		var _v8p = "res://assets/art/tokens/v8_role_%s.png" % _v8role
		if ResourceLoader.exists(_v8p):
			return _v8p
		var _hp = "res://assets/art/tokens/hire_%s_%s_f%d.png" % [_v8role, team, frame % 4]
		if ResourceLoader.exists(_hp):
			return _hp
	# 敌军：加密度 hire/role token，再回退 bandit
	if team == "enemy" or c.faction == "enemy":
		var erole = BattleRules.job_role(c.job_id) if Engine.get_main_loop() else "skirmisher"
		var ep = "res://assets/art/tokens/hire_%s_enemy_f%d.png" % [erole, frame % 4]
		if ResourceLoader.exists(ep):
			return ep
		return "res://assets/art/tokens/bandit_enemy_f%d.png" % (frame % 4)
	# 雇佣棋子（具名检查之后）
	var role2 = BattleRules.job_role(c.job_id) if Engine.get_main_loop() else "skirmisher"
	var hp = "res://assets/art/tokens/hire_%s_%s_f%d.png" % [role2, team, frame % 4]
	if ResourceLoader.exists(hp):
		return hp
	var hair = str(c.appearance.get("hair", "ash_brown"))
	var eyes = str(c.appearance.get("eyes", "slate"))
	var g = str(c.gender)
	var job = str(c.job_id)
	var job_map = {"warrior":"heavy_inf","archer":"hunter","priest":"apprentice","light_cavalry":"squire"}
	if job_map.has(job):
		job = job_map[job]
	return "res://assets/art/tokens/%s_%s_%s_%s_%s_f%d.png" % [hair, eyes, g, job, team, frame]

static func token(c: CKCharacter, team: String, size: int = 48, done: bool = false) -> Texture2D:
	var frame = 0 if done else int((_token_phase / 0.12)) % 4
	var path = _token_key(c, team, frame)
	var ck = "t|" + path + "|" + str(done)
	if _cache.has(ck):
		return _cache[ck]
	var tex2 = _try_load(path)
	# v8.5: leader shard-plate + legacy 72px chibi tokens are unreadable on the board ->
	# bust token composed from the unit's own portrait (face crop, team rim).
	if path.find("leader_default") >= 0 or (tex2 != null and tex2.get_width() <= 72):
		var bt = _bust_token(c, team, done)
		if bt != null:
			_cache[ck] = bt
			return bt
	if tex2 != null:
		_cache[ck] = tex2
		return tex2
	# 兵种板绘棋子（美术升档）
	var plate = {
		"heavy_inf": "tank_plate", "warrior": "tank_plate",
		"hunter": "ranger_plate", "archer": "ranger_plate",
		"apprentice": "mage_plate", "priest": "mage_plate",
		"squire": "leader_plate", "light_cavalry": "leader_plate",
		"light_inf": "skirm_plate",
	}.get(c.job_id, "")
	if c.is_leader:
		plate = "leader_plate"
	if plate != "":
		var pp = "res://assets/art/tokens/%s_%s_f%d.png" % [plate, team, frame]
		var pt = _try_load(pp)
		if pt != null:
			_cache["tplate|" + plate + "|" + team + "|" + str(frame)] = pt
			return pt
	return _proc_token(c, team, size, done)

static func _bust_token(c: CKCharacter, team: String, done: bool = false) -> Texture2D:
	var key = "bust|%s|%s|%s" % [str(c.id) if c.id != "" else c.name, team, str(done)]
	if _cache.has(key):
		return _cache[key]
	var pt = portrait(c, 220)
	if pt == null:
		return null
	var img: Image = pt.get_image()
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var side := int(min(w, h) * 0.80)
	var x0 := int((w - side) / 2)
	var y0 := clampi(int(h * 0.05), 0, maxi(0, h - side))
	var crop := img.get_region(Rect2i(x0, y0, side, side))
	var S := 128
	crop.resize(S, S, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var rim := Color(0.45, 0.95, 0.82) if team == "player" else Color(1.0, 0.48, 0.45)
	if c.is_leader:
		rim = Color(0.62, 0.86, 1.0)
	var cxy := (S - 1) * 0.5
	for y in S:
		for x in S:
			var r := Vector2(x - cxy, y - cxy).length() / (S * 0.5)
			if r > 1.0:
				continue
			var col := crop.get_pixel(x, y)
			col.a = 1.0
			# subtle bottom vignette for depth
			var vg := clampf((float(y) / S - 0.55) * 0.6, 0.0, 0.3)
			col = col.darkened(vg)
			if done:
				var g := col.get_luminance()
				col = Color(g, g, g).lerp(col, 0.25).darkened(0.25)
			var ring := exp(-pow((r - 0.915) / 0.035, 2.0))
			col = col.lerp(rim, clampf(ring, 0.0, 1.0))
			var inner_glow := exp(-pow((r - 0.86) / 0.05, 2.0)) * 0.25
			col = col.lerp(rim, inner_glow)
			col.a = clampf((0.985 - r) * S * 0.25, 0.0, 1.0)
			out.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(out)
	_cache[key] = tex
	return tex

static func banner(w: int = 160, h: int = 220, with_name: bool = true) -> Texture2D:
	var hex = _crest_hex()
	var path = "res://assets/art/banners/banner_%s_w%d.png" % [hex, _banner_frame]
	var ck = "b|" + path
	if _cache.has(ck):
		return _cache[ck]
	var tex2 = _try_load(path)
	if tex2 == null:
		path = "res://assets/art/banners/banner_c9a227_w%d.png" % _banner_frame
		ck = "b|" + path
		tex2 = _try_load(path)
	if tex2 != null:
		_cache[ck] = tex2
		return tex2
	return _proc_banner(w, h, with_name)

static func banner_wide(w: int = 320, h: int = 72) -> Texture2D:
	var b = banner(80, 110, true)
	# compose wide bar
	var ck = "bw|" + _crest_hex() + "|" + str(w) + "|" + str(_banner_frame)
	if _cache.has(ck):
		return _cache[ck]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.10, 0.12, 0.16, 0.92))
	var crest = crest_color()
	for x in w:
		img.set_pixel(x, 0, crest)
		img.set_pixel(x, 1, crest)
		img.set_pixel(x, h - 1, crest.darkened(0.2))
		img.set_pixel(x, h - 2, crest.darkened(0.2))
	var out := ImageTexture.create_from_image(img)
	_cache[ck] = out
	return out

static func draw_token_on(ci: CanvasItem, center: Vector2, c: CKCharacter, team: String, radius: float = 20.0, done: bool = false) -> void:
	var tex = token(c, team, int(radius * 2.4), done)
	var sz = Vector2(radius * 2.2, radius * 2.2)
	ci.draw_texture_rect(tex, Rect2(center - sz * 0.5, sz), false)

# ---- procedural fallbacks (simplified) ----
static func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var w = img.get_width(); var h = img.get_height()
	for y in range(maxi(0, int(cy - ry - 1)), mini(h, int(cy + ry + 2))):
		for x in range(maxi(0, int(cx - rx - 1)), mini(w, int(cx + rx + 2))):
			var nx = (x - cx) / rx; var ny = (y - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				img.set_pixel(x, y, col)

static func _fill_rect(img: Image, r: Rect2i, col: Color) -> void:
	var w = img.get_width(); var h = img.get_height()
	for y in range(clampi(r.position.y, 0, h - 1), clampi(r.position.y + r.size.y, 0, h)):
		for x in range(clampi(r.position.x, 0, w - 1), clampi(r.position.x + r.size.x, 0, w)):
			img.set_pixel(x, y, col)


static func _boss_portrait(key: String) -> String:
	var fp = "res://assets/art/portraits/%s_boss_face_plate.png" % key
	if ResourceLoader.exists(fp):
		return fp
	return "res://assets/art/portraits/%s_boss.png" % key


static func _farm_tags_for(c: CKCharacter) -> Array:
	## 职事/年龄 → 农场标签（可多选，靠前优先）
	var tags: Array = []
	var job = str(c.job_id)
	var age = int(c.age)
	if age <= 14:
		tags.append("child")
		tags.append("orphan")
	elif age <= 20:
		tags.append("youth")
		tags.append("recruit_raw")
		tags.append("novice")
	if age >= 55:
		tags.append("elder")
		tags.append("monk_old")
	var job_map := {
		"hunter": ["hunter", "ranger", "veteran_bow", "archer"],
		"archer": ["archer", "veteran_bow", "hunter", "ranger"],
		"heavy_inf": ["heavy", "spear", "guard", "iron_sergeant", "warden"],
		"warrior": ["heavy", "spear", "captain", "duelist"],
		"light_inf": ["skirm", "scout", "outrider", "fisher"],
		"squire": ["squire", "youth", "standard", "banner"],
		"light_cavalry": ["cavalry", "outrider", "captain"],
		"apprentice": ["scholar", "alchemist", "novice", "monk"],
		"priest": ["monk", "ash_priest", "monk_old", "novice"],
	}
	if job_map.has(job):
		for tg in job_map[job]:
			tags.append(tg)
	# soft extras
	if str(c.name).find("商") >= 0 or str(c.name).find("贾") >= 0:
		tags.append("merchant")
		tags.append("quartermaster")
	return tags

static func _face_uid(c: CKCharacter) -> int:
	## FNV 起点 + 开放寻址：超长王朝不共脸（同 id 稳定）
	## 农场板槽：按性别/年龄/职事优先占坑，再回落到全表探测
	var cid = str(c.id)
	if _face_assign.has(cid):
		return int(_face_assign[cid])
	var h := 2166136261
	var key = "%s|%s|%s|%s|%s|%s|%s" % [
		cid, str(c.name), str(c.gender),
		str(c.appearance.get("hair", "")), str(c.appearance.get("eyes", "")),
		str(c.appearance.get("brow", "")), str(c.appearance.get("scar", "")),
	]
	for ch2 in key:
		h = int((h ^ ch2.unicode_at(0)) * 16777619) & 0x7fffffff
	var prefer: Array = []
	# 0) per-tag farm slots first
	for tg in _farm_tags_for(c):
		if FARM_FACE_BY_TAG.has(tg):
			var arr: Array = FARM_FACE_BY_TAG[tg]
			for s in arr:
				prefer.append(int(s))
	if str(c.gender) == "f":
		prefer.assign(FARM_FACE_SLOTS_F)
		if int(c.age) <= 14:
			prefer = [755, 155, 355, 555] + prefer
		elif int(c.age) <= 22:
			prefer = [763, 752, 161, 361, 561] + prefer
	else:
		prefer.assign(FARM_FACE_SLOTS_M)
		if int(c.age) >= 50:
			prefer = [765, 764, 766] + prefer
		elif int(c.age) <= 14:
			prefer = [754, 154, 354, 554] + prefer
		elif int(c.age) <= 22:
			prefer = [762, 160, 360, 560] + prefer
		elif str(c.job_id) in ["apprentice", "priest"]:
			prefer = [766, 166, 366, 566] + prefer
	# 1) 优先农场槽（空或已属自己）；hash 旋转避免总抢同一张
	var npref = prefer.size()
	if npref > 0:
		var rot = h % npref
		for i in range(npref):
			var slot = int(prefer[(rot + i) % npref])
			var owner = str(_face_owner.get(slot, ""))
			if owner == "" or owner == cid:
				_face_owner[slot] = cid
				_face_assign[cid] = slot
				return slot
	# 2) 全表开放寻址
	var start = h % FACE_SLOTS
	for i in range(FACE_SLOTS):
		var slot2 = (start + i) % FACE_SLOTS
		var owner2 = str(_face_owner.get(slot2, ""))
		if owner2 == "" or owner2 == cid:
			_face_owner[slot2] = cid
			_face_assign[cid] = slot2
			return slot2
	_face_assign[cid] = start
	return start

static func _fingerprint_portrait(tex: Texture2D, c: CKCharacter) -> Texture2D:
	## 个人板为底；hireface 等位图作下半身/衣饰次级细节；轻染发瞳
	var g = "f" if str(c.gender) == "f" else "m"
	var hair = str(c.appearance.get("hair", "ash_brown"))
	var eyes = str(c.appearance.get("eyes", "slate"))
	var scar = str(c.appearance.get("scar", "none"))
	var brow = str(c.appearance.get("brow", "straight"))
	if scar == "":
		scar = "none"
	if brow == "":
		brow = "straight"
	var ck = "fp4|" + str(c.id) + "|" + hair + "|" + eyes + "|" + brow + "|" + scar
	if _cache.has(ck):
		return _cache[ck]
	var img: Image = tex.get_image()
	if img == null:
		_cache[ck] = tex
		return tex
	img = img.duplicate()
	var w = img.get_width()
	var h = img.get_height()
	var uid = _face_uid(c)
	# 次级：等位 hireface 衣饰/下半融合
	var face_p = "res://assets/art/portraits/hireface_%s_%s_%s_%s_%s.png" % [hair, eyes, g, scar, brow]
	var allele = _try_load(face_p)
	if allele != null:
		var aimg: Image = allele.get_image()
		if aimg != null:
			if aimg.get_width() != w or aimg.get_height() != h:
				aimg = aimg.duplicate()
				aimg.resize(w, h, Image.INTERPOLATE_LANCZOS)
			for y in range(h):
				for x in range(w):
					var p = img.get_pixel(x, y)
					var q = aimg.get_pixel(x, y)
					if p.a < 0.05 or q.a < 0.05:
						continue
					# 下半身/衣领区多用等位细节；上半脸保留个人构图
					var amt = 0.0
					if y > int(h * 0.58):
						amt = 0.48
					elif y > int(h * 0.48):
						amt = 0.28
					if amt > 0.0:
						img.set_pixel(x, y, p.lerp(q, amt))
	var hc = hair_color(c.appearance)
	var ec = eye_color(c.appearance)
	for y in range(h):
		for x in range(w):
			var p = img.get_pixel(x, y)
			if p.a < 0.05:
				continue
			var outc = p
			if y < int(h * 0.36):
				outc = p.lerp(Color(hc.r, hc.g, hc.b, p.a), 0.12)
			elif y < int(h * 0.50) and x > int(w * 0.28) and x < int(w * 0.72):
				outc = p.lerp(Color(ec.r, ec.g, ec.b, p.a), 0.10)
			var shift = Color(1.0 + (uid % 5) * 0.006, 1.0 + ((uid / 3) % 4) * 0.005, 1.0 - (uid % 3) * 0.006, 1.0)
			img.set_pixel(x, y, Color(clampf(outc.r * shift.r, 0, 1), clampf(outc.g * shift.g, 0, 1), clampf(outc.b * shift.b, 0, 1), p.a))
	var marks = [
		Vector2i(int(w * (0.58 + (uid % 6) * 0.015)), int(h * (0.40 + ((uid / 4) % 5) * 0.015))),
		Vector2i(int(w * (0.36 + ((uid / 2) % 5) * 0.012)), int(h * (0.48 + (uid % 4) * 0.012))),
	]
	for mpos in marks:
		if mpos.x > 1 and mpos.y > 1 and mpos.x < w - 2 and mpos.y < h - 2:
			img.set_pixel(mpos.x, mpos.y, Color(0.28, 0.16, 0.12, 0.9))
	var out := ImageTexture.create_from_image(img)
	_cache[ck] = out
	return out

static func _proc_portrait(c: CKCharacter, size: int) -> Texture2D:
	var role = BattleRules.job_role(c.job_id)
	var ck = "pp3|" + str(c.id) + "|" + role + "|" + str(c.gender) + "|" + str(c.age) + "|" + c.rank + "|" + str(size)
	if _cache.has(ck): return _cache[ck]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var s = float(size)
	var crest = crest_color()
	var ring = role_color(c.job_id)
	# 背景环按兵种
	_fill_ellipse(img, s * 0.5, s * 0.5, s * 0.48, s * 0.48, ring.darkened(0.35))
	_fill_ellipse(img, s * 0.5, s * 0.5, s * 0.44, s * 0.44, Color(0.14, 0.16, 0.22))
	# 肤色微差（id 哈希）
	var h = 0
	for ch2 in str(c.id):
		h = (h * 31 + ch2.unicode_at(0)) % 97
	var skin = Color(0.78 + (h % 7) * 0.015, 0.62 + (h % 5) * 0.012, 0.50 + (h % 4) * 0.01)
	_fill_ellipse(img, s * 0.5, s * 0.42, s * 0.22, s * 0.26, skin)
	# 发型：男短女长
	var hair = hair_color(c.appearance)
	if c.gender == "f":
		_fill_ellipse(img, s * 0.5, s * 0.30, s * 0.26, s * 0.16, hair)
		_fill_rect(img, Rect2i(int(s * 0.18), int(s * 0.34), int(s * 0.14), int(s * 0.28)), hair)
		_fill_rect(img, Rect2i(int(s * 0.68), int(s * 0.34), int(s * 0.14), int(s * 0.28)), hair)
	else:
		_fill_ellipse(img, s * 0.5, s * 0.28, s * 0.23, s * 0.12, hair)
	# 眼睛
	var eye = eye_color(c.appearance)
	_fill_ellipse(img, s * 0.42, s * 0.42, s * 0.035, s * 0.04, eye)
	_fill_ellipse(img, s * 0.58, s * 0.42, s * 0.035, s * 0.04, eye)
	# 衣领按兵种
	_fill_rect(img, Rect2i(int(s * 0.22), int(s * 0.62), int(s * 0.56), int(s * 0.30)), crest.darkened(0.15).lerp(ring, 0.35))
	if role == "tank":
		_fill_rect(img, Rect2i(int(s * 0.30), int(s * 0.58), int(s * 0.40), int(s * 0.08)), ring.lightened(0.1))
	elif role == "ranger":
		_fill_rect(img, Rect2i(int(s * 0.72), int(s * 0.48), int(s * 0.08), int(s * 0.22)), Color(0.35, 0.25, 0.15))
	elif role == "mage":
		_fill_ellipse(img, s * 0.5, s * 0.72, s * 0.06, s * 0.06, ring.lightened(0.3))
	elif role == "cavalry":
		_fill_rect(img, Rect2i(int(s * 0.45), int(s * 0.55), int(s * 0.1), int(s * 0.2)), Color(0.55, 0.4, 0.2))
	# 伤疤
	if str(c.appearance.get("scar", "none")) != "none":
		_fill_rect(img, Rect2i(int(s * 0.55), int(s * 0.36), int(s * 0.12), int(s * 0.025)), Color(0.55, 0.25, 0.22, 0.85))
	# 年龄纹
	if c.age >= 40:
		_fill_rect(img, Rect2i(int(s * 0.34), int(s * 0.48), int(s * 0.10), int(s * 0.015)), Color(0.55, 0.4, 0.35, 0.55))
		_fill_rect(img, Rect2i(int(s * 0.56), int(s * 0.48), int(s * 0.10), int(s * 0.015)), Color(0.55, 0.4, 0.35, 0.55))
	if c.age >= 55:
		_fill_ellipse(img, s * 0.5, s * 0.22, s * 0.12, s * 0.04, hair.lightened(0.35))
	# 勋位边框
	var ri = c.rank_index()
	if ri >= 1:
		var rc = [Color(0.55, 0.55, 0.6), Color(0.75, 0.65, 0.35), Color(0.85, 0.75, 0.4), Color(0.9, 0.55, 0.35)][clampi(ri, 0, 3)]
		for x in size:
			img.set_pixel(x, 0, rc)
			img.set_pixel(x, 1, rc)
			img.set_pixel(x, size - 1, rc)
			img.set_pixel(x, size - 2, rc)
		for y in size:
			img.set_pixel(0, y, rc)
			img.set_pixel(1, y, rc)
			img.set_pixel(size - 1, y, rc)
			img.set_pixel(size - 2, y, rc)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

static func role_color(job_id: String) -> Color:
	var role = BattleRules.job_role(job_id) if Engine.get_main_loop() else "skirmisher"
	return {
		"tank": Color(0.55, 0.58, 0.72),
		"cavalry": Color(0.75, 0.55, 0.25),
		"ranger": Color(0.35, 0.65, 0.40),
		"mage": Color(0.55, 0.40, 0.75),
		"skirmisher": Color(0.70, 0.45, 0.35),
	}.get(role, Color(0.6, 0.6, 0.6))

static func _proc_token(c: CKCharacter, team: String, size: int, done: bool) -> Texture2D:
	var role = BattleRules.job_role(c.job_id)
	var ck = "pt2|" + str(c.id) + "|" + team + "|" + role + "|" + str(c.gender) + "|" + str(size) + "|" + str(done)
	if _cache.has(ck): return _cache[ck]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var s = float(size)
	var col = crest_color() if team == "player" else Color(0.7, 0.25, 0.22)
	if done: col = col.darkened(0.35)
	var ring = role_color(c.job_id)
	# 外环 + 内盘
	_fill_ellipse(img, s * 0.5, s * 0.5, s * 0.48, s * 0.48, ring)
	_fill_ellipse(img, s * 0.5, s * 0.5, s * 0.40, s * 0.40, col)
	# 发型色点
	var hair = hair_color(c.appearance)
	_fill_ellipse(img, s * 0.5, s * 0.34, s * 0.18, s * 0.10, hair)
	_fill_ellipse(img, s * 0.5, s * 0.42, s * 0.15, s * 0.16, Color(0.86, 0.72, 0.58))
	# 兵种武器剪影
	if role == "tank":
		_fill_rect(img, Rect2i(int(s * 0.28), int(s * 0.60), int(s * 0.44), int(s * 0.14)), ring.lightened(0.12))
	elif role == "ranger":
		_fill_rect(img, Rect2i(int(s * 0.72), int(s * 0.28), int(s * 0.08), int(s * 0.36)), Color(0.4, 0.28, 0.15))
		_fill_rect(img, Rect2i(int(s * 0.68), int(s * 0.26), int(s * 0.16), int(s * 0.06)), Color(0.55, 0.4, 0.2))
	elif role == "mage":
		_fill_ellipse(img, s * 0.5, s * 0.70, s * 0.09, s * 0.09, ring.lightened(0.3))
		_fill_rect(img, Rect2i(int(s * 0.47), int(s * 0.55), int(s * 0.06), int(s * 0.16)), ring)
	elif role == "cavalry":
		_fill_rect(img, Rect2i(int(s * 0.18), int(s * 0.48), int(s * 0.64), int(s * 0.08)), Color(0.55, 0.4, 0.22))
	else:
		_fill_rect(img, Rect2i(int(s * 0.70), int(s * 0.40), int(s * 0.06), int(s * 0.28)), Color(0.7, 0.7, 0.75))
	if c.is_leader:
		_fill_ellipse(img, s * 0.5, s * 0.12, s * 0.08, s * 0.05, crest_color())
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

static func _proc_banner(w: int, h: int, _with_name: bool) -> Texture2D:
	var ck = "pb|" + _crest_hex() + "|" + str(w)
	if _cache.has(ck): return _cache[ck]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var crest = crest_color()
	_fill_rect(img, Rect2i(20, 16, int(w * 0.65), int(h * 0.5)), crest)
	_fill_rect(img, Rect2i(16, 4, 6, h - 8), Color(0.35, 0.28, 0.18))
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex
