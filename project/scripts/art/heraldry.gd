class_name CKHeraldry
extends RefCounted
## Deep heraldry API: tinctures, marshalling, cadency, nation styles, v1 migrate.
## Colors live in heraldry_v2.json (style ratchet: no hex in this file).

const DATA_PATH := "res://assets/art/heraldry_v2.json"
const SCHEMA := 2

static var _data: Dictionary = {}
static var _ready := false

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

static func cadency_for_birth_order(order: int) -> String:
	## 1-based birth order among living full siblings; 0 / negative → none.
	if order <= 0:
		return "none"
	var best := "none"
	for row in table().get("cadency", []):
		var r: Dictionary = row
		if int(r.get("order", 0)) == mini(order, 9):
			return str(r.get("id", "none"))
		best = str(r.get("id", best))
	return best

static func achievement_for_rank(rank: String) -> Dictionary:
	var helm_map: Dictionary = table().get("rank_to_helm", {})
	var crown_map: Dictionary = table().get("rank_to_crown", {})
	var helm := str(helm_map.get(rank, "none"))
	var crown := str(crown_map.get(rank, "none"))
	var supporters: Array = ["none", "none"]
	if rank in ["duke", "royal"]:
		supporters = ["frost_beast", "frost_beast"]
	return {
		"helm": helm,
		"crown": crown,
		"mantling_a": "",
		"mantling_b": "",
		"supporters": supporters,
		"motto": "",
	}

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
		base["achievement"] = ach
	if not base.has("marshalling") or typeof(base["marshalling"]) != TYPE_DICTIONARY:
		base["marshalling"] = {"mode": "none", "partner": {}}
	base["cadency"] = str(base.get("cadency", "none"))
	base["bastardy"] = bool(base.get("bastardy", false))
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
	var ach := achievement_for_rank(rank)
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
		"marshalling": {"mode": "none", "partner": {}},
		"cadency": "none",
		"bastardy": false,
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

static func marshal(primary: Dictionary, partner: Dictionary, mode: String = "impale") -> Dictionary:
	var a := normalize(primary)
	var b := normalize(partner)
	var m := str(mode)
	if m not in ["impale", "quarter"]:
		m = "impale"
	a["marshalling"] = {"mode": m, "partner": b}
	# Visual field becomes a marker; renderer composites both arms.
	if m == "impale":
		a["division"] = "per_pale"
	elif m == "quarter":
		a["division"] = "quarterly"
	return normalize(a)

static func apply_cadency(spec: Dictionary, birth_order: int, bastardy: bool = false) -> Dictionary:
	var s := normalize(spec)
	s["cadency"] = cadency_for_birth_order(birth_order)
	s["bastardy"] = bastardy
	return normalize(s)

static func apply_rank(spec: Dictionary, rank: String) -> Dictionary:
	var s := normalize(spec)
	var ach: Dictionary = (s.get("achievement", {}) as Dictionary).duplicate(true)
	var built := achievement_for_rank(rank)
	ach["helm"] = str(built.get("helm", ach.get("helm", "none")))
	ach["crown"] = str(built.get("crown", ach.get("crown", "none")))
	if str(ach.get("mantling_a", "")) == "":
		ach["mantling_a"] = str(s.get("field_a", ""))
	if str(ach.get("mantling_b", "")) == "":
		ach["mantling_b"] = str(s.get("ordinary_tincture", s.get("field_b", "")))
	if rank in ["duke", "royal"]:
		ach["supporters"] = built.get("supporters", ["frost_beast", "frost_beast"])
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
	var marsh: Dictionary = s.get("marshalling", {})
	var partner_key := ""
	if str(marsh.get("mode", "none")) != "none" and typeof(marsh.get("partner")) == TYPE_DICTIONARY:
		partner_key = cache_key(marsh["partner"] as Dictionary)
	return "|".join([
		str(s.get("schema", 2)),
		str(s.get("division", "")), str(s.get("partition_line", "")),
		str(s.get("field_a", "")), str(s.get("field_b", "")),
		str(s.get("ordinary", "")), str(s.get("ordinary_tincture", "")),
		str(s.get("border", "")), str(s.get("border_color", "")),
		",".join(chs),
		str(s.get("shield_shape", "")), str(s.get("nation", "")),
		str(s.get("cadency", "")), str(int(bool(s.get("bastardy", false)))),
		str(ach.get("helm", "")), str(ach.get("crown", "")),
		str(ach.get("motto", "")), str(marsh.get("mode", "")), partner_key,
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

static func birth_order_among_siblings(child: Object) -> int:
	## 1-based order by age descending (oldest = 1) among shared parent_ids.
	if child == null:
		return 0
	var pids: Array = child.get("parent_ids") if typeof(child.get("parent_ids")) == TYPE_ARRAY else []
	if pids.is_empty():
		return 1
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs == null:
		return 1
	var chars: Dictionary = gs.characters if gs.get("characters") != null else {}
	var sibs: Array = []
	for cid in chars.keys():
		var o = chars[cid]
		if o == null or not bool(o.get("alive")):
			continue
		var op: Array = o.get("parent_ids") if typeof(o.get("parent_ids")) == TYPE_ARRAY else []
		if op.size() < 1:
			continue
		var share := false
		for p in pids:
			if str(p) != "" and str(p) in op:
				share = true
				break
		if share:
			sibs.append(o)
	sibs.sort_custom(func(a, b): return int(a.get("age")) > int(b.get("age")) or (int(a.get("age")) == int(b.get("age")) and str(a.get("id")) < str(b.get("id"))))
	for i in sibs.size():
		if str(sibs[i].get("id")) == str(child.get("id")):
			return i + 1
	return sibs.size() + 1

static func is_bastard(child: Object) -> bool:
	if child == null:
		return false
	var meta = child.get("blood_meta")
	if typeof(meta) == TYPE_DICTIONARY and bool((meta as Dictionary).get("bastard", false)):
		return true
	if typeof(meta) == TYPE_DICTIONARY and bool((meta as Dictionary).get("bastardy", false)):
		return true
	var honors = child.get("honors")
	if typeof(honors) == TYPE_ARRAY and ("bastard" in honors or "natural_child" in honors):
		return true
	return false

static func stamp_child_heraldry(child: Object, house_spec: Dictionary = {}) -> Dictionary:
	## Writes blood_meta.heraldry and returns the personal arms.
	var base := normalize(house_spec if not house_spec.is_empty() else {})
	if house_spec.is_empty():
		var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
		if gs != null and typeof(gs.get("banner_spec")) == TYPE_DICTIONARY:
			base = normalize(gs.banner_spec)
	var order := birth_order_among_siblings(child)
	var bast := is_bastard(child)
	var personal := apply_cadency(base, order, bast)
	var rank := str(child.get("rank")) if child != null else "knight"
	personal = apply_rank(personal, rank)
	if child != null:
		var meta: Dictionary = child.get("blood_meta") if typeof(child.get("blood_meta")) == TYPE_DICTIONARY else {}
		meta = meta.duplicate(true)
		meta["heraldry"] = {
			"cadency": personal.get("cadency", "none"),
			"bastardy": bast,
			"birth_order": order,
			"spec": personal,
		}
		child.set("blood_meta", meta)
	return personal
