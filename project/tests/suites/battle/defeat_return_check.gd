extends Node
## WS-D #50/#5: defeat and retreat go back to the castle (never chapter 0) with an injury settlement;
## chapter-owned mid-cs suppresses BattleDefeat.record (no castle event_log「败北」).

var _battle


func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL defeat_return: ", err)
		get_tree().quit(1)
		return
	print("DEFEAT_RETURN PASS")
	get_tree().quit(0)


func _run() -> String:
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	GameState.set_flag("hub_open")
	var err := _protocol_back_paths()
	if err != "":
		return err
	err = _protocol_castle_record_gate()
	if err != "":
		return err
	if BattleDefeat.back_path(true, false, "res://scenes/story/chapter0.tscn") != "res://scenes/story/chapter0.tscn":
		return "story win lost its return"
	if BattleDefeat.back_path(true, false, "") != BattleDefeat.CASTLE:
		return "win with no return"
	return await _live_retreat()


func _protocol_back_paths() -> String:
	if BattleDefeat.back_path(false, false, "res://scenes/story/chapter0.tscn") != BattleDefeat.CASTLE:
		return "story defeat after hub_open still returns to chapter"
	# Mid-cs / era: battle_return_chapter means the chapter owns the fight — retry on loss
	# even after hub_open (content seasons run with hub already open).
	GameState.set_meta("battle_return_chapter", "cs01_01")
	GameState.set_meta("battle_map", "quest_bandit")
	GameState.set_meta("battle_lose_flags", ["cs01_mid_lost"])
	var player := "res://scenes/story/chapter_player.tscn"
	if BattleDefeat.back_path(false, false, player) != player:
		return "hub_open + battle_return_chapter loss must retry chapter"
	if not GameState.flag("quest_bandit_lost"):
		return "quest_bandit_lost not written on chapter retry"
	if not GameState.flag("cs01_mid_lost"):
		return "cs01_mid_lost not applied from battle_lose_flags"
	return ""


func _protocol_castle_record_gate() -> String:
	# Chapter-owned: maybe_record must not write META / event_log.
	var before_log := GameState.event_log.size()
	var skipped := BattleDefeat.maybe_record([], "lose")
	if skipped != "":
		return "chapter maybe_record should return empty got %s" % skipped
	if str(GameState.get_meta(BattleDefeat.META, "")) != "":
		return "chapter maybe_record wrote META"
	if GameState.event_log.size() != before_log:
		return "chapter maybe_record grew event_log"
	print("OK protocol chapter suppresses castle defeat record")
	GameState.set_meta("battle_return_chapter", "")
	if GameState.has_meta(BattleDefeat.META):
		GameState.remove_meta(BattleDefeat.META)
	var hub_text := BattleDefeat.maybe_record([], "lose")
	if hub_text == "" or not hub_text.begins_with(Locale.t("defeat_head")):
		return "hub maybe_record missing defeat_head got %s" % hub_text
	if str(GameState.get_meta(BattleDefeat.META, "")) != hub_text:
		return "hub maybe_record META mismatch"
	var hit := false
	for row in GameState.event_log:
		if str(row).find(Locale.t("defeat_head")) >= 0:
			hit = true
			break
	if not hit:
		return "hub maybe_record missing from event_log"
	print("OK protocol hub still records castle defeat")
	return ""


func _live_retreat() -> String:
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	GameState.set_flag("hub_open")
	GameState.set_meta("cutscenes_on", false)
	GameState.settings["cutscenes"] = false
	GameState.set_meta("battle_return", "res://scenes/story/chapter0.tscn")
	GameState.set_meta("battle_map", "obj_rout")
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	_battle = packed.instantiate()
	add_child(_battle)
	_battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle.size = Vector2(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	if not BattleDefeat.retreat(_battle):
		return "retreat refused"
	await get_tree().process_frame
	if str(_battle.get_meta("result_back", "")) != BattleDefeat.CASTLE:
		return "result_back %s" % _battle.get_meta("result_back", "")
	var text := str(GameState.get_meta(BattleDefeat.META, ""))
	if not text.begins_with(Locale.t("defeat_retreat_head")):
		return "settlement %s" % text
	var hurt := 0
	for u in _battle.units:
		if u.team == "player" and u.char.injured:
			hurt += 1
	if hurt == 0 or text.find("·") < 0:
		return "no injuries settled: %s" % text
	if BattleDefeat.retreat(_battle):
		return "double retreat"
	return ""
