extends Node
## v9.1 fields round-trip, and v8.7 / v8.8 saves gain blood, rites, titles, courts and age stage.

const _StoryCheck = preload("res://tests/suites/core/story_state_check.gd")

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	var story_fails: Array = await _StoryCheck.run(self)
	for f in story_fails:
		_fails.append(f)
	_round_trip()
	_migrate("v8.7", false)
	_migrate("v8.8", true)
	if _fails.is_empty():
		print("SAVE ROUNDTRIP PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL save: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _person(tag: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = "save_" + tag
	c.name = "验档·" + tag
	c.gender = "f"
	c.age = 34
	c.rank = "count"
	c.blood_mix = {"frost_crown": 0.7, "common_ash": 0.3}
	c.blood_meta = {
		"verified": true, "verdict": "shown", "rites": ["frost", "register"],
		"title": "count", "lamp_seat": "baron", "merit": 6,
	}
	c.honors = ["frost_bond", "paper_patent"]
	c.ensure_genome()
	CKBloodline.force_tier(c.genome, "frostcrown", "royal", "f")
	CKBloodline.stamp_traits(c.genome, "frostcrown", "full", "f", false)
	return c

func _round_trip() -> void:
	GameState.new_game("烬行", "灰旗", "#c9a227")
	var c := _person("round")
	GameState.characters[c.id] = c
	World.royal_courts = CKCourt.blank_courts(91)
	World.royal_courts["year"] = 12
	var stage := CKGenomePortrait.age_stage_of(c)
	var sig := JSON.stringify(c.genome.get("sig", {}))
	_ok(GameState.save_game(), "save_game")
	var raw_text := FileAccess.get_file_as_string(GameState.SAVE_PATH)
	var raw = JSON.parse_string(raw_text)
	_ok(typeof(raw) == TYPE_DICTIONARY and str(raw.get("schema", "")) == "v9.1", "schema v9.1 written")
	var row: Dictionary = raw.get("characters", {}).get(c.id, {})
	_ok(str(row.get("age_stage", "")) == stage, "age stage persisted")
	_ok(str(row.get("blood_meta", {}).get("lamp_seat", "")) == "baron", "lamp seat persisted")
	_ok((row.get("blood_meta", {}).get("rites", []) as Array).has("frost"), "rites persisted")
	_ok(bool(row.get("blood_meta", {}).get("verified", false)), "blood test persisted")
	_ok(str(row.get("blood_meta", {}).get("title", "")) == "count", "title persisted")
	_ok(typeof(raw.get("world_v87", {}).get("royal_courts", {})) == TYPE_DICTIONARY, "royal courts persisted")
	c.age = 2
	c.blood_meta = {}
	World.royal_courts = {}
	_ok(GameState.load_game(), "load_game")
	var back: CKCharacter = GameState.characters.get(c.id)
	_ok(back != null, "character returned")
	if back == null:
		return
	_ok(CKGenomePortrait.age_stage_of(back) == stage, "age stage restored from age")
	_ok(str(back.blood_meta.get("verdict", "")) == "shown", "verdict restored")
	_ok(bool(back.blood_meta.get("verified", false)), "verified restored")
	_ok((back.blood_meta.get("rites", []) as Array).has("register"), "register rite restored")
	_ok(str(back.blood_meta.get("lamp_seat", "")) == "baron", "lamp seat restored")
	_ok(str(back.blood_meta.get("title", "")) == "count", "title restored")
	_ok("frost_bond" in back.honors, "frost bond restored")
	_ok(JSON.stringify(back.genome.get("sig", {})) == sig, "bloodline traits restored")
	_ok(typeof(World.royal_courts.get("nations", {})) == TYPE_DICTIONARY and World.royal_courts["nations"].size() == 10, "ten courts restored")
	_ok(int(World.royal_courts.get("year", 0)) == 12, "court year restored")

func _migrate(schema: String, with_genome: bool) -> void:
	var row := {
		"id": "legacy_%s" % schema, "name": "旧档", "gender": "m", "age": 41, "rank": "baron",
		"blood_mix": {"common_ash": 1.0}, "stats": {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8},
		"alive": true, "in_roster": true, "is_leader": true,
	}
	if with_genome:
		row["genome"] = {"v": 2, "loci": {"hair": ["ink_black", "ink_black"], "eyes": ["slate", "slate"], "brow": ["straight", "straight"], "ears": ["round", "round"], "mark": ["crown_rime", "none"]},
			"face": {"width": 0.1}, "body": {"height": 0.2}}
	var data := {
		"schema": schema, "version": 1, "started": true, "surname": "灰旗", "silver": 40, "food": 10,
		"year": 3, "month": 4, "characters": {row["id"]: row}, "world_v87": {"pos": "hq", "day": 2},
	}
	var migrated: Dictionary = GameState.migrate_save_data(data)
	_ok(str(migrated.get("schema", "")) == "v9.1", "%s schema upgraded" % schema)
	_ok(str(migrated.get("migrated_from", "")) == schema, "%s remembers its origin" % schema)
	var mrow: Dictionary = migrated["characters"][row["id"]]
	_ok(str(mrow.get("age_stage", "")) == "middle", "%s age stage filled" % schema)
	_ok(str(mrow.get("blood_meta", {}).get("title", "")) == "baron", "%s title filled from rank" % schema)
	_ok(mrow.get("blood_meta", {}).get("rites", []) is Array, "%s rites default" % schema)
	_ok(str(mrow.get("blood_meta", {}).get("lamp_seat", "x")) == "", "%s lamp seat default" % schema)
	_ok(not bool(mrow.get("blood_meta", {}).get("verified", true)), "%s unverified until a blood test" % schema)
	var courts: Dictionary = migrated.get("world_v87", {}).get("royal_courts", {})
	_ok(courts.get("nations", {}).size() == 10, "%s royal courts seeded" % schema)
	_ok(GameState.apply_save_data(migrated), "%s apply" % schema)
	var loaded: CKCharacter = GameState.characters.get(row["id"])
	_ok(loaded != null and not loaded.genome.is_empty() and loaded.genome.has("sig"), "%s genome has signature loci" % schema)
	if with_genome and loaded != null:
		var frost = loaded.genome.get("sig", {}).get("sig_frostcrown", [])
		_ok(frost is Array and str(frost[0]) == "rime_lash", "%s crown_rime migrated to rime lash" % schema)
