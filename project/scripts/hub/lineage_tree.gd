extends Control
## Genealogy v2 details (docs/design/genealogy-v2.md): one person's family tree.
## Parents above, the person and spouse(s) in the middle, children below.
## Drag pans, pinch / wheel zooms; tapping a node fills the right panel, "以此为中心" re-focuses.

const VIEW := Rect2(24, 72, 820, 600)
const NODE := Vector2(132, 150)
const GAP := 20.0
const ROW_Y := [24.0, 224.0, 424.0]
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const DRAG_SLOP := 10.0
const OVERVIEW := "res://scenes/hub/lineage_view.tscn"

var focus_id := ""
var _selected: CKCharacter
var _view: Panel
var _canvas: Control
var _info: Control
var _title: Label
var _drag_dist := 0.0
var _touches: Dictionary = {}
var _pinch_d := 0.0

func _ready() -> void:
	var p: Dictionary = CKNav.params()
	focus_id = str(p.get("focus", ""))
	if not GameState.characters.has(focus_id):
		var l = GameState.get_leader()
		focus_id = str(l.id) if l != null else ""
	_build()
	refocus(focus_id)

func nav_back() -> void:
	## details -> overview. The overview pushed us with CKNav.go, so pop that entry.
	if not CKNav.stack.is_empty():
		var top: Dictionary = CKNav.stack.pop_back()
		CKNav.replace(str(top.path), top.get("params", {}))
	else:
		CKNav.replace(OVERVIEW)

func _back() -> void:
	nav_back()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		nav_back()
		get_viewport().set_input_as_handled()

func _build() -> void:
	UIKit.void_bg(self)
	UIKit.top_bar(self, Locale.t("gen2_11") % GameState.surname, [], Locale.t("gen2_12"), nav_back)
	CKHeraldryChrome.place_company_header(self, Vector2(800, 2), Vector2(44, 52))
	_view = Panel.new()
	_view.name = "TreeViewport"
	_view.position = VIEW.position
	_view.size = VIEW.size
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.015), Color(1, 1, 1, 0.08), 10))
	_view.gui_input.connect(_on_view_input)
	add_child(_view)
	_canvas = Control.new()
	_canvas.name = "TreeCanvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.add_child(_canvas)
	_title = UIKit.mono("", 10, UIKit.TEXT_FAINT, false)
	_title.position = VIEW.position + Vector2(12, 8)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_info = Control.new()
	_info.name = "InfoHost"
	_info.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_info)
	if not DeviceProfile.is_mobile():
		UIKit.footer_bar(self, [[Locale.t("gen2_13"), Locale.t("gen2_14")], [Locale.t("gen2_15"), Locale.t("gen2_16")], ["ESC", Locale.t("gen2_12")]], "GENEALOGY v2")
	UIFX.page_enter(self)

func apply_mobile_layout() -> void:
	var foot := get_node_or_null("StitchFooter") as Control
	MobileLayout.pin_footer(foot)
	if not DeviceProfile.is_mobile():
		return
	var w := maxf(size.x, 1280.0)
	var ca := get_node_or_null("CastleArms") as Control
	if ca:
		ca.visible = true
		ca.position = Vector2(w - 64.0, 6.0)
		ca.size = Vector2(52, 60)
		ca.custom_minimum_size = Vector2(52, 60)
	var bottom := (foot.position.y if foot else size.y) - 8.0
	if _view != null:
		_view.position = Vector2(12.0, 72.0)
		_view.size = Vector2(minf(820.0, w * 0.55), maxf(400.0, bottom - 80.0))
	if _title != null:
		_title.add_theme_font_size_override("font_size", MobileLayout.FONT_FLOOR)
		_title.size = Vector2(maxf(_title.size.x, 200.0), maxf(_title.size.y, float(MobileLayout.FONT_FLOOR) + 6.0))
	if _canvas != null:
		for n in _canvas.get_children():
			if n is Label and str(n.name) == "GapLabel":
				var g := n as Label
				g.add_theme_font_size_override("font_size", MobileLayout.FONT_FLOOR)
				g.size.y = maxf(g.size.y, float(MobileLayout.FONT_FLOOR) + 8.0)
			elif n is Button:
				for ch in n.get_children():
					if ch is Label:
						var lab := ch as Label
						lab.add_theme_font_size_override("font_size", MobileLayout.FONT_FLOOR)
						lab.size.y = maxf(lab.size.y, float(MobileLayout.FONT_FLOOR) + 6.0)
	_render_info()

