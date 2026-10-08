class_name UIKit
extends RefCounted

## v8.6.0-art "CenturyKnights Frost" — tokens from the live Google Stitch design system (tokens.json).
## Dark luminous ink void · frosted glass panels · 1px highlight stroke · generous whitespace · thin type.
## Crystal frost = primary/focus only · mint = ally/heal · coral = enemy/deny · ember = sparks only.
## NO medieval cliché, NO ice-crystal frame plates on chrome (retired v8.6), NO parchment/gold.
const BG := Color("#07080C")
const BG_DEEP := Color("#040507")
const BG_GLOW := Color("#10141C")
const PANEL := Color("#161B24")
const PANEL_LIT := Color("#1C2330")
const ACCENT := Color("#6ED4FF")
const ACCENT_HOVER := Color("#9BE4FF")
const ACCENT_PRESSED := Color("#3AADDF")
const ON_ACCENT := Color("#041018")
const ACCENT_DIM := Color("#2A4554")
const TEXT := Color("#F4F7FB")
const TEXT_DIM := Color("#9AA6B8")
const TEXT_FAINT := Color("#6B7585")
const DANGER := Color("#FF7A70")
const OK := Color("#5EE0B5")
const PARCHMENT := Color("#F4F7FB")     # legacy name -> headline text
const STONE := Color("#2A3240")
const FOCUS_RING := Color("#6ED4FF")
const STROKE := Color(1, 1, 1, 0.14)
const STROKE_HI := Color(1, 1, 1, 0.22)
const DISABLED_BG := Color(1, 1, 1, 0.025)
const DISABLED_BORDER := Color(1, 1, 1, 0.07)
const DISABLED_TEXT := Color("#4E5664")
const EMBER := Color("#FF8A3D")
const RETIRE_CHROME := true   # v8.6: ice-crystal frame plates + banner strips retired from chrome
const SZ_DISPLAY := 40
const SZ_TITLE := 28
const SZ_HEADLINE := 19
const SZ_BODY := 15
const SZ_LABEL := 12

static var _fonts: Dictionary = {}
static var _theme: Theme

static func font(kind: String = "regular") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = {"regular": "res://assets/fonts/NotoSansSC-Regular-ck.otf", "bold": "res://assets/fonts/NotoSansSC-Bold-ck.otf", "mono": "res://assets/fonts/JetBrainsMono-Variable.ttf"}.get(kind, "")
	var f: Font = null
	if path != "" and ResourceLoader.exists(path):
		f = load(path)
		if kind == "mono" and f is FontFile:
			var fv := FontVariation.new()
			fv.base_font = f
			fv.variation_opentype = {"wght": 500}
			var cjk := font("regular")
			if cjk:
				fv.fallbacks = [cjk]
			f = fv
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[kind] = f
	return f

static func glass(radius: int = 12, alpha: float = 0.78, elevated: bool = false) -> StyleBoxFlat:
	## frosted glass: translucent slate, 1px highlight stroke, soft long shadow
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL_LIT if elevated else PANEL, alpha)
	sb.border_color = STROKE_HI if elevated else STROKE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.42)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(0, 10)
	sb.anti_aliasing = true
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	return sb

