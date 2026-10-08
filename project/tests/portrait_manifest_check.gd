extends Node
## Plan A: genome seed + style-lock prompt, manifest round-trip, ingest by unit_id, fallback when missing.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL portrait: ", err)
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _person(id: String, hair_a: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = id
	c.gender = "f"
	c.age = 24
	c.job_id = "hunter"
	c.faction = "player"
	c.blood_mix = {"river_ward": 0.7, "common_ash": 0.3}
	c.appearance = {"hair": "wheat", "eyes": "river_blue", "brow": "arch", "scar": "none"}
	c.scars = ["cheek_l"]
	c.genome = {
		"loci": {
			"hair": [hair_a, "wheat"],
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

func _run() -> String:
	var lock: Dictionary = CKGenomePortrait.style_lock()
	var prefix := str(lock.get("qwen", {}).get("prefix", ""))
	var negative := str(lock.get("qwen", {}).get("negative", ""))
	if prefix == "" or negative == "" or not prefix.begins_with("CenturyKnights style lock"):
		return "style lock prefix/negative missing"
	var a := _person("manifest_a", "wheat")
	var b := _person("manifest_b", "wheat")
	b.id = "manifest_b"
	if CKGenomePortrait.seed_for(a) != CKGenomePortrait.seed_for(a):
		return "seed not stable"
	if CKGenomePortrait.seed_for(a) != CKGenomePortrait.seed_for(b):
		return "seed must follow the genome, not unit_id"
	if CKGenomePortrait.seed_payload(a) != CKGenomePortrait.seed_payload(b):
		return "payload drifted"
	var changed := _person("manifest_a", "ink_black")
	if CKGenomePortrait.seed_for(changed) == CKGenomePortrait.seed_for(a):
		return "hair allele did not change the seed"
	var desc: Dictionary = CKGenomePortrait.descriptors(a)
	var tokens: Array = desc["tokens"]
	if tokens.find("hair:wheat") < 0 or tokens.find("eyes:river_blue") < 0:
		return "missing hair/eye tokens %s" % str(tokens)
	if tokens.find("face.width:narrow") < 0:
		return "face polygenic band missing %s" % str(tokens)
	if tokens.find("scar:cheek_l") < 0 or tokens.find("age:young_adult") < 0:
		return "scar/age tokens missing %s" % str(tokens)
	var stage_err := _stages(a)
	if stage_err != "":
		return stage_err
	var pos := CKGenomePortrait.positive_prompt(a)
	if not pos.begins_with(prefix):
		return "positive does not start with style-lock prefix"
	if not pos.contains("wheat-blonde hair") or not pos.contains("Waist-up half-body"):
		return "positive missing half-body descriptors"
	if CKGenomePortrait.negative_prompt(a) != negative:
		return "negative is not the style-lock negative"
	CKGenomePortrait.set_bloodline_clause_hook(func(_u): return "BLOODLINE_HOOK_CLAUSE")
	var hooked := CKGenomePortrait.positive_prompt(a)
	CKGenomePortrait.set_bloodline_clause_hook(Callable())
	if not hooked.begins_with(prefix) or not hooked.contains("BLOODLINE_HOOK_CLAUSE"):
		return "bloodline hook not appended"
	if CKGenomePortrait.positive_prompt(a).contains("BLOODLINE_HOOK_CLAUSE"):
		return "bloodline hook leaked"
	var rows: Array = CKGenomePortrait.build_manifest([a, changed])
	if rows.size() != 6:
		return "manifest row count %d" % rows.size()
	for key in ["unit_id", "seed", "positive", "negative", "out_path"]:
		if not (rows[0] as Dictionary).has(key):
			return "manifest missing " + key
	if str(rows[0]["unit_id"]) != "manifest_a":
		return "unit_id"
	var current_seed := -1
	for row in rows:
		if str(row.get("unit_id")) == "manifest_a" and str(row.get("stage")) == "young_adult":
			current_seed = int(row.get("seed"))
			break
	if current_seed != CKGenomePortrait.seed_for(a):
		return "manifest seed"
	if str(rows[0]["out_path"]) != "project/assets/art/portraits/genome/manifest_a_infant.png":
		return "out_path %s" % str(rows[0]["out_path"])
	var current_path := ""
	for row in rows:
		if str(row.get("unit_id")) == "manifest_a" and str(row.get("stage")) == "young_adult":
			current_path = str(row.get("out_path"))
			break
	if current_path != "project/assets/art/portraits/genome/manifest_a_young_adult.png":
		return "current out_path %s" % current_path
	if str(rows[0]["negative"]) != negative:
		return "manifest negative"
	var mp := "/tmp/ck_portrait_manifest.json"
	if CKGenomePortrait.export_manifest([a], mp) != 3:
		return "export_manifest"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(mp))
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).size() != 3:
		return "exported json"
	CKGenomePortrait.dir_override = ""
	CKGenomePortrait.clear_mem()
	UnitArt.clear_cache()
	if CKGenomePortrait.texture(a) != null:
		return "unexpected genome texture before ingest"
	var kind_before := UnitArt.portrait_kind(a)
	if kind_before == "genome":
		return "kind genome without a plate"
	if kind_before not in ["named", "hireuniq", "bust", "geno", "proc"]:
		return "bad fallback kind " + kind_before
	if UnitArt.portrait(a, 96) == null:
		return "portrait fallback returned null"
	var src := "/tmp/ck_farm_src"
	var dest := "/tmp/ck_genome_plates"
	DirAccess.make_dir_recursive_absolute(src)
	DirAccess.make_dir_recursive_absolute(dest)
	var src_da := DirAccess.open(src)
	if src_da:
		for fn in src_da.get_files():
			src_da.remove(str(fn))
	var dest_da := DirAccess.open(dest)
	if dest_da:
		for fn2 in dest_da.get_files():
			dest_da.remove(str(fn2))
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.43, 0.83, 1.0))
	if img.save_png(src.path_join("manifest_a_young_adult.png")) != OK:
		return "save farm png"
	if img.save_png(src.path_join("manifest_a_youth.png")) != OK:
		return "save youth png"
	CKGenomePortrait.dir_override = dest
	CKGenomePortrait.clear_mem()
	var ing: Dictionary = CKGenomePortrait.ingest_dir(src)
	if int(ing.get("count", 0)) != 2 or not (ing["mapped"] as Dictionary).has("manifest_a_young_adult"):
		return "ingest_dir %s" % str(ing)
	CKGenomePortrait.clear_mem()
	UnitArt.clear_cache()
	if CKGenomePortrait.texture(a) == null:
		return "texture miss after ingest"
	if UnitArt.portrait_kind(a) != "genome":
		return "portrait_kind after ingest"
	if UnitArt.portrait(a, 96) == null:
		return "portrait null after ingest"
	DirAccess.remove_absolute(dest.path_join("manifest_a_young_adult.png"))
	CKGenomePortrait.clear_mem()
	UnitArt.clear_cache()
	if UnitArt.portrait_kind(a) != "genome":
		return "nearest stage should still supply a plate"
	a.age = 8
	CKGenomePortrait.clear_mem()
	if CKGenomePortrait.texture(a) == null:
		return "youth plate missed"
	a.age = 24
	CKGenomePortrait.clear_mem()
	DirAccess.remove_absolute(dest.path_join("manifest_a_youth.png"))
	CKGenomePortrait.clear_mem()
	UnitArt.clear_cache()
	if UnitArt.portrait_kind(a) == "genome":
		return "stale genome kind after delete"
	if UnitArt.portrait(a, 96) == null:
		return "fallback broke after delete"
	var rendered := "/tmp/ck_farm_rendered"
	DirAccess.make_dir_recursive_absolute(rendered)
	for stage_name in ["infant", "youth", "young_adult"]:
		if img.save_png(rendered.path_join("manifest_a_%s.png" % stage_name)) != OK:
			return "save rendered " + stage_name
	var ing2: Dictionary = CKGenomePortrait.ingest_manifest(mp, rendered)
	if int(ing2.get("count", 0)) != 3 or not (ing2.get("mapped", {}) as Dictionary).has("manifest_a_young_adult"):
		return "ingest_manifest %s" % str(ing2)
	CKGenomePortrait.clear_mem()
	if CKGenomePortrait.texture(a) == null:
		return "texture miss after manifest ingest"
	CKGenomePortrait.dir_override = ""
	CKGenomePortrait.clear_mem()
	print("PORTRAIT PASS seed=%d kind=%s" % [CKGenomePortrait.seed_for(a), kind_before])
	return ""

