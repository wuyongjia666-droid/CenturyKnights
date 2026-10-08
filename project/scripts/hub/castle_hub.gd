extends Control
const HubTodo := preload("res://scripts/ui/widgets/todo_center.gd")
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
	UIFX.fade_in(self, 0.32)
	Music.play_hub()
	GameState.state_changed.connect(_refresh)

func _build() -> void:
	## v8.6 — layout-matched to Stitch 02_castle_hub.png:
	## top bar · left NAVIGATION rail · centre SEASONAL DOSSIER (3 cards + campaign row) · right KNIGHT ROSTER plate · footer hints
	for c in get_children():
		remove_child(c)
		c.queue_free()
	UIKit.void_bg(self)
	var tb := UIKit.top_bar(self, "「%s堡」" % GameState.surname, UIKit.std_resource_chips(), "主菜单", func():
		GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	_res_bar = HBoxContainer.new()   # kept for _refresh compatibility (resource tick)
	_res_bar.visible = false
	add_child(_res_bar)
	var right_box: HBoxContainer = tb.get_child(tb.get_child_count() - 1)
	var save_b := UIKit.ghost_button("存档", 64, 32)
	save_b.pressed.connect(func():
		GameState.save_game()
		_hint.text = Locale.t("save_ok"))
	right_box.add_child(save_b)
	right_box.move_child(save_b, right_box.get_child_count() - 2)

	# ── NAVIGATION ─────────────────────────────────────────
	UIKit.panel_at(self, Rect2(26, 72, 150, 612), 10)
	var nl := UIKit.mono("NAVIGATION", 9, UIKit.TEXT_FAINT)
	nl.position = Vector2(40, 86)
	add_child(nl)
	var scroll := ScrollContainer.new()
	scroll.name = "NavRail"
	scroll.position = Vector2(34, 108)
	scroll.size = Vector2(142, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 4)
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rail)
	var groups: Array = [
		{"id": "military", "title": Locale.t("ux_hub_military"), "items": [
			["战役", "出战编成 · 最多四人", "res://scenes/hub/deploy.tscn", Locale.t("btn_deploy"), "deploy"],
			[Locale.t("btn_train"), "六维与转职", "res://scenes/hub/train.tscn", Locale.t("btn_train"), "train"],
			["战技树", "冷却与二阶", "res://scenes/hub/skill_tree.tscn", "战技树", "skills"],
		]},
		{"id": "civil", "title": Locale.t("ux_hub_civil"), "items": [
			[Locale.t("btn_tavern"), "招募新刃", "res://scenes/hub/tavern.tscn", Locale.t("btn_tavern"), "tavern"],
			[Locale.t("btn_forge"), "灰刃与铁火", "res://scenes/hub/forge.tscn", Locale.t("btn_forge"), "forge"],
			[Locale.t("btn_market"), "粮铁药材", "res://scenes/hub/market.tscn", Locale.t("btn_market"), "market"],
			["属地", "四野租佃庄园", "res://scenes/hub/estates.tscn", "属地", "estates"],
			[Locale.t("btn_quests"), "陆桥委托", "res://scenes/hub/quests.tscn", Locale.t("btn_quests"), "quests"],
			["工事", "厅堂校场市集", "res://scenes/hub/works.tscn", "工事", "works"],
		]},
		{"id": "family", "title": Locale.t("ux_hub_family"), "items": [
			[Locale.t("btn_roster"), "名册与立绘", "res://scenes/hub/roster.tscn", Locale.t("btn_roster"), "roster"],
			[Locale.t("btn_shrine"), "祈愈与丰收", "res://scenes/hub/shrine.tscn", Locale.t("btn_shrine"), "shrine"],
			[Locale.t("btn_marriage"), "春令与期望", "res://scenes/hub/marriage.tscn", Locale.t("btn_marriage"), "marriage"],
			[Locale.t("btn_lineage"), "血胤与容貌", "res://scenes/hub/lineage_view.tscn", Locale.t("btn_lineage"), "lineage"],
			["授旗礼", "子嗣三步入队", "res://scenes/hub/lineage_rite.tscn", "授旗礼", "rite"],
		]},
		{"id": "court", "title": Locale.t("ux_hub_court"), "items": [
			[Locale.t("btn_hourglass"), "预告与推进", "res://scenes/hub/hourglass.tscn", Locale.t("btn_hourglass"), "hourglass"],
			["设置", "规则与速度", "res://scenes/ui/settings.tscn", "设置", "settings"],
		]},
		{"id": "atlas", "title": Locale.t("ux_hub_atlas"), "items": [
			["舆图", "跑图 · 城镇 · 委托", "res://scenes/hub/atlas_view.tscn", "舆图", "atlas"],
		]},
	]
	var n := 0
	var first := true
	for group in groups:
		var box := VBoxContainer.new()
		box.name = "NavGroup_%s" % str(group["id"])
		box.add_theme_constant_override("separation", 1)
		rail.add_child(box)
		var badge := HubTodo.count_for(str(group["id"]))
		var head_txt := str(group["title"])
		if badge > 0:
			head_txt = "%s %d" % [head_txt, badge]
		var head := UIKit.mono(head_txt, 9, UIKit.ACCENT, false)
		head.custom_minimum_size = Vector2(134, 14)
		box.add_child(head)
		for item in group["items"]:
			if not HubTodo.is_unlocked(str(item[4])):
				continue
			n += 1
			var b := _nav_item("%02d" % n, str(item[0]), str(item[1]), first, false, true)
			first = false
			var legacy := str(item[3]) if str(item[3]) != "" else str(item[0])
			b.set_meta("legacy_label", legacy)
			b.set_meta("hub_entry", str(item[4]))
			var path: String = item[2]
			b.pressed.connect(_go_nav.bind(b, path))
			box.add_child(b)
	UIFX.stagger_children(rail, 0.018, 0.2)
	var gp := UIKit.mono("GAMEPAD", 9, UIKit.TEXT_FAINT)
	gp.position = Vector2(40, 660)
	add_child(gp)
	var gpc := UIKit.mono("● READY", 9, UIKit.OK)
	gpc.position = Vector2(112, 660)
	add_child(gpc)

	# ── SEASONAL DOSSIER ───────────────────────────────────
	var cp := UIKit.panel_at(self, Rect2(188, 72, 820, 612), 10)
	var ce := UIKit.mono("SEASONAL DOSSIER", 10, UIKit.ACCENT)
	ce.position = Vector2(26, 22)
	cp.add_child(ce)
	var ceh := UIKit.hairline(Color(UIKit.ACCENT, 0.35))
	ceh.position = Vector2(26 + ce.get_minimum_size().x + 10, 29)
	ceh.size = Vector2(36, 1)
	cp.add_child(ceh)
	var ct := UIKit.title_label("本季事务", 28)
	ct.position = Vector2(26, 38)
	cp.add_child(ct)
	var meta := UIKit.mono("ENTRY 01-03 / 03 PENDING", 10, UIKit.TEXT_DIM)
	meta.position = Vector2(794 - meta.get_minimum_size().x, 24)
	cp.add_child(meta)
	var meta2 := UIKit.body_label("%s · %s旗大厅事务汇总" % [Calendar.label(), GameState.surname], UIKit.TEXT_FAINT, 11)
	meta2.position = Vector2(494, 50)
	meta2.size = Vector2(300, 16)
	meta2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cp.add_child(meta2)

	_story_hint = Label.new()
	_update_story_hint()
	var roster_n: int = GameState.roster().size()
	var leader = GameState.get_leader()
	var wed := 0
	var kids := 0
	for ch in GameState.roster():
		if str(ch.spouse_id) != "":
			wed += 1
		kids += ch.children_ids.size()
	var cards := [
		{"tag": "MAINLINE · 主线", "col": UIKit.DANGER, "id": "# 01", "title": "战役推进", "desc": _story_hint.text,
		 "kv": [["当前卷", _cur_vol_label(), UIKit.TEXT], ["已解锁章节", "%d 章" % _unlocked_count(), UIKit.ACCENT]],
		 "act": "继续主线", "cb": Callable(self, "_continue_mainline")},
		{"tag": "RECRUIT · 征募", "col": UIKit.ACCENT, "id": "# 02", "title": "酒馆有新面孔", "desc": "烽火酒馆的候选人每旬轮换；职业、特质与佣金各不相同。",
		 "kv": [["麾下", "%d 人" % roster_n, UIKit.TEXT], ["银币", str(GameState.silver), UIKit.ACCENT]],
		 "act": "前往酒馆接洽", "cb": func(): get_tree().change_scene_to_file("res://scenes/hub/tavern.tscn")},
		{"tag": "ALLIANCE · 家族", "col": UIKit.OK, "id": "# 03", "title": "联姻与传承", "desc": "联姻缔约决定血脉与可遗传特质；子嗣成年后可行授旗礼入队。",
		 "kv": [["已缔约", "%d 对" % wed, UIKit.TEXT], ["子嗣", "%d 人" % kids, UIKit.OK]],
		 "act": "前往联姻廷", "cb": func(): get_tree().change_scene_to_file("res://scenes/hub/marriage.tscn")},
	]
	var first_link: Button = null
	for i in cards.size():
		var cd: Dictionary = cards[i]
		var card := UIKit.panel_at(cp, Rect2(26 + i * 262, 86, 246, 312), 8)
		var tg := UIKit.tag_chip(str(cd.tag), cd.col)
		tg.position = Vector2(16, 18)
		card.add_child(tg)
		var idl := UIKit.mono(str(cd.id), 10, UIKit.TEXT_FAINT, false)
		idl.position = Vector2(200, 20)
		card.add_child(idl)
		var tt := UIKit.title_label(str(cd.title), 18)
		tt.add_theme_font_override("font", UIKit.font("bold"))
		tt.position = Vector2(16, 54)
		card.add_child(tt)
		var ds := UIKit.body_label(str(cd.desc), UIKit.TEXT_FAINT, 12)
		ds.position = Vector2(16, 88)
		ds.size = Vector2(214, 64)
		ds.custom_minimum_size = Vector2(214, 0)
		card.add_child(ds)
		var kv := VBoxContainer.new()
		kv.position = Vector2(16, 178)
		kv.add_theme_constant_override("separation", 8)
		card.add_child(kv)
		for row in cd.kv:
			kv.add_child(UIKit.kv_row(str(row[0]), str(row[1]), row[2], 214))
		var fh := UIKit.hairline(Color(1, 1, 1, 0.07))
		fh.position = Vector2(16, 258)
		fh.size = Vector2(214, 1)
		card.add_child(fh)
		var al := UIKit.mono("ACTION", 9, UIKit.TEXT_FAINT)
		al.position = Vector2(16, 274)
		card.add_child(al)
		var lb := UIKit.link_button(str(cd.act))
		lb.position = Vector2(230 - lb.get_combined_minimum_size().x, 268)
		lb.pressed.connect(cd.cb)
		card.add_child(lb)
		if first_link == null:
			first_link = lb

	# campaign row (chapter picker) — inside dossier, below the cards
	var crl := UIKit.mono("CAMPAIGN // 章节直达", 9, UIKit.TEXT_FAINT)
	crl.position = Vector2(26, 408)
	cp.add_child(crl)
	var row := HBoxContainer.new()
	row.position = Vector2(26, 426)
	row.add_theme_constant_override("separation", 10)
	cp.add_child(row)
	_vol_pick = OptionButton.new()
	_vol_pick.custom_minimum_size = Vector2(108, 38)
	_vol_pick.add_theme_font_size_override("font_size", 13)
	row.add_child(_vol_pick)
	_chapter_pick = OptionButton.new()
	_chapter_pick.custom_minimum_size = Vector2(280, 38)
	_chapter_pick.add_theme_font_size_override("font_size", 13)
	row.add_child(_chapter_pick)
	_rebuild_volume_picker()
	_rebuild_chapter_picker()
	_vol_pick.item_selected.connect(_on_volume_picked)
	_chapter_pick.item_selected.connect(_on_chapter_picked)
	var go_b := UIKit.ghost_button("前往选中章", 112, 38)
	go_b.pressed.connect(func():
		var i = _chapter_pick.selected
		if i >= 0 and i < _chapter_paths.size():
			get_tree().change_scene_to_file(str(_chapter_paths[i])))
	row.add_child(go_b)
	var cont_b := UIKit.cta_button("继续主线", "A", 220, 40)
	cont_b.position = Vector2(794 - 220, 424)
	cont_b.pressed.connect(_continue_mainline)
	cp.add_child(cont_b)
	cont_b.call_deferred("grab_focus")
	var todo_row := HBoxContainer.new()
	todo_row.name = "TodoRow"
	todo_row.position = Vector2(26, 476)
	todo_row.size = Vector2(520, 28)
	todo_row.clip_contents = true
	todo_row.add_theme_constant_override("separation", 6)
	cp.add_child(todo_row)
	todo_row.add_child(UIKit.mono(Locale.t("ux_hub_todo"), 10, UIKit.ACCENT, false))
	for todo in HubTodo.snapshot():
		if int(todo.get("count", 0)) <= 0:
			continue
		todo_row.add_child(UIKit.tag_chip("%s %d" % [str(todo.get("label", "")), int(todo.get("count", 0))], UIKit.ACCENT))
	var ih := UIKit.hairline(Color(1, 1, 1, 0.07))
	ih.position = Vector2(26, 512)
	ih.size = Vector2(768, 1)
	cp.add_child(ih)
	var hints := HBoxContainer.new()
	hints.position = Vector2(26, 528)
	hints.add_theme_constant_override("separation", 6)
	cp.add_child(hints)
	for hk in [["A", "确认 / 选定"], ["B", "返回中枢"], ["X", "存档"], ["Y", "快速休整"]]:
		hints.add_child(UIKit.keycap(hk[0]))
		var hl2 := UIKit.body_label(hk[1], UIKit.TEXT_DIM, 11)
		hl2.autowrap_mode = TextServer.AUTOWRAP_OFF
		hints.add_child(hl2)
		var g2 := Control.new()
		g2.custom_minimum_size = Vector2(14, 0)
		hints.add_child(g2)
	_hint = UIKit.body_label("", UIKit.OK, 11)
	_hint.position = Vector2(494, 528)
	_hint.size = Vector2(300, 18)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cp.add_child(_hint)
	_hint.text = "当前中枢士气：%d%%  ●" % GameState.morale

	# ── KNIGHT ROSTER plate ────────────────────────────────
	var rp := UIKit.panel_at(self, Rect2(1024, 72, 232, 612), 10)
	var rl := UIKit.mono("KNIGHT ROSTER", 9, UIKit.ACCENT)
	rl.position = Vector2(16, 18)
	rp.add_child(rl)
	var rl2 := UIKit.mono("PLATE #01", 9, UIKit.TEXT_FAINT)
	rl2.position = Vector2(216 - rl2.get_minimum_size().x, 18)
	rp.add_child(rl2)
	if leader:
		UIKit.portrait_plate(rp, Rect2(16, 44, 200, 250), leader, "ACTIVE GUARD")
		var nm := UIKit.title_label(leader.name, 22)
		nm.position = Vector2(16, 308)
		rp.add_child(nm)
		var ag := UIKit.body_label("%d 岁" % leader.age, UIKit.TEXT_FAINT, 12)
		ag.position = Vector2(172, 316)
		ag.size = Vector2(44, 16)
		ag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rp.add_child(ag)
		var jb := UIKit.body_label("%s · %s" % [GameState.get_job(leader.job_id).get("name", ""), leader.rank_name()], UIKit.ACCENT, 12)
		jb.position = Vector2(16, 342)
		jb.size = Vector2(200, 16)
		rp.add_child(jb)
		var sg := GridContainer.new()
		sg.columns = 2
		sg.position = Vector2(16, 370)
		sg.add_theme_constant_override("h_separation", 8)
		sg.add_theme_constant_override("v_separation", 8)
		rp.add_child(sg)
		for st in [["生命 HP", "%d" % leader.max_hp, UIKit.OK], ["攻击 ATK", "%d" % leader.derived_atk(), UIKit.TEXT], ["防御 DEF", "%d" % leader.derived_def(), UIKit.TEXT], ["移动 MOV", "%d" % leader.derived_move(), UIKit.ACCENT]]:
			var bx := UIKit.stat_box(st[0], st[1], st[2])
			bx.custom_minimum_size = Vector2(96, 0)
			sg.add_child(bx)
		var fl := UIKit.body_label("%s旗家主，率 %d 名骑士守着这座堡。工事、委任与联姻誓约都会写入家族旁注。" % [GameState.surname, roster_n], UIKit.TEXT_FAINT, 11)
		fl.position = Vector2(16, 468)
		fl.size = Vector2(200, 48)
		fl.custom_minimum_size = Vector2(200, 0)
		rp.add_child(fl)
		var vb := UIKit.ghost_button("检视骑士完整档案", 200, 32)
		vb.position = Vector2(16, 522)
		vb.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/roster.tscn"))
		rp.add_child(vb)
		var pb := UIKit.ghost_button("请爵", 200, 32)
		pb.name = "PromoteOpen"
		pb.position = Vector2(16, 560)
		pb.pressed.connect(func():
			Sfx.click()
			get_tree().change_scene_to_file("res://scenes/hub/title_promote.tscn"))
		rp.add_child(pb)

	UIKit.footer_bar(self, [["A", "确认"], ["B", "返回"], ["LB/RB", "切换分区"], ["ESC", "主菜单"]], "CENTURYKNIGHTS · FROST_TACTICAL v8.6")
	_fit_narrow()
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func _go_nav(btn: Button, dest: String) -> void:
	UIFX.press_feedback(btn)
	Sfx.click()
	get_tree().change_scene_to_file(dest)

