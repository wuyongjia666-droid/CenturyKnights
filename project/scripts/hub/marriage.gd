extends Control

var _list: VBoxContainer
var _detail: RichTextLabel
var _expect: RichTextLabel
var _selected: CKCharacter
var _suitor: CKCharacter
var _suitor_bar: HBoxContainer
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
var _marry_idle := ""
var _rite_on: Dictionary = {}
var _posts_label: Label
var _post_nation := ""
var _wed_line: Label
var _toast: Label
var _toast_tw: Tween
var _chip_value: Array = []
var _result_hold := ""
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
	_suitor = _resolve_suitor()
	_ensure_posts()
	_build()
	_refresh_suitor_bar()
	_refresh()
	UIFX.slide_from_bottom(self, 24.0, 0.32)

const MobileReflow := preload("res://scripts/platform/mobile_reflow.gd")
var _mob := false
var _top_title := ""
var _top_back := ""
var _top_chips: Array = []
var _m_card_w := 400.0


func _build() -> void:
	## v8.6 — layout-matched to Stitch 17_marriage.png: protocol header · candidate tabs ·
	## CLAN PRINCIPAL | GENOMIC HARMONY | ALLIED SPOUSE · forecast + 再议/缔约 · footer
	UIKit.void_bg(self)
	_top_title = "宗族谱系枢纽 · 联姻盟誓"
	_top_back = "返回城堡"
	_top_chips = [
		["灰烬邦", GameState.get_rep_name("ashland"), UIKit.ACCENT],
		["河卫邦", GameState.get_rep_name("riverland"), UIKit.TEXT],
		["银币", str(GameState.silver), UIKit.ACCENT],
		["历", Calendar.label(), UIKit.TEXT_DIM]]
	var tb := UIKit.top_bar(self, _top_title, _top_chips, _top_back, _back)
	_bind_chips(tb)
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
	_posts_label = UIKit.mono(Locale.t("ux_marriage_posts", [_nation_name(_post_nation)]), 9, UIKit.TEXT_FAINT)
	_posts_label.position = Vector2(42, 228)
	add_child(_posts_label)
	var suitor_cap := UIKit.mono("SUITOR // 提亲方", 9, UIKit.ACCENT)
	suitor_cap.name = "SuitorCaption"
	suitor_cap.position = Vector2(42, 168)
	add_child(suitor_cap)
	_suitor_bar = HBoxContainer.new()
	_suitor_bar.name = "SuitorBar"
	_suitor_bar.position = Vector2(140, 160)
	_suitor_bar.size = Vector2(960, 40)
	_suitor_bar.add_theme_constant_override("separation", 8)
	add_child(_suitor_bar)
	var help := UIKit.ghost_button(Locale.t("ux_help_open"), 132, 32)
	help.name = "OpenGuide"
	help.position = Vector2(1106, 158)
	help.pressed.connect(func(): CKHelpCodex.open(self, true))
	add_child(help)
	_list = VBoxContainer.new()   # legacy handle (unused for layout)
	_list.visible = false
	add_child(_list)
	_tabs = HBoxContainer.new()
	_tabs.position = Vector2(300, 224)
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
	_punnett = UIKit.panel_at(self, Rect2(654, 508, 584, 128), 10)
	_punnett.name = "PunnettBoard"
	_msg = UIKit.body_label("选定婚仪后，这里写明子女会怎样入谱。", UIKit.TEXT_DIM, 12)
	_msg.name = "RiteExplain"
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.clip_text = false
	_msg.position = Vector2(12, 72)
	_msg.size = Vector2(576, 64)
	_rite_board.add_child(_msg)
	var row := HBoxContainer.new()
	row.name = "MarriageActions"
	row.position = Vector2(602, 642)
	row.size = Vector2(636, 44)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var duty_btn := UIKit.ghost_button("起誓·义役", 108, 40)
	duty_btn.name = "DutyOath"
	duty_btn.pressed.connect(func():
		UIFX.press_feedback(duty_btn)
		var r = GameState.start_alliance_duty()
		_msg.text = str(r.get("msg"))
		_show_toast(str(r.get("msg")), bool(r.get("ok")))
		if r.get("ok"):
			UIFX.confirm(duty_btn)
			Sfx.lineage_chime()
			GameState.save_game()
			_refresh_chips())
	row.add_child(duty_btn)
	var rite := UIKit.ghost_button("族谱授旗礼", 108, 40)
	rite.name = "FlagRite"
	rite.pressed.connect(func(): CKNav.go("res://scenes/hub/lineage_rite.tscn"))
	row.add_child(rite)
	var refresh := UIKit.ghost_button(_reroll_btn_text(), 148, 40)
	refresh.name = "Reroll"
	refresh.tooltip_text = Locale.t("ux_marriage_reroll_tip")
	refresh.pressed.connect(_on_reroll_pressed)
	row.add_child(refresh)
	_marry_btn = UIKit.cta_button("✓ 缔约 · 40 银", "A", 196, 44)
	_marry_idle = _marry_btn.text
	_marry_btn.pressed.connect(_start_vow)
	row.add_child(_marry_btn)
	_wed_line = UIKit.body_label("", UIKit.OK, 13)
	_wed_line.name = "SpouseLine"
	_wed_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wed_line.position = Vector2(42, 646)
	_wed_line.size = Vector2(520, 32)
	_wed_line.visible = false
	add_child(_wed_line)
	_toast = UIKit.body_label("", UIKit.TEXT, 14)
	_toast.name = "MarriageToast"
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	## Above RiteBoard/Punnett so 誓约完成 lines are not clipped under the green panels.
	_toast.position = Vector2(200, 300)
	_toast.size = Vector2(880, 168)
	_toast.z_index = 40
	_toast.visible = false
	var tst := UIKit.flat_box(Color(0.03, 0.045, 0.07, 0.94), Color(UIKit.ACCENT, 0.55), 8)
	tst.content_margin_left = 16
	tst.content_margin_right = 16
	tst.content_margin_top = 10
	tst.content_margin_bottom = 10
	_toast.add_theme_stylebox_override("normal", tst)
	add_child(_toast)
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
	var vp := UIKit.panel_at(_vow_panel, Rect2(220, 120, 840, 420), 12, true)
	var ve := UIKit.mono("VOW RITUAL // 誓约仪式", 10, UIKit.ACCENT)
	ve.position = Vector2(28, 22)
	vp.add_child(ve)
	_vow_body = RichTextLabel.new()
	_vow_body.bbcode_enabled = true
	_vow_body.fit_content = false
	_vow_body.position = Vector2(28, 48)
	_vow_body.size = Vector2(784, 280)
	_vow_body.add_theme_color_override("default_color", UIKit.TEXT)
	_vow_body.add_theme_font_size_override("normal_font_size", 14)
	_vow_body.add_theme_font_size_override("bold_font_size", 18)
	vp.add_child(_vow_body)
	_vow_actions = HBoxContainer.new()
	_vow_actions.position = Vector2(28, 350)
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
		if GameState.marriage_candidates.is_empty() or _selected == null or _spouse() != null:
			return
		var i := GameState.marriage_candidates.find(_selected)
		i = (i + (1 if e.is_action_pressed("ui_right") else -1) + GameState.marriage_candidates.size()) % GameState.marriage_candidates.size()
		_select(GameState.marriage_candidates[i])

