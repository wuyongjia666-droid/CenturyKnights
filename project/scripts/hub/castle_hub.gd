extends Control
const HubTodo := preload("res://scripts/ui/widgets/todo_center.gd")
var _res_bar: HBoxContainer
var _hint: Label
var _story_hint: Label
var _new_line := ""

var _m_cards: Array = []

func _ready() -> void:
	if not GameState.flag("hub_open"):
		GameState.set_flag("hub_open")
	_build()
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
	var tb := UIKit.top_bar(self, Locale.t("shell_c84f88cd") % house, UIKit.std_resource_chips(), Locale.t("shell_8112901e"), confirm_title)
	_res_bar = HBoxContainer.new()   # kept for _refresh compatibility (resource tick)
	_res_bar.visible = false
	add_child(_res_bar)
	var right_box: HBoxContainer = tb.get_child(tb.get_child_count() - 1)
	var help_b := UIKit.ghost_button(Locale.t("ux_help_open"), 108, 32)
	help_b.name = "OpenGuide"
	help_b.pressed.connect(func(): CKHelpCodex.open(self, true))
	right_box.add_child(help_b)
	var save_b := UIKit.ghost_button(Locale.t("shell_40e191bd"), 64, 32)
	save_b.pressed.connect(func():
		GameState.save_game()
		_hint.text = Locale.t("save_ok"))
	right_box.add_child(save_b)
	right_box.move_child(save_b, right_box.get_child_count() - 2)

	# ── NAVIGATION ─────────────────────────────────────────
	var nav_panel := UIKit.panel_at(self, Rect2(26, 72, 150, 612), 10)
	nav_panel.name = "NavPanel"
	var nl := UIKit.mono("NAVIGATION", UIKit.desk_sz(9), UIKit.TEXT_FAINT)
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
	## P0-IA: five sections (ux-navigation-v1 §3.1). Locked entries stay visible, greyed, with a reason.
	var groups: Array = [
		{"id": "home", "title": Locale.t("ux_hub_home"), "items": [
			[Locale.t("btn_hourglass"), Locale.t("shell_05820eaa"), "res://scenes/hub/hourglass.tscn", Locale.t("btn_hourglass"), "hourglass"],
			[Locale.t("ux_entry_castle_view"), Locale.t("ux_entry_castle_view"), "res://scenes/hub/castle_view.tscn", "", "castle_view"],
			[Locale.t("shell_7debf9cb"), Locale.t("shell_2155ceaf"), "res://scenes/ui/settings.tscn", Locale.t("shell_7debf9cb"), "settings"],
		]},
		{"id": "military", "title": Locale.t("ux_hub_military"), "items": [
			[Locale.t("shell_15c92308"), DeployBrief.cap_line(), "res://scenes/hub/deploy.tscn", Locale.t("btn_deploy"), "deploy"],
			[Locale.t("btn_roster"), Locale.t("shell_f0ea80bf"), "res://scenes/hub/roster.tscn", Locale.t("btn_roster"), "roster"],
			[Locale.t("btn_tavern"), Locale.t("shell_74f80552"), "res://scenes/hub/tavern.tscn", Locale.t("btn_tavern"), "tavern"],
			[Locale.t("btn_train"), Locale.t("shell_0cb33307"), "res://scenes/hub/train.tscn", Locale.t("btn_train"), "train"],
			[Locale.t("shell_5366fd25"), Locale.t("shell_1f6a2fed"), "res://scenes/hub/skill_tree.tscn", Locale.t("shell_5366fd25"), "skills"],
		]},
		{"id": "atlas", "title": Locale.t("ux_hub_atlas"), "items": [
			[Locale.t("ux_hub_atlas_btn"), Locale.t("ux_hub_atlas_sub"), "res://scenes/hub/atlas_view.tscn", Locale.t("ux_hub_atlas_btn"), "atlas"],
			[Locale.t("btn_quests"), Locale.t("ux_hub_quests_sub"), "res://scenes/hub/quests.tscn", Locale.t("btn_quests"), "quests"],
			[Locale.t("ux_entry_court_news"), Locale.t("ux_entry_court_news"), "res://scenes/hub/court_news.tscn", "", "court_news"],
		]},
		{"id": "family", "title": Locale.t("ux_hub_family"), "items": [
			[Locale.t("btn_lineage"), Locale.t("ux_hub_lineage_sub"), "res://scenes/hub/lineage_view.tscn", Locale.t("btn_lineage"), "lineage"],
			[Locale.t("btn_marriage"), Locale.t("shell_f075f209"), "res://scenes/hub/marriage.tscn", Locale.t("btn_marriage"), "marriage"],
			[Locale.t("shell_dcb83d03"), Locale.t("shell_92bb4d72"), "res://scenes/hub/lineage_rite.tscn", Locale.t("shell_dcb83d03"), "rite"],
			[Locale.t("ux_entry_titles"), Locale.t("ux_entry_titles"), "res://scenes/hub/title_promote.tscn", "", "titles"],
			[Locale.t("ux_entry_rivals"), Locale.t("ux_entry_rivals"), "res://scenes/hub/rival_houses.tscn", "", "rivals"],
			[Locale.t("ux_entry_ancestors"), Locale.t("ux_entry_ancestors"), "res://scenes/hub/ancestors.tscn", "", "ancestors"],
			[Locale.t("ux_entry_bonds"), Locale.t("ux_entry_bonds"), "res://scenes/story/support_viewer.tscn", "", "bonds"],
		]},
		{"id": "civil", "title": Locale.t("ux_hub_civil"), "items": [
			[Locale.t("shell_d0d30beb"), Locale.t("shell_7dea5328"), "res://scenes/hub/works.tscn", Locale.t("shell_d0d30beb"), "works"],
			[Locale.t("btn_forge"), Locale.t("shell_a07db291"), "res://scenes/hub/forge.tscn", Locale.t("btn_forge"), "forge"],
			[Locale.t("btn_market"), Locale.t("shell_55dea989"), "res://scenes/hub/market.tscn", Locale.t("btn_market"), "market"],
			[Locale.t("btn_shrine"), Locale.t("shell_f7881394"), "res://scenes/hub/shrine.tscn", Locale.t("btn_shrine"), "shrine"],
			[Locale.t("shell_8d3d6c29"), Locale.t("shell_be28a894"), "res://scenes/hub/estates.tscn", Locale.t("shell_8d3d6c29"), "estates"],
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
		var head := UIKit.mono(head_txt, UIKit.desk_sz(9), UIKit.ACCENT, false)
		head.custom_minimum_size = Vector2(134, 14)
		box.add_child(head)
		for item in group["items"]:
			var entry := str(item[4])
			var st := UnlockSchedule.state(entry)
			n += 1
			var path: String = item[2]
			if bool(st.open):
				var b := _nav_item("%02d" % n, str(item[0]), str(item[1]), first, false, true)
				first = false
				var legacy := str(item[3]) if str(item[3]) != "" else str(item[0])
				b.set_meta("legacy_label", legacy)
				b.set_meta("hub_entry", entry)
				b.pressed.connect(_go_nav.bind(b, path))
				box.add_child(b)
			else:
				var lb := _nav_item("%02d" % n, "%s · %s" % [str(item[0]), Locale.t("ux_lock_tag")], str(st.reason), false, false, true)
				lb.name = "Locked_" + entry
				lb.modulate = Color(1, 1, 1, 0.5)
				lb.set_meta("hub_entry", entry)
				lb.set_meta("locked", true)
				lb.pressed.connect(open_lock_sheet.bind(str(item[0]), st))
				box.add_child(lb)
	UIFX.stagger_children(rail, 0.018, 0.2)
	_announce_new()

	# ── SEASONAL DOSSIER ───────────────────────────────────
	var cp := UIKit.panel_at(self, Rect2(188, 72, 820, 612), 10)
	var ce := UIKit.mono("SEASONAL DOSSIER", UIKit.desk_sz(10), UIKit.ACCENT)
	ce.position = Vector2(26, 22)
	cp.add_child(ce)
	var ceh := UIKit.hairline(Color(UIKit.ACCENT, 0.35))
	ceh.position = Vector2(26 + ce.get_minimum_size().x + 10, 29)
	ceh.size = Vector2(36, 1)
	cp.add_child(ceh)
	var ct := UIKit.title_label(Locale.t("shell_b69fd89f"), 28)
	ct.position = Vector2(26, 38)
	cp.add_child(ct)
	var meta := UIKit.mono("ENTRY 01-03 / 03 PENDING", UIKit.desk_sz(10), UIKit.TEXT_DIM)
	meta.position = Vector2(794 - meta.get_minimum_size().x, 24)
	cp.add_child(meta)
	var meta2 := UIKit.body_label(Locale.t("shell_d9f64f13") % [Calendar.label(), Locale.latin(str(GameState.surname), "House")], UIKit.TEXT_FAINT, UIKit.desk_sz(11))
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
			"act": Locale.t("shell_4f21c510"), "cb": func(): CKNav.go("res://scenes/hub/tavern.tscn")},
		{"tag": Locale.t("shell_0ea8299b"), "col": UIKit.OK, "id": "# 03", "title": Locale.t("shell_994ca053"), "desc": Locale.t("shell_ccb1cfc4"),
			"kv": [[Locale.t("shell_9466cac8"), Locale.t("shell_9219bb7b") % wed, UIKit.TEXT], [Locale.t("shell_bd657d70"), Locale.t("shell_445ffb2d") % kids, UIKit.OK]],
			"act": Locale.t("shell_b74f3aed"), "cb": func(): CKNav.go("res://scenes/hub/marriage.tscn")},
	]
	_m_cards = cards
	cp.name = "DossierPanel"
	var first_link: Button = null
	for i in cards.size():
		var cd: Dictionary = cards[i]
		var card := UIKit.panel_at(cp, Rect2(26 + i * 262, 86, 246, 312), 8)
		var tg := UIKit.tag_chip(str(cd.tag), cd.col)
		tg.position = Vector2(16, 18)
		card.add_child(tg)
		var idl := UIKit.mono(str(cd.id), UIKit.desk_sz(10), UIKit.TEXT_FAINT, false)
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
		var al := UIKit.mono("ACTION", UIKit.desk_sz(9), UIKit.TEXT_FAINT)
		al.position = Vector2(16, 274)
		card.add_child(al)
		var lb := UIKit.link_button(str(cd.act))
		lb.position = Vector2(230 - lb.get_combined_minimum_size().x, 268)
		lb.pressed.connect(cd.cb)
		card.add_child(lb)
		if first_link == null:
			first_link = lb

	# mainline caption. Progress comes from CKStoryState; the scene comes from StoryCatalog.
	var crl := UIKit.mono(Locale.t("shell_4e4b2279"), UIKit.desk_sz(9), UIKit.TEXT_FAINT)
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
	todo_row.add_child(UIKit.mono(Locale.t("ux_hub_todo"), UIKit.desk_sz(10), UIKit.ACCENT, false))
	for todo in HubTodo.snapshot():
		if int(todo.get("count", 0)) <= 0:
			continue
		var chip_text := "%s %d" % [str(todo.get("label", "")), int(todo.get("count", 0))]
		var link := HubTodo.link_for(todo)
		if link == "":
			todo_row.add_child(UIKit.tag_chip(chip_text, UIKit.ACCENT))
			continue
		var chip := Button.new()
		chip.name = "Todo_%s" % str(todo.get("category", ""))
		chip.text = chip_text + " ›"
		chip.flat = true
		chip.add_theme_font_size_override("font_size", UIKit.desk_sz(11))
		chip.add_theme_color_override("font_color", UIKit.ACCENT)
		chip.pressed.connect(func(): CKNav.go(link))
		todo_row.add_child(chip)
	if not HubTodo.any_due():
		todo_row.add_child(UIKit.mono(Locale.t("ux_todo_none"), UIKit.desk_sz(10), UIKit.TEXT_FAINT, false))
	var ih := UIKit.hairline(Color(1, 1, 1, 0.07))
	ih.position = Vector2(26, 512)
	ih.size = Vector2(768, 1)
	cp.add_child(ih)
	_hint = UIKit.body_label("", UIKit.OK, UIKit.desk_sz(11))
	_hint.position = Vector2(494, 528)
	_hint.size = Vector2(300, 18)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cp.add_child(_hint)
	_hint.text = Locale.t("shell_216a69b5") % GameState.morale
	if _new_line != "":
		_hint.text = _new_line
		_hint.add_theme_color_override("font_color", UIKit.EMBER)

	# ── KNIGHT ROSTER plate ────────────────────────────────
	var rp := UIKit.panel_at(self, Rect2(1024, 72, 232, 612), 10)
	rp.name = "RosterPlate"
	var rl := UIKit.mono("KNIGHT ROSTER", UIKit.desk_sz(9), UIKit.ACCENT)
	rl.position = Vector2(16, 18)
	rp.add_child(rl)
	var rl2 := UIKit.mono("PLATE #01", UIKit.desk_sz(9), UIKit.TEXT_FAINT, false)  # no track: fits beside title at ≥12px
	rl2.position = Vector2(216 - rl2.get_minimum_size().x, 18)
	rp.add_child(rl2)
	if leader:
		# Desktop: the house note overlapped the stat boxes; lift the stack 20px (mobile reflows separately).
		var dy := 0 if DeviceProfile.is_mobile() else -20
		UIKit.portrait_plate(rp, Rect2(16, 44, 200, 250 + dy), leader, "ACTIVE GUARD")
		var nm := UIKit.title_label(Locale.latin(str(leader.name), str(leader.id)), 22)
		nm.position = Vector2(16, 308 + dy)
		rp.add_child(nm)
		var ag := UIKit.body_label(Locale.t("shell_5a0a47eb") % leader.age, UIKit.TEXT_FAINT, 12)
		ag.position = Vector2(172, 316 + dy)
		ag.size = Vector2(44, 16)
		ag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rp.add_child(ag)
		var job_name := Locale.latin(str(GameState.get_job(leader.job_id).get("name", leader.job_id)), str(leader.job_id))
		var rank_label := Locale.latin(str(leader.rank_name()), str(leader.rank))
		var jb := UIKit.body_label("%s · %s" % [job_name, rank_label], UIKit.ACCENT, 12)
		jb.position = Vector2(16, 342 + dy)
		jb.size = Vector2(200, 16)
		rp.add_child(jb)
		var sg := GridContainer.new()
		sg.columns = 2
		sg.position = Vector2(16, 370 + dy)
		sg.add_theme_constant_override("h_separation", 8)
		sg.add_theme_constant_override("v_separation", 8)
		rp.add_child(sg)
		var hp_txt := "%d/%d" % [leader.hp, leader.max_hp]
		var stat_rows := [
			[Locale.t("shell_70f83a5e"), hp_txt, UIKit.OK],
			[Locale.t("shell_705f477a"), "%d" % leader.derived_atk(), UIKit.TEXT],
			[Locale.t("shell_92cc6bc7"), "%d" % leader.derived_def(), UIKit.TEXT],
			[Locale.t("shell_e4daf17b"), "%d" % leader.derived_move(), UIKit.ACCENT],
		]
		for st in stat_rows:
			var bx := UIKit.stat_box(st[0], st[1], st[2])
			bx.custom_minimum_size = Vector2(96, 0)
			sg.add_child(bx)
		var fl := UIKit.body_label(Locale.t("shell_c5922dc9") % [Locale.latin(str(GameState.surname), "House"), roster_n], UIKit.TEXT_FAINT, UIKit.desk_sz(11))
		fl.position = Vector2(16, 468)
		if dy != 0:
			fl.position.y = maxf(468.0, sg.position.y + sg.get_combined_minimum_size().y + 6.0)
		fl.size = Vector2(200, 48)
		fl.custom_minimum_size = Vector2(200, 0)
		rp.add_child(fl)
		var vb := UIKit.ghost_button(Locale.t("shell_108b5beb"), 200, 32)
		vb.position = Vector2(16, 522)
		vb.pressed.connect(func(): CKNav.go("res://scenes/hub/roster.tscn"))
		rp.add_child(vb)
		var pb := UIKit.ghost_button(Locale.t("shell_9639cd7e"), 200, 32)
		pb.name = "PromoteOpen"
		pb.position = Vector2(16, 560)
		pb.pressed.connect(func():
			Sfx.click()
			CKNav.go("res://scenes/hub/title_promote.tscn"))
		rp.add_child(pb)

	if not DeviceProfile.is_mobile():   # only keys that really do something (audit #6)
		UIKit.footer_bar(self, [["A", Locale.t("shell_b56d9ac6")], ["ESC", Locale.t("a1_hub_esc")]], "CENTURYKNIGHTS · FROST_TACTICAL v8.6")
	_fit_narrow()
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func _go_nav(btn: Button, dest: String) -> void:
	if btn.has_meta("hub_entry"):
		mark_seen(str(btn.get_meta("hub_entry")))
	UIFX.press_feedback(btn)
	Sfx.click()
	CKNav.go(dest)

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

## Audit #6: leaving to the title asks first (ESC / back opens the system menu via CKNav instead).
func confirm_title() -> void:
	if get_node_or_null("TitleConfirm") != null:
		return
	var sheet := Control.new()
	sheet.name = "TitleConfirm"
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.z_index = 40
	add_child(sheet)
	CKNav.push_overlay(sheet)
	sheet.tree_exited.connect(func(): CKNav.pop_overlay(sheet))
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.6)
	sheet.add_child(dim)
	var p := UIKit.panel_at(sheet, Rect2(390, 250, 500, 220), 14, true)
	var t := UIKit.title_label(Locale.t("a1_title_q"), 22)
	t.position = Vector2(24, 20)
	p.add_child(t)
	var r := UIKit.body_label(Locale.t("a1_title_body"), UIKit.TEXT_DIM, 14)
	r.position = Vector2(24, 64)
	r.size = Vector2(452, 60)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(r)
	var stay := UIKit.ghost_button(Locale.t("a1_title_stay"), 160, 48)
	stay.name = "TitleStay"
	stay.position = Vector2(24, 148)
	stay.pressed.connect(func(): sheet.queue_free())
	p.add_child(stay)
	stay.call_deferred("grab_focus")
	var go := UIKit.make_accent_button(Locale.t("a1_title_go"), 200)
	go.name = "TitleGo"
	go.custom_minimum_size = Vector2(200, 48)
	go.position = Vector2(276, 148)
	go.pressed.connect(func():
		GameState.save_game()
		sheet.queue_free()
		CKNav.replace(CKNav.TITLE))
	p.add_child(go)

