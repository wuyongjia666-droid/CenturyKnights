extends Control
## v8 世界舆图 — nations + landbridge from atlas_v8.json / farm plates

func _ready() -> void:
	UIKit.make_themed_bg(self, "castle")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_top = 24
	root.offset_right = -24
	root.offset_bottom = -24
	add_child(root)
	var title := UIKit.make_label("世界舆图", true)
	root.add_child(title)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	root.add_child(split)
	var map_wrap := PanelContainer.new()
	map_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(map_wrap)
	var map_tr := TextureRect.new()
	map_tr.name = "MapPlate"
	map_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_tr.custom_minimum_size = Vector2(720, 420)
	map_wrap.add_child(map_tr)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(280, 0)
	side.add_theme_constant_override("separation", 8)
	split.add_child(side)
	var tip := UIKit.make_dim_label("选择邦国查看地理板块。")
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(tip)
	var _Atlas = preload("res://scripts/art/atlas_art.gd")
	var d: Dictionary = _Atlas.data()
	var world := _Atlas.world_plate()
	if world == "":
		world = "res://assets/art/ui/atlas_world.png" if ResourceLoader.exists("res://assets/art/ui/atlas_world.png") else ""
	if world != "":
		map_tr.texture = load(world)
	var nations: Array = d.get("nations", [])
	for n in nations:
		var nid := str(n.get("id", ""))
		var nm := str(n.get("name", nid))
		var blurb := str(n.get("blurb", ""))
		var b := UIKit.make_button(nm, 240)
		var captured := nid
		var captured_name := nm
		var captured_blurb := blurb
		b.pressed.connect(func():
			UIFX.press_feedback(b)
			var path := _Atlas.nation_plate(captured)
			if path != "":
				map_tr.texture = load(path)
				UIFX.focus_ring(map_tr)
			tip.text = "%s — %s" % [captured_name, captured_blurb]
		)
		side.add_child(b)
	var back := UIKit.make_button("返回城堡", 240)
	back.pressed.connect(func():
		UIFX.page_exit(self)
		get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
	)
	side.add_child(back)
	UIFX.wire_tree(self)