func _fit_narrow() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := HubTodo.narrow_scale(vp.x)
	scale = Vector2(s, s)

func _open_promote() -> void:
	var old := get_node_or_null("PromoteModal")
	if old:
		old.queue_free()
	var leader = GameState.get_leader()
	if leader == null:
		return
	var modal := Control.new()
	modal.name = "PromoteModal"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.z_index = 30
	add_child(modal)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.72)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			modal.queue_free())
	modal.add_child(dim)
	var host := Control.new()
	host.position = Vector2(460, 220)
	modal.add_child(host)
	CKCourt.build_promote_ui(host, leader, {}, Callable(self, "_do_promote"))

func _do_promote() -> void:
	var leader = GameState.get_leader()
	if leader == null:
		return
	var r := CKCourt.promote(leader)
	if _hint:
		_hint.text = str(r.get("msg", ""))
	var modal := get_node_or_null("PromoteModal")
	if modal:
		modal.queue_free()

func _chapter_cleared(id: int) -> bool:
	if id < 0 or GameState.story == null:
		return false
	return bool(GameState.story.flags.get("chapter%d_done" % id, false))

func _need_cleared(prev: int) -> bool:
	return prev < 0 or _chapter_cleared(prev)

func _unlocked_count() -> int:
	var k := 0
	for entry in _chapter_catalog():
		if _need_cleared(int(entry[2])):
			k += 1
	return k

