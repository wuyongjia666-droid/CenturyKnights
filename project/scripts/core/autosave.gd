class_name CKAutosave
extends RefCounted
## Auto slot writes. Month saves are throttled to one per game month.
## Battle and background saves are explicit so a mid-month pause still lands.
## Improve-plan G2 #57: a corner chip flashes for half a second after a successful auto write.

static var month_writes: int = 0
static var _last_month: String = ""
static var _last_flash_ms: int = 0
const FLASH_GAP_MS := 2000
const FLASH_SEC := 0.55


static func reset_throttle() -> void:
	month_writes = 0
	_last_month = ""
	_last_flash_ms = 0


static func on_month() -> void:
	var stamp := "%d-%d" % [Calendar.year, Calendar.month]
	if stamp == _last_month:
		return
	_last_month = stamp
	if GameState.save_to_slot("auto"):
		month_writes += 1
		flash()


static func before_battle() -> bool:
	var ok := GameState.save_to_slot("auto")
	if ok:
		flash()
	return ok


static func after_battle() -> bool:
	var ok := GameState.save_to_slot("auto")
	if ok:
		flash()
	return ok


static func on_background() -> bool:
	var ok := GameState.save_to_slot("auto")
	if ok:
		flash()
	return ok


## Corner chip on the current scene. Debounced so month+battle chains do not stack.
static func flash() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_flash_ms < FLASH_GAP_MS and _last_flash_ms > 0:
		return
	_last_flash_ms = now
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	var old := host.get_node_or_null("AutosaveToast")
	if old != null:
		old.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "AutosaveToast"
	layer.layer = 80
	host.add_child(layer)
	var lab := Label.new()
	lab.text = Locale.t("autosave_toast")
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", UIKit.TEXT)
	lab.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	lab.add_theme_constant_override("outline_size", 3)
	var vp := tree.root.get_visible_rect().size
	lab.position = Vector2(vp.x - 220, 16)
	lab.size = Vector2(200, 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.14, 0.82)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	lab.add_theme_stylebox_override("normal", sb)
	layer.add_child(lab)
	var tw := layer.create_tween()
	tw.tween_interval(FLASH_SEC)
	tw.tween_property(lab, "modulate:a", 0.0, 0.25)
	tw.tween_callback(layer.queue_free)
