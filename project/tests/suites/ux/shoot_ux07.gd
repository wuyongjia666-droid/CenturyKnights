extends Node
## UX-07 出图。CK_MODE=desktop|phone，CK_SHOOT_OUT 为 png 路径。

func _ready() -> void:
	GameState.settings["tutorial_highlight"] = false
	GameState.settings["tips_seen"] = {"settings_lamp": true, "menu_lamp": true}
	var phone := OS.get_environment("CK_MODE") == "phone"
	var win := Vector2i(1080, 1920) if phone else Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	get_tree().root.content_scale_factor = 1.0
	DisplayServer.window_set_size(win)
	get_tree().root.size = win
	await get_tree().process_frame
	await get_tree().process_frame
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.size = Vector2(win)
	add_child(host)
	var credits := (load("res://scenes/ui/credits.tscn") as PackedScene).instantiate()
	host.add_child(credits)
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OS.get_environment("CK_SHOOT_OUT")
	if path == "":
		path = "/tmp/ux07.png"
	var err := img.save_png(path)
	print("SHOOT %s %sx%s err=%s" % [path, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)
