extends Node
## WS-C #43/#44：城市概览不再留白（传闻）、没有的铺子页签隐藏、交付栏写清去哪交。

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game("霜行", "灰旗", GameState.crest_color)
	World.reset()
	World.events_enabled = false
	await _city("hq", false)
	World.pos = "ash_capital"
	await _city("ash_capital", true)
	if _fails.is_empty():
		print("LINE C CITY PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL line_c_city: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _city(cid: String, has_smith: bool) -> void:
	GameState.set_meta("city_id", cid)
	var packed: PackedScene = load("res://scenes/hub/city.tscn")
	var c := packed.instantiate()
	add_child(c)
	await get_tree().process_frame
	var tabs: Dictionary = c.get("_tab_btn")
	_ok((tabs["smith"] as Button).visible == has_smith, "%s smith tab visible=%s" % [cid, (tabs["smith"] as Button).visible])
	c.call("_set_tab", "smith")
	_ok(has_smith or str(c.get("tab")) == "overview", "%s: hidden smith tab still opens" % cid)
	c.call("_set_tab", "overview")
	await get_tree().process_frame
	var r: Array = c.call("rumors", cid)
	_ok(not r.is_empty(), "%s: no rumors" % cid)
	_ok(c.find_child("Rumors", true, false) != null or c.find_child("RumorsBox", true, false) != null, "%s: rumor box missing" % cid)
	c.queue_free()
	await get_tree().process_frame