func _refresh() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	if _posts_label:
		var su_l := _get_suitor()
		if su_l != null and CKFamilyState.is_hero_party(su_l) and not CKFamilyState.can_reroll_court(su_l):
			if CKFamilyState.uses_court_posts(su_l):
				_posts_label.text = "主线/教学廷帖 · %s（不可再议）" % _nation_name(_post_nation)
			else:
				_posts_label.text = "主角团主线姻缘（无廷帖刷新）"
		else:
			_posts_label.text = Locale.t("ux_marriage_posts", [_nation_name(_post_nation)])
	var reroll := get_node_or_null("MarriageActions/Reroll") as Button
	var sp := _spouse()
	_sync_reroll_btn(reroll, sp == null)
	_sync_footer_hints(sp != null)
	if sp != null:
		## Married: no candidate tabs — one clear banner, and the right card is the spouse.
		var banner := UIKit.body_label(married_banner_text(sp), UIKit.OK, MobilePage.FONT if _mob else 14)
		banner.name = "MarriedBanner"
		banner.autowrap_mode = TextServer.AUTOWRAP_OFF
		_tabs.add_child(banner)
		_select(sp)
		return
	if GameState.marriage_candidates.is_empty():
		var empty_msg := "春令无人应帖。再议或提高声望。"
		var su0 := _get_suitor()
		if su0 != null and CKFamilyState.is_hero_party(su0) and not CKFamilyState.uses_court_posts(su0):
			empty_msg = "主角团走主线姻缘，不在此刷廷帖。"
		elif su0 != null and CKFamilyState.is_hero_party(su0):
			empty_msg = "春令无人应帖。主角团不可再议抽帖。"
		_tabs.add_child(UIKit.empty_state(empty_msg))
		return
	var suitor = _get_suitor()
	var k := 0
	for cand in GameState.marriage_candidates:
		k += 1
		var check = Lineage.can_propose(suitor, cand)
		var mark := "●" if check.get("ok") else "○"
		if suitor != null and str(suitor.spouse_id) == str(cand.id):
			mark = Locale.t("ux_spouse_mark")
		var b := UIKit.ghost_button("%02d  %s · %s  %s" % [k, cand.name, cand.rank_name(), mark], 0, 32)
		b.tooltip_text = "可表白" if check.get("ok") else str(check.get("msg", "声望不足"))
		b.toggle_mode = true
		b.set_meta("cand", cand)
		var captured = cand
		b.pressed.connect(func(): _select(captured))
		_tabs.add_child(b)
	_select(GameState.marriage_candidates[0])

## Desktop footer: once wed, the first three key hints (contract / re-roll / switch candidate)
## no longer apply. footer_bar lays each hint out as keycap, label, gap.
const _WED_HIDDEN_HINT_COUNT := 3
func _sync_footer_hints(wed: bool) -> void:
	var foot := get_node_or_null("StitchFooter")
	if foot == null:
		return
	for h in foot.get_children():
		if h is HBoxContainer:
			var kids := h.get_children()
			for i in mini(kids.size(), _WED_HIDDEN_HINT_COUNT * 3):
				(kids[i] as Control).visible = not wed

## Current 提亲方's spouse, or null while that person is unmarried.
func _spouse() -> CKCharacter:
	var s := _get_suitor()
	if s == null or str(s.spouse_id) == "":
		return null
	return GameState.characters.get(str(s.spouse_id)) as CKCharacter

func married_banner_text(sp: CKCharacter) -> String:
	return Locale.t("ux_married_banner", [sp.name])

func is_married_view() -> bool:
	return _spouse() != null and _selected == _spouse()

func _resolve_suitor() -> CKCharacter:
	var fid := str(GameState.marriage_focus_id)
	if fid != "" and GameState.characters.has(fid):
		var c: CKCharacter = GameState.characters[fid]
		if CKFamilyState.is_marriage_suitor(c):
			return c
	var lead := GameState.get_leader()
	if lead != null:
		GameState.marriage_focus_id = str(lead.id)
	return lead

func _get_suitor() -> CKCharacter:
	if _suitor != null and is_instance_valid(_suitor):
		return _suitor
	_suitor = _resolve_suitor()
	return _suitor

func _set_suitor(c: CKCharacter) -> void:
	if c == null or not CKFamilyState.is_marriage_suitor(c):
		return
	_suitor = c
	GameState.marriage_focus_id = str(c.id)
	var nid := _post_nation if _post_nation != "" else CKFamilyState.active_marriage_nation(GameState)
	GameState.ensure_marriage_candidates(nid, c)
	_refresh_suitor_bar()
	_refresh()

func _refresh_suitor_bar() -> void:
	if _suitor_bar == null:
		return
	for ch in _suitor_bar.get_children():
		ch.queue_free()
	var cur := _get_suitor()
	for c in CKFamilyState.marriage_suitors(GameState):
		var mark := ""
		if str(c.spouse_id) != "":
			mark = " · 已成婚"
		var label := "%s%s" % [c.name, mark]
		if c.is_leader:
			label = "团长·" + label
		var b := UIKit.ghost_button(label, 0, 36)
		b.toggle_mode = true
		b.button_pressed = (cur != null and str(c.id) == str(cur.id))
		b.set_meta("suitor", c)
		b.custom_minimum_size = Vector2(maxi(96, int(b.get_minimum_size().x)), 36)
		var captured = c
		b.pressed.connect(func(): _set_suitor(captured))
		_suitor_bar.add_child(b)
	_sync_duty_btn()

