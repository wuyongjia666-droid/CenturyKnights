extends Control

var _forecast: RichTextLabel
var _log: RichTextLabel

func _ready() -> void:
	_build()
	_show_forecast(1)

func _build() -> void:
	UIKit.make_themed_bg(self, "hourglass")
	UIFX.page_enter(self)
	if ResourceLoader.exists("res://assets/art/ui/hub_banner_strip.png"):
		var strip := TextureRect.new()
		strip.texture = load("res://assets/art/ui/hub_banner_strip.png")
		strip.position = Vector2(0, 0)
		strip.custom_minimum_size = Vector2(1280, 48)
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)

	if ResourceLoader.exists("res://assets/art/ui/monthly_banner.png"):
		var mb := TextureRect.new()
		mb.texture = load("res://assets/art/ui/monthly_banner.png")
		mb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mb.stretch_mode = TextureRect.STRETCH_SCALE
		mb.position = Vector2(320, 8)
		mb.size = Vector2(640, 48)
		mb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mb)
	var t = UIKit.make_label("岁月沙漏", true)
	t.position = Vector2(40, 16)
	add_child(t)
	# 月结图腾条
	var chip_row := HBoxContainer.new()
	chip_row.name = "MonthChips"
	chip_row.position = Vector2(40, 430)
	chip_row.add_theme_constant_override("separation", 8)
	add_child(chip_row)
	var cal = UIKit.make_label(Calendar.label())
	cal.position = Vector2(40, 56)
	cal.name = "CalLabel"
	cal.add_theme_color_override("font_color", UIKit.ACCENT)
	add_child(cal)
	var fl = UIKit.make_dim_label("先看预告，再倾沙漏。人会老，旗还在——儿童口粮也计入月结。")
	fl.position = Vector2(200, 56)
	add_child(fl)

	var fp = UIKit.make_panel()
	fp.position = Vector2(40, 100)
	fp.custom_minimum_size = Vector2(600, 320)
	add_child(fp)
	var ftitle = UIKit.make_label("推进预告")
	ftitle.add_theme_color_override("font_color", UIKit.ACCENT)
	fp.add_child(VBoxContainer.new())
	var fv = fp.get_child(0) as VBoxContainer
	fv.add_child(ftitle)
	_forecast = RichTextLabel.new()
	_forecast.custom_minimum_size = Vector2(560, 260)
	_forecast.bbcode_enabled = true
	_forecast.add_theme_color_override("default_color", UIKit.TEXT)
	fv.add_child(_forecast)

	var lp = UIKit.make_panel()
	lp.position = Vector2(680, 100)
	lp.custom_minimum_size = Vector2(560, 320)
	add_child(lp)
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	var ltitle = UIKit.make_label("推进结果")
	ltitle.add_theme_color_override("font_color", UIKit.ACCENT)
	lv.add_child(ltitle)
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(520, 260)
	_log.bbcode_enabled = true
	_log.add_theme_color_override("default_color", UIKit.TEXT)
	lv.add_child(_log)

	var row := HBoxContainer.new()
	row.position = Vector2(40, 460)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var m1 = UIKit.make_accent_button(Locale.t("advance_month"), 140)
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
	var lines: Array = ["将推进 [b]%d[/b] 月，预计发生：" % months]
	if evs.is_empty():
		lines.append("（无特殊事件，仍有军饷与口粮结算）")
	for e in evs:
		lines.append("· " + str(e.get("text", "")))
	_forecast.text = "\n".join(lines)

func _advance(months: int) -> void:
	_show_forecast(months)
	var evs = Calendar.advance(months)
	var lines: Array = ["[b]%s[/b] 推进结果：" % Calendar.label()]
	for e in evs:
		var tx = str(e.get("text", ""))
		if str(e.get("type", "")) == "rival_deal" or tx.find("契约") >= 0:
			lines.append("· [color=#c9a227]%s[/color]" % tx)
		else:
			lines.append("· " + tx)
	_log.text = "\n".join(lines)
	_refresh_month_chips("\n".join(lines))
	get_node("CalLabel").text = Calendar.label()
	_show_forecast(1)
	GameState.save_game()

func _to_harvest() -> void:
	var guard = 0
	while not GameState.flag("harvest_done") and guard < 24:
		Calendar.advance(1)
		guard += 1
	_log.text = "已抵达丰收结算。当前 [b]%s[/b]。沙漏旁的人，又老了一点。" % Calendar.label()
	get_node("CalLabel").text = Calendar.label()
	GameState.save_game()

func _refresh_month_chips(log_text: String) -> void:
	var row = get_node_or_null("MonthChips")
	if row == null:
		return
	for c in row.get_children():
		c.queue_free()
	var keys: Array = []
	if log_text.find("粮") >= 0 or log_text.find("属地") >= 0:
		keys.append("grain")
	if log_text.find("银") >= 0:
		keys.append("silver")
	if log_text.find("士气") >= 0:
		keys.append("morale")
	if log_text.find("联姻") >= 0:
		keys.append("marriage")
	if log_text.find("血胤") >= 0 or log_text.find("月泽") >= 0:
		keys.append("blood")
	if log_text.find("堡志") >= 0:
		keys.append("ambition")
	if keys.is_empty():
		keys = ["grain", "silver"]
	for k in keys:
		var path = "res://assets/art/ui/month_chip_%s.png" % k
		if ResourceLoader.exists(path):
			var tr := TextureRect.new()
			tr.texture = load(path)
			tr.custom_minimum_size = Vector2(40, 40)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tr)
	var tip = UIKit.make_dim_label("月结图腾：粮 / 银 / 士气 / 联姻 / 血胤 / 堡志")
	row.add_child(tip)
