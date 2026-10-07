extends Control

var _msg: Label

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var t = UIKit.make_label("委任榜", true)
	t.position = Vector2(40, 20)
	add_child(t)
	var vb := VBoxContainer.new()
	vb.position = Vector2(40, 80)
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	for q in GameState.quests:
		var stars = "★".repeat(int(q.stars))
		var battle_tag = "〔战棋〕" if q.get("battle") else "〔自动〕"
		var b = UIKit.make_button("%s %s %s  奖%d银 / 声望+%d / 耗%d月" % [q.name, stars, battle_tag, q.silver, q.rep, q.months], 900)
		var qid = q.id
		b.pressed.connect(func(): _accept(qid))
		vb.add_child(b)
		var d = UIKit.make_label(str(q.desc))
		vb.add_child(d)
	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 520)
	add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back"))
	back.position = Vector2(40, 600)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)

func _accept(qid: String) -> void:
	var r = GameState.accept_quest(qid)
	if r.get("battle"):
		GameState.set_meta("battle_return", "res://scenes/hub/quests.tscn")
		GameState.set_meta("battle_map", "quest_bandit")
		# reward on win handled simply: set flag via battle - for quest battle reuse ch0 map
		get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
	else:
		_msg.text = "完成：%s" % r.quest.name
		GameState.save_game()
