extends Control
var _msg: Label
func _ready() -> void:
	UIKit.make_themed_bg(self, "market")
	if ResourceLoader.exists("res://assets/art/ui/hub_banner_strip.png"):
		var strip := TextureRect.new()
		strip.texture = load("res://assets/art/ui/hub_banner_strip.png")
		strip.position = Vector2(0, 0)
		strip.custom_minimum_size = Vector2(1280, 48)
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)

	var t = UIKit.make_label("陆桥商路（堡内市）", true); t.position = Vector2(40, 16); add_child(t)
	var bp = GameState.market_buy_prices()
	var sp = GameState.market_sell_prices()
	var prices = UIKit.make_dim_label("买：粮%d / 铁%d / 药%d　　卖：粮%d / 铁%d / 药%d　·　市集 Lv%d%s" % [
		bp.food, bp.iron, bp.herb, sp.food, sp.iron, sp.herb, GameState.building_level("market"),
		"（商路）" if bool(GameState.house_mods.get("trade_route", false)) else ""
	])
	prices.position = Vector2(40, 56); add_child(prices)
	var grid := GridContainer.new(); grid.columns = 2; grid.position = Vector2(40, 110)
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 10); add_child(grid)
	for item in ["food", "iron", "herb"]:
		var buy = UIKit.make_accent_button("买" + Locale.t(item), 160)
		var it = item
		buy.pressed.connect(func():
			var r = GameState.market_buy(it)
			_msg.text = str(r.get("msg"))
		)
		grid.add_child(buy)
		var sell = UIKit.make_button("卖" + Locale.t(item), 160)
		sell.pressed.connect(func():
			var r = GameState.market_sell(it)
			_msg.text = str(r.get("msg"))
		)
		grid.add_child(sell)
	_msg = UIKit.make_label(""); _msg.position = Vector2(40, 300); add_child(_msg)
	var tip = UIKit.make_dim_label("工事升市集、委任守桥首通、联姻商契都会改价。")
	tip.position = Vector2(40, 340); add_child(tip)
	var back = UIKit.make_button(Locale.t("btn_back")); back.position = Vector2(40, 400)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")); add_child(back)
