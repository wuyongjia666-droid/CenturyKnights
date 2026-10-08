extends Node
## 手动出图。CK_SHOOT=settings|battle，CK_MODE=desktop|phone|deuteranopia|protanopia|tritanopia。

func _ready() -> void:
	GameState.settings["tutorial_highlight"] = false
	GameState.settings["tips_seen"] = {"settings_lamp": true, "menu_lamp": true}
	GameState.settings["ui_scale"] = 1.0
	var kind := OS.get_environment("CK_SHOOT")
	var mode := OS.get_environment("CK_MODE")
	var phone := mode == "phone"
	var win := Vector2i(1080, 1920) if phone else Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	get_tree().root.content_scale_factor = 1.0
	DisplayServer.window_set_size(win)
	get_tree().root.size = win
	await get_tree().process_frame
	await get_tree().process_frame
	if kind == "battle":
		_battle(mode)
	else:
		_settings()
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OS.get_environment("CK_SHOOT_OUT")
	if path == "":
		path = "/tmp/ux02.png"
	var err := img.save_png(path)
	print("SHOOT %s %sx%s err=%s" % [path, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)

func _settings() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.size = get_viewport().get_visible_rect().size
	add_child(host)
	GameState.settings["colorblind"] = "deuteranopia"
	GameState.settings["high_contrast"] = false
	var settings := (load("res://scenes/ui/settings.tscn") as PackedScene).instantiate()
	host.add_child(settings)

func _battle(mode: String) -> void:
	if mode == "":
		mode = "deuteranopia"
	GameState.settings["colorblind"] = mode
	Frost.apply_accessibility()
	var board = preload("res://scripts/ui/widgets/battle_swatch.gd").new()
	board.position = Vector2.ZERO
	board.size = get_viewport().get_visible_rect().size
	board.custom_minimum_size = board.size
	add_child(board)
	var hud: HBoxContainer = HBoxContainer.new()
	hud.position = Vector2(28, 16)
	hud.add_theme_constant_override("separation", 16)
	add_child(hud)
	var names := {
		"deuteranopia": "绿色弱",
		"protanopia": "红色弱",
		"tritanopia": "蓝色弱",
	}
	hud.add_child(UIKit.eyebrow("BATTLE"))
	hud.add_child(UIKit.title_label("我方回合 · %s" % names.get(mode, mode), 22))
	var ally := UIKit.faction_mark("player")
	var enemy := UIKit.faction_mark("enemy")
	hud.add_child(ally)
	hud.add_child(_tag("我军 · 圆"))
	hud.add_child(enemy)
	hud.add_child(_tag("敌军 · 三角"))

func _tag(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(96, 44)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UIKit.TEXT)
	return label
