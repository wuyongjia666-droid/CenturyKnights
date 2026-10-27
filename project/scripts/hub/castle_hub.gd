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
	if has_meta("m_relayout"):
		remove_meta("m_relayout")
	UIKit.void_bg(self)
	set_meta("m_bg_count", get_child_count())
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

	## Heraldry: castle banner strip (团徽 shield + cloth) — shared Chrome, not a one-off crest.
	CKHeraldryField.place_banner_plate(self, Vector2(188, 14), Vector2(40, 48), Vector2(26, 36))

	## Y1-B stub: mid-run dynasty end banner over the seasonal dossier.
	## After a successful 传旗, show BannerHandoffPanel with crest strip until dismissed.
	if Lineage.is_dynasty_ended():
		var host := Control.new()
		host.name = "DynastyEndHost"
		host.position = Vector2(190, 72)
		host.size = Vector2(700, 140)
		add_child(host)
		Lineage.attach_dynasty_end_feel(host, 680.0)
	elif Lineage.is_banner_handoff_pending():
		var hhost := Control.new()
		hhost.name = "BannerHandoffHost"
		hhost.position = Vector2(190, 72)
		hhost.size = Vector2(700, 160)
		add_child(hhost)
		Lineage.attach_banner_handoff_feel(hhost, 680.0)

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
			[Locale.t("btn_sui_year"), Locale.t("ux_hub_sui_sub"), "res://scenes/hub/sui_yearcard.tscn", Locale.t("btn_sui_year"), "sui_ke"],
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
				var title_t := str(item[0])
				## Y1-B hub-feel: unread 岁课角标 on the family nav entry itself.
				if entry == "sui_ke":
					var unread := CKSuiKe.inbox_count()
					if unread > 0:
						title_t = "%s %d" % [title_t, unread]
				var b := _nav_item("%02d" % n, title_t, str(item[1]), first, false, true)
				first = false
				var legacy := str(item[3]) if str(item[3]) != "" else str(item[0])
				b.set_meta("legacy_label", legacy)
				b.set_meta("hub_entry", entry)
				if entry == "sui_ke":
					b.name = "ToSuiYear"
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
	var meta2_text: String = Locale.t("shell_d9f64f13") % [Calendar.label(), Locale.latin(str(GameState.surname), "House")]
	var regency_line: String = Lineage.regency_status()
	if regency_line != "":
		meta2_text = regency_line + " · " + meta2_text
	var meta2 := UIKit.body_label(meta2_text, UIKit.TEXT_FAINT, UIKit.desk_sz(11))
	meta2.position = Vector2(494, 50)
	meta2.size = Vector2(300, 16)
	if regency_line != "":
		# Regency adds a visible prefix; widen leftward so the right edge stays put.
		meta2.position = Vector2(294, 50)
		meta2.size = Vector2(500, 16)
		meta2.add_theme_color_override("font_color", UIKit.ACCENT)
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
		chip.pressed.connect(func():
			HubTodo.prepare_nav(todo)
			CKNav.go(link))
		todo_row.add_child(chip)
	if not HubTodo.any_due():
		todo_row.add_child(UIKit.mono(Locale.t("ux_todo_none"), UIKit.desk_sz(10), UIKit.TEXT_FAINT, false))
	var season_y := _add_content_season_row_desk(cp, 508.0)
	var ih := UIKit.hairline(Color(1, 1, 1, 0.07))
	ih.position = Vector2(26, season_y)
	ih.size = Vector2(768, 1)
	cp.add_child(ih)
	_hint = UIKit.body_label("", UIKit.OK, UIKit.desk_sz(11))
	_hint.position = Vector2(494, season_y + 16.0)
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
		var home_shield := Vector2(22, 28)
		var row_y := 44.0 + 250.0 + float(dy) - home_shield.y - 4.0
		CKHeraldryField.place_home_lineage_row(rp, CKHeraldryField.household_for_overview(5), Vector2(16, row_y), home_shield)

	if not DeviceProfile.is_mobile():   # only keys that really do something (audit #6)
		UIKit.footer_bar(self, [["A", Locale.t("shell_b56d9ac6")], ["ESC", Locale.t("a1_hub_esc")]], "CENTURYKNIGHTS · FROST_TACTICAL v8.6")
	_fit_narrow()
	UIFX.page_enter(self)
	UIFX.wire_tree(self)
	if DeviceProfile.is_mobile() and is_inside_tree():
		call_deferred("apply_mobile_layout")

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
	if has_meta("m_relayout"):
		_m_sheet(sheet, Locale.t("a1_title_q"), Locale.t("a1_title_body"), [
			["TitleStay", Locale.t("a1_title_stay"), false, func(): sheet.queue_free()],
			["TitleGo", Locale.t("a1_title_go"), true, func():
				GameState.save_game()
				sheet.queue_free()
				CKNav.replace(CKNav.TITLE)],
		], 0)
		return
	var p := UIKit.panel_at(sheet, Rect2(_sheet_x(500.0), 250, 500, 220), 14, true)
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

