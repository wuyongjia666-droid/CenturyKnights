extends Node
## CMP-02: epoch dues leave a tight opening month and do not touch GameState.rng.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL economy pressure: ", err)
		get_tree().quit(1)
	else:
		print("ECONOMY PRESSURE PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.silver = 200
	var wage := CKEconomyState.monthly_wage(GameState)
	if wage <= 0:
		return "opening wage %d" % wage
	var rng_before := GameState.rng.state
	var opened: Dictionary = CKEconomyState.apply_epoch_pressure(GameState, 1)
	var expect_due := maxi(0, 200 - (wage * 3 - 1))
	if int(opened.get("silver", 0)) != expect_due:
		return "muster %s wage %d" % [str(opened), wage]
	if int(GameState.silver) != 200 - expect_due:
		return "year-1 silver %d" % int(GameState.silver)
	if int(GameState.silver) >= wage * 3:
		return "year 1 is not tight"
	GameState.silver = 2000
	var mid: Dictionary = CKEconomyState.apply_epoch_pressure(GameState, 25)
	if str(mid.get("phase", "")) != "mid" or int(mid.get("silver", 0)) != 180:
		return "mid %s" % str(mid)
	if int(GameState.silver) != 1820:
		return "mid silver %d" % int(GameState.silver)
	GameState.silver = 4000
	var late: Dictionary = CKEconomyState.apply_epoch_pressure(GameState, 55)
	if str(late.get("phase", "")) != "late" or int(late.get("silver", 0)) != 1380:
		return "late %s" % str(late)
	if int(GameState.silver) != 2620:
		return "late silver %d" % int(GameState.silver)
	if GameState.rng.state != rng_before:
		return "rng moved"
	var purse: Dictionary = CKEconomyState.apply_spring_purse(GameState)
	if int(purse.get("silver", 0)) != 180:
		return "purse"
	return ""
