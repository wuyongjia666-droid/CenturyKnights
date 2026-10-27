extends Node
## S05 可玩门禁：同一存档走完 cs05_01 + cs05_02 + cs05_03 的 hub→章→战/访→回。
## 根因同 playable_gate：季级裸旗不得让后章藏掉「先试一锋」。
## 裸旗仍留给协议测试；播放器只认本章的章 id#旗。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const HOURGLASS := "res://scenes/hub/hourglass.tscn"
const FIRST := "先试一锋"
const RETRY := "再试锋镝"
const VISIT := "去看月份怎么往前走"
const HUB_LABEL := "回到灰旗堡"
const LOSS_NEEDLE := "锋收回来"
const MAP_ID := "quest_bandit"
const StoryFlagScope = preload("res://scripts/narrative/story_flag_scope.gd")

const CHAPTERS := ["cs05_01", "cs05_02", "cs05_03"]

var _player = null


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_playable_gate_s05: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON PLAYABLE GATE S05 PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := await _locale_chrome()
	if err != "":
		return err
	Locale.set_lang("zh_CN")
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	err = await _hub_chips(CHAPTERS)
	if err != "":
		return err
	err = await _cycle("cs05_01", true)
	if err != "":
		return err
	if not GameState.flag("cs05_mid_fought"):
		return "cs05_01 win did not keep raw cs05_mid_fought"
	err = await _cycle("cs05_02", false)
	if err != "":
		return err
	err = await _cs05_still_fought()
	if err != "":
		return err
	err = await _cycle("cs05_03", false)
	if err != "":
		return err
	err = await _hub_chips(CHAPTERS)
	if err != "":
		return err
	print("OK playable gate cs05_01+cs05_02+cs05_03 same save")
	return ""


func _locale_chrome() -> String:
	Locale.set_lang("en")
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var err := await _open_player("cs05_01")
	if err != "":
		return err
	await get_tree().process_frame
	_player.size = Vector2(1280, 720)
	await get_tree().process_frame
	var save := _player.find_child("StorySave", true, false) as Button
	var leave := _player.find_child("StoryLeaveHub", true, false) as Button
	if save == null or leave == null:
		return "locale chrome buttons missing"
	if save.text == "story_save" or save.text == "..." or save.text.find("Save") < 0:
		return "save locale hole got %s" % save.text
	if leave.text == "story_back_to_hub" or leave.text == "..." or leave.text.find("castle") < 0:
		return "leave locale hole got %s" % leave.text
	var labels: Array = _player.action_labels()
	if labels.is_empty() or str(labels[0]).find("Continue") < 0:
		return "continue locale hole labels=%s" % str(labels)
	if str(labels[0]) == "story_continue_line":
		return "continue still raw key"
	var rect := leave.get_global_rect()
	if rect.size.x < 8.0 or rect.position.x < 0.0 or rect.position.x + rect.size.x > 1288.0:
		return "leave off screen %s" % rect
	if rect.position.y > 80.0:
		return "leave not in the top bar %s" % rect
	_free_player()
	await get_tree().process_frame
	Locale.set_lang("zh_CN")
	print("OK locale chrome en save/leave/continue on screen")
	return ""


func _cycle(cid: String, probe_leave: bool) -> String:
	var err := await _open_player(cid)
	if err != "":
		return err
	if probe_leave:
		err = await _probe_leave(cid)
		if err != "":
			return err
	var need_battle := true
	var need_visit := true
	for _step in 30:
		_player.simulate_finish_dialogue()
		await get_tree().process_frame
		await get_tree().process_frame
		if str(_player._chapter.get("id", "")) != cid:
			return "%s drifted to %s" % [cid, str(_player._chapter.get("id", ""))]
		var labels: Array = _player.action_labels()
		var acted := false
		if need_battle and labels.find(FIRST) >= 0:
			err = _sibling_fought_ok(cid)
			if err != "":
				return err
			err = await _battle(cid)
			if err != "":
				return err
			need_battle = false
			acted = true
		elif need_visit and labels.find(VISIT) >= 0:
			err = await _visit(cid)
			if err != "":
				return err
			need_visit = false
			acted = true
		elif not need_battle and not need_visit and labels.find(HUB_LABEL) >= 0:
			return await _leave_via_action(cid, labels)
		elif not need_battle and not need_visit:
			err = await _press_real_choice(cid, labels)
			if err == "skip":
				pass
			elif err != "":
				return err
			else:
				acted = true
		if acted:
			continue
		if _press_continue():
			await get_tree().process_frame
			await get_tree().process_frame
			continue
		return "%s stuck need_battle=%s need_visit=%s beat=%s labels=%s" % [
			cid, need_battle, need_visit, _player.current_beat_id(), str(labels)]
	return "%s cycle exceeded steps" % cid


