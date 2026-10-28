class_name CKHeraldry
extends RefCounted
## Castle heraldry API: tinctures, nation styles, rank-tiered achievement, v1 migrate.
## Company banner (团徽) is permanent; family arms (族徽) are per-family with a canton echo.
## No marriage marshalling / per-person cadency — genealogy shows 爵位徽记 separately.
## Colors live in heraldry_v2.json (style ratchet: no hex in this file).

const DATA_PATH := "res://assets/art/heraldry_v2.json"
const SCHEMA := 2

static var _data: Dictionary = {}
static var _ready := false
static var _vector_cache: Dictionary = {}

static func table() -> Dictionary:
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
	return table().get("palette", [])

static func color_names() -> Array:
	return table().get("color_names", [])

static func tincture(id: String) -> Dictionary:
	var all: Dictionary = table().get("tinctures", {})
	return all.get(id, {}) as Dictionary

static func tincture_hex(id: String) -> String:
	var t := tincture(id)
	return str(t.get("hex", ""))

static func tincture_class(id_or_hex: String) -> String:
	var key := str(id_or_hex).strip_edges().to_lower()
	var all: Dictionary = table().get("tinctures", {})
	if all.has(key):
		return str((all[key] as Dictionary).get("class", "colour"))
	var hx := key.trim_prefix("#")
	for tid in all.keys():
		var td: Dictionary = all[tid]
		if str(td.get("hex", "")).trim_prefix("#").to_lower() == hx:
			return str(td.get("class", "colour"))
	# Unknown hex: treat light as metal, dark as colour (fallback).
	var col := Color("#" + hx) if hx.length() == 6 else Color(0.4, 0.5, 0.6)
	return "metal" if col.get_luminance() >= 0.62 else "colour"

static func tincture_ok(a: String, b: String) -> bool:
	## Rule of tincture: metal may not lie on metal; colour may not lie on colour.
	## Furs are exempt and may neighbour either class.
	if str(a).strip_edges() == "" or str(b).strip_edges() == "":
		return true
	var ca := tincture_class(a)
	var cb := tincture_class(b)
	if ca == "fur" or cb == "fur":
		return true
	if ca == cb:
		return false
	return true

static func tincture_ok_spec(spec: Dictionary) -> Dictionary:
	## Returns {ok:bool, issues:PackedStringArray}.
	var s := normalize(spec)
	var issues: Array = []
	var field_a := str(s.get("field_a", ""))
	var field_b := str(s.get("field_b", ""))
	var division := str(s.get("division", "solid"))
	if division != "solid" and not tincture_ok(field_a, field_b):
		issues.append("field_ab")
	var ordinary := str(s.get("ordinary", "none"))
	if ordinary != "none":
		var ot := str(s.get("ordinary_tincture", s.get("charge_color", "")))
		if not tincture_ok(field_a, ot):
			issues.append("ordinary_on_field")
	var charges: Array = s.get("charges", [])
	for ch in charges:
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var ct := str((ch as Dictionary).get("tincture", ""))
		if ct != "" and not tincture_ok(field_a, ct):
			issues.append("charge_on_field")
			break
	var emblem := str(s.get("emblem", "none"))
	if emblem != "none" and emblem != "":
		var ec := str(s.get("emblem_color", ""))
		if ec != "" and not tincture_ok(field_a, ec):
			if not ("charge_on_field" in issues):
				issues.append("charge_on_field")
	return {"ok": issues.is_empty(), "issues": issues}

static func nation_style(nid: String) -> Dictionary:
	var nations: Dictionary = table().get("nations", {})
	if nations.has(nid):
		return (nations[nid] as Dictionary).duplicate(true)
	return (nations.get("ashbanner", {}) as Dictionary).duplicate(true)

static func division_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for d in table().get("divisions", []):
		out.append(str((d as Dictionary).get("id", "")))
	return out

static func ordinary_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for d in table().get("ordinaries", []):
		out.append(str((d as Dictionary).get("id", "")))
	return out

static func partition_line_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for d in table().get("partition_lines", []):
		out.append(str((d as Dictionary).get("id", "")))
	return out

static func charge_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for d in table().get("charges", []):
		out.append(str((d as Dictionary).get("id", "")))
	return out

