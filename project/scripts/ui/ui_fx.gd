class_name UIFX
extends RefCounted

static func fade_in(node: CanvasItem, dur: float = 0.35) -> void:
	if node == null: return
	node.modulate.a = 0.0
	var tw = node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

static func pop_in(node: Control, dur: float = 0.28) -> void:
	if node == null: return
	node.scale = Vector2(0.92, 0.92)
	node.modulate.a = 0.0
	var tw = node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, dur)
	tw.tween_property(node, "scale", Vector2.ONE, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

static func punch(node: Control, amount: float = 0.06) -> void:
	if node == null: return
	var tw = node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * (1.0 + amount), 0.08)
	tw.tween_property(node, "scale", Vector2.ONE, 0.12)

static func slide_from_bottom(node: Control, dist: float = 40.0, dur: float = 0.35) -> void:
	if node == null: return
	var target = node.position
	node.position = target + Vector2(0, dist)
	node.modulate.a = 0.0
	var tw = node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "position", target, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(node, "modulate:a", 1.0, dur)

static func flash_modulate(node: CanvasItem, col: Color = Color(1.2, 1.1, 0.9), dur: float = 0.18) -> void:
	if node == null: return
	var orig = node.modulate
	node.modulate = col
	var tw = node.create_tween()
	tw.tween_property(node, "modulate", orig, dur)

static func shake_control(node: Control, amp: float = 6.0, dur: float = 0.22) -> void:
	if node == null: return
	var origin = node.position
	var tw = node.create_tween()
	tw.tween_property(node, "position", origin + Vector2(amp, -amp * 0.4), dur * 0.25)
	tw.tween_property(node, "position", origin + Vector2(-amp, amp * 0.3), dur * 0.25)
	tw.tween_property(node, "position", origin + Vector2(amp * 0.4, amp * 0.2), dur * 0.25)
	tw.tween_property(node, "position", origin, dur * 0.25)