func _cur_vol_label() -> String:
	if _vol_pick and _vol_pick.selected >= 0:
		return _vol_pick.get_item_text(_vol_pick.selected)
	return "卷零"

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _nav_item(idx: String, title_t: String, sub_t: String, active: bool = false, minor: bool = false, compact: bool = false) -> Button:
	## Stitch nav item: mono index (icon slot) + label; active = boxed frost; five states
	var b := Button.new()
	b.text = "%s   %s" % [idx, title_t]
	b.tooltip_text = sub_t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(134, 20 if compact else (25 if minor else 30))
	b.add_theme_font_size_override("font_size", 11 if compact else (12 if minor else 13))
	b.focus_mode = Control.FOCUS_ALL
	var mk := func(bg: Color, bd: Color, bw: int) -> StyleBoxFlat:
		var s := UIKit._btn_box(bg, bd, bw, 6)
		s.content_margin_left = 8 if compact else 10
		s.content_margin_top = 0 if compact else 3
		s.content_margin_bottom = 0 if compact else 3
		return s
	var normal: StyleBoxFlat = mk.call(Color(UIKit.ACCENT, 0.10), Color(UIKit.ACCENT, 0.75), 1) if active else mk.call(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
	if active:
		normal.shadow_color = Color(UIKit.ACCENT, 0.18)
		normal.shadow_size = 8
	UIKit._apply_states(b, {
		"normal": normal,
		"hover": mk.call(Color(UIKit.ACCENT, 0.08), Color(UIKit.ACCENT, 0.35), 1),
		"pressed": mk.call(Color(UIKit.ACCENT, 0.18), Color(UIKit.ACCENT, 0.6), 1),
		"focus": UIKit._focus_ring(UIKit.FOCUS_RING, 8),
		"disabled": mk.call(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0),
	})
	b.add_theme_color_override("font_color", UIKit.ACCENT if active else (UIKit.TEXT_FAINT if minor else UIKit.TEXT_DIM))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", UIKit.ACCENT)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", UIKit.DISABLED_TEXT)
	UIFX.wire_button(b)
	return b


func _refresh() -> void:
	if is_inside_tree() and get_node_or_null("StitchTopBar"):
		call_deferred("_build")
		return
	_rebuild_volume_picker()
	_rebuild_chapter_picker()
	_update_story_hint()

func _update_story_hint() -> void:
	var lines := _story_hint_lines()
	for i in lines.size():
		if _chapter_cleared(i):
			continue
		var line: String = lines[i]
		if i == 0:
			_story_hint.text = line % GameState.story.beat(0)
		else:
			_story_hint.text = line
		return
	if GameState.story.flags.get("volume38_mid_done", false):
		_story_hint.text = "三十八卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume37_done"):
		_story_hint.text = "三十七卷已执。可继续第三十八卷或经营。"
	elif GameState.flag("volume37_mid_done"):
		_story_hint.text = "三十七卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume36_done"):
		_story_hint.text = "三十六卷已执。可继续第三十七卷或经营。"
	elif GameState.flag("volume36_mid_done"):
		_story_hint.text = "三十六卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume35_done"):
		_story_hint.text = "三十五卷已执。可继续第三十六卷或经营。"
	elif GameState.flag("volume35_mid_done"):
		_story_hint.text = "三十五卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume34_done"):
		_story_hint.text = "三十四卷已执。可继续第三十五卷或经营。"
	elif GameState.flag("volume34_mid_done"):
		_story_hint.text = "三十四卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume33_done"):
		_story_hint.text = "三十三卷已执。可继续第三十四卷或经营。"
	elif GameState.flag("volume33_mid_done"):
		_story_hint.text = "三十三卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume32_done"):
		_story_hint.text = "三十二卷已执。可继续第三十三卷或经营。"
	elif GameState.flag("volume32_mid_done"):
		_story_hint.text = "三十二卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume31_done"):
		_story_hint.text = "三十一卷已执。可继续第三十二卷或经营。"
	elif GameState.flag("volume31_mid_done"):
		_story_hint.text = "三十一卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume30_done"):
		_story_hint.text = "三十卷已执。可继续第三十一卷或经营。"
	elif GameState.flag("volume30_mid_done"):
		_story_hint.text = "三十卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume29_done"):
		_story_hint.text = "二十九卷已执。可继续第三十卷或经营。"
	elif GameState.flag("volume29_mid_done"):
		_story_hint.text = "二十九卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume28_done"):
		_story_hint.text = "二十八卷已执。可继续第二十九卷或经营。"
	elif GameState.flag("volume28_mid_done"):
		_story_hint.text = "二十八卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume27_done"):
		_story_hint.text = "二十七卷已执。可继续第二十八卷或经营。"
	elif GameState.flag("volume27_mid_done"):
		_story_hint.text = "二十七卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume26_done"):
		_story_hint.text = "二十六卷已执。可继续第二十七卷或经营。"
	elif GameState.flag("volume26_mid_done"):
		_story_hint.text = "二十六卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume25_done"):
		_story_hint.text = "二十五卷已执。可继续第二十六卷或经营。"
	elif GameState.flag("volume25_mid_done"):
		_story_hint.text = "二十五卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume24_done"):
		_story_hint.text = "二十四卷已执。可继续第二十五卷或经营。"
	elif GameState.flag("volume24_mid_done"):
		_story_hint.text = "二十四卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume23_done"):
		_story_hint.text = "二十三卷已执。可继续第二十四卷或经营。"
	elif GameState.flag("volume23_mid_done"):
		_story_hint.text = "二十三卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume22_done"):
		_story_hint.text = "二十二卷已执。可继续第二十三卷或经营。"
	elif GameState.flag("volume22_mid_done"):
		_story_hint.text = "二十二卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume21_done"):
		_story_hint.text = "二十一卷已执。可继续第二十二卷或经营。"
	elif GameState.flag("volume21_mid_done"):
		_story_hint.text = "二十一卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume20_done"):
		_story_hint.text = "二十卷已执。可继续第二十一卷或经营。"
	elif GameState.flag("volume20_mid_done"):
		_story_hint.text = "二十卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume19_done"):
		_story_hint.text = "十九卷已执。可继续第二十卷或经营。"
	elif GameState.flag("volume19_mid_done"):
		_story_hint.text = "十九卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume18_done"):
		_story_hint.text = "十八卷已执。可继续第十九卷或经营。"
	elif GameState.flag("volume18_mid_done"):
		_story_hint.text = "十八卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume17_done"):
		_story_hint.text = "十七卷已执。可继续第十八卷或经营。"
	elif GameState.flag("volume17_mid_done"):
		_story_hint.text = "十七卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume16_done"):
		_story_hint.text = "十六卷已执。可继续第十七卷或经营。"
	elif GameState.flag("volume16_mid_done"):
		_story_hint.text = "十六卷中段已执。可继续后半或经营。"
	elif GameState.flag("volume15_done"):
		_story_hint.text = "十五卷已执。可继续第十六卷或经营。"
	elif GameState.flag("volume15_mid_done"):
		_story_hint.text = "十五卷中段已执。可继续后半或经营。"
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


