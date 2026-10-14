extends Node
## Board-piece screenshots: battle board at desktop + mobile gate resolutions.
## args: --out=DIR [--before] [--map=ID]

func _ready() -> void:
	var out := "/tmp/ck_pawn"
	var before := false
	var map := "ch0_pass"
	var scene := "battle"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		if a == "--before": before = true
		if a.begins_with("--map="): map = a.substr(6)
		if a.begins_with("--scene="): scene = a.substr(8)
	if DisplayServer.get_name() == "headless":
		print("PAWN SHOTS headless-skip")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var res := [Vector2i(1280, 720)] if not DeviceProfile.is_mobile() else [Vector2i(2400, 1080), Vector2i(2340, 1080), Vector2i(1920, 1080), Vector2i(2560, 1600)]
	for r in res:
		GameState.new_game("Ash", "Banner", "#%02x%02x%02x" % [110, 212, 255])
		GameState.set_meta("battle_map", map)
		GameState.set_meta("cutscenes_on", false)
		GameState.settings["cutscenes"] = false
		get_window().size = r
		await get_tree().process_frame
		var node = load("res://scenes/battle/battle.tscn" if scene == "battle" else "res://scenes/hub/%s.tscn" % scene).instantiate()
		get_tree().root.add_child(node)
		get_tree().current_scene = node
		if before:
			var f = node.get_node_or_null("BoardFigures")
			if f: f.queue_free()
		if DeviceProfile.is_mobile():
			MobileChrome.call_deferred("_apply")
		await get_tree().create_timer(1.5).timeout
		if scene == "battle":
			node.map_draw.queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s_%dx%d.png" % [out, scene, "before" if before else "after", r.x, r.y])
		print("SHOT ", r)
		node.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
