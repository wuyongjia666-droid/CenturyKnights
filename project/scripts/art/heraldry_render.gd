class_name CKHeraldryRender
extends RefCounted
## Premium procedural heraldry renderer. Supersampled polygons, frost sheen, enamel edge.
## All colours come from the arms spec / heraldry_v2.json — no hex literals here.

const SS := 2  ## supersample factor

static func compose_texture(spec: Dictionary, w: int = 160, h: int = 220, wave: float = 0.0, mode: String = "banner") -> Texture2D:
	return ImageTexture.create_from_image(compose(spec, w, h, wave, mode))

static func compose(spec: Dictionary, w: int = 160, h: int = 220, wave: float = 0.0, mode: String = "banner") -> Image:
	# Art pass 2: anti-aliased vector renderer (ThorVG). Lazy-loaded so boot stays lean.
	var vec_script: GDScript = load("res://scripts/art/heraldry_vector.gd") as GDScript
	if vec_script != null:
		var vec: RefCounted = vec_script.new()
		if not vec.call("lib").is_empty():
			return vec.call("render", spec, w, h, mode, wave)
	var s := CKHeraldry.normalize(spec)
	match mode:
		"shield":
			return _compose_shield(s, w, h, true)
		"arms":
			return _compose_achievement(s, w, h)
		_:
			return _compose_banner(s, w, h, wave)

static func _compose_banner(s: Dictionary, w: int, h: int, wave: float) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var table := CKHeraldry.table()
	var poles: Array = table.get("pole", [])
	var pole_dark := Color(str(poles[0])) if poles.size() > 0 else Color(0.23, 0.27, 0.33)
	var pole_lit := Color(str(poles[1])) if poles.size() > 1 else Color(0.42, 0.46, 0.52)
	var pole_x := int(w * 0.10)
	_rect(img, pole_x - 2, int(h * 0.04), 5, int(h * 0.88), pole_dark)
	_rect(img, pole_x - 1, int(h * 0.04), 3, int(h * 0.88), pole_lit)
	# Always paint on a rectangular cloth (nation shield shape is for shield/arms modes).
	var cloth_x := pole_x + 4
	var cloth_w := int(w * 0.72)
	var cloth_y := int(h * 0.08)
	var cloth_h := int(h * 0.62)
	var cloth_spec := s.duplicate(true)
	cloth_spec["shield_shape"] = "heater"
	# Build supersampled rectangular field without heater taper: use round mask? Better: custom rect mask.
	var arms := _compose_cloth(cloth_spec, cloth_w, cloth_h)
	for yy in range(cloth_h):
		var wobble := int(sin((yy * 0.11) + wave * TAU) * (1.5 + 1.5 * sin(wave * TAU)))
		# Soft swallowtail fade at bottom.
		var tail_fade := 1.0
		if yy > int(cloth_h * 0.82):
			var tf := float(yy - int(cloth_h * 0.82)) / float(maxi(1, cloth_h - int(cloth_h * 0.82)))
			tail_fade = 1.0 - tf * 0.15
		for xx in range(cloth_w):
			var src := arms.get_pixel(xx, yy)
			if src.a < 0.04:
				continue
			# Swallowtail notch near bottom center.
			if yy > int(cloth_h * 0.78):
				var u := absf(float(xx) / float(maxi(1, cloth_w - 1)) - 0.5)
				var depth := float(yy - int(cloth_h * 0.78)) / float(maxi(1, cloth_h - int(cloth_h * 0.78)))
				if u < 0.12 * depth:
					continue
			var dx := cloth_x + xx + wobble
			var dy := cloth_y + yy
			if dx < 0 or dy < 0 or dx >= w or dy >= h:
				continue
			var shade := (1.0 - 0.12 * (float(xx) / float(maxi(1, cloth_w)))) * tail_fade
			# Vertical sheen stripe.
			var sheen_w := clampf(1.0 - absf(float(xx) / float(maxi(1, cloth_w)) - 0.28) * 3.0, 0.0, 1.0) * 0.08
			src = Color(
				clampf(src.r * shade + sheen_w, 0.0, 1.0),
				clampf(src.g * shade + sheen_w, 0.0, 1.0),
				clampf(src.b * shade + sheen_w * 0.9, 0.0, 1.0),
				src.a
			)
			img.set_pixel(dx, dy, src)
	# Finial.
	_fill_ellipse(img, pole_x, int(h * 0.04), 4, 4, pole_lit)
	return img

