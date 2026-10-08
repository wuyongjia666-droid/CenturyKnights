extends SceneTree
## v8.5: instantiate every hub / battle / menu scene headless; any parse or _ready error fails CI.

func _init() -> void:
	var gs = root.get_node_or_null("GameState")
	await process_frame
	gs = root.get_node_or_null("GameState")
	if gs:
		gs.new_game("烬行", "灰旗", "#c9a227")
	var fails: Array = []
	var scenes: Array = []
	for dir in ["res://scenes/hub", "res://scenes/battle", "res://scenes/ui", "res://scenes/menu"]:
		var d = DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".tscn"):
				scenes.append(dir + "/" + f)
	for sp in scenes:
		var ps = load(sp)
		if ps == null:
			fails.append(sp + " (load)")
			continue
		var n = ps.instantiate()
		if n == null:
			fails.append(sp + " (instantiate)")
			continue
		root.add_child(n)
		await process_frame
		await process_frame
		if n.get_script() != null and not n.get_script().can_instantiate():
			fails.append(sp + " (script)")
		n.queue_free()
		await process_frame
	print("scene_load_check: %d scenes" % scenes.size())
	if fails.is_empty():
		print("=== SCENE LOAD PASS ===")
		quit(0)
	else:
		for f in fails:
			print("FAIL ", f)
		quit(1)
