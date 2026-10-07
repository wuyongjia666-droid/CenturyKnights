extends Control
## 陆桥商路：买卖 + 商队决策（中长期贸易环）· 前端式信息层级 + AT 动效

var _msg: Label
var _prices: Label

func _ready() -> void:
	UIKit.make_themed_bg(self, "market")
	UIFX.fade_in(self, 0.30)
	Music.play_castle()
	if ResourceLoader.exists("res://assets/art/ui/caravan_banner.png"):
		var strip := TextureRect.new()
		strip.texture = load("res://assets/art/ui/caravan_banner.png")
		strip.position = Vector2(0, 0)
		strip.custom_minimum_size = Vector2(1280, 52)
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)
	elif ResourceLoader.exists("res://assets/art/ui/market_banner.png"):
		var strip2 := TextureRect.new()
		strip2.texture = load("res://assets/art/ui/market_banner.png")
		strip2.position = Vector2(0, 0)
		strip2.custom_minimum_size = Vector2(1280, 48)
		strip2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip2.stretch_mode = TextureRect.STRETCH_SCALE
		strip2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip2)

	var t = UIKit.make_label("陆桥商路（堡内市 · 商队）", true)
	t.position = Vector2(40, 12)
	add_child(t)
	UIFX.breathe(t, 0.008, 3.0)

	_prices = UIKit.make_dim_label(_price_text())
	_prices.position = Vector2(40, 56)
	_prices.custom_minimum_size = Vector2(1180, 30)
	add_child(_prices)

	# 主区：即时买卖（短环）
	var sec1 = UIKit.make_label("市集现货")
	sec1.position = Vector2(40, 96)
	sec1.add_theme_color_override("font_color", UIKit.ACCENT)
	add_child(sec1)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(40, 130)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.name = "BuySellGrid"
	add_child(grid)
	for item in ["food", "iron", "herb"]:
		var buy = UIKit.make_accent_button("买" + Locale.t(item), 160)
		var it = item
		buy.pressed.connect(func():
			UIFX.press_feedback(buy)
			var r = GameState.market_buy(it)
			_msg.text = str(r.get("msg"))
			if r.get("ok", true):
				UIFX.confirm_burst(buy)
				Sfx.deal()
			_refresh_prices()
		)
		grid.add_child(buy)
		var sell = UIKit.make_button("卖" + Locale.t(item), 160)
		sell.pressed.connect(func():
			UIFX.press_feedback(sell)
			var r = GameState.market_sell(it)
			_msg.text = str(r.get("msg"))
			_refresh_prices()
		)
		grid.add_child(sell)
	UIFX.stagger_children(grid, 0.04, 0.24)

	# 中长期：商队
	var sec2 = UIKit.make_label("陆桥商队（投资 · 三月交割）")
	sec2.position = Vector2(40, 280)
	sec2.add_theme_color_override("font_color", UIKit.ACCENT)
	add_child(sec2)
	var tip2 = UIKit.make_dim_label("粮运稳、铁运厚、香料险而利。商路旁注与联姻义役可降低遇劫。途中写入族谱。")
	tip2.position = Vector2(40, 310)
	tip2.custom_minimum_size = Vector2(1100, 30)
	add_child(tip2)

	var row := HBoxContainer.new()
	row.position = Vector2(40, 350)
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	for kind in ["grain", "iron", "spice"]:
		var hb := VBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ip = "res://assets/art/ui/convoy_%s.png" % kind
		if ResourceLoader.exists(ip):
			icon.texture = load(ip)
		hb.add_child(icon)
		var cn = {"grain": "粮运 35银", "iron": "铁运 45银", "spice": "香料 55银"}[kind]
		var b = UIKit.make_accent_button(cn, 140)
		var k = kind
		b.pressed.connect(func():
			UIFX.press_feedback(b)
			var r = GameState.start_caravan(k)
			_msg.text = str(r.get("msg"))
			if r.get("ok"):
				UIFX.confirm_burst(b)
				Sfx.deal()
				GameState.save_game()
			_refresh_prices()
		)
		hb.add_child(b)
		row.add_child(hb)
	UIFX.stagger_children(row, 0.05, 0.26)

	var status = UIKit.make_dim_label(_caravan_status())
	status.position = Vector2(40, 460)
	status.name = "CaravanStatus"
	add_child(status)

	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 500)
	_msg.custom_minimum_size = Vector2(1000, 40)
	add_child(_msg)
	var tip = UIKit.make_dim_label("工事升市集、委任守桥首通、联姻商契都会改价。商队是市集之上的中长环。")
	tip.position = Vector2(40, 540)
	add_child(tip)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.position = Vector2(40, 600)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)

func _price_text() -> String:
	var bp = GameState.market_buy_prices()
	var sp = GameState.market_sell_prices()
	return "买：粮%d / 铁%d / 药%d　　卖：粮%d / 铁%d / 药%d　·　市集 Lv%d%s" % [
		bp.food, bp.iron, bp.herb, sp.food, sp.iron, sp.herb, GameState.building_level("market"),
		"（商路）" if bool(GameState.house_mods.get("trade_route", false)) else ""
	]

func _caravan_status() -> String:
	if int(GameState.caravan.get("turns_left", 0)) > 0:
		var k = str(GameState.caravan.get("kind", ""))
		var cn = {"grain": "粮运", "iron": "铁运", "spice": "香料"}.get(k, k)
		return "在途：%s　余 %d 月　投资 %d 银" % [cn, int(GameState.caravan.turns_left), int(GameState.caravan.get("invested", 0))]
	return "暂无商队在途——选一条航线投资上路。"

func _refresh_prices() -> void:
	_prices.text = _price_text()
	var st = get_node_or_null("CaravanStatus")
	if st:
		st.text = _caravan_status()
