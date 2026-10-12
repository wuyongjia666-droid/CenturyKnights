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

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if CKPauseMenu.current == null and _focus_in_coach(focus):
		return
	# Audit P2-7: a sub-page goes back one level; the castle, battle and story open the pause menu.
	if back_action(get_tree().current_scene) == "back":
		get_viewport().set_input_as_handled()
		get_tree().current_scene.call("_back")
		return
	CKPauseMenu.toggle()
	get_viewport().set_input_as_handled()
	if CKPauseMenu.current != null and is_instance_valid(CKPauseMenu.current):
		var vp := get_viewport().get_visible_rect().size
		MobileLayout.place_pause(CKPauseMenu.current, vp)

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
