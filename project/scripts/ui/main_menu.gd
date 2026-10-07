extends Control

func _ready() -> void:
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 氛围底纹：深色石砖感色块
	var left := ColorRect.new()
	left.color = UIKit.BG_DEEP
	left.set_anchors_preset(PRESET_LEFT_WIDE)
	left.offset_right = 280
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	var accent := ColorRect.new()
	accent.color = UIKit.ACCENT
	accent.position = Vector2(280, 0)
	accent.size = Vector2(4, 720)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)

	# 左侧大旗
	var big_banner := TextureRect.new()
	big_banner.texture = UnitArt.banner(180, 260, true)
	big_banner.position = Vector2(50, 180)
	big_banner.custom_minimum_size = Vector2(180, 260)
	big_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(big_banner)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := UIKit.make_label(Locale.t("game_title"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)

	var sub := UIKit.make_label(Locale.t("subtitle"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_theme_color_override("font_color", UIKit.ACCENT)
	box.add_child(sub)

	var flavor := UIKit.make_dim_label("战棋 · 城堡 · 联姻 · 传代——一面旗，要扛过百年。")
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(flavor)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	box.add_child(spacer)

	for item in [
		[Locale.t("menu_new"), Callable(self, "_on_new"), false],
		[Locale.t("menu_continue"), Callable(self, "_on_continue"), not GameState.has_save()],
		[Locale.t("menu_settings"), Callable(self, "_on_settings"), false],
		[Locale.t("menu_quit"), func(): get_tree().quit(), false],
	]:
		var b: Button = UIKit.make_accent_button(item[0], 300) if item[0] == Locale.t("menu_new") else UIKit.make_button(item[0], 300)
		b.disabled = item[2]
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(item[1])
		box.add_child(b)

	var tip := UIKit.make_dim_label("原创 IP · 第零章加长 · Godot 4.3")
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.add_theme_font_size_override("font_size", 12)
	box.add_child(tip)

func _on_new() -> void:
	get_tree().change_scene_to_file("res://scenes/story/naming.tscn")

func _on_continue() -> void:
	if GameState.load_game():
		UnitArt.clear_cache()
		if GameState.flag("hub_open") or GameState.chapter0_beat >= "0.3":
			get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings.tscn")
