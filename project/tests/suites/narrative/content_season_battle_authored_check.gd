extends Node
## Authored mid-cs battle CTAs (not simulate-only): press 「先试一锋」
## → battle scene + battle_return_chapter → reopen same beat → continue.

const Schema = preload("res://scripts/narrative/chapter_schema.gd")
const PLAYER := "res://scenes/story/chapter_player.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const BATTLE_LABEL := "先试一锋"
const MAP_ID := "quest_bandit"
## Beat that owns the authored mid-skirmish CTA.
const BATTLE_BEAT := {
	"cs01_01": "hall",
	"cs02_01": "estate",
	"cs03_01": "bridge",
	"cs04_01": "bridge",
	"cs05_01": "bridge",
	"cs06_01": "bridge",
	"cs07_01": "bridge",
	"cs08_01": "bridge",
	"cs09_01": "bridge",
	"cs10_01": "bridge",
}
## After return, continue must land here (beat.next of the battle beat).
const AFTER := {
	"cs01_01": "audit",
	"cs02_01": "birth",
	"cs03_01": "tavern",
	"cs04_01": "tavern",
	"cs05_01": "tavern",
	"cs06_01": "tavern",
	"cs07_01": "tavern",
	"cs08_01": "tavern",
	"cs09_01": "tavern",
	"cs10_01": "tavern",
}
## Live press path on a spread of seasons (static gate covers all ten).
const LIVE := ["cs01_01", "cs03_01", "cs08_01", "cs10_01"]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_battle_authored: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON BATTLE AUTHORED PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _authored_static_all()
	if err != "":
		return err
	for cid in LIVE:
		err = await _live_press_battle_roundtrip(cid)
		if err != "":
			return err
	return ""


func _authored_static_all() -> String:
	for cid in BATTLE_BEAT.keys():
		var err := _authored_one(str(cid))
		if err != "":
			return err
		print("OK authored %s @%s → battle %s" % [cid, BATTLE_BEAT[cid], MAP_ID])
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
	var want_beat := str(BATTLE_BEAT[cid])
	var acc := {"battle": 0, "cont": 0, "total": 0, "err": ""}
	for b in data.get("beats", []):
		_accumulate_beat(cid, want_beat, b, acc)
		if str(acc["err"]) != "":
			return str(acc["err"])
	if int(acc["battle"]) != 1:
		return "%s authored battle count %d (want 1 on %s)" % [cid, int(acc["battle"]), want_beat]
	if int(acc["cont"]) != 1:
		return "%s continue_after_battle missing on %s" % [cid, want_beat]
	if int(acc["total"]) != 1:
		return "%s total battle ops %d want 1" % [cid, int(acc["total"])]
	return ""


func _accumulate_beat(cid: String, want_beat: String, b, acc: Dictionary) -> void:
	if str(acc.get("err", "")) != "":
		return
	for a in b.get("actions", []):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		if str(b.get("id", "")) == want_beat and str(a.get("id", "")) == "continue_after_battle":
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
				acc["err"] = "%s continue_after_battle missing goto" % cid
				return
		for step in a.get("do", []):
			if typeof(step) != TYPE_DICTIONARY:
				continue
			if str(step.get("op", "")) != "battle":
				continue
			acc["total"] = int(acc["total"]) + 1
			if str(b.get("id", "")) != want_beat:
				acc["err"] = "%s battle on wrong beat %s want %s" % [cid, b.get("id"), want_beat]
				return
			if str(step.get("map", "")) != MAP_ID:
				acc["err"] = "%s battle map want %s got %s" % [cid, MAP_ID, step.get("map")]
				return
			if str(step.get("return", "")) != PLAYER:
				acc["err"] = "%s battle return must be player got %s" % [cid, step.get("return")]
				return
			if str(a.get("label", "")) != BATTLE_LABEL:
				acc["err"] = "%s battle label want %s got %s" % [cid, BATTLE_LABEL, a.get("label")]
				return
			if str(a.get("id", "")) != "open_skirmish":
				acc["err"] = "%s battle action id" % cid
				return
			var want_flag := cid.substr(0, 4) + "_mid_fought"
			var when_row = a.get("when", {})
			if typeof(when_row) != TYPE_DICTIONARY or str(when_row.get("not_flag", "")) != want_flag:
				acc["err"] = "%s when.not_flag want %s got %s" % [cid, want_flag, str(when_row)]
				return
			var wf: Array = step.get("win_flags", [])
			if wf.size() != 1 or str(wf[0]) != want_flag:
				acc["err"] = "%s win_flags want [%s] got %s" % [cid, want_flag, str(wf)]
				return
			acc["battle"] = int(acc["battle"]) + 1


