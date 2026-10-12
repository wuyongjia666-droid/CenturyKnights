extends RefCounted
## Vector heraldry renderer (art pass 2). Builds one SVG per achievement and rasterises it with
## ThorVG (Image.load_svg_from_string): anti-aliased at any size. Art fragments live in
## assets/art/heraldry_vector.json; every colour comes from JSON — no hex literals here.

const SHIELD_W := 200.0
const SHIELD_H := 240.0
const MOTTO_FONT := "res://assets/fonts/NotoSansSC-Bold-ck.otf"

static var _lib: Dictionary = {}
static var _font: FontFile = null

static func lib() -> Dictionary:
	if _lib.is_empty():
		var f := FileAccess.open("res://assets/art/heraldry_vector.json", FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_lib = parsed
	return _lib

static func render(spec: Dictionary, w: int, h: int, mode: String, wave: float = 0.0) -> Image:
	var s := CKHeraldry.normalize(spec)
	var svg := ""
	match mode:
		"arms":
			svg = arms_svg(s, w, h)
		"banner":
			svg = banner_svg(s, w, h, wave)
		_:
			svg = shield_svg(s, w, h)
	var img := Image.new()
	if img.load_svg_from_string(svg, 1.0) != OK or img.is_empty():
		img = Image.create(maxi(1, w), maxi(1, h), false, Image.FORMAT_RGBA8)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img

# ---------------------------------------------------------------- colours

static func _hx(c: Color) -> String:
	return "#" + c.to_html(false)

static func _ink() -> String:
	return str(CKHeraldry.table().get("outline", CKHeraldry.tincture_hex("sable")))

static func _tint_vars(hex: String) -> Dictionary:
	var c := Color(hex)
	var lum := c.get_luminance()
	return {
		"{T}": _hx(c),
		"{TL}": _hx(c.lightened(0.55 if lum < 0.6 else 0.35)),
		"{TD}": _hx(c.darkened(0.38 if lum > 0.35 else 0.2)),
	}

static func _global_vars() -> Dictionary:
	var L := lib()
	var metal: Array = L.get("metal", [])
	var sup: Dictionary = L.get("supporter_tones", {})
	var gem: Dictionary = L.get("gem", {})
	var v := {"{K}": _ink(), "{G}": str(gem.get("base", "")), "{GL}": str(gem.get("light", "")),
		"{S}": str(sup.get("body", "")), "{SL}": str(sup.get("light", "")), "{SD}": str(sup.get("dark", ""))}
	for i in range(metal.size()):
		v["{M%d}" % i] = str(metal[i])
	return v

static func _sub(frag: String, vars: Dictionary) -> String:
	var out := frag
	for k in vars.keys():
		out = out.replace(str(k), str(vars[k]))
	return out

# ---------------------------------------------------------------- shield geometry (200x240 box)

static func shield_path(shape: String) -> String:
	match shape:
		"round":
			return "M100,6 C158,6 194,52 194,120 C194,188 158,234 100,234 C42,234 6,188 6,120 C6,52 42,6 100,6 Z"
		"lozenge":
			return "M100,4 L194,120 L100,236 L6,120 Z"
		"kite":
			return "M100,4 C150,8 186,28 188,70 C190,140 146,198 100,236 C54,198 10,140 12,70 C14,28 50,8 100,4 Z"
		"banner":
			return "M10,8 L190,8 L190,196 L100,236 L10,196 Z"
		_:
			return "M8,8 L192,8 L192,112 C192,172 152,210 100,234 C48,210 8,172 8,112 Z"

static func _line_pts(a: Vector2, b: Vector2, kind: String) -> PackedVector2Array:
	## Partition line from a→b with heraldic profile; returns sampled points (excludes nothing).
	var pts := PackedVector2Array()
	var d := b - a
	var length := d.length()
	if length < 0.01:
		return PackedVector2Array([a, b])
	var n := d.normalized().orthogonal()
	var period := 26.0
	var amp := 6.0
	var steps := int(maxf(2.0, length / 2.0))
	if kind == "straight" or kind == "":
		return PackedVector2Array([a, b])
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := t * length / period
		var off := 0.0
		match kind:
			"wavy":
				off = sin(x * TAU) * amp
			"engrailed":
				off = -absf(sin(x * PI)) * amp * 1.2 + amp * 0.6
			"invected":
				off = absf(sin(x * PI)) * amp * 1.2 - amp * 0.6
			"embattled":
				off = amp if fmod(x, 1.0) < 0.5 else -amp
			"nebuly":
				off = (sin(x * TAU) + 0.45 * sin(x * TAU * 2.0 + 1.2)) * amp
		pts.append(a + d * t + n * off)
	return pts

static func _poly(pts: PackedVector2Array) -> String:
	var parts: PackedStringArray = []
	for p in pts:
		parts.append("%.1f,%.1f" % [p.x, p.y])
	return "M" + " L".join(parts) + " Z"

static func _division_path(div: String, line: String) -> String:
	var W := SHIELD_W
	var H := SHIELD_H
	match div:
		"per_pale":
			var e := _line_pts(Vector2(W / 2, -10), Vector2(W / 2, H + 10), line)
			e.append(Vector2(W + 10, H + 10))
			e.append(Vector2(W + 10, -10))
			return _poly(e)
		"per_fess":
			var e2 := _line_pts(Vector2(-10, H * 0.48), Vector2(W + 10, H * 0.48), line)
			e2.append(Vector2(W + 10, H + 10))
			e2.append(Vector2(-10, H + 10))
			return _poly(e2)
		"per_bend":
			var e3 := _line_pts(Vector2(-10, -10), Vector2(W + 10, H + 10), line)
			e3.append(Vector2(-10, H + 10))
			return _poly(e3)
		"per_bend_sinister":
			var e4 := _line_pts(Vector2(W + 10, -10), Vector2(-10, H + 10), line)
			e4.append(Vector2(W + 10, H + 10))
			return _poly(e4)
		"quarterly":
			return "M%.1f,-10 L%.1f,-10 L%.1f,%.1f L%.1f,%.1f Z M-10,%.1f L%.1f,%.1f L%.1f,%.1f L-10,%.1f Z" % [
				W / 2, W + 10, W + 10, H * 0.48, W / 2, H * 0.48, H * 0.48, W / 2, H * 0.48, W / 2, H + 10, H + 10]
		"per_chevron":
			var e5 := _line_pts(Vector2(-10, H * 0.92), Vector2(W / 2, H * 0.40), line)
			e5.append_array(_line_pts(Vector2(W / 2, H * 0.40), Vector2(W + 10, H * 0.92), line))
			e5.append(Vector2(W + 10, H + 10))
			e5.append(Vector2(-10, H + 10))
			return _poly(e5)
		"per_saltire":
			return "M-10,-10 L%.1f,%.1f L-10,%.1f Z M%.1f,-10 L%.1f,%.1f L%.1f,%.1f Z" % [
				W / 2, H * 0.5, H + 10, W + 10, W / 2, H * 0.5, W + 10, H + 10]
		"gyronny":
			var out := ""
			var c := Vector2(W / 2, H * 0.48)
			for k in range(4):
				var a0 := k * PI * 0.5
				var p1 := c + Vector2(cos(a0), sin(a0)) * 400.0
				var p2 := c + Vector2(cos(a0 + PI * 0.25), sin(a0 + PI * 0.25)) * 400.0
				out += "M%.1f,%.1f L%.1f,%.1f L%.1f,%.1f Z " % [c.x, c.y, p1.x, p1.y, p2.x, p2.y]
			return out
	return ""

static func _ordinary_path(kind: String) -> String:
	## 200x240 shield box; paths overshoot the edge and are clipped by the shield.
	var paths := {
		"fess": "M-10,91.2 L210,91.2 L210,139.2 L-10,139.2 Z",
		"pale": "M70,-10 L130,-10 L130,250 L70,250 Z",
		"pale_thin": "M86,-10 L114,-10 L114,250 L86,250 Z",
		"bend": "M-10,10 L10,-10 L230,230 L210,270 Z",
		"bend_sinister": "M190,-10 L210,10 L-10,270 L-30,230 Z",
		"chevron": "M-10,192 L100,72 L210,192 L210,235.2 L100,115.2 L-10,235.2 Z",
		"cross": "M78,-10 L122,-10 L122,88 L210,88 L210,128 L122,128 L122,250 L78,250 L78,128 L-10,128 L-10,88 L78,88 Z",
		"saltire": "M-10,6 L6,-10 L100,98 L194,-10 L210,6 L114,116 L210,226 L194,250 L100,134 L6,250 L-10,226 L86,116 Z",
		"chief": "M-10,-10 L210,-10 L210,64 L-10,64 Z",
		"bordure": shield_path("heater") + " M30,30 L170,30 L170,112 C170,160 138,190 100,208 C62,190 30,160 30,112 Z",
		"orle": "M26,26 L174,26 L174,112 C174,162 140,194 100,214 C60,194 26,162 26,112 Z M40,40 L160,40 L160,112 C160,154 132,180 100,198 C68,180 40,154 40,112 Z",
		"pile": "M30,-10 L170,-10 L100,200 Z",
		"pall": "M-10,6 L6,-10 L100,92 L194,-10 L210,6 L114,110 L114,250 L86,250 L86,110 Z",
	}
	return str(paths.get(kind, ""))

# ---------------------------------------------------------------- shield content

static func _charge_frag(id: String, hex: String, cx: float, cy: float, size: float) -> String:
	var L := lib()
	var charges: Dictionary = L.get("charges", {})
	var key := id
	if key == "chevron":
		key = "chevron_mark"
	elif key == "bend":
		key = "bend_mark"
	if not charges.has(key):
		key = "ring"
	var vars := _tint_vars(hex)
	vars.merge(_global_vars())
	var k := size / 100.0
	var shadow := '<g transform="translate(%.2f,%.2f) scale(%.4f) translate(-50,-50)" opacity="0.28">%s</g>' % [
		cx + size * 0.025, cy + size * 0.035, k, _sub(str(charges[key]), vars).replace("fill=\"" + str(vars["{T}"]) + "\"", "fill=\"" + _ink() + "\"")]
	return shadow + '<g transform="translate(%.2f,%.2f) scale(%.4f) translate(-50,-50)">%s</g>' % [cx, cy, k, _sub(str(charges[key]), vars)]

static func _fur_pattern(kind: String, base_hex: String, spot_hex: String) -> String:
	var out := '<rect x="-10" y="-10" width="220" height="260" fill="%s"/>' % base_hex
	for row in range(9):
		for col in range(7):
			var x := 14.0 + col * 30.0 + (15.0 if row % 2 == 1 else 0.0)
			var y := 14.0 + row * 28.0
			if kind == "vair":
				out += '<path d="M%.1f,%.1f l8,-10 l8,10 l0,12 l-16,0 Z" fill="%s"/>' % [x - 8, y + 2, spot_hex]
			else:
				out += '<path d="M%.1f,%.1f c-3,6 -4,12 0,16 c4,-4 3,-10 0,-16 Z M%.1f,%.1f a2,2 0 1,0 0.1,0 M%.1f,%.1f a2,2 0 1,0 0.1,0 M%.1f,%.1f a2,2 0 1,0 0.1,0" fill="%s"/>' % [
					x, y, x - 4, y - 3, x + 4, y - 3, x, y - 6, spot_hex]
	return out

static func _fur_of(hex: String) -> Dictionary:
	for tid in (CKHeraldry.table().get("tinctures", {}) as Dictionary).keys():
		var t: Dictionary = CKHeraldry.table().tinctures[tid]
		if str(t.get("class", "")) == "fur" and str(t.get("hex", "")).to_lower() == hex.to_lower():
			return {"kind": str(tid), "spot": str(t.get("spot", _ink()))}
	return {}

static func _field_fill(hex: String) -> String:
	var fur := _fur_of(hex)
	if fur.is_empty():
		return '<rect x="-10" y="-10" width="220" height="260" fill="%s"/>' % hex
	return _fur_pattern(str(fur.kind), hex, str(fur.spot))

static func shield_content(s: Dictionary) -> String:
	## Field, division, ordinary, charges, canton — in the 200x240 shield box (unclipped).
	var fa := str(s.get("field_a", CKHeraldry.tincture_hex("slate")))
	var fb := str(s.get("field_b", CKHeraldry.tincture_hex("sable")))
	var out := _field_fill(fa)
	var div := str(s.get("division", "solid"))
	var dp := _division_path(div, str(s.get("partition_line", "straight")))
	if dp != "":
		out += '<clipPath id="cp_div"><path d="%s"/></clipPath><g clip-path="url(#cp_div)">%s</g>' % [dp, _field_fill(fb)]
		out += '<path d="%s" fill="none" stroke="%s" stroke-width="1.6" opacity="0.55"/>' % [dp, _ink()]
	out += _diaper()
	var ord := str(s.get("ordinary", "none"))
	var op := _ordinary_path(ord)
	if op != "":
		var oc := str(s.get("ordinary_tincture", CKHeraldry.tincture_hex("argent")))
		var tv := _tint_vars(oc)
		out += '<path d="%s" fill="%s" fill-rule="evenodd" stroke="%s" stroke-width="2.6" stroke-linejoin="round"/>' % [op, oc, _ink()]
		out += '<path d="%s" fill="none" fill-rule="evenodd" stroke="%s" stroke-width="1.2" opacity="0.7" transform="translate(1.2,1.2)"/>' % [op, tv["{TL}"]]
	out += _charges_svg(s, ord != "none")
	out += _canton_svg(s)
	return out

static func _charges_svg(s: Dictionary, has_ordinary: bool) -> String:
	var charges: Array = s.get("charges", [])
	if charges.is_empty():
		var emblem := str(s.get("emblem", ""))
		if emblem == "" or emblem == "none":
			return ""
		charges = [{"id": emblem, "tincture": str(s.get("emblem_color", "")), "placement": "center"}]
	var out := ""
	var multi := charges.size() > 1
	for ch in charges:
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var cd: Dictionary = ch
		var pos := Vector2(100, 110)
		var size := 128.0 if not has_ordinary else 104.0
		match str(cd.get("placement", "center")):
			"chief":
				pos = Vector2(100, 40)
				size = 56.0
			"base":
				pos = Vector2(100, 184)
				size = 56.0
			"dexter":
				pos = Vector2(54, 104)
				size = 50.0
			"sinister":
				pos = Vector2(146, 104)
				size = 50.0
			_:
				if multi:
					size = 92.0
		out += _charge_frag(str(cd.get("id", "ring")), str(cd.get("tincture", CKHeraldry.tincture_hex("argent"))), pos.x, pos.y, size)
	return out

static func _canton_svg(s: Dictionary) -> String:
	## Fixed small canton echoing the company banner (family arms only), inset per shield shape.
	var mark = s.get("castle_mark", {})
	if typeof(mark) != TYPE_DICTIONARY or str((mark as Dictionary).get("field", "")) == "":
		return ""
	var md: Dictionary = mark
	var r := Rect2(16, 16, 58, 52)
	match str(s.get("shield_shape", "heater")):
		"round":
			r = Rect2(36, 40, 50, 46)
		"kite":
			r = Rect2(34, 28, 50, 46)
		"lozenge":
			r = Rect2(62, 60, 40, 38)
	var rim := CKHeraldry.tincture_hex("argent")
	var out := (
		'<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="3" fill="%s" stroke="%s" stroke-width="5"/>'
		% [r.position.x, r.position.y, r.size.x, r.size.y, _ink(), _ink()]
	)
	out += (
		'<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="2" fill="%s" stroke="%s" stroke-width="1.6"/>'
		% [r.position.x + 2.5, r.position.y + 2.5, r.size.x - 5, r.size.y - 5, str(md.field), rim]
	)
	if str(md.get("charge", "")) != "":
		var tint := str(md.get("tincture", rim))
		if absf(Color(tint).get_luminance() - Color(str(md.field)).get_luminance()) < 0.22:
			tint = _ink() if Color(str(md.field)).get_luminance() > 0.5 else rim
		var c := r.get_center()
		out += _charge_frag(str(md.charge), tint, c.x, c.y, minf(r.size.x, r.size.y) * 0.8)
	return out

static func _material(shape_d: String, border: String, border_hex: String) -> String:
	## Enamel sheen + bevel + frost-metal rim + ink outline (drawn after clipped content).
	var out := '<g clip-path="url(#cp_shield)">'
	out += '<rect x="-10" y="-10" width="220" height="260" fill="url(#gr_sheen)"/>'
	out += '<ellipse cx="62" cy="52" rx="70" ry="44" fill="url(#gr_spec)"/>'
	out += '<path d="%s" fill="none" stroke="%s" stroke-width="10" opacity="0.18"/>' % [shape_d, _ink()]
	out += '<path d="%s" fill="none" stroke="url(#gr_bevel)" stroke-width="5" opacity="0.55"/>' % shape_d
	if border != "none" and border != "":
		var t := 'transform="translate(100,120) scale(0.9) translate(-100,-120)"'
		match border:
			"double":
				out += '<path d="%s" fill="none" stroke="%s" stroke-width="3" %s/>' % [shape_d, border_hex, t]
				out += (
					'<path d="%s" fill="none" stroke="%s" stroke-width="1.6" '
					+ 'transform="translate(100,120) scale(0.84) translate(-100,-120)"/>'
				) % [shape_d, border_hex]
			"dentil":
				out += '<path d="%s" fill="none" stroke="%s" stroke-width="5" stroke-dasharray="5 5" %s/>' % [shape_d, border_hex, t]
			_:
				out += '<path d="%s" fill="none" stroke="%s" stroke-width="2.6" %s/>' % [shape_d, border_hex, t]
	out += "</g>"
	out += '<path d="%s" fill="none" stroke="%s" stroke-width="9" stroke-linejoin="round"/>' % [shape_d, _ink()]
	out += '<path d="%s" fill="none" stroke="url(#gr_rim)" stroke-width="5" stroke-linejoin="round"/>' % shape_d
	out += (
		'<path d="%s" fill="none" stroke="%s" stroke-width="1" stroke-linejoin="round" opacity="0.8" '
		+ 'transform="translate(100,120) scale(0.955) translate(-100,-120)"/>'
	) % [shape_d, _ink()]
	return out

static func _defs(s: Dictionary) -> String:
	var L := lib()
	var metal: Array = L.get("metal", [])
	var m := func(i: int) -> String: return str(metal[clampi(i, 0, metal.size() - 1)]) if not metal.is_empty() else _ink()
	var argent := CKHeraldry.tincture_hex("argent")
	var sup: Dictionary = L.get("supporter_tones", {})
	var ach: Dictionary = s.get("achievement", {})
	var ma := str(ach.get("mantling_a", s.get("field_a", "")))
	var mb := str(ach.get("mantling_b", s.get("field_b", "")))
	if ma == "":
		ma = str(s.get("field_a", argent))
	if mb == "":
		mb = str(s.get("field_b", argent))
	var out := "<defs>"
	out += (
		'<linearGradient id="gr_sheen" x1="0" y1="0" x2="1" y2="1">'
		+ '<stop offset="0" stop-color="%s" stop-opacity="0.30"/>'
		+ '<stop offset="0.45" stop-color="%s" stop-opacity="0"/>'
		+ '<stop offset="1" stop-color="%s" stop-opacity="0.32"/></linearGradient>'
	) % [argent, argent, _ink()]
	out += (
		'<radialGradient id="gr_spec" cx="0.5" cy="0.5" r="0.5">'
		+ '<stop offset="0" stop-color="%s" stop-opacity="0.35"/>'
		+ '<stop offset="1" stop-color="%s" stop-opacity="0"/></radialGradient>'
	) % [argent, argent]
	out += (
		'<linearGradient id="gr_bevel" x1="0" y1="0" x2="1" y2="1">'
		+ '<stop offset="0" stop-color="%s"/>'
		+ '<stop offset="1" stop-color="%s" stop-opacity="0"/></linearGradient>'
	) % [argent, argent]
	out += (
		'<linearGradient id="gr_rim" x1="0" y1="0" x2="1" y2="1">'
		+ '<stop offset="0" stop-color="%s"/><stop offset="0.35" stop-color="%s"/>'
		+ '<stop offset="0.7" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>'
	) % [m.call(4), m.call(2), m.call(1), m.call(3)]
	out += (
		'<linearGradient id="hm_metal" x1="0" y1="0" x2="1" y2="0">'
		+ '<stop offset="0" stop-color="%s"/><stop offset="0.3" stop-color="%s"/>'
		+ '<stop offset="0.55" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>'
	) % [m.call(1), m.call(4), m.call(2), m.call(0)]
	out += (
		'<linearGradient id="cr_metal" x1="0" y1="0" x2="0" y2="1">'
		+ '<stop offset="0" stop-color="%s"/><stop offset="0.5" stop-color="%s"/>'
		+ '<stop offset="1" stop-color="%s"/></linearGradient>'
	) % [m.call(4), m.call(2), m.call(1)]
	out += '<linearGradient id="cr_band" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % [m.call(3), m.call(1)]
	out += '<radialGradient id="cr_pearl" cx="0.35" cy="0.35" r="0.7"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></radialGradient>' % [argent, m.call(2)]
	out += (
		'<linearGradient id="mt_outer" x1="0" y1="0" x2="1" y2="1">'
		+ '<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>'
	) % [_hx(Color(ma).lightened(0.12)), _hx(Color(ma).darkened(0.35))]
	out += (
		'<linearGradient id="sp_body" x1="0" y1="0" x2="1" y2="1">'
		+ '<stop offset="0" stop-color="%s"/><stop offset="0.5" stop-color="%s"/>'
		+ '<stop offset="1" stop-color="%s"/></linearGradient>'
	) % [str(sup.get("light", argent)), str(sup.get("body", argent)), str(sup.get("deep", _ink()))]
	out += "</defs>"
	return out.replace("{B}", mb)

static func _shield_group(s: Dictionary) -> String:
	var shape := shield_path(str(s.get("shield_shape", "heater")))
	var out := '<clipPath id="cp_shield"><path d="%s"/></clipPath>' % shape
	out += '<path d="%s" fill="%s" opacity="0.35" transform="translate(4,6)"/>' % [shape, _ink()]
	out += '<g clip-path="url(#cp_shield)">%s</g>' % shield_content(s)
	out += _material(shape, str(s.get("border", "none")), str(s.get("border_color", CKHeraldry.tincture_hex("bleu_celeste"))))
	return out

static func _svg_doc(w: int, h: int, vb: Vector2, body: String) -> String:
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %.0f %.0f" preserveAspectRatio="xMidYMid meet">%s</svg>' % [w, h, vb.x, vb.y, body]

static func shield_svg(s: Dictionary, w: int, h: int) -> String:
	var body := _defs(s) + '<g transform="translate(6,4)">' + _shield_group(s) + "</g>"
	return _svg_doc(w, h, Vector2(214, 254), body)

# ---------------------------------------------------------------- full achievement

static func arms_svg(s: Dictionary, w: int, h: int) -> String:
	var L := lib()
	var gv := _global_vars()
	var ach: Dictionary = s.get("achievement", {})
	var helm := str(ach.get("helm", "none"))
	var crown := str(ach.get("crown", "none"))
	var motto := str(ach.get("motto", "")).strip_edges()
	var sups: Array = _supporters_for(s)
	var has_sup := not sups.is_empty()
	var mant_vars := gv.duplicate()
	var ma := str(ach.get("mantling_a", s.get("field_a", "")))
	var mb := str(ach.get("mantling_b", s.get("field_b", "")))
	mant_vars["{A}"] = ma
	mant_vars["{AL}"] = _hx(Color(ma).lightened(0.45))
	mant_vars["{AD}"] = _hx(Color(ma).darkened(0.35))
	mant_vars["{B}"] = mb if mb != "" else CKHeraldry.tincture_hex("argent")
	var body := _defs(s)
	# Shield at (185,236) scale 1.15 → 230x276; helm centred x=300.
	var sh_tf := 'transform="translate(185,236) scale(1.15)"'
	if helm != "none":
		body += '<g transform="translate(300,184) scale(0.92) translate(-300,-80)">%s</g>' % _sub(str(L.get("mantling", "")), mant_vars)
	if has_sup:
		var tones := gv.duplicate()
		body += _compartment()
		body += '<g transform="translate(34,282) scale(0.82)">%s</g>' % _sub(str((L.get("supporters", {}) as Dictionary).get(sups[0], "")), tones)
		body += '<g transform="translate(566,282) scale(-0.82,0.82)">%s</g>' % _sub(str((L.get("supporters", {}) as Dictionary).get(sups[1], "")), tones)
	body += "<g %s>%s</g>" % [sh_tf, _shield_group(s)]
	if helm != "none":
		body += '<g transform="translate(300,176) scale(0.72) translate(-100,-100)">%s</g>' % _sub(str((L.get("helms", {}) as Dictionary).get(helm, "")), gv)
		if crown != "none":
			body += '<g transform="translate(300,86) scale(0.58) translate(-100,-55)">%s</g>' % _sub(str((L.get("crowns", {}) as Dictionary).get(crown, "")), gv)
	elif crown != "none":
		body += '<g transform="translate(300,206) scale(0.82) translate(-100,-70)">%s</g>' % _sub(str((L.get("crowns", {}) as Dictionary).get(crown, "")), gv)
	if motto != "":
		body += _ribbon(motto, 300.0, 662.0 if has_sup else 572.0)
	var top := 20.0 if crown != "none" or helm != "none" else 200.0
	var bottom := 716.0 if motto != "" else (620.0 if has_sup else 540.0)
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 %.0f 600 %.0f" preserveAspectRatio="xMidYMid meet">%s</svg>' % [w, h, top, bottom - top, body]

static func _supporters_for(s: Dictionary) -> Array:
	var ach: Dictionary = s.get("achievement", {})
	var raw: Array = ach.get("supporters", [])
	var any := false
	for r in raw:
		if str(r) != "" and str(r) != "none":
			any = true
	if not any:
		return []
	var L := lib()
	var by_nation: Dictionary = L.get("nation_supporters", {})
	var lib_sups: Dictionary = L.get("supporters", {})
	var pair: Array = by_nation.get(str(s.get("nation", "")), ["stag", "stag"])
	var out: Array = []
	for i in range(2):
		var want := str(raw[i]) if i < raw.size() else "none"
		out.append(want if lib_sups.has(want) else str(pair[i]))
	return out

static func _compartment() -> String:
	var c: Dictionary = lib().get("compartment", {})
	var out := (
		'<path d="M40,580 C90,556 170,560 230,566 L370,566 C430,560 510,556 560,580 '
		+ 'L548,612 C470,626 130,626 52,612 Z" fill="%s" stroke="%s" stroke-width="3.4" stroke-linejoin="round"/>'
	) % [str(c.get("side", "")), _ink()]
	out += (
		'<path d="M40,580 C90,556 170,560 230,566 L370,566 C430,560 510,556 560,580 '
		+ 'C500,574 420,578 300,580 C180,578 100,574 40,580 Z" fill="%s" stroke="%s" stroke-width="2" stroke-linejoin="round"/>'
	) % [str(c.get("top", "")), _ink()]
	for x in [96, 168, 262, 344, 432, 506]:
		out += '<path d="M%d,586 l10,-14 l8,16 Z" fill="%s" stroke="%s" stroke-width="1.6" opacity="0.9"/>' % [x, str(c.get("ice", "")), _ink()]
	return out

# ---------------------------------------------------------------- motto ribbon with real glyph outlines

static func _ribbon(text: String, cx: float, cy: float) -> String:
	var r: Dictionary = lib().get("ribbon", {})
	var face := str(r.get("face", CKHeraldry.tincture_hex("argent")))
	var shade := str(r.get("shade", face))
	var back := str(r.get("back", _ink()))
	var font_px := 34
	var glyphs := text_path(text, 120)
	var gk := float(font_px) / 120.0
	var tw := maxf(160.0, float(glyphs.get("width", 0.0)) * gk + 70.0)
	var hw := tw * 0.5
	var out := ""
	# Folded tails behind.
	out += '<path d="M%.1f,%.1f l-46,-6 l18,26 l-18,26 l58,-6 Z" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % [cx - hw + 10, cy - 14, back, _ink()]
	out += '<path d="M%.1f,%.1f l46,-6 l-18,26 l18,26 l-58,-6 Z" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % [cx + hw - 10, cy - 14, back, _ink()]
	# Main face with gentle arc.
	out += '<path d="M%.1f,%.1f Q%.1f,%.1f %.1f,%.1f L%.1f,%.1f Q%.1f,%.1f %.1f,%.1f Z" fill="%s" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % [
		cx - hw, cy - 26, cx, cy - 40, cx + hw, cy - 26, cx + hw, cy + 22, cx, cy + 8, cx - hw, cy + 22, face, _ink()]
	out += '<path d="M%.1f,%.1f Q%.1f,%.1f %.1f,%.1f" fill="none" stroke="%s" stroke-width="2.4" opacity="0.8"/>' % [cx - hw + 6, cy + 14, cx, cy + 0, cx + hw - 6, cy + 14, shade]
	if str(glyphs.get("d", "")) != "":
		var tx := cx - float(glyphs.width) * gk * 0.5
		var ty := cy + font_px * 0.12
		out += '<path d="%s" transform="translate(%.1f,%.1f) scale(%.4f)" fill="%s"/>' % [glyphs.d, tx, ty, gk, str(r.get("text", _ink()))]
	return out