func _sync_duty_btn() -> void:
	var duty := get_node_or_null("MarriageActions/DutyOath") as Control
	if duty == null:
		return
	var s := _get_suitor()
	## 联姻义役是团长外交；佣兵婚不走义役。
	duty.visible = s != null and bool(s.is_leader)

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
	var col_h := maxf(24.0, footer_y - 44.0)
	var col_w := maxf(40.0, rect.size.x - text_x - 10.0)
	var clip := Control.new()
	clip.position = Vector2(text_x, 36)
	clip.size = Vector2(col_w, col_h)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(clip)
	var v := VBoxContainer.new()
	v.position = Vector2.ZERO
	v.size = Vector2(col_w, col_h)
	v.clip_contents = true
	v.add_theme_constant_override("separation", 6 if compact else 2)
	clip.add_child(v)
	if compact:
		var age := UIKit.body_label(Locale.t("marriage_compact_who", [c.name, c.age]), UIKit.TEXT, 12)
		age.name = "AgeLine"
		age.autowrap_mode = TextServer.AUTOWRAP_OFF
		age.clip_text = true
		age.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(age)
	var role_tag: String = Locale.t("ux_spouse_side") if is_married_view() else "应帖者"
	var ln := UIKit.body_label("%s旗 · %s" % [GameState.surname if c.is_leader else str(c.name).substr(0, 1), "家主" if c.is_leader else role_tag], UIKit.TEXT, 13)
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
	var grade := "S" if pct >= 85 else ("A" if pct >= 70 else ("B" if pct >= 55 else "C"))
	# WS-C #34: three numbers that decide the match; everything else lives behind 「详情」
	_grade.text = Locale.t("wsc_mr_key") % [grade, pct, _rite_cost(a, b), CKCharacter.rank_label(str(ex.rank_hint))]
	_grade.name = "KeyFacts"
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
		var rk := UIKit.mono("RANK // %s" % CKCharacter.rank_label(str(ex.rank_hint)), 9, UIKit.TEXT_FAINT, false)
		rk.clip_text = true
		rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rk.position = Vector2(8, 176)
		rk.size = Vector2(rect.size.x - 16, 20)
		p.add_child(rk)
	## Heir preview: chips size to their two text lines and wrap into extra rows.
	var tp: Array = ex.trait_probs.slice(0, 3)
	var inner_w := rect.size.x - 16.0
	var it := UIKit.body_label("后代遗传特质推演", UIKit.TEXT_DIM, 11)
	it.autowrap_mode = TextServer.AUTOWRAP_OFF
	it.clip_text = true
	it.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_h := maxf(16.0, it.get_minimum_size().y)
	var chips: Array = []
	var chip_h := 0.0
	var min_cw := 28.0
	for tq in tp:
		var cn := UIKit.body_label(str(tq.name), UIKit.OK, 12)
		cn.autowrap_mode = TextServer.AUTOWRAP_OFF
		cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cp := UIKit.mono("%d%% 显性" % int(round(float(tq.prob) * 100)), 9, UIKit.TEXT_FAINT, false)
		cp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip_h = maxf(chip_h, cn.get_minimum_size().y + cp.get_minimum_size().y + 8.0)
		min_cw = maxf(min_cw, maxf(cn.get_minimum_size().x, cp.get_minimum_size().x) + 8.0)
		chips.append([cn, cp])
	var per_row := clampi(int((inner_w - 16.0 + 8.0) / (min_cw + 8.0)), 1, 3)
	var rows := int(ceil(float(maxi(1, chips.size())) / float(per_row)))
	var cw := maxf(min_cw, (inner_w - 16.0 - 8.0 * (per_row - 1)) / float(per_row))
	cw = minf(cw, inner_w - 16.0)
	var need_h := 4.0 + title_h + 4.0 + rows * chip_h + (rows - 1) * 4.0 + 6.0
	preview_h = maxf(preview_h, need_h)
	preview_y = minf(preview_y, rect.size.y - preview_h - 6.0)
	## never ride up over the big harmony number
	preview_y = maxf(preview_y, big.position.y + bw.y + 2.0)
	var one_line := need_h > rect.size.y - preview_y - 4.0
	if one_line:
		## tight panel: fold each chip into one line ("骁勇 55%") so nothing spills out
		chip_h = 0.0
		for ci in chips.size():
			var pr: Array = chips[ci]
			(pr[0] as Label).text = "%s %d%%" % [(pr[0] as Label).text, int(round(float(tp[ci].prob) * 100))]
			(pr[0] as Label).add_theme_font_size_override("font_size", 11)
			chip_h = maxf(chip_h, (pr[0] as Label).get_minimum_size().y + 4.0)
		preview_h = 4.0 + title_h + 4.0 + rows * chip_h + (rows - 1) * 4.0 + 4.0
	preview_h = minf(preview_h, rect.size.y - preview_y - 4.0)
	for n in p.get_children():
		if n is Control and n != big and n != pc and (n as Control).position.y >= 160.0 and (n as Control).position.y + (n as Control).size.y > preview_y:
			(n as Control).visible = false  # rank/bar yield to the preview when space is short
	var ib := UIKit.panel_at(p, Rect2(8, preview_y, inner_w, preview_h), 6)
	ib.name = "HeirPreview"
	ib.clip_contents = true
	it.position = Vector2(4, 4)
	it.size = Vector2(inner_w - 8.0, title_h)
	ib.add_child(it)
	for i in chips.size():
		var r := i / per_row
		var col := i % per_row
		var in_row := mini(per_row, chips.size() - r * per_row)
		var row_w := in_row * cw + (in_row - 1) * 8.0
		var x0 := (inner_w - row_w) * 0.5
		var chip := UIKit.panel_at(ib, Rect2(x0 + col * (cw + 8.0), 8.0 + title_h + r * (chip_h + 4.0), cw, chip_h), 4)
		chip.name = "TraitChip%d" % i
		var cs: StyleBoxFlat = chip.get_theme_stylebox("panel").duplicate()
		cs.bg_color = Color(UIKit.OK, 0.06)
		cs.border_color = Color(UIKit.OK, 0.45)
		chip.add_theme_stylebox_override("panel", cs)
		var cn: Label = chips[i][0]
		var cp: Label = chips[i][1]
		var h1 := cn.get_minimum_size().y
		cn.clip_text = true
		cn.position = Vector2(2, 4)
		cn.size = Vector2(cw - 4, h1)
		chip.add_child(cn)
		if one_line:
			cn.position.y = 2
			cp.free()
			continue
		cp.clip_text = true
		cp.position = Vector2(2, 4 + h1)
		cp.size = Vector2(cw - 4, cp.get_minimum_size().y)
		chip.add_child(cp)