func selected() -> CKCharacter:
	return _selected

func canvas() -> Control:
	return _canvas

func refocus(id: String) -> void:
	focus_id = id
	for n in _canvas.get_children():
		_canvas.remove_child(n)
		n.queue_free()
	var chars: Dictionary = GameState.characters
	var c: CKCharacter = chars.get(id)
	_selected = c
	if c == null:
		var l := UIKit.body_label(Locale.t("gen2_17"), UIKit.TEXT_FAINT, 15)
		l.position = Vector2(24, 40)
		_canvas.add_child(l)
		_canvas.size = VIEW.size
		_render_info()
		return
	_title.text = Locale.t("gen2_18") % c.name
	var rows := [CKLineageInfo.parents_of(chars, c), [c] + CKLineageInfo.spouses_of(chars, c), CKLineageInfo.children_of(chars, c)]
	var widest := 0
	for r in rows:
		widest = maxi(widest, r.size())
	var w := maxf(VIEW.size.x, widest * (NODE.x + GAP) + GAP * 2)
	_canvas.size = Vector2(w, ROW_Y[2] + NODE.y + 30)
	var pos: Dictionary = {}
	for ri in rows.size():
		var r: Array = rows[ri]
		var rw := r.size() * (NODE.x + GAP) - GAP
		var x := (w - rw) * 0.5
		for person in r:
			pos[person.id] = Vector2(x, ROW_Y[ri])
			_canvas.add_child(_node(person, Vector2(x, ROW_Y[ri]), person == c))
			x += NODE.x + GAP
	if rows[0].is_empty():
		_canvas.add_child(_gap_label(Locale.t("gen2_19"), w, ROW_Y[0] + 60))
	if rows[2].is_empty():
		_canvas.add_child(_gap_label(Locale.t("gen2_20"), w, ROW_Y[2] + 60))
	var me: Vector2 = pos[c.id]
	for sp in rows[1]:
		if sp != c:
			_line([me + Vector2(NODE.x, NODE.y * 0.5), pos[sp.id] + Vector2(0, NODE.y * 0.5)], UIKit.OK)
	for par in rows[0]:
		_line([pos[par.id] + Vector2(NODE.x * 0.5, NODE.y), me + Vector2(NODE.x * 0.5, 0)], UIKit.ACCENT)
	for kid in rows[2]:
		var top := me + Vector2(NODE.x * 0.5, NODE.y)
		var bot: Vector2 = pos[kid.id] + Vector2(NODE.x * 0.5, 0)
		var mid := (top.y + bot.y) * 0.5
		_line([top, Vector2(top.x, mid), Vector2(bot.x, mid), bot], UIKit.ACCENT)
	set_zoom(1.0)
	# centre the focused person in view
	_canvas.position = Vector2(VIEW.size.x * 0.5 - (me.x + NODE.x * 0.5), 0)
	_clamp()
	_render_info()

## "父母未录" / "尚无子女": one horizontal line centred over the empty row (it used to have no
## width, so autowrap stacked it one glyph per line).
func _gap_label(text: String, w: float, y: float) -> Label:
	var g := UIKit.body_label(text, UIKit.TEXT_FAINT, 12)
	g.name = "GapLabel"
	g.autowrap_mode = TextServer.AUTOWRAP_OFF
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.position = Vector2(0, y)
	g.size = Vector2(w, 32)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g

func _line(pts: Array, col: Color) -> void:
	var l := Line2D.new()
	for p in pts:
		l.add_point(p)
	l.width = 2.0
	l.default_color = Color(col, 0.55)
	l.antialiased = true
	_canvas.add_child(l)
	_canvas.move_child(l, 0)