func _open_content_season(chapter_id: String) -> void:
	var scene := StoryCatalog.request_chapter(chapter_id)
	CKNav.replace(scene)

## Desk ContentSeasonRow. Returns the Y used for the next hairline.
## Empty entries → skip entirely (禁 EmptyHost / 空态 CTA).
## 季数增多后桌面不再横排 Season_*（会与 Banner 叠字）；改开 sheet，与手机一致。
func _add_content_season_row_desk(cp: Control, y: float) -> float:
	var entries: Array = StoryCatalog.content_season_entries()
	if entries.is_empty():
		return y
	var row := HBoxContainer.new()
	row.name = "ContentSeasonRow"
	row.position = Vector2(26, y)
	row.size = Vector2(740, 28)
	row.clip_contents = true
	row.add_theme_constant_override("separation", 6)
	cp.add_child(row)
	row.add_child(UIKit.mono(Locale.t("ux_hub_content_season"), UIKit.desk_sz(10), UIKit.EMBER, false))
	var open_b := Button.new()
	open_b.name = "ContentSeasonOpen"
	open_b.text = Locale.t("ux_hub_content_season_play") % Locale.t("ux_hub_content_season")
	open_b.flat = true
	open_b.add_theme_font_size_override("font_size", UIKit.desk_sz(11))
	open_b.add_theme_color_override("font_color", UIKit.EMBER)
	open_b.pressed.connect(_open_content_season_sheet)
	row.add_child(open_b)
	return y + 28.0

## Mobile ContentSeasonRow. Skip when empty — never paint EmptyHost.
func _add_content_season_row_mobile(host: Control) -> void:
	var entries: Array = StoryCatalog.content_season_entries()
	if entries.is_empty():
		return
	# Sit in the todo HFlow (same row as 本月无待办) so the dossier stays within 296px
	# on 1280×720; the sheet carries every Season_* playable chip (scrollable).
	var row := HBoxContainer.new()
	row.name = "ContentSeasonRow"
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(row)
	var open_b := MobilePage.button(
		Locale.t("ux_hub_content_season_play") % Locale.t("ux_hub_content_season"),
		false,
		_open_content_season_sheet)
	open_b.name = "ContentSeasonOpen"
	open_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_b.custom_minimum_size = Vector2(150, M_HIT)
	open_b.add_theme_color_override("font_color", UIKit.EMBER)
	row.add_child(open_b)


