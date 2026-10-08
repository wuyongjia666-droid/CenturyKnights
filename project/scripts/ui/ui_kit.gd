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
	## v8.6 Stitch: ink void + 48px grid is the base for every screen; the themed painting survives only as a
	## faint atmospheric wash (no more painted plates competing with frosted panels).
	var bg = make_screen_bg(parent, false)
	void_bg(parent)
	var path = "res://assets/art/ui/%s_backdrop.png" % theme
	if not ResourceLoader.exists(path):
		path = "res://assets/art/ui/castle_backdrop.png"
	if ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.modulate = Color(0.55, 0.66, 0.85, 0.10)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(tr)
		parent.add_child(_vignette())
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

# --- v8.6 Stitch kit: shared scaffold matching docs/art/stitch_skeletons_v8/*.png --------------------
const MONO_TRACK := "\u2009"

static func mono(text: String, size: int = 11, col: Color = TEXT_FAINT, tracked: bool = true) -> Label:
	var l := Label.new()
	if tracked:
		var s := ""
		for ch in text:
			s += ch + (MONO_TRACK if ch.unicode_at(0) < 128 and ch != " " else "")
		l.text = s
	else:
		l.text = text
	l.add_theme_font_override("font", font("mono"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func void_bg(parent: Control) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://shaders/frost_void.gdshader"):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/frost_void.gdshader")
		r.material = m
	r.color = BG
	parent.add_child(r)
	return r

static func flat_box(bg: Color = Color(0.055, 0.067, 0.090, 0.88), border: Color = Color(1, 1, 1, 0.10), radius: int = 10, bw: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

static func panel_at(parent: Control, rect: Rect2, radius: int = 10, focus: bool = false) -> Panel:
	## Stitch panel: flat ink fill, 1px stroke; focus=true → frost border + soft outer glow
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var s := flat_box(Color(0.055, 0.067, 0.090, 0.90), Color(ACCENT, 0.85) if focus else Color(1, 1, 1, 0.10), radius, 2 if focus else 1)
	if focus:
		s.shadow_color = Color(ACCENT, 0.22)
		s.shadow_size = 14
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(p)
	return p

static func keycap(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font("mono"))
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", TEXT_DIM)
	var s := flat_box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.22), 4)
	s.content_margin_left = 5
	s.content_margin_right = 5
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", s)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func tag_chip(text: String, col: Color = ACCENT, filled: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font("bold"))
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", ON_ACCENT if filled else col)
	var s := flat_box(col if filled else Color(col, 0.10), Color(col, 0.55), 4)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", s)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

static func kv_row(k: String, v: String, col: Color = TEXT, w: float = 0.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	if w > 0:
		h.custom_minimum_size = Vector2(w, 0)
	var kl := Label.new()
	kl.text = k
	kl.add_theme_font_size_override("font_size", 12)
	kl.add_theme_color_override("font_color", TEXT_FAINT)
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(kl)
	var vl := Label.new()
	vl.text = v
	vl.add_theme_font_override("font", font("bold"))
	vl.add_theme_font_size_override("font_size", 12)
	vl.add_theme_color_override("font_color", col)
	h.add_child(vl)
	return h

static func stat_box(label: String, value: String, col: Color = TEXT, delta: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	var s := flat_box(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.09), 6)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 7
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)
	v.add_child(mono(label, 9, TEXT_FAINT))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	v.add_child(h)
	var vl := Label.new()
	vl.text = value
	vl.add_theme_font_override("font", font("mono"))
	vl.add_theme_font_size_override("font_size", 16)
	vl.add_theme_color_override("font_color", col)
	h.add_child(vl)
	if delta != "":
		var d := mono(delta, 11, OK, false)
		d.size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(d)
	return p

static func slim_bar(value: float, max_v: float, col: Color = ACCENT, w: float = 160.0, h: float = 4.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0
	b.max_value = max(1.0, max_v)
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.07)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

static func compact(b: Button, h: int) -> void:
	## shrink vertical content margins so a button can sit at h px (<40) without overflowing its row
	if h >= 40:
		return
	var m := maxi(1, int((h - 18) / 2.0))
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		if b.has_theme_stylebox_override(st) or b.has_theme_stylebox(st):
			var sb: StyleBox = b.get_theme_stylebox(st)
			if sb == null:
				continue
			var d: StyleBox = sb.duplicate()
			d.content_margin_top = m
			d.content_margin_bottom = m
			b.add_theme_stylebox_override(st, d)

static func cta_button(text: String, key: String = "A", w: int = 200, h: int = 44) -> Button:
	var b := make_accent_button("%s   [%s]" % [text, key] if key != "" else text, w)
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 15 if h >= 40 else 13)
	compact(b, h)
	return b

