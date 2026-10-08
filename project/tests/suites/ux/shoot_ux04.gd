extends Node
## UX-04 出图。CK_MODE=desktop|phone，CK_SHOOT_OUT 为 png 路径。

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
	_page(win)
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OS.get_environment("CK_SHOOT_OUT")
	if path == "":
		path = "/tmp/ux04.png"
	var err := img.save_png(path)
	print("SHOOT %s %sx%s err=%s" % [path, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)

func _page(win: Vector2i) -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.size = Vector2(win)
	add_child(host)
	UIKit.void_bg(host)
	UIKit.top_bar(host, "字体 · FONTS", [], "", Callable())
	var col_w := mini(640, win.x - 80)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.glass(16, 0.86, true))
	card.position = Vector2((win.x - col_w) * 0.5, 120 if win.y > 1000 else 96)
	card.custom_minimum_size = Vector2(col_w, 0)
	card.size = Vector2(col_w, 0)
	host.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	box.add_child(UIKit.eyebrow("COVERAGE"))
	box.add_child(UIKit.title_label("子集盖住界面与数据", 32 if win.y > 1000 else 28))
	box.add_child(UIKit.body_label("Noto Sans SC 子集。新出现的汉字若不在字库里，门禁会失败并打印缺字。", UIKit.TEXT_DIM, 16))
	box.add_child(UIKit.title_label("σ  ≈  ０９", 36))
	box.add_child(UIKit.body_label("甲　乙　丙　丁", UIKit.TEXT, 22))
	box.add_child(UIKit.body_label("百年骑士 · 霜青 · 薄荷 · 珊瑚", UIKit.TEXT_DIM, 16))