## Audit #7: an entry that opened since the last visit gets a dot until it is tapped,
## plus one line telling the player what opened. First visit seeds everything as seen.
static func seen_entries() -> Array:
	var v = GameState.settings.get("hub_seen", null)
	return v if v is Array else []

static func is_new_entry(entry: String) -> bool:
	return GameState.settings.has("hub_seen") and not seen_entries().has(entry)

static func mark_seen(entry: String) -> void:
	var a := seen_entries().duplicate()
	if not a.has(entry):
		a.append(entry)
	GameState.settings["hub_seen"] = a

func _announce_new() -> void:
	var opened: Array = []
	var fresh: Array = []
	for b in find_children("*", "Button", true, false):
		if b.has_meta("hub_entry") and not b.has_meta("locked"):
			var entry := str(b.get_meta("hub_entry"))
			opened.append(entry)
			if is_new_entry(entry):
				fresh.append(str(b.get_meta("legacy_label", entry)))
				b.text = "● " + b.text
				b.add_theme_color_override("font_color", UIKit.EMBER)
				b.set_meta("new_entry", true)
	if not GameState.settings.has("hub_seen"):
		GameState.settings["hub_seen"] = opened
		return
	if fresh.is_empty():
		return
	var told: Array = GameState.settings.get("hub_told", [])
	var tell: Array = fresh.filter(func(x): return not told.has(x))
	if not tell.is_empty():
		_new_line = Locale.t("a1_hub_new") % "、".join(tell)
		GameState.settings["hub_told"] = told + tell

