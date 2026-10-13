class_name BannerName
extends RefCounted
## Opening review B-02: the surname written in the middle of the company banner — charcoal,
## heavy at the start, slightly crooked — on every on-screen banner. Settings key
## "banner_name" (default on) hides it.

const FONT := preload("res://assets/fonts/NotoSansSC-Bold-ck.otf")
const NODE := "BannerName"


static func attach(tr: Control, surname: String = "") -> Label:
	if tr == null:
		return null
	var text := surname if surname != "" else str(GameState.surname)
	text = text.strip_edges().left(2)
	var lab := tr.get_node_or_null(NODE) as Label
	if lab == null:
		lab = Label.new()
		lab.name = NODE
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.set_anchors_preset(Control.PRESET_FULL_RECT)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.add_theme_font_override("font", FONT)
		lab.rotation = -0.07
		tr.add_child(lab)
		lab.resized.connect(func(): lab.pivot_offset = lab.size * 0.5)
	var box := tr.custom_minimum_size if tr.custom_minimum_size.x > 0.0 else tr.size
	var px := int(clampf(minf(box.x, box.y * 0.72) * (0.5 if text.length() <= 1 else 0.32), 10.0, 160.0))
	lab.add_theme_font_size_override("font_size", px)
	lab.add_theme_color_override("font_color", Color(0.1, 0.09, 0.08, 0.92))
	lab.add_theme_color_override("font_outline_color", Color(0.96, 0.94, 0.88, 0.85))
	lab.add_theme_constant_override("outline_size", maxi(2, px / 9))
	lab.text = text
	lab.visible = text != "" and bool(GameState.settings.get("banner_name", true))
	return lab