static func _motto_font() -> FontFile:
	if _font == null and ResourceLoader.exists(MOTTO_FONT):
		_font = load(MOTTO_FONT) as FontFile
	return _font

static func text_path(text: String, px: int) -> Dictionary:
	## Converts text to an SVG path via TextServer glyph contours (baseline at y=0).
	var f := _motto_font()
	if f == null:
		return {"d": "", "width": 0.0}
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = f.get_rids()[0]
	var size := Vector2i(px, 0)
	var x := 0.0
	var d := ""
	var spacing := px * 0.12
	for i in range(text.length()):
		var cp := text.unicode_at(i)
		var gi := ts.font_get_glyph_index(rid, px, cp, 0)
		if gi == 0:
			continue
		var cont: Dictionary = ts.font_get_glyph_contours(rid, px, gi)
		d += _contours_to_path(cont, x)
		x += ts.font_get_glyph_advance(rid, px, gi).x + spacing
	return {"d": d, "width": maxf(0.0, x - spacing)}

static func _contours_to_path(cont: Dictionary, ox: float) -> String:
	var pts: PackedVector3Array = cont.get("points", PackedVector3Array())
	var ends: PackedInt32Array = cont.get("contours", PackedInt32Array())
	var out := ""
	var start := 0
	for e in ends:
		out += _contour(pts, start, int(e), ox)
		start = int(e) + 1
	return out

