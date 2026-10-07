extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var err := change_scene_to_file("res://scenes/ui/main_menu.tscn")
	if err != OK:
		push_error("change_scene failed: %s" % err)
		quit(1)
		return
	await process_frame
	await process_frame
	var root_scene := current_scene
	if root_scene == null:
		push_error("no current scene")
		quit(1)
		return
	var cc: CenterContainer = null
	for c in root_scene.get_children():
		if c is CenterContainer:
			cc = c
			break
	if cc == null:
		push_error("FAIL: no CenterContainer on main menu")
		quit(2)
		return
	var box: VBoxContainer = null
	for c in cc.get_children():
		if c is VBoxContainer:
			box = c
			break
	if box == null:
		push_error("FAIL: no VBox under CenterContainer")
		quit(3)
		return
	var vp := root.get_visible_rect().size
	var mid := vp * 0.5
	var box_mid := box.global_position + box.size * 0.5
	var drift := (box_mid - mid).abs()
	print("LAYOUT_OK viewport=%s box_pos=%s box_size=%s box_mid=%s drift=%s" % [
		vp, box.global_position, box.size, box_mid, drift
	])
	if drift.x > 40.0 or drift.y > 80.0:
		push_error("FAIL: menu not centered, drift=%s" % drift)
		quit(4)
		return
	# Ensure no hard-coded broken pattern remains in script source check via presence of CenterContainer
	print("PASS main menu centered")
	quit(0)
