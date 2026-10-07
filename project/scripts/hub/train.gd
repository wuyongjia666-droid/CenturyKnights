extends Control
var _msg: Label
func _ready() -> void:
	UIKit.make_screen_bg(self)
	var t = UIKit.make_label("演武场", true); t.position = Vector2(40, 16); add_child(t)
	var tip = UIKit.make_dim_label("耗 15 银 + 1 月：随机六维 +1，小概率领悟禀性。转职不锁前职，看属性与物资。")
	tip.position = Vector2(40, 56); add_child(tip)
	var vb := VBoxContainer.new(); vb.position = Vector2(40, 100); vb.add_theme_constant_override("separation", 8); add_child(vb)
	for c in GameState.roster():
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); vb.add_child(row)
		row.add_child(UIKit.make_portrait_rect(c, 48))
		var b = UIKit.make_button("训练 " + c.name, 260)
		var cid = c.id
		b.pressed.connect(func():
			var r = GameState.train(cid)
			_msg.text = str(r.get("msg"))
		)
		row.add_child(b)
	var promo = UIKit.make_label("转职（属性+物资达标即可）"); promo.position = Vector2(520, 100)
	promo.add_theme_color_override("font_color", UIKit.ACCENT); add_child(promo)
	var pv := VBoxContainer.new(); pv.position = Vector2(520, 140); pv.add_theme_constant_override("separation", 8); add_child(pv)
	for jid in ["light_cavalry", "warrior", "archer", "priest"]:
		var job = GameState.get_job(jid)
		var b = UIKit.make_button("转职→%s" % job.get("name", jid), 260)
		b.pressed.connect(func():
			var leader = GameState.get_leader()
			if leader:
				var r = GameState.try_promote(leader.id, jid)
				_msg.text = str(r.get("msg"))
		)
		pv.add_child(b)
	_msg = UIKit.make_label(""); _msg.position = Vector2(40, 520); add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back")); back.position = Vector2(40, 600)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")); add_child(back)
