extends Control
var _chapter_pick: OptionButton
var _vol_pick: OptionButton
var _chapter_paths: Array = []
var _selected_vol: int = 0

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
		["授旗礼", "子嗣三步入队", "res://scenes/hub/lineage_rite.tscn"],
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
	var cont_b = UIKit.make_accent_button("继续主线", 140)
	cont_b.pressed.connect(_continue_mainline)
	row.add_child(cont_b)
	_vol_pick = OptionButton.new()
	_vol_pick.custom_minimum_size = Vector2(120, 36)
	_vol_pick.add_theme_font_size_override("font_size", 15)
	row.add_child(_vol_pick)
	_chapter_pick = OptionButton.new()
	_chapter_pick.custom_minimum_size = Vector2(240, 36)
	_chapter_pick.add_theme_font_size_override("font_size", 15)
	row.add_child(_chapter_pick)
	_rebuild_volume_picker()
	_rebuild_chapter_picker()
	_vol_pick.item_selected.connect(_on_volume_picked)
	_chapter_pick.item_selected.connect(_on_chapter_picked)
	var go_b = UIKit.make_accent_button("前往选中章", 140)
	go_b.pressed.connect(func():
		var i = _chapter_pick.selected
		if i >= 0 and i < _chapter_paths.size():
			get_tree().change_scene_to_file(str(_chapter_paths[i]))
	)
	row.add_child(go_b)
	var menu_b = UIKit.make_button("主菜单", 100)
	menu_b.pressed.connect(func():
		GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	row.add_child(menu_b)


func _refresh() -> void:
	UIKit.update_resources(_res_bar)
	_rebuild_volume_picker()
	_rebuild_chapter_picker()
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
	elif not GameState.flag("chapter8_done"):
		_story_hint.text = "可点「第八章·港灯」签署海商盟约。"
	elif not GameState.flag("chapter9_done"):
		_story_hint.text = "可点「第九章·商路」夺回辎重。"
	elif not GameState.flag("chapter10_done"):
		_story_hint.text = "可点「第十章·回响」赴盟主宴。"
	elif not GameState.flag("chapter11_done"):
		_story_hint.text = "可点「第十一章·门阙」验旗。"
	elif not GameState.flag("chapter12_done"):
		_story_hint.text = "可点「第十二章·余波」应对朔影家夜袭。"
	elif not GameState.flag("chapter13_done"):
		_story_hint.text = "可点「第十三章·嗣位」完成对决。"
	elif not GameState.flag("chapter14_done"):
		_story_hint.text = "可点「第十四章·并席」共持火把。"
	elif not GameState.flag("chapter15_done"):
		_story_hint.text = "可点「第十五章·席散」完成第一卷终章。"
	elif not GameState.flag("chapter16_done"):
		_story_hint.text = "第二卷开启：可点「第十六章·海草」。"
	elif not GameState.flag("chapter17_done"):
		_story_hint.text = "可点「第十七章·盐河」重开盐路。"
	elif not GameState.flag("chapter18_done"):
		_story_hint.text = "可点「第十八章·门阙」写入二卷可入。"
	elif not GameState.flag("chapter19_done"):
		_story_hint.text = "第二卷后半：可点「第十九章·远岸」。"
	elif not GameState.flag("chapter20_done"):
		_story_hint.text = "可点「第二十章·潮墙」落两印。"
	elif not GameState.flag("chapter21_done"):
		_story_hint.text = "可点「第二十一章·席终」完成第二卷。"
	elif not GameState.flag("chapter22_done"):
		_story_hint.text = "第三卷开启：可点「第二十二章·北风」。"
	elif not GameState.flag("chapter23_done"):
		_story_hint.text = "可点「第二十三章·霜桥」落霜印。"
	elif not GameState.flag("chapter24_done"):
		_story_hint.text = "可点「第二十四章·钤印」完成三卷中段。"
	elif not GameState.flag("chapter25_done"):
		_story_hint.text = "第三卷后半：可点「第二十五章·朔原」。"
	elif not GameState.flag("chapter26_done"):
		_story_hint.text = "可点「第二十六章·冠雪」落两印。"
	elif not GameState.flag("chapter27_done"):
		_story_hint.text = "可点「第二十七章·席终」完成第三卷。"
	elif not GameState.flag("chapter28_done"):
		_story_hint.text = "第四卷开启：点「继续主线」或章节下拉选第二十八章·南泽。"
	elif not GameState.flag("chapter29_done"):
		_story_hint.text = "可继续第二十九章·金陌（章节下拉）。"
	elif not GameState.flag("chapter30_done"):
		_story_hint.text = "可继续第三十章·钤印（四卷中段）。"
	elif not GameState.flag("chapter31_done"):
		_story_hint.text = "第四卷后半：第三十一章·铁峡。"
	elif not GameState.flag("chapter32_done"):
		_story_hint.text = "可继续第三十二章·星津。"
	elif not GameState.flag("chapter33_done"):
		_story_hint.text = "可点继续主线赴第三十三章·四卷席终。"
	elif not GameState.flag("chapter34_done"):
		_story_hint.text = "第五卷开启：点「继续主线」选第三十四章·破晓。"
	elif not GameState.flag("chapter35_done"):
		_story_hint.text = "可继续第三十五章·晚钟。"
	elif not GameState.flag("chapter36_done"):
		_story_hint.text = "可继续第三十六章·钤印（五卷中段）。"
	elif not GameState.flag("chapter37_done"):
		_story_hint.text = "第五卷后半：点「继续主线」选第三十七章·长川。"
	elif not GameState.flag("chapter38_done"):
		_story_hint.text = "可继续第三十八章·终阙。"
	elif not GameState.flag("chapter39_done"):
		_story_hint.text = "可继续第三十九章·五卷席终。"
	elif not GameState.flag("chapter40_done"):
		_story_hint.text = "第六卷开启：点「继续主线」选第四十章·雾原。"
	elif not GameState.flag("chapter41_done"):
		_story_hint.text = "可继续第四十一章·石冢。"
	elif not GameState.flag("chapter42_done"):
		_story_hint.text = "可继续第四十二章·钤印（六卷中段）。"
	elif not GameState.flag("chapter43_done"):
		_story_hint.text = "第六卷后半：点「继续主线」或卷六选第四十三章·黑潮。"
	elif not GameState.flag("chapter44_done"):
		_story_hint.text = "可继续第四十四章·曜塔。"
	elif not GameState.flag("chapter45_done"):
		_story_hint.text = "可继续第四十五章·六卷席终。"
	elif not GameState.flag("chapter46_done"):
		_story_hint.text = "第七卷开启：点「继续主线」或卷七选第四十六章·余烬。"
	elif not GameState.flag("chapter47_done"):
		_story_hint.text = "可继续第四十七章·冠火。"
	elif not GameState.flag("chapter48_done"):
		_story_hint.text = "可继续第四十八章·钤印（七卷中段）。"
	elif not GameState.flag("chapter49_done"):
		_story_hint.text = "第七卷后半：点「继续主线」或卷七选第四十九章·烬原。"
	elif not GameState.flag("chapter50_done"):
		_story_hint.text = "可继续第五十章·百旗。"
	elif not GameState.flag("chapter51_done"):
		_story_hint.text = "可继续第五十一章·七卷席终。"
	elif not GameState.flag("chapter52_done"):
		_story_hint.text = "第八卷开启：点「继续主线」或卷八选第五十二章·破晓。"
	elif not GameState.flag("chapter53_done"):
		_story_hint.text = "可继续第五十三章·镜湖。"
	elif not GameState.flag("chapter54_done"):
		_story_hint.text = "可继续第五十四章·钤印（八卷中段）。"
	elif not GameState.flag("chapter55_done"):
		_story_hint.text = "第八卷后半：点「继续主线」或卷八选第五十五章·朔风。"
	elif not GameState.flag("chapter56_done"):
		_story_hint.text = "可继续第五十六章·曜廷。"
	elif not GameState.flag("chapter57_done"):
		_story_hint.text = "可继续第五十七章·八卷席终。"
	elif not GameState.flag("chapter58_done"):
		_story_hint.text = "第九卷开启：点「继续主线」或卷九选第五十八章·余烬港。"
	elif not GameState.flag("chapter59_done"):
		_story_hint.text = "可继续第五十九章·霜驿。"
	elif not GameState.flag("chapter60_done"):
		_story_hint.text = "可继续第六十章·九卷钤印（九卷中段）。"
	elif not GameState.flag("chapter61_done"):
		_story_hint.text = "第九卷后半：点「继续主线」或卷九选第六十一章·烬原。"
	elif not GameState.flag("chapter62_done"):
		_story_hint.text = "可继续第六十二章·曜阙。"
	elif not GameState.flag("chapter63_done"):
		_story_hint.text = "可继续第六十三章·九卷席终。"
	elif not GameState.flag("chapter64_done"):
		_story_hint.text = "第十卷·井市：点「继续主线」或卷十选第六十四章·井市。"
	elif not GameState.flag("chapter65_done"):
		_story_hint.text = "可继续第六十五章·铜铃。"
	elif not GameState.flag("chapter66_done"):
		_story_hint.text = "可继续第六十六章·井印（十卷中段）。"
	elif not GameState.flag("chapter67_done"):
		_story_hint.text = "第十卷后半：点「继续主线」或卷十选第六十七章·盐船。"
	elif not GameState.flag("chapter68_done"):
		_story_hint.text = "可继续第六十八章·纸坊。"
	elif not GameState.flag("chapter69_done"):
		_story_hint.text = "可继续第六十九章·十卷席终。"
	elif not GameState.flag("chapter70_done"):
		_story_hint.text = "第十一卷·窑火：点「继续主线」或卷十一选第七十章·窑口。"
	elif not GameState.flag("chapter71_done"):
		_story_hint.text = "可继续第七十一章·釉河。"
	elif not GameState.flag("chapter72_done"):
		_story_hint.text = "可继续第七十二章·窑印（十一卷中段）。"
	elif not GameState.flag("chapter73_done"):
		_story_hint.text = "第十一卷后半：点「继续主线」或选第七十三章·烟囱。"
	elif not GameState.flag("chapter74_done"):
		_story_hint.text = "可继续第七十四章·火塘。"
	elif not GameState.flag("chapter75_done"):
		_story_hint.text = "可继续第七十五章·十一卷席终。"
	elif not GameState.flag("chapter76_done"):
		_story_hint.text = "第十二卷·梨园：点「继续主线」或卷十二选第七十六章·台口。"
	elif not GameState.flag("chapter77_done"):
		_story_hint.text = "可继续第七十七章·检场。"
	elif not GameState.flag("chapter78_done"):
		_story_hint.text = "可继续第七十八章·戏印（十二卷中段）。"
	elif not GameState.flag("chapter79_done"):
		_story_hint.text = "第十二卷后半：点「继续主线」或卷十二选第七十九章·后台。"
	elif not GameState.flag("chapter80_done"):
		_story_hint.text = "可继续第八十章·灯架。"
	elif not GameState.flag("chapter81_done"):
		_story_hint.text = "可继续第八十一章·十二卷席终。"
	elif not GameState.flag("chapter82_done"):
		_story_hint.text = "第十三卷·蚕桑：点「继续主线」或卷十三选第八十二章·桑陌。"
	elif not GameState.flag("chapter83_done"):
		_story_hint.text = "可继续第八十三章·缫丝。"
	elif not GameState.flag("chapter84_done"):
		_story_hint.text = "可继续第八十四章·丝印（十三卷中段）。"
	elif not GameState.flag("chapter85_done"):
		_story_hint.text = "第十三卷后半：点「继续主线」或卷十三选第八十五章·烘茧。"
	elif not GameState.flag("chapter86_done"):
		_story_hint.text = "可继续第八十六章·经轴。"
	elif not GameState.flag("chapter87_done"):
		_story_hint.text = "可继续第八十七章·十三卷席终。"
	elif not GameState.flag("chapter88_done"):
		_story_hint.text = "第十四卷·茶岭：点「继续主线」或卷十四选第八十八章·茶梯。"
	elif not GameState.flag("chapter89_done"):
		_story_hint.text = "可继续第八十九章·蒸青。"
	elif not GameState.flag("chapter90_done"):
		_story_hint.text = "可继续第九十章·茶印（十四卷中段）。"
	elif not GameState.flag("chapter91_done"):
		_story_hint.text = "第十四卷后半：点「继续主线」或卷十四选第九十一章·晾青。"
	elif not GameState.flag("chapter92_done"):
		_story_hint.text = "可继续第九十二章·茶引。"
	elif not GameState.flag("chapter93_done"):
		_story_hint.text = "可继续第九十三章·十四卷席终。"
	elif not GameState.flag("chapter94_done"):
		_story_hint.text = "第十五卷·药市：点「继续主线」或卷十五选第九十四章·药圃。"
	elif not GameState.flag("chapter95_done"):
		_story_hint.text = "可继续第九十五章·医馆。"
	elif not GameState.flag("chapter96_done"):
		_story_hint.text = "可继续第九十六章·方印（十五卷中段）。"
	elif GameState.flag("volume15_mid_done"):
		_story_hint.text = "十五卷中段已执。自由经营或等候后半。"
	elif GameState.flag("volume14_done"):
		_story_hint.text = "十四卷已执。可继续第十五卷或经营。"
	elif GameState.flag("volume14_mid_done"):
		_story_hint.text = "十四卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume13_done"):
		_story_hint.text = "十三卷已执。可继续第十四卷或经营。"
	elif GameState.flag("volume13_mid_done"):
		_story_hint.text = "十三卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume12_done"):
		_story_hint.text = "十二卷已执。可继续第十三卷或经营。"
	elif GameState.flag("volume12_mid_done"):
		_story_hint.text = "十二卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume11_done"):
		_story_hint.text = "十一卷已执。可继续第十二卷或经营。"
	elif GameState.flag("volume10_done"):
		_story_hint.text = "十卷已执。可继续第十一卷或经营。"
	elif GameState.flag("volume10_mid_done"):
		_story_hint.text = "十卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume9_done"):
		_story_hint.text = "九卷已执。可继续第十卷或经营。"
	elif GameState.flag("volume9_mid_done"):
		_story_hint.text = "九卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume8_done"):
		_story_hint.text = "八卷已执。可继续第九卷或经营。"
	elif GameState.flag("volume8_mid_done"):
		_story_hint.text = "八卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume7_done"):
		_story_hint.text = "七卷已执。可继续第八卷或经营。"
	elif GameState.flag("volume7_mid_done"):
		_story_hint.text = "七卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume6_done"):
		_story_hint.text = "六卷已执。可继续第七卷或经营。"
	elif GameState.flag("volume6_mid_done"):
		_story_hint.text = "六卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume5_done"):
		_story_hint.text = "五卷已执。可继续第六卷或经营。"
	elif GameState.flag("volume5_mid_done"):
		_story_hint.text = "五卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume4_done"):
		_story_hint.text = "四卷已执。可继续第五卷或经营。"
	elif GameState.flag("volume3_done"):
		_story_hint.text = "三卷已执。可继续第四卷或经营。"
	elif GameState.flag("volume3_mid_done"):
		_story_hint.text = "三卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume2_done"):
		_story_hint.text = "二卷已执。可继续第三卷或经营。"
	elif GameState.flag("volume2_mid_done"):
		_story_hint.text = "第二卷前半完成。可继续后半或经营。"
	elif GameState.flag("volume1_done"):
		_story_hint.text = "第一卷·已执百年。可继续第二卷或经营。"
	else:
		_story_hint.text = "主线暂缓。敌宅交涉、授旗分支、战技与传代皆可。"


