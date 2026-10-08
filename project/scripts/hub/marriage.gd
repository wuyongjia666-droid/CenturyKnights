extends Control

var _list: VBoxContainer
var _detail: RichTextLabel
var _expect: RichTextLabel
var _selected: CKCharacter
var _msg: Label
var _portrait: TextureRect
var _leader_portrait: TextureRect
var _seal_fx: TextureRect
var _dual: Control
const DUAL_W := 380.0
var _vow_step: int = 0
var _vow_panel: Control
var _vow_body: RichTextLabel
var _vow_actions: HBoxContainer
var _vow_gift: String = "banner"
var _vow_doctrine: String = "strict"
var _tabs: HBoxContainer
var _cards: Control
var _grade: Label
var _marry_btn: Button
var _rite_on: Dictionary = {}
var _rite_board: Control
var _punnett: Control
var _narrow := false
var _rect_principal := Rect2(42, 244, 386, 252)
var _rect_harmony := Rect2(448, 244, 384, 264)
var _rect_spouse := Rect2(852, 244, 386, 252)

func _ready() -> void:
	UIFX.fade_in(self, 0.3)
	if int(GameState.reputation.get("ashland", 0)) < 30:
		GameState.reputation["ashland"] = maxi(int(GameState.reputation.get("ashland", 0)), 35)
	if GameState.marriage_candidates.is_empty():
		GameState.refresh_marriage_candidates()
	_build()
	_refresh()
	UIFX.slide_from_bottom(self, 24.0, 0.32)

