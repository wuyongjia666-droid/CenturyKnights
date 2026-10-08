extends Node
## UX-08: every hub/ui clickable is at least 44px after MobileLayout.ensure_hit_targets.
## Exceptions live in ALLOW with a reason. Back/Esc opens CKPauseMenu and does not change scene.

const HIT := 44.0

# scene file name + button name -> why it may stay under 44px. Empty means no exceptions.
const ALLOW := {}

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_fit_math()
	await _lineage_column()
	await _tiny_button()
	GameState.new_game("霜行", "灰旗", GameState.crest_color)
	if GameState.settings is Dictionary:
		GameState.settings["tutorial_highlight"] = false
	await _scan_scenes()
	await _back_key()
	if _fails.is_empty():
		print("TOUCH PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL touch: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _fit_math() -> void:
	var insets := {"left": 0.0, "top": 84.0, "right": 0.0, "bottom": 96.0}
	var fitted: Dictionary = MobileLayout.fit(Vector2(1080, 1920), insets)
	var s := float(fitted.get("scale", 0.0))
	var pos: Vector2 = fitted.get("position", Vector2(-1, -1))
	_ok(s > 0.0 and s <= 1.0, "portrait scale %s" % s)
	_ok(pos.x >= 0.0 and pos.y >= 84.0, "portrait origin %s" % pos)

func _lineage_column() -> void:
	var root := Control.new()
	root.size = Vector2(1280, 720)
	add_child(root)
	var tree := Control.new()
	tree.position = Vector2(42, 150)
	tree.size = Vector2(800, 440)
	root.add_child(tree)
	var jumps := HBoxContainer.new()
	jumps.name = "LineageJumps"
	jumps.position = Vector2(42, 604)
	jumps.size = Vector2(400, 44)
	root.add_child(jumps)
	var footer := Control.new()
	footer.name = "StitchFooter"
	footer.position = Vector2(0, 1500)
	footer.size = Vector2(1280, 28)
	root.add_child(footer)
	await get_tree().process_frame
	MobileLayout.extend_portrait_lists(root)
	_ok(jumps.position.y > 1000.0, "lineage jumps stayed at %s" % jumps.position)
	_ok(tree.size.y > 800.0, "lineage tree height %s" % tree.size.y)
	root.queue_free()
	await get_tree().process_frame

func _tiny_button() -> void:
	var host := Control.new()
	add_child(host)
	var tiny := Button.new()
	tiny.custom_minimum_size = Vector2(80, 20)
	tiny.size = Vector2(80, 20)
	host.add_child(tiny)
	await get_tree().process_frame
	MobileLayout.ensure_hit_targets(host, HIT)
	_ok(tiny.custom_minimum_size.x >= HIT and tiny.custom_minimum_size.y >= HIT, "tiny min %s" % tiny.custom_minimum_size)
	host.queue_free()
	await get_tree().process_frame

func _scan_scenes() -> void:
	var scenes: Array = _scene_paths()
	_ok(scenes.size() >= 20, "scene count %d" % scenes.size())
	var seen := {}
	var buttons := 0
	var violations := 0
	for path in scenes:
		var packed := load(str(path)) as PackedScene
		if packed == null:
			_fails.append("%s load" % path)
			continue
		var node := packed.instantiate()
		if node == null:
			_fails.append("%s instantiate" % path)
			continue
		add_child(node)
		await get_tree().process_frame
		await get_tree().process_frame
		if node is Control:
			MobileLayout.extend_portrait_lists(node as Control)
		MobileLayout.ensure_hit_targets(node, HIT)
		await get_tree().process_frame
		var found: Array = _measure(node, str(path), seen)
		buttons += int(found[0])
		violations += int(found[1])
		node.queue_free()
		await get_tree().process_frame
	for key in ALLOW.keys():
		if not seen.has(key):
			_fails.append("whitelist unused: %s" % key)
	print("TOUCH scenes=%d buttons=%d violations=%d whitelist=%d" % [scenes.size(), buttons, violations, seen.size()])

func _scene_paths() -> Array:
	var scenes: Array = []
	for dir in ["res://scenes/hub", "res://scenes/ui"]:
		var d := DirAccess.open(dir)
		if d == null:
			_fails.append("missing %s" % dir)
			continue
		for f in d.get_files():
			if str(f).ends_with(".tscn"):
				scenes.append(dir + "/" + str(f))
	scenes.sort()
	return scenes

func _measure(node: Node, path: String, seen: Dictionary) -> Array:
	var buttons := 0
	var violations := 0
	var stack: Array = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for child in cur.get_children():
			stack.append(child)
		if not (cur is BaseButton):
			continue
		var button := cur as BaseButton
		if not button.visible or not button.is_visible_in_tree():
			continue
		if button.mouse_filter != Control.MOUSE_FILTER_STOP:
			continue
		if bool(button.get_meta("touch_exempt", false)):
			continue
		buttons += 1
		var w := maxf(button.size.x, button.custom_minimum_size.x)
		var h := maxf(button.size.y, button.custom_minimum_size.y)
		var reason := MobileLayout.hit_exception(button)
		if reason != "":
			if not seen.has(reason):
				print("ALLOW %s" % reason)
				seen[reason] = true
			continue
		if w + 0.5 >= HIT and h + 0.5 >= HIT:
			continue
		var key := "%s|%s" % [path.get_file(), str(button.name)]
		if ALLOW.has(key):
			seen[key] = true
			print("ALLOW %s (%s) %.0fx%.0f" % [key, str(ALLOW[key]), w, h])
			continue
		violations += 1
		_fails.append("%s %s %.0fx%.0f" % [path, button.name, w, h])
	return [buttons, violations]

func _back_key() -> void:
	if CKPauseMenu.current != null and is_instance_valid(CKPauseMenu.current):
		CKPauseMenu.current.free()
	await get_tree().process_frame
	var castle_ps := load("res://scenes/hub/castle_hub.tscn") as PackedScene
	var castle := castle_ps.instantiate()
	add_child(castle)
	await get_tree().process_frame
	var here := get_tree().current_scene
	_press_cancel()
	await get_tree().process_frame
	_ok(get_tree().current_scene == here, "cancel left the current scene")
	_ok(CKPauseMenu.current != null and is_instance_valid(CKPauseMenu.current), "cancel should open pause")
	_press_cancel()
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(CKPauseMenu.current == null or not is_instance_valid(CKPauseMenu.current), "second cancel should close pause")
	var coach := CKCoach.attach(self)
	coach.focus_mode = Control.FOCUS_ALL
	coach.grab_focus()
	await get_tree().process_frame
	_press_cancel()
	await get_tree().process_frame
	_ok(CKPauseMenu.current == null or not is_instance_valid(CKPauseMenu.current), "focused coach should keep cancel")
	coach.queue_free()
	castle.queue_free()
	await get_tree().process_frame

func _press_cancel() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	get_viewport().push_input(ev)
