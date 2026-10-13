extends Node
## P0 playtest: ch0 opens on 20 second-person narrator lines; the captain must be on stage
## from the first frame (not an empty plate), and stay on the captain's own lines.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL ch0 first frame: ", err)
		get_tree().quit(1)
	else:
		print("CH0 FIRST FRAME PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var lead: CKCharacter = GameState.get_leader()
	var ch0 = load("res://scenes/story/chapter_player.tscn").instantiate()
	ch0.chapter_path = "res://data/story/chapters/ch0.json"
	ch0.lock_path = true
	ch0.suppress_scene_change = true
	add_child(ch0)
	await get_tree().process_frame
	ch0._load_beat("0.0")
	ch0._line_idx = 0
	ch0._show_line()
	if str(ch0.test_capture.get("portrait_kind", "")) != "narrator_leader" or ch0.get("_portrait").texture == null:
		return "first frame has no captain (%s)" % str(ch0.test_capture.get("portrait_kind"))
	if str(ch0.test_capture.get("portrait_who", "")) != lead.id:
		return "first frame shows %s" % ch0.test_capture.get("portrait_who")
	ch0._speaker_portrait("leader")
	if ch0.get("_portrait").texture == null or str(ch0.test_capture.get("portrait_who", "")) != lead.id:
		return "captain line lost the portrait"
	return ""