func _build() -> void:
	## v8.6 — layout-matched to Stitch 17_marriage.png: protocol header · candidate tabs ·
	## CLAN PRINCIPAL | GENOMIC HARMONY | ALLIED SPOUSE · forecast + 再议/缔约 · footer
	UIKit.void_bg(self)
	UIKit.top_bar(self, "宗族谱系枢纽 · 联姻盟誓", [
		["灰烬邦", GameState.get_rep_name("ashland"), UIKit.ACCENT],
		["河卫邦", GameState.get_rep_name("riverland"), UIKit.TEXT],
		["银币", str(GameState.silver), UIKit.ACCENT],
		["历", Calendar.label(), UIKit.TEXT_DIM]], "返回城堡", _back)
	UIKit.page_head(self, 42, 72, "HARMONIC RATIO EVALUATION", "联姻契约", "MARRIAGE PROTOCOL", "宗族双源结合研判与血脉特质推演 —— 声望是门，子嗣期望是窗。", "PROTOCOL NO.07", 18)
	var rd := UIKit.mono("RATING DISCIPLINE", 9, UIKit.TEXT_FAINT)
	rd.position = Vector2(1238 - rd.get_minimum_size().x, 96)
	add_child(rd)
	_grade = UIKit.body_label("", UIKit.OK, 12)
	_grade.autowrap_mode = TextServer.AUTOWRAP_OFF
	_grade.position = Vector2(938, 112)
	_grade.size = Vector2(300, 18)
	_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_grade)
	var hl := UIKit.hairline(Color(1, 1, 1, 0.07))
	hl.position = Vector2(42, 196)
	hl.size = Vector2(1196, 1)
	add_child(hl)
	var cl := UIKit.mono("CANDIDATES // 春令应帖", 9, UIKit.TEXT_FAINT)
	cl.position = Vector2(42, 204)
	add_child(cl)
	_list = VBoxContainer.new()   # legacy handle (unused for layout)
	_list.visible = false
	add_child(_list)
	_tabs = HBoxContainer.new()
	_tabs.position = Vector2(300, 200)
	_tabs.add_theme_constant_override("separation", 8)
	add_child(_tabs)

	_cards = Control.new()
	_cards.position = Vector2(0, 0)
	_cards.size = Vector2(1280, 720)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)

	_seal_fx = TextureRect.new()
	_seal_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_seal_fx.stretch_mode = TextureRect.STRETCH_SCALE
	_seal_fx.size = Vector2(220, 220)
	_seal_fx.position = Vector2(640 - 110, 300 - 110)
	_seal_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal_fx.modulate = Color(1, 1, 1, 0)
	_seal_fx.z_index = 5
	add_child(_seal_fx)

	_rite_board = UIKit.panel_at(self, Rect2(42, 516, 600, 112), 10)
	_rite_board.name = "RiteBoard"
	_punnett = UIKit.panel_at(self, Rect2(654, 508, 584, 148), 10)
	_punnett.name = "PunnettBoard"
	_msg = UIKit.body_label("选定婚仪后，这里写明子女会怎样入谱。", UIKit.TEXT_DIM, 12)
	_msg.name = "RiteExplain"
	_msg.autowrap_mode = TextServer.AUTOWRAP_OFF
	_msg.clip_text = true
	_msg.position = Vector2(12, 80)
	_msg.size = Vector2(576, 22)
	_rite_board.add_child(_msg)
	var row := HBoxContainer.new()
	row.name = "MarriageActions"
	row.position = Vector2(602, 660)
	row.size = Vector2(636, 44)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var duty_btn := UIKit.ghost_button("起誓·义役", 108, 40)
	duty_btn.pressed.connect(func():
		UIFX.press_feedback(duty_btn)
		var r = GameState.start_alliance_duty()
		_msg.text = str(r.get("msg"))
		if r.get("ok"):
			UIFX.confirm_burst(duty_btn)
			Sfx.lineage_chime()
			GameState.save_game())
	row.add_child(duty_btn)
	var rite := UIKit.ghost_button("族谱授旗礼", 108, 40)
	rite.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/lineage_rite.tscn"))
	row.add_child(rite)
	var refresh := UIKit.ghost_button("再议   [B]", 108, 40)
	refresh.tooltip_text = "刷新春令候选"
	refresh.pressed.connect(func():
		GameState.refresh_marriage_candidates()
		_refresh())
	row.add_child(refresh)
	_marry_btn = UIKit.cta_button("✓ 缔约 · 40 银", "A", 196, 44)
	_marry_btn.pressed.connect(_start_vow)
	row.add_child(_marry_btn)
	UIKit.footer_bar(self, [["A", "缔约"], ["B", "再议"], ["←→", "切换候选"], ["ESC", "返回城堡"]], "GENE ARCHIVE · FROST_TACTICAL v8.6")

	# vow ritual modal
	_vow_panel = Control.new()
	_vow_panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_vow_panel.visible = false
	_vow_panel.z_index = 20
	add_child(_vow_panel)
	var dim := ColorRect.new()
	dim.color = Color(UIKit.BG, 0.72)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_vow_panel.add_child(dim)
	var vp := UIKit.panel_at(_vow_panel, Rect2(260, 190, 760, 320), 12, true)
	var ve := UIKit.mono("VOW RITUAL // 誓约仪式", 10, UIKit.ACCENT)
	ve.position = Vector2(28, 22)
	vp.add_child(ve)
	_vow_body = RichTextLabel.new()
	_vow_body.bbcode_enabled = true
	_vow_body.fit_content = false
	_vow_body.position = Vector2(28, 48)
	_vow_body.size = Vector2(704, 190)
	_vow_body.add_theme_color_override("default_color", UIKit.TEXT)
	_vow_body.add_theme_font_size_override("normal_font_size", 14)
	_vow_body.add_theme_font_size_override("bold_font_size", 18)
	vp.add_child(_vow_body)
	_vow_actions = HBoxContainer.new()
	_vow_actions.position = Vector2(28, 256)
	_vow_actions.add_theme_constant_override("separation", 10)
	vp.add_child(_vow_actions)
	UIFX.page_enter(self)
	apply_mobile_layout()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		if _vow_panel and _vow_panel.visible:
			_vow_panel.visible = false
		else:
			_back()
	elif e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right"):
		if GameState.marriage_candidates.is_empty() or _selected == null:
			return
		var i := GameState.marriage_candidates.find(_selected)
		i = (i + (1 if e.is_action_pressed("ui_right") else -1) + GameState.marriage_candidates.size()) % GameState.marriage_candidates.size()
		_select(GameState.marriage_candidates[i])

func _refresh() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	if GameState.marriage_candidates.is_empty():
		_tabs.add_child(UIKit.empty_state("春令无人应帖。再议或提高声望。"))
		return
	var k := 0
	for cand in GameState.marriage_candidates:
		k += 1
		var check = Lineage.can_propose(GameState.get_leader(), cand)
		var b := UIKit.ghost_button("%02d  %s · %s  %s" % [k, cand.name, cand.rank_name(), "●" if check.get("ok") else "○"], 0, 32)
		b.tooltip_text = "可表白" if check.get("ok") else str(check.get("msg", "声望不足"))
		b.toggle_mode = true
		b.set_meta("cand", cand)
		var captured = cand
		b.pressed.connect(func(): _select(captured))
		_tabs.add_child(b)
	_select(GameState.marriage_candidates[0])

