extends Control
## 属地庄园：单堡多属地 · 庄头委任 · 产出预览 · 劫掠提示（美术升档图标）

var _msg: Label
var _list: VBoxContainer
var _picker_hid: String = ""
var _picker: Control
var _kpis: Control

func _ready() -> void:
	## v8.6 — layout-matched to Stitch 16_estates.png: top bar · header · 3 KPI cards (粮仓/金库/工事) ·
	## HOLDING MATRIX rows (icon · name/chips · yield delta · focus segmented · steward · actions) · footer
	UIKit.void_bg(self)
	var first_note := grant_first_holding()
	UIFX.fade_in(self, 0.28)
	Music.play_castle()
	UIKit.top_bar(self, "领地营建 · 四野属地", UIKit.std_resource_chips(), "返回城堡", func(): CKNav.up())
	_place_estates_crests()
	UIKit.page_head(self, 42, 70, "ESTATE SANCTUARY INFRASTRUCTURE // SECTOR 01", "领地营建", "TERRITORIAL PROSPERITY")
	var sum := UIKit.body_label(_sum_text(), UIKit.TEXT_DIM, 12)
	sum.name = "Sum"
	sum.autowrap_mode = TextServer.AUTOWRAP_OFF
	sum.position = Vector2(738, 106)
	sum.size = Vector2(500, 18)
	sum.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(sum)
	_kpis = Control.new()
	_kpis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kpis)
	_build_kpis()
	UIKit.section_head(self, Vector2(42, 270), "属地改修名录", "HOLDING RETROFIT MATRIX", 1196, "")
	var fcount := UIKit.body_label(_focus_counts_text(), UIKit.TEXT_FAINT, 11)
	fcount.name = "FocusCounts"
	fcount.autowrap_mode = TextServer.AUTOWRAP_OFF
	fcount.position = Vector2(838, 271)
	fcount.size = Vector2(400, 16)
	fcount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(fcount)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(38, 290)
	scroll.size = Vector2(1206, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)
	_rebuild()
	UIFX.stagger_children(_list, 0.05, 0.26)
	_msg = UIKit.body_label("", UIKit.OK, 12)
	_msg.autowrap_mode = TextServer.AUTOWRAP_OFF
	_msg.position = Vector2(42, 664)
	_msg.size = Vector2(700, 18)
	add_child(_msg)
	var row := HBoxContainer.new()
	row.position = Vector2(838, 654)
	row.size = Vector2(400, 36)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var works := UIKit.ghost_button("工事 / 堡志", 112, 36)
	works.pressed.connect(func(): CKNav.go("res://scenes/hub/works.tscn"))
	row.add_child(works)
	var field := UIKit.cta_button(Locale.t("ux_estates_field"), "F", 160, 48)
	field.name = "FieldBookBtn"
	field.pressed.connect(open_field_book)
	row.add_child(field)
	var patrol := UIKit.cta_button("全堡巡防", "X", 150, 36)
	patrol.pressed.connect(_do_patrol)
	row.add_child(patrol)
	if first_note != "":
		_msg.text = first_note
	UIKit.footer_bar(self, [["A", "执行升级"], ["X", "全堡巡防"], ["Y", "委任庄头"], ["ESC", "返回城堡"]], "ESTATE PROTOCOL · FROST_TACTICAL v8.6")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		if _picker != null and is_instance_valid(_picker):
			_picker.queue_free()
			_picker = null
		else:
			CKNav.up()

func _yield_totals() -> Dictionary:
	var t := {"food": 0, "silver": 0, "herb": 0, "fort": 0, "stewards": 0, "open": 0}
	for hid in GameState.HOLDING_DEFS.keys():
		if not GameState.holding_unlocked(hid):
			continue
		t.open += 1
		var pv = GameState.holding_yield_preview(hid)
		t.food += int(pv.food)
		t.silver += int(pv.silver)
		t.herb += int(pv.get("herb", 0))
		if str(GameState.holding_focus(hid)) == "fortify":
			t.fort += 1
		if GameState.steward_of(hid) != null:
			t.stewards += 1
	return t