func _sibling_fought_ok(cid: String) -> String:
	if cid != "cs05_02" and cid != "cs05_03":
		return ""
	if not GameState.flag("cs05_mid_fought"):
		return "%s expected raw fought still set" % cid
	if StoryFlagScope.seen("cs05_mid_fought"):
		return "%s inherited prior cs05 fought" % cid
	return ""


func _leave_via_action(cid: String, labels: Array) -> String:
	if not _player.simulate_press_action_containing(HUB_LABEL):
		return "%s could not press hub return %s" % [cid, str(labels)]
	await get_tree().process_frame
	if str(_player.test_capture.get("scene", "")) != HUB:
		return "%s return scene %s" % [cid, str(_player.test_capture.get("scene", ""))]
	if str(GameState.get_meta("last_story_chapter", "")) != cid:
		return "%s last_story_chapter" % cid
	_free_player()
	await get_tree().process_frame
	print("OK cycle %s battle+visit+hub" % cid)
	return ""


func _press_real_choice(cid: String, labels: Array) -> String:
	var choice := _real_choice(labels)
	if choice == "":
		return "skip"
	if not _player.simulate_press_action_containing(choice):
		return "%s choice press %s" % [cid, choice]
	await get_tree().process_frame
	await get_tree().process_frame
	return ""


func _probe_leave(cid: String) -> String:
	var beat: String = _player.current_beat_id()
	var leave := _player.find_child("StoryLeaveHub", true, false) as Button
	if leave == null:
		return "%s StoryLeaveHub missing" % cid
	if leave.text != HUB_LABEL:
		return "%s leave text %s" % [cid, leave.text]
	leave.pressed.emit()
	await get_tree().process_frame
	if str(_player.test_capture.get("scene", "")) != HUB:
		return "%s mid leave scene %s" % [cid, str(_player.test_capture.get("scene", ""))]
	if GameState.story.season_beat(cid) != beat:
		return "%s mid leave wiped beat %s" % [cid, GameState.story.season_beat(cid)]
	_free_player()
	await get_tree().process_frame
	var err := await _open_player(cid)
	if err != "":
		return err
	if _player.current_beat_id() != beat:
		return "%s resume after leave want %s got %s" % [cid, beat, _player.current_beat_id()]
	print("OK %s mid-chapter leave resumes %s" % [cid, beat])
	return ""


func _battle(cid: String) -> String:
	var fought := cid.substr(0, 4) + "_mid_fought"
	var lost := cid.substr(0, 4) + "_mid_lost"
	var beat: String = _player.current_beat_id()
	if not _player.simulate_press_action_containing(FIRST):
		return "%s first press %s" % [cid, str(_player.action_labels())]
	await get_tree().process_frame
	var err := _assert_battle_launch(cid, fought)
	if err != "":
		return err
	err = _assert_loss_stamp(cid, lost)
	if err != "":
		return err
	err = await _reopen_loss_line(cid, beat)
	if err != "":
		return err
	err = await _retry_and_win(cid, fought, lost, beat)
	if err != "":
		return err
	print("OK %s battle loss→retry→win @%s" % [cid, beat])
	return ""


func _assert_loss_stamp(cid: String, lost: String) -> String:
	if BattleDefeat.back_path(false, false, PLAYER) != PLAYER:
		return "%s loss did not return to chapter" % cid
	if not GameState.flag(lost):
		return "%s loss raw flag" % cid
	if not StoryFlagScope.seen(lost):
		return "%s loss not scoped to this chapter" % cid
	return ""