static func ghost_button(text: String, w: int = 120, h: int = 36) -> Button:
	var b := make_button(text, w)
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 13 if h >= 30 else 12)
	compact(b, h)
	return b

static func link_button(text: String, col: Color = ACCENT) -> Button:
	## text-only action link ("前往酒馆接洽 →") with hover underline-ish tint + focus ring
	var b := Button.new()
	b.text = text + "  →"
	b.flat = false
	b.add_theme_font_override("font", font("bold"))
	b.add_theme_font_size_override("font_size", 13)
	var e := _btn_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6)
	e.content_margin_left = 6
	e.content_margin_right = 6
	var h := _btn_box(Color(col, 0.10), Color(col, 0.35), 1, 6)
	h.content_margin_left = 6
	h.content_margin_right = 6
	_apply_states(b, {"normal": e, "hover": h, "pressed": h, "focus": _focus_ring(FOCUS_RING, 8), "disabled": e})
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", col)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	b.focus_mode = Control.FOCUS_ALL
	UIFX.wire_button(b)
	return b

static func res_chip(label: String, value: String, col: Color = TEXT) -> PanelContainer:
	var p := PanelContainer.new()
	var s := flat_box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.10), 6)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", s)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var k := Label.new()
	k.text = label
	k.add_theme_font_size_override("font_size", 11)
	k.add_theme_color_override("font_color", TEXT_FAINT)
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_override("font", font("mono"))
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", col)
	h.add_child(v)
	return p

static func std_resource_chips() -> Array:
	return [
		["银币", str(GameState.silver), ACCENT],
		["粮", str(GameState.food), TEXT],
		["铁", str(GameState.iron), TEXT],
		["士气", str(GameState.morale), OK if GameState.morale >= 50 else DANGER],
		["历", Calendar.label(), TEXT_DIM],
	]

static func top_bar(parent: Control, context: String, chips: Array = [], back_text: String = "返回城堡", back_cb: Callable = Callable()) -> Control:
	## 56px Stitch top bar: ● CENTURY KNIGHTS // context ……… [chips] [返回 ESC]
	var bar := Control.new()
	bar.name = "StitchTopBar"
	bar.position = Vector2.ZERO
	bar.size = Vector2(1280, 56)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	var bgc := ColorRect.new()
	bgc.color = Color(0.02, 0.024, 0.035, 0.72)
	bgc.size = Vector2(1280, 56)
	bgc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bgc)
	var hl := hairline(Color(1, 1, 1, 0.08))
	hl.position = Vector2(0, 55)
	hl.size = Vector2(1280, 1)
	bar.add_child(hl)
	var dot := Panel.new()
	var ds := StyleBoxFlat.new()
	ds.bg_color = ACCENT
	ds.set_corner_radius_all(4)
	ds.shadow_color = Color(ACCENT, 0.6)
	ds.shadow_size = 6
	dot.add_theme_stylebox_override("panel", ds)
	dot.position = Vector2(26, 24)
	dot.size = Vector2(8, 8)
	bar.add_child(dot)
	var brand := mono("CENTURY KNIGHTS", 11, TEXT_DIM)
	brand.position = Vector2(44, 19)
	bar.add_child(brand)
	var sep := mono("//", 11, TEXT_FAINT, false)
	sep.position = Vector2(44 + brand.get_minimum_size().x + 10, 19)
	bar.add_child(sep)
	var ctx := Label.new()
	ctx.text = context
	ctx.add_theme_font_size_override("font_size", 15)
	ctx.add_theme_color_override("font_color", TEXT)
	ctx.position = Vector2(sep.position.x + 26, 15)
	bar.add_child(ctx)
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.position = Vector2(400, 11)
	right.size = Vector2(856, 34)
	bar.add_child(right)
	for c in chips:
		right.add_child(res_chip(str(c[0]), str(c[1]), c[2] if c.size() > 2 else TEXT))
	if back_cb.is_valid():
		var back_w := 112
		var back_h := 32
		if DeviceProfile.is_mobile():
			back_h = int(clampf(DeviceProfile.hit_px(), 44.0, 48.0))
			back_w = 120
		var b := ghost_button("%s  ESC" % back_text, back_w, back_h)
		b.name = "BackButton"
		b.pressed.connect(back_cb)
		right.add_child(b)
	return bar