func _live_press_battle_roundtrip(cid: String) -> String:
	var mid := str(BATTLE_BEAT[cid])
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
	var err := _assert_ready_for_battle(cid, mid, player)
	if err == "":
		err = await _press_battle_and_check(cid, player)
	player.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	err = _assert_win_back(cid, mid)
	if err != "":
		return err
	err = await _reopen_and_continue(cid, mid, after, packed)
	if err == "":
		print("OK live press battle %s @%s → %s → %s" % [cid, mid, MAP_ID, after])
	return err


func _assert_ready_for_battle(cid: String, mid: String, player) -> String:
	if player.current_beat_id() != mid:
		return "%s mid want %s got %s" % [cid, mid, player.current_beat_id()]
	if GameState.story.season_beat(cid) != mid:
		return "%s cursor not %s before battle" % [cid, mid]
	if player.action_labels().find(BATTLE_LABEL) < 0:
		return "%s missing battle CTA labels=%s" % [cid, str(player.action_labels())]
	return ""


func _press_battle_and_check(cid: String, player) -> String:
	if not player.simulate_press_action_containing(BATTLE_LABEL):
		return "%s could not press battle CTA labels=%s" % [cid, str(player.action_labels())]
	await get_tree().process_frame
	if str(player.test_capture.get("scene", "")) != BATTLE:
		return "%s press battle scene want battle got %s" % [
			cid, str(player.test_capture.get("scene", ""))]
	if str(player.test_capture.get("battle_map", "")) != MAP_ID:
		return "%s battle_map want %s got %s" % [
			cid, MAP_ID, str(player.test_capture.get("battle_map", ""))]
	if str(GameState.get_meta("battle_return_chapter", "")) != cid:
		return "%s battle_return_chapter want %s got %s" % [
			cid, cid, str(GameState.get_meta("battle_return_chapter", ""))]
	if str(GameState.get_meta("battle_return", "")) != StoryCatalog.player_scene():
		return "%s battle_return must be player not hub (got %s)" % [
			cid, str(GameState.get_meta("battle_return", ""))]
	return ""


func _assert_win_back(cid: String, mid: String) -> String:
	var back := BattleDefeat.back_path(true, false, StoryCatalog.player_scene())
	if back != StoryCatalog.player_scene():
		return "%s win back_path %s" % [cid, back]
	# Season cursor must survive the leave (remembered on load_beat before battle).
	if GameState.story.season_beat(cid) != mid:
		return "%s season cursor lost after battle leave (got %s)" % [
			cid, GameState.story.season_beat(cid)]
	return ""


func _reopen_and_continue(cid: String, mid: String, after: String, packed: PackedScene) -> String:
	# Mimic battle report → chapter_player: battle_return_chapter reopens chapter.
	GameState.set_meta("battle_return_chapter", cid)
	GameState.set_meta("story_chapter_id", "")
	var player = packed.instantiate()
	player.suppress_scene_change = true
	player.lock_path = false
	player.chapter_path = ""
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	var err := ""
	if str(player._chapter.get("id", "")) != cid:
		err = "%s reopen chapter want %s got %s" % [cid, cid, str(player._chapter.get("id", ""))]
	elif player.current_beat_id() != mid:
		err = "%s reopen want %s got %s" % [cid, mid, player.current_beat_id()]
	else:
		player.simulate_finish_dialogue()
		await get_tree().process_frame
		await get_tree().process_frame
		if player.action_labels().find(BATTLE_LABEL) < 0:
			err = "%s reopen missing battle CTA labels=%s" % [cid, str(player.action_labels())]
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
