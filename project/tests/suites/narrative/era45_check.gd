extends Node
## NAR-07：第四、五纪元十六章可走通，对白守则为零，选择旗标被后续条件读到，
## 十六场战斗至少五种目标，同伴不在名册时走替代台词。

const Schema = preload("res://scripts/narrative/chapter_schema.gd")
const LintScript = preload("res://scripts/narrative/dialogue_lint.gd")
const PLAYER := "res://scenes/story/chapter_player.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const CHAPTER_DIR := "res://data/story/chapters"
const MAPS := ["res://data/maps/story_era4.json", "res://data/maps/story_era5.json"]
const CAST := "res://data/cast/companions_v92.json"
const SEEDS := [11, 22, 33]

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL era45: ", err)
		get_tree().quit(1)
	else:
		print("ERA45 PASS")
		get_tree().quit(0)

func _run() -> String:
	var files := _chapter_files()
	if files.size() != 16:
		return "era45 chapter count %d" % files.size()
	var lint := LintScript.new()
	var lint_err := lint.load_rules()
	if lint_err != "":
		return lint_err
	var speakers := {}
	var set_at := {}
	var read_at := {}
	var battles := {}
	var order := 0
	for path in files:
		var schema := Schema.validate_file(path)
		if not schema.is_empty():
			return str(schema[0])
		var report: Dictionary = lint.scan_file(path)
		var violations: Array = report.get("violations", [])
		if not violations.is_empty():
			return "lint %s" % str(violations[0])
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		var lines := 0
		for beat in data.get("beats", []):
			order += 1
			for line in beat.get("lines", []):
				lines += 1
				speakers[str(line.get("speaker", ""))] = true
				_note_when(line.get("when", {}), order, read_at)
			_note_when(beat.get("when", {}), order, read_at)
			for action in beat.get("actions", []):
				_note_when(action.get("when", {}), order, read_at)
				for step in action.get("do", []):
					if str(step.get("op", "")) == "set_flag":
						var flag := str(step.get("flag", ""))
						if (flag.begins_with("e4_") or flag.begins_with("e5_")) and not flag.ends_with("_fought"):
							set_at[flag] = order
					if str(step.get("op", "")) == "battle":
						battles[str(step.get("map", ""))] = str(step.get("objective", ""))
		if lines < 80 or lines > 150:
			return "%s lines %d" % [path, lines]
	var named := 0
	var cast = JSON.parse_string(FileAccess.get_file_as_string(CAST))
	for row in cast.get("companions", []):
		if speakers.has(str(row.get("name", ""))):
			named += 1
	if named < 6:
		return "named speakers %d" % named
	for flag in set_at.keys():
		if int(read_at.get(flag, -1)) <= int(set_at[flag]):
			return "flag not read later: %s" % flag
	var map_err := _maps(battles)
	if map_err != "":
		return map_err
	for seed_n in SEEDS:
		for path in files:
			var walk_err := await _walk(path, int(seed_n))
			if walk_err != "":
				return "seed %d %s %s" % [seed_n, path, walk_err]
	var death_err := await _deaths()
	if death_err != "":
		return death_err
	print("OK era45 chapters=16 speakers=%d seeds=%s" % [named, str(SEEDS)])
	return ""

