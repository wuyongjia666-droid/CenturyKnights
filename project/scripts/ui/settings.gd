extends Control

const CombatCutsceneScript = preload("res://scripts/battle/combat_cutscene.gd")

func _back() -> void:
	if GameState.started:
		get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()

func _ready() -> void:
	## v8.6 Stitch 23 tokens: ink void · top bar · centred frosted settings column
	UIKit.void_bg(self)
	UIKit.top_bar(self, "设置 · SETTINGS", [], "返回", _back)
	UIKit.panel_at(self, Rect2(390, 84, 500, 580), 14)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
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

	var mus = CheckButton.new()
	mus.text = "背景音乐（程序氛围床）"
	mus.button_pressed = Music.enabled if Music else true
	mus.toggled.connect(func(on):
		Music.enabled = on
		if on: Music.play_hub()
		else: Music.stop()
	)
	box.add_child(mus)
	var sfxb = CheckButton.new()
	sfxb.text = "音效"
	sfxb.button_pressed = Sfx.enabled
	sfxb.toggled.connect(func(on): Sfx.enabled = on)
	box.add_child(sfxb)
	var cut = CheckButton.new()
	cut.text = "3D 战斗演出（攻击时播放；Space 跳过 · Tab 倍速）"
	cut.button_pressed = bool(GameState.settings.get("cutscenes", true))
	cut.toggled.connect(func(on): GameState.settings["cutscenes"] = on)
	box.add_child(cut)
	var cspd = CheckButton.new()
	cspd.text = "战斗演出默认 2× 倍速"
	cspd.button_pressed = float(GameState.settings.get("cutscene_speed", 1.0)) >= 2.0
	cspd.toggled.connect(func(on):
		GameState.settings["cutscene_speed"] = 2.0 if on else 1.0
		CombatCutsceneScript.speed = 2.0 if on else 1.0)
	box.add_child(cspd)
	var reduced = CheckButton.new()
	reduced.text = "减动效（缩短入场/呼吸）"
	reduced.button_pressed = bool(GameState.settings.get("reduced_motion", false))
	reduced.toggled.connect(func(on): GameState.settings["reduced_motion"] = on)
	box.add_child(reduced)
	var note = UIKit.make_dim_label("音频均为程序生成 WAV，无第三方曲库版权风险。动效遵循 Active Theory：短按压、错落入场、可关呼吸。")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(440, 0)
	note.add_theme_font_size_override("font_size", 12)
	box.add_child(note)

	var back = UIKit.make_accent_button(Locale.t("btn_back"), 200)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	box.add_child(back)
	UIKit.footer_bar(self, [["A", "切换"], ["ESC", "返回"]], "SETTINGS · FROST_TACTICAL v8.6")
	UIFX.wire_tree(self)
	UIFX.stagger_children(box, 0.035, 0.22)