func _build_kpis() -> void:
	for c in _kpis.get_children():
		_kpis.remove_child(c)
		c.queue_free()
	var t := _yield_totals()
	var cool_txt := ("冷却 %d" % int(GameState.patrol_cooldown)) if int(GameState.patrol_cooldown) > 0 else "可巡防"
	var patrol_txt := ("巡防中 %d 月" % int(GameState.patrol_boost_months)) if int(GameState.patrol_boost_months) > 0 else cool_txt
	var cards := [
		{"icon": "grain", "en": "GRANARY DEPOT", "zh": "粮仓", "chip": "OPEN %d / 4" % t.open, "lab": "月结净产 // MONTHLY YIELD", "big": "+%d" % t.food, "unit": "粮 / 月结",
				"col": UIKit.TEXT, "foot": "已开垦属地", "v": t.open, "max": 4, "bar": UIKit.ACCENT},
		{"icon": "cash", "en": "IMPERIAL TREASURY", "zh": "金库", "chip": "STEWARDS %d" % t.stewards, "lab": "月结岁入 // MONTHLY REVENUE", "big": "+%d" % t.silver,
				"unit": "银 / 月结", "col": UIKit.ACCENT, "foot": "庄头委任", "v": t.stewards, "max": max(1, t.open), "bar": UIKit.OK},
		{"icon": "fortify", "en": "DEFENSE FORTIFICATIONS", "zh": "工事", "chip": patrol_txt, "lab": "戍卫属地 // BULWARK", "big": "%d 处" % t.fort, "unit": "戍卫偏向",
				"col": UIKit.TEXT, "foot": "总等级", "v": GameState.total_holding_levels(), "max": 12, "bar": UIKit.ACCENT},
	]
	for i in cards.size():
		var cd: Dictionary = cards[i]
		var p := UIKit.panel_at(_kpis, Rect2(42 + i * 404, 132, 388, 126), 10)
		var ib := UIKit.panel_at(p, Rect2(18, 18, 38, 38), 6)
		var ic := TextureRect.new()
		var ipath := "res://assets/art/ui/v86/kpi_%s.png" % cd.icon
		if ResourceLoader.exists(ipath):
			ic.texture = load(ipath)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(3, 3)
		ic.size = Vector2(32, 32)
		ib.add_child(ic)
		var en := UIKit.mono(str(cd.en), 9, UIKit.TEXT_FAINT)
		en.position = Vector2(66, 18)
		p.add_child(en)
		var zh := UIKit.title_label(str(cd.zh), 19)
		zh.position = Vector2(66, 30)
		p.add_child(zh)
		var chip := UIKit.tag_chip(str(cd.chip), UIKit.ACCENT)
		chip.position = Vector2(370 - chip.get_combined_minimum_size().x, 22)
		p.add_child(chip)
		var lab := UIKit.mono(str(cd.lab), 9, UIKit.TEXT_FAINT, false)
		lab.position = Vector2(18, 64)
		p.add_child(lab)
		var big := Label.new()
		big.text = str(cd.big)
		big.add_theme_font_override("font", UIKit.font("mono"))
		big.add_theme_font_size_override("font_size", 28)
		big.add_theme_color_override("font_color", cd.col)
		big.position = Vector2(18, 74)
		p.add_child(big)
		var un := UIKit.body_label(str(cd.unit), UIKit.TEXT_FAINT, 11)
		un.autowrap_mode = TextServer.AUTOWRAP_OFF
		un.position = Vector2(24 + big.get_minimum_size().x, 90)
		un.size = Vector2(120, 16)
		p.add_child(un)
		var ft := UIKit.body_label("%s：%d / %d" % [cd.foot, cd.v, cd.max], UIKit.TEXT_FAINT, 11)
		ft.autowrap_mode = TextServer.AUTOWRAP_OFF
		ft.position = Vector2(210, 92)
		ft.size = Vector2(160, 16)
		ft.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p.add_child(ft)
		var bar := UIKit.slim_bar(float(cd.v), float(cd.max), cd.bar, 352, 3)
		bar.position = Vector2(18, 112)
		p.add_child(bar)

func _focus_counts_text() -> String:
	var n := {"grain": 0, "cash": 0, "fortify": 0}
	for hid in GameState.HOLDING_DEFS.keys():
		if GameState.holding_unlocked(hid):
			var f = str(GameState.holding_focus(hid))
			n[f] = int(n.get(f, 0)) + 1
	return "粮作 %d　·　钱作 %d　·　戍卫 %d" % [n.grain, n.cash, n.fortify]

func _refresh_focus_counts() -> void:
	var fc = get_node_or_null("FocusCounts")
	if fc: fc.text = _focus_counts_text()

func _focus_tile(fk: String, current: bool, hid: String) -> Button:
	## v8.6 segmented focus control (粮作/钱作/戍卫): current = frost fill; five states via theme
	var flab = {"grain": "粮作", "cash": "钱作", "fortify": "戍卫"}[fk]
	var b: Button = UIKit.make_accent_button(flab, 58) if current else UIKit.make_button(flab, 58)
	b.custom_minimum_size = Vector2(58, 30)
	b.add_theme_font_size_override("font_size", 12)
	UIKit.compact(b, 30)
	b.tooltip_text = {"grain": "粮作：月结偏粮", "cash": "钱作：月结偏银", "fortify": "戍卫：抗劫掠"}[fk] + "（改作10银/冷却2月）"
	var capt_h = hid
	b.pressed.connect(func():
		UIFX.press_feedback(b)
		if current:
			_msg.text = "已是当前经营偏向：%s" % flab
			return
		var rr = GameState.set_holding_focus(capt_h, fk)
		_msg.text = str(rr.get("msg"))
		if rr.get("ok"):
			UIFX.confirm(b)
			Sfx.confirm()
			GameState.save_game()
			_after_change()
		else:
			UIFX.soft_deny(b)
	)
	return b


func _place_estates_crests() -> void:
	## Estates chrome: 团徽 header + castle banner strip.
	var mob := DeviceProfile.is_mobile()
	var hdr := Vector2(44, 52) if not mob else Vector2(40, 48)
	CKHeraldryField.place_company_header(self, Vector2(1180, 8) if not mob else Vector2(1180, 4), hdr)
	CKHeraldryField.place_banner_plate(self, Vector2(1120, 8) if not mob else Vector2(1120, 4), hdr, Vector2(28, 38))

func apply_mobile_layout() -> void:
	if MobilePage.active(self):
		_m_build()

func _after_change() -> void:
	if has_meta("m_on"):
		_m_build()
		return
	_rebuild()
	_refresh_focus_counts()
	_build_kpis()
	var sum2 = get_node_or_null("Sum")
	if sum2: sum2.text = _sum_text()

