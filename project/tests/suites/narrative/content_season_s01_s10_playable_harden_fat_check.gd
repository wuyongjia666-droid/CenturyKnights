extends Node
## Fat knife #7: 已有季可玩硬化（S01–S10）—
## 每季进章→关键战/访或选择→章末「回到灰旗堡」；卡死/无出口/读档撞号清零；
## 禁新开季、禁一句台词充数、禁抬截图 baseline。
## Desktop E2E；抽样 S01/S05/S10 章内+章末出口 shots。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const HOURGLASS := "res://scenes/hub/hourglass.tscn"
const StoryFlagScope = preload("res://scripts/narrative/story_flag_scope.gd")
const Schema = preload("res://scripts/narrative/chapter_schema.gd")

const FIRST := "先试一锋"
const RETRY := "再试锋镝"
const VISIT := "去看月份怎么往前走"
const HUB_LABEL := "回到灰旗堡"
const MAP_ID := "quest_bandit"
const MARKER := "CONTENT SEASON S01-S10 PLAYABLE HARDEN FAT PASS"
const SHOT_DIR := "user://season_s01_s10_harden_shots"
const DESK := Vector2i(1280, 720)

## One playable chapter per season (enter→critical→exit).
const SEASON_CHAPTERS := [
	"cs01_01", "cs02_01", "cs03_01", "cs04_01", "cs05_01",
	"cs06_01", "cs07_01", "cs08_01", "cs09_01", "cs10_01",
]

## Sample 3 seasons for full battle+visit+choice+hub + shots.
const SAMPLE := ["cs01_01", "cs05_01", "cs10_01"]

var _player = null
var _shot_n := 0


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content season s01-s10 playable harden fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _algebra()
	if err != "":
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	DisplayServer.window_set_size(DESK)
	await _settle(2)
	err = await _chrome_leave_onscreen()
	if err != "":
		return err
	err = await _save_load_no_collision()
	if err != "":
		return err
	err = await _all_seasons_enter_critical_exit()
	if err != "":
		return err
	err = await _sample_three_full_paths()
	if err != "":
		return err
	return ""


func _algebra() -> String:
	var err := _algebra_player_leave()
	if err != "":
		return err
	err = _algebra_ban_new_season()
	if err != "":
		return err
	for cid in SEASON_CHAPTERS:
		err = _algebra_chapter(str(cid))
		if err != "":
			return err
	print("OK algebra S01-S10 return_scene+battle+visit+choice+ledger + leave repin")
	return ""


func _algebra_player_leave() -> String:
	var player := FileAccess.get_file_as_string("res://scripts/story/chapter_player.gd")
	if player.find("call_deferred(\"_place_top_buttons\")") < 0:
		return "chapter_player must deferred-repin StoryLeaveHub"
	if player.find("top_buttons_cluster") < 0:
		return "chapter_player must measure top button cluster (EN leave width)"
	if player.find("story_back_to_hub") < 0:
		return "chapter_player missing hub exit label wiring"
	return ""


func _algebra_ban_new_season() -> String:
	## Ban: no new content season dirs/index rows invented by this knife.
	var idx := FileAccess.get_file_as_string("res://data/content_seasons/index.json")
	if idx.find("cs11") >= 0 or idx.find("S11") >= 0:
		return "ban: must not open S11 / cs11 for progress"
	var self_body := FileAccess.get_file_as_string(
		"res://tests/suites/narrative/content_season_s01_s10_playable_harden_fat_check.gd")
	if self_body.find("EmptyHost") >= 0 and self_body.find("禁") < 0:
		return "ban: EmptyHost surface knife"
	return ""


func _algebra_chapter(cid: String) -> String:
	var path := "res://data/story/chapters/%s.json" % cid
	if not FileAccess.file_exists(path):
		return "missing " + path
	var schema: Array = Schema.validate_file(path)
	if not schema.is_empty():
		return "%s schema %s" % [cid, str(schema[0])]
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return "%s not dict" % cid
	if str(data.get("return_scene", "")) != HUB:
		return "%s return_scene not hub" % cid
	var beats: Array = data.get("beats", [])
	if beats.is_empty():
		return "%s no beats" % cid
	var last: Dictionary = beats[beats.size() - 1]
	if str(last.get("id", "")) != "ledger":
		return "%s terminal want ledger got %s" % [cid, last.get("id")]
	return _algebra_ops(cid, beats)


