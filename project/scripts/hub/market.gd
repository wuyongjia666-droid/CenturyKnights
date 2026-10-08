extends Control
## v8.6 — layout-matched to Stitch 14_market.png: top bar · 买入 PURCHASE list (left) · TARGET COMMODITY detail +
## QUANTITY SELECTOR + total estimate + 买入/卖出 CTAs (centre) · 卖出 STOCK list + 陆桥商队 caravan desk (right).
## Economy unchanged: GameState.market_buy/market_sell(item, qty), start_caravan, escort_caravan.

const ITEMS := ["food", "iron", "herb"]
const EN := {"food": "SUPPLIES // 战略储备", "iron": "IRON ORE // 锻造主料", "herb": "SALVE // 行军医疗"}
const DESC := {"food": "军粮是行军的底线。月结扣粮，粮尽则士气崩。", "iron": "炉火工坊打造灰刃的主料，市集等级越高越便宜。", "herb": "伤药：出征前备足，临时伤不至于拖垮整支旗队。"}
const ICON := {"food": "res://assets/art/ui/v86/kpi_grain.png", "iron": "res://assets/art/ui/v86/mk_iron.png", "herb": "res://assets/art/ui/v86/mk_herb.png"}

var _sel := "iron"
var _qty := 1
var _left: Control
var _mid: Control
var _right: Control
var _bar: Control
var _msg := ""
var _msg_ok := true

func _ready() -> void:
	UIKit.void_bg(self)
	Music.play_castle()
	_left = Control.new()
	_mid = Control.new()
	_right = Control.new()
	for n in [_left, _mid, _right]:
		n.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(n)
	_render()
	UIKit.footer_bar(self, [["A", "确认买入"], ["S", "卖出"], ["←→", "调整数量"], ["ESC", "返回城堡"]], "MARKET // LV %d · v8.6" % GameState.building_level("market"))
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()
	elif e is InputEventKey and e.pressed and not e.echo:
		match (e as InputEventKey).keycode:
			KEY_LEFT:
				_set_qty(_qty - 1)
			KEY_RIGHT:
				_set_qty(_qty + 1)
			KEY_S:
				_sell()
			_:
				return
		get_viewport().set_input_as_handled()

func _clear(n: Control) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()

func _render() -> void:
	if _bar:
		_bar.queue_free()
	_bar = UIKit.top_bar(self, "陆桥商路 · MARKET", [["银币", str(GameState.silver), UIKit.ACCENT], ["粮", str(GameState.food), UIKit.TEXT], ["铁", str(GameState.iron), UIKit.TEXT], ["药", str(GameState.herb), UIKit.TEXT], ["市集", "LV %d" % GameState.building_level("market"), UIKit.OK]], "返回城堡", _back)
	_clear(_left)
	_clear(_mid)
	_clear(_right)
	_render_left()
	_render_mid()
	_render_right()

func _icon(item: String, sz: int) -> TextureRect:
	var t := TextureRect.new()
	if ResourceLoader.exists(ICON[item]):
		t.texture = load(ICON[item])
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(sz, sz)
	t.size = Vector2(sz, sz)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _row_btn(r: Rect2, on: bool) -> Button:
	var b := Button.new()
	b.position = r.position
	b.custom_minimum_size = r.size
	b.size = r.size
	b.focus_mode = Control.FOCUS_ALL
	var n := UIKit.flat_box(Color(UIKit.ACCENT, 0.08) if on else Color(1, 1, 1, 0.02), Color(UIKit.ACCENT, 0.85) if on else Color(1, 1, 1, 0.08), 6, 2 if on else 1)
	UIKit._apply_states(b, {
		"normal": n,
		"hover": UIKit.flat_box(Color(0.07, 0.09, 0.12, 0.95), Color(UIKit.ACCENT, 0.45), 6),
		"pressed": UIKit.flat_box(Color(UIKit.ACCENT, 0.12), Color(UIKit.ACCENT, 0.9), 6, 2),
		"focus": UIKit._focus_ring(UIKit.FOCUS_RING, 8),
		"disabled": UIKit.flat_box(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.05), 6),
	})
	return b