func _sum_text() -> String:
	var stewards = 0
	for hid in GameState.holdings.keys():
		if str(GameState.holdings[hid].get("steward_id", "")) != "":
			stewards += 1
	var extra = ""
	if int(GameState.patrol_boost_months) > 0:
		extra += "　巡防中(%d月)" % int(GameState.patrol_boost_months)
	elif int(GameState.patrol_cooldown) > 0:
		extra += "　巡防冷却(%d)" % int(GameState.patrol_cooldown)
	if int(GameState.estate_quiet_months) > 0:
		extra += "　安静%d月" % int(GameState.estate_quiet_months)
	return "工匠调度：已开垦 %d / 4 · 总等级 %d · 庄头 %d%s" % [
		GameState.unlocked_holdings_count(), GameState.total_holding_levels(), stewards, extra]

func _rebuild() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_month_echo_feel(_list)
	var focused_done := false
	for hid in GameState.HOLDING_DEFS.keys():
		var def: Dictionary = GameState.HOLDING_DEFS[hid]
		var unlocked = GameState.holding_unlocked(hid)
		var lv = GameState.holding_level(hid)
		var focused: bool = unlocked and lv < 3 and not focused_done
		if focused:
			focused_done = true
		var row := Control.new()
		row.custom_minimum_size = Vector2(1196, 88)
		_list.add_child(row)
		var p := UIKit.panel_at(row, Rect2(2, 2, 1192, 84), 8, focused)
		if not unlocked:
			p.modulate = Color(1, 1, 1, 0.62)
		# icon box
		var ib := UIKit.panel_at(p, Rect2(16, 14, 56, 56), 8)
		var icon := TextureRect.new()
		icon.position = Vector2(2, 2)
		icon.size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ip = "res://assets/art/estates/%s.png" % hid
		if ResourceLoader.exists(ip):
			icon.texture = load(ip)
		ib.add_child(icon)
		# name + chips + desc
		var nh := HBoxContainer.new()
		nh.position = Vector2(88, 16)
		nh.add_theme_constant_override("separation", 8)
		p.add_child(nh)
		var nm := UIKit.title_label(str(def.name), 17)
		nm.add_theme_font_override("font", UIKit.font("bold"))
		nh.add_child(nm)
		nh.add_child(UIKit.tag_chip(("LV %d / 3" % lv) if unlocked else "未开垦", UIKit.TEXT_DIM))
		if unlocked and lv < 3:
			nh.add_child(UIKit.tag_chip("● 可升级", UIKit.OK))
		elif unlocked:
			nh.add_child(UIKit.tag_chip("✓ 已满级", UIKit.ACCENT))
		var st = GameState.steward_of(hid) if unlocked else null
		var dsc := str(def.desc) + ("　庄头：%s" % st.name if st != null else ("　庄头空缺 · 易遭劫掠" if unlocked else Locale.t("wsc_e_how") % _quest_name(str(def.get("quest", "")))))
		var dl := UIKit.body_label(dsc, UIKit.TEXT_FAINT, 12)
		dl.autowrap_mode = TextServer.AUTOWRAP_OFF
		dl.clip_text = true
		dl.position = Vector2(88, 50)
		dl.size = Vector2(300, 18)
		p.add_child(dl)
		# yield delta box
		var yb := UIKit.panel_at(p, Rect2(404, 12, 214, 60), 6)
		yb.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.08), 6))
		var yl := UIKit.mono("月结产出 // YIELD", 9, UIKit.TEXT_FAINT, false)
		yl.position = Vector2(12, 8)
		yb.add_child(yl)
		var ytxt := "—"
		if unlocked:
			var pv = GameState.holding_yield_preview(hid)
			ytxt = "粮 +%d   银 +%d" % [int(pv.food), int(pv.silver)]
			if int(pv.get("herb", 0)) > 0:
				ytxt += "   药 +%d" % int(pv.herb)
		var yv := Label.new()
		yv.text = ytxt
		yv.add_theme_font_override("font", UIKit.font("bold"))
		yv.add_theme_font_size_override("font_size", 14)
		yv.add_theme_color_override("font_color", UIKit.TEXT if unlocked else UIKit.TEXT_FAINT)
		yv.position = Vector2(12, 26)
		yb.add_child(yv)
		var bid = hid
		if unlocked:
			# focus segmented
			var fl := UIKit.mono("经营偏向 // FOCUS", 9, UIKit.TEXT_FAINT, false)
			fl.position = Vector2(636, 14)
			p.add_child(fl)
			var fb := HBoxContainer.new()
			fb.position = Vector2(636, 34)
			fb.add_theme_constant_override("separation", 4)
			p.add_child(fb)
			var foc = GameState.holding_focus(hid)
			for fk in ["grain", "cash", "fortify"]:
				fb.add_child(_focus_tile(fk, fk == foc, hid))
			# cost / patrol meta
			var ml := UIKit.mono("升级 // COST", 9, UIKit.TEXT_FAINT, false)
			ml.position = Vector2(840, 14)
			p.add_child(ml)
			var mv := UIKit.body_label(("%d 银 · %d 粮" % [40 * lv, 8 * lv]) if lv < 3 else "MAX", UIKit.TEXT if lv < 3 else UIKit.TEXT_FAINT, 13)
			mv.autowrap_mode = TextServer.AUTOWRAP_OFF
			mv.position = Vector2(840, 36)
			mv.size = Vector2(130, 18)
			p.add_child(mv)
			var pt := ""
			if GameState.holding_patrol_cd(bid) > 0:
				pt = "巡防冷却 %d 月" % GameState.holding_patrol_cd(bid)
			elif GameState.holding_patrol_boost(bid) > 0:
				pt = "巡防中 %d 月" % GameState.holding_patrol_boost(bid)
			if pt != "":
				var pl := UIKit.body_label(pt, UIKit.OK, 11)
				pl.autowrap_mode = TextServer.AUTOWRAP_OFF
				pl.position = Vector2(840, 58)
				pl.size = Vector2(130, 16)
				p.add_child(pl)
		# actions column
		var ac := VBoxContainer.new()
		ac.position = Vector2(986, 11)
		ac.size = Vector2(190, 68)
		ac.add_theme_constant_override("separation", 4)
		p.add_child(ac)
		if unlocked and lv < 3:
			var b := UIKit.cta_button("升级属地", "A" if focused else "", 190, 32)
			b.pressed.connect(func(): _upgrade(bid))
			ac.add_child(b)
		else:
			var b2 := UIKit.ghost_button("已满级" if unlocked else "前置未满足", 190, 32)
			b2.disabled = true
			ac.add_child(b2)
		if unlocked:
			var sr := HBoxContainer.new()
			sr.add_theme_constant_override("separation", 6)
			ac.add_child(sr)
			if st != null:
				var bc := UIKit.ghost_button("撤庄头", 93, 26)
				bc.pressed.connect(func(): _clear_steward(bid))
				sr.add_child(bc)
			else:
				var bs := UIKit.ghost_button("委任庄头", 93, 26)
				bs.pressed.connect(func(): _open_picker(bid))
				sr.add_child(bs)
			var pb := UIKit.ghost_button("巡此路线", 93, 26)
			pb.disabled = GameState.holding_patrol_cd(bid) > 0 or GameState.holding_patrol_boost(bid) > 0
			pb.pressed.connect(func(): _do_patrol_one(bid))
			sr.add_child(pb)

