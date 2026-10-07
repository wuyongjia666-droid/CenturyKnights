extends Control

var _forecast: RichTextLabel
var _log: RichTextLabel

func _ready() -> void:
	_build()
	_show_forecast(1)

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var t = UIKit.make_label("岁月沙漏", true)
	t.position = Vector2(40, 20)
	add_child(t)
	var cal = UIKit.make_label(Calendar.label())
	cal.position = Vector2(40, 60)
	cal.name = "CalLabel"
	add_child(cal)
	var fl = UIKit.make_label("推进预告（X5）")
	fl.position = Vector2(40, 100)
	fl.add_theme_color_override("font_color", UIKit.ACCENT)
	add_child(fl)
	_forecast = RichTextLabel.new()
	_forecast.position = Vector2(40, 130)
	_forecast.custom_minimum_size = Vector2(600, 280)
	_forecast.bbcode_enabled = true
	add_child(_forecast)
	_log = RichTextLabel.new()
	_log.position = Vector2(680, 130)
	_log.custom_minimum_size = Vector2(540, 400)
	_log.bbcode_enabled = true
	add_child(_log)
	var row := HBoxContainer.new()
	row.position = Vector2(40, 450)
	add_child(row)
	var m1 = UIKit.make_button(Locale.t("advance_month"), 140)
	m1.pressed.connect(func(): _advance(1))
	row.add_child(m1)
	var m3 = UIKit.make_button(Locale.t("advance_season"), 140)
	m3.pressed.connect(func(): _advance(3))
	row.add_child(m3)
	var harvest = UIKit.make_button("教程：跳至丰收月", 180)
	harvest.pressed.connect(_to_harvest)
	row.add_child(harvest)
	var back = UIKit.make_button(Locale.t("btn_back"), 100)
	back.pressed.connect(func():
		if str(GameState.chapter0_beat) == "0.6":
			get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
	)
	row.add_child(back)

func _show_forecast(months: int) -> void:
	var evs = Calendar.forecast(months)
	var lines: Array = ["将推进 %d 月，预计发生：" % months]
	if evs.is_empty():
		lines.append("（无特殊事件，仍有军饷结算）")
	for e in evs:
		lines.append("· " + str(e.get("text", "")))
	_forecast.text = "\n".join(lines)

func _advance(months: int) -> void:
	_show_forecast(months)
	var evs = Calendar.advance(months)
	var lines: Array = ["[%s] 推进结果：" % Calendar.label()]
	for e in evs:
		lines.append("· " + str(e.get("text", "")))
	_log.text = "\n".join(lines)
	get_node("CalLabel").text = Calendar.label()
	_show_forecast(1)
	GameState.save_game()

func _to_harvest() -> void:
	var guard = 0
	while not GameState.flag("harvest_done") and guard < 24:
		Calendar.advance(1)
		guard += 1
	_log.text = "已抵达丰收结算。当前 %s" % Calendar.label()
	get_node("CalLabel").text = Calendar.label()
	GameState.save_game()
