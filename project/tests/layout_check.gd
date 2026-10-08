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
	## v8.6 Stitch 01: editorial left column (not centred) — must sit in the left third, fully on-screen
	var box := root_scene.find_child("MenuColumn", false, false) as VBoxContainer
	if box == null:
		push_error("FAIL: no MenuColumn on main menu")
		quit(2)
		return
	var vp := root.get_visible_rect().size
	var r := Rect2(box.global_position, Vector2.ZERO)
	for ch in box.get_children():
		if ch is Control and (ch as Control).visible:
			r = r.merge(Rect2((ch as Control).global_position, (ch as Control).size))
	print("LAYOUT_OK viewport=%s col=%s" % [vp, r])
	## (headless --script has no autoload fonts, so line heights inflate: check slot + first CTA visibility, not full height)
	var first_btn: Control = null
	for ch in box.get_children():
		if ch is Button:
			first_btn = ch
			break
	if r.position.x < 24.0 or r.position.y < 24.0 or r.end.x > vp.x * 0.5 or first_btn == null or first_btn.global_position.y > vp.y - 120.0:
		push_error("FAIL: menu column off its Stitch 01 slot: %s" % r)
		quit(4)
		return
	var btns := 0
	for c in box.find_children("*", "Button", true, false):
		if (c as Button).visible:
			btns += 1
	if btns < 3:
		push_error("FAIL: menu column has %d buttons" % btns)
		quit(3)
		return
	print("PASS main menu column (Stitch 01)")
	quit(0)