## Sheet listing every playable content-season chapter (Season_* chips).
## Ten seasons overflow a 720p / portrait phone — chips live in ContentSeasonScroll.
func _open_content_season_sheet() -> void:
	var entries: Array = StoryCatalog.content_season_entries()
	if entries.is_empty():
		return
	var old := get_node_or_null("ContentSeasonSheet")
	if old:
		old.queue_free()
	var sheet := Control.new()
	sheet.name = "ContentSeasonSheet"
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
	var w := maxf(size.x, 1280.0)
	var h := size.y if size.y > 400.0 else 720.0
	var center := CenterContainer.new()
	center.position = Vector2.ZERO
	center.size = Vector2(w, h)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(center)
	var pw := clampf(w * 0.5, 680.0, 820.0)
	# Cap chip viewport so ten Season_* rows stay reachable on 720p / portrait phones.
	# (PanelContainer has no custom_maximum_size in 4.3 — fix scroll height instead.)
	var chrome := 220.0  # title + body + close + panel margins
	var scroll_h := clampf(h * 0.88 - chrome, 220.0, h * 0.62)
	var card := PanelContainer.new()
	card.name = "SheetCard"
	card.custom_minimum_size = Vector2(pw, 0)
	var sb := UIKit.flat_box(Color(0.06, 0.075, 0.10, 0.98), Color(UIKit.ACCENT, 0.55), 14, 2)
	for side in ["left", "right"]:
		sb.set("content_margin_" + side, 32)
	for side in ["top", "bottom"]:
		sb.set("content_margin_" + side, 26)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)
	var outer := VBoxContainer.new()
	outer.name = "ContentSeasonOuter"
	outer.add_theme_constant_override("separation", 12)
	card.add_child(outer)
	var title := MobilePage.label(Locale.t("ux_hub_content_season"), UIKit.TEXT, 30, true)
	title.add_theme_font_override("font", UIKit.font("bold"))
	outer.add_child(title)
	outer.add_child(MobilePage.label(Locale.t("ux_hub_content_season_sheet_body"), UIKit.TEXT_DIM, 24, true))
	var scroll := ScrollContainer.new()
	scroll.name = "ContentSeasonScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, scroll_h)
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.name = "ContentSeasonList"
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for entry in entries:
		var chapter_id := str(entry.get("chapter_id", ""))
		var label := StoryCatalog.content_season_label(entry)
		var chip := MobilePage.button(Locale.t("ux_hub_content_season_play") % label, true, func():
			sheet.queue_free()
			_open_content_season(chapter_id))
		chip.name = "Season_%s" % chapter_id
		chip.custom_minimum_size = Vector2(0, 80)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override("font_size", 24)
		chip.add_theme_color_override("font_color", UIKit.EMBER)
		box.add_child(chip)
	var close_b := MobilePage.button(Locale.t("ux_codex_close"), false, func(): sheet.queue_free())
	close_b.name = "ContentSeasonClose"
	close_b.custom_minimum_size = Vector2(0, 80)
	close_b.add_theme_font_size_override("font_size", 24)
	outer.add_child(close_b)
	if box.get_child_count() > 0:
		(box.get_child(0) as BaseButton).call_deferred("grab_focus")

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
	if has_meta("m_relayout"):
		var btns: Array = []
		var focus := 0
		if str(st.get("link", "")) == "mainline":
			btns.append(["LockGo", Locale.t("ux_lock_go"), true, func():
				sheet.queue_free()
				var tgt := HubTodo.mainline_target()
				CKNav.go(StoryCatalog.request_chapter(str(tgt.get("id", "ch0"))))])
		btns.append(["LockOk", Locale.t("ux_lock_ok"), false, func(): sheet.queue_free()])
		_m_sheet(sheet, title, str(st.get("reason", "")), btns, focus)
		return
	var p := UIKit.panel_at(sheet, Rect2(_sheet_x(500.0), 470, 500, 210), 14, true)
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


func _sheet_x(w: float) -> float:
	return (maxf(size.x, 1280.0) - w) * 0.5


## ── Landscape phone hub (docs/design/mobile-landscape.md, ux-navigation-v1 §3.1) ──
## One 76px top bar · left column of the five section tabs · centre grid of big entry tiles for
## the chosen section · right column: main line (continue CTA + to-dos) and the leader card.
## Every target is ≥76 logical px (48dp), text ≥22px, nothing is positioned for 1280 only.
const M_FONT := 22
const M_HIT := 76.0
const M_TOP := 96.0
const M_PAD := 20.0
const M_GAP := 12.0
const M_TAB_W := 196.0
const M_TILE_H := 124.0
const _IC := "res://assets/art/ui/v86/"
const _IE := "res://assets/art/estates/"
## Frost line icons (cyan stroke set) per hub entry; reused where the set has no exact glyph.
const M_ICONS := {
	"hourglass": _IC + "kpi_grain.png", "castle_view": _IC + "kpi_fortify.png", "settings": _IC + "mk_iron.png",
	"deploy": _IE + "stone_slope.png", "roster": _IC + "kpi_fortify.png", "tavern": _IC + "mk_herb.png",
	"train": _IC + "mk_iron.png", "skills": _IE + "stone_slope.png",
	"atlas": _IE + "tide_bridge.png", "quests": _IE + "stone_slope.png", "court_news": _IE + "reed_ford.png",
	"lineage": _IE + "fog_vale.png", "sui_ke": _IC + "kpi_grain.png", "marriage": _IE + "fog_vale.png", "rite": _IC + "kpi_fortify.png",
	"titles": _IC + "kpi_cash.png", "rivals": _IE + "stone_slope.png", "ancestors": _IE + "fog_vale.png", "bonds": _IE + "reed_ford.png",
	"works": _IC + "kpi_fortify.png", "forge": _IC + "mk_iron.png", "market": _IC + "kpi_cash.png", "shrine": _IC + "mk_herb.png", "estates": _IC + "kpi_grain.png",
}
var _m_tab := ""
var _m_tabs: Dictionary = {}
var _m_grids: Dictionary = {}
var _m_summaries: Dictionary = {}

