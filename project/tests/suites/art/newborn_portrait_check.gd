extends Node
## Playtest bug: a newborn showed a teen face. A real birth must show the shared infant plate at
## 0–2, the shared child plate at 3–11, a non-infant/non-child plate at 12 and 16, at every
## display size, and the same after save/load (portrait re-resolves from age only).

const AGES := [0, 1, 2, 3, 5, 12, 16]
const SIZES := [72, 128, 400, 640]


func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL newborn_portrait: ", err)
		get_tree().quit(1)
		return
	print("NEWBORN PORTRAIT PASS")
	get_tree().quit(0)


func _want(c: CKCharacter, size: int) -> Texture2D:
	var p := UnitArt.band_plate_path(c)
	if p == "":
		return null
	return CKArtPaths.load_portrait(p, CKArtPaths.tier_for_display(size))


func _same(a: Texture2D, b: Texture2D) -> bool:
	if a == null or b == null:
		return false
	if a == b:
		return true
	return a.get_size() == b.get_size() and a.get_image().get_data() == b.get_image().get_data()


func _check(c: CKCharacter, tag: String) -> String:
	var infant_ref: Texture2D = CKArtPaths.load_portrait(UnitArt.INFANT_PLATE, "small")
	if infant_ref == null:
		return "infant plate missing " + UnitArt.INFANT_PLATE
	for age in AGES:
		c.age = int(age)
		for size in SIZES:
			var tex: Texture2D = UnitArt.portrait(c, size)
			if tex == null:
				return "%s null portrait age %d size %d" % [tag, age, size]
			var small: Texture2D = UnitArt.portrait(c, 72)
			if age <= 11:
				if not _same(tex, _want(c, size)):
					return "%s age %d size %d not shared %s plate" % [tag, age, size, UnitArt.display_band(age)]
				if age <= 2 and not _same(small, infant_ref):
					return "%s age %d not infant" % [tag, age]
				if age >= 3 and _same(small, infant_ref):
					return "%s age %d still infant" % [tag, age]
			else:
				if _same(small, infant_ref):
					return "%s age %d shows infant" % [tag, age]
				for g in ["f", "m"]:
					var kid: Texture2D = CKArtPaths.load_portrait(str(UnitArt.CHILD_PLATE[g]), "small")
					if _same(small, kid):
						return "%s age %d shows child plate" % [tag, age]
		var kind := UnitArt.portrait_kind(c)
		if age <= 2 and kind != "infant":
			return "%s kind age %d = %s" % [tag, age, kind]
	c.age = 0
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
	if _same(UnitArt.portrait(b2, 72), CKArtPaths.load_portrait(UnitArt.INFANT_PLATE, "small")):
		return "birthday 2->3 kept infant plate"
	## Export-path bank discovery: listing must still find plates when only *.import names exist.
	if CKPortraitBank._strip_export_suffix("infant_x.webp.import") != "infant_x.webp":
		return "export suffix strip"
	if not CKPortraitBank.has_plates():
		return "bank not discovered via res://"
	return ""
