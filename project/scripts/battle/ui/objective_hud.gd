class_name ObjectiveHud
extends RefCounted
## Objective strip. It sits in the top bar, and drops below a safe-area inset
## when the battle root itself has not already been moved clear of that inset.

static func attach(host: Node) -> void:
	if host.get_node_or_null("ObjectiveHud") != null:
		refresh(host)
		return
	var panel := Panel.new()
	panel.name = "ObjectiveHud"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	var style := UIKit.glass(12, 0.88)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(12, 8)
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var eye := UIKit.eyebrow(BattleObjectives.text("obj_eyebrow"), UIKit.ACCENT)
	eye.name = "Eye"
	eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(eye)
	var title := Label.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", UIKit.font("bold"))
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UIKit.TEXT)
	row.add_child(title)
	var detail := Label.new()
	detail.name = "Detail"
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", UIKit.ACCENT)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	host.add_child(panel)
	place(host)
	refresh(host)


static func place(host: Node) -> void:
	var hud := host.get_node_or_null("ObjectiveHud") as Control
	if hud == null:
		return
	var insets := _insets(host)
	var top := float(insets.get("top", 0.0))
	var left := float(insets.get("left", 0.0))
	var root := host as Control
	var consumed := true
	if root != null:
		consumed = root.position.y + 0.5 >= top and root.position.x + 0.5 >= left
	if consumed:
		hud.position = Vector2(904, 12)
		hud.size = Vector2(352, 44)
	else:
		hud.position = Vector2(left + 12.0, top + 8.0)
		hud.size = Vector2(360, 44)
	hud.custom_minimum_size = hud.size
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func refresh(host: Node) -> void:
	var hud := host.get_node_or_null("ObjectiveHud")
	if hud == null:
		return
	place(host)
	var map_id = host.get("map_id")
	var units = host.get("units")
	var round_no = host.get("_round_no")
	if map_id == null or units == null or round_no == null:
		return
	var info := BattleObjectives.summary(BattleMaps.get_map(str(map_id)), units, int(round_no))
	var title := hud.get_node_or_null("Row/Title") as Label
	var detail := hud.get_node_or_null("Row/Detail") as Label
	if title:
		title.text = str(info.get("title", ""))
	if detail:
		detail.text = str(info.get("detail", ""))


static func _insets(host: Node) -> Dictionary:
	if host.has_meta("mobile_insets"):
		var own = host.get_meta("mobile_insets")
		if typeof(own) == TYPE_DICTIONARY:
			return own
	var tree := host.get_tree()
	if tree != null and tree.current_scene != null and tree.current_scene.has_meta("mobile_insets"):
		var shared = tree.current_scene.get_meta("mobile_insets")
		if typeof(shared) == TYPE_DICTIONARY:
			return shared
	return {}
