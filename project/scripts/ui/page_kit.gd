class_name CKPageKit
extends RefCounted
## Line B page kit: Frost shell, cards, empty/failure states and touch-safe lists for the
## older hub pages. 1280x720 design space; CKMobileChrome scales it onto the phone.
## No key hints on touch; every button is at least HIT tall; lists scroll by finger drag.

const HIT := 48.0
const TOP := 128.0      ## first content row under top bar + page head
const BOTTOM := 676.0   ## last content pixel above the footer / feedback line
const PAD := 42.0

## Top bar, page head, optional desktop footer. Back goes through CKNav (one back action).
## HEAD_Y sits below the 56px StitchTopBar so Chinese titles never stack onto CENTURY KNIGHTS.
const HEAD_Y := 64.0

static func shell(page: Control, context: String, eyebrow: String, title: String, desc: String = "", theme: String = "") -> void:
	## theme "none": the page already painted its own backdrop (UIKit.make_themed_bg(self, ...)).
	page.set_meta("ck_page_kit", true)  # MobileLayout.center_kit_page centres the 1280 grid on wide phones
	if theme == "":
		UIKit.void_bg(page)
	elif theme != "none":
		UIKit.make_themed_bg(page, theme)
	UIKit.top_bar(page, context, [[Locale.t("lb_chip_date"), Calendar.label(), UIKit.TEXT_DIM]], Locale.t("btn_back"), func(): back(page))
	var head := UIKit.page_head(page, PAD, HEAD_Y, eyebrow, title, "", "", "", 22)
	head.name = "PageHead"
	head.set_meta("font_floor_exempt", true)  # keep designed sizes; floor was stacking onto the top bar
	if desc != "":
		# Park beside the title inside PageHead so layout/narrow audits treat them as one header.
		var th := head.get_child(1) as HBoxContainer
		var d := UIKit.body_label(desc, UIKit.TEXT_DIM, 12)
		d.name = "PageDesc"
		d.autowrap_mode = TextServer.AUTOWRAP_OFF
		d.clip_text = true
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		d.tooltip_text = desc
		d.mouse_filter = Control.MOUSE_FILTER_PASS
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.custom_minimum_size = Vector2(minf(520.0, 1280.0 - PAD * 2.0 - 220.0), 18)
		if th != null:
			th.add_child(d)
		else:
			d.position = Vector2(PAD + 200.0, HEAD_Y + 40.0)
			d.size = Vector2(800, 18)
			page.add_child(d)
	if touch():
		var bb := page.find_child("BackButton", true, false) as Button
		if bb != null:
			bb.text = Locale.t("btn_back")

static func footer(page: Control, hints: Array, meta: String) -> void:
	if touch():
		return
	UIKit.footer_bar(page, hints, meta)

static func touch() -> bool:
	return DeviceProfile.is_mobile() or DisplayServer.is_touchscreen_available()

static func back(_page: Control) -> void:
	Sfx.click()
	CKNav.back()

## Rounded Frost panel at a fixed rect; children go into the returned panel.
static func card(parent: Control, rect: Rect2, name: String = "", focus: bool = false) -> Panel:
	var p := UIKit.panel_at(parent, rect, 12, focus)
	if name != "":
		p.name = name
	return p

## Card header: zh title + small tracked caption.
static func card_head(card: Control, title: String, caption: String = "", y: float = 14.0) -> void:
	var t := UIKit.title_label(title, 17)
	t.position = Vector2(18, y)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(t)
	if caption != "":
		var c := UIKit.mono(caption, 9, UIKit.TEXT_FAINT)
		c.position = Vector2(18, y + 26)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(c)

