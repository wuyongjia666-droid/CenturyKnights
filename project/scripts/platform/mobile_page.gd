class_name MobilePage
extends RefCounted
## Landscape-phone page kit: 22px text (≈12dp), 76px buttons (48dp), container layout only,
## so text wraps instead of overlapping. See docs/design/mobile-landscape.md.

const FONT := 22
const HIT := 76.0
const TOP := 92.0

static func active(node: Control) -> bool:
	if not DeviceProfile.is_mobile() or not node.is_inside_tree():
		return false
	var vp := node.get_viewport().get_visible_rect().size
	return vp.x > vp.y * 1.2

static func width(node: Control) -> float:
	return maxf(node.size.x, 1280.0)

static func label(t: String, col: Color, fs: int = FONT, wrap: bool = true) -> Label:
	var l := UIKit.body_label(t, col, fs)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func button(t: String, accent: bool, cb: Callable, min_w: float = 0.0) -> Button:
	var b := UIKit.make_accent_button(t, 120) if accent else UIKit.make_button(t, 120)
	b.custom_minimum_size = Vector2(min_w, HIT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", FONT)
	b.clip_text = true
	b.pressed.connect(cb)
	return b

static func panel(parent: Control, rect: Rect2, margin: int = 14) -> VBoxContainer:
	var p := PanelContainer.new()
	p.position = rect.position
	p.size = rect.size
	var sb := UIKit.flat_box(Color(0.055, 0.067, 0.090, 0.92), Color(1, 1, 1, 0.10), 10)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v

## Replaces the desktop StitchTopBar/StitchFooter with one 76px row: title, info, buttons.
static func top_bar(scene: Control, title: String, info: String, buttons: Array) -> HBoxContainer:
	for nm in ["StitchTopBar", "StitchFooter"]:
		var n := scene.get_node_or_null(nm) as CanvasItem
		if n:
			n.visible = false
	var bar := HBoxContainer.new()
	bar.name = "MobileTopBar"
	bar.position = Vector2(26, 8)
	bar.size = Vector2(width(scene) - 50, HIT)
	bar.add_theme_constant_override("separation", 10)
	scene.add_child(bar)
	var t := label(title, UIKit.TEXT, 24, false)
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.add_child(t)
	# resources wrap to a second line instead of being cut off on narrow phones
	var inf := label(info, UIKit.ACCENT, FONT, true)
	inf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inf.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inf.max_lines_visible = 2
	inf.custom_minimum_size = Vector2(160, 0)
	inf.add_theme_constant_override("line_spacing", -4)
	bar.add_child(inf)
	inf.set_meta("m_raw", info)
	inf.resized.connect(_wrap_segments.bind(inf))
	for spec in buttons:
		var b := button(str(spec[0]), false, spec[1], 180)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		bar.add_child(b)
	return bar

## Breaks the info line only between " · " segments so a value like 士气 70 never splits.
static func _wrap_segments(inf: Label) -> void:
	var raw := str(inf.get_meta("m_raw", inf.text))
	var segs := raw.split(" · ")
	var font := inf.get_theme_font("font")
	var fs := inf.get_theme_font_size("font_size")
	var w := inf.size.x
	if font == null or w <= 0 or segs.size() < 2:
		return
	var lines: Array[String] = []
	var cur := ""
	for sg in segs:
		var cand := sg if cur == "" else cur + " · " + sg
		if cur != "" and font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			lines.append(cur)
			cur = sg
		else:
			cur = cand
	lines.append(cur)
	var txt := "\n".join(lines)
	if inf.text != txt:
		inf.text = txt

static func spacer(v: Control) -> void:
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)

## Centred phone sheet over a dim layer: returns [overlay, content VBox]. Width ~62% of the
## screen, height follows content up to the screen minus margins. Text 22-30px, buttons 76px.
static func sheet(host: Control, nm: String, title: String, z: int = 40, title_col: Color = UIKit.TEXT) -> Array:
	var w := width(host)
	var h := host.size.y if host.size.y > 400.0 else 720.0
	var overlay := ColorRect.new()
	overlay.name = nm
	overlay.color = Color(0.02, 0.03, 0.05, 0.72)
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(w, h)
	overlay.z_index = z
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(overlay)
	var center := CenterContainer.new()
	center.size = Vector2(w, h)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var p := PanelContainer.new()
	p.name = "SheetCard"
	p.custom_minimum_size = Vector2(clampf(w * 0.62, 760.0, 1040.0), 0)
	var sb := UIKit.flat_box(Color(0.06, 0.075, 0.10, 0.98), Color(UIKit.ACCENT, 0.55), 14, 2)
	for side in ["left", "right"]:
		sb.set("content_margin_" + side, 28)
	for side in ["top", "bottom"]:
		sb.set("content_margin_" + side, 22)
	p.add_theme_stylebox_override("panel", sb)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var t := label(title, title_col, 30, true)
	t.add_theme_font_override("font", UIKit.font("bold"))
	v.add_child(t)
	v.set_meta("max_h", h - 60.0)
	return [overlay, v]

## Scroll area inside a sheet that grows with its content up to the space left on screen.
static func sheet_scroll(v: VBoxContainer, reserve: float) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	sc.add_child(list)
	var cap := maxf(160.0, float(v.get_meta("max_h", 660.0)) - reserve)
	list.minimum_size_changed.connect(func():
		sc.custom_minimum_size.y = minf(cap, list.get_combined_minimum_size().y))
	sc.custom_minimum_size.y = cap * 0.5
	return list

## Raise every Label/Button/RichText under root to phone sizes (22px text, 76px buttons).
static func upsize(root: Node, fs: int = FONT) -> void:
	for n in root.find_children("*", "Control", true, false):
		if n is Button:
			var b := n as Button
			b.add_theme_font_size_override("font_size", maxi(fs, b.get_theme_font_size("font_size")))
			b.custom_minimum_size.y = maxf(HIT, b.custom_minimum_size.y)
			b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, 120.0)
		elif n is Label:
			var l := n as Label
			l.add_theme_font_size_override("font_size", maxi(fs, l.get_theme_font_size("font_size")))
		elif n is RichTextLabel:
			var r := n as RichTextLabel
			r.add_theme_font_size_override("normal_font_size", maxi(fs, r.get_theme_font_size("normal_font_size")))
			r.add_theme_font_size_override("bold_font_size", maxi(fs + 4, r.get_theme_font_size("bold_font_size")))
