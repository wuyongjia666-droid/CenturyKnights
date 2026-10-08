class_name CKPortraitBank
extends RefCounted
## v9.2 Plan A bank: complete Qwen plates, five age stages, nearest bucket by identity_overlap.
## Official art is never a paper-doll collage. Plates live under portraits/genome/bank/ (farm).
## This manifest is the queue; an empty plate directory leaves CKGenomePortrait.texture() unchanged.

const HIT_MIN := 0.80
const MAX_BUCKETS := 6000
const COVERAGE_YEARS := 100
const COVERAGE_SEEDS: Array[int] = [
	1101, 1102, 1103, 1104, 1105, 1106, 1107, 1108, 1109, 1110,
	1111, 1112, 1113, 1114, 1115, 1116, 1117, 1118, 1119, 1120,
]
const PLATE_W := 768
const PLATE_H := 1024

static var dir_override: String = ""
static var _plates_known := false
static var _plates := false
static var _indexed := false
static var _exact: Dictionary = {}
static var _by_stage: Dictionary = {}

static func manifest_path() -> String:
	var proj := ProjectSettings.globalize_path("res://")
	if proj.ends_with("/"):
		proj = proj.substr(0, proj.length() - 1)
	return proj.get_base_dir().path_join("tools/farm_queue/genome_bank_v92.json")

static func bank_dir() -> String:
	if dir_override != "":
		return dir_override
	return ProjectSettings.globalize_path("res://assets/art/portraits/genome/bank")

static func clear_cache() -> void:
	_plates_known = false
	_plates = false
	_indexed = false
	_exact.clear()
	_by_stage.clear()

static func has_plates() -> bool:
	if _plates_known:
		return _plates
	_plates = false
	var dir := bank_dir()
	if DirAccess.dir_exists_absolute(dir):
		var da := DirAccess.open(dir)
		if da != null:
			for fn in da.get_files():
				if str(fn).to_lower().ends_with(".png"):
					_plates = true
					break
	_plates_known = true
	return _plates

static func try_texture(c: Object) -> Texture2D:
	if not has_plates():
		return null
	var m := best_match(c)
	if not bool(m.get("hit", false)):
		return null
	return _load_png(bank_dir().path_join(str(m.get("bucket_key", "")) + ".png"))

static func best_match(c: Object) -> Dictionary:
	_ensure_index()
	var blood := ""
	if c != null and c.has_method("primary_bloodline"):
		blood = str(c.call("primary_bloodline"))
	return match_identity(identity_list(c), CKGenomePortrait.age_stage_of(c), blood)

static func match_identity(ident: Array, stage: String, blood: String = "") -> Dictionary:
	_ensure_index()
	var empty := {"hit": false, "overlap": 0.0, "bucket_key": "", "stage": stage, "bloodline": ""}
	var sig := _sig(ident)
	var cands: Array = _exact.get("%s|%s" % [stage, sig], [])
	if not cands.is_empty():
		var chosen: Dictionary = cands[0]
		if blood != "":
			for row in cands:
				if str(row.get("bloodline", "")) == blood:
					chosen = row
					break
		var ov := token_overlap(ident, chosen.get("identity", []))
		return {
			"hit": ov >= HIT_MIN,
			"overlap": ov,
			"bucket_key": str(chosen.get("bucket_key", "")),
			"stage": stage,
			"bloodline": str(chosen.get("bloodline", "")),
		}
	var best_ov := -1.0
	var best: Dictionary = {}
	for row in _by_stage.get(stage, []):
		var ov2 := token_overlap(ident, row.get("identity", []))
		var key := str(row.get("bucket_key", ""))
		var better := ov2 > best_ov + 0.0000001
		var tie := absf(ov2 - best_ov) <= 0.0000001 and (best.is_empty() or key < str(best.get("bucket_key", "")))
		if better or tie:
			best_ov = ov2
			best = row
	if best.is_empty():
		return empty
	return {
		"hit": best_ov >= HIT_MIN,
		"overlap": best_ov,
		"bucket_key": str(best.get("bucket_key", "")),
		"stage": stage,
		"bloodline": str(best.get("bloodline", "")),
	}

static func token_overlap(ia: Array, ib: Array) -> float:
	if ia.is_empty():
		return 1.0
	var have := {}
	for t in ib:
		have[str(t)] = true
	var hit := 0
	for t in ia:
		if have.has(str(t)):
			hit += 1
	return float(hit) / float(ia.size())

static func identity_list(c: Object) -> Array:
	var out: Array = []
	for t in CKGenomePortrait.describe(c).get("identity", []):
		out.append(str(t))
	out.sort()
	return out

static func face_cluster(ident: Array) -> String:
	var parts: PackedStringArray = []
	for t in ident:
		var s := str(t)
		if s.begins_with("face."):
			parts.append(s)
	parts.sort()
	return "|".join(parts)

