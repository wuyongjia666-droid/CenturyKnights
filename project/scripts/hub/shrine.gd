extends Control
func _ready() -> void:
	UIKit.make_screen_bg(self)
	var t = UIKit.make_label("祠堂", true); t.position = Vector2(40, 16); add_child(t)
	var tip = UIKit.make_dim_label("一级祠堂：丰收月加产出；可一键清临时伤并回满生命。香灰里有旧旗的味。")
	tip.position = Vector2(40, 56); add_child(tip)
	var msg = UIKit.make_label("当前等级：%d" % GameState.shrine_level); msg.position = Vector2(40, 110); add_child(msg)
	var heal = UIKit.make_accent_button("祈愈（清临时伤）", 220); heal.position = Vector2(40, 170)
	heal.pressed.connect(func(): msg.text = GameState.heal_at_shrine()); add_child(heal)
	var back = UIKit.make_button(Locale.t("btn_back")); back.position = Vector2(40, 260)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")); add_child(back)
