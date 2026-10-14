extends Control
## v8.6 — layout-matched to Stitch 10_roster.png: top bar · MERCENARY CADRE list (numbered rows, status/class) ·
## DOSSIER panel (blueprint portrait plate · identity · rank · traits · combat stats · actions) · footer.

var _list: VBoxContainer
var _dossier: Control
var _selected: CKCharacter
var _rows: Array = []

func _ready() -> void:
	UIKit.void_bg(self)
	var roster: Array = GameState.roster()
	var pay := 0
	for c in roster:
		pay += int(c.salary)
	UIKit.top_bar(self, "驻编骑士名册", [["银币", str(GameState.silver), UIKit.ACCENT], ["编制", "%02d 名" % roster.size(), UIKit.TEXT], ["月薪合计", "%d" % pay, UIKit.TEXT_DIM], ["历", Calendar.label(), UIKit.TEXT_DIM]], "返回城堡", _back)
	UIKit.page_head(self, 42, 70, "MERCENARY CADRE", "驻编骑士名册", "BATTALION ARCHIVE")
	var cnt := UIKit.body_label("共 %d 名骑士待命 · 伤者标红" % roster.size(), UIKit.TEXT_DIM, 11)
	cnt.autowrap_mode = TextServer.AUTOWRAP_OFF
	cnt.position = Vector2(42, 128)
	cnt.size = Vector2(372, 16)
	add_child(cnt)
	var scroll := ScrollContainer.new()
	scroll.name = "RosterListScroll"
	scroll.position = Vector2(42, 152)
	scroll.size = Vector2(372, 508)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	if roster.is_empty():
		_list.add_child(UIKit.empty_state("花名册空空如也。去烽火酒馆看看。"))
	var i := 0
	for c in roster:
		i += 1
		_list.add_child(_row(c, i))
	var fl := UIKit.body_label("FILTER: 全部职业（%d/%d）" % [roster.size(), roster.size()], UIKit.TEXT_FAINT, 11)
	fl.autowrap_mode = TextServer.AUTOWRAP_OFF
	fl.position = Vector2(42, 668)
	add_child(fl)
	_dossier = Control.new()
	_dossier.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_dossier)
	if not roster.is_empty():
		_select(roster[0])
	UIKit.footer_bar(self, [["A", "确认选定"], ["B", "返回军营"], ["↑↓", "上下切换骑士"], ["ESC", "返回城堡"]], "CENTURY KNIGHTS · ROSTER v8.6")
	UIFX.stagger_children(_list, 0.04, 0.24)
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func apply_mobile_layout() -> void:
	_mobile_build()
	if _mob:
		return
	var scroll := find_child("RosterListScroll", true, false) as ScrollContainer
	var foot := find_child("StitchFooter", true, false) as Control
	MobileLayout.fill_scroll(scroll, foot, 508)

func _back() -> void:
	CKNav.up()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()

func _role_en(c: CKCharacter) -> String:
	var r := str(GameState.get_job(c.job_id).get("role", ""))
	return {"tank": "DEFENDER", "ranger": "ARCHER", "mage": "TACTICIAN", "cavalry": "VANGUARD", "healer": "SUPPORT"}.get(r, "STRIKER")

