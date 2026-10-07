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
