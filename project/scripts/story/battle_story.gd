class_name BattleStory
extends RefCounted
## Story interrupts inside a battle (tutorial-story v2). Data: res://data/story/battle_story.json.
## A short dialogue bar over the bottom of the board: tap anywhere to advance, 跳过 skips the rest
## of this battle's interrupts. Each trigger plays once per save (flag bs_<map>_<trigger>).

const DATA := "res://data/story/battle_story.json"
const LAYER_NAME := "BattleStoryLayer"
const TOUCH := 48

static var _cache: Dictionary = {}

static func table() -> Dictionary:
	if _cache.is_empty() and FileAccess.file_exists(DATA):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if typeof(parsed) == TYPE_DICTIONARY:
			_cache = parsed
	return _cache

static func lines_for(map_id: String, trigger: String) -> Array:
	var maps: Dictionary = table().get("maps", {})
	var m = maps.get(map_id, {})
	if typeof(m) != TYPE_DICTIONARY:
		return []
	var rows = (m as Dictionary).get(trigger, [])
	return rows if typeof(rows) == TYPE_ARRAY else []

static func flag_key(map_id: String, trigger: String) -> String:
	return "bs_%s_%s" % [map_id, trigger.replace(":", "_")]

## Count player turns on the host and fire turn:N.
static func on_player_turn(host: Node, map_id: String) -> void:
	var n := int(host.get_meta("bs_turn", 0)) + 1
	host.set_meta("bs_turn", n)
	fire(host, map_id, "turn:%d" % n)

## Returns the number of lines queued (0 when nothing new to say).
static func fire(host: Node, map_id: String, trigger: String) -> int:
	if host == null or not is_instance_valid(host):
		return 0
	if bool(host.get_meta("bs_skipped", false)):
		return 0
	# The interrupt lines are authored in Chinese only, like the chapter text.
	if Locale.is_en():
		return 0
	var rows := lines_for(map_id, trigger)
	if rows.is_empty():
		return 0
	var key := flag_key(map_id, trigger)
	if GameState.flag(key):
		return 0
	GameState.set_flag(key, true)
	var trail: Array = host.get_meta("bs_log", [])
	trail.append(trigger)
	host.set_meta("bs_log", trail)
	var layer := _layer(host)
	var q: Array = layer.get_meta("queue", [])
	for r in rows:
		if typeof(r) == TYPE_DICTIONARY:
			q.append(r)
	layer.set_meta("queue", q)
	if not bool(layer.get_meta("showing", false)):
		_next(layer)
	return rows.size()

static func _layer(host: Node) -> CanvasLayer:
	var existing := host.get_node_or_null(LAYER_NAME)
	if existing is CanvasLayer:
		return existing
	var layer := CanvasLayer.new()
	layer.name = LAYER_NAME
	layer.layer = 40
	host.add_child(layer)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.18)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var bar := PanelContainer.new()
	bar.name = "Bar"
	bar.anchor_left = 0.08
	bar.anchor_right = 0.92
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -168
	bar.offset_bottom = -20
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if host.has_method("_mobile_landscape") and host._mobile_landscape():
		# Landscape phone: the bark sits over the side panel, right of the board, never over it.
		var vpw: float = maxf(1.0, host.get_viewport().get_visible_rect().size.x)
		var board_end: float = (12.0 + 856.0 + 12.0 + host._root_w() - host.MOBILE_RAIL_W - 1280.0 + 8.0 + 12.0) * host.scale.x
		bar.anchor_left = clampf(board_end / vpw, 0.4, 0.8)
		bar.anchor_right = 1.0 - (host.MOBILE_RAIL_W + 6.0) * host.scale.x / vpw
		bar.anchor_top = 0.42
		bar.offset_top = 0
		bar.offset_bottom = -12
		dim.color = Color(0, 0, 0, 0.0)
		bar.anchor_top = 0.1
		preload("res://scripts/battle/ui/battle_mobile_side.gd").yield_to(host, root)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.045, 0.065, 0.93)
	sb.border_color = Color(UIKit.ACCENT, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	bar.add_theme_stylebox_override("panel", sb)
	root.add_child(bar)
	var vb := VBoxContainer.new()
	vb.name = "VBoxContainer"
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(vb)
	var sp := Label.new()
	sp.name = "Speaker"
	sp.add_theme_color_override("font_color", UIKit.ACCENT)
	sp.add_theme_font_size_override("font_size", 18)
	sp.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	vb.add_child(sp)
	var body := Label.new()
	body.name = "Body"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", UIKit.TEXT)
	body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	vb.add_child(body)
	var hint := Label.new()
	hint.text = Locale.t("story_tap_continue")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	vb.add_child(hint)
	var skip := Button.new()
	skip.name = "Skip"
	skip.text = Locale.t("story_skip_lines")
	skip.custom_minimum_size = Vector2(112, TOUCH)
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -136
	skip.offset_right = -24
	skip.offset_top = 16
	skip.offset_bottom = 16 + TOUCH
	if not DeviceProfile.is_mobile():
		# Desktop: sit in the empty header strip left of the rail, not on top of the drill banner.
		skip.offset_left = -504
		skip.offset_right = -392
	root.add_child(skip)
	skip.pressed.connect(func(): skip_all(host))
	if DeviceProfile.is_mobile():
		for pair in [[sp, 22], [body, 24], [hint, 22], [skip, 22]]:
			(pair[0] as Control).add_theme_font_size_override("font_size", pair[1])
		skip.custom_minimum_size = Vector2(150, 76)
		skip.offset_left = -174
		skip.offset_bottom = 16 + 76
	if not DeviceProfile.is_mobile():
		# Desktop: the bark bar is modal and sits on the command rows; hide them while it shows so
		# "点屏幕继续" never lands on the danger toggle or the end-turn button.
		root.visibility_changed.connect(func():
			for rn in ["CommandRow", "CommandRow2"]:
				var r := host.get_node_or_null(rn) as CanvasItem
				if r:
					r.visible = not root.visible)
	root.gui_input.connect(func(ev: InputEvent):
		var tap: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
		if tap:
			root.accept_event()
			_next(layer)
	)
	return layer

static func _next(layer: CanvasLayer) -> void:
	var root := layer.get_node("Root") as Control
	var q: Array = layer.get_meta("queue", [])
	if q.is_empty():
		root.visible = false
		layer.set_meta("showing", false)
		return
	var row: Dictionary = q.pop_front()
	layer.set_meta("queue", q)
	layer.set_meta("showing", true)
	(root.get_node("Bar/VBoxContainer/Speaker") as Label).text = str(row.get("speaker", ""))
	(root.get_node("Bar/VBoxContainer/Body") as Label).text = str(row.get("text", ""))
	root.visible = true

static func skip_all(host: Node) -> void:
	host.set_meta("bs_skipped", true)
	var layer := host.get_node_or_null(LAYER_NAME)
	if layer is CanvasLayer:
		layer.set_meta("queue", [])
		_next(layer)

static func is_showing(host: Node) -> bool:
	var layer := host.get_node_or_null(LAYER_NAME)
	return layer is CanvasLayer and bool(layer.get_meta("showing", false))

static func advance(host: Node) -> void:
	var layer := host.get_node_or_null(LAYER_NAME)
	if layer is CanvasLayer:
		_next(layer)