static func visible_set(c: Object) -> String:
	var parts: PackedStringArray = []
	for e in CKBloodline.signatures(c, false):
		var st := str(e.get("state", ""))
		if st != "":
			parts.append("sig:" + st)
	for t in CKBloodline.expressed_traits(c, false):
		var st2 := str(t.get("state", ""))
		if st2 != "":
			parts.append("trait:" + st2)
	var arr: Array = []
	for s in parts:
		arr.append(s)
	arr.sort()
	return ",".join(arr) if not arr.is_empty() else "none"

static func build_from_campaigns(seeds: Array = COVERAGE_SEEDS, years: int = COVERAGE_YEARS) -> Dictionary:
	var buckets := {}
	var emitted := {}
	var observed: Array = []
	for seed_i in seeds:
		CKCampaignSim.run(years, int(seed_i))
		var births: Array = []
		for c in GameState.characters.values():
			if _is_birth(c):
				births.append(c)
		births.sort_custom(func(a, b): return str(a.id) < str(b.id))
		for c in births:
			var ident := identity_list(c)
			observed.append({
				"identity": ident,
				"stage": CKGenomePortrait.age_stage_of(c),
				"blood": str(c.primary_bloodline()),
			})
			_emit_person(c, buckets, emitted)
	var rows: Array = buckets.values()
	rows.sort_custom(func(a, b): return str(a.get("bucket_key", "")) < str(b.get("bucket_key", "")))
	var seed_list: Array = []
	for seed_i in seeds:
		seed_list.append(int(seed_i))
	var payload := {
		"version": "v92",
		"scheme": "A_bucket_nearest",
		"premise": "complete_qwen_gene_seed_five_stages",
		"seeds": seed_list,
		"years": years,
		"hit_overlap_min": HIT_MIN,
		"max_buckets": MAX_BUCKETS,
		"plate": {"width": PLATE_W, "height": PLATE_H},
		"buckets": rows,
	}
	install_rows(rows)
	return {"payload": payload, "observed": observed, "rows": rows}

static func write_manifest(payload: Dictionary) -> int:
	var path := manifest_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("bank manifest write failed: " + path)
		return -1
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return (payload.get("buckets", []) as Array).size()

static func load_manifest() -> Dictionary:
	var raw := FileAccess.get_file_as_string(manifest_path())
	var data = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	install_rows(data.get("buckets", []))
	return data

static func install_rows(rows: Array) -> void:
	_exact.clear()
	_by_stage.clear()
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var stage := str(row.get("stage", ""))
		var sig := _sig(row.get("identity", []))
		var k := "%s|%s" % [stage, sig]
		if not _exact.has(k):
			_exact[k] = []
		(_exact[k] as Array).append(row)
		if not _by_stage.has(stage):
			_by_stage[stage] = []
		(_by_stage[stage] as Array).append(row)
	for k2 in _exact.keys():
		(_exact[k2] as Array).sort_custom(func(a, b): return str(a.get("bucket_key", "")) < str(b.get("bucket_key", "")))
	_indexed = true

static func coverage(observed: Array) -> Dictionary:
	var n := observed.size()
	var hits := 0
	var sum := 0.0
	var worst := 1.0
	for o in observed:
		var m := match_identity(o.get("identity", []), str(o.get("stage", "")), str(o.get("blood", "")))
		if bool(m.get("hit", false)):
			hits += 1
			var ov := float(m.get("overlap", 0.0))
			sum += ov
			if ov < worst:
				worst = ov
	var rate := 0.0 if n == 0 else float(hits) / float(n)
	var mean := 0.0 if hits == 0 else sum / float(hits)
	return {"births": n, "hits": hits, "hit_rate": rate, "mean_overlap": mean, "worst": worst if hits > 0 else 0.0}

static func forbidden_hits(text: String) -> Array:
	var words: Array = CKGenomePortrait.style_lock().get("anti_trope", {}).get("forbid_in_positive", [])
	var low := text.to_lower()
	var hits: Array = []
	for w in words:
		var term := str(w).to_lower().strip_edges()
		if term != "" and _has_term(low, term):
			hits.append(term)
	return hits

static func validate_payload(payload: Dictionary) -> String:
	var rows: Array = payload.get("buckets", [])
	if rows.size() > MAX_BUCKETS:
		return "bucket count %d" % rows.size()
	if rows.is_empty():
		return "empty bank"
	var lock: Dictionary = CKGenomePortrait.style_lock()
	var prefix := str(lock.get("qwen", {}).get("prefix", ""))
	var negative := str(lock.get("qwen", {}).get("negative", ""))
	if prefix == "" or negative == "":
		return "style lock missing"
	var groups := {}
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			return "row type"
		var pos := str(row.get("positive", ""))
		if not pos.begins_with(prefix):
			return "prefix missing on " + str(row.get("bucket_key", ""))
		if str(row.get("negative", "")) != negative:
			return "negative mismatch on " + str(row.get("bucket_key", ""))
		if int(row.get("seed", 0)) <= 0:
			return "seed missing on " + str(row.get("bucket_key", ""))
		var bad: Array = forbidden_hits(pos)
		if not bad.is_empty():
			return "anti-trope %s on %s" % [str(bad), str(row.get("bucket_key", ""))]
		var key := str(row.get("bucket_key", ""))
		var us := key.rfind("_")
		if us <= 0:
			return "bucket key " + key
		var series := key.substr(us + 1)
		if not groups.has(series):
			groups[series] = {}
		groups[series][str(row.get("stage", ""))] = true
	for series2 in groups.keys():
		for stage in CKGenomePortrait.STAGES:
			if not (groups[series2] as Dictionary).has(str(stage)):
				return "series %s missing %s" % [series2, stage]
	return ""

