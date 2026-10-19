extends Node
## #321: exports have no farm manifest. best_match must fall back to the packed plated index
## (data/art/genome_bank_index.json) and pick a same-sex, same-band plate that exists.


func _ready() -> void:
	var err := _run()
	CKPortraitBank.force_export_index = false
	CKPortraitBank.clear_cache()
	if err != "":
		print("FAIL bank export index: ", err)
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _sex_of_ident(ident: Array) -> String:
	for t in ident:
		if str(t).begins_with("gender:"):
			return str(t).get_slice(":", 1)
	return ""


func _run() -> String:
	var rows: Array = CKPortraitBank.load_bank_index()
	if rows.is_empty():
		return "index empty or missing"
	CKPortraitBank.force_export_index = true
	CKPortraitBank.clear_cache()
	var plated := {}
	for r in rows:
		plated[str(r["bucket_key"])] = r
	for step in [_check_exact, _check_near, _check_flip, _check_chars]:
		var err: String = step.call(rows, plated)
		if err != "":
			return err
	return ""


## 1) Every plated row matches itself exactly through the export path, and its plate loads.
func _check_exact(rows: Array, plated: Dictionary) -> String:
	for r in rows:
		var ident: Array = (r["identity"] as Array).duplicate()
		ident.sort()
		var m: Dictionary = CKPortraitBank.match_identity(
			ident, str(r["stage"]), str(r["bloodline"])
		)
		if not bool(m.get("hit", false)):
			return "row %s not hit on export path" % r["bucket_key"]
		var got := str(m.get("bucket_key", ""))
		if not plated.has(got):
			return "export match %s is not a plated row" % got
		var g: Dictionary = plated[got]
		if str(g["stage"]) != str(r["stage"]) or str(g["sex"]) != str(r["sex"]):
			return "row %s matched %s with another band/sex" % [r["bucket_key"], got]
	for i in range(0, rows.size(), 37):
		var key := str(rows[i]["bucket_key"])
		if CKPortraitBank._load_plate(key, "small") == null:
			return "plate %s missing (small tier)" % key
	var installed := 0
	for st in CKPortraitBank._by_stage.keys():
		installed += (CKPortraitBank._by_stage[st] as Array).size()
	if installed != rows.size():
		return (
			"export path loaded %d rows, not the %d index rows (farm manifest leaked in?)"
			% [installed, rows.size()]
		)
	return ""


## 2) A one-token change (not gender) still lands on the same sex and band.
func _check_near(rows: Array, plated: Dictionary) -> String:
	for i in range(0, rows.size(), 5):
		var r: Dictionary = rows[i]
		var ident: Array = []
		var dropped := false
		for t in r["identity"]:
			var s := str(t)
			if not dropped and s.begins_with("face."):
				ident.append(s + "_x")
				dropped = true
			else:
				ident.append(s)
		ident.sort()
		var m2: Dictionary = CKPortraitBank.match_identity(ident, str(r["stage"]), "")
		var got2 := str(m2.get("bucket_key", ""))
		if got2 == "":
			return "near miss for %s returned nothing" % r["bucket_key"]
		var g2: Dictionary = plated[got2]
		if str(g2["sex"]) != _sex_of_ident(ident) or str(g2["stage"]) != str(r["stage"]):
			return "near %s -> %s crossed sex/band" % [r["bucket_key"], got2]
	return ""


## 2b) Flipping only the gender token must land on the other sex (never the original row).
func _check_flip(rows: Array, plated: Dictionary) -> String:
	for i in range(0, rows.size(), 9):
		var r: Dictionary = rows[i]
		var want := "m" if str(r["sex"]) == "f" else "f"
		var flipped: Array = []
		for t in r["identity"]:
			flipped.append("gender:" + want if str(t).begins_with("gender:") else str(t))
		flipped.sort()
		var m3: Dictionary = CKPortraitBank.match_identity(flipped, str(r["stage"]), "")
		var got3 := str(m3.get("bucket_key", ""))
		if got3 != "" and str(plated[got3]["sex"]) != want:
			return (
				"gender flip of %s still matched %s (%s)"
				% [r["bucket_key"], got3, plated[got3]["sex"]]
			)
	return ""


## 3) Real characters, both sexes, every band: try_texture never hands back the other sex.
func _check_chars(rows: Array, plated: Dictionary) -> String:
	var n_chars := 0
	var hits := 0
	for st in CKGenomePortrait.STAGES:
		for sex in ["m", "f"]:
			for k in 6:
				var c := CKCharacter.new()
				c.id = "export_idx_%s_%s_%d" % [st, sex, k]
				c.gender = sex
				c.age = CKGenomePortrait.stage_apex(str(st))
				c.ensure_genome()
				var pack: Dictionary = CKPortraitBank.try_texture(c, "small")
				var stem := str(pack.get("stem", ""))
				if pack.get("texture") == null or stem == "":
					return "no plate for %s" % c.id
				if not stem.begins_with(str(st) + "_"):
					return "%s got %s from another band" % [c.id, stem]
				var ps := CKPortraitBank.plate_sex(stem)
				if ps != sex:
					return "%s (%s) got plate %s labelled %s" % [c.id, sex, stem, ps]
				var pm: Dictionary = CKPortraitBank.plated_match(c)
				var bm: Dictionary = CKPortraitBank.best_match(c)
				if str(pm.get("bucket_key", "")) != str(bm.get("bucket_key", "")):
					return (
						"%s: export best_match %s != plated_match %s"
						% [c.id, bm.get("bucket_key"), pm.get("bucket_key")]
					)
				if bool(pm.get("hit", false)):
					hits += 1
				n_chars += 1
	print("BANK EXPORT INDEX PASS rows=%d chars=%d plated_hits=%d" % [rows.size(), n_chars, hits])
	return ""
