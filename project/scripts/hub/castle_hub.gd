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
	var house := Locale.latin(str(GameState.surname), "House")
	var tb := UIKit.top_bar(self, Locale.t("shell_c84f88cd") % house, UIKit.std_resource_chips(), Locale.t("shell_8112901e"), func():
		GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	_res_bar = HBoxContainer.new()   # kept for _refresh compatibility (resource tick)
	_res_bar.visible = false
	add_child(_res_bar)
	var right_box: HBoxContainer = tb.get_child(tb.get_child_count() - 1)
	var save_b := UIKit.ghost_button(Locale.t("shell_40e191bd"), 64, 32)
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
			[Locale.t("shell_15c92308"), DeployBrief.cap_line(), "res://scenes/hub/deploy.tscn", Locale.t("btn_deploy"), "deploy"],
			[Locale.t("btn_train"), Locale.t("shell_0cb33307"), "res://scenes/hub/train.tscn", Locale.t("btn_train"), "train"],
			[Locale.t("shell_5366fd25"), Locale.t("shell_1f6a2fed"), "res://scenes/hub/skill_tree.tscn", Locale.t("shell_5366fd25"), "skills"],
		]},
		{"id": "civil", "title": Locale.t("ux_hub_civil"), "items": [
			[Locale.t("btn_tavern"), Locale.t("shell_74f80552"), "res://scenes/hub/tavern.tscn", Locale.t("btn_tavern"), "tavern"],
			[Locale.t("btn_forge"), Locale.t("shell_a07db291"), "res://scenes/hub/forge.tscn", Locale.t("btn_forge"), "forge"],
			[Locale.t("btn_market"), Locale.t("shell_55dea989"), "res://scenes/hub/market.tscn", Locale.t("btn_market"), "market"],
			[Locale.t("shell_8d3d6c29"), Locale.t("shell_be28a894"), "res://scenes/hub/estates.tscn", Locale.t("shell_8d3d6c29"), "estates"],
			[Locale.t("btn_quests"), Locale.t("shell_5d2cf665"), "res://scenes/hub/quests.tscn", Locale.t("btn_quests"), "quests"],
			[Locale.t("shell_d0d30beb"), Locale.t("shell_7dea5328"), "res://scenes/hub/works.tscn", Locale.t("shell_d0d30beb"), "works"],
		]},
		{"id": "family", "title": Locale.t("ux_hub_family"), "items": [
			[Locale.t("btn_roster"), Locale.t("shell_f0ea80bf"), "res://scenes/hub/roster.tscn", Locale.t("btn_roster"), "roster"],
			[Locale.t("btn_shrine"), Locale.t("shell_f7881394"), "res://scenes/hub/shrine.tscn", Locale.t("btn_shrine"), "shrine"],
			[Locale.t("btn_marriage"), Locale.t("shell_f075f209"), "res://scenes/hub/marriage.tscn", Locale.t("btn_marriage"), "marriage"],
			[Locale.t("btn_lineage"), Locale.t("shell_a675f919"), "res://scenes/hub/lineage_view.tscn", Locale.t("btn_lineage"), "lineage"],
			[Locale.t("shell_dcb83d03"), Locale.t("shell_92bb4d72"), "res://scenes/hub/lineage_rite.tscn", Locale.t("shell_dcb83d03"), "rite"],
		]},
		{"id": "court", "title": Locale.t("ux_hub_court"), "items": [
			[Locale.t("btn_hourglass"), Locale.t("shell_05820eaa"), "res://scenes/hub/hourglass.tscn", Locale.t("btn_hourglass"), "hourglass"],
			[Locale.t("shell_7debf9cb"), Locale.t("shell_2155ceaf"), "res://scenes/ui/settings.tscn", Locale.t("shell_7debf9cb"), "settings"],
		]},
		{"id": "atlas", "title": Locale.t("ux_hub_atlas"), "items": [
			[Locale.t("shell_26a377a3"), Locale.t("shell_8a91fe2c"), "res://scenes/hub/atlas_view.tscn", Locale.t("shell_26a377a3"), "atlas"],
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
	var ct := UIKit.title_label(Locale.t("shell_b69fd89f"), 28)
	ct.position = Vector2(26, 38)
	cp.add_child(ct)
	var meta := UIKit.mono("ENTRY 01-03 / 03 PENDING", 10, UIKit.TEXT_DIM)
	meta.position = Vector2(794 - meta.get_minimum_size().x, 24)
	cp.add_child(meta)
	var meta2 := UIKit.body_label(Locale.t("shell_d9f64f13") % [Calendar.label(), Locale.latin(str(GameState.surname), "House")], UIKit.TEXT_FAINT, 11)
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
		{"tag": Locale.t("shell_1c7432f9"), "col": UIKit.DANGER, "id": "# 01", "title": Locale.t("shell_830b485d"), "desc": _story_hint.text,
		 "kv": [[Locale.t("shell_a21ba281"), _cur_vol_label(), UIKit.TEXT], [Locale.t("shell_e6247ac7"), Locale.t("shell_71e987bf") % _unlocked_count(), UIKit.ACCENT]],
		 "act": Locale.t("shell_e4492ae0"), "cb": Callable(self, "_continue_mainline")},
		{"tag": Locale.t("shell_0295ed30"), "col": UIKit.ACCENT, "id": "# 02", "title": Locale.t("shell_d50391de"), "desc": Locale.t("shell_bd1759e1"),
		 "kv": [[Locale.t("shell_5cda5bb8"), Locale.t("shell_445ffb2d") % roster_n, UIKit.TEXT], [Locale.t("shell_946c7148"), str(GameState.silver), UIKit.ACCENT]],
		 "act": Locale.t("shell_4f21c510"), "cb": func(): get_tree().change_scene_to_file("res://scenes/hub/tavern.tscn")},
		{"tag": Locale.t("shell_0ea8299b"), "col": UIKit.OK, "id": "# 03", "title": Locale.t("shell_994ca053"), "desc": Locale.t("shell_ccb1cfc4"),
		 "kv": [[Locale.t("shell_9466cac8"), Locale.t("shell_9219bb7b") % wed, UIKit.TEXT], [Locale.t("shell_bd657d70"), Locale.t("shell_445ffb2d") % kids, UIKit.OK]],
		 "act": Locale.t("shell_b74f3aed"), "cb": func(): get_tree().change_scene_to_file("res://scenes/hub/marriage.tscn")},
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
	var crl := UIKit.mono(Locale.t("shell_4e4b2279"), 9, UIKit.TEXT_FAINT)
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
	var go_b := UIKit.ghost_button(Locale.t("shell_9c6a962e"), 112, 38)
	go_b.pressed.connect(func():
		var i = _chapter_pick.selected
		if i >= 0 and i < _chapter_paths.size():
			get_tree().change_scene_to_file(str(_chapter_paths[i])))
	row.add_child(go_b)
	var cont_b := UIKit.cta_button(Locale.t("shell_e4492ae0"), "A", 220, 40)
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
	for hk in [["A", Locale.t("shell_cbde0e46")], ["B", Locale.t("shell_5e5f966c")], ["X", Locale.t("shell_40e191bd")], ["Y", Locale.t("shell_afa16e78")]]:
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
	_hint.text = Locale.t("shell_216a69b5") % GameState.morale

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
		var nm := UIKit.title_label(Locale.latin(str(leader.name), str(leader.id)), 22)
		nm.position = Vector2(16, 308)
		rp.add_child(nm)
		var ag := UIKit.body_label(Locale.t("shell_5a0a47eb") % leader.age, UIKit.TEXT_FAINT, 12)
		ag.position = Vector2(172, 316)
		ag.size = Vector2(44, 16)
		ag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rp.add_child(ag)
		var job_name := Locale.latin(str(GameState.get_job(leader.job_id).get("name", leader.job_id)), str(leader.job_id))
		var rank_label := Locale.latin(str(leader.rank_name()), str(leader.rank))
		var jb := UIKit.body_label("%s · %s" % [job_name, rank_label], UIKit.ACCENT, 12)
		jb.position = Vector2(16, 342)
		jb.size = Vector2(200, 16)
		rp.add_child(jb)
		var sg := GridContainer.new()
		sg.columns = 2
		sg.position = Vector2(16, 370)
		sg.add_theme_constant_override("h_separation", 8)
		sg.add_theme_constant_override("v_separation", 8)
		rp.add_child(sg)
		for st in [[Locale.t("shell_70f83a5e"), "%d" % leader.max_hp, UIKit.OK], [Locale.t("shell_705f477a"), "%d" % leader.derived_atk(), UIKit.TEXT], [Locale.t("shell_92cc6bc7"), "%d" % leader.derived_def(), UIKit.TEXT], [Locale.t("shell_e4daf17b"), "%d" % leader.derived_move(), UIKit.ACCENT]]:
			var bx := UIKit.stat_box(st[0], st[1], st[2])
			bx.custom_minimum_size = Vector2(96, 0)
			sg.add_child(bx)
		var fl := UIKit.body_label(Locale.t("shell_c5922dc9") % [Locale.latin(str(GameState.surname), "House"), roster_n], UIKit.TEXT_FAINT, 11)
		fl.position = Vector2(16, 468)
		fl.size = Vector2(200, 48)
		fl.custom_minimum_size = Vector2(200, 0)
		rp.add_child(fl)
		var vb := UIKit.ghost_button(Locale.t("shell_108b5beb"), 200, 32)
		vb.position = Vector2(16, 522)
		vb.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/roster.tscn"))
		rp.add_child(vb)
		var pb := UIKit.ghost_button(Locale.t("shell_9639cd7e"), 200, 32)
		pb.name = "PromoteOpen"
		pb.position = Vector2(16, 560)
		pb.pressed.connect(func():
			Sfx.click()
			get_tree().change_scene_to_file("res://scenes/hub/title_promote.tscn"))
		rp.add_child(pb)

	UIKit.footer_bar(self, [["A", Locale.t("shell_b56d9ac6")], ["B", Locale.t("shell_11d02415")], ["LB/RB", Locale.t("shell_6e89d3a3")], ["ESC", Locale.t("shell_8112901e")]], "CENTURYKNIGHTS · FROST_TACTICAL v8.6")
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
	return Locale.t("shell_f8fce0c2")

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
		_story_hint.text = Locale.t("shell_f3a26fd2")
	elif GameState.flag("volume37_done"):
		_story_hint.text = Locale.t("shell_47c0b245")
	elif GameState.flag("volume37_mid_done"):
		_story_hint.text = Locale.t("shell_7694041a")
	elif GameState.flag("volume36_done"):
		_story_hint.text = Locale.t("shell_800e0a67")
	elif GameState.flag("volume36_mid_done"):
		_story_hint.text = Locale.t("shell_5d79b77d")
	elif GameState.flag("volume35_done"):
		_story_hint.text = Locale.t("shell_498a1fd0")
	elif GameState.flag("volume35_mid_done"):
		_story_hint.text = Locale.t("shell_de5c040f")
	elif GameState.flag("volume34_done"):
		_story_hint.text = Locale.t("shell_d3014537")
	elif GameState.flag("volume34_mid_done"):
		_story_hint.text = Locale.t("shell_5357977d")
	elif GameState.flag("volume33_done"):
		_story_hint.text = Locale.t("shell_980c8ea6")
	elif GameState.flag("volume33_mid_done"):
		_story_hint.text = Locale.t("shell_84b0ecbb")
	elif GameState.flag("volume32_done"):
		_story_hint.text = Locale.t("shell_421b0b2d")
	elif GameState.flag("volume32_mid_done"):
		_story_hint.text = Locale.t("shell_23ae85e9")
	elif GameState.flag("volume31_done"):
		_story_hint.text = Locale.t("shell_4c997942")
	elif GameState.flag("volume31_mid_done"):
		_story_hint.text = Locale.t("shell_808565e3")
	elif GameState.flag("volume30_done"):
		_story_hint.text = Locale.t("shell_e721af9c")
	elif GameState.flag("volume30_mid_done"):
		_story_hint.text = Locale.t("shell_9c597a79")
	elif GameState.flag("volume29_done"):
		_story_hint.text = Locale.t("shell_030b0284")
	elif GameState.flag("volume29_mid_done"):
		_story_hint.text = Locale.t("shell_0a77c583")
	elif GameState.flag("volume28_done"):
		_story_hint.text = Locale.t("shell_8709847e")
	elif GameState.flag("volume28_mid_done"):
		_story_hint.text = Locale.t("shell_0ca7f8f4")
	elif GameState.flag("volume27_done"):
		_story_hint.text = Locale.t("shell_25e7f8ca")
	elif GameState.flag("volume27_mid_done"):
		_story_hint.text = Locale.t("shell_37d0b58b")
	elif GameState.flag("volume26_done"):
		_story_hint.text = Locale.t("shell_e4e0bbeb")
	elif GameState.flag("volume26_mid_done"):
		_story_hint.text = Locale.t("shell_cbc0f1d3")
	elif GameState.flag("volume25_done"):
		_story_hint.text = Locale.t("shell_0c82786d")
	elif GameState.flag("volume25_mid_done"):
		_story_hint.text = Locale.t("shell_80ec05de")
	elif GameState.flag("volume24_done"):
		_story_hint.text = Locale.t("shell_2161ad4e")
	elif GameState.flag("volume24_mid_done"):
		_story_hint.text = Locale.t("shell_2e9528f4")
	elif GameState.flag("volume23_done"):
		_story_hint.text = Locale.t("shell_c0931d92")
	elif GameState.flag("volume23_mid_done"):
		_story_hint.text = Locale.t("shell_1bce1e7f")
	elif GameState.flag("volume22_done"):
		_story_hint.text = Locale.t("shell_ea69504a")
	elif GameState.flag("volume22_mid_done"):
		_story_hint.text = Locale.t("shell_b29a25d3")
	elif GameState.flag("volume21_done"):
		_story_hint.text = Locale.t("shell_c7f03a04")
	elif GameState.flag("volume21_mid_done"):
		_story_hint.text = Locale.t("shell_eed3622a")
	elif GameState.flag("volume20_done"):
		_story_hint.text = Locale.t("shell_b610b8de")
	elif GameState.flag("volume20_mid_done"):
		_story_hint.text = Locale.t("shell_23f12fb9")
	elif GameState.flag("volume19_done"):
		_story_hint.text = Locale.t("shell_da706a57")
	elif GameState.flag("volume19_mid_done"):
		_story_hint.text = Locale.t("shell_6ff28c78")
	elif GameState.flag("volume18_done"):
		_story_hint.text = Locale.t("shell_f6254cbf")
	elif GameState.flag("volume18_mid_done"):
		_story_hint.text = Locale.t("shell_33f3dc0b")
	elif GameState.flag("volume17_done"):
		_story_hint.text = Locale.t("shell_2f9ff777")
	elif GameState.flag("volume17_mid_done"):
		_story_hint.text = Locale.t("shell_a7a21cd5")
	elif GameState.flag("volume16_done"):
		_story_hint.text = Locale.t("shell_3e118248")
	elif GameState.flag("volume16_mid_done"):
		_story_hint.text = Locale.t("shell_ba0796dc")
	elif GameState.flag("volume15_done"):
		_story_hint.text = Locale.t("shell_729a2cc4")
	elif GameState.flag("volume15_mid_done"):
		_story_hint.text = Locale.t("shell_4aa6b05b")
	elif GameState.flag("volume14_done"):
		_story_hint.text = Locale.t("shell_a20f869f")
	elif GameState.flag("volume14_mid_done"):
		_story_hint.text = Locale.t("shell_612f1ea0")
	elif GameState.flag("volume13_done"):
		_story_hint.text = Locale.t("shell_fff5a58f")
	elif GameState.flag("volume13_mid_done"):
		_story_hint.text = Locale.t("shell_61626390")
	elif GameState.flag("volume12_done"):
		_story_hint.text = Locale.t("shell_4ae95e09")
	elif GameState.flag("volume12_mid_done"):
		_story_hint.text = Locale.t("shell_69fd29d1")
	elif GameState.flag("volume11_done"):
		_story_hint.text = Locale.t("shell_6e6133cb")
	elif GameState.flag("volume10_done"):
		_story_hint.text = Locale.t("shell_53cd6403")
	elif GameState.flag("volume10_mid_done"):
		_story_hint.text = Locale.t("shell_0e80284d")
	elif GameState.flag("volume9_done"):
		_story_hint.text = Locale.t("shell_a32d644c")
	elif GameState.flag("volume9_mid_done"):
		_story_hint.text = Locale.t("shell_4bf78788")
	elif GameState.flag("volume8_done"):
		_story_hint.text = Locale.t("shell_d9efbbee")
	elif GameState.flag("volume8_mid_done"):
		_story_hint.text = Locale.t("shell_6d009e7d")
	elif GameState.flag("volume7_done"):
		_story_hint.text = Locale.t("shell_956be5af")
	elif GameState.flag("volume7_mid_done"):
		_story_hint.text = Locale.t("shell_094324b3")
	elif GameState.flag("volume6_done"):
		_story_hint.text = Locale.t("shell_3e7d9621")
	elif GameState.flag("volume6_mid_done"):
		_story_hint.text = Locale.t("shell_95e5f18f")
	elif GameState.flag("volume5_done"):
		_story_hint.text = Locale.t("shell_aa5cfee6")
	elif GameState.flag("volume5_mid_done"):
		_story_hint.text = Locale.t("shell_895f014c")
	elif GameState.flag("volume4_done"):
		_story_hint.text = Locale.t("shell_01644c1e")
	elif GameState.flag("volume3_done"):
		_story_hint.text = Locale.t("shell_ac46ccb4")
	elif GameState.flag("volume3_mid_done"):
		_story_hint.text = Locale.t("shell_9f0e9e29")
	elif GameState.flag("volume2_done"):
		_story_hint.text = Locale.t("shell_0ccbf4c2")
	elif GameState.flag("volume2_mid_done"):
		_story_hint.text = Locale.t("shell_f1245588")
	elif GameState.flag("volume1_done"):
		_story_hint.text = Locale.t("shell_f0f3ce67")
	else:
		_story_hint.text = Locale.t("shell_1d0997d8")


func _story_hint_lines() -> Array:
	return [
		Locale.t("shell_657780f3"),
		Locale.t("shell_03d1e8c7"),
		Locale.t("shell_2de08d7f"),
		Locale.t("shell_b1fbbf65"),
		Locale.t("shell_a41ed39f"),
		Locale.t("shell_136f5ff9"),
		Locale.t("shell_4a2cd1f6"),
		Locale.t("shell_9b3287cb"),
		Locale.t("shell_6f0d0156"),
		Locale.t("shell_eeaa7f1c"),
		Locale.t("shell_bb37d6fb"),
		Locale.t("shell_93848c5b"),
		Locale.t("shell_60f3bc4d"),
		Locale.t("shell_39c95219"),
		Locale.t("shell_5a06f598"),
		Locale.t("shell_557cfaac"),
		Locale.t("shell_f2447884"),
		Locale.t("shell_58f1f999"),
		Locale.t("shell_eebc3f40"),
		Locale.t("shell_77e418c5"),
		Locale.t("shell_8dffb0b0"),
		Locale.t("shell_47cdb84d"),
		Locale.t("shell_690e6993"),
		Locale.t("shell_10725d6a"),
		Locale.t("shell_76551b18"),
		Locale.t("shell_945540ca"),
		Locale.t("shell_d06129d8"),
		Locale.t("shell_5dee6bda"),
		Locale.t("shell_3697b5b7"),
		Locale.t("shell_1a0c01c5"),
		Locale.t("shell_c3bc8c05"),
		Locale.t("shell_38ef7187"),
		Locale.t("shell_05c09e1b"),
		Locale.t("shell_a6f29559"),
		Locale.t("shell_a35854f4"),
		Locale.t("shell_051bec8b"),
		Locale.t("shell_4518ecf7"),
		Locale.t("shell_7ce4ea33"),
		Locale.t("shell_4e3fe9c0"),
		Locale.t("shell_31f67480"),
		Locale.t("shell_5f02af91"),
		Locale.t("shell_18a8f730"),
		Locale.t("shell_f789bb89"),
		Locale.t("shell_a095b439"),
		Locale.t("shell_d7c2d62e"),
		Locale.t("shell_98e9ce74"),
		Locale.t("shell_86c59866"),
		Locale.t("shell_82f362f5"),
		Locale.t("shell_eb0fecee"),
		Locale.t("shell_c5fbbc27"),
		Locale.t("shell_638399df"),
		Locale.t("shell_1036ccaf"),
		Locale.t("shell_7d1a90d6"),
		Locale.t("shell_aecb1b93"),
		Locale.t("shell_86a71783"),
		Locale.t("shell_790f35e9"),
		Locale.t("shell_19c16eaa"),
		Locale.t("shell_118fc252"),
		Locale.t("shell_b426baa8"),
		Locale.t("shell_ccca15a3"),
		Locale.t("shell_f39331c7"),
		Locale.t("shell_b78f10b8"),
		Locale.t("shell_2d873b56"),
		Locale.t("shell_b40e1411"),
		Locale.t("shell_f06dd3d7"),
		Locale.t("shell_d341f387"),
		Locale.t("shell_16d512cd"),
		Locale.t("shell_21e0f656"),
		Locale.t("shell_1cff9c49"),
		Locale.t("shell_3569a444"),
		Locale.t("shell_7ee9f2e0"),
		Locale.t("shell_a47f14f0"),
		Locale.t("shell_469a57a3"),
		Locale.t("shell_8a32b3fe"),
		Locale.t("shell_9e80d6b4"),
		Locale.t("shell_77b3b3e7"),
		Locale.t("shell_2c5932ce"),
		Locale.t("shell_23da6099"),
		Locale.t("shell_928b7503"),
		Locale.t("shell_c93ae063"),
		Locale.t("shell_d38bcf50"),
		Locale.t("shell_44a0ddb2"),
		Locale.t("shell_78dc26d1"),
		Locale.t("shell_33c0c569"),
		Locale.t("shell_bd4ea252"),
		Locale.t("shell_b4dacf75"),
		Locale.t("shell_ca9d02b2"),
		Locale.t("shell_d0ef54b9"),
		Locale.t("shell_f8d01bd3"),
		Locale.t("shell_cf645c7c"),
		Locale.t("shell_c64d2eec"),
		Locale.t("shell_6302da57"),
		Locale.t("shell_61b3a288"),
		Locale.t("shell_0587a9d0"),
		Locale.t("shell_ff331fc1"),
		Locale.t("shell_62088a8a"),
		Locale.t("shell_1a151070"),
		Locale.t("shell_f447086a"),
		Locale.t("shell_6f09e310"),
		Locale.t("shell_7587975e"),
		Locale.t("shell_f2706207"),
		Locale.t("shell_f44b8914"),
		Locale.t("shell_1d24bfcf"),
		Locale.t("shell_1d0b7c61"),
		Locale.t("shell_384ef0a0"),
		Locale.t("shell_8dfd9a2f"),
		Locale.t("shell_11b256f0"),
		Locale.t("shell_b11b51bd"),
		Locale.t("shell_26a58a94"),
		Locale.t("shell_05e8ea3d"),
		Locale.t("shell_37850170"),
		Locale.t("shell_0da704f9"),
		Locale.t("shell_8eb87ab3"),
		Locale.t("shell_9df03327"),
		Locale.t("shell_7f865451"),
		Locale.t("shell_da522cd9"),
		Locale.t("shell_b5f809dd"),
		Locale.t("shell_aac34b52"),
		Locale.t("shell_5fe8b249"),
		Locale.t("shell_4cdf2ae2"),
		Locale.t("shell_e2120b8f"),
		Locale.t("shell_439af96b"),
		Locale.t("shell_bb7dace7"),
		Locale.t("shell_c601ae43"),
		Locale.t("shell_f4218c64"),
		Locale.t("shell_4c9acc44"),
		Locale.t("shell_619fcd33"),
		Locale.t("shell_cd96627f"),
		Locale.t("shell_25a47ba0"),
		Locale.t("shell_00222e62"),
		Locale.t("shell_2e248ac0"),
		Locale.t("shell_ea51b651"),
		Locale.t("shell_ee9dfd33"),
		Locale.t("shell_ebd378a1"),
		Locale.t("shell_205e0a89"),
		Locale.t("shell_7e7dd025"),
		Locale.t("shell_b79fba72"),
		Locale.t("shell_5af9737f"),
		Locale.t("shell_79be047e"),
		Locale.t("shell_3a562ed8"),
		Locale.t("shell_f916540d"),
		Locale.t("shell_10b0f331"),
		Locale.t("shell_3c69d4d1"),
		Locale.t("shell_0490d840"),
		Locale.t("shell_a7909a8a"),
		Locale.t("shell_ad3c5ca1"),
		Locale.t("shell_f5c7c372"),
		Locale.t("shell_9d4c3025"),
		Locale.t("shell_0ef79222"),
		Locale.t("shell_8fe158c4"),
		Locale.t("shell_6c72f720"),
		Locale.t("shell_fcbc88d8"),
		Locale.t("shell_1467a998"),
		Locale.t("shell_05fb976c"),
		Locale.t("shell_957db539"),
		Locale.t("shell_689bc28d"),
		Locale.t("shell_1e883f07"),
		Locale.t("shell_44dca801"),
		Locale.t("shell_0d23bdc0"),
		Locale.t("shell_0f34c51b"),
		Locale.t("shell_1fd20bd9"),
		Locale.t("shell_dec14f66"),
		Locale.t("shell_1f5ecf5c"),
		Locale.t("shell_edd70261"),
		Locale.t("shell_4e33a0a0"),
		Locale.t("shell_7bc11e9b"),
		Locale.t("shell_d26e5808"),
		Locale.t("shell_c7ca73e8"),
		Locale.t("shell_9590f94b"),
		Locale.t("shell_1c453b2f"),
		Locale.t("shell_b99c62c6"),
		Locale.t("shell_3b7c185e"),
		Locale.t("shell_9b72b839"),
		Locale.t("shell_f64789a6"),
		Locale.t("shell_8a653f27"),
		Locale.t("shell_4ab83a7e"),
		Locale.t("shell_85b32796"),
		Locale.t("shell_b04514e7"),
		Locale.t("shell_ba23b7d0"),
		Locale.t("shell_ef4e3c97"),
		Locale.t("shell_31e8e2bf"),
		Locale.t("shell_6359daa4"),
		Locale.t("shell_2e03166c"),
		Locale.t("shell_29af4ffc"),
		Locale.t("shell_e218e2a6"),
		Locale.t("shell_057163a9"),
		Locale.t("shell_ec74342f"),
		Locale.t("shell_78dfbf16"),
		Locale.t("shell_3bae68b9"),
		Locale.t("shell_bfba3c72"),
		Locale.t("shell_2ee293da"),
		Locale.t("shell_8c5c223a"),
		Locale.t("shell_f4866c3e"),
		Locale.t("shell_e98d3d31"),
		Locale.t("shell_d6468c3e"),
		Locale.t("shell_b8692224"),
		Locale.t("shell_eff83765"),
		Locale.t("shell_5e9e9ddb"),
		Locale.t("shell_5f6f029c"),
		Locale.t("shell_a44399cd"),
		Locale.t("shell_f9219b9d"),
		Locale.t("shell_123e020b"),
		Locale.t("shell_2e23c3c3"),
		Locale.t("shell_ab7d3f08"),
		Locale.t("shell_3ca58880"),
		Locale.t("shell_bb8c800d"),
		Locale.t("shell_81df3e5d"),
		Locale.t("shell_282b8946"),
		Locale.t("shell_c8563e2a"),
		Locale.t("shell_bb9bee08"),
		Locale.t("shell_d2261e98"),
		Locale.t("shell_9d41e521"),
		Locale.t("shell_d04aaaa0"),
		Locale.t("shell_b945840e"),
		Locale.t("shell_4ef519df"),
		Locale.t("shell_48df07e6"),
		Locale.t("shell_8157054c"),
		Locale.t("shell_b58ae3d1"),
		Locale.t("shell_e3d14011"),
		Locale.t("shell_d349b252"),
		Locale.t("shell_fb8a673d"),
		Locale.t("shell_00eeac7e"),
		Locale.t("shell_c1a3cfb2"),
		Locale.t("shell_fa3b4fd2"),
		Locale.t("shell_ac282558"),
		Locale.t("shell_a7b56ca8"),
		Locale.t("shell_46e58184"),
		Locale.t("shell_13f16886"),
		Locale.t("shell_65b5422d"),
		Locale.t("shell_a27dfae3"),
		Locale.t("shell_8169362a"),
		Locale.t("shell_68a022c7"),
		Locale.t("shell_46e81496"),
		Locale.t("shell_4b44e78c"),
		Locale.t("shell_f655689f"),
	]

func _chapter_catalog() -> Array:
	# [label, scene, unlock_flag, volume_index]
	return [
		[Locale.t("shell_ff9edff6"), "res://scenes/story/chapter0.tscn", -1, 0],
		[Locale.t("shell_c400f629"), "res://scenes/story/chapter1.tscn", 0, 1],
		[Locale.t("shell_74866b4f"), "res://scenes/story/chapter2.tscn", 1, 1],
		[Locale.t("shell_99b888a5"), "res://scenes/story/chapter3.tscn", 2, 1],
		[Locale.t("shell_051f9803"), "res://scenes/story/chapter4.tscn", 3, 1],
		[Locale.t("shell_39ae4021"), "res://scenes/story/chapter5.tscn", 4, 1],
		[Locale.t("shell_8a74087d"), "res://scenes/story/chapter6.tscn", 5, 1],
		[Locale.t("shell_0a920a45"), "res://scenes/story/chapter7.tscn", 6, 1],
		[Locale.t("shell_751dce91"), "res://scenes/story/chapter8.tscn", 7, 1],
		[Locale.t("shell_f05a04a7"), "res://scenes/story/chapter9.tscn", 8, 1],
		[Locale.t("shell_568cabb7"), "res://scenes/story/chapter10.tscn", 9, 1],
		[Locale.t("shell_02828d8d"), "res://scenes/story/chapter11.tscn", 10, 1],
		[Locale.t("shell_da8696b4"), "res://scenes/story/chapter12.tscn", 11, 1],
		[Locale.t("shell_d9d4eaba"), "res://scenes/story/chapter13.tscn", 12, 1],
		[Locale.t("shell_7ddf921c"), "res://scenes/story/chapter14.tscn", 13, 1],
		[Locale.t("shell_6a9a154f"), "res://scenes/story/chapter15.tscn", 14, 1],
		[Locale.t("shell_eda18708"), "res://scenes/story/chapter16.tscn", 15, 2],
		[Locale.t("shell_cd1c5c53"), "res://scenes/story/chapter17.tscn", 16, 2],
		[Locale.t("shell_bbb2fbe8"), "res://scenes/story/chapter18.tscn", 17, 2],
		[Locale.t("shell_773855ef"), "res://scenes/story/chapter19.tscn", 18, 2],
		[Locale.t("shell_c19a53f0"), "res://scenes/story/chapter20.tscn", 19, 2],
		[Locale.t("shell_703d0f48"), "res://scenes/story/chapter21.tscn", 20, 2],
		[Locale.t("shell_ac0a50d1"), "res://scenes/story/chapter22.tscn", 21, 3],
		[Locale.t("shell_0abe57cf"), "res://scenes/story/chapter23.tscn", 22, 3],
		[Locale.t("shell_587639e7"), "res://scenes/story/chapter24.tscn", 23, 3],
		[Locale.t("shell_4beea25c"), "res://scenes/story/chapter25.tscn", 24, 3],
		[Locale.t("shell_b5d00d3a"), "res://scenes/story/chapter26.tscn", 25, 3],
		[Locale.t("shell_c6d0b7e7"), "res://scenes/story/chapter27.tscn", 26, 3],
		[Locale.t("shell_7358884b"), "res://scenes/story/chapter28.tscn", 27, 4],
		[Locale.t("shell_69569e88"), "res://scenes/story/chapter29.tscn", 28, 4],
		[Locale.t("shell_3fe672c9"), "res://scenes/story/chapter30.tscn", 29, 4],
		[Locale.t("shell_4df63b66"), "res://scenes/story/chapter31.tscn", 30, 4],
		[Locale.t("shell_886ea5c9"), "res://scenes/story/chapter32.tscn", 31, 4],
		[Locale.t("shell_32c2e64f"), "res://scenes/story/chapter33.tscn", 32, 4],
		[Locale.t("shell_f03fd785"), "res://scenes/story/chapter34.tscn", 33, 5],
		[Locale.t("shell_e284e16a"), "res://scenes/story/chapter35.tscn", 34, 5],
		[Locale.t("shell_d0edd474"), "res://scenes/story/chapter36.tscn", 35, 5],
		[Locale.t("shell_bce10b89"), "res://scenes/story/chapter37.tscn", 36, 5],
		[Locale.t("shell_484ed2d3"), "res://scenes/story/chapter38.tscn", 37, 5],
		[Locale.t("shell_8297e3d4"), "res://scenes/story/chapter39.tscn", 38, 5],
		[Locale.t("shell_b6d661b1"), "res://scenes/story/chapter40.tscn", 39, 6],
		[Locale.t("shell_97317279"), "res://scenes/story/chapter41.tscn", 40, 6],
		[Locale.t("shell_c52c0365"), "res://scenes/story/chapter42.tscn", 41, 6],
		[Locale.t("shell_52cb1a0f"), "res://scenes/story/chapter43.tscn", 42, 6],
		[Locale.t("shell_90ec31fb"), "res://scenes/story/chapter44.tscn", 43, 6],
		[Locale.t("shell_c8925dcc"), "res://scenes/story/chapter45.tscn", 44, 6],
		[Locale.t("shell_3b9b1e91"), "res://scenes/story/chapter46.tscn", 45, 7],
		[Locale.t("shell_019b849d"), "res://scenes/story/chapter47.tscn", 46, 7],
		[Locale.t("shell_a14cfe81"), "res://scenes/story/chapter48.tscn", 47, 7],
		[Locale.t("shell_2233f86c"), "res://scenes/story/chapter49.tscn", 48, 7],
		[Locale.t("shell_ce5be43a"), "res://scenes/story/chapter50.tscn", 49, 7],
		[Locale.t("shell_e2ceca2d"), "res://scenes/story/chapter51.tscn", 50, 7],
		[Locale.t("shell_4b8faabb"), "res://scenes/story/chapter52.tscn", 51, 8],
		[Locale.t("shell_720f7a1d"), "res://scenes/story/chapter53.tscn", 52, 8],
		[Locale.t("shell_cbd73db4"), "res://scenes/story/chapter54.tscn", 53, 8],
		[Locale.t("shell_c0988848"), "res://scenes/story/chapter55.tscn", 54, 8],
		[Locale.t("shell_3c6d9940"), "res://scenes/story/chapter56.tscn", 55, 8],
		[Locale.t("shell_d9602008"), "res://scenes/story/chapter57.tscn", 56, 8],
		[Locale.t("shell_f6384789"), "res://scenes/story/chapter58.tscn", 57, 9],
		[Locale.t("shell_52c5968e"), "res://scenes/story/chapter59.tscn", 58, 9],
		[Locale.t("shell_3a7326c5"), "res://scenes/story/chapter60.tscn", 59, 9],
		[Locale.t("shell_0e6f1865"), "res://scenes/story/chapter61.tscn", 60, 9],
		[Locale.t("shell_7ad482f1"), "res://scenes/story/chapter62.tscn", 61, 9],
		[Locale.t("shell_a711bbd5"), "res://scenes/story/chapter63.tscn", 62, 9],
		[Locale.t("shell_8d192207"), "res://scenes/story/chapter64.tscn", 63, 10],
		[Locale.t("shell_c102b818"), "res://scenes/story/chapter65.tscn", 64, 10],
		[Locale.t("shell_37fd8efe"), "res://scenes/story/chapter66.tscn", 65, 10],
		[Locale.t("shell_0c545bed"), "res://scenes/story/chapter67.tscn", 66, 10],
		[Locale.t("shell_ada37c6b"), "res://scenes/story/chapter68.tscn", 67, 10],
		[Locale.t("shell_2cac5d78"), "res://scenes/story/chapter69.tscn", 68, 10],
		[Locale.t("shell_4be1f5ab"), "res://scenes/story/chapter70.tscn", 69, 11],
		[Locale.t("shell_3db8066d"), "res://scenes/story/chapter71.tscn", 70, 11],
		[Locale.t("shell_1f34f1ec"), "res://scenes/story/chapter72.tscn", 71, 11],
		[Locale.t("shell_0c282b9f"), "res://scenes/story/chapter73.tscn", 72, 11],
		[Locale.t("shell_803f8893"), "res://scenes/story/chapter74.tscn", 73, 11],
		[Locale.t("shell_986a2cd3"), "res://scenes/story/chapter75.tscn", 74, 11],
		[Locale.t("shell_eb3e8e7d"), "res://scenes/story/chapter76.tscn", 75, 12],
		[Locale.t("shell_c493c936"), "res://scenes/story/chapter77.tscn", 76, 12],
		[Locale.t("shell_a226adc8"), "res://scenes/story/chapter78.tscn", 77, 12],
		[Locale.t("shell_e2071c84"), "res://scenes/story/chapter79.tscn", 78, 12],
		[Locale.t("shell_e01a1440"), "res://scenes/story/chapter80.tscn", 79, 12],
		[Locale.t("shell_11fcdc75"), "res://scenes/story/chapter81.tscn", 80, 12],
		[Locale.t("shell_346c388c"), "res://scenes/story/chapter82.tscn", 81, 13],
		[Locale.t("shell_74d825cb"), "res://scenes/story/chapter83.tscn", 82, 13],
		[Locale.t("shell_881b3529"), "res://scenes/story/chapter84.tscn", 83, 13],
		[Locale.t("shell_85cde9e6"), "res://scenes/story/chapter85.tscn", 84, 13],
		[Locale.t("shell_0f9a0879"), "res://scenes/story/chapter86.tscn", 85, 13],
		[Locale.t("shell_8d56ed42"), "res://scenes/story/chapter87.tscn", 86, 13],
		[Locale.t("shell_25ee1cf0"), "res://scenes/story/chapter88.tscn", 87, 14],
		[Locale.t("shell_339725a4"), "res://scenes/story/chapter89.tscn", 88, 14],
		[Locale.t("shell_5f25faf0"), "res://scenes/story/chapter90.tscn", 89, 14],
		[Locale.t("shell_9a4d8978"), "res://scenes/story/chapter91.tscn", 90, 14],
		[Locale.t("shell_e0646f1c"), "res://scenes/story/chapter92.tscn", 91, 14],
		[Locale.t("shell_824394d7"), "res://scenes/story/chapter93.tscn", 92, 14],
		[Locale.t("shell_6c0bea3c"), "res://scenes/story/chapter94.tscn", 93, 15],
		[Locale.t("shell_793abfbf"), "res://scenes/story/chapter95.tscn", 94, 15],
		[Locale.t("shell_20463660"), "res://scenes/story/chapter96.tscn", 95, 15],
		[Locale.t("shell_66850a99"), "res://scenes/story/chapter97.tscn", 96, 15],
		[Locale.t("shell_cf5e0830"), "res://scenes/story/chapter98.tscn", 97, 15],
		[Locale.t("shell_18bac93d"), "res://scenes/story/chapter99.tscn", 98, 15],
		[Locale.t("shell_bbef247d"), "res://scenes/story/chapter100.tscn", 99, 16],
		[Locale.t("shell_1b1fc612"), "res://scenes/story/chapter101.tscn", 100, 16],
		[Locale.t("shell_348b9a85"), "res://scenes/story/chapter102.tscn", 101, 16],
		[Locale.t("shell_439c9c71"), "res://scenes/story/chapter103.tscn", 102, 16],
		[Locale.t("shell_dfa63efe"), "res://scenes/story/chapter104.tscn", 103, 16],
		[Locale.t("shell_86c1c45f"), "res://scenes/story/chapter105.tscn", 104, 16],
		[Locale.t("shell_9e4c88e1"), "res://scenes/story/chapter106.tscn", 105, 17],
		[Locale.t("shell_445831ea"), "res://scenes/story/chapter107.tscn", 106, 17],
		[Locale.t("shell_38d59a59"), "res://scenes/story/chapter108.tscn", 107, 17],
		[Locale.t("shell_d3dd2d22"), "res://scenes/story/chapter109.tscn", 108, 17],
		[Locale.t("shell_30576f99"), "res://scenes/story/chapter110.tscn", 109, 17],
		[Locale.t("shell_d003793c"), "res://scenes/story/chapter111.tscn", 110, 17],
		[Locale.t("shell_27f72f6b"), "res://scenes/story/chapter112.tscn", 111, 18],
		[Locale.t("shell_a6e14f30"), "res://scenes/story/chapter113.tscn", 112, 18],
		[Locale.t("shell_a63412f2"), "res://scenes/story/chapter114.tscn", 113, 18],
		[Locale.t("shell_6dded41e"), "res://scenes/story/chapter115.tscn", 114, 18],
		[Locale.t("shell_ab04dbbb"), "res://scenes/story/chapter116.tscn", 115, 18],
		[Locale.t("shell_eb85a22e"), "res://scenes/story/chapter117.tscn", 116, 18],
		[Locale.t("shell_02acf5eb"), "res://scenes/story/chapter118.tscn", 117, 19],
		[Locale.t("shell_d2a07750"), "res://scenes/story/chapter119.tscn", 118, 19],
		[Locale.t("shell_1ec9ffcb"), "res://scenes/story/chapter120.tscn", 119, 19],
		[Locale.t("shell_ad2147c1"), "res://scenes/story/chapter121.tscn", 120, 19],
		[Locale.t("shell_5068e1b6"), "res://scenes/story/chapter122.tscn", 121, 19],
		[Locale.t("shell_aa5892ca"), "res://scenes/story/chapter123.tscn", 122, 19],
		[Locale.t("shell_82a2150f"), "res://scenes/story/chapter124.tscn", 123, 20],
		[Locale.t("shell_1ff6c16b"), "res://scenes/story/chapter125.tscn", 124, 20],
		[Locale.t("shell_27c725ec"), "res://scenes/story/chapter126.tscn", 125, 20],
		[Locale.t("shell_27b90fa3"), "res://scenes/story/chapter127.tscn", 126, 20],
		[Locale.t("shell_f84f65ce"), "res://scenes/story/chapter128.tscn", 127, 20],
		[Locale.t("shell_f79bb2e7"), "res://scenes/story/chapter129.tscn", 128, 20],
		[Locale.t("shell_136dbcb0"), "res://scenes/story/chapter130.tscn", 129, 21],
		[Locale.t("shell_869aacec"), "res://scenes/story/chapter131.tscn", 130, 21],
		[Locale.t("shell_5e65942a"), "res://scenes/story/chapter132.tscn", 131, 21],
		[Locale.t("shell_d0c87fe3"), "res://scenes/story/chapter133.tscn", 132, 21],
		[Locale.t("shell_1d2b8398"), "res://scenes/story/chapter134.tscn", 133, 21],
		[Locale.t("shell_26982a24"), "res://scenes/story/chapter135.tscn", 134, 21],
		[Locale.t("shell_6e9b4479"), "res://scenes/story/chapter136.tscn", 135, 22],
		[Locale.t("shell_a2f977d5"), "res://scenes/story/chapter137.tscn", 136, 22],
		[Locale.t("shell_c2031627"), "res://scenes/story/chapter138.tscn", 137, 22],
		[Locale.t("shell_bc8c2ff0"), "res://scenes/story/chapter139.tscn", 138, 22],
		[Locale.t("shell_14502c2a"), "res://scenes/story/chapter140.tscn", 139, 22],
		[Locale.t("shell_6e3951bc"), "res://scenes/story/chapter141.tscn", 140, 22],
		[Locale.t("shell_2f209da9"), "res://scenes/story/chapter142.tscn", 141, 23],
		[Locale.t("shell_bdab6026"), "res://scenes/story/chapter143.tscn", 142, 23],
		[Locale.t("shell_88f0768b"), "res://scenes/story/chapter144.tscn", 143, 23],
		[Locale.t("shell_69c2458c"), "res://scenes/story/chapter145.tscn", 144, 23],
		[Locale.t("shell_f5962bf7"), "res://scenes/story/chapter146.tscn", 145, 23],
		[Locale.t("shell_0098c87d"), "res://scenes/story/chapter147.tscn", 146, 23],
		[Locale.t("shell_ef26d4ec"), "res://scenes/story/chapter148.tscn", 147, 24],
		[Locale.t("shell_4ea013c3"), "res://scenes/story/chapter149.tscn", 148, 24],
		[Locale.t("shell_1d64bc38"), "res://scenes/story/chapter150.tscn", 149, 24],
		[Locale.t("shell_04fa4f5f"), "res://scenes/story/chapter151.tscn", 150, 24],
		[Locale.t("shell_5e470cd3"), "res://scenes/story/chapter152.tscn", 151, 24],
		[Locale.t("shell_8d5e5c37"), "res://scenes/story/chapter153.tscn", 152, 24],
		[Locale.t("shell_4cb20896"), "res://scenes/story/chapter154.tscn", 153, 25],
		[Locale.t("shell_5ca1578f"), "res://scenes/story/chapter155.tscn", 154, 25],
		[Locale.t("shell_709f2e05"), "res://scenes/story/chapter156.tscn", 155, 25],
		[Locale.t("shell_2a04e5d0"), "res://scenes/story/chapter157.tscn", 156, 25],
		[Locale.t("shell_7cf8cb7b"), "res://scenes/story/chapter158.tscn", 157, 25],
		[Locale.t("shell_3126a10d"), "res://scenes/story/chapter159.tscn", 158, 25],
		[Locale.t("shell_c5eb3538"), "res://scenes/story/chapter160.tscn", 159, 26],
		[Locale.t("shell_e7a9d262"), "res://scenes/story/chapter161.tscn", 160, 26],
		[Locale.t("shell_36471665"), "res://scenes/story/chapter162.tscn", 161, 26],
		[Locale.t("shell_30f48a02"), "res://scenes/story/chapter163.tscn", 162, 26],
		[Locale.t("shell_4ce1e23a"), "res://scenes/story/chapter164.tscn", 163, 26],
		[Locale.t("shell_ba4e55a3"), "res://scenes/story/chapter165.tscn", 164, 26],
		[Locale.t("shell_d7678724"), "res://scenes/story/chapter166.tscn", 165, 27],
		[Locale.t("shell_a3118d34"), "res://scenes/story/chapter167.tscn", 166, 27],
		[Locale.t("shell_e3db61a6"), "res://scenes/story/chapter168.tscn", 167, 27],
		[Locale.t("shell_5f26d015"), "res://scenes/story/chapter169.tscn", 168, 27],
		[Locale.t("shell_61669bfd"), "res://scenes/story/chapter170.tscn", 169, 27],
		[Locale.t("shell_55019a69"), "res://scenes/story/chapter171.tscn", 170, 27],
		[Locale.t("shell_7f3e7140"), "res://scenes/story/chapter172.tscn", 171, 28],
		[Locale.t("shell_af1e27c0"), "res://scenes/story/chapter173.tscn", 172, 28],
		[Locale.t("shell_a1149920"), "res://scenes/story/chapter174.tscn", 173, 28],
		[Locale.t("shell_6b732027"), "res://scenes/story/chapter175.tscn", 174, 28],
		[Locale.t("shell_37237945"), "res://scenes/story/chapter176.tscn", 175, 28],
		[Locale.t("shell_5a692396"), "res://scenes/story/chapter177.tscn", 176, 28],
		[Locale.t("shell_557fbcc5"), "res://scenes/story/chapter178.tscn", 177, 29],
		[Locale.t("shell_bd901bb9"), "res://scenes/story/chapter179.tscn", 178, 29],
		[Locale.t("shell_4b15853f"), "res://scenes/story/chapter180.tscn", 179, 29],
		[Locale.t("shell_7a7c41fc"), "res://scenes/story/chapter181.tscn", 180, 29],
		[Locale.t("shell_a17e1ac7"), "res://scenes/story/chapter182.tscn", 181, 29],
		[Locale.t("shell_e114b029"), "res://scenes/story/chapter183.tscn", 182, 29],
		[Locale.t("shell_9ad5e8f0"), "res://scenes/story/chapter184.tscn", 183, 30],
		[Locale.t("shell_0b17dd98"), "res://scenes/story/chapter185.tscn", 184, 30],
		[Locale.t("shell_2c88342b"), "res://scenes/story/chapter186.tscn", 185, 30],
		[Locale.t("shell_35e2096c"), "res://scenes/story/chapter187.tscn", 186, 30],
		[Locale.t("shell_7a30559d"), "res://scenes/story/chapter188.tscn", 187, 30],
		[Locale.t("shell_bdb72c85"), "res://scenes/story/chapter189.tscn", 188, 30],
		[Locale.t("shell_9d7230c7"), "res://scenes/story/chapter190.tscn", 189, 31],
		[Locale.t("shell_626f5aee"), "res://scenes/story/chapter191.tscn", 190, 31],
		[Locale.t("shell_3a4dd820"), "res://scenes/story/chapter192.tscn", 191, 31],
		[Locale.t("shell_75c28136"), "res://scenes/story/chapter193.tscn", 192, 31],
		[Locale.t("shell_f843472a"), "res://scenes/story/chapter194.tscn", 193, 31],
		[Locale.t("shell_99c9db29"), "res://scenes/story/chapter195.tscn", 194, 31],
		[Locale.t("shell_e9bdace4"), "res://scenes/story/chapter196.tscn", 195, 32],
		[Locale.t("shell_e9220e38"), "res://scenes/story/chapter197.tscn", 196, 32],
		[Locale.t("shell_2084654e"), "res://scenes/story/chapter198.tscn", 197, 32],
		[Locale.t("shell_b2923ff4"), "res://scenes/story/chapter199.tscn", 198, 32],
		[Locale.t("shell_9be5b6f4"), "res://scenes/story/chapter200.tscn", 199, 32],
		[Locale.t("shell_40f6d47a"), "res://scenes/story/chapter201.tscn", 200, 32],
		[Locale.t("shell_fcfbe002"), "res://scenes/story/chapter202.tscn", 201, 33],
		[Locale.t("shell_1bdd74da"), "res://scenes/story/chapter203.tscn", 202, 33],
		[Locale.t("shell_6290c003"), "res://scenes/story/chapter204.tscn", 203, 33],
		[Locale.t("shell_85cb9c46"), "res://scenes/story/chapter205.tscn", 204, 33],
		[Locale.t("shell_2f072c0c"), "res://scenes/story/chapter206.tscn", 205, 33],
		[Locale.t("shell_d6a2341b"), "res://scenes/story/chapter207.tscn", 206, 33],
		[Locale.t("shell_1666962a"), "res://scenes/story/chapter208.tscn", 207, 34],
		[Locale.t("shell_2170288b"), "res://scenes/story/chapter209.tscn", 208, 34],
		[Locale.t("shell_f8eb58d6"), "res://scenes/story/chapter210.tscn", 209, 34],
		[Locale.t("shell_da14da4d"), "res://scenes/story/chapter211.tscn", 210, 34],
		[Locale.t("shell_05d1457e"), "res://scenes/story/chapter212.tscn", 211, 34],
		[Locale.t("shell_e4e3c70c"), "res://scenes/story/chapter213.tscn", 212, 34],
		[Locale.t("shell_0e504333"), "res://scenes/story/chapter214.tscn", 213, 35],
		[Locale.t("shell_b62a393c"), "res://scenes/story/chapter215.tscn", 214, 35],
		[Locale.t("shell_451f5c38"), "res://scenes/story/chapter216.tscn", 215, 35],
		[Locale.t("shell_28d5a1e7"), "res://scenes/story/chapter217.tscn", 216, 35],
		[Locale.t("shell_98a65e37"), "res://scenes/story/chapter218.tscn", 217, 35],
		[Locale.t("shell_59261888"), "res://scenes/story/chapter219.tscn", 218, 35],
		[Locale.t("shell_229da75f"), "res://scenes/story/chapter220.tscn", 219, 36],
		[Locale.t("shell_7041e4dc"), "res://scenes/story/chapter221.tscn", 220, 36],
		[Locale.t("shell_eb45e3e1"), "res://scenes/story/chapter222.tscn", 221, 36],
		[Locale.t("shell_19d04eb7"), "res://scenes/story/chapter223.tscn", 222, 36],
		[Locale.t("shell_4f0d4639"), "res://scenes/story/chapter224.tscn", 223, 36],
		[Locale.t("shell_aa522cc3"), "res://scenes/story/chapter225.tscn", 224, 36],
		[Locale.t("shell_f79c095f"), "res://scenes/story/chapter226.tscn", 225, 37],
		[Locale.t("shell_dd256405"), "res://scenes/story/chapter227.tscn", 226, 37],
		[Locale.t("shell_af22c7fd"), "res://scenes/story/chapter228.tscn", 227, 37],
		[Locale.t("shell_68a1257b"), "res://scenes/story/chapter229.tscn", 228, 37],
		[Locale.t("shell_540b56e5"), "res://scenes/story/chapter230.tscn", 229, 37],
		[Locale.t("shell_c456b86d"), "res://scenes/story/chapter231.tscn", 230, 37],
		[Locale.t("shell_c2d3165c"), "res://scenes/story/chapter232.tscn", 231, 38],
		[Locale.t("shell_f5e8973e"), "res://scenes/story/chapter233.tscn", 232, 38],
		[Locale.t("shell_d8fcb9ac"), "res://scenes/story/chapter234.tscn", 233, 38],
	]

func _volume_labels() -> Array:
	return [Locale.t("shell_f8fce0c2"), Locale.t("shell_915752d2"), Locale.t("shell_3de6cab8"), Locale.t("shell_908496c6"), Locale.t("shell_ab76fa61"), Locale.t("shell_6caa671c"), Locale.t("shell_4f929f0d"), Locale.t("shell_8ae4b9db"), Locale.t("shell_025e1a68"), Locale.t("shell_f283ea9e"), Locale.t("shell_ba1141aa"), Locale.t("shell_0f971623"), Locale.t("shell_5a1ec09e"), Locale.t("shell_9c575371"), Locale.t("shell_2d7ba2f4"), Locale.t("shell_d8e5378c"), Locale.t("shell_4ee049e9"), Locale.t("shell_835bb0fc"), Locale.t("shell_96660831"), Locale.t("shell_09dac31a"), Locale.t("shell_279f00b1"), Locale.t("shell_6293619b"), Locale.t("shell_ef0904d2"), Locale.t("shell_ccdd777b"), Locale.t("shell_a562316a"), Locale.t("shell_bc55cd66"), Locale.t("shell_52368959"), Locale.t("shell_45257aa4"), Locale.t("shell_d87c2b89"), Locale.t("shell_6ad43ccd"), Locale.t("shell_36ae776a"), Locale.t("shell_47697449"), Locale.t("shell_53bcbb9f"), Locale.t("shell_f9d63576"), Locale.t("shell_833195a8"), Locale.t("shell_47cc5569"), Locale.t("shell_50fd5719"), Locale.t("shell_d70c51b8"), Locale.t("shell_557adf45")]

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
