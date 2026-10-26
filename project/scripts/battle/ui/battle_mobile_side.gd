extends RefCounted
## Landscape phone: every side-rail panel (unit card, log, objective, rewind, lock tips)
## is stacked in one scrolling column left of the command rail, at readable size.

const COL := "MobileSideCol"
const FONT := 22
const HIT := 76.0
const SKIP := ["CommandRow", "CommandRow2", "ControlsTip", "BoardXform", "BattleDualLedger"]


static func attach(host: Control, x: float, w: float) -> void:
	var sc := host.get_node_or_null(COL) as ScrollContainer
	var top := 60.0
	var host_h := maxf(720.0, host.size.y if host.size.y > 1.0 else 720.0)
	var h := maxf(280.0, host_h - top - 10.0)
	if sc == null:
		sc = ScrollContainer.new()
		sc.name = COL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.z_index = 5
		host.add_child(sc)
		var vb := VBoxContainer.new()
		vb.name = "Stack"
		vb.add_theme_constant_override("separation", 10)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(vb)
		sc.position = Vector2(x, top)
		sc.size = Vector2(w, h)
		for c in host.get_children():
			_adopt(host, c)
		host.child_entered_tree.connect(_defer_adopt.bind(host))
	sc.position = Vector2(x, top)
	sc.size = Vector2(w, h)
	# T-P15: keep the column off the board and stop the card clipping / eating taps.
	BattleEdgePick.note_layout(host)


static func _defer_adopt(n: Node, host: Control) -> void:
	_adopt.call_deferred(host, n)


static func _adopt(host: Control, n: Node) -> void:
	if not is_instance_valid(n) or not (n is Control) or n.get_parent() != host:
		return
	var c := n as Control
	if c.name in SKIP or c.name == COL or c is ScrollContainer:
		return
	var px := float(c.get_meta("m_base_x", c.position.x))
	if px < 880.0 or c.size.x > 700.0 or c.position.y > 700.0:
		return
	var stack := host.get_node(COL + "/Stack")
	host.remove_child(c)
	stack.add_child(c)
	if c.name in ["ObjectiveHud", "LockPracticeBanner"]:
		stack.move_child(c, 0)
	c.z_index = 0
	c.custom_minimum_size = Vector2(0, 0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.clip_contents = false
	grow(c, (host.get_node(COL) as Control).size.x)


static func grow(n: Node, w: float) -> void:
	if n.has_method("mobile_layout"):
		n.mobile_layout(w - 48.0)
		return
	if n.has_meta("m_custom"):
		return
	if n is Label:
		var l := n as Label
		l.add_theme_font_size_override("font_size", maxi(FONT, l.get_theme_font_size("font_size")))
		if not (l.get_parent() is HBoxContainer):
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.clip_text = false
		l.max_lines_visible = -1
		# Y1-A T-P2-1: never let a floored label collapse below one line of glyphs.
		var fs: float = float(l.get_theme_font_size("font_size"))
		l.custom_minimum_size = Vector2(0, maxf(l.custom_minimum_size.y, fs + 4.0))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif n is RichTextLabel:
		var r := n as RichTextLabel
		for k in ["normal_font_size", "bold_font_size", "mono_font_size"]:
			r.add_theme_font_size_override(k, maxi(FONT, r.get_theme_font_size(k)))
		var rfs: float = float(r.get_theme_font_size("normal_font_size"))
		r.custom_minimum_size = Vector2(0, maxf(r.custom_minimum_size.y, rfs + 4.0))
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif n is Button:
		var b := n as Button
		b.add_theme_font_size_override("font_size", maxi(FONT, b.get_theme_font_size("font_size")))
		b.custom_minimum_size = Vector2(clampf(b.custom_minimum_size.x, 96.0, w), HIT)
		b.clip_text = false
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif n is Control and not (n is Container) and (n as Control).custom_minimum_size.x > w:
		(n as Control).custom_minimum_size.x = w - 40.0
	for ch in n.get_children():
		grow(ch, w)
	if n.get_class() == "Panel":
		_flow_panel(n as Control)


## A plain Panel lays its row out by hand; give it a wrapping row and grow to fit.
static func _flow_panel(p: Control) -> void:
	var box: Control = null
	for ch in p.get_children():
		if ch is BoxContainer or ch is FlowContainer:
			box = ch
	if box == null:
		return
	if box is HBoxContainer:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 6)
		flow.mouse_filter = box.mouse_filter
		var nm := box.name
		for k in box.get_children():
			k.reparent(flow, false)
			if k is Label:
				(k as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
		p.remove_child(box)
		box.queue_free()
		flow.name = nm
		p.add_child(flow)
		box = flow
	box.position = Vector2(12, 8)
	var fit := func():
		if not is_instance_valid(box):
			return
		box.size = Vector2(maxf(40.0, p.size.x - 24.0), 0)
		var h := box.get_combined_minimum_size().y + 16.0
		if absf(p.custom_minimum_size.y - h) > 1.0:
			p.custom_minimum_size = Vector2(0, h)
	p.resized.connect(fit)
	box.minimum_size_changed.connect(fit)
	fit.call_deferred()


## A story bark takes over the side column while it is up.
static func yield_to(host: Node, bark: Control) -> void:
	bark.visibility_changed.connect(_sync.bind(host, bark))
	_sync.call_deferred(host, bark)
	host.child_entered_tree.connect(_on_child.bind(host, bark))


static func _on_child(n: Node, host: Node, bark: Control) -> void:
	if n.name == COL:
		_sync.call_deferred(host, bark)


static func _sync(host: Node, bark: Control) -> void:
	var sc := host.get_node_or_null(COL) as Control
	if sc != null and is_instance_valid(bark):
		sc.visible = not bark.is_visible_in_tree()
