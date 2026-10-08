extends Control
## v8.6 — layout-matched to Stitch 12_tavern.png: top bar (refresh) · RECRUITMENT ROSTER header ·
## three candidate cards (TARGET FOCUSED / STANDBY · plate · identity · attribute bars · traits · hire) · footer.

var _list: VBoxContainer     # legacy handle
var _detail: RichTextLabel   # legacy handle
var _selected: CKCharacter
var _msg: Label
var _portrait: TextureRect   # legacy handle
var _trait_row: HBoxContainer
var _cards: Control
var _card_scroll: ScrollContainer

func _ready() -> void:
	_build()
	_refresh()
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func _build() -> void:
	UIKit.void_bg(self)
	var tb := UIKit.top_bar(self, "烽火酒馆 · 本旬候选人", [["银币", str(GameState.silver), UIKit.ACCENT], ["月薪支出", "%d" % _payroll(), UIKit.DANGER], ["历", Calendar.label(), UIKit.TEXT_DIM]], "返回城堡", _back)
	var right_box: HBoxContainer = tb.get_child(tb.get_child_count() - 1)
	var rb := UIKit.ghost_button("刷新候选  ↻", 108, 32)
	rb.pressed.connect(func():
		GameState.refresh_tavern()
		_refresh())
	right_box.add_child(rb)
	right_box.move_child(rb, right_box.get_child_count() - 2)
	var hh := HBoxContainer.new()
	hh.position = Vector2(42, 74)
	hh.add_theme_constant_override("separation", 10)
	add_child(hh)
	var t := UIKit.title_label("招募名册", 22)
	hh.add_child(t)
	var en := UIKit.mono("/ RECRUITMENT ROSTER", 11, UIKit.ACCENT)
	en.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(en)
	var fl := UIKit.body_label("门轴会叫。柜上挂着脸与数——六维、血胤、禀性。看走眼，月饷会教你做人。", UIKit.TEXT_FAINT, 11)
	fl.autowrap_mode = TextServer.AUTOWRAP_OFF
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(fl)
	_msg = UIKit.body_label("", UIKit.OK, 12)
	_msg.autowrap_mode = TextServer.AUTOWRAP_OFF
	_msg.position = Vector2(838, 80)
	_msg.size = Vector2(400, 18)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_msg)
	_list = VBoxContainer.new()
	_list.visible = false
	add_child(_list)
	_detail = RichTextLabel.new()
	_detail.visible = false
	add_child(_detail)
	_portrait = TextureRect.new()
	_portrait.visible = false
	add_child(_portrait)
	_cards = Control.new()
	_cards.mouse_filter = Control.MOUSE_FILTER_PASS
	if DeviceProfile.is_mobile():
		_card_scroll = ScrollContainer.new()
		_card_scroll.name = "TavernCardScroll"
		_card_scroll.position = Vector2(24, 108)
		_card_scroll.size = Vector2(1232, 560)
		_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(_card_scroll)
		_card_scroll.add_child(_cards)
	else:
		add_child(_cards)
	UIKit.footer_bar(self, [["A", "确认招募"], ["X", "刷新名单"], ["←→", "切换候选人"], ["ESC", "返回城堡"]], "TAVERN PROTOCOL · FROST_TACTICAL v8.6")

func _payroll() -> int:
	var s := 0
	for c in GameState.roster():
		s += int(c.salary)
	return s

func apply_mobile_layout() -> void:
	if _card_scroll == null:
		return
	var foot := find_child("StitchFooter", true, false) as Control
	MobileLayout.fill_scroll(_card_scroll, foot, 560)
	_refresh()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()
	elif e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right"):
		var arr: Array = GameState.tavern_candidates
		if arr.is_empty() or _selected == null:
			return
		var i := arr.find(_selected)
		i = (i + (1 if e.is_action_pressed("ui_right") else -1) + arr.size()) % arr.size()
		_select(arr[i])

func _fee(c: CKCharacter) -> int:
	return 25 + c.rank_index() * 15

func _refresh() -> void:
	for n in _cards.get_children():
		_cards.remove_child(n)
		n.queue_free()
	if GameState.tavern_candidates.is_empty():
		var e := UIKit.empty_state("今夜柜上无人。点刷新再碰运气。")
		e.position = Vector2(42, 300)
		_cards.add_child(e)
		_selected = null
		return
	if _selected == null or not GameState.tavern_candidates.has(_selected):
		_selected = GameState.tavern_candidates[0]
	var i := 0
	var mobile := DeviceProfile.is_mobile() and _card_scroll != null
	var card_h := 540.0 + DeviceProfile.hit_px() if mobile else 570.0
	var y := 0.0
	for cand in GameState.tavern_candidates.slice(0, 3):
		if mobile:
			_card(cand, Rect2(0, y, 1196, card_h), cand == _selected, i)
			y += card_h + 12.0
		else:
			_card(cand, Rect2(42 + i * 404, 112, 388, 570), cand == _selected, i)
		i += 1
	if mobile:
		_cards.custom_minimum_size = Vector2(1196, y)

