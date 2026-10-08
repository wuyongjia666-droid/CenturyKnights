extends Control

var _list: VBoxContainer
var _detail: RichTextLabel
var _portrait: TextureRect
var _trait_row: HBoxContainer
var _perm_box: BoxContainer
var _card_name: Label
var _card_sub: Label
var _card_blood: Label
var _blood_box: VBoxContainer
var _card_root: Control
var _link_fx: TextureRect
const CARD_W := 232.0
const CARD_FRAME := "res://assets/art/ui/v85/lineage_card_frame.png"

func _ready() -> void:
	_build()
	_refresh()

func _build() -> void:
	UIKit.make_themed_bg(self, "lineage")
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

	var strip = TextureRect.new()
	if not UIKit.RETIRE_CHROME and ResourceLoader.exists("res://assets/art/ui/lineage_banner.png"):
		strip.texture = load("res://assets/art/ui/lineage_banner.png")
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.position = Vector2(0, 0)
		strip.size = Vector2(1280, 56)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)
		UIFX.banner_shimmer(strip, 3.8)
	var t = UIKit.make_label("族谱 · 血胤", true)
	t.position = Vector2(40, 16)
	add_child(t)
	UIFX.breathe(t, 0.008, 3.4)
	UIFX.stagger_children(self, 0.03, 0.22)
	var tip = UIKit.make_dim_label("血胤混合条不是装饰——是两条河在旗下交汇。托孤之约后，族谱即同盟凭证；子嗣成年可授旗。联姻月结 / 血胤月泽计入岁月沙漏。")
	tip.position = Vector2(40, 56)
	add_child(tip)
	var mrow := HBoxContainer.new()
	mrow.position = Vector2(900, 50)
	mrow.add_theme_constant_override("separation", 6)
	add_child(mrow)
	for ck in ["marriage", "blood", "morale"]:
		var cp = "res://assets/art/ui/month_chip_%s.png" % ck
		if ResourceLoader.exists(cp):
			var tr := TextureRect.new()
			tr.texture = load(cp)
			tr.custom_minimum_size = Vector2(32, 32)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mrow.add_child(tr)

	var list_panel = UIKit.make_panel()
	list_panel.position = Vector2(40, 90)
	list_panel.custom_minimum_size = Vector2(420, 500)
	add_child(list_panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	list_panel.add_child(_list)

	var detail_panel = UIKit.make_panel()
	detail_panel.position = Vector2(480, 90)
	detail_panel.custom_minimum_size = Vector2(760, 500)
	add_child(detail_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	detail_panel.add_child(hb)
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	hb.add_child(left_col)
	left_col.add_child(_build_card())
	_trait_row = HBoxContainer.new()
	_trait_row.add_theme_constant_override("separation", 4)
	left_col.add_child(_trait_row)
	var blood_title = UIKit.make_label("血胤混合", true)
	blood_title.add_theme_font_size_override("font_size", 13)
	left_col.add_child(blood_title)
	_blood_box = VBoxContainer.new()
	_blood_box.add_theme_constant_override("separation", 3)
	left_col.add_child(_blood_box)
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 6)
	hb.add_child(right_col)
	var perm_row := HBoxContainer.new()
	perm_row.add_theme_constant_override("separation", 10)
	right_col.add_child(perm_row)
	var perm_title = UIKit.make_label("永久权重", true)
	perm_title.add_theme_font_size_override("font_size", 14)
	perm_row.add_child(perm_title)
	_perm_box = HBoxContainer.new()
	_perm_box.add_theme_constant_override("separation", 10)
	perm_row.add_child(_perm_box)
	_detail = RichTextLabel.new()
	_detail.custom_minimum_size = Vector2(470, 440)
	_detail.bbcode_enabled = true
	_detail.scroll_active = true
	_detail.add_theme_color_override("default_color", UIKit.TEXT)
	right_col.add_child(_detail)

	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.position = Vector2(40, 640)
	back.pressed.connect(func():
		if str(GameState.chapter0_beat) in ["0.5", "0.55"]:
			get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
	)
	add_child(back)
	var rite = UIKit.make_accent_button("授旗礼", 120)
	rite.position = Vector2(180, 640)
	rite.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/lineage_rite.tscn"))
	add_child(rite)

func _build_card() -> Control:
	## v8.5 lineage card: v840 lineage_card plate (prepped: portrait window cut, info area dark-glass)
	var s := CARD_W / 349.0
	_card_root = Control.new()
	_card_root.custom_minimum_size = Vector2(349, 439) * s
	_card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clip := Control.new()
	clip.position = Vector2(16, 40) * s
	clip.size = Vector2(320, 196) * s
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_root.add_child(clip)
	var bgc := ColorRect.new()
	bgc.color = UIKit.BG
	bgc.size = clip.size
	bgc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(bgc)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# square bust in a landscape window: full width, top-biased crop (keep the face)
	_portrait.position = Vector2(0, -clip.size.x * 0.12)
	_portrait.size = Vector2(clip.size.x, clip.size.x)
	_portrait.pivot_offset = _portrait.size * 0.5
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_portrait)
	var frame := TextureRect.new()
	if ResourceLoader.exists(CARD_FRAME):
		frame.texture = load(CARD_FRAME)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.size = _card_root.custom_minimum_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_root.add_child(frame)
	var info := VBoxContainer.new()
	info.position = Vector2(30, 248) * s
	info.size = Vector2(290, 170) * s
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_root.add_child(info)
	_card_name = UIKit.make_label("", true)
	_card_name.add_theme_font_size_override("font_size", 18)
	info.add_child(_card_name)
	_card_sub = UIKit.make_dim_label("")
	_card_sub.add_theme_font_size_override("font_size", 12)
	info.add_child(_card_sub)
	_card_blood = UIKit.make_label("")
	_card_blood.add_theme_font_size_override("font_size", 12)
	_card_blood.add_theme_color_override("font_color", UIKit.ACCENT)
	info.add_child(_card_blood)
	_trait_row = HBoxContainer.new()
	_trait_row.add_theme_constant_override("separation", 4)
	info.add_child(_trait_row)
	# lineage_link FX overlay (authored, 256x64, 8 frames) — plays across the card on select
	_link_fx = TextureRect.new()
	_link_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_link_fx.stretch_mode = TextureRect.STRETCH_SCALE
	_link_fx.position = Vector2(0, 222) * s
	_link_fx.size = Vector2(349, 87) * s
	_link_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_link_fx.modulate = Color(1, 1, 1, 0)
	_card_root.add_child(_link_fx)
	return _card_root

