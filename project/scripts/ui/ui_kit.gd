class_name UIKit
extends RefCounted

## v8.0.0-art locked vibe: Contemporary Fantasy SRPG — luminous ink, crystal-ember, matte dark UI
## NO medieval cliché (no parchment scrolls, gothic stone, war-banner gold kitsch)
const BG := Color(0.07, 0.08, 0.12)           # ink void
const BG_DEEP := Color(0.04, 0.05, 0.08)
const PANEL := Color(0.12, 0.14, 0.20)         # matte slate glass
const PANEL_LIT := Color(0.18, 0.22, 0.30)
const ACCENT := Color(0.55, 0.78, 0.92)        # crystal frost
const ACCENT_DIM := Color(0.32, 0.48, 0.62)
const TEXT := Color(0.92, 0.94, 0.97)          # cool ivory
const TEXT_DIM := Color(0.55, 0.60, 0.68)
const DANGER := Color(0.92, 0.38, 0.48)        # soft coral alert
const OK := Color(0.42, 0.82, 0.68)            # mint signal
const PARCHMENT := Color(0.78, 0.86, 0.94)     # cool wash (kept name for API compat)
const STONE := Color(0.22, 0.26, 0.34)
const FOCUS_RING := Color(0.72, 0.92, 1.0)
const DISABLED_BG := Color(0.10, 0.11, 0.14, 0.55)
const DISABLED_BORDER := Color(0.28, 0.32, 0.40, 0.45)
const DISABLED_TEXT := Color(0.40, 0.44, 0.50)
const EMBER := Color(0.98, 0.62, 0.38)         # secondary warm accent (sparks only)

static func make_button(text: String, min_w: int = 160) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 42)
	_style_button(b)
	b.pressed.connect(func(): Sfx.click())
	UIFX.wire_button(b)
	return b

static func make_accent_button(text: String, min_w: int = 160) -> Button:
	var b := make_button(text, min_w)
	b.pressed.connect(func(): Sfx.confirm())
	var n = _tex_style("res://assets/art/ui/btn_accent_chrome.png", _flat(ACCENT.darkened(0.25), ACCENT, 8), Vector2i(14, 8))
	var h = _tex_style("res://assets/art/ui/btn_accent_chrome.png", _flat(ACCENT.darkened(0.10), ACCENT.lightened(0.15), 8), Vector2i(14, 8))
	var p = _tex_style("res://assets/art/ui/btn_accent_chrome.png", _flat(ACCENT.darkened(0.35), ACCENT_DIM, 8), Vector2i(14, 8))
	var f = _tex_style("res://assets/art/ui/btn_accent_chrome.png", _flat(ACCENT.darkened(0.15), FOCUS_RING, 8), Vector2i(14, 8))
	var d = _flat(DISABLED_BG, DISABLED_BORDER, 8)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", f)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_color_override("font_color", Color(0.12, 0.10, 0.06))
	b.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.02))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.04, 0.02))
	b.add_theme_color_override("font_focus_color", Color(0.10, 0.08, 0.04))
	b.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	b.focus_mode = Control.FOCUS_ALL
	return b

static func _style_button(b: Button) -> void:
	## 全态：normal / hover / pressed / focus / disabled（厚涂战旗）
	var flat_n := StyleBoxFlat.new()
	flat_n.bg_color = Color(0.14, 0.16, 0.22, 0.92)
	flat_n.border_color = Color(0.45, 0.65, 0.82, 0.75)
	flat_n.set_border_width_all(2)
	flat_n.set_corner_radius_all(6)
	flat_n.content_margin_left = 12
	flat_n.content_margin_right = 12
	flat_n.content_margin_top = 8
	flat_n.content_margin_bottom = 8
	var flat_h := flat_n.duplicate()
	flat_h.bg_color = Color(0.20, 0.26, 0.36, 0.96)
	flat_h.border_color = Color(0.70, 0.90, 1.0, 0.95)
	var flat_p := flat_n.duplicate()
	flat_p.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	flat_p.border_color = Color(0.40, 0.58, 0.75, 0.9)
	var flat_f := flat_n.duplicate()
	flat_f.bg_color = Color(0.16, 0.20, 0.28, 0.98)
	flat_f.border_color = FOCUS_RING
	flat_f.set_border_width_all(3)
	var flat_d := flat_n.duplicate()
	flat_d.bg_color = DISABLED_BG
	flat_d.border_color = DISABLED_BORDER
	var n = _tex_style("res://assets/art/ui/btn_chrome.png", flat_n, Vector2i(12, 8))
	var hov = _tex_style("res://assets/art/ui/btn_chrome.png", flat_h, Vector2i(12, 8))
	var pr = _tex_style("res://assets/art/ui/btn_chrome.png", flat_p, Vector2i(12, 8))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("focus", flat_f)
	b.add_theme_stylebox_override("disabled", flat_d)
	b.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
	b.add_theme_color_override("font_hover_color", Color(0.85, 0.95, 1.0))
	b.add_theme_color_override("font_pressed_color", Color(0.70, 0.85, 0.95))
	b.add_theme_color_override("font_focus_color", Color(0.88, 0.96, 1.0))
	b.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	b.focus_mode = Control.FOCUS_ALL