func _select(c: CKCharacter) -> void:
	_selected = c
	_refresh()

func _card(c: CKCharacter, r: Rect2, focus: bool, idx: int) -> void:
	var p := UIKit.panel_at(_cards, r, 12, focus)
	var click := Button.new()
	click.flat = true
	click.position = Vector2.ZERO
	click.size = r.size
	click.focus_mode = Control.FOCUS_NONE
	click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var e := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		click.add_theme_stylebox_override(st, e)
	click.pressed.connect(func(): _select(c))
	p.add_child(click)
	var tag := UIKit.tag_chip("TARGET FOCUSED" if focus else "STANDBY", UIKit.ACCENT, focus)
	tag.position = Vector2(18, 18)
	p.add_child(tag)
	var idl := UIKit.mono("ID #%s" % str(c.id).right(6).to_upper(), 9, UIKit.TEXT_FAINT, false)
	idl.position = Vector2(30 + tag.get_combined_minimum_size().x, 22)
	p.add_child(idl)
	var fee := HBoxContainer.new()
	fee.position = Vector2(220, 14)
	fee.size = Vector2(150, 26)
	fee.alignment = BoxContainer.ALIGNMENT_END
	fee.add_theme_constant_override("separation", 6)
	p.add_child(fee)
	var fl := UIKit.body_label("招募佣金", UIKit.TEXT_FAINT, 11)
	fl.autowrap_mode = TextServer.AUTOWRAP_OFF
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fee.add_child(fl)
	var fv := Label.new()
	fv.text = "%d" % _fee(c)
	fv.add_theme_font_override("font", UIKit.font("mono"))
	fv.add_theme_font_size_override("font_size", 20 if focus else 17)
	fv.add_theme_color_override("font_color", UIKit.ACCENT if focus else UIKit.TEXT)
	fee.add_child(fv)
	var fu := UIKit.body_label("银", UIKit.TEXT_FAINT, 11)
	fu.autowrap_mode = TextServer.AUTOWRAP_OFF
	fu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fee.add_child(fu)
	var job: Dictionary = GameState.get_job(c.job_id)
	UIKit.portrait_plate(p, Rect2(18, 54, 120, 150), c, str(job.get("name", "")).substr(0, 6))
	var en := UIKit.mono(str(job.get("role", "recruit")).to_upper() + " · " + c.rank_name(), 9, UIKit.TEXT_DIM, false)
	en.position = Vector2(154, 58)
	p.add_child(en)
	var nm := UIKit.title_label(c.name, 22)
	nm.add_theme_font_override("font", UIKit.font("bold"))
	nm.position = Vector2(154, 74)
	nm.size = Vector2(216, 30)
	nm.clip_text = true
	p.add_child(nm)
	var g := GridContainer.new()
	g.columns = 2
	g.position = Vector2(154, 114)
	g.add_theme_constant_override("h_separation", 6)
	p.add_child(g)
	var b1 := UIKit.stat_box("职业", str(job.get("name", "")), UIKit.ACCENT)
	b1.custom_minimum_size = Vector2(105, 0)
	g.add_child(b1)
	var b2 := UIKit.stat_box("年龄 · 月薪", "%d · %d" % [c.age, c.salary], UIKit.TEXT)
	b2.custom_minimum_size = Vector2(105, 0)
	g.add_child(b2)
	var sig_txt := CKBloodline.summary_zh(c)
	var ds := UIKit.body_label("%s血胤。%s" % [c.bloodline_display(), sig_txt if sig_txt != "冕征：未见" else "看脸，也看数。"], UIKit.TEXT_FAINT, 11)
	ds.position = Vector2(154, 172)
	ds.size = Vector2(216, 32)
	ds.custom_minimum_size = Vector2(216, 0)
	p.add_child(ds)
	# attributes
	var ab := UIKit.panel_at(p, Rect2(18, 218, 352, 148), 8)
	ab.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.08), 8))
	var at := UIKit.body_label("战术体格参量 (ATTRIBUTES)", UIKit.TEXT_DIM, 11)
	at.autowrap_mode = TextServer.AUTOWRAP_OFF
	at.position = Vector2(14, 10)
	ab.add_child(at)
	var tot := 0
	for sk in CKCharacter.STAT_KEYS:
		tot += int(c.stats[sk])
	var grade := "S" if tot >= 66 else ("A" if tot >= 56 else ("B" if tot >= 46 else "C"))
	var gl := UIKit.body_label("综合评级：%s" % grade, UIKit.OK, 11)
	gl.autowrap_mode = TextServer.AUTOWRAP_OFF
	gl.position = Vector2(250, 10)
	gl.size = Vector2(88, 16)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ab.add_child(gl)
	var keys: Array = CKCharacter.STAT_KEYS.duplicate()
	keys.sort_custom(func(a, b): return int(c.stats[a]) > int(c.stats[b]))
	var y := 34.0
	for sk in keys.slice(0, 3):
		var row := UIKit.kv_row(Locale.t("stat_" + sk), str(c.stats[sk]), UIKit.TEXT, 324)
		row.position = Vector2(14, y)
		ab.add_child(row)
		var bar := UIKit.slim_bar(float(c.stats[sk]), 16.0, UIKit.ACCENT if focus else UIKit.OK, 324, 3)
		bar.position = Vector2(14, y + 20)
		ab.add_child(bar)
		y += 30
	var dr := HBoxContainer.new()
	dr.position = Vector2(14, 124)
	dr.add_theme_constant_override("separation", 18)
	ab.add_child(dr)
	for it in [["生命", str(c.max_hp)], ["攻击", str(c.derived_atk())], ["防御", str(c.derived_def())], ["移动", str(c.derived_move())]]:
		dr.add_child(UIKit.stat_chip(it[0], it[1]))
	# traits
	var tl := UIKit.body_label("专属特质预览 (TRAITS)", UIKit.TEXT_DIM, 11)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tl.position = Vector2(18, 374)
	p.add_child(tl)
	var ty := 394.0
	var shown := 0
	for tr in c.traits:
		if shown >= 2:
			break
		var td: Dictionary = GameState.get_trait(str(tr))
		var tp := UIKit.panel_at(p, Rect2(18, ty, 352, 44), 6)
		tp.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.09), 6))
		var ic := UIKit.trait_icon_rect(str(tr), 22.0)
		ic.position = Vector2(10, 11)
		tp.add_child(ic)
		var tn := UIKit.body_label("「%s」" % str(td.get("name", tr)), UIKit.TEXT, 12)
		tn.autowrap_mode = TextServer.AUTOWRAP_OFF
		tn.position = Vector2(40, 4)
		tp.add_child(tn)
		var pol := str(td.get("polarity", ""))
		var pc := UIKit.body_label("增益" if pol == "pos" else ("减益" if pol == "neg" else "中性"), UIKit.OK if pol == "pos" else (UIKit.DANGER if pol == "neg" else UIKit.TEXT_FAINT), 10)
		pc.autowrap_mode = TextServer.AUTOWRAP_OFF
		pc.position = Vector2(290, 8)
		pc.size = Vector2(50, 14)
		pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tp.add_child(pc)
		var tdsc := UIKit.body_label(str(td.get("desc", "")), UIKit.TEXT_FAINT, 10)
		tdsc.autowrap_mode = TextServer.AUTOWRAP_OFF
		tdsc.clip_text = true
		tdsc.position = Vector2(40, 23)
		tdsc.size = Vector2(300, 16)
		tp.add_child(tdsc)
		ty += 50
		shown += 1
	if c.traits.is_empty():
		var nt := UIKit.body_label("（禀性未显）", UIKit.TEXT_FAINT, 12)
		nt.position = Vector2(18, ty)
		p.add_child(nt)
	var hire: Button
	var hire_h := 46
	if DeviceProfile.is_mobile():
		hire_h = int(maxf(46.0, DeviceProfile.hit_px()))
	if focus:
		hire = UIKit.cta_button("招募加入军团（%d 银）" % _fee(c), "A", 352, hire_h)
		hire.call_deferred("grab_focus")
	else:
		hire = UIKit.ghost_button("招募备选（%d 银）" % _fee(c), 352, maxi(42, hire_h - 4))
	hire.position = Vector2(18, r.size.y - 18 - hire.custom_minimum_size.y)
	hire.pressed.connect(func():
		_selected = c
		_hire())
	p.add_child(hire)

func _hire() -> void:
	if _selected == null:
		return
	var r = GameState.recruit(_selected)
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		Sfx.confirm()
		_selected = null
	_refresh()

func _back() -> void:
	if str(GameState.chapter0_beat) == "0.2" and not GameState.flag("hub_open"):
		get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
