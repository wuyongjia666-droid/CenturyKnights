extends Node
## NAR-02：选项、条件、旗标、战斗引用，以及章节 schema。

const Schema = preload("res://scripts/narrative/chapter_schema.gd")
const Cond = preload("res://scripts/narrative/story_conditions.gd")
const Catalog = preload("res://scripts/narrative/story_catalog.gd")
const SAMPLE := "res://tests/suites/narrative/fixtures/player_sample.json"
const CH0 := "res://data/story/chapters/ch0.json"
const DENGYING_LINE := "我跟着你不是为了姓。是为了隘口那条路还能走人。不过——姓也重要。没姓的旗，风一吹就散。"

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
	var exit_err := _ch0_exit()
	if exit_err != "":
		return exit_err
	var route_err := await _mainline_routing()
	if route_err != "":
		return route_err
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
		"你是石垒坡的佃户，没有姓，也没有爵位。刚挑完一担石头，肩膀还疼。",
		"你看向北边的隘口。那里冒起一股烟，不是做饭的烟，是出事了。",
		"又在看烟？你说过好几回，想出去闯，挣个自己的姓。我都记着。",
		"你弟弟小粟今天赶着粮车往北走，要过隘口那条窄路。",
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
	return _ch0_novel_arc()

func _ch0_novel_arc() -> String:
	var raw := FileAccess.get_file_as_string(CH0)
	for banned in ["血黏", "掌心的血", "替你去死", "渗着血", "四对二", "血胤混合", "给我们一个姓"]:
		if raw.find(banned) >= 0:
			return "ch0 still has superseded prose %s" % banned
	var data = JSON.parse_string(raw)
	var wantan_at := -1
	var dengying_at := -1
	var idx := 0
	for beat in data.get("beats", []):
		if str(beat.get("id", "")) != "0.0":
			continue
		for line in beat.get("lines", []):
			var speaker := str(line.get("speaker", ""))
			var text := str(line.get("text", ""))
			if speaker == "石垒·晚担" and wantan_at < 0:
				wantan_at = idx
			if speaker == "苇原·灯影" and text == DENGYING_LINE:
				dengying_at = idx
			idx += 1
	if wantan_at < 0 or dengying_at < 0 or wantan_at > dengying_at:
		return "ch0 0.0 wantan %d dengying %d" % [wantan_at, dengying_at]
	print("OK ch0 novel arc")
	return ""

func _conditions() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var names: Array = []
	for c in GameState.roster():
		names.append(str(c.name))
	if names.size() < 3 or str(names[1]) != "石垒·晚担" or str(names[2]) != "苇原·灯影":
		return "roster order %s" % str(names)
	if int(GameState.roster()[1].salary) >= int(GameState.roster()[2].salary):
		return "wantan pay should stay under dengying"
	if GameState.roster()[1].traits.has("heir_mark"):
		return "wantan carries an heir mark"
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

## Audit P1-5: the prologue's departure button opens e1_01, not a dead archive notice.
func _ch0_exit() -> String:
	var data = JSON.parse_string(FileAccess.get_file_as_string(CH0))
	for b in data.get("beats", []):
		for a in b.get("actions", []):
			if str(a.get("id", "")) != "old_volume":
				continue
			for step in a.get("do", []):
				if str(step.get("op", "")) == "archive_notice":
					return "old_volume still shows the archive notice"
				if str(step.get("op", "")) == "open_chapter" and str(step.get("id", "")) == "e1_01":
					print("OK ch0 departs to e1_01")
					return ""
	return "old_volume does not open e1_01"
## Audit P0-1 / P0-2 / P1-6: every volume chapter opens by id, has a way out of its last beat,
## and its beat survives CKStoryState.
func _mainline_routing() -> String:
	var packed: PackedScene = load(Catalog.player_scene())
	var count := 0
	for row in Catalog.mainline_entries():
		var id := str(row.get("id", ""))
		if id == "ch0":
			continue
		count += 1
		var data = JSON.parse_string(FileAccess.get_file_as_string(str(row["path"])))
		var idx := int(data.get("legacy_index", 0))
		if idx <= 0 or idx >= CKStoryState.CHAPTER_COUNT:
			return "%s legacy_index %d outside story_state" % [id, idx]
		GameState.story.set_beat(idx, "probe")
		if GameState.story.beat(idx) != "probe":
			return "%s beat not stored" % id
		GameState.story.set_beat(idx, GameState.story.default_beat(idx))
		var last := ""
		for b in data.get("beats", []):
			if b.get("next") == null or str(b.get("next", "")) == "":
				last = str(b.get("id", ""))
		if last == "":
			return "%s has no last beat" % id
		if Catalog.request_chapter(id) != Catalog.player_scene():
			return "%s scene" % id
		var player = packed.instantiate()
		player.suppress_scene_change = true
		add_child(player)
		await get_tree().process_frame
		var loaded := str(player._chapter.get("id", ""))
		if loaded != id:
			player.queue_free()
			return "requested %s but player opened %s" % [id, loaded]
		player._load_beat(last)
		player._line_idx = 1 << 20
		player._refresh_actions()
		await get_tree().process_frame
		var live := 0
		for c in player._actions.get_children():
			if c is Button and not c.is_queued_for_deletion() and not (c as Button).disabled:
				live += 1
		if live == 0:
			player.queue_free()
			return "%s last beat %s has no exit" % [id, last]
		player.queue_free()
		GameState.story.set_beat(idx, GameState.story.default_beat(idx))
	if count < 40:
		return "only %d volume chapters" % count
	Catalog.request_chapter("e9_99")
	var lost = packed.instantiate()
	lost.suppress_scene_change = true
	add_child(lost)
	await get_tree().process_frame
	var bad := str(lost._chapter.get("id", ""))
	lost.queue_free()
	if bad == "ch0":
		return "unknown id fell back to ch0"
	print("OK mainline routing chapters=", count)
	return ""