func _story_hint_lines() -> Array:
	return [
		"第零章进行中：节拍 %s —— 点「第零章节拍」继续剧情",
		"第零章已完成。可点「第一章·陆桥」推进新地图战役；亦可自由经营。",
		"第一章已完成。可点「第二章·姓氏」继续主线。",
		"可点「第三章·铁祷」学习战技与转职深造。",
		"可点「第四章·百年」挑战断字关。",
		"可点「第五章·烽烟」开启王朝级战役；先升战技树二阶。",
		"可点「第六章·托孤」签署托孤之约。",
		"可点「第七章·子嗣」打响正名战。",
		"可点「第八章·港灯」签署海商盟约。",
		"可点「第九章·商路」夺回辎重。",
		"可点「第十章·回响」赴盟主宴。",
		"可点「第十一章·门阙」验旗。",
		"可点「第十二章·余波」应对朔影家夜袭。",
		"可点「第十三章·嗣位」完成对决。",
		"可点「第十四章·并席」共持火把。",
		"可点「第十五章·席散」完成第一卷终章。",
		"第二卷开启：可点「第十六章·海草」。",
		"可点「第十七章·盐河」重开盐路。",
		"可点「第十八章·门阙」写入二卷可入。",
		"第二卷后半：可点「第十九章·远岸」。",
		"可点「第二十章·潮墙」落两印。",
		"可点「第二十一章·席终」完成第二卷。",
		"第三卷开启：可点「第二十二章·北风」。",
		"可点「第二十三章·霜桥」落霜印。",
		"可点「第二十四章·钤印」完成三卷中段。",
		"第三卷后半：可点「第二十五章·朔原」。",
		"可点「第二十六章·冠雪」落两印。",
		"可点「第二十七章·席终」完成第三卷。",
		"第四卷开启：点「继续主线」或章节下拉选第二十八章·南泽。",
		"可继续第二十九章·金陌（章节下拉）。",
		"可继续第三十章·钤印（四卷中段）。",
		"第四卷后半：第三十一章·铁峡。",
		"可继续第三十二章·星津。",
		"可点继续主线赴第三十三章·四卷席终。",
		"第五卷开启：点「继续主线」选第三十四章·破晓。",
		"可继续第三十五章·晚钟。",
		"可继续第三十六章·钤印（五卷中段）。",
		"第五卷后半：点「继续主线」选第三十七章·长川。",
		"可继续第三十八章·终阙。",
		"可继续第三十九章·五卷席终。",
		"第六卷开启：点「继续主线」选第四十章·雾原。",
		"可继续第四十一章·石冢。",
		"可继续第四十二章·钤印（六卷中段）。",
		"第六卷后半：点「继续主线」或卷六选第四十三章·黑潮。",
		"可继续第四十四章·曜塔。",
		"可继续第四十五章·六卷席终。",
		"第七卷开启：点「继续主线」或卷七选第四十六章·余烬。",
		"可继续第四十七章·冠火。",
		"可继续第四十八章·钤印（七卷中段）。",
		"第七卷后半：点「继续主线」或卷七选第四十九章·烬原。",
		"可继续第五十章·百旗。",
		"可继续第五十一章·七卷席终。",
		"第八卷开启：点「继续主线」或卷八选第五十二章·破晓。",
		"可继续第五十三章·镜湖。",
		"可继续第五十四章·钤印（八卷中段）。",
		"第八卷后半：点「继续主线」或卷八选第五十五章·朔风。",
		"可继续第五十六章·曜廷。",
		"可继续第五十七章·八卷席终。",
		"第九卷开启：点「继续主线」或卷九选第五十八章·余烬港。",
		"可继续第五十九章·霜驿。",
		"可继续第六十章·九卷钤印（九卷中段）。",
		"第九卷后半：点「继续主线」或卷九选第六十一章·烬原。",
		"可继续第六十二章·曜阙。",
		"可继续第六十三章·九卷席终。",
		"第十卷·井市：点「继续主线」或卷十选第六十四章·井市。",
		"可继续第六十五章·铜铃。",
		"可继续第六十六章·井印（十卷中段）。",
		"第十卷后半：点「继续主线」或卷十选第六十七章·盐船。",
		"可继续第六十八章·纸坊。",
		"可继续第六十九章·十卷席终。",
		"第十一卷·窑火：点「继续主线」或卷十一选第七十章·窑口。",
		"可继续第七十一章·釉河。",
		"可继续第七十二章·窑印（十一卷中段）。",
		"第十一卷后半：点「继续主线」或选第七十三章·烟囱。",
		"可继续第七十四章·火塘。",
		"可继续第七十五章·十一卷席终。",
		"第十二卷·梨园：点「继续主线」或卷十二选第七十六章·台口。",
		"可继续第七十七章·检场。",
		"可继续第七十八章·戏印（十二卷中段）。",
		"第十二卷后半：点「继续主线」或卷十二选第七十九章·后台。",
		"可继续第八十章·灯架。",
		"可继续第八十一章·十二卷席终。",
		"第十三卷·蚕桑：点「继续主线」或卷十三选第八十二章·桑陌。",
		"可继续第八十三章·缫丝。",
		"可继续第八十四章·丝印（十三卷中段）。",
		"第十三卷后半：点「继续主线」或卷十三选第八十五章·烘茧。",
		"可继续第八十六章·经轴。",
		"可继续第八十七章·十三卷席终。",
		"第十四卷·茶岭：点「继续主线」或卷十四选第八十八章·茶梯。",
		"可继续第八十九章·蒸青。",
		"可继续第九十章·茶印（十四卷中段）。",
		"第十四卷后半：点「继续主线」或卷十四选第九十一章·晾青。",
		"可继续第九十二章·茶引。",
		"可继续第九十三章·十四卷席终。",
		"第十五卷·药市：点「继续主线」或卷十五选第九十四章·药圃。",
		"可继续第九十五章·医馆。",
		"可继续第九十六章·方印（十五卷中段）。",
		"第十五卷后半：点「继续主线」或卷十五选第九十七章·煎药。",
		"可继续第九十八章·医籍。",
		"可继续第九十九章·十五卷席终。",
		"第十六卷·马市：点「继续主线」或卷十六选第一百章·马厩。",
		"可继续第一百零一章·驯场。",
		"可继续第一百零二章·马印（十六卷中段）。",
		"第十六卷后半：点「继续主线」或卷十六选第一百零三章·马市。",
		"可继续第一百零四章·鞍房。",
		"可继续第一百零五章·十六卷席终。",
		"第十七卷·酒坊：点「继续主线」或卷十七选第一百零六章·曲房。",
		"可继续第一百零七章·糟坊。",
		"可继续第一百零八章·酒印（十七卷中段）。",
		"第十七卷后半：点「继续主线」或卷十七选第一百零九章·开酿。",
		"可继续第一百一十章·排档。",
		"可继续第一百一十一章·十七卷席终。",
		"第十八卷·镖行：点「继续主线」或卷十八选第一百一十二章·镖局。",
		"可继续第一百一十三章·夜营。",
		"可继续第一百一十四章·镖印（十八卷中段）。",
		"第十八卷后半：点「继续主线」或卷十八选第一百一十五章·镖市。",
		"可继续第一百一十六章·驿站。",
		"可继续第一百一十七章·十八卷席终。",
		"第十九卷·渔港：点「继续主线」或卷十九选第一百一十八章·码头。",
		"可继续第一百一十九章·潮汐。",
		"可继续第一百二十章·港印（十九卷中段）。",
		"第十九卷后半：点「继续主线」或卷十九选第一百二十一章·渔市。",
		"可继续第一百二十二章·货栈。",
		"可继续第一百二十三章·十九卷席终。",
		"第二十卷·纸坊：点「继续主线」或卷二十选第一百二十四章·纸坊。",
		"可继续第一百二十五章·抄帘。",
		"可继续第一百二十六章·纸印（二十卷中段）。",
		"第二十卷后半：点「继续主线」或卷二十选第一百二十七章·压榨。",
		"可继续第一百二十八章·案库。",
		"可继续第一百二十九章·二十卷席终。",
		"第二十一卷·铜市：点「继续主线」或卷二十一选第一百三十章·铜炉。",
		"可继续第一百三十一章·砧台。",
		"可继续第一百三十二章·铜印（二十一卷中段）。",
		"第二十一卷后半：点「继续主线」或卷二十一选第一百三十三章·铜市。",
		"可继续第一百三十四章·甲库。",
		"可继续第一百三十五章·二十一卷席终。",
		"第二十二卷·灯市：点「继续主线」或卷二十二选第一百三十六章·灯街。",
		"可继续第一百三十七章·灯棚。",
		"可继续第一百三十八章·灯印（二十二卷中段）。",
		"第二十二卷后半：点「继续主线」或卷二十二选第一百三十九章·灯会。",
		"可继续第一百四十章·灯塔。",
		"可继续第一百四十一章·二十二卷席终。",
		"第二十三卷·粮仓：点「继续主线」或卷二十三选第一百四十二章·粮囤。",
		"可继续第一百四十三章·仓房。",
		"可继续第一百四十四章·粮印（二十三卷中段）。",
		"第二十三卷后半：点「继续主线」或卷二十三选第一百四十五章·开仓。",
		"可继续第一百四十六章·义仓。",
		"可继续第一百四十七章·二十三卷席终。",
		"第二十四卷·雪栈：点「继续主线」或卷二十四选第一百四十八章·雪栈。",
		"可继续第一百四十九章·冰窖。",
		"可继续第一百五十章·雪印（二十四卷中段）。",
		"第二十四卷后半：点「继续主线」或卷二十四选第一百五十一章·雪市。",
		"可继续第一百五十二章·暖驿。",
		"可继续第一百五十三章·二十四卷席终。",
		"第二十五卷·竹海：点「继续主线」或卷二十五选第一百五十四章·竹海。",
		"可继续第一百五十五章·笋市。",
		"可继续第一百五十六章·竹印（二十五卷中段）。",
		"第二十五卷后半：点「继续主线」或卷二十五选第一百五十七章·竹市。",
		"可继续第一百五十八章·篁祠。",
		"可继续第一百五十九章·二十五卷席终。",
		"第二十六卷·驿道：点「继续主线」或卷二十六选第一百六十章·驿站。",
		"可继续第一百六十一章·急递。",
		"可继续第一百六十二章·驿印（二十六卷中段）。",
		"第二十六卷后半：点「继续主线」或卷二十六选第一百六十三章·驿市。",
		"可继续第一百六十四章·夜驿。",
		"可继续第一百六十五章·二十六卷席终。",
		"第二十七卷·钟鼓：点「继续主线」或卷二十七选第一百六十六章·钟楼。",
		"可继续第一百六十七章·守钟。",
		"可继续第一百六十八章·钟印（二十七卷中段）。",
		"第二十七卷后半：点「继续主线」或卷二十七选第一百六十九章·钟市。",
		"可继续第一百七十章·撞钟。",
		"可继续第一百七十一章·二十七卷席终。",
		"第二十八卷·雨巷：点「继续主线」或卷二十八选第一百七十二章·雨巷。",
		"可继续第一百七十三章·伞棚。",
		"可继续第一百七十四章·雨印（二十八卷中段）。",
		"第二十八卷后半：点「继续主线」或卷二十八选第一百七十五章·雨市。",
		"可继续第一百七十六章·避雨。",
		"可继续第一百七十七章·二十八卷席终。",
		"第二十九卷·砚市：点「继续主线」或卷二十九选第一百七十八章·砚坑。",
		"可继续第一百七十九章·案台。",
		"可继续第一百八十章·砚印（二十九卷中段）。",
		"第二十九卷后半：点「继续主线」或卷二十九选第一百八十一章·砚市。",
		"可继续第一百八十二章·捺印。",
		"可继续第一百八十三章·二十九卷席终。",
		"第三十卷·蜂场：点「继续主线」或卷三十选第一百八十四章·蜂巢。",
		"可继续第一百八十五章·烟熏。",
		"可继续第一百八十六章·蜂印（三十卷中段）。",
		"第三十卷后半：点「继续主线」或卷三十选第一百八十七章·蜜市。",
		"可继续第一百八十八章·蜂后。",
		"可继续第一百八十九章·三十卷席终。",
		"第三十一卷·笛楼：点「继续主线」或卷三十一选第一百九十章·笛楼。",
		"可继续第一百九十一章·回音。",
		"可继续第一百九十二章·笛印（三十一卷中段）。",
		"第三十一卷后半：点「继续主线」或卷三十一选第一百九十三章·笛市。",
		"可继续第一百九十四章·独奏。",
		"可继续第一百九十五章·三十一卷席终。",
		"第三十二卷·影戏：点「继续主线」或卷三十二选第一百九十六章·影幕。",
		"可继续第一百九十七章·灯影。",
		"可继续第一百九十八章·影印（三十二卷中段）。",
		"第三十二卷后半：点「继续主线」或卷三十二选第一百九十九章·影市。",
		"可继续第二百章·独影。",
		"可继续第二百零一章·三十二卷席终。",
		"第三十三卷·盐滩：点「继续主线」或卷三十三选第二百零二章·盐滩。",
		"可继续第二百零三章·盐堆。",
		"可继续第二百零四章·盐印（三十三卷中段）。",
		"第三十三卷后半：点「继续主线」或卷三十三选第二百零五章·盐市。",
		"可继续第二百零六章·独晒。",
		"可继续第二百零七章·三十三卷席终。",
		"第三十四卷·染坊：点「继续主线」或卷三十四选第二百零八章·染坊。",
		"可继续第二百零九章·晾竿。",
		"可继续第二百一十章·染印（三十四卷中段）。",
		"第三十四卷后半：点「继续主线」或卷三十四选第二百一十一章·色市。",
		"可继续第二百一十二章·独染。",
		"可继续第二百一十三章·三十四卷席终。",
		"第三十五卷·鼓楼：点「继续主线」或卷三十五选第二百一十四章·鼓楼。",
		"可继续第二百一十五章·擂台。",
		"可继续第二百一十六章·鼓印（三十五卷中段）。",
		"第三十五卷后半：点「继续主线」或卷三十五选第二百一十七章·鼓市。",
		"可继续第二百一十八章·独擂。",
		"可继续第二百一十九章·三十五卷席终。",
		"第三十六卷·香市：点「继续主线」或卷三十六选第二百二十章·香市。",
		"可继续第二百二十一章·烟径。",
		"可继续第二百二十二章·香印（三十六卷中段）。",
		"第三十六卷后半：点「继续主线」或卷三十六选第二百二十三章·香摊。",
		"可继续第二百二十四章·独香。",
		"可继续第二百二十五章·三十六卷席终。",
		"第三十七卷·潮汐：点「继续主线」或卷三十七选第二百二十六章·潮滩。",
		"可继续第二百二十七章·礁脉。",
		"可继续第二百二十八章·潮印（三十七卷中段）。",
		"第三十七卷后半：点「继续主线」或卷三十七选第二百二十九章·潮市。",
		"可继续第二百三十章·独潮。",
		"可继续第二百三十一章·三十七卷席终。",
		"第三十八卷·瓷市：点「继续主线」或卷三十八选第二百三十二章·瓷市。",
		"可继续第二百三十三章·釉池。",
		"可继续第二百三十四章·瓷印（三十八卷中段）。",
	]

