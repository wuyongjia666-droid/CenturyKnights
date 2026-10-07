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

	# Full-rect CenterContainer: stays centered on any window/stretch size
	# (fixes PRESET_CENTER + hard-coded position "跑偏" on Windows export).
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := UIKit.make_label(Locale.t("game_title"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title)

	var sub := UIKit.make_label(Locale.t("subtitle"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_theme_color_override("font_color", UIKit.ACCENT)
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer)

	for item in [
		[Locale.t("menu_new"), Callable(self, "_on_new"), false],
		[Locale.t("menu_continue"), Callable(self, "_on_continue"), not GameState.has_save()],
		[Locale.t("menu_settings"), Callable(self, "_on_settings"), false],
		[Locale.t("menu_quit"), func(): get_tree().quit(), false],
	]:
		var b: Button = UIKit.make_button(item[0], 280)
		b.disabled = item[2]
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(item[1])
		box.add_child(b)

	var tip := UIKit.make_label("原创 IP · 第零章必玩 · Godot 4.3")
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.add_theme_font_size_override("font_size", 12)
	box.add_child(tip)

func _on_new() -> void:
	get_tree().change_scene_to_file("res://scenes/story/naming.tscn")

func _on_continue() -> void:
	if GameState.load_game():
		if GameState.flag("hub_open") or GameState.chapter0_beat >= "0.3":
			get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings.tscn")
