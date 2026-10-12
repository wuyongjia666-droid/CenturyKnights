extends Node
## Audit P1-3: the castle sortie pays once a calendar month; repeats are drills. Story fights are untouched.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL sortie cap: ", err)
		get_tree().quit(1)
	else:
		print("SORTIE CAP PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	if BattleVictory.sortie_is_drill(GameState):
		return "a story fight (no sortie meta) counted as a drill"
	GameState.set_meta("battle_sortie", true)
	if BattleVictory.sortie_is_drill(GameState):
		return "first sortie of the month is a drill"
	GameState.set_meta("battle_sortie", true)
	if not BattleVictory.sortie_is_drill(GameState):
		return "second sortie in a month still paid"
	var blob: Dictionary = GameState.build_save_data()
	GameState.apply_save_data(blob)
	GameState.set_meta("battle_sortie", true)
	if not BattleVictory.sortie_is_drill(GameState):
		return "sortie month lost on reload"
	Calendar.advance(1)
	GameState.set_meta("battle_sortie", true)
	if BattleVictory.sortie_is_drill(GameState):
		return "new month sortie is a drill"
	print("OK sortie cap")
	return ""
