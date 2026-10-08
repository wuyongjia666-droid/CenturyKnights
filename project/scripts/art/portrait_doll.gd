class_name CKPortraitDoll
extends RefCounted
## v8.7 runtime paper-doll portrait (docs/art/character-system-v87.md section 2).
## Composes edit-diff parts (assets/art/doll/) from the genome phenotype. CPU compose at SIZE, cached per look-hash
## (memory + user://doll_cache). Named heroes keep bespoke busts; this serves recruits, children, NPCs.
const DIR := "res://assets/art/doll/"
const SIZE := 384
const HAIR_STYLES := {"m": ["crop", "swept", "tied", "messy"], "f": ["long", "pony", "bob", "crown"]}
const SCAR_SLOT := {"cheek_l": "scar_cheek_l", "cheek_r": "scar_cheek_l", "brow_l": "scar_brow_r", "brow_r": "scar_brow_r", "chin": "scar_chin", "neck": "scar_chin"}
static var _cache: Dictionary = {}

static func available(bloodline: String, gender: String) -> bool:
	return ResourceLoader.exists(DIR + "%s_%s/base.png" % [bloodline, gender])

static func _img(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var t: Texture2D = load(path)
	if t == null:
		return null
	var im: Image = t.get_image()
	if im == null:
		return null
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	if im.get_width() != SIZE:
		im.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	return im

static func _over(dst: Image, src: Image) -> void:
	if src != null:
		dst.blend_rect(src, Rect2i(0, 0, SIZE, SIZE), Vector2i.ZERO)

## neutral luminance part -> genome colour (shadow 0.28x .. highlight toward frost white), alpha kept
static func _gradient(src: Image, col: Color, strength: float = 1.0) -> Image:
	if src == null:
		return null
	var d: PackedByteArray = src.get_data()
	var r0 := col.r
	var g0 := col.g
	var b0 := col.b
	for i in range(0, d.size(), 4):
		var a := d[i + 3]
		if a == 0:
			continue
		var l := float(d[i]) / 255.0
		var k := 0.28 + 1.05 * l
		var hi := clampf((l - 0.78) * 3.0, 0.0, 1.0) * 0.55
		d[i] = int(clampf(lerpf(r0 * k, 0.957, hi), 0.0, 1.0) * 255.0)
		d[i + 1] = int(clampf(lerpf(g0 * k, 0.969, hi), 0.0, 1.0) * 255.0)
		d[i + 2] = int(clampf(lerpf(b0 * k, 0.984, hi), 0.0, 1.0) * 255.0)
		d[i + 3] = int(float(a) * strength)
	return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, d)

## iris mask (white, alpha) x base luminance -> eye colour overlay
static func _iris(base: Image, mask: Image, col: Color) -> Image:
	if mask == null:
		return null
	var m: PackedByteArray = mask.get_data()
	var b: PackedByteArray = base.get_data()
	var out := PackedByteArray()
	out.resize(m.size())
	for i in range(0, m.size(), 4):
		var a := m[i + 3]
		if a == 0:
			continue
		var l := (0.3 * float(b[i]) + 0.59 * float(b[i + 1]) + 0.11 * float(b[i + 2])) / 255.0
		var k := 0.35 + 1.25 * l
		out[i] = int(clampf(col.r * k, 0.0, 1.0) * 255.0)
		out[i + 1] = int(clampf(col.g * k, 0.0, 1.0) * 255.0)
		out[i + 2] = int(clampf(col.b * k, 0.0, 1.0) * 255.0)
		out[i + 3] = int(float(a) * 0.85)
	return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, out)

## second-bloodline face crossfade limited to an ellipse around the face (eyes/nose/jaw), weight w
static func _blend_face(dst: Image, other: Image, w: float) -> void:
	if other == null or w <= 0.0:
		return
	var d: PackedByteArray = dst.get_data()
	var o: PackedByteArray = other.get_data()
	var cx := 0.5 * SIZE
	var cy := 0.36 * SIZE
	var rx := 0.20 * SIZE
	var ry := 0.24 * SIZE
	for y in SIZE:
		var dy := (float(y) - cy) / ry
		for x in SIZE:
			var dx := (float(x) - cx) / rx
			var e := dx * dx + dy * dy
			if e >= 1.0:
				continue
			var t := w * (1.0 - smoothstep(0.55, 1.0, e))
			var i := (y * SIZE + x) * 4
			for c in 3:
				d[i + c] = int(lerpf(float(d[i + c]), float(o[i + c]), t))
	dst.set_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, d)

