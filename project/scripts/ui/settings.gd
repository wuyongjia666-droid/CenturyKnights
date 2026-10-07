extends Control

func _ready() -> void:
	UIKit.make_screen_bg(self)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := UIKit.make_label("设置", true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title)

	var preview = CheckButton.new()
	preview.text = "战斗规则透视（命中/伤害区间）"
	preview.button_pressed = GameState.settings.get("rules_preview", true)
	preview.toggled.connect(func(on):
		GameState.settings["rules_preview"] = on
		BattleRules.preview_enabled = on
	)
	box.add_child(preview)

	var highlight = CheckButton.new()
	highlight.text = "新手高亮指引"
	highlight.button_pressed = GameState.settings.get("tutorial_highlight", true)
	highlight.toggled.connect(func(on): GameState.settings["tutorial_highlight"] = on)
	box.add_child(highlight)

	box.add_child(UIKit.make_label("文字速度"))
	var speed = HSlider.new()
	speed.min_value = 0.5
	speed.max_value = 2.0
	speed.step = 0.25
	speed.value = GameState.settings.get("text_speed", 1.0)
	speed.custom_minimum_size = Vector2(280, 24)
	speed.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	speed.value_changed.connect(func(v): GameState.settings["text_speed"] = v)
	box.add_child(speed)

	box.add_child(UIKit.make_dim_label("音频：程序短音效占位（无第三方曲库版权风险）。"))

	var back = UIKit.make_button(Locale.t("btn_back"), 200)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func():
		if GameState.started:
			get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	box.add_child(back)
