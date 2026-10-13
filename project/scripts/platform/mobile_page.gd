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
