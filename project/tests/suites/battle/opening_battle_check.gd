extends Node
## Opening-chain track B: ch0_pass seize + idle objective + e1 banter + no militia.

func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL opening_battle: ", err)
		get_tree().quit(1)
		return
	print("OPENING_BATTLE PASS")
	get_tree().quit(0)


func _run() -> String:
	GameState.new_game("烬行", "岑", "#" + "6ED4FF")
	var err := _check_data()
	if err != "":
		return err
	return await _check_battle()


func _check_data() -> String:
	var m: Dictionary = BattleMaps.get_map("ch0_pass")
	if str(BattleObjectives.spec(m).get("type", "")) != "seize":
		return "ch0_pass objective"
	if bool(m.get("tutorial_militia", false)):
		return "militia still on"
	if not bool(m.get("tutorial", false)):
		return "tutorial flag missing"
	if int(m.get("w", 0)) < 10 or int(m.get("h", 0)) < 7:
		return "map size"
	if BattleStory.lines_for("ch0_pass", "start").size() < 3:
		return "ch0 start thin"
	if BattleStory.lines_for("e1_reed_escort", "start").size() < 3:
		return "e1 start missing"
	var era: Dictionary = BattleMaps.get_map("e1_reed_escort")
	var names: Array = era.get("enemy_names", [])
	if names.is_empty() or str(names[0]).find("林缘") < 0:
		return "e1 enemy names"
	var err := _check_board_triggers()
	if err != "":
		return err
	var desc := BattleVictory.describe("ch0_pass", {})
	if int(desc.get("skill_points", -1)) != 0:
		return "tutorial skill points %s" % desc.get("skill_points")
	return ""


func _u(team: String, pos: Vector2i, tag := "") -> Dictionary:
	return {"team": team, "pos": pos, "tag": tag, "char": {"hp": 10}}


func _check_board_triggers() -> String:
	var seize := {"type": "seize", "tile": [7, 3]}
	if not BattleStory.board_triggers([_u("player", Vector2i(7, 3))], seize).is_empty():
		return "past_seize fired on the seize tile"
	if not BattleStory.board_triggers([_u("player", Vector2i(8, 3))], seize).has("past_seize"):
		return "past_seize missing"
	var esc := {"type": "escort", "npc": "grain", "exit_tile": [11, 1]}
	var far := [_u("ally", Vector2i(1, 5), "grain"), _u("enemy", Vector2i(8, 2))]
	if not BattleStory.board_triggers(far, esc).is_empty():
		return "escort triggers fired early"
	var near := [_u("ally", Vector2i(10, 2), "grain"), _u("enemy", Vector2i(9, 3))]
	var got := BattleStory.board_triggers(near, esc)
	if not got.has("npc_near_goal") or not got.has("npc_threatened"):
		return "escort triggers %s" % [got]
	for trig in ["npc_threatened", "npc_near_goal"]:
		if BattleStory.lines_for("e1_reed_escort", trig).is_empty():
			return "e1 %s lines missing" % trig
	if BattleStory.lines_for("ch0_pass", "past_seize").is_empty():
		return "ch0 past_seize lines missing"
	return ""


func _check_battle() -> String:
	GameState.set_meta("battle_map", "ch0_pass")
	var packed: PackedScene = load("res://scenes/battle/battle.tscn")
	var battle = packed.instantiate()
	add_child(battle)
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle.size = Vector2(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var err := _battle_assertions(battle)
	battle.queue_free()
	return err


func _battle_assertions(battle) -> String:
	if str(battle.map_id) != "ch0_pass":
		return "map id %s" % battle.map_id
	var militia := 0
	var foes := 0
	for u in battle.units:
		if str(u.char.name).find("民兵") >= 0:
			militia += 1
		if str(u.team) == "enemy":
			foes += 1
	if militia > 0:
		return "militia deployed"
	if foes < 3:
		return "expected 3 foes got %d" % foes
	battle.selected = -1
	BattleInfoPanel.refresh(battle)
	var idle := str(battle.info_label.text)
	if idle.find("歼灭全部敌人") >= 0:
		return "idle still rout: " + idle
	var seize_label := BattleObjectives.text("obj_seize")
	if idle.find(seize_label) < 0:
		return "idle missing seize (%s): %s" % [seize_label, idle]
	if battle.get_node_or_null("LockTipPanel") != null:
		return "lock tip at deploy"
	BattleLockTutorial.run_sequence(battle)
	if battle.get_node_or_null("LockTipPanel") == null:
		return "lock tip missing after sequence"
	for u in battle.units:
		if str(u.team) == "player" and u.char.hp > 0:
			u.pos = Vector2i(7, 3)
			break
	battle._check_end()
	var got = battle.get_meta("battle_verdict", {})
	if str(got.get("result", "")) != "win" or str(got.get("reason", "")) != "seize":
		return "seize win %s" % got
	return ""
