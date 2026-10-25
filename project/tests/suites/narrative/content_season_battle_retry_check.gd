extends Node
## Mid-cs under hub_open: loss stamps csXX_mid_lost → CTA morphs「再试锋镝」+ loss line;
## win stamps mid_fought + season_ledger/yeartrace for the skirmish itself;
## bare「继续」stamps 未试锋 skip / 试锋未成 abort ledger when leaving without a win;
## win clears csXX_mid_lost + map_id+_lost residue so loss-state cannot resurrect after a retry win;
## chapter-owned mid-cs suppresses month_echo.battle (season_ledger/yeartrace own the trail);
## chapter-owned mid-cs suppresses BattleDefeat.record (no castle event_log「败北」);
## chapter-owned mid-cs suppresses CKEnemyLoadout.apply_defeat sticky injury.

const PLAYER := "res://scenes/story/chapter_player.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const FIRST_LABEL := "先试一锋"
const RETRY_LABEL := "再试锋镝"
const MAP_ID := "quest_bandit"
const LIVE := [
	{"cid": "cs01_01", "beat": "hall", "after": "audit", "loss_needle": "锋收回来"},
	{"cid": "cs03_01", "beat": "bridge", "after": "tavern", "loss_needle": "锋收回来"},
	{"cid": "cs05_01", "beat": "bridge", "after": "tavern", "loss_needle": "锋收回来"},
	{"cid": "cs08_01", "beat": "bridge", "after": "tavern", "loss_needle": "锋收回来"},
	{"cid": "cs10_01", "beat": "bridge", "after": "tavern", "loss_needle": "锋收回来"},
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
	var err := _protocol_loss_flags()
	if err != "":
		return err
	err = _protocol_win_clears_lost()
	if err != "":
		return err
	err = _protocol_month_echo_suppressed()
	if err != "":
		return err
	err = _protocol_defeat_record_suppressed()
	if err != "":
		return err
	err = _protocol_defeat_injury_suppressed()
	if err != "":
		return err
	for row in LIVE:
		err = await _live_win_ledger_and_hide(
			str(row["cid"]), str(row["beat"]), str(row["after"]))
		if err != "":
			return err
		err = await _live_loss_morph(
			str(row["cid"]), str(row["beat"]), str(row["loss_needle"]))
		if err != "":
			return err
		err = await _live_skip_ledger(
			str(row["cid"]), str(row["beat"]), str(row["after"]))
		if err != "":
			return err
		err = await _live_abort_ledger(
			str(row["cid"]), str(row["beat"]), str(row["after"]))
		if err != "":
			return err
		err = await _live_loss_then_win_clears_lost(
			str(row["cid"]), str(row["beat"]))
		if err != "":
			return err
	return ""


func _fought(cid: String) -> String:
	return cid.substr(0, 4) + "_mid_fought"


func _lost(cid: String) -> String:
	return cid.substr(0, 4) + "_mid_lost"


func _protocol_loss_flags() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	if BattleDefeat.back_path(false, false, "res://scenes/story/chapter0.tscn") != BattleDefeat.CASTLE:
		return "bare story loss under hub_open must CASTLE"
	GameState.set_meta("battle_return_chapter", "cs03_01")
	GameState.set_meta("battle_map", MAP_ID)
	GameState.set_meta("battle_lose_flags", ["cs03_mid_lost"])
	if BattleDefeat.back_path(false, false, PLAYER) != PLAYER:
		return "chapter-owned loss under hub_open must retry player"
	if not GameState.flag(MAP_ID + "_lost"):
		return "%s_lost not set" % MAP_ID
	if not GameState.flag("cs03_mid_lost"):
		return "cs03_mid_lost not applied from battle_lose_flags"
	if GameState.get_meta("battle_lose_flags", ["x"]).size() != 0:
		return "battle_lose_flags not consumed"
	print("OK protocol lose_flags → csXX_mid_lost + map_lost")
	return ""


func _live_win_ledger_and_hide(cid: String, beat: String, after: String) -> String:
	var fought := _fought(cid)
	var pair = await _ready_at_cta(cid, beat, FIRST_LABEL)
	if typeof(pair) == TYPE_STRING:
		return str(pair)
	var packed: PackedScene = pair[0]
	var player = pair[1]
	if not player.simulate_press_action_containing(FIRST_LABEL):
		player.queue_free()
		return "%s win: press failed labels=%s" % [cid, str(player.action_labels())]
	await get_tree().process_frame
	var err := ""
	if str(player.test_capture.get("scene", "")) != BATTLE:
		err = "%s win: scene %s" % [cid, str(player.test_capture.get("scene", ""))]
	else:
		var stamped: Array = player.test_capture.get("battle_win_flags", [])
		if stamped.size() != 1 or str(stamped[0]) != fought:
			err = "%s win: win_flags %s" % [cid, str(stamped)]
		else:
			var led_cap: Dictionary = player.test_capture.get("battle_win_ledger", {})
			if str(led_cap.get("choice", "")) != "mid_skirmish":
				err = "%s win: stamp win_ledger %s" % [cid, str(led_cap)]
			else:
				BattleVictory.apply(MAP_ID)
				if not GameState.flag(fought):
					err = "%s win: flag %s missing" % [cid, fought]
				else:
					var found: Dictionary = CKSuiKe.season_ledger_find(cid, "mid_skirmish")
					if found.is_empty():
						err = "%s win: season_ledger mid_skirmish missing" % cid
					elif str(found.get("outcome", "")).find("试锋得手") < 0:
						err = "%s win: ledger outcome %s" % [cid, str(found.get("outcome", ""))]
					else:
						var yt := false
						for row in CKSuiKe.yeartrace():
							if str(row.get("id", "")) == "%s:mid_skirmish" % cid:
								yt = true
								break
						if not yt:
							err = "%s win: yeartrace mid_skirmish missing" % cid
						elif GameState.get_meta("battle_win_ledger", {"x": 1}).size() != 0:
							err = "%s win: battle_win_ledger not consumed" % cid
						else:
							GameState.house_mods.erase("month_echo")
							# Chapter leave still owns battle_return_chapter — must not phantom month_echo.
							if BattleVictory.maybe_note_month_echo_battle(true, "山匪", 40, false, false):
								err = "%s win: month_echo.battle written under chapter" % cid
							elif str(CKEconomyState.month_echo_snapshot().get("battle", "")) != "":
								err = "%s win: month_echo.battle residue" % cid
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
		err = "%s win reopen beat %s" % [cid, player2.current_beat_id()]
	else:
		player2.simulate_finish_dialogue()
		await get_tree().process_frame
		await get_tree().process_frame
		var labels: Array = player2.action_labels()
		if labels.find(FIRST_LABEL) >= 0 or labels.find(RETRY_LABEL) >= 0:
			err = "%s win: fight CTA still shown labels=%s" % [cid, str(labels)]
		elif not player2.simulate_press_action_containing("继续"):
			err = "%s win: continue missing labels=%s" % [cid, str(labels)]
		else:
			await get_tree().process_frame
			await get_tree().process_frame
			if player2.current_beat_id() != after:
				err = "%s win: after continue want %s got %s" % [cid, after, player2.current_beat_id()]
			elif not CKSuiKe.season_ledger_find(cid, "mid_skirmish_skip").is_empty():
				err = "%s win: continue wrote skip ledger after fight" % cid
			elif not CKSuiKe.season_ledger_find(cid, "mid_skirmish_abort").is_empty():
				err = "%s win: continue wrote abort ledger after fight" % cid
	player2.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK live win ledger+hide+no-month_echo %s @%s → %s" % [cid, beat, after])
	return err


func _live_loss_morph(cid: String, beat: String, needle: String) -> String:
	var lost := _lost(cid)
	var pair = await _ready_at_cta(cid, beat, FIRST_LABEL)
	if typeof(pair) == TYPE_STRING:
		return str(pair)
	var packed: PackedScene = pair[0]
	var player = pair[1]
	if not player.simulate_press_action_containing(FIRST_LABEL):
		player.queue_free()
		return "%s loss: press failed" % cid
	await get_tree().process_frame
	var lose_stamped: Array = player.test_capture.get("battle_lose_flags", [])
	var err := ""
	if lose_stamped.size() != 1 or str(lose_stamped[0]) != lost:
		err = "%s loss: stamp lose_flags %s want %s" % [cid, str(lose_stamped), lost]
	else:
		var back := BattleDefeat.back_path(false, false, StoryCatalog.player_scene())
		if back != StoryCatalog.player_scene():
			err = "%s loss: back_path %s" % [cid, back]
		elif not GameState.flag(lost):
			err = "%s loss: %s not set" % [cid, lost]
		elif not GameState.flag(MAP_ID + "_lost"):
			err = "%s loss: quest_bandit_lost not set" % cid
		else:
			# Protocol hub write may leave META; clear so we only catch a fresh write.
			if GameState.has_meta(BattleDefeat.META):
				GameState.remove_meta(BattleDefeat.META)
			var before_log := GameState.event_log.size()
			if BattleDefeat.maybe_record([], "lose") != "":
				err = "%s loss: castle record not suppressed" % cid
			elif str(GameState.get_meta(BattleDefeat.META, "")) != "":
				err = "%s loss: defeat META written under chapter" % cid
			elif GameState.event_log.size() != before_log:
				err = "%s loss: event_log grew under chapter" % cid
			else:
				var probe := CKCharacter.new()
				probe.job_id = "light_inf"
				probe.level = 1
				probe.stats = {"str": 10, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
				probe.hp = 5
				probe.max_hp = 40
				probe.injured = false
				var units := [{"char": probe, "team": "player"}]
				if CKEnemyLoadout.maybe_apply_defeat(units, "standard"):
					err = "%s loss: defeat injury not suppressed" % cid
				elif probe.injured:
					err = "%s loss: injured stamped under chapter" % cid
				elif probe.hp != probe.max_hp:
					err = "%s loss: chapter injury gate hp %s" % [cid, probe.hp]
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
		# Loss line is last visible — skip to end so body shows it.
		player2.skip_lines()
		await get_tree().process_frame
		var body := str(player2._body.text)
		if body.find(needle) < 0:
			err = "%s loss: body missing needle %s got %s" % [cid, needle, body]
		else:
			player2.simulate_finish_dialogue()
			await get_tree().process_frame
			await get_tree().process_frame
			var labels: Array = player2.action_labels()
			if labels.find(RETRY_LABEL) < 0:
				err = "%s loss: retry CTA missing labels=%s" % [cid, str(labels)]
			elif labels.find(FIRST_LABEL) >= 0:
				err = "%s loss: first CTA still shown labels=%s" % [cid, str(labels)]
	player2.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK live loss morph+no-castle-record+no-injury %s @%s → %s + line" % [cid, beat, RETRY_LABEL])
	return err



func _live_skip_ledger(cid: String, beat: String, after: String) -> String:
	var fought := _fought(cid)
	var pair = await _ready_at_cta(cid, beat, FIRST_LABEL)
	if typeof(pair) == TYPE_STRING:
		return str(pair)
	var player = pair[1]
	var err := ""
	if not player.simulate_press_action_containing("继续"):
		err = "%s skip: continue missing labels=%s" % [cid, str(player.action_labels())]
	else:
		await get_tree().process_frame
		await get_tree().process_frame
		if player.current_beat_id() != after:
			err = "%s skip: want %s got %s" % [cid, after, player.current_beat_id()]
		elif GameState.flag(fought):
			err = "%s skip: mid_fought set without fight" % cid
		else:
			err = _assert_choice_ledger(cid, "mid_skirmish_skip", "未试锋")
			if err == "" and not CKSuiKe.season_ledger_find(cid, "mid_skirmish_abort").is_empty():
				err = "%s skip: abort ledger also written" % cid
	player.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK live skip 未试锋 %s @%s → %s" % [cid, beat, after])
	return err


func _live_abort_ledger(cid: String, beat: String, after: String) -> String:
	var lost := _lost(cid)
	var fought := _fought(cid)
	var pair = await _ready_at_cta(cid, beat, FIRST_LABEL)
	if typeof(pair) == TYPE_STRING:
		return str(pair)
	var packed: PackedScene = pair[0]
	var player = pair[1]
	if not player.simulate_press_action_containing(FIRST_LABEL):
		player.queue_free()
		return "%s abort: press fight failed" % cid
	await get_tree().process_frame
	var err := ""
	BattleDefeat.back_path(false, false, StoryCatalog.player_scene())
	if not GameState.flag(lost):
		err = "%s abort: %s not set" % [cid, lost]
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
	player2.simulate_finish_dialogue()
	await get_tree().process_frame
	await get_tree().process_frame
	if player2.action_labels().find(RETRY_LABEL) < 0:
		err = "%s abort: retry CTA missing labels=%s" % [cid, str(player2.action_labels())]
	elif not player2.simulate_press_action_containing("继续"):
		err = "%s abort: continue missing labels=%s" % [cid, str(player2.action_labels())]
	else:
		await get_tree().process_frame
		await get_tree().process_frame
		if player2.current_beat_id() != after:
			err = "%s abort: want %s got %s" % [cid, after, player2.current_beat_id()]
		elif GameState.flag(fought):
			err = "%s abort: mid_fought set on loss leave" % cid
		else:
			err = _assert_choice_ledger(cid, "mid_skirmish_abort", "试锋未成")
			if err == "" and not CKSuiKe.season_ledger_find(cid, "mid_skirmish_skip").is_empty():
				err = "%s abort: skip ledger also written" % cid
	player2.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK live abort 试锋未成 %s @%s → %s" % [cid, beat, after])
	return err


func _assert_choice_ledger(cid: String, choice: String, needle: String) -> String:
	var found: Dictionary = CKSuiKe.season_ledger_find(cid, choice)
	if found.is_empty():
		return "%s: season_ledger %s missing" % [cid, choice]
	if str(found.get("outcome", "")).find(needle) < 0:
		return "%s: ledger %s outcome %s" % [cid, choice, str(found.get("outcome", ""))]
	var yt := false
	var want_id := "%s:%s" % [cid, choice]
	for row in CKSuiKe.yeartrace():
		if str(row.get("id", "")) == want_id:
			yt = true
			break
	if not yt:
		return "%s: yeartrace %s missing" % [cid, choice]
	return ""



func _protocol_win_clears_lost() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	GameState.set_flag("cs03_mid_lost")
	GameState.set_flag(MAP_ID + "_lost")
	GameState.set_meta("battle_win_flags", ["cs03_mid_fought"])
	GameState.set_meta("battle_lose_flags", ["cs03_mid_lost"])
	GameState.set_meta("battle_win_ledger", {})
	BattleVictory.apply(MAP_ID)
	if not GameState.flag("cs03_mid_fought"):
		return "protocol win: mid_fought missing"
	if GameState.flag("cs03_mid_lost"):
		return "protocol win: mid_lost residue still set"
	if GameState.flag(MAP_ID + "_lost"):
		return "protocol win: map_lost residue still set"
	if GameState.get_meta("battle_lose_flags", ["x"]).size() != 0:
		return "protocol win: battle_lose_flags meta not consumed"
	print("OK protocol win clears mid_lost + map_lost residue")
	return ""



func _protocol_month_echo_suppressed() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	GameState.house_mods.erase("month_echo")
	GameState.set_meta("battle_return_chapter", "")
	GameState.set_meta("battle_win_ledger", {})
	# Hub / bare map fight still writes month_echo.battle.
	if not BattleVictory.maybe_note_month_echo_battle(true, "山匪", 40, false, false):
		return "protocol echo: hub win should write"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("battle", "")) == "":
		return "protocol echo: hub win line missing %s" % str(snap)
	GameState.house_mods.erase("month_echo")
	# Chapter-owned via battle_return_chapter — suppress.
	GameState.set_meta("battle_return_chapter", "cs03_01")
	if BattleVictory.maybe_note_month_echo_battle(true, "山匪", 40, false, false):
		return "protocol echo: chapter win should suppress"
	if BattleVictory.maybe_note_month_echo_battle(false, "山匪", 0, false, false):
		return "protocol echo: chapter lose should suppress"
	snap = CKEconomyState.month_echo_snapshot()
	if str(snap.get("battle", "")) != "":
		return "protocol echo: chapter left battle residue %s" % str(snap)
	GameState.set_meta("battle_return_chapter", "")
	GameState.house_mods.erase("month_echo")
	# Chapter-owned via non-empty battle_win_ledger alone — suppress.
	GameState.set_meta("battle_win_ledger", {
		"chapter": "cs03_01", "choice": "mid_skirmish",
		"title": "试锋", "outcome": "试锋得手",
	})
	if BattleVictory.maybe_note_month_echo_battle(true, "山匪", 40, false, false):
		return "protocol echo: ledger win should suppress"
	if BattleVictory.maybe_note_month_echo_battle(false, "山匪", 0, false, false):
		return "protocol echo: ledger lose should suppress"
	snap = CKEconomyState.month_echo_snapshot()
	if str(snap.get("battle", "")) != "":
		return "protocol echo: ledger left battle residue %s" % str(snap)
	GameState.set_meta("battle_win_ledger", {})
	print("OK protocol mid-cs suppresses month_echo.battle")
	return ""



func _protocol_defeat_record_suppressed() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	GameState.set_meta("battle_return_chapter", "cs03_01")
	if GameState.has_meta(BattleDefeat.META):
		GameState.remove_meta(BattleDefeat.META)
	var before := GameState.event_log.size()
	if BattleDefeat.maybe_record([], "lose") != "":
		return "protocol record: chapter should suppress"
	if str(GameState.get_meta(BattleDefeat.META, "")) != "":
		return "protocol record: chapter wrote META"
	if GameState.event_log.size() != before:
		return "protocol record: chapter grew event_log"
	GameState.set_meta("battle_return_chapter", "")
	var text := BattleDefeat.maybe_record([], "lose")
	if text == "" or not text.begins_with(Locale.t("defeat_head")):
		return "protocol record: hub should write got %s" % text
	print("OK protocol mid-cs suppresses castle defeat record")
	return ""


func _protocol_defeat_injury_suppressed() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	GameState.set_meta("battle_return_chapter", "cs03_01")
	var c := CKCharacter.new()
	c.job_id = "light_inf"
	c.level = 1
	c.stats = {"str": 10, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	c.hp = 5
	c.max_hp = 40
	c.injured = false
	var units := [{"char": c, "team": "player"}]
	if not CKEnemyLoadout.suppresses_defeat_injury():
		return "protocol injury: suppresses_defeat_injury false"
	if CKEnemyLoadout.maybe_apply_defeat(units, "standard"):
		return "protocol injury: chapter should suppress"
	if c.injured:
		return "protocol injury: chapter stamped injured"
	if c.hp != c.max_hp:
		return "protocol injury: chapter hp %s" % c.hp
	GameState.set_meta("battle_return_chapter", "")
	c.hp = 5
	c.injured = false
	if not CKEnemyLoadout.maybe_apply_defeat(units, "standard"):
		return "protocol injury: hub should apply"
	if not c.injured or c.hp != maxi(1, int(c.max_hp * 0.3)):
		return "protocol injury: hub injury missing"
	print("OK protocol mid-cs suppresses defeat injury")
	return ""


func _live_loss_then_win_clears_lost(cid: String, beat: String) -> String:
	var lost := _lost(cid)
	var fought := _fought(cid)
	var pair = await _ready_at_cta(cid, beat, FIRST_LABEL)
	if typeof(pair) == TYPE_STRING:
		return str(pair)
	var packed: PackedScene = pair[0]
	var player = pair[1]
	if not player.simulate_press_action_containing(FIRST_LABEL):
		player.queue_free()
		return "%s clear: first press failed" % cid
	await get_tree().process_frame
	BattleDefeat.back_path(false, false, StoryCatalog.player_scene())
	var err := ""
	if not GameState.flag(lost):
		err = "%s clear: %s not set after loss" % [cid, lost]
	elif not GameState.flag(MAP_ID + "_lost"):
		err = "%s clear: map_lost not set after loss" % cid
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
	player2.simulate_finish_dialogue()
	await get_tree().process_frame
	await get_tree().process_frame
	if player2.action_labels().find(RETRY_LABEL) < 0:
		err = "%s clear: retry CTA missing labels=%s" % [cid, str(player2.action_labels())]
	elif not player2.simulate_press_action_containing(RETRY_LABEL):
		err = "%s clear: retry press failed" % cid
	else:
		await get_tree().process_frame
		var lose_stamped: Array = player2.test_capture.get("battle_lose_flags", [])
		if lose_stamped.size() != 1 or str(lose_stamped[0]) != lost:
			err = "%s clear: retry stamp lose_flags %s" % [cid, str(lose_stamped)]
		else:
			BattleVictory.apply(MAP_ID)
			if not GameState.flag(fought):
				err = "%s clear: mid_fought missing after win" % cid
			elif GameState.flag(lost):
				err = "%s clear: mid_lost residue after win" % cid
			elif GameState.flag(MAP_ID + "_lost"):
				err = "%s clear: map_lost residue after win" % cid
	player2.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	GameState.set_meta("battle_return_chapter", cid)
	var player3 = packed.instantiate()
	player3.suppress_scene_change = true
	player3.lock_path = false
	player3.chapter_path = ""
	add_child(player3)
	await get_tree().process_frame
	await get_tree().process_frame
	if player3.current_beat_id() != beat:
		err = "%s clear reopen beat %s" % [cid, player3.current_beat_id()]
	else:
		player3.skip_lines()
		await get_tree().process_frame
		var body := str(player3._body.text)
		if body.find("锋收回来") >= 0:
			err = "%s clear: loss line still shown after win body=%s" % [cid, body]
		else:
			player3.simulate_finish_dialogue()
			await get_tree().process_frame
			await get_tree().process_frame
			var labels: Array = player3.action_labels()
			if labels.find(FIRST_LABEL) >= 0 or labels.find(RETRY_LABEL) >= 0:
				err = "%s clear: fight CTA after win labels=%s" % [cid, str(labels)]
	player3.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK live loss→win clears mid_lost+map_lost %s @%s" % [cid, beat])
	return err


func _ready_at_cta(cid: String, beat: String, want_label: String):
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
	if player.action_labels().find(want_label) < 0:
		var msg2 := "%s ready missing %s labels=%s" % [cid, want_label, str(player.action_labels())]
		player.queue_free()
		await get_tree().process_frame
		return msg2
	return [packed, player]
