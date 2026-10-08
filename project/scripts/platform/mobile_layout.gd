class_name MobileLayout
extends RefCounted
## Places the 1280x720 Stitch root inside a phone safe rect.
## 1080x1920 (16:9) and 1080x2400 (20:9) are the portrait targets; landscape uses the same fit.

const DESIGN := Vector2(1280, 720)

static func fit(viewport: Vector2, insets: Dictionary, design: Vector2 = DESIGN) -> Dictionary:
	var left := float(insets.get("left", 0.0))
	var top := float(insets.get("top", 0.0))
	var right := float(insets.get("right", 0.0))
	var bottom := float(insets.get("bottom", 0.0))
	var usable := Vector2(
		maxf(1.0, viewport.x - left - right),
		maxf(1.0, viewport.y - top - bottom)
	)
	var s := minf(usable.x / design.x, usable.y / design.y)
	s = minf(s, 1.0)
	var pos := Vector2(left, top)
	var slack_x := usable.x - design.x * s
	var slack_y := usable.y - design.y * s
	if slack_x > 0.5:
		pos.x = left + slack_x * 0.5
	if slack_y > 0.5:
		pos.y = top + slack_y * 0.5
	return {"scale": s, "position": pos, "usable": usable}

static func apply_root(root: Control, fit: Dictionary) -> void:
	var s := float(fit.get("scale", 1.0))
	var pos: Vector2 = fit.get("position", Vector2.ZERO)
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.anchor_right = 0.0
	root.anchor_bottom = 0.0
	root.pivot_offset = Vector2.ZERO
	root.scale = Vector2(s, s)
	root.size = DESIGN
	root.position = pos
	root.offset_left = pos.x
	root.offset_top = pos.y
	root.offset_right = pos.x + DESIGN.x
	root.offset_bottom = pos.y + DESIGN.y

static func pin_footer(footer: Control) -> void:
	if footer == null or not footer.is_inside_tree():
		return
	var root := _host_root(footer)
	if root == null:
		return
	var vp := footer.get_viewport().get_visible_rect().size
	var sy := root.scale.y if root.scale.y > 0.01 else 1.0
	var bottom_inset := 0.0
	if root.has_meta("mobile_insets"):
		bottom_inset = float((root.get_meta("mobile_insets") as Dictionary).get("bottom", 0.0))
	var local_bottom := (vp.y - root.global_position.y - bottom_inset) / sy
	footer.position.y = maxf(footer.position.y, local_bottom - footer.size.y)

static func fill_scroll(scroll: ScrollContainer, footer: Control, fallback: float) -> void:
	if scroll == null or not scroll.is_inside_tree():
		return
	pin_footer(footer)
	var sy := scroll.get_global_transform_with_canvas().get_scale().y
	if sy < 0.01:
		sy = 1.0
	var limit := scroll.get_viewport().get_visible_rect().size.y - 12.0
	if footer:
		limit = footer.get_global_rect().position.y - 8.0
	var room := (limit - scroll.get_global_rect().position.y) / sy
	if room > 40.0:
		scroll.size.y = maxf(fallback, room)

## Portrait slack sits below the 720 design. Pull the footer down and let the long
## lists (roster, codex, lineage) use that room. fit() itself stays letterboxed.
static func extend_portrait_lists(root: Control) -> void:
	if root == null or not root.is_inside_tree():
		return
	var footer := root.find_child("StitchFooter", true, false) as Control
	if _has_long_list(root):
		_pin_top(root)
		if footer:
			pin_footer(footer)
	var roster := root.find_child("RosterListScroll", true, false) as ScrollContainer
	if roster:
		fill_scroll(roster, footer, 508.0)
	_grow_codex(root, footer)
	_grow_lineage(root, footer)

static func ensure_hit_targets(root: Node, min_px: float = -1.0) -> void:
	if root == null:
		return
	var need := min_px
	if need < 0.0:
		need = DeviceProfile.hit_px()
	_grow_buttons(root, need)

static func _grow_buttons(node: Node, need: float) -> void:
	for child in node.get_children():
		if child is BaseButton:
			_grow_hit(child as BaseButton, need)
		_grow_buttons(child, need)

static func _grow_hit(button: BaseButton, need: float) -> void:
	if not button.visible or not button.is_visible_in_tree():
		return
	if button.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	if bool(button.get_meta("touch_exempt", false)):
		return
	if hit_exception(button) != "":
		return
	var w := maxf(button.size.x, button.custom_minimum_size.x)
	var h := maxf(button.size.y, button.custom_minimum_size.y)
	if w + 0.5 >= need and h + 0.5 >= need:
		return
	var nw := maxf(w, need)
	var nh := maxf(h, need)
	button.custom_minimum_size = Vector2(nw, nh)
	button.size = Vector2(maxf(button.size.x, nw), maxf(button.size.y, nh))