func _render_cards() -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	var suitor = _get_suitor()
	var left_tag := "提亲一方" if suitor == null or not bool(suitor.is_leader) else "宗主一方"
	if _mob:
		_cards.add_child(_m_house_card(suitor, Locale.t("mw_fc94ece4"), UIKit.ACCENT))
		_cards.add_child(_m_harmony(suitor, _selected))
		_cards.add_child(_m_house_card(_selected, Locale.t("ux_spouse_side") if is_married_view() else Locale.t("mw_d382e424"), UIKit.OK))
		_fill_forecast(suitor, _selected)
		return
	_house_card(_rect_principal, suitor, left_tag, "CLAN PRINCIPAL", UIKit.ACCENT, "SERIES: VII-01")
	_harmony_card(_rect_harmony, suitor, _selected)
	_house_card(_rect_spouse, _selected, Locale.t("ux_spouse_side") if is_married_view() else "应帖一方", "SPOUSE" if is_married_view() else "ALLIED SPOUSE", UIKit.OK, "SERIES: IV-02")
	_fill_forecast(suitor, _selected)

func _fill_forecast(a: CKCharacter, b: CKCharacter) -> void:
	if _rite_board == null or _punnett == null:
		return
	if _mob:
		_m_fill_forecast(a, b)
		return
	if _msg and _msg.get_parent() != _rite_board and (_msg_scroll == null or _msg.get_parent() != _msg_scroll):
		_msg.reparent(_rite_board, false)
	for ch in _rite_board.get_children():
		if ch == _msg or ch == _msg_scroll:
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
	var rites: Array = CKCourt.required_rites(a, b) if a != null and b != null and not is_married_view() else []
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
			btn.tooltip_text = Locale.t("mw_6c9a2d8d") % [str(r.get("desc", "")), str(r.get("block", ""))]
			var captured := id
			btn.pressed.connect(func():
				_rite_on[captured] = not bool(_rite_on.get(captured, true))
				Sfx.click()
				if str(captured) == "frost":
					Sfx.play("frost_crackle")
				_fill_forecast(_get_suitor(), _selected))
			_rite_board.add_child(btn)
			x += step
	_consequence_line(a, b)
	_desk_msg_layout(row_y + 44.0 if not rites.is_empty() else row_y)
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
	cast.tooltip_text = cast.text
	cast.mouse_filter = Control.MOUSE_FILTER_PASS
	cast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cast.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	cast.position = Vector2(12, holder.position.y + holder.size.y + 2.0)
	cast.size = Vector2(hold_w, maxf(16.0, _punnett.size.y - cast.position.y - 4.0))
	## Wrap; if the panel still can't hold it, step the font down, then let the
	## punnett rows above give way so the forecast is never cut off.
	var fs := 12
	while fs > 10 and _label_text_h(cast, hold_w) > cast.size.y:
		fs -= 1
		cast.add_theme_font_size_override("font_size", fs)
	_punnett.add_child(cast)
	UIFX.wire_tree(_rite_board)
	_mobile_after_render.call_deferred()