func apply_mobile_layout() -> void:
	if has_meta("m_relayout") or not DeviceProfile.is_mobile() or not is_inside_tree():
		return
	var vps := get_viewport().get_visible_rect().size
	if vps.x < vps.y * 1.2:
		return
	set_meta("m_relayout", true)
	var w := maxf(size.x, 1280.0)
	var h := size.y if size.y > 400.0 else 720.0
	# Keep the live nav buttons (signals, lock metas, "new" dots) and rebuild everything around them.
	_m_tabs.clear()
	_m_grids.clear()
	_m_summaries.clear()
	var groups: Array = []
	var rail := find_child("NavRail", true, false)
	if rail:
		# Desktop uses VBoxContainer; after one mobile pass groups are GridContainer.
		for box in rail.find_children("NavGroup_*", "", true, false):
			var btns: Array = []
			for b in box.get_children():
				if b is Button:
					btns.append(b)
			for b in btns:
				box.remove_child(b)
			groups.append({"id": str(box.name).trim_prefix("NavGroup_"), "btns": btns})
	var bg_n := int(get_meta("m_bg_count", 1))
	var kids := get_children()
	for idx in range(kids.size()):
		var c: Node = kids[idx]
		if idx < bg_n or c == _res_bar:
			continue
		remove_child(c)
		c.queue_free()
	_m_top_bar(w)
	var right_w := 400.0 if w >= 1500.0 else 372.0
	var body_h := h - M_TOP - 16.0
	_m_tabs_column(groups, Rect2(M_PAD, M_TOP, M_TAB_W, body_h))
	var gx := M_PAD + M_TAB_W + M_GAP
	_m_entry_grid(groups, Rect2(gx, M_TOP, w - gx - right_w - M_GAP - M_PAD, body_h))
	_m_right_column(Rect2(w - right_w - M_PAD, M_TOP, right_w, body_h))
	var pick := str(GameState.get_meta("hub_tab", "")) if GameState.has_meta("hub_tab") else ""
	if not _m_tabs.has(pick):
		pick = "military" if _m_tabs.has("military") else str(_m_tabs.keys()[0]) if not _m_tabs.is_empty() else ""
	_m_select(pick)

func _m_top_bar(w: float) -> void:
	var house := Locale.latin(str(GameState.surname), "House")
	var info := "%s %d · %s %d · %s %d · %s" % [Locale.t("shell_946c7148"), GameState.silver,
		Locale.t("shell_6763b86e"), GameState.food, Locale.t("shell_69e7baef"), GameState.iron, Calendar.label()]
	var bar := MobilePage.top_bar(self, Locale.t("shell_c84f88cd") % house, info, [
		[Locale.t("ux_help_open"), func(): CKHelpCodex.open(self, true)],
		[Locale.t("shell_40e191bd"), func():
			GameState.save_game()
			if _hint:
				_hint.text = Locale.t("save_ok")],
		[Locale.t("shell_8112901e"), confirm_title],
	])
	bar.size = Vector2(w - 2.0 * M_PAD, M_HIT)
	bar.position = Vector2(M_PAD, 10)
	## Heraldry: keep 团徽 visible on phone top strip (same Chrome as desktop).
	CKHeraldryField.place_banner_plate(self, Vector2(M_PAD, M_TOP - 4.0), Vector2(36, 44), Vector2(22, 30))
	var info_l := bar.get_child(1) as Label
	if info_l:
		info_l.name = "MobileRes"
	var help := bar.get_child(2) as Button
	if help:
		help.name = "OpenGuide"
	for i in range(2, bar.get_child_count()):
		(bar.get_child(i) as Control).custom_minimum_size.x = 150.0

