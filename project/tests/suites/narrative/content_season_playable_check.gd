extends Node
## 内容季 #1 可玩章：schema + dialogue lint + chapter_player 走进对白并选择「把无写进谱」。

const Schema = preload("res://scripts/narrative/chapter_schema.gd")
const LintScript = preload("res://scripts/narrative/dialogue_lint.gd")
const CHAPTER := "res://data/story/chapters/cs01_01.json"
const PLAYER := "res://scenes/story/chapter_player.tscn"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_playable: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON PLAYABLE PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _validate_chapter()
	if err != "":
		return err
	var data = JSON.parse_string(FileAccess.get_file_as_string(CHAPTER))
	var line_count := _count_lines(data)
	err = _assert_catalog_and_counts(data, line_count)
	if err != "":
		return err
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var packed: PackedScene = load(PLAYER)
	if packed == null:
		return "player scene missing"
	var player = packed.instantiate()
	player.chapter_path = CHAPTER
	player.lock_path = true
	player.suppress_scene_change = true
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	err = await _walk_to_choice(player, 220)
	if err != "":
		return err
	err = await _choose_and_assert(player)
	if err != "":
		return err
	print("OK cs01_01 lines=%d beat=ledger flag=cs01_wrote_wu ledger+yeartrace" % line_count)
	return ""


func _validate_chapter() -> String:
	if not FileAccess.file_exists(CHAPTER):
		return "missing " + CHAPTER
	var schema := Schema.validate_file(CHAPTER)
	if not schema.is_empty():
		return str(schema[0])
	var lint := LintScript.new()
	var loaded := lint.load_rules()
	if loaded != "":
		return loaded
	var report: Dictionary = lint.scan_file(CHAPTER)
	var violations: Array = report.get("violations", [])
	if not violations.is_empty():
		return "lint %s" % str(violations[0])
	return ""


func _count_lines(data) -> int:
	var line_count := 0
	if typeof(data) != TYPE_DICTIONARY:
		return 0
	for beat in data.get("beats", []):
		line_count += (beat.get("lines", []) as Array).size()
	return line_count


func _assert_catalog_and_counts(data, line_count: int) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "chapter not dict"
	if str(data.get("id", "")) != "cs01_01":
		return "id"
	if line_count < 70:
		return "too few lines %d" % line_count
	for row in StoryCatalog.mainline_entries():
		if str(row.get("id", "")) == "cs01_01":
			return ""
	return "StoryCatalog missing cs01_01"


func _choose_and_assert(player) -> String:
	if not player.simulate_press_action_containing("把无写进谱"):
		return "could not press write_wu labels=%s" % str(player.action_labels())
	await get_tree().process_frame
	await get_tree().process_frame
	if not GameState.flag("cs01_wrote_wu"):
		return "flag cs01_wrote_wu not set"
	if player.current_beat_id() != "ledger":
		return "expected ledger beat, at %s" % player.current_beat_id()
	var led: Dictionary = CKSuiKe.season_ledger_find("cs01_01", "write_wu")
	if led.is_empty():
		return "content_season_ledger missing cs01_01/write_wu"
	if str(led.get("outcome", "")).find("无") < 0:
		return "ledger outcome missing 无: %s" % str(led.get("outcome", ""))
	var yt_hit := false
	for row in CKSuiKe.yeartrace():
		if str(row.get("id", "")) == "cs01_01:write_wu" and str(row.get("outcome", "")).find("无") >= 0:
			yt_hit = true
			break
	if not yt_hit:
		return "yeartrace missing cs01_01:write_wu 无 pen"
	player.simulate_finish_dialogue()
	await get_tree().process_frame
	return ""


func _walk_to_choice(player, max_steps: int) -> String:
	var steps := 0
	while steps < max_steps:
		player.simulate_finish_dialogue()
		await get_tree().process_frame
		await get_tree().process_frame
		var labels: Array = player.action_labels()
		if labels.find("把无写进谱") >= 0 and labels.find("先压下不挂谱") >= 0:
			return ""
		var advanced := false
		for needle in ["继续", "继续 ▶"]:
			if player.simulate_press_action_containing(needle):
				advanced = true
				break
		if not advanced:
			return "stuck at beat=%s labels=%s" % [player.current_beat_id(), str(labels)]
		steps += 1
		await get_tree().process_frame
	return "choice not reached after %d steps beat=%s" % [max_steps, player.current_beat_id()]
