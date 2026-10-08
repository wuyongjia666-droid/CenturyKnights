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
	var scroll := find_child("RosterListScroll", true, false) as ScrollContainer
	var foot := find_child("StitchFooter", true, false) as Control
	MobileLayout.fill_scroll(scroll, foot, 508)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")

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
	var no := UIKit.mono("NO", 7, UIKit.TEXT_FAINT, false)
	no.position = Vector2(12, 4)
	nb.add_child(no)
	var nn := UIKit.mono("%02d" % idx, 14, UIKit.TEXT, false)
	nn.position = Vector2(7, 14)
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
	elif c.injured:
		nh.add_child(UIKit.tag_chip("负伤", UIKit.DANGER))
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
	var st := UIKit.body_label("● 驻地战备良好" if not c.injured else "● 伤病休整中", UIKit.OK if not c.injured else UIKit.DANGER, 11)
	st.autowrap_mode = TextServer.AUTOWRAP_OFF
	st.position = Vector2(600, 20)
	st.size = Vector2(180, 16)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(st)
	UIKit.portrait_plate(p, Rect2(22, 52, 238, 330), c, "HALF-BODY PORTRAIT // SPEC 01")
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
	for it in [["生命值", "%d/%d" % [c.hp, c.max_hp], UIKit.OK if not c.injured else UIKit.DANGER], ["攻击", str(c.derived_atk()), UIKit.TEXT], ["防御", str(c.derived_def()), UIKit.TEXT], ["命中", str(c.derived_hit()), UIKit.TEXT], ["回避", str(c.derived_avo()), UIKit.TEXT], ["移动", str(c.derived_move()), UIKit.ACCENT]]:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var k := UIKit.body_label(str(it[0]), UIKit.TEXT_FAINT, 11)
		k.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(k)
		v.add_child(UIKit.mono(str(it[1]), 15, it[2], false))
		dr.add_child(v)
	var tok := TextureRect.new()
	tok.texture = UnitArt.token(c, "player", 64, false)
	tok.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tok.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tok.position = Vector2(716, 430)
	tok.size = Vector2(56, 56)
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
	var b1 := UIKit.ghost_button("血脉详档", 128, 44)
	b1.name = "OpenDossier"
	b1.pressed.connect(func():
		Sfx.click()
		GameState.set_meta("dossier_id", c.id)
		GameState.set_meta("dossier_back", "res://scenes/hub/roster.tscn")
		get_tree().change_scene_to_file("res://scenes/hub/unit_dossier.tscn"))
	br.add_child(b1)
	var b1b := UIKit.ghost_button("族谱", 88, 44)
	b1b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/lineage_view.tscn"))
	br.add_child(b1b)
	var b2 := UIKit.ghost_button("锻造装备  (X)", 128, 38)
	b2.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/forge.tscn"))
	br.add_child(b2)
	var b3 := UIKit.cta_button("委派出战", "A", 150, 38)
	b3.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/deploy.tscn"))
	br.add_child(b3)