func _m_box(rect: Rect2, nm: String, margin: int = 12) -> VBoxContainer:
	var v := MobilePage.panel(self, rect, margin)
	v.get_parent().name = nm
	return v

func _m_tabs_column(groups: Array, rect: Rect2) -> void:
	var v := _m_box(rect, "SectionTabs", 10)
	v.add_theme_constant_override("separation", 8)
	for g in groups:
		var id := str(g.id)
		var title := Locale.t("ux_hub_%s" % id)
		var badge := HubTodo.count_for(id)
		var fresh := false
		for b in g.btns:
			if (b as Button).has_meta("new_entry"):
				fresh = true
		var t := Button.new()
		t.name = "Tab_" + id
		t.text = title + ("  %d" % badge if badge > 0 else "") + ("  ●" if fresh and badge == 0 else "")
		t.toggle_mode = true
		t.focus_mode = Control.FOCUS_ALL
		t.size_flags_vertical = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size = Vector2(0, M_HIT)
		t.add_theme_font_size_override("font_size", 26)
		t.add_theme_font_override("font", UIKit.font("bold"))
		var mk := func(bg: Color, bd: Color, bw: int) -> StyleBoxFlat:
			var sb := UIKit._btn_box(bg, bd, bw, 8)
			sb.content_margin_left = 18
			return sb
		UIKit._apply_states(t, {
			"normal": mk.call(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.08), 1),
			"hover": mk.call(Color(UIKit.ACCENT, 0.08), Color(UIKit.ACCENT, 0.35), 1),
			"pressed": mk.call(Color(UIKit.ACCENT, 0.20), Color(UIKit.ACCENT, 0.9), 2),
			"hover_pressed": mk.call(Color(UIKit.ACCENT, 0.22), Color(UIKit.ACCENT, 0.9), 2),
			"focus": UIKit._focus_ring(UIKit.FOCUS_RING, 8),
		})
		t.alignment = HORIZONTAL_ALIGNMENT_LEFT
		t.add_theme_color_override("font_color", UIKit.TEXT_DIM)
		t.add_theme_color_override("font_pressed_color", UIKit.ACCENT)
		t.add_theme_color_override("font_hover_pressed_color", UIKit.ACCENT)
		t.add_theme_color_override("font_hover_color", Color.WHITE)
		if badge > 0 or fresh:
			t.add_theme_color_override("font_color", UIKit.EMBER)
		t.pressed.connect(func():
			Sfx.click()
			_m_select(id))
		v.add_child(t)
		_m_tabs[id] = t

func _m_entry_grid(groups: Array, rect: Rect2) -> void:
	var v := _m_box(rect, "EntryPanel", 14)
	v.add_theme_constant_override("separation", 10)
	var head := MobilePage.label("", UIKit.TEXT, 28, false)
	head.name = "SectionTitle"
	head.add_theme_font_override("font", UIKit.font("bold"))
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.name = "NavRail"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	var inner_w := rect.size.x - 28.0
	# Y1-A 机制 C: 272 min so 1600×720 phone roots get 3 cols (family「同袍」不再卡在第 4 行半裁).
	var cols := clampi(int(floor((inner_w + M_GAP) / (272.0 + M_GAP))), 2, 3)
	var tile_w := floorf((inner_w - M_GAP * (cols - 1)) / cols) - 2.0
	var avail := rect.size.y - 28.0 - 48.0
	for g in groups:
		var rows := int(ceil(float(g.btns.size()) / cols))
		# Leave ≥6px slack vs scroll clip so the last row is fully enclosed (audit Locked_bonds).
		var th := clampf(floorf((avail - M_GAP * 3.0) / 4.0) - 6.0, 110.0, 140.0)
		var grid := GridContainer.new()
		grid.name = "NavGroup_" + str(g.id)
		grid.columns = cols
		grid.add_theme_constant_override("h_separation", int(M_GAP))
		grid.add_theme_constant_override("v_separation", int(M_GAP))
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(grid)
		for b in g.btns:
			_m_tile(b as Button, tile_w, th)
			grid.add_child(b)
		_m_grids[str(g.id)] = grid
		var free_h := avail - rows * th - M_GAP * maxi(0, rows - 1) - M_GAP
		var summ := _m_summary(str(g.id), g.btns)
		summ.visible = false
		summ.set_meta("fits", free_h >= 100.0)
		stack.add_child(summ)
		_m_summaries[str(g.id)] = summ