func _row(c: CKCharacter, idx: int) -> Button:
	var b := Button.new()
	var row_h := 66.0
	if DeviceProfile.is_mobile():
		row_h = maxf(row_h, DeviceProfile.hit_px())
	b.custom_minimum_size = Vector2(364, row_h)
	b.focus_mode = Control.FOCUS_ALL
	b.set_meta("cid", c.id)
	UIKit._apply_states(b, {
		"normal": UIKit.flat_box(Color(0.055, 0.067, 0.090, 0.92), Color(1, 1, 1, 0.10), 6),
		"hover": UIKit.flat_box(Color(0.07, 0.09, 0.12, 0.95), Color(UIKit.ACCENT, 0.45), 6),
		"pressed": UIKit.flat_box(Color(UIKit.ACCENT, 0.10), Color(UIKit.ACCENT, 0.8), 6, 2),
		"focus": UIKit._focus_ring(UIKit.FOCUS_RING, 8),
		"disabled": UIKit.flat_box(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.05), 6),
	})
	b.pressed.connect(func():
		UIFX.press_feedback(b)
		_select(c))
	b.focus_entered.connect(func(): _select(c))
	var nb := Panel.new()
	nb.position = Vector2(10, 14)
	nb.size = Vector2(36, 38)
	nb.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.16), 4))
	nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nb)
	var nn := UIKit.mono("%02d" % idx, 14, UIKit.TEXT, false)
	# Desktop: drop the "NO" micro-label (was 7px); center the index in the badge.
	nn.position = Vector2(7, 8 if not DeviceProfile.is_mobile() else 14)
	if DeviceProfile.is_mobile():
		var no := UIKit.mono("NO", 7, UIKit.TEXT_FAINT, false, false)
		no.position = Vector2(12, 4)
		nb.add_child(no)
	nb.add_child(nn)
	var nh := HBoxContainer.new()
	nh.position = Vector2(58, 10)
	nh.add_theme_constant_override("separation", 8)
	nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nh)
	var nm := UIKit.title_label(c.name, 16)
	nm.add_theme_color_override("font_color", UIKit.DANGER if c.injured else UIKit.TEXT)
	nh.add_child(nm)
	if c.is_leader:
		nh.add_child(UIKit.tag_chip("队长待命", UIKit.ACCENT))
	elif c.injured or CKInjury.label(c) != "":
		var chip := CKInjury.label(c)
		nh.add_child(UIKit.tag_chip(chip if chip != "" else "负伤", UIKit.DANGER))
	elif not c.traits.is_empty():
		nh.add_child(UIKit.tag_chip(str(GameState.get_trait(str(c.traits[0])).get("name", c.traits[0])), UIKit.OK))
	var sub := UIKit.body_label("%s · 年龄 %d 岁 · LV %d" % [GameState.get_job(c.job_id).get("name", ""), c.age, c.level], UIKit.TEXT_FAINT, 11)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.position = Vector2(58, 38)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sub)
	var cl := UIKit.mono("CLASS", 8, UIKit.TEXT_FAINT, false)
	cl.position = Vector2(318, 14)
	b.add_child(cl)
	var ce := UIKit.mono(_role_en(c), 9, UIKit.TEXT_DIM, false)
	ce.position = Vector2(352 - ce.get_minimum_size().x, 32)
	b.add_child(ce)
	_rows.append(b)
	return b

func _select(c: CKCharacter) -> void:
	if _selected == c and _dossier.get_child_count() > 0:
		return
	_selected = c
	for r in _rows:
		var on: bool = str(r.get_meta("cid")) == str(c.id)
		var s := UIKit.flat_box(Color(UIKit.ACCENT, 0.08) if on else Color(0.055, 0.067, 0.090, 0.92), Color(UIKit.ACCENT, 0.9) if on else Color(1, 1, 1, 0.10), 6, 2 if on else 1)
		if on:
			s.shadow_color = Color(UIKit.ACCENT, 0.22)
			s.shadow_size = 10
		r.add_theme_stylebox_override("normal", s)
	_render()