func _chapter_catalog() -> Array:
	# [label, scene, unlock_flag, volume_index]
	return [
		["第零章", "res://scenes/story/chapter0.tscn", -1, 0],
		["第一章·陆桥", "res://scenes/story/chapter1.tscn", 0, 1],
		["第二章·姓氏", "res://scenes/story/chapter2.tscn", 1, 1],
		["第三章·铁祷", "res://scenes/story/chapter3.tscn", 2, 1],
		["第四章·百年", "res://scenes/story/chapter4.tscn", 3, 1],
		["第五章·烽烟", "res://scenes/story/chapter5.tscn", 4, 1],
		["第六章·托孤", "res://scenes/story/chapter6.tscn", 5, 1],
		["第七章·子嗣", "res://scenes/story/chapter7.tscn", 6, 1],
		["第八章·港灯", "res://scenes/story/chapter8.tscn", 7, 1],
		["第九章·商路", "res://scenes/story/chapter9.tscn", 8, 1],
		["第十章·回响", "res://scenes/story/chapter10.tscn", 9, 1],
		["第十一章·门阙", "res://scenes/story/chapter11.tscn", 10, 1],
		["第十二章·余波", "res://scenes/story/chapter12.tscn", 11, 1],
		["第十三章·嗣位", "res://scenes/story/chapter13.tscn", 12, 1],
		["第十四章·并席", "res://scenes/story/chapter14.tscn", 13, 1],
		["第十五章·席散", "res://scenes/story/chapter15.tscn", 14, 1],
		["第十六章·海草", "res://scenes/story/chapter16.tscn", 15, 2],
		["第十七章·盐河", "res://scenes/story/chapter17.tscn", 16, 2],
		["第十八章·门阙", "res://scenes/story/chapter18.tscn", 17, 2],
		["第十九章·远岸", "res://scenes/story/chapter19.tscn", 18, 2],
		["第二十章·潮墙", "res://scenes/story/chapter20.tscn", 19, 2],
		["第二十一章·席终", "res://scenes/story/chapter21.tscn", 20, 2],
		["第二十二章·北风", "res://scenes/story/chapter22.tscn", 21, 3],
		["第二十三章·霜桥", "res://scenes/story/chapter23.tscn", 22, 3],
		["第二十四章·钤印", "res://scenes/story/chapter24.tscn", 23, 3],
		["第二十五章·朔原", "res://scenes/story/chapter25.tscn", 24, 3],
		["第二十六章·冠雪", "res://scenes/story/chapter26.tscn", 25, 3],
		["第二十七章·席终", "res://scenes/story/chapter27.tscn", 26, 3],
		["第二十八章·南泽", "res://scenes/story/chapter28.tscn", 27, 4],
		["第二十九章·金陌", "res://scenes/story/chapter29.tscn", 28, 4],
		["第三十章·钤印", "res://scenes/story/chapter30.tscn", 29, 4],
		["第三十一章·铁峡", "res://scenes/story/chapter31.tscn", 30, 4],
		["第三十二章·星津", "res://scenes/story/chapter32.tscn", 31, 4],
		["第三十三章·席终", "res://scenes/story/chapter33.tscn", 32, 4],
		["第三十四章·破晓", "res://scenes/story/chapter34.tscn", 33, 5],
		["第三十五章·晚钟", "res://scenes/story/chapter35.tscn", 34, 5],
		["第三十六章·钤印", "res://scenes/story/chapter36.tscn", 35, 5],
		["第三十七章·长川", "res://scenes/story/chapter37.tscn", 36, 5],
		["第三十八章·终阙", "res://scenes/story/chapter38.tscn", 37, 5],
		["第三十九章·席终", "res://scenes/story/chapter39.tscn", 38, 5],
		["第四十章·雾原", "res://scenes/story/chapter40.tscn", 39, 6],
		["第四十一章·石冢", "res://scenes/story/chapter41.tscn", 40, 6],
		["第四十二章·钤印", "res://scenes/story/chapter42.tscn", 41, 6],
		["第四十三章·黑潮", "res://scenes/story/chapter43.tscn", 42, 6],
		["第四十四章·曜塔", "res://scenes/story/chapter44.tscn", 43, 6],
		["第四十五章·席终", "res://scenes/story/chapter45.tscn", 44, 6],
		["第四十六章·余烬", "res://scenes/story/chapter46.tscn", 45, 7],
		["第四十七章·冠火", "res://scenes/story/chapter47.tscn", 46, 7],
		["第四十八章·钤印", "res://scenes/story/chapter48.tscn", 47, 7],
		["第四十九章·烬原", "res://scenes/story/chapter49.tscn", 48, 7],
		["第五十章·百旗", "res://scenes/story/chapter50.tscn", 49, 7],
		["第五十一章·席终", "res://scenes/story/chapter51.tscn", 50, 7],
		["第五十二章·破晓", "res://scenes/story/chapter52.tscn", 51, 8],
		["第五十三章·镜湖", "res://scenes/story/chapter53.tscn", 52, 8],
		["第五十四章·钤印", "res://scenes/story/chapter54.tscn", 53, 8],
		["第五十五章·朔风", "res://scenes/story/chapter55.tscn", 54, 8],
		["第五十六章·曜廷", "res://scenes/story/chapter56.tscn", 55, 8],
		["第五十七章·席终", "res://scenes/story/chapter57.tscn", 56, 8],
		["第五十八章·余烬港", "res://scenes/story/chapter58.tscn", 57, 9],
		["第五十九章·霜驿", "res://scenes/story/chapter59.tscn", 58, 9],
		["第六十章·钤印", "res://scenes/story/chapter60.tscn", 59, 9],
		["第六十一章·烬原", "res://scenes/story/chapter61.tscn", 60, 9],
		["第六十二章·曜阙", "res://scenes/story/chapter62.tscn", 61, 9],
		["第六十三章·席终", "res://scenes/story/chapter63.tscn", 62, 9],
		["第六十四章·井市", "res://scenes/story/chapter64.tscn", 63, 10],
		["第六十五章·铜铃", "res://scenes/story/chapter65.tscn", 64, 10],
		["第六十六章·井印", "res://scenes/story/chapter66.tscn", 65, 10],
		["第六十七章·盐船", "res://scenes/story/chapter67.tscn", 66, 10],
		["第六十八章·纸坊", "res://scenes/story/chapter68.tscn", 67, 10],
		["第六十九章·席终", "res://scenes/story/chapter69.tscn", 68, 10],
		["第七十章·窑口", "res://scenes/story/chapter70.tscn", 69, 11],
		["第七十一章·釉河", "res://scenes/story/chapter71.tscn", 70, 11],
		["第七十二章·窑印", "res://scenes/story/chapter72.tscn", 71, 11],
		["第七十三章·烟囱", "res://scenes/story/chapter73.tscn", 72, 11],
		["第七十四章·火塘", "res://scenes/story/chapter74.tscn", 73, 11],
		["第七十五章·席终", "res://scenes/story/chapter75.tscn", 74, 11],
		["第七十六章·台口", "res://scenes/story/chapter76.tscn", 75, 12],
		["第七十七章·检场", "res://scenes/story/chapter77.tscn", 76, 12],
		["第七十八章·戏印", "res://scenes/story/chapter78.tscn", 77, 12],
		["第七十九章·后台", "res://scenes/story/chapter79.tscn", 78, 12],
		["第八十章·灯架", "res://scenes/story/chapter80.tscn", 79, 12],
		["第八十一章·席终", "res://scenes/story/chapter81.tscn", 80, 12],
		["第八十二章·桑陌", "res://scenes/story/chapter82.tscn", 81, 13],
		["第八十三章·缫丝", "res://scenes/story/chapter83.tscn", 82, 13],
		["第八十四章·丝印", "res://scenes/story/chapter84.tscn", 83, 13],
		["第八十五章·烘茧", "res://scenes/story/chapter85.tscn", 84, 13],
		["第八十六章·经轴", "res://scenes/story/chapter86.tscn", 85, 13],
		["第八十七章·席终", "res://scenes/story/chapter87.tscn", 86, 13],
		["第八十八章·茶梯", "res://scenes/story/chapter88.tscn", 87, 14],
		["第八十九章·蒸青", "res://scenes/story/chapter89.tscn", 88, 14],
		["第九十章·茶印", "res://scenes/story/chapter90.tscn", 89, 14],
		["第九十一章·晾青", "res://scenes/story/chapter91.tscn", 90, 14],
		["第九十二章·茶引", "res://scenes/story/chapter92.tscn", 91, 14],
		["第九十三章·席终", "res://scenes/story/chapter93.tscn", 92, 14],
		["第九十四章·药圃", "res://scenes/story/chapter94.tscn", 93, 15],
		["第九十五章·医馆", "res://scenes/story/chapter95.tscn", 94, 15],
		["第九十六章·方印", "res://scenes/story/chapter96.tscn", 95, 15],
		["第九十七章·煎药", "res://scenes/story/chapter97.tscn", 96, 15],
		["第九十八章·医籍", "res://scenes/story/chapter98.tscn", 97, 15],
		["第九十九章·席终", "res://scenes/story/chapter99.tscn", 98, 15],
		["第一百章·马厩", "res://scenes/story/chapter100.tscn", 99, 16],
		["第一百零一章·驯场", "res://scenes/story/chapter101.tscn", 100, 16],
		["第一百零二章·马印", "res://scenes/story/chapter102.tscn", 101, 16],
		["第一百零三章·马市", "res://scenes/story/chapter103.tscn", 102, 16],
		["第一百零四章·鞍房", "res://scenes/story/chapter104.tscn", 103, 16],
		["第一百零五章·席终", "res://scenes/story/chapter105.tscn", 104, 16],
		["第一百零六章·曲房", "res://scenes/story/chapter106.tscn", 105, 17],
		["第一百零七章·糟坊", "res://scenes/story/chapter107.tscn", 106, 17],
		["第一百零八章·酒印", "res://scenes/story/chapter108.tscn", 107, 17],
		["第一百零九章·开酿", "res://scenes/story/chapter109.tscn", 108, 17],
		["第一百一十章·排档", "res://scenes/story/chapter110.tscn", 109, 17],
		["第一百一十一章·席终", "res://scenes/story/chapter111.tscn", 110, 17],
		["第一百一十二章·镖局", "res://scenes/story/chapter112.tscn", 111, 18],
		["第一百一十三章·夜营", "res://scenes/story/chapter113.tscn", 112, 18],
		["第一百一十四章·镖印", "res://scenes/story/chapter114.tscn", 113, 18],
		["第一百一十五章·镖市", "res://scenes/story/chapter115.tscn", 114, 18],
		["第一百一十六章·驿站", "res://scenes/story/chapter116.tscn", 115, 18],
		["第一百一十七章·席终", "res://scenes/story/chapter117.tscn", 116, 18],
		["第一百一十八章·码头", "res://scenes/story/chapter118.tscn", 117, 19],
		["第一百一十九章·潮汐", "res://scenes/story/chapter119.tscn", 118, 19],
		["第一百二十章·港印", "res://scenes/story/chapter120.tscn", 119, 19],
		["第一百二十一章·渔市", "res://scenes/story/chapter121.tscn", 120, 19],
		["第一百二十二章·货栈", "res://scenes/story/chapter122.tscn", 121, 19],
		["第一百二十三章·席终", "res://scenes/story/chapter123.tscn", 122, 19],
		["第一百二十四章·纸坊", "res://scenes/story/chapter124.tscn", 123, 20],
		["第一百二十五章·抄帘", "res://scenes/story/chapter125.tscn", 124, 20],
		["第一百二十六章·纸印", "res://scenes/story/chapter126.tscn", 125, 20],
		["第一百二十七章·压榨", "res://scenes/story/chapter127.tscn", 126, 20],
		["第一百二十八章·案库", "res://scenes/story/chapter128.tscn", 127, 20],
		["第一百二十九章·席终", "res://scenes/story/chapter129.tscn", 128, 20],
		["第一百三十章·铜炉", "res://scenes/story/chapter130.tscn", 129, 21],
		["第一百三十一章·砧台", "res://scenes/story/chapter131.tscn", 130, 21],
		["第一百三十二章·铜印", "res://scenes/story/chapter132.tscn", 131, 21],
		["第一百三十三章·铜市", "res://scenes/story/chapter133.tscn", 132, 21],
		["第一百三十四章·甲库", "res://scenes/story/chapter134.tscn", 133, 21],
		["第一百三十五章·席终", "res://scenes/story/chapter135.tscn", 134, 21],
		["第一百三十六章·灯街", "res://scenes/story/chapter136.tscn", 135, 22],
		["第一百三十七章·灯棚", "res://scenes/story/chapter137.tscn", 136, 22],
		["第一百三十八章·灯印", "res://scenes/story/chapter138.tscn", 137, 22],
		["第一百三十九章·灯会", "res://scenes/story/chapter139.tscn", 138, 22],
		["第一百四十章·灯塔", "res://scenes/story/chapter140.tscn", 139, 22],
		["第一百四十一章·席终", "res://scenes/story/chapter141.tscn", 140, 22],
		["第一百四十二章·粮囤", "res://scenes/story/chapter142.tscn", 141, 23],
		["第一百四十三章·仓房", "res://scenes/story/chapter143.tscn", 142, 23],
		["第一百四十四章·粮印", "res://scenes/story/chapter144.tscn", 143, 23],
		["第一百四十五章·开仓", "res://scenes/story/chapter145.tscn", 144, 23],
		["第一百四十六章·义仓", "res://scenes/story/chapter146.tscn", 145, 23],
		["第一百四十七章·席终", "res://scenes/story/chapter147.tscn", 146, 23],
		["第一百四十八章·雪栈", "res://scenes/story/chapter148.tscn", 147, 24],
		["第一百四十九章·冰窖", "res://scenes/story/chapter149.tscn", 148, 24],
		["第一百五十章·雪印", "res://scenes/story/chapter150.tscn", 149, 24],
		["第一百五十一章·雪市", "res://scenes/story/chapter151.tscn", 150, 24],
		["第一百五十二章·暖驿", "res://scenes/story/chapter152.tscn", 151, 24],
		["第一百五十三章·席终", "res://scenes/story/chapter153.tscn", 152, 24],
		["第一百五十四章·竹海", "res://scenes/story/chapter154.tscn", 153, 25],
		["第一百五十五章·笋市", "res://scenes/story/chapter155.tscn", 154, 25],
		["第一百五十六章·竹印", "res://scenes/story/chapter156.tscn", 155, 25],
		["第一百五十七章·竹市", "res://scenes/story/chapter157.tscn", 156, 25],
		["第一百五十八章·篁祠", "res://scenes/story/chapter158.tscn", 157, 25],
		["第一百五十九章·席终", "res://scenes/story/chapter159.tscn", 158, 25],
		["第一百六十章·驿站", "res://scenes/story/chapter160.tscn", 159, 26],
		["第一百六十一章·急递", "res://scenes/story/chapter161.tscn", 160, 26],
		["第一百六十二章·驿印", "res://scenes/story/chapter162.tscn", 161, 26],
		["第一百六十三章·驿市", "res://scenes/story/chapter163.tscn", 162, 26],
		["第一百六十四章·夜驿", "res://scenes/story/chapter164.tscn", 163, 26],
		["第一百六十五章·席终", "res://scenes/story/chapter165.tscn", 164, 26],
		["第一百六十六章·钟楼", "res://scenes/story/chapter166.tscn", 165, 27],
		["第一百六十七章·守钟", "res://scenes/story/chapter167.tscn", 166, 27],
		["第一百六十八章·钟印", "res://scenes/story/chapter168.tscn", 167, 27],
		["第一百六十九章·钟市", "res://scenes/story/chapter169.tscn", 168, 27],
		["第一百七十章·撞钟", "res://scenes/story/chapter170.tscn", 169, 27],
		["第一百七十一章·席终", "res://scenes/story/chapter171.tscn", 170, 27],
		["第一百七十二章·雨巷", "res://scenes/story/chapter172.tscn", 171, 28],
		["第一百七十三章·伞棚", "res://scenes/story/chapter173.tscn", 172, 28],
		["第一百七十四章·雨印", "res://scenes/story/chapter174.tscn", 173, 28],
		["第一百七十五章·雨市", "res://scenes/story/chapter175.tscn", 174, 28],
		["第一百七十六章·避雨", "res://scenes/story/chapter176.tscn", 175, 28],
		["第一百七十七章·席终", "res://scenes/story/chapter177.tscn", 176, 28],
		["第一百七十八章·砚坑", "res://scenes/story/chapter178.tscn", 177, 29],
		["第一百七十九章·案台", "res://scenes/story/chapter179.tscn", 178, 29],
		["第一百八十章·砚印", "res://scenes/story/chapter180.tscn", 179, 29],
		["第一百八十一章·砚市", "res://scenes/story/chapter181.tscn", 180, 29],
		["第一百八十二章·捺印", "res://scenes/story/chapter182.tscn", 181, 29],
		["第一百八十三章·席终", "res://scenes/story/chapter183.tscn", 182, 29],
		["第一百八十四章·蜂巢", "res://scenes/story/chapter184.tscn", 183, 30],
		["第一百八十五章·烟熏", "res://scenes/story/chapter185.tscn", 184, 30],
		["第一百八十六章·蜂印", "res://scenes/story/chapter186.tscn", 185, 30],
		["第一百八十七章·蜜市", "res://scenes/story/chapter187.tscn", 186, 30],
		["第一百八十八章·蜂后", "res://scenes/story/chapter188.tscn", 187, 30],
		["第一百八十九章·席终", "res://scenes/story/chapter189.tscn", 188, 30],
		["第一百九十章·笛楼", "res://scenes/story/chapter190.tscn", 189, 31],
		["第一百九十一章·回音", "res://scenes/story/chapter191.tscn", 190, 31],
		["第一百九十二章·笛印", "res://scenes/story/chapter192.tscn", 191, 31],
		["第一百九十三章·笛市", "res://scenes/story/chapter193.tscn", 192, 31],
		["第一百九十四章·独奏", "res://scenes/story/chapter194.tscn", 193, 31],
		["第一百九十五章·席终", "res://scenes/story/chapter195.tscn", 194, 31],
		["第一百九十六章·影幕", "res://scenes/story/chapter196.tscn", 195, 32],
		["第一百九十七章·灯影", "res://scenes/story/chapter197.tscn", 196, 32],
		["第一百九十八章·影印", "res://scenes/story/chapter198.tscn", 197, 32],
		["第一百九十九章·影市", "res://scenes/story/chapter199.tscn", 198, 32],
		["第二百章·独影", "res://scenes/story/chapter200.tscn", 199, 32],
		["第二百零一章·席终", "res://scenes/story/chapter201.tscn", 200, 32],
		["第二百零二章·盐滩", "res://scenes/story/chapter202.tscn", 201, 33],
		["第二百零三章·盐堆", "res://scenes/story/chapter203.tscn", 202, 33],
		["第二百零四章·盐印", "res://scenes/story/chapter204.tscn", 203, 33],
		["第二百零五章·盐市", "res://scenes/story/chapter205.tscn", 204, 33],
		["第二百零六章·独晒", "res://scenes/story/chapter206.tscn", 205, 33],
		["第二百零七章·席终", "res://scenes/story/chapter207.tscn", 206, 33],
		["第二百零八章·染坊", "res://scenes/story/chapter208.tscn", 207, 34],
		["第二百零九章·晾竿", "res://scenes/story/chapter209.tscn", 208, 34],
		["第二百一十章·染印", "res://scenes/story/chapter210.tscn", 209, 34],
		["第二百一十一章·色市", "res://scenes/story/chapter211.tscn", 210, 34],
		["第二百一十二章·独染", "res://scenes/story/chapter212.tscn", 211, 34],
		["第二百一十三章·席终", "res://scenes/story/chapter213.tscn", 212, 34],
		["第二百一十四章·鼓楼", "res://scenes/story/chapter214.tscn", 213, 35],
		["第二百一十五章·擂台", "res://scenes/story/chapter215.tscn", 214, 35],
		["第二百一十六章·鼓印", "res://scenes/story/chapter216.tscn", 215, 35],
		["第二百一十七章·鼓市", "res://scenes/story/chapter217.tscn", 216, 35],
		["第二百一十八章·独擂", "res://scenes/story/chapter218.tscn", 217, 35],
		["第二百一十九章·席终", "res://scenes/story/chapter219.tscn", 218, 35],
		["第二百二十章·香市", "res://scenes/story/chapter220.tscn", 219, 36],
		["第二百二十一章·烟径", "res://scenes/story/chapter221.tscn", 220, 36],
		["第二百二十二章·香印", "res://scenes/story/chapter222.tscn", 221, 36],
		["第二百二十三章·香摊", "res://scenes/story/chapter223.tscn", 222, 36],
		["第二百二十四章·独香", "res://scenes/story/chapter224.tscn", 223, 36],
		["第二百二十五章·席终", "res://scenes/story/chapter225.tscn", 224, 36],
		["第二百二十六章·潮滩", "res://scenes/story/chapter226.tscn", 225, 37],
		["第二百二十七章·礁脉", "res://scenes/story/chapter227.tscn", 226, 37],
		["第二百二十八章·潮印", "res://scenes/story/chapter228.tscn", 227, 37],
		["第二百二十九章·潮市", "res://scenes/story/chapter229.tscn", 228, 37],
		["第二百三十章·独潮", "res://scenes/story/chapter230.tscn", 229, 37],
		["第二百三十一章·席终", "res://scenes/story/chapter231.tscn", 230, 37],
		["第二百三十二章·瓷市", "res://scenes/story/chapter232.tscn", 231, 38],
		["第二百三十三章·釉池", "res://scenes/story/chapter233.tscn", 232, 38],
		["第二百三十四章·瓷印", "res://scenes/story/chapter234.tscn", 233, 38],
	]

