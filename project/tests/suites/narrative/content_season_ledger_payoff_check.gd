extends Node
## 内容季选择账本：二十章 JSON 均含 season_ledger；_01/_02 抽样走进选择后断言 ledger+yeartrace。

const Schema = preload("res://scripts/narrative/chapter_schema.gd")
const LintScript = preload("res://scripts/narrative/dialogue_lint.gd")
const PLAYER := "res://scenes/story/chapter_player.tscn"

## chapter_path, press_label, chapter_id, choice_id, outcome_needle
const WALKS := [
	["res://data/story/chapters/cs01_01.json", "把无写进谱", "cs01_01", "write_wu", "无"],
	["res://data/story/chapters/cs02_01.json", "两行并排留", "cs02_01", "keep_parallel", "并排"],
	["res://data/story/chapters/cs05_01.json", "空椅并排链", "cs05_01", "keep_chain", "空椅"],
	["res://data/story/chapters/cs08_01.json", "祖祠并排记", "cs08_01", "keep_stele", "祖祠"],
	["res://data/story/chapters/cs10_01.json", "城印并排记", "cs10_01", "keep_seal", "城印"],
	["res://data/story/chapters/cs01_02.json", "空格并排留", "cs01_02", "keep_slip", "空格"],
	["res://data/story/chapters/cs05_02.json", "链仍并排", "cs05_02", "keep_reread", "链"],
	["res://data/story/chapters/cs10_02.json", "印底并排留", "cs10_02", "keep_base", "印底"],
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_ledger_payoff: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON LEDGER PAYOFF PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _assert_all_ten_json()
	if err != "":
		return err
	err = _assert_append_api()
	if err != "":
		return err
	for row in WALKS:
		err = await _walk_one(row)
		if err != "":
			return err
	print("OK ledger seasons=20 walks=%d" % WALKS.size())
	return ""


func _assert_all_ten_json() -> String:
	for i in range(1, 11):
		for suffix in ["_01", "_02"]:
			var cid := "cs%02d%s" % [i, suffix]
			var path := "res://data/story/chapters/%s.json" % cid
			if not FileAccess.file_exists(path):
				return "missing " + path
			var schema := Schema.validate_file(path)
			if not schema.is_empty():
				return str(schema[0])
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(data) != TYPE_DICTIONARY:
				return cid + " not dict"
			var ledger_ops := 0
			for beat in data.get("beats", []):
				for action in beat.get("actions", []):
					for step in action.get("do", []):
						if typeof(step) == TYPE_DICTIONARY and str(step.get("op", "")) == "season_ledger":
							ledger_ops += 1
							if str(step.get("choice", "")) == "":
								return cid + " season_ledger missing choice"
							if str(step.get("outcome", "")) == "":
								return cid + " season_ledger missing outcome"
			if ledger_ops < 2:
				return cid + " expected ≥2 season_ledger ops, got %d" % ledger_ops
	return ""


func _assert_append_api() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var a: Dictionary = CKSuiKe.season_ledger_append("cs99_test", "pick_a", "试笔", "试写一笔", "", true)
	if a.is_empty():
		return "append returned empty"
	var b: Dictionary = CKSuiKe.season_ledger_append("cs99_test", "pick_a", "试笔", "试写一笔·改", "", true)
	if CKSuiKe.season_ledger_count() < 1:
		return "ledger empty after append"
	var found: Dictionary = CKSuiKe.season_ledger_find("cs99_test", "pick_a")
	if str(found.get("outcome", "")) != "试写一笔·改":
		return "idempotent replace failed: %s" % str(found)
	var yt := false
	for row in CKSuiKe.yeartrace():
		if str(row.get("id", "")) == "cs99_test:pick_a":
			yt = true
			break
	if not yt:
		return "yeartrace mirror missing"
	return ""


func _walk_one(spec: Array) -> String:
	var chapter_path := str(spec[0])
	var label := str(spec[1])
	var chapter_id := str(spec[2])
	var choice_id := str(spec[3])
	var needle := str(spec[4])
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var packed: PackedScene = load(PLAYER)
	if packed == null:
		return "player scene missing"
	var player = packed.instantiate()
	player.chapter_path = chapter_path
	player.lock_path = true
	player.suppress_scene_change = true
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	var err := await _walk_to_choice(player, label, 120)
	if err != "":
		player.queue_free()
		return "%s: %s" % [chapter_id, err]
	if not player.simulate_press_action_containing(label):
		var labels: Array = player.action_labels()
		player.queue_free()
		return "%s: could not press %s labels=%s" % [chapter_id, label, str(labels)]
	await get_tree().process_frame
	await get_tree().process_frame
	var led: Dictionary = CKSuiKe.season_ledger_find(chapter_id, choice_id)
	if led.is_empty():
		player.queue_free()
		return "%s: ledger missing %s/%s" % [chapter_id, chapter_id, choice_id]
	if str(led.get("outcome", "")).find(needle) < 0:
		player.queue_free()
		return "%s: outcome missing %s in %s" % [chapter_id, needle, str(led.get("outcome", ""))]
	var yt_id := "%s:%s" % [chapter_id, choice_id]
	var yt_hit := false
	for row in CKSuiKe.yeartrace():
		if str(row.get("id", "")) == yt_id:
			yt_hit = true
			break
	if not yt_hit:
		player.queue_free()
		return "%s: yeartrace missing %s" % [chapter_id, yt_id]
	print("OK walk %s choice=%s outcome=%s" % [chapter_id, choice_id, str(led.get("outcome", ""))])
	player.queue_free()
	await get_tree().process_frame
	return ""


func _walk_to_choice(player, want_label: String, max_steps: int) -> String:
	var steps := 0
	while steps < max_steps:
		player.simulate_finish_dialogue()
		await get_tree().process_frame
		await get_tree().process_frame
		var labels: Array = player.action_labels()
		if labels.find(want_label) >= 0:
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
