extends Node
## ART-01: 20 campaign_sim seeds, bucket hit rate, empty-bank fallback, unit plate before bucket.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL portrait bank: ", err)
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _wants_write() -> bool:
	for a in OS.get_cmdline_user_args():
		if str(a) == "--write":
			return true
	return false

func _run() -> String:
	var fb := _fallback_chain()
	if fb != "":
		return fb
	var built: Dictionary = CKPortraitBank.build_from_campaigns()
	var rows: Array = built.get("rows", [])
	var observed: Array = built.get("observed", [])
	if _wants_write():
		if CKPortraitBank.write_manifest(built.get("payload", {})) < 0:
			return "write manifest"
		print("WROTE %s buckets=%d" % [CKPortraitBank.manifest_path(), rows.size()])
	CKPortraitBank.clear_cache()
	var loaded := CKPortraitBank.load_manifest()
	if loaded.is_empty():
		return "manifest missing; re-run with --write"
	var drift := _same_rows(rows, loaded.get("buckets", []))
	if drift != "":
		return "manifest drift " + drift
	var why := CKPortraitBank.validate_payload(loaded)
	if why != "":
		return why
	var cov: Dictionary = CKPortraitBank.coverage(observed)
	if int(cov.get("births", 0)) <= 0:
		return "no births"
	if float(cov.get("hit_rate", 0.0)) < 0.95:
		return "hit rate %.3f" % float(cov.get("hit_rate", 0.0))
	if float(cov.get("mean_overlap", 0.0)) < CKPortraitBank.HIT_MIN:
		return "mean overlap %.3f" % float(cov.get("mean_overlap", 0.0))
	var nn := _nearest(loaded.get("buckets", []))
	if nn != "":
		return nn
	var plate := _plate_priority()
	if plate != "":
		return plate
	print("PORTRAIT BANK PASS births=%d hit_rate=%.3f mean_overlap=%.3f buckets=%d worst=%.3f" % [
		int(cov.get("births", 0)), float(cov.get("hit_rate", 0.0)), float(cov.get("mean_overlap", 0.0)),
		(loaded.get("buckets", []) as Array).size(), float(cov.get("worst", 0.0)),
	])
	return ""

func _same_rows(built: Array, loaded: Array) -> String:
	if built.size() != loaded.size():
		return "count %d vs %d" % [built.size(), loaded.size()]
	var by := {}
	for row in loaded:
		by[str(row.get("bucket_key", ""))] = row
	for row in built:
		var key := str(row.get("bucket_key", ""))
		if not by.has(key):
			return "missing " + key
		var other: Dictionary = by[key]
		if str(row.get("positive", "")) != str(other.get("positive", "")):
			return "positive " + key
		if int(row.get("seed", 0)) != int(other.get("seed", 0)):
			return "seed " + key
		if str(row.get("negative", "")) != str(other.get("negative", "")):
			return "negative " + key
		if _join(row.get("identity", [])) != _join(other.get("identity", [])):
			return "identity " + key
	return ""

func _join(ident: Array) -> String:
	var parts: PackedStringArray = []
	for t in ident:
		parts.append(str(t))
	parts.sort()
	return "|".join(parts)

func _nearest(rows: Array) -> String:
	var row: Dictionary = {}
	for r in rows:
		if str(r.get("stage", "")) == "young_adult":
			row = r
			break
	if row.is_empty():
		return "no young_adult bucket"
	var ident: Array = []
	for t in row.get("identity", []):
		ident.append(str(t))
	ident.append("face.extra:probe")
	var m: Dictionary = CKPortraitBank.match_identity(ident, "young_adult", str(row.get("bloodline", "")))
	if not bool(m.get("hit", false)):
		return "nearest miss overlap=%.3f" % float(m.get("overlap", 0.0))
	if float(m.get("overlap", 0.0)) < CKPortraitBank.HIT_MIN:
		return "nearest overlap %.3f" % float(m.get("overlap", 0.0))
	return ""