func _upgrade(hid: String) -> void:
	var r = GameState.upgrade_holding(hid)
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		Sfx.confirm()
		GameState.save_game()
		_after_change()
	else:
		Sfx.miss()

func _clear_steward(hid: String) -> void:
	GameState.clear_steward(hid)
	GameState.save_game()
	_msg.text = "已撤下庄头"
	Sfx.confirm()
	_after_change()

func _open_picker(hid: String) -> void:
	_picker_hid = hid
	if _picker != null and is_instance_valid(_picker):
		_picker.queue_free()
	if has_meta("m_on"):
		_m_picker(hid)
		return
	_picker = UIKit.panel_at(self, Rect2(320, 120, 640, 480), 12, true)
	_picker.z_index = 20
	var title = UIKit.make_label("选择庄头 — %s" % GameState.HOLDING_DEFS[hid].name, true)
	title.position = Vector2(16, 12)
	_picker.add_child(title)
	var tip = UIKit.make_dim_label("花名册存活成员；一人仅可管一处属地。")
	tip.position = Vector2(16, 48)
	_picker.add_child(tip)
	var sc := ScrollContainer.new()
	sc.position = Vector2(16, 80)
	sc.custom_minimum_size = Vector2(600, 340)
	_picker.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	sc.add_child(vb)
	for c in GameState.roster():
		if c == null or not c.alive:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vb.add_child(row)
		var tex = UnitArt.portrait(c, 48)
		var tr = TextureRect.new()
		tr.custom_minimum_size = Vector2(48, 48)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if tex != null:
			tr.texture = tex
		row.add_child(tr)
		var lab = UIKit.make_label("%s　%s　Lv%d" % [c.name, c.job_id, c.level])
		lab.custom_minimum_size = Vector2(320, 0)
		row.add_child(lab)
		var cid = c.id
		var bb = UIKit.make_accent_button("委任", 80)
		bb.pressed.connect(func(): _do_assign(cid))
		row.add_child(bb)
	var close = UIKit.make_button("关闭", 100)
	close.position = Vector2(16, 430)
	close.pressed.connect(func():
		if _picker != null and is_instance_valid(_picker):
			_picker.queue_free()
			_picker = null
	)
	_picker.add_child(close)

func _do_assign(cid: String) -> void:
	var r = GameState.assign_steward(_picker_hid, cid)
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		Sfx.confirm()
		GameState.save_game()
		if _picker != null and is_instance_valid(_picker):
			_picker.queue_free()
			_picker = null
		_after_change()
	else:
		Sfx.miss()

## WS-C #37: the first holding is open from day one (new games and old saves with none), so the page is never all grey.
func _month_echo_feel(parent: Node) -> void:
	## Y1-B 月循环加深：属地页回读上月领地/属地收成；尚无则 CTA 去沙漏。
	if Lineage.is_dynasty_ended():
		Lineage.attach_dynasty_end_feel(parent, 1190.0)
	var panel := VBoxContainer.new()
	panel.name = "MonthEchoPanel"
	panel.add_theme_constant_override("separation", 6)
	panel.custom_minimum_size = Vector2(1190, 0)
	parent.add_child(panel)
	panel.add_child(UIKit.mono(Locale.t("lb_est_echo_head"), 9, UIKit.ACCENT, false))
	var rows := CKEconomyState.month_echo_lines()
	if rows.is_empty():
		## Y1-B: no month echo yet → EmptyHost why/how + ToHourglass.
		var host := VBoxContainer.new()
		host.name = "EmptyHost"
		host.add_theme_constant_override("separation", 12)
		host.add_child(CKPageKit.empty(
			Locale.t("lb_est_echo_empty"),
			Locale.t("lb_est_echo_why"),
			Locale.t("lb_est_echo_empty_how"),
			1100
		))
		var acts := HBoxContainer.new()
		acts.name = "EmptyActions"
		acts.add_theme_constant_override("separation", 12)
		var to_h := CKPageKit.button(Locale.t("lb_est_to_hourglass"), true, 280)
		to_h.name = "ToHourglass"
		to_h.pressed.connect(func(): CKNav.go("res://scenes/hub/hourglass.tscn"))
		acts.add_child(to_h)
		UIFX.wire_button(to_h)
		host.add_child(acts)
		panel.add_child(host)
		return
	var snap := CKEconomyState.month_echo_snapshot()
	panel.add_child(CKPageKit.text(Locale.t("lb_est_echo_when", [str(snap.get("label", ""))]), UIKit.TEXT_DIM, 12, 1100))
	for row in rows:
		var line := CKPageKit.text(str(row.get("text", "")), UIKit.OK, 14, 1100)
		line.name = "EchoLine_%s" % str(row.get("kind", "x"))
		panel.add_child(line)


