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
	var root := footer.get_tree().current_scene as Control
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
