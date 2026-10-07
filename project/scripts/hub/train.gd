extends Control
var _msg: Label
func _ready() -> void:
	var bg := ColorRect.new(); bg.color = UIKit.BG; bg.set_anchors_preset(PRESET_FULL_RECT); add_child(bg)
	var t = UIKit.make_label("演武场", true); t.position = Vector2(40, 20); add_child(t)
	var tip = UIKit.make_label("耗 15 银 + 1 月：随机六维 +1，小概率领悟禀性"); tip.position = Vector2(40, 70); add_child(tip)
	var vb := VBoxContainer.new(); vb.position = Vector2(40, 110); add_child(vb)
	for c in GameState.roster():
		var b = UIKit.make_button("训练 " + c.name, 300)
		var cid = c.id
		b.pressed.connect(func():
			var r = GameState.train(cid)
			_msg.text = str(r.get("msg"))
		)
		vb.add_child(b)
	# 转职入口
	var promo = UIKit.make_label("转职（属性+物资达标即可，不锁前职）"); promo.position = Vector2(500, 110); add_child(promo)
	var pv := VBoxContainer.new(); pv.position = Vector2(500, 150); add_child(pv)
	var jobs = ["light_cavalry", "warrior", "archer", "priest"]
	for jid in jobs:
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