static func _compose_cloth(s: Dictionary, w: int, h: int) -> Image:
	## Rectangular cloth arms (no shield outline taper).
	var sw := w * SS
	var sh := h * SS
	var hi := Image.create(sw, sh, false, Image.FORMAT_RGBA8)
	hi.fill(Color(0, 0, 0, 0))
	var mask := PackedByteArray()
	mask.resize(sw * sh)
	for i in range(sw * sh):
		mask[i] = 1
	_paint_field(hi, mask, s)
	_paint_ordinary(hi, mask, s)
	_paint_charges(hi, mask, s)
	_paint_border_ornament(hi, mask, s)
	_paint_castle_mark(hi, mask, s)
	_apply_material(hi, mask, s)
	# Thin frost rim on cloth edges.
	var ink := Color(str(CKHeraldry.table().get("outline", CKHeraldry.tincture_hex("sable"))))
	ink.a = 0.55
	var cw := hi.get_width()
	var ch := hi.get_height()
	for y in range(ch):
		for x in range(cw):
			if x < 2 or y < 2 or x >= cw - 2 or y >= ch - 2:
				hi.set_pixel(x, y, ink)
	return _downsample(hi, w, h)

static func _compose_achievement(s: Dictionary, w: int, h: int) -> Image:
	## Shield + optional helm/crown/mantling/supporters/motto.
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ach: Dictionary = s.get("achievement", {})
	var has_top := str(ach.get("helm", "none")) != "none" or str(ach.get("crown", "none")) != "none"
	var has_motto := str(ach.get("motto", "")).strip_edges() != ""
	var has_sup := false
	var sups: Array = ach.get("supporters", [])
	for sp in sups:
		if str(sp) != "none" and str(sp) != "":
			has_sup = true
			break
	var top_h := int(h * 0.18) if has_top else int(h * 0.04)
	var bot_h := int(h * 0.14) if has_motto else int(h * 0.04)
	var side := int(w * 0.16) if has_sup else int(w * 0.08)
	var shield_w := w - side * 2
	var shield_h := h - top_h - bot_h
	var shield := _compose_shield(s, shield_w, shield_h, true)
	_blit(img, shield, side, top_h)
	if has_top:
		_paint_helm_crown(img, s, side, 0, shield_w, top_h + int(shield_h * 0.12))
	if has_sup:
		_paint_supporter(img, s, 2, top_h + int(shield_h * 0.15), side - 2, int(shield_h * 0.7), false)
		_paint_supporter(img, s, w - side, top_h + int(shield_h * 0.15), side - 2, int(shield_h * 0.7), true)
	if has_motto:
		_paint_motto_scroll(img, s, int(w * 0.08), h - bot_h, int(w * 0.84), bot_h - 2)
	return img

static func _compose_shield(s: Dictionary, w: int, h: int, with_outline: bool) -> Image:
	var sw := w * SS
	var sh := h * SS
	var hi := Image.create(sw, sh, false, Image.FORMAT_RGBA8)
	hi.fill(Color(0, 0, 0, 0))
	var shape := str(s.get("shield_shape", "heater"))
	var mask := _shield_mask(sw, sh, shape)
	_paint_field(hi, mask, s)
	_paint_ordinary(hi, mask, s)
	_paint_charges(hi, mask, s)
	_paint_border_ornament(hi, mask, s)
	_paint_castle_mark(hi, mask, s)
	_apply_material(hi, mask, s)
	if with_outline:
		_paint_outline(hi, mask)
	# Downsample.
	return _downsample(hi, w, h)

static func _shield_mask(w: int, h: int, shape: String) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(w * h)
	var cx := w * 0.5
	var cy := h * 0.42
	for y in range(h):
		for x in range(w):
			var u := (float(x) + 0.5) / float(w)
			var v := (float(y) + 0.5) / float(h)
			var inside := false
			match shape:
				"round":
					var dx := (u - 0.5) * 2.0
					var dy := (v - 0.5) * 2.0
					inside = dx * dx + dy * dy <= 0.92
				"lozenge":
					inside = absf(u - 0.5) / 0.46 + absf(v - 0.5) / 0.48 <= 1.0
				"kite":
					# Pointed bottom, tapered top.
					var top := 0.06
					var bot := 0.96
					if v < top or v > bot:
						inside = false
					else:
						var t := (v - top) / (bot - top)
						var half := 0.42 * (1.0 - pow(t, 1.35))
						inside = absf(u - 0.5) <= half
				"banner":
					# Rectangular cloth with swallowtail cut.
					if u < 0.08 or u > 0.92 or v < 0.06 or v > 0.94:
						inside = false
					elif v > 0.78:
						var tail := absf(u - 0.5)
						inside = tail > 0.08 * ((v - 0.78) / 0.16) and tail < 0.42
					else:
						inside = true
				_:  # heater
					if v < 0.06 or v > 0.94:
						inside = false
					elif v < 0.55:
						inside = absf(u - 0.5) <= 0.44
					else:
						var t := (v - 0.55) / 0.39
						var half := 0.44 * (1.0 - t * t)
						inside = absf(u - 0.5) <= half
			mask[y * w + x] = 1 if inside else 0
	return mask

