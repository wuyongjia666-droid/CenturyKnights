class_name UIKit
extends RefCounted

const BG := Color(0.10, 0.12, 0.16)
const BG_DEEP := Color(0.07, 0.08, 0.11)
const PANEL := Color(0.16, 0.19, 0.26)
const PANEL_LIT := Color(0.20, 0.24, 0.32)
const ACCENT := Color(0.79, 0.64, 0.15)
const ACCENT_DIM := Color(0.55, 0.44, 0.12)
const TEXT := Color(0.93, 0.91, 0.86)
const TEXT_DIM := Color(0.62, 0.60, 0.55)
const DANGER := Color(0.78, 0.30, 0.28)
const OK := Color(0.38, 0.68, 0.48)
const PARCHMENT := Color(0.90, 0.84, 0.70)
const STONE := Color(0.28, 0.30, 0.36)

static func make_button(text: String, min_w: int = 160) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 42)
	_style_button(b)
	b.pressed.connect(func(): Sfx.click())
	return b

static func make_accent_button(text: String, min_w: int = 160) -> Button:
	var b := make_button(text, min_w)
	b.pressed.connect(func(): Sfx.confirm())
	var n = _flat(ACCENT.darkened(0.25), ACCENT, 8)
	var h = _flat(ACCENT.darkened(0.10), ACCENT.lightened(0.15), 8)
	var p = _flat(ACCENT.darkened(0.35), ACCENT_DIM, 8)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_color_override("font_color", Color(0.12, 0.10, 0.06))
	b.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.02))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.04, 0.02))
	return b

static func _style_button(b: Button) -> void:
	var n = _flat(PANEL, ACCENT_DIM, 8)
	var h = _flat(PANEL_LIT, ACCENT, 8)
	var p = _flat(PANEL.darkened(0.15), ACCENT.darkened(0.2), 8)
	var d = _flat(PANEL.darkened(0.25), STONE, 8)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", PARCHMENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM)
	b.add_theme_font_size_override("font_size", 15)

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
	p.add_theme_stylebox_override("panel", parchment_style())
	return p

static func parchment_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.19, 0.26, 0.96)
	sb.set_corner_radius_all(10)
	sb.border_color = ACCENT_DIM
	sb.set_border_width_all(2)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(2, 3)
	return sb

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
	var b := make_button(text + "\n" + subtitle, min_w)
	b.custom_minimum_size = Vector2(min_w, 64)
	b.add_theme_font_size_override("font_size", 14)
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
