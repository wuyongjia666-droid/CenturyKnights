extends Node
## WS-D #50/#5: defeat and retreat go back to the castle (never chapter 0) with an injury settlement;
## chapter-owned mid-cs suppresses BattleDefeat.record (no castle event_log「败北」);
## chapter-owned mid-cs suppresses CKEnemyLoadout.apply_defeat sticky injury;
## chapter-owned mid-cs suppresses CKInjury downs settle (no blood_meta injury/death).

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
	err = _protocol_defeat_injury_gate()
	if err != "":
		return err
	err = _protocol_ckinjury_settle_gate()
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


func _protocol_defeat_injury_gate() -> String:
	# Chapter-owned: maybe_apply_defeat must not stamp injured / classic_down.
	GameState.set_meta("battle_return_chapter", "cs01_01")
	var c := CKCharacter.new()
	c.job_id = "light_inf"
	c.level = 1
	c.stats = {"str": 10, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	c.hp = 4
	c.max_hp = 40
	c.injured = false
	var units := [{"char": c, "team": "player"}]
	if CKEnemyLoadout.maybe_apply_defeat(units, "standard"):
		return "chapter maybe_apply_defeat should skip"
	if c.injured:
		return "chapter maybe_apply_defeat stamped injured"
	if c.hp != c.max_hp:
		return "chapter maybe_apply_defeat hp %s" % c.hp
	print("OK protocol chapter suppresses defeat injury")
	GameState.set_meta("battle_return_chapter", "")
	c.hp = 4
	c.injured = false
	if not CKEnemyLoadout.maybe_apply_defeat(units, "standard"):
		return "hub maybe_apply_defeat should apply"
	if not c.injured or c.hp != maxi(1, int(c.max_hp * 0.3)):
		return "hub maybe_apply_defeat injury missing"
	print("OK protocol hub still applies defeat injury")
	return ""



func _protocol_ckinjury_settle_gate() -> String:
	# Chapter-owned: CKInjury._settle must not write blood_meta injury / stele.
	GameState.set_meta("battle_return_chapter", "cs01_01")
	if not CKInjury.suppresses_settle():
		return "chapter suppresses_settle false"
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	GameState.set_flag("hub_open")
	GameState.set_meta("battle_return_chapter", "cs01_01")
	CKInjury.set_mode("classic")
	var ally: CKCharacter = null
	for c in GameState.roster():
		if not c.is_leader:
			ally = c
			break
	if ally == null:
		return "no ally for ckinjury settle"
	var battle := Node.new()
	battle.add_user_signal("unit_downed", [
		{"name": "who", "type": TYPE_OBJECT},
		{"name": "info", "type": TYPE_DICTIONARY},
	])
	battle.add_user_signal("battle_finished", [
		{"name": "result", "type": TYPE_DICTIONARY},
	])
	add_child(battle)
	CKInjury.attach(battle)
	battle.emit_signal("unit_downed", ally, {
		"team": "player", "map_id": "ch12_yard", "killer": "探针",
		"overflow": 24, "seed": 1,
	})
	battle.emit_signal("battle_finished", {"win": false, "map_id": "ch12_yard"})
	if not ally.alive:
		return "chapter ckinjury settle killed ally"
	if not CKInjury.record(ally).is_empty():
		return "chapter ckinjury settle wrote injury"
	var stele0 = ally.blood_meta.get("stele", {}) if typeof(ally.blood_meta) == TYPE_DICTIONARY else {}
	if typeof(stele0) == TYPE_DICTIONARY and str(stele0.get("cause", "")) == "battle":
		return "chapter ckinjury settle wrote stele"
	print("OK protocol chapter suppresses ckinjury settle")
	battle.queue_free()
	GameState.set_meta("battle_return_chapter", "")
	if CKInjury.suppresses_settle():
		return "hub suppresses_settle true"
	# Hub still settles (classic lethal seed).
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	GameState.set_flag("hub_open")
	CKInjury.set_mode("classic")
	ally = null
	for c in GameState.roster():
		if not c.is_leader:
			ally = c
			break
	battle = Node.new()
	battle.add_user_signal("unit_downed", [
		{"name": "who", "type": TYPE_OBJECT},
		{"name": "info", "type": TYPE_DICTIONARY},
	])
	battle.add_user_signal("battle_finished", [
		{"name": "result", "type": TYPE_DICTIONARY},
	])
	add_child(battle)
	CKInjury.attach(battle)
	battle.emit_signal("unit_downed", ally, {
		"team": "player", "map_id": "ch12_yard", "killer": "探针",
		"overflow": 24, "seed": 1,
	})
	battle.emit_signal("battle_finished", {"win": false, "map_id": "ch12_yard"})
	if ally.alive:
		return "hub ckinjury settle did not kill"
	print("OK protocol hub still runs ckinjury settle")
	battle.queue_free()
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