static func border_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for d in table().get("borders", []):
		out.append(str((d as Dictionary).get("id", "")))
	return out

static func achievement_for_rank(rank: String, nid: String = "") -> Dictionary:
	var helm_map: Dictionary = table().get("rank_to_helm", {})
	var crown_map: Dictionary = table().get("rank_to_crown", {})
	var helm := str(helm_map.get(rank, "none"))
	var crown := str(crown_map.get(rank, "none"))
	var supporters: Array = ["none", "none"]
	if rank in ["duke", "royal"]:
		supporters = nation_supporter_pair(nid)
	return {
		"helm": helm,
		"crown": crown,
		"mantling_a": "",
		"mantling_b": "",
		"supporters": supporters,
		"motto": "",
	}


static func _vector_table() -> Dictionary:
	## Lazy read of heraldry_vector.json (nation_supporters / supporter art ids).
	if not _vector_cache.is_empty():
		return _vector_cache
	var f := FileAccess.open("res://assets/art/heraldry_vector.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			_vector_cache = parsed
	return _vector_cache


static func supporter_ids() -> PackedStringArray:
	## DIY order: none + six frost beasts from the vector library.
	var out := PackedStringArray(["none", "stag", "wolf", "crane", "eagle", "bear", "seadrake"])
	var lib_sups: Dictionary = _vector_table().get("supporters", {})
	for k in lib_sups.keys():
		var id := str(k)
		if id != "" and out.find(id) < 0:
			out.append(id)
	return out


static func nation_supporter_pair(nid: String) -> Array:
	var by: Dictionary = _vector_table().get("nation_supporters", {})
	var pair: Array = by.get(str(nid), ["stag", "stag"])
	if typeof(pair) != TYPE_ARRAY or pair.size() < 2:
		return ["stag", "stag"]
	var L := str(pair[0]).strip_edges()
	var R := str(pair[1]).strip_edges()
	if L == "" or L == "frost_beast" or L == "none":
		L = "stag"
	if R == "" or R == "frost_beast" or R == "none":
		R = "stag"
	return [L, R]


static func _sanitize_supporters(raw, nid: String = "") -> Array:
	var pair := nation_supporter_pair(nid)
	var out: Array = ["none", "none"]
	if typeof(raw) != TYPE_ARRAY:
		return out
	for i in range(2):
		var want := str(raw[i]) if i < raw.size() else "none"
		want = want.strip_edges()
		if want == "" or want == "frost_beast":
			# Legacy sentinel → real nation pair (or none when low rank left bare).
			want = str(pair[i]) if want == "frost_beast" else "none"
		if want != "none" and supporter_ids().find(want) < 0:
			want = str(pair[i])
		out[i] = want
	return out

static func _raw_defaults() -> Dictionary:
	var base: Dictionary = (table().get("defaults", {}) as Dictionary).duplicate(true)
	if base.is_empty():
		base = {"schema": SCHEMA, "field": "solid", "division": "solid", "field_a": "", "field_b": ""}
	return base

static func _hex(v, fallback: String) -> String:
	var s := str(v).strip_edges().to_lower()
	if s == "" or s == "#":
		s = fallback
	if s == "" or s == "#":
		s = tincture_hex("azure")
	if not s.begins_with("#"):
		s = "#" + s
	return "#" + BannerSpec._migrate_hex(s)

static func migrate_v1(raw: Dictionary) -> Dictionary:
	var base := _raw_defaults()
	for k in raw.keys():
		base[k] = raw[k]
	base["schema"] = SCHEMA
	var field_map: Dictionary = table().get("v1_field_to_division", {})
	var charge_map: Dictionary = table().get("v1_charge_to_ordinary", {})
	var field := str(base.get("field", "solid"))
	var had_division := raw.has("division")
	var had_ordinary := raw.has("ordinary")
	if had_division:
		base["division"] = str(base.get("division", "solid"))
	else:
		base["division"] = str(field_map.get(field, field))
	if not division_ids().has(str(base["division"])):
		base["division"] = "solid"
	var ch := str(base.get("charge", "none"))
	if had_ordinary:
		base["ordinary"] = str(base.get("ordinary", "none"))
	else:
		base["ordinary"] = str(charge_map.get(ch, ch))
	if not ordinary_ids().has(str(base["ordinary"])):
		base["ordinary"] = "none"
	base["ordinary_tincture"] = _hex(base.get("ordinary_tincture", base.get("charge_color", "")), str(base.get("charge_color", "")))
	base["partition_line"] = str(base.get("partition_line", "straight"))
	if not partition_line_ids().has(str(base["partition_line"])):
		base["partition_line"] = "straight"
	# Emblem → primary charge.
	var emblem := str(base.get("emblem", "ring"))
	var emblem_color := _hex(base.get("emblem_color", ""), "")
	var charges: Array = []
	if typeof(base.get("charges")) == TYPE_ARRAY and not (base["charges"] as Array).is_empty():
		charges = (base["charges"] as Array).duplicate(true)
	elif emblem != "" and emblem != "none":
		var cid := emblem
		if cid == "chevron":
			cid = "chevron_mark"
		elif cid == "bend":
			cid = "bend_mark"
		charges = [{"id": cid, "tincture": emblem_color, "placement": "center"}]
	base["charges"] = charges
	if not base.has("achievement") or typeof(base["achievement"]) != TYPE_DICTIONARY:
		base["achievement"] = _raw_defaults().get("achievement", {})
	else:
		var ach: Dictionary = (base["achievement"] as Dictionary).duplicate(true)
		var def_ach: Dictionary = _raw_defaults().get("achievement", {})
		for ak in def_ach.keys():
			if not ach.has(ak):
				ach[ak] = def_ach[ak]
		ach["supporters"] = _sanitize_supporters(ach.get("supporters", []), str(base.get("nation", "")))
		base["achievement"] = ach
	# Arms belong to the castle, not a person/marriage: drop legacy marshalling / cadency / bastardy.
	for legacy_key in ["marshalling", "cadency", "bastardy"]:
		base.erase(legacy_key)
	base["nation"] = str(base.get("nation", "ashbanner"))
	base["shield_shape"] = str(base.get("shield_shape", nation_style(str(base["nation"])).get("shield", "heater")))
	# Keep v1 aliases in sync.
	base["field"] = str(base["division"]) if str(base["division"]) in ["solid", "per_fess", "per_pale"] else "solid"
	base["charge"] = str(base["ordinary"]) if str(base["ordinary"]) in ["none", "fess", "pale", "bend", "chevron", "pale_thin"] else "none"
	base["charge_color"] = str(base["ordinary_tincture"])
	if not charges.is_empty() and typeof(charges[0]) == TYPE_DICTIONARY:
		base["emblem"] = str((charges[0] as Dictionary).get("id", "ring"))
		base["emblem_color"] = str((charges[0] as Dictionary).get("tincture", emblem_color))
	base["field_a"] = _hex(base.get("field_a", ""), "")
	base["field_b"] = _hex(base.get("field_b", ""), "")
	base["border"] = str(base.get("border", "line"))
	if not border_ids().has(str(base["border"])):
		base["border"] = "none"
	base["border_color"] = _hex(base.get("border_color", ""), "")
	var gc := str(base.get("glyph_char", "")).strip_edges()
	base["glyph_char"] = gc.left(1) if gc != "" else ""
	# Keep surname charge glyph in sync with spec.glyph_char.
	if str(base.get("emblem", "")) == "surname" and base["glyph_char"] != "":
		var synced: Array = []
		for c in base.get("charges", []):
			if typeof(c) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = (c as Dictionary).duplicate(true)
			if str(row.get("id", "")) == "surname":
				row["glyph"] = base["glyph_char"]
			synced.append(row)
		if synced.is_empty():
			synced = [{"id": "surname", "tincture": str(base.get("emblem_color", "")), "placement": "center", "glyph": base["glyph_char"]}]
		base["charges"] = synced
	return base

static func normalize(raw) -> Dictionary:
	var base := _raw_defaults()
	if typeof(raw) != TYPE_DICTIONARY:
		return migrate_v1(base)
	var d: Dictionary = raw
	if int(d.get("schema", 0)) < SCHEMA:
		return migrate_v1(d)
	# Already v2: fill missing keys then sanitize.
	for k in base.keys():
		if not d.has(k):
			d[k] = base[k]
	return migrate_v1(d)

static func from_crest(color: String) -> Dictionary:
	var base := _raw_defaults()
	var hx := str(color).strip_edges()
	if hx != "":
		if not hx.begins_with("#"):
			hx = "#" + hx
		base["field_a"] = _hex(hx, hx)
	return normalize(base)

static func from_nation(nid: String, rank: String = "knight") -> Dictionary:
	var st := nation_style(nid)
	var fa := tincture_hex(str(st.get("field_a", "azure")))
	var fb := tincture_hex(str(st.get("field_b", "sable")))
	var ot := tincture_hex(str(st.get("ordinary_tincture", "argent")))
	var chs: Array = []
	var preferred: Array = st.get("charges", [])
	if not preferred.is_empty():
		chs.append({"id": str(preferred[0]), "tincture": ot if ot != "" else fa, "placement": "center"})
		# Fix charge tincture against field.
		if not tincture_ok(fa, str((chs[0] as Dictionary)["tincture"])):
			(chs[0] as Dictionary)["tincture"] = tincture_hex("argent") if tincture_class(fa) == "colour" else tincture_hex("sable")
	var ach := achievement_for_rank(rank, nid)
	ach["mantling_a"] = fa
	ach["mantling_b"] = ot if ot != "" else fb
	ach["motto"] = str(st.get("motto", ""))
	var bias: Array = st.get("partition_bias", ["solid"])
	var division := str(bias[0]) if not bias.is_empty() else "solid"
	if division == "wavy":
		division = "per_fess"
	var ordinary := str(st.get("ordinary", "none"))
	if not tincture_ok(fa, ot) and ordinary != "none":
		ot = tincture_hex("argent") if tincture_class(fa) == "colour" else tincture_hex("sable")
	return normalize({
		"schema": SCHEMA,
		"nation": nid,
		"shield_shape": str(st.get("shield", "heater")),
		"division": division,
		"field": division if division in ["solid", "per_fess", "per_pale"] else "solid",
		"field_a": fa,
		"field_b": fb,
		"partition_line": "wavy" if "wavy" in bias else "straight",
		"ordinary": ordinary,
		"ordinary_tincture": ot,
		"charge": ordinary if ordinary in ["none", "fess", "pale", "bend", "chevron", "pale_thin"] else "none",
		"charge_color": ot,
		"charges": chs,
		"emblem": str((chs[0] as Dictionary).get("id", "ring")) if not chs.is_empty() else "ring",
		"emblem_color": str((chs[0] as Dictionary).get("tincture", ot)) if not chs.is_empty() else ot,
		"border": "line",
		"border_color": tincture_hex("bleu_celeste"),
		"achievement": ach,
	})

static func randomize_for_nation(nid: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var base := from_nation(nid)
	var st := nation_style(nid)
	var divs: Array = st.get("partition_bias", division_ids())
	# Filter to real divisions.
	var real_divs: Array = []
	for d in divs:
		if str(d) in division_ids() or str(d) == "wavy":
			real_divs.append("per_fess" if str(d) == "wavy" else str(d))
	if real_divs.is_empty():
		real_divs = ["solid", "per_pale", "per_fess"]
	base["division"] = str(real_divs[r.randi() % real_divs.size()])
	var lines := partition_line_ids()
	base["partition_line"] = str(lines[r.randi() % lines.size()])
	var ords: Array = [str(st.get("ordinary", "none")), "none", "fess", "pale", "chevron"]
	base["ordinary"] = str(ords[r.randi() % ords.size()])
	var preferred: Array = st.get("charges", [])
	var all_ch := charge_ids()
	var pick := str(preferred[r.randi() % preferred.size()]) if not preferred.is_empty() else str(all_ch[r.randi() % all_ch.size()])
	var ct := str(base.get("ordinary_tincture", base.get("field_b", "")))
	if not tincture_ok(str(base["field_a"]), ct):
		ct = tincture_hex("argent") if tincture_class(str(base["field_a"])) == "colour" else tincture_hex("sable")
	base["charges"] = [{"id": pick, "tincture": ct, "placement": "center"}]
	base["emblem"] = pick
	base["emblem_color"] = ct
	return normalize(base)

## Map a nation-table charge id onto a company DIY emblem slot (BannerSpec.EMBLEMS).
static func company_emblem_id(raw: String) -> String:
	var id := str(raw).strip_edges()
	if id in ["ring", "arc", "wave", "leaf", "chevron", "spark", "filament", "tide", "notch", "bars", "bend", "hollow", "surname"]:
		return id
	const MAP := {
		"ash_plume": "bars", "plume": "bars", "tower": "bars", "bridge": "bend",
		"shadow_arc": "arc", "crescent": "arc", "jade_wave": "wave", "reed": "wave",
		"glass_lantern": "filament", "lantern": "filament", "ice_crown": "ring", "annulet": "ring",
		"ember_notch": "notch", "anvil": "notch", "salt_crystal": "spark", "mullet": "spark",
		"flake": "spark", "constellation": "spark", "starbridge": "spark",
		"iron_chevron": "chevron", "chevron_mark": "chevron", "fog_leaf": "leaf",
		"zephyr": "leaf", "lozenge": "leaf", "bend_mark": "bend", "tide": "tide",
	}
	return str(MAP.get(id, "ring"))


## First unicode character of a surname (empty if blank).
static func surname_char(surname: String) -> String:
	var s := str(surname).strip_edges()
	if s.is_empty():
		return ""
	return s.left(1)


## Force emblem=surname with glyph_char from surname (or existing glyph).
static func with_surname_emblem(spec: Dictionary, surname: String = "") -> Dictionary:
	var s := normalize(spec)
	var ch := surname_char(surname) if str(surname).strip_edges() != "" else surname_char(str(s.get("glyph_char", "")))
	if ch == "":
		return s
	s["glyph_char"] = ch
	s["emblem"] = "surname"
	var tint := str(s.get("emblem_color", s.get("ordinary_tincture", tincture_hex("argent"))))
	if tint == "":
		tint = tincture_hex("argent")
	s["emblem_color"] = tint
	s["charges"] = [{"id": "surname", "tincture": tint, "placement": "center", "glyph": ch}]
	return normalize(s)


## Procedural seal strokes in unit square [-1,1]^2 (font-free fallback / raster).
static func surname_stroke_segments(glyph: String) -> Array:
	var cp := 0
	if str(glyph).length() > 0:
		cp = str(glyph).unicode_at(0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("surname_seal#%d" % cp)
	var segs: Array = []
	# Outer frame — geometric seal border.
	segs.append([Vector2(-0.88, -0.88), Vector2(0.88, -0.88)])
	segs.append([Vector2(0.88, -0.88), Vector2(0.88, 0.88)])
	segs.append([Vector2(0.88, 0.88), Vector2(-0.88, 0.88)])
	segs.append([Vector2(-0.88, 0.88), Vector2(-0.88, -0.88)])
	var nh := 1 + (cp % 3)
	for i in nh:
		var y := -0.55 + float(i + 1) * (1.1 / float(nh + 1)) + (rng.randf() - 0.5) * 0.06
		var x0 := -0.72 + rng.randf() * 0.12
		var x1 := 0.72 - rng.randf() * 0.12
		segs.append([Vector2(x0, y), Vector2(x1, y)])
	var nv := 1 + ((cp >> 3) % 3)
	for i in nv:
		var x := -0.55 + float(i + 1) * (1.1 / float(nv + 1)) + (rng.randf() - 0.5) * 0.06
		var y0 := -0.72 + rng.randf() * 0.12
		var y1 := 0.72 - rng.randf() * 0.12
		segs.append([Vector2(x, y0), Vector2(x, y1)])
	if (cp >> 6) & 1:
		segs.append([Vector2(-0.55, -0.55), Vector2(0.55, 0.55)])
	if (cp >> 7) & 1:
		segs.append([Vector2(0.55, -0.55), Vector2(-0.55, 0.55)])
	if (cp >> 8) & 1:
		segs.append([Vector2(-0.25, -0.72), Vector2(0.6, -0.15)])
	if (cp >> 9) & 1:
		segs.append([Vector2(-0.6, 0.15), Vector2(0.25, 0.72)])
	if (cp >> 10) & 1:
		segs.append([Vector2(-0.4, 0.0), Vector2(0.4, 0.0)])
	return segs


static func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func surname_stroke_hit(dx: float, dy: float, glyph: String, thickness: float = 0.11) -> bool:
	for seg in surname_stroke_segments(glyph):
		if typeof(seg) != TYPE_ARRAY or (seg as Array).size() < 2:
			continue
		var a: Vector2 = (seg as Array)[0]
		var b: Vector2 = (seg as Array)[1]
		if _dist_point_segment(Vector2(dx, dy), a, b) <= thickness:
			return true
	return false


## Company 团徽 preset: ash cloth (B-09) + nation division/ordinary/emblem + heart tincture.
## heart_hex empty → nation ordinary_tincture (or argent).
static func company_preset_from_nation(nid: String, heart_hex: String = "") -> Dictionary:
	var base := from_nation(nid)
	var field := tincture_hex("ash")
	var pair := tincture_hex("ash_deep")
	var heart := str(heart_hex).strip_edges()
	if heart == "":
		heart = str(base.get("ordinary_tincture", ""))
	if heart == "":
		heart = tincture_hex("argent")
	if not heart.begins_with("#") and heart != "":
		heart = "#" + heart
	var raw_eid := "ring"
	var chs: Array = base.get("charges", [])
	if not chs.is_empty() and typeof(chs[0]) == TYPE_DICTIONARY:
		raw_eid = str((chs[0] as Dictionary).get("id", "ring"))
	elif str(base.get("emblem", "")) != "":
		raw_eid = str(base.get("emblem", "ring"))
	var eid := company_emblem_id(raw_eid)
	var ordinary := str(base.get("ordinary", "none"))
	var division := str(base.get("division", "solid"))
	# Keep nation motto + rank helm/crown; remantle onto company ash cloth + heart.
	var ach: Dictionary = (base.get("achievement", {}) as Dictionary).duplicate(true)
	ach["mantling_a"] = field
	ach["mantling_b"] = heart
	return normalize({
		"schema": SCHEMA,
		"nation": nid,
		"shield_shape": str(base.get("shield_shape", "heater")),
		"division": division,
		"field": division if division in ["solid", "per_fess", "per_pale"] else "solid",
		"field_a": field,
		"field_b": pair,
		"partition_line": str(base.get("partition_line", "straight")),
		"ordinary": ordinary,
		"ordinary_tincture": heart,
		"charge": ordinary if ordinary in ["none", "fess", "pale", "bend", "chevron", "pale_thin"] else "none",
		"charge_color": heart,
		"charges": [{"id": eid, "tincture": heart, "placement": "center"}],
		"emblem": eid,
		"emblem_color": heart,
		"border": str(base.get("border", "line")),
		"border_color": str(base.get("border_color", tincture_hex("bleu_celeste"))),
		"achievement": ach,
	})



static func helm_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for row in table().get("helms", []):
		if typeof(row) == TYPE_DICTIONARY:
			out.append(str((row as Dictionary).get("id", "none")))
	if out.is_empty():
		out = PackedStringArray(["none", "closed", "grilled", "royal"])
	return out

static func crown_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for row in table().get("crowns", []):
		if typeof(row) == TYPE_DICTIONARY:
			out.append(str((row as Dictionary).get("id", "none")))
	if out.is_empty():
		out = PackedStringArray(["none", "knight", "baron", "count", "duke", "royal"])
	return out

static func has_achievement_ornament(spec: Dictionary) -> bool:
	var s := normalize(spec)
	var ach: Dictionary = s.get("achievement", {})
	if typeof(ach) != TYPE_DICTIONARY:
		return false
	if str(ach.get("helm", "none")) != "none":
		return true
	if str(ach.get("crown", "none")) != "none":
		return true
	if str(ach.get("motto", "")).strip_edges() != "":
		return true
	var sups: Array = ach.get("supporters", [])
	if typeof(sups) == TYPE_ARRAY:
		for s_id in sups:
			if str(s_id) != "" and str(s_id) != "none":
				return true
	return false

static func stamp_achievement_meta(node: Object, spec: Dictionary) -> void:
	if node == null:
		return
	var s := normalize(spec)
	var ach: Dictionary = s.get("achievement", {})
	if typeof(ach) != TYPE_DICTIONARY:
		ach = {}
	node.set_meta("arms_helm", str(ach.get("helm", "none")))
	node.set_meta("arms_crown", str(ach.get("crown", "none")))
	node.set_meta("arms_motto", str(ach.get("motto", "")).strip_edges())
	var sups := _sanitize_supporters(ach.get("supporters", []), str(s.get("nation", "")))
	node.set_meta("arms_supporter_l", str(sups[0]))
	node.set_meta("arms_supporter_r", str(sups[1]))


static func clear_achievement_meta_cloth(node: Object) -> void:
	## HangCloth / ShellBanner stay rectangular cloth — never claim achievement ornaments.
	if node == null:
		return
	node.set_meta("arms_helm", "none")
	node.set_meta("arms_crown", "none")
	node.set_meta("arms_motto", "")
	node.set_meta("arms_supporter_l", "none")
	node.set_meta("arms_supporter_r", "none")

static func apply_rank(spec: Dictionary, rank: String) -> Dictionary:
	var s := normalize(spec)
	var ach: Dictionary = (s.get("achievement", {}) as Dictionary).duplicate(true)
	var nid := str(s.get("nation", ""))
	var built := achievement_for_rank(rank, nid)
	ach["helm"] = str(built.get("helm", ach.get("helm", "none")))
	ach["crown"] = str(built.get("crown", ach.get("crown", "none")))
	if str(ach.get("mantling_a", "")) == "":
		ach["mantling_a"] = str(s.get("field_a", ""))
	if str(ach.get("mantling_b", "")) == "":
		ach["mantling_b"] = str(s.get("ordinary_tincture", s.get("field_b", "")))
	if rank in ["duke", "royal"]:
		ach["supporters"] = nation_supporter_pair(nid)
	elif rank in ["knight", "baron", "count"]:
		# Low ranks stay bare unless the player already DIY'd supporters.
		var cur := _sanitize_supporters(ach.get("supporters", []), nid)
		if str(cur[0]) == "frost_beast" or str(cur[1]) == "frost_beast":
			ach["supporters"] = ["none", "none"]
	s["achievement"] = ach
	return normalize(s)

static func cache_key(spec: Dictionary) -> String:
	var s := normalize(spec)
	var chs: Array = []
	for c in s.get("charges", []):
		if typeof(c) == TYPE_DICTIONARY:
			var cd: Dictionary = c
			chs.append("%s:%s:%s" % [cd.get("id", ""), cd.get("tincture", ""), cd.get("placement", "")])
	var ach: Dictionary = s.get("achievement", {})
	return "|".join([
		str(s.get("schema", 2)),
		str(s.get("division", "")), str(s.get("partition_line", "")),
		str(s.get("field_a", "")), str(s.get("field_b", "")),
		str(s.get("ordinary", "")), str(s.get("ordinary_tincture", "")),
		str(s.get("border", "")), str(s.get("border_color", "")),
		",".join(chs),
		str(s.get("shield_shape", "")), str(s.get("nation", "")),
		str(ach.get("helm", "")), str(ach.get("crown", "")),
		str(ach.get("motto", "")),
		",".join(_sanitize_supporters(ach.get("supporters", []), str(s.get("nation", "")))),
		str(s.get("glyph_char", "")),
		str(s.get("castle_mark", {})), str(s.get("family_tier", "")),
	])

static func contrast_ok(spec: Dictionary) -> bool:
	var s := normalize(spec)
	var a := Color(str(s.field_a))
	var e_col := str(s.get("emblem_color", s.get("ordinary_tincture", "")))
	if e_col == "":
		var chs: Array = s.get("charges", [])
		if not chs.is_empty() and typeof(chs[0]) == TYPE_DICTIONARY:
			e_col = str((chs[0] as Dictionary).get("tincture", ""))
	if e_col == "":
		return true
	var e := Color(e_col)
	return absf(a.get_luminance() - e.get_luminance()) >= 0.22


# --- Company banner (团徽) vs family arms (族徽) ------------------------------------------
## Family arms = own core design + small fixed canton echoing the company banner + tier ornament.
## Uniqueness is judged on the core design only (vs company banner and other families).

const FAMILY_TIERS := ["commoner", "noble", "royal"]

static func core_key(spec: Dictionary) -> String:
	var s := normalize(spec)
	var chs: Array = []
	for c in s.get("charges", []):
		if typeof(c) == TYPE_DICTIONARY:
			var cd: Dictionary = c
			var g := str(cd.get("glyph", ""))
			if g == "":
				chs.append("%s:%s" % [cd.get("id", ""), str(cd.get("tincture", "")).to_lower()])
			else:
				chs.append("%s:%s:%s" % [cd.get("id", ""), str(cd.get("tincture", "")).to_lower(), g])
	return "|".join([
		str(s.get("division", "")), str(s.get("partition_line", "")),
		str(s.get("field_a", "")).to_lower(), str(s.get("field_b", "")).to_lower(),
		str(s.get("ordinary", "")), str(s.get("ordinary_tincture", "")).to_lower(),
		",".join(chs), str(s.get("shield_shape", "")),
		str(s.get("glyph_char", "")),
	])

static func generate_unique_arms(nation: String, seed_text: String, taken: Dictionary) -> Dictionary:
	## Deterministic per seed; re-rolls until the core design is not in `taken` (core_key -> owner).
	var rng := RandomNumberGenerator.new()
	for attempt in range(256):
		rng.seed = hash("%s#%s#%d" % [nation, seed_text, attempt])
		var spec := randomize_for_nation(nation, rng)
		for legacy_key in ["castle_mark", "family_tier"]:
			spec.erase(legacy_key)
		if not taken.has(core_key(spec)):
			return spec
	# Exhaustive fallback: walk tinctures until free (never returns a duplicate core).
	var base := randomize_for_nation(nation, rng)
	for tid in (table().get("tinctures", {}) as Dictionary).keys():
		for oid in ["fess", "pale", "bend", "chevron", "cross", "saltire", "chief", "pile", "pall"]:
			var cand := base.duplicate(true)
			cand["ordinary"] = oid
			cand["ordinary_tincture"] = tincture_hex(str(tid))
			cand = normalize(cand)
			if not taken.has(core_key(cand)):
				return cand
	return base

static func family_display_arms(core: Dictionary, castle_spec: Dictionary, tier: String) -> Dictionary:
	## Core design + fixed company-banner canton + tier ornament.
	var s := normalize(core)
	var castle := normalize(castle_spec)
	var chs: Array = castle.get("charges", [])
	var mark_charge := ""
	var mark_tint := str(castle.get("emblem_color", castle.get("ordinary_tincture", "")))
	if not chs.is_empty() and typeof(chs[0]) == TYPE_DICTIONARY:
		mark_charge = str((chs[0] as Dictionary).get("id", ""))
		mark_tint = str((chs[0] as Dictionary).get("tincture", mark_tint))
	s["castle_mark"] = {"kind": "canton", "field": str(castle.get("field_a", "")), "charge": mark_charge, "tincture": mark_tint}
	var t := tier if tier in FAMILY_TIERS else "commoner"
	s["family_tier"] = t
	var orn: Dictionary = (table().get("family_tier_ornament", {}) as Dictionary).get(t, {})
	s["border"] = str(orn.get("border", "none"))
	if orn.has("border_tincture"):
		s["border_color"] = tincture_hex(str(orn["border_tincture"]))
	var max_charges := int(orn.get("max_charges", 1))
	var cur: Array = s.get("charges", [])
	var style := nation_style(str(s.get("nation", "")))
	var pool: Array = style.get("charges", [])
	var tint := str(s.get("emblem_color", tincture_hex("argent")))
	var placements := ["center", "chief", "base"]
	while cur.size() < max_charges and cur.size() < placements.size() and pool.size() > cur.size():
		cur.append({"id": str(pool[cur.size()]), "tincture": tint, "placement": placements[cur.size()]})
	if cur.size() > max_charges:
		cur = cur.slice(0, max_charges)
	s["charges"] = cur
	return s
