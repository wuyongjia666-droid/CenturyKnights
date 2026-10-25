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
	"cs06_01": "hourglass",
	"cs07_01": "hourglass",
	"cs08_01": "hourglass",
	"cs09_01": "hourglass",
	"cs10_01": "hourglass",
}
## After return, continue must land here (beat.next of the visit beat).
const AFTER := {
	"cs01_01": "tavern",
	"cs02_01": "tavern",
	"cs03_01": "bridge",
	"cs04_01": "bridge",
	"cs05_01": "bridge",
	"cs06_01": "bridge",
	"cs07_01": "bridge",
	"cs08_01": "bridge",
	"cs09_01": "bridge",
	"cs10_01": "bridge",
}
## Live press path on a spread of seasons (static gate covers all ten).
const LIVE := ["cs01_01", "cs03_01", "cs08_01", "cs10_01"]


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
		var hit_visit := 0
		var hit_continue := 0
		var total_visits := 0
		for b in data.get("beats", []):
			for a in b.get("actions", []):
				if typeof(a) != TYPE_DICTIONARY:
					continue
				for step in a.get("do", []):
					if typeof(step) != TYPE_DICTIONARY:
						continue
					if str(step.get("op", "")) != "visit":
						continue
					total_visits += 1
					if str(b.get("id", "")) != want_beat:
						return "%s visit on wrong beat %s want %s" % [cid, b.get("id"), want_beat]
					if str(step.get("path", "")) != HOURGLASS:
						return "%s visit path want hourglass got %s" % [cid, step.get("path")]
					if str(a.get("label", "")) != VISIT_LABEL:
						return "%s visit label want %s got %s" % [cid, VISIT_LABEL, a.get("label")]
					if str(a.get("id", "")) != "open_hourglass":
						return "%s visit action id" % cid
					hit_visit += 1
				if str(b.get("id", "")) == want_beat and str(a.get("id", "")) == "continue_after_visit":
					hit_continue += 1
					var lab := str(a.get("label", ""))
					if lab.find("继续") < 0:
						return "%s continue label missing 继续: %s" % [cid, lab]
					var goto_ok := false
					for step2 in a.get("do", []):
						if typeof(step2) == TYPE_DICTIONARY and str(step2.get("op", "")) == "goto":
							goto_ok = true
					if not goto_ok:
						return "%s continue_after_visit missing goto" % cid
		if hit_visit != 1:
			return "%s authored visit count %d (want 1 on %s)" % [cid, hit_visit, want_beat]
		if hit_continue != 1:
			return "%s continue_after_visit missing on %s" % [cid, want_beat]
		if total_visits != 1:
			return "%s total visit ops %d want 1" % [cid, total_visits]
		print("OK authored %s @%s → hourglass" % [cid, want_beat])
	return ""


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
	var err := ""
	if player.current_beat_id() != mid:
		err = "%s mid want %s got %s" % [cid, mid, player.current_beat_id()]
	elif GameState.story.season_beat(cid) != mid:
		err = "%s cursor not %s before visit" % [cid, mid]
	elif player.action_labels().find(VISIT_LABEL) < 0:
		err = "%s missing visit CTA labels=%s" % [cid, str(player.action_labels())]
	if err == "":
		# LIVE path: press the authored label — not simulate_visit.
		if not player.simulate_press_action_containing(VISIT_LABEL):
			err = "%s could not press visit CTA labels=%s" % [cid, str(player.action_labels())]
		else:
			await get_tree().process_frame
			if str(player.test_capture.get("scene", "")) != HOURGLASS:
				err = "%s press visit scene want hourglass got %s" % [
					cid, str(player.test_capture.get("scene", ""))]
			elif str(GameState.get_meta("story_return_chapter", "")) != cid:
				err = "%s story_return_chapter want %s got %s" % [
					cid, cid, str(GameState.get_meta("story_return_chapter", ""))]
			elif str(GameState.get_meta("story_return", "")) != StoryCatalog.player_scene():
				err = "%s story_return must be player not hub (got %s)" % [
					cid, str(GameState.get_meta("story_return", ""))]
	player.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	var ret := StoryCatalog.take_story_return(HUB)
	if ret != StoryCatalog.player_scene():
		return "%s take want player got %s" % [cid, ret]
	if str(GameState.get_meta("story_chapter_id", "")) != cid:
		return "%s story_chapter_id not restored" % cid
	if GameState.story.season_beat(cid) != mid:
		return "%s season cursor lost after take (got %s)" % [cid, GameState.story.season_beat(cid)]
	# Reopen chapter_player the way CKNav.replace(player) would.
	player = packed.instantiate()
	player.suppress_scene_change = true
	player.lock_path = false
	player.chapter_path = ""
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
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
	if err == "":
		print("OK live press visit %s @%s → hourglass → %s" % [cid, mid, after])
	return err
