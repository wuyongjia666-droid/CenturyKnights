extends Node

func _ready() -> void:
	var phone := OS.get_environment("CK_MODE") == "phone"
	var win := Vector2i(1080, 1920) if phone else Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	get_tree().root.content_scale_factor = 1.0
	DisplayServer.window_set_size(win)
	get_tree().root.size = win
	await get_tree().process_frame
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.size = Vector2(win)
	add_child(host)
	UIKit.void_bg(host)
	UIKit.top_bar(host, "手感 · MOTION", [], "", Callable())
	var card := PanelContainer.new()
	var w := mini(520, win.x - 64)
	card.position = Vector2((win.x - w) * 0.5, 140)
	card.custom_minimum_size = Vector2(w, 0)
	card.add_theme_stylebox_override("panel", UIKit.glass(16, 0.88, true))
	host.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	box.add_child(UIKit.eyebrow("JUICE"))
	box.add_child(UIKit.title_label("转场与按压", 28))
	box.add_child(UIKit.body_label("页面转场最长 0.22 秒。减动效时不超过 0.08 秒。触感关掉后，确认键不会震动。", UIKit.TEXT_DIM, 15))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UIKit.make_accent_button("确认", 140))
	row.add_child(UIKit.ghost_button("返回", 120, 44))
	box.add_child(row)
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OS.get_environment("CK_SHOOT_OUT")
	if path == "":
		path = "/tmp/ux09.png"
	var err := img.save_png(path)
	print("SHOOT err=%s" % err)
	get_tree().quit(0 if err == OK else 1)
