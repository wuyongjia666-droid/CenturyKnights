class_name UnitArt
extends RefCounted
## 原创程序立绘 / 棋子 / 战旗（不依赖外部素材包）

static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache.clear()

static func _key(parts: Array) -> String:
	return "|".join(parts)

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

static func skin_tone(appearance: Dictionary, gender: String) -> Color:
	# 轻微随发色偏移，保持可读肤色
	var base = Color(0.86, 0.72, 0.60) if gender == "f" else Color(0.82, 0.68, 0.55)
	return base

static func armor_color(job_id: String, team: String, crest: Color) -> Color:
	if team == "enemy":
		return Color(0.45, 0.22, 0.20)
	match job_id:
		"hunter", "archer":
			return Color(0.28, 0.42, 0.30)
		"apprentice", "priest":
			return Color(0.35, 0.32, 0.55)
		"heavy_inf", "warrior":
			return Color(0.38, 0.40, 0.45)
		"squire", "light_cavalry":
			return crest.darkened(0.15).lerp(Color(0.45, 0.42, 0.38), 0.35)
		_:
			return Color(0.32, 0.38, 0.48).lerp(crest, 0.25)

static func crest_color() -> Color:
	return Color(str(GameState.crest_color))

static func portrait(c: CKCharacter, size: int = 96) -> ImageTexture:
	var k = _key(["p", c.id if c.id != "" else c.name, c.job_id, c.gender, str(c.appearance), c.faction, size, GameState.crest_color])
	if _cache.has(k):
		return _cache[k]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_portrait(img, c, size)
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex

static func token(c: CKCharacter, team: String, size: int = 48, done: bool = false) -> ImageTexture:
	var k = _key(["t", c.id if c.id != "" else c.name, c.job_id, c.gender, str(c.appearance), team, size, done, GameState.crest_color])
	if _cache.has(k):
		return _cache[k]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_token(img, c, team, size, done)
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex

static func banner(w: int = 160, h: int = 220, with_name: bool = true) -> ImageTexture:
	var k = _key(["b", GameState.crest_color, GameState.surname, w, h, with_name])
	if _cache.has(k):
		return _cache[k]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_banner(img, w, h, with_name)
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex

static func banner_wide(w: int = 320, h: int = 72) -> ImageTexture:
	var k = _key(["bw", GameState.crest_color, GameState.surname, w, h])
	if _cache.has(k):
		return _cache[k]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_banner_wide(img, w, h)
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex

