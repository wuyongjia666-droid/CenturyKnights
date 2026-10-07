extends Control

var _list: VBoxContainer
var _detail: RichTextLabel
var _portrait: TextureRect

func _ready() -> void:
	_build()
	_refresh()

func _build() -> void:
	UIKit.make_screen_bg(self)
	var t = UIKit.make_label("族谱 · 血胤", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var tip = UIKit.make_dim_label("血胤混合条不是装饰——是两条河在旗下交汇。托孤之约后，族谱即同盟凭证；子嗣成年可授旗。下方为族谱纪事。")
	tip.position = Vector2(40, 56)
	add_child(tip)

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
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(128, 128)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(_portrait)
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
