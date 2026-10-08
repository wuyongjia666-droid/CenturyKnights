extends Node
## 手动出图：CK_SHOOT=desktop|phone，CK_SHOOT_OUT=绝对路径。不参与 CI。

func _ready() -> void:
	var phone := OS.get_environment("CK_SHOOT") == "phone"
	var win := Vector2i(1080, 1920) if phone else Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	DisplayServer.window_set_size(win)
	get_tree().root.size = win
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.new_game("霜行", "灰旗", GameState.crest_color)
	if GameState.settings is Dictionary:
		GameState.settings["tutorial_highlight"] = false
	var leader = GameState.get_leader()
	if leader:
		leader.injured = true
	Calendar.month = Calendar.SPRING_MONTH
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.position = Vector2.ZERO
	bg.size = Vector2(win)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var packed: PackedScene = load("res://scenes/hub/castle_hub.tscn")
	var hub := packed.instantiate() as Control
	hub.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hub.position = Vector2.ZERO
	hub.size = Vector2(1280, 720)
	add_child(hub)
	if phone:
		var fitted: float = 720.0 * hub.scale.x
		hub.position.y = maxf(0.0, (float(win.y) - fitted) * 0.5)
	for _i in 36:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_height() > 8 and img.get_pixel(4, 4).a < 0.01 and img.get_pixel(4, img.get_height() - 4).a > 0.5:
		img.flip_y()
	var path := OS.get_environment("CK_SHOOT_OUT")
	if path == "":
		path = "/tmp/ux06.png"
	var err := img.save_png(path)
	print("SHOOT %s %sx%s err=%s" % [path, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)
