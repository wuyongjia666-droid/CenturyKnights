extends Control
## One unit: expressed and carried traits, parent source, purity, age stage, title, family tree.

var _focus: CKCharacter

func _ready() -> void:
	_focus = _resolve()
	var who := _focus.name if _focus != null else Locale.t("lb_dos_nobody")
	CKPageKit.shell(self, Locale.t("lb_dos_ctx", [who]), "UNIT DOSSIER", who, Locale.t("lb_dos_desc"))
	_build()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "UNIT DOSSIER · FROST")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func apply_mobile_layout() -> void:
	## Phone: real reflow (not just m_center_ok). Fixed desktop slots squash after FONT_FLOOR.
	MobileLayout.pin_footer(get_node_or_null("StitchFooter"))
	set_meta("m_center_ok", true)
	if not DeviceProfile.is_mobile():
		return
	var left := get_node_or_null("PortraitColumn") as Control
	var mid := get_node_or_null("TraitList") as Control
	var right := get_node_or_null("FamilyTree") as Control
	var foot := get_node_or_null("StitchFooter") as Control
	var top := 136.0
	var bottom := (foot.position.y - 8.0) if foot != null else size.y - 40.0
	var h := maxf(280.0, bottom - top)
	var w := size.x
	var gap := 10.0
	var pad := 16.0
	# Landscape logical root (~1600×720): three columns share width/height, no clip squash.
	# Narrow / portrait: stack portrait + traits, hide tree chrome that would crush.
	var narrow := w < 1100.0
	if narrow:
		if left != null:
			left.position = Vector2(pad, top)
			left.size = Vector2(w - pad * 2.0, minf(360.0, h * 0.48))
			left.clip_contents = false
		if mid != null:
			mid.visible = true
			mid.position = Vector2(pad, top + (left.size.y if left else 0.0) + gap)
			mid.size = Vector2(w - pad * 2.0, maxf(160.0, bottom - mid.position.y))
			mid.clip_contents = false
		if right != null:
			right.visible = false
	else:
		var lw := clampf(w * 0.24, 260.0, 340.0)
		var rw := clampf(w * 0.30, 300.0, 440.0)
		var mw := maxf(280.0, w - lw - rw - pad * 2.0 - gap * 2.0)
		if left != null:
			left.visible = true
			left.position = Vector2(pad, top)
			left.size = Vector2(lw, h)
			left.clip_contents = false
		if mid != null:
			mid.visible = true
			mid.position = Vector2(pad + lw + gap, top)
			mid.size = Vector2(mw, h)
			mid.clip_contents = false
		if right != null:
			right.visible = true
			right.position = Vector2(pad + lw + gap + mw + gap, top)
			right.size = Vector2(rw, h)
			right.clip_contents = false
	_mobile_relax_portrait(left)
	_mobile_relax_traits(mid)
	_mobile_relax_tree(right)
	MobileLayout.ensure_min_fonts(self)
	_mobile_floor_page_head()
	_mobile_reflow_life(mid)


func _mobile_floor_page_head() -> void:
	## PageHead is font_floor_exempt (fixed title row); ensure_min_fonts skips it.
	## Hide Latin kickers; raise Chinese title / desc to FONT_FLOOR (same as MobilePage.upsize).
	var head := find_child("PageHead", true, false) as Control
	if head == null:
		return
	for n in head.find_children("*", "Label", true, false):
		var lab := n as Label
		var fs := lab.get_theme_font_size("font_size")
		if fs <= 12 and MobileLayout.is_decor_kicker(lab.text):
			lab.visible = false
			lab.set_meta("m_kicker_hidden", true)
			continue
		if fs < MobileLayout.FONT_FLOOR:
			lab.add_theme_font_size_override("font_size", MobileLayout.FONT_FLOOR)


func _mobile_relax_portrait(left: Control) -> void:
	if left == null:
		return
	var iw := maxf(200.0, left.size.x - 36.0)
	for n in ["AgeStage", "TitleChip"]:
		var chip := left.find_child(n, true, false) as Control
		if chip != null:
			chip.custom_minimum_size.y = maxf(chip.custom_minimum_size.y, 28.0)
	for c in left.get_children():
		if c is Label:
			var lab := c as Label
			if lab.size.x > 10.0 and lab.size.x < iw:
				lab.size.x = iw
			lab.clip_text = false
			if lab.size.y > 0.0 and lab.size.y < float(MobileLayout.FONT_FLOOR):
				lab.size.y = 0.0
				lab.custom_minimum_size.y = 0.0
		elif c is Button:
			var b := c as Button
			b.custom_minimum_size = Vector2(iw, maxf(b.custom_minimum_size.y, MobilePage.HIT))
			b.size.x = iw


