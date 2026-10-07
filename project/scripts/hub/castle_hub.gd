extends Control

var _res_bar: HBoxContainer
var _hint: Label
var _story_hint: Label

func _ready() -> void:
	if not GameState.flag("hub_open"):
		GameState.set_flag("hub_open")
	_build()
	UIFX.fade_in(self, 0.35)
	Music.play_hub()
	GameState.state_changed.connect(_refresh)

func _build() -> void:
	for c in get_children():
		c.queue_free()
	UIKit.make_screen_bg(self)

	var banner = UIKit.make_banner_rect(64, 92)
	banner.position = Vector2(36, 16)
	add_child(banner)

	var title = UIKit.make_label(Locale.t("hub_title"), true)
	title.position = Vector2(120, 18)
	add_child(title)

	var sub = UIKit.make_dim_label("%s旗 · 纹章已升 · 「%s」仍在风里" % [GameState.surname, GameState.surname])
	sub.position = Vector2(120, 56)
	add_child(sub)

	_res_bar = UIKit.resource_bar()
	_res_bar.position = Vector2(40, 88)
	add_child(_res_bar)
	UIKit.update_resources(_res_bar)

	_story_hint = UIKit.make_label("")
	_story_hint.position = Vector2(40, 118)
	_story_hint.add_theme_color_override("font_color", UIKit.ACCENT)
	add_child(_story_hint)
	_update_story_hint()

	# 领袖卡
	var leader = GameState.get_leader()
	if leader:
		var lp = UIKit.make_panel()
		lp.position = Vector2(980, 88)
		lp.custom_minimum_size = Vector2(260, 140)
		add_child(lp)
		var lhb := HBoxContainer.new()
		lhb.add_theme_constant_override("separation", 8)
		lp.add_child(lhb)
		lhb.add_child(UIKit.make_portrait_rect(leader, 72))
		var lv := VBoxContainer.new()
		lhb.add_child(lv)
		lv.add_child(UIKit.make_label(leader.name))
		lv.add_child(UIKit.make_dim_label("%s · %d岁" % [GameState.get_job(leader.job_id).get("name", ""), leader.age]))
		lv.add_child(UIKit.make_dim_label(leader.rank_name()))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(40, 160)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)

	var buttons = [
		[Locale.t("btn_roster"), "名册与立绘", "res://scenes/hub/roster.tscn"],
		[Locale.t("btn_tavern"), "招募新刃", "res://scenes/hub/tavern.tscn"],
		[Locale.t("btn_quests"), "陆桥委托", "res://scenes/hub/quests.tscn"],
		[Locale.t("btn_train"), "六维与转职", "res://scenes/hub/train.tscn"],
		[Locale.t("btn_forge"), "灰刃与铁火", "res://scenes/hub/forge.tscn"],
		[Locale.t("btn_shrine"), "祈愈与丰收", "res://scenes/hub/shrine.tscn"],
		[Locale.t("btn_lineage"), "血胤与容貌", "res://scenes/hub/lineage_view.tscn"],
		[Locale.t("btn_marriage"), "春令与期望", "res://scenes/hub/marriage.tscn"],
		[Locale.t("btn_hourglass"), "预告与推进", "res://scenes/hub/hourglass.tscn"],
		[Locale.t("btn_market"), "粮铁药材", "res://scenes/hub/market.tscn"],
		[Locale.t("btn_deploy"), "最多四人", "res://scenes/hub/deploy.tscn"],
		["战技树", "冷却与二阶", "res://scenes/hub/skill_tree.tscn"],
		["设置", "规则与速度", "res://scenes/ui/settings.tscn"],
	]
	for item in buttons:
		var b = UIKit.make_hub_nav_button(item[0], item[1], 210)
		var path = item[2]
		b.pressed.connect(func(): get_tree().change_scene_to_file(path))
		grid.add_child(b)

	var flavor = UIKit.make_panel()
	flavor.position = Vector2(40, 520)
	flavor.custom_minimum_size = Vector2(900, 70)
	add_child(flavor)
	var fl = UIKit.make_dim_label("大厅风里有铁锈与灯油味。传家宝槽仍封着——完整版才会醒。眼下，旗下每一扇门都是命。")
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fl.custom_minimum_size = Vector2(860, 50)
	flavor.add_child(fl)

	_hint = UIKit.make_label("")
	_hint.position = Vector2(40, 600)
	_hint.custom_minimum_size = Vector2(1000, 40)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)

	var row := HBoxContainer.new()
	row.position = Vector2(40, 650)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var save_b = UIKit.make_button("存档", 100)
	save_b.pressed.connect(func():
		GameState.save_game()
		_hint.text = Locale.t("save_ok")
	)
	row.add_child(save_b)
	var ch_b = UIKit.make_accent_button("第零章节拍", 160)
	ch_b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn"))
	row.add_child(ch_b)
	var ch1_b = UIKit.make_accent_button("第一章·陆桥", 160)
	ch1_b.disabled = not GameState.flag("chapter0_done")
	ch1_b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/story/chapter1.tscn"))
	row.add_child(ch1_b)
	var ch2_b = UIKit.make_accent_button("第二章·姓氏", 160)
	ch2_b.disabled = not GameState.flag("chapter1_done")
	ch2_b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/story/chapter2.tscn"))
	row.add_child(ch2_b)
	var ch3_b = UIKit.make_accent_button("第三章·铁祷", 160)
	ch3_b.disabled = not GameState.flag("chapter2_done")
	ch3_b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/story/chapter3.tscn"))
	row.add_child(ch3_b)
	var ch4_b = UIKit.make_accent_button("第四章·百年", 160)
	ch4_b.disabled = not GameState.flag("chapter3_done")
	ch4_b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/story/chapter4.tscn"))
	row.add_child(ch4_b)
	var ch5_b = UIKit.make_accent_button("第五章·烽烟", 160)
	ch5_b.disabled = not GameState.flag("chapter4_done")
	ch5_b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/story/chapter5.tscn"))
	row.add_child(ch5_b)
	var ch6_b = UIKit.make_accent_button("第六章·托孤", 160)
	ch6_b.disabled = not GameState.flag("chapter5_done")
	ch6_b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/story/chapter6.tscn"))
	row.add_child(ch6_b)
	var ch7_b = UIKit.make_accent_button("第七章·子嗣", 160)
	ch7_b.disabled = not GameState.flag("chapter6_done")
	ch7_b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/story/chapter7.tscn"))
	row.add_child(ch7_b)
	var menu_b = UIKit.make_button("主菜单", 100)
	menu_b.pressed.connect(func():
		GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	row.add_child(menu_b)

func _refresh() -> void:
	UIKit.update_resources(_res_bar)
	_update_story_hint()

func _update_story_hint() -> void:
	if not GameState.flag("chapter0_done"):
		_story_hint.text = "第零章进行中：节拍 %s —— 点「第零章节拍」继续剧情" % GameState.chapter0_beat
	elif not GameState.flag("chapter1_done"):
		_story_hint.text = "第零章已完成。可点「第一章·陆桥」推进新地图战役；亦可自由经营。"
	elif not GameState.flag("chapter2_done"):
		_story_hint.text = "第一章已完成。可点「第二章·姓氏」继续主线。"
	elif not GameState.flag("chapter3_done"):
		_story_hint.text = "可点「第三章·铁祷」学习战技与转职深造。"
	elif not GameState.flag("chapter4_done"):
		_story_hint.text = "可点「第四章·百年」挑战断字关。"
	elif not GameState.flag("chapter5_done"):
		_story_hint.text = "可点「第五章·烽烟」开启王朝级战役；先升战技树二阶。"
	elif not GameState.flag("chapter6_done"):
		_story_hint.text = "可点「第六章·托孤」签署托孤之约。"
	elif not GameState.flag("chapter7_done"):
		_story_hint.text = "可点「第七章·子嗣」打响正名战。"
	else:
		_story_hint.text = "主线暂缓。自由经营、战技树、联姻传代皆可。"

func panel_button_labels() -> Array:
	var out: Array = []
	for c in get_children():
		if c is GridContainer:
			for b in c.get_children():
				if b is BaseButton:
					# hub buttons now have subtitle newlines — take first line
					var txt = str(b.text).split("\n")[0]
					out.append(txt)
	return out
