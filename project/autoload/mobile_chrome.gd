extends Node
## On Android/iOS (or CK_FORCE_MOBILE=1), expand the viewport for 16:9–20:9
## and inset the current Control root by the display safe area.
## Desktop and headless CI leave the 1280x720 root untouched.

func _ready() -> void:
	if not DeviceProfile.is_mobile():
		return
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(1280, 720)
	get_tree().node_added.connect(_on_node_added)
	get_viewport().size_changed.connect(_on_resize)

func _on_node_added(_n: Node) -> void:
	call_deferred("_apply")

func _on_resize() -> void:
	call_deferred("_apply")

func _apply() -> void:
	if not DeviceProfile.is_mobile():
		return
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
	MobileLayout.apply_root(root, fitted)
	if root.has_method("apply_mobile_layout"):
		root.apply_mobile_layout()