func _mobile_relax_traits(mid: Control) -> void:
	if mid == null or not mid.visible:
		return
	var box := mid.get_node_or_null("LifePanel") as Control
	if box != null:
		box.size.x = maxf(200.0, mid.size.x - 32.0)
		box.custom_minimum_size.x = box.size.x
		# Drop fixed 206px height so FONT_FLOOR can grow the VBox.
		box.custom_minimum_size.y = 0.0
		box.size.y = maxf(box.size.y, box.get_combined_minimum_size().y)
	for c in mid.get_children():
		if c is ScrollContainer:
			var sc := c as ScrollContainer
			sc.size.x = maxf(160.0, mid.size.x - 24.0)
			var col := sc.get_child(0) as Control if sc.get_child_count() > 0 else null
			if col != null:
				col.custom_minimum_size.x = maxf(140.0, sc.size.x - 16.0)
		elif c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
			var lab := c as Label
			lab.size.x = maxf(160.0, mid.size.x - 32.0)
			lab.clip_text = false


func _mobile_relax_tree(right: Control) -> void:
	if right == null or not right.visible:
		return
	var tree_scroll: ScrollContainer = null
	for c in right.get_children():
		if c is ScrollContainer:
			tree_scroll = c as ScrollContainer
			break
	if tree_scroll != null:
		tree_scroll.position = Vector2(12, 40)
		var crest := right.get_node_or_null("CrestPreview") as Control
		var bot := (crest.position.y - 8.0) if crest != null else right.size.y - 56.0
		tree_scroll.size = Vector2(maxf(160.0, right.size.x - 24.0), maxf(120.0, bot - tree_scroll.position.y))
		var tree := tree_scroll.get_child(0) as Control if tree_scroll.get_child_count() > 0 else null
		if tree != null:
			tree.custom_minimum_size.x = maxf(140.0, tree_scroll.size.x - 16.0)
	# Person chips: font floor makes 12px/64h squash — grow hit + allow wrap height.
	for b in right.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.name in ["CrestPreview", "OpenCodex"]:
			btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, MobilePage.HIT)
			continue
		btn.add_theme_font_size_override("font_size", maxi(btn.get_theme_font_size("font_size"), MobileLayout.FONT_FLOOR))
		btn.custom_minimum_size = Vector2(maxf(btn.custom_minimum_size.x, 140.0), maxf(btn.custom_minimum_size.y, 88.0))
		btn.clip_text = false
	for lab in right.find_children("*", "Label", true, false):
		var l := lab as Label
		l.clip_text = false
		if l.custom_minimum_size.y > 0.0 and l.custom_minimum_size.y < float(MobileLayout.FONT_FLOOR):
			l.custom_minimum_size.y = 0.0


func _mobile_reflow_life(mid: Control) -> void:
	if mid == null or not mid.visible:
		return
	var box := mid.get_node_or_null("LifePanel") as Control
	if box == null:
		return
	box.size.x = maxf(200.0, mid.size.x - 32.0)
	box.size.y = maxf(box.get_combined_minimum_size().y, box.size.y)
	var life_bottom := box.position.y + box.size.y + 8.0
	for c in mid.get_children():
		if c == box or not (c is Control):
			continue
		var cn := c as Control
		if cn.position.y < 240.0:  # LIFE header stays
			continue
		if cn.position.y < life_bottom:
			cn.position.y = life_bottom
		if c is ScrollContainer:
			cn.size = Vector2(maxf(160.0, mid.size.x - 24.0), maxf(80.0, mid.size.y - cn.position.y - 12.0))
		elif c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
			cn.size = Vector2(maxf(160.0, mid.size.x - 32.0), maxf(cn.get_minimum_size().y, mid.size.y - cn.position.y - 12.0))

func _resolve() -> CKCharacter:
	var want := ""
	if GameState.has_meta("dossier_id"):
		want = str(GameState.get_meta("dossier_id"))
	if want != "" and GameState.characters.has(want):
		return GameState.characters[want]
	return GameState.get_leader()

