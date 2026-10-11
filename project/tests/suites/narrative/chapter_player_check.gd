extends Node
## NAR-02：选项、条件、旗标、战斗引用，以及章节 schema。

const Schema = preload("res://scripts/narrative/chapter_schema.gd")
const Cond = preload("res://scripts/narrative/story_conditions.gd")
const Catalog = preload("res://scripts/narrative/story_catalog.gd")
const SAMPLE := "res://tests/suites/narrative/fixtures/player_sample.json"
const CH0 := "res://data/story/chapters/ch0.json"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL chapter player: ", err)
		get_tree().quit(1)
	else:
		print("CHAPTER PLAYER PASS")
		get_tree().quit(0)

func _run() -> String:
	var story_scripts := 0
	var dir := DirAccess.open("res://scripts/story")
	if dir == null:
		return "scripts/story missing"
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".gd"):
			story_scripts += 1
		name = dir.get_next()
	dir.list_dir_end()
	if story_scripts > 6:
		return "scripts/story gd count %d" % story_scripts
	print("OK story scripts=", story_scripts)
	if ResourceLoader.exists("res://scenes/story/chapter1.tscn"):
		return "chapter1.tscn still on the mainline"
	var schema_err := _schemas()
	if schema_err != "":
		return schema_err
	var ch0_err := _ch0_covers_four()
	if ch0_err != "":
		return ch0_err
	var cond_err := _conditions()
	if cond_err != "":
		return cond_err
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var packed: PackedScene = load("res://scenes/story/chapter_player.tscn")
	if packed == null:
		return "player scene missing"
	var player = packed.instantiate()
	player.chapter_path = SAMPLE
	player.lock_path = true
	player.suppress_scene_change = true
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	var opened := await _advance_lines(player, ["灯还在桌上。", "选一条。"])
	if opened != "":
		return opened
	player.simulate_finish_dialogue()
	await get_tree().process_frame
	var labels: Array = player.action_labels()
	if labels.find("把灯留下") < 0 or labels.find("把灯吹灭") < 0:
		return "choices missing %s" % str(labels)
	if labels.find("只有同伴在场") < 0:
		return "companion condition hidden while dengying is rostered"
	if labels.find("血里有灰") < 0:
		return "bloodline condition hidden"
	if labels.find("出去打仗") < 0:
		return "battle action missing"
	if not player.simulate_press_action_containing("把灯留下"):
		return "could not press keep"
	await get_tree().process_frame
	if not GameState.flag("sample_kept"):
		return "flag sample_kept not written"
	if player.current_beat_id() != "s1":
		return "choice did not goto s1, at %s" % player.current_beat_id()
	print("OK choice + flag + goto")
	player.simulate_goto_beat("s0")
	player.simulate_finish_dialogue()
	await get_tree().process_frame
	labels = player.action_labels()
	if labels.find("把灯吹灭") >= 0:
		return "not_flag failed to hide blow after sample_kept"
	print("OK condition hides choice")
	GameState.set_flag("sample_kept", false)
	player.simulate_goto_beat("s0")
	player.simulate_finish_dialogue()
	if not player.simulate_press_action_containing("出去打仗"):
		return "could not press battle"
	if str(player.test_capture.get("battle_map", "")) != "sample_map":
		return "battle map %s" % str(player.test_capture)
	if str(player.test_capture.get("battle_objective", "")) != "seize":
		return "battle objective %s" % str(player.test_capture)
	if str(player.test_capture.get("scene", "")) != "res://scenes/battle/battle.tscn":
		return "battle scene %s" % str(player.test_capture)
	if str(GameState.get_meta("battle_map", "")) != "sample_map":
		return "battle meta missing"
	print("OK battle ref")
	var entries: Array = Catalog.mainline_entries()
	var saw_ch0 := false
	var saw_lint := false
	for row in entries:
		if str(row.get("id", "")) == "ch0":
			saw_ch0 = true
		if str(row.get("id", "")).begins_with("lint_"):
			saw_lint = true
	if not saw_ch0 or saw_lint:
		return "catalog %s" % str(entries)
	if Catalog.archive_replay_enabled():
		return "archive replay should stay closed"
	print("OK catalog")
	var ch0 = packed.instantiate()
	ch0.chapter_path = CH0
	ch0.lock_path = true
	ch0.suppress_scene_change = true
	add_child(ch0)
	await get_tree().process_frame
	var ch0_lines := [
		"朔澜陆桥的边境，风比刀硬。一面撕破的灰旗仍钉在折断的旗杆上，布边被烟熏成近黑——像有人用尽最后一口气，也要把「还在」两个字留在天际。",
		"你把它拾起。不是为了王庭的册封，不是为了哪一座城门的钥匙。只是因为旗下还有人：伤的、饿的、不肯散的。",
		"团长……不，你还没被叫过团长。可今夜之后，总得有人扛这名字。给我们一个姓，一种颜色。灰烬旗从今夜起算第一夜。",
		"我跟着你不是为了姓。是为了隘口那条路还能走人。不过——姓也重要。没姓的旗，风一吹就散。",
	]
	var ch0_open := await _advance_lines(ch0, ch0_lines)
	if ch0_open != "":
		return ch0_open
	ch0.simulate_goto_beat("0.4")
	ch0.simulate_finish_dialogue()
	await get_tree().process_frame
	if ch0.action_labels().find("前往联姻廷") < 0:
		return "ch0 marriage gate %s" % str(ch0.action_labels())
	if int(GameState.reputation.get("ashland", 0)) < 30:
		return "spring reputation was not prepared"
	print("OK ch0 marriage gate")
	return ""

