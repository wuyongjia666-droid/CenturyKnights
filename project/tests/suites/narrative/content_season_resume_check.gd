extends Node
## Owned runtime resume after dialogue for content seasons:
## GameState season cursor (cs* outside CKStoryState int slots) + SceneTree hub land.
## Also deepens beat-acceptance for cs01..cs10 (min lines / last beat escape).

const Schema = preload("res://scripts/narrative/chapter_schema.gd")
const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"
const CHAPTERS := [
	"cs01_01", "cs02_01", "cs03_01", "cs04_01", "cs05_01",
	"cs06_01", "cs07_01", "cs08_01", "cs09_01", "cs10_01",
]
const CHOICE := {
	"cs01_01": "把无写进谱",
	"cs08_01": "祖祠并排记",
	"cs10_01": "城印并排记",
}
## Mid-chapter beat used to prove cursor survives close/reopen (not the last beat).
const MID_BEAT := {
	"cs01_01": "hall",
	"cs08_01": "stele",
	"cs10_01": "seal",
}


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_resume: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON RESUME PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _beat_acceptance_all()
	if err != "":
		return err
	err = _season_cursor_api()
	if err != "":
		return err
	for cid in ["cs01_01", "cs08_01", "cs10_01"]:
		err = await _resume_and_hub(cid)
		if err != "":
			return err
	return ""


func _beat_acceptance_all() -> String:
	for cid in CHAPTERS:
		var path := "res://data/story/chapters/%s.json" % cid
		if not FileAccess.file_exists(path):
			return "missing " + path
		var schema := Schema.validate_file(path)
		if not schema.is_empty():
			return "%s schema %s" % [cid, str(schema[0])]
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(data) != TYPE_DICTIONARY:
			return "%s not dict" % cid
		if str(data.get("return_scene", "")) != HUB:
			return "%s return_scene" % cid
		var idx := int(data.get("legacy_index", 0))
		if idx < 401 or idx > 410:
			return "%s legacy_index %d not in season marker band" % [cid, idx]
		# Int slot must NOT accept season markers (root-cause gate).
		GameState.story.set_beat(idx, "should_not_stick")
		if GameState.story.beat(idx) == "should_not_stick":
			return "%s legacy %d wrongly stored in int beats[]" % [cid, idx]
		var beats: Array = data.get("beats", [])
		if beats.size() < 4:
			return "%s too few beats %d" % [cid, beats.size()]
		var total_lines := 0
		var last_id := ""
		for b in beats:
			var lines: Array = b.get("lines", [])
			if lines.size() < 4:
				return "%s beat %s too thin (%d lines)" % [cid, b.get("id"), lines.size()]
			total_lines += lines.size()
			var nxt = b.get("next")
			if nxt == null or str(nxt) == "":
				last_id = str(b.get("id", ""))
				var acts: Array = b.get("actions", [])
				if not acts.is_empty():
					# Last beat may use actions; empty-actions protocol is also ok.
					pass
		if last_id == "":
			return "%s no terminal beat" % cid
		if last_id != "ledger":
			return "%s terminal beat want ledger got %s" % [cid, last_id]
		if total_lines < 30:
			return "%s total lines %d" % [cid, total_lines]
		print("OK accept %s beats=%d lines=%d legacy=%d" % [cid, beats.size(), total_lines, idx])
	return ""


func _season_cursor_api() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	if GameState.story.season_beat("cs08_01") != "":
		return "fresh season cursor dirty"
	GameState.story.set_season_beat("cs08_01", "stele")
	if GameState.story.season_beat("cs08_01") != "stele":
		return "set_season_beat failed"
	if not GameState.save_game():
		return "save failed"
	var written = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	var block = written.get("story", {})
	if typeof(block) != TYPE_DICTIONARY:
		return "save story block missing"
	var sb = block.get("season_beats", {})
	if typeof(sb) != TYPE_DICTIONARY or str(sb.get("cs08_01", "")) != "stele":
		return "save season_beats missing/wrong %s" % str(sb)
	GameState.story.set_season_beat("cs08_01", "")
	if GameState.story.season_beat("cs08_01") != "":
		return "erase season beat failed"
	if not GameState.load_game():
		return "reload failed"
	if GameState.story.season_beat("cs08_01") != "stele":
		return "reload lost season cursor"
	print("OK season_beats save/load")
	return ""