## §9: dossier always opens; the bloodline trait panel + codex stay locked until e2_06.
func _bloodline_open() -> bool:
	return GameState.flag("e2_06_fought")

func _marriage_openable(c: CKCharacter) -> bool:
	return CKFamilyState.is_marriage_suitor(c)

func _back() -> void:
	var dest := "res://scenes/hub/roster.tscn"
	if GameState.has_meta("dossier_back"):
		dest = str(GameState.get_meta("dossier_back"))
	CKNav.up(dest)

func _build() -> void:
	var c := _focus
	var sheet: Dictionary = CKCourtChrome.unit_sheet(c)
	var left := UIKit.panel_at(self, Rect2(42, 136, 300, 512), 12, true)
	left.name = "PortraitColumn"
	if c != null:
		UIKit.portrait_plate(left, Rect2(18, 16, 264, 300), c, CKGenomePortrait.STAGE_ZH.get(str(sheet.get("stage", "")), ""), false, CKArtPaths.TIER_LARGE)
	var chips := HBoxContainer.new()
	chips.position = Vector2(18, 324)
	chips.size = Vector2(264, 32)
	chips.add_theme_constant_override("separation", 8)
	left.add_child(chips)
	var stage := UIKit.tag_chip("龄段 · %s" % str(sheet.get("stage_zh", "—")), UIKit.ACCENT, true)
	stage.name = "AgeStage"
	chips.add_child(stage)
	var title := UIKit.tag_chip("爵 · %s" % str(sheet.get("title", "—")), UIKit.TEXT)
	title.name = "TitleChip"
	chips.add_child(title)
	var line := UIKit.title_label(str(sheet.get("line_zh", "—")), 18)
	line.position = Vector2(18, 368)
	left.add_child(line)
	var pur := UIKit.mono("纯度 %d%%" % int(sheet.get("purity", 0)), 16, UIKit.ACCENT, false)
	pur.name = "PurityReadout"
	pur.position = Vector2(18, 398)
	left.add_child(pur)
	var pbar := UIKit.slim_bar(float(sheet.get("purity", 0)), 100.0, UIKit.ACCENT, 260, 6)
	pbar.name = "PurityBar"
	pbar.position = Vector2(18, 426)
	left.add_child(pbar)
	var verified := "已验血" if bool(sheet.get("verified", false)) else "尚未验血 · 携因不公开"
	var note := UIKit.body_label(verified, UIKit.OK if bool(sheet.get("verified", false)) else UIKit.TEXT_FAINT, 12)
	note.position = Vector2(18, 446)
	note.size = Vector2(264, 28)
	left.add_child(note)
	if _marriage_openable(c):
		var marry_btn := CKPageKit.button(Locale.t("ux_dossier_propose"), true, 264)
		marry_btn.name = "OpenMarriage"
		marry_btn.position = Vector2(18, 478)
		marry_btn.custom_minimum_size = Vector2(264, 48)
		var focus_id := str(c.id)
		marry_btn.pressed.connect(func():
			Sfx.click()
			GameState.marriage_focus_id = focus_id
			CKNav.go("res://scenes/hub/marriage.tscn"))
		left.add_child(marry_btn)
	var mid := UIKit.panel_at(self, Rect2(358, 136, 440, 512), 12)
	mid.name = "TraitList"
	_life(mid, c)
	var sh := UIKit.mono("EXPRESSED", 9, UIKit.ACCENT)
	sh.position = Vector2(16, 250)
	mid.add_child(sh)
	if not _bloodline_open():
		var lock := UIKit.body_label(Locale.t("lb_dos_lock", [Locale.t("ux_lock_bloodline")]), UIKit.TEXT_DIM, 13)
		lock.name = "BloodlineLock"
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock.position = Vector2(16, 274)
		lock.size = Vector2(408, 120)
		mid.add_child(lock)
	else:
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(12, 272)
		scroll.size = Vector2(416, 226)
		scroll.scroll_deadzone = 10
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		mid.add_child(scroll)
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(400, 0)
		col.add_theme_constant_override("separation", 8)
		scroll.add_child(col)
		_trait_block(col, "显出", sheet.get("shown", []), UIKit.OK)
		var carry_title := "携因" if bool(sheet.get("verified", false)) else "携因 · 验血后可见"
		_trait_block(col, carry_title, sheet.get("carried", []) if bool(sheet.get("verified", false)) else [], UIKit.ACCENT)
		if not bool(sheet.get("verified", false)):
			col.add_child(UIKit.body_label("祠堂验血之前，潜征保持未识。", UIKit.TEXT_FAINT, 12))
	if DeviceProfile.is_mobile():
		_follow_life(mid, sh)
	var right := UIKit.panel_at(self, Rect2(814, 136, 424, 512), 12)
	right.name = "FamilyTree"
	var fh := UIKit.mono("FAMILY · TRAIT HIGHLIGHT", 9, UIKit.TEXT_FAINT)
	fh.position = Vector2(16, 14)
	right.add_child(fh)
	var tree_scroll := ScrollContainer.new()
	tree_scroll.position = Vector2(12, 40)
	tree_scroll.size = Vector2(400, 396)
	tree_scroll.scroll_deadzone = 10
	tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(tree_scroll)
	var tree := VBoxContainer.new()
	tree.custom_minimum_size = Vector2(380, 0)
	tree.add_theme_constant_override("separation", 8)
	tree_scroll.add_child(tree)
	_archive(tree, c)
	_yeartrace(tree, c)
	_tree(tree, c, sheet)
	var crest := CKPageKit.button(Locale.t("lb_dos_crest"), false, 188)
	crest.name = "CrestPreview"
	crest.position = Vector2(16, 448)
	crest.pressed.connect(_show_crest)
	right.add_child(crest)
	var codex := CKPageKit.button(Locale.t("lb_dos_codex"), false, 188)
	codex.name = "OpenCodex"
	codex.position = Vector2(220, 448)
	if _bloodline_open():
		codex.pressed.connect(func():
			Sfx.click()
			CKNav.go("res://scenes/hub/bloodline_codex.tscn"))
	else:
		codex.disabled = true
		codex.set_meta("deny_reason", Locale.t("ux_lock_bloodline"))
		codex.modulate = Color(1, 1, 1, 0.5)
	right.add_child(codex)

