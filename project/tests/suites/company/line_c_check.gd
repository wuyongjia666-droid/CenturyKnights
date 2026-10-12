extends Node
## WS-C（舆图·城镇·经营）回归：委托榜、舆图、城市、属地、市集、铁匠、酒馆刷新、联姻。

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game("霜行", "灰旗", GameState.crest_color)
	World.reset()
	World.events_enabled = false
	await _quests()
	if _fails.is_empty():
		print("LINE C PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL line_c: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _scene(path: String) -> Node:
	var packed: PackedScene = load(path)
	_ok(packed != null, "missing " + path)
	if packed == null:
		return null
	var n := packed.instantiate()
	add_child(n)
	await get_tree().process_frame
	return n


static func texts(n: Node) -> String:
	var out := ""
	if n is Label or n is Button:
		out += str(n.text) + "\n"
	for ch in n.get_children():
		out += texts(ch)
	return out


func _quests() -> void:
	var page := await _scene("res://scenes/hub/quests.tscn")
	if page == null:
		return
	var t := texts(page)
	_ok(t.find("手上还没接城里的委托") >= 0, "quests: empty world state missing")
	_ok(t.find("📍 石垒坡") >= 0, "quests: castle card has no place")
	_ok(t.find("耗时 1 月") >= 0, "quests: castle card has no months")
	page.call("_accept", "q_drill")
	await get_tree().process_frame
	_ok(str(page.get("_msg").text).find("办完了") >= 0, "quests: no result after accept")
	_ok(texts(page).find("再接一次") >= 0, "quests: repeat state missing")
	page.call("_accept", "nope")
	_ok(str(page.get("_msg").text).find("没接上") >= 0, "quests: failure state missing")
	page.queue_free()
