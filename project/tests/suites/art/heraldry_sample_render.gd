extends Node
## Renders 12 sample arms PNGs into user://heraldry_samples/ then copies note to stdout.

func _ready() -> void:
	var out_dir := "user://heraldry_samples"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var samples: Array = [
		{"id": "01_ashbanner_knight", "nation": "ashbanner", "rank": "knight", "mode": "shield"},
		{"id": "02_shuoying_baron", "nation": "shuoying", "rank": "baron", "mode": "arms"},
		{"id": "03_qinghe_count", "nation": "qinghe", "rank": "count", "mode": "shield"},
		{"id": "04_lantern_knight", "nation": "lantern", "rank": "knight", "mode": "banner"},
		{"id": "05_frostcrown_royal", "nation": "frostcrown", "rank": "royal", "mode": "arms"},
		{"id": "06_emberold_duke", "nation": "emberold", "rank": "duke", "mode": "arms"},
		{"id": "07_saltmarsh_knight", "nation": "saltmarsh", "rank": "knight", "mode": "shield"},
		{"id": "08_irongorge_baron", "nation": "irongorge", "rank": "baron", "mode": "shield"},
		{"id": "09_starriver_count", "nation": "starriver", "rank": "count", "mode": "shield"},
		{"id": "10_southzephyr_knight", "nation": "southzephyr", "rank": "knight", "mode": "shield"},
		{"id": "11_family_noble", "nation": "qinghe", "rank": "baron", "mode": "shield", "family_tier": "noble"},
		{"id": "12_family_royal", "nation": "frostcrown", "rank": "duke", "mode": "arms", "family_tier": "royal"},
	]
	var written: Array = []
	for s in samples:
		var spec := CKHeraldry.from_nation(str(s.nation), str(s.rank))
		spec = CKHeraldry.apply_rank(spec, str(s.rank))
		if s.has("family_tier"):
			# Family arms (族徽): unique core + fixed company-banner canton + tier ornament.
			var company := CKHeraldry.from_nation("ashbanner")
			var core := CKHeraldry.generate_unique_arms(str(s.nation), str(s.id), {CKHeraldry.core_key(company): "company"})
			var fam := CKHeraldry.family_display_arms(core, company, str(s.family_tier))
			fam["achievement"] = spec.get("achievement", {})
			spec = fam
		var img: Image
		match str(s.mode):
			"banner":
				img = CKHeraldryRender.compose(spec, 384, 560, 0.15, "banner")
			"arms":
				img = CKHeraldryRender.compose(spec, 512, 600, 0.0, "arms")
			_:
				img = CKHeraldryRender.compose(spec, 512, 600, 0.0, "shield")
		var path := out_dir.path_join(str(s.id) + ".png")
		img.save_png(path)
		written.append(ProjectSettings.globalize_path(path))
		print("WROTE ", path, " opaque=", _opaque(img))
	print("HERALDRY SAMPLES ", ",".join(written))
	print("HERALDRY SAMPLE RENDER PASS")
	get_tree().quit(0)

func _opaque(img: Image) -> int:
	var n := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.1:
				n += 1
	return n