static func _paint_field(img: Image, mask: PackedByteArray, s: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var fa := Color(str(s.get("field_a", CKHeraldry.tincture_hex("slate"))))
	var fb := Color(str(s.get("field_b", CKHeraldry.tincture_hex("sable"))))
	var div := str(s.get("division", "solid"))
	var line := str(s.get("partition_line", "straight"))
	for y in range(h):
		for x in range(w):
			if mask[y * w + x] == 0:
				continue
			var u := float(x) / float(maxi(1, w - 1))
			var v := float(y) / float(maxi(1, h - 1))
			var use_b := _division_side(div, u, v, line)
			img.set_pixel(x, y, fb if use_b else fa)

static func _division_side(div: String, u: float, v: float, line: String) -> bool:
	var edge := 0.5
	var wobble := 0.0
	match line:
		"wavy":
			wobble = 0.04 * sin(u * TAU * 3.0 + v * 2.0)
		"engrailed":
			wobble = 0.03 * absf(sin(u * TAU * 6.0))
		"embattled":
			wobble = 0.04 if fmod(u * 10.0, 1.0) < 0.5 else -0.02
		"invected":
			wobble = -0.03 * absf(sin(u * TAU * 6.0))
		"nebuly":
			wobble = 0.05 * sin(u * TAU * 2.0) * cos(v * TAU * 2.0)
		_:
			wobble = 0.0
	match div:
		"per_pale":
			return u > edge + wobble
		"per_fess":
			return v > edge + wobble
		"per_bend":
			return v > u + wobble
		"per_bend_sinister":
			return v > (1.0 - u) + wobble
		"quarterly":
			return (u > 0.5) != (v > 0.5)
		"per_chevron":
			var chev := 1.0 - absf(u - 0.5) * 1.6
			return v > chev * 0.55 + 0.35 + wobble
		"per_saltire":
			return (v > u) != (v > 1.0 - u)
		"gyronny":
			var ang := atan2(v - 0.5, u - 0.5)
			return int(floor((ang + PI) / (PI * 0.25))) % 2 == 0
		_:
			return false

static func _paint_ordinary(img: Image, mask: PackedByteArray, s: Dictionary) -> void:
	var kind := str(s.get("ordinary", "none"))
	if kind == "none":
		return
	var col := Color(str(s.get("ordinary_tincture", s.get("charge_color", CKHeraldry.tincture_hex("argent")))))
	col.a = 0.96
	var w := img.get_width()
	var h := img.get_height()
	var thickness := 0.14
	for y in range(h):
		for x in range(w):
			if mask[y * w + x] == 0:
				continue
			var u := float(x) / float(maxi(1, w - 1))
			var v := float(y) / float(maxi(1, h - 1))
			if _ordinary_hit(kind, u, v, thickness):
				img.set_pixel(x, y, col)

static func _ordinary_hit(kind: String, u: float, v: float, t: float) -> bool:
	match kind:
		"fess":
			return absf(v - 0.48) < t * 0.55
		"pale", "pale_thin":
			var tw := t * (0.35 if kind == "pale_thin" else 0.55)
			return absf(u - 0.5) < tw
		"bend":
			return absf(v - u) < t * 0.45
		"bend_sinister":
			return absf(v - (1.0 - u)) < t * 0.45
		"chevron":
			var arm := absf(v - (0.72 - absf(u - 0.5) * 1.15))
			return arm < t * 0.35 and v < 0.78
		"cross":
			return absf(u - 0.5) < t * 0.4 or absf(v - 0.45) < t * 0.35
		"saltire":
			return absf(v - u) < t * 0.32 or absf(v - (1.0 - u)) < t * 0.32
		"chief":
			return v < 0.22
		"bordure":
			return u < 0.10 or u > 0.90 or v < 0.08 or v > 0.90
		"orle":
			var outer := u < 0.12 or u > 0.88 or v < 0.10 or v > 0.88
			var inner := u > 0.18 and u < 0.82 and v > 0.16 and v < 0.82
			return outer and not inner
		"pile":
			return absf(u - 0.5) < (0.42 * (1.0 - v)) and v < 0.85
		"pall":
			var a := absf(v - u * 0.7 - 0.15) < t * 0.3
			var b := absf(v - (1.0 - u) * 0.7 - 0.15) < t * 0.3
			var c := v > 0.45 and absf(u - 0.5) < t * 0.35
			return (a or b) and v < 0.55 or c
		_:
			return false

static func _paint_charges(img: Image, mask: PackedByteArray, s: Dictionary) -> void:
	var charges: Array = s.get("charges", [])
	if charges.is_empty():
		# Fall back to emblem.
		var emblem := str(s.get("emblem", ""))
		if emblem == "" or emblem == "none":
			return
		charges = [{"id": emblem, "tincture": str(s.get("emblem_color", "")), "placement": "center"}]
	var w := img.get_width()
	var h := img.get_height()
	for ch in charges:
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var cd: Dictionary = ch
		var id := str(cd.get("id", "ring"))
		if id == "chevron":
			id = "chevron_mark"
		elif id == "bend":
			id = "bend_mark"
		var col := Color(str(cd.get("tincture", s.get("emblem_color", CKHeraldry.tincture_hex("argent")))))
		var placement := str(cd.get("placement", "center"))
		var cx := 0.5
		var cy := 0.46
		match placement:
			"chief":
				cy = 0.22
			"base":
				cy = 0.72
			"dexter":
				cx = 0.28
			"sinister":
				cx = 0.72
		_stamp_charge(img, mask, id, cx, cy, col, mini(w, h), 0.22 if charges.size() <= 1 else 0.13)

static func _stamp_charge(img: Image, mask: PackedByteArray, id: String, cx: float, cy: float, col: Color, scale_px: int, r: float = 0.22) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var shape := id
	# Resolve shape from catalog if possible.
	for row in CKHeraldry.table().get("charges", []):
		if str((row as Dictionary).get("id", "")) == id:
			shape = str((row as Dictionary).get("shape", id))
			break
	for y in range(h):
		for x in range(w):
			if mask[y * w + x] == 0:
				continue
			var u := float(x) / float(maxi(1, w - 1))
			var v := float(y) / float(maxi(1, h - 1))
			var dx := (u - cx) / r
			var dy := (v - cy) / r
			if _charge_hit(shape, dx, dy):
				img.set_pixel(x, y, col)

static func _charge_hit(shape: String, dx: float, dy: float) -> bool:
	var d2 := dx * dx + dy * dy
	match shape:
		"ring":
			return d2 <= 1.0 and d2 >= 0.55
		"ring_thick":
			return d2 <= 1.0 and d2 >= 0.35
		"annulet":
			return d2 <= 0.85 and d2 >= 0.55
		"arc":
			return d2 <= 1.0 and d2 >= 0.6 and dy < 0.15
		"wave":
			return absf(dy - 0.25 * sin(dx * 3.2)) < 0.18 and absf(dx) < 1.1
		"diamond", "lozenge", "leaf":
			return absf(dx) + absf(dy) * 1.15 < 1.0
		"chevron":
			return absf(dy + 0.2 - absf(dx) * 0.9) < 0.22 and dy < 0.6
		"cross_spark", "spark":
			return (absf(dx) < 0.18 and absf(dy) < 1.0) or (absf(dy) < 0.18 and absf(dx) < 1.0)
		"filament":
			return (absf(dx) < 0.12 and absf(dy) < 1.0) or (d2 <= 0.55 and d2 >= 0.28 and dy < 0.1)
		"tide":
			return absf(dy + 0.45) < 0.12 and absf(dx) < 1.0 \
				or absf(dy) < 0.12 and absf(dx) < 0.75 \
				or absf(dy - 0.4) < 0.12 and absf(dx) < 0.45
		"notch":
			return (absf(dx + 0.7) < 0.15 and absf(dy) < 1.0) \
				or (absf(dy + 0.7) < 0.15 and dx > -0.7 and dx < 0.9) \
				or (absf(dy - 0.7) < 0.15 and dx > -0.7 and dx < 0.9)
		"bars":
			return (absf(dx + 0.7) < 0.16 and absf(dy) < 1.0) \
				or (absf(dx) < 0.16 and dy > -0.6) \
				or (absf(dx - 0.7) < 0.16 and dy > -0.3)
		"bend":
			return absf(dy - dx) < 0.22
		"mullet":
			# 5-point star approximation.
			var ang := atan2(dy, dx)
			var rad := sqrt(d2)
			var spike := 0.45 + 0.55 * absf(cos(ang * 2.5))
			return rad < spike and rad > 0.12
		"crescent":
			return d2 <= 1.0 and not ((dx - 0.25) * (dx - 0.25) + dy * dy <= 0.72)
		"tower":
			return (absf(dx) < 0.45 and dy > -0.2 and dy < 0.9) \
				or (absf(dx) < 0.7 and dy > -0.85 and dy < -0.2)
		"bridge":
			return (absf(dy - 0.15) < 0.12 and absf(dx) < 1.0) \
				or (absf(dx + 0.55) < 0.14 and dy > 0.15 and dy < 0.9) \
				or (absf(dx - 0.55) < 0.14 and dy > 0.15 and dy < 0.9)
		"lantern":
			var body := absf(dx) < 0.55 and dy > -0.15 and dy < 0.85 and (absf(dx) < 0.35 or dy < 0.55)
			var dome := d2 <= 0.42 and dy < -0.05 and dy > -0.85
			var hook := absf(dx) < 0.12 and dy < -0.55 and dy > -1.15
			var flame := absf(dx) < 0.18 and dy > 0.05 and dy < 0.45
			return body or dome or hook or flame
		"flake":
			return (absf(dx) < 0.12 and absf(dy) < 1.0) or (absf(dy) < 0.12 and absf(dx) < 1.0) \
				or absf(absf(dx) - absf(dy)) < 0.12 and d2 < 1.0
		"reed":
			return absf(dx - 0.15 * sin(dy * 4.0)) < 0.14 and absf(dy) < 1.0
		"anvil":
			return (absf(dy - 0.35) < 0.2 and absf(dx) < 0.9) \
				or (absf(dx) < 0.35 and dy > -0.7 and dy < 0.35) \
				or (absf(dy + 0.75) < 0.15 and absf(dx) < 0.7)
		"starbridge":
			return absf(dy - 0.2 * sin(dx * 2.5)) < 0.14 and absf(dx) < 1.1 \
				or (d2 <= 0.2)
		"zephyr", "plume":
			var stem := absf(dx) < 0.14 and dy > -0.2 and dy < 1.0
			var blade := absf(dy + 0.35 - absf(dx) * 0.55) < 0.28 and dy < 0.2 and absf(dx) < 1.05
			return stem or blade
		"crownlet":
			return (absf(dy - 0.2) < 0.18 and absf(dx) < 0.9) \
				or (absf(dx) < 0.15 and dy > -0.9 and dy < 0.2) \
				or (absf(dx - 0.55) < 0.12 and dy > -0.7 and dy < 0.2) \
				or (absf(dx + 0.55) < 0.12 and dy > -0.7 and dy < 0.2)
		"label":
			return (absf(dy + 0.55) < 0.18 and absf(dx) < 1.0) \
				or (absf(dx + 0.6) < 0.12 and dy > -0.55 and dy < 0.3) \
				or (absf(dx) < 0.12 and dy > -0.55 and dy < 0.3) \
				or (absf(dx - 0.6) < 0.12 and dy > -0.55 and dy < 0.3)
		"martlet":
			return (d2 <= 0.55 and dy < 0.2) or (absf(dy - 0.45) < 0.2 and absf(dx) < 0.9)
		"fleur":
			return d2 <= 0.35 or (absf(dx) < 0.2 and dy < 0.9 and dy > -0.2) \
				or ((dx - 0.55) * (dx - 0.55) + (dy + 0.1) * (dy + 0.1) <= 0.22) \
				or ((dx + 0.55) * (dx + 0.55) + (dy + 0.1) * (dy + 0.1) <= 0.22)
		"rose":
			var ang2 := atan2(dy, dx)
			var rad2 := sqrt(d2)
			return rad2 < 0.55 + 0.35 * absf(cos(ang2 * 2.0)) and rad2 > 0.12
		"cross_moline":
			return ((absf(dx) < 0.2 and absf(dy) < 1.0) or (absf(dy) < 0.2 and absf(dx) < 1.0)) \
				and not (absf(dx) > 0.55 and absf(dy) > 0.55)
		"octofoil":
			var ang3 := atan2(dy, dx)
			return sqrt(d2) < 0.5 + 0.4 * absf(cos(ang3 * 4.0))
		_:
			return d2 <= 0.85 and d2 >= 0.4

static func _paint_border_ornament(img: Image, mask: PackedByteArray, s: Dictionary) -> void:
	var kind := str(s.get("border", "none"))
	if kind == "none":
		return
	var col := Color(str(s.get("border_color", CKHeraldry.tincture_hex("bleu_celeste"))))
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h):
		for x in range(w):
			if mask[y * w + x] == 0:
				continue
			var edge := _is_mask_edge(mask, w, h, x, y, 3)
			if not edge:
				continue
			match kind:
				"line":
					if _is_mask_edge(mask, w, h, x, y, 2):
						img.set_pixel(x, y, col)
				"double":
					if _is_mask_edge(mask, w, h, x, y, 2) or (_is_mask_edge(mask, w, h, x, y, 5) and not _is_mask_edge(mask, w, h, x, y, 3)):
						img.set_pixel(x, y, col)
				"dentil":
					if _is_mask_edge(mask, w, h, x, y, 3):
						var u := float(x) / 8.0
						if fmod(u, 1.0) < 0.55:
							img.set_pixel(x, y, col)
				_:
					pass