func _play_link_fx() -> void:
	if _link_fx == null:
		return
	var frames: Array = []
	for i in range(8):
		var fp = "res://assets/art/fx/lineage_link_%d.png" % i
		if ResourceLoader.exists(fp):
			frames.append(load(fp))
	if frames.is_empty():
		return
	_link_fx.texture = frames[0]
	_link_fx.modulate = Color(1, 1, 1, 1)
	for i in range(1, frames.size()):
		var fi = i
		get_tree().create_timer(0.06 * fi).timeout.connect(func():
			if is_instance_valid(_link_fx): _link_fx.texture = frames[fi])
	var tw = _link_fx.create_tween()
	tw.tween_interval(0.06 * frames.size())
	tw.tween_property(_link_fx, "modulate:a", 0.0, 0.35)

func _blood_bar(label: String, pct: float, col: Color) -> Control:
	## v840 bloodline_strip plate -> tintable TextureProgressBar (prep: clean gradient fill + capped frame)
	var w := CARD_W
	var h := w * 48.0 / 640.0
	var root := Control.new()
	root.custom_minimum_size = Vector2(w, h + 14)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab := UIKit.make_dim_label("%s　%d%%" % [label, int(round(pct * 100))])
	lab.add_theme_font_size_override("font_size", 11)
	lab.position = Vector2(2, 0)
	root.add_child(lab)
	var sx := w / 640.0
	var bar := TextureProgressBar.new()
	bar.texture_under = load("res://assets/art/ui/v85/bloodline_under.png")
	bar.texture_progress = load("res://assets/art/ui/v85/bloodline_fill.png")
	bar.nine_patch_stretch = true
	bar.tint_progress = col
	bar.position = Vector2(21 * sx, 14 + 9 * sx)
	bar.size = Vector2(598 * sx, 36 * sx)
	bar.max_value = 100
	bar.value = 0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var fr := TextureRect.new()
	fr.texture = load("res://assets/art/ui/v85/bloodline_frame.png")
	fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fr.stretch_mode = TextureRect.STRETCH_SCALE
	fr.position = Vector2(0, 14)
	fr.size = Vector2(w, h)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fr)
	bar.create_tween().tween_property(bar, "value", pct * 100.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return root

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var shown := false
	for ch in GameState.characters.values():
		if not ch.alive:
			continue
		var tag = ""
		if ch.is_leader:
			tag = "〔团长〕"
		elif ch.is_child:
			tag = "〔子嗣〕"
		elif ch.spouse_id != "":
			tag = "〔联姻〕"
		var b = UIKit.make_button("%s%s %d岁" % [ch.name, tag, ch.age], 380)
		var captured = ch
		b.pressed.connect(func():
			UIFX.focus_ring(b)
			UIFX.press_feedback(b)
			_show(captured)
			_play_link_fx()
			if _card_root: UIFX.select_pulse(_card_root)
		)
		_list.add_child(b)
		if not shown:
			_show(ch)
			shown = true
	if not shown:
		_list.add_child(UIKit.empty_state("族谱尚无在世之人。"))

func _show(c: CKCharacter) -> void:
	var pt = UnitArt.portrait(c, 220)
	_portrait.texture = pt if pt != null else UnitArt.portrait(c, 128)
	var tag = "团长" if c.is_leader else ("子嗣" if c.is_child else ("联姻" if c.spouse_id != "" else "旗下"))
	if _card_name: _card_name.text = str(c.name)
	if _card_sub: _card_sub.text = "%s · %d岁 · %s" % [tag, int(c.age), str(c.job_id)]
	var top_k := ""
	var top_v := -1.0
	for bk in c.blood_mix.keys():
		if float(c.blood_mix[bk]) > top_v:
			top_v = float(c.blood_mix[bk])
			top_k = str(bk)
	if _card_blood:
		_card_blood.text = ("主血胤：%s %d%%" % [GameState.get_bloodline(top_k).get("name", top_k), int(round(top_v * 100))]) if top_k != "" else "主血胤：—"
	if _blood_box:
		for ch in _blood_box.get_children():
			ch.queue_free()
		for bk in c.blood_mix.keys():
			var bl = GameState.get_bloodline(bk)
			var bc := Color(str(bl.get("color", "#8ecae6"))) if bl.has("color") else UIKit.ACCENT
			_blood_box.add_child(_blood_bar(str(bl.get("name", bk)), float(c.blood_mix[bk]), bc.lightened(0.15)))
	if _trait_row:
		for ch in _trait_row.get_children():
			ch.queue_free()
		for tr in c.traits:
			var icon = UIKit.trait_icon_rect(str(tr), 24.0)
			var td = GameState.get_trait(str(tr))
			icon.tooltip_text = str(td.get("name", tr)) + " — " + str(td.get("desc", td.get("name", tr)))
			_trait_row.add_child(icon)
	if _perm_box:
		for ch in _perm_box.get_children():
			ch.queue_free()
		var weights: Array = []
		if c.is_leader:
			weights.append(["heir_mark", "团长轴心"])
		if c.spouse_id != "":
			weights.append(["loyal", "联姻月结"])
		if c.is_child:
			weights.append(["diligent", "子嗣口粮"])
		for bk in c.blood_mix.keys():
			if float(c.blood_mix[bk]) >= 0.45:
				weights.append(["lucky", "血胤月泽"])
				break
		if weights.is_empty():
			_perm_box.add_child(UIKit.make_dim_label("（暂无）"))
		else:
			for w in weights:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 4)
				row.add_child(UIKit.trait_icon_rect(str(w[0]), 24.0))
				row.add_child(UIKit.make_dim_label(str(w[1])))
				_perm_box.add_child(row)
	var lines: Array = [UIKit.char_card_text(c), ""]
	var bparts: Array = []
	for k in c.blood_mix.keys():
		var bl = GameState.get_bloodline(k)
		var col = str(bl.get("color", "#8ecae6")) if bl.has("color") else "#8ecae6"
		bparts.append("[color=%s]%s %d%%[/color]" % [col, bl.get("name", k), int(round(float(c.blood_mix[k]) * 100))])
	lines.append("[b]血胤[/b]　" + "　".join(bparts))
	lines.append("")
	lines.append("资质上下限：")
	for sk in CKCharacter.STAT_KEYS:
		lines.append("  %s 当前%d　限%d–%d" % [Locale.t("stat_" + sk), c.stats[sk], c.apt_min.get(sk, 0), c.apt_max.get(sk, 0)])
	var app = GameState.data_appearance.get("alleles", {})
	lines.append("容貌：")
	for key in ["hair", "eyes", "brow", "scar"]:
		var id = c.appearance.get(key, "")
		var nm = id
		for al in app.get(key, []):
			if al.id == id:
				nm = al.get("name", id)
		lines.append("  %s：%s" % [{"hair": "发", "eyes": "瞳", "brow": "眉", "scar": "疤"}[key], nm])
	if c.parent_ids.size() > 0:
		lines.append("双亲：" + str(c.parent_ids))
	if c.is_child and c.age >= Calendar.ADULT_AGE:
		lines.append("\n[color=#c9a227]可授旗入队[/color]")
		var r = Lineage.enlist_adult(c)
		lines.append(str(r.get("msg", "")))
		lines.append("")
	lines.append("[b]永久影响（族谱权重）[/b]")
	var perm: Array = []
	if c.is_leader:
		perm.append("团长：月结与堡志以你为轴")
	if c.spouse_id != "":
		perm.append("联姻在世：每月士气/银微收益（血胤月泽）")
	if c.is_child:
		perm.append("子嗣：口粮计入月结；成年授旗可入花名册")
	for tr in c.traits:
		var td = GameState.get_trait(tr) if GameState.has_method("get_trait") else {}
		var tn = str(td.get("name", tr)) if td else str(tr)
		var pol = str(td.get("polarity", "")) if td else ""
		var col = "#7dce7a" if pol == "pos" else ("#e07070" if pol == "neg" else "#c9a227")
		perm.append("禀性 [color=%s]%s[/color] 影响成长与战场检定" % [col, tn])
	if perm.is_empty():
		perm.append("（尚无额外永久条目）")
	for p in perm:
		lines.append("· " + p)
	lines.append("")
	lines.append("[color=#8a8090]族谱不是装饰——血胤浓度驱动「血胤月泽」月结。[/color]")
	_detail.text = "\n".join(lines)
	_append_lineage_log_to(_detail)


func _append_lineage_log_to(rtl: RichTextLabel) -> void:
	if rtl == null:
		return
	rtl.text += "\n\n[color=#c9a227]族谱纪事[/color]\n"
	var logs = GameState.lineage_log
	if logs.is_empty():
		rtl.text += "（尚无纪事——联姻、春令廷议、授旗礼会写入此处）\n"
		return
	for i in range(maxi(0, logs.size() - 12), logs.size()):
		var e = logs[i]
		rtl.text += "· [%s] %s\n" % [e.get("t", ""), e.get("text", "")]
