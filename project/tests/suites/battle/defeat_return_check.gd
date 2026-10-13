extends Node
## WS-D #50/#5: defeat and retreat go back to the castle (never chapter 0) with an injury settlement.

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
	if BattleDefeat.back_path(false, false, "res://scenes/story/chapter0.tscn") != BattleDefeat.CASTLE:
		return "story defeat after hub_open still returns to chapter"
	if BattleDefeat.back_path(true, false, "res://scenes/story/chapter0.tscn") != "res://scenes/story/chapter0.tscn":
		return "story win lost its return"
	if BattleDefeat.back_path(true, false, "") != BattleDefeat.CASTLE:
		return "win with no return"
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
