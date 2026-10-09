extends Control
const HubTodo := preload("res://scripts/ui/widgets/todo_center.gd")
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
		 "kv": [[Locale.t("shell_a21ba281"), _era_text(), UIKit.TEXT], [Locale.t("shell_e6247ac7"), Locale.t("shell_71e987bf") % _open_count(), UIKit.ACCENT]],
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

	# mainline caption. Progress comes from CKStoryState; the scene comes from StoryCatalog.
	var crl := UIKit.mono(Locale.t("shell_4e4b2279"), 9, UIKit.TEXT_FAINT)
	crl.position = Vector2(26, 408)
	cp.add_child(crl)
	var now := UIKit.body_label(_mainline_caption(), UIKit.TEXT, 13)
	now.name = "MainlineNow"
	now.position = Vector2(26, 428)
	now.size = Vector2(500, 32)
	cp.add_child(now)
	var cont_b := UIKit.cta_button(Locale.t("shell_e4492ae0"), "A", 220, 40)
	cont_b.name = "ContinueMainline"
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
	_update_story_hint()

func _cursor() -> Dictionary:
	return HubTodo.mainline_target()

func _era_text() -> String:
	var era := int(_cursor().get("era", 0))
	if era <= 0:
		return Locale.t("ux_hub_era0")
	return Locale.t("ux_hub_era") % era

func _open_count() -> int:
	return int(_cursor().get("place", 1))

func _mainline_caption() -> String:
	var cursor := _cursor()
	if bool(cursor.get("done", false)):
		return Locale.t("ux_hub_mainline_done")
	var title := Locale.latin(str(cursor.get("title", "")), str(cursor.get("id", "ch0")))
	return Locale.t("ux_hub_now") % title

func _update_story_hint() -> void:
	if _story_hint == null:
		return
	_story_hint.text = _mainline_caption()

func _continue_mainline() -> void:
	var cursor := _cursor()
	var scene := StoryCatalog.request_chapter(str(cursor.get("id", "ch0")))
	get_tree().change_scene_to_file(scene)

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