func _nav_item(idx: String, title_t: String, sub_t: String, active: bool = false, minor: bool = false, compact: bool = false) -> Button:
	## Stitch nav item: mono index (icon slot) + label; active = boxed frost; five states
	var b := Button.new()
	b.text = "%s   %s" % [idx, title_t]
	b.tooltip_text = sub_t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(134, 20 if compact else (25 if minor else 30))
	b.add_theme_font_size_override("font_size", UIKit.desk_sz(11) if compact else (12 if minor else 13))
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
	CKNav.replace(scene)

## Lock sheet (§4.4): what it is, when it opens, and "take me there" when the main line opens it.
func open_lock_sheet(title: String, st: Dictionary) -> void:
	var old := get_node_or_null("LockSheet")
	if old:
		old.queue_free()
	var sheet := Control.new()
	sheet.name = "LockSheet"
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.z_index = 40
	add_child(sheet)
	CKNav.push_overlay(sheet)
	sheet.tree_exited.connect(func(): CKNav.pop_overlay(sheet))
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.6)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			sheet.queue_free())
	sheet.add_child(dim)
	var p := UIKit.panel_at(sheet, Rect2(390, 470, 500, 210), 14, true)
	var t := UIKit.title_label(title, 22)
	t.position = Vector2(24, 20)
	p.add_child(t)
	var r := UIKit.body_label(str(st.get("reason", "")), UIKit.TEXT_DIM, 14)
	r.position = Vector2(24, 64)
	r.size = Vector2(452, 60)
	p.add_child(r)
	var ok := UIKit.ghost_button(Locale.t("ux_lock_ok"), 140, 44)
	ok.name = "LockOk"
	ok.position = Vector2(336, 146)
	ok.pressed.connect(func(): sheet.queue_free())
	p.add_child(ok)
	if str(st.get("link", "")) == "mainline":
		var go := UIKit.cta_button(Locale.t("ux_lock_go"), "A", 200, 44)
		go.name = "LockGo"
		go.position = Vector2(24, 146)
		go.pressed.connect(func():
			sheet.queue_free()
			var tgt := HubTodo.mainline_target()
			CKNav.go(StoryCatalog.request_chapter(str(tgt.get("id", "ch0")))))
		p.add_child(go)
		go.call_deferred("grab_focus")
	else:
		ok.call_deferred("grab_focus")

