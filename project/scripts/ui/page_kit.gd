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
static func shell(page: Control, context: String, eyebrow: String, title: String, desc: String = "", theme: String = "") -> void:
	## theme "none": the page already painted its own backdrop (UIKit.make_themed_bg(self, ...)).
	if theme == "":
		UIKit.void_bg(page)
	elif theme != "none":
		UIKit.make_themed_bg(page, theme)
	UIKit.top_bar(page, context, [[Locale.t("lb_chip_date"), Calendar.label(), UIKit.TEXT_DIM]], Locale.t("btn_back"), func(): back(page))
	var head := UIKit.page_head(page, PAD, 50, eyebrow, title, "", "", "", 22)
	head.name = "PageHead"
	if desc != "":
		var tl := head.get_child(1).get_child(0) as Label
		var x := PAD + (tl.get_minimum_size().x if tl != null else 160.0) + 24.0
		var d := UIKit.body_label(desc, UIKit.TEXT_DIM, 12)
		d.name = "PageDesc"
		d.autowrap_mode = TextServer.AUTOWRAP_OFF
		d.clip_text = true
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		d.position = Vector2(x, 100)
		d.size = Vector2(1280.0 - PAD - x, 18)
		d.tooltip_text = desc
		d.mouse_filter = Control.MOUSE_FILTER_PASS
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
	var b: Button = UIKit.make_accent_button(label, int(w)) if primary else UIKit.make_button(label, int(w))
	b.custom_minimum_size = Vector2(w, maxf(h, HIT))
	b.add_theme_font_size_override("font_size", 15)
	return b

## Disable with a reason the player sees when they tap it anyway (UIFX.deny).
static func lock(b: BaseButton, reason: String) -> void:
	b.disabled = reason != ""
	b.set_meta("deny_reason", reason)
	b.tooltip_text = reason

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
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
