class_name UnitArt
extends RefCounted
## 优先加载预绘 PNG 图集；缺失时回退程序绘制

static var _cache: Dictionary = {}
static var _banner_frame: int = 0
static var _token_phase: float = 0.0

static func clear_cache() -> void:
	_cache.clear()

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
		return "res://assets/art/portraits/escort_boss.png"
	if str(c.name).find("港匪头目") >= 0:
		return "res://assets/art/portraits/harbor_boss.png"
	if str(c.name).find("礁口伏弓") >= 0:
		return "res://assets/art/portraits/harbor_archer.png"
	if str(c.name).find("渔港水匪") >= 0:
		return "res://assets/art/portraits/harbor_thug.png"
	if str(c.name).find("灯市匪首") >= 0:
		return "res://assets/art/portraits/lamp_boss.png"
	if str(c.name).find("油库伏弓") >= 0:
		return "res://assets/art/portraits/lamp_archer.png"
	if str(c.name).find("灯市毛贼") >= 0:
		return "res://assets/art/portraits/lamp_thug.png"
	if str(c.name).find("铜市匪首") >= 0:
		return "res://assets/art/portraits/copper_boss.png"
	if str(c.name).find("矿道伏弓") >= 0:
		return "res://assets/art/portraits/copper_archer.png"
	if str(c.name).find("铜市悍匪") >= 0:
		return "res://assets/art/portraits/copper_thug.png"
	if str(c.name).find("纸坊匪首") >= 0:
		return "res://assets/art/portraits/paper_boss.png"
	if str(c.name).find("浆槽伏弓") >= 0:
		return "res://assets/art/portraits/paper_archer.png"
	if str(c.name).find("纸坊毛贼") >= 0:
		return "res://assets/art/portraits/paper_thief.png"
	if str(c.name).find("劫镖") >= 0 or str(c.name).find("劫道") >= 0 or str(c.name).find("关口伏弓") >= 0:
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
	if str(c.name).find("劫镖") >= 0 or str(c.name).find("劫道") >= 0 or str(c.name).find("关口伏弓") >= 0:
		return "res://assets/art/tokens/escort_raider_enemy_f%d.png" % frame
	if team == "enemy" or c.faction == "enemy":
		return "res://assets/art/tokens/bandit_enemy_f%d.png" % frame
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

static func _proc_portrait(c: CKCharacter, size: int) -> Texture2D:
	var ck = "pp|" + str(c.id) + "|" + str(size)
	if _cache.has(ck): return _cache[ck]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var s = float(size)
	var crest = crest_color()
	_fill_ellipse(img, s * 0.5, s * 0.5, s * 0.46, s * 0.46, Color(0.18, 0.2, 0.26))
	_fill_ellipse(img, s * 0.5, s * 0.42, s * 0.22, s * 0.26, Color(0.82, 0.68, 0.55))
	_fill_ellipse(img, s * 0.5, s * 0.28, s * 0.23, s * 0.12, hair_color(c.appearance))
	_fill_rect(img, Rect2i(int(s * 0.25), int(s * 0.62), int(s * 0.5), int(s * 0.28)), crest.darkened(0.2))
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex

static func _proc_token(c: CKCharacter, team: String, size: int, done: bool) -> Texture2D:
	var ck = "pt|" + str(c.id) + "|" + team + "|" + str(size) + "|" + str(done)
	if _cache.has(ck): return _cache[ck]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var s = float(size)
	var col = crest_color() if team == "player" else Color(0.7, 0.25, 0.22)
	if done: col = col.darkened(0.35)
	_fill_ellipse(img, s * 0.5, s * 0.5, s * 0.4, s * 0.4, col)
	_fill_ellipse(img, s * 0.5, s * 0.38, s * 0.16, s * 0.18, Color(0.85, 0.72, 0.6))
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