func _render() -> void:
	if _mob:
		_render_mobile()
		return
	for n in _dossier.get_children():
		_dossier.remove_child(n)
		n.queue_free()
	var c := _selected
	var p := UIKit.panel_at(_dossier, Rect2(436, 72, 802, 604), 12)
	var dt := UIKit.tag_chip("DOSSIER #%s" % str(c.id).right(3).to_upper(), UIKit.ACCENT)
	dt.position = Vector2(22, 18)
	p.add_child(dt)
	var idl := UIKit.mono("IDENTIFIER: %s // CENTURY KNIGHTS REGISTER" % str(c.id).to_upper(), 9, UIKit.TEXT_FAINT, false)
	idl.position = Vector2(140, 22)
	p.add_child(idl)
	var hurt := c.injured or CKInjury.label(c) != ""
	var status := _status_text(c)
	var st := UIKit.body_label(status, UIKit.OK if not hurt else UIKit.DANGER, 11)
	st.autowrap_mode = TextServer.AUTOWRAP_OFF
	st.position = Vector2(600, 20)
	st.size = Vector2(180, 16)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(st)
	UIKit.portrait_plate(p, Rect2(22, 52, 238, 330), c, "HALF-BODY PORTRAIT // SPEC 01", false, CKArtPaths.TIER_MEDIUM)
	var bio := UIKit.panel_at(p, Rect2(22, 394, 238, 120), 8)
	var bl := UIKit.mono("CHRONICLE BIO", 9, UIKit.TEXT_FAINT)
	bl.position = Vector2(14, 12)
	bio.add_child(bl)
	var bt := UIKit.body_label("「%s」" % ("%s旗家主。" % GameState.surname if c.is_leader else ("%s血胤。" % c.bloodline_display())), UIKit.TEXT, 13)
	bt.position = Vector2(14, 32)
	bt.size = Vector2(210, 20)
	bt.custom_minimum_size = Vector2(210, 0)
	bio.add_child(bt)
	var bd := UIKit.body_label("月薪 %d 银 · %s" % [c.salary, "联姻在世" if str(c.spouse_id) != "" else ("子嗣" if c.is_child else "旗下骑士")], UIKit.TEXT_FAINT, 11)
	bd.position = Vector2(14, 74)
	bd.size = Vector2(210, 32)
	bd.custom_minimum_size = Vector2(210, 0)
	bio.add_child(bd)
	# identity
	var x0 := 284.0
	var po := UIKit.mono("PRIMARY OPERATIVE", 9, UIKit.ACCENT)
	po.position = Vector2(x0, 54)
	p.add_child(po)
	var nm := UIKit.title_label(c.name, 30)
	nm.position = Vector2(x0, 70)
	p.add_child(nm)
	var er := UIKit.mono("EXPERIENCE RANK", 9, UIKit.TEXT_FAINT)
	er.position = Vector2(780 - er.get_minimum_size().x, 54)
	p.add_child(er)
	var lvl := Label.new()
	lvl.text = "LV. %d" % c.level
	lvl.add_theme_font_override("font", UIKit.font("mono"))
	lvl.add_theme_font_size_override("font_size", 20)
	lvl.add_theme_color_override("font_color", UIKit.ACCENT)
	lvl.position = Vector2(780 - 90, 72)
	lvl.size = Vector2(90, 26)
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(lvl)
	var job: Dictionary = GameState.get_job(c.job_id)
	var g := GridContainer.new()
	g.columns = 2
	g.position = Vector2(x0, 118)
	g.add_theme_constant_override("h_separation", 12)
	p.add_child(g)
	for it in [["职业 // CLASS", "%s · %s" % [job.get("name", ""), c.rank_name()]], ["年龄 // CHRONO AGE", "%d 岁" % c.age]]:
		var bx := UIKit.stat_box(it[0], it[1], UIKit.TEXT)
		bx.custom_minimum_size = Vector2(242, 0)
		g.add_child(bx)
	UIKit.section_head(p, Vector2(x0, 190), "CHARACTER TRAITS", "先天禀赋", 496, "%d 项禀性" % c.traits.size())
	var tx := x0
	var shown := 0
	for tr in c.traits:
		if shown >= 2:
			break
		var td: Dictionary = GameState.get_trait(str(tr))
		var tc := UIKit.panel_at(p, Rect2(tx, 214, 242, 92), 8, shown == 0)
		var ic := UIKit.trait_icon_rect(str(tr), 22.0)
		ic.position = Vector2(12, 12)
		tc.add_child(ic)
		var tn := UIKit.body_label(str(td.get("name", tr)), UIKit.TEXT, 14)
		tn.autowrap_mode = TextServer.AUTOWRAP_OFF
		tn.position = Vector2(42, 12)
		tc.add_child(tn)
		var pol := str(td.get("polarity", ""))
		var pc := UIKit.mono("PASSIVE" if pol != "neg" else "FLAW", 8, UIKit.OK if pol != "neg" else UIKit.DANGER, false)
		pc.position = Vector2(230 - pc.get_minimum_size().x, 16)
		tc.add_child(pc)
		var tdsc := UIKit.body_label(str(td.get("desc", "影响成长与战场检定。")), UIKit.TEXT_DIM, 11)
		tdsc.position = Vector2(12, 42)
		tdsc.size = Vector2(218, 44)
		tdsc.custom_minimum_size = Vector2(218, 0)
		tdsc.clip_text = true
		tc.add_child(tdsc)
		tx += 254
		shown += 1
	if c.traits.is_empty():
		var nt := UIKit.body_label("（禀性未显）", UIKit.TEXT_FAINT, 12)
		nt.position = Vector2(x0, 220)
		p.add_child(nt)
	UIKit.section_head(p, Vector2(x0, 322), "COMBAT PROFILE", "六维与派生", 496, "血胤 %s" % c.bloodline_display())
	var sg := GridContainer.new()
	sg.columns = 6
	sg.position = Vector2(x0, 346)
	sg.add_theme_constant_override("h_separation", 6)
	p.add_child(sg)
	for sk in CKCharacter.STAT_KEYS:
		var bx := UIKit.stat_box(Locale.t("stat_" + sk), str(c.stats[sk]), UIKit.TEXT)
		bx.custom_minimum_size = Vector2(78, 0)
		sg.add_child(bx)
	var hl := UIKit.hairline(Color(1, 1, 1, 0.07))
	hl.position = Vector2(x0, 424)
	hl.size = Vector2(496, 1)
	p.add_child(hl)
	var dr := HBoxContainer.new()
	dr.position = Vector2(x0, 436)
	dr.add_theme_constant_override("separation", 22)
	p.add_child(dr)
	var move_now := c.derived_move() + CKInjury.move_mod(c)
	for it in _derived_rows(c, move_now):
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var k := UIKit.body_label(str(it[0]), UIKit.TEXT_FAINT, 11)
		k.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(k)
		v.add_child(UIKit.mono(str(it[1]), 15, it[2], false))
		dr.add_child(v)
	var tok := TextureRect.new()
	tok.texture = UnitArt.token(c, "player", 64, false)  # placeholder until the 3D figure lands
	tok.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tok.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tok.position = Vector2(680, 390)
	tok.size = Vector2(110, 140)
	if UnitArt.board_pawns_enabled():
		CKBoardFigures.ensure(self).bind(tok, c, "player")
	tok.tooltip_text = "战棋棋子预览"
	p.add_child(tok)
	var fh := UIKit.hairline(Color(1, 1, 1, 0.07))
	fh.position = Vector2(22, 532)
	fh.size = Vector2(758, 1)
	p.add_child(fh)
	var oid := UIKit.mono("OPERATIVE ID: %s" % str(c.id).to_upper(), 9, UIKit.TEXT_FAINT, false)
	oid.position = Vector2(22, 556)
	p.add_child(oid)
	var br := HBoxContainer.new()
	br.position = Vector2(180, 546)
	br.size = Vector2(590, 44)
	br.alignment = BoxContainer.ALIGNMENT_END
	br.add_theme_constant_override("separation", 10)
	p.add_child(br)
	var acts := _actions(c)
	var b1 := UIKit.ghost_button(acts[0][0], 128, 44)
	b1.name = "OpenDossier"
	b1.pressed.connect(acts[0][2])
	br.add_child(b1)
	var b1b := UIKit.ghost_button(acts[1][0], 88, 44)
	b1b.pressed.connect(acts[1][2])
	br.add_child(b1b)
	var b2 := UIKit.ghost_button(acts[2][0], 128, 38)
	b2.pressed.connect(acts[2][2])
	br.add_child(b2)
	var b3 := UIKit.cta_button(acts[3][0], "A", 150, 38)
	b3.pressed.connect(acts[3][2])
	br.add_child(b3)

