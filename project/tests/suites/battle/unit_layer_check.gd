extends Node
## Route C 3D unit layer: headless falls back to 2D tokens; path walk BFS; perf cap.

func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL unit layer: ", err)
		get_tree().quit(1)
		return
	print("UNIT LAYER PASS")
	get_tree().quit(0)

func _run() -> String:
	if DisplayServer.get_name() == "headless" and CKUnitLayer3D.enabled():
		return "headless must use 2D tokens"
	if CKUnitLayer3D.enabled(CKUnitLayer3D.MAX_UNITS + 1):
		return "unit cap ignored"
	GameState.new_game("层", "灰旗", GameState.crest_color)
	GameState.set_meta("battle_map", "ch0_pass")
	GameState.settings["cutscenes"] = false
	var b = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(b)
	await get_tree().process_frame
	await get_tree().process_frame
	var u = null
	for x in b.units:
		if str(x.team) == "player":
			u = x
			break
	if u == null:
		return "no player unit"
	var a: Vector2i = u.pos
	var to := a
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var c2: Vector2i = a + d * 2
		if b._in_bounds(c2) and not b._terrain_blocked().has(c2) and not b._terrain_blocked().has(a + d):
			to = c2
			break
	if to == a:
		return "no free cell"
	var path: Array = b._unit_path(u, a, to)
	if path.is_empty() or path.back() != to:
		return "path does not end at target: %s" % [path]
	var prev := a
	for c in path:
		if absi(c.x - prev.x) + absi(c.y - prev.y) != 1:
			return "path not step-by-step: %s" % [path]
		prev = c
	b.queue_free()
	return ""