func panel_button_labels() -> Array:
	var out: Array = []
	var g := get_node_or_null("NavRail")
	if g:
		_collect_labels(g, out)
	return out

func _collect_labels(n: Node, out: Array) -> void:
	for b in n.get_children():
		if b is BaseButton and not b.has_meta("locked"):
			out.append(str(b.get_meta("legacy_label", str(b.text).split("\n")[0])))
		_collect_labels(b, out)


## Landscape phone: 300px nav rail with 22px text, 76px (48dp) entries; dossier and roster
## plate slide right into the extra width. Runs once per build (meta guard).
const M_RAIL_W := 300.0
func _mobile_relayout() -> void:
	if has_meta("m_relayout") or not DeviceProfile.is_mobile():
		return
	var vps := get_viewport().get_visible_rect().size
	if vps.x < vps.y * 1.2:
		return
	set_meta("m_relayout", true)
	var dx := M_RAIL_W - 150.0
	for c in get_children():
		if not (c is Control) or c.name in ["NavPanel", "NavRail", "StitchTopBar", "StitchFooter", "HubBannerPreview"]:
			continue
		var ctrl := c as Control
		if ctrl.position.x >= 170.0 and ctrl.size.x < 1000.0:
			ctrl.position.x += dx
	var np := get_node_or_null("NavPanel") as Control
	if np:
		np.size = Vector2(M_RAIL_W, 720 - M_TOP - 8)
		np.position.y = M_TOP
	var rail := find_child("NavRail", true, false) as ScrollContainer
	if rail:
		rail.position = Vector2(34, M_TOP + 8)
		rail.size = Vector2(M_RAIL_W - 16.0, 720 - M_TOP - 24)
		for b in rail.find_children("*", "Button", true, false):
			var nb := b as Button
			nb.add_theme_font_size_override("font_size", 22)
			nb.custom_minimum_size = Vector2(M_RAIL_W - 24.0, 76)
			nb.clip_text = true
		for l in rail.find_children("*", "Label", true, false):
			var ll := l as Label
			ll.add_theme_font_size_override("font_size", 22)
			ll.custom_minimum_size = Vector2(M_RAIL_W - 24.0, 34)
	var foot := get_node_or_null("StitchFooter") as Control
	if foot:
		foot.visible = false
	_mobile_top_bar()
	_mobile_dossier()
	_mobile_plate()
	# Rail caption / gamepad status sit where the wider rail now is; touch has no gamepad.
	for l in find_children("*", "Control", true, false):
		var lc := l as Control
		if lc is ScrollContainer or rail and rail.is_ancestor_of(lc):
			continue
		var gp := lc.global_position
		if (lc is Label or lc is HBoxContainer) and gp.x < 200.0 and (gp.y < 100.0 and gp.y > 60.0 or gp.y > 640.0 and gp.y < 700.0):
			lc.visible = false

