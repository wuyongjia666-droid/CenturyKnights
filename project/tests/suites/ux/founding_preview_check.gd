extends Node
## Founding (建团) page: the flag/portrait preview and the raise button stay on screen
## after the options pane is scrolled to the bottom, and every option change repaints the flag.
## With a display and `-- --out=DIR` it also writes PNGs (top + scrolled) per size.
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1080, 1920)]
var _out := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	var shots := _out != "" and DisplayServer.get_name() != "headless"
	if shots:
		DirAccess.make_dir_recursive_absolute(_out)
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var errors: PackedStringArray = []
	for sz in SIZES:
		var host := Control.new()
		if shots:
			get_window().size = sz
			await get_tree().process_frame
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		else:
			host.size = Vector2(sz)
		add_child(host)
		var page = load("res://scenes/story/naming.tscn").instantiate()
		host.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for i in 4:
			await get_tree().process_frame
		var tag := "%dx%d" % [sz.x, sz.y]
		if shots:
			await _shot("founding_%s_top" % tag)
		var before: Texture2D = page._banner.texture
		var sc: ScrollContainer = page._scroll
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
		page._shift_enum("emblem", 1)  # an option at the bottom of the list
		for i in 3:
			await get_tree().process_frame
		if page._banner.texture == before:
			errors.append("%s banner did not repaint after option change" % tag)
		var view := Rect2(Vector2.ZERO, host.size)
		var rel := func(c: Control) -> Rect2: return Rect2(c.global_position - host.global_position, c.size)
		for pair in [["banner", page._banner], ["shield", page._shield], ["portrait", page._portrait], ["raise", page._start_btn], ["surname", page._surname]]:
			var r: Rect2 = rel.call(pair[1])
			if r.size.x < 40 or r.size.y < 40 or not view.grow(1).encloses(r):
				errors.append("%s %s off screen after scroll: %s in %s" % [tag, pair[0], r, view])
		if not page._pane.is_ancestor_of(page._banner) or page._scroll.is_ancestor_of(page._banner):
			errors.append("%s banner must live in the fixed pane" % tag)
		if shots:
			await _shot("founding_%s_scrolled" % tag)
		host.queue_free()
		await get_tree().process_frame
	if errors.is_empty():
		print("FOUNDING PREVIEW PASS")
	else:
		for e in errors:
			print("FAIL ", e)
	get_tree().quit(0 if errors.is_empty() else 1)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name)
