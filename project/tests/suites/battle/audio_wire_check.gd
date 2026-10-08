extends Node
## Battle music, weapon hits, footsteps, biome ambience, and gendered age-band barks.

var _battle


func _ready() -> void:
	var err := _source()
	if err == "":
		err = await _runtime()
	if err != "":
		print("FAIL audio wire: ", err)
		get_tree().quit(1)
		return
	print("AUDIO WIRE PASS")
	get_tree().quit(0)


func _source() -> String:
	var src := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	for needle in ["play_player_turn", "play_enemy_turn", "play_boss", "set_tension", "play_victory", "play_defeat", "play_weapon", "play_footstep", "play_ambience", "play_battle", "play_bark"]:
		if src.find(needle) < 0:
			return "missing %s" % needle
	for call in ["_bark(atk.char, \"shout\")", "_bark(def.char, \"shout\")", "_bark(def.char, \"breath\")", "_bark(u.char, \"shout\")", "_bark(o.char, \"shout\")", "_bark(o.char, \"breath\")"]:
		if src.find(call) < 0:
			return "missing %s" % call
	if src.find("Sfx.play_bark(str(c.gender), int(c.age), kind)") < 0:
		return "bark signature"
	return ""


func _runtime() -> String:
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	GameState.set_meta("battle_map", "obj_rout")
	GameState.set_meta("cutscenes_on", false)
	GameState.settings["cutscenes"] = false
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if Music.current_state() != "player_turn":
		return "open state %s" % Music.current_state()
	var tension := Music._tension
	if tension < 0.0 or tension > 1.0:
		return "tension %s" % tension
	var biome := AtlasArt.biome_for_map(_battle.map_id)
	if str(Sfx._ambience_id) != "amb_" + biome and biome != "":
		return "ambience %s for %s" % [Sfx._ambience_id, biome]
	_battle.turn_team = "enemy"
	_battle._sync_battle_music()
	if Music.current_state() != "enemy_turn":
		return "enemy state %s" % Music.current_state()
	_battle.map_id = "obj_boss"
	_battle.turn_team = "player"
	_battle._sync_battle_music()
	if Music.current_state() != "boss":
		return "boss state %s" % Music.current_state()
	_battle._finish(true)
	if Music.current_state() != "victory":
		return "victory state %s" % Music.current_state()
	var barked := false
	for k in Sfx._players.keys():
		if str(k).begins_with("bark_"):
			barked = true
			break
	if not barked:
		return "victory bark missing"
	return ""
