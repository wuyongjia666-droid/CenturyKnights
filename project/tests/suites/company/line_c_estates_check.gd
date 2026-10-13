extends Node
## WS-C #37：属地开局就有一块能用；巡防成功、失败都有结果框；重复巡防给冷却原因。

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game("霜行", "灰旗", GameState.crest_color)
	GameState.holdings = {}
	var packed: PackedScene = load("res://scenes/hub/estates.tscn")
	var e := packed.instantiate()
	add_child(e)
	await get_tree().process_frame
	_ok(GameState.holdings.size() == 1, "first holding not granted: %s" % str(GameState.holdings))
	_ok(str(e.get("_msg").text).find("第一块田庄") >= 0, "no first-holding note")
	GameState.silver = 0
	e.call("_do_patrol_one", str(GameState.holdings.keys()[0]))
	_ok(e.find_child("PatrolResult", true, false) != null, "no failure box")
	GameState.silver = 999
	GameState.food = 999
	e.call("_do_patrol_one", str(GameState.holdings.keys()[0]))
	var tip := e.find_child("PatrolTip", true, false) as Label
	_ok(tip != null and tip.text.find("巡防完成") >= 0, "no success result")
	e.call("_do_patrol_one", str(GameState.holdings.keys()[0]))
	_ok(str(e.get("_msg").text).find("冷却") >= 0, "repeat patrol gives no cooldown reason")
	e.queue_free()
	await get_tree().process_frame
	var again := packed.instantiate()
	add_child(again)
	await get_tree().process_frame
	_ok(GameState.holdings.size() == 1, "grant ran twice")
	if _fails.is_empty():
		print("LINE C ESTATES PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL line_c_estates: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