static func _tex_style(tex_path: String, fallback: StyleBoxFlat, margins: Vector2i = Vector2i(12, 10)) -> StyleBox:
	if ResourceLoader.exists(tex_path):
		var sb := StyleBoxTexture.new()
		sb.texture = load(tex_path)
		sb.texture_margin_left = 12
		sb.texture_margin_right = 12
		sb.texture_margin_top = 12
		sb.texture_margin_bottom = 12
		sb.content_margin_left = margins.x
		sb.content_margin_right = margins.x
		sb.content_margin_top = margins.y
		sb.content_margin_bottom = margins.y
		return sb
	return fallback

static func _flat(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(1, 2)
	return sb

static func make_label(text: String, large: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", TEXT)
	if large:
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", PARCHMENT)
	else:
		l.add_theme_font_size_override("font_size", 15)
	return l

static func make_dim_label(text: String) -> Label:
	var l := make_label(text)
	l.add_theme_color_override("font_color", TEXT_DIM)
	l.add_theme_font_size_override("font_size", 13)
	return l

static func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var flat = parchment_style()
	p.add_theme_stylebox_override("panel", _tex_style("res://assets/art/ui/panel_chrome.png", flat))
	return p

static func parchment_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.14, 0.13, 0.11, 0.94)
	s.border_color = Color(0.72, 0.58, 0.32, 0.85)
	s.set_border_width_all(2)
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
	sb.bg_color = Color(0.14, 0.15, 0.20, 0.95)
	sb.set_corner_radius_all(6)
	sb.border_color = STONE
	sb.set_border_width_all(2)
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
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate = Color(1, 1, 1, 0.95)
		parent.add_child(tr)
		# move just above solid bg: re-add veil
		var veil := ColorRect.new()
		veil.color = Color(0.05, 0.06, 0.09, 0.38)
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(veil)
	return bg

static func make_screen_bg(parent: Control, illustrated: bool = false) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	# 插画城堡底图（城堡枢纽等）
	if illustrated:
		var path = "res://assets/art/ui/castle_backdrop.png"
		if not ResourceLoader.exists(path):
			path = "res://assets/art/ui/hub_backdrop.png"
		if ResourceLoader.exists(path):
			var tr := TextureRect.new()
			tr.texture = load(path)
			tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.modulate = Color(1, 1, 1, 0.92)
			parent.add_child(tr)
			# 半透明遮罩保证文字可读
			var veil := ColorRect.new()
			veil.color = Color(0.06, 0.07, 0.1, 0.42)
			veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(veil)
	# 顶部纹章色细线
	var top := ColorRect.new()
	top.color = Color(str(GameState.crest_color)) if GameState.started else ACCENT
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, 4)
	top.offset_bottom = 4
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top)
	# 底部暗角
	var bottom := ColorRect.new()
	bottom.color = BG_DEEP
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -48
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bottom)
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
	h.add_theme_constant_override("separation", 18)
	return h

static func update_resources(bar: HBoxContainer) -> void:
	for c in bar.get_children():
		c.queue_free()
	var items = [
		["银币", GameState.silver, ACCENT],
		["粮", GameState.food, TEXT],
		["铁", GameState.iron, TEXT],
		["药", GameState.herb, TEXT],
		["士气", GameState.morale, OK if GameState.morale >= 50 else DANGER],
		[Calendar.label(), "", TEXT_DIM],
	]
	for it in items:
		var l := Label.new()
		if str(it[1]) == "":
			l.text = str(it[0])
		else:
			l.text = "%s %s" % [it[0], str(it[1])]
		l.add_theme_color_override("font_color", it[2])
		l.add_theme_font_size_override("font_size", 14)
		bar.add_child(l)

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
	var b := Button.new()
	b.text = text if subtitle == "" else "%s\n%s" % [text, subtitle]
	b.custom_minimum_size = Vector2(min_w, 64)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 14)
	b.focus_mode = Control.FOCUS_ALL
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.12, 0.14, 0.20, 0.94)
	flat.border_color = Color(0.45, 0.65, 0.82, 0.75)
	flat.border_width_left = 4
	flat.border_width_top = 1
	flat.border_width_right = 1
	flat.border_width_bottom = 1
	flat.set_corner_radius_all(10)
	flat.content_margin_left = 14
	flat.content_margin_right = 10
	flat.content_margin_top = 8
	flat.content_margin_bottom = 8
	var flat_h := flat.duplicate()
	flat_h.bg_color = Color(0.18, 0.24, 0.34, 0.98)
	flat_h.border_color = FOCUS_RING
	var flat_p := flat.duplicate()
	flat_p.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	var flat_f := flat.duplicate()
	flat_f.border_color = FOCUS_RING
	flat_f.border_width_left = 5
	var flat_d := flat.duplicate()
	flat_d.bg_color = DISABLED_BG
	flat_d.border_color = DISABLED_BORDER
	var n = _tex_style("res://assets/art/ui/hub_nav_chrome.png", flat, Vector2i(14, 8))
	var hov = _tex_style("res://assets/art/ui/hub_nav_chrome.png", flat_h, Vector2i(14, 8))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", flat_p)
	b.add_theme_stylebox_override("focus", flat_f)
	b.add_theme_stylebox_override("disabled", flat_d)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(0.88, 0.96, 1.0))
	b.add_theme_color_override("font_pressed_color", Color(0.70, 0.85, 0.95))
	b.add_theme_color_override("font_focus_color", Color(0.90, 0.97, 1.0))
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