static func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var w = img.get_width()
	var h = img.get_height()
	var x0 = maxi(0, int(cx - rx - 1))
	var x1 = mini(w - 1, int(cx + rx + 1))
	var y0 = maxi(0, int(cy - ry - 1))
	var y1 = mini(h - 1, int(cy + ry + 1))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var nx = (x - cx) / rx
			var ny = (y - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				img.set_pixel(x, y, col)

static func _fill_rect(img: Image, r: Rect2i, col: Color) -> void:
	var w = img.get_width()
	var h = img.get_height()
	var x0 = clampi(r.position.x, 0, w - 1)
	var y0 = clampi(r.position.y, 0, h - 1)
	var x1 = clampi(r.position.x + r.size.x - 1, 0, w - 1)
	var y1 = clampi(r.position.y + r.size.y - 1, 0, h - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y, col)

static func _blend(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var dst = img.get_pixel(x, y)
	var a = col.a
	img.set_pixel(x, y, Color(
		dst.r * (1.0 - a) + col.r * a,
		dst.g * (1.0 - a) + col.g * a,
		dst.b * (1.0 - a) + col.b * a,
		mini(1.0, dst.a + a)
	))

static func _stroke_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color, thick: float = 1.5) -> void:
	var w = img.get_width()
	var h = img.get_height()
	var x0 = maxi(0, int(cx - rx - thick - 1))
	var x1 = mini(w - 1, int(cx + rx + thick + 1))
	var y0 = maxi(0, int(cy - ry - thick - 1))
	var y1 = mini(h - 1, int(cy + ry + thick + 1))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var nx = (x - cx) / rx
			var ny = (y - cy) / ry
			var d = nx * nx + ny * ny
			var outer = ((rx + thick) / rx)
			var inner = maxf(0.01, (rx - thick) / rx)
			if d <= outer * outer and d >= inner * inner * 0.85:
				img.set_pixel(x, y, col)

static func _draw_portrait(img: Image, c: CKCharacter, size: int) -> void:
	var team = "enemy" if c.faction == "enemy" else "player"
	var crest = crest_color()
	var armor = armor_color(c.job_id, team, crest)
	var skin = skin_tone(c.appearance, c.gender)
	var hair = hair_color(c.appearance)
	var eyes = eye_color(c.appearance)
	var s = float(size)

	# 羊皮纸圆框背景
	_fill_ellipse(img, s * 0.5, s * 0.5, s * 0.48, s * 0.48, Color(0.14, 0.16, 0.20, 1))
	_fill_ellipse(img, s * 0.5, s * 0.5, s * 0.44, s * 0.44, Color(0.22, 0.24, 0.30, 1))
	_stroke_ellipse(img, s * 0.5, s * 0.5, s * 0.46, s * 0.46, crest.lightened(0.1), 2.0)

	# 肩甲 / 躯干
	_fill_ellipse(img, s * 0.5, s * 0.82, s * 0.38, s * 0.22, armor)
	_fill_rect(img, Rect2i(int(s * 0.22), int(s * 0.62), int(s * 0.56), int(s * 0.28)), armor.darkened(0.08))
	# 领饰用纹章色
	_fill_rect(img, Rect2i(int(s * 0.42), int(s * 0.58), int(s * 0.16), int(s * 0.12)), crest)

	# 头
	_fill_ellipse(img, s * 0.5, s * 0.42, s * 0.22, s * 0.26, skin)

	# 发型
	var brow = str(c.appearance.get("brow", "straight"))
	_fill_ellipse(img, s * 0.5, s * 0.30, s * 0.23, s * 0.14, hair)
	if c.gender == "f":
		_fill_ellipse(img, s * 0.28, s * 0.48, s * 0.08, s * 0.18, hair)
		_fill_ellipse(img, s * 0.72, s * 0.48, s * 0.08, s * 0.18, hair)
	else:
		_fill_rect(img, Rect2i(int(s * 0.30), int(s * 0.22), int(s * 0.40), int(s * 0.10)), hair)

	# 眉
	var by = s * 0.38
	if brow == "arch":
		_fill_rect(img, Rect2i(int(s * 0.36), int(by), int(s * 0.10), 2), hair.darkened(0.2))
		_fill_rect(img, Rect2i(int(s * 0.54), int(by), int(s * 0.10), 2), hair.darkened(0.2))
	elif brow == "thick":
		_fill_rect(img, Rect2i(int(s * 0.35), int(by), int(s * 0.12), 3), hair.darkened(0.25))
		_fill_rect(img, Rect2i(int(s * 0.53), int(by), int(s * 0.12), 3), hair.darkened(0.25))
	else:
		_fill_rect(img, Rect2i(int(s * 0.36), int(by + 1), int(s * 0.10), 2), hair.darkened(0.15))
		_fill_rect(img, Rect2i(int(s * 0.54), int(by + 1), int(s * 0.10), 2), hair.darkened(0.15))

	# 眼
	_fill_ellipse(img, s * 0.42, s * 0.44, s * 0.035, s * 0.028, Color.WHITE)
	_fill_ellipse(img, s * 0.58, s * 0.44, s * 0.035, s * 0.028, Color.WHITE)
	_fill_ellipse(img, s * 0.42, s * 0.44, s * 0.018, s * 0.018, eyes)
	_fill_ellipse(img, s * 0.58, s * 0.44, s * 0.018, s * 0.018, eyes)

	# 疤
	var scar = str(c.appearance.get("scar", "none"))
	if scar == "cheek":
		for i in 8:
			img.set_pixel(int(s * 0.64) + i / 2, int(s * 0.50) + i, Color(0.55, 0.25, 0.25, 0.85))
	elif scar == "brow":
		_fill_rect(img, Rect2i(int(s * 0.52), int(s * 0.36), int(s * 0.10), 2), Color(0.5, 0.2, 0.2, 0.9))

	# 头盔 / 职业饰件
	match c.job_id:
		"squire", "light_cavalry":
			_fill_ellipse(img, s * 0.5, s * 0.26, s * 0.20, s * 0.10, armor.lightened(0.15))
			_fill_rect(img, Rect2i(int(s * 0.48), int(s * 0.12), int(s * 0.04), int(s * 0.12)), crest)
		"heavy_inf", "warrior":
			_fill_ellipse(img, s * 0.5, s * 0.28, s * 0.22, s * 0.12, Color(0.55, 0.55, 0.58))
			_fill_rect(img, Rect2i(int(s * 0.30), int(s * 0.30), int(s * 0.40), int(s * 0.06)), Color(0.4, 0.4, 0.42))
		"hunter", "archer":
			_fill_ellipse(img, s * 0.5, s * 0.28, s * 0.18, s * 0.08, Color(0.25, 0.35, 0.22))
		"apprentice", "priest":
			_fill_ellipse(img, s * 0.5, s * 0.22, s * 0.16, s * 0.08, Color(0.75, 0.72, 0.55))

	# 团长金环
	if c.is_leader:
		_stroke_ellipse(img, s * 0.5, s * 0.5, s * 0.47, s * 0.47, Color(0.85, 0.72, 0.25), 2.5)

static func _draw_token(img: Image, c: CKCharacter, team: String, size: int, done: bool) -> void:
	var crest = crest_color()
	var armor = armor_color(c.job_id, team, crest)
	var skin = skin_tone(c.appearance, c.gender)
	var hair = hair_color(c.appearance)
	var s = float(size)
	if done:
		armor = armor.darkened(0.35)
		skin = skin.darkened(0.25)
		hair = hair.darkened(0.25)

	# 底座圆影
	_fill_ellipse(img, s * 0.5, s * 0.88, s * 0.32, s * 0.10, Color(0, 0, 0, 0.35))

	# 腿
	_fill_rect(img, Rect2i(int(s * 0.34), int(s * 0.62), int(s * 0.10), int(s * 0.22)), armor.darkened(0.1))
	_fill_rect(img, Rect2i(int(s * 0.56), int(s * 0.62), int(s * 0.10), int(s * 0.22)), armor.darkened(0.1))

	# 躯干
	_fill_rect(img, Rect2i(int(s * 0.30), int(s * 0.38), int(s * 0.40), int(s * 0.28)), armor)
	_fill_ellipse(img, s * 0.5, s * 0.40, s * 0.20, s * 0.10, armor.lightened(0.05))

	# 披风 / 队色条
	var sash = crest if team == "player" else Color(0.7, 0.2, 0.2)
	_fill_rect(img, Rect2i(int(s * 0.28), int(s * 0.42), 3, int(s * 0.22)), sash)
	_fill_rect(img, Rect2i(int(s * 0.68), int(s * 0.42), 3, int(s * 0.22)), sash)

	# 头
	_fill_ellipse(img, s * 0.5, s * 0.28, s * 0.14, s * 0.16, skin)
	_fill_ellipse(img, s * 0.5, s * 0.20, s * 0.14, s * 0.08, hair)

	# 武器示意
	var atk = str(GameState.get_job(c.job_id).get("atk_type", "melee"))
	if atk == "ranged":
		# 弓
		_stroke_ellipse(img, s * 0.78, s * 0.48, s * 0.08, s * 0.16, Color(0.45, 0.32, 0.18), 1.5)
		_fill_rect(img, Rect2i(int(s * 0.76), int(s * 0.36), 2, int(s * 0.24)), Color(0.7, 0.7, 0.75))
	elif atk == "magic":
		_fill_ellipse(img, s * 0.78, s * 0.42, s * 0.06, s * 0.06, Color(0.55, 0.7, 0.95, 0.9))
		_fill_rect(img, Rect2i(int(s * 0.76), int(s * 0.42), 3, int(s * 0.22)), Color(0.55, 0.45, 0.25))
	else:
		# 剑
		_fill_rect(img, Rect2i(int(s * 0.74), int(s * 0.22), 3, int(s * 0.34)), Color(0.75, 0.78, 0.85))
		_fill_rect(img, Rect2i(int(s * 0.70), int(s * 0.48), int(s * 0.12), 3), Color(0.55, 0.45, 0.25))

	# 头盔尖（骑兵/团长）
	if c.job_id in ["squire", "light_cavalry"] or c.is_leader:
		_fill_rect(img, Rect2i(int(s * 0.48), int(s * 0.06), int(s * 0.04), int(s * 0.10)), sash)

	# 外圈队色
	var ring = Color(0.35, 0.55, 0.85) if team == "player" else Color(0.85, 0.35, 0.30)
	if done:
		ring = ring.darkened(0.4)
	_stroke_ellipse(img, s * 0.5, s * 0.5, s * 0.46, s * 0.46, ring, 2.0)

static func _draw_banner(img: Image, w: int, h: int, with_name: bool) -> void:
	var crest = crest_color()
	var pole_x = int(w * 0.18)
	# 旗杆
	_fill_rect(img, Rect2i(pole_x, 4, 6, h - 8), Color(0.35, 0.28, 0.18))
	_fill_ellipse(img, float(pole_x + 3), 8.0, 5.0, 5.0, crest.lightened(0.2))
	# 旗面（燕尾）
	var fx = pole_x + 6
	var fw = int(w * 0.70)
	var fh = int(h * 0.55)
	_fill_rect(img, Rect2i(fx, 16, fw, fh), crest)
	_fill_rect(img, Rect2i(fx, 16, fw, 8), crest.lightened(0.15))
	_fill_rect(img, Rect2i(fx, 16 + fh - 8, fw, 8), crest.darkened(0.2))
	# 燕尾缺口
	for i in range(0, 18):
		var cut = int(i * 0.7)
		_fill_rect(img, Rect2i(fx + fw - cut, 16 + fh / 2 - 9 + i, cut + 1, 1), Color(0, 0, 0, 0))
	# 中央盾徽
	var cx = fx + fw * 0.42
	var cy = 16 + fh * 0.48
	_fill_ellipse(img, cx, cy, 16, 18, Color(0.12, 0.14, 0.18, 0.9))
	_fill_ellipse(img, cx, cy, 12, 14, Color(0.92, 0.88, 0.75))
	# 简化灰烬纹：三角焰
	var flame = crest.darkened(0.1)
	for i in 12:
		var yy = int(cy - 6 + i)
		var half = 6 - i / 2
		_fill_rect(img, Rect2i(int(cx - half), yy, half * 2, 1), flame)
	# 姓氏底条
	if with_name:
		_fill_rect(img, Rect2i(fx, 16 + fh + 4, fw - 10, 22), Color(0.10, 0.12, 0.16, 0.85))

static func _draw_banner_wide(img: Image, w: int, h: int) -> void:
	var crest = crest_color()
	_fill_rect(img, Rect2i(0, 0, w, h), Color(0.12, 0.14, 0.18, 0.92))
	_fill_rect(img, Rect2i(0, 0, w, 4), crest)
	_fill_rect(img, Rect2i(0, h - 4, w, 4), crest.darkened(0.2))
	_fill_rect(img, Rect2i(0, 0, 8, h), crest)
	# 小旗徽
	_fill_ellipse(img, 40.0, float(h) * 0.5, 18.0, 20.0, crest)
	_fill_ellipse(img, 40.0, float(h) * 0.5, 12.0, 14.0, Color(0.92, 0.88, 0.75))
	for i in 10:
		var yy = int(h * 0.5 - 5 + i)
		var half = 5 - i / 2
		_fill_rect(img, Rect2i(40 - half, yy, half * 2, 1), crest.darkened(0.15))

## 在 CanvasItem 上绘制棋子（无纹理时的即时绘制备用）
static func draw_token_on(ci: CanvasItem, center: Vector2, c: CKCharacter, team: String, radius: float = 20.0, done: bool = false) -> void:
	var tex = token(c, team, int(radius * 2.4), done)
	var sz = Vector2(radius * 2.2, radius * 2.2)
	ci.draw_texture_rect(tex, Rect2(center - sz * 0.5, sz), false)