func _house_card(rect: Rect2, c: CKCharacter, side_tag: String, side_en: String, col: Color, series: String) -> void:
	var p := UIKit.panel_at(_cards, rect, 10)
	p.clip_contents = true
	var footer_y := rect.size.y - 32.0
	var head := HBoxContainer.new()
	head.position = Vector2(12, 10)
	head.size = Vector2(rect.size.x - 24, 20)
	head.add_theme_constant_override("separation", 8)
	p.add_child(head)
	var left_h := HBoxContainer.new()
	left_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_h.clip_contents = true
	left_h.add_theme_constant_override("separation", 6)
	head.add_child(left_h)
	left_h.add_child(UIKit.mono(side_en, 9, col))
	var hz := UIKit.body_label("// " + side_tag, col, 11)
	hz.autowrap_mode = TextServer.AUTOWRAP_OFF
	hz.clip_text = true
	hz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_h.add_child(hz)
	var se := UIKit.mono(series, 9, UIKit.TEXT_FAINT)
	head.add_child(se)
	if c == null:
		return
	var compact := rect.size.y < 230.0
	var plate := Rect2(14, 36, 120, 128)
	if compact:
		plate = Rect2(10, 34, 72, maxf(56.0, footer_y - 42.0))
	UIKit.portrait_plate(p, plate, c, "FROST")
	if not compact:
		var nm := UIKit.title_label(c.name, 15)
		nm.name = "CardName"
		nm.add_theme_font_override("font", UIKit.font("bold"))
		nm.position = Vector2(10, plate.end.y + 4)
		nm.size = Vector2(128, 20)
		nm.clip_text = true
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(nm)
		var sub := UIKit.body_label("%d岁 · %s" % [c.age, GameState.get_job(c.job_id).get("name", "")], col, 11)
		sub.name = "AgeLine"
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.clip_text = true
		sub.position = Vector2(10, plate.end.y + 24)
		sub.size = Vector2(128, 32)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(sub)
	var text_x := plate.end.x + 8.0
	var v := VBoxContainer.new()
	v.position = Vector2(text_x, 36)
	v.size = Vector2(maxf(40.0, rect.size.x - text_x - 10.0), maxf(24.0, footer_y - 44.0))
	v.clip_contents = true
	v.add_theme_constant_override("separation", 6 if compact else 2)
	p.add_child(v)
	if compact:
		var age := UIKit.body_label(Locale.t("marriage_compact_who", [c.name, c.age]), UIKit.TEXT, 12)
		age.name = "AgeLine"
		age.autowrap_mode = TextServer.AUTOWRAP_OFF
		age.clip_text = true
		age.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(age)
	var ln := UIKit.body_label("%s旗 · %s" % [GameState.surname if c.is_leader else str(c.name).substr(0, 1), "家主" if c.is_leader else "应帖者"], UIKit.TEXT, 13)
	ln.autowrap_mode = TextServer.AUTOWRAP_OFF
	ln.clip_text = true
	v.add_child(ln)
	v.add_child(UIKit.body_label("%s  LV %d" % [c.rank_name(), c.level], UIKit.TEXT, 13))
	var pb := str(c.primary_bloodline())
	var bl: Dictionary = GameState.get_bloodline(pb)
	var pct := int(round(float(c.blood_mix.get(pb, 1.0)) * 100))
	var blood := UIKit.body_label("%s  %d%%" % [str(bl.get("name", pb)), pct], col, 13)
	blood.autowrap_mode = TextServer.AUTOWRAP_OFF
	blood.clip_text = true
	v.add_child(blood)
	var tr_names: Array = []
	for tid in c.traits.slice(0, 3):
		tr_names.append(str(GameState.get_trait(str(tid)).get("name", tid)))
	var dsc := UIKit.body_label("禀性 %s" % ("、".join(tr_names) if not tr_names.is_empty() else "未显"), UIKit.TEXT_FAINT, 12)
	dsc.autowrap_mode = TextServer.AUTOWRAP_OFF
	dsc.clip_text = true
	v.add_child(dsc)
	var fh := UIKit.hairline(Color(1, 1, 1, 0.07))
	fh.position = Vector2(12, footer_y - 6)
	fh.size = Vector2(rect.size.x - 24, 1)
	p.add_child(fh)
	var foot := HBoxContainer.new()
	foot.position = Vector2(12, footer_y)
	foot.size = Vector2(rect.size.x - 24, 20)
	foot.add_theme_constant_override("separation", 8)
	p.add_child(foot)
	var pd := UIKit.mono("PEDIGREE · GEN %s" % ("I" if c.parent_ids.is_empty() else "II"), 9, UIKit.TEXT_FAINT)
	pd.name = "PedigreeCaption"
	pd.clip_text = true
	pd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pd.custom_minimum_size = Vector2(120, 16)
	foot.add_child(pd)
	var fit := UIKit.body_label("ATK %d · DEF %d" % [c.derived_atk(), c.derived_def()], UIKit.TEXT_DIM, 11)
	fit.autowrap_mode = TextServer.AUTOWRAP_OFF
	fit.clip_text = true
	fit.custom_minimum_size = Vector2(108, 16)
	fit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(fit)