## Turns a desktop rail row into a phone tile: big title on top, one-line purpose / lock reason below.
func _m_tile(b: Button, w: float, th: float = M_TILE_H) -> void:
	var locked := b.has_meta("locked")
	var raw := str(b.text)
	var fresh := raw.begins_with("● ")
	raw = raw.trim_prefix("● ")
	var parts := raw.split("   ", false, 1)
	var title := parts[1] if parts.size() > 1 else raw
	if locked:
		title = title.trim_suffix(" · " + Locale.t("ux_lock_tag"))
	var sub := str(b.tooltip_text)
	b.text = ("● " if fresh else "") + title
	b.tooltip_text = sub
	b.custom_minimum_size = Vector2(w, th)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 26)
	var mk := func(bg: Color, bd: Color, bw: int) -> StyleBoxFlat:
		var sb := UIKit._btn_box(bg, bd, bw, 10)
		sb.content_margin_left = 94
		sb.content_margin_right = 14
		sb.content_margin_top = 10
		sb.content_margin_bottom = 74 if locked else 46
		return sb
	var base := Color(1, 1, 1, 0.025) if locked else Color(UIKit.ACCENT, 0.06)
	UIKit._apply_states(b, {
		"normal": mk.call(base, Color(1, 1, 1, 0.10) if locked else Color(UIKit.ACCENT, 0.30), 1),
		"hover": mk.call(Color(UIKit.ACCENT, 0.12), Color(UIKit.ACCENT, 0.6), 1),
		"pressed": mk.call(Color(UIKit.ACCENT, 0.22), Color(UIKit.ACCENT, 0.9), 2),
		"focus": UIKit._focus_ring(UIKit.FOCUS_RING, 10),
		"disabled": mk.call(base, Color(1, 1, 1, 0.06), 1),
	})
	if not fresh:
		b.add_theme_color_override("font_color", UIKit.TEXT_DIM if locked else UIKit.TEXT)
	var ic := TextureRect.new()
	ic.name = "Icon"
	var ip := str(M_ICONS.get(str(b.get_meta("hub_entry", "")), "res://assets/art/ui/v86/kpi_fortify.png"))
	if ResourceLoader.exists(ip):
		ic.texture = load(ip)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.self_modulate = Color(0.55, 0.62, 0.70) if locked else Color(1, 1, 1)
	ic.anchor_top = 0.5
	ic.anchor_bottom = 0.5
	ic.offset_left = 18
	ic.offset_right = 78
	ic.offset_top = -30
	ic.offset_bottom = 30
	b.add_child(ic)
	var sl := UIKit.body_label(sub, UIKit.TEXT_FAINT if locked else UIKit.ACCENT, M_FONT)
	sl.name = "Sub"
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sl.clip_text = true
	if locked:
		sl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		sl.max_lines_visible = 2
		sl.add_theme_constant_override("line_spacing", -2)
	sl.anchor_left = 0.0
	sl.anchor_right = 1.0
	sl.anchor_top = 1.0
	sl.anchor_bottom = 1.0
	sl.offset_left = 94
	sl.offset_right = -14
	sl.offset_top = -74 if locked else -46
	sl.offset_bottom = -10
	b.add_child(sl)
	if locked:
		b.modulate = Color(1, 1, 1, 0.62)

func _m_select(id: String) -> void:
	if not _m_grids.has(id):
		return
	_m_tab = id
	GameState.set_meta("hub_tab", id)
	for k in _m_grids:
		(_m_grids[k] as Control).visible = (k == id)
		if _m_summaries.has(k):
			var sm := _m_summaries[k] as Control
			sm.visible = (k == id) and bool(sm.get_meta("fits", false))
		(_m_tabs[k] as Button).set_pressed_no_signal(k == id)
	var head := find_child("SectionTitle", true, false) as Label
	if head:
		head.text = Locale.t("ux_hub_%s" % id)
	var scroll := find_child("NavRail", true, false) as ScrollContainer
	if scroll:
		scroll.scroll_vertical = 0

