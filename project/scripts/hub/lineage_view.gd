extends Control

var _list: VBoxContainer
var _detail: RichTextLabel

func _ready() -> void:
	_build()
	_refresh()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var t = UIKit.make_label("族谱 · 血胤", true)
	t.position = Vector2(40, 20)
	add_child(t)
	_list = VBoxContainer.new()
	_list.position = Vector2(40, 80)
	add_child(_list)
	_detail = RichTextLabel.new()
	_detail.position = Vector2(480, 80)
	_detail.custom_minimum_size = Vector2(740, 500)
	_detail.bbcode_enabled = true
	add_child(_detail)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.position = Vector2(40, 640)
	back.pressed.connect(func():
		if str(GameState.chapter0_beat) == "0.5":
			get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
	)
	add_child(back)

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
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
		var b = UIKit.make_button("%s%s %d岁" % [ch.name, tag, ch.age], 400)
		var captured = ch
		b.pressed.connect(func(): _show(captured))
		_list.add_child(b)
		if ch.is_child:
			var enlist = UIKit.make_button("授旗入队", 120)
			var cid = ch.id
			enlist.pressed.connect(func():
				var r = Lineage.enlist_adult(GameState.characters[cid])
				_detail.text = str(r.get("msg"))
			)
			# show near - skip for layout simplicity; button in detail

func _show(c: CKCharacter) -> void:
	var lines: Array = [UIKit.char_card_text(c), ""]
	lines.append("[b]血胤混合条（X2）[/b]")
	for k in c.blood_mix.keys():
		var bl = GameState.get_bloodline(k)
		var pct = int(round(float(c.blood_mix[k]) * 100))
		var bar = "█".repeat(maxi(1, int(pct / 5))) + "░".repeat(maxi(0, 20 - int(pct / 5)))
		lines.append("%s %s %d%%" % [bl.get("name", k), bar, pct])
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
		lines.append("  %s：%s" % [key, nm])
	if c.parent_ids.size() > 0:
		lines.append("双亲：" + str(c.parent_ids))
	if c.is_child and c.age >= Calendar.ADULT_AGE:
		lines.append("\n可授旗入队")
		# auto offer
	_detail.text = "\n".join(lines)
