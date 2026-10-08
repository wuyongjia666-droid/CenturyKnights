extends Control

const CombatCutsceneScript = preload("res://scripts/battle/combat_cutscene.gd")
const BattleSwatchScript = preload("res://scripts/ui/widgets/battle_swatch.gd")

var _swatch: Control
var _scale_readout: Label

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
	UIKit.top_bar(self, Locale.t("shell_57ea9dbf"), [], Locale.t("shell_11d02415"), _back)
	var vp := get_viewport_rect().size
	var column_w := minf(520.0, vp.x - 64.0)
	var side := maxf(24.0, (vp.x - column_w) * 0.5)
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.position = Vector2(side, 72)
	scroll.size = Vector2(column_w, maxf(200.0, vp.y - 124.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	add_child(scroll)

	var box := VBoxContainer.new()
	box.name = "SettingsColumn"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(column_w, 0)
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	box.add_child(UIKit.eyebrow("ACCESS"))
	box.add_child(UIKit.make_label(Locale.t("shell_language")))
	var lang_row := HBoxContainer.new()
	lang_row.name = "LanguageRow"
	lang_row.add_theme_constant_override("separation", 8)
	var zh_b := UIKit.make_button(Locale.t("shell_lang_zh"), 140)
	var en_b := UIKit.make_button(Locale.t("shell_lang_en"), 140)
	zh_b.pressed.connect(func():
		Locale.set_lang("zh_CN")
		get_tree().reload_current_scene())
	en_b.pressed.connect(func():
		Locale.set_lang("en")
		get_tree().reload_current_scene())
	lang_row.add_child(zh_b)
	lang_row.add_child(en_b)
	box.add_child(lang_row)
	box.add_child(UIKit.make_label(_line("ux_scale", Locale.t("shell_7fec9db5"))))
	var scale := HSlider.new()
	scale.name = "UiScale"
	scale.min_value = 0.9
	scale.max_value = 1.4
	scale.step = 0.1
	scale.value = Frost.ui_scale()
	scale.custom_minimum_size = Vector2(0, 44)
	scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_readout = UIKit.body_label("%d%%" % int(round(Frost.ui_scale() * 100.0)), UIKit.ACCENT, 14)
	scale.value_changed.connect(func(v):
		GameState.settings["ui_scale"] = v
		_scale_readout.text = "%d%%" % int(round(float(v) * 100.0))
		Frost.apply_accessibility()
	)
	box.add_child(scale)
	box.add_child(_scale_readout)

	box.add_child(UIKit.make_label(_line("ux_colorblind", Locale.t("shell_f406bde1"))))
	var modes := OptionButton.new()
	modes.name = "Colorblind"
	modes.custom_minimum_size = Vector2(0, 44)
	modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids := [
		["none", _line("ux_cb_none", Locale.t("shell_06eba986"))],
		["deuteranopia", _line("ux_cb_deutan", Locale.t("shell_dd5eb2b4"))],
		["protanopia", _line("ux_cb_protan", Locale.t("shell_181e100b"))],
		["tritanopia", _line("ux_cb_tritan", Locale.t("shell_8391fd27"))],
	]
	var current := Frost.mode()
	var select := 0
	for i in ids.size():
		modes.add_item(ids[i][1], i)
		modes.set_item_metadata(i, ids[i][0])
		if ids[i][0] == current:
			select = i
	modes.selected = select
	modes.item_selected.connect(func(idx):
		GameState.settings["colorblind"] = str(modes.get_item_metadata(idx))
		_refresh_palette()
	)
	box.add_child(modes)
	box.add_child(_check(_line("ux_contrast", Locale.t("shell_f7c782f3")), Frost.high_contrast(), func(on):
		GameState.settings["high_contrast"] = on
		_refresh_palette()
	))

	box.add_child(UIKit.make_label(_line("ux_preview", Locale.t("shell_d2cf4e81"))))
	var preview_row := HBoxContainer.new()
	preview_row.name = "FactionPreview"
	preview_row.add_theme_constant_override("separation", 18)
	box.add_child(preview_row)
	preview_row.add_child(_token("player", _line("ux_ally", Locale.t("shell_c832b9ce"))))
	preview_row.add_child(_token("enemy", _line("ux_enemy", Locale.t("shell_f4069c8b"))))
	_swatch = BattleSwatchScript.new()
	_swatch.name = "BattleSwatch"
	_swatch.custom_minimum_size = Vector2(0, 150)
	_swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_swatch)

	box.add_child(UIKit.make_label(_line("ux_shake", Locale.t("shell_2336506f"))))
	var shake := HSlider.new()
	shake.name = "ScreenShake"
	shake.min_value = 0
	shake.max_value = 100
	shake.step = 5
	shake.value = float(GameState.settings.get("screen_shake", 100))
	shake.custom_minimum_size = Vector2(0, 44)
	shake.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shake.value_changed.connect(func(v): GameState.settings["screen_shake"] = v)
	box.add_child(shake)
	box.add_child(_check(_line("ux_haptics", Locale.t("shell_d678bca7")), Frost.haptics_enabled(), func(on):
		GameState.settings["haptics"] = on
	))

	box.add_child(UIKit.hairline(UIKit.STROKE, 1.0))
	box.add_child(_check(Locale.t("shell_0c5cbf76"), bool(GameState.settings.get("rules_preview", true)), func(on):
		GameState.settings["rules_preview"] = on
		BattleRules.preview_enabled = on
	))
	var highlight := _check(Locale.t("shell_73266386"), bool(GameState.settings.get("tutorial_highlight", true)), func(on):
		GameState.settings["tutorial_highlight"] = on
	)
	highlight.name = "TutorialHighlight"
	box.add_child(highlight)
	var codex := UIKit.make_button(Locale.t("ux_codex_open"), 220)
	codex.name = "OpenCodex"
	codex.custom_minimum_size = Vector2(220, 44)
	codex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	codex.pressed.connect(func(): CKHelpCodex.open(self))
	box.add_child(codex)

	box.add_child(UIKit.make_label(Locale.t("shell_0511f605")))
	var speed = HSlider.new()
	speed.min_value = 0.5
	speed.max_value = 2.0
	speed.step = 0.25
	speed.value = GameState.settings.get("text_speed", 1.0)
	speed.custom_minimum_size = Vector2(0, 44)
	speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed.value_changed.connect(func(v): GameState.settings["text_speed"] = v)
	box.add_child(speed)
	box.add_child(_check(Locale.t("shell_32953e9c"), Music.enabled if Music else true, func(on):
		Music.enabled = on
		if on:
			Music.play_hub()
		else:
			Music.stop()
	))
	box.add_child(_check(Locale.t("shell_505e64c2"), Sfx.enabled, func(on): Sfx.enabled = on))
	box.add_child(_check(Locale.t("shell_52f3174e"), bool(GameState.settings.get("cutscenes", true)), func(on):
		GameState.settings["cutscenes"] = on
	))
	box.add_child(_check(Locale.t("shell_8c33eefe"), float(GameState.settings.get("cutscene_speed", 1.0)) >= 2.0, func(on):
		GameState.settings["cutscene_speed"] = 2.0 if on else 1.0
		CombatCutsceneScript.speed = 2.0 if on else 1.0
	))
	box.add_child(_check(Locale.t("shell_3c10b27c"), bool(GameState.settings.get("reduced_motion", false)), func(on):
		GameState.settings["reduced_motion"] = on
	))
	var note = UIKit.make_dim_label(Locale.t("shell_291459bc"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(0, 0)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_theme_font_size_override("font_size", 12)
	box.add_child(note)

	var back_row := CenterContainer.new()
	back_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(back_row)
	var back = UIKit.make_accent_button(Locale.t("btn_back"), 200)
	back.custom_minimum_size = Vector2(200, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	back_row.add_child(back)
	UIKit.footer_bar(self, [["A", Locale.t("shell_2f116b7d")], ["ESC", Locale.t("shell_11d02415")]], "SETTINGS · FROST")
	UIFX.wire_tree(self)

func _check(text: String, on: bool, cb: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.text = text
	button.button_pressed = on
	button.custom_minimum_size = Vector2(0, 44)
	button.toggled.connect(cb)
	return button

func _token(team: String, caption: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var mark := UIKit.faction_mark(team)
	mark.custom_minimum_size = Vector2(44, 44)
	col.add_child(mark)
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(64, 18)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	col.add_child(label)
	return col

func _refresh_palette() -> void:
	Frost.apply_accessibility()
	if _swatch:
		_swatch.queue_redraw()
	var preview := find_child("FactionPreview", true, false)
	if preview:
		for mark in preview.find_children("*", "Control", true, false):
			if mark.get("team") != null:
				(mark as CanvasItem).queue_redraw()

func _line(key: String, fallback: String) -> String:
	var s := Locale.t(key)
	if s == key or s == "":
		return fallback
	return s