func _m_right_column(rect: Rect2) -> void:
	# Main line first: it is the one thing the player should do next.
	# Content seasons: one dossier chip → sheet (roster must stay on 1280×720).
	var main_h := 296.0
	var v := _m_box(Rect2(rect.position, Vector2(rect.size.x, main_h)), "DossierPanel", 14)
	var dossier := v.get_parent() as Control
	if dossier:
		dossier.clip_contents = true
	v.add_theme_constant_override("separation", 8)
	v.add_child(MobilePage.label(Locale.t("ux_hub_mainline_cap"), UIKit.TEXT_FAINT, M_FONT, false))
	var now := MobilePage.label(_mainline_caption(), UIKit.TEXT, 24, true)
	now.name = "MainlineNow"
	now.max_lines_visible = 2
	now.add_theme_font_override("font", UIKit.font("bold"))
	v.add_child(now)
	var cont_b := MobilePage.button(Locale.t("shell_e4492ae0"), true, _continue_mainline)
	cont_b.name = "ContinueMainline"
	cont_b.custom_minimum_size = Vector2(0, 84)
	cont_b.add_theme_font_size_override("font_size", 26)
	v.add_child(cont_b)
	cont_b.call_deferred("grab_focus")
	var todo_row := HFlowContainer.new()
	todo_row.name = "TodoRow"
	todo_row.add_theme_constant_override("h_separation", 8)
	todo_row.add_theme_constant_override("v_separation", 8)
	v.add_child(todo_row)
	var due := 0
	for todo in HubTodo.snapshot():
		if int(todo.get("count", 0)) <= 0:
			continue
		due += 1
		var link := HubTodo.link_for(todo)
		var chip := MobilePage.button("%s %d" % [str(todo.get("label", "")), int(todo.get("count", 0))], false, func():
			if link != "":
				HubTodo.prepare_nav(todo)
				CKNav.go(link))
		chip.name = "Todo_%s" % str(todo.get("category", ""))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(150, M_HIT)
		chip.add_theme_color_override("font_color", UIKit.EMBER)
		todo_row.add_child(chip)
	if due == 0:
		todo_row.add_child(MobilePage.label(Locale.t("ux_todo_none"), UIKit.TEXT_FAINT, M_FONT, false))
	_add_content_season_row_mobile(todo_row)
	MobilePage.spacer(v)
	_hint = MobilePage.label((Locale.t("shell_216a69b5") % GameState.morale).replace("  ●", ""), UIKit.OK, M_FONT, false)
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if _new_line != "":
		_hint.text = _new_line
		_hint.add_theme_color_override("font_color", UIKit.EMBER)
	v.add_child(_hint)
	var leader = GameState.get_leader()
	if leader == null:
		return
	var lr := Rect2(rect.position + Vector2(0, main_h + M_GAP), Vector2(rect.size.x, rect.size.y - main_h - M_GAP))
	var lv := _m_box(lr, "RosterPlate", 12)
	lv.add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(row)
	var ph := clampf(lr.size.y - 24.0 - M_HIT - 8.0, 120.0, 200.0)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(roundf(ph * 0.8), ph)
	holder.clip_contents = true
	row.add_child(holder)
	UIKit.portrait_plate(holder, Rect2(0, 0, roundf(ph * 0.8), ph), leader, "")
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	CKHeraldryField.place_home_lineage_row(info, CKHeraldryField.household_for_overview(5), Vector2.ZERO, Vector2(22, 28))
	var nm := MobilePage.label(Locale.latin(str(leader.name), str(leader.id)), UIKit.TEXT, 24, false)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.add_theme_font_override("font", UIKit.font("bold"))
	info.add_child(nm)
	var job_name := Locale.latin(str(GameState.get_job(leader.job_id).get("name", leader.job_id)), str(leader.job_id))
	var sub := MobilePage.label("%s · %s" % [Locale.t("shell_5a0a47eb") % leader.age, job_name], UIKit.ACCENT, M_FONT, false)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(sub)
	var sg := GridContainer.new()
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 10)
	info.add_child(sg)
	for st in [[Locale.t("shell_70f83a5e"), "%d/%d" % [leader.hp, leader.max_hp], UIKit.OK], [Locale.t("shell_705f477a"), str(leader.derived_atk()), UIKit.TEXT],
			[Locale.t("shell_92cc6bc7"), str(leader.derived_def()), UIKit.TEXT], [Locale.t("shell_e4daf17b"), str(leader.derived_move()), UIKit.ACCENT]]:
		var cell := MobilePage.label("%s %s" % [str(st[0]).split(" ")[0], st[1]], st[2], M_FONT, false)
		sg.add_child(cell)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	lv.add_child(btns)
	btns.add_child(MobilePage.button(Locale.t("ux_hub_file_short"), false, func(): CKNav.go("res://scenes/hub/roster.tscn")))
	var pb := MobilePage.button(Locale.t("shell_9639cd7e"), false, func():
		Sfx.click()
		CKNav.go("res://scenes/hub/title_promote.tscn"))
	pb.name = "PromoteOpen"
	btns.add_child(pb)


