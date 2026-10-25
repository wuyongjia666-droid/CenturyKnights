extends Control
## Rival houses (line B, audit #26). Left: ten houses with stance and relation. Right: the
## picked house, its latest scheme, and one action card per move (cost / effect / risk).
## Cards say why they cannot be used. Deal logic is unchanged (GameState / CKSchemes).

var _list: VBoxContainer
var _head: VBoxContainer
var _grid: GridContainer
var _msg: Label
var _left: Control
var _right: Control
var _selected: Dictionary = {}

func _ready() -> void:
	UIKit.make_themed_bg(self, "rival")
	CKPageKit.shell(self, Locale.t("lb_rv_ctx"), "RIVAL HOUSES", Locale.t("lb_rv_title"), Locale.t("lb_rv_desc"), "none")
	_left = _frost_panel()
	_left.name = "RivalList"
	add_child(_left)
	_list = CKPageKit.list(_left, Rect2(12, 12, 316, 476), "Houses")
	_right = _frost_panel()
	_right.name = "RivalDetail"
	add_child(_right)
	var inner := VBoxContainer.new()
	inner.name = "DetailInner"
	inner.add_theme_constant_override("separation", 10)
	_right.add_child(inner)
	_head = VBoxContainer.new()
	_head.add_theme_constant_override("separation", 4)
	inner.add_child(_head)
	var s := ScrollContainer.new()
	s.name = "ActionScroll"
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.scroll_deadzone = 10
	inner.add_child(s)
	_grid = GridContainer.new()
	_grid.name = "Actions"
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	s.add_child(_grid)
	_msg = CKPageKit.feedback(self)
	_refresh()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "RIVAL HOUSES · FROST")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)
	apply_mobile_layout()

func _frost_panel() -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.clip_contents = true
	var sb := UIKit.glass(12, 0.98, true)
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)
	var fill := ColorRect.new()
	fill.name = "FrostFill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = Color(UIKit.PANEL, 0.96)
	p.add_child(fill)
	return p

## Desktop: fixed 1280×720 columns + optional whole-page scale (narrow_layout_check).
## Phone (CK_FORCE_MOBILE / device): fill height, grow list/detail, FONT_FLOOR — no shrink.
func apply_mobile_layout() -> void:
	if _left == null or _right == null:
		return
	set_meta("m_center_ok", true)
	if DeviceProfile.is_mobile() or has_meta("mobile_fit_key"):
		_apply_phone_layout()
		return
	_apply_desktop_layout()

func _apply_desktop_layout() -> void:
	scale = Vector2.ONE
	_left.position = Vector2(42, CKPageKit.TOP + 8)
	_left.size = Vector2(340, 500)
	_right.position = Vector2(394, CKPageKit.TOP + 8)
	_right.size = Vector2(844, 500)
	_sync_frost_fills()
	var inner := _right.get_node_or_null("DetailInner") as Control
	if inner:
		inner.position = Vector2(16, 14)
		inner.size = Vector2(812, 472)
	_grid.columns = 2
	var vp := get_viewport_rect().size
	var k := minf(vp.x / 1280.0, vp.y / 720.0)
	if k < 0.999:
		scale = Vector2(k, k)
		size = Vector2(1280, 720)
	else:
		scale = Vector2.ONE