static func page_head(parent: Control, x: float, y: float, eyebrow_en: String, title: String, en_title: String = "", desc: String = "", tag: String = "", title_px: int = 30) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.position = Vector2(x, y)
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	var eh := HBoxContainer.new()
	eh.add_theme_constant_override("separation", 10)
	v.add_child(eh)
	eh.add_child(mono("— " + eyebrow_en, 10, ACCENT))
	if tag != "":
		eh.add_child(tag_chip(tag, ACCENT))
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	v.add_child(th)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", title_px)
	t.add_theme_color_override("font_color", TEXT)
	th.add_child(t)
	if en_title != "":
		var e := mono(en_title, 11, TEXT_FAINT)
		e.size_flags_vertical = Control.SIZE_SHRINK_END
		e.custom_minimum_size = Vector2(0, 30)
		th.add_child(e)
	if desc != "":
		var d := Label.new()
		d.text = desc
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", TEXT_DIM)
		v.add_child(d)
	return v

static func footer_bar(parent: Control, hints: Array, meta: String = "FROST_TACTICAL v8.6") -> Control:
	var bar := Control.new()
	bar.name = "StitchFooter"
	bar.position = Vector2(0, 692)
	bar.size = Vector2(1280, 28)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	var hl := hairline(Color(1, 1, 1, 0.07))
	hl.size = Vector2(1280, 1)
	bar.add_child(hl)
	var h := HBoxContainer.new()
	h.position = Vector2(26, 5)
	h.add_theme_constant_override("separation", 6)
	bar.add_child(h)
	for it in hints:
		h.add_child(keycap(str(it[0])))
		var l := Label.new()
		l.text = str(it[1])
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", TEXT_DIM)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(12, 0)
		h.add_child(gap)
	var m := mono(meta, 9, TEXT_FAINT)
	m.position = Vector2(1254 - m.get_minimum_size().x, 8)
	bar.add_child(m)
	return bar

static func section_head(parent: Control, pos: Vector2, title_zh: String, en: String, w: float, right_text: String = "") -> void:
	var t := Label.new()
	t.text = title_zh
	t.position = pos
	t.add_theme_font_override("font", font("bold"))
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", ACCENT)
	parent.add_child(t)
	var e := mono("// " + en, 9, TEXT_FAINT)
	e.position = pos + Vector2(t.get_minimum_size().x + 8, 3)
	parent.add_child(e)
	if right_text != "":
		var r := Label.new()
		r.text = right_text
		r.add_theme_font_size_override("font_size", 11)
		r.add_theme_color_override("font_color", TEXT_FAINT)
		r.position = pos + Vector2(w - r.get_minimum_size().x, 1)
		parent.add_child(r)