func _render_left() -> void:
	UIKit.panel_at(_left, Rect2(24, 72, 336, 608), 10)
	UIKit.section_head(_left, Vector2(42, 86), "买入", "PURCHASE", 300, "市集 LV %d" % GameState.building_level("market"))
	var hd := UIKit.mono("采购品类 / ITEM                    单价", 8, UIKit.TEXT_FAINT, false)
	hd.position = Vector2(42, 116)
	_left.add_child(hd)
	var bp: Dictionary = GameState.market_buy_prices()
	var y := 136.0
	for it in ITEMS:
		var on: bool = it == _sel
		var b := _row_btn(Rect2(36, y, 312, 62), on)
		var item: String = it
		b.pressed.connect(func():
			_sel = item
			_qty = 1
			_render())
		_left.add_child(b)
		var ic := _icon(it, 32)
		ic.position = Vector2(12, 15)
		b.add_child(ic)
		var nm := UIKit.title_label(Locale.t(it), 15, UIKit.TEXT)
		nm.position = Vector2(56, 10)
		b.add_child(nm)
		var en := UIKit.mono(EN[it], 8, UIKit.TEXT_FAINT, false)
		en.position = Vector2(56, 36)
		b.add_child(en)
		var pr := UIKit.mono("%d" % int(bp[it]), 16, UIKit.ACCENT if on else UIKit.TEXT, false)
		pr.position = Vector2(280 - pr.get_minimum_size().x, 18)
		b.add_child(pr)
		var u := UIKit.mono("银", 8, UIKit.TEXT_FAINT, false)
		u.position = Vector2(286, 26)
		b.add_child(u)
		if on:
			b.call_deferred("grab_focus")
		y += 72
	UIKit.panel_at(_left, Rect2(36, 560, 312, 104), 8)
	var nt := UIKit.title_label("ⓘ 陆桥商行情报", 12, UIKit.ACCENT)
	nt.position = Vector2(50, 572)
	_left.add_child(nt)
	var nb := UIKit.body_label("工事升市集、委任守桥首通、联姻商契都会改价%s。" % ("；商路已通，价更优" if bool(GameState.house_mods.get("trade_route", false)) else ""), UIKit.TEXT_DIM, 11)
	nb.position = Vector2(50, 596)
	nb.size = Vector2(284, 60)
	nb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_left.add_child(nb)

func _set_qty(q: int) -> void:
	var price := int(GameState.market_buy_prices()[_sel])
	var mx := maxi(1, int(GameState.silver / maxi(1, price)))
	_qty = clampi(q, 1, maxi(1, mini(99, mx)))
	_render()

