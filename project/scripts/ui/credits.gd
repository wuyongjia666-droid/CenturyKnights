extends Control
## 制作人员、原创声明、字体许可。主菜单入口由 CORE-06 接线。

const _FONTS := [
	{
		"file": "NotoSansSC-Regular-ck.otf",
		"name": "Noto Sans CJK SC",
		"copy": "© 2014-2021 Adobe",
		"note": "SIL Open Font License 1.1。本仓库只带项目用到的子集。",
	},
	{
		"file": "NotoSansSC-Bold-ck.otf",
		"name": "Noto Sans CJK SC Bold",
		"copy": "© 2014-2021 Adobe",
		"note": "SIL Open Font License 1.1。粗体子集，许可与常规体相同。",
	},
	{
		"file": "JetBrainsMono-Variable.ttf",
		"name": "JetBrains Mono",
		"copy": "© 2020 The JetBrains Mono Project Authors",
		"note": "SIL Open Font License 1.1。用于数字与等宽读数。",
	},
]

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()

func _ready() -> void:
	UIKit.void_bg(self)
	UIKit.top_bar(self, _line("ux_credits_bar", "制作人员 · CREDITS"), [], "返回", _back)
	var vp := get_viewport_rect().size
	var column_w := minf(560.0, vp.x - 64.0)
	var side := maxf(24.0, (vp.x - column_w) * 0.5)
	var scroll := ScrollContainer.new()
	scroll.name = "CreditsScroll"
	scroll.position = Vector2(side, 72)
	scroll.size = Vector2(column_w, maxf(200.0, vp.y - 124.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	add_child(scroll)

	var box := VBoxContainer.new()
	box.name = "CreditsColumn"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(column_w, 0)
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	box.add_child(UIKit.eyebrow("PROJECT"))
	box.add_child(UIKit.title_label(_line("ux_credits_title", "百年骑士"), 26))
	box.add_child(_body(_line("ux_credits_who", "独立原创项目。本页只列仓库里真实在用的第三方字体，不编造职务名单。")))

	box.add_child(UIKit.eyebrow("ORIGINAL"))
	box.add_child(UIKit.make_label(_line("ux_credits_original_h", "原创声明")))
	box.add_child(_body(_line("ux_credits_original", "系统、文本、界面与代码均为本项目原创。对战棋类型的致敬只留在规则层，不收入其他作品的名称、角色、图像或音频。")))

	box.add_child(UIKit.eyebrow("FONTS"))
	box.add_child(UIKit.make_label(_line("ux_credits_fonts_h", "字体许可")))
	for spec in _FONTS:
		box.add_child(_font_row(spec))
	box.add_child(_body(_line("ux_credits_ofl", "三份字体均为 SIL Open Font License 1.1，说明见 docs/licenses.md。")))

	var back_row := CenterContainer.new()
	back_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(back_row)
	var back = UIKit.make_accent_button(Locale.t("btn_back"), 200)
	back.custom_minimum_size = Vector2(200, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	back_row.add_child(back)
	UIKit.footer_bar(self, [["ESC", "返回"]], "CREDITS · FROST")

func _font_row(spec: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var plate := UIKit.glass(12, 0.9, false)
	plate.content_margin_left = 14
	plate.content_margin_right = 14
	plate.content_margin_top = 8
	plate.content_margin_bottom = 8
	plate.shadow_size = 6
	plate.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", plate)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	var file := Label.new()
	file.text = str(spec["file"])
	file.autowrap_mode = TextServer.AUTOWRAP_OFF
	file.clip_text = false
	file.add_theme_font_override("font", UIKit.font("mono"))
	file.add_theme_font_size_override("font_size", 14)
	file.add_theme_color_override("font_color", UIKit.ACCENT)
	col.add_child(file)
	var meta := Label.new()
	meta.text = "%s · %s" % [str(spec["name"]), str(spec["copy"])]
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_font_size_override("font_size", 13)
	meta.add_theme_color_override("font_color", UIKit.TEXT)
	col.add_child(meta)
	var note := _body(str(spec["note"]))
	note.add_theme_font_size_override("font_size", 12)
	col.add_child(note)
	return panel

func _body(text: String) -> Label:
	var label := UIKit.body_label(text, UIKit.TEXT_DIM, 15)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _line(key: String, fallback: String) -> String:
	var s := Locale.t(key)
	if s == key or s == "":
		return fallback
	return s
