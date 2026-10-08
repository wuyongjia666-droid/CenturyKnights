extends Node

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL heirloom: ", err)
		get_tree().quit(1)
	else:
		print("HEIRLOOM PASS")
		get_tree().quit(0)

func _run() -> String:
	if CKHeirloom.succeeds(1, 0.79) != true or CKHeirloom.succeeds(1, 0.80) != false:
		return "plus1 table"
	if CKHeirloom.succeeds(2, 0.54) != true or CKHeirloom.succeeds(2, 0.55) != false:
		return "plus2 table"
	if CKHeirloom.succeeds(3, 0.29) != true or CKHeirloom.succeeds(3, 0.30) != false:
		return "plus3 table"
	if CKHeirloom.succeeds(4, 0.0):
		return "plus4 should be closed"
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var bearer: CKCharacter = GameState.get_leader()
	if bearer == null:
		return "no leader"
	GameState.iron = 30
	GameState.silver = 200
	var fail: Dictionary = CKHeirloom.apply_roll(GameState, bearer.id, 0.99)
	if str(fail.get("result", "")) != "fail" or CKHeirloom.plus_of(bearer.id) != 0:
		return "fail kept plus"
	if GameState.iron != 28 or GameState.silver != 185:
		return "fail still spent"
	var ok: Dictionary = CKHeirloom.apply_roll(GameState, bearer.id, 0.0)
	if str(ok.get("result", "")) != "success" or CKHeirloom.plus_of(bearer.id) != 1:
		return "success %s" % str(ok)
	if World.gear_bonus(bearer, "atk") < 1:
		return "plus not in gear bonus"
	if CKHeirloom.grown_atk(1, 0) != 0 or CKHeirloom.grown_atk(3, 0) < 2:
		return "generation curve"
	CKHeirloom.mark_heirloom(bearer.id, 1)
	var heir := CKCharacter.new()
	heir.id = "heir_probe"
	heir.alive = true
	GameState.characters[heir.id] = heir
	var passed: Dictionary = CKHeirloom.pass_down(bearer.id, heir.id)
	if not bool(passed.get("ok", false)) or int(passed.get("gen", 0)) != 2:
		return "pass"
	var back: Dictionary = CKHeirloom.pass_down(heir.id, bearer.id)
	if int(back.get("gen", 0)) != 3:
		return "third gen %s" % str(back)
	if CKHeirloom.grown_atk(int(CKHeirloom.row(bearer.id).get("gen", 0)), 0) < 2:
		return "third gen atk"
	if World.gear_bonus(bearer, "atk") < 2:
		return "heir gear"
	if bool(CKHeirloom.store(GameState, bearer.id).get("ok", false)):
		return "stored with no treasury"
	GameState.buildings["treasury"] = 1
	if not bool(CKHeirloom.store(GameState, bearer.id).get("ok", false)):
		return "store"
	if CKHeirloom.plus_bonus(bearer, "atk") != 0:
		return "vault still grants atk"
	if not bool(CKHeirloom.withdraw(GameState, bearer.id).get("ok", false)):
		return "withdraw"
	if CKHeirloom.plus_bonus(bearer, "atk") < 2:
		return "atk after withdraw"
	GameState.characters.erase(heir.id)
	return ""
