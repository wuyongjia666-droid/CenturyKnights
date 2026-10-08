extends Control
## v8.6 — layout-matched to Stitch 15_temple.png: top bar · editorial head (FACILITY // SANCTUARY RITE) with
## purity/tier KPIs right · three service cards (blessing · healing [focused] · restoration) · info strip · footer.

var _msg: Label

func _ready() -> void:
	UIKit.void_bg(self)
	var lv := GameState.building_level("shrine")
	UIKit.top_bar(self, "祠堂 · SANCTUARY", [["银币", str(GameState.silver), UIKit.ACCENT], ["士气", str(GameState.morale), UIKit.OK if GameState.morale >= 50 else UIKit.DANGER], ["历", Calendar.label(), UIKit.TEXT_DIM]], "返回城堡", _back)
	UIKit.page_head(self, 42, 76, "FACILITY // SANCTUARY RITE", "祠堂 · 霜月祭", "SANCTUARY // FROST MOON RITE", "香灰里有旧旗的味。祠堂等级来自「工事」，丰收产出与祈愈随等级增强。")
	var injured := 0
	var hurt := 0
	var roster: Array = GameState.roster()
	for c in roster:
		if c.injured:
			injured += 1
		if c.injured or c.hp < c.max_hp:
			hurt += 1
	# KPIs right
	_kpi(Vector2(930, 92), "SANCTUARY TIER", "LV %d / 3" % lv, UIKit.ACCENT)
	_kpi(Vector2(1090, 92), "待祈愈", "%d 人" % hurt, UIKit.DANGER if hurt > 0 else UIKit.OK)
	var hl := UIKit.hairline(Color(1, 1, 1, 0.08))
	hl.position = Vector2(42, 172)
	hl.size = Vector2(1196, 1)
	add_child(hl)
	# three service cards
	var w := 380.0
	var y := 200.0
	_card(Rect2(42, y + 16, w, 380), "SERVICE // 01 · 丰收加护", "常驻 · PASSIVE", "加护", "HARVEST BLESSING",
		"祠堂等级提升秋收产出",
		"祠堂每升一级，秋收时额外产出增加；无需主动操作，月结自动生效。",
		[["当前等级", "LV %d" % lv, UIKit.ACCENT], ["加护对象", "全部属地", UIKit.TEXT], ["生效时机", "秋收月结", UIKit.TEXT_DIM]],
		"CONSUMPTION", "无消耗", false, "", Callable())
	_card(Rect2(450, y, w, 412), "SERVICE // 02 · 祈愈之水", "TARGET FOCUSED", "祈愈", "PURIFICATION & HEALING",
		"清除临时伤 · 回满全队生命",
		"在祠堂焚香祈愈：所有负伤者清除临时伤，生命回满。出征前来一趟，旗下人才走得远。",
		[["负伤骑士", "%d 人" % injured, UIKit.DANGER if injured > 0 else UIKit.OK], ["未满生命", "%d / %d 人" % [hurt, roster.size()], UIKit.TEXT], ["回复量", "100% 生命", UIKit.OK]],
		"COST REQUIREMENT", "免费 · 祠堂恩典", true, "祈愈", Callable(self, "_heal"))
	_card(Rect2(858, y + 16, w, 380), "SERVICE // 03 · 祠堂修缮", "工事 · WORKS", "修缮", "SANCTUARY RESTORATION",
		"在「工事」中升级祠堂",
		"祠堂上限 3 级。升级需要银币与工期，由工事统一调度。",
		[["当前等级", "LV %d" % lv, UIKit.ACCENT], ["等级上限", "LV 3", UIKit.TEXT], ["状态", "已满级" if lv >= 3 else "可升级", UIKit.OK if lv >= 3 else UIKit.TEXT]],
		"ROUTE", "前往工事", false, "前往工事", func(): get_tree().change_scene_to_file("res://scenes/hub/works.tscn"))
	# info strip
	var strip := UIKit.panel_at(self, Rect2(42, 628, 1196, 48), 8)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg = UIKit.body_label("ⓘ 祈愈不耗银、不耗时；临时伤会降低出征表现，开战前务必清除。", UIKit.TEXT_DIM, 12)
	_msg.autowrap_mode = TextServer.AUTOWRAP_OFF
	_msg.position = Vector2(62, 643)
	add_child(_msg)
	UIKit.footer_bar(self, [["A", "祈愈"], ["W", "前往工事"], ["ESC", "返回城堡"]], "SANCTUARY // LV %d · v8.6" % lv)
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()
	elif e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_W:
		get_tree().change_scene_to_file("res://scenes/hub/works.tscn")