func apply_mobile_layout() -> void:
	_mobile_relayout()
	## Portrait: top-align, let the nav rail scroll, stretch dossier lists into slack.
	var rail := find_child("NavRail", true, false) as ScrollContainer
	if rail:
		rail.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		rail.custom_minimum_size = Vector2(rail.size.x, maxf(rail.size.y, 480.0))
	MobileLayout.fit_top_bar(self, size.x if size.x > 64.0 else 1280.0)
	# Hang a compact company banner on the top bar area for DIY preview.
	if has_meta("m_relayout"):
		return
	var existing := get_node_or_null("HubBannerPreview") as TextureRect
	if existing == null:
		existing = TextureRect.new()
		existing.name = "HubBannerPreview"
		existing.custom_minimum_size = Vector2(56, 78)
		existing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		existing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		existing.position = Vector2(1180, 12)
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(existing)
	UnitArt.clear_cache()
	existing.texture = UnitArt.banner(56, 78, false)
	BannerName.attach(existing)


## ── Phone dossier / plate: container-built so 22px text wraps instead of overlapping ──
const M_FONT := 22
const M_HIT := 76.0
const M_PLATE_W := 280.0
const M_TOP := 92.0

func _mobile_top_bar() -> void:
	var tb := get_node_or_null("StitchTopBar") as Control
	if tb:
		tb.visible = false
	var bp := get_node_or_null("HubBannerPreview")
	if bp:
		bp.queue_free()
	var bar := HBoxContainer.new()
	bar.name = "MobileTopBar"
	bar.position = Vector2(26, 8)
	bar.size = Vector2(maxf(size.x, 1280.0) - 50, M_HIT)
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	var house := Locale.latin(str(GameState.surname), "House")
	var ctx := _m_label(Locale.t("shell_c84f88cd") % house, UIKit.TEXT, 24, false)
	ctx.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.add_child(ctx)
	var res_txt := "%s %d · %s %d · %s %d · %s" % [Locale.t("shell_946c7148"), GameState.silver,
		Locale.t("shell_6763b86e"), GameState.food, Locale.t("shell_69e7baef"), GameState.iron, Calendar.label()]
	var res := _m_label(res_txt, UIKit.ACCENT, M_FONT, false)
	res.name = "MobileRes"
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(res)
	for spec in [[Locale.t("ux_help_open"), func(): CKHelpCodex.open(self, true)],
			[Locale.t("shell_40e191bd"), func():
				GameState.save_game()
				if _hint:
					_hint.text = Locale.t("save_ok")],
			[Locale.t("shell_8112901e"), func():
				GameState.save_game()
				CKNav.replace(CKNav.TITLE)]]:
		var b := _m_button(str(spec[0]), false, spec[1])
		b.custom_minimum_size = Vector2(180, M_HIT)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		bar.add_child(b)