static func grant_first_holding() -> String:
	if not GameState.holdings.is_empty():
		return ""
	var hid: String = str(GameState.HOLDING_DEFS.keys()[0])
	GameState.unlock_holding(hid)
	GameState.save_game()
	return Locale.t("wsc_e_first") % str(GameState.HOLDING_DEFS[hid].get("name", hid))

static func _quest_name(qid: String) -> String:
	for q in GameState.quests:
		if str(q.get("id", "")) == qid:
			return str(q.get("name", qid))
	return qid

func _do_patrol() -> void:
	var r = GameState.patrol_holdings()
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		Sfx.confirm()
		GameState.save_game()
		_after_change()
		_show_patrol_vignette("", str(r.get("msg", "")))
	else:
		Sfx.miss()
		_show_result(Locale.t("wsc_e_fail_title"), str(r.get("msg", "")))

func _do_patrol_one(hid: String) -> void:
	var r = GameState.patrol_holding(hid)
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		Sfx.confirm()
		GameState.save_game()
		_after_change()
		_show_patrol_vignette(hid, str(r.get("msg", "")))
	else:
		Sfx.miss()
		_show_result(Locale.t("wsc_e_fail_title"), str(r.get("msg", "")))

## WS-C #37: failure (no silver, cooldown, nothing unlocked) gets a box with the reason, not just a beep.
func _show_result(title: String, body: String) -> void:
	var overlay := ColorRect.new()
	overlay.name = "PatrolResult"
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 30
	add_child(overlay)
	if has_meta("m_on"):
		overlay.queue_free()
		var sh := MobilePage.sheet(self, "PatrolResult", title, 30, UIKit.DANGER)
		var sv: VBoxContainer = sh[1]
		sv.add_child(MobilePage.label(body + "\n" + Locale.t("wsc_e_fail_hint"), UIKit.TEXT, 24, true))
		var okb := MobilePage.button(Locale.t("wsc_t_lost_ok"), true, (sh[0] as Node).queue_free)
		sv.add_child(okb)
		okb.call_deferred("grab_focus")
		return
	var p := UIKit.panel_at(overlay, Rect2(390, 240, 500, 220), 14, true)
	var t := UIKit.title_label(title, 20, UIKit.DANGER)
	t.position = Vector2(24, 20)
	p.add_child(t)
	var b := UIKit.body_label(body + "\n" + Locale.t("wsc_e_fail_hint"), UIKit.TEXT, 14)
	b.position = Vector2(24, 64)
	b.size = Vector2(452, 90)
	p.add_child(b)
	var ok := UIKit.ghost_button(Locale.t("wsc_t_lost_ok"), 160, 48)
	ok.position = Vector2(316, 156)
	ok.pressed.connect(overlay.queue_free)
	p.add_child(ok)
	ok.call_deferred("grab_focus")

func _show_patrol_vignette(hid: String, result: String = "") -> void:
	if has_meta("m_on"):
		_m_vignette(hid, result)
		return
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 30
	add_child(overlay)
	var panel = UIKit.make_panel()
	panel.position = Vector2(320, 140)
	panel.custom_minimum_size = Vector2(640, 400)
	overlay.add_child(panel)
	var title = UIKit.make_label("巡防沙盘" + ((" · " + str(GameState.HOLDING_DEFS.get(hid, {}).get("name", ""))) if hid != "" else " · 四野全线"), true)
	title.position = Vector2(16, 12)
	panel.add_child(title)
	var map = TextureRect.new()
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.position = Vector2(16, 48)
	map.custom_minimum_size = Vector2(600, 280)
	panel.add_child(map)
	var frames: Array = []
	for fi in range(12):
		var fp = "res://assets/art/ui/patrol_vignette_f%d.png" % fi
		if ResourceLoader.exists(fp):
			frames.append(load(fp))
	if frames.is_empty() and ResourceLoader.exists("res://assets/art/ui/patrol_vignette.png"):
		frames.append(load("res://assets/art/ui/patrol_vignette.png"))
	if not frames.is_empty():
		map.texture = frames[0]
		var anim_i := [0]
		var tw = get_tree().create_timer(0.12)
		# 顺序播帧
		for step in range(1, frames.size()):
			var capture_step = step
			get_tree().create_timer(0.12 * capture_step).timeout.connect(func():
				if is_instance_valid(map) and capture_step < frames.size():
					map.texture = frames[capture_step]
			)
	if hid != "" and ResourceLoader.exists("res://assets/art/ui/patrol_mark_%s.png" % hid):
		var mark = TextureRect.new()
		mark.texture = load("res://assets/art/ui/patrol_mark_%s.png" % hid)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.custom_minimum_size = Vector2(48, 48)
		# approximate mark positions matching art
		var pos_map = {"reed_ford": Vector2(120, 200), "stone_slope": Vector2(320, 100), "fog_vale": Vector2(480, 180), "tide_bridge": Vector2(280, 260)}
		var mp: Vector2 = pos_map.get(hid, Vector2(300, 180))
		mark.position = Vector2(16, 48) + mp - Vector2(24, 24)
		panel.add_child(mark)
	var tip = UIKit.make_dim_label((result + "。" if result != "" else "") + "旗丁已走完路线。本属地劫掠风险大降。")
	tip.name = "PatrolTip"
	tip.position = Vector2(16, 340)
	panel.add_child(tip)
	var close = UIKit.make_accent_button("收起沙盘", 140)
	close.position = Vector2(480, 350)
	close.pressed.connect(func(): overlay.queue_free())
	panel.add_child(close)
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
	)