func _heal() -> void:
	_msg.text = "✓ " + GameState.heal_at_shrine() + "　· 祠堂 LV%d" % GameState.building_level("shrine")
	_msg.add_theme_color_override("font_color", UIKit.OK)

func _kpi(pos: Vector2, label: String, value: String, col: Color) -> void:
	var l := UIKit.mono(label, 9, UIKit.TEXT_FAINT, false)
	l.position = pos
	add_child(l)
	var v := UIKit.mono(value, 18, col, false)
	v.position = pos + Vector2(0, 18)
	add_child(v)

func _card(r: Rect2, eyebrow: String, chip: String, title: String, en: String, head: String, body: String, rows: Array, cost_k: String, cost_v: String, focus: bool, act: String, cb: Callable) -> void:
	UIKit.panel_at(self, r, 10, focus)
	var x := r.position.x + 22
	var cw := r.size.x - 44
	var e := UIKit.mono(eyebrow, 9, UIKit.ACCENT if focus else UIKit.TEXT_FAINT, false)
	e.position = Vector2(x, r.position.y + 20)
	add_child(e)
	var ch := UIKit.tag_chip(chip, UIKit.ACCENT if focus else UIKit.TEXT_DIM)
	ch.position = Vector2(r.end.x - 22 - ch.get_minimum_size().x, r.position.y + 17)
	add_child(ch)
	var t := UIKit.title_label(title, 28, UIKit.TEXT)
	t.position = Vector2(x, r.position.y + 48)
	add_child(t)
	var en_l := UIKit.mono(en, 9, UIKit.ACCENT if focus else UIKit.TEXT_FAINT, false)
	en_l.position = Vector2(x, r.position.y + 92)
	add_child(en_l)
	var hd := UIKit.title_label(head, 15, UIKit.TEXT)
	hd.position = Vector2(x, r.position.y + 122)
	add_child(hd)
	var bd := UIKit.body_label(body, UIKit.TEXT_DIM, 12)
	bd.position = Vector2(x, r.position.y + 150)
	bd.size = Vector2(cw, 48)
	bd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(bd)
	var kv := VBoxContainer.new()
	kv.position = Vector2(x, r.position.y + 212)
	kv.add_theme_constant_override("separation", 8)
	add_child(kv)
	for row in rows:
		kv.add_child(UIKit.kv_row(str(row[0]), str(row[1]), row[2], cw))
	var sep := UIKit.hairline(Color(1, 1, 1, 0.08))
	sep.position = Vector2(x, r.end.y - 78)
	sep.size = Vector2(cw, 1)
	add_child(sep)
	var ck := UIKit.mono(cost_k, 8, UIKit.TEXT_FAINT, false)
	ck.position = Vector2(x, r.end.y - 62)
	add_child(ck)
	var cv := UIKit.title_label(cost_v, 14, UIKit.ACCENT if focus else UIKit.TEXT)
	cv.position = Vector2(x, r.end.y - 44)
	add_child(cv)
	if act != "" and cb.is_valid():
		var b: Button = UIKit.cta_button(act, "A", 150, 40) if focus else UIKit.ghost_button("%s  [W]" % act, 130, 36)
		b.position = Vector2(r.end.x - 22 - b.custom_minimum_size.x, r.end.y - 58)
		b.pressed.connect(cb)
		add_child(b)
		if focus:
			b.call_deferred("grab_focus")