func _status_text(c: CKCharacter) -> String:
	var hurt := c.injured or CKInjury.label(c) != ""
	var block := CKInjury.deploy_block_reason(c)
	if block != "":
		return "● " + block
	if hurt:
		return "● 伤病休整中"
	return "● 驻地战备良好"

func _derived_rows(c: CKCharacter, move_now: int) -> Array:
	return [["生命值", "%d/%d" % [c.hp, c.max_hp], UIKit.OK if not c.injured else UIKit.DANGER],
		["攻击", str(c.derived_atk()), UIKit.TEXT], ["防御", str(c.derived_def()), UIKit.TEXT],
		["命中", str(c.derived_hit()), UIKit.TEXT], ["回避", str(c.derived_avo()), UIKit.TEXT], ["移动", str(move_now), UIKit.ACCENT]]

func _actions(c: CKCharacter) -> Array:
	var x_key := "" if DeviceProfile.is_mobile() else "  (X)"
	return [
		["血脉详档", false, func():
			Sfx.click()
			GameState.set_meta("dossier_id", c.id)
			GameState.set_meta("dossier_back", "res://scenes/hub/roster.tscn")
			CKNav.go("res://scenes/hub/unit_dossier.tscn")],
		["族谱", false, func(): CKNav.go("res://scenes/hub/lineage_view.tscn")],
		["锻造装备" + x_key, false, func(): CKNav.go("res://scenes/hub/forge.tscn")],
		["委派出战", true, func(): CKNav.go("res://scenes/hub/deploy.tscn")],
	]

## ── landscape phone ───────────────────────────────────────
var _mob := false
var _m_list: VBoxContainer
var _m_dossier: VBoxContainer

