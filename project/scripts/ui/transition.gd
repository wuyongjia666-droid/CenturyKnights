class_name CKTransition
extends CanvasLayer
## P0-FX-01 (ux-navigation-v1 §6.1). Owned by CKNav; layer 90, under the pause menu (100).
## Contract:
##   cover()            ink curtain fully up, swallows mouse/touch. Called right before a scene change.
##   reveal(dir)        new scene slides in 24px from dir (+1 forward from the right, -1 back from the left)
##                      while the curtain fades out; input unblocks when done.
##   total_seconds()    leave + enter time; <= 0.36s, <= 0.1s with reduced motion.
## Never blocks forever: reveal() always ends with the curtain hidden, even if the scene is not a Control.

const LEAVE := 0.14
const ENTER := 0.2
const REDUCED := 0.04
const SLIDE := 24.0

var curtain: ColorRect
var _tw: Tween

func _init() -> void:
	layer = 90
	name = "CKTransition"
	process_mode = Node.PROCESS_MODE_ALWAYS
	curtain = ColorRect.new()
	curtain.name = "InkCurtain"
	curtain.color = UIKit.BG
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.modulate.a = 0.0
	curtain.visible = false
	add_child(curtain)

static func leave_seconds() -> float:
	return REDUCED if UIFX.reduced() else LEAVE

static func enter_seconds() -> float:
	return REDUCED if UIFX.reduced() else ENTER

static func total_seconds() -> float:
	return leave_seconds() + enter_seconds()

func blocking() -> bool:
	return curtain.visible and curtain.mouse_filter == Control.MOUSE_FILTER_STOP

func cover() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	curtain.visible = true
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	curtain.modulate.a = 1.0

func reveal(scene: Node, dir: int) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var t := enter_seconds()
	if scene is Control and not UIFX.reduced():
		var c := scene as Control
		var end := c.position
		c.position = end + Vector2(SLIDE * signf(float(dir)), 0)
		c.create_tween().tween_property(c, "position", end, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tw = create_tween()
	_tw.tween_property(curtain, "modulate:a", 0.0, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tw.tween_callback(_done)

func _done() -> void:
	curtain.visible = false
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