func _harmony_card(rect: Rect2, a: CKCharacter, b: CKCharacter) -> void:
	## 子嗣期望 — every block has its own fixed row; nothing overlaps (v8.5 bug)
	var p := UIKit.panel_at(_cards, rect, 10)
	var t := UIKit.mono("GENOMIC HARMONY", 9, UIKit.TEXT_DIM)
	t.clip_text = true
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(8, 12)
	t.size = Vector2(rect.size.x - 16, 16)
	p.add_child(t)
	if a == null or b == null:
		return
	var ex: Dictionary = Lineage.heir_expectation(a, b)
	var mids := 0.0
	var hi := 1.0
	for sk in CKCharacter.STAT_KEYS:
		mids += (float(ex.apt_min[sk]) + float(ex.apt_max[sk])) * 0.5
		hi = maxf(hi, float(ex.apt_max[sk]))
	var pct := clampi(int(round(mids / CKCharacter.STAT_KEYS.size() / maxf(hi, 12.0) * 100.0)), 1, 99)
	_grade.text = "●  子嗣资质评级  %s" % ("S" if pct >= 85 else ("A" if pct >= 70 else ("B" if pct >= 55 else "C")))
	var compact := rect.size.y < 230.0
	var lab := UIKit.body_label("子嗣期望 · 资质共鸣指标", UIKit.TEXT_DIM, 12)
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.clip_text = true
	lab.position = Vector2(8, 28 if compact else 32)
	lab.size = Vector2(rect.size.x - 16, 18 if compact else 36)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(lab)
	var big := Label.new()
	big.text = "%d" % pct
	big.add_theme_font_override("font", UIKit.font("mono"))
	big.add_theme_font_size_override("font_size", 22 if compact else 36)
	big.add_theme_color_override("font_color", UIKit.ACCENT)
	p.add_child(big)
	var bw := big.get_minimum_size()
	var big_y := 48.0 if compact else 70.0
	big.position = Vector2((rect.size.x - bw.x) * 0.5 - 8, big_y)
	big.size = bw
	var pc := UIKit.mono("%", 14, UIKit.ACCENT, false)
	pc.position = Vector2(big.position.x + bw.x + 4, big_y + (22.0 if compact else 36.0))
	p.add_child(pc)
	var preview_y := 198.0
	var preview_h := 60.0
	if compact:
		preview_h = minf(52.0, maxf(36.0, rect.size.y * 0.34))
		preview_y = rect.size.y - preview_h - 6.0
	else:
		var bar := UIKit.slim_bar(pct, 100, UIKit.ACCENT, 160, 3)
		bar.position = Vector2((rect.size.x - 160) * 0.5, 168)
		p.add_child(bar)
		var rk := UIKit.mono("RANK // %s" % CKCharacter.RANK_NAMES.get(ex.rank_hint, ex.rank_hint), 9, UIKit.TEXT_FAINT, false)
		rk.clip_text = true
		rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rk.position = Vector2(8, 176)
		rk.size = Vector2(rect.size.x - 16, 20)
		p.add_child(rk)
	var ib := UIKit.panel_at(p, Rect2(8, preview_y, rect.size.x - 16, preview_h), 6)
	ib.name = "HeirPreview"
	ib.clip_contents = true
	var it := UIKit.body_label("后代遗传特质推演", UIKit.TEXT_DIM, 11)
	it.autowrap_mode = TextServer.AUTOWRAP_OFF
	it.clip_text = true
	it.position = Vector2(4, 6)
	it.size = Vector2(rect.size.x - 40, 16)
	it.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ib.add_child(it)
	var tp: Array = ex.trait_probs.slice(0, 3)
	var cw := maxf(28.0, (ib.size.x - 36.0) / 3.0)
	for i in tp.size():
		var chip := UIKit.panel_at(ib, Rect2(12 + i * (cw + 8), 24, cw, 32), 4)
		var cs: StyleBoxFlat = chip.get_theme_stylebox("panel").duplicate()
		cs.bg_color = Color(UIKit.OK, 0.06)
		cs.border_color = Color(UIKit.OK, 0.45)
		chip.add_theme_stylebox_override("panel", cs)
		var cn := UIKit.body_label(str(tp[i].name), UIKit.OK, 12)
		cn.autowrap_mode = TextServer.AUTOWRAP_OFF
		cn.clip_text = true
		cn.position = Vector2(2, 2)
		cn.size = Vector2(cw - 4, 16)
		cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(cn)
		var cp := UIKit.mono("%d%% 显性" % int(round(float(tp[i].prob) * 100)), 9, UIKit.TEXT_FAINT, false)
		cp.clip_text = true
		cp.position = Vector2(2, 20)
		cp.size = Vector2(cw - 4, 14)
		cp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(cp)
