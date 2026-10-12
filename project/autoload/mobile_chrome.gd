extends Node
## On Android/iOS (or CK_FORCE_MOBILE=1), expand the viewport for tall phones,
## bleed the void background edge-to-edge, and inset interactive chrome by safe area.
## Desktop and headless CI leave the 1280x720 root untouched.

var _bleed: ColorRect

func _ready() -> void:
	if not DeviceProfile.is_mobile():
		return
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(1280, 720)
	_ensure_immersive()
	_ensure_bleed()
	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(_on_resize)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if DeviceProfile.is_mobile():
			_ensure_immersive()
			call_deferred("_apply")

func _ensure_immersive() -> void:
	# Fullscreen / borderless so system bars do not reserve letterbox strips.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if DisplayServer.has_method("window_set_flag"):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

func _ensure_bleed() -> void:
	## Full-window void behind the scaled 1280x720 root so unused portrait slack
	## is Frost ink, not OS black letterbox bars.
	if _bleed != null and is_instance_valid(_bleed):
		return
	_bleed = ColorRect.new()
	_bleed.name = "MobileBleedBg"
	_bleed.color = UIKit.BG
	_bleed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bleed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bleed.z_index = -100
	get_tree().root.add_child(_bleed)
	get_tree().root.move_child(_bleed, 0)

func _on_node_added(_n: Node) -> void:
	call_deferred("_apply")

func _on_resize() -> void:
	call_deferred("_apply")

func _apply() -> void:
	if not DeviceProfile.is_mobile():
		return
	_ensure_immersive()
	_ensure_bleed()
	if _bleed != null and is_instance_valid(_bleed):
		_bleed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bleed.color = UIKit.BG
	var scene := get_tree().current_scene
	if scene == null or not (scene is Control):
		return
	var root := scene as Control
	var vp: Vector2 = root.get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if win.x < 2.0:
		win = vp
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var insets := DeviceProfile.insets_from_safe(vp, win, safe)
	var fitted := MobileLayout.fit(vp, insets)
	var key := "%s|%s|%s|%s" % [vp, insets, fitted.get("scale", 1.0), fitted.get("position", Vector2.ZERO)]
	if str(root.get_meta("mobile_fit_key", "")) == key:
		return
	root.set_meta("mobile_fit_key", key)
	root.set_meta("mobile_insets", insets)
	root.set_meta("mobile_origin", fitted.get("position", Vector2.ZERO))
	root.set_meta("mobile_scale", fitted.get("scale", 1.0))
	root.set_meta("mobile_paint_rect", fitted.get("paint_rect", Rect2(Vector2.ZERO, vp)))
	MobileLayout.apply_root(root, fitted)
	if root.has_method("apply_mobile_layout"):
		root.apply_mobile_layout()
	MobileLayout.extend_portrait_lists(root)
	MobileLayout.ensure_hit_targets(root)

## App-wide touch drag-to-scroll: any ScrollContainer scrolls when a finger
## drags over it, even when the drag starts on a button inside it.
var _touch_start := Vector2.ZERO
var _touch_scroll: ScrollContainer = null
var _dragging := false
var _swallow_release := false
const DRAG_SLOP := 14.0

func _handle_touch_scroll(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.index != 0:
			return false
		if event.pressed:
			_touch_start = event.position
			_touch_scroll = _scroll_at(event.position)
			_dragging = false
		else:
			_swallow_release = _dragging
			_dragging = false
			_touch_scroll = null
		return false
	if event is InputEventScreenDrag and event.index == 0 and _touch_scroll != null and is_instance_valid(_touch_scroll):
		if not _dragging and event.position.distance_to(_touch_start) < DRAG_SLOP:
			return false
		_dragging = true
		var sc := _touch_scroll
		var k := 1.0 / maxf(0.01, sc.get_global_transform_with_canvas().get_scale().y)
		sc.scroll_vertical -= int(event.relative.y * k)
		sc.scroll_horizontal -= int(event.relative.x * k)
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventMouseButton and not event.pressed and _swallow_release and event.button_index == MOUSE_BUTTON_LEFT:
		_swallow_release = false
		get_viewport().set_input_as_handled()
		return true
	if (event is InputEventMouseMotion) and _dragging:
		get_viewport().set_input_as_handled()
		return true
	return false

func _scroll_at(pos: Vector2) -> ScrollContainer:
	var best: ScrollContainer = null
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		if n is ScrollContainer and (n as Control).get_global_rect().has_point(pos):
			best = n
		for c in n.get_children():
			stack.append(c)
	return best

func _input(event: InputEvent) -> void:
	if DeviceProfile.is_mobile() and _handle_touch_scroll(event):
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if CKPauseMenu.current == null and _focus_in_coach(focus):
		return
	get_viewport().set_input_as_handled()
	CKNav.back()

## "back" when Esc / Android back should leave this page via its own _back(), "pause" otherwise.
func back_action(scene: Node) -> String:
	if CKPauseMenu.current != null and is_instance_valid(CKPauseMenu.current):
		return "pause"
	if scene != null and scene.has_method("_back"):
		return "back"
	return "pause"

func _focus_in_coach(focus: Control) -> bool:
	if focus == null:
		return false
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var coach := scene.find_child("LampCoach", true, false)
	if coach == null:
		return false
	var cursor: Node = focus
	while cursor:
		if cursor == coach:
			return true
		cursor = cursor.get_parent()
	return false