static func _contour(pts: PackedVector3Array, a: int, b: int, ox: float) -> String:
	## FreeType tags: 1 = on-curve, 0 = conic control, 2 = cubic control.
	var n := b - a + 1
	if n < 2:
		return ""
	var first := -1
	for i in range(n):
		if int(pts[a + i].z) == 1:
			first = i
			break
	var P := func(i: int) -> Vector3: return pts[a + ((i % n) + n) % n]
	var s := ""
	var start_pt: Vector2
	if first == -1:
		var p0: Vector3 = P.call(0)
		var p1: Vector3 = P.call(1)
		start_pt = Vector2((p0.x + p1.x) * 0.5, (p0.y + p1.y) * 0.5)
		first = 0
	else:
		var q: Vector3 = P.call(first)
		start_pt = Vector2(q.x, q.y)
	s += "M%.2f,%.2f " % [start_pt.x + ox, start_pt.y]
	var i := 1
	while i <= n:
		var cur: Vector3 = P.call(first + i)
		var tag := int(cur.z)
		if tag == 1:
			s += "L%.2f,%.2f " % [cur.x + ox, cur.y]
			i += 1
		elif tag == 2:
			var c2: Vector3 = P.call(first + i + 1)
			var end: Vector3 = P.call(first + i + 2)
			s += "C%.2f,%.2f %.2f,%.2f %.2f,%.2f " % [cur.x + ox, cur.y, c2.x + ox, c2.y, end.x + ox, end.y]
			i += 3
		else:
			var nxt: Vector3 = P.call(first + i + 1)
			var endp := Vector2(nxt.x, nxt.y)
			var step := 2
			if int(nxt.z) == 0:
				endp = Vector2((cur.x + nxt.x) * 0.5, (cur.y + nxt.y) * 0.5)
				step = 1
			s += "Q%.2f,%.2f %.2f,%.2f " % [cur.x + ox, cur.y, endp.x + ox, endp.y]
			i += step
	return s + "Z "

