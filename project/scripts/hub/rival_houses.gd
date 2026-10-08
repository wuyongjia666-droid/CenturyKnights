extends Control

var _list: VBoxContainer
var _body: RichTextLabel
var _actions: VBoxContainer
var _msg: Label
var _left: Control
var _right: Control
var _back: Button
var _inh: Button
var _selected: Dictionary = {}

func _ready() -> void:
	UIKit.make_themed_bg(self, "rival")
	if not UIKit.RETIRE_CHROME and ResourceLoader.exists("res://assets/art/ui/rival_banner.png"):
		var _bn := TextureRect.new()
		_bn.texture = load("res://assets/art/ui/rival_banner.png")
		_bn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bn.stretch_mode = TextureRect.STRETCH_SCALE
		_bn.position = Vector2(0, 0)
		_bn.size = Vector2(1280, 52)
		_bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bn)
		UIFX.banner_shimmer(_bn, 3.8)
	if not UIKit.RETIRE_CHROME and ResourceLoader.exists("res://assets/art/ui/hub_banner_strip.png"):
		var strip := TextureRect.new()
		strip.texture = load("res://assets/art/ui/hub_banner_strip.png")
		strip.position = Vector2(0, 0)
		strip.custom_minimum_size = Vector2(1280, 48)
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)

	UIFX.page_enter(self)
	UIFX.fade_in(self, 0.3)
	Music.play_hub()
	var t = UIKit.make_label("敌宅交涉", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var tip = UIKit.make_dim_label("十国各有一家。图谋写在朝堂年历上，使馆可以反制。")
	tip.position = Vector2(40, 56)
	add_child(tip)
	var left = _frost_panel()
	left.name = "RivalList"
	left.position = Vector2(40, 100)
	left.size = Vector2(360, 500)
	add_child(left)
	_left = left
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 12)
	scroll.size = Vector2(336, 476)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(320, 0)
	scroll.add_child(_list)
	var right = _frost_panel()
	right.name = "RivalDetail"
	right.position = Vector2(420, 100)
	right.size = Vector2(820, 500)
	right.z_index = 2
	add_child(right)
	_right = right
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	right.add_child(detail)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(0, 96)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("default_color", UIKit.TEXT)
	detail.add_child(_body)
	_actions = VBoxContainer.new()
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_theme_constant_override("separation", 8)
	detail.add_child(_actions)
	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 540)
	add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.name = "RivalBack"
	back.position = Vector2(40, 640)
	_back = back
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)
	var inh = UIKit.make_accent_button("嗣位冲突", 140)
	inh.name = "RivalInherit"
	inh.position = Vector2(180, 640)
	_inh = inh
	inh.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/inheritance.tscn"))
	add_child(inh)
	_refresh()
	UIFX.stagger_children(_list, 0.05, 0.22)
	UIFX.wire_tree(self)
	apply_mobile_layout()

func _frost_panel() -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.clip_contents = true
	var sb := UIKit.glass(12, 0.98, true)
	sb.shadow_size = 8
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	var mask := ColorRect.new()
	mask.name = "FrostMask"
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	mask.color = Color(UIKit.BG, 0.82)
	var shader_path := "res://shaders/frost_mask.gdshader"
	if ResourceLoader.exists(shader_path):
		var mat := ShaderMaterial.new()
		mat.shader = load(shader_path)
		mask.material = mat
	p.add_child(mask)
	var fill := ColorRect.new()
	fill.name = "FrostFill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = Color(UIKit.PANEL, 0.96)
	p.add_child(fill)
	return p

func _sync_frost(p: Control) -> void:
	if p == null:
		return
	for nm in ["FrostMask", "FrostFill"]:
		var c := p.get_node_or_null(nm) as Control
		if c == null:
			continue
		c.position = Vector2.ZERO
		c.size = p.size

func apply_mobile_layout() -> void:
	if _left == null or _right == null:
		return
	var vp := get_viewport_rect().size
	var wide := vp.x >= 1100.0 and vp.y >= 680.0
	if wide:
		_left.position = Vector2(40, 100)
		_left.size = Vector2(360, 500)
		_right.position = Vector2(420, 100)
		_right.size = Vector2(820, 500)
		if _back:
			_back.position = Vector2(40, 640)
		if _inh:
			_inh.position = Vector2(180, 640)
		_msg.position = Vector2(40, 612)
		_msg.size = Vector2(780, 22)
	else:
		var margin := 12.0
		var list_h := 132.0
		_left.position = Vector2(margin, 88)
		_left.size = Vector2(vp.x - margin * 2.0, list_h)
		var btn_y := vp.y - 52.0
		_right.position = Vector2(margin, 88.0 + list_h + 8.0)
		_right.size = Vector2(_left.size.x, maxf(96.0, btn_y - 8.0 - _right.position.y))
		if _back:
			_back.position = Vector2(margin, btn_y)
		if _inh:
			_inh.position = Vector2(margin + 132.0, btn_y)
		_msg.position = Vector2(margin, btn_y - 22.0)
		_msg.size = Vector2(maxf(80.0, vp.x - margin * 2.0), 20)
		_msg.clip_text = true
	_place_inner(_left, 12.0)
	_place_inner(_right, 12.0)
	_sync_frost(_left)
	_sync_frost(_right)

