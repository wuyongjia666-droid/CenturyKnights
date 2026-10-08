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
	if tokens.find("scar:cheek_l") < 0 or tokens.find("age:adult") < 0:
		return "scar/age tokens missing %s" % str(tokens)
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
	if rows.size() != 2:
		return "manifest row count"
	for key in ["unit_id", "seed", "positive", "negative", "out_path"]:
		if not (rows[0] as Dictionary).has(key):
			return "manifest missing " + key
	if str(rows[0]["unit_id"]) != "manifest_a":
		return "unit_id"
	if int(rows[0]["seed"]) != CKGenomePortrait.seed_for(a):
		return "manifest seed"
	if str(rows[0]["out_path"]) != "project/assets/art/portraits/genome/manifest_a.png":
		return "out_path %s" % str(rows[0]["out_path"])
	if str(rows[0]["negative"]) != negative:
		return "manifest negative"
	var mp := "/tmp/ck_portrait_manifest.json"
	if CKGenomePortrait.export_manifest([a], mp) != 1:
		return "export_manifest"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(mp))
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).size() != 1:
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
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.43, 0.83, 1.0))
	if img.save_png(src.path_join("manifest_a.png")) != OK:
		return "save farm png"
	CKGenomePortrait.dir_override = dest
	CKGenomePortrait.clear_mem()
	var ing: Dictionary = CKGenomePortrait.ingest_dir(src)
	if int(ing.get("count", 0)) != 1 or not (ing["mapped"] as Dictionary).has("manifest_a"):
		return "ingest_dir %s" % str(ing)
	CKGenomePortrait.clear_mem()
	UnitArt.clear_cache()
	if CKGenomePortrait.texture(a) == null:
		return "texture miss after ingest"
	if UnitArt.portrait_kind(a) != "genome":
		return "portrait_kind after ingest"
	if UnitArt.portrait(a, 96) == null:
		return "portrait null after ingest"
	DirAccess.remove_absolute(dest.path_join("manifest_a.png"))
	CKGenomePortrait.clear_mem()
	UnitArt.clear_cache()
	if UnitArt.portrait_kind(a) == "genome":
		return "stale genome kind after delete"
	if UnitArt.portrait(a, 96) == null:
		return "fallback broke after delete"
	var rendered := "/tmp/ck_farm_rendered"
	DirAccess.make_dir_recursive_absolute(rendered)
	if img.save_png(rendered.path_join("manifest_a.png")) != OK:
		return "save rendered"
	var ing2: Dictionary = CKGenomePortrait.ingest_manifest(mp, rendered)
	if int(ing2.get("count", 0)) != 1 or not (ing2.get("mapped", {}) as Dictionary).has("manifest_a"):
		return "ingest_manifest %s" % str(ing2)
	CKGenomePortrait.clear_mem()
	if CKGenomePortrait.texture(a) == null:
		return "texture miss after manifest ingest"
	CKGenomePortrait.dir_override = ""
	CKGenomePortrait.clear_mem()
	print("PORTRAIT PASS seed=%d kind=%s" % [CKGenomePortrait.seed_for(a), kind_before])
	return ""