func _fallback_chain() -> String:
	var c := _person("bank_fallback")
	CKGenomePortrait.dir_override = ""
	CKPortraitBank.dir_override = ""
	CKGenomePortrait.clear_mem()
	if CKGenomePortrait.texture(c) != null:
		return "texture before any plate"
	var kind := UnitArt.portrait_kind(c)
	if kind == "genome":
		return "genome kind without a plate"
	if kind not in ["named", "hireuniq", "bust", "geno", "proc"]:
		return "bad fallback kind " + kind
	if UnitArt.portrait(c, 96) == null:
		return "fallback portrait null"
	return ""

func _plate_priority() -> String:
	var birth: CKCharacter = null
	for c in GameState.characters.values():
		if c.parent_ids.is_empty():
			continue
		birth = c
		break
	if birth == null:
		return "no birth left in the last campaign"
	var m: Dictionary = CKPortraitBank.best_match(birth)
	if not bool(m.get("hit", false)):
		return "birth missed its bucket"
	var unit_dir := "/tmp/ck_bank_unit"
	var bank_dir := "/tmp/ck_bank_plates"
	_reset_dir(unit_dir)
	_reset_dir(bank_dir)
	var stage := CKGenomePortrait.age_stage_of(birth)
	var stem := CKGenomePortrait.file_stem(str(birth.id))
	var unit_path := unit_dir.path_join("%s_%s.png" % [stem, stage])
	var bank_path := bank_dir.path_join(str(m.get("bucket_key", "")) + ".png")
	var unit_img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	unit_img.fill(Color8(110, 212, 255))
	var bank_img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	bank_img.fill(Color8(94, 224, 181))
	if unit_img.save_png(unit_path) != OK:
		return "save unit plate"
	if bank_img.save_png(bank_path) != OK:
		return "save bank plate"
	CKGenomePortrait.dir_override = unit_dir
	CKPortraitBank.dir_override = bank_dir
	CKGenomePortrait.clear_mem()
	var both := CKGenomePortrait.texture(birth)
	if both == null or both.get_width() != 4:
		_clear_overrides()
		return "unit plate should win over the bucket (%s)" % _plate_desc(both)
	DirAccess.remove_absolute(unit_path)
	CKGenomePortrait.clear_mem()
	var only_bank := CKGenomePortrait.texture(birth)
	if only_bank == null or only_bank.get_width() != 6:
		_clear_overrides()
		return "bucket plate missed after unit plate was removed (%s)" % _plate_desc(only_bank)
	DirAccess.remove_absolute(bank_dir.path_join(str(m.get("bucket_key", "")) + ".png"))
	CKGenomePortrait.clear_mem()
	if CKGenomePortrait.texture(birth) != null:
		_clear_overrides()
		return "texture remained after both plates were removed"
	if UnitArt.portrait_kind(birth) == "genome":
		_clear_overrides()
		return "genome kind after plates were removed"
	_clear_overrides()
	return ""

func _plate_desc(tex: Texture2D) -> String:
	if tex == null:
		return "null"
	return "%dx%d" % [tex.get_width(), tex.get_height()]

func _clear_overrides() -> void:
	CKGenomePortrait.dir_override = ""
	CKPortraitBank.dir_override = ""
	CKGenomePortrait.clear_mem()

func _reset_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)
	var da := DirAccess.open(path)
	if da == null:
		return
	for fn in da.get_files():
		da.remove(str(fn))

func _person(id: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = id
	c.gender = "f"
	c.age = 24
	c.job_id = "hunter"
	c.faction = "player"
	c.blood_mix = {"river_ward": 0.7, "common_ash": 0.3}
	c.appearance = {"hair": "wheat", "eyes": "river_blue", "brow": "arch", "scar": "none"}
	c.genome = {
		"loci": {
			"hair": ["wheat", "wheat"],
			"eyes": ["river_blue", "amber"],
			"brow": ["arch", "straight"],
			"ears": ["round", "round"],
			"mark": ["none", "none"],
		},
		"face": {"width": -0.42, "jaw": -0.2, "cheek": 0.1, "nose": -0.36, "eye_tilt": 0.4, "eye_size": -0.1, "brow_height": 0.05},
		"body": {"height": 0.2, "build": -0.3},
		"v": 2,
	}
	CKGenome.sync_appearance(c)
	return c
