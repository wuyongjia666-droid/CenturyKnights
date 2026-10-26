extends Control

const CombatCutsceneScript = preload("res://scripts/battle/combat_cutscene.gd")
const BattleSwatchScript = preload("res://scripts/ui/widgets/battle_swatch.gd")

var _swatch: Control
var _scale_readout: Label

const MobileReflow := preload("res://scripts/platform/mobile_reflow.gd")


func _back() -> void:
	if GameState.started:
		CKNav.up()
	else:
		CKNav.replace(CKNav.TITLE)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()

func _ready() -> void:
	## Audit #11: two columns of groups (画面 / 动效 / 声音 / 战斗 / 操作与帮助) instead of one narrow strip.
	UIKit.void_bg(self)
	UIKit.top_bar(self, Locale.t("shell_57ea9dbf"), [], Locale.t("shell_11d02415"), _back)
	_place_shell_crests()
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.position = Vector2(32, 68)
	scroll.size = Vector2(1216, 612 if not DeviceProfile.is_mobile() else 644)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	add_child(scroll)
	var cols := HBoxContainer.new()
	cols.name = "SettingsColumns"
	cols.add_theme_constant_override("separation", 32)
	scroll.add_child(cols)
	var left := _column(cols, "SettingsColumn")
	var right := _column(cols, "SettingsColumnRight")

	var view := _group(left, "a1_set_view")
	view.add_child(UIKit.make_label(Locale.t("shell_language")))
	var lang_row := HBoxContainer.new()
	lang_row.name = "LanguageRow"
	lang_row.add_theme_constant_override("separation", 8)
	var zh_b := UIKit.make_button(Locale.t("shell_lang_zh"), 140)
	var en_b := UIKit.make_button(Locale.t("shell_lang_en"), 140)
	for b in [zh_b, en_b]:
		b.custom_minimum_size = Vector2(140, 48)
	UIKit.mark_choice(zh_b, Locale.lang == "zh_CN")
	UIKit.mark_choice(en_b, Locale.lang.begins_with("en"))
	zh_b.pressed.connect(func():
		if Locale.lang == "zh_CN":
			UIKit.mark_choice(zh_b, true)
			return
		Locale.set_lang("zh_CN")
		get_tree().reload_current_scene())
	en_b.pressed.connect(func():
		if Locale.lang.begins_with("en"):
			UIKit.mark_choice(en_b, true)
			return
		Locale.set_lang("en")
		get_tree().reload_current_scene())
	lang_row.add_child(zh_b)
	lang_row.add_child(en_b)
	view.add_child(lang_row)
	_scale_readout = UIKit.body_label("%d%%" % int(round(Frost.ui_scale() * 100.0)), UIKit.ACCENT, 14)
	var scale := _slider(view, "UiScale", _line("ux_scale", Locale.t("shell_7fec9db5")), 0.9, 1.4, 0.1, Frost.ui_scale(), func(v):
		GameState.settings["ui_scale"] = v
		_scale_readout.text = "%d%%" % int(round(float(v) * 100.0))
		Frost.apply_accessibility())
	_scale_readout.custom_minimum_size = Vector2(56, 0)
	_scale_readout.autowrap_mode = TextServer.AUTOWRAP_OFF
	scale.get_parent().add_child(_scale_readout)
	view.add_child(UIKit.make_label(_line("ux_colorblind", Locale.t("shell_f406bde1"))))
	var modes := OptionButton.new()
	modes.name = "Colorblind"
	modes.custom_minimum_size = Vector2(0, 48)
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
	view.add_child(modes)
	view.add_child(_check(_line("ux_contrast", Locale.t("shell_f7c782f3")), Frost.high_contrast(), func(on):
		GameState.settings["high_contrast"] = on
		_refresh_palette()
	))
	view.add_child(UIKit.make_label(_line("ux_preview", Locale.t("shell_d2cf4e81"))))
	var preview_row := HBoxContainer.new()
	preview_row.name = "FactionPreview"
	preview_row.add_theme_constant_override("separation", 18)
	view.add_child(preview_row)
	preview_row.add_child(_token("player", _line("ux_ally", Locale.t("shell_c832b9ce"))))
	preview_row.add_child(_token("enemy", _line("ux_enemy", Locale.t("shell_f4069c8b"))))
	_swatch = BattleSwatchScript.new()
	_swatch.name = "BattleSwatch"
	_swatch.custom_minimum_size = Vector2(0, 150)
	_swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.add_child(_swatch)

	var motion := _group(left, "a1_set_motion")
	motion.add_child(_check(Locale.t("shell_3c10b27c"), bool(GameState.settings.get("reduced_motion", false)), func(on):
		GameState.settings["reduced_motion"] = on
	))
	_slider(motion, "ScreenShake", _line("ux_shake", Locale.t("shell_2336506f")), 0, 100, 5, float(GameState.settings.get("screen_shake", 100)), func(v):
		GameState.settings["screen_shake"] = v)
	motion.add_child(_check(_line("ux_haptics", Locale.t("shell_d678bca7")), Frost.haptics_enabled(), func(on):
		GameState.settings["haptics"] = on
	))
	motion.add_child(_check(Locale.t("set_board_3d"), bool(GameState.settings.get("board_units_3d", CKUnitLayer3D.default_on())), func(on):
		GameState.settings["board_units_3d"] = on
	))

	var sound := _group(right, "a1_set_sound")
	for bus in [["Master", "a1_vol_master"], ["Music", "a1_vol_music"], ["SFX", "a1_vol_sfx"]]:
		var bus_name := str(bus[0])
		_slider(sound, "Vol" + bus_name, Locale.t(str(bus[1])), 0.0, 1.0, 0.05, Music.get_bus_volume(bus_name), func(v):
			Music.set_bus_volume(bus_name, float(v)))
	sound.add_child(_check(Locale.t("shell_32953e9c"), Music.enabled if Music else true, func(on):
		Music.enabled = on
		if on:
			Music.play_hub()
		else:
			Music.stop()
	))
	sound.add_child(_check(Locale.t("shell_505e64c2"), Sfx.enabled, func(on): Sfx.enabled = on))

	var battle := _group(right, "a1_set_battle")
	battle.add_child(UIKit.make_label(Locale.t("a1_anim")))
	var anim := OptionButton.new()
	anim.name = "BattleAnim"
	anim.custom_minimum_size = Vector2(0, 48)
	anim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for m in [["full", "a1_anim_full"], ["key", "a1_anim_key"], ["off", "a1_anim_off"]]:
		anim.add_item(Locale.t(str(m[1])))
		anim.set_item_metadata(anim.item_count - 1, str(m[0]))
	anim.selected = ["full", "key", "off"].find(anim_mode())
	anim.item_selected.connect(func(idx): set_anim_mode(str(anim.get_item_metadata(idx))))
	battle.add_child(anim)
	battle.add_child(_check(Locale.t("shell_8c33eefe"), float(GameState.settings.get("cutscene_speed", 1.0)) >= 2.0, func(on):
		GameState.settings["cutscene_speed"] = 2.0 if on else 1.0
		CombatCutsceneScript.speed = 2.0 if on else 1.0
	))
	battle.add_child(_check(Locale.t("shell_0c5cbf76"), bool(GameState.settings.get("rules_preview", true)), func(on):
		GameState.settings["rules_preview"] = on
		BattleRules.preview_enabled = on
	))
	battle.add_child(_check(Locale.t("ux_touch_confirm"), bool(GameState.settings.get("touch_confirm", DeviceProfile.is_mobile())), func(on):
		GameState.settings["touch_confirm"] = on
	))
	battle.add_child(_check(Locale.t("ux_touch_drag_commit"), bool(GameState.settings.get("touch_drag_commit", DeviceProfile.is_mobile())), func(on):
		GameState.settings["touch_drag_commit"] = on
	))

	var help := _group(right, "a1_set_help")
	if not DeviceProfile.is_mobile():
		help.add_child(_check(Locale.t("ux_nav_right_back"), bool(GameState.settings.get("nav_right_back", true)), func(on):
			GameState.settings["nav_right_back"] = on
		))
	var highlight := _check(Locale.t("shell_73266386"), bool(GameState.settings.get("tutorial_highlight", true)), func(on):
		GameState.settings["tutorial_highlight"] = on
	)
	highlight.name = "TutorialHighlight"
	help.add_child(highlight)
	help.add_child(_check(Locale.t("fertility_setting"), CKFamilyState.fast_family(GameState), func(on):
		CKFamilyState.set_fast_family(GameState, on)))
	_slider(help, "TextSpeed", Locale.t("shell_0511f605"), 0.5, 2.0, 0.25, float(GameState.settings.get("text_speed", 1.0)), func(v):
		GameState.settings["text_speed"] = v)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	help.add_child(btns)
	var codex := UIKit.make_button(Locale.t("ux_codex_open"), 200)
	codex.name = "OpenCodex"
	codex.custom_minimum_size = Vector2(200, 48)
	codex.pressed.connect(func(): CKHelpCodex.open(self))
	btns.add_child(codex)
	var guide := UIKit.make_button(Locale.t("ux_help_open"), 200)
	guide.name = "OpenGuide"
	guide.custom_minimum_size = Vector2(200, 48)
	guide.pressed.connect(func(): CKHelpCodex.open(self, true))
	btns.add_child(guide)
	var note = UIKit.make_dim_label(Locale.t("shell_291459bc"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_theme_font_size_override("font_size", 12)
	help.add_child(note)
	if not DeviceProfile.is_mobile():
		UIKit.footer_bar(self, [["A", Locale.t("shell_2f116b7d")], ["ESC", Locale.t("shell_11d02415")]], "SETTINGS · FROST")
	_mobile_layout(scroll, cols)
	UIFX.wire_tree(self)


## Landscape phone: 76px top bar, the two columns fill the width, 22px text, 76px controls.
func _mobile_layout(scroll: ScrollContainer, cols: HBoxContainer) -> void:
	if not MobilePage.active(self):
		return
	var vp := get_viewport().get_visible_rect().size
	var w := maxf(1280.0, vp.x * 720.0 / maxf(1.0, vp.y))
	MobilePage.top_bar(self, Locale.t("shell_57ea9dbf"), "", [[Locale.t("shell_11d02415"), _back]])
	_place_shell_crests()
	scroll.position = Vector2(24, MobilePage.TOP + 4.0)
	scroll.size = Vector2(w - 48.0, 720.0 - MobilePage.TOP - 16.0)
	var cw := (w - 48.0 - 32.0 - 16.0) * 0.5
	for c in cols.get_children():
		(c as Control).custom_minimum_size = Vector2(cw, 0)
		MobileReflow.grow(c, cw - 32.0)
	for sl in cols.find_children("*", "HSlider", true, false):
		(sl as Control).custom_minimum_size.y = MobilePage.HIT

func _place_shell_crests() -> void:
	## Settings chrome: ShellCrestStrip (团徽+旗徽) under the top bar.
	var mob := DeviceProfile.is_mobile()
	var hdr := Vector2(40, 48) if not mob else Vector2(36, 44)
	var ban := Vector2(26, 36) if not mob else Vector2(22, 30)
	CKHeraldryChrome.place_shell_crest_strip(self, Vector2(1120, 8) if not mob else Vector2(1120, 4), hdr, ban)
	CKHeraldryField.place_company_header(self, Vector2(1180, 8) if not mob else Vector2(1180, 4), hdr)

static func anim_mode() -> String:
	var m := str(GameState.settings.get("cutscene_mode", ""))
	if m in ["full", "key", "off"]:
		return m
	return "full" if bool(GameState.settings.get("cutscenes", true)) else "off"

## 开 / 只看暴击和击杀 / 关. "off" also clears the legacy bool the battle controller reads.
static func set_anim_mode(m: String) -> void:
	if not m in ["full", "key", "off"]:
		m = "full"
	GameState.settings["cutscene_mode"] = m
	GameState.settings["cutscenes"] = m != "off"

func _column(parent: Control, n: String) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.name = n
	c.custom_minimum_size = Vector2(592, 0)
	c.add_theme_constant_override("separation", 14)
	parent.add_child(c)
	return c

func _group(col: VBoxContainer, title_key: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.name = "Group_" + title_key
	var st := UIKit.flat_box(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.08), 10)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 12
	st.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", st)
	col.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UIKit.title_label(Locale.t(title_key), 17, UIKit.ACCENT))
	return v

func _slider(parent: Control, n: String, label: String, lo: float, hi: float, step: float, val: float, cb: Callable) -> HSlider:
	parent.add_child(UIKit.make_label(label))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var sl := HSlider.new()
	sl.name = n
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = val
	sl.custom_minimum_size = Vector2(0, 48)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(cb)
	row.add_child(sl)
	return sl

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
