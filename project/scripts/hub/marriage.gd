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
	UIKit.make_themed_bg(self, "marriage")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)
	if not UIKit.RETIRE_CHROME and ResourceLoader.exists("res://assets/art/ui/hub_banner_strip.png"):
		var strip := TextureRect.new()
		strip.texture = load("res://assets/art/ui/hub_banner_strip.png")
		strip.position = Vector2(0, 0)
		strip.custom_minimum_size = Vector2(1280, 48)
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)

	var _mb = TextureRect.new()
	if not UIKit.RETIRE_CHROME and ResourceLoader.exists("res://assets/art/ui/marriage_banner.png"):
		_mb.texture = load("res://assets/art/ui/marriage_banner.png")
		_mb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_mb.stretch_mode = TextureRect.STRETCH_SCALE
		_mb.position = Vector2(0, 0)
		_mb.size = Vector2(1280, 56)
		_mb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_mb)
		UIFX.banner_shimmer(_mb, 3.6)
	var t = UIKit.make_label("联姻廷 · 春令试婚", true)
	t.position = Vector2(40, 12)
	add_child(t)
	var rep = UIKit.make_dim_label("灰烬邦声望：%s　河卫邦：%s　——声望是门，子嗣期望是窗。" % [GameState.get_rep_name("ashland"), GameState.get_rep_name("riverland")])
	rep.position = Vector2(40, 52)
	add_child(rep)

	var list_panel = UIKit.make_panel()
	list_panel.position = Vector2(40, 90)
	list_panel.custom_minimum_size = Vector2(360, 380)
	add_child(list_panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	list_panel.add_child(_list)

	var detail_panel = UIKit.make_panel()
	detail_panel.position = Vector2(420, 90)
	detail_panel.custom_minimum_size = Vector2(400, 380)
	add_child(detail_panel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	detail_panel.add_child(dv)
	dv.add_child(_build_dual())
	_detail = RichTextLabel.new()
	_detail.scroll_active = true
	_detail.custom_minimum_size = Vector2(380, 190)
	_detail.bbcode_enabled = true
	_detail.add_theme_color_override("default_color", UIKit.TEXT)
	dv.add_child(_detail)

	var el = UIKit.make_label(Locale.t("heir_expect"))
	el.position = Vector2(840, 90)
	el.add_theme_color_override("font_color", UIKit.ACCENT)
	add_child(el)
	var exp_panel = UIKit.make_panel()
	exp_panel.position = Vector2(840, 120)
	exp_panel.custom_minimum_size = Vector2(400, 350)
	add_child(exp_panel)
	_expect = RichTextLabel.new()
	_expect.custom_minimum_size = Vector2(370, 320)
	_expect.bbcode_enabled = true
	_expect.add_theme_color_override("default_color", UIKit.TEXT)
	exp_panel.add_child(_expect)

	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 500)
	_msg.custom_minimum_size = Vector2(800, 40)
	add_child(_msg)
	var flavor = UIKit.make_dim_label("厅外有人比较旗色与族谱。王朝烽烟里，联姻是同盟，子嗣期望是承诺——订婚前务必读完。")
	flavor.position = Vector2(40, 540)
	add_child(flavor)
	var duty_tip = UIKit.make_dim_label("联姻后可起「义役」：六月护路共济——真月结代价，换声望与商路安稳。")
	duty_tip.position = Vector2(40, 570)
	add_child(duty_tip)
	var duty_btn = UIKit.make_accent_button("起誓·联姻义役", 160)
	duty_btn.position = Vector2(900, 560)
	if ResourceLoader.exists("res://assets/art/ui/alliance_duty_chip.png"):
		var dc := TextureRect.new()
		dc.texture = load("res://assets/art/ui/alliance_duty_chip.png")
		dc.position = Vector2(860, 558)
		dc.custom_minimum_size = Vector2(32, 32)
		dc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dc)
	duty_btn.pressed.connect(func():
		UIFX.press_feedback(duty_btn)
		var r = GameState.start_alliance_duty()
		_msg.text = str(r.get("msg"))
		if r.get("ok"):
			UIFX.confirm_burst(duty_btn)
			Sfx.lineage_chime()
			GameState.save_game()
)
	add_child(duty_btn)

	var row := HBoxContainer.new()
	row.position = Vector2(40, 590)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var marry = UIKit.make_accent_button("进入誓约仪式（40银）", 240)
	marry.pressed.connect(_start_vow)
	row.add_child(marry)
	var rite = UIKit.make_button("族谱授旗礼", 140)
	rite.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/lineage_rite.tscn"))
	row.add_child(rite)
	var refresh = UIKit.make_button("刷新候选", 120)
	refresh.pressed.connect(func():
		GameState.refresh_marriage_candidates()
		_refresh()
	)
	row.add_child(refresh)
	var back = UIKit.make_button(Locale.t("btn_back"), 100)
	back.pressed.connect(_back)
	row.add_child(back)

	_vow_panel = UIKit.make_panel()
	_vow_panel.position = Vector2(200, 160)
	_vow_panel.custom_minimum_size = Vector2(880, 360)
	_vow_panel.visible = false
	add_child(_vow_panel)
	_vow_body = RichTextLabel.new()
	_vow_body.bbcode_enabled = true
	_vow_body.custom_minimum_size = Vector2(840, 260)
	_vow_body.position = Vector2(20, 16)
	_vow_body.add_theme_color_override("default_color", UIKit.TEXT)
	_vow_panel.add_child(_vow_body)
	_vow_actions = HBoxContainer.new()
	_vow_actions.position = Vector2(20, 290)
	_vow_actions.add_theme_constant_override("separation", 12)
	_vow_panel.add_child(_vow_actions)

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if GameState.marriage_candidates.is_empty():
		_list.add_child(UIKit.empty_state("春令无人应帖。刷新或提高声望。"))
		return
	for cand in GameState.marriage_candidates:
		var check = Lineage.can_propose(GameState.get_leader(), cand)
		var tag = "可表白" if check.get("ok") else "声望不足"
		var b = UIKit.make_button("%s　%s　%s" % [cand.name, cand.rank_name(), tag], 320)
		var captured = cand
		b.pressed.connect(func(): _select(captured))
		_list.add_child(b)
	_select(GameState.marriage_candidates[0])

