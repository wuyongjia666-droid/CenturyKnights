extends Control
## 城堡工事：厅堂/校场/市集/工坊/祠堂升级 —— 经营闭环核心

var _msg: Label
var _list: VBoxContainer

func _ready() -> void:
	UIKit.make_screen_bg(self)
	UIFX.fade_in(self, 0.28)
	var t = UIKit.make_label("城堡工事", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var tip = UIKit.make_dim_label("银与铁换石阶。厅堂扩编队，校场减演武费，市集改价，工坊省料，祠堂加丰收。委任首通会留下永久旁注。")
	tip.position = Vector2(40, 56)
	tip.custom_minimum_size = Vector2(1100, 40)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tip)

	var summary = UIKit.make_label(GameState.building_summary())
	summary.position = Vector2(40, 100)
	summary.add_theme_color_override("font_color", UIKit.ACCENT)
	summary.name = "Summary"
	add_child(summary)

	var mods = UIKit.make_dim_label(_house_mod_text())
	mods.position = Vector2(40, 128)
	mods.custom_minimum_size = Vector2(1100, 40)
	mods.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mods.name = "Mods"
	add_child(mods)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 180)
	scroll.custom_minimum_size = Vector2(1200, 380)
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_rebuild()

	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 580)
	add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.position = Vector2(40, 640)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)

func _house_mod_text() -> String:
	var parts: Array = []
	if bool(GameState.house_mods.get("hall_discount", false)):
		parts.append("厅堂折扣")
	if bool(GameState.house_mods.get("trade_route", false)):
		parts.append("河卫商路")
	if bool(GameState.house_mods.get("drill_discount", false)):
		parts.append("校场减价")
	if bool(GameState.house_mods.get("vow_banner", false)):
		parts.append("旗饰遗产")
	if bool(GameState.house_mods.get("vow_prayer", false)):
		parts.append("祷文遗产")
	if bool(GameState.house_mods.get("vow_trade", false)):
		parts.append("商契遗产")
	if int(GameState.house_mods.get("war_memory", 0)) > 0:
		parts.append("战勋×%d" % int(GameState.house_mods.war_memory))
	if parts.is_empty():
		return "家族旁注：尚无永久修正——完成委任首通或联姻誓约会写入。"
	return "家族旁注：" + " · ".join(parts)

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var descs := {
		"hall": "扩编队上限（现 %d 人）。Lv2→5人，Lv3→6人。" % GameState.max_deploy(),
		"barracks": "演武花费现 %d 银；Lv2+ 月结士气，Lv3 有概率双加。" % GameState.train_cost(),
		"market": "买价更低、卖价更高。商路旁注可再叠加。",
		"forge": "打造更省铁银；Lv3 产出精灰刃（+3攻）。",
		"shrine": "丰收粮产与祈愈强度随等级上升。",
	}
	for id in ["hall", "barracks", "market", "forge", "shrine"]:
		var lv = GameState.building_level(id)
		var card = UIKit.make_panel()
		card.custom_minimum_size = Vector2(1160, 0)
		_list.add_child(card)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		card.add_child(hb)
		var vb := VBoxContainer.new()
		vb.custom_minimum_size = Vector2(900, 0)
		hb.add_child(vb)
		var title = UIKit.make_label("%s　Lv%d / %d" % [GameState.BUILDING_NAMES[id], lv, GameState.BUILDING_MAX])
		title.add_theme_color_override("font_color", UIKit.ACCENT)
		vb.add_child(title)
		vb.add_child(UIKit.make_dim_label(str(descs.get(id, ""))))
		if lv < GameState.BUILDING_MAX:
			var cost: Dictionary = GameState.BUILDING_COST.get(lv + 1, {})
			var need_s = int(cost.get("silver", 0))
			if bool(GameState.house_mods.get("hall_discount", false)) and id == "hall":
				need_s = int(need_s * 0.75)
			vb.add_child(UIKit.make_dim_label("升级需：%d 银 · %d 铁 · %d 粮" % [need_s, int(cost.get("iron", 0)), int(cost.get("food", 0))]))
		var bid = id
		var b = UIKit.make_accent_button("升级" if lv < GameState.BUILDING_MAX else "满级", 120)
		b.disabled = lv >= GameState.BUILDING_MAX
		b.pressed.connect(func(): _upgrade(bid))
		hb.add_child(b)

func _upgrade(id: String) -> void:
	var r = GameState.upgrade_building(id)
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		Sfx.confirm()
		GameState.save_game()
		get_node("Summary").text = GameState.building_summary()
		get_node("Mods").text = _house_mod_text()
		_rebuild()
	else:
		Sfx.miss()
