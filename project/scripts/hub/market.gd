extends Control
var _msg: Label
func _ready() -> void:
	var bg := ColorRect.new(); bg.color = UIKit.BG; bg.set_anchors_preset(PRESET_FULL_RECT); add_child(bg)
	var t = UIKit.make_label("陆桥商路（堡内市）", true); t.position = Vector2(40, 20); add_child(t)
	var prices = UIKit.make_label("买价：粮2 / 铁8 / 药6　　卖价：粮1 / 铁5 / 药4"); prices.position = Vector2(40, 70); add_child(prices)
	var grid := GridContainer.new(); grid.columns = 2; grid.position = Vector2(40, 120)
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 8); add_child(grid)
	for item in ["food", "iron", "herb"]:
		var buy = UIKit.make_button("买" + Locale.t(item), 160)
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
	_msg = UIKit.make_label(""); _msg.position = Vector2(40, 320); add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back")); back.position = Vector2(40, 400)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")); add_child(back)
