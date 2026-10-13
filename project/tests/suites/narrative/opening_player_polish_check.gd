extends Node
## Track A polish: C-01/02/03/08/10 + G-05/G-06 against the live chapter player.

const CH0 := "res://data/story/chapters/ch0.json"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL opening player polish: ", err)
		get_tree().quit(1)
	else:
		print("OPENING PLAYER POLISH PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var packed: PackedScene = load("res://scenes/story/chapter_player.tscn")
	if packed == null:
		return "player scene missing"
	var ch0 = packed.instantiate()
	ch0.chapter_path = CH0
	ch0.lock_path = true
	ch0.suppress_scene_change = true
	add_child(ch0)
	await get_tree().process_frame
	await get_tree().process_frame
	var err := _check_chrome(ch0)
	if err != "":
		return err
	err = await _check_choices(ch0)
	if err != "":
		return err
	err = _check_narrator(ch0)
	if err != "":
		return err
	err = _check_recruit(ch0)
	if err != "":
		return err
	err = _check_journal()
	if err != "":
		return err
	return ""

func _check_chrome(ch0) -> String:
	var meta: Label = ch0.get("_beat_meta")
	if meta == null:
		return "beat_meta missing"
	if str(meta.text).find("节拍") >= 0:
		return "C-01 beat debug still shown: %s" % meta.text
	if str(meta.text).find("/") < 0:
		return "C-01 progress caption missing: %s" % meta.text
	if ch0.find_child("SpeakerActiveTag", true, false) != null:
		return "C-02 SPEAKER ACTIVE tag still present"
	var footer = ch0.find_child("StitchFooter", true, false)
	if footer != null:
		for c in footer.get_children():
			if c is Label and str(c.text).find("v8.") >= 0:
				return "C-08 versioned footer: %s" % c.text
	return ""

func _check_choices(ch0) -> String:
	ch0.simulate_goto_beat("0.17")
	ch0.simulate_finish_dialogue()
	await get_tree().process_frame
	var labels: Array = ch0.action_labels()
	if labels.find("收下地契和饷银，让这一仗记在槐里家") < 0:
		return "C-10 0.17 choice missing %s" % str(labels)
	for c in ch0.get("_actions").get_children():
		if c is BaseButton and str(c.text).find("+80") >= 0:
			return ""
	return "C-10 cost hint missing on 0.17 accept"

func _check_narrator(ch0) -> String:
	ch0._speaker_portrait("旁白")
	if not bool(ch0.test_capture.get("portrait_narrator", false)):
		return "C-03 narrator meta not set"
	# P0: second-person narration keeps the captain on stage (no empty first frame).
	if str(ch0.test_capture.get("portrait_kind", "")) != "narrator_leader":
		return "P0 narrator should show captain, got %s" % str(ch0.test_capture)
	if ch0.get("_portrait").texture == null:
		return "P0 narrator captain plate empty"
	return ""

func _check_recruit(ch0) -> String:
	GameState.silver = maxi(GameState.silver, 999)
	if GameState.tavern_candidates.is_empty():
		GameState.refresh_tavern()
	if GameState.tavern_candidates.is_empty():
		return "G-05 tavern empty"
	var hire = GameState.tavern_candidates[0]
	hire.name = "测·募兵"
	var hired: Dictionary = GameState.recruit(hire, 0)
	if not bool(hired.get("ok", false)):
		return "G-05 could not recruit test hire: %s" % str(hired)
	if ch0._speaker_label("新来的人") != "测·募兵":
		return "G-05 recruit label %s" % ch0._speaker_label("新来的人")
	return ""

func _check_journal() -> String:
	GameState.set_flag("pro_merit_own")
	GameState.set_flag("pro_lease_kept")
	GameState.set_flag("pro_roster_wantan")
	var journal := str(GameState.build_dynasty_journal())
	if journal.find("隘口那一仗，我没让") < 0:
		return "G-06 journal missing merit_own arc"
	if journal.find("娘的地还在") < 0:
		return "G-06 journal missing lease_kept arc"
	if journal.find("名册第一行是石垒·晚担") < 0:
		return "G-06 journal missing roster arc"
	return ""