static func hairline(color: Color = STROKE, w: float = 1.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, w)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func _btn_box(bg: Color, border: Color, bw: int = 1, radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb

static func _focus_ring(col: Color = FOCUS_RING, radius: int = 10) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.border_color = col
	f.set_border_width_all(2)
	f.set_corner_radius_all(radius)
	f.expand_margin_left = 3
	f.expand_margin_right = 3
	f.expand_margin_top = 3
	f.expand_margin_bottom = 3
	f.anti_aliasing = true
	return f

static func _secondary_states() -> Dictionary:
	return {
		"normal": _btn_box(Color(1, 1, 1, 0.045), STROKE),
		"hover": _btn_box(Color(1, 1, 1, 0.09), STROKE_HI),
		"pressed": _btn_box(Color(0, 0, 0, 0.28), Color(ACCENT, 0.45)),
		"focus": _focus_ring(),
		"disabled": _btn_box(DISABLED_BG, DISABLED_BORDER),
	}

static func _primary_states() -> Dictionary:
	return {
		"normal": _btn_box(ACCENT, Color(ACCENT_HOVER, 0.9)),
		"hover": _btn_box(ACCENT_HOVER, Color(1, 1, 1, 0.9)),
		"pressed": _btn_box(ACCENT_PRESSED, ACCENT_PRESSED),
		"focus": _focus_ring(Color(1, 1, 1, 0.92)),
		"disabled": _btn_box(ACCENT_DIM, Color(ACCENT_DIM, 0.6)),
	}

static func _apply_states(b: Control, st: Dictionary) -> void:
	for k in st.keys():
		b.add_theme_stylebox_override(k, st[k])
	b.add_theme_stylebox_override("hover_pressed", st["pressed"])

static func frost_theme() -> Theme:
	## project-wide Theme: every Control gets token chrome even when a screen builds raw nodes
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("regular")
	t.default_font_size = SZ_BODY
	var sec := _secondary_states()
	for typ in ["Button", "OptionButton", "MenuButton", "CheckButton", "CheckBox", "LinkButton"]:
		for k in sec.keys():
			if typ in ["CheckButton", "CheckBox"] and k != "focus":
				var e := StyleBoxEmpty.new()
				e.content_margin_left = 6
				e.content_margin_right = 6
				t.set_stylebox(k, typ, e)
				continue
			t.set_stylebox(k, typ, sec[k])
		t.set_stylebox("hover_pressed", typ, sec["pressed"] if not typ in ["CheckButton", "CheckBox"] else StyleBoxEmpty.new())
		t.set_color("font_color", typ, TEXT)
		t.set_color("font_hover_color", typ, Color.WHITE)
		t.set_color("font_pressed_color", typ, ACCENT)
		t.set_color("font_hover_pressed_color", typ, ACCENT_HOVER)
		t.set_color("font_focus_color", typ, Color.WHITE)
		t.set_color("font_disabled_color", typ, DISABLED_TEXT)
		t.set_constant("h_separation", typ, 8)
	for typ in ["PanelContainer", "Panel"]:
		t.set_stylebox("panel", typ, glass())
	var pop := glass(10, 0.96, true)
	pop.content_margin_left = 8
	pop.content_margin_right = 8
	pop.content_margin_top = 8
	pop.content_margin_bottom = 8
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("panel", "PopupPanel", pop)
	var hov := _btn_box(Color(ACCENT, 0.14), Color(0, 0, 0, 0), 0, 6)
	t.set_stylebox("hover", "PopupMenu", hov)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	var tip := glass(8, 0.96, true)
	tip.shadow_size = 10
	tip.content_margin_left = 12
	tip.content_margin_right = 12
	tip.content_margin_top = 8
	tip.content_margin_bottom = 8
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	var le := _btn_box(Color(0, 0, 0, 0.32), STROKE, 1, 8)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", _focus_ring())
	t.set_stylebox("read_only", "LineEdit", _btn_box(DISABLED_BG, DISABLED_BORDER))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_FAINT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.3))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("bold_font", "RichTextLabel", font("bold"))
	t.set_font("mono_font", "RichTextLabel", font("mono"))
	var pb_bg := _btn_box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 3)
	pb_bg.content_margin_top = 0
	pb_bg.content_margin_bottom = 0
	var pb_fg := _btn_box(ACCENT, Color(0, 0, 0, 0), 0, 3)
	pb_fg.content_margin_top = 0
	pb_fg.content_margin_bottom = 0
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fg)
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_font_size("font_size", "ProgressBar", 11)
	for sbt in ["VScrollBar", "HScrollBar"]:
		var tr := StyleBoxFlat.new()
		tr.bg_color = Color(1, 1, 1, 0.03)
		tr.set_corner_radius_all(3)
		tr.content_margin_left = 3
		tr.content_margin_right = 3
		tr.content_margin_top = 3
		tr.content_margin_bottom = 3
		var gr := StyleBoxFlat.new()
		gr.bg_color = Color(1, 1, 1, 0.16)
		gr.set_corner_radius_all(3)
		var grh := gr.duplicate()
		grh.bg_color = Color(ACCENT, 0.6)
		t.set_stylebox("scroll", sbt, tr)
		t.set_stylebox("grabber", sbt, gr)
		t.set_stylebox("grabber_highlight", sbt, grh)
		t.set_stylebox("grabber_pressed", sbt, grh)
	var slider := _btn_box(Color(1, 1, 1, 0.10), Color(0, 0, 0, 0), 0, 2)
	slider.content_margin_top = 2
	slider.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", slider)
	var area := _btn_box(Color(ACCENT, 0.8), Color(0, 0, 0, 0), 0, 2)
	area.content_margin_top = 2
	area.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", area)
	t.set_stylebox("grabber_area_highlight", "HSlider", area)
	var tab_sel := _btn_box(Color(1, 1, 1, 0.08), STROKE_HI, 1, 8)
	var tab_un := _btn_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 8)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", sec["hover"])
	t.set_stylebox("panel", "TabContainer", glass())
	t.set_stylebox("panel", "ItemList", glass(10, 0.6))
	t.set_stylebox("selected", "ItemList", _btn_box(Color(ACCENT, 0.16), Color(ACCENT, 0.5)))
	t.set_stylebox("focus", "ItemList", _focus_ring())
	t.set_color("font_color", "ItemList", TEXT)
	_theme = t
	return t