func _trait_block(parent: Node, title: String, rows: Array, col: Color) -> void:
	parent.add_child(UIKit.mono(title, 11, col, false))
	if rows.is_empty():
		parent.add_child(UIKit.body_label("（无）", UIKit.TEXT_FAINT, 12))
		return
	for e in rows:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(380, 44)
		card.add_theme_stylebox_override("panel", UIKit.flat_box(Color(col, 0.08), Color(col, 0.35), 8))
		parent.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 6)
		v.add_child(top)
		top.add_child(CKCourtChrome.law_chip(str(e.get("law", ""))))
		var nm := UIKit.body_label(str(e.get("zh", e.get("state", ""))), UIKit.TEXT, 14)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.clip_text = true
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nm.custom_minimum_size = Vector2(180, 0)
		top.add_child(nm)
		var sub := UIKit.body_label("%s · %s" % [str(e.get("law_zh", "")), str(e.get("from", ""))], UIKit.TEXT_DIM, 12)
		sub.autowrap_mode = TextServer.AUTOWRAP_OFF
		sub.clip_text = true
		v.add_child(sub)


func _yeartrace(parent: Node, focus: CKCharacter) -> void:
	## Season-01 deepen: durable 岁课年迹 (read-only), survives inbox ack.
	var panel := VBoxContainer.new()
	panel.name = "YeartracePanel"
	panel.add_theme_constant_override("separation", 4)
	parent.add_child(panel)
	panel.add_child(UIKit.mono("SUI · YEARTRACE", 9, UIKit.ACCENT, false))
	if focus == null:
		panel.add_child(UIKit.body_label("—", UIKit.TEXT_FAINT, 12))
		return
	var rows: Array = CKSuiKe.yeartrace_for(focus.id)
	if rows.is_empty():
		var empty := UIKit.body_label("尚无岁课年迹。", UIKit.TEXT_FAINT, 12)
		empty.name = "YeartraceEmpty"
		panel.add_child(empty)
		return
	# Newest last in store; show latest first, cap 6.
	var shown := 0
	for i in range(rows.size() - 1, -1, -1):
		if shown >= 6:
			break
		var item: Dictionary = rows[i]
		var line := "%d年%d月 · %s · %s" % [
			int(item.get("year", 0)),
			int(item.get("month", 0)),
			str(item.get("title", "")),
			str(item.get("outcome", "")),
		]
		var lab := UIKit.body_label(line, UIKit.TEXT, 12)
		lab.name = "Yeartrace_%d" % shown
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF
		lab.clip_text = true
		lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lab.custom_minimum_size = Vector2(360, maxi(18, MobileLayout.FONT_FLOOR))
		panel.add_child(lab)
		shown += 1


