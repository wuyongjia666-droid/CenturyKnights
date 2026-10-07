extends Control

var _res_bar: HBoxContainer
var _hint: Label
var _story_hint: Label

func _ready() -> void:
	if not GameState.flag("hub_open"):
		GameState.set_flag("hub_open")
	_build()
	GameState.state_changed.connect(_refresh)

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var title = UIKit.make_label(Locale.t("hub_title"), true)
	title.position = Vector2(40, 20)
	add_child(title)

	_res_bar = UIKit.resource_bar()
	_res_bar.position = Vector2(40, 60)
	add_child(_res_bar)
	UIKit.update_resources(_res_bar)

	_story_hint = UIKit.make_label("")
	_story_hint.position = Vector2(40, 92)
	_story_hint.add_theme_color_override("font_color", UIKit.ACCENT)
	add_child(_story_hint)
	_update_story_hint()

	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(40, 140)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)

	var buttons = [
		[Locale.t("btn_roster"), "res://scenes/hub/roster.tscn"],
		[Locale.t("btn_tavern"), "res://scenes/hub/tavern.tscn"],
		[Locale.t("btn_quests"), "res://scenes/hub/quests.tscn"],
		[Locale.t("btn_train"), "res://scenes/hub/train.tscn"],
		[Locale.t("btn_forge"), "res://scenes/hub/forge.tscn"],
		[Locale.t("btn_shrine"), "res://scenes/hub/shrine.tscn"],
		[Locale.t("btn_lineage"), "res://scenes/hub/lineage_view.tscn"],
		[Locale.t("btn_marriage"), "res://scenes/hub/marriage.tscn"],
		[Locale.t("btn_hourglass"), "res://scenes/hub/hourglass.tscn"],
		[Locale.t("btn_market"), "res://scenes/hub/market.tscn"],
		[Locale.t("btn_deploy"), "res://scenes/hub/deploy.tscn"],
		["设置", "res://scenes/ui/settings.tscn"],
	]
	for item in buttons:
		var b = UIKit.make_button(item[0], 200)
		var path = item[1]
		b.pressed.connect(func(): get_tree().change_scene_to_file(path))
		grid.add_child(b)

	var heir = UIKit.make_label(Locale.t("heirloom_preview"))
	heir.position = Vector2(40, 520)
	heir.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	add_child(heir)

	_hint = UIKit.make_label("")
	_hint.position = Vector2(40, 560)
	_hint.custom_minimum_size = Vector2(1000, 80)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)

	var row := HBoxContainer.new()
	row.position = Vector2(40, 640)
	add_child(row)
	var save_b = UIKit.make_button("存档", 100)
	save_b.pressed.connect(func():
		GameState.save_game()
		_hint.text = Locale.t("save_ok")
	)
	row.add_child(save_b)
	var ch_b = UIKit.make_button("第零章节拍", 140)
	ch_b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn"))
	row.add_child(ch_b)
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
	else:
		_story_hint.text = "第零章已完成。可自由经营灰旗堡。"