# ---------------------------------------------------------------- banner (cloth on a pole)

static func banner_svg(s: Dictionary, w: int, h: int, wave: float) -> String:
	var bl: Dictionary = lib().get("banner", {})
	var ph := wave * TAU
	var body := _defs(s)
	# Cloth box 160x200 at (40,30); wavy right edge + swallowtail.
	var edge := ""
	for k in range(0, 11):
		var y := 30.0 + k * 20.0
		edge += "L%.1f,%.1f " % [200.0 + sin(ph + k * 0.6) * 4.0, y]
	var cloth := "M40,30 %s L200,230 L120,206 L40,230 Z" % edge
	body += '<clipPath id="cp_cloth"><path d="%s"/></clipPath>' % cloth
	body += '<path d="%s" fill="%s" opacity="0.35" transform="translate(4,5)"/>' % [cloth, _ink()]
	body += '<g clip-path="url(#cp_cloth)"><g transform="translate(40,30) scale(0.8,0.833)">%s</g>' % shield_content(s)
	for k in range(4):
		var x := 60.0 + k * 40.0 + sin(ph + k) * 6.0
		body += '<rect x="%.1f" y="20" width="18" height="230" fill="%s" opacity="0.10"/>' % [x, CKHeraldry.tincture_hex("argent")]
		body += '<rect x="%.1f" y="20" width="10" height="230" fill="%s" opacity="0.14"/>' % [x + 20, _ink()]
	body += "</g>"
	body += '<path d="%s" fill="none" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % [cloth, _ink()]
	body += '<rect x="30" y="14" width="9" height="300" rx="3" fill="%s" stroke="%s" stroke-width="2"/>' % [str(bl.get("pole_lit", "")), _ink()]
	body += '<rect x="30" y="24" width="174" height="7" rx="3" fill="%s" stroke="%s" stroke-width="2"/>' % [str(bl.get("pole_lit", "")), _ink()]
	body += '<path d="M34.5,0 L42,12 L34.5,20 L27,12 Z" fill="%s" stroke="%s" stroke-width="2"/>' % [str(bl.get("finial", "")), _ink()]
	return _svg_doc(w, h, Vector2(220, 320), body)

static func _diaper() -> String:
	## Tone-on-tone lozenge diapering: reads as enamel / embroidery up close, invisible at icon size.
	var d := ""
	for k in range(-12, 13):
		var x := k * 22.0
		d += "M%.1f,-10 L%.1f,250 M%.1f,-10 L%.1f,250 " % [x, x + 130.0, x + 130.0, x]
	var out := '<path d="%s" fill="none" stroke="%s" stroke-width="0.9" opacity="0.10"/>' % [d, CKHeraldry.tincture_hex("argent")]
	out += '<path d="%s" fill="none" stroke="%s" stroke-width="0.9" opacity="0.06" transform="translate(1.2,1.2)"/>' % [d, _ink()]
	return out