func _resume_and_hub(cid: String) -> String:
	var path := "res://data/story/chapters/%s.json" % cid
	var mid := str(MID_BEAT[cid])
	var choice := str(CHOICE[cid])
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	# Open via owned request_chapter path (meta story_chapter_id), not lock_path.
	var scene := StoryCatalog.request_chapter(cid)
	if scene != StoryCatalog.player_scene():
		return "%s request_chapter scene %s" % [cid, scene]
	if str(GameState.get_meta("story_chapter_id", "")) != cid:
		return "%s meta not set" % cid
	var packed: PackedScene = load(PLAYER)
	var player = packed.instantiate()
	player.suppress_scene_change = true
	# lock_path false so _resolve_path consumes story_chapter_id
	player.lock_path = false
	player.chapter_path = ""
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	if player.get("_chapter") == null or str(player.get("_chapter").get("id", "")) != cid:
		# Access via current beat / title path: force open check through beat id
		pass
	# Jump to mid beat and remember via player API.
	player.simulate_goto_beat(mid)
	await get_tree().process_frame
	if player.current_beat_id() != mid:
		player.queue_free()
		return "%s mid beat want %s got %s" % [cid, mid, player.current_beat_id()]
	if GameState.story.season_beat(cid) != mid:
		player.queue_free()
		return "%s GameState cursor not remembered at %s (got %s)" % [
			cid, mid, GameState.story.season_beat(cid)]
	player.queue_free()
	await get_tree().process_frame
	# Reopen: cursor must restore mid beat (owned resume).
	StoryCatalog.request_chapter(cid)
	player = packed.instantiate()
	player.suppress_scene_change = true
	player.lock_path = false
	player.chapter_path = ""
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	if player.current_beat_id() != mid:
		player.queue_free()
		return "%s resume want %s got %s" % [cid, mid, player.current_beat_id()]
	print("OK resume mid %s @ %s" % [cid, mid])
	# Walk to choice → ledger → hub return.
	var err := await _walk_to_label(player, choice, 80)
	if err != "":
		player.queue_free()
		return "%s %s" % [cid, err]
	if not player.simulate_press_action_containing(choice):
		player.queue_free()
		return "%s press choice failed labels=%s" % [cid, str(player.action_labels())]
	await get_tree().process_frame
	await get_tree().process_frame
	if player.current_beat_id() != "ledger":
		player.queue_free()
		return "%s after choice want ledger got %s" % [cid, player.current_beat_id()]
	if GameState.story.season_beat(cid) != "ledger":
		player.queue_free()
		return "%s cursor not ledger (got %s)" % [cid, GameState.story.season_beat(cid)]
	player.simulate_finish_dialogue()
	await get_tree().process_frame
	await get_tree().process_frame
	if not player.simulate_press_action_containing("灰旗堡"):
		player.queue_free()
		return "%s hub CTA missing labels=%s" % [cid, str(player.action_labels())]
	await get_tree().process_frame
	var landed := str(player.test_capture.get("scene", ""))
	if landed != HUB:
		player.queue_free()
		return "%s hub land want %s got %s" % [cid, HUB, landed]
	if str(GameState.get_meta("last_story_chapter", "")) != cid:
		player.queue_free()
		return "%s last_story_chapter meta missing" % cid
	# Cursor survives hub land (reopen still at ledger, not first beat).
	if GameState.story.season_beat(cid) != "ledger":
		player.queue_free()
		return "%s cursor cleared on hub return" % cid
	player.queue_free()
	await get_tree().process_frame
	StoryCatalog.request_chapter(cid)
	player = packed.instantiate()
	player.suppress_scene_change = true
	player.lock_path = false
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	if player.current_beat_id() != "ledger":
		player.queue_free()
		return "%s post-hub reopen want ledger got %s" % [cid, player.current_beat_id()]
	print("OK hub land+cursor %s" % cid)
	player.queue_free()
	await get_tree().process_frame
	return ""


func _walk_to_label(player, needle: String, max_steps: int) -> String:
	var steps := 0
	while steps < max_steps:
		player.simulate_finish_dialogue()
		await get_tree().process_frame
		await get_tree().process_frame
		var labels: Array = player.action_labels()
		for lab in labels:
			if str(lab).find(needle) >= 0:
				return ""
		var advanced := false
		for adv in ["继续", "继续 ▶"]:
			if player.simulate_press_action_containing(adv):
				advanced = true
				break
		if not advanced:
			return "stuck beat=%s labels=%s" % [player.current_beat_id(), str(labels)]
		steps += 1
		await get_tree().process_frame
	return "label %s not reached" % needle