func _chapter_catalog() -> Array:
	# [label, scene, unlock_flag, volume_index]
	return [
		["第零章", "res://scenes/story/chapter0.tscn", "", 0],
		["第一章·陆桥", "res://scenes/story/chapter1.tscn", "chapter0_done", 1],
		["第二章·姓氏", "res://scenes/story/chapter2.tscn", "chapter1_done", 1],
		["第三章·铁祷", "res://scenes/story/chapter3.tscn", "chapter2_done", 1],
		["第四章·百年", "res://scenes/story/chapter4.tscn", "chapter3_done", 1],
		["第五章·烽烟", "res://scenes/story/chapter5.tscn", "chapter4_done", 1],
		["第六章·托孤", "res://scenes/story/chapter6.tscn", "chapter5_done", 1],
		["第七章·子嗣", "res://scenes/story/chapter7.tscn", "chapter6_done", 1],
		["第八章·港灯", "res://scenes/story/chapter8.tscn", "chapter7_done", 1],
		["第九章·商路", "res://scenes/story/chapter9.tscn", "chapter8_done", 1],
		["第十章·回响", "res://scenes/story/chapter10.tscn", "chapter9_done", 1],
		["第十一章·门阙", "res://scenes/story/chapter11.tscn", "chapter10_done", 1],
		["第十二章·余波", "res://scenes/story/chapter12.tscn", "chapter11_done", 1],
		["第十三章·嗣位", "res://scenes/story/chapter13.tscn", "chapter12_done", 1],
		["第十四章·并席", "res://scenes/story/chapter14.tscn", "chapter13_done", 1],
		["第十五章·席散", "res://scenes/story/chapter15.tscn", "chapter14_done", 1],
		["第十六章·海草", "res://scenes/story/chapter16.tscn", "chapter15_done", 2],
		["第十七章·盐河", "res://scenes/story/chapter17.tscn", "chapter16_done", 2],
		["第十八章·门阙", "res://scenes/story/chapter18.tscn", "chapter17_done", 2],
		["第十九章·远岸", "res://scenes/story/chapter19.tscn", "chapter18_done", 2],
		["第二十章·潮墙", "res://scenes/story/chapter20.tscn", "chapter19_done", 2],
		["第二十一章·席终", "res://scenes/story/chapter21.tscn", "chapter20_done", 2],
		["第二十二章·北风", "res://scenes/story/chapter22.tscn", "chapter21_done", 3],
		["第二十三章·霜桥", "res://scenes/story/chapter23.tscn", "chapter22_done", 3],
		["第二十四章·钤印", "res://scenes/story/chapter24.tscn", "chapter23_done", 3],
		["第二十五章·朔原", "res://scenes/story/chapter25.tscn", "chapter24_done", 3],
		["第二十六章·冠雪", "res://scenes/story/chapter26.tscn", "chapter25_done", 3],
		["第二十七章·席终", "res://scenes/story/chapter27.tscn", "chapter26_done", 3],
		["第二十八章·南泽", "res://scenes/story/chapter28.tscn", "chapter27_done", 4],
		["第二十九章·金陌", "res://scenes/story/chapter29.tscn", "chapter28_done", 4],
		["第三十章·钤印", "res://scenes/story/chapter30.tscn", "chapter29_done", 4],
		["第三十一章·铁峡", "res://scenes/story/chapter31.tscn", "chapter30_done", 4],
		["第三十二章·星津", "res://scenes/story/chapter32.tscn", "chapter31_done", 4],
		["第三十三章·席终", "res://scenes/story/chapter33.tscn", "chapter32_done", 4],
		["第三十四章·破晓", "res://scenes/story/chapter34.tscn", "chapter33_done", 5],
		["第三十五章·晚钟", "res://scenes/story/chapter35.tscn", "chapter34_done", 5],
		["第三十六章·钤印", "res://scenes/story/chapter36.tscn", "chapter35_done", 5],
		["第三十七章·长川", "res://scenes/story/chapter37.tscn", "chapter36_done", 5],
		["第三十八章·终阙", "res://scenes/story/chapter38.tscn", "chapter37_done", 5],
		["第三十九章·席终", "res://scenes/story/chapter39.tscn", "chapter38_done", 5],
		["第四十章·雾原", "res://scenes/story/chapter40.tscn", "chapter39_done", 6],
		["第四十一章·石冢", "res://scenes/story/chapter41.tscn", "chapter40_done", 6],
		["第四十二章·钤印", "res://scenes/story/chapter42.tscn", "chapter41_done", 6],
		["第四十三章·黑潮", "res://scenes/story/chapter43.tscn", "chapter42_done", 6],
		["第四十四章·曜塔", "res://scenes/story/chapter44.tscn", "chapter43_done", 6],
		["第四十五章·席终", "res://scenes/story/chapter45.tscn", "chapter44_done", 6],
		["第四十六章·余烬", "res://scenes/story/chapter46.tscn", "chapter45_done", 7],
		["第四十七章·冠火", "res://scenes/story/chapter47.tscn", "chapter46_done", 7],
		["第四十八章·钤印", "res://scenes/story/chapter48.tscn", "chapter47_done", 7],
		["第四十九章·烬原", "res://scenes/story/chapter49.tscn", "chapter48_done", 7],
		["第五十章·百旗", "res://scenes/story/chapter50.tscn", "chapter49_done", 7],
		["第五十一章·席终", "res://scenes/story/chapter51.tscn", "chapter50_done", 7],
		["第五十二章·破晓", "res://scenes/story/chapter52.tscn", "chapter51_done", 8],
		["第五十三章·镜湖", "res://scenes/story/chapter53.tscn", "chapter52_done", 8],
		["第五十四章·钤印", "res://scenes/story/chapter54.tscn", "chapter53_done", 8],
		["第五十五章·朔风", "res://scenes/story/chapter55.tscn", "chapter54_done", 8],
		["第五十六章·曜廷", "res://scenes/story/chapter56.tscn", "chapter55_done", 8],
		["第五十七章·席终", "res://scenes/story/chapter57.tscn", "chapter56_done", 8],
		["第五十八章·余烬港", "res://scenes/story/chapter58.tscn", "chapter57_done", 9],
		["第五十九章·霜驿", "res://scenes/story/chapter59.tscn", "chapter58_done", 9],
		["第六十章·钤印", "res://scenes/story/chapter60.tscn", "chapter59_done", 9],
		["第六十一章·烬原", "res://scenes/story/chapter61.tscn", "chapter60_done", 9],
		["第六十二章·曜阙", "res://scenes/story/chapter62.tscn", "chapter61_done", 9],
		["第六十三章·席终", "res://scenes/story/chapter63.tscn", "chapter62_done", 9],
		["第六十四章·井市", "res://scenes/story/chapter64.tscn", "chapter63_done", 10],
		["第六十五章·铜铃", "res://scenes/story/chapter65.tscn", "chapter64_done", 10],
		["第六十六章·井印", "res://scenes/story/chapter66.tscn", "chapter65_done", 10],
		["第六十七章·盐船", "res://scenes/story/chapter67.tscn", "chapter66_done", 10],
		["第六十八章·纸坊", "res://scenes/story/chapter68.tscn", "chapter67_done", 10],
		["第六十九章·席终", "res://scenes/story/chapter69.tscn", "chapter68_done", 10],
		["第七十章·窑口", "res://scenes/story/chapter70.tscn", "chapter69_done", 11],
		["第七十一章·釉河", "res://scenes/story/chapter71.tscn", "chapter70_done", 11],
		["第七十二章·窑印", "res://scenes/story/chapter72.tscn", "chapter71_done", 11],
		["第七十三章·烟囱", "res://scenes/story/chapter73.tscn", "chapter72_done", 11],
		["第七十四章·火塘", "res://scenes/story/chapter74.tscn", "chapter73_done", 11],
		["第七十五章·席终", "res://scenes/story/chapter75.tscn", "chapter74_done", 11],
		["第七十六章·台口", "res://scenes/story/chapter76.tscn", "chapter75_done", 12],
		["第七十七章·检场", "res://scenes/story/chapter77.tscn", "chapter76_done", 12],
		["第七十八章·戏印", "res://scenes/story/chapter78.tscn", "chapter77_done", 12],
		["第七十九章·后台", "res://scenes/story/chapter79.tscn", "chapter78_done", 12],
		["第八十章·灯架", "res://scenes/story/chapter80.tscn", "chapter79_done", 12],
		["第八十一章·席终", "res://scenes/story/chapter81.tscn", "chapter80_done", 12],
		["第八十二章·桑陌", "res://scenes/story/chapter82.tscn", "chapter81_done", 13],
		["第八十三章·缫丝", "res://scenes/story/chapter83.tscn", "chapter82_done", 13],
		["第八十四章·丝印", "res://scenes/story/chapter84.tscn", "chapter83_done", 13],
		["第八十五章·烘茧", "res://scenes/story/chapter85.tscn", "chapter84_done", 13],
		["第八十六章·经轴", "res://scenes/story/chapter86.tscn", "chapter85_done", 13],
		["第八十七章·席终", "res://scenes/story/chapter87.tscn", "chapter86_done", 13],
		["第八十八章·茶梯", "res://scenes/story/chapter88.tscn", "chapter87_done", 14],
		["第八十九章·蒸青", "res://scenes/story/chapter89.tscn", "chapter88_done", 14],
		["第九十章·茶印", "res://scenes/story/chapter90.tscn", "chapter89_done", 14],
		["第九十一章·晾青", "res://scenes/story/chapter91.tscn", "chapter90_done", 14],
		["第九十二章·茶引", "res://scenes/story/chapter92.tscn", "chapter91_done", 14],
		["第九十三章·席终", "res://scenes/story/chapter93.tscn", "chapter92_done", 14],
		["第九十四章·药圃", "res://scenes/story/chapter94.tscn", "chapter93_done", 15],
		["第九十五章·医馆", "res://scenes/story/chapter95.tscn", "chapter94_done", 15],
		["第九十六章·方印", "res://scenes/story/chapter96.tscn", "chapter95_done", 15],
	]

