extends Node
## Authored mid-cs visit CTAs (not simulate_visit): press 「去看月份怎么往前走」
## → hourglass → take_story_return → same beat → continue.

const Schema = preload("res://scripts/narrative/chapter_schema.gd")
const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"
const HOURGLASS := "res://scenes/hub/hourglass.tscn"
const VISIT_LABEL := "去看月份怎么往前走"
## Beat that owns the authored hourglass visit CTA.
const VISIT_BEAT := {
	"cs01_01": "audit",
	"cs02_01": "birth",
	"cs03_01": "hourglass",
	"cs04_01": "hourglass",
	"cs05_01": "hourglass",
	"cs05_02": "hourglass",
	"cs06_01": "hourglass",
	"cs06_02": "hourglass",
	"cs07_01": "hourglass",
	"cs07_02": "hourglass",
	"cs08_01": "hourglass",
	"cs08_02": "hourglass",
	"cs09_01": "hourglass",
	"cs09_02": "hourglass",
	"cs10_01": "hourglass",
	"cs10_02": "hourglass",
}
## After return, continue must land here (beat.next of the visit beat).
const AFTER := {
	"cs01_01": "tavern",
	"cs02_01": "tavern",
	"cs03_01": "bridge",
	"cs04_01": "bridge",
	"cs05_01": "bridge",
	"cs05_02": "bridge",
	"cs06_01": "bridge",
	"cs06_02": "bridge",
	"cs07_01": "bridge",
	"cs07_02": "bridge",
	"cs08_01": "bridge",
	"cs08_02": "bridge",
	"cs09_01": "bridge",
	"cs09_02": "bridge",
	"cs10_01": "bridge",
	"cs10_02": "bridge",
}
## Live press path on a spread of seasons (static gate covers all ten).
const LIVE := [
	"cs01_01", "cs02_01", "cs03_01", "cs04_01", "cs05_01", "cs05_02",
	"cs06_01", "cs06_02", "cs07_01", "cs07_02", "cs08_01", "cs08_02",
	"cs09_01", "cs09_02", "cs10_01", "cs10_02",
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_visit_authored: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON VISIT AUTHORED PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _authored_static_all()
	if err != "":
		return err
	for cid in LIVE:
		err = await _live_press_visit_roundtrip(cid)
		if err != "":
			return err
	return ""


func _authored_static_all() -> String:
	for cid in VISIT_BEAT.keys():
		var err := _authored_one(str(cid))
		if err != "":
			return err
		print("OK authored %s @%s → hourglass" % [cid, VISIT_BEAT[cid]])
	return ""


func _authored_one(cid: String) -> String:
	var path := "res://data/story/chapters/%s.json" % cid
	if not FileAccess.file_exists(path):
		return "missing " + path
	var schema := Schema.validate_file(path)
	if not schema.is_empty():
		return "%s schema %s" % [cid, str(schema[0])]
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return "%s not dict" % cid
	var want_beat := str(VISIT_BEAT[cid])
	var acc := {"visit": 0, "cont": 0, "total": 0, "err": ""}
	for b in data.get("beats", []):
		_accumulate_beat(cid, want_beat, b, acc)
		if str(acc["err"]) != "":
			return str(acc["err"])
	if int(acc["visit"]) != 1:
		return "%s authored visit count %d (want 1 on %s)" % [cid, int(acc["visit"]), want_beat]
	if int(acc["cont"]) != 1:
		return "%s continue_after_visit missing on %s" % [cid, want_beat]
	if int(acc["total"]) != 1:
		return "%s total visit ops %d want 1" % [cid, int(acc["total"])]
	return ""


func _accumulate_beat(cid: String, want_beat: String, b, acc: Dictionary) -> void:
	if str(acc.get("err", "")) != "":
		return
	for a in b.get("actions", []):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		if str(b.get("id", "")) == want_beat and str(a.get("id", "")) == "continue_after_visit":
			acc["cont"] = int(acc["cont"]) + 1
			var lab := str(a.get("label", ""))
			if lab.find("继续") < 0:
				acc["err"] = "%s continue label missing 继续: %s" % [cid, lab]
				return
			var goto_ok := false
			for step2 in a.get("do", []):
				if typeof(step2) == TYPE_DICTIONARY and str(step2.get("op", "")) == "goto":
					goto_ok = true
			if not goto_ok:
				acc["err"] = "%s continue_after_visit missing goto" % cid
				return
		for step in a.get("do", []):
			if typeof(step) != TYPE_DICTIONARY:
				continue
			if str(step.get("op", "")) != "visit":
				continue
			acc["total"] = int(acc["total"]) + 1
			if str(b.get("id", "")) != want_beat:
				acc["err"] = "%s visit on wrong beat %s want %s" % [cid, b.get("id"), want_beat]
				return
			if str(step.get("path", "")) != HOURGLASS:
				acc["err"] = "%s visit path want hourglass got %s" % [cid, step.get("path")]
				return
			if str(a.get("label", "")) != VISIT_LABEL:
				acc["err"] = "%s visit label want %s got %s" % [cid, VISIT_LABEL, a.get("label")]
				return
			if str(a.get("id", "")) != "open_hourglass":
				acc["err"] = "%s visit action id" % cid
				return
			acc["visit"] = int(acc["visit"]) + 1


func _live_press_visit_roundtrip(cid: String) -> String:
	var mid := str(VISIT_BEAT[cid])
	var after := str(AFTER[cid])
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var scene := StoryCatalog.request_chapter(cid)
	if scene != StoryCatalog.player_scene():
		return "%s request_chapter scene %s" % [cid, scene]
	var packed: PackedScene = load(PLAYER)
	var player = packed.instantiate()
	player.suppress_scene_change = true
	player.lock_path = false
	player.chapter_path = ""
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	player.simulate_goto_beat(mid)
	await get_tree().process_frame
	player.simulate_finish_dialogue()
	await get_tree().process_frame
	await get_tree().process_frame
	var err := _assert_ready_for_visit(cid, mid, player)
	if err == "":
		err = await _press_visit_and_check(cid, player)
	player.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	err = _assert_take_return(cid, mid)
	if err != "":
		return err
	err = await _reopen_and_continue(cid, mid, after, packed)
	if err == "":
		print("OK live press visit %s @%s → hourglass → %s" % [cid, mid, after])
	return err


func _assert_ready_for_visit(cid: String, mid: String, player) -> String:
	if player.current_beat_id() != mid:
		return "%s mid want %s got %s" % [cid, mid, player.current_beat_id()]
	if GameState.story.season_beat(cid) != mid:
		return "%s cursor not %s before visit" % [cid, mid]
	if player.action_labels().find(VISIT_LABEL) < 0:
		return "%s missing visit CTA labels=%s" % [cid, str(player.action_labels())]
	return ""


func _press_visit_and_check(cid: String, player) -> String:
	if not player.simulate_press_action_containing(VISIT_LABEL):
		return "%s could not press visit CTA labels=%s" % [cid, str(player.action_labels())]
	await get_tree().process_frame
	if str(player.test_capture.get("scene", "")) != HOURGLASS:
		return "%s press visit scene want hourglass got %s" % [
			cid, str(player.test_capture.get("scene", ""))]
	if str(GameState.get_meta("story_return_chapter", "")) != cid:
		return "%s story_return_chapter want %s got %s" % [
			cid, cid, str(GameState.get_meta("story_return_chapter", ""))]
	if str(GameState.get_meta("story_return", "")) != StoryCatalog.player_scene():
		return "%s story_return must be player not hub (got %s)" % [
			cid, str(GameState.get_meta("story_return", ""))]
	return ""


func _assert_take_return(cid: String, mid: String) -> String:
	var ret := StoryCatalog.take_story_return(HUB)
	if ret != StoryCatalog.player_scene():
		return "%s take want player got %s" % [cid, ret]
	if str(GameState.get_meta("story_chapter_id", "")) != cid:
		return "%s story_chapter_id not restored" % cid
	if GameState.story.season_beat(cid) != mid:
		return "%s season cursor lost after take (got %s)" % [cid, GameState.story.season_beat(cid)]
	return ""


func _reopen_and_continue(cid: String, mid: String, after: String, packed: PackedScene) -> String:
	var player = packed.instantiate()
	player.suppress_scene_change = true
	player.lock_path = false
	player.chapter_path = ""
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	var err := ""
	if player.current_beat_id() != mid:
		err = "%s reopen want %s got %s" % [cid, mid, player.current_beat_id()]
	else:
		player.simulate_finish_dialogue()
		await get_tree().process_frame
		await get_tree().process_frame
		if player.action_labels().find(VISIT_LABEL) < 0:
			err = "%s reopen missing visit CTA labels=%s" % [cid, str(player.action_labels())]
		elif not player.simulate_press_action_containing("继续"):
			err = "%s continue after return failed labels=%s" % [cid, str(player.action_labels())]
		else:
			await get_tree().process_frame
			await get_tree().process_frame
			if player.current_beat_id() != after:
				err = "%s after continue want %s got %s" % [cid, after, player.current_beat_id()]
	player.queue_free()
	await get_tree().process_frame
	return err