static func make_button(text: String, min_w: int = 160) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 40)
	_style_button(b)
	b.pressed.connect(func(): Sfx.click())
	UIFX.wire_button(b)
	return b

static func make_accent_button(text: String, min_w: int = 160) -> Button:
	## primary: crystal-frost fill, ink text — reserved for the main action on a screen
	var b := make_button(text, min_w)
	b.pressed.connect(func(): Sfx.confirm())
	_apply_states(b, _primary_states())
	b.add_theme_color_override("font_color", ON_ACCENT)
	b.add_theme_color_override("font_hover_color", ON_ACCENT)
	b.add_theme_color_override("font_pressed_color", ON_ACCENT)
	b.add_theme_color_override("font_hover_pressed_color", ON_ACCENT)
	b.add_theme_color_override("font_focus_color", ON_ACCENT)
	b.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	b.add_theme_font_override("font", font("bold"))
	b.focus_mode = Control.FOCUS_ALL
	return b

static func _style_button(b: Button) -> void:
	## 全态：normal / hover / pressed / focus / disabled — frosted secondary
	_apply_states(b, _secondary_states())
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	b.focus_mode = Control.FOCUS_ALL

static func _tex_style(tex_path: String, fallback: StyleBoxFlat, margins: Vector2i = Vector2i(12, 10)) -> StyleBox:
	## v8.6: chrome plates retired — always token flat style
	fallback.content_margin_left = margins.x
	fallback.content_margin_right = margins.x
	fallback.content_margin_top = margins.y
	fallback.content_margin_bottom = margins.y
	return fallback

static func _flat(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := _btn_box(bg, border, 1, radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func make_label(text: String, large: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", TEXT)
	if large:
		l.add_theme_font_size_override("font_size", SZ_TITLE)
		l.add_theme_color_override("font_color", TEXT)
	else:
		l.add_theme_font_size_override("font_size", SZ_BODY)
	return l

static func make_dim_label(text: String) -> Label:
	var l := make_label(text)
	l.add_theme_color_override("font_color", TEXT_DIM)
	l.add_theme_font_size_override("font_size", 13)
	return l

static func make_panel() -> PanelContainer:
	## v8.6: frosted glass (1px stroke). Ice-crystal panel_chrome plates retired.
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", glass())
	return p

static func make_glass(radius: int = 12, alpha: float = 0.78) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", glass(radius, alpha))
	return p

static func eyebrow(text: String, col: Color = ACCENT) -> Label:
	## small tracked caps label above titles (label token)
	var l := Label.new()
	var spaced := ""
	for ch in text:
		spaced += ch + ("\u2009" if ch.unicode_at(0) < 128 else "")
	l.text = spaced
	l.add_theme_font_size_override("font_size", SZ_LABEL)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", font("bold"))
	return l

static func page_header(parent: Control, title: String, eyebrow_text: String = "", x: float = 48.0, y: float = 28.0) -> VBoxContainer:
	## clean editorial header: eyebrow + thin large title + hairline — replaces banner strips
	var v := VBoxContainer.new()
	v.position = Vector2(x, y)
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if eyebrow_text != "":
		v.add_child(eyebrow(eyebrow_text))
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", SZ_TITLE)
	t.add_theme_color_override("font_color", TEXT)
	v.add_child(t)
	parent.add_child(v)
	return v

static func parchment_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(PANEL, 0.82)
	s.border_color = STROKE
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	return s


static func stone_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL_LIT, 0.82)
	sb.set_corner_radius_all(8)
	sb.border_color = STROKE
	sb.set_border_width_all(1)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func make_themed_bg(parent: Control, theme: String = "castle") -> ColorRect:
	var bg = make_screen_bg(parent, false)
	var path = "res://assets/art/ui/%s_backdrop.png" % theme
	if not ResourceLoader.exists(path):
		path = "res://assets/art/ui/castle_backdrop.png"
	if ResourceLoader.exists(path):
		_add_backdrop(parent, load(path), 0.62)
	return bg

static func _add_backdrop(parent: Control, tex: Texture2D, veil_a: float = 0.62) -> void:
	## v8.6: painting sits deep behind an ink veil + vignette (luminous ink void, text always readable)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	var veil := ColorRect.new()
	veil.color = Color(BG, veil_a)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(veil)
	parent.add_child(_vignette())

static func _vignette() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(BG, 0.0))
	g.set_color(1, Color(BG, 0.78))
	g.set_offset(0, 0.35)
	g.set_offset(1, 1.0)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.42)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 144
	var v := TextureRect.new()
	v.texture = gt
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

