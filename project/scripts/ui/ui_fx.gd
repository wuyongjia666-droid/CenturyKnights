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

static func wire_button(btn: BaseButton) -> void:
	## 全态交互：hover / press / focus / disabled（每个控件必挂）
	if btn == null: return
	if btn.has_meta("uifx_wired"): return
	btn.set_meta("uifx_wired", true)
	btn.focus_mode = Control.FOCUS_ALL
	btn.button_down.connect(func():
		if btn.disabled:
			soft_deny(btn)
		else:
			press_feedback(btn)
	)
	btn.mouse_entered.connect(func():
		_sync_disabled_modulate(btn)
		if not btn.disabled:
			hover_lift(btn, 0.03)
			flash_modulate(btn, Color(1.05, 1.12, 1.2), 0.12)
	)
	btn.mouse_exited.connect(func():
		hover_settle(btn)
		_sync_disabled_modulate(btn)
	)
	btn.focus_entered.connect(func():
		if not btn.disabled:
			focus_ring(btn, Color(0.85, 0.95, 1.15), 0.28)
	)
	btn.focus_exited.connect(func(): hover_settle(btn))
	_sync_disabled_modulate(btn)

static func _sync_disabled_modulate(btn: BaseButton) -> void:
	if btn == null: return
	if btn.disabled:
		btn.modulate = Color(0.55, 0.52, 0.48, 0.72)
		btn.scale = Vector2.ONE
	elif btn.modulate.r < 0.9:
		btn.modulate = Color(1, 1, 1, 1)

static func wire_control(ctrl: Control) -> void:
	## 非按钮可聚焦控件：hover + focus
	if ctrl == null: return
	if ctrl.has_meta("uifx_ctrl_wired"): return
	ctrl.set_meta("uifx_ctrl_wired", true)
	if ctrl.focus_mode == Control.FOCUS_NONE:
		ctrl.focus_mode = Control.FOCUS_ALL
	ctrl.mouse_entered.connect(func(): hover_lift(ctrl, 0.02))
	ctrl.mouse_exited.connect(func(): hover_settle(ctrl))
	ctrl.focus_entered.connect(func(): focus_ring(ctrl))
	ctrl.focus_exited.connect(func(): hover_settle(ctrl))

static func wire_tree(root: Node) -> void:
	## 递归：BaseButton 全态 + LineEdit/Option/Slider/ItemList hover·focus
	if root == null: return
	if root is BaseButton:
		wire_button(root)
	elif root is LineEdit or root is TextEdit or root is OptionButton \
			or root is Slider or root is SpinBox or root is ItemList:
		wire_control(root)
	for c in root.get_children():
		wire_tree(c)

static func page_enter(root: Control, from: Vector2 = Vector2(0, 28)) -> void:
	## 页面级入场：淡入 + 微位移（AT / 前端 page transition）
	if root == null: return
	fade_in(root, 0.34)
	if reduced():
		return
	# 顶栏金线闪一下（若有 transition_rule）
	if ResourceLoader.exists("res://assets/art/ui/transition_rule.png"):
		var rule := TextureRect.new()
		rule.texture = load("res://assets/art/ui/transition_rule.png")
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule.position = Vector2(0, 44)
		rule.size = Vector2(1280, 8)
		rule.modulate.a = 0.0
		root.add_child(rule)
		var tw = rule.create_tween()
		tw.tween_property(rule, "modulate:a", 1.0, _dur(0.12))
		tw.tween_property(rule, "modulate:a", 0.0, _dur(0.28))
		tw.tween_callback(rule.queue_free)


static func chip_pulse(node: Control, col: Color = Color(1.35, 1.2, 0.85)) -> void:
	## 资源/徽标轻脉冲（月结、商队到港）
	if node == null: return
	flash_modulate(node, col, 0.22)
	punch(node, 0.05)

static func banner_shimmer(node: CanvasItem, period: float = 3.6) -> void:
	## 顶栏横幅慢速明暗（AT: living chrome）
	if node == null or reduced(): return
	var base := node.modulate
	var hi := Color(minf(1.0, base.r * 1.08), minf(1.0, base.g * 1.05), minf(1.0, base.b * 1.02), base.a)
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "modulate", hi, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "modulate", base, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

static func panel_rise(node: Control, dist: float = 18.0, dur: float = 0.30) -> void:
	## 面板从下方升起（对话框 / 确认层）
	if node == null: return
	dur = _dur(dur)
	var target := node.position
	node.position = target + Vector2(0, dist)
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "position", target, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(node, "modulate:a", 1.0, dur * 0.85)

static func soft_deny(node: Control) -> void:
	## 拒绝反馈：轻抖 + 冷色闪（比 confirm 弱）
	if node == null: return
	shake_control(node, 4.0, 0.18)
	flash_modulate(node, Color(0.95, 0.75, 0.75), 0.16)

static func resource_tick(node: Control) -> void:
	## 资源数字跳动（月结/买卖后）
	if node == null: return
	punch(node, 0.04)
	flash_modulate(node, Color(1.2, 1.15, 0.9), 0.14)

static func focus_ring(node: Control, col: Color = Color(1.15, 0.95, 0.55), dur: float = 0.4) -> void:
	## 焦点金环闪（族谱选人 / 大厅高亮）
	if node == null: return
	flash_modulate(node, col, dur)
	hover_lift(node, 0.02)

static func boss_threat(node: Control) -> void:
	## 精英登场压迫感：冷珊瑚闪 + 轻抖
	if node == null: return
	shake_control(node, 5.0, 0.28)
	flash_modulate(node, Color(1.2, 0.55, 0.65), 0.32)
	punch(node, 0.06)

static func select_pulse(node: Control, dur: float = 0.55) -> void:
	## 选中脉动（战棋选人 / 列表焦点）
	if node == null or reduced(): return
	dur = _dur(dur)
	var base := node.scale
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", base * 1.04, dur * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base, dur * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flash_modulate(node, Color(1.08, 1.14, 1.22), dur * 0.5)

static func soft_flash(node: CanvasItem, col: Color = Color(1.18, 1.1, 0.92), dur: float = 0.2) -> void:
	if node == null: return
	flash_modulate(node, col, dur)

static func list_ripple(parent: Node, delay: float = 0.035) -> void:
	## 列表项依次 punch（选中后反馈波）
	if parent == null or reduced(): return
	var i := 0
	for c in parent.get_children():
		if c is Control:
			var ctrl: Control = c
			var tw = ctrl.create_tween()
			tw.tween_interval(delay * i)
			tw.tween_callback(func(): punch(ctrl, 0.035))
			i += 1

static func nav_slide(node: Control, from_x: float = -24.0, dur: float = 0.28) -> void:
	## 侧栏/导航滑入
	if node == null: return
	slide_from(node, Vector2(from_x, 0), absf(from_x), dur)

static func page_exit(root: Control, dur: float = 0.16) -> void:
	## 页面离开：快于入场
	if root == null: return
	exit_fade(root, dur)

static func nav_press_then(btn: Control, cb: Callable) -> void:
	## 导航：先微交互再跳转，避免「死点」
	if btn != null:
		press_feedback(btn)
		confirm_burst(btn)
	cb.call()
