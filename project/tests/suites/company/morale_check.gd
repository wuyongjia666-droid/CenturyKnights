extends Node
## CMP-07: morale bands are readable, and two unpaid months without a hold send someone away.

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL morale: ", err)
		get_tree().quit(1)
		return
	print("MORALE PASS")
	get_tree().quit(0)

func _run() -> String:
	var err := _bands()
	if err != "":
		return err
	err = _desert()
	if err != "":
		return err
	err = _hold()
	if err != "":
		return err
	return ""

func _bands() -> String:
	var expect := {
		100: ["high", 3, 1],
		80: ["high", 3, 1],
		79: ["steady", 0, 0],
		50: ["steady", 0, 0],
		49: ["low", -3, 0],
		25: ["low", -3, 0],
		24: ["broken", -5, -1],
		0: ["broken", -5, -1],
	}
	for morale in expect.keys():
		var want: Array = expect[morale]
		var got: Dictionary = CKMorale.battle_mods(int(morale))
		if str(got.get("id", "")) != str(want[0]) or int(got.get("hit", 99)) != int(want[1]) or int(got.get("atk", 99)) != int(want[2]):
			return "band %s got %s" % [morale, got]
	return ""

func _non_leader() -> CKCharacter:
	for c in GameState.roster():
		if not c.is_leader:
			return c
	return null

func _desert() -> String:
	GameState.new_game("士气", "灰旗", GameState.crest_color)
	var ally := _non_leader()
	if ally == null:
		return "no ally"
	var name := ally.name
	var size0 := GameState.roster().size()
	GameState.silver = 0
	GameState.food = 40
	GameState.apply_monthly_upkeep()
	if CKMorale.unpaid_months(GameState) != 1:
		return "first unpaid month %d" % CKMorale.unpaid_months(GameState)
	if not ally.in_roster:
		return "left after one unpaid month"
	GameState.silver = 0
	GameState.food = 40
	GameState.apply_monthly_upkeep()
	if ally.in_roster or GameState.roster().has(ally):
		return "still on the roster after two unpaid months"
	if GameState.roster().size() != size0 - 1:
		return "roster size %d" % GameState.roster().size()
	if not bool(ally.blood_meta.get("deserted", false)):
		return "desert flag missing"
	var logged := false
	for row in GameState.event_log:
		if str(row).find(name) >= 0 and str(row).find("离队") >= 0:
			logged = true
	if not logged:
		return "no desert event"
	if not GameState.get_leader().in_roster:
		return "leader left"
	return ""

func _hold() -> String:
	GameState.new_game("士气", "灰旗", GameState.crest_color)
	var ally := _non_leader()
	GameState.silver = 0
	GameState.food = 40
	GameState.apply_monthly_upkeep()
	CKMorale.hold_back(GameState)
	GameState.silver = 0
	GameState.food = 40
	GameState.apply_monthly_upkeep()
	if not ally.in_roster:
		return "hold did not keep the ally"
	if CKMorale.unpaid_months(GameState) < 2:
		return "hold cleared the unpaid streak"
	return ""