func _render_mid() -> void:
	UIKit.panel_at(_mid, Rect2(372, 72, 512, 608), 10)
	UIKit.section_head(_mid, Vector2(390, 86), "当前选定", "TARGET COMMODITY", 476, "REG-ID: #%s-%02d" % [_sel.to_upper(), GameState.building_level("market")])
	var bp: Dictionary = GameState.market_buy_prices()
	var sp: Dictionary = GameState.market_sell_prices()
	var price := int(bp[_sel])
	UIKit.panel_at(_mid, Rect2(390, 116, 476, 108), 8)
	var ib := UIKit.panel_at(_mid, Rect2(404, 130, 80, 80), 8, true)
	var ic := _icon(_sel, 52)
	ic.position = Vector2(14, 14)
	ib.add_child(ic)
	var nm := UIKit.title_label(Locale.t(_sel), 24, UIKit.TEXT)
	nm.position = Vector2(500, 128)
	_mid.add_child(nm)
	var en := UIKit.mono(EN[_sel], 9, UIKit.ACCENT, false)
	en.position = Vector2(500 + nm.get_minimum_size().x + 12, 140)
	_mid.add_child(en)
	var ds := UIKit.body_label(DESC[_sel], UIKit.TEXT_DIM, 12)
	ds.position = Vector2(500, 166)
	ds.size = Vector2(352, 44)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mid.add_child(ds)
	var g := HBoxContainer.new()
	g.position = Vector2(390, 238)
	g.add_theme_constant_override("separation", 10)
	_mid.add_child(g)
	for sb in [UIKit.stat_box("买入单价 BUY", "%d 银" % price, UIKit.ACCENT), UIKit.stat_box("卖出回收 SELL", "%d 银" % int(sp[_sel]), UIKit.TEXT), UIKit.stat_box("库存 STOCK", "%d" % int(GameState.get(_sel)), UIKit.TEXT)]:
		sb.custom_minimum_size = Vector2(152, 0)
		g.add_child(sb)
	# quantity selector
	UIKit.panel_at(_mid, Rect2(390, 318, 476, 164), 8)
	var qh := UIKit.title_label("■ 采购数量锁定", 12, UIKit.ACCENT)
	qh.position = Vector2(406, 330)
	_mid.add_child(qh)
	var qe := UIKit.mono("// QUANTITY SELECTOR", 8, UIKit.TEXT_FAINT, false)
	qe.position = Vector2(406 + qh.get_minimum_size().x + 8, 334)
	_mid.add_child(qe)
	var mx := maxi(1, mini(99, int(GameState.silver / maxi(1, price))))
	var mxl := UIKit.body_label("最大可购：%d 份" % mx, UIKit.TEXT_FAINT, 11)
	mxl.autowrap_mode = TextServer.AUTOWRAP_OFF
	mxl.position = Vector2(850 - mxl.get_minimum_size().x, 331)
	_mid.add_child(mxl)
	var steps := [["-10", -10, 406], ["−", -1, 462], ["+", 1, 742], ["+10", 10, 798]]
	for st in steps:
		var b := UIKit.ghost_button(str(st[0]), 48, 48)
		b.position = Vector2(st[2], 364)
		var d: int = st[1]
		b.pressed.connect(func(): _set_qty(_qty + d))
		_mid.add_child(b)
	var qv := UIKit.mono("%02d" % _qty, 34, UIKit.TEXT, false)
	qv.position = Vector2(628 - qv.get_minimum_size().x * 0.5, 362)
	_mid.add_child(qv)
	var qu := UIKit.mono("份 · 单价 %d 银" % price, 8, UIKit.TEXT_FAINT, false)
	qu.position = Vector2(628 - qu.get_minimum_size().x * 0.5, 410)
	_mid.add_child(qu)
	var qk := HBoxContainer.new()
	qk.position = Vector2(520, 442)
	qk.add_theme_constant_override("separation", 8)
	_mid.add_child(qk)
	var ql := UIKit.body_label("快速配比：", UIKit.TEXT_FAINT, 11)
	ql.autowrap_mode = TextServer.AUTOWRAP_OFF
	ql.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qk.add_child(ql)
	for p in [["最少 (1)", 1], ["半量 (%d)" % maxi(1, mx / 2), maxi(1, mx / 2)], ["上限 (%d)" % mx, mx]]:
		var qb := UIKit.ghost_button(str(p[0]), 76, 24)
		qb.add_theme_font_size_override("font_size", 11)
		var qn: int = p[1]
		qb.pressed.connect(func(): _set_qty(qn))
		qk.add_child(qb)
	# total
	UIKit.panel_at(_mid, Rect2(390, 494, 476, 62), 8)
	var tl := UIKit.mono("本次结算预估 // TOTAL ESTIMATE", 8, UIKit.TEXT_FAINT, false)
	tl.position = Vector2(406, 506)
	_mid.add_child(tl)
	var tv := UIKit.mono("%d 银 × %d 份 = %d 银" % [price, _qty, price * _qty], 13, UIKit.TEXT, false)
	tv.position = Vector2(406, 526)
	_mid.add_child(tv)
	var left := GameState.silver - price * _qty
	var rl := UIKit.mono("支付后银币余额", 8, UIKit.TEXT_FAINT, false)
	rl.position = Vector2(850 - rl.get_minimum_size().x, 506)
	_mid.add_child(rl)
	var rv := UIKit.mono("%d" % left, 15, UIKit.ACCENT if left >= 0 else UIKit.DANGER, false)
	rv.position = Vector2(850 - rv.get_minimum_size().x, 524)
	_mid.add_child(rv)
	if _msg != "":
		var m := UIKit.body_label(_msg, UIKit.OK if _msg_ok else UIKit.DANGER, 12)
		m.autowrap_mode = TextServer.AUTOWRAP_OFF
		m.position = Vector2(390, 572)
		_mid.add_child(m)
	var sell := UIKit.ghost_button("卖出 %d 份  [S]" % _qty, 150, 52)
	sell.position = Vector2(390, 612)
	sell.disabled = int(GameState.get(_sel)) < _qty
	sell.pressed.connect(_sell)
	_mid.add_child(sell)
	var buy := UIKit.cta_button("买入 · %d 银" % (price * _qty), "A", 300, 52)
	buy.position = Vector2(566, 612)
	buy.disabled = left < 0
	buy.pressed.connect(_buy)
	_mid.add_child(buy)

func _buy() -> void:
	var r: Dictionary = GameState.market_buy(_sel, _qty)
	_msg = str(r.get("msg"))
	_msg_ok = bool(r.get("ok", true))
	if _msg_ok:
		Sfx.deal()
	_render()

func _sell() -> void:
	var r: Dictionary = GameState.market_sell(_sel, _qty)
	_msg = str(r.get("msg"))
	_msg_ok = bool(r.get("ok", true))
	_qty = 1
	_render()

