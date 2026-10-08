class_name CKCoach
extends Control
## 灯引：高亮一个 Control，其余压暗，点击继续。多步序列的说明卡避开安全区。
## Narrative / 其他流只通过 CKTips.register 写入内容，不要改本文件的洞矩形算法。

signal advanced
signal finished

const TALL_VIEWPORT := Vector2(1080, 2400)
const TALL_INSETS := {"left": 0.0, "top": 84.0, "right": 0.0, "bottom": 96.0}

var hole: Rect2 = Rect2()
var step_index: int = 0
var step_count: int = 0

var _steps: Array = []
var _target: Control
var _safe: Rect2 = Rect2()
var _card: PanelContainer
var _body: Label
var _step: Label

static func safe_rect(viewport: Vector2, insets: Dictionary) -> Rect2:
	var left := float(insets.get("left", 0.0))
	var top := float(insets.get("top", 0.0))
	var right := float(insets.get("right", 0.0))
	var bottom := float(insets.get("bottom", 0.0))
	return Rect2(left, top, maxf(1.0, viewport.x - left - right), maxf(1.0, viewport.y - top - bottom))

static func attach(host: Node) -> CKCoach:
	var coach := CKCoach.new()
	coach.name = "LampCoach"
	host.add_child(coach)
	return coach

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	z_as_relative = false
	z_index = 80
	_build_card()

func _build_card() -> void:
	_card = PanelContainer.new()
	_card.name = "LampCard"
	_card.mouse_filter = MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", UIKit.glass(14, 0.94, true))
	_card.custom_minimum_size = Vector2(340, 0)
	var box := VBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	_card.add_child(box)
	var eye := UIKit.eyebrow("LAMP · 灯引")
	eye.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(eye)
	_body = UIKit.body_label("", UIKit.TEXT, 15)
	_body.name = "LampBody"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(300, 0)
	_body.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(_body)
	var hint := UIKit.body_label(_line("ux_coach_continue", "点击继续"), UIKit.ACCENT, 12)
	hint.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(hint)
	_step = UIKit.body_label("", UIKit.TEXT_DIM, 12)
	_step.name = "LampStep"
	_step.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(_step)
	add_child(_card)

func present_target(target: Control, text: String, safe: Rect2 = Rect2()) -> void:
	play_steps([{"target": target, "text": text}], safe)

func play_steps(steps: Array, safe: Rect2 = Rect2()) -> void:
	_steps = steps
	step_count = steps.size()
	step_index = 0
	_safe = safe
	_show_step()

func advance() -> void:
	if _steps.is_empty():
		return
	step_index += 1
	advanced.emit()
	if step_index >= _steps.size():
		finished.emit()
		queue_free()
		return
	_show_step()

func callout_rect() -> Rect2:
	if _card == null:
		return Rect2()
	return _card.get_global_rect()

func _show_step() -> void:
	var step: Dictionary = _steps[step_index]
	var node = step.get("target")
	_target = node if node is Control else null
	if _body:
		_body.text = str(step.get("text", ""))
	if _step:
		_step.text = "%d / %d" % [step_index + 1, maxi(step_count, 1)]
	_sync()

func _process(_delta: float) -> void:
	_sync()

func _sync() -> void:
	if _target != null and is_instance_valid(_target):
		hole = _target.get_global_rect()
	queue_redraw()
	_place_callout()

func _place_callout() -> void:
	if _card == null:
		return
	var width := 380.0
	_card.custom_minimum_size = Vector2(width, 0)
	if _body:
		_body.custom_minimum_size = Vector2(width - 52.0, 0)
	var min_size := _card.get_combined_minimum_size()
	var card_size := Vector2(maxf(width, min_size.x), maxf(88.0, min_size.y))
	var safe_local := _safe_local()
	var local_hole := Rect2(hole.position - global_position, hole.size)
	var gap := 16.0
	var x := local_hole.position.x
	var y := local_hole.end.y + gap
	if y + card_size.y > safe_local.end.y - 4.0:
		y = local_hole.position.y - gap - card_size.y
	x = clampf(x, safe_local.position.x + 8.0, maxf(safe_local.position.x + 8.0, safe_local.end.x - card_size.x - 8.0))
	y = clampf(y, safe_local.position.y + 8.0, maxf(safe_local.position.y + 8.0, safe_local.end.y - card_size.y - 8.0))
	_card.position = Vector2(x, y)
	_card.size = card_size

func _safe_local() -> Rect2:
	if _safe.size.x > 2.0 and _safe.size.y > 2.0:
		return Rect2(_safe.position - global_position, _safe.size)
	var vp := get_viewport_rect().size
	if vp.x < 2.0:
		vp = size
	return Rect2(Vector2.ZERO, vp if vp.x > 2.0 else size)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			advance()
			accept_event()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		advance()
		accept_event()

func _draw() -> void:
	var dim := Color(0, 0, 0, 0.72)
	var h := Rect2(hole.position - global_position, hole.size)
	if h.size.x < 1.0 or h.size.y < 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), dim)
		return
	draw_rect(Rect2(0, 0, size.x, maxf(0.0, h.position.y)), dim)
	draw_rect(Rect2(0, h.end.y, size.x, maxf(0.0, size.y - h.end.y)), dim)
	draw_rect(Rect2(0, h.position.y, maxf(0.0, h.position.x), h.size.y), dim)
	draw_rect(Rect2(h.end.x, h.position.y, maxf(0.0, size.x - h.end.x), h.size.y), dim)
	var stroke := UIKit.ACCENT
	draw_rect(h.grow(1.0), stroke, false, 2.0)

func _line(key: String, fallback: String) -> String:
	var s := Locale.t(key)
	if s == key or s == "":
		return fallback
	return s
