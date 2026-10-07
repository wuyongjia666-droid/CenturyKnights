extends Control

var _list: VBoxContainer
var _body: RichTextLabel
var _actions: VBoxContainer
var _msg: Label
var _selected: Dictionary = {}

func _ready() -> void:
	UIKit.make_screen_bg(self)
	UIFX.fade_in(self, 0.3)
	Music.play_hub()
	var t = UIKit.make_label("敌宅交涉", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var tip = UIKit.make_dim_label("朔影家是余波主谋；清河可换情报；灯市会偏商子嗣更易谈拢。")
	tip.position = Vector2(40, 56)
	add_child(tip)
	var left = UIKit.make_panel()
	left.position = Vector2(40, 100)
	left.custom_minimum_size = Vector2(360, 420)
	add_child(left)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	left.add_child(_list)
	var right = UIKit.make_panel()
	right.position = Vector2(420, 100)
	right.custom_minimum_size = Vector2(820, 420)
	add_child(right)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.custom_minimum_size = Vector2(780, 260)
	_body.add_theme_color_override("default_color", UIKit.TEXT)
	right.add_child(_body)
	_actions = VBoxContainer.new()
	_actions.position = Vector2(16, 290)
	_actions.add_theme_constant_override("separation", 8)
	right.add_child(_actions)
	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 540)
	add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.position = Vector2(40, 640)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)
	var inh = UIKit.make_accent_button("嗣位冲突", 140)
	inh.position = Vector2(180, 640)
	inh.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/inheritance.tscn"))
	add_child(inh)
	_refresh()

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for h in GameState.data_rivals.get("houses", []):
		var hid = str(h.get("id"))
		var stance = GameState.get_rival_stance(hid)
		var b = UIKit.make_button("%s　[%s]" % [h.get("name"), _stance_cn(stance)], 320)
		var captured = h
		b.pressed.connect(func(): _select(captured))
		_list.add_child(b)
	if GameState.data_rivals.get("houses", []).size() > 0:
		_select(GameState.data_rivals.get("houses", [])[0])

func _stance_cn(s: String) -> String:
	return {"hostile": "敌对", "wary": "对峙", "neutral": "中立", "cordial": "并席"}.get(s, s)

func _select(h: Dictionary) -> void:
	_selected = h
	for c in _actions.get_children():
		c.queue_free()
	var hid = str(h.get("id"))
	var stance = GameState.get_rival_stance(hid)
	_body.text = "[b]%s[/b]\n立场：%s\n%s\n\n交涉会写入族谱纪事，并可能改变立场。" % [h.get("name"), _stance_cn(stance), h.get("desc", "")]
	var deal = GameState.rival_deals.get(hid, {})
	if int(deal.get("turns_left", 0)) > 0:
		_body.text += "\n\n[color=#c9a227]进行中契约：%s（余%d月）[/color]" % [deal.get("kind"), deal.get("turns_left")]
		_add("改约→商路（+15银）", func(): _renego(hid, "trade"))
		_add("改约→情报（+15银）", func(): _renego(hid, "intel"))
		_add("改约→停战（+15银）", func(): _renego(hid, "truce"))
		_add("毁约（收回部分银，恶化立场）", func(): _breach(hid))
	else:
		_add("立约·商路（25银/3月→银+50）", func(): _deal(hid, "trade"))
		_add("立约·情报（25银/3月→战技点）", func(): _deal(hid, "intel"))
		_add("立约·停战（40银/2月→并席）", func(): _deal(hid, "truce", 2, 40))
	_add("送礼交涉（30银）", func(): _gift(hid))
	_add("示威施压", func(): _pressure(hid))
	if hid == "shuoying" and stance in ["hostile", "wary"]:
		_add("开启嗣位冲突场景", func(): get_tree().change_scene_to_file("res://scenes/hub/inheritance.tscn"))
	_add("双嗣校场", func(): get_tree().change_scene_to_file("res://scenes/hub/heir_rivalry.tscn"))

func _add(text: String, cb: Callable) -> void:
	var b = UIKit.make_accent_button(text, 360)
	b.pressed.connect(cb)
	_actions.add_child(b)

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
