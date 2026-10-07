extends Control

func _ready() -> void:
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(PRESET_CENTER)
	center.position = Vector2(440, 160)
	center.custom_minimum_size = Vector2(400, 400)
	center.add_theme_constant_override("separation", 14)
	add_child(center)

	var title := UIKit.make_label(Locale.t("game_title"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)
	var sub := UIKit.make_label(Locale.t("subtitle"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", UIKit.ACCENT)
	center.add_child(sub)
	center.add_child(Control.new())

	var b_new = UIKit.make_button(Locale.t("menu_new"), 280)
	b_new.pressed.connect(_on_new)
	center.add_child(b_new)

	var b_cont = UIKit.make_button(Locale.t("menu_continue"), 280)
	b_cont.disabled = not GameState.has_save()
	b_cont.pressed.connect(_on_continue)
	center.add_child(b_cont)

	var b_set = UIKit.make_button(Locale.t("menu_settings"), 280)
	b_set.pressed.connect(_on_settings)
	center.add_child(b_set)

	var b_quit = UIKit.make_button(Locale.t("menu_quit"), 280)
	b_quit.pressed.connect(func(): get_tree().quit())
	center.add_child(b_quit)

	var tip := UIKit.make_label("原创 IP · 第零章必玩 · Godot 4.3")
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 12)
	center.add_child(tip)

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
