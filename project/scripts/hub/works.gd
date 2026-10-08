extends Control
## 城堡工事：厅堂/校场/市集/工坊/祠堂升级 —— 经营闭环核心

var _msg: Label
var _list: VBoxContainer

func _ready() -> void:
	UIKit.make_themed_bg(self, "works")
	UIFX.page_enter(self)
	UIFX.fade_in(self, 0.28)
	Music.play_castle()
	if not UIKit.RETIRE_CHROME and ResourceLoader.exists("res://assets/art/ui/works_banner.png"):
		var wb := TextureRect.new()
		wb.texture = load("res://assets/art/ui/works_banner.png")
		wb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wb.stretch_mode = TextureRect.STRETCH_SCALE
		wb.position = Vector2(0, 0)
		wb.size = Vector2(1280, 52)
		wb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(wb)
		UIFX.banner_shimmer(wb, 3.8)
	elif not UIKit.RETIRE_CHROME and ResourceLoader.exists("res://assets/art/ui/hub_banner_strip.png"):
		var strip := TextureRect.new()
		strip.texture = load("res://assets/art/ui/hub_banner_strip.png")
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.position = Vector2(0, 0)
		strip.size = Vector2(1280, 48)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)
	var t = UIKit.make_label("城堡工事", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var tip = UIKit.make_dim_label("工事至 Lv5；属地庄园可委任庄头抗劫掠。堡志：战勋十次、两岸/四野/深耕、庄头遍野、家训周岁、精锻、库银、六旗等。")
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
	scroll.custom_minimum_size = Vector2(1200, 320)
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_rebuild()
	UIFX.stagger_children(_list, 0.04, 0.24)
	UIFX.wire_tree(self)

	if ResourceLoader.exists("res://assets/art/ui/ambition_strip.png"):
		var astr := TextureRect.new()
		astr.texture = load("res://assets/art/ui/ambition_strip.png")
		astr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		astr.stretch_mode = TextureRect.STRETCH_SCALE
		astr.position = Vector2(40, 520)
		astr.size = Vector2(1200, 36)
		astr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(astr)
	if ResourceLoader.exists("res://assets/art/ui/month_chip_ambition.png"):
		var achip := TextureRect.new()
		achip.texture = load("res://assets/art/ui/month_chip_ambition.png")
		achip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		achip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		achip.position = Vector2(40, 556)
		achip.size = Vector2(28, 28)
		achip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(achip)
	var amb_title = UIKit.make_label("堡志（中长期）")
	amb_title.position = Vector2(76, 560)
	amb_title.add_theme_color_override("font_color", UIKit.ACCENT)
	add_child(amb_title)
	var amb_lines: Array = []
	for a in GameState.ambition_list():
		var mark = "✓" if a.get("done") else "·"
		amb_lines.append("%s %s — %s（奖：%s）" % [mark, a.name, a.desc, a.reward])
	var amb_lbl = UIKit.make_dim_label("\n".join(amb_lines))
	amb_lbl.position = Vector2(40, 588)
	amb_lbl.custom_minimum_size = Vector2(1200, 90)
	amb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	amb_lbl.name = "Ambitions"
	add_child(amb_lbl)

	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 680)
	add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.position = Vector2(40, 700)
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
		var al: Array = []
		for a in GameState.ambition_list():
			var mark = "✓" if a.get("done") else "·"
			al.append("%s %s — %s（奖：%s）" % [mark, a.name, a.desc, a.reward])
		if has_node("Ambitions"):
			get_node("Ambitions").text = "\n".join(al)
		_rebuild()
	else:
		Sfx.miss()
