extends Node
## Audit P1-1: a fresh game has nothing due; hp below max is not a wound; locked entries never count.

const Todo = preload("res://scripts/ui/widgets/todo_center.gd")

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL todo due: ", err)
		get_tree().quit(1)
	else:
		print("TODO DUE PASS")
		get_tree().quit(0)

func _run() -> String:
	Todo.reset_for_tests()
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	for item in Todo.snapshot():
		if int(item.get("count", 0)) > 0 and str(item.get("category", "")) != "festival":
			return "fresh game shows %s %d" % [str(item.get("label", "")), int(item.get("count", 0))]
	GameState.get_leader().hp = 1
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "injured" and int(item.get("count", 0)) > 0:
			return "hp below max counted as wounded"
	GameState.set_meta("active_quest_id", "q_bandit")
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "quests" and not Todo.is_unlocked("quests"):
			return "locked quests still counted"
	GameState.get_leader().injured = true
	var hurt := 0
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "injured":
			hurt = int(item.get("count", 0))
	if hurt != 1:
		return "real wound not counted (%d)" % hurt
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "injured" and Todo.link_for(item) != "res://scenes/hub/roster.tscn":
			return "injured chip has no roster link"
		if str(item.get("category", "")) == "festival" and Todo.link_for(item) != "":
			return "festival chip links somewhere"
	if Todo.link_for({"link": "res://scenes/hub/nope.tscn"}) != "":
		return "missing scene accepted as link"
	Todo.register("x", "home", "x", 1, "res://scenes/hub/roster.tscn")
	var found := false
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "x" and Todo.link_for(item) != "":
			found = true
	Todo.reset_for_tests()
	if not found:
		return "registered link dropped"
	GameState.remove_meta("active_quest_id")
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.active = [{"id": "wq_probe", "title": "probe", "state": "active", "kind": "deliver", "target": "ash_capital", "issuer": "ash_capital"}]
	if Todo.is_unlocked("quests"):
		var wq := 0
		for item in Todo.snapshot():
			if str(item.get("category", "")) == "quests":
				wq = int(item.get("count", 0))
		if wq < 1:
			return "world active not counted (%d)" % wq
	World.active.clear()
	print("OK todo due")
	return ""