func _oval_portrait(parent: Control, box: Rect2, s: float) -> TextureRect:
	## portrait clipped to an ellipse (oval_mask) so it sits inside the dual frame's rings
	var mask := TextureRect.new()
	mask.texture = load("res://assets/art/ui/v85/oval_mask.png")
	mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mask.stretch_mode = TextureRect.STRETCH_SCALE
	mask.position = box.position * s
	mask.size = box.size * s
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(mask)
	var bgc := ColorRect.new()
	bgc.color = UIKit.BG
	bgc.size = mask.size
	bgc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(bgc)
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.size = mask.size
	tr.pivot_offset = mask.size * 0.5
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(tr)
	return tr

func _build_dual() -> Control:
	## v8.5 dual vow frame: v840 dual_portrait_frame with ovals cut (prep_v850_chrome.py);
	## leader left, candidate right, authored marriage_seal FX blooms at the join.
	var s := DUAL_W / 720.0
	_dual = Control.new()
	_dual.custom_minimum_size = Vector2(720, 320) * s
	_dual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_leader_portrait = _oval_portrait(_dual, Rect2(62, 48, 262, 230), s)
	_portrait = _oval_portrait(_dual, Rect2(405, 36, 258, 246), s)
	var fr := TextureRect.new()
	var fp := "res://assets/art/ui/v85/dual_portrait_frame_cut.png"
	if ResourceLoader.exists(fp):
		fr.texture = load(fp)
	fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fr.stretch_mode = TextureRect.STRETCH_SCALE
	fr.size = _dual.custom_minimum_size
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dual.add_child(fr)
	UIFX.banner_shimmer(fr, 4.0)
	_seal_fx = TextureRect.new()
	_seal_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_seal_fx.stretch_mode = TextureRect.STRETCH_SCALE
	_seal_fx.size = Vector2(150, 150)
	_seal_fx.position = Vector2(363, 160) * s - _seal_fx.size * 0.5
	_seal_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal_fx.modulate = Color(1, 1, 1, 0)
	_dual.add_child(_seal_fx)
	var leader = GameState.get_leader()
	if leader:
		_leader_portrait.texture = UnitArt.portrait(leader, 220)
	return _dual

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
	var _g := str(c.gender)
	var _age := int(c.age)
	var _geno := "v84_geno_mid_%s_house" % _g
	if _age <= 22:
		_geno = "v84_geno_youth_%s_vow" % _g
	elif _age >= 50:
		_geno = "v84_geno_elder_%s_seal" % _g
	var _gp := "res://assets/art/portraits/%s.png" % _geno
	# own face first (per-tag farm faces); v84 geno plate only as fallback
	var own = UnitArt.portrait(c, 220)
	if own != null:
		_portrait.texture = own
	elif ResourceLoader.exists(_gp):
		_portrait.texture = load(_gp)
	UIFX.focus_ring(_portrait)
	UIFX.select_pulse(_portrait)
	var check = Lineage.can_propose(GameState.get_leader(), c)
	_detail.text = UIKit.char_card_text(c) + "\n\n门槛：%s\n%s" % [check.get("need", ""), check.get("msg", "")]
	var leader = GameState.get_leader()
	var exp = Lineage.heir_expectation(leader, c)
	var lines: Array = ["[b]子嗣期望（订婚前）[/b]"]
	lines.append("血胤混合预览：")
	for k in exp.blood_mix.keys():
		var bl = GameState.get_bloodline(k)
		lines.append("  %s %d%%" % [bl.get("name", k), int(round(float(exp.blood_mix[k]) * 100))])
	lines.append("六维资质区间：")
	for sk in CKCharacter.STAT_KEYS:
		lines.append("  %s %d–%d" % [Locale.t("stat_" + sk), exp.apt_min[sk], exp.apt_max[sk]])
	lines.append("禀性概率（前几）：")
	for tp in exp.trait_probs.slice(0, mini(5, exp.trait_probs.size())):
		lines.append("  %s %.0f%%" % [tp.name, tp.prob * 100])
	lines.append("容貌·发色：")
	for ap in exp.appearance_probs.get("hair", []).slice(0, 3):
		lines.append("  %s %.0f%%" % [ap.name, ap.prob * 100])
	lines.append("预估子代勋位：%s" % CKCharacter.RANK_NAMES.get(exp.rank_hint, exp.rank_hint))
	_expect.text = "\n".join(lines)

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
			_vow_body.text = "[b]誓约·第一步 · 宣读子嗣期望[/b]\n\n厅上众人静听。\n%s 与 %s 将共旗同席。\n请确认右侧子嗣期望无误，再向前一步。" % [a, b]
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
			_vow_body.text = "[b]誓约·第四步 · 定聘落成[/b]\n\n聘礼 40 银将入库。家训与嫁妆写入族谱旁注。\n妊娠将在岁月中推进；陆桥会传『灰旗有家，可托孤』。"
			_vow_btn("落成婚约", func(): _finish_marry())
			_vow_btn("取消", func(): _vow_panel.visible = false)

func _vow_btn(text: String, cb: Callable) -> void:
	var b = UIKit.make_accent_button(text, 200)
	b.pressed.connect(cb)
	_vow_actions.add_child(b)

func _finish_marry() -> void:
	if _selected == null:
		return
	var r = Lineage.marry(GameState.get_leader(), _selected, 40)
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
		if _dual: UIFX.select_pulse(_dual)
		_refresh()

func _back() -> void:
	if str(GameState.chapter0_beat) in ["0.4", "0.45", "0.5"] and not GameState.flag("chapter0_done"):
		get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
