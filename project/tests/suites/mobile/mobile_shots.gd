extends Node
## Mobile landscape gate: renders key screens at phone resolutions with the
## project's real stretch settings and writes PNG + layout report JSON.
const SCREENS := [
	["title", "res://scenes/ui/main_menu.tscn"],
	["castle", "res://scenes/hub/castle_hub.tscn", "military", "hub_tab"],
	["castle_family", "res://scenes/hub/castle_hub.tscn", "family", "hub_tab"],
	["castle_civil", "res://scenes/hub/castle_hub.tscn", "civil", "hub_tab"],
	["roster", "res://scenes/hub/roster.tscn"],
	["tavern", "res://scenes/hub/tavern.tscn"],
	["marriage", "res://scenes/hub/marriage.tscn"],
	["marriage_wed", "res://scenes/hub/marriage.tscn", null, "", {"wed": true}],
	["lineage", "res://scenes/hub/lineage_view.tscn"],
	["wing_works", "res://scenes/hub/works.tscn"],
	["wing_annex_academy", "res://scenes/hub/annex.tscn", null, "", {"annex": "academy"}],
	["wing_annex_embassy", "res://scenes/hub/annex.tscn", null, "", {"annex": "embassy"}],
	["wing_annex_infirmary", "res://scenes/hub/annex.tscn", null, "", {"annex": "infirmary"}],
	["wing_annex_treasury", "res://scenes/hub/annex.tscn", null, "", {"annex": "treasury"}],
	["wing_forge", "res://scenes/hub/forge.tscn"],
	["wing_estates", "res://scenes/hub/estates.tscn"],
	["wing_market", "res://scenes/hub/market.tscn"],
	["atlas", "res://scenes/hub/atlas_view.tscn"],
	["atlas_side", "res://scenes/hub/atlas_view.tscn", true, "atlas_open_side"],
	["atlas_capital", "res://scenes/hub/atlas_view.tscn", true, "atlas_open_side", {"world_pos": "ash_capital"}],
	["atlas_log", "res://scenes/hub/atlas_view.tscn", "log", "atlas_sheet_tab", {"world_pos": "ash_capital"}],
	["atlas_regions", "res://scenes/hub/atlas_view.tscn", "regions", "atlas_sheet_tab", {"world_pos": "ash_capital"}],
	["city", "res://scenes/hub/city.tscn", null, "", {"world_pos": "ash_capital"}],
	["city_smith", "res://scenes/hub/city.tscn", "smith", "city_tab", {"world_pos": "ash_capital"}],
	["city_market", "res://scenes/hub/city.tscn", "market", "city_tab", {"world_pos": "ash_capital"}],
	["city_board", "res://scenes/hub/city.tscn", "board", "city_tab", {"world_pos": "ash_capital"}],
	["city_tavern", "res://scenes/hub/city.tscn", "tavern", "city_tab", {"world_pos": "ash_capital"}],
	["city_armory", "res://scenes/hub/city.tscn", "armory", "city_tab", {"world_pos": "ash_capital"}],
	["city_sundry", "res://scenes/hub/city.tscn", "sundry", "city_tab", {"world_pos": "ash_capital"}],
	["city_lamp", "res://scenes/hub/city.tscn", "lamp", "city_tab", {"world_pos": "ash_capital"}],
	["city_castle", "res://scenes/hub/city.tscn"],
	["battle", "res://scenes/battle/battle.tscn"],
	["settings", "res://scenes/ui/settings.tscn"],
	["founding", "res://scenes/story/naming.tscn"],
	["dialogue", "res://scenes/story/chapter0.tscn"],
]
## Desktop gate (--desktop): mouse input, no mobile reflow, PC resolutions.
const DESKTOP_EXTRA := [
	["panorama", "res://scenes/hub/castle_view.tscn"],
	["annex_infirmary", "res://scenes/hub/annex.tscn", null, "", {"annex": "infirmary"}],
	["annex_academy", "res://scenes/hub/annex.tscn", null, "", {"annex": "academy"}],
	["annex_treasury", "res://scenes/hub/annex.tscn", null, "", {"annex": "treasury"}],
	["annex_embassy", "res://scenes/hub/annex.tscn", null, "", {"annex": "embassy"}],
	["works", "res://scenes/hub/works.tscn"],
	["load", "res://scenes/ui/save_slots.tscn"],
]
const RES := [Vector2i(2400, 1080), Vector2i(2340, 1080), Vector2i(1920, 1080), Vector2i(2560, 1600)]
const RES_DESKTOP := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
var _desktop := false
var _out := "/tmp/ck_mobile"
var _report := []
var _only: PackedStringArray = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		if arg.begins_with("--only="):
			_only = arg.substr(7).split(",")
		if arg == "--desktop":
			_desktop = true
	if DisplayServer.get_name() == "headless":
		print("MOBILE PASS headless-skip")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(_out)

	GameState.new_game("Ash", "Banner", "#%02x%02x%02x" % [110, 212, 255])
	var screens: Array = SCREENS.duplicate()
	if _desktop:
		screens.append_array(DESKTOP_EXTRA)
	for r in (RES_DESKTOP if _desktop else RES):
		get_window().size = r
		await get_tree().process_frame
		await get_tree().process_frame
		for pair in screens:
			if _desktop and str(pair[0]).begins_with("wing_"):
				continue  # phone-only rebuilds; desktop wings are covered by DESKTOP_EXTRA "works" etc.
			if not _only.is_empty() and not Array(_only).any(func(o): return str(pair[0]).begins_with(o)):
				continue
			if pair.size() > 2 and pair[2] != null:
				GameState.set_meta(str(pair[3]) if pair.size() > 3 else "city_tab", pair[2])
			var meta: Dictionary = (pair[4] as Dictionary).duplicate() if pair.size() > 4 else {}
			var home := World.pos
			if meta.has("world_pos"):
				## shoot a settlement the player is standing in (e.g. a capital), with a road log
				var wp := str(meta["world_pos"])
				meta.erase("world_pos")
				World.pos = wp
				World.visited[wp] = true
				World._tlog("抵达 %s（初次踏足）" % str(World.node(wp).get("name", wp)))
			var wed := bool(meta.get("wed", false))
			meta.erase("wed")
			var lead: CKCharacter = GameState.get_leader()
			var cand: CKCharacter = null
			var had := false
			if wed and lead != null and not GameState.marriage_candidates.is_empty():
				## married-state shot: wed the first candidate for this one shot, then undo
				cand = GameState.marriage_candidates[0]
				had = GameState.characters.has(str(cand.id))
				GameState.characters[str(cand.id)] = cand
				lead.spouse_id = str(cand.id)
				cand.spouse_id = str(lead.id)
			await _shoot(str(pair[1]), "%s_%dx%d" % [pair[0], r.x, r.y], meta)
			if cand != null:
				lead.spouse_id = ""
				cand.spouse_id = ""
				if not had:
					GameState.characters.erase(str(cand.id))
			World.pos = home
	var f := FileAccess.open(_out + "/layout.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, " "))
	print("MOBILE DONE")
	get_tree().quit(0)

func _shoot(path: String, name: String, node_meta: Dictionary = {}) -> void:
	var packed = load(path)
	if packed == null:
		push_error("missing " + path)
		return
	var node = packed.instantiate()
	for k in node_meta:
		node.set_meta(k, node_meta[k])
	get_tree().root.add_child(node)
	get_tree().current_scene = node
	if not _desktop:
		MobileChrome.call_deferred("_apply")
	await get_tree().create_timer(3.0 if name.begins_with("dialogue") else 0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	var vr := get_viewport().get_visible_rect()
	var items := []
	_root_scale = maxf(0.001, (node as CanvasItem).get_global_transform().get_scale().y) if node is CanvasItem else 1.0
	_collect(node, items, vr)
	_report_placeholders(node, items)
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
			var clip := _scroll_clip(c)
			var clipped := false
			if clip.size.x > 0.0:
				clipped = not clip.grow(1.0).encloses(r)
				if not clip.intersects(r):
					for ch0 in n.get_children():
						_collect(ch0, items, vr)
					return
			var txt := ""
			var need_w := 0.0
			if c is Label or c is Button:
				txt = str(c.text)
				var trims: bool = (c is Label and ((c as Label).text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING or (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF)) \
					or (c is Button and (c as Button).text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING)
				if txt != "" and not trims:
					var fnt: Font = c.get_theme_font("font")
					if fnt:
						need_w = fnt.get_string_size(txt.split("\n")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")).x * c.get_global_transform().get_scale().x
			items.append({"type": c.get_class(), "path": str(c.get_path()), "text": txt.left(30),
				"rect": [r.position.x, r.position.y, r.size.x, r.size.y],
				"font": roundi(c.get_theme_font_size("font_size") * c.get_global_transform().get_scale().y / _root_scale), "in_scroll": _in_scroll(c), "clipped": clipped, "need_w": need_w})
	for ch in n.get_children():
		_collect(ch, items, vr)

func _in_scroll(c: Node) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


## What a scroll view actually shows: items scrolled out of it are not on screen.
func _scroll_clip(c: Node) -> Rect2:
	## Scroll views and clipping frames (e.g. the atlas map window) hide what lies outside them.
	var p := c.get_parent()
	var out := Rect2()
	while p != null:
		if p is ScrollContainer or (p is Control and (p as Control).clip_contents):
			var r := (p as Control).get_global_rect()
			out = r if out.size.x <= 0.0 else out.intersection(r)
		p = p.get_parent()
	return out


func _report_placeholders(n: Node, items: Array) -> void:
	if n is TextureRect and (n as Control).is_visible_in_tree():
		var t: Texture2D = (n as TextureRect).texture
		var tp := t.resource_path if t else ""
		if t is PlaceholderTexture2D or tp.contains("placeholder") or tp.ends_with("icon.svg"):
			var r := (n as Control).get_global_rect()
			items.append({"type": "Placeholder", "path": str(n.get_path()), "text": tp.get_file(),
				"rect": [r.position.x, r.position.y, r.size.x, r.size.y], "font": 0, "in_scroll": true, "clipped": true, "need_w": 0.0})
	for ch in n.get_children():
		_report_placeholders(ch, items)
