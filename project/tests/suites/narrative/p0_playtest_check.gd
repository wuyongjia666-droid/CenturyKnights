extends Node
## P0 Android playtest regressions (2026-10-14):
## 1. ch0 opens on 20 second-person narrator lines; the captain must be on stage, not an empty plate.
## 2. A male captain's marriage candidates are women (and the reverse), face plates included.
## 3. The tutorial "skip, just marry someone" action actually marries the captain.

const CH0 := "res://data/story/chapters/ch0.json"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL p0 playtest: ", err)
		get_tree().quit(1)
	else:
		print("P0 PLAYTEST PASS")
		get_tree().quit(0)

func _run() -> String:
	for g in ["m", "f"]:
		var err := await _one(g)
		if err != "":
			return "[captain %s] %s" % [g, err]
	return _bank_labels()

func _one(g: String) -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var lead: CKCharacter = GameState.get_leader()
	lead.gender = g
	var want := "f" if g == "m" else "m"
	# 2) candidates
	for k in 4:
		GameState.refresh_marriage_candidates()
		for c in GameState.marriage_candidates:
			if str(c.gender) != want:
				return "candidate %s gender %s" % [c.name, c.gender]
			if str(c.genome.get("sex", want)) not in [want, ""]:
				return "candidate %s genome sex %s" % [c.name, c.genome.get("sex")]
	# 1) narrator + captain lines show the captain
	var ch0 = load("res://scenes/story/chapter_player.tscn").instantiate()
	ch0.chapter_path = CH0
	ch0.lock_path = true
	ch0.suppress_scene_change = true
	add_child(ch0)
	await get_tree().process_frame
	ch0._load_beat("0.0")
	ch0._line_idx = 0
	ch0._show_line()
	if str(ch0.test_capture.get("portrait_kind", "")) != "narrator_leader" or ch0.get("_portrait").texture == null:
		return "first ch0 frame has no captain: %s" % str(ch0.test_capture.get("portrait_kind"))
	if str(ch0.test_capture.get("portrait_who", "")) != lead.id:
		return "first frame shows %s, not the captain" % ch0.test_capture.get("portrait_who")
	ch0._speaker_portrait("leader")
	if ch0.get("_portrait").texture == null or str(ch0.test_capture.get("portrait_who", "")) != lead.id:
		return "captain line lost the portrait"
	# 3) skip → married to the opposite sex, from a cold start (reputation none)
	GameState.reputation["ashland"] = 0
	ch0._auto_marry()
	if not GameState.flag("married") or lead.spouse_id == "":
		return "auto_marry did nothing: %s" % ch0._hint.text
	var sp: CKCharacter = GameState.characters.get(lead.spouse_id)
	if sp == null or str(sp.gender) != want:
		return "auto_marry spouse gender %s" % (sp.gender if sp else "?")
	ch0.queue_free()
	await get_tree().process_frame
	return ""

func _bank_labels() -> String:
	var keys: Array = []
	var labelled := 0
	var f := 0
	for key in (JSON.parse_string(FileAccess.get_file_as_string(CKPortraitBank.SEX_INDEX)).get("sex", {}) as Dictionary).keys():
		keys.append(key)
		labelled += 1
		if CKPortraitBank.plate_sex(str(key)) == "f":
			f += 1
	if labelled < 100 or f < 5:
		return "bank sex labels thin: %d/%d" % [f, labelled]
	for s in ["m", "f"]:
		for key in CKPortraitBank._same_sex(keys, s):
			if CKPortraitBank.plate_sex(str(key)) != s:
				return "bank filter let %s through for %s" % [key, s]
	return ""