func _volume_labels() -> Array:
	return ["卷零", "卷一", "卷二", "卷三", "卷四", "卷五", "卷六", "卷七", "卷八", "卷九", "卷十", "卷十一", "卷十二", "卷十三", "卷十四", "卷十五"]

func _volume_unlocked(vol: int) -> bool:
	# a volume is unlocked if any chapter in it is unlocked
	for entry in _chapter_catalog():
		if int(entry[3]) != vol:
			continue
		var need = str(entry[2])
		if need == "" or GameState.flag(need):
			return true
	return false

func _rebuild_volume_picker() -> void:
	if _vol_pick == null:
		return
	_vol_pick.clear()
	var prefer := 0
	for v in range(9):
		if not _volume_unlocked(v):
			continue
		_vol_pick.add_item(str(_volume_labels()[v]), v)
		# prefer highest unlocked volume that still has incomplete chapters
		var incomplete := false
		for entry in _chapter_catalog():
			if int(entry[3]) != v:
				continue
			var path = str(entry[1])
			var bn = path.get_file().replace(".tscn", "").replace("chapter", "")
			var done_flag = "chapter%s_done" % bn
			var need = str(entry[2])
			var unlocked = need == "" or GameState.flag(need)
			if unlocked and not GameState.flag(done_flag):
				incomplete = true
				break
		if incomplete:
			prefer = _vol_pick.item_count - 1
	if _vol_pick.item_count > 0:
		_vol_pick.select(prefer)
		_selected_vol = int(_vol_pick.get_item_id(prefer))