func _continue_clears_text(player) -> String:
	player.size = Vector2(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var actions := player.get("_actions") as Control
	var body := player.get("_body") as Control
	var btn := player.find_child("AdvanceLine", true, false) as Control
	if actions == null or body == null or btn == null:
		return "continue control missing"
	if actions.get_parent() == player:
		return "continue still floats over the page"
	if btn.size.x > 200.0:
		return "continue too wide %s" % btn.size
	var br := body.get_global_rect()
	var ar := btn.get_global_rect()
	if br.size.x > 8.0 and br.size.y > 8.0 and ar.size.x > 8.0 and ar.size.y > 8.0 and br.intersects(ar):
		var hit := br.intersection(ar)
		if hit.size.x > 2.0 and hit.size.y > 2.0:
			return "continue covers dialogue %s" % hit
	return ""

func _advance_lines(player, expected: Array) -> String:
	if player.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		return "chapter player still auto-translates"
	var body := player.get("_body") as RichTextLabel
	if body == null:
		return "dialogue body missing"
	if body.fit_content:
		return "dialogue body fit_content can collapse the page"
	if body.bbcode_enabled:
		return "dialogue body still parses bbcode"
	for i in expected.size():
		var shown := str(body.text)
		if shown == "" or shown == "...":
			return "blank dialogue page %d" % i
		if shown != str(expected[i]):
			return "line %d got %s" % [i, shown]
		if i == 0 and i + 1 < expected.size():
			var cover := await _continue_clears_text(player)
			if cover != "":
				return cover
		if i + 1 < expected.size():
			if not player.simulate_press_action_containing("继续"):
				return "could not advance line %d" % i
			await get_tree().process_frame
	return ""

func _schemas() -> String:
	for path in [CH0, SAMPLE]:
		var errors: Array = Schema.validate_file(path)
		if not errors.is_empty():
			return str(errors[0])
	var lint_errors: Array = Schema.validate_file("res://data/story/chapters/lint_clean.json")
	if lint_errors.is_empty():
		return "lint fixture was treated as a chapter"
	print("OK schema")
	return ""

func _ch0_covers_four() -> String:
	var data = JSON.parse_string(FileAccess.get_file_as_string(CH0))
	var saw_choice := false
	var saw_when := false
	var saw_flag := false
	var saw_battle := false
	for beat in data.get("beats", []):
		var actions: Array = beat.get("actions", [])
		if actions.size() >= 2:
			saw_choice = true
		for action in actions:
			if typeof(action) == TYPE_DICTIONARY and action.has("when"):
				saw_when = true
			for step in action.get("do", []):
				if str(step.get("op", "")) == "set_flag":
					saw_flag = true
				if str(step.get("op", "")) == "battle" and str(step.get("map", "")) != "":
					saw_battle = true
	if not saw_choice or not saw_when or not saw_flag or not saw_battle:
		return "ch0 missing choice=%s when=%s flag=%s battle=%s" % [saw_choice, saw_when, saw_flag, saw_battle]
	return ""

func _conditions() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	if not Cond.met({"companion": "dengying"}):
		return "dengying should be present"
	if not Cond.met({"companion": "weiyuan_dengying"}):
		return "companion id should resolve to cast_key"
	if Cond.met({"companion": "nobody_cast"}):
		return "unknown companion matched"
	if not Cond.met({"bloodline": "common_ash", "who": "leader"}):
		return "leader ash missing"
	if Cond.met({"bloodline": "no_such_line"}):
		return "missing bloodline matched"
	if not Cond.met({"not": {"flag": "sample_kept"}}):
		return "not-flag"
	GameState.set_flag("sample_kept", true)
	if Cond.met({"not_flag": "sample_kept"}):
		return "not_flag stayed true"
	var stranger = CKCharacter.new()
	stranger.cast_key = "stranger"
	if Cond.met({"companion": "dengying"}, [stranger]):
		return "roster override still saw dengying"
	print("OK conditions")
	return ""
