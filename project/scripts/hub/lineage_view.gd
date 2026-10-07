extends Control

var _list: VBoxContainer
var _detail: RichTextLabel
var _portrait: TextureRect
var _trait_row: HBoxContainer
var _perm_box: VBoxContainer

func _ready() -> void:
	_build()
	_refresh()

func _build() -> void:
	UIKit.make_themed_bg(self, "lineage")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)
	if ResourceLoader.exists("res://assets/art/ui/hub_banner_strip.png"):
		var strip := TextureRect.new()
		strip.texture = load("res://assets/art/ui/hub_banner_strip.png")
		strip.position = Vector2(0, 0)
		strip.custom_minimum_size = Vector2(1280, 48)
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)

	var strip = TextureRect.new()
	if ResourceLoader.exists("res://assets/art/ui/lineage_banner.png"):
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
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(128, 128)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left_col.add_child(_portrait)
	_trait_row = HBoxContainer.new()
	_trait_row.add_theme_constant_override("separation", 4)
	left_col.add_child(_trait_row)
	var tip_t = UIKit.make_dim_label("禀性图标")
	left_col.add_child(tip_t)
	var perm_title = UIKit.make_label("永久权重", true)
	perm_title.add_theme_font_size_override("font_size", 14)
	left_col.add_child(perm_title)
	_perm_box = VBoxContainer.new()
	_perm_box.add_theme_constant_override("separation", 4)
	_perm_box.custom_minimum_size = Vector2(140, 0)
	left_col.add_child(_perm_box)
	_detail = RichTextLabel.new()
	_detail.custom_minimum_size = Vector2(580, 460)
	_detail.bbcode_enabled = true
	_detail.add_theme_color_override("default_color", UIKit.TEXT)
	hb.add_child(_detail)

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
		b.pressed.connect(func(): _show(captured))
		_list.add_child(b)
		if not shown:
			_show(ch)
			shown = true
	if not shown:
		_list.add_child(UIKit.empty_state("族谱尚无在世之人。"))

func _show(c: CKCharacter) -> void:
	_portrait.texture = UnitArt.portrait(c, 128)
	if _trait_row:
		for ch in _trait_row.get_children():
			ch.queue_free()
		for tr in c.traits:
			var icon = UIKit.trait_icon_rect(str(tr), 32.0)
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
	lines.append("[b]血胤混合条[/b]")
	for k in c.blood_mix.keys():
		var bl = GameState.get_bloodline(k)
		var pct = int(round(float(c.blood_mix[k]) * 100))
		var bar = "█".repeat(maxi(1, int(pct / 5))) + "░".repeat(maxi(0, 20 - int(pct / 5)))
		var col = str(bl.get("color", "#c9a227")) if bl.has("color") else "#c9a227"
		lines.append("%s [color=%s]%s[/color] %d%%" % [bl.get("name", k), col, bar, pct])
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