static func look_hash(c: Object, ph: Dictionary) -> String:
	var key := "%s|%s|%s|%s|%.2f|%s|%s|%s|%s|%s|%s|%s" % [ph["bloodline"], ph["bloodline2"], ph["gender"], ph["age_stage"], ph["bloodline2_w"],
		ph["hair_color"].to_html(false), ph["eye_color"].to_html(false), ph["loci"]["brow"]["id"], ph["loci"]["ears"]["id"],
		ph["loci"]["mark"]["id"], ",".join(c.scars), ",".join(c.honors) + "|" + str(c.job_id) + "|" + _style(c)]
	return str(key.hash())

static func _style(c: Object) -> String:
	var g := "f" if str(c.gender) == "f" else "m"
	var arr: Array = HAIR_STYLES[g]
	return str(arr[absi(hash(str(c.id) + "hair")) % arr.size()])

static func compose(c: Object) -> Texture2D:
	if not c.has_method("ensure_genome"):
		return null
	c.ensure_genome()
	var ph := CKGenome.phenotype(c)
	var bl := str(ph["bloodline"])
	var g := "f" if str(c.gender) == "f" else "m"
	if not available(bl, g):
		return null
	var key := look_hash(c, ph)
	if _cache.has(key):
		return _cache[key]
	var cache_path := "user://doll_cache/%s.png" % key
	if FileAccess.file_exists(cache_path):
		var ci := Image.load_from_file(cache_path)
		if ci != null:
			var ct := ImageTexture.create_from_image(ci)
			_cache[key] = ct
			return ct
	var d := DIR + "%s_%s/" % [bl, g]
	var stage := str(ph["age_stage"])
	var base: Image = null
	if stage != "adult":
		base = _img(d + stage + ".png")
	if base == null:
		base = _img(d + "base.png")
	if base == null:
		return null
	var b2 := str(ph["bloodline2"])
	if b2 != "" and available(b2, g):
		_blend_face(base, _img(DIR + "%s_%s/%s.png" % [b2, g, "base" if stage == "adult" else stage]), clampf(float(ph["bloodline2_w"]) * 1.1, 0.0, 0.6))
	var out := base.duplicate() as Image
	_over(out, _img(DIR + "outfit/%s_t1_%s.png" % [str(c.job_id), g]))
	if ph["loci"]["ears"]["id"] == "crest":
		_over(out, _img(d + "ears_crest.png"))
	_over(out, _iris(base, _img(d + "iris_mask.png"), ph["eye_color"]))
	if ph["loci"]["eyes"]["id"] == "rime":
		_over(out, _gradient(_img(d + "iris_mask.png"), Color("#E8FAFF"), 0.35))
	var hc: Color = ph["hair_color"]
	_over(out, _gradient(_img(d + "brow_%s.png" % ph["loci"]["brow"]["id"]), hc.darkened(0.25)))
	var mk := str(ph["loci"]["mark"]["id"])
	if mk != "none":
		var mimg := _img(d + "mark_%s.png" % mk)
		if mimg != null and float(ph["loci"]["mark"]["strength"]) < 1.0:
			mimg = _gradient(mimg, Color(1, 1, 1), float(ph["loci"]["mark"]["strength"]))
		_over(out, mimg)
	for s in c.scars:
		_over(out, _img(d + "%s.png" % SCAR_SLOT.get(str(s), "scar_cheek_l")))
	_over(out, _gradient(_img(d + "hair_%s.png" % _style(c)), hc))
	for h in c.honors:
		_over(out, _img(DIR + "honor/%s_%s.png" % [str(h), g]))
	DirAccess.make_dir_recursive_absolute("user://doll_cache")
	out.save_png(cache_path)
	var tex := ImageTexture.create_from_image(out)
	_cache[key] = tex
	return tex
