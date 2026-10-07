extends Control
func _ready() -> void:
	var bg := ColorRect.new(); bg.color = UIKit.BG; bg.set_anchors_preset(PRESET_FULL_RECT); add_child(bg)
	var t = UIKit.make_label("出战编队（最多4人）", true); t.position = Vector2(40, 20); add_child(t)
	var vb := VBoxContainer.new(); vb.position = Vector2(40, 80); add_child(vb)
	for c in GameState.roster():
		var on = c.id in GameState.deploy_ids
		var b = CheckButton.new(); b.text = "%s（%s）" % [c.name, GameState.get_job(c.job_id).get("name", "")]; b.button_pressed = on
		var cid = c.id
		b.toggled.connect(func(pressed):
			if pressed:
				if GameState.deploy_ids.size() >= 4 and cid not in GameState.deploy_ids:
					b.button_pressed = false
					return
				if cid not in GameState.deploy_ids:
					GameState.deploy_ids.append(cid)
			else:
				GameState.deploy_ids.erase(cid)
		)
		vb.add_child(b)
	var fight = UIKit.make_button("练习战（清匪）", 200); fight.position = Vector2(40, 500)
	fight.pressed.connect(func():
		GameState.set_meta("battle_return", "res://scenes/hub/castle_hub.tscn")
		get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
	); add_child(fight)
	var back = UIKit.make_button(Locale.t("btn_back")); back.position = Vector2(40, 560)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")); add_child(back)