## Vertical, finger-draggable list inside `host` at rect. Returns the VBox to fill.
static func list(host: Control, rect: Rect2, name: String = "List") -> VBoxContainer:
	var s := ScrollContainer.new()
	s.name = name + "Scroll"
	s.position = rect.position
	s.size = rect.size
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.scroll_deadzone = 10
	s.clip_contents = true
	host.add_child(s)
	var v := VBoxContainer.new()
	v.name = name
	v.custom_minimum_size = Vector2(rect.size.x - 14.0, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	s.add_child(v)
	return v

## After filling a list: let drags that start on a row or button scroll the list.
static func drag_through(v: Node) -> void:
	for ch in v.get_children():
		if ch is Control and not (ch is ScrollContainer):
			var c := ch as Control
			if c.mouse_filter == Control.MOUSE_FILTER_STOP:
				c.mouse_filter = Control.MOUSE_FILTER_PASS
		drag_through(ch)

static func clear(n: Node) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()

## Wrapped body text for list rows and cards.
static func text(s: String, col: Color = UIKit.TEXT_DIM, size: int = 14, w: float = 0.0) -> Label:
	var l := UIKit.body_label(s, col, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if w > 0.0:
		l.custom_minimum_size = Vector2(w, 0)
	return l

## A row card for lists: tinted panel with a VBox body.
static func row(col: Color = UIKit.ACCENT, min_h: float = 56.0) -> Array:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, min_h)
	var sb := UIKit.flat_box(Color(col, 0.06), Color(col, 0.30), 10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	return [p, v]

## Empty state: what this page is for, why it is empty and how to fill it.
static func empty(title: String, why: String, how: String = "", w: float = 520.0) -> PanelContainer:
	var r := row(UIKit.TEXT_FAINT, 120)
	var p: PanelContainer = r[0]
	p.name = "EmptyState"
	var v: VBoxContainer = r[1]
	v.add_theme_constant_override("separation", 8)
	var t := UIKit.title_label(title, 17, UIKit.TEXT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	v.add_child(text(why, UIKit.TEXT_DIM, 14, w))
	if how != "":
		v.add_child(text(how, UIKit.ACCENT, 13, w))
	return p

## Button with no key hint, at least HIT tall. primary = frost fill.
static func button(label: String, primary: bool = false, w: float = 160.0, h: float = HIT) -> Button:
	var tall := maxf(h, HIT)
	if DeviceProfile.is_mobile():
		tall = maxf(tall, MobileLayout.HIT_FLOOR)
	var b: Button = UIKit.make_accent_button(label, int(w)) if primary else UIKit.make_button(label, int(w))
	b.custom_minimum_size = Vector2(w, tall)
	b.add_theme_font_size_override("font_size", 22 if DeviceProfile.is_mobile() else 15)
	return b

## Disable with a reason the player sees when they tap it anyway (UIFX.deny).
## Pass show_under=true for a persistent red line under the button (请爵 P2).
static func lock(b: BaseButton, reason: String, show_under: bool = false) -> void:
	b.disabled = reason != ""
	b.set_meta("deny_reason", reason)
	b.tooltip_text = reason
	var old_hint := b.get_node_or_null("LockHint")
	if old_hint != null:
		old_hint.queue_free()
	if reason == "" or not show_under:
		return
	var lab := Label.new()
	lab.name = "LockHint"
	lab.text = reason
	var fs := 22 if DeviceProfile.is_mobile() else 13
	lab.add_theme_font_size_override("font_size", fs)
	lab.add_theme_color_override("font_color", UIKit.DANGER)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bw := maxf(b.custom_minimum_size.x, maxf(b.size.x, 200.0))
	var bh := maxf(b.custom_minimum_size.y, maxf(b.size.y, HIT))
	lab.position = Vector2(0, bh + 4.0)
	lab.size = Vector2(bw, float(fs * 2 + 8))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	b.resized.connect(func():
		if is_instance_valid(lab):
			lab.position.y = b.size.y + 4.0
			lab.size.x = maxf(b.size.x, 200.0))

## One-line feedback strip above the bottom edge. ok=false paints it as a failure.
static func feedback(page: Control) -> Label:
	var l := UIKit.body_label("", UIKit.OK, 14)
	l.name = "Feedback"
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.position = Vector2(PAD, BOTTOM - 22.0)
	l.size = Vector2(1280.0 - PAD * 2.0, 22)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(l)
	return l

static func say(l: Label, msg: String, ok: bool = true) -> void:
	if l == null:
		return
	l.text = msg
	l.add_theme_color_override("font_color", UIKit.OK if ok else UIKit.DANGER)
	UIFX.flash_modulate(l, Color(1.2, 1.2, 1.2), 0.2)
	if ok:
		Sfx.confirm()
	else:
		UIFX.haptic(8)

## Small "label: value" stat line for cards.
static func stat(parent: Control, pos: Vector2, label: String, value: String, col: Color = UIKit.TEXT) -> void:
	var a := UIKit.mono(label, 10, UIKit.TEXT_FAINT, false)
	a.position = pos
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(a)
	var b := UIKit.title_label(value, 20, col)
	b.position = pos + Vector2(0, 14)
	if DeviceProfile.is_mobile():
		# Phone type floor (22px) would stack the caption onto the value: put them on one line.
		var fa := MobileLayout.FONT_FLOOR
		a.add_theme_font_size_override("font_size", fa)
		b.add_theme_font_size_override("font_size", maxi(fa, 24))
		a.position = pos + Vector2(0, 6)
		b.position = pos + Vector2(a.get_minimum_size().x + 8.0, 2)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)

## Phone: stretch kit cards across the full root width and raise empty-state type.
## Call from apply_mobile_layout; sets m_center_ok so MobileLayout.center_kit_page leaves us alone.
static func phone_fill(page: Control) -> void:
	if page == null or not MobilePage.active(page):
		return
	page.set_meta("m_center_ok", true)
	var w := MobilePage.width(page)
	var bar := page.find_child("StitchTopBar", true, false) as Control
	if bar != null and bar.size.x < w - 8.0:
		MobileLayout.stretch_top_bar(bar, w - bar.size.x)
	var desc := page.find_child("PageDesc", true, false) as Label
	if desc != null:
		desc.size.x = maxf(200.0, w - desc.position.x - PAD)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.max_lines_visible = 2
	var fb := page.find_child("Feedback", true, false) as Control
	if fb != null:
		fb.position.x = PAD
		fb.size.x = w - PAD * 2.0
	var cards: Array[Control] = []
	for c in page.get_children():
		if not (c is Panel or c is PanelContainer):
			continue
		var cc := c as Control
		if cc.position.y < TOP - 8.0 or cc.size.x < 180.0:
			continue
		cards.append(cc)
	# Filter bar (court news) stretches full width above the list card.
	var filters := page.find_child("FilterBar", true, false) as HBoxContainer
	if filters != null:
		filters.position = Vector2(PAD, TOP + 6.0)
		filters.size = Vector2(w - PAD * 2.0, MobilePage.HIT)
		for b in filters.get_children():
			if b is BaseButton:
				(b as BaseButton).custom_minimum_size = Vector2(0, MobilePage.HIT)
				(b as BaseButton).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				(b as BaseButton).add_theme_font_size_override("font_size", MobilePage.FONT)
	if cards.is_empty():
		MobilePage.upsize(page)
		_boost_empty(page, w - PAD * 2.0)
		return
	cards.sort_custom(func(a, b): return a.position.x < b.position.x)
	var gap := 12.0
	var n := cards.size()
	var top_y := TOP + (66.0 if filters != null else 8.0)
	var bottom := BOTTOM - 8.0
	var cw := (w - PAD * 2.0 - gap * float(maxi(0, n - 1))) / float(n)
	var x := PAD
	for card in cards:
		var old := Rect2(card.position, card.size)
		card.position = Vector2(x, top_y)
		card.size = Vector2(cw, bottom - top_y)
		_resize_card_inners(card, old, card.size)
		x += cw + gap
	MobilePage.upsize(page)
	_boost_empty(page, cw - 28.0 if n > 1 else w - PAD * 2.0 - 40.0)


static func _resize_card_inners(card: Control, old: Rect2, neu: Vector2) -> void:
	var sx := neu.x / maxf(1.0, old.size.x)
	var sy := neu.y / maxf(1.0, old.size.y)
	for ch in card.get_children():
		if not (ch is Control):
			continue
		var c := ch as Control
		# Keep header labels near the top-left; stretch scroll/lists and free-placed blocks.
		if c is ScrollContainer:
			c.position = Vector2(c.position.x, c.position.y)
			c.size = Vector2(maxf(120.0, neu.x - c.position.x - 12.0), maxf(80.0, neu.y - c.position.y - 12.0))
		elif c is BoxContainer and c.position.y > 40.0:
			c.position.x = 18.0
			c.size.x = maxf(120.0, neu.x - 36.0)
			if c.size.y > 1.0:
				c.size.y = maxf(c.size.y * sy, c.size.y)
		elif c is Label or c is RichTextLabel:
			c.size.x = maxf(c.size.x * sx, neu.x - c.position.x - 24.0)
		elif c is BaseButton:
			c.position.x = minf(c.position.x, neu.x - maxf(c.custom_minimum_size.x, 120.0) - 14.0)
			c.custom_minimum_size.y = maxf(c.custom_minimum_size.y, MobilePage.HIT)


static func _boost_empty(page: Control, text_w: float) -> void:
	for empty in page.find_children("EmptyState", "PanelContainer", true, false):
		var p := empty as PanelContainer
		# Prefer filling the host card so empty pages do not look like a postage stamp.
		var host_w := text_w
		var host_h := 180.0
		var par := p.get_parent()
		if par is Control:
			host_w = maxf(host_w, (par as Control).size.x - 36.0)
			host_h = maxf(host_h, (par as Control).size.y - 72.0)
		elif p.get_parent() != null and p.get_parent().get_parent() is Control:
			var sc := p.get_parent().get_parent() as Control  # ScrollContainer under card
			host_w = maxf(host_w, sc.size.x - 28.0)
			host_h = maxf(host_h, sc.size.y - 24.0)
		p.custom_minimum_size = Vector2(maxf(p.custom_minimum_size.x, host_w), maxf(p.custom_minimum_size.y, mini(host_h, 280.0)))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for lab in p.find_children("*", "Label", true, false):
			var l := lab as Label
			var fs := l.get_theme_font_size("font_size")
			l.add_theme_font_size_override("font_size", maxi(fs, 22))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = maxf(text_w - 24.0, host_w - 48.0)