func _m_label(t: String, col: Color, fs: int = M_FONT, wrap: bool = true) -> Label:
	var l := UIKit.body_label(t, col, fs)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _m_button(t: String, accent: bool, cb: Callable) -> Button:
	var b := UIKit.make_accent_button(t, 120) if accent else UIKit.make_button(t, 120)
	b.custom_minimum_size = Vector2(0, M_HIT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", M_FONT)
	b.clip_text = true
	b.pressed.connect(cb)
	return b

func _m_clear(panel: Control) -> void:
	for c in panel.get_children():
		panel.remove_child(c)
		c.queue_free()

func _mobile_dossier() -> void:
	var cp := get_node_or_null("DossierPanel") as Control
	if cp == null:
		return
	var w := maxf(size.x, 1280.0)
	cp.position = Vector2(26 + M_RAIL_W + 12, M_TOP)
	cp.size = Vector2(w - cp.position.x - M_PLATE_W - 36, 720 - M_TOP - 8)
	_m_clear(cp)
	var mg := MarginContainer.new()
	mg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + side, 16)
	cp.add_child(mg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	mg.add_child(col)
	col.add_child(_m_label(Locale.t("shell_b69fd89f"), UIKit.TEXT, 28, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	for cd in _m_cards:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UIKit.flat_box(Color(0.055, 0.067, 0.090, 0.9), Color(1, 1, 1, 0.10), 8))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_stretch_ratio = 1.0
		row.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		card.add_child(v)
		var tt := _m_label(str(cd.title), cd.col, 24, true)
		tt.add_theme_font_override("font", UIKit.font("bold"))
		v.add_child(tt)
		for kvr in cd.kv:
			v.add_child(_m_label("%s  %s" % [str(kvr[0]), str(kvr[1])], kvr[2]))
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(sp)
		v.add_child(_m_button(str(cd.act), false, cd.cb))
	var now := _m_label(_mainline_caption(), UIKit.TEXT)
	now.name = "MainlineNow"
	col.add_child(now)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)
	var todo_row := HBoxContainer.new()
	todo_row.name = "TodoRow"
	todo_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	todo_row.clip_contents = true
	bottom.add_child(todo_row)
	var due := 0
	for todo in HubTodo.snapshot():
		if int(todo.get("count", 0)) <= 0:
			continue
		due += 1
		var link := HubTodo.link_for(todo)
		var go_todo := func():
			if link != "":
				CKNav.go(link)
		var chip := _m_button("%s %d" % [str(todo.get("label", "")), int(todo.get("count", 0))], false, go_todo)
		chip.name = "Todo_%s" % str(todo.get("category", ""))
		chip.size_flags_horizontal = Control.SIZE_FILL
		todo_row.add_child(chip)
	if due == 0:
		todo_row.add_child(_m_label(Locale.t("ux_todo_none"), UIKit.TEXT_FAINT, M_FONT, false))
	var cont_b := _m_button(Locale.t("shell_e4492ae0"), true, _continue_mainline)
	cont_b.name = "ContinueMainline"
	cont_b.custom_minimum_size = Vector2(260, M_HIT)
	cont_b.size_flags_horizontal = Control.SIZE_SHRINK_END
	bottom.add_child(cont_b)
	_hint = _m_label(Locale.t("shell_216a69b5") % GameState.morale, UIKit.OK, M_FONT, false)
	col.add_child(_hint)

func _mobile_plate() -> void:
	var rp := get_node_or_null("RosterPlate") as Control
	var leader = GameState.get_leader()
	if rp == null or leader == null:
		return
	var w := maxf(size.x, 1280.0)
	rp.position = Vector2(w - M_PLATE_W - 24, M_TOP)
	rp.size = Vector2(M_PLATE_W, 720 - M_TOP - 8)
	_m_clear(rp)
	var mg := MarginContainer.new()
	mg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + side, 12)
	rp.add_child(mg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	mg.add_child(v)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(M_PLATE_W - 24, 220)
	v.add_child(holder)
	UIKit.portrait_plate(holder, Rect2(0, 0, M_PLATE_W - 24, 220), leader, "")
	v.add_child(_m_label("%s · %s" % [Locale.latin(str(leader.name), str(leader.id)), Locale.t("shell_5a0a47eb") % leader.age], UIKit.TEXT, 24, false))
	var sg := GridContainer.new()
	sg.columns = 2
	v.add_child(sg)
	for st in [[Locale.t("shell_70f83a5e"), "%d/%d" % [leader.hp, leader.max_hp], UIKit.OK], [Locale.t("shell_705f477a"), str(leader.derived_atk()), UIKit.TEXT],
			[Locale.t("shell_92cc6bc7"), str(leader.derived_def()), UIKit.TEXT], [Locale.t("shell_e4daf17b"), str(leader.derived_move()), UIKit.ACCENT]]:
		var cell := _m_label("%s %s" % [str(st[0]).split(" ")[0], st[1]], st[2], M_FONT, false)
		cell.custom_minimum_size = Vector2((M_PLATE_W - 32) / 2.0, 0)
		sg.add_child(cell)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	v.add_child(_m_button(Locale.t("shell_108b5beb"), false, func(): CKNav.go("res://scenes/hub/roster.tscn")))
	var pb := _m_button(Locale.t("shell_9639cd7e"), false, func():
		Sfx.click()
		CKNav.go("res://scenes/hub/title_promote.tscn"))
	pb.name = "PromoteOpen"
	v.add_child(pb)
