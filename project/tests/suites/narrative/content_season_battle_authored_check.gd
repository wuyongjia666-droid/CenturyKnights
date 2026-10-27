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
	"cs01_02": "bridge",
	"cs02_02": "bridge",
	"cs03_02": "bridge",
	"cs03_03": "bridge",
	"cs04_02": "bridge",
	"cs04_03": "bridge",
	"cs05_01": "bridge",
	"cs05_02": "bridge",
	"cs05_03": "bridge",
	"cs06_01": "bridge",
	"cs06_02": "bridge",
	"cs06_03": "bridge",
	"cs07_03": "bridge",
	"cs07_01": "bridge",
	"cs07_02": "bridge",
	"cs08_01": "bridge",
	"cs08_02": "bridge",
	"cs09_01": "bridge",
	"cs09_02": "bridge",
	"cs10_01": "bridge",
	"cs10_02": "bridge",
}
## After return, continue must land here (beat.next of the battle beat).
const AFTER := {
	"cs01_01": "audit",
	"cs02_01": "birth",
	"cs03_01": "tavern",
	"cs04_01": "tavern",
	"cs01_02": "tavern",
	"cs02_02": "tavern",
	"cs03_02": "tavern",
	"cs03_03": "tavern",
	"cs04_02": "tavern",
	"cs04_03": "tavern",
	"cs05_01": "tavern",
	"cs05_02": "tavern",
	"cs05_03": "tavern",
	"cs06_01": "tavern",
	"cs06_02": "tavern",
	"cs06_03": "tavern",
	"cs07_03": "tavern",
	"cs07_01": "tavern",
	"cs07_02": "tavern",
	"cs08_01": "tavern",
	"cs08_02": "tavern",
	"cs09_01": "tavern",
	"cs09_02": "tavern",
	"cs10_01": "tavern",
	"cs10_02": "tavern",
}
## Live press path on every authored season (static gate already covers all ten).
const LIVE := [
	"cs01_01", "cs01_02", "cs02_01", "cs02_02", "cs03_01", "cs03_02", "cs03_03", "cs04_01", "cs04_02", "cs04_03",
	"cs05_01", "cs05_02", "cs05_03", "cs06_01", "cs06_02", "cs06_03", "cs07_01", "cs07_02",
	"cs07_03",
	"cs08_01", "cs08_02", "cs09_01", "cs09_02", "cs10_01", "cs10_02",
]


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
	var acc := {"open": 0, "retry": 0, "cont": 0, "total": 0, "lost_line": 0, "err": ""}
	for b in data.get("beats", []):
		_accumulate_beat(cid, want_beat, b, acc)
		if str(acc["err"]) != "":
			return str(acc["err"])
	if int(acc["open"]) != 1 or int(acc["retry"]) != 1:
		return "%s open/retry want 1/1 got %d/%d" % [cid, int(acc["open"]), int(acc["retry"])]
	if int(acc["cont"]) != 1:
		return "%s continue_after_battle missing on %s" % [cid, want_beat]
	if int(acc["total"]) != 2:
		return "%s total battle ops %d want 2" % [cid, int(acc["total"])]
	if int(acc["lost_line"]) != 1:
		return "%s mid_lost dialogue line missing on %s" % [cid, want_beat]
	return ""


func _accumulate_beat(cid: String, want_beat: String, b, acc: Dictionary) -> void:
	if str(acc.get("err", "")) != "":
		return
	var mid_flag := _fought(cid)
	var lost_flag := _lost(cid)
	if str(b.get("id", "")) == want_beat:
		_accumulate_lost_line(b, mid_flag, lost_flag, acc)
		_accumulate_continue(cid, b, acc)
	for a in b.get("actions", []):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		for step in a.get("do", []):
			if typeof(step) != TYPE_DICTIONARY or str(step.get("op", "")) != "battle":
				continue
			acc["total"] = int(acc["total"]) + 1
			var err := _check_battle_action(cid, want_beat, str(b.get("id", "")), a, step, mid_flag, lost_flag)
			if err != "":
				acc["err"] = err
				return
			var aid := str(a.get("id", ""))
			if aid == "open_skirmish":
				acc["open"] = int(acc["open"]) + 1
			elif aid == "retry_skirmish":
				acc["retry"] = int(acc["retry"]) + 1


func _accumulate_lost_line(b, mid_flag: String, lost_flag: String, acc: Dictionary) -> void:
	for line in b.get("lines", []):
		if typeof(line) != TYPE_DICTIONARY:
			continue
		var when_line = line.get("when", {})
		if typeof(when_line) != TYPE_DICTIONARY:
			continue
		var has_lost := false
		var has_not_fought := false
		for item in when_line.get("all", []):
			if typeof(item) != TYPE_DICTIONARY:
				continue
			if str(item.get("flag", "")) == lost_flag:
				has_lost = true
			if str(item.get("not_flag", "")) == mid_flag:
				has_not_fought = true
		if has_lost and has_not_fought and str(line.get("text", "")) != "":
			acc["lost_line"] = int(acc["lost_line"]) + 1


