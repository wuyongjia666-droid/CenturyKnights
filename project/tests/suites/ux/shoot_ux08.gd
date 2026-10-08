extends Node
## Portrait shots for UX-08. CK_SHOOT=castle|roster|lineage|codex|settings|pause
## CK_SHOOT_OUT=absolute png path. Not part of CI.

const _SCENES := {
	"castle": "res://scenes/hub/castle_hub.tscn",
	"roster": "res://scenes/hub/roster.tscn",
	"lineage": "res://scenes/hub/lineage_view.tscn",
	"codex": "res://scenes/hub/bloodline_codex.tscn",
	"settings": "res://scenes/ui/settings.tscn",
	"pause": "res://scenes/hub/castle_hub.tscn",
}

func _ready() -> void:
	var which := OS.get_environment("CK_SHOOT")
	if not _SCENES.has(which):
		which = "castle"
	var win := Vector2i(1080, 1920)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	DisplayServer.window_set_size(win)
	get_tree().root.size = win
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.new_game("霜行", "灰旗", GameState.crest_color)
	if GameState.settings is Dictionary:
		GameState.settings["tutorial_highlight"] = false
	var packed: PackedScene = load(str(_SCENES[which]))
	var node := packed.instantiate()
	add_child(node)
	if node is Control and which != "settings":
		var root := node as Control
		var insets := {"left": 0.0, "top": 48.0, "right": 0.0, "bottom": 36.0}
		root.set_meta("mobile_insets", insets)
		var fitted: Dictionary = MobileLayout.fit(Vector2(win), insets)
		MobileLayout.apply_root(root, fitted)
		if root.has_method("apply_mobile_layout"):
			root.apply_mobile_layout()
		MobileLayout.extend_portrait_lists(root)
		MobileLayout.ensure_hit_targets(root)
	elif node is Control:
		var settings := node as Control
		MobileLayout.fit_top_bar(settings, float(win.x))
		MobileLayout.ensure_hit_targets(settings, 44.0)
	if which == "pause":
		CKPauseMenu.toggle()
		MobileLayout.place_pause(CKPauseMenu.current, Vector2(win))
	for _i in 36:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_height() > 8 and img.get_pixel(4, 4).a < 0.01 and img.get_pixel(4, img.get_height() - 4).a > 0.5:
		img.flip_y()
	var path := OS.get_environment("CK_SHOOT_OUT")
	if path == "":
		path = "/tmp/ux08.png"
	var err := img.save_png(path)
	print("SHOOT %s %sx%s err=%s" % [path, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)
