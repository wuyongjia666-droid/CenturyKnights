extends Control
func _ready() -> void:
	var bg := ColorRect.new(); bg.color = UIKit.BG; bg.set_anchors_preset(PRESET_FULL_RECT); add_child(bg)
	var t = UIKit.make_label("祠堂", true); t.position = Vector2(40, 20); add_child(t)
	var tip = UIKit.make_label("一级祠堂：丰收月加产出；可一键清临时伤并回满生命。"); tip.position = Vector2(40, 80); add_child(tip)
	var msg = UIKit.make_label("当前等级：%d" % GameState.shrine_level); msg.position = Vector2(40, 120); add_child(msg)
	var heal = UIKit.make_button("祈愈（清临时伤）", 220); heal.position = Vector2(40, 180)
	heal.pressed.connect(func(): msg.text = GameState.heal_at_shrine()); add_child(heal)
	var back = UIKit.make_button(Locale.t("btn_back")); back.position = Vector2(40, 280)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")); add_child(back)