func _node(c: CKCharacter, at: Vector2, is_focus: bool) -> Button:
	var b := Button.new()
	b.name = "Node_%s" % c.id
	b.set_meta("cid", c.id)
	b.position = at
	b.size = NODE
	b.custom_minimum_size = NODE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var bg := Color(UIKit.ACCENT, 0.08) if is_focus else Color(0.055, 0.067, 0.090, 0.92)
	var bd := UIKit.ACCENT if is_focus else Color(1, 1, 1, 0.12)
	b.add_theme_stylebox_override("normal", UIKit.flat_box(bg, bd, 8, 2 if is_focus else 1))
	b.add_theme_stylebox_override("hover", UIKit.flat_box(Color(0.07, 0.09, 0.12, 0.95), Color(UIKit.ACCENT, 0.45), 8))
	b.add_theme_stylebox_override("focus", UIKit._focus_ring(UIKit.FOCUS_RING, 10))
	var mob := DeviceProfile.is_mobile()
	var por := CKLineageInfo.portrait_rect(c, Vector2(66, 76) if mob else Vector2(84, 96))
	por.position = Vector2(33, 6) if mob else Vector2(24, 8)
	b.add_child(por)
	var nm := UIKit.body_label(c.name, UIKit.TEXT if c.alive else UIKit.TEXT_FAINT, 13)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.position = Vector2(4, 84 if mob else 108)
	nm.size = Vector2(NODE.x - 8, 30 if mob else 18)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nm)
	var sub := UIKit.body_label((Locale.t("gen2_21") % c.age) if c.alive else Locale.t("gen2_22"), UIKit.OK if c.alive else UIKit.TEXT_FAINT, 11)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(4, 116 if mob else 128)
	sub.size = Vector2(NODE.x - 8, 30 if mob else 16)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sub)
	CKHeraldryChrome.attach_node_chrome(b, c, NODE)
	b.pressed.connect(func():
		if _drag_dist > DRAG_SLOP:
			return
		UIFX.press_feedback(b)
		select(c))
	return b

func select(c: CKCharacter) -> void:
	_selected = c
	_render_info()

func _render_info() -> void:
	var can_refocus := _selected != null and str(_selected.id) != focus_id
	if DeviceProfile.is_mobile():
		var vw := maxf(get_viewport().get_visible_rect().size.x, 1280.0)
		var x0 := VIEW.end.x + 16.0
		var rect := Rect2(x0, VIEW.position.y + 24.0, maxf(380.0, vw - x0 - 24.0), VIEW.size.y - 24.0)
		CKLineageInfo.render_mobile(_info, _selected, Locale.t("gen2_23") if can_refocus else "", func():
			Sfx.click()
			refocus(str(_selected.id)), rect)
		return
	CKLineageInfo.render(_info, _selected, Locale.t("gen2_23") if can_refocus else "", func():
		Sfx.click()
		refocus(str(_selected.id)))

# ── pan / zoom ─────────────────────────────────────────
func pan(delta: Vector2) -> void:
	_canvas.position += delta
	_clamp()

func set_zoom(z: float) -> void:
	_canvas.scale = Vector2.ONE * clampf(z, ZOOM_MIN, ZOOM_MAX)
	_clamp()

func zoom_by(f: float, around: Vector2 = VIEW.size * 0.5) -> void:
	var old := _canvas.scale.x
	var nz := clampf(old * f, ZOOM_MIN, ZOOM_MAX)
	var local := (around - _canvas.position) / old
	_canvas.scale = Vector2.ONE * nz
	_canvas.position = around - local * nz
	_clamp()

func _clamp() -> void:
	## keep at least `margin` px of the canvas on screen
	var s := _canvas.size * _canvas.scale.x
	var margin := 120.0
	_canvas.position.x = clampf(_canvas.position.x, margin - s.x, VIEW.size.x - margin)
	_canvas.position.y = clampf(_canvas.position.y, margin - s.y, VIEW.size.y - margin)

func _on_view_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_drag_dist = 0.0
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.1, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / 1.1, mb.position)
	elif e is InputEventMouseMotion and ((e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) and _touches.size() < 2:
		var rel := (e as InputEventMouseMotion).relative
		_drag_dist += rel.length()
		pan(rel)
	elif e is InputEventMagnifyGesture:
		zoom_by((e as InputEventMagnifyGesture).factor, (e as InputEventMagnifyGesture).position)
	elif e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
		_pinch_d = 0.0
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		_touches[d.index] = d.position
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var dist: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_d > 1.0:
				zoom_by(dist / _pinch_d, ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5)
			_pinch_d = dist
			_drag_dist = DRAG_SLOP + 1.0
