extends Node
## WS-D #52: the first month must allow two things, not one. Opening silver covers a level-2 works
## upgrade plus a training session, and still leaves a month's wages in the chest.


func _ready() -> void:
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	var up := int(GameState.BUILDING_COST[2]["silver"])
	var train := GameState.train_cost()
	var left := GameState.silver - up - train
	print("OPENING BUDGET silver=%d works=%d train=%d left=%d" % [GameState.silver, up, train, left])
	if left < 20:
		print("FAIL opening budget: only %d left after works + training" % left)
		get_tree().quit(1)
		return
	print("OPENING BUDGET PASS")
	get_tree().quit(0)