func _render_cards() -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	var leader = GameState.get_leader()
	_house_card(_rect_principal, leader, "宗主一方", "CLAN PRINCIPAL", UIKit.ACCENT, "SERIES: VII-01")
	_harmony_card(_rect_harmony, leader, _selected)
	_house_card(_rect_spouse, _selected, "应帖一方", "ALLIED SPOUSE", UIKit.OK, "SERIES: IV-02")
	_fill_forecast(leader, _selected)

func _fill_forecast(a: CKCharacter, b: CKCharacter) -> void:
	if _rite_board == null or _punnett == null:
		return
	for ch in _rite_board.get_children():
		if ch == _msg:
			continue
		ch.queue_free()
	for ch in _punnett.get_children():
		ch.queue_free()
	var cap := UIKit.mono("RITES // 婚仪", 9, UIKit.ACCENT)
	cap.clip_text = true
	cap.position = Vector2(12, 8)
	cap.size = Vector2(280, 16)
	_rite_board.add_child(cap)
	_sync_rite_flags(a, b)
	var rites: Array = CKCourt.required_rites(a, b) if a != null and b != null else []
	var row_y := 32.0
	if not rites.is_empty():
		var x := 12.0
		var btn_w := 136.0 if _rite_board.size.x >= 560.0 else 108.0
		var step := btn_w + 8.0
		for r in rites:
			var id := str(r.get("id", ""))
			var on := bool(_rite_on.get(id, true))
			var btn := UIKit.ghost_button("%s %s" % ["✓" if on else "○", str(r.get("name", id))], btn_w, 40)
			btn.name = "Rite_" + id
			if x + btn_w > _rite_board.size.x - 8.0 and x > 12.0:
				x = 12.0
				row_y += 44.0
			btn.position = Vector2(x, row_y)
			btn.tooltip_text = "%s\n若不接受：%s" % [str(r.get("desc", "")), str(r.get("block", ""))]
			var captured := id
			btn.pressed.connect(func():
				_rite_on[captured] = not bool(_rite_on.get(captured, true))
				Sfx.click()
				if str(captured) == "frost":
					Sfx.play("frost_crackle")
				_fill_forecast(GameState.get_leader(), _selected))
			_rite_board.add_child(btn)
			x += step
	_consequence_line(a, b)
	if _narrow:
		_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_msg.position = Vector2(8, row_y + 44.0)
		_msg.size = Vector2(maxf(40.0, _rite_board.size.x - 16.0), maxf(16.0, _rite_board.size.y - _msg.position.y - 6.0))
	else:
		_msg.autowrap_mode = TextServer.AUTOWRAP_OFF
		_msg.position = Vector2(12, 80)
		_msg.size = Vector2(minf(576.0, _rite_board.size.x - 24.0), 22)
	var ph := UIKit.mono("PUNNETT // 每项性状", 9, UIKit.TEXT_FAINT)
	ph.clip_text = true
	ph.position = Vector2(12, 6)
	ph.size = Vector2(240, 16)
	_punnett.add_child(ph)
	_punnett.clip_contents = true
	_rite_board.clip_contents = true
	var holder := VBoxContainer.new()
	var hold_w := maxf(80.0, _punnett.size.x - 24.0)
	var hold_h := 70.0 if _punnett.size.y >= 140.0 else maxf(28.0, _punnett.size.y - 50.0)
	holder.position = Vector2(12, 22)
	holder.size = Vector2(hold_w, hold_h)
	holder.clip_contents = true
	_punnett.add_child(holder)
	CKCourtChrome.fill_punnett(holder, a, b, 2)
	var cast := UIKit.body_label(str(CKFamilyState.combat_expectation(a, b).get("line", "")), UIKit.ACCENT, 12)
	cast.name = "CombatForecast"
	cast.clip_text = true
	if _punnett.size.y >= 140.0:
		cast.autowrap_mode = TextServer.AUTOWRAP_OFF
		cast.position = Vector2(12, 108)
		cast.size = Vector2(560, 28)
	else:
		cast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cast.position = Vector2(8, holder.position.y + holder.size.y + 2.0)
		cast.size = Vector2(hold_w, maxf(16.0, _punnett.size.y - cast.position.y - 4.0))
	_punnett.add_child(cast)
	UIFX.wire_tree(_rite_board)