func _place_inner(panel: Control, pad: float) -> void:
	var inner := Vector2(maxf(40.0, panel.size.x - pad * 2.0), maxf(40.0, panel.size.y - pad * 2.0))
	for ch in panel.get_children():
		if str(ch.name) == "FrostMask" or str(ch.name) == "FrostFill":
			continue
		if ch is Control:
			(ch as Control).position = Vector2(pad, pad)
			(ch as Control).size = inner

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for h in GameState.data_rivals.get("houses", []):
		var hid = str(h.get("id"))
		var stance = GameState.get_rival_stance(hid)
		var b = UIKit.make_button("%s　[%s]" % [h.get("name"), _stance_cn(stance)], 300)
		var captured = h
		b.pressed.connect(func(): _select(captured))
		_list.add_child(b)
	if GameState.data_rivals.get("houses", []).size() > 0:
		_select(GameState.data_rivals.get("houses", [])[0])

func _stance_cn(s: String) -> String:
	return CKSchemes.band_zh(s)

func _select(h: Dictionary) -> void:
	_selected = h
	for c in _actions.get_children():
		c.queue_free()
	var hid = str(h.get("id"))
	var stance = GameState.get_rival_stance(hid)
	var court := _court_house(hid)
	var rel := int(court.get("relation", CKSchemes.opening_relation(hid))) if not court.is_empty() else CKSchemes.opening_relation(hid)
	var band := str(court.get("relation_band", "")) if court.has("relation_band") else CKSchemes.band_of(rel)
	var last := CKSchemes.latest(court)
	var scheme_line := str(last.get("text", "今年还没有新的图谋。"))
	_body.text = "[b]%s[/b]\n家风：%s\n关系：%s（%d）\n%s\n\n最近图谋：%s\n\n交涉会写入族谱纪事，并可能改变立场。" % [h.get("name"), h.get("creed", ""), _stance_cn(band if band != "" else stance), rel, h.get("desc", ""), scheme_line]
	var deal = GameState.rival_deals.get(hid, {})
	if int(deal.get("turns_left", 0)) > 0:
		var mid = str(deal.get("last_event", ""))
		var mid_n = int(deal.get("mid_ticks", 0))
		var accent := UIKit.ACCENT.to_html(false)
		var dim := UIKit.TEXT_DIM.to_html(false)
		_body.text += "\n\n[color=#%s]进行中契约：%s（余%d月 · 已过%d月中检）[/color]" % [accent, deal.get("kind"), deal.get("turns_left"), mid_n]
		if mid != "":
			_body.text += "\n[color=#%s]最近月中：%s[/color]" % [dim, mid]
		elif GameState.last_deal_events.size() > 0:
			_body.text += "\n[color=#%s]最近月中纪事：%s[/color]" % [dim, str(GameState.last_deal_events[0])]
		_add("推进一月（看契约中期）", func(): _tick_month(hid))
		_add("改约→商路（+15银）", func(): _renego(hid, "trade"))
		_add("改约→情报（+15银）", func(): _renego(hid, "intel"))
		_add("改约→停战（+15银）", func(): _renego(hid, "truce"))
		_add("毁约（收回部分银，恶化立场）", func(): _breach(hid))
	else:
		_add("立约·商路（25银/3月→银+50）", func(): _deal(hid, "trade"))
		_add("立约·情报（25银/3月→战技点）", func(): _deal(hid, "intel"))
		_add("立约·停战（40银/2月→并席）", func(): _deal(hid, "truce", 2, 40))
	_add("使馆反制最近图谋", func(): _counter(hid))
	_add("送礼交涉（30银）", func(): _gift(hid))
	_add("示威施压", func(): _pressure(hid))
	if hid == "shuoying" and stance in ["hostile", "wary"]:
		_add("开启嗣位冲突场景", func(): get_tree().change_scene_to_file("res://scenes/hub/inheritance.tscn"))
	_add("双嗣校场", func(): get_tree().change_scene_to_file("res://scenes/hub/heir_rivalry.tscn"))