## Landscape phone: one 76px top bar, candidate tabs, a scrolling body (three house cards,
## then rites + punnett) and a full-width action row, all at 22px / 76px.
func _mobile_relayout() -> bool:
	if _mob:
		return true
	if not MobilePage.active(self) or _punnett == null:
		return false
	_mob = true
	var vp := get_viewport().get_visible_rect().size
	var w := maxf(1280.0, vp.x * 720.0 / maxf(1.0, vp.y))
	var parts := PackedStringArray()
	for ch in _top_chips:
		parts.append("%s %s" % [ch[0], ch[1]])
	var help := get_node_or_null("OpenGuide") as Button
	var btns: Array = []
	if help:
		help.visible = false
		btns.append([help.text, func(): CKHelpCodex.open(self, true)])
	btns.append([_top_back, _back])
	MobilePage.top_bar(self, _top_title, " · ".join(parts), btns)
	for ch in get_children():
		if not (ch is Control) or ch == _cards or ch == _tabs or ch == _vow_panel or ch == _toast:
			continue
		var c := ch as Control
		if c.name in ["MobileTopBar", "MarriageActions", "RiteBoard", "PunnettBoard"] or c is TextureRect:
			continue
		if c.position.y > 40.0 and c.position.y < 240.0:
			c.visible = false
	_tabs.position = Vector2(16, MobilePage.TOP + 4.0)
	var jy := 720.0 - MobilePage.HIT - 12.0
	var row := get_node("MarriageActions") as HBoxContainer
	row.position = Vector2(16, jy)
	row.size = Vector2(w - 32.0, MobilePage.HIT)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	for b in row.get_children():
		(b as Control).custom_minimum_size = Vector2(0, MobilePage.HIT)
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(b as Control).add_theme_font_size_override("font_size", MobilePage.FONT)
	var top := MobilePage.TOP + 4.0 + MobilePage.HIT + 10.0
	var stack := MobileReflow.column(self, "MobileBody", Rect2(16, top, w - 32.0, jy - top - 10.0))
	# One row at 720 logical height: three house/harmony cards + a rites-over-odds column, so the
	# combat forecast sits above the action row without scrolling.
	var mrow := HBoxContainer.new()
	mrow.name = "MobileRow"
	mrow.add_theme_constant_override("separation", 10)
	stack.add_child(mrow)
	var cards := HBoxContainer.new()
	cards.name = "MobileCards"
	cards.add_theme_constant_override("separation", 10)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(cards)
	remove_child(_cards)
	_cards.queue_free()
	_cards = cards
	var inner := w - 32.0 - 24.0
	var side_w := clampf(inner * 0.29, 340.0, 520.0)
	_m_card_w = (inner - side_w - 30.0) / 3.0
	var boards := VBoxContainer.new()
	boards.name = "MobileBoards"
	boards.add_theme_constant_override("separation", 10)
	boards.custom_minimum_size.x = side_w
	mrow.add_child(boards)
	for bd in [_rite_board, _punnett]:
		(bd as Control).reparent(boards, false)
		(bd as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(bd as Control).size = Vector2(side_w, 0)
	if _wed_line:
		_wed_line.reparent(stack, false)
		_wed_line.add_theme_font_size_override("font_size", MobilePage.FONT)
	_rect_principal = Rect2(0, 0, _m_card_w, 300)
	_rect_harmony = Rect2(0, 0, _m_card_w, 300)
	_rect_spouse = Rect2(0, 0, _m_card_w, 300)
	_narrow = true
	_m_vow_panel(w)
	if _selected != null:
		_render_cards()
	return true


## Phone: the vow ritual card fills most of the screen with 24px text and 76px choices.
func _m_vow_panel(w: float) -> void:
	var vp := _vow_body.get_parent() as Control
	vp.position = Vector2(maxf(40.0, (w - 1100.0) * 0.5), 40)
	vp.size = Vector2(minf(1100.0, w - 80.0), 640)
	for ch in vp.get_children():
		if ch is Label:
			(ch as Label).add_theme_font_size_override("font_size", MobilePage.FONT)
	_vow_body.position = Vector2(32, 64)
	_vow_body.size = Vector2(vp.size.x - 64.0, 640.0 - 64.0 - MobilePage.HIT - 48.0)
	_vow_body.add_theme_font_size_override("normal_font_size", 24)
	_vow_body.add_theme_font_size_override("bold_font_size", 30)
	_vow_actions.position = Vector2(32, 640.0 - MobilePage.HIT - 28.0)
	_vow_actions.add_theme_constant_override("separation", 16)


func _mobile_after_render() -> void:
	if not _mob:
		return
	for bd in [_rite_board, _punnett]:
		MobileReflow.reflow_inplace(bd, (bd as Control).size.x)
	for b in _tabs.get_children():
		if b is Button:
			(b as Button).custom_minimum_size = Vector2(0, MobilePage.HIT)
			(b as Button).add_theme_font_size_override("font_size", MobilePage.FONT)


func apply_mobile_layout() -> void:
	if _mobile_relayout():
		return
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
		_punnett.size = Vector2(584, 128)
		var actions_wide := get_node_or_null("MarriageActions") as Control
		if actions_wide:
			actions_wide.position = Vector2(602, 642)
			actions_wide.size = Vector2(636, 44)
		if _wed_line:
			_wed_line.position = Vector2(42, 646)
			_wed_line.size = Vector2(520, 32)
	else:
		var margin := 8.0
		var foot := get_node_or_null("StitchFooter") as Control
		var foot_y := vp.y - 8.0
		if foot:
			foot_y = foot.position.y
		var actions := get_node_or_null("MarriageActions") as Control
		if actions:
			actions.position = Vector2(margin, foot_y - 58.0)
			actions.size = Vector2(vp.x - margin * 2.0, 44)
		if _wed_line:
			_wed_line.position = Vector2(margin, actions.position.y - 18.0 if actions else foot_y - 76.0)
			_wed_line.size = Vector2(maxf(120.0, vp.x * 0.42), 18.0)
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
		var help := get_node_or_null("OpenGuide") as Control
		if help:
			var help_w := help.size.x
			var x := minf(vp.x - 8.0 - help_w, _grade.position.x - 8.0 - help_w)
			help.position = Vector2(maxf(8.0, x), 72)
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
	if is_married_view():
		_msg.text = Locale.t("ux_married_note", [b.name])
		_msg.add_theme_color_override("font_color", UIKit.OK)
		return
	var bits: Array = []
	for r in CKCourt.required_rites(a, b):
		var id := str(r.get("id", ""))
		bits.append(str(r.get("desc", "")) if bool(_rite_on.get(id, false)) else str(r.get("block", "")))
	_full_terms = " ".join(bits) if not bits.is_empty() else "无特殊婚仪。子女按常例入谱。"
	_msg.text = _full_terms if _full_terms.length() <= 40 else _full_terms.substr(0, 38) + Locale.t("wsc_mr_more")
	_msg.tooltip_text = _full_terms
	_msg.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _msg.gui_input.is_connected(_on_msg_input):
		_msg.gui_input.connect(_on_msg_input)
	var blocked := CKCourt.rite_block(a, b, _accepted_ids()) != ""
	_msg.add_theme_color_override("font_color", UIKit.DANGER if blocked else UIKit.TEXT_DIM)

var _full_terms := ""
var _msg_scroll: ScrollContainer

func _label_text_h(l: Label, w: float) -> float:
	var f: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	return f.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y + 2.0

## Desktop rite log: top-aligned, wrapped, scrolls when longer than the board.
func _desk_msg_layout(top_y: float) -> void:
	if _msg == null or _rite_board == null:
		return
	if _msg_scroll == null or not is_instance_valid(_msg_scroll):
		_msg_scroll = ScrollContainer.new()
		_msg_scroll.name = "RiteLogScroll"
		_msg_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_rite_board.add_child(_msg_scroll)
	if _msg_scroll.get_parent() != _rite_board:
		_msg_scroll.reparent(_rite_board, false)
	if _msg.get_parent() != _msg_scroll:
		_msg.reparent(_msg_scroll, false)
	_rite_board.clip_contents = true
	var w := maxf(40.0, _rite_board.size.x - 24.0)
	_msg_scroll.position = Vector2(12, top_y)
	_msg_scroll.size = Vector2(w, maxf(20.0, _rite_board.size.y - top_y - 6.0))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.clip_text = false
	_msg.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg.custom_minimum_size = Vector2(w - 12.0, 0)
	if _full_terms != "" and not is_married_view() and _msg.text.ends_with(Locale.t("wsc_mr_more")):
		_msg.text = _full_terms

func _rite_cost(a: CKCharacter, b: CKCharacter) -> int:
	var cost := 0
	if a == null or b == null:
		return 0
	for r in CKCourt.required_rites(a, b):
		if bool(_rite_on.get(str(r.get("id", "")), true)):
			cost += int(r.get("cost", 0))
	return cost

func _on_msg_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if tap and _full_terms.length() > 40:
		show_details()

## Full terms + child forecast in one readable box (the old bottom strip of small print).
func show_details() -> void:
	var old := find_child("MarriageDetails", false, false)
	if old:
		old.queue_free()
	if _mob:
		var sh := MobilePage.sheet(self, "MarriageDetails", Locale.t("wsc_mr_detail"), 40, UIKit.ACCENT)
		var sv: VBoxContainer = sh[1]
		var list := MobilePage.sheet_scroll(sv, 200.0)
		var line := str(CKFamilyState.combat_expectation(_get_suitor(), _selected).get("line", ""))
		list.add_child(MobilePage.label(_full_terms + "\n\n" + line, UIKit.TEXT, 24, true))
		var okb := MobilePage.button(Locale.t("wsc_t_lost_ok"), true, (sh[0] as Node).queue_free)
		sv.add_child(okb)
		okb.call_deferred("grab_focus")
		return
	var overlay := ColorRect.new()
	overlay.name = "MarriageDetails"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 40
	add_child(overlay)
	var p := UIKit.panel_at(overlay, Rect2(240, 120, 800, 480), 14, true)
	var t := UIKit.title_label(Locale.t("wsc_mr_detail"), 20, UIKit.ACCENT)
	t.position = Vector2(24, 18)
	p.add_child(t)
	var sc := ScrollContainer.new()
	sc.position = Vector2(24, 60)
	sc.size = Vector2(752, 340)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var body := UIKit.body_label(_full_terms + "\n\n" + str(CKFamilyState.combat_expectation(_get_suitor(), _selected).get("line", "")), UIKit.TEXT, 15)
	body.custom_minimum_size = Vector2(740, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sc.add_child(body)
	var ok := UIKit.ghost_button(Locale.t("wsc_t_lost_ok"), 180, 48)
	ok.position = Vector2(596, 416)
	ok.pressed.connect(overlay.queue_free)
	p.add_child(ok)
	ok.call_deferred("grab_focus")

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
	var check = Lineage.can_propose(_get_suitor(), c)
	var rite_block := CKCourt.rite_block(_get_suitor(), c, _accepted_ids()) if check.get("ok") else ""
	_marry_btn.disabled = not bool(check.get("ok")) or rite_block != ""
	_marry_btn.tooltip_text = str(check.get("msg", "")) if not check.get("ok") else rite_block
	if not check.get("ok"):
		_msg.text = "门槛：%s" % str(check.get("msg", ""))
		_msg.add_theme_color_override("font_color", UIKit.DANGER)
	if is_married_view():
		_msg.text = Locale.t("ux_married_note", [c.name])
		_msg.add_theme_color_override("font_color", UIKit.OK)
	_sync_contract_button()
	if _result_hold != "":
		_msg.text = _result_hold
		_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_msg.clip_text = false
		_msg.add_theme_color_override("font_color", UIKit.OK)

func _start_vow() -> void:
	var suitor = _get_suitor()
	if suitor != null and str(suitor.spouse_id) != "":
		_present_wed(Locale.t("ux_married_block"), false)
		return
	if _selected == null:
		return
	var check = Lineage.can_propose(suitor, _selected)
	if not check.get("ok"):
		_msg.text = str(check.get("msg", "不可定聘"))
		return
	_vow_step = 0
	_vow_panel.visible = true
	_show_vow()

func _show_vow() -> void:
	for c in _vow_actions.get_children():
		c.queue_free()
	var suitor = _get_suitor()
	var a = suitor.name if suitor else "提亲方"
	var b = _selected.name
	match _vow_step:
		0:
			var rite := _vow_rite_copy(suitor)
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
			var rite_line := _vow_rite_copy(suitor)
			_vow_body.text = "[b]誓约·第四步 · 定聘落成[/b]\n\n聘礼 40 银将入库。家训与嫁妆写入族谱旁注。\n妊娠将在岁月中推进；陆桥会传『灰旗有家，可托孤』。\n%s" % rite_line
			_vow_btn("落成婚约", func(): _finish_marry())
			_vow_btn("取消", func(): _vow_panel.visible = false)

func _vow_btn(text: String, cb: Callable) -> void:
	var b: Button = UIKit.ghost_button(text, 132, 40) if text == "取消" else UIKit.make_accent_button(text, 150)
	if _mob:
		b.custom_minimum_size = Vector2(220, MobilePage.HIT)
		b.add_theme_font_size_override("font_size", MobilePage.FONT)
	b.pressed.connect(cb)
	_vow_actions.add_child(b)
	if _vow_actions.get_child_count() == 1:
		b.call_deferred("grab_focus")

func _finish_marry() -> void:
	if _selected == null:
		return
	var suitor = _get_suitor()
	var ids := _accepted_ids()
	var r = Lineage.marry(suitor, _selected, 40, ids, true)
	_msg.text = str(r.get("msg", ""))
	_vow_panel.visible = false
	if r.get("ok"):
		GameState.save_game()
		_msg.text += "　誓约完成。双姓共席，旗又升高一寸。"
		var sname: String = suitor.name if suitor else "提亲方"
		GameState.add_lineage_event("誓约婚宴：%s 与 %s 四步成礼（含家训）。" % [sname, _selected.name])
		## 家训 / 嫁妆旁注仍是团旗外交婚的特典；佣兵婚只成礼入谱。
		if suitor != null and bool(suitor.is_leader):
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
		_present_wed(_msg.text, true)
		_refresh_suitor_bar()
		_refresh()

func _ensure_posts() -> void:
	var nid := CKFamilyState.active_marriage_nation(GameState)
	var suitor := _get_suitor()
	GameState.ensure_marriage_candidates(nid, suitor)
	_post_nation = nid

func _reroll_btn_text() -> String:
	var cost := CKFamilyState.COURT_REROLL_SILVER
	var text := "再议 · %d银" % cost
	if not DeviceProfile.is_mobile():
		text += "  [B]"
	return text

func _on_reroll_pressed() -> void:
	var suitor := _get_suitor()
	if suitor != null and not CKFamilyState.can_reroll_court(suitor):
		_show_toast("主角团走主线姻缘，不可再议抽帖", false)
		return
	var nid := _post_nation if _post_nation != "" else CKFamilyState.active_marriage_nation(GameState)
	var r: Dictionary = GameState.reroll_marriage_candidates(nid, suitor)
	_show_toast(str(r.get("msg", "")), bool(r.get("ok", false)))
	if bool(r.get("ok", false)):
		_refresh_chips()
		_refresh()

func _sync_reroll_btn(reroll: Button, unmarried: bool) -> void:
	if reroll == null:
		return
	var suitor := _get_suitor()
	var allow := unmarried and suitor != null and CKFamilyState.can_reroll_court(suitor)
	reroll.visible = unmarried and suitor != null and (CKFamilyState.can_reroll_court(suitor) or CKFamilyState.uses_court_posts(suitor))
	## Hero captain: show greyed 再议 so the rule is visible; mercs: enabled when unmarried.
	if suitor != null and CKFamilyState.is_hero_party(suitor):
		reroll.visible = unmarried
		reroll.disabled = true
		reroll.text = "再议 · 主线"
		reroll.tooltip_text = "主角团走主线姻缘，不可再议抽帖"
	else:
		reroll.disabled = not allow
		reroll.text = _reroll_btn_text()
		reroll.tooltip_text = Locale.t("ux_marriage_reroll_tip") + "（%d 银）" % CKFamilyState.COURT_REROLL_SILVER

func _nation_name(nid: String) -> String:
	return str(CKBloodline.nation(nid).get("name", nid))

func _bind_chips(bar: Control) -> void:
	_chip_value.clear()
	if bar == null or bar.get_child_count() == 0:
		return
	var right := bar.get_child(bar.get_child_count() - 1)
	if right == null:
		return
	for ch in right.get_children():
		if ch is PanelContainer and ch.get_child_count() > 0:
			var row := ch.get_child(0)
			if row.get_child_count() >= 2 and row.get_child(1) is Label:
				_chip_value.append(row.get_child(1))

func _refresh_chips() -> void:
	if _chip_value.size() < 4:
		return
	(_chip_value[0] as Label).text = GameState.get_rep_name("ashland")
	(_chip_value[1] as Label).text = GameState.get_rep_name("riverland")
	(_chip_value[2] as Label).text = str(GameState.silver)
	(_chip_value[3] as Label).text = Calendar.label()

func _sync_contract_button() -> void:
	if _marry_btn == null:
		return
	var suitor = _get_suitor()
	var wed := suitor != null and str(suitor.spouse_id) != ""
	if wed:
		_marry_btn.disabled = true
		_marry_btn.text = Locale.t("ux_married_cta")
	elif _marry_idle != "":
		_marry_btn.text = _marry_idle
	if _wed_line == null:
		return
	if wed and GameState.characters.has(str(suitor.spouse_id)):
		var sp: CKCharacter = GameState.characters[str(suitor.spouse_id)]
		## The top MarriedBanner already names the spouse; on phones this line fell under the cards
		## (and mobile reflow can re-show it), so keep it empty as well as hidden.
		_wed_line.text = ""
		_wed_line.tooltip_text = Locale.t("ux_spouse_line", [sp.name])
		_wed_line.visible = false
	else:
		_wed_line.visible = false
		_wed_line.text = ""

func _show_toast(text: String, ok: bool) -> void:
	if _toast == null or text == "":
		return
	_toast.text = text
	_toast.add_theme_color_override("font_color", UIKit.OK if ok else UIKit.DANGER)
	## Tall centered toast: multi-line 婚仪/誓约完成 must not sit under the green boards.
	_toast.position = Vector2(200, 300)
	_toast.size = Vector2(880, 168 if text.length() > 40 else 110)
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = _toast.create_tween()
	_toast_tw.tween_interval(3.4)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.35)
	_toast_tw.tween_callback(func():
		if is_instance_valid(_toast):
			_toast.visible = false)

func _present_wed(text: String, ok: bool) -> void:
	if ok:
		_result_hold = text
	_show_toast(text, ok)
	_refresh_chips()
	_sync_contract_button()
	if _msg and text != "":
		_msg.text = text
		_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_msg.clip_text = false
		_msg.add_theme_color_override("font_color", UIKit.OK if ok else UIKit.DANGER)
		if _rite_board != null and not _mob:
			_desk_msg_layout(32.0 if is_married_view() else _msg.position.y)

func _back() -> void:
	if str(GameState.chapter0_beat) in ["0.4", "0.45", "0.5"] and not GameState.flag("chapter0_done"):
		CKNav.replace("res://scenes/story/chapter0.tscn")
	else:
		CKNav.up()



## ── Phone cards: container-built so every line wraps inside its column; no empty stat plates ──
func _m_card_box(col: Color) -> Array:
	var p := PanelContainer.new()
	var sb := UIKit.flat_box(Color(0.055, 0.067, 0.090, 0.92), Color(col, 0.35), 10)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 12)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size.x = _m_card_w
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	return [p, v]

