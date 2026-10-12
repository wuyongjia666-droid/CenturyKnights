class_name CKAutosave
extends RefCounted
## Auto slot writes. Month saves are throttled to one per game month.
## Battle and background saves are explicit so a mid-month pause still lands.

static var month_writes: int = 0
static var _last_month: String = ""

static func reset_throttle() -> void:
	month_writes = 0
	_last_month = ""

static func on_month() -> void:
	var stamp := "%d-%d" % [Calendar.year, Calendar.month]
	if stamp == _last_month:
		return
	_last_month = stamp
	if _save():
		month_writes += 1

static func before_battle() -> bool:
	return _save()

static func after_battle() -> bool:
	return _save()

static func on_background() -> bool:
	return GameState.save_to_slot("auto")   # app is going away; nothing to show

static func _save() -> bool:
	var ok := GameState.save_to_slot("auto")
	if ok:
		flash()
	return ok

## Audit #57: a small "已自动存档" mark in the top-right corner for a moment.
static var flashes: int = 0

static func flash() -> void:
	flashes += 1
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var old := tree.root.get_node_or_null("AutosaveFlash")
	if old != null:
		old.free()
	var layer := CanvasLayer.new()
	layer.name = "AutosaveFlash"
	layer.layer = 90
	tree.root.add_child.call_deferred(layer)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UIKit.flat_box(Color(0.03, 0.04, 0.06, 0.82), Color(UIKit.ACCENT, 0.45), 8)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", sb)
	var l := UIKit.body_label("◆ " + Locale.t("a1_autosaved"), UIKit.ACCENT, 13)
	chip.add_child(l)
	layer.add_child(chip)
	chip.anchor_left = 1.0
	chip.anchor_right = 1.0
	chip.offset_left = -170
	chip.offset_right = -16
	chip.offset_top = 64
	chip.offset_bottom = 92
	var tw := chip.create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(chip, "modulate:a", 0.0, 0.4)
	tw.tween_callback(layer.queue_free)