func _reopen_loss_line(cid: String, beat: String) -> String:
	_free_player()
	await get_tree().process_frame
	var err := await _open_player(cid)
	if err != "":
		return err
	if _player.current_beat_id() != beat:
		return "%s loss resume beat %s" % [cid, _player.current_beat_id()]
	_player.simulate_finish_dialogue()
	await get_tree().process_frame
	var body := str(_player._body.text)
	if body.find(LOSS_NEEDLE) < 0:
		return "%s loss line missing %s" % [cid, body]
	var labels: Array = _player.action_labels()
	if labels.find(RETRY) < 0 or labels.find(FIRST) >= 0:
		return "%s loss CTA %s" % [cid, str(labels)]
	return ""


func _retry_and_win(cid: String, fought: String, lost: String, beat: String) -> String:
	if not _player.simulate_press_action_containing(RETRY):
		return "%s retry press" % cid
	await get_tree().process_frame
	var err := _assert_battle_launch(cid, fought)
	if err != "":
		return err
	BattleVictory.apply(MAP_ID)
	err = _assert_win_bookkeeping(cid, fought, lost)
	if err != "":
		return err
	return await _reopen_after_win(cid, beat)


func _assert_win_bookkeeping(cid: String, fought: String, lost: String) -> String:
	if not GameState.flag(fought) or GameState.flag(lost):
		return "%s win flags fought=%s lost=%s" % [cid, GameState.flag(fought), GameState.flag(lost)]
	if not StoryFlagScope.seen(fought) or StoryFlagScope.seen(lost):
		return "%s win scope fought/lost" % cid
	var led: Dictionary = CKSuiKe.season_ledger_find(cid, "mid_skirmish")
	if led.is_empty() or str(led.get("outcome", "")) == "":
		return "%s win ledger missing" % cid
	return ""


func _reopen_after_win(cid: String, beat: String) -> String:
	_free_player()
	await get_tree().process_frame
	var err := await _open_player(cid)
	if err != "":
		return err
	if _player.current_beat_id() != beat:
		return "%s win resume beat %s" % [cid, _player.current_beat_id()]
	_player.simulate_finish_dialogue()
	await get_tree().process_frame
	var body := str(_player._body.text)
	if body.find(LOSS_NEEDLE) >= 0:
		return "%s loss line survived win %s" % [cid, body]
	var labels: Array = _player.action_labels()
	if labels.find(FIRST) >= 0 or labels.find(RETRY) >= 0:
		return "%s fight CTA still up after win %s" % [cid, str(labels)]
	if not _press_continue():
		return "%s no continue after win %s" % [cid, str(labels)]
	await get_tree().process_frame
	await get_tree().process_frame
	return ""


func _assert_battle_launch(cid: String, fought: String) -> String:
	if str(_player.test_capture.get("scene", "")) != BATTLE:
		return "%s battle scene %s" % [cid, str(_player.test_capture.get("scene", ""))]
	if str(GameState.get_meta("battle_map", "")) != MAP_ID:
		return "%s battle map %s" % [cid, str(GameState.get_meta("battle_map", ""))]
	var map: Dictionary = BattleMaps.get_map(MAP_ID)
	if str(map.get("name", "")) == "" or str(map.get("name", "")) == str(BattleMaps.get_map("ch0_pass").get("name", "")):
		return "%s quest_bandit fell back to ch0" % cid
	if str(_player.test_capture.get("battle_objective", "")) != "rout":
		return "%s objective %s" % [cid, str(_player.test_capture.get("battle_objective", ""))]
	if str(GameState.get_meta("battle_return_chapter", "")) != cid:
		return "%s battle_return_chapter %s" % [cid, str(GameState.get_meta("battle_return_chapter", ""))]
	var ret := str(GameState.get_meta("battle_return", ""))
	if ret != PLAYER or ret == HUB:
		return "%s battle_return %s" % [cid, ret]
	var wins: Array = _player.test_capture.get("battle_win_flags", [])
	if wins.find(fought) < 0:
		return "%s win_flags %s" % [cid, str(wins)]
	return ""


