class_name CKGenomePortrait
extends RefCounted
## Plan A (v8.9): one genome-seeded half-body portrait per unit. Paper-doll layering is retired.
## The art farm renders `export_manifest()`; `ingest_dir` / `ingest_manifest` map files back by unit_id.
## Family resemblance is the shared prompt descriptors, not a shared file.
## Bloodline copy is NOT owned here. Register `set_bloodline_clause_hook` from the bloodline pack.

const RES_DIR := "res://assets/art/portraits/genome/"
const USER_DIR := "user://genome_portrait_cache/"
const HALF_BODY := "Waist-up half-body portrait, three-quarter view facing camera-left, chest-up, eye level, single person, plain plate background #D9DEE3."

const HAIR_PROSE := {
	"ink_black": "ink-black hair",
	"ash_brown": "ash-brown hair",
	"ember_red": "ember-red hair",
	"wheat": "wheat-blonde hair",
	"frost_silver": "frost-silver hair",
}
const EYE_PROSE := {
	"dusk": "dusk-violet eyes",
	"slate": "slate-grey eyes",
	"pine": "pine-green eyes",
	"river_blue": "river-blue eyes",
	"amber": "amber eyes",
	"rime": "pale glacier-rime eyes with a thin frost ring",
}
const BROW_PROSE := {
	"thick": "thick brows", "straight": "straight brows", "arch": "arched brows", "soft": "soft brows",
}
const EAR_PROSE := {"round": "rounded ears", "crest": "fine pointed ear tips"}
const FACE_WORD := {
	"width": ["narrow", "balanced", "broad"],
	"jaw": ["soft", "defined", "square"],
	"cheek": ["flat", "moderate", "high"],
	"nose": ["fine", "straight", "strong"],
	"eye_tilt": ["down-tilted", "level", "up-tilted"],
	"eye_size": ["small", "medium", "large"],
	"brow_height": ["low", "mid", "high"],
}
const FACE_PROSE := {
	"width": ["a narrow face", "a balanced face width", "a broad face"],
	"jaw": ["a soft jaw", "a defined jaw", "a square jaw"],
	"cheek": ["flat cheeks", "moderate cheeks", "high cheekbones"],
	"nose": ["a fine nose", "a straight nose", "a strong nose"],
	"eye_tilt": ["down-tilted eyes", "level eyes", "up-tilted eyes"],
	"eye_size": ["small eyes", "medium eyes", "large eyes"],
	"brow_height": ["low-set brows", "mid-set brows", "high-set brows"],
}
const SCAR_PROSE := {
	"cheek_l": "a scar on the left cheek",
	"cheek_r": "a scar on the right cheek",
	"brow_l": "a scar through the left brow",
	"brow_r": "a scar through the right brow",
	"chin": "a scar on the chin",
	"neck": "a scar on the neck",
}

static var _mem: Dictionary = {}
static var _miss: Dictionary = {}
static var _lock: Dictionary = {}
## Optional. The bloodline pack may supply one extra prompt clause per unit. Empty until registered.
static var bloodline_clause_hook: Callable = Callable()
## Tests point this at a temp directory so ingest does not write the repo tree.
static var dir_override: String = ""

static func set_bloodline_clause_hook(cb: Callable) -> void:
	bloodline_clause_hook = cb

static func _bloodline_clause(c: Object) -> String:
	if bloodline_clause_hook.is_valid():
		return str(bloodline_clause_hook.call(c)).strip_edges()
	return ""

static func style_lock_path() -> String:
	var proj := ProjectSettings.globalize_path("res://")
	if proj.ends_with("/"):
		proj = proj.substr(0, proj.length() - 1)
	return proj.get_base_dir().path_join("docs/art/style-lock-v87.json")

static func style_lock() -> Dictionary:
	if not _lock.is_empty():
		return _lock
	var f := FileAccess.open(style_lock_path(), FileAccess.READ)
	if f == null:
		push_error("style lock missing: " + style_lock_path())
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_lock = parsed
	return _lock