func _m_house_card(c: CKCharacter, side_tag: String, col: Color) -> Control:
	var pv := _m_card_box(col)
	var v: VBoxContainer = pv[1]
	v.add_child(MobilePage.label(side_tag, col, MobilePage.FONT, false))
	if c == null:
		return pv[0]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var pr := UIKit.make_portrait_rect(c, 132)
	pr.custom_minimum_size = Vector2(84, 112)
	pr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pr)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var nm := MobilePage.label(c.name, UIKit.TEXT, 24, true)
	nm.name = "CardName"
	nm.add_theme_font_override("font", UIKit.font("bold"))
	info.add_child(nm)
	var age := MobilePage.label(Locale.t("mw_0ea48000") % [c.age, GameState.get_job(c.job_id).get("name", "")], col, MobilePage.FONT, true)
	age.name = "AgeLine"
	info.add_child(age)
	info.add_child(MobilePage.label("%s · LV %d" % [c.rank_name(), c.level], UIKit.TEXT, MobilePage.FONT, true))
	info.add_child(MobilePage.label(Locale.t("mw_6e124674") % [c.derived_atk(), c.derived_def()], UIKit.TEXT_DIM, MobilePage.FONT, true))
	var pb := str(c.primary_bloodline())
	var bl: Dictionary = GameState.get_bloodline(pb)
	var pct := int(round(float(c.blood_mix.get(pb, 1.0)) * 100))
	v.add_child(MobilePage.label(Locale.t("mw_4b9d1a53") % [str(bl.get("name", pb)), pct], col, MobilePage.FONT, true))
	var tr_names: Array = []
	for tid in c.traits.slice(0, 3):
		tr_names.append(str(GameState.get_trait(str(tid)).get("name", tid)))
	v.add_child(MobilePage.label(Locale.t("mw_b88be11b") % ("、".join(tr_names) if not tr_names.is_empty() else Locale.t("mw_47f87f27")), UIKit.TEXT_FAINT, MobilePage.FONT, true))
	return pv[0]