func _mobile_build() -> void:
	if _mob or not MobilePage.active(self):
		return
	_mob = true
	for c in get_children():
		if c is CanvasItem and c.get_index() > 0:
			(c as CanvasItem).visible = false
	var roster: Array = GameState.roster()
	var pay := 0
	for c in roster:
		pay += int(c.salary)
	var info := "%s %d · %s" % [Locale.t("shell_946c7148"), GameState.silver, Locale.t("shell_445ffb2d") % roster.size()]
	MobilePage.top_bar(self, Locale.t("btn_roster"), info, [[Locale.t("btn_back"), _back]])
	var w := MobilePage.width(self)
	var lv := MobilePage.panel(self, Rect2(26, MobilePage.TOP, 400, 720 - MobilePage.TOP - 8), 10)
	var sc := ScrollContainer.new()
	sc.name = "RosterListScroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sc)
	_m_list = VBoxContainer.new()
	_m_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m_list.add_theme_constant_override("separation", 8)
	sc.add_child(_m_list)
	_rows.clear()
	var i := 0
	for c in roster:
		i += 1
		var b := MobilePage.button("%02d  %s\n%s · LV %d" % [i, c.name, str(GameState.get_job(c.job_id).get("name", "")), c.level], false, _select.bind(c))
		b.custom_minimum_size = Vector2(0, 96)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_meta("cid", c.id)
		if c.injured:
			b.add_theme_color_override("font_color", UIKit.DANGER)
		_m_list.add_child(b)
		_rows.append(b)
	_m_dossier = MobilePage.panel(self, Rect2(438, MobilePage.TOP, w - 438 - 24, 720 - MobilePage.TOP - 8), 14)
	if _selected:
		var c0 := _selected
		_selected = null
		_select(c0)

func _render_mobile() -> void:
	for n in _m_dossier.get_children():
		_m_dossier.remove_child(n)
		n.queue_free()
	var c := _selected
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_m_dossier.add_child(top)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(220, 300)
	top.add_child(holder)
	UIKit.portrait_plate(holder, Rect2(0, 0, 220, 300), c, "", false, CKArtPaths.TIER_MEDIUM)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	top.add_child(info)
	info.add_child(MobilePage.label("%s   LV %d" % [c.name, c.level], UIKit.TEXT, 30, false))
	var job: Dictionary = GameState.get_job(c.job_id)
	info.add_child(MobilePage.label("%s · %s · %s" % [job.get("name", ""), c.rank_name(), Locale.t("shell_5a0a47eb") % c.age], UIKit.ACCENT))
	var hurt := c.injured or CKInjury.label(c) != ""
	info.add_child(MobilePage.label(_status_text(c), UIKit.DANGER if hurt else UIKit.OK))
	var shown := 0
	for tr in c.traits:
		if shown >= 2:
			break
		var td: Dictionary = GameState.get_trait(str(tr))
		info.add_child(MobilePage.label("「%s」%s" % [str(td.get("name", tr)), str(td.get("desc", ""))], UIKit.TEXT_DIM))
		shown += 1
	var sg := GridContainer.new()
	sg.columns = 6
	sg.add_theme_constant_override("h_separation", 14)
	info.add_child(sg)
	for sk in CKCharacter.STAT_KEYS:
		sg.add_child(MobilePage.label("%s %s" % [Locale.t("stat_" + sk), str(c.stats[sk])], UIKit.TEXT, MobilePage.FONT, false))
	var dg := GridContainer.new()
	dg.columns = 6
	dg.add_theme_constant_override("h_separation", 14)
	info.add_child(dg)
	for it in _derived_rows(c, c.derived_move() + CKInjury.move_mod(c)):
		dg.add_child(MobilePage.label("%s %s" % [it[0], it[1]], it[2], MobilePage.FONT, false))
	if UnitArt.board_pawns_enabled():  # board-piece preview: same 3D figure as the battle grid
		var fig := TextureRect.new()
		fig.custom_minimum_size = Vector2(170, 240)
		fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fig.tooltip_text = "战棋棋子预览"
		top.add_child(fig)
		CKBoardFigures.ensure(self).bind(fig, c, "player")
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 10)
	_m_dossier.add_child(br)
	var acts := _actions(c)
	for ai in acts.size():
		var a: Array = acts[ai]
		var b := MobilePage.button(str(a[0]), bool(a[1]), a[2])
		if ai == 0:
			b.name = "OpenDossier"
		br.add_child(b)