func _on_volume_picked(idx: int) -> void:
	if _vol_pick == null or idx < 0:
		return
	_selected_vol = int(_vol_pick.get_item_id(idx))
	_rebuild_chapter_picker()

func _rebuild_chapter_picker() -> void:
	if _chapter_pick == null:
		return
	_chapter_pick.clear()
	_chapter_paths.clear()
	var select_idx := 0
	var vol = _selected_vol
	if _vol_pick != null and _vol_pick.selected >= 0:
		vol = int(_vol_pick.get_item_id(_vol_pick.selected))
		_selected_vol = vol
	for entry in _chapter_catalog():
		if int(entry[3]) != vol:
			continue
		var label = str(entry[0])
		var path = str(entry[1])
		var need = str(entry[2])
		var unlocked = need == "" or GameState.flag(need)
		if not unlocked:
			continue
		_chapter_pick.add_item(label)
		_chapter_paths.append(path)
		var bn = path.get_file().replace(".tscn", "").replace("chapter", "")
		var done_flag = "chapter%s_done" % bn
		if not GameState.flag(done_flag):
			select_idx = _chapter_paths.size() - 1
	if _chapter_paths.size() > 0:
		_chapter_pick.select(select_idx)

func _on_chapter_picked(_idx: int) -> void:
	pass

func _continue_mainline() -> void:
	# search all volumes for first incomplete unlocked chapter
	var last_path := ""
	for entry in _chapter_catalog():
		var path = str(entry[1])
		var need = str(entry[2])
		var unlocked = need == "" or GameState.flag(need)
		if not unlocked:
			continue
		last_path = path
		var bn = path.get_file().replace(".tscn", "").replace("chapter", "")
		var done_flag = "chapter%s_done" % bn
		if not GameState.flag(done_flag):
			get_tree().change_scene_to_file(path)
			return
	if last_path != "":
		get_tree().change_scene_to_file(last_path)


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
