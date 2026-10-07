extends Control
## 族谱授旗礼：选成年子嗣 → 对话步骤 → 授旗入队

var _list: VBoxContainer
var _body: RichTextLabel
var _actions: VBoxContainer
var _selected: CKCharacter
var _step: int = 0
var _msg: Label

func _ready() -> void:
	UIKit.make_screen_bg(self)
	UIFX.fade_in(self, 0.3)
	Music.play_hub()
	var t = UIKit.make_label("族谱 · 授旗礼", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var tip = UIKit.make_dim_label("成年子嗣可在此走完三步授旗：宣名、按印、入花名册。")
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
	_body.custom_minimum_size = Vector2(780, 280)
	_body.add_theme_color_override("default_color", UIKit.TEXT)
	right.add_child(_body)
	_actions = VBoxContainer.new()
	_actions.position = Vector2(16, 300)
	_actions.add_theme_constant_override("separation", 8)
	right.add_child(_actions)

	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 540)
	add_child(_msg)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.position = Vector2(40, 640)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn"))
	add_child(back)
	var mar = UIKit.make_button("回联姻廷", 120)
	mar.position = Vector2(180, 640)
	mar.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/marriage.tscn"))
	add_child(mar)
	var lin = UIKit.make_button("回族谱", 120)
	lin.position = Vector2(320, 640)
	lin.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/lineage_view.tscn"))
	add_child(lin)
	_refresh_list()

func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var any := false
	for ch in GameState.characters.values():
		if not ch.alive or not ch.is_child:
			continue
		var ready = ch.age >= Calendar.ADULT_AGE and not ch.in_roster
		var tag = "可授旗" if ready else ("已入队" if ch.in_roster else "%d岁" % ch.age)
		var b = UIKit.make_button("%s　%s" % [ch.name, tag], 320)
		b.disabled = not ready
		var captured = ch
		b.pressed.connect(func(): _select(captured))
		_list.add_child(b)
		any = true
	if not any:
		_list.add_child(UIKit.empty_state("尚无子嗣。联姻后岁月推进可诞育。"))
	_body.text = "点选左侧成年且未入队的子嗣，开始授旗礼。"
	for c in _actions.get_children():
		c.queue_free()

func _select(c: CKCharacter) -> void:
	_selected = c
	_step = 0
	_show_step()

func _show_step() -> void:
	for c in _actions.get_children():
		c.queue_free()
	if _selected == null:
		return
	match _step:
		0:
			_body.text = "[b]授旗·宣名[/b]\n\n族谱吏高声：\n「%s，血胤已录，年满可授。」\n厅上众人看向混合条与禀性。" % _selected.name
			_add("宣名完毕", func(): _step = 1; _show_step())
		1:
			_body.text = "[b]授旗·按印[/b]\n\n团长按灰旗印于册。\n「旗下不弃家，家不弃旗。」\n%s 握旗杆，指节发白。" % _selected.name
			_add("按印入册", func(): _step = 2; _show_step())
		2:
			_body.text = "[b]授旗·入花名册[/b]\n\n确认后将调用授旗入队。\n战技点 +1，族谱纪事将写入此礼。"
			_add("完成授旗", func(): _do_enlist())
			_add("取消", func(): _refresh_list())

func _add(text: String, cb: Callable) -> void:
	var b = UIKit.make_accent_button(text, 280)
	b.pressed.connect(cb)
	_actions.add_child(b)

func _do_enlist() -> void:
	if _selected == null:
		return
	var r = Lineage.enlist_adult(_selected)
	_msg.text = str(r.get("msg", ""))
	if r.get("ok"):
		GameState.add_lineage_event("授旗礼：%s 三步入花名册。" % _selected.name)
		GameState.add_skill_point(1)
		GameState.add_rep("ashland", 2)
		Sfx.lineage_chime()
		Sfx.fanfare()
		GameState.save_game()
	_refresh_list()
