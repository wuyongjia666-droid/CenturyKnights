extends Control
func _ready() -> void:
	UIKit.make_screen_bg(self)
	var cap = GameState.max_deploy()
	var t = UIKit.make_label("出战编队（最多%d人 · 厅堂 Lv%d）" % [cap, GameState.building_level("hall")], true); t.position = Vector2(40, 16); add_child(t)
	var tip = UIKit.make_dim_label("勾选出战者。棋盘上会以立绘棋子示人——不是色块。")
	tip.position = Vector2(40, 56); add_child(tip)
	var vb := VBoxContainer.new(); vb.position = Vector2(40, 100); vb.add_theme_constant_override("separation", 8); add_child(vb)
	for c in GameState.roster():
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); vb.add_child(row)
		row.add_child(UIKit.make_portrait_rect(c, 48))
		var on = c.id in GameState.deploy_ids
		var b = CheckButton.new(); b.text = "%s（%s）" % [c.name, GameState.get_job(c.job_id).get("name", "")]; b.button_pressed = on
		var cid = c.id
		b.toggled.connect(func(pressed):
			if pressed:
				if GameState.deploy_ids.size() >= GameState.max_deploy() and cid not in GameState.deploy_ids:
					b.button_pressed = false
					return
				if cid not in GameState.deploy_ids:
					GameState.deploy_ids.append(cid)
			else:
				GameState.deploy_ids.erase(cid)
		)
		row.add_child(b)
	var fight = UIKit.make_accent_button("练习战（清匪）", 200); fight.position = Vector2(40, 500)
	fight.pressed.connect(func():
		GameState.set_meta("battle_return", "res://scenes/hub/castle_hub.tscn")
		GameState.set_meta("battle_map", "quest_bandit")
		get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
	); add_child(fight)
	var back = UIKit.make_button(Locale.t("btn_back")); back.position = Vector2(40, 560)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")); add_child(back)
