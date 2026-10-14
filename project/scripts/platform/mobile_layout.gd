class_name MobileLayout
extends RefCounted
## Places the 1280x720 Stitch root inside a phone safe rect.
## 1080x1920 (16:9) and 1080x2400 (20:9) are the portrait targets; landscape uses the same fit.

const DESIGN := Vector2(1280, 720)

static func fit(viewport: Vector2, insets: Dictionary, design: Vector2 = DESIGN) -> Dictionary:
	## Full-bleed: the root fills the whole safe area (no centered design column).
	## Scale keeps the design's short side fitting; the long side expands.
	var left := float(insets.get("left", 0.0))
	var top := float(insets.get("top", 0.0))
	var right := float(insets.get("right", 0.0))
	var bottom := float(insets.get("bottom", 0.0))
	var usable := Vector2(
		maxf(1.0, viewport.x - left - right),
		maxf(1.0, viewport.y - top - bottom)
	)
	var s := minf(minf(usable.x / design.x, usable.y / design.y), 1.0)
	var portrait := viewport.y > viewport.x + 80.0
	var paint := Rect2(Vector2.ZERO, viewport)
	return {"scale": s, "position": Vector2(left, top), "usable": usable, "size": usable / s,
		"paint_rect": paint, "portrait": portrait}

static func apply_root(root: Control, fit: Dictionary) -> void:
	var s := float(fit.get("scale", 1.0))
	var pos: Vector2 = fit.get("position", Vector2.ZERO)
	var sz: Vector2 = fit.get("size", DESIGN)
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.anchor_right = 0.0
	root.anchor_bottom = 0.0
	root.pivot_offset = Vector2.ZERO
	root.scale = Vector2(s, s)
	root.position = pos
	root.offset_left = pos.x
	root.offset_top = pos.y
	root.offset_right = pos.x + sz.x
	root.offset_bottom = pos.y + sz.y
	root.size = sz

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
## lists (roster, codex, lineage) use that room. fit() top-aligns; this fills the slack.
static func extend_portrait_lists(root: Control) -> void:
	if root == null or not root.is_inside_tree():
		return
	_pin_top(root)
	var footer := root.find_child("StitchFooter", true, false) as Control
	if _has_long_list(root):
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
		if DeviceProfile.is_mobile() and font_floor_applies(root):
			need = maxf(need, HIT_FLOOR)
	_grow_buttons(root, need)

## Mobile type floor (docs/design/mobile-landscape.md): 1 dp ≈ 1.75 logical px on a 720-tall
## landscape root, so 12dp = 21px. Every text node under `root` is raised to FONT_FLOOR unless the
## node (or the scene root) sets meta "font_floor_exempt". Pure-Latin spaced-caps kickers
## ("C E N T U R Y", "— Q U E U E") are decoration on desktop; on a phone they are hidden.
const FONT_FLOOR := 22
const HIT_FLOOR := 76.0

## Hand-placed pages whose phone redesign is owned by another line (or not done yet). The floor
## would push their absolute rows into each other, so they keep desktop sizes until their own
## apply_mobile_layout lands; that change removes the page from this list.
const FONT_FLOOR_PENDING := [
	"res://scenes/hub/city.tscn",
	"res://scenes/hub/market.tscn",
	"res://scenes/hub/estates.tscn", "res://scenes/hub/works.tscn",
	"res://scenes/hub/forge.tscn",
]

static func font_floor_applies(root: Node) -> bool:
	if root == null or bool(root.get_meta("font_floor_exempt", false)):
		return false
	return not (root.scene_file_path in FONT_FLOOR_PENDING)

static func ensure_min_fonts(root: Node, floor_px: int = FONT_FLOOR) -> void:
	if not font_floor_applies(root):
		return
	_floor_fonts(root, floor_px)

static func _floor_fonts(node: Node, floor_px: int) -> void:
	for child in node.get_children():
		if bool(child.get_meta("font_floor_exempt", false)):
			continue
		if child is Control:
			_floor_one(child as Control, floor_px)
		_floor_fonts(child, floor_px)

static func is_decor_kicker(text: String) -> bool:
	var t := text.strip_edges()
	if t.length() < 2:
		return t == "/" or t == "//"
	t = t.replace("\u2009", " ")
	var re := RegEx.new()
	re.compile("^[A-Z0-9 ·/\\-—–.:#]+$")
	if re.search(t) == null:
		return false
	return t.contains(" ") or t.contains("/")