## §4.10 田册（属事处）：谁下地、口袋里有多少、交回旗库。横屏手机：按钮高 48，整页可滚。
var _field_overlay: Control
var _field_list: VBoxContainer
var _field_msg: Label


func open_field_book() -> void:
	if _field_overlay != null and is_instance_valid(_field_overlay):
		_field_overlay.queue_free()
	var overlay := ColorRect.new()
	overlay.name = "FieldBook"
	overlay.color = Color(0.04, 0.06, 0.1, 0.92)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_field_overlay = overlay
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	overlay.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	var title := UIKit.make_label(Locale.t("ux_field_plaque"), true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UIKit.make_accent_button(Locale.t("ux_field_close"), 120)
	close.custom_minimum_size.y = 48
	close.pressed.connect(close_field_book)
	head.add_child(close)
	var mob := DeviceProfile.is_mobile() or has_meta("m_on")
	var sh := Vector2(34, 42) if mob else Vector2(36, 44)
	CKHeraldryField.place_field_crest_strip(overlay, Vector2(1180, 10) if not mob else Vector2(20, 8), sh, Vector2(22, 30) if mob else Vector2(24, 34))
	var sub := UIKit.body_label(Locale.t("ux_estates_sub"), UIKit.TEXT_DIM, 14)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(sub)
	_field_msg = UIKit.body_label("", UIKit.OK, 14)
	_field_msg.name = "FieldMsg"
	_field_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_field_msg)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)
	_field_list = VBoxContainer.new()
	_field_list.name = "FieldList"
	_field_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_field_list)
	_fill_field_list()
	if has_meta("m_on"):
		overlay.size = Vector2(MobilePage.width(self), size.y if size.y > 400.0 else 720.0)
		overlay.z_index = 30
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		MobilePage.upsize(overlay)
		title.add_theme_font_size_override("font_size", 30)


func close_field_book() -> void:
	if _field_overlay != null and is_instance_valid(_field_overlay):
		_field_overlay.queue_free()
	_field_overlay = null
	if has_meta("m_on"):
		_m_build()
		return
	_rebuild()


func _field_status(c: CKCharacter) -> String:
	if CKPurse.is_following(GameState, c.id):
		return Locale.t("ux_field_follow")
	var job := str(c.blood_meta.get("estate_job", ""))
	if job != "":
		return Locale.t("ux_field_on") % str(GameState.HOLDING_DEFS.get(job, {}).get("name", job))
	if int(c.age) < 8:
		return Locale.t("ux_field_young")
	return Locale.t("ux_field_idle")


func _fill_field_list() -> void:
	for ch in _field_list.get_children():
		ch.queue_free()
	var open_holdings: Array = []
	for hid in GameState.HOLDING_DEFS.keys():
		if GameState.holding_unlocked(hid):
			open_holdings.append(str(hid))
	if open_holdings.is_empty():
		_field_list.add_child(UIKit.body_label(Locale.t("ux_field_no_land"), UIKit.TEXT_DIM, 14))
	var shown := 0
	for c in GameState.characters.values():
		if c == null or not c.alive:
			continue
		if c.in_roster and CKPurse._is_hireling(c):
			continue
		shown += 1
		var purse := CKPurse.get_purse(c)
		var row := HBoxContainer.new()
		row.name = "FieldRow_%s" % str(c.id)
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size.y = 48
		CKHeraldryField.attach_office_field_arms(row, c, Vector2(26, 32) if has_meta("m_on") else Vector2(28, 34))
		var lab := UIKit.body_label(Locale.t("ux_field_row") % [c.name, c.age, purse, _field_status(c)], UIKit.TEXT, 14)
		lab.custom_minimum_size.x = 340
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(lab)
		var cid := str(c.id)
		if int(c.age) >= 8:
			for hid in open_holdings:
				var b := UIKit.ghost_button(str(GameState.HOLDING_DEFS[hid].get("name", hid)), 96, 48)
				var hold: String = hid
				b.disabled = str(c.blood_meta.get("estate_job", "")) == hold
				b.pressed.connect(func(): _field_do(CKPurse.assign_field(GameState.characters[cid], hold)))
				row.add_child(b)
			if str(c.blood_meta.get("estate_job", "")) != "":
				var leave := UIKit.ghost_button(Locale.t("ux_field_leave"), 96, 48)
				leave.pressed.connect(func(): _field_do(CKPurse.assign_field(GameState.characters[cid], "")))
				row.add_child(leave)
		if purse > 0:
			var rem := UIKit.ghost_button(Locale.t("ux_field_remit") % purse, 128, 48)
			rem.pressed.connect(func(): _field_do(CKPurse.remit_to_flag(GameState.characters[cid])))
			row.add_child(rem)
		_field_list.add_child(row)
		if has_meta("m_on"):
			_m_field_row(row, lab)
	if shown == 0:
		_field_list.add_child(UIKit.body_label(Locale.t("ux_field_nobody"), UIKit.TEXT_DIM, 14))
	if has_meta("m_on"):
		MobilePage.upsize(_field_list)


