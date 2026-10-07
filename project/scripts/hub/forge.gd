extends Control
var _msg: Label
func _ready() -> void:
	var bg := ColorRect.new(); bg.color = UIKit.BG; bg.set_anchors_preset(PRESET_FULL_RECT); add_child(bg)
	var t = UIKit.make_label("炉火工坊", true); t.position = Vector2(40, 20); add_child(t)
	var tip = UIKit.make_label("打造灰刃：需 2 铁 + 20 银，装备后攻击 +2"); tip.position = Vector2(40, 70); add_child(tip)
	var vb := VBoxContainer.new(); vb.position = Vector2(40, 110); add_child(vb)
	for c in GameState.roster():
		var b = UIKit.make_button("为 %s 打造" % c.name, 300)
		var cid = c.id
		b.pressed.connect(func():
			var r = GameState.craft_weapon(cid)
			_msg.text = str(r.get("msg"))
		)
		vb.add_child(b)
	_msg = UIKit.make_label(""); _msg.position = Vector2(40, 520); add_child(_msg)
	var heir = UIKit.make_label(Locale.t("heirloom_preview")); heir.position = Vector2(40, 560)
	heir.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55)); add_child(heir)
	var back = UIKit.make_button(Locale.t("btn_back")); back.position = Vector2(40, 620)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")); add_child(back)