static func _floor_one(c: Control, floor_px: int) -> void:
	var key := "font_size"
	if c is RichTextLabel:
		key = "normal_font_size"
	elif not (c is Label or c is Button or c is LineEdit or c is TextEdit or c is SpinBox):
		return
	if c is SpinBox:
		_floor_one((c as SpinBox).get_line_edit(), floor_px)
		return
	var fs := c.get_theme_font_size(key)
	if fs >= floor_px:
		return
	if c is Label and fs <= 12 and c.visible and is_decor_kicker((c as Label).text):
		c.visible = false
		c.set_meta("m_kicker_hidden", true)
		return
	c.add_theme_font_size_override(key, floor_px)
	if c is RichTextLabel:
		for k in ["bold_font_size", "italics_font_size", "mono_font_size", "bold_italics_font_size"]:
			if c.get_theme_font_size(k) < floor_px:
				c.add_theme_font_size_override(k, floor_px)

static func _grow_buttons(node: Node, need: float) -> void:
	for child in node.get_children():
		# a scaled layer (e.g. the atlas map) sizes its own targets in on-screen px
		if not (child is BaseButton) and bool(child.get_meta("touch_exempt", false)):
			continue
		if child is BaseButton:
			_grow_hit(child as BaseButton, need)
		_grow_buttons(child, need)

static func _grow_hit(button: BaseButton, need: float) -> void:
	if not button.visible or not button.is_visible_in_tree():
		return
	# PASS buttons (rows inside drag-scroll lists) are still tap targets; only IGNORE is decoration.
	if button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
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
	var old_size := button.size
	button.custom_minimum_size = Vector2(nw, nh)
	button.size = Vector2(maxf(button.size.x, nw), maxf(button.size.y, nh))
	# Free-positioned buttons grow around their centre so they stay aligned with their row.
	if not (button.get_parent() is Container):
		button.position -= (button.size - old_size) * 0.5

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
	jump_h = maxf(jump_h, 48.0)
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

static func hit_exception(_button: Node) -> String:
	# P0-MOB-01 (ux-navigation-v1 §6.3): no exemptions. The NavRail rows grow to hit_px() and the
	# column scrolls. Kept as a hook so a future exemption must name its reason here.
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
	if layer == null:
		return
	var panel: Control = null
	for child in layer.get_children():
		if child is CenterContainer:
			return  # A-03: the pause menu centres itself in every orientation.
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

## Long-tail CKPageKit pages are a fixed 1280 grid. On a 20:9 phone the root is ~1600 wide and the
## grid hugged the left edge with a dead strip on the right; centre it instead. Full-rect children
## (backdrops) already stretch and are left alone. Idempotent: re-runs shift by the difference only.
static func center_kit_page(root: Control) -> void:
	if root == null or not bool(root.get_meta("ck_page_kit", false)):
		return
	# A page with its own phone layout opts in only when that layout never re-places its columns.
	if root.has_method("apply_mobile_layout") and not bool(root.get_meta("m_center_ok", false)):
		return
	var dx := floorf(maxf(0.0, root.size.x - DESIGN.x) * 0.5)
	var old := float(root.get_meta("m_center_dx", 0.0))
	if is_equal_approx(dx, old):
		return
	root.set_meta("m_center_dx", dx)
	for child in root.get_children():
		if not (child is Control):
			continue
		var c := child as Control
		if c.anchor_right > 0.5 or c.anchor_left > 0.5:
			continue
		if c.name == "StitchTopBar":
			stretch_top_bar(c, 2.0 * (dx - old))
			continue
		c.position.x += dx - old

## Widen a 1280 StitchTopBar by `extra` px: title stays left, the right cluster moves to the edge.
static func stretch_top_bar(bar: Control, extra: float) -> void:
	if bar == null or absf(extra) < 0.5:
		return
	bar.size.x += extra
	for bc in bar.get_children():
		if not (bc is Control):
			continue
		var b := bc as Control
		if b.size.x >= 800.0:
			b.size.x += extra
		elif b.position.x > 640.0:
			b.position.x += extra