func _m_harmony(a: CKCharacter, b: CKCharacter) -> Control:
	var pv := _m_card_box(UIKit.TEXT_DIM)
	var v: VBoxContainer = pv[1]
	v.add_child(MobilePage.label(Locale.t("mw_9090426e"), UIKit.TEXT_DIM, MobilePage.FONT, false))
	if a == null or b == null:
		return pv[0]
	var ex: Dictionary = Lineage.heir_expectation(a, b)
	var mids := 0.0
	var hi := 1.0
	for sk in CKCharacter.STAT_KEYS:
		mids += (float(ex.apt_min[sk]) + float(ex.apt_max[sk])) * 0.5
		hi = maxf(hi, float(ex.apt_max[sk]))
	var pct := clampi(int(round(mids / CKCharacter.STAT_KEYS.size() / maxf(hi, 12.0) * 100.0)), 1, 99)
	var grade := "S" if pct >= 85 else ("A" if pct >= 70 else ("B" if pct >= 55 else "C"))
	_grade.text = Locale.t("wsc_mr_key") % [grade, pct, _rite_cost(a, b), CKCharacter.rank_label(str(ex.rank_hint))]
	_grade.name = "KeyFacts"
	var big := MobilePage.label("%s  %d%%" % [grade, pct], UIKit.ACCENT, 40, false)
	big.add_theme_font_override("font", UIKit.font("mono"))
	v.add_child(big)
	v.add_child(MobilePage.label(Locale.t("mw_c4a0ef09") % str(CKCharacter.rank_label(str(ex.rank_hint))), UIKit.TEXT, MobilePage.FONT, true))
	var hp := VBoxContainer.new()
	hp.name = "HeirPreview"
	hp.add_theme_constant_override("separation", 2)
	v.add_child(hp)
	hp.add_child(MobilePage.label(Locale.t("mw_87646fa0"), UIKit.TEXT_FAINT, MobilePage.FONT, false))
	for t in ex.trait_probs.slice(0, 3):
		hp.add_child(MobilePage.label("%s  %d%%" % [str(t.name), int(round(float(t.prob) * 100))], UIKit.OK, MobilePage.FONT, true))
	return pv[0]