func _stages(a: CKCharacter) -> String:
	var saved := a.age
	var want := {0: "infant", 2: "infant", 3: "youth", 14: "youth", 15: "young_adult", 34: "young_adult", 35: "middle", 54: "middle", 55: "elder", 80: "elder"}
	for age_i in want.keys():
		a.age = int(age_i)
		if CKGenomePortrait.age_stage_of(a) != str(want[age_i]):
			a.age = saved
			return "stage map age %s -> %s" % [age_i, CKGenomePortrait.age_stage_of(a)]
	a.age = 24
	var base := CKGenomePortrait.identity_seed(a)
	var seed_young := CKGenomePortrait.seed_for(a)
	for age_i in [1, 8, 24, 40, 62]:
		a.age = age_i
		if CKGenomePortrait.identity_seed(a) != base:
			a.age = saved
			return "identity seed drifted at %d" % age_i
	a.age = 62
	if CKGenomePortrait.seed_for(a) == seed_young:
		a.age = saved
		return "stage offset did not move the render seed"
	a.age = 1
	var infant: Dictionary = CKGenomePortrait.describe(a)
	a.age = 62
	var elder: Dictionary = CKGenomePortrait.describe(a)
	var ib := {}
	for t in elder.get("identity", []):
		ib[str(t)] = true
	var hit := 0
	var idn: Array = infant.get("identity", [])
	for t in idn:
		if ib.has(str(t)):
			hit += 1
	var frac := 1.0 if idn.is_empty() else float(hit) / float(idn.size())
	if frac < CKGenomePortrait.IDENTITY_OVERLAP_MIN:
		a.age = saved
		return "identity overlap %.3f below threshold" % frac
	var infant_prose := " ".join(infant["prose"])
	var elder_prose := " ".join(elder["prose"])
	if infant_prose.find("swaddle") < 0 or infant_prose.find("carried") < 0:
		a.age = saved
		return "infant outfit missing"
	if elder_prose.find("elder robes") < 0 or elder_prose.find("thinning") < 0:
		a.age = saved
		return "elder hair/robes missing"
	if infant_prose == elder_prose:
		a.age = saved
		return "stage prose did not change"
	var roy := CKCharacter.new()
	roy.id = "age_ash"
	roy.gender = "m"
	roy.age = 10
	roy.rank = "count"
	roy.blood_mix = {"ash_chart": 1.0}
	roy.ensure_genome()
	CKBloodline.force_tier(roy.genome, "ashbanner", "royal", "m")
	CKBloodline.stamp_traits(roy.genome, "ashbanner", "full", "m", false)
	var hidden := CKBloodline.portrait_clause(roy)
	if hidden.find("cool grey cast along the jaw") >= 0:
		a.age = saved
		return "age-awakened jaw cast showed before 28"
	roy.age = 30
	var shown := CKBloodline.portrait_clause(roy)
	if shown.find("cool grey cast along the jaw") < 0:
		a.age = saved
		return "age-awakened jaw cast missing at 30"
	a.age = saved
	return ""