func apply_mobile_layout() -> void:
	var vp := get_viewport_rect().size
	_fit_chrome(vp)
	if _punnett == null or _rite_board == null:
		return
	var wide := vp.x >= 1100.0 and vp.y >= 680.0
	_narrow = not wide
	if wide:
		_rect_principal = Rect2(42, 244, 386, 252)
		_rect_harmony = Rect2(448, 244, 384, 264)
		_rect_spouse = Rect2(852, 244, 386, 252)
		_rite_board.position = Vector2(42, 516)
		_rite_board.size = Vector2(600, 112)
		_punnett.position = Vector2(654, 508)
		_punnett.size = Vector2(584, 148)
		var actions_wide := get_node_or_null("MarriageActions") as Control
		if actions_wide:
			actions_wide.position = Vector2(602, 660)
			actions_wide.size = Vector2(636, 44)
	else:
		var margin := 8.0
		var foot := get_node_or_null("StitchFooter") as Control
		var foot_y := vp.y - 8.0
		if foot:
			foot_y = foot.position.y
		var actions := get_node_or_null("MarriageActions") as Control
		if actions:
			actions.position = Vector2(margin, foot_y - 50.0)
			actions.size = Vector2(vp.x - margin * 2.0, 44)
		if _tabs:
			_tabs.position = Vector2(margin, 130)
			_tabs.size = Vector2(vp.x - margin * 2.0, 32)
			_tabs.clip_contents = true
		for ch in get_children():
			if ch is VBoxContainer and (ch as Control).position.y > 60.0 and (ch as Control).position.y < 100.0:
				var head := ch as VBoxContainer
				if head.get_child_count() >= 3:
					var desc := head.get_child(2) as CanvasItem
					if desc:
						desc.visible = false
		var y0 := 168.0
		var actions_y := actions.position.y if actions else foot_y - 8.0
		var gap := 8.0
		var board_h := 92.0
		var card_h := actions_y - gap - board_h - gap - y0
		if card_h < 132.0:
			board_h = 78.0
			card_h = maxf(112.0, actions_y - gap - board_h - gap - y0)
		var inner := vp.x - margin * 2.0
		var col_w := (inner - gap * 2.0) / 3.0
		_rect_principal = Rect2(margin, y0, col_w, card_h)
		_rect_harmony = Rect2(margin + col_w + gap, y0, col_w, card_h)
		_rect_spouse = Rect2(margin + (col_w + gap) * 2.0, y0, col_w, card_h)
		var boards_y := y0 + card_h + gap
		var half := (inner - gap) * 0.5
		_rite_board.position = Vector2(margin, boards_y)
		_rite_board.size = Vector2(half, board_h)
		_punnett.position = Vector2(margin + half + gap, boards_y)
		_punnett.size = Vector2(half, board_h)
		_grade.position = Vector2(maxf(8.0, vp.x - 308.0), 96)
		_grade.size = Vector2(minf(300.0, vp.x - _grade.position.x - 8.0), 18)
		_grade.clip_text = true
	if _selected != null:
		_render_cards()

func _fit_chrome(vp: Vector2) -> void:
	var bar := get_node_or_null("StitchTopBar") as Control
	if bar and vp.x < 1270.0:
		bar.size.x = vp.x
		var right: HBoxContainer = null
		for ch in bar.get_children():
			if ch is ColorRect:
				(ch as ColorRect).size.x = vp.x
			elif ch is HBoxContainer:
				right = ch
		if right:
			var limit := maxf(120.0, vp.x - 280.0)
			var guard := 0
			while right.get_combined_minimum_size().x > limit and guard < 6:
				var dropped := false
				for drop in right.get_children():
					if drop is Control and (drop as Control).visible and str(drop.name) != "BackButton":
						(drop as Control).visible = false
						dropped = true
						break
				if not dropped:
					break
				guard += 1
			var width := minf(right.get_combined_minimum_size().x, vp.x - 16.0)
			right.position = Vector2(vp.x - 8.0 - width, right.position.y)
			right.custom_minimum_size = Vector2(width, right.size.y)
			right.size = Vector2(width, right.size.y)
			right.clip_contents = true
			for ch2 in bar.get_children():
				if ch2 is Label and (ch2 as Label).position.x > 120.0:
					var lab := ch2 as Label
					lab.size = Vector2(maxf(48.0, right.position.x - lab.position.x - 8.0), 26)
					lab.clip_text = true
					lab.autowrap_mode = TextServer.AUTOWRAP_OFF
					lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var foot := get_node_or_null("StitchFooter") as Control
	MobileLayout.pin_footer(foot)
	if foot == null:
		return
	if vp.y < 680.0:
		foot.position.y = vp.y - foot.size.y
	foot.size.x = vp.x
	foot.clip_contents = true
	for ch3 in foot.get_children():
		if ch3 is ColorRect:
			(ch3 as ColorRect).size.x = vp.x
		elif ch3 is Label and vp.x < 1100.0:
			(ch3 as Label).visible = false