func _apply_phone_layout() -> void:
	scale = Vector2.ONE
	MobileLayout.pin_footer(get_node_or_null("StitchFooter"))
	var top := CKPageKit.TOP + 8.0
	var foot := get_node_or_null("StitchFooter") as Control
	var bottom := size.y - 48.0
	if foot != null:
		foot.position.y = minf(foot.position.y, size.y - maxf(foot.size.y, 28.0))
		bottom = minf(foot.position.y - 8.0, size.y - 8.0)
	var h := maxf(240.0, bottom - top)
	var w := size.x
	var pad := 16.0
	var gap := 12.0
	var lw := clampf(w * 0.28, 280.0, 400.0)
	_left.position = Vector2(pad, top)
	_left.size = Vector2(lw, h)
	_right.position = Vector2(pad + lw + gap, top)
	_right.size = Vector2(maxf(280.0, w - pad * 2.0 - lw - gap), h)
	_sync_frost_fills()
	var list_scroll := _left.get_node_or_null("HousesScroll") as ScrollContainer
	if list_scroll != null:
		list_scroll.position = Vector2(12, 12)
		list_scroll.size = Vector2(maxf(200.0, _left.size.x - 24.0), maxf(120.0, _left.size.y - 24.0))
		if _list != null:
			_list.custom_minimum_size.x = maxf(180.0, list_scroll.size.x - 14.0)
	var inner := _right.get_node_or_null("DetailInner") as Control
	if inner:
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 16.0
		inner.offset_top = 14.0
		inner.offset_right = -16.0
		inner.offset_bottom = -14.0
		inner.position = Vector2(16, 14)
		inner.size = Vector2(maxf(280.0, _right.size.x - 32.0), maxf(160.0, _right.size.y - 28.0))
	_grid.columns = 1 if _right.size.x < 720.0 else 2
	if _list != null:
		for b in _list.get_children():
			if b is Button:
				var btn := b as Button
				btn.add_theme_font_size_override("font_size", maxi(btn.get_theme_font_size("font_size"), MobileLayout.FONT_FLOOR))
				btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, MobilePage.HIT * 0.9)
	for card in _grid.get_children():
		if card is Control:
			var pc := card as Control
			pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pc.custom_minimum_size.x = 0.0
			pc.custom_minimum_size.y = maxf(pc.custom_minimum_size.y, 180.0)
	MobileLayout.ensure_min_fonts(self)
	# PageHead is font_floor_exempt — hide Latin kickers / raise title+desc.
	var head := find_child("PageHead", true, false) as Control
	if head != null:
		for n in head.find_children("*", "Label", true, false):
			var lab := n as Label
			var fs := lab.get_theme_font_size("font_size")
			if fs <= 12 and MobileLayout.is_decor_kicker(lab.text):
				lab.visible = false
				lab.set_meta("m_kicker_hidden", true)
			elif fs < MobileLayout.FONT_FLOOR:
				lab.add_theme_font_size_override("font_size", MobileLayout.FONT_FLOOR)
	for card in _grid.get_children():
		for lab in card.find_children("*", "Label", true, false):
			var l := lab as Label
			l.clip_text = false
			if l.custom_minimum_size.x > 0.0:
				l.custom_minimum_size.x = maxf(l.custom_minimum_size.x, minf(360.0, _right.size.x - 80.0))

func _sync_frost_fills() -> void:
	for p in [_left, _right]:
		var fill := (p as Control).get_node_or_null("FrostFill") as Control
		if fill:
			fill.position = Vector2.ZERO
			fill.size = (p as Control).size

func _refresh() -> void:
	CKPageKit.clear(_list)
	var houses: Array = GameState.data_rivals.get("houses", [])
	if houses.is_empty():
		## Y1-B / heir #30: no rivals → why/how + named ToCourtNews (schemes live on the gazette).
		var host := VBoxContainer.new()
		host.name = "EmptyHost"
		host.add_theme_constant_override("separation", 12)
		host.add_child(CKPageKit.empty(
			Locale.t("lb_rv_none"),
			Locale.t("lb_rv_none_why"),
			Locale.t("lb_rv_none_how"),
			280
		))
		var acts := HBoxContainer.new()
		acts.name = "EmptyActions"
		acts.add_theme_constant_override("separation", 12)
		var to_n := CKPageKit.button(Locale.t("lb_rv_to_court_news"), true, 260)
		to_n.name = "ToCourtNews"
		to_n.pressed.connect(func(): CKNav.go("res://scenes/hub/court_news.tscn"))
		acts.add_child(to_n)
		UIFX.wire_button(to_n)
		host.add_child(acts)
		_list.add_child(host)
		return
	for h in houses:
		var hid := str(h.get("id"))
		var rel := _relation(hid)
		var band := CKSchemes.band_of(rel)
		var b := Button.new()
		b.name = "House_%s" % hid
		b.custom_minimum_size = Vector2(0, 56)
		b.toggle_mode = true
		b.button_pressed = str(_selected.get("id", "")) == hid
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "  %s　·　%s %d" % [str(h.get("name")), CKSchemes.band_zh(band), rel]
		b.add_theme_font_size_override("font_size", MobileLayout.FONT_FLOOR if DeviceProfile.is_mobile() else 15)
		if int(GameState.rival_deals.get(hid, {}).get("turns_left", 0)) > 0:
			b.text += "　" + Locale.t("lb_rv_dealing")
		## 敌徽 — nation arms via Chrome (never company/family).
		var ra := CKHeraldryChrome.make_rival_arms(h, Vector2(28, 34))
		ra.position = Vector2(6, 11)
		ra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ra)
		b.pressed.connect(func(): Sfx.click(); _select(h); _refresh_marks())
		_list.add_child(b)
	CKPageKit.drag_through(_list)
	if _selected.is_empty():
		_selected = houses[0]
	_select(_selected)
	_refresh_marks()