static func _grow_codex(root: Control, footer: Control) -> void:
	var rail := root.find_child("NationRailPanel", true, false) as Control
	var body := root.find_child("CodexBody", true, false) as Control
	if rail == null and body == null:
		return
	var bottom := _list_bottom(root, footer)
	if rail:
		rail.size.y = maxf(rail.size.y, bottom - rail.position.y)
		var inner := _first_scroll(rail)
		if inner:
			inner.size.y = maxf(inner.size.y, rail.size.y - inner.position.y - 12.0)
	if body:
		body.size.y = maxf(body.size.y, bottom - body.position.y)
		var line := body.find_child("LineScroll", true, false) as ScrollContainer
		if line:
			var room := body.size.y - line.position.y - 8.0
			if room > 40.0:
				line.size.y = maxf(line.size.y, room)

static func _grow_lineage(root: Control, footer: Control) -> void:
	var jumps := root.find_child("LineageJumps", true, false) as Control
	if jumps == null:
		return
	var bottom := _list_bottom(root, footer)
	var jump_h := maxf(jumps.size.y, jumps.get_combined_minimum_size().y)
	jump_h = maxf(jump_h, 44.0)
	jumps.position.y = maxf(120.0, bottom - jump_h)
	for child in root.get_children():
		if not (child is Control):
			continue
		var ctrl := child as Control
		if ctrl == jumps or ctrl == footer:
			continue
		if absf(ctrl.position.x - 42.0) > 1.5 or absf(ctrl.position.y - 150.0) > 1.5:
			continue
		if absf(ctrl.size.x - 800.0) > 8.0:
			continue
		ctrl.size.y = maxf(ctrl.size.y, jumps.position.y - 12.0 - ctrl.position.y)
		return

static func _list_bottom(root: Control, footer: Control) -> float:
	if footer:
		return footer.position.y - 8.0
	return root.size.y - 28.0

static func _first_scroll(parent: Node) -> ScrollContainer:
	for child in parent.get_children():
		if child is ScrollContainer:
			return child as ScrollContainer
	return null

static func hit_exception(button: Node) -> String:
	# NavRail is a 142px stitch column. 44px rows push the last entry out of the first screen.
	var node: Node = button
	while node:
		if str(node.name) == "NavRail":
			return "NavRail keeps the stitch row height; the column scrolls"
		node = node.get_parent()
	return ""

static func _has_long_list(root: Control) -> bool:
	if root.find_child("RosterListScroll", true, false) != null:
		return true
	if root.find_child("NationRailPanel", true, false) != null:
		return true
	return root.find_child("LineageJumps", true, false) != null

static func _host_root(footer: Control) -> Control:
	var scene := footer.get_tree().current_scene as Control
	if scene != null and (scene == footer or scene.is_ancestor_of(footer)):
		return scene
	var host: Control = footer
	var node: Node = footer
	while node.get_parent() is Control:
		host = node.get_parent() as Control
		node = host
	return host

static func _pin_top(root: Control) -> void:
	var vp := root.get_viewport().get_visible_rect().size
	if vp.y < vp.x + 80.0:
		return
	var top := 0.0
	if root.has_meta("mobile_insets"):
		var insets: Dictionary = root.get_meta("mobile_insets")
		top = float(insets.get("top", 0.0))
	if root.position.y <= top + 1.0:
		return
	root.position.y = top
	root.offset_top = top
	root.offset_bottom = top + root.size.y

static func place_pause(layer: Node, viewport: Vector2) -> void:
	if layer == null or viewport.y < viewport.x:
		return
	var panel: Control = null
	for child in layer.get_children():
		if child is Control and not (child is ColorRect):
			panel = child as Control
			break
	if panel == null:
		return
	var sz := panel.custom_minimum_size
	if sz.x < 40.0:
		sz.x = maxf(panel.size.x, 280.0)
	if sz.y < 40.0:
		sz.y = maxf(panel.size.y, 280.0)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	var x := maxf(24.0, (viewport.x - sz.x) * 0.5)
	var y := maxf(48.0, (viewport.y - sz.y) * 0.5)
	panel.position = Vector2(x, y)
	panel.size = sz

static func fit_top_bar(root: Control, width: float) -> void:
	var bar := root.find_child("StitchTopBar", true, false) as Control
	if bar == null or width < 64.0 or bar.size.x <= width + 1.0:
		return
	bar.size.x = width
	for child in bar.get_children():
		if not (child is Control):
			continue
		var ctrl := child as Control
		if ctrl.size.x > width:
			ctrl.size.x = width
		if child is HBoxContainer:
			var box := child as HBoxContainer
			var box_w := minf(maxf(box.size.x, 280.0), width - 32.0)
			box.size.x = box_w
			box.position.x = maxf(120.0, width - box_w - 16.0)
