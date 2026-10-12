extends RefCounted
## Landscape phone: turns a hand-placed desktop panel (absolute children) into a container
## layout. Children are grouped into rows by their y position, rows become wrapping flows,
## text goes to 22px (≈12dp) and buttons to 76px (48dp). See docs/design/mobile-landscape.md.

const FONT := 22
const HIT := 76.0


## Replace every hand-placed Panel under `host` (direct children) with a reflowed column.
static func reflow_children(host: Control, w: float) -> void:
	for c in host.get_children():
		if c is Control and not c.is_queued_for_deletion() and not c.has_meta("m_reflowed"):
			reflow(c as Control, w)


static func reflow(p: Control, w: float) -> Control:
	if p is Container:
		p.set_meta("m_reflowed", true)
		grow(p, w)
		return p
	var kids: Array = []
	for ch in p.get_children():
		if ch is Control and (ch as Control).visible and not ch.is_queued_for_deletion():
			var cc := ch as Control
			if cc is ColorRect and cc.size.y <= 3.0:
				continue
			kids.append(cc)
	kids.sort_custom(func(a, b): return a.position.y < b.position.y or (absf(a.position.y - b.position.y) < 0.5 and a.position.x < b.position.x))
	var rows: Array = []
	var row_end := -1e9
	for k in kids:
		var kc := k as Control
		var h := maxf(kc.size.y, kc.get_combined_minimum_size().y)
		if rows.is_empty() or kc.position.y >= row_end - 4.0:
			rows.append([kc])
			row_end = kc.position.y + h
		else:
			rows[-1].append(kc)
			row_end = maxf(row_end, kc.position.y + h)
	var out: Control
	var inner_w := w
	if p.get_class() == "Panel":
		var pc := PanelContainer.new()
		var sb = p.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var s2: StyleBoxFlat = (sb as StyleBoxFlat).duplicate()
			s2.content_margin_left = maxf(s2.content_margin_left, 14)
			s2.content_margin_right = maxf(s2.content_margin_right, 14)
			s2.content_margin_top = maxf(s2.content_margin_top, 12)
			s2.content_margin_bottom = maxf(s2.content_margin_bottom, 12)
			pc.add_theme_stylebox_override("panel", s2)
		out = pc
		inner_w = w - 28.0
	else:
		out = MarginContainer.new()
	out.name = p.name
	out.set_meta("m_reflowed", true)
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	out.mouse_filter = p.mouse_filter
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	out.add_child(v)
	for r in rows:
		r.sort_custom(func(a, b): return a.position.x < b.position.x)
		var holder: Control = v
		if r.size() > 1:
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 12)
			flow.add_theme_constant_override("v_separation", 6)
			flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(flow)
			holder = flow
		for k in r:
			var kc := k as Control
			kc.reparent(holder, false)
			_settle(kc, inner_w, r.size() == 1)
	var parent := p.get_parent()
	if parent != null:
		var idx := p.get_index()
		parent.remove_child(p)
		parent.add_child(out)
		parent.move_child(out, idx)
	for ch in p.get_children():
		ch.queue_free()
	p.queue_free()
	return out


static func _settle(c: Control, w: float, alone: bool) -> void:
	c.position = Vector2.ZERO
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if c.clip_contents and c.get_class() == "Control":
		# a cropped picture window: keep its art as drawn
		c.custom_minimum_size = c.size
		return
	if c is TextureRect or c is ProgressBar or c is ColorRect or c is TextureButton:
		c.custom_minimum_size = Vector2(minf(maxf(c.custom_minimum_size.x, c.size.x), w), maxf(c.custom_minimum_size.y, c.size.y))
		if c is ProgressBar or c is ColorRect:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.custom_minimum_size.x = 0
		return
	if c.get_class() == "Panel" or (c.get_class() == "Control" and c.get_child_count() > 0):
		var r := reflow(c, w)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL if alone else Control.SIZE_FILL
		return
	if c is Label and alone:
		(c as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size = Vector2(0, 0)
	elif c is Label:
		(c as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
		c.custom_minimum_size = Vector2(0, 0)
	if c is Button and alone:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow(c, w)


static func grow(n: Node, w: float) -> void:
	if n is Label:
		var l := n as Label
		l.add_theme_font_size_override("font_size", maxi(FONT, l.get_theme_font_size("font_size")))
		l.clip_text = false
		l.max_lines_visible = -1
		if l.get_parent() is FlowContainer and l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.get_minimum_size().x > w * 0.7:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = w
		if l.get_parent() is VBoxContainer:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			l.custom_minimum_size.x = 0
	elif n is RichTextLabel:
		var rt := n as RichTextLabel
		for k in ["normal_font_size", "bold_font_size", "mono_font_size"]:
			rt.add_theme_font_size_override(k, FONT)
		rt.custom_minimum_size.x = 0
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif n is Button:
		var b := n as Button
		b.add_theme_font_size_override("font_size", maxi(FONT, b.get_theme_font_size("font_size")))
		b.custom_minimum_size = Vector2(clampf(b.custom_minimum_size.x, HIT, w), HIT)
		b.clip_text = false
		for k in ["icon_max_width"]:
			b.add_theme_constant_override(k, 40)
	elif n is Control and not (n is Container) and (n as Control).custom_minimum_size.x > w:
		(n as Control).custom_minimum_size.x = w
	if n is Control and (n as Control).custom_minimum_size.x > w and not (n is Button):
		(n as Control).custom_minimum_size.x = w
	for ch in n.get_children():
		if ch is Control and ch.get_class() == "Panel" and not (n is Container) and ch.get_child_count() > 0:
			continue
		grow(ch, w)
	if n is HBoxContainer and (n as Control).get_combined_minimum_size().x > w:
		_to_flow(n as HBoxContainer)


## A row that no longer fits wraps instead of running off the column.
static func _to_flow(row: HBoxContainer) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 6)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.mouse_filter = row.mouse_filter
	var nm := row.name
	var parent := row.get_parent()
	if parent == null:
		return
	var idx := row.get_index()
	for k in row.get_children():
		k.reparent(flow, false)
		if k is Control:
			(k as Control).size_flags_horizontal = Control.SIZE_FILL
	parent.remove_child(row)
	row.queue_free()
	flow.name = nm
	parent.add_child(flow)
	parent.move_child(flow, idx)


## A scrolling column at `rect`; returns its stack.
static func column(host: Control, nm: String, rect: Rect2) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = nm
	sc.position = rect.position
	sc.size = rect.size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(sc)
	var v := VBoxContainer.new()
	v.name = "Stack"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	return v
