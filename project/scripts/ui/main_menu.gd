extends Control
## v8.6 — Stitch 01_menu: full-bleed key art, editorial left column, indexed menu list, no banner/parchment.

func _ready() -> void:
	_build()
	UIFX.fade_in(self, 0.4)
	UIFX.page_enter(self)
	UIFX.wire_tree(self)
	Music.play_hub()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var art_path := "res://assets/art/ui/hub_backdrop.png"
	for p in ["res://assets/art/ui/menu_backdrop.png", "res://assets/art/ui/castle_backdrop.png"]:
		if ResourceLoader.exists(p):
			art_path = p
			break
	if ResourceLoader.exists(art_path):
		var art := TextureRect.new()
		art.texture = load(art_path)
		art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate = Color(0.78, 0.84, 0.95)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
	UIKit.side_veil(self, true, 0.68, 0.94)
	add_child(UIKit._vignette())

	var col := VBoxContainer.new()
	col.name = "MenuColumn"
	col.position = Vector2(96, 132)
	col.custom_minimum_size = Vector2(440, 0)
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	col.add_child(UIKit.eyebrow(Locale.t("shell_a683d75b")))
	var title := UIKit.title_label(Locale.t("game_title"), 56)
	col.add_child(title)
	var sub := UIKit.title_label(Locale.t("subtitle"), UIKit.SZ_HEADLINE, UIKit.ACCENT)
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap)
	col.add_child(UIKit.body_label(Locale.t("shell_0a5b0c2e"), UIKit.TEXT_DIM, 14))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 12)
	col.add_child(gap2)
	var line := UIKit.hairline()
	line.custom_minimum_size = Vector2(360, 1)
	col.add_child(line)
	var gap3 := Control.new()
	gap3.custom_minimum_size = Vector2(0, 14)
	col.add_child(gap3)

	var latest := CKSaveSlots.latest_slot()
	var items := [
		["01", "MenuNew", Locale.t("menu_new"), Callable(self, "_on_new"), false],
		["02", "MenuContinue", Locale.t("menu_continue"), Callable(self, "_on_continue"), latest == ""],
		["03", "MenuLoad", Locale.t("menu_load"), Callable(self, "_on_load"), false],
		["04", "MenuSettings", Locale.t("menu_settings"), Callable(self, "_on_settings"), false],
		["05", "MenuCredits", Locale.t("menu_credits"), Callable(self, "_on_credits"), false],
		["06", "MenuQuit", Locale.t("menu_quit"), func(): get_tree().quit(), false],
	]
	var first: Button = null
	for it in items:
		var b := UIKit.index_button(it[0], it[2], 360)
		b.name = it[1]
		b.disabled = it[4]
		b.pressed.connect(it[3])
		if it[0] == "01":
			b.add_theme_color_override("font_color", UIKit.ACCENT)
		col.add_child(b)
		if it[1] == "MenuContinue":
			var summary := UIKit.body_label(CKSaveSlots.continue_line(latest), UIKit.TEXT_DIM, 13)
			summary.name = "ContinueSummary"
			summary.custom_minimum_size = Vector2(360, 0)
			col.add_child(summary)
		if first == null and not b.disabled:
			first = b
	if first:
		first.call_deferred("grab_focus")

	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var foot_text := Locale.t("menu_footer_plain")
	if version != "":
		foot_text = Locale.t("menu_footer", [version])
	var foot := UIKit.body_label(foot_text, UIKit.TEXT_FAINT, 12)
	foot.name = "VersionLabel"
	foot.position = Vector2(96, 664)
	foot.size = Vector2(400, 20)
	add_child(foot)
	var keys := UIKit.body_label(Locale.t("shell_7af5bdc2"), UIKit.TEXT_FAINT, 12)
	keys.position = Vector2(984, 664)
	keys.size = Vector2(200, 20)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(keys)

func _on_new() -> void:
	get_tree().change_scene_to_file("res://scenes/story/naming.tscn")

func _on_continue() -> void:
	var slot := CKSaveSlots.latest_slot()
	if slot != "" and GameState.load_from_slot(slot):
		CKSaveSlots.enter_loaded(get_tree())

func _on_load() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/save_slots.tscn")

func _on_credits() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings.tscn")