func _algebra_ops(cid: String, beats: Array) -> String:
	var has_battle := false
	var has_visit := false
	var has_choice := false
	for b in beats:
		for a in b.get("actions", []):
			if typeof(a) != TYPE_DICTIONARY:
				continue
			for op in a.get("do", []):
				if typeof(op) != TYPE_DICTIONARY:
					continue
				match str(op.get("op", "")):
					"battle":
						has_battle = true
					"visit":
						has_visit = true
					"season_ledger":
						var ch := str(op.get("choice", ""))
						if ch != "" and ch.find("skip") < 0 and ch.find("abort") < 0:
							has_choice = true
	if not has_battle:
		return "%s missing mid battle" % cid
	if not has_visit:
		return "%s missing visit exit" % cid
	if not has_choice:
		return "%s missing tavern critical choice" % cid
	return ""


func _settle(n: int = 4) -> void:
	for _i in n:
		await get_tree().process_frame


func _shot(tag: String) -> void:
	_shot_n += 1
	var path := "%s/%02d_%s.png" % [SHOT_DIR, _shot_n, tag]
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(ProjectSettings.globalize_path(path))
		print("SHOT ", path)


func _boot() -> void:
	GameState.new_game("季硬化", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false


func _chrome_leave_onscreen() -> String:
	_boot()
	Locale.set_lang("en")
	var err := await _open_player("cs01_01")
	if err != "":
		return err
	_player.size = Vector2(1280, 720)
	await _settle(6)
	_player._place_top_buttons()
	await _settle(2)
	var leave := _player.find_child("StoryLeaveHub", true, false) as Button
	var save := _player.find_child("StorySave", true, false) as Button
	if leave == null or save == null:
		return "chrome buttons missing"
	if leave.text.find("castle") < 0:
		return "en leave missing castle got %s" % leave.text
	var rect := leave.get_global_rect()
	if rect.size.x < 8.0 or rect.position.x < 0.0:
		return "en leave off-screen left %s" % rect
	if rect.position.x + rect.size.x > 1288.0:
		return "en leave off-screen right %s cluster=%s" % [
			rect, str(_player.test_capture.get("top_buttons_cluster", "?"))]
	if rect.position.y > 100.0:
		return "en leave not top bar %s" % rect
	print("OK chrome en leave on-screen ", rect)
	_free_player()
	await _settle(2)
	Locale.set_lang("zh_CN")
	err = await _open_player("cs01_01")
	if err != "":
		return err
	_player.size = Vector2(1280, 720)
	await _settle(6)
	_player._place_top_buttons()
	await _settle(2)
	leave = _player.find_child("StoryLeaveHub", true, false) as Button
	if leave == null or leave.text != HUB_LABEL:
		return "zh leave text %s" % (leave.text if leave else "null")
	rect = leave.get_global_rect()
	if rect.position.x + rect.size.x > 1288.0:
		return "zh leave off-screen %s" % rect
	print("OK chrome zh leave on-screen ", rect)
	_free_player()
	await _settle(2)
	return ""


func _save_load_no_collision() -> String:
	## 读档撞号: season_beats per chapter + scoped mid flags must not overwrite siblings.
	_boot()
	Locale.set_lang("zh_CN")
	var prep := _save_stamp_scoped()
	if str(prep.get("err", "")) != "":
		return str(prep["err"])
	var taken: Dictionary = prep["taken"]
	var k1: String = prep["k1"]
	var k2: String = prep["k2"]
	if not GameState.save_game():
		return "save_game failed"
	GameState.new_game("擦档", "灰旗", GameState.crest_color)
	if not GameState.load_game():
		return "load_game failed"
	var err := _save_assert_after_load(k1, k2, taken)
	if err != "":
		return err
	print("OK save/load season_beats+scoped flags+id no 撞号")
	return ""


func _save_stamp_scoped() -> Dictionary:
	GameState.story.set_season_beat("cs03_01", "bridge")
	GameState.story.set_season_beat("cs03_02", "hourglass")
	GameState.set_meta("story_flag_chapter", "cs03_01")
	StoryFlagScope.note("cs03_01", "cs03_mid_fought", true)
	GameState.set_flag("cs03_mid_fought", true)
	GameState.set_meta("story_flag_chapter", "cs03_02")
	StoryFlagScope.note("cs03_02", "cs03_mid_lost", true)
	GameState.set_flag("cs03_mid_lost", true)
	var k1 := StoryFlagScope.scoped_key("cs03_01", "cs03_mid_fought")
	var k2 := StoryFlagScope.scoped_key("cs03_02", "cs03_mid_lost")
	if k1 == k2:
		return {"err": "scoped keys collided"}
	if not GameState.flag(k1) or not GameState.flag(k2):
		return {"err": "scoped flags not stored"}
	var lead0: CKCharacter = GameState.get_leader()
	if lead0 == null:
		return {"err": "leader missing before save"}
	var taken: Dictionary = {}
	for id in GameState.characters.keys():
		taken[str(id)] = true
	return {"err": "", "taken": taken, "k1": k1, "k2": k2}


func _save_assert_after_load(k1: String, k2: String, taken: Dictionary) -> String:
	if GameState.story.season_beat("cs03_01") != "bridge":
		return "season_beats cs03_01 wiped on load"
	if GameState.story.season_beat("cs03_02") != "hourglass":
		return "season_beats cs03_02 wiped/collided on load"
	if not GameState.flag(k1) or not GameState.flag(k2):
		return "scoped flags lost on load"
	GameState.set_meta("story_flag_chapter", "cs03_01")
	if not StoryFlagScope.seen("cs03_mid_fought"):
		return "cs03_01 fought not seen after load"
	if StoryFlagScope.seen("cs03_mid_lost"):
		return "cs03_01 wrongly inherited cs03_02 lost"
	GameState.set_meta("story_flag_chapter", "cs03_02")
	if not StoryFlagScope.seen("cs03_mid_lost"):
		return "cs03_02 lost not seen after load"
	if StoryFlagScope.seen("cs03_mid_fought"):
		return "cs03_02 wrongly inherited cs03_01 fought"
	var lead: CKCharacter = GameState.get_leader()
	if lead == null:
		return "leader missing after load"
	## Audit P0-3: next id after load must not reuse a saved person.
	var nid := CharacterFactory.next_id("c")
	if taken.has(nid) or nid == str(lead.id):
		return "character id 撞号 got %s" % nid
	return ""


func _all_seasons_enter_critical_exit() -> String:
	_boot()
	Locale.set_lang("zh_CN")
	for cid in SEASON_CHAPTERS:
		var err := await _cycle_critical_exit(cid, false)
		if err != "":
			return err
	print("OK all S01-S10 _01 enter→critical→hub exit")
	return ""


func _sample_three_full_paths() -> String:
	_boot()
	Locale.set_lang("zh_CN")
	for cid in SAMPLE:
		var err := await _cycle_critical_exit(cid, true)
		if err != "":
			return err
	print("OK sample S01/S05/S10 full paths + shots")
	return ""


func _cycle_critical_exit(cid: String, with_shots: bool) -> String:
	var err := await _open_player(cid)
	if err != "":
		return err
	_player.size = Vector2(1280, 720)
	await _settle(3)
	if with_shots:
		_shot("%s_interior" % cid)
	var need_battle := true
	var need_visit := true
	var need_choice := true
	for _step in 36:
		_player.simulate_finish_dialogue()
		await _settle(2)
		if str(_player._chapter.get("id", "")) != cid:
			return "%s drifted to %s" % [cid, str(_player._chapter.get("id", ""))]
		var labels: Array = _player.action_labels()
		var acted := false
		if need_battle and labels.find(FIRST) >= 0:
			err = await _do_battle_win(cid)
			if err != "":
				return err
			need_battle = false
			acted = true
		elif need_visit and labels.find(VISIT) >= 0:
			err = await _do_visit(cid)
			if err != "":
				return err
			need_visit = false
			acted = true
		elif need_choice:
			var choice := _pick_choice(labels)
			if choice != "":
				if not _player.simulate_press_action_containing(choice):
					return "%s choice press %s" % [cid, choice]
				await _settle(2)
				need_choice = false
				acted = true
		if not need_battle and not need_visit and not need_choice and labels.find(HUB_LABEL) >= 0:
			if with_shots:
				_shot("%s_exit" % cid)
			if not _player.simulate_press_action_containing(HUB_LABEL):
				return "%s hub press %s" % [cid, str(labels)]
			await _settle(2)
			if str(_player.test_capture.get("scene", "")) != HUB:
				return "%s exit scene %s" % [cid, str(_player.test_capture.get("scene", ""))]
			_free_player()
			await _settle(2)
			print("OK harden cycle %s" % cid)
			return ""
		if acted:
			continue
		if _press_continue():
			await _settle(2)
			continue
		## Mid-chapter top leave must never be the only way — but stuck here is P0.
		return "%s stuck battle=%s visit=%s choice=%s beat=%s labels=%s" % [
			cid, need_battle, need_visit, need_choice, _player.current_beat_id(), str(labels)]
	return "%s cycle exceeded" % cid


func _pick_choice(labels: Array) -> String:
	for lab in labels:
		var s := str(lab)
		if s == FIRST or s == RETRY or s == VISIT or s == HUB_LABEL:
			continue
		if s.begins_with("继续") or s.find("Continue") >= 0:
			continue
		return s
	return ""


func _do_battle_win(cid: String) -> String:
	var fought := cid.substr(0, 4) + "_mid_fought"
	var lost := cid.substr(0, 4) + "_mid_lost"
	var beat: String = _player.current_beat_id()
	if not _player.simulate_press_action_containing(FIRST):
		return "%s first press" % cid
	await _settle(2)
	var err := _assert_loss_stamp(cid, lost)
	if err != "":
		return err
	err = await _reopen_loss_retry(cid, beat)
	if err != "":
		return err
	BattleVictory.apply(MAP_ID)
	err = _assert_win_flags(cid, fought, lost)
	if err != "":
		return err
	return await _reopen_after_win(cid, beat)


func _assert_loss_stamp(cid: String, lost: String) -> String:
	if str(_player.test_capture.get("scene", "")) != BATTLE:
		return "%s battle launch scene %s" % [cid, str(_player.test_capture.get("scene", ""))]
	var lose_stamped: Array = _player.test_capture.get("battle_lose_flags", [])
	if lose_stamped.is_empty() or str(lose_stamped[0]) != lost:
		return "%s lose_flags %s" % [cid, str(lose_stamped)]
	var back := BattleDefeat.back_path(false, false, StoryCatalog.player_scene())
	if back != StoryCatalog.player_scene():
		return "%s loss back_path %s" % [cid, back]
	if not GameState.flag(lost) or not StoryFlagScope.seen(lost):
		return "%s loss flag not scoped" % cid
	return ""


func _reopen_loss_retry(cid: String, beat: String) -> String:
	_free_player()
	await _settle(2)
	GameState.set_meta("battle_return_chapter", cid)
	var err := await _open_player(cid)
	if err != "":
		return err
	if _player.current_beat_id() != beat:
		return "%s loss resume beat %s" % [cid, _player.current_beat_id()]
	_player.simulate_finish_dialogue()
	await _settle(2)
	if _player.action_labels().find(RETRY) < 0:
		return "%s missing retry after loss %s" % [cid, str(_player.action_labels())]
	if not _player.simulate_press_action_containing(RETRY):
		return "%s retry press" % cid
	await _settle(2)
	return ""


func _assert_win_flags(cid: String, fought: String, lost: String) -> String:
	if not GameState.flag(fought) or GameState.flag(lost):
		return "%s win flags fought=%s lost=%s" % [cid, GameState.flag(fought), GameState.flag(lost)]
	if not StoryFlagScope.seen(fought):
		return "%s win not scoped" % cid
	return ""


func _reopen_after_win(cid: String, beat: String) -> String:
	_free_player()
	await _settle(2)
	var err := await _open_player(cid)
	if err != "":
		return err
	if _player.current_beat_id() != beat:
		return "%s win resume beat %s" % [cid, _player.current_beat_id()]
	_player.simulate_finish_dialogue()
	await _settle(2)
	var labels: Array = _player.action_labels()
	if labels.find(FIRST) >= 0 or labels.find(RETRY) >= 0:
		return "%s battle CTAs stuck after win %s" % [cid, str(labels)]
	if not _press_continue():
		return "%s no continue after win %s" % [cid, str(labels)]
	await _settle(2)
	return ""


func _do_visit(cid: String) -> String:
	var beat: String = _player.current_beat_id()
	if not _player.simulate_press_action_containing(VISIT):
		return "%s visit press" % cid
	await _settle(2)
	if str(_player.test_capture.get("scene", "")) != HOURGLASS:
		return "%s visit scene %s" % [cid, str(_player.test_capture.get("scene", ""))]
	if str(GameState.get_meta("story_return_chapter", "")) != cid:
		return "%s story_return_chapter %s" % [cid, str(GameState.get_meta("story_return_chapter", ""))]
	var back := StoryCatalog.take_story_return("")
	if back != PLAYER:
		return "%s take_story_return %s" % [cid, back]
	_free_player()
	await _settle(2)
	var err := await _open_player(cid)
	if err != "":
		return err
	if _player.current_beat_id() != beat:
		return "%s visit resume want %s got %s" % [cid, beat, _player.current_beat_id()]
	_player.simulate_finish_dialogue()
	await _settle(2)
	if not _press_continue():
		return "%s no continue after visit %s" % [cid, str(_player.action_labels())]
	await _settle(2)
	return ""


func _press_continue() -> bool:
	var labels: Array = _player.action_labels()
	for lab in labels:
		var s := str(lab)
		if s.begins_with("继续") or s.find("Continue") >= 0:
			return _player.simulate_press_action_containing(s)
	## AdvanceLine compact continue
	var adv := _player.find_child("AdvanceLine", true, false) as Button
	if adv != null:
		adv.pressed.emit()
		return true
	return false


func _open_player(cid: String) -> String:
	_free_player()
	StoryCatalog.request_chapter(cid)
	var packed: PackedScene = load(PLAYER)
	_player = packed.instantiate()
	_player.suppress_scene_change = true
	_player.lock_path = false
	_player.chapter_path = ""
	add_child(_player)
	await _settle(4)
	if _player == null:
		return "player null"
	if str(_player._chapter.get("id", "")) != cid:
		return "open want %s got %s" % [cid, str(_player._chapter.get("id", ""))]
	return ""


func _free_player() -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	_player = null