static func make_screen_bg(parent: Control, illustrated: bool = false) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	if illustrated:
		var path = "res://assets/art/ui/castle_backdrop.png"
		if not ResourceLoader.exists(path):
			path = "res://assets/art/ui/hub_backdrop.png"
		if ResourceLoader.exists(path):
			_add_backdrop(parent, load(path), 0.58)
	return bg

static func trait_icon_rect(trait_id: String, size: float = 28.0) -> TextureRect:
	var tr := TextureRect.new()
	var path = "res://assets/art/ui/trait_%s.png" % trait_id
	if not ResourceLoader.exists(path):
		path = "res://assets/art/ui/trait_chip.png"
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.tooltip_text = trait_id
	return tr

static func resource_bar() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	return h

static func update_resources(bar: HBoxContainer) -> void:
	## label (faint, small) + value (mono numerals) chips — no plates
	for c in bar.get_children():
		c.queue_free()
	var items = [
		["银币", GameState.silver, ACCENT],
		["粮", GameState.food, TEXT],
		["铁", GameState.iron, TEXT],
		["药", GameState.herb, TEXT],
		["士气", GameState.morale, OK if GameState.morale >= 50 else DANGER],
	]
	for it in items:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var k := Label.new()
		k.text = str(it[0])
		k.add_theme_font_size_override("font_size", SZ_LABEL)
		k.add_theme_color_override("font_color", TEXT_FAINT)
		k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(k)
		var v := Label.new()
		v.text = str(it[1])
		v.add_theme_font_override("font", font("mono"))
		v.add_theme_font_size_override("font_size", 15)
		v.add_theme_color_override("font_color", it[2])
		hb.add_child(v)
		bar.add_child(hb)
	var cal := Label.new()
	cal.text = Calendar.label()
	cal.add_theme_font_size_override("font_size", 13)
	cal.add_theme_color_override("font_color", TEXT_DIM)
	bar.add_child(cal)

static func char_card_text(c: CKCharacter) -> String:
	var job = GameState.get_job(c.job_id)
	var lines = [
		"[b]%s[/b]　%s　%d岁　%s" % [c.name, job.get("name", ""), c.age, c.rank_name()],
		"六维 力%d 体%d 技%d 敏%d 感%d 意%d" % [c.stats["str"], c.stats["vit"], c.stats["skl"], c.stats["agi"], c.stats["per"], c.stats["wil"]],
		"血胤 %s" % c.bloodline_display(),
	]
	var tnames: Array = []
	for tid in c.traits:
		tnames.append(GameState.get_trait(tid).get("name", tid))
	lines.append("禀性 " + ("、".join(tnames) if tnames.size() else "无"))
	if c.injured:
		lines.append("[color=#c75a5a]【临时伤】[/color]")
	return "\n".join(lines)

static func make_portrait_rect(c: CKCharacter, size: int = 72) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = UnitArt.portrait(c, size)
	return tr

static func make_banner_rect(w: int = 72, h: int = 100) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(w, h)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = UnitArt.banner(w, h, true)
	return tr