static func _emit_person(c: Object, buckets: Dictionary, emitted: Dictionary) -> void:
	var saved_age := int(c.get("age"))
	var saved_scars: Array = (c.get("scars") as Array).duplicate()
	c.set("scars", [])
	c.set("age", CKGenomePortrait.stage_apex("young_adult"))
	var dedup := "%s#%s#%s" % [_sig(identity_list(c)), str(c.call("primary_bloodline")), visible_set(c)]
	if emitted.has(dedup):
		c.set("age", saved_age)
		c.set("scars", saved_scars)
		return
	emitted[dedup] = true
	var series := _fnv(dedup)
	var blood := str(c.call("primary_bloodline"))
	var sex := "f" if str(c.get("gender")) == "f" else "m"
	for stage in CKGenomePortrait.STAGES:
		var stage_s := str(stage)
		c.set("age", CKGenomePortrait.stage_apex(stage_s))
		var ident := identity_list(c)
		var ph: Dictionary = CKGenome.phenotype(c)
		var hair := str(ph.get("loci", {}).get("hair", {}).get("id", ""))
		var eyes := str(ph.get("loci", {}).get("eyes", {}).get("id", ""))
		var key := "%s_%s" % [stage_s, series]
		buckets[key] = {
			"bucket_key": key,
			"stage": stage_s,
			"stage_zh": CKGenomePortrait.stage_zh(stage_s),
			"seed": CKGenomePortrait.seed_for(c),
			"identity_seed": CKGenomePortrait.identity_seed(c),
			"bloodline": blood,
			"sex": sex,
			"hair": hair,
			"eyes": eyes,
			"face_cluster": face_cluster(ident),
			"visible_traits": visible_set(c),
			"identity": ident,
			"positive": CKGenomePortrait.positive_prompt(c),
			"negative": CKGenomePortrait.negative_prompt(c),
			"out_path": "project/assets/art/portraits/genome/bank/%s.png" % key,
			"width": PLATE_W,
			"height": PLATE_H,
			"steps": int(CKGenomePortrait.style_lock().get("qwen", {}).get("steps", 28)),
			"cfg": float(CKGenomePortrait.style_lock().get("qwen", {}).get("cfg", 1.0)),
			"sampler": str(CKGenomePortrait.style_lock().get("qwen", {}).get("sampler", "euler")),
			"scheduler": str(CKGenomePortrait.style_lock().get("qwen", {}).get("scheduler", "simple")),
		}
	c.set("age", saved_age)
	c.set("scars", saved_scars)

static func _is_birth(c: Object) -> bool:
	var pids = c.get("parent_ids")
	return typeof(pids) == TYPE_ARRAY and not (pids as Array).is_empty()

static func _ensure_index() -> void:
	if _indexed:
		return
	var data := load_manifest()
	if data.is_empty():
		_indexed = true

static func _sig(ident: Array) -> String:
	var parts: PackedStringArray = []
	for t in ident:
		parts.append(str(t))
	parts.sort()
	return "|".join(parts)

static func _fnv(s: String) -> String:
	return "%08x%08x" % [_fnv1a(s, 2166136261), _fnv1a(s, 2166136261 ^ 0x9e3779b9)]

static func _fnv1a(s: String, seed: int) -> int:
	var h := seed & 0xffffffff
	for i in s.length():
		h = (h ^ s.unicode_at(i)) & 0xffffffff
		h = (h * 16777619) & 0xffffffff
	return h

static func _has_term(text: String, term: String) -> bool:
	var start := 0
	var n := term.length()
	while true:
		var i := text.find(term, start)
		if i < 0:
			return false
		var before_ok := i == 0 or not _is_word(text.unicode_at(i - 1))
		var after := i + n
		var after_ok := after >= text.length() or not _is_word(text.unicode_at(after))
		if before_ok and after_ok:
			if i >= 3 and text.substr(i - 3, 3) == "no ":
				start = after
				continue
			return true
		start = i + 1
	return false

static func _is_word(ch: int) -> bool:
	return (ch >= 48 and ch <= 57) or (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch == 95

static func _load_png(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)