func _field_do(r: Dictionary) -> void:
	_field_msg.text = str(r.get("msg", ""))
	_field_msg.add_theme_color_override("font_color", UIKit.OK if bool(r.get("ok", false)) else UIKit.DANGER)
	_fill_field_list()


## ── Phone landscape: holding cards fill the width (left); summary + page actions in their own column ──
var _m_root: Control

func _m_build() -> void:
	set_meta("m_on", true)
	var keep := _msg.text if _msg != null and is_instance_valid(_msg) else ""
	for c in get_children():
		if c is CanvasItem and c.get_index() > 0 and c != _m_root and c != _picker:
			(c as CanvasItem).visible = false
	if _m_root and is_instance_valid(_m_root):
		remove_child(_m_root)
		_m_root.queue_free()
	_m_root = Control.new()
	_m_root.name = "MobileEstates"
	_m_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_m_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_m_root)
	var w := MobilePage.width(self)
	var h := size.y if size.y > 400.0 else 720.0
	var top := MobilePage.TOP
	var bh := h - top - 16.0
	var old := get_node_or_null("MobileTopBar")
	if old:
		remove_child(old)
		old.queue_free()
	var bar := MobilePage.top_bar(self, Locale.t("mw_39662991"), Locale.t("mw_41e31e6c") % [GameState.silver, GameState.food, GameState.iron, Calendar.label()],
			[[Locale.t("btn_back"), func(): CKNav.up()]])
	bar.visible = true
	_place_estates_crests()
	var rw := clampf(w * 0.27, 340.0, 420.0)
	var lw := w - 40.0 - rw - 12.0
	var lv := MobilePage.panel(_m_root, Rect2(20, top, lw, bh), 12)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	sc.add_child(list)
	for hid in GameState.HOLDING_DEFS.keys():
		list.add_child(_m_holding(str(hid)))
	var rv := MobilePage.panel(_m_root, Rect2(w - 20 - rw, top, rw, bh), 12)
	rv.add_child(MobilePage.label(Locale.t("mw_c9e01e67"), UIKit.ACCENT, 24, false))
	rv.add_child(MobilePage.label(_sum_text().replace("　", " · "), UIKit.TEXT_DIM, MobilePage.FONT, true))
	rv.add_child(MobilePage.label(_focus_counts_text().replace("　", ""), UIKit.TEXT_FAINT, MobilePage.FONT, true))
	_msg = MobilePage.label(keep, UIKit.OK, MobilePage.FONT, true)
	rv.add_child(_msg)
	MobilePage.spacer(rv)
	var field := MobilePage.button(Locale.t("ux_estates_field"), true, open_field_book)
	field.name = "FieldBookBtn"
	rv.add_child(field)
	rv.add_child(MobilePage.button(Locale.t("mw_69668f1a"), false, _do_patrol))
	rv.add_child(MobilePage.button(Locale.t("mw_e3e092a7"), false, func(): CKNav.go("res://scenes/hub/works.tscn")))

func _m_holding(hid: String) -> Control:
	var def: Dictionary = GameState.HOLDING_DEFS[hid]
	var unlocked: bool = GameState.holding_unlocked(hid)
	var lv: int = GameState.holding_level(hid)
	var card := PanelContainer.new()
	var sb := UIKit.flat_box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.10), 10)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 12)
	card.add_theme_stylebox_override("panel", sb)
	if not unlocked:
		card.modulate = Color(1, 1, 1, 0.62)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(72, 72)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ip := "res://assets/art/estates/%s.png" % hid
	if ResourceLoader.exists(ip):
		icon.texture = load(ip)
	row.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	row.add_child(v)
	var t := MobilePage.label("%s   %s" % [str(def.name), ("Lv %d / 3" % lv) if unlocked else Locale.t("mw_c9190e80")], UIKit.TEXT, 26, false)
	t.add_theme_font_override("font", UIKit.font("bold"))
	v.add_child(t)
	var st = GameState.steward_of(hid) if unlocked else null
	var how := "；" + (Locale.t("wsc_e_how") % _quest_name(str(def.get("quest", "")))).replace("\u3000", "").strip_edges()
	var tail := (Locale.t("mw_4d0e475f") % st.name) if st != null else (Locale.t("mw_4e8abd0f") if unlocked else how)
	var dsc := str(def.desc) + tail
	v.add_child(MobilePage.label(dsc, UIKit.TEXT_DIM, MobilePage.FONT, true))
	if not unlocked:
		return card
	var pv = GameState.holding_yield_preview(hid)
	var ytxt := Locale.t("mw_c7eee1dc") % [int(pv.food), int(pv.silver)]
	if int(pv.get("herb", 0)) > 0:
		ytxt += Locale.t("mw_afd9fc74") % int(pv.herb)
	if lv < 3:
		ytxt += Locale.t("mw_d908bc9d") % [40 * lv, 8 * lv]
	if GameState.holding_patrol_cd(hid) > 0:
		ytxt += Locale.t("mw_0296c7bc") % GameState.holding_patrol_cd(hid)
	elif GameState.holding_patrol_boost(hid) > 0:
		ytxt += Locale.t("mw_30b4a962") % GameState.holding_patrol_boost(hid)
	v.add_child(MobilePage.label(ytxt, UIKit.ACCENT, MobilePage.FONT, true))
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 8)
	v.add_child(fr)
	var fl := MobilePage.label(Locale.t("mw_99f92210"), UIKit.TEXT_FAINT, MobilePage.FONT, false)
	fl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fr.add_child(fl)
	var foc = GameState.holding_focus(hid)
	for fk in ["grain", "cash", "fortify"]:
		var fb := _focus_tile(fk, fk == foc, hid)
		fb.custom_minimum_size = Vector2(0, MobilePage.HIT)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.add_theme_font_size_override("font_size", MobilePage.FONT)
		fr.add_child(fb)
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 8)
	v.add_child(ar)
	var bid := hid
	var up := MobilePage.button(Locale.t("mw_91c7146a") if lv < 3 else Locale.t("mw_8fde9e92"), lv < 3, func(): _upgrade(bid))
	up.disabled = lv >= 3
	ar.add_child(up)
	if st != null:
		ar.add_child(MobilePage.button(Locale.t("mw_14f8cc32"), false, func(): _clear_steward(bid)))
	else:
		ar.add_child(MobilePage.button(Locale.t("mw_23073274"), false, func(): _open_picker(bid)))
	var pb := MobilePage.button(Locale.t("mw_4f279682"), false, func(): _do_patrol_one(bid))
	pb.disabled = GameState.holding_patrol_cd(bid) > 0 or GameState.holding_patrol_boost(bid) > 0
	ar.add_child(pb)
	return card