func _visit(cid: String) -> String:
	var beat: String = _player.current_beat_id()
	if not _player.simulate_press_action_containing(VISIT):
		return "%s visit press %s" % [cid, str(_player.action_labels())]
	await get_tree().process_frame
	if str(_player.test_capture.get("scene", "")) != HOURGLASS:
		return "%s visit scene %s" % [cid, str(_player.test_capture.get("scene", ""))]
	if str(GameState.get_meta("story_return_chapter", "")) != cid:
		return "%s story_return_chapter %s" % [cid, str(GameState.get_meta("story_return_chapter", ""))]
	if str(GameState.get_meta("story_return", "")) != PLAYER:
		return "%s story_return %s" % [cid, str(GameState.get_meta("story_return", ""))]
	var back := StoryCatalog.take_story_return("")
	if back != PLAYER:
		return "%s take_story_return %s" % [cid, back]
	if str(GameState.get_meta("story_chapter_id", "")) != cid:
		return "%s story_chapter_id after visit %s" % [cid, str(GameState.get_meta("story_chapter_id", ""))]
	_free_player()
	await get_tree().process_frame
	var err := await _open_player(cid)
	if err != "":
		return err
	if _player.current_beat_id() != beat:
		return "%s visit resume want %s got %s" % [cid, beat, _player.current_beat_id()]
	_player.simulate_finish_dialogue()
	await get_tree().process_frame
	if not _press_continue():
		return "%s no continue after visit %s" % [cid, str(_player.action_labels())]
	await get_tree().process_frame
	await get_tree().process_frame
	print("OK %s visit hourglass→chapter @%s" % [cid, beat])
	return ""


func _cs05_still_fought() -> String:
	var beat := _beat_with_label("cs05_01", FIRST)
	if beat == "":
		return "cs05_01 battle beat missing"
	var err := await _open_player("cs05_01")
	if err != "":
		return err
	_player.simulate_goto_beat(beat)
	await get_tree().process_frame
	_player.simulate_finish_dialogue()
	await get_tree().process_frame
	if not StoryFlagScope.seen("cs05_mid_fought"):
		return "cs05_01 lost its own fought after cs05_02"
	var labels: Array = _player.action_labels()
	if labels.find(FIRST) >= 0:
		return "cs05_01 fight CTA returned after a win %s" % str(labels)
	_free_player()
	await get_tree().process_frame
	print("OK cs05_01 fought stays chapter-local after cs05_02")
	return ""


func _hub_chips(ids: Array) -> String:
	var packed: PackedScene = load(HUB)
	if packed == null:
		return "castle_hub missing"
	var hub = packed.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	if hub.find_child("ContentSeasonRow", true, false) == null:
		hub.queue_free()
		await get_tree().process_frame
		return "ContentSeasonRow missing"
	if hub.has_method("_open_content_season_sheet"):
		hub.call("_open_content_season_sheet")
		await get_tree().process_frame
		await get_tree().process_frame
	for cid in ids:
		var chip := hub.find_child("Season_%s" % cid, true, false) as BaseButton
		if chip == null:
			hub.queue_free()
			await get_tree().process_frame
			return "hub chip %s missing" % cid
		if chip.disabled:
			hub.queue_free()
			await get_tree().process_frame
			return "hub chip %s disabled" % cid
		if StoryCatalog.request_chapter(cid) != PLAYER:
			hub.queue_free()
			await get_tree().process_frame
			return "request_chapter %s" % cid
	hub.queue_free()
	await get_tree().process_frame
	return ""


func _open_player(cid: String) -> String:
	StoryCatalog.request_chapter(cid)
	var packed: PackedScene = load(PLAYER)
	if packed == null:
		return "chapter player missing"
	_player = packed.instantiate()
	_player.suppress_scene_change = true
	_player.lock_path = false
	_player.chapter_path = ""
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	if str(_player._chapter.get("id", "")) != cid:
		return "opened %s want %s" % [str(_player._chapter.get("id", "")), cid]
	return ""


func _free_player() -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	_player = null


func _press_continue() -> bool:
	if _player.simulate_press_action_containing("继续 ▶"):
		return true
	return _player.simulate_press_action_containing("继续")


func _real_choice(labels: Array) -> String:
	for raw in labels:
		var label := str(raw)
		if label.find("继续") >= 0:
			continue
		if label == FIRST or label == RETRY or label == VISIT or label == HUB_LABEL:
			continue
		return label
	return ""


func _beat_with_label(cid: String, label: String) -> String:
	var path := "res://data/story/chapters/%s.json" % cid
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	for beat in data.get("beats", []):
		if typeof(beat) != TYPE_DICTIONARY:
			continue
		for action in beat.get("actions", []):
			if typeof(action) == TYPE_DICTIONARY and str(action.get("label", "")) == label:
				return str(beat.get("id", ""))
	return ""
