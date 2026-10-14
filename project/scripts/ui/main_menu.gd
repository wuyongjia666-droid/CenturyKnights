extends Control
## v8.6 — Stitch 01_menu: full-bleed key art, editorial left column, indexed menu list, no banner/parchment.

var _msg: Label
var _loading := false

func _ready() -> void:
	# Any way back from a prologue replay (back key, menu) puts the real game back.
	GameState.end_prologue_replay()
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
	var art_path := CKArtPaths.resolve("res://assets/art/ui/hub_backdrop.png")
	for p in ["res://assets/art/ui/menu_backdrop.png", "res://assets/art/ui/castle_backdrop.png"]:
		var resolved := CKArtPaths.resolve(p)
		if CKArtPaths.exists(resolved):
			art_path = resolved
			break
	if CKArtPaths.exists(art_path):
		var art := TextureRect.new()
		art.texture = CKArtPaths.load_texture(art_path)
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
	col.position = Vector2(96, 76)  # desktop: 7 rows + summary must end above 720
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
		["03", "MenuReplay", Locale.t("menu_replay"), Callable(self, "_on_replay"), false],
		["04", "MenuLoad", Locale.t("menu_load"), Callable(self, "_on_load"), false],
		["05", "MenuSettings", Locale.t("menu_settings"), Callable(self, "_on_settings"), false],
		["06", "MenuCredits", Locale.t("menu_credits"), Callable(self, "_on_credits"), false],
		["07", "MenuQuit", Locale.t("menu_quit"), func(): get_tree().quit(), false],
	]
	var first: Button = null
	# Phones: 48dp buttons do not fit 7 rows in 720 logical px, so use a two-column grid,
	# drop Quit (Android leaves via Home) and the keyboard hint line.
	var mobile := DeviceProfile.is_mobile()
	var host: Container = col
	if mobile:
		col.position = Vector2(72, 28)
		items.pop_back()
		var grid := GridContainer.new()
		grid.name = "MenuGrid"
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		col.add_child(grid)
		host = grid
	for it in items:
		var b := UIKit.index_button(it[0], it[2], 360)
		b.name = it[1]
		b.disabled = it[4]
		b.pressed.connect(it[3])
		if it[0] == "01":
			b.add_theme_color_override("font_color", UIKit.ACCENT)
		host.add_child(b)
		if it[1] == "MenuContinue" and not mobile:
			var summary := UIKit.body_label(CKSaveSlots.continue_line(latest), UIKit.TEXT_DIM, 13)
			summary.name = "ContinueSummary"
			summary.custom_minimum_size = Vector2(360, 0)
			col.add_child(summary)
		if first == null and not b.disabled:
			first = b
	if mobile and latest != "":
		var msum := UIKit.body_label(CKSaveSlots.continue_line(latest), UIKit.TEXT_DIM, 13)
		msum.name = "ContinueSummary"
		col.add_child(msum)
	if first:
		first.call_deferred("grab_focus")

	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var foot_text := Locale.t("menu_footer_plain")
	if version != "":
		foot_text = Locale.t("menu_footer", [version])
	var foot := UIKit.body_label(foot_text, UIKit.TEXT_FAINT, 12)
	foot.name = "VersionLabel"
	foot.position = Vector2(880, 664)
	foot.size = Vector2(304, 20)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(foot)
	if not DeviceProfile.is_mobile():   # no keyboard hint on touch
		var keys := UIKit.body_label(Locale.t("shell_7af5bdc2"), UIKit.TEXT_FAINT, 12)
		keys.position = Vector2(984, 640)
		keys.size = Vector2(200, 20)
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(keys)
	_msg = UIKit.body_label("", UIKit.DANGER, 13)
	_msg.name = "MenuMsg"
	_msg.position = Vector2(96, 48)
	_msg.size = Vector2(600, 20)
	add_child(_msg)
	if mobile:
		foot.position = Vector2(72, 672)
		foot.size.y = 34.0
		foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		foot.add_theme_font_size_override("font_size", 22)
		# Two-column grid buttons must meet the phone hit floor (audit P2 title).
		var grid := col.get_node_or_null("MenuGrid")
		if grid:
			for child in grid.get_children():
				if child is BaseButton:
					(child as BaseButton).custom_minimum_size = Vector2(
						maxf((child as BaseButton).custom_minimum_size.x, 200.0),
						MobileLayout.HIT_FLOOR)
					(child as BaseButton).add_theme_font_size_override("font_size", 22)

func _on_new() -> void:
	CKNav.replace("res://scenes/story/naming.tscn")

func _on_replay() -> void:
	GameState.begin_prologue_replay()
	CKNav.replace("res://scenes/story/chapter0.tscn")

## Audit #9: a failed load says so; a second tap while loading does nothing.
func _on_continue() -> void:
	if _loading:
		return
	var slot := CKSaveSlots.latest_slot()
	if slot == "":
		_msg.text = Locale.t("menu_no_save")
		return
	_loading = true
	if GameState.load_from_slot(slot):
		CKSaveSlots.enter_loaded(get_tree())
		return
	_loading = false
	_msg.text = Locale.t("a1_menu_load_fail")
	Sfx.miss()

func _on_load() -> void:
	CKNav.go("res://scenes/ui/save_slots.tscn")

func _on_credits() -> void:
	CKNav.go("res://scenes/ui/credits.tscn")

func _on_settings() -> void:
	CKNav.go("res://scenes/ui/settings.tscn")