func _sync_rite_flags(a: CKCharacter, b: CKCharacter) -> void:
	var nxt := {}
	if a != null and b != null:
		for r in CKCourt.required_rites(a, b):
			var id := str(r.get("id", ""))
			nxt[id] = bool(_rite_on.get(id, true))
	_rite_on = nxt

func _vow_rite_copy(leader: CKCharacter) -> String:
	if leader == null or _selected == null:
		return ""
	var bits: Array = []
	var cost := 0
	for r in CKCourt.required_rites(leader, _selected):
		var id := str(r.get("id", ""))
		var on := bool(_rite_on.get(id, false))
		cost += int(r.get("cost", 0)) if on else 0
		bits.append("%s：%s" % [str(r.get("name", id)), str(r.get("desc", "")) if on else str(r.get("block", ""))])
	if bits.is_empty():
		return "无必须婚仪。"
	return "婚仪（礼银 %d）\n%s" % [cost, "\n".join(bits)]

func _accepted_ids() -> Array:
	var ids: Array = []
	for k in _rite_on.keys():
		if bool(_rite_on[k]):
			ids.append(str(k))
	return ids

func _consequence_line(a: CKCharacter, b: CKCharacter) -> void:
	if _msg == null:
		return
	if a == null or b == null:
		_msg.text = "选定双方后，这里写明婚仪会把子女写成什么样。"
		return
	var bits: Array = []
	for r in CKCourt.required_rites(a, b):
		var id := str(r.get("id", ""))
		bits.append(str(r.get("desc", "")) if bool(_rite_on.get(id, false)) else str(r.get("block", "")))
	_msg.text = " ".join(bits) if not bits.is_empty() else "无特殊婚仪。子女按常例入谱。"
	var blocked := CKCourt.rite_block(a, b, _accepted_ids()) != ""
	_msg.add_theme_color_override("font_color", UIKit.DANGER if blocked else UIKit.TEXT_DIM)

func play_seal_fx(hold: bool = false) -> void:
	if _seal_fx == null:
		return
	var frames: Array = []
	for i in range(8):
		var fp = "res://assets/art/fx/marriage_seal_dense_%d.png" % i
		if ResourceLoader.exists(fp):
			frames.append(load(fp))
	if frames.is_empty():
		return
	_seal_fx.texture = frames[0]
	_seal_fx.modulate = Color(1, 1, 1, 1)
	for i in range(1, frames.size()):
		var fi = i
		get_tree().create_timer(0.07 * fi).timeout.connect(func():
			if is_instance_valid(_seal_fx): _seal_fx.texture = frames[fi])
	if not hold:
		var tw = _seal_fx.create_tween()
		tw.tween_interval(0.07 * frames.size() + 0.6)
		tw.tween_property(_seal_fx, "modulate:a", 0.0, 0.5)

func _select(c: CKCharacter) -> void:
	_selected = c
	for b in _tabs.get_children():
		if b is Button and b.has_meta("cand"):
			b.button_pressed = (b.get_meta("cand") == c)
	_render_cards()
	var check = Lineage.can_propose(GameState.get_leader(), c)
	var rite_block := CKCourt.rite_block(GameState.get_leader(), c, _accepted_ids()) if check.get("ok") else ""
	_marry_btn.disabled = not bool(check.get("ok")) or rite_block != ""
	_marry_btn.tooltip_text = str(check.get("msg", "")) if not check.get("ok") else rite_block
	if not check.get("ok"):
		_msg.text = "门槛：%s" % str(check.get("msg", ""))
		_msg.add_theme_color_override("font_color", UIKit.DANGER)

func _start_vow() -> void:
	if _selected == null:
		return
	var check = Lineage.can_propose(GameState.get_leader(), _selected)
	if not check.get("ok"):
		_msg.text = str(check.get("msg", "不可定聘"))
		return
	_vow_step = 0
	_vow_panel.visible = true
	_show_vow()