func _refresh_marks() -> void:
	for b in _list.get_children():
		if b is Button:
			(b as Button).set_pressed_no_signal(str(b.name) == "House_%s" % str(_selected.get("id", "")))

func _relation(hid: String) -> int:
	var court := _court_house(hid)
	return int(court.get("relation", CKSchemes.opening_relation(hid))) if not court.is_empty() else CKSchemes.opening_relation(hid)

func _select(h: Dictionary) -> void:
	_selected = h
	CKPageKit.clear(_head)
	CKPageKit.clear(_grid)
	var hid := str(h.get("id"))
	var rel := _relation(hid)
	var band := CKSchemes.band_of(rel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_head.add_child(row)
	row.add_child(CKHeraldryChrome.make_rival_arms(h, Vector2(44, 52)))
	row.add_child(UIKit.title_label(str(h.get("name")), 22))
	row.add_child(UIKit.tag_chip(Locale.t("lb_rv_rel", [CKSchemes.band_zh(band), rel]), UIKit.OK if rel >= 0 else UIKit.DANGER))
	_head.add_child(CKPageKit.text(Locale.t("lb_rv_creed", [str(h.get("creed", "")), str(h.get("desc", ""))]), UIKit.TEXT_DIM, 13, 800))
	var last := CKSchemes.latest(_court_house(hid))
	_head.add_child(CKPageKit.text(Locale.t("lb_rv_scheme", [str(last.get("text", Locale.t("lb_rv_no_scheme")))]), UIKit.ACCENT, 13, 800))
	var deal: Dictionary = GameState.rival_deals.get(hid, {})
	var s := GameState.silver
	if int(deal.get("turns_left", 0)) > 0:
		var mid := str(deal.get("last_event", ""))
		var said := Locale.t("lb_rv_deal_now", [_kind_zh(str(deal.get("kind"))), int(deal.get("turns_left")), mid if mid != "" else Locale.t("lb_rv_deal_quiet")])
		_head.add_child(CKPageKit.text(said, UIKit.OK, 13, 800))
		_card("lb_rv_a_tick", "", Func.new(func(): _tick_month(hid)), "")
		for k in ["trade", "intel", "truce"]:
			if k == str(deal.get("kind")):
				continue
			_card("lb_rv_a_reneg_" + k, "15", Func.new(func(): _renego(hid, k)), Locale.t("lb_short_silver", [15 - s]) if s < 15 else "")
		_card("lb_rv_a_breach", "", Func.new(func(): _breach(hid)), "")
	else:
		_card("lb_rv_a_trade", "25", Func.new(func(): _deal(hid, "trade")), Locale.t("lb_short_silver", [25 - s]) if s < 25 else "")
		_card("lb_rv_a_intel", "25", Func.new(func(): _deal(hid, "intel")), Locale.t("lb_short_silver", [25 - s]) if s < 25 else "")
		_card("lb_rv_a_truce", "40", Func.new(func(): _deal(hid, "truce", 2, 40)), Locale.t("lb_short_silver", [40 - s]) if s < 40 else "")
	var counter_why := ""
	if last.is_empty() or bool(last.get("foiled", false)):
		counter_why = Locale.t("lb_rv_counter_none")
	elif not (GameState.buildings.has("embassy") and int(GameState.buildings.get("embassy", 0)) >= 1):
		counter_why = Locale.t("lb_rv_counter_noemb")
	_card("lb_rv_a_counter", "", Func.new(func(): _counter(hid)), counter_why)
	_card("lb_rv_a_gift", "30", Func.new(func(): _gift(hid)), Locale.t("lb_short_silver", [30 - s]) if s < 30 else ("" if band != "cordial" else Locale.t("lb_rv_gift_max")))
	_card("lb_rv_a_press", "", Func.new(func(): _pressure(hid)), "")
	if hid == "shuoying" and GameState.get_rival_stance(hid) in ["hostile", "wary"]:
		_card("lb_rv_a_inherit", "", Func.new(func(): CKNav.go("res://scenes/hub/inheritance.tscn")), "")
	_card("lb_rv_a_heirs", "", Func.new(func(): CKNav.go("res://scenes/hub/heir_rivalry.tscn")), "")
	CKPageKit.drag_through(_grid)
	UIFX.wire_tree(_grid)

## Tiny holder so each card keeps its own callable.
class Func:
	var cb: Callable
	func _init(c: Callable) -> void:
		cb = c

## key -> locale key prefix: <key> title, <key>_fx effect, <key>_risk risk.
func _card(key: String, cost: String, f: Func, why: String) -> void:
	var r := CKPageKit.row(UIKit.ACCENT, 150)
	var p: PanelContainer = r[0]
	p.custom_minimum_size = Vector2(396, 180 if DeviceProfile.is_mobile() else 150)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.name = "Act_" + key.trim_prefix("lb_rv_a_")
	var v: VBoxContainer = r[1]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(UIKit.title_label(Locale.t(key), 16))
	top.add_child(UIKit.tag_chip(Locale.t("lb_rv_cost", [cost]) if cost != "" else Locale.t("lb_rv_free"), UIKit.ACCENT if cost != "" else UIKit.OK))
	v.add_child(CKPageKit.text(Locale.t(key + "_fx"), UIKit.TEXT, 13, 360))
	v.add_child(CKPageKit.text(Locale.t(key + "_risk"), UIKit.TEXT_DIM, 12, 360))
	var b := CKPageKit.button(Locale.t("lb_rv_do"), why == "", 360)
	CKPageKit.lock(b, why)
	b.pressed.connect(f.cb)
	v.add_child(b)
	_grid.add_child(p)

func _kind_zh(k: String) -> String:
	return Locale.t("lb_rv_kind_" + k)

func _court_house(hid: String) -> Dictionary:
	if typeof(World.royal_courts) != TYPE_DICTIONARY:
		return {}
	var nations: Dictionary = World.royal_courts.get("nations", {})
	var row = nations.get(hid, {})
	return row if typeof(row) == TYPE_DICTIONARY else {}

func _done(msg: String, ok: bool) -> void:
	CKPageKit.say(_msg, msg, ok)
	if ok:
		GameState.save_game()
	_refresh()

func _counter(hid: String) -> void:
	var court := _court_house(hid)
	var last := CKSchemes.latest(court)
	CKSchemes.apply_counter(court, last)
	var nations: Dictionary = World.royal_courts.get("nations", {})
	nations[hid] = court
	World.royal_courts["nations"] = nations
	GameState.add_lineage_event(Locale.t("lb_rv_log_counter", [hid]))
	_done(Locale.t("lb_rv_counter_ok", [str(_selected.get("name", hid)), str(last.get("kind_zh", ""))]), true)

func _gift(hid: String) -> void:
	GameState.silver -= 30
	var cur := GameState.get_rival_stance(hid)
	var nxt: String = {"hostile": "wary", "wary": "neutral", "neutral": "cordial", "cordial": "cordial"}.get(cur, "neutral")
	GameState.set_rival_stance(hid, nxt)
	GameState.add_lineage_event(Locale.t("lb_rv_log_gift", [hid, nxt]))
	_done(Locale.t("lb_rv_gift_ok", [CKSchemes.band_zh(nxt)]), true)

func _renego(hid: String, kind: String) -> void:
	var r: Dictionary = GameState.renegotiate_rival_deal(hid, kind, 15)
	_done(str(r.get("msg")), bool(r.get("ok", false)))

func _breach(hid: String) -> void:
	var r: Dictionary = GameState.breach_rival_deal(hid)
	_done(str(r.get("msg")), bool(r.get("ok", false)))

func _deal(hid: String, kind: String, turns: int = 3, price: int = 25) -> void:
	Sfx.deal()
	var r: Dictionary = GameState.start_rival_deal(hid, kind, turns, price)
	_done(str(r.get("msg")), bool(r.get("ok", false)))

func _pressure(hid: String) -> void:
	GameState.add_rep("ashland", 1)
	var msg := Locale.t("lb_rv_press_ok")
	if hid == "shuoying" and GameState.get_rival_stance(hid) == "hostile":
		msg = Locale.t("lb_rv_press_shuoying")
	elif GameState.get_rival_stance(hid) == "cordial":
		msg = Locale.t("lb_rv_press_cordial")
	GameState.add_lineage_event(Locale.t("lb_rv_log_press", [hid]))
	_done(msg, true)

func _tick_month(hid: String) -> void:
	var evs = Calendar.advance(1)
	var lines: Array = []
	for e in evs:
		var tx := str(e.get("text", ""))
		if tx.find(Locale.t("lb_rv_deal_word")) >= 0 or tx.find(hid) >= 0:
			lines.append(tx)
	if lines.is_empty() and GameState.last_deal_events.size() > 0:
		lines = GameState.last_deal_events.duplicate()
	_done(Locale.t("lb_rv_tick_quiet") if lines.is_empty() else Locale.t("lb_rv_tick_mid", [" / ".join(lines)]), true)