## Phone sheet: centred card sized for touch (title 30px, body 24px, 80px buttons), height follows the text.
func _m_sheet(sheet: Control, title: String, body: String, buttons: Array, focus: int) -> void:
	var w := maxf(size.x, 1280.0)
	var h := size.y if size.y > 400.0 else 720.0
	var pw := clampf(w * 0.5, 680.0, 820.0)
	var center := CenterContainer.new()
	center.position = Vector2.ZERO
	center.size = Vector2(w, h)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(center)
	var p := PanelContainer.new()
	p.name = "SheetCard"
	p.custom_minimum_size = Vector2(pw, 0)
	var sb := UIKit.flat_box(Color(0.06, 0.075, 0.10, 0.98), Color(UIKit.ACCENT, 0.55), 14, 2)
	for side in ["left", "right"]:
		sb.set("content_margin_" + side, 32)
	for side in ["top", "bottom"]:
		sb.set("content_margin_" + side, 26)
	p.add_theme_stylebox_override("panel", sb)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	var t := MobilePage.label(title, UIKit.TEXT, 30, true)
	t.add_theme_font_override("font", UIKit.font("bold"))
	v.add_child(t)
	v.add_child(MobilePage.label(body, UIKit.TEXT_DIM, 24, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	for i in buttons.size():
		var spec: Array = buttons[i]
		var b := MobilePage.button(str(spec[1]), bool(spec[2]), spec[3])
		b.name = str(spec[0])
		b.custom_minimum_size = Vector2(0, 80)
		b.add_theme_font_size_override("font_size", 24)
		row.add_child(b)
		if i == focus:
			b.call_deferred("grab_focus")


## Section summary card under short grids: live numbers for the section + what opens the rest.
func _m_summary(id: String, btns: Array) -> Control:
	var p := PanelContainer.new()
	p.name = "Summary_" + id
	var sb := UIKit.flat_box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.06), 10)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 16)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var locked := 0
	for b in btns:
		if (b as Button).has_meta("locked"):
			locked += 1
	var roster: Array = GameState.roster()
	var wed := 0
	var kids := 0
	for ch in roster:
		if str(ch.spouse_id) != "":
			wed += 1
		kids += ch.children_ids.size()
	var line := ""
	match id:
		"home":
			line = Locale.t("ux_hub_sum_home") % [Calendar.label(), GameState.morale]
		"military":
			line = Locale.t("ux_hub_sum_military") % [roster.size(), GameState.max_deploy(), GameState.silver]
		"atlas":
			line = Locale.t("ux_hub_sum_atlas") % [_mainline_caption()]
		"family":
			line = Locale.t("ux_hub_sum_family") % [roster.size(), wed, kids]
		"civil":
			line = Locale.t("ux_hub_sum_civil") % [GameState.silver, GameState.food, GameState.iron]
	v.add_child(MobilePage.label(line, UIKit.TEXT, M_FONT, true))
	var hint := Locale.t("ux_hub_sum_locked") % locked if locked > 0 else Locale.t("ux_hub_sum_open")
	v.add_child(MobilePage.label(hint, UIKit.TEXT_FAINT, M_FONT, true))
	return p
