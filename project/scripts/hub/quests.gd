extends Control

var _msg: Label

func _ready() -> void:
	UIKit.make_themed_bg(self, "quests")
	if ResourceLoader.exists("res://assets/art/ui/quests_banner.png"):
		var _bn := TextureRect.new()
		_bn.texture = load("res://assets/art/ui/quests_banner.png")
		_bn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bn.stretch_mode = TextureRect.STRETCH_SCALE
		_bn.position = Vector2(0, 0)
		_bn.size = Vector2(1280, 52)
		_bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bn)
		UIFX.banner_shimmer(_bn, 3.8)
	UIFX.page_enter(self)
	UIFX.wire_tree(self)
	if ResourceLoader.exists("res://assets/art/ui/hub_banner_strip.png"):
		var strip := TextureRect.new()
		strip.texture = load("res://assets/art/ui/hub_banner_strip.png")
		strip.position = Vector2(0, 0)
		strip.custom_minimum_size = Vector2(1280, 48)
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)

	var t = UIKit.make_label("委任榜", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var tip = UIKit.make_dim_label("陆桥的委托写在木板上：有的要刀，有的只要旗在风里亮一夜。")
	tip.position = Vector2(40, 56)
	add_child(tip)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 90)
	scroll.custom_minimum_size = Vector2(1200, 480)
	add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	scroll.add_child(vb)

	for q in GameState.quests:
		var card = UIKit.make_panel()
		card.custom_minimum_size = Vector2(1160, 0)
		vb.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)
		var stars = "★".repeat(int(q.stars))
		var battle_tag = "〔战棋〕" if q.get("battle") else "〔自动〕"
		var first_tag = "〔已首通〕" if bool(GameState.quest_done.get(q.id, false)) else "〔首通有奖〕"
		var title = UIKit.make_label("%s　%s　%s　%s" % [q.name, stars, battle_tag, first_tag])
		title.add_theme_color_override("font_color", UIKit.ACCENT if q.get("battle") else UIKit.TEXT)
		cv.add_child(title)
		cv.add_child(UIKit.make_dim_label(str(q.desc)))
		cv.add_child(UIKit.make_dim_label("奖励 %d 银 · 声望 +%d · 耗时 %d 月" % [q.silver, q.rep, q.months]))
		var b = UIKit.make_accent_button("接受委任", 160)
		var qid = q.id
		b.pressed.connect(func(): _accept(qid))
		cv.add_child(b)

	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 590)
	add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back"))
	back.position = Vector2(40, 640)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)

func _accept(qid: String) -> void:
	var r = GameState.accept_quest(qid)
	if r.get("battle"):
		GameState.set_meta("battle_return", "res://scenes/hub/quests.tscn")
		var mid = str(r.quest.get("map", GameState.get_meta("battle_map", "quest_bandit")))
		GameState.set_meta("battle_map", mid)
		get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
	else:
		var extra = str(r.get("first_clear", ""))
		_msg.text = "完成：%s —— %s%s" % [r.quest.name, str(r.quest.get("desc", "")), ("\n" + extra) if extra else ""]
		GameState.save_game()
