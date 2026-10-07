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
const FARM_FACE_SLOTS_M := [760, 762, 764, 765, 766, 750, 751, 753, 754, 160, 162, 164, 165, 166, 150, 151, 153, 154, 360, 362, 364, 365, 366, 350, 351, 353, 354, 560, 562, 564, 565, 566, 550, 551, 553, 554]
const FARM_FACE_SLOTS_F := [761, 763, 752, 755, 161, 163, 152, 155, 361, 363, 352, 355, 561, 563, 552, 555]


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

static func _portrait_key(c: CKCharacter) -> String:
	# 具名角色优先 face_plate（美术升档）
	var named_plate := ""
	if c.is_leader:
		named_plate = "leader_default_face_plate"
	elif c.name.find("灯影") >= 0:
		named_plate = "ally_dengying_face_plate"
	elif c.name.find("民兵·甲") >= 0:
		named_plate = "militia_a_face_plate"
	elif c.name.find("民兵·乙") >= 0:
		named_plate = "militia_b_face_plate"
	elif c.name.find("河荇") >= 0:
		named_plate = "ally_heye_face_plate"
	elif c.name.find("苇心") >= 0:
		named_plate = "ally_weixin_face_plate"
	if named_plate != "":
		var pp = "res://assets/art/portraits/%s.png" % named_plate
		if ResourceLoader.exists(pp):
			return pp
	if c.is_leader:
		var p = "res://assets/art/portraits/leader_default.png"
		if ResourceLoader.exists(p):
			return p
	if c.name.find("灯影") >= 0:
		return "res://assets/art/portraits/ally_dengying.png"
	if c.name.find("民兵·甲") >= 0:
		return "res://assets/art/portraits/militia_a.png"
	if c.name.find("民兵·乙") >= 0:
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

static func portrait(c: CKCharacter, size: int = 96) -> Texture2D:
	var path = _portrait_key(c)
	var ck = "p|" + path + "|" + str(c.id)
	if _cache.has(ck):
		return _cache[ck]
	var tex2 = _try_load(path)
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
	var ft = _try_load(face_p)
	if ft != null:
		return _fingerprint_portrait(ft, c)
	# 雇佣/花名册：角色×性别板（回退）
	var role = BattleRules.job_role(c.job_id) if Engine.get_main_loop() else "skirmisher"
	var hire_p = "res://assets/art/portraits/hire_%s_%s_plate.png" % [role, g]
	var ht = _try_load(hire_p)
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
		var pt = _try_load(pp)
		if pt != null:
			_cache["plate|" + plate + "|" + str(size)] = pt
			return pt
	return _proc_portrait(c, size)

static func _token_key(c: CKCharacter, team: String, frame: int) -> String:
	if c.is_leader:
		return "res://assets/art/tokens/leader_default_%s_f%d.png" % [team, frame]
	if c.name.find("灯影") >= 0:
		return "res://assets/art/tokens/ally_dengying_%s_f%d.png" % [team, frame]
	if c.name.find("民兵·甲") >= 0:
		return "res://assets/art/tokens/militia_a_%s_f%d.png" % [team, frame]
	if c.name.find("民兵·乙") >= 0:
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