static func _is_mask_edge(mask: PackedByteArray, w: int, h: int, x: int, y: int, dist: int) -> bool:
	if mask[y * w + x] == 0:
		return false
	for dy in range(-dist, dist + 1):
		for dx in range(-dist, dist + 1):
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				return true
			if mask[ny * w + nx] == 0:
				return true
	return false

static func _apply_material(img: Image, mask: PackedByteArray, s: Dictionary) -> void:
	## Soft top sheen + deterministic micro enamel noise + edge darken.
	var w := img.get_width()
	var h := img.get_height()
	var sheen := Color(str(CKHeraldry.table().get("sheen", CKHeraldry.tincture_hex("argent"))))
	var seed := int(CKHeraldry.cache_key(s).hash())
	for y in range(h):
		for x in range(w):
			if mask[y * w + x] == 0:
				continue
			var c := img.get_pixel(x, y)
			var v := float(y) / float(maxi(1, h - 1))
			var u := float(x) / float(maxi(1, w - 1))
			# Top-left cool sheen.
			var sheen_w := clampf(1.0 - (u * 0.55 + v * 0.9), 0.0, 1.0) * 0.18
			c = c.lerp(sheen, sheen_w)
			# Micro noise.
			var n := _hash_noise(x + seed, y - seed)
			c = Color(
				clampf(c.r + n * 0.03, 0.0, 1.0),
				clampf(c.g + n * 0.03, 0.0, 1.0),
				clampf(c.b + n * 0.025, 0.0, 1.0),
				c.a
			)
			# Edge darken for enamel lip.
			if _is_mask_edge(mask, w, h, x, y, 2):
				c = c.darkened(0.18)
			img.set_pixel(x, y, c)

