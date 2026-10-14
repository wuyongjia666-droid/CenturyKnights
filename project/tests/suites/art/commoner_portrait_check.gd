extends Node
## Improve #4: folk recruits are tagged continental commoners and resolve a portrait.

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL commoner portrait: ", err)
		get_tree().quit(1)
		return
	print("COMMONER PORTRAIT PASS")
	get_tree().quit(0)

func _run() -> String:
	GameState.new_game("平民", "灰旗", GameState.crest_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var tagged := 0
	var pictured := 0
	for _i in 12:
		var roll: Dictionary = CKBloodline.roll_recruit("ashbanner", "tavern", rng, {"folk_only": true})
		roll["tier"] = "folk"
		var c: CKCharacter = CharacterFactory.make_tavern_candidate(rng, roll)
		if c.has_meta("continental_commoner") and bool(c.get_meta("continental_commoner")):
			tagged += 1
		var tex: Texture2D = UnitArt.portrait(c, 96, "small")
		if tex != null:
			pictured += 1
	if tagged < 10:
		return "folk tagged %d/12" % tagged
	if pictured < 10:
		return "portraits resolved %d/12" % pictured
	# farm tag bias puts civilian tags first
	var roll2: Dictionary = CKBloodline.roll_recruit("ashbanner", "tavern", rng, {"folk_only": true})
	roll2["tier"] = "folk"
	var c2: CKCharacter = CharacterFactory.make_tavern_candidate(rng, roll2)
	var tags: Array = UnitArt._farm_tags_for(c2)
	if tags.is_empty() or str(tags[0]) not in ["fisher", "merchant", "orphan", "mid", "youth", "recruit_raw"]:
		return "civilian tags not preferred: %s" % str(tags)
	return ""