func _render_right() -> void:
	UIKit.panel_at(_right, Rect2(896, 72, 360, 300), 10)
	UIKit.section_head(_right, Vector2(912, 86), "卖出", "SELL // 库存回收", 328, "")
	var hd := UIKit.mono("库藏 / STOCK               持有        回收价", 8, UIKit.TEXT_FAINT, false)
	hd.position = Vector2(912, 116)
	_right.add_child(hd)
	var sp: Dictionary = GameState.market_sell_prices()
	var y := 134.0
	for it in ITEMS:
		var b := _row_btn(Rect2(906, y, 340, 50), it == _sel)
		var item: String = it
		b.pressed.connect(func():
			_sel = item
			_qty = 1
			_render())
		_right.add_child(b)
		var ic := _icon(it, 24)
		ic.position = Vector2(10, 13)
		b.add_child(ic)
		var nm := UIKit.title_label(Locale.t(it), 13, UIKit.TEXT)
		nm.position = Vector2(44, 14)
		b.add_child(nm)
		var st := UIKit.mono("%d" % int(GameState.get(it)), 14, UIKit.ACCENT, false)
		st.position = Vector2(200 - st.get_minimum_size().x, 15)
		b.add_child(st)
		var pv := UIKit.mono("%d 银" % int(sp[it]), 12, UIKit.TEXT, false)
		pv.position = Vector2(326 - pv.get_minimum_size().x, 16)
		b.add_child(pv)
		y += 58
	var tot := 0
	for it in ITEMS:
		tot += int(GameState.get(it)) * int(sp[it])
	var kv := UIKit.kv_row("仓库预估总值", "%d 银" % tot, UIKit.ACCENT, 328)
	kv.position = Vector2(912, 334)
	_right.add_child(kv)
	# caravan desk
	UIKit.panel_at(_right, Rect2(896, 384, 360, 296), 10)
	UIKit.section_head(_right, Vector2(912, 398), "陆桥商队", "CARAVAN · 三月交割", 328, "")
	var tip := UIKit.body_label("粮运稳、铁运厚、香料险而利。商路旁注与联姻义役可降低遇劫。", UIKit.TEXT_DIM, 11)
	tip.position = Vector2(912, 424)
	tip.size = Vector2(328, 34)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right.add_child(tip)
	var busy := int(GameState.caravan.get("turns_left", 0)) > 0
	var cx := 912.0
	for kind in ["grain", "iron", "spice"]:
		var cn: String = {"grain": "粮运\n35 银", "iron": "铁运\n45 银", "spice": "香料\n55 银"}[kind]
		var b := UIKit.ghost_button(cn, 104, 70)
		b.position = Vector2(cx, 470)
		b.disabled = busy
		var ip: String = {"grain": "res://assets/art/ui/v86/kpi_grain.png", "iron": "res://assets/art/ui/v86/mk_iron.png", "spice": "res://assets/art/ui/v86/kpi_cash.png"}[kind]
		if ResourceLoader.exists(ip):
			b.icon = load(ip)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 28)
		var k: String = kind
		b.pressed.connect(func():
			var r: Dictionary = GameState.start_caravan(k)
			_msg = str(r.get("msg"))
			_msg_ok = bool(r.get("ok"))
			if _msg_ok:
				Sfx.deal()
				GameState.save_game()
			_render())
		_right.add_child(b)
		cx += 112
	var st := UIKit.body_label(_caravan_status(), UIKit.ACCENT if busy else UIKit.TEXT_FAINT, 12)
	st.name = "CaravanStatus"
	st.autowrap_mode = TextServer.AUTOWRAP_OFF
	st.position = Vector2(912, 556)
	_right.add_child(st)
	var esc := UIKit.ghost_button("⇄ 雇护运（12 银）", 328, 40)
	esc.position = Vector2(912, 590)
	esc.disabled = not busy
	esc.tooltip_text = "" if busy else "暂无商队在途"
	esc.pressed.connect(func():
		var r: Dictionary = GameState.escort_caravan()
		_msg = str(r.get("msg"))
		_msg_ok = bool(r.get("ok"))
		if _msg_ok:
			Sfx.confirm()
			GameState.save_game()
		_render())
	_right.add_child(esc)

func _caravan_status() -> String:
	if int(GameState.caravan.get("turns_left", 0)) > 0:
		var k = str(GameState.caravan.get("kind", ""))
		var cn = {"grain": "粮运", "iron": "铁运", "spice": "香料"}.get(k, k)
		return "在途：%s · 余 %d 月 · 投资 %d 银" % [cn, int(GameState.caravan.turns_left), int(GameState.caravan.get("invested", 0))]
	return "暂无商队在途——选一条航线投资上路。"
