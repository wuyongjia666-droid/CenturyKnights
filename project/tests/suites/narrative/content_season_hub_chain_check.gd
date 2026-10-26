extends Node
## Hub → 内容季章 → 中途战/据点 visit → 回章：抽样真链路 E2E（禁 EmptyHost）。
## S01–S10 _01 全链路 + _02 抽样（cs01/05/08/10_02）：hub→章→战/访→回。静态度交 hub_entry /
## battle_retry / visit_authored。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const HOURGLASS := "res://scenes/hub/hourglass.tscn"
const FIRST_LABEL := "先试一锋"
const RETRY_LABEL := "再试锋镝"
const VISIT_LABEL := "去看月份怎么往前走"
const MAP_ID := "quest_bandit"
const LOSS_NEEDLE := "锋收回来"

const CHAINS := [
	{
		"cid": "cs01_01",
		"order": "battle_then_visit",
		"mid": "hall",
		"after_mid": "audit",
		"visit": "audit",
		"after_visit": "tavern",
	},
	{
		"cid": "cs02_01",
		"order": "visit_then_battle",
		"mid": "estate",
		"after_mid": "birth",
		"visit": "birth",
		"after_visit": "tavern",
	},
	{
		"cid": "cs03_01",
		"order": "battle_then_visit",
		"mid": "bridge",
		"after_mid": "tavern",
		"visit": "hourglass",
		"after_visit": "bridge",
	},
	{
		"cid": "cs04_01",
		"order": "visit_then_battle",
		"mid": "bridge",
		"after_mid": "tavern",
		"visit": "hourglass",
		"after_visit": "bridge",
	},
	{
		"cid": "cs05_01",
		"order": "battle_then_visit",
		"mid": "bridge",
		"after_mid": "tavern",
		"visit": "hourglass",
		"after_visit": "bridge",
	},
	{
		"cid": "cs06_01",
		"order": "visit_then_battle",
		"mid": "bridge",
		"after_mid": "tavern",
		"visit": "hourglass",
		"after_visit": "bridge",
	},
	{
		"cid": "cs07_01",
		"order": "battle_then_visit",
		"mid": "bridge",
		"after_mid": "tavern",
		"visit": "hourglass",
		"after_visit": "bridge",
	},
	{
		"cid": "cs08_01",
		"order": "visit_then_battle",
		"mid": "bridge",
		"after_mid": "tavern",
		"visit": "hourglass",
		"after_visit": "bridge",
	},
	{
		"cid": "cs09_01",
		"order": "battle_then_visit",
		"mid": "bridge",
		"after_mid": "tavern",
		"visit": "hourglass",
		"after_visit": "bridge",
	},
	{
		"cid": "cs10_01",
		"order": "visit_then_battle",
		"mid": "bridge",
		"after_mid": "tavern",
		"visit": "hourglass",
		"after_visit": "bridge",
	},
	{
		"cid": "cs01_02",
		"order": "battle_then_visit",
		"mid": "bridge",
		"after_mid": "tavern",
		"visit": "hourglass",
		"after_visit": "bridge",
	},
	{
		"cid": "cs05_02",
		"order": "visit_then_battle",
		"mid": "bridge",
		"after_mid": "tavern",
		"visit": "hourglass",
		"after_visit": "bridge",
	},
	{
		"cid": "cs08_02",
		"order": "battle_then_visit",
		"mid": "bridge",
		"after_mid": "tavern",
		"visit": "hourglass",
		"after_visit": "bridge",
	},
	{
		"cid": "cs10_02",
		"order": "visit_then_battle",
		"mid": "bridge",
		"after_mid": "tavern",
		"visit": "hourglass",
		"after_visit": "bridge",
	},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_hub_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON HUB CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := await _hub_chips_and_returns()
	if err != "":
		return err
	for row in CHAINS:
		err = await _chain_one(row)
		if err != "":
			return err
	return ""


func _hub_chips_and_returns() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
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
	for row in CHAINS:
		var cid := str(row["cid"])
		if hub.find_child("Season_%s" % cid, true, false) == null:
			hub.queue_free()
			await get_tree().process_frame
			return "hub chip %s missing" % cid
		if StoryCatalog.request_chapter(cid) != StoryCatalog.player_scene():
			hub.queue_free()
			await get_tree().process_frame
			return "request_chapter %s" % cid
		if str(GameState.get_meta("story_chapter_id", "")) != cid:
			hub.queue_free()
			await get_tree().process_frame
			return "meta story_chapter_id %s" % cid
		var path := "res://data/story/chapters/%s.json" % cid
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(data) != TYPE_DICTIONARY:
			hub.queue_free()
			await get_tree().process_frame
			return "parse %s" % cid
		if str(data.get("return_scene", "")) != HUB:
			hub.queue_free()
			await get_tree().process_frame
			return "return_scene %s want hub" % cid
	hub.queue_free()
	await get_tree().process_frame
	print("OK hub chips + return_scene ×%d" % CHAINS.size())
	return ""


func _chain_one(row: Dictionary) -> String:
	var cid := str(row["cid"])
	var err := ""
	if str(row["order"]) == "battle_then_visit":
		err = await _battle_loss_then_win(cid, str(row["mid"]), str(row["after_mid"]))
		if err != "":
			return err
		err = await _visit_roundtrip(cid, str(row["visit"]), str(row["after_visit"]))
		if err != "":
			return err
	else:
		err = await _visit_roundtrip(cid, str(row["visit"]), str(row["after_visit"]))
		if err != "":
			return err
		err = await _battle_loss_then_win(cid, str(row["mid"]), str(row["after_mid"]))
		if err != "":
			return err
	print("OK hub-chain %s (%s)" % [cid, str(row["order"])])
	return ""


func _fought(cid: String) -> String:
	return cid.substr(0, 4) + "_mid_fought"


func _lost(cid: String) -> String:
	return cid.substr(0, 4) + "_mid_lost"


func _open_at(cid: String, beat: String, want_label: String):
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	StoryCatalog.request_chapter(cid)
	var packed: PackedScene = load(PLAYER)
	var player = packed.instantiate()
	player.suppress_scene_change = true
	player.lock_path = false
	player.chapter_path = ""
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	player.simulate_goto_beat(beat)
	await get_tree().process_frame
	player.simulate_finish_dialogue()
	await get_tree().process_frame
	await get_tree().process_frame
	if player.current_beat_id() != beat:
		var msg := "%s open beat want %s got %s" % [cid, beat, player.current_beat_id()]
		player.queue_free()
		await get_tree().process_frame
		return msg
	if player.action_labels().find(want_label) < 0:
		var msg2 := "%s open missing %s labels=%s" % [cid, want_label, str(player.action_labels())]
		player.queue_free()
		await get_tree().process_frame
		return msg2
	return [packed, player]


func _battle_loss_then_win(cid: String, mid: String, after: String) -> String:
	var lost := _lost(cid)
	var fought := _fought(cid)
	var pair = await _open_at(cid, mid, FIRST_LABEL)
	if typeof(pair) == TYPE_STRING:
		return str(pair)
	var packed: PackedScene = pair[0]
	var player = pair[1]
	if not player.simulate_press_action_containing(FIRST_LABEL):
		player.queue_free()
		await get_tree().process_frame
		return "%s battle press failed" % cid
	await get_tree().process_frame
	var err := ""
	var lose_stamped: Array = player.test_capture.get("battle_lose_flags", [])
	if str(player.test_capture.get("scene", "")) != BATTLE:
		err = "%s battle scene %s" % [cid, str(player.test_capture.get("scene", ""))]
	elif lose_stamped.size() != 1 or str(lose_stamped[0]) != lost:
		err = "%s lose_flags %s want %s" % [cid, str(lose_stamped), lost]
	else:
		var back := BattleDefeat.back_path(false, false, StoryCatalog.player_scene())
		if back != StoryCatalog.player_scene():
			err = "%s loss back_path %s" % [cid, back]
		elif not GameState.flag(lost):
			err = "%s loss flag %s missing" % [cid, lost]
	player.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	# Reopen: needle last + retry CTA.
	GameState.set_meta("battle_return_chapter", cid)
	var p2 = packed.instantiate()
	p2.suppress_scene_change = true
	p2.lock_path = false
	p2.chapter_path = ""
	add_child(p2)
	await get_tree().process_frame
	await get_tree().process_frame
	if p2.current_beat_id() != mid:
		err = "%s loss reopen beat %s" % [cid, p2.current_beat_id()]
	else:
		p2.skip_lines()
		await get_tree().process_frame
		if str(p2._body.text).find(LOSS_NEEDLE) < 0:
			err = "%s loss needle missing got %s" % [cid, str(p2._body.text)]
		else:
			p2.simulate_finish_dialogue()
			await get_tree().process_frame
			await get_tree().process_frame
			if p2.action_labels().find(RETRY_LABEL) < 0:
				err = "%s retry CTA missing %s" % [cid, str(p2.action_labels())]
			elif not p2.simulate_press_action_containing(RETRY_LABEL):
				err = "%s retry press failed" % cid
			else:
				await get_tree().process_frame
				BattleVictory.apply(MAP_ID)
				if not GameState.flag(fought):
					err = "%s win flag missing" % cid
				elif GameState.flag(lost):
					err = "%s mid_lost residue after win" % cid
				elif GameState.flag(MAP_ID + "_lost"):
					err = "%s map_lost residue after win" % cid
	p2.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	# Continue after win.
	GameState.set_meta("battle_return_chapter", cid)
	var p3 = packed.instantiate()
	p3.suppress_scene_change = true
	p3.lock_path = false
	p3.chapter_path = ""
	add_child(p3)
	await get_tree().process_frame
	await get_tree().process_frame
	p3.simulate_goto_beat(mid)
	await get_tree().process_frame
	p3.simulate_finish_dialogue()
	await get_tree().process_frame
	await get_tree().process_frame
	var labels: Array = p3.action_labels()
	if labels.find(FIRST_LABEL) >= 0 or labels.find(RETRY_LABEL) >= 0:
		err = "%s after-win battle CTA still shown %s" % [cid, str(labels)]
	elif not p3.simulate_press_action_containing("继续"):
		err = "%s after-win continue missing %s" % [cid, str(labels)]
	else:
		await get_tree().process_frame
		await get_tree().process_frame
		if p3.current_beat_id() != after:
			err = "%s after-win want %s got %s" % [cid, after, p3.current_beat_id()]
	p3.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK chain battle loss→win %s @%s → %s" % [cid, mid, after])
	return err


func _visit_roundtrip(cid: String, visit_beat: String, after: String) -> String:
	var pair = await _open_at(cid, visit_beat, VISIT_LABEL)
	if typeof(pair) == TYPE_STRING:
		return str(pair)
	var packed: PackedScene = pair[0]
	var player = pair[1]
	var err := ""
	if not player.simulate_press_action_containing(VISIT_LABEL):
		err = "%s visit press failed %s" % [cid, str(player.action_labels())]
	else:
		await get_tree().process_frame
		if str(player.test_capture.get("scene", "")) != HOURGLASS:
			err = "%s visit scene want hourglass got %s" % [cid, str(player.test_capture.get("scene", ""))]
		elif str(GameState.get_meta("story_return_chapter", "")) != cid:
			err = "%s story_return_chapter want %s got %s" % [
				cid, cid, str(GameState.get_meta("story_return_chapter", ""))]
		elif str(GameState.get_meta("story_return", "")) != StoryCatalog.player_scene():
			err = "%s story_return must be player got %s" % [
				cid, str(GameState.get_meta("story_return", ""))]
		else:
			var ret := StoryCatalog.take_story_return(HUB)
			if ret != StoryCatalog.player_scene():
				err = "%s take want player got %s" % [cid, ret]
			elif str(GameState.get_meta("story_chapter_id", "")) != cid:
				err = "%s story_chapter_id not restored" % cid
			elif GameState.story.season_beat(cid) != visit_beat:
				err = "%s season cursor lost after take (got %s)" % [
					cid, GameState.story.season_beat(cid)]
	player.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	var p2 = packed.instantiate()
	p2.suppress_scene_change = true
	p2.lock_path = false
	p2.chapter_path = ""
	add_child(p2)
	await get_tree().process_frame
	await get_tree().process_frame
	if p2.current_beat_id() != visit_beat:
		err = "%s visit reopen want %s got %s" % [cid, visit_beat, p2.current_beat_id()]
	else:
		p2.simulate_finish_dialogue()
		await get_tree().process_frame
		await get_tree().process_frame
		if not p2.simulate_press_action_containing("继续"):
			err = "%s visit-continue missing %s" % [cid, str(p2.action_labels())]
		else:
			await get_tree().process_frame
			await get_tree().process_frame
			if p2.current_beat_id() != after:
				err = "%s visit-continue want %s got %s" % [cid, after, p2.current_beat_id()]
	p2.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK chain visit %s @%s → %s" % [cid, visit_beat, after])
	return err
