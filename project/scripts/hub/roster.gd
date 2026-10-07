extends Control

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var t = UIKit.make_label("花名册", true)
	t.position = Vector2(40, 20)
	add_child(t)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 80)
	scroll.custom_minimum_size = Vector2(1200, 520)
	add_child(scroll)
	var vb := VBoxContainer.new()
	scroll.add_child(vb)
	for c in GameState.roster():
		var job = GameState.get_job(c.job_id)
		var injury = "〔伤〕" if c.injured else ""
		var l = UIKit.make_label("%s | %s | Lv%d | 月薪%d | HP%d/%d %s\n%s" % [
			c.name, job.get("name", ""), c.level, c.salary, c.hp, c.max_hp, injury,
			"力%d体%d技%d敏%d感%d意%d" % [c.stats["str"], c.stats["vit"], c.stats["skl"], c.stats["agi"], c.stats["per"], c.stats["wil"]]
		])
		vb.add_child(l)
	var back = UIKit.make_button(Locale.t("btn_back"))
	back.position = Vector2(40, 640)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)