func _accumulate_continue(cid: String, b, acc: Dictionary) -> void:
	for a in b.get("actions", []):
		if typeof(a) != TYPE_DICTIONARY or str(a.get("id", "")) != "continue_after_battle":
			continue
		acc["cont"] = int(acc["cont"]) + 1
		if str(a.get("label", "")).find("继续") < 0:
			acc["err"] = "%s continue label missing 继续: %s" % [cid, str(a.get("label", ""))]
			return
		var mid_flag := _fought(cid)
		var lost_flag := _lost(cid)
		var goto_ok := false
		var skip_ok := false
		var abort_ok := false
		for step2 in a.get("do", []):
			if typeof(step2) != TYPE_DICTIONARY:
				continue
			var op := str(step2.get("op", ""))
			if op == "goto":
				goto_ok = true
			elif op == "season_ledger":
				var choice := str(step2.get("choice", ""))
				var outcome := str(step2.get("outcome", ""))
				var when_row = step2.get("when", {})
				if choice == "mid_skirmish_skip":
					if (
						_when_all_has(when_row, "not_flag", mid_flag)
						and _when_all_has(when_row, "not_flag", lost_flag)
						and outcome.find("未试锋") >= 0
						and bool(step2.get("yeartrace", false))
					):
						skip_ok = true
				elif choice == "mid_skirmish_abort":
					if (
						_when_all_has(when_row, "not_flag", mid_flag)
						and _when_all_has(when_row, "flag", lost_flag)
						and outcome.find("试锋未成") >= 0
						and bool(step2.get("yeartrace", false))
					):
						abort_ok = true
		if not goto_ok:
			acc["err"] = "%s continue_after_battle missing goto" % cid
		elif not skip_ok:
			acc["err"] = "%s continue missing 未试锋 skip ledger" % cid
		elif not abort_ok:
			acc["err"] = "%s continue missing 试锋未成 abort ledger" % cid


func _check_battle_action(cid: String, want_beat: String, beat_id: String, a, step, mid_flag: String, lost_flag: String) -> String:
	var err := ""
	if beat_id != want_beat:
		err = "%s battle on wrong beat %s want %s" % [cid, beat_id, want_beat]
	elif str(step.get("map", "")) != MAP_ID:
		err = "%s battle map want %s got %s" % [cid, MAP_ID, step.get("map")]
	elif str(step.get("return", "")) != PLAYER:
		err = "%s battle return must be player got %s" % [cid, step.get("return")]
	else:
		err = _check_battle_payload(cid, step, mid_flag, lost_flag)
	if err != "":
		return err
	return _check_battle_cta(cid, a, mid_flag, lost_flag)


func _check_battle_payload(cid: String, step, mid_flag: String, lost_flag: String) -> String:
	var wf: Array = step.get("win_flags", [])
	if wf.size() != 1 or str(wf[0]) != mid_flag:
		return "%s win_flags want [%s] got %s" % [cid, mid_flag, str(wf)]
	var lf: Array = step.get("lose_flags", [])
	if lf.size() != 1 or str(lf[0]) != lost_flag:
		return "%s lose_flags want [%s] got %s" % [cid, lost_flag, str(lf)]
	var led = step.get("win_ledger", {})
	if typeof(led) != TYPE_DICTIONARY:
		return "%s win_ledger missing" % cid
	if str(led.get("choice", "")) != "mid_skirmish":
		return "%s win_ledger.choice" % cid
	if str(led.get("outcome", "")) == "":
		return "%s win_ledger.outcome empty" % cid
	if not bool(led.get("yeartrace", false)):
		return "%s win_ledger.yeartrace" % cid
	return ""


func _check_battle_cta(cid: String, a, mid_flag: String, lost_flag: String) -> String:
	var aid := str(a.get("id", ""))
	var alab := str(a.get("label", ""))
	var when_row = a.get("when", {})
	if aid == "open_skirmish":
		if alab != BATTLE_LABEL:
			return "%s open label want %s got %s" % [cid, BATTLE_LABEL, alab]
		if not _when_all_has(when_row, "not_flag", mid_flag) or not _when_all_has(when_row, "not_flag", lost_flag):
			return "%s open when want not %s/%s got %s" % [cid, mid_flag, lost_flag, str(when_row)]
		return ""
	if aid == "retry_skirmish":
		if alab != "再试锋镝":
			return "%s retry label want 再试锋镝 got %s" % [cid, alab]
		if not _when_all_has(when_row, "not_flag", mid_flag) or not _when_all_has(when_row, "flag", lost_flag):
			return "%s retry when want not %s + flag %s got %s" % [cid, mid_flag, lost_flag, str(when_row)]
		return ""
	return "%s unexpected battle action id %s" % [cid, aid]


func _mid_prefix(cid: String) -> String:
	# Season-level mid flags (csNN_mid_*) shared by _01/_02; matches hub_chain.
	return cid.substr(0, 4)


func _fought(cid: String) -> String:
	return _mid_prefix(cid) + "_mid_fought"


func _lost(cid: String) -> String:
	return _mid_prefix(cid) + "_mid_lost"


func _when_all_has(when_row, key: String, want: String) -> bool:
	if typeof(when_row) != TYPE_DICTIONARY:
		return false
	for item in when_row.get("all", []):
		if typeof(item) == TYPE_DICTIONARY and str(item.get(key, "")) == want:
			return true
	return false


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