func _add(text: String, cb: Callable) -> void:
	var b = UIKit.make_accent_button(text, 360)
	b.pressed.connect(cb)
	_actions.add_child(b)

func _court_house(hid: String) -> Dictionary:
	if typeof(World.royal_courts) != TYPE_DICTIONARY:
		return {}
	var nations: Dictionary = World.royal_courts.get("nations", {})
	var row = nations.get(hid, {})
	return row if typeof(row) == TYPE_DICTIONARY else {}

func _counter(hid: String) -> void:
	var court := _court_house(hid)
	var last := CKSchemes.latest(court)
	if last.is_empty() or bool(last.get("foiled", false)):
		_msg.text = "这家今年没有可反制的图谋。"
		return
	var built := GameState.buildings.has("embassy") and int(GameState.buildings.get("embassy", 0)) >= 1
	if not built:
		_msg.text = "使馆还没建。反制接口已留给使馆，建好之后才能挡下图谋。"
		return
	CKSchemes.apply_counter(court, last)
	var nations: Dictionary = World.royal_courts.get("nations", {})
	nations[hid] = court
	World.royal_courts["nations"] = nations
	GameState.add_lineage_event("使馆反制：%s" % hid)
	_msg.text = "使馆挡下了%s的%s。" % [str(_selected.get("name", hid)), str(last.get("kind_zh", ""))]
	Sfx.confirm()
	GameState.save_game()
	_refresh()

func _gift(hid: String) -> void:
	if GameState.silver < 30:
		_msg.text = "银两不足"
		return
	GameState.silver -= 30
	var cur = GameState.get_rival_stance(hid)
	var nxt = {"hostile": "wary", "wary": "neutral", "neutral": "cordial", "cordial": "cordial"}.get(cur, "neutral")
	GameState.set_rival_stance(hid, nxt)
	GameState.add_lineage_event("敌宅送礼：%s → %s" % [hid, nxt])
	_msg.text = "送礼成功，立场变为「%s」" % _stance_cn(nxt)
	Sfx.confirm()
	GameState.save_game()
	_refresh()

func _renego(hid: String, kind: String) -> void:
	var r = GameState.renegotiate_rival_deal(hid, kind, 15)
	_msg.text = str(r.get("msg"))
	if r.get("ok"):
		Sfx.confirm(); GameState.save_game(); _refresh()

func _breach(hid: String) -> void:
	var r = GameState.breach_rival_deal(hid)
	_msg.text = str(r.get("msg"))
	if r.get("ok"):
		Sfx.confirm(); GameState.save_game(); _refresh()

func _deal(hid: String, kind: String, turns: int = 3, price: int = 25) -> void:
	Sfx.deal()
	var r = GameState.start_rival_deal(hid, kind, turns, price)
	_msg.text = str(r.get("msg"))
	if r.get("ok"):
		Sfx.confirm()
		GameState.save_game()
		_refresh()

func _pressure(hid: String) -> void:
	GameState.add_rep("ashland", 1)
	if hid == "shuoying" and GameState.get_rival_stance(hid) == "hostile":
		_msg.text = "示威让朔影家更警惕，但灰旗声望微升。建议用战役或嗣位冲突解决。"
	else:
		var cur = GameState.get_rival_stance(hid)
		if cur == "cordial":
			_msg.text = "已并席，不宜再压。"
		else:
			_msg.text = "示威记录在案。战场胜利更能改写立场。"
	GameState.add_lineage_event("敌宅示威：%s" % hid)
	Sfx.confirm()
	_select(_selected)

func _tick_month(hid: String) -> void:
	var evs = Calendar.advance(1)
	var deal_lines: Array = []
	for e in evs:
		var tx = str(e.get("text", ""))
		if tx.find("契约") >= 0 or tx.find(hid) >= 0:
			deal_lines.append(tx)
	if deal_lines.is_empty() and GameState.last_deal_events.size() > 0:
		deal_lines = GameState.last_deal_events.duplicate()
	if deal_lines.is_empty():
		_msg.text = "推进一月。本月无契约中期事件（或契约已到期）。"
	else:
		_msg.text = "月中：\n" + "\n".join(deal_lines)
		Sfx.deal()
	GameState.save_game()
	_refresh()
	# reselect house
	for h in GameState.data_rivals.get("houses", []):
		if str(h.get("id")) == hid:
			_select(h)
			break