func _show_vow() -> void:
	for c in _vow_actions.get_children():
		c.queue_free()
	var leader = GameState.get_leader()
	var a = leader.name if leader else "团长"
	var b = _selected.name
	match _vow_step:
		0:
			var rite := _vow_rite_copy(leader)
			_vow_body.text = "[b]誓约·第一步 · 宣读子嗣期望[/b]\n\n厅上众人静听。\n%s 与 %s 将共旗同席。\n婚仪在下方点选：勾上才写入子女，取消则按那条誓约拦住这门亲事。\n%s" % [a, b, rite]
			_vow_btn("确认期望，继续", func(): _vow_step = 1; _show_vow())
			_vow_btn("取消", func(): _vow_panel.visible = false)
		1:
			_vow_body.text = "[b]誓约·第二步 · 双姓共席 · 嫁妆偏向[/b]\n\n「灰旗不弃印，联姻不弃家。」\n请选择嫁妆旁注（永久家族修正）：\n旗饰＝丰收永续声望　祷文＝嗣子意志资质　商契＝丰收永续加银"
			_vow_btn("旗饰", func(): _vow_gift = "banner"; _vow_step = 2; _show_vow())
			_vow_btn("祷文", func(): _vow_gift = "prayer"; _vow_step = 2; _show_vow())
			_vow_btn("商契", func(): _vow_gift = "trade"; _vow_step = 2; _show_vow())
			_vow_btn("取消", func(): _vow_panel.visible = false)
		2:
			_vow_body.text = "[b]誓约·第三步 · 家训[/b]\n\n立家训，百年不改。择一：\n[color=#e07070]严教[/color]：月结士气微升，子嗣早教偏武更易\n[color=#6db0e0]仁恤[/color]：月结+粮与士气\n[color=#e9c46a]商本[/color]：月结+银"
			_vow_btn("严教", func(): _vow_doctrine = "strict"; _vow_step = 3; _show_vow())
			_vow_btn("仁恤", func(): _vow_doctrine = "mercy"; _vow_step = 3; _show_vow())
			_vow_btn("商本", func(): _vow_doctrine = "commerce"; _vow_step = 3; _show_vow())
			_vow_btn("取消", func(): _vow_panel.visible = false)
		3:
			var rite_line := _vow_rite_copy(leader)
			_vow_body.text = "[b]誓约·第四步 · 定聘落成[/b]\n\n聘礼 40 银将入库。家训与嫁妆写入族谱旁注。\n妊娠将在岁月中推进；陆桥会传『灰旗有家，可托孤』。\n%s" % rite_line
			_vow_btn("落成婚约", func(): _finish_marry())
			_vow_btn("取消", func(): _vow_panel.visible = false)

func _vow_btn(text: String, cb: Callable) -> void:
	var b: Button = UIKit.ghost_button(text, 132, 40) if text == "取消" else UIKit.make_accent_button(text, 150)
	b.pressed.connect(cb)
	_vow_actions.add_child(b)
	if _vow_actions.get_child_count() == 1:
		b.call_deferred("grab_focus")

func _finish_marry() -> void:
	if _selected == null:
		return
	var leader = GameState.get_leader()
	var ids := _accepted_ids()
	var r = Lineage.marry(leader, _selected, 40, ids)
	_msg.text = str(r.get("msg", ""))
	_vow_panel.visible = false
	if r.get("ok"):
		GameState.save_game()
		_msg.text += "　誓约完成。双姓共席，旗又升高一寸。"
		GameState.add_lineage_event("誓约婚宴：%s 与 %s 四步成礼（含家训）。" % [GameState.get_leader().name if GameState.get_leader() else "团长", _selected.name])
		match _vow_gift:
			"banner":
				GameState.add_rep("ashland", 4)
				GameState.house_mods["vow_banner"] = true
				GameState.add_lineage_event("嫁妆旁注：旗饰——丰收月永续声望")
			"prayer":
				GameState.add_skill_point(1)
				GameState.house_mods["vow_prayer"] = true
				GameState.add_lineage_event("嫁妆旁注：祷文——嗣子意志资质+1")
			"trade":
				GameState.silver += 30
				GameState.house_mods["vow_trade"] = true
				GameState.add_lineage_event("嫁妆旁注：商契——丰收永续加银")
		GameState.house_mods["doctrine"] = _vow_doctrine
		var dn = {"strict": "严教", "mercy": "仁恤", "commerce": "商本"}.get(_vow_doctrine, _vow_doctrine)
		GameState.add_lineage_event("家训既立：%s" % dn)
		for am in GameState.check_ambitions():
			_msg.text += "　" + am
		GameState.add_rep("ashland", 2)
		Sfx.confirm()
		Sfx.lineage_chime()
		play_seal_fx()
		_refresh()

func _back() -> void:
	if str(GameState.chapter0_beat) in ["0.4", "0.45", "0.5"] and not GameState.flag("chapter0_done"):
		get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