func _archive(parent: Node, focus: CKCharacter) -> void:
	var arch: Dictionary = CKFamilyState.child_archive(GameState, focus)
	parent.add_child(UIKit.mono("OFFSPRING ARCHIVE", 9, UIKit.ACCENT, false))
	for row in [["AptBand", str(arch.get("apt_zh", ""))], ["TacticOdds", str(arch.get("tactics_zh", ""))], ["RoyalOdds", str(arch.get("royal_zh", ""))]]:
		var lab := UIKit.body_label(row[1], UIKit.TEXT, 12)
		lab.name = row[0]
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF
		lab.clip_text = true
		lab.custom_minimum_size = Vector2(360, 16)
		parent.add_child(lab)


func _tree(parent: Node, focus: CKCharacter, sheet: Dictionary) -> void:
	if focus == null:
		parent.add_child(UIKit.empty_state("谱上还没有这个人。"))
		return
	var focus_states := {}
	for e in sheet.get("shown", []):
		focus_states[str(e.get("state", ""))] = str(e.get("zh", ""))
	var rows: Array = []
	rows.append({"label": "父母", "people": _people(focus.parent_ids)})
	var self_row: Array = [focus]
	if str(focus.spouse_id) != "" and GameState.characters.has(str(focus.spouse_id)):
		self_row.append(GameState.characters[str(focus.spouse_id)])
	rows.append({"label": "本人", "people": self_row})
	rows.append({"label": "子女", "people": _people(focus.children_ids)})
	for row in rows:
		parent.add_child(UIKit.mono(str(row["label"]), 10, UIKit.TEXT_FAINT, false))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		parent.add_child(h)
		var people: Array = row["people"]
		if people.is_empty():
			h.add_child(UIKit.body_label("—", UIKit.TEXT_FAINT, 12))
			continue
		for p in people:
			h.add_child(_person_chip(p, focus, focus_states))

func _people(ids) -> Array:
	var out: Array = []
	if typeof(ids) != TYPE_ARRAY:
		return out
	for id in ids:
		if GameState.characters.has(str(id)):
			out.append(GameState.characters[str(id)])
	return out

func _person_chip(p: CKCharacter, focus: CKCharacter, focus_states: Dictionary) -> Control:
	var share := ""
	var their: Dictionary = CKCourtChrome.unit_sheet(p)
	for e in their.get("shown", []):
		if focus_states.has(str(e.get("state", ""))):
			share = str(e.get("zh", ""))
			break
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 64)
	b.focus_mode = Control.FOCUS_ALL
	b.text = "%s\n%s · %s" % [p.name, CKGenomePortrait.STAGE_ZH.get(CKGenomePortrait.stage_for_age(p.age), ""), CKCourt.ladder_zh(CKCourt.current_title(p), str(p.gender))]
	if share != "" and p != focus:
		b.text += "\n同征 " + share
	var on := p == focus
	var bd := UIKit.OK if share != "" else (UIKit.ACCENT if on else Color(1, 1, 1, 0.16))
	UIKit._apply_states(b, {
		"normal": UIKit.flat_box(Color(UIKit.OK, 0.10) if share != "" else Color(1, 1, 1, 0.03), bd, 8, 2 if share != "" or on else 1),
		"hover": UIKit.flat_box(Color(UIKit.ACCENT, 0.12), UIKit.ACCENT, 8, 1),
		"pressed": UIKit.flat_box(Color(UIKit.ACCENT, 0.2), UIKit.ACCENT, 8, 2),
		"focus": UIKit._focus_ring(UIKit.FOCUS_RING, 10),
		"disabled": UIKit.flat_box(UIKit.DISABLED_BG, UIKit.DISABLED_BORDER, 8, 1),
	})
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", UIKit.TEXT)
	var captured := p
	b.pressed.connect(func():
		Sfx.click()
		UIFX.press_feedback(b)
		GameState.set_meta("dossier_id", captured.id)
		CKNav.go("res://scenes/hub/unit_dossier.tscn"))
	return b