## ── Phone popups: steward picker, patrol sand-table, field book rows ──
func _m_picker(hid: String) -> void:
	var sh := MobilePage.sheet(self, "StewardPicker", Locale.t("mw_pick_steward") % str(GameState.HOLDING_DEFS[hid].name), 30)
	_picker = sh[0]
	var v: VBoxContainer = sh[1]
	v.add_child(MobilePage.label(Locale.t("mw_pick_tip"), UIKit.TEXT_DIM, MobilePage.FONT, true))
	var list := MobilePage.sheet_scroll(v, 260.0)
	for c in GameState.roster():
		if c == null or not c.alive:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		list.add_child(row)
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(72, 72)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex = UnitArt.portrait(c, 72)
		if tex != null:
			tr.texture = tex
		row.add_child(tr)
		var job := str(GameState.get_job(c.job_id).get("name", c.job_id))
		var lab := MobilePage.label("%s · %s · Lv%d" % [c.name, job, c.level], UIKit.TEXT, MobilePage.FONT, true)
		lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lab)
		var cid := str(c.id)
		var bb := MobilePage.button(Locale.t("mw_assign"), true, func(): _do_assign(cid), 150)
		bb.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(bb)
	v.add_child(MobilePage.button(Locale.t("ux_field_close"), false, func():
		if _picker != null and is_instance_valid(_picker):
			_picker.queue_free()
			_picker = null))

func _m_vignette(hid: String, result: String) -> void:
	var where := str(GameState.HOLDING_DEFS.get(hid, {}).get("name", "")) if hid != "" else Locale.t("mw_patrol_all")
	var title := Locale.t("mw_patrol_title") + " · " + where
	var sh := MobilePage.sheet(self, "PatrolVignette", title, 30)
	var overlay: Control = sh[0]
	var v: VBoxContainer = sh[1]
	var map := TextureRect.new()
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map.custom_minimum_size = Vector2(0, clampf(float(v.get_meta("max_h", 660.0)) - 300.0, 220.0, 380.0))
	v.add_child(map)
	var frames: Array = []
	for fi in range(12):
		var fp := "res://assets/art/ui/patrol_vignette_f%d.png" % fi
		if ResourceLoader.exists(fp):
			frames.append(load(fp))
	var still := "res://assets/art/ui/patrol_vignette.png"
	if frames.is_empty() and ResourceLoader.exists(still):
		frames.append(load(still))
	if not frames.is_empty():
		map.texture = frames[0]
		for step in range(1, frames.size()):
			var k := step
			get_tree().create_timer(0.12 * k).timeout.connect(func():
				if is_instance_valid(map):
					map.texture = frames[k])
	var tip := MobilePage.label((result + "。" if result != "" else "") + Locale.t("mw_patrol_done"), UIKit.TEXT_DIM, MobilePage.FONT, true)
	tip.name = "PatrolTip"
	v.add_child(tip)
	v.add_child(MobilePage.button(Locale.t("mw_patrol_close"), true, func(): overlay.queue_free()))
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(overlay):
			overlay.queue_free())

## Field-book row on phone: name/status on top, holding buttons wrap underneath.
func _m_field_row(row: HBoxContainer, lab: Label) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var idx := row.get_index()
	_field_list.add_child(box)
	_field_list.move_child(box, idx)
	_field_list.remove_child(row)
	row.remove_child(lab)
	lab.custom_minimum_size.x = 0
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(lab)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	box.add_child(flow)
	for b in row.get_children():
		row.remove_child(b)
		(b as Control).custom_minimum_size = Vector2(maxf(160.0, (b as Control).custom_minimum_size.x), MobilePage.HIT)
		flow.add_child(b)
	row.queue_free()
