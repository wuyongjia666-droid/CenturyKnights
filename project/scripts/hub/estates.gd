extends Control
## 属地庄园：单堡多属地经营（委任首通解锁，可升级加深月结）

var _msg: Label
var _list: VBoxContainer

func _ready() -> void:
	UIKit.make_screen_bg(self)
	UIFX.fade_in(self, 0.28)
	Music.play_castle()
	var t = UIKit.make_label("属地庄园", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var tip = UIKit.make_dim_label("陆桥四野：苇原渡、石垒坡、雾谷药田、断潮渡哨。完成对应委任首通即开垦；升级加深月结粮银。堡志「两岸/四野/深耕」与此挂钩。")
	tip.position = Vector2(40, 56)
	tip.custom_minimum_size = Vector2(1180, 40)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tip)

	var sum = UIKit.make_label("已开垦 %d / 4　总等级 %d" % [GameState.unlocked_holdings_count(), GameState.total_holding_levels()])
	sum.position = Vector2(40, 100)
	sum.add_theme_color_override("font_color", UIKit.ACCENT)
	sum.name = "Sum"
	add_child(sum)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 140)
	scroll.custom_minimum_size = Vector2(1200, 460)
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_rebuild()

	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 620)
	add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.position = Vector2(40, 660)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)
	var works = UIKit.make_button("去工事/堡志", 140)
	works.position = Vector2(180, 660)
	works.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/works.tscn"))
	add_child(works)

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	for hid in GameState.HOLDING_DEFS.keys():
		var def: Dictionary = GameState.HOLDING_DEFS[hid]
		var unlocked = GameState.holding_unlocked(hid)
		var lv = GameState.holding_level(hid)
		var card = UIKit.make_panel()
		card.custom_minimum_size = Vector2(1160, 0)
		_list.add_child(card)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		card.add_child(hb)
		var vb := VBoxContainer.new()
		vb.custom_minimum_size = Vector2(880, 0)
		hb.add_child(vb)
		var title = UIKit.make_label("%s　%s" % [def.name, ("Lv%d / 3" % lv) if unlocked else "未开垦"])
		title.add_theme_color_override("font_color", UIKit.ACCENT if unlocked else UIKit.DIM)
		vb.add_child(title)
		vb.add_child(UIKit.make_dim_label(str(def.desc)))
		var y = "月结：粮+%d 银+%d" % [int(def.get("food", 0)) * maxi(lv, 1), int(def.get("silver", 0)) * maxi(lv, 1)]
		if def.get("herb"):
			y += " 药+%d" % (int(def.herb) * maxi(lv, 1))
		if def.get("rep"):
			y += " 声望"
		if not unlocked:
			y = "完成委任「%s」首通后开垦" % str(def.get("quest", ""))
		vb.add_child(UIKit.make_dim_label(y))
		if unlocked and lv < 3:
			vb.add_child(UIKit.make_dim_label("升级需：%d银 / %d粮" % [40 * lv, 8 * lv]))
		var bid = hid
		if unlocked and lv < 3:
			var b = UIKit.make_accent_button("升级属地", 140)
			b.pressed.connect(func(): _upgrade(bid))
			hb.add_child(b)
		elif unlocked:
			var b2 = UIKit.make_button("满级", 100)
			b2.disabled = true
			hb.add_child(b2)
		else:
			var b3 = UIKit.make_button("未开垦", 100)
			b3.disabled = true
			hb.add_child(b3)

func _upgrade(hid: String) -> void:
	var r = GameState.upgrade_holding(hid)
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		Sfx.confirm()
		GameState.save_game()
		get_node("Sum").text = "已开垦 %d / 4　总等级 %d" % [GameState.unlocked_holdings_count(), GameState.total_holding_levels()]
		_rebuild()
	else:
		Sfx.miss()