static func make_hub_nav_button(text: String, subtitle: String, min_w: int = 210) -> Button:
	## v8.6: glass list item — title on line 1, muted subtitle line 2; frost focus ring
	var b := Button.new()
	b.text = text if subtitle == "" else "%s\n%s" % [text, subtitle]
	b.custom_minimum_size = Vector2(min_w, 58)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 14)
	b.focus_mode = Control.FOCUS_ALL
	var n := _btn_box(Color(1, 1, 1, 0.035), STROKE, 1, 10)
	n.content_margin_left = 16
	var h := _btn_box(Color(ACCENT, 0.09), Color(ACCENT, 0.55), 1, 10)
	h.content_margin_left = 16
	var pr := _btn_box(Color(0, 0, 0, 0.3), Color(ACCENT, 0.4), 1, 10)
	pr.content_margin_left = 16
	var d := _btn_box(DISABLED_BG, DISABLED_BORDER, 1, 10)
	d.content_margin_left = 16
	_apply_states(b, {"normal": n, "hover": h, "pressed": pr, "focus": _focus_ring(FOCUS_RING, 12), "disabled": d})
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	UIFX.wire_button(b)
	return b

# --- 轻量程序音效（AudioStreamGenerator 短脉冲，无外部授权问题）---
static var _sfx_player: AudioStreamPlayer
static var _sfx_ready: bool = false

static func _ensure_sfx() -> void:
	if _sfx_ready:
		return
	_sfx_ready = true
	# 延迟到有 SceneTree 时再挂；点击时若无树则静默


static func empty_state(text: String) -> Label:
	var l := make_dim_label(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

# --- v8.6 Stitch layout primitives ---------------------------------------------------------
static func side_veil(parent: Control, from_left: bool = true, reach: float = 0.62, a: float = 0.92) -> TextureRect:
	## horizontal ink gradient so an editorial column sits over full-bleed key art
	var g := Gradient.new()
	g.set_color(0, Color(BG, a))
	g.set_color(1, Color(BG, 0.0))
	g.set_offset(0, 0.0)
	g.set_offset(1, reach)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0 if from_left else 1.0, 0.5)
	gt.fill_to = Vector2(1.0 if from_left else 0.0, 0.5)
	gt.width = 256
	gt.height = 4
	var v := TextureRect.new()
	v.texture = gt
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	return v

static func glass_at(parent: Control, rect: Rect2, radius: int = 14, alpha: float = 0.72) -> Panel:
	## absolutely-placed frosted panel (1px highlight stroke, soft shadow)
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", glass(radius, alpha))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

static func index_button(idx: String, text: String, min_w: int = 320) -> Button:
	## editorial list item: mono index + label, left aligned, underline-on-hover glass states
	var b := Button.new()
	b.text = "%s    %s" % [idx, text]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(min_w, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_ALL
	var n := _btn_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10)
	n.content_margin_left = 18
	var h := _btn_box(Color(ACCENT, 0.10), Color(ACCENT, 0.45), 1, 10)
	h.content_margin_left = 18
	var pr := _btn_box(Color(ACCENT, 0.18), Color(ACCENT, 0.7), 1, 10)
	pr.content_margin_left = 18
	var d := _btn_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10)
	d.content_margin_left = 18
	_apply_states(b, {"normal": n, "hover": h, "pressed": pr, "focus": _focus_ring(FOCUS_RING, 12), "disabled": d})
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ACCENT_HOVER)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	UIFX.wire_button(b)
	return b

static func stat_chip(label: String, value: String, col: Color = TEXT) -> HBoxContainer:
	## label (faint, small) + mono value
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", SZ_LABEL)
	l.add_theme_color_override("font_color", TEXT_FAINT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_font_override("font", font("mono"))
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", col)
	h.add_child(v)
	return h

static func title_label(text: String, size: int = SZ_TITLE, col: Color = TEXT) -> Label:
	var t := Label.new()
	t.text = text
	t.add_theme_font_size_override("font_size", size)
	t.add_theme_color_override("font_color", col)
	return t

static func body_label(text: String, col: Color = TEXT_DIM, size: int = 13) -> Label:
	var t := Label.new()
	t.text = text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", size)
	t.add_theme_color_override("font_color", col)
	return t
