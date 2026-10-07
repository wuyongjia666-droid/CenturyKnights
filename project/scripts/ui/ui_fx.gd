class_name UIFX
extends RefCounted
## Active-Theory 级动效 + 前端微交互原则（ease-out 入场 / 短退出 / 分层反馈）
## 时长：按压 100–150ms · 面板 220–320ms · 页面 400–550ms；尊重「减动效」时可缩短

static func reduced() -> bool:
	return bool(GameState.settings.get("reduced_motion", false))

static func _dur(base: float) -> float:
	return base * 0.35 if reduced() else base

static func fade_in(node: CanvasItem, dur: float = 0.32) -> void:
	if node == null: return
	dur = _dur(dur)
	node.modulate.a = 0.0
	var tw = node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

static func pop_in(node: Control, dur: float = 0.28) -> void:
	if node == null: return
	dur = _dur(dur)
	node.scale = Vector2(0.92, 0.92)
	node.modulate.a = 0.0
	var tw = node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, dur)
	tw.tween_property(node, "scale", Vector2.ONE, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

static func punch(node: Control, amount: float = 0.06) -> void:
	if node == null: return
	var tw = node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * (1.0 + amount), _dur(0.09)).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, _dur(0.12)).set_ease(Tween.EASE_IN)

static func slide_from_bottom(node: Control, dist: float = 40.0, dur: float = 0.35) -> void:
	if node == null: return
	dur = _dur(dur)
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
	tw.tween_property(node, "modulate", orig, _dur(dur)).set_ease(Tween.EASE_OUT)

static func shake_control(node: Control, amp: float = 6.0, dur: float = 0.22) -> void:
	if node == null: return
	dur = _dur(dur)
	var origin = node.position
	var tw = node.create_tween()
	tw.tween_property(node, "position", origin + Vector2(amp, -amp * 0.4), dur * 0.25)
	tw.tween_property(node, "position", origin + Vector2(-amp, amp * 0.3), dur * 0.25)
	tw.tween_property(node, "position", origin + Vector2(amp * 0.4, amp * 0.2), dur * 0.25)
	tw.tween_property(node, "position", origin, dur * 0.25)

## —— Active Theory / 前端分层 ——
static func stagger_children(parent: Node, delay: float = 0.045, dur: float = 0.28) -> void:
	## 列表错落入场（hierarchy reveal）
	if parent == null: return
	delay = _dur(delay); dur = _dur(dur)
	var i := 0
	for c in parent.get_children():
		if c is CanvasItem:
			var ci: CanvasItem = c
			ci.modulate.a = 0.0
			if c is Control:
				(c as Control).scale = Vector2(0.96, 0.96)
			var tw = ci.create_tween()
			tw.tween_interval(delay * i)
			tw.tween_property(ci, "modulate:a", 1.0, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			if c is Control:
				tw.parallel().tween_property(c, "scale", Vector2.ONE, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			i += 1

static func press_feedback(node: Control) -> void:
	## 按压微交互 ~120ms（web button press）
	if node == null: return
	var tw = node.create_tween()
	tw.tween_property(node, "scale", Vector2(0.96, 0.96), _dur(0.07)).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, _dur(0.11)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

static func hover_lift(node: Control, up: float = 0.03) -> void:
	if node == null: return
	var tw = node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * (1.0 + up), _dur(0.14)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

static func hover_settle(node: Control) -> void:
	if node == null: return
	var tw = node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, _dur(0.16)).set_ease(Tween.EASE_OUT)

static func breathe(node: CanvasItem, amp: float = 0.012, period: float = 2.4) -> void:
	## 闲置呼吸——界面「活着」（AT: nothing static）
	if node == null or reduced(): return
	if node is Control:
		var c: Control = node
		var tw = c.create_tween().set_loops()
		tw.tween_property(c, "scale", Vector2.ONE * (1.0 + amp), period * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(c, "scale", Vector2.ONE, period * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	else:
		var base = node.modulate
		var hi = Color(base.r, base.g, base.b, minf(1.0, base.a + 0.08))
		var tw2 = node.create_tween().set_loops()
		tw2.tween_property(node, "modulate", hi, period * 0.5).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(node, "modulate", base, period * 0.5).set_trans(Tween.TRANS_SINE)

static func slide_from(node: Control, dir: Vector2, dist: float = 36.0, dur: float = 0.34) -> void:
	## 空间来源入场（面板从哪来回哪去）
	if node == null: return
	dur = _dur(dur)
	var target = node.position
	node.position = target + dir.normalized() * dist
	node.modulate.a = 0.0
	var tw = node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "position", target, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(node, "modulate:a", 1.0, dur)

static func exit_fade(node: CanvasItem, dur: float = 0.18) -> void:
	## 退出更快（ease-in，比入场短）
	if node == null: return
	var tw = node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, _dur(dur)).set_ease(Tween.EASE_IN)

static func confirm_burst(node: Control) -> void:
	## 确认分层：缩放弹 + 闪色
	if node == null: return
	punch(node, 0.08)
	flash_modulate(node, Color(1.25, 1.15, 0.95), 0.2)
