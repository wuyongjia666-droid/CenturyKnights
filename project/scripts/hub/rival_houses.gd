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
	CKPageKit.shell(self, Locale.t("lb_rv_ctx"), "RIVAL HOUSES", Locale.t("lb_rv_title"), Locale.t("lb_rv_desc"))
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

## Fixed 1280x720 design. On a bare small window (no CKMobileChrome fit) scale the page down.
func apply_mobile_layout() -> void:
	if _left == null or _right == null:
		return
	_left.position = Vector2(42, CKPageKit.TOP + 8)
	_left.size = Vector2(340, 500)
	_right.position = Vector2(394, CKPageKit.TOP + 8)
	_right.size = Vector2(844, 500)
	for p in [_left, _right]:
		var fill := (p as Control).get_node_or_null("FrostFill") as Control
		if fill:
			fill.position = Vector2.ZERO
			fill.size = (p as Control).size
	var inner := _right.get_node_or_null("DetailInner") as Control
	if inner:
		inner.position = Vector2(16, 14)
		inner.size = Vector2(812, 472)
	if has_meta("mobile_fit_key"):
		return
	var vp := get_viewport_rect().size
	var k := minf(vp.x / 1280.0, vp.y / 720.0)
	if k < 0.999:
		scale = Vector2(k, k)
		size = Vector2(1280, 720)
	else:
		scale = Vector2.ONE

func _refresh() -> void:
	CKPageKit.clear(_list)
	var houses: Array = GameState.data_rivals.get("houses", [])
	if houses.is_empty():
		_list.add_child(CKPageKit.empty(Locale.t("lb_rv_none"), Locale.t("lb_rv_none_why"), "", 280))
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
		b.add_theme_font_size_override("font_size", 15)
		if int(GameState.rival_deals.get(hid, {}).get("turns_left", 0)) > 0:
			b.text += "　" + Locale.t("lb_rv_dealing")
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
	p.custom_minimum_size = Vector2(396, 150)
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
