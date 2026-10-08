extends Node
## 手动出图：CK_SHOOT=desktop|phone，CK_SHOOT_OUT=绝对路径。不参与 CI。

func _ready() -> void:
	var mode := OS.get_environment("CK_SHOOT")
	var phone := mode == "phone"
	var win := Vector2i(1080, 1920) if phone else Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	DisplayServer.window_set_size(win)
	get_tree().root.size = win
	await get_tree().process_frame
	await get_tree().process_frame
	await _stage(phone)
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_height() > 8 and img.get_pixel(4, 4).a < 0.01 and img.get_pixel(4, img.get_height() - 4).a > 0.5:
		img.flip_y()
	var path := OS.get_environment("CK_SHOOT_OUT")
	if path == "":
		path = "/tmp/ux01.png"
	var err := img.save_png(path)
	print("SHOOT %s %sx%s err=%s" % [path, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)

func _stage(phone: bool) -> void:
	var root := Control.new()
	root.name = "Stage"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size = get_viewport().get_visible_rect().size
	add_child(root)
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var glow := ColorRect.new()
	glow.color = Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.05)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if phone:
		glow.position = Vector2(0, 0)
		glow.size = Vector2(1080, 280)
	else:
		glow.position = Vector2(0, 0)
		glow.size = Vector2(520, 720)
	root.add_child(glow)

	var safe := CKCoach.safe_rect(
		Vector2(1080, 1920) if phone else Vector2(1280, 720),
		{"left": 0.0, "top": 84.0, "right": 0.0, "bottom": 96.0} if phone else {"left": 0.0, "top": 24.0, "right": 24.0, "bottom": 24.0}
	)
	var col := VBoxContainer.new()
	col.position = Vector2(48, 220) if phone else Vector2(88, 72)
	col.custom_minimum_size = Vector2(920, 0) if phone else Vector2(460, 0)
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	col.add_child(UIKit.eyebrow("CENTURY KNIGHTS · 百年骑士"))
	col.add_child(UIKit.title_label("灯引", 48 if phone else 40))
	var sub := UIKit.body_label("第一次走进这里时，只点亮一次。", UIKit.TEXT_DIM, 16 if phone else 15)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(880, 0) if phone else Vector2(420, 0)
	col.add_child(sub)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.glass(16, 0.88, true))
	panel.custom_minimum_size = Vector2(920, 0) if phone else Vector2(460, 0)
	col.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	panel.add_child(list)
	list.add_child(UIKit.body_label("本月 · 灰旗堡", UIKit.TEXT_DIM, 13))
	var target := UIKit.make_accent_button("出战编队", 860 if phone else 400)
	target.name = "Deploy"
	target.custom_minimum_size = Vector2(860 if phone else 400, 56 if phone else 48)
	list.add_child(target)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 168 if phone else 150)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(gap)
	var other := UIKit.make_button("花名册", 860 if phone else 400)
	other.custom_minimum_size = Vector2(860 if phone else 400, 52 if phone else 44)
	list.add_child(other)
	var other2 := UIKit.make_button("联姻廷", 860 if phone else 400)
	other2.custom_minimum_size = Vector2(860 if phone else 400, 52 if phone else 44)
	list.add_child(other2)
	if not phone:
		var rail := PanelContainer.new()
		rail.add_theme_stylebox_override("panel", UIKit.glass(16, 0.82, true))
		rail.position = Vector2(760, 120)
		rail.custom_minimum_size = Vector2(400, 0)
		root.add_child(rail)
		var rail_box := VBoxContainer.new()
		rail_box.add_theme_constant_override("separation", 8)
		rail.add_child(rail_box)
		rail_box.add_child(UIKit.eyebrow("ASH KEEP"))
		rail_box.add_child(UIKit.title_label("灰旗堡", 28))
		rail_box.add_child(UIKit.body_label("第 1 年 3 月", UIKit.TEXT, 16))
		rail_box.add_child(UIKit.body_label("银币 120    粮食 40", UIKit.TEXT_DIM, 14))
		rail_box.add_child(UIKit.body_label("士气平稳。灯引指着该做的下一件事。", UIKit.TEXT_DIM, 14))

	await get_tree().process_frame
	await get_tree().process_frame
	var coach := CKCoach.attach(root)
	coach.present_target(target, "先编排出战的人。同一次旅程里，灯引不会再亮。", safe)
	if phone:
		var foot := PanelContainer.new()
		foot.add_theme_stylebox_override("panel", UIKit.glass(14, 0.94, true))
		foot.position = Vector2(48, 1920 - 96 - 84)
		foot.custom_minimum_size = Vector2(984, 64)
		foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(foot)
		var foot_label := UIKit.body_label("安全区以内 · 点击任意处继续", UIKit.ACCENT, 15)
		foot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		foot.add_child(foot_label)
	await get_tree().process_frame
	await get_tree().process_frame