static func portrait_plate(parent: Control, rect: Rect2, c, caption: String = "", focus: bool = false) -> Panel:
	## blueprint plate: thin frame + corner ticks + clipped portrait + mono caption
	var p := panel_at(parent, rect, 8, focus)
	var inner := Control.new()
	inner.position = Vector2(1, 1)
	inner.size = rect.size - Vector2(2, 2)
	inner.clip_contents = true
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inner)
	if c != null:
		var tex: Texture2D = null
		var pr: TextureRect = make_portrait_rect(c, int(rect.size.y))
		tex = pr.texture
		pr.queue_free()
		if tex:
			var t := TextureRect.new()
			t.texture = tex
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			t.size = inner.size
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(t)
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(BG, 0.85))
	g.set_offset(0, 0.55)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	gt.width = 4
	gt.height = 64
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = inner.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(shade)
	for corner in [Vector2(6, 6), Vector2(rect.size.x - 16, 6), Vector2(6, rect.size.y - 16), Vector2(rect.size.x - 16, rect.size.y - 16)]:
		var tick := Control.new()
		tick.position = corner
		tick.size = Vector2(10, 10)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var a := ColorRect.new()
		a.color = Color(ACCENT, 0.55)
		var b := ColorRect.new()
		b.color = Color(ACCENT, 0.55)
		var left: bool = corner.x < 10
		var top: bool = corner.y < 10
		a.size = Vector2(10, 1)
		a.position = Vector2(0, 0 if top else 9)
		b.size = Vector2(1, 10)
		b.position = Vector2(0 if left else 9, 0)
		tick.add_child(a)
		tick.add_child(b)
		p.add_child(tick)
	if caption != "":
		var cap := mono(caption, 9, ACCENT)
		cap.position = Vector2(12, rect.size.y - 22)
		p.add_child(cap)
	return p