func _chapter_files() -> Array:
	var dir := DirAccess.open(CHAPTER_DIR)
	var names: Array = []
	if dir == null:
		return names
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if (file_name.begins_with("era4_") or file_name.begins_with("era5_")) and file_name.ends_with(".json"):
			names.append(CHAPTER_DIR + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	return names

func _note_when(when, order: int, read_at: Dictionary) -> void:
	if typeof(when) != TYPE_DICTIONARY:
		return
	var row: Dictionary = when
	for key in ["flag", "not_flag"]:
		var flag := str(row.get(key, ""))
		if flag != "":
			read_at[flag] = order
	for key in ["any_flag", "not_any_flag"]:
		var listed = row.get(key, [])
		if typeof(listed) == TYPE_ARRAY:
			for flag in listed:
				read_at[str(flag)] = order
	for key in ["all", "any"]:
		var kids = row.get(key, [])
		if typeof(kids) == TYPE_ARRAY:
			for kid in kids:
				_note_when(kid, order, read_at)
	if row.has("not"):
		_note_when(row.get("not"), order, read_at)

func _maps(battles: Dictionary) -> String:
	var kinds := {}
	var seen := {}
	for path in MAPS:
		if not FileAccess.file_exists(path):
			return "missing " + path
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		var batch: Dictionary = data.get("maps", {})
		if batch.size() != 8:
			return "%s map count %d" % [path, batch.size()]
		for id in batch.keys():
			var row: Dictionary = batch[id]
			var w := int(row.get("w", 0))
			var h := int(row.get("h", 0))
			if w < 10 or w > 14 or h < 8 or h > 10:
				return "%s size %dx%d" % [id, w, h]
			var terrain: Array = row.get("terrain", [])
			if terrain.size() != h:
				return "%s terrain rows" % id
			for line in terrain:
				if typeof(line) != TYPE_ARRAY or (line as Array).size() != w:
					return "%s terrain width" % id
			var kind := str(row.get("objective", {}).get("type", ""))
			if kind == "":
				return "%s missing objective" % id
			kinds[kind] = true
			seen[str(id)] = kind
	if kinds.size() < 5:
		return "objective kinds %d" % kinds.size()
	if battles.size() != 16:
		return "battle refs %d" % battles.size()
	for map_id in battles.keys():
		if not seen.has(map_id):
			return "battle map missing " + str(map_id)
		if str(seen[map_id]) != str(battles[map_id]):
			return "objective mismatch %s" % str(map_id)
	print("OK maps=%d objectives=%s" % [seen.size(), str(kinds.keys())])
	return ""

func _walk(path: String, seed_n: int) -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var packed: PackedScene = load(PLAYER)
	var player = packed.instantiate()
	player.chapter_path = path
	player.lock_path = true
	player.suppress_scene_change = true
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var guard := 0
	var stuck := 0
	while guard < 80:
		guard += 1
		player.simulate_finish_dialogue()
		var enabled: Array = []
		for child in player._actions.get_children():
			if child is BaseButton and is_instance_valid(child) and not child.is_queued_for_deletion() and not child.disabled:
				enabled.append(child)
		if enabled.is_empty():
			var stopped := str(player.current_beat_id())
			player.queue_free()
			await get_tree().process_frame
			if stopped != "end":
				return "stopped at %s before end" % stopped
			return ""
		var before := str(player.current_beat_id())
		var btn: BaseButton = enabled[rng.randi() % enabled.size()]
		btn.pressed.emit()
		if str(player.test_capture.get("scene", "")) == BATTLE:
			player.test_capture.clear()
			var nxt := str(player._beat.get("next", ""))
			if nxt == "":
				return "battle without next at " + before
			player.simulate_goto_beat(nxt)
		var after := str(player.current_beat_id())
		if after == before:
			stuck += 1
			if stuck > 4:
				return "stuck at " + before
		else:
			stuck = 0
	return "guard"

func _deaths() -> String:
	var kiln := await _branch(
		"res://data/story/chapters/era5_03.json",
		"zhensheng",
		"裂谷·砧声",
		true,
		"我还在这扇门口",
		"门口没有砧声"
	)
	if kiln != "":
		return kiln
	var page := await _branch(
		"res://data/story/chapters/era5_04.json",
		"dengying",
		"苇原·灯影",
		false,
		"我的页还在我手里",
		"灯影已经不在这间屋子"
	)
	if page != "":
		return page
	print("OK dead companion branches")
	return ""

func _branch(path: String, cast_key: String, display_name: String, create: bool, alive_sub: String, dead_sub: String) -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var person: CKCharacter = null
	if create:
		person = CKCharacter.new()
		person.id = "era45_" + cast_key
		person.cast_key = cast_key
		person.name = display_name
		person.alive = true
		person.in_roster = true
		GameState.characters[person.id] = person
	else:
		for c in GameState.characters.values():
			if c != null and str(c.cast_key) == cast_key:
				person = c
				break
	if person == null:
		return "missing " + cast_key
	person.alive = true
	var shown := await _body_at(path, "after")
	if shown.find(alive_sub) < 0 or shown.find(dead_sub) >= 0:
		return "alive %s got %s" % [cast_key, shown]
	person.alive = false
	shown = await _body_at(path, "after")
	if shown.find(dead_sub) < 0 or shown.find(alive_sub) >= 0:
		return "dead %s got %s" % [cast_key, shown]
	return ""

func _body_at(path: String, beat_id: String) -> String:
	var packed: PackedScene = load(PLAYER)
	var player = packed.instantiate()
	player.chapter_path = path
	player.lock_path = true
	player.suppress_scene_change = true
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	player.simulate_goto_beat(beat_id)
	var body := str(player._body.text)
	player.queue_free()
	await get_tree().process_frame
	return body
