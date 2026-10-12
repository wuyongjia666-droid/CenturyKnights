extends Node
## Mobile landscape gate: renders key screens at phone resolutions with the
## project's real stretch settings and writes PNG + layout report JSON.
const SCREENS := [
	["title", "res://scenes/ui/main_menu.tscn"],
	["castle", "res://scenes/hub/castle_hub.tscn"],
	["roster", "res://scenes/hub/roster.tscn"],
	["tavern", "res://scenes/hub/tavern.tscn"],
	["marriage", "res://scenes/hub/marriage.tscn"],
	["lineage", "res://scenes/hub/lineage_view.tscn"],
	["atlas", "res://scenes/hub/atlas_view.tscn"],
	["city", "res://scenes/hub/city.tscn"],
	["battle", "res://scenes/battle/battle.tscn"],
	["settings", "res://scenes/ui/settings.tscn"],
]
const RES := [Vector2i(2400, 1080), Vector2i(2340, 1080), Vector2i(1920, 1080), Vector2i(2560, 1600)]
var _out := "/tmp/ck_mobile"
var _report := []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	if DisplayServer.get_name() == "headless":
		print("MOBILE PASS headless-skip")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(_out)

	GameState.new_game("Ash", "Banner", "#%02x%02x%02x" % [110, 212, 255])
	for r in RES:
		get_window().size = r
		await get_tree().process_frame
		await get_tree().process_frame
		for pair in SCREENS:
			await _shoot(str(pair[1]), "%s_%dx%d" % [pair[0], r.x, r.y])
	var f := FileAccess.open(_out + "/layout.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, " "))
	print("MOBILE DONE")
	get_tree().quit(0)

func _shoot(path: String, name: String) -> void:
	var packed = load(path)
	if packed == null:
		push_error("missing " + path)
		return
	var node = packed.instantiate()
	get_tree().root.add_child(node)
	get_tree().current_scene = node
	MobileChrome.call_deferred("_apply")
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	var vr := get_viewport().get_visible_rect()
	var items := []
	_root_scale = maxf(0.001, (node as CanvasItem).get_global_transform().get_scale().y) if node is CanvasItem else 1.0
	_collect(node, items, vr)
	_report.append({"shot": name, "viewport": [vr.size.x, vr.size.y], "items": items})
	get_tree().current_scene = self
	node.queue_free()
	await get_tree().process_frame

## Fonts are measured as drawn: a label inside a zoomed map counts at its on-screen size.
var _root_scale := 1.0


func _collect(n: Node, items: Array, vr: Rect2) -> void:
	if n is Control and n.is_visible_in_tree():
		var c: Control = n
		if c is BaseButton or c is Label or c is LineEdit:
			var r := c.get_global_rect()
			var txt := ""
			if c is Label or c is Button:
				txt = str(c.text)
			items.append({"type": c.get_class(), "path": str(c.get_path()), "text": txt.left(30),
				"rect": [r.position.x, r.position.y, r.size.x, r.size.y],
				"font": roundi(c.get_theme_font_size("font_size") * c.get_global_transform().get_scale().y / _root_scale), "in_scroll": _in_scroll(c)})
	for ch in n.get_children():
		_collect(ch, items, vr)

func _in_scroll(c: Node) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false
