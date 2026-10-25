extends Node
## Mid-cs battle under hub_open: loss retries via battle_return_chapter;
## win stamps csXX_mid_fought and hides 「先试一锋」 (live press, not simulate-only).

const PLAYER := "res://scenes/story/chapter_player.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const BATTLE_LABEL := "先试一锋"
const MAP_ID := "quest_bandit"
const LIVE := [
	{"cid": "cs01_01", "beat": "hall", "after": "audit"},
	{"cid": "cs08_01", "beat": "bridge", "after": "tavern"},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_battle_retry: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON BATTLE RETRY PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _protocol_loss_retry()
	if err != "":
		return err
	for row in LIVE:
		err = await _live_win_hides_cta(str(row["cid"]), str(row["beat"]), str(row["after"]))
		if err != "":
			return err
		err = await _live_loss_keeps_cta(str(row["cid"]), str(row["beat"]))
		if err != "":
			return err
	return ""


func _flag_for(cid: String) -> String:
	return cid.substr(0, 4) + "_mid_fought"


func _protocol_loss_retry() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	# Bare story return after hub still CASTLE (WS-D #50).
	if BattleDefeat.back_path(false, false, "res://scenes/story/chapter0.tscn") != BattleDefeat.CASTLE:
		return "bare story loss under hub_open must CASTLE"
	GameState.set_meta("battle_return_chapter", "cs03_01")
	GameState.set_meta("battle_map", MAP_ID)
	if BattleDefeat.back_path(false, false, PLAYER) != PLAYER:
		return "chapter-owned loss under hub_open must retry player"
	if not GameState.flag(MAP_ID + "_lost"):
		return "%s_lost not set" % MAP_ID
	print("OK protocol hub_open + battle_return_chapter → retry")
	return ""


func _live_win_hides_cta(cid: String, beat: String, after: String) -> String:
	var flag := _flag_for(cid)
	var pair = await _ready_at_cta(cid, beat)
	if typeof(pair) == TYPE_STRING:
		return str(pair)
	var packed: PackedScene = pair[0]
	var player = pair[1]
	if not player.simulate_press_action_containing(BATTLE_LABEL):
		player.queue_free()
		return "%s win: press failed labels=%s" % [cid, str(player.action_labels())]
	await get_tree().process_frame
	var err := ""
	if str(player.test_capture.get("scene", "")) != BATTLE:
		err = "%s win: scene %s" % [cid, str(player.test_capture.get("scene", ""))]
	elif str(GameState.get_meta("battle_return_chapter", "")) != cid:
		err = "%s win: battle_return_chapter" % cid
	else:
		var stamped: Array = player.test_capture.get("battle_win_flags", [])
		if stamped.size() != 1 or str(stamped[0]) != flag:
			err = "%s win: stamp win_flags %s want %s" % [cid, str(stamped), flag]
		else:
			var sp := BattleVictory.apply(MAP_ID)
			if not GameState.flag(flag):
				err = "%s win: flag %s not set after apply flags=%s" % [cid, flag, str(sp.get("flags", []))]
			elif GameState.get_meta("battle_win_flags", ["x"]).size() != 0:
				err = "%s win: battle_win_flags not consumed" % cid
	player.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	# Reopen at same beat — fight CTA gated off; continue still works.
	GameState.set_meta("battle_return_chapter", cid)
	var player2 = packed.instantiate()
	player2.suppress_scene_change = true
	player2.lock_path = false
	player2.chapter_path = ""
	add_child(player2)
	await get_tree().process_frame
	await get_tree().process_frame
	if player2.current_beat_id() != beat:
		err = "%s win reopen beat %s want %s" % [cid, player2.current_beat_id(), beat]
	else:
		player2.simulate_finish_dialogue()
		await get_tree().process_frame
		await get_tree().process_frame
		var labels: Array = player2.action_labels()
		if labels.find(BATTLE_LABEL) >= 0:
			err = "%s win: fight CTA still shown labels=%s" % [cid, str(labels)]
		elif not player2.simulate_press_action_containing("继续"):
			err = "%s win: continue missing labels=%s" % [cid, str(labels)]
		else:
			await get_tree().process_frame
			await get_tree().process_frame
			if player2.current_beat_id() != after:
				err = "%s win: after continue want %s got %s" % [cid, after, player2.current_beat_id()]
	player2.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK live win hides CTA %s @%s flag=%s → %s" % [cid, beat, flag, after])
	return err


func _live_loss_keeps_cta(cid: String, beat: String) -> String:
	var pair = await _ready_at_cta(cid, beat)
	if typeof(pair) == TYPE_STRING:
		return str(pair)
	var packed: PackedScene = pair[0]
	var player = pair[1]
	if not player.simulate_press_action_containing(BATTLE_LABEL):
		player.queue_free()
		return "%s loss: press failed" % cid
	await get_tree().process_frame
	# hub_open already set in _ready_at_cta; chapter meta stamped by press.
	var back := BattleDefeat.back_path(false, false, StoryCatalog.player_scene())
	var err := ""
	if back != StoryCatalog.player_scene():
		err = "%s loss: back_path %s" % [cid, back]
	player.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	GameState.set_meta("battle_return_chapter", cid)
	var player2 = packed.instantiate()
	player2.suppress_scene_change = true
	player2.lock_path = false
	player2.chapter_path = ""
	add_child(player2)
	await get_tree().process_frame
	await get_tree().process_frame
	if player2.current_beat_id() != beat:
		err = "%s loss reopen beat %s" % [cid, player2.current_beat_id()]
	else:
		player2.simulate_finish_dialogue()
		await get_tree().process_frame
		await get_tree().process_frame
		if player2.action_labels().find(BATTLE_LABEL) < 0:
			err = "%s loss: fight CTA gone labels=%s" % [cid, str(player2.action_labels())]
	player2.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK live loss keeps CTA %s @%s (retry)" % [cid, beat])
	return err


func _ready_at_cta(cid: String, beat: String):
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
		var msg := "%s ready beat want %s got %s" % [cid, beat, player.current_beat_id()]
		player.queue_free()
		await get_tree().process_frame
		return msg
	if player.action_labels().find(BATTLE_LABEL) < 0:
		var msg2 := "%s ready missing CTA labels=%s" % [cid, str(player.action_labels())]
		player.queue_free()
		await get_tree().process_frame
		return msg2
	return [packed, player]