## Life panel (audit #16): class, age, HP, six stats and whether they can deploy. Always shown,
## so the middle column is never empty while the bloodline part is still locked.
func _life(mid: Control, c: CKCharacter) -> void:
	var h := UIKit.mono("LIFE", 9, UIKit.ACCENT)
	h.position = Vector2(16, 14)
	mid.add_child(h)
	var box := VBoxContainer.new()
	box.name = "LifePanel"
	box.position = Vector2(16, 34)
	box.size = Vector2(408, 206)
	if DeviceProfile.is_mobile():
		box.custom_minimum_size = Vector2(408, 0)
		box.size = Vector2(408, 0)  # grow with FONT_FLOOR; apply_mobile_layout sizes width
	box.add_theme_constant_override("separation", 6)
	mid.add_child(box)
	if c == null:
		box.add_child(CKPageKit.text(Locale.t("lb_dos_nobody"), UIKit.TEXT_FAINT, 13, 400))
		return
	var job := str(GameState.get_job(c.job_id).get("name", c.job_id))
	box.add_child(CKPageKit.text(Locale.t("lb_dos_line", [job, c.age, c.hp, c.max_hp]), UIKit.TEXT, 15, 400))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for k in CKCharacter.STAT_KEYS:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(128, 56 if DeviceProfile.is_mobile() else 40)
		var sb := UIKit.flat_box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.12), 8)
		sb.content_margin_left = 10
		cell.add_theme_stylebox_override("panel", sb)
		var l := UIKit.body_label("%s  %d / %d" % [Locale.t("stat_" + k), int(c.stats.get(k, 0)), int(c.apt_max.get(k, 20))], UIKit.TEXT, 14)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(l)
		grid.add_child(cell)
	var why := CKInjury.deploy_block_reason(c) if c.in_roster else ""
	var status := Locale.t("lb_dos_ok") if why == "" else Locale.t("lb_dos_blocked", [why])
	if not c.in_roster:
		status = Locale.t("lb_dos_home")
	box.add_child(CKPageKit.text(status, UIKit.OK if why == "" else UIKit.DANGER, 13, 400))

## Mobile only: the 22px font floor makes LifePanel taller than its 206px slot, so the
## EXPRESSED header, bloodline lock and trait scroll move down to sit under it.
func _follow_life(mid: Control, sh: Control) -> void:
	var box := mid.get_node_or_null("LifePanel") as Control
	if box == null:
		return
	var base_y := sh.position.y
	var movers: Array = []
	for n in mid.get_children():
		if n is Control and n != box and (n as Control).position.y >= base_y - 1.0:
			movers.append([n, (n as Control).position.y])
	box.resized.connect(func():
		var dy := maxf(0.0, box.position.y + box.size.y + 8.0 - base_y)
		for m in movers:
			var cn := m[0] as Control
			cn.position.y = float(m[1]) + dy
			if cn is ScrollContainer:
				cn.size.y = maxf(80.0, mid.size.y - cn.position.y - 12.0)
			elif cn is Label and (cn as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
				cn.size.y = maxf(cn.get_minimum_size().y, mid.size.y - cn.position.y - 12.0)
	)

## Company crest at full size (audit #56). Back / tap outside closes it.
func _show_crest() -> void:
	Sfx.click()
	var layer := Control.new()
	layer.name = "CrestOverlay"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.size = Vector2(1280, 720)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UIKit.BG, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var tr := TextureRect.new()
	tr.texture = CKHeraldryRender.compose_texture(GameState.banner_spec, 320, 440)
	tr.position = Vector2(480, 96)
	tr.size = Vector2(320, 440)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tr)
	var close := CKPageKit.button(Locale.t("lb_close"), true, 200)
	close.position = Vector2(540, 560)
	close.pressed.connect(func(): CKNav.pop_overlay(layer); layer.queue_free())
	layer.add_child(close)
	layer.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			CKNav.pop_overlay(layer)
			layer.queue_free())
	add_child(layer)
	CKNav.push_overlay(layer)
	UIFX.pop_in(tr)
