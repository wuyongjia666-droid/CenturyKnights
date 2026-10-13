extends Node
## P0 playtest: the tutorial "skip, just marry someone" action must marry the captain from a
## cold start (reputation none), to the opposite sex, for either captain sex.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL auto marry: ", err)
		get_tree().quit(1)
	else:
		print("AUTO MARRY PASS")
		get_tree().quit(0)

func _run() -> String:
	for g in ["m", "f"]:
		GameState.new_game("烬行", "灰旗", GameState.crest_color)
		var lead: CKCharacter = GameState.get_leader()
		lead.gender = g
		GameState.reputation["ashland"] = 0
		var ch0 = load("res://scenes/story/chapter_player.tscn").instantiate()
		ch0.chapter_path = "res://data/story/chapters/ch0.json"
		ch0.lock_path = true
		ch0.suppress_scene_change = true
		add_child(ch0)
		await get_tree().process_frame
		ch0._auto_marry()
		if not GameState.flag("married") or lead.spouse_id == "":
			return "captain %s: skip did nothing (%s)" % [g, ch0._hint.text]
		var sp: CKCharacter = GameState.characters.get(lead.spouse_id)
		if sp == null or str(sp.gender) == g:
			return "captain %s: spouse gender %s" % [g, sp.gender if sp else "?"]
		ch0.queue_free()
		await get_tree().process_frame
	return ""