func _volume_labels() -> Array:
	return ["卷零", "卷一", "卷二", "卷三", "卷四", "卷五", "卷六", "卷七", "卷八", "卷九", "卷十", "卷十一", "卷十二", "卷十三", "卷十四", "卷十五", "卷十六", "卷十七", "卷十八", "卷十九", "卷二十", "卷二十一", "卷二十二", "卷二十三", "卷二十四", "卷二十五", "卷二十六", "卷二十七", "卷二十八", "卷二十九", "卷三十", "卷三十一", "卷三十二", "卷三十三", "卷三十四", "卷三十五", "卷三十六", "卷三十七", "卷三十八"]

func _volume_unlocked(vol: int) -> bool:
	# a volume is unlocked if any chapter in it is unlocked
	for entry in _chapter_catalog():
		if int(entry[3]) != vol:
			continue
		if _need_cleared(int(entry[2])):
			return true
	return false

func _rebuild_volume_picker() -> void:
	if _vol_pick == null:
		return
	_vol_pick.clear()
	var prefer := 0
	for v in range(_volume_labels().size()):
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
			var unlocked = _need_cleared(int(entry[2]))
			if unlocked and bn.is_valid_int() and not _chapter_cleared(int(bn)):
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
		var unlocked = _need_cleared(int(entry[2]))
		if not unlocked:
			continue
		_chapter_pick.add_item(label)
		_chapter_paths.append(path)
		var bn = path.get_file().replace(".tscn", "").replace("chapter", "")
		if bn.is_valid_int() and not _chapter_cleared(int(bn)):
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
		var unlocked = _need_cleared(int(entry[2]))
		if not unlocked:
			continue
		last_path = path
		var bn = path.get_file().replace(".tscn", "").replace("chapter", "")
		if bn.is_valid_int() and not _chapter_cleared(int(bn)):
			get_tree().change_scene_to_file(path)
			return
	if last_path != "":
		get_tree().change_scene_to_file(last_path)


func panel_button_labels() -> Array:
	var out: Array = []
	var g := get_node_or_null("NavRail")
	if g:
		_collect_labels(g, out)
	return out

func _collect_labels(n: Node, out: Array) -> void:
	for b in n.get_children():
		if b is BaseButton:
			out.append(str(b.get_meta("legacy_label", str(b.text).split("\n")[0])))
		_collect_labels(b, out)
