extends Control
## 制作人员、原创声明、字体许可。主菜单入口由 CORE-06 接线。

static func _fonts() -> Array:
	return [
	{
		"file": "NotoSansSC-Regular-ck.otf",
		"name": "Noto Sans CJK SC",
		"copy": "© 2014-2021 Adobe",
		"note": Locale.t("shell_3143c1c7"),
	},
	{
		"file": "NotoSansSC-Bold-ck.otf",
		"name": "Noto Sans CJK SC Bold",
		"copy": "© 2014-2021 Adobe",
		"note": Locale.t("shell_66136c41"),
	},
	{
		"file": "JetBrainsMono-Variable.ttf",
		"name": "JetBrains Mono",
		"copy": "© 2020 The JetBrains Mono Project Authors",
		"note": Locale.t("shell_5080eb2e"),
	},
]

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()

func _ready() -> void:
	UIKit.void_bg(self)
	UIKit.top_bar(self, _line("ux_credits_bar", Locale.t("shell_fd490f03")), [], Locale.t("shell_11d02415"), _back)
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
	box.add_child(UIKit.title_label(_line("ux_credits_title", Locale.t("shell_03ffa791")), 26))
	box.add_child(_body(_line("ux_credits_who", Locale.t("shell_f95ba58b"))))

	box.add_child(UIKit.eyebrow("ORIGINAL"))
	box.add_child(UIKit.make_label(_line("ux_credits_original_h", Locale.t("shell_355c3e55"))))
	box.add_child(_body(_line("ux_credits_original", Locale.t("shell_acd80e41"))))

	box.add_child(UIKit.eyebrow("FONTS"))
	box.add_child(UIKit.make_label(_line("ux_credits_fonts_h", Locale.t("shell_450a0438"))))
	for spec in _fonts():
		box.add_child(_font_row(spec))
	box.add_child(_body(_line("ux_credits_ofl", Locale.t("shell_6104cf16"))))

	var back_row := CenterContainer.new()
	back_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(back_row)
	var back = UIKit.make_accent_button(Locale.t("btn_back"), 200)
	back.custom_minimum_size = Vector2(200, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	back_row.add_child(back)
	UIKit.footer_bar(self, [["ESC", Locale.t("shell_11d02415")]], "CREDITS · FROST")

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
