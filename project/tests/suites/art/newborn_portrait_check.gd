extends Node
## A real birth resolves a genome-seeded Qwen plate from age alone: 0–2 infant,
## 3–11 child, 12–15 teen, 16+ adult. Display size must not change the file.
## The plate is stable across save/load and swaps when a birthday crosses a band.

const AGES := [0, 1, 2, 3, 5, 11, 12, 15, 16]
const SIZES := [72, 128, 400, 640]


func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL newborn_portrait: ", err)
		get_tree().quit(1)
		return
	print("NEWBORN PORTRAIT PASS")
	get_tree().quit(0)


func _path_at(c: CKCharacter, age: int, size: int) -> String:
	c.age = age
	UnitArt.clear_cache()
	CKGenomePortrait.clear_mem()
	var _tex: Texture2D = UnitArt.portrait(c, size)
	return str(c.get_meta("ck_portrait_path", ""))


func _check(c: CKCharacter, tag: String) -> String:
	var by_age := {}
	for age in AGES:
		var got := _one_age(c, tag, int(age))
		if str(got.get("err", "")) != "":
			return str(got["err"])
		by_age[int(age)] = str(got["path"])
	c.age = 0
	return _band_locks(tag, by_age)


func _one_age(c: CKCharacter, tag: String, age: int) -> Dictionary:
	var paths := {}
	for size in SIZES:
		var path := _path_at(c, age, int(size))
		if path == "":
			return {"err": "%s empty path age %d size %d" % [tag, age, size]}
		if UnitArt.portrait(c, int(size)) == null:
			return {"err": "%s null portrait age %d size %d" % [tag, age, size]}
		paths[path] = true
	if paths.size() != 1:
		return {"err": "%s age %d size changed file %s" % [tag, age, str(paths.keys())]}
	var chosen := str(paths.keys()[0])
	var stem_err := _stem_for(tag, age, chosen)
	if stem_err != "":
		return {"err": stem_err}
	var kind := UnitArt.portrait_kind(c)
	if age <= 2 and kind != "infant":
		return {"err": "%s kind age %d = %s" % [tag, age, kind]}
	return {"err": "", "path": chosen}


func _stem_for(tag: String, age: int, path: String) -> String:
	var stem := CKArtPaths._portrait_stem(path).get_file()
	var band := UnitArt.display_band(age)
	if band == "infant" and not stem.begins_with("infant_"):
		return "%s age %d stem %s" % [tag, age, stem]
	if band == "child" and not stem.begins_with("youth_"):
		return "%s age %d child stem %s" % [tag, age, stem]
	if band == "teen" and not stem.begins_with("youth_"):
		return "%s age %d teen stem %s" % [tag, age, stem]
	if band == "adult" and (stem.begins_with("infant_") or stem.begins_with("youth_")):
		return "%s age %d adult stem %s" % [tag, age, stem]
	return ""


func _band_locks(tag: String, by_age: Dictionary) -> String:
	if by_age[0] != by_age[2]:
		return "%s infant band split %s vs %s" % [tag, by_age[0], by_age[2]]
	if by_age[3] != by_age[11]:
		return "%s child band split" % tag
	if by_age[12] != by_age[15]:
		return "%s teen band split" % tag
	if by_age[2] == by_age[3]:
		return "%s 2→3 did not swap" % tag
	if by_age[11] == by_age[12]:
		return "%s 11→12 did not swap" % tag
	if by_age[15] == by_age[16]:
		return "%s 15→16 did not swap" % tag
	return ""


## Same JSON path the save slots write, without touching player slots.
func _roundtrip() -> bool:
	var parsed = JSON.parse_string(JSON.stringify(GameState.build_save_data()))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	return GameState.apply_save_data(parsed)


func _run() -> String:
	CKPortraitBank.clear_cache()
	CKGenomePortrait.clear_mem()
	GameState.new_game("烬行", "灰旗", "frost")
	var mom := GameState.get_leader()
	if mom == null:
		return "no leader"
	mom.gender = "f"
	mom.age = 24
	var kid: CKCharacter = Lineage.birth_child(mom)
	if kid == null:
		return "birth_child null"
	if not GameState.characters.has(kid.id):
		GameState.characters[kid.id] = kid
	if int(kid.age) != 0:
		return "newborn age %d" % kid.age
	var e := _check(kid, "fresh")
	if e != "":
		return e
	## Save at age 0, reload, re-check every band on the loaded object.
	CKGenomePortrait.clear_mem()
	if not _roundtrip():
		return "save/load failed"
	var back: CKCharacter = GameState.characters.get(kid.id)
	if back == null:
		return "child lost after load"
	e = _check(back, "loaded")
	if e != "":
		return e
	## Birthday advance on a saved 2-year-old: age 3 after load must leave the infant plate.
	back.age = 2
	if not _roundtrip():
		return "save/load 2 failed"
	var b2: CKCharacter = GameState.characters.get(kid.id)
	b2.age += 1
	var infant_path := _path_at(b2, 2, 72)
	var child_path := _path_at(b2, 3, 72)
	if infant_path == "" or infant_path == child_path:
		return "birthday 2->3 kept infant plate %s" % infant_path
	## Export-path bank discovery: listing must still find plates when only *.import names exist.
	if CKPortraitBank._strip_export_suffix("infant_x.webp.import") != "infant_x.webp":
		return "export suffix strip"
	if not CKPortraitBank.has_plates():
		return "bank not discovered via res://"
	return ""
