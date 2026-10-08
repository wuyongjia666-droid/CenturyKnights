extends Node
## UX-03 English shell screenshots. CK_MODE=desktop|phone, CK_SHOOT_DIR for pngs.

const SCENES := [
	["menu", "res://scenes/ui/main_menu.tscn"],
	["settings", "res://scenes/ui/settings.tscn"],
	["castle", "res://scenes/hub/castle_hub.tscn"],
	["battle", "res://scenes/battle/battle.tscn"],
]


func _ready() -> void:
	print("SHOOT begin")
	var phone := OS.get_environment("CK_MODE") == "phone"
	var tag := "phone" if phone else "desktop"
	var win := Vector2i(1080, 1920) if phone else Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	get_tree().root.content_scale_factor = 1.0
	DisplayServer.window_set_size(win)
	get_tree().root.size = win
	var out_dir := OS.get_environment("CK_SHOOT_DIR")
	if out_dir == "":
		out_dir = "/tmp"
	GameState.new_game("Ash", "Ash", GameState.crest_color)
	if GameState.settings is Dictionary:
		GameState.settings["tutorial_highlight"] = false
	Locale.set_lang("en")
	await get_tree().process_frame
	for pair in SCENES:
		await _shot(str(pair[0]), str(pair[1]), tag, out_dir)
	get_tree().quit(0)


func _shot(shot_name: String, path: String, tag: String, out_dir: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		print("SHOOT missing ", path)
		return
	var node := packed.instantiate()
	add_child(node)
	for _i in 20:
		await get_tree().process_frame
	RenderingServer.force_draw()
	var tex := get_viewport().get_texture()
	if tex == null:
		print("SHOOT no texture ", shot_name)
		return
	var img := tex.get_image()
	if img == null:
		print("SHOOT no image ", shot_name)
		return
	if img.get_height() > 8 and img.get_pixel(4, 4).a < 0.01 and img.get_pixel(4, img.get_height() - 4).a > 0.5:
		img.flip_y()
	var dest := "%s/ux03-%s-%s.png" % [out_dir, shot_name, tag]
	var err := img.save_png(dest)
	print("SHOOT %s %sx%s err=%s" % [dest, img.get_width(), img.get_height(), err])
	node.queue_free()
	await get_tree().process_frame