static func _hash_noise(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177
	return (float(n & 0xffff) / 65535.0) * 2.0 - 1.0

static func _paint_outline(img: Image, mask: PackedByteArray) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var ink := Color(str(CKHeraldry.table().get("outline", CKHeraldry.tincture_hex("sable"))))
	ink.a = 0.92
	for y in range(h):
		for x in range(w):
			if mask[y * w + x] == 0:
				continue
			if _is_mask_edge(mask, w, h, x, y, 1):
				img.set_pixel(x, y, ink)

static func _paint_helm_crown(img: Image, s: Dictionary, x0: int, y0: int, bw: int, bh: int) -> void:
	var ach: Dictionary = s.get("achievement", {})
	var helm := str(ach.get("helm", "none"))
	var crown := str(ach.get("crown", "none"))
	var metal := Color(CKHeraldry.tincture_hex("or"))
	var lit := Color(CKHeraldry.tincture_hex("argent"))
	var ink := Color(str(CKHeraldry.table().get("outline", CKHeraldry.tincture_hex("sable"))))
	var cx := x0 + bw / 2
	var cy := y0 + int(bh * 0.58)
	if helm != "none":
		# Mantling ribbons first (behind helm).
		var ma := Color(str(ach.get("mantling_a", s.get("field_a", ""))))
		var mb := Color(str(ach.get("mantling_b", s.get("field_b", ""))))
		for i in range(8):
			var tt := float(i) / 7.0
			var lx := cx - int(bw * (0.16 + tt * 0.18))
			var ly := cy + int(bh * (0.02 + tt * 0.22))
			_fill_ellipse(img, lx, ly, int(bw * 0.07), int(bh * 0.05), ma.darkened(tt * 0.15))
			var rx := cx + int(bw * (0.16 + tt * 0.18))
			_fill_ellipse(img, rx, ly, int(bw * 0.07), int(bh * 0.05), mb.darkened(tt * 0.15))
		# Helmet bowl + visor.
		_fill_ellipse(img, cx, cy, int(bw * 0.17), int(bh * 0.30), metal.darkened(0.22))
		_fill_ellipse(img, cx, cy - 2, int(bw * 0.14), int(bh * 0.24), metal)
		_fill_ellipse(img, cx - 2, cy - 6, int(bw * 0.06), int(bh * 0.08), lit.darkened(0.05))
		if helm == "closed":
			_rect(img, cx - int(bw * 0.08), cy - int(bh * 0.02), int(bw * 0.16), 3, ink)
		elif helm == "grilled" or helm == "royal":
			for i in range(5):
				var gx := cx - int(bw * 0.09) + i * int(bw * 0.04)
				_rect(img, gx, cy - int(bh * 0.10), 2, int(bh * 0.20), ink)
			# Chin guard.
			_fill_ellipse(img, cx, cy + int(bh * 0.12), int(bw * 0.12), int(bh * 0.10), metal.darkened(0.1))
	if crown != "none":
		var cy2 := y0 + int(bh * 0.18)
		var base_w := int(bw * 0.30)
		_rect(img, cx - base_w / 2, cy2, base_w, int(bh * 0.09), metal)
		_rect(img, cx - base_w / 2, cy2, base_w, 2, lit)
		var peaks := 3 if crown in ["knight", "baron"] else (5 if crown != "royal" else 7)
		for i in range(peaks):
			var px := cx - base_w / 2 + int(float(i) * float(base_w) / float(maxi(1, peaks - 1)))
			var ph := int(bh * (0.16 if i % 2 == 0 or crown == "royal" else 0.10))
			_rect(img, px - 2, cy2 - ph, 4, ph, metal)
			_fill_ellipse(img, px, cy2 - ph, 3, 3, lit if crown != "royal" else Color(CKHeraldry.tincture_hex("azure")))
		if crown == "royal":
			_fill_ellipse(img, cx, cy2 - int(bh * 0.20), 4, 4, Color(CKHeraldry.tincture_hex("azure")))

static func _paint_supporter(img: Image, s: Dictionary, x0: int, y0: int, bw: int, bh: int, flip: bool) -> void:
	var col := Color(CKHeraldry.tincture_hex("slate"))
	var lit := Color(CKHeraldry.tincture_hex("cloud"))
	col.a = 0.9
	# Frost-beast: body, neck, head, legs, tail — geometric but readable.
	var dir := -1 if flip else 1
	var bx := x0 + bw / 2
	var by := y0 + int(bh * 0.48)
	_fill_ellipse(img, bx, by, int(bw * 0.32), int(bh * 0.26), col)
	var hx := bx + dir * int(bw * 0.22)
	var hy := y0 + int(bh * 0.22)
	_fill_ellipse(img, hx, hy, int(bw * 0.18), int(bh * 0.14), col)
	_fill_ellipse(img, hx + dir * int(bw * 0.10), hy - int(bh * 0.06), int(bw * 0.10), int(bh * 0.08), lit.darkened(0.15))
	# Ear / crest.
	_rect(img, hx + dir * 2, hy - int(bh * 0.18), 3, int(bh * 0.12), col)
	# Legs.
	_rect(img, bx - int(bw * 0.18), by + int(bh * 0.12), 4, int(bh * 0.32), col)
	_rect(img, bx + int(bw * 0.08), by + int(bh * 0.12), 4, int(bh * 0.30), col)
	_rect(img, bx - int(bw * 0.06), by + int(bh * 0.10), 4, int(bh * 0.34), col.darkened(0.08))
	# Tail curl.
	var tx := bx - dir * int(bw * 0.28)
	_fill_ellipse(img, tx, by + int(bh * 0.05), int(bw * 0.12), int(bh * 0.08), col)
	_fill_ellipse(img, tx - dir * int(bw * 0.08), by - int(bh * 0.06), int(bw * 0.08), int(bh * 0.06), col)

static func _paint_motto_scroll(img: Image, s: Dictionary, x0: int, y0: int, bw: int, bh: int) -> void:
	var scroll_col := Color(CKHeraldry.tincture_hex("cloud"))
	scroll_col.a = 0.94
	_fill_ellipse(img, x0 + 6, y0 + bh / 2, 8, bh / 2 - 1, scroll_col.darkened(0.12))
	_fill_ellipse(img, x0 + bw - 6, y0 + bh / 2, 8, bh / 2 - 1, scroll_col.darkened(0.12))
	_rect(img, x0 + 8, y0 + 3, bw - 16, bh - 6, scroll_col)
	var accent := Color(str(s.get("field_a", CKHeraldry.tincture_hex("azure"))))
	_rect(img, x0 + int(bw * 0.18), y0 + bh / 2 - 1, int(bw * 0.64), 2, accent)
	_rect(img, x0 + int(bw * 0.22), y0 + bh / 2 + 4, int(bw * 0.56), 1, accent.darkened(0.25))

static func _downsample(src: Image, w: int, h: int) -> Image:
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var sw := src.get_width()
	var sh := src.get_height()
	for y in range(h):
		for x in range(w):
			var r := 0.0
			var g := 0.0
			var b := 0.0
			var a := 0.0
			var n := 0.0
			for oy in range(SS):
				for ox in range(SS):
					var sx := mini(sw - 1, x * SS + ox)
					var sy := mini(sh - 1, y * SS + oy)
					var c := src.get_pixel(sx, sy)
					r += c.r * c.a
					g += c.g * c.a
					b += c.b * c.a
					a += c.a
					n += 1.0
			if a < 0.01:
				continue
			out.set_pixel(x, y, Color(r / a, g / a, b / a, a / n))
	return out

static func _blit(dst: Image, src: Image, x0: int, y0: int) -> void:
	for y in range(src.get_height()):
		for x in range(src.get_width()):
			var c := src.get_pixel(x, y)
			if c.a < 0.04:
				continue
			var dx := x0 + x
			var dy := y0 + y
			if dx < 0 or dy < 0 or dx >= dst.get_width() or dy >= dst.get_height():
				continue
			dst.set_pixel(dx, dy, c)

static func _rect(img: Image, x: int, y: int, rw: int, rh: int, col: Color) -> void:
	var W := img.get_width()
	var H := img.get_height()
	for yy in range(clampi(y, 0, H), clampi(y + rh, 0, H)):
		for xx in range(clampi(x, 0, W), clampi(x + rw, 0, W)):
			img.set_pixel(xx, yy, col)

static func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	var W := img.get_width()
	var H := img.get_height()
	for yy in range(cy - ry, cy + ry + 1):
		for xx in range(cx - rx, cx + rx + 1):
			if xx < 0 or yy < 0 or xx >= W or yy >= H:
				continue
			var dx := float(xx - cx) / float(maxi(1, rx))
			var dy := float(yy - cy) / float(maxi(1, ry))
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(xx, yy, col)

static var _rank_badge_cache: Dictionary = {}

static func rank_badge(rank: String, size: int = 28) -> Texture2D:
	## Genealogy title badge (coronet / pin per noble tier). Not cadency: title only.
	var badges: Dictionary = CKHeraldry.table().get("rank_badges", {})
	var key := "%s@%d" % [rank, size]
	if _rank_badge_cache.has(key):
		return _rank_badge_cache[key]
	if not badges.has(rank):
		return null
	var img := Image.new()
	if img.load_svg_from_string(str(badges[rank]), float(size) / 64.0) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_rank_badge_cache[key] = tex
	return tex

static func _paint_castle_mark(img: Image, mask: PackedByteArray, s: Dictionary) -> void:
	## Family arms: small dexter-chief canton carrying the host castle's field + charge.
	var mark = s.get("castle_mark", {})
	if typeof(mark) != TYPE_DICTIONARY or str((mark as Dictionary).get("field", "")) == "":
		return
	var md: Dictionary = mark
	var fill := Color(str(md.get("field", "")))
	var ink := Color(str(CKHeraldry.table().get("outline", CKHeraldry.tincture_hex("sable"))))
	var w := img.get_width()
	var h := img.get_height()
	var cw := 0.30
	var ch := 0.25
	for y in range(h):
		for x in range(w):
			if mask[y * w + x] == 0:
				continue
			var u := float(x) / float(maxi(1, w - 1))
			var v := float(y) / float(maxi(1, h - 1))
			if u > cw or v > ch:
				continue
			var edge := (cw - u) < 0.012 or (ch - v) < 0.012
			img.set_pixel(x, y, ink if edge else fill)
	var cid := str(md.get("charge", ""))
	if cid != "":
		_stamp_charge(img, mask, cid, cw * 0.5 + 0.02, ch * 0.5 + 0.03, Color(str(md.get("tincture", CKHeraldry.tincture_hex("argent")))), mini(w, h), 0.085)
