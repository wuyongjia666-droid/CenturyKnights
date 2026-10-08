extends Control
## Court gazette: births, deaths, succession crises. Filters only; the year sim is untouched.

var _filter := "all"
var _list: VBoxContainer
var _scroll: ScrollContainer

func _ready() -> void:
	UIKit.void_bg(self)
	UIKit.top_bar(self, "朝报", [["历", Calendar.label(), UIKit.TEXT_DIM]], "返回舆图", _back)
	UIKit.page_head(self, 42, 72, "COURT GAZETTE", "十邦朝报", "BIRTHS · DEATHS · SUCCESSION", "邻国王室的添丁、辞世与承座危机。舆图上的标记与这里同一份记录。", "", 18)
	var bar := HBoxContainer.new()
	bar.name = "FilterBar"
	bar.position = Vector2(42, 200)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	for it in [["all", "全部", "FilterAll"], ["birth", "添丁", "FilterBirth"], ["death", "辞世", "FilterDeath"], ["succession", "更替", "FilterSuccession"], ["marriage", "配婚", "FilterMarriage"], ["recall", "归国", "FilterRecall"]]:
		var b := UIKit.ghost_button(str(it[1]), 120, 44)
		b.name = str(it[2])
		b.toggle_mode = true
		b.button_pressed = str(it[0]) == "all"
		var kind := str(it[0])
		b.pressed.connect(func():
			Sfx.click()
			_set_filter(kind))
		bar.add_child(b)
	var panel := UIKit.panel_at(self, Rect2(42, 256, 1196, 420), 12)
	panel.name = "NewsList"
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(16, 16)
	_scroll.size = Vector2(1164, 388)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(1140, 0)
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)
	_fill()
	UIKit.footer_bar(self, [["ESC", "返回舆图"]], "COURT GAZETTE · FROST")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func apply_mobile_layout() -> void:
	MobileLayout.pin_footer(get_node_or_null("StitchFooter"))

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/atlas_view.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()

func _set_filter(kind: String) -> void:
	_filter = kind
	var bar := get_node_or_null("FilterBar")
	if bar:
		for ch in bar.get_children():
			if ch is Button:
				var on := str(ch.name).trim_prefix("Filter").to_lower() == kind
				(ch as Button).set_pressed_no_signal(on)
	if kind == "death":
		Sfx.play("bell_toll")
	elif kind == "birth":
		Sfx.lineage_chime()
	_fill()

func _fill() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	var rows: Array = []
	for ev in CKCourt.news_events():
		var kind := str(ev.get("kind", ""))
		if _filter != "all" and kind != _filter:
			continue
		rows.append(ev)
	if rows.is_empty():
		_list.add_child(UIKit.empty_state("这一栏还没有朝报。年历走到次年正月，邻国王室才会写入。"))
		return
	var crisis_nations := {}
	for ev in rows:
		if str(ev.get("crisis", "")) != "":
			crisis_nations[str(ev.get("nation_zh", ""))] = str(ev.get("crisis", ""))
	for nz in crisis_nations.keys():
		var banner := UIKit.body_label("危机 · %s · %s" % [nz, str(crisis_nations[nz])], UIKit.DANGER, 14)
		banner.custom_minimum_size = Vector2(1100, 28)
		_list.add_child(banner)
	for ev2 in rows:
		var kind2 := str(ev2.get("kind", ""))
		var col: Color = UIKit.OK if kind2 == "birth" else (UIKit.DANGER if kind2 == "death" else UIKit.ACCENT)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(1100, 52)
		card.add_theme_stylebox_override("panel", UIKit.flat_box(Color(col, 0.06), Color(col, 0.35), 8))
		var v := VBoxContainer.new()
		card.add_child(v)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		v.add_child(top)
		top.add_child(UIKit.tag_chip(CKCourtChrome.KIND_ZH.get(kind2, kind2), col))
		top.add_child(UIKit.mono("第 %d 年 · %s" % [int(ev2.get("year", 0)), str(ev2.get("nation_zh", ""))], 12, UIKit.TEXT_DIM, false))
		var body := UIKit.body_label(str(ev2.get("text", "")), UIKit.TEXT, 14)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(body)
		_list.add_child(card)
	UIFX.stagger_children(_list, 0.03, 0.2)