static func file_stem(unit_id: String) -> String:
	var raw := unit_id.strip_edges()
	if raw == "":
		return "unit"
	var s := ""
	for i in raw.length():
		var ch := raw.unicode_at(i)
		var ok := (ch >= 48 and ch <= 57) or (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch == 95 or ch == 45
		s += char(ch) if ok else "_"
	return s if s != "" else "unit"

static func age_stage_of(c: Object) -> String:
	var age_i := int(c.get("age"))
	if age_i < 18:
		return "young"
	if age_i >= 45:
		return "elder"
	return "adult"

static func _band(v: float) -> int:
	if v <= -0.34:
		return 0
	if v >= 0.34:
		return 2
	return 1

static func _ensure(c: Object) -> void:
	if c.has_method("ensure_genome"):
		c.call("ensure_genome")

## Canonical genome string. Same genes, scars, age stage and sex => same seed, regardless of unit_id.
static func seed_payload(c: Object) -> String:
	_ensure(c)
	var g: Dictionary = c.get("genome") if typeof(c.get("genome")) == TYPE_DICTIONARY else {}
	var parts: PackedStringArray = []
	var loci: Dictionary = g.get("loci", {})
	for locus in CKGenome.LOCI.keys():
		var pair: Array = loci.get(locus, ["", ""])
		var a := str(pair[0]) if pair.size() > 0 else ""
		var b := str(pair[1]) if pair.size() > 1 else ""
		parts.append("%s:%s/%s" % [locus, a, b])
	var face: Dictionary = g.get("face", {})
	for k in CKGenome.FACE_KEYS:
		parts.append("f.%s:%.4f" % [k, float(face.get(k, 0.0))])
	var body: Dictionary = g.get("body", {})
	for k in CKGenome.BODY_KEYS:
		parts.append("b.%s:%.4f" % [k, float(body.get(k, 0.0))])
	var scars: Array = []
	var raw_scars = c.get("scars")
	if typeof(raw_scars) == TYPE_ARRAY:
		scars = (raw_scars as Array).duplicate()
	scars.sort()
	var scar_s := ""
	for i in scars.size():
		if i > 0:
			scar_s += ","
		scar_s += str(scars[i])
	parts.append("scars:" + scar_s)
	parts.append("age:" + age_stage_of(c))
	parts.append("sex:" + ("f" if str(c.get("gender")) == "f" else "m"))
	return "|".join(parts)

static func seed_for(c: Object) -> int:
	return maxi(1, hash(seed_payload(c)) & 0x7fffffff)

static func genome_seed(c: Object) -> int:
	return seed_for(c)

static func describe(c: Object) -> Dictionary:
	_ensure(c)
	var ph: Dictionary = CKGenome.phenotype(c)
	var tokens: Array = []
	var heritable: Array = []
	var prose: Array = []
	var stage := str(ph.get("age_stage", age_stage_of(c)))
	var sex := "f" if str(c.get("gender")) == "f" else "m"
	var who: String = str({"young": "youthful", "elder": "elder", "adult": "adult"}.get(stage, "adult"))
	prose.append("%s %s" % [who, "woman" if sex == "f" else "man"])
	tokens.append("gender:%s" % sex)
	tokens.append("age:%s" % stage)
	var hair_e: Dictionary = ph["loci"]["hair"]
	var hair_id := str(hair_e.get("id", ""))
	tokens.append("hair:%s" % hair_id)
	heritable.append("hair:%s" % hair_id)
	var hair_bit := str(HAIR_PROSE.get(hair_id, hair_id + " hair"))
	var hb := str(hair_e.get("blend", ""))
	if hb != "":
		tokens.append("hair_blend:%s" % hb)
		heritable.append("hair_blend:%s" % hb)
		hair_bit += " with a %s undertone" % str(HAIR_PROSE.get(hb, hb)).trim_suffix(" hair")
	if stage == "elder":
		hair_bit += ", greying toward frost silver"
	var hair_col: Color = ph["hair_color"]
	hair_bit += " (%s)" % hair_col.to_html(false)
	prose.append(hair_bit)
	var eye_e: Dictionary = ph["loci"]["eyes"]
	var eye_id := str(eye_e.get("id", ""))
	tokens.append("eyes:%s" % eye_id)
	heritable.append("eyes:%s" % eye_id)
	var eye_bit := str(EYE_PROSE.get(eye_id, eye_id + " eyes"))
	var eb := str(eye_e.get("blend", ""))
	if eb != "":
		tokens.append("eyes_blend:%s" % eb)
		heritable.append("eyes_blend:%s" % eb)
		eye_bit += ", hint of %s" % str(EYE_PROSE.get(eb, eb))
	var eye_col: Color = ph["eye_color"]
	eye_bit += " (%s)" % eye_col.to_html(false)
	prose.append(eye_bit)
	var brow := str(ph["loci"]["brow"].get("id", "straight"))
	tokens.append("brow:%s" % brow)
	heritable.append("brow:%s" % brow)
	prose.append(str(BROW_PROSE.get(brow, brow + " brows")))
	var ears := str(ph["loci"]["ears"].get("id", "round"))
	tokens.append("ears:%s" % ears)
	heritable.append("ears:%s" % ears)
	prose.append(str(EAR_PROSE.get(ears, ears + " ears")))
	var face: Dictionary = ph.get("face", {})
	for k in CKGenome.FACE_KEYS:
		var bi := _band(float(face.get(k, 0.0)))
		var word: Array = FACE_WORD.get(k, ["mid", "mid", "mid"])
		var phrase: Array = FACE_PROSE.get(k, ["", "", ""])
		var tok := "face.%s:%s" % [k, str(word[bi])]
		tokens.append(tok)
		heritable.append(tok)
		prose.append(str(phrase[bi]))
	var mk_e: Dictionary = ph["loci"]["mark"]
	var mk := str(mk_e.get("id", "none"))
	var mk_s := float(mk_e.get("strength", 1.0))
	tokens.append("mark:%s" % mk)
	heritable.append("mark:%s" % mk)
	if mk == "none":
		prose.append("no birthmark")
	elif mk == "ember_sigil":
		var faint := mk_s < 0.99
		var stok := "mark_strength:%s" % ("faint" if faint else "full")
		tokens.append(stok)
		heritable.append(stok)
		prose.append("a faint ember vein under the eye" if faint else "an ember vein under the eye")
	elif mk == "crown_rime":
		tokens.append("mark_strength:full")
		heritable.append("mark_strength:full")
		prose.append("a frost-crystal birthmark at the left temple")
	else:
		prose.append(mk)
	var scars: Array = []
	var raw = c.get("scars")
	if typeof(raw) == TYPE_ARRAY:
		scars = (raw as Array).duplicate()
	scars.sort()
	if scars.is_empty():
		tokens.append("scar:none")
		prose.append("unscarred skin")
	else:
		for s in scars:
			tokens.append("scar:%s" % str(s))
			prose.append(str(SCAR_PROSE.get(str(s), "a scar")))
	var skin: Color = ph["skin_color"]
	prose.append("skin tone %s" % skin.to_html(false))
	tokens.append("bloodline:%s" % str(ph.get("bloodline", "")))
	return {
		"tokens": tokens,
		"heritable": heritable,
		"prose": prose,
		"age_stage": stage,
		"seed_payload": seed_payload(c),
	}

static func descriptors(c: Object) -> Dictionary:
	return describe(c)

static func positive_prompt(c: Object) -> String:
	var q: Dictionary = style_lock().get("qwen", {})
	var prefix := str(q.get("prefix", ""))
	var accent_key := "enemy_accent" if str(c.get("faction")) == "enemy" else "ally_accent"
	var accent := str(q.get(accent_key, ""))
	var d := describe(c)
	var body := ", ".join(d["prose"])
	var parts: PackedStringArray = []
	if prefix != "":
		parts.append(prefix)
	if accent != "":
		parts.append(accent)
	parts.append(HALF_BODY)
	if body != "":
		parts.append(body)
	var hook := _bloodline_clause(c)
	if hook != "":
		parts.append(hook)
	return " ".join(parts)

static func negative_prompt(_c: Object = null) -> String:
	return str(style_lock().get("qwen", {}).get("negative", ""))

static func out_rel(unit_id: String) -> String:
	return "project/assets/art/portraits/genome/%s.png" % file_stem(unit_id)

static func manifest_entry(c: Object) -> Dictionary:
	var uid := str(c.get("id"))
	return {
		"unit_id": uid,
		"seed": seed_for(c),
		"positive": positive_prompt(c),
		"negative": negative_prompt(c),
		"out_path": out_rel(uid),
	}

static func build_manifest(units: Array) -> Array:
	var rows: Array = []
	for u in units:
		rows.append(manifest_entry(u))
	return rows

static func export_manifest(units: Array, path: String) -> int:
	var rows := build_manifest(units)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("manifest write failed: " + path)
		return -1
	f.store_string(JSON.stringify(rows, "\t"))
	f.close()
	return rows.size()

static func portrait_dir_abs() -> String:
	if dir_override != "":
		return dir_override
	return ProjectSettings.globalize_path(RES_DIR)

static func _load_png(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

static func texture(c: Object) -> Texture2D:
	var stem := file_stem(str(c.get("id")))
	if _mem.has(stem) and _mem[stem] is Texture2D:
		return _mem[stem]
	if _miss.has(stem):
		return null
	var abs_png := portrait_dir_abs().path_join(stem + ".png")
	var hit := _load_png(abs_png)
	if hit != null:
		_mem[stem] = hit
		return hit
	if dir_override == "":
		var res_path := RES_DIR + stem + ".png"
		if ResourceLoader.exists(res_path):
			var tex: Texture2D = load(res_path)
			if tex != null:
				_mem[stem] = tex
				return tex
		var user_hit := _load_png(USER_DIR + stem + ".png")
		if user_hit != null:
			_mem[stem] = user_hit
			return user_hit
		var legacy := cache_key(c)
		if ResourceLoader.exists(RES_DIR + legacy + ".png"):
			var tex2: Texture2D = load(RES_DIR + legacy + ".png")
			if tex2 != null:
				_mem[stem] = tex2
				return tex2
		var user_legacy := _load_png(USER_DIR + legacy + ".png")
		if user_legacy != null:
			_mem[stem] = user_legacy
			return user_legacy
	_miss[stem] = true
	return null

static func clear_mem() -> void:
	_mem.clear()
	_miss.clear()

static func cache_key(c: Object) -> String:
	_ensure(c)
	var g: Dictionary = {}
	if typeof(c.get("genome")) == TYPE_DICTIONARY:
		g = c.get("genome") as Dictionary
	var blood: Dictionary = {}
	if typeof(c.get("blood_mix")) == TYPE_DICTIONARY:
		blood = c.get("blood_mix") as Dictionary
	var scars: Array = []
	if typeof(c.get("scars")) == TYPE_ARRAY:
		scars = c.get("scars") as Array
	var honors: Array = []
	if typeof(c.get("honors")) == TYPE_ARRAY:
		honors = c.get("honors") as Array
	var payload: Dictionary = {
		"g": g,
		"blood": blood,
		"sex": str(c.get("gender")),
		"age_band": age_stage_of(c),
		"job": str(c.get("job_id")),
		"scars": scars,
		"honors": honors,
	}
	return "%08x" % (hash(JSON.stringify(payload)) & 0x7fffffff)

static func _copy_png(src: String, dest: String) -> bool:
	var img := Image.load_from_file(src)
	if img == null:
		return false
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	return img.save_png(dest) == OK

static func ingest_dir(src_dir: String) -> Dictionary:
	var mapped := {}
	var skipped: Array = []
	if not DirAccess.dir_exists_absolute(src_dir):
		return {"ok": false, "error": "missing dir", "mapped": mapped, "skipped": skipped, "count": 0}
	var dest := portrait_dir_abs()
	DirAccess.make_dir_recursive_absolute(dest)
	var da := DirAccess.open(src_dir)
	if da == null:
		return {"ok": false, "error": "cannot open", "mapped": mapped, "skipped": skipped, "count": 0}
	for fn in da.get_files():
		if not str(fn).to_lower().ends_with(".png"):
			continue
		var stem := file_stem(str(fn).get_basename())
		var to := dest.path_join(stem + ".png")
		if not _copy_png(src_dir.path_join(str(fn)), to):
			skipped.append(str(fn))
			continue
		mapped[stem] = to
		_mem.erase(stem)
		_miss.erase(stem)
	return {"ok": skipped.is_empty(), "mapped": mapped, "skipped": skipped, "count": mapped.size()}

static func ingest_manifest(manifest_path: String, rendered_root: String = "") -> Dictionary:
	var raw := FileAccess.get_file_as_string(manifest_path)
	var data = JSON.parse_string(raw)
	if typeof(data) != TYPE_ARRAY:
		return {"ok": false, "error": "manifest is not a JSON array", "mapped": {}, "missing": [], "count": 0}
	var dest := portrait_dir_abs()
	DirAccess.make_dir_recursive_absolute(dest)
	var proj := ProjectSettings.globalize_path("res://")
	if proj.ends_with("/"):
		proj = proj.substr(0, proj.length() - 1)
	var repo := proj.get_base_dir()
	var mapped := {}
	var missing: Array = []
	for row in data:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var uid := file_stem(str(row.get("unit_id", "")))
		if uid == "":
			continue
		var cands: Array = []
		if rendered_root != "":
			cands.append(rendered_root.path_join(uid + ".png"))
			cands.append(rendered_root.path_join(str(row.get("unit_id", "")) + ".png"))
		var op := str(row.get("out_path", ""))
		if op != "":
			cands.append(op)
			cands.append(repo.path_join(op))
		var src := ""
		for cand in cands:
			if FileAccess.file_exists(str(cand)):
				src = str(cand)
				break
		if src == "" or not _copy_png(src, dest.path_join(uid + ".png")):
			missing.append(uid)
			continue
		mapped[uid] = dest.path_join(uid + ".png")
		_mem.erase(uid)
		_miss.erase(uid)
	return {"ok": missing.is_empty(), "mapped": mapped, "missing": missing, "count": mapped.size()}

static func kinship_report(parent_a: Object, parent_b: Object, child: Object) -> Dictionary:
	var ta := describe(parent_a)
	var tb := describe(parent_b)
	var tc := describe(child)
	var union := {}
	for t in ta["heritable"]:
		union[str(t)] = true
	for t in tb["heritable"]:
		union[str(t)] = true
	var shared: Array = []
	var only: Array = []
	for t in tc["heritable"]:
		if union.has(str(t)):
			shared.append(str(t))
		else:
			only.append(str(t))
	var frac := 0.0
	if (tc["heritable"] as Array).size() > 0:
		frac = float(shared.size()) / float((tc["heritable"] as Array).size())
	return {
		"father_tokens": ta["tokens"],
		"mother_tokens": tb["tokens"],
		"child_tokens": tc["tokens"],
		"father_heritable": ta["heritable"],
		"mother_heritable": tb["heritable"],
		"child_heritable": tc["heritable"],
		"father_prose": ta["prose"],
		"mother_prose": tb["prose"],
		"child_prose": tc["prose"],
		"shared": shared,
		"child_only": only,
		"fraction": frac,
	}

static func _carrier_loci(silver_side: bool) -> Dictionary:
	if silver_side:
		return {
			"hair": ["ash_brown", "frost_silver"],
			"eyes": ["slate", "rime"],
			"brow": ["straight", "soft"],
			"ears": ["round", "crest"],
			"mark": ["none", "crown_rime"],
		}
	return {
		"hair": ["ink_black", "frost_silver"],
		"eyes": ["amber", "dusk"],
		"brow": ["thick", "straight"],
		"ears": ["round", "crest"],
		"mark": ["none", "ember_sigil"],
	}

static func _demo_person(id: String, gender: String, face_base: float, loci: Dictionary, rng: RandomNumberGenerator) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = id
	c.gender = gender
	c.age = 28
	c.blood_mix = {"ember_noble": 0.55, "frost_crown": 0.25, "river_ward": 0.20}
	c.faction = "player"
	c.job_id = "light_inf"
	c.appearance = {"hair": "ink_black", "eyes": "amber", "brow": "straight", "scar": "none"}
	var g := {"loci": loci.duplicate(true), "face": {}, "body": {}, "v": 2}
	for k in CKGenome.FACE_KEYS:
		g["face"][k] = clampf(face_base + rng.randf_range(-0.06, 0.06), -1.0, 1.0)
	for k in CKGenome.BODY_KEYS:
		g["body"][k] = clampf(0.2 + rng.randf_range(-0.05, 0.05), -1.0, 1.0)
	c.genome = g
	CKGenome.sync_appearance(c)
	return c

static func _demo_child(father: CKCharacter, mother: CKCharacter, gen: int, rng: RandomNumberGenerator) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = "lin_c%d_%d" % [gen, rng.randi()]
	c.name = c.id
	c.gender = "f" if rng.randf() < 0.5 else "m"
	c.age = 22
	c.blood_mix = {"ember_noble": 0.5, "frost_crown": 0.25, "river_ward": 0.25}
	c.faction = "player"
	c.job_id = "light_inf"
	c.genome = CKGenome.cross(father.genome, mother.genome, c.blood_mix, rng)
	CKGenome.sync_appearance(c)
	return c

## Three generations of CKGenome.cross from carrier founders. Each row is one heir vs their two parents.
static func demo_lineage(seed_i: int = 89) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var father := _demo_person("lin_f0", "m", 0.62, _carrier_loci(false), rng)
	var mother := _demo_person("lin_m0", "f", 0.58, _carrier_loci(true), rng)
	var rows: Array = []
	for gen in 3:
		var child := _demo_child(father, mother, gen, rng)
		rows.append({
			"gen": gen + 1,
			"father": father,
			"mother": mother,
			"child": child,
			"report": kinship_report(father, mother, child),
		})
		if str(child.gender) == "m":
			father = child
			mother = _demo_person("lin_sp%d" % gen, "f", 0.60, _carrier_loci(gen % 2 == 0), rng)
		else:
			mother = child
			father = _demo_person("lin_sp%d" % gen, "m", 0.60, _carrier_loci(gen % 2 == 0), rng)
	return rows