## Phone: rites and child forecast as two auto-height cards (the fixed-size boards squashed text).
func _m_fill_forecast(a: CKCharacter, b: CKCharacter) -> void:
	var boards := _rite_board.get_parent() as Control
	_rite_board.visible = false
	_punnett.visible = false
	for nm in ["MRites", "MForecast"]:
		var old := boards.get_node_or_null(nm)
		if old:
			if _msg and old.is_ancestor_of(_msg):
				_msg.reparent(self, false)
			boards.remove_child(old)
			old.queue_free()
	var rp := _m_card_box(UIKit.ACCENT)
	(rp[0] as Control).name = "MRites"
	(rp[0] as Control).custom_minimum_size.x = 0
	boards.add_child(rp[0])
	var rv: VBoxContainer = rp[1]
	rv.add_child(MobilePage.label(Locale.t("mw_127f0d3b"), UIKit.ACCENT, MobilePage.FONT, false))
	_sync_rite_flags(a, b)
	var rites: Array = CKCourt.required_rites(a, b) if a != null and b != null and not is_married_view() else []
	if not rites.is_empty():
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 8)
		fl.add_theme_constant_override("v_separation", 8)
		rv.add_child(fl)
		for r in rites:
			var id := str(r.get("id", ""))
			var on := bool(_rite_on.get(id, true))
			var captured := id
			var btn := MobilePage.button("%s %s" % ["✓" if on else "○", str(r.get("name", id))], on, func():
				_rite_on[captured] = not bool(_rite_on.get(captured, true))
				Sfx.click()
				if str(captured) == "frost":
					Sfx.play("frost_crackle")
				_m_fill_forecast(_get_suitor(), _selected), 180)
			btn.name = "Rite_" + id
			btn.size_flags_horizontal = Control.SIZE_FILL
			btn.tooltip_text = Locale.t("mw_6c9a2d8d") % [str(r.get("desc", "")), str(r.get("block", ""))]
			fl.add_child(btn)
	(rp[0] as Control).visible = true  # married: keep the vow log readable (page body scrolls)
	_msg.reparent(rv, false)
	_msg.add_theme_font_size_override("font_size", MobilePage.FONT)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg.custom_minimum_size = Vector2(0, 0)
	_consequence_line(a, b)
	var fp := _m_card_box(UIKit.TEXT_DIM)
	(fp[0] as Control).name = "MForecast"
	(fp[0] as Control).custom_minimum_size.x = 0
	boards.add_child(fp[0])
	var fv: VBoxContainer = fp[1]
	fv.add_child(MobilePage.label(Locale.t("mw_085d21a4"), UIKit.TEXT_DIM, MobilePage.FONT, false))
	if a != null and b != null:
		## Odds share one wrapping line so the combat forecast fits a 16:9 phone without scrolling.
		var odds := PackedStringArray()
		for r in CKBloodline.forecast(a, b).slice(0, 2):
			odds.append("%s %d%%" % [str(r.get("royal_zh", "")), int(round(float(r.get("royal", 0.0)) * 100.0))])
		for r2 in CKBloodline.trait_odds(a, b).slice(0, 2):
			odds.append("%s %d%%" % [str(r2.get("zh", "")), int(round(float(r2.get("shown", 0.0)) * 100.0))])
		var ol := MobilePage.label(" · ".join(odds), UIKit.TEXT, MobilePage.FONT, true)
		ol.name = "HeirOdds"
		fv.add_child(ol)
		var cast := MobilePage.label(str(CKFamilyState.combat_expectation(a, b).get("line", "")), UIKit.ACCENT, MobilePage.FONT, true)
		cast.name = "CombatForecast"
		fv.add_child(cast)
	UIFX.wire_tree(boards)
	_mobile_after_render.call_deferred()
