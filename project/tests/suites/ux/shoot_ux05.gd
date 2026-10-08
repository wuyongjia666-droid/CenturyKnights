extends Node
## UX-05 组件清单出图。CK_MODE=desktop|phone，CK_SHOOT_OUT 为 png。

func _ready() -> void:
	var phone := OS.get_environment("CK_MODE") == "phone"
	var win := Vector2i(1080, 1920) if phone else Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	get_tree().root.content_scale_factor = 1.0
	DisplayServer.window_set_size(win)
	get_tree().root.size = win
	await get_tree().process_frame
	await get_tree().process_frame
	_sheet(win)
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OS.get_environment("CK_SHOOT_OUT")
	if path == "":
		path = "/tmp/ux05.png"
	var err := img.save_png(path)
	print("SHOOT %s %sx%s err=%s" % [path, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)

func _sheet(win: Vector2i) -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.size = Vector2(win)
	add_child(host)
	UIKit.void_bg(host)
	UIKit.top_bar(host, "组件 · KIT", [], "", Callable())
	var col_w := mini(720, win.x - 48)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2((win.x - col_w) * 0.5, 72)
	scroll.size = Vector2(col_w, win.y - 96)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(col_w, 0)
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	box.add_child(UIKit.eyebrow("COMPONENTS"))
	box.add_child(UIKit.title_label("磨砂玻璃组件", 28))
	box.add_child(UIKit.tab_bar(PackedStringArray(["军务", "内政", "家族"]), 0))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.add_child(UIKit.make_accent_button("确认", 120))
	buttons.add_child(UIKit.ghost_button("返回", 120, 44))
	box.add_child(buttons)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.add_child(UIKit.tag_chip("霜青", UIKit.ACCENT, true))
	chips.add_child(UIKit.tag_chip("薄荷", UIKit.OK, false))
	chips.add_child(UIKit.tag_chip("珊瑚", UIKit.DANGER, false))
	box.add_child(chips)
	box.add_child(UIKit.list_row("花名册", "12"))
	box.add_child(UIKit.list_row("可升级工事", "2"))
	var dialog := UIKit.dialog_panel("本月待办", "建筑、委托、婚事、伤病、节庆、训练。每条只占一行。")
	box.add_child(dialog)