static func stitch_dialogue(scene: Control) -> void:
	## v8.6 — Stitch 21_dialogue skin for every story chapter (scripts share _banner/_title/_portrait/_speaker/
	## _body/_actions). Re-lays the built nodes: ink void + grid, brand line, large speaker plate left,
	## bottom transcript box, choice branch cards right-aligned above the box, footer keycaps. Logic untouched.
	var portrait = scene.get("_portrait")
	var speaker = scene.get("_speaker")
	var body = scene.get("_body")
	var actions = scene.get("_actions")
	var title = scene.get("_title")
	var banner = scene.get("_banner")
	if not (portrait is TextureRect and speaker is Label and body is RichTextLabel and actions is Control):
		return
	var vg := void_bg(scene)
	scene.move_child(vg, 1 if scene.get_child_count() > 1 else 0)
	if banner is CanvasItem:
		(banner as CanvasItem).visible = false
	# brand line + chapter title
	var brand := mono("CENTURY KNIGHTS //", 10, TEXT_DIM)
	brand.position = Vector2(42, 22)
	scene.add_child(brand)
	if title is Label:
		var t := title as Label
		t.position = Vector2(48 + brand.get_minimum_size().x, 16)
		t.add_theme_font_size_override("font_size", 16)
		t.add_theme_color_override("font_color", TEXT)
	var hl := hairline(Color(1, 1, 1, 0.08))
	hl.position = Vector2(0, 52)
	hl.size = Vector2(1280, 1)
	scene.add_child(hl)
	var eb := mono("● SPEAKER ACTIVE // 01", 9, ACCENT, false)
	eb.position = Vector2(56, 74)
	scene.add_child(eb)
	# speaker plate (left)
	var plate := Panel.new()
	plate.name = "SpeakerPlate"
	plate.position = Vector2(56, 96)
	plate.size = Vector2(300, 420)
	plate.clip_contents = true
	var ps := flat_box(Color(0.04, 0.05, 0.07, 0.9), Color(ACCENT, 0.45), 6)
	ps.shadow_color = Color(ACCENT, 0.14)
	ps.shadow_size = 18
	plate.add_theme_stylebox_override("panel", ps)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(plate)
	var panel: Control = null
	var hb = (portrait as Control).get_parent()
	if hb is Control and (hb as Control).get_parent() is Control:
		panel = (hb as Control).get_parent()
	if panel and panel.get_parent() == scene:
		scene.move_child(plate, panel.get_index())
	(portrait as Control).reparent(plate, false)
	var pr := portrait as TextureRect
	pr.position = Vector2(1, 1)
	pr.custom_minimum_size = Vector2(298, 418)
	pr.size = Vector2(298, 418)
	pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var shade := ColorRect.new()
	shade.color = Color(BG, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(BG, 0.0))
	g.set_color(1, Color(BG, 0.9))
	g.set_offset(0, 0.62)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var sh := TextureRect.new()
	sh.texture = gt
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.size = Vector2(300, 420)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(sh)
	var cap := mono("", 9, TEXT_DIM, false)
	cap.position = Vector2(14, 392)
	plate.add_child(cap)
	# transcript box (bottom)
	if panel:
		panel.position = Vector2(180, 486)
		panel.custom_minimum_size = Vector2(920, 176)
		panel.size = Vector2(920, 176)
		panel.set_deferred("size", Vector2(920, 176))
		var bs := flat_box(Color(0.035, 0.045, 0.065, 0.94), Color(ACCENT, 0.30), 8)
		bs.content_margin_left = 26
		bs.content_margin_right = 26
		bs.content_margin_top = 16
		bs.content_margin_bottom = 14
		panel.add_theme_stylebox_override("panel", bs)
		var tr := mono("TRANSCRIPT // LOG", 8, TEXT_FAINT, false)
		tr.position = Vector2(1090 - 110, 472)
		scene.add_child(tr)
	var sp := speaker as Label
	var chip := flat_box(Color(ACCENT, 0.10), Color(ACCENT, 0.55), 4)
	chip.content_margin_left = 10
	chip.content_margin_right = 10
	chip.content_margin_top = 2
	chip.content_margin_bottom = 2
	sp.add_theme_stylebox_override("normal", chip)
	sp.add_theme_font_size_override("font_size", 15)
	sp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var bd := body as RichTextLabel
	bd.custom_minimum_size = Vector2(860, 96)
	bd.add_theme_font_size_override("normal_font_size", 17)
	bd.add_theme_constant_override("line_separation", 6)
	# choice branch cards: right-aligned, bottom pinned above the transcript box
	var act := actions as Control
	var relayout := func():
		if not is_instance_valid(act):
			return
		var sz := act.get_combined_minimum_size()
		act.position = Vector2(1100 - maxf(sz.x, 240.0), 462 - sz.y)
	if act is BoxContainer:
		(act as BoxContainer).alignment = BoxContainer.ALIGNMENT_END
		act.sort_children.connect(relayout)
	relayout.call()
	# narrator / crest banner → hide plate; keep caption in sync with speaker
	var tm := Timer.new()
	tm.wait_time = 0.1
	tm.autostart = true
	scene.add_child(tm)
	var sync := func():
		if not is_instance_valid(pr):
			return
		var tex: Texture2D = pr.texture
		var is_banner := tex == null or (tex.resource_path.find("/banners/") >= 0) or (tex.get_width() < 200 and tex.get_height() > tex.get_width() * 1.2)
		plate.visible = not is_banner
		eb.visible = plate.visible
		cap.text = ("SPEAKER // " + sp.text) if sp.text != "" else ""
	tm.timeout.connect(sync)
	sync.call()
	# chapter-level buttons (存档 / 返回灰旗堡) sit in the brand bar, right-aligned
	for ch in scene.get_children():
		if ch is Button and (ch as Button).position.y < 90:
			var cb := ch as Button
			cb.custom_minimum_size = Vector2(maxf(cb.custom_minimum_size.x, 112), 32)
			compact(cb, 32)
			cb.position = Vector2(1238 - maxf(cb.size.x, cb.custom_minimum_size.x), 10)
	footer_bar(scene, [["A", "继续 / 选择"]], "STORY // TRANSCRIPT v8.6")
