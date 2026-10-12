class_name BannerSpec
extends RefCounted
## Modular company banner: field / charge / border / emblem. Pure presentation.
## Colors live in res://assets/art/banner_diy_v93.json (style ratchet: no new hex in .gd).

const FIELDS := ["solid", "per_fess", "per_pale"]
const CHARGES := ["none", "fess", "pale", "bend", "chevron", "pale_thin"]
const BORDERS := ["none", "line", "double", "dentil"]
const EMBLEMS := ["ring", "arc", "wave", "leaf", "chevron", "spark", "filament", "tide", "notch", "bars", "bend", "hollow"]
const DATA_PATH := "res://assets/art/banner_diy_v93.json"

static var _data: Dictionary = {}
static var _ready := false

static func _table() -> Dictionary:
	if _ready:
		return _data
	_ready = true
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			_data = parsed
	return _data

static func palette() -> Array:
	return _table().get("palette", [])

static func color_names() -> Array:
	return _table().get("color_names", [])

static var _migration: Dictionary = {}
static var _migration_ready := false

static func _migrate_hex(raw: String) -> String:
	if not _migration_ready:
		_migration_ready = true
		var f := FileAccess.open("res://assets/art/crest_palette_v92.json", FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_migration = (parsed as Dictionary).get("migration", {})
	var c := str(raw).trim_prefix("#").to_lower()
	return str(_migration.get(c, c))

static func default_spec(field_hex: String = "") -> Dictionary:
	var base := _raw_defaults()
	var hx := str(field_hex).strip_edges()
	if hx != "":
		if not hx.begins_with("#"):
			hx = "#" + hx
		base["field_a"] = "#" + _migrate_hex(hx)
	return normalize(base)

static func from_crest(color: String) -> Dictionary:
	return default_spec(color)

static func _raw_defaults() -> Dictionary:
	var base: Dictionary = (_table().get("defaults", {}) as Dictionary).duplicate(true)
	if base.is_empty():
		base = {
			"field": "solid", "field_a": "#" + UIKit.ACCENT.to_html(false),
			"field_b": "#" + UIKit.ACCENT_DIM.to_html(false),
			"charge": "none", "charge_color": "#" + UIKit.TEXT.to_html(false), "border": "line",
			"border_color": "#" + UIKit.ACCENT_HOVER.to_html(false), "emblem": "ring",
			"emblem_color": "#" + UIKit.TEXT.to_html(false),
		}
	return base

static func normalize(raw) -> Dictionary:
	var base := _raw_defaults()
	if typeof(raw) != TYPE_DICTIONARY:
		# still sanitize enum/hex
		raw = base
	else:
		var d: Dictionary = raw
		for k in base.keys():
			if d.has(k):
				base[k] = d[k]
	base["field"] = str(base["field"])
	if not FIELDS.has(base["field"]):
		base["field"] = "solid"
	base["charge"] = str(base["charge"])
	if not CHARGES.has(base["charge"]):
		base["charge"] = "none"
	base["border"] = str(base["border"])
	if not BORDERS.has(base["border"]):
		base["border"] = "none"
	base["emblem"] = str(base["emblem"])
	if not EMBLEMS.has(base["emblem"]):
		base["emblem"] = "ring"
	base["field_a"] = _hex(base["field_a"], "#" + UIKit.ACCENT.to_html(false))
	base["field_b"] = _hex(base["field_b"], "#" + UIKit.ACCENT_DIM.to_html(false))
	base["charge_color"] = _hex(base["charge_color"], "#" + UIKit.TEXT.to_html(false))
	base["border_color"] = _hex(base["border_color"], "#" + UIKit.ACCENT_HOVER.to_html(false))
	base["emblem_color"] = _hex(base["emblem_color"], "#" + UIKit.TEXT.to_html(false))
	return base

static func _hex(v, fallback: String) -> String:
	var s := str(v).strip_edges().to_lower()
	if s == "":
		s = fallback
	if not s.begins_with("#"):
		s = "#" + s
	return "#" + _migrate_hex(s)

static func cache_key(spec: Dictionary) -> String:
	var s := normalize(spec)
	return "|".join([
		s.field, s.field_a, s.field_b, s.charge, s.charge_color,
		s.border, s.border_color, s.emblem, s.emblem_color,
	])

static func contrast_ok(spec: Dictionary) -> bool:
	var s := normalize(spec)
	var a := Color(str(s.field_a))
	var e := Color(str(s.emblem_color))
	return absf(a.get_luminance() - e.get_luminance()) >= 0.22

static func compose(spec: Dictionary, w: int = 160, h: int = 220, wave: float = 0.0) -> Image:
	var s := normalize(spec)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pole_x := int(w * 0.10)
	var cloth_x := pole_x + 4
	var cloth_w := int(w * 0.72)
	var cloth_y := int(h * 0.08)
	var cloth_h := int(h * 0.62)
	var poles: Array = _table().get("pole", [])
	var pole_dark := Color(str(poles[0])) if poles.size() > 0 else UIKit.STONE
	var pole_lit := Color(str(poles[1])) if poles.size() > 1 else UIKit.TEXT_DIM
	_rect(img, pole_x - 2, int(h * 0.04), 5, int(h * 0.88), pole_dark)
	_rect(img, pole_x - 1, int(h * 0.04), 3, int(h * 0.88), pole_lit)
	var fa := Color(str(s.field_a))
	var fb := Color(str(s.field_b))
	for yy in range(cloth_h):
		var y := cloth_y + yy
		var wobble := int(sin((yy * 0.11) + wave * TAU) * (2.0 + 2.0 * sin(wave * TAU)))
		var row_w := cloth_w + wobble
		for xx in range(maxi(1, row_w)):
			var x := cloth_x + xx
			if x < 0 or x >= w or y < 0 or y >= h:
				continue
			var col := fa
			match str(s.field):
				"per_fess":
					if yy > cloth_h * 0.5:
						col = fb
				"per_pale":
					if xx > row_w * 0.5:
						col = fb
				_:
					col = fa
			var shade := 1.0 - 0.12 * (float(xx) / float(maxi(1, row_w)))
			col = Color(col.r * shade, col.g * shade, col.b * shade, 1.0)
			img.set_pixel(x, y, col)
	_paint_charge(img, s, cloth_x, cloth_y, cloth_w, cloth_h)
	_paint_border(img, s, cloth_x, cloth_y, cloth_w, cloth_h)
	_paint_emblem(img, s, cloth_x, cloth_y, cloth_w, cloth_h)
	return img

static func compose_texture(spec: Dictionary, w: int = 160, h: int = 220, wave: float = 0.0) -> Texture2D:
	return ImageTexture.create_from_image(compose(spec, w, h, wave))

static func _rect(img: Image, x: int, y: int, rw: int, rh: int, col: Color) -> void:
	var W := img.get_width()
	var H := img.get_height()
	for yy in range(clampi(y, 0, H), clampi(y + rh, 0, H)):
		for xx in range(clampi(x, 0, W), clampi(x + rw, 0, W)):
			img.set_pixel(xx, yy, col)

static func _paint_charge(img: Image, s: Dictionary, x: int, y: int, w: int, h: int) -> void:
	var kind := str(s.charge)
	if kind == "none":
		return
	var c := Color(str(s.charge_color))
	c.a = 0.92
	match kind:
		"fess":
			_rect(img, x, y + int(h * 0.42), w, int(h * 0.16), c)
		"pale":
			_rect(img, x + int(w * 0.38), y, int(w * 0.24), h, c)
		"pale_thin":
			_rect(img, x + int(w * 0.44), y, int(w * 0.12), h, c)
		"bend":
			for i in range(h):
				var bx := x + int(float(i) / float(h) * w) - 4
				_rect(img, bx, y + i, 12, 2, c)
		"chevron":
			for i in range(int(h * 0.45)):
				var t := float(i) / float(h * 0.45)
				var half := int(w * 0.42 * t)
				var cy := y + int(h * 0.18) + i
				_rect(img, x + int(w * 0.5) - half, cy, half * 2, 2, c)
		_:
			pass

static func _paint_border(img: Image, s: Dictionary, x: int, y: int, w: int, h: int) -> void:
	var kind := str(s.border)
	if kind == "none":
		return
	var c := Color(str(s.border_color))
	match kind:
		"line":
			_frame(img, x, y, w, h, c, 2)
		"double":
			_frame(img, x, y, w, h, c, 2)
			_frame(img, x + 4, y + 4, w - 8, h - 8, c, 1)
		"dentil":
			_frame(img, x, y, w, h, c, 2)
			for i in range(0, w, 8):
				_rect(img, x + i, y, 4, 3, c)
				_rect(img, x + i, y + h - 3, 4, 3, c)
		_:
			pass

static func _frame(img: Image, x: int, y: int, w: int, h: int, c: Color, t: int) -> void:
	_rect(img, x, y, w, t, c)
	_rect(img, x, y + h - t, w, t, c)
	_rect(img, x, y, t, h, c)
	_rect(img, x + w - t, y, t, h, c)

static func _paint_emblem(img: Image, s: Dictionary, x: int, y: int, w: int, h: int) -> void:
	var kind := str(s.emblem)
	if kind == "none":
		return
	var c := Color(str(s.emblem_color))
	var cx := x + int(w * 0.5)
	var cy := y + int(h * 0.48)
	var r := int(mini(w, h) * 0.18)
	match kind:
		"ring", "hollow":
			_ring(img, cx, cy, r, c, 2 if kind == "ring" else 3)
		"arc":
			_arc(img, cx, cy, r, c)
		"wave":
			for i in range(-r, r):
				var wy := cy + int(sin(i * 0.35) * 3.0)
				_rect(img, cx + i, wy, 2, 2, c)
				_rect(img, cx + i, wy + 5, 2, 2, c)
		"leaf":
			_diamond(img, cx, cy, r, c)
		"chevron":
			for i in range(r):
				_rect(img, cx - i, cy - r + i, 2, 2, c)
				_rect(img, cx + i, cy - r + i, 2, 2, c)
		"spark":
			_rect(img, cx - 1, cy - r, 3, r * 2, c)
			_rect(img, cx - r, cy - 1, r * 2, 3, c)
			_rect(img, cx - 1, cy - 1, 3, 3, Color(1, 1, 1, 1))
		"filament":
			_rect(img, cx - 1, cy - r, 2, r * 2, c)
			_ring(img, cx, cy - int(r * 0.4), int(r * 0.55), c, 2)
		"tide":
			_rect(img, cx - r, cy - 6, r * 2, 2, c)
			_rect(img, cx - int(r * 0.75), cy, int(r * 1.5), 2, c)
			_rect(img, cx - int(r * 0.45), cy + 6, int(r * 0.9), 2, c)
		"notch":
			_rect(img, cx - r, cy - r, 2, r * 2, c)
			_rect(img, cx - r, cy - r, r * 2, 2, c)
			_rect(img, cx - r, cy + r - 2, r * 2, 2, c)
		"bars":
			_rect(img, cx - r, cy - r, 3, r * 2, c)
			_rect(img, cx - 2, cy - int(r * 0.6), 3, int(r * 1.6), c)
			_rect(img, cx + r - 3, cy - int(r * 0.3), 3, int(r * 1.3), c)
		"bend":
			for i in range(-r, r):
				_rect(img, cx + i, cy + i, 3, 3, c)
		_:
			_ring(img, cx, cy, r, c, 2)

static func _ring(img: Image, cx: int, cy: int, r: int, c: Color, t: int) -> void:
	var W := img.get_width()
	var H := img.get_height()
	for yy in range(cy - r - t, cy + r + t + 1):
		for xx in range(cx - r - t, cx + r + t + 1):
			if xx < 0 or yy < 0 or xx >= W or yy >= H:
				continue
			var d := Vector2(xx - cx, yy - cy).length()
			if d <= float(r) and d >= float(r - t):
				img.set_pixel(xx, yy, c)

static func _arc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	var W := img.get_width()
	var H := img.get_height()
	for i in range(20):
		var a := PI * 0.15 + PI * 0.7 * (float(i) / 19.0)
		var xx := cx + int(cos(a) * r)
		var yy := cy + int(sin(a) * r) - 2
		if xx >= 0 and yy >= 0 and xx < W and yy < H:
			img.set_pixel(xx, yy, c)
			if xx + 1 < W:
				img.set_pixel(xx + 1, yy, c)

static func _diamond(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for i in range(-r, r + 1):
		var half := r - absi(i)
		_rect(img, cx - half, cy + i, half * 2 + 1, 1, c)
