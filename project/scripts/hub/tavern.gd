extends Control

var _list: VBoxContainer
var _detail: RichTextLabel
var _selected: CKCharacter
var _msg: Label
var _portrait: TextureRect

func _ready() -> void:
	_build()
	_refresh()

func _build() -> void:
	UIKit.make_screen_bg(self)
	var t = UIKit.make_label("烽火酒馆", true)
	t.position = Vector2(40, 16)
	add_child(t)
	var flavor = UIKit.make_dim_label("门轴会叫。柜上挂着脸与数——六维、血胤、禀性。看走眼，月饷会教你做人。")
	flavor.position = Vector2(40, 56)
	add_child(flavor)

	var panel = UIKit.make_panel()
	panel.position = Vector2(40, 90)
	panel.custom_minimum_size = Vector2(460, 420)
	add_child(panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	panel.add_child(_list)

	var detail_panel = UIKit.make_panel()
	detail_panel.position = Vector2(520, 90)
	detail_panel.custom_minimum_size = Vector2(720, 420)
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
	_detail.custom_minimum_size = Vector2(540, 360)
	_detail.bbcode_enabled = true
	_detail.add_theme_color_override("default_color", UIKit.TEXT)
	hb.add_child(_detail)

	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 540)
	add_child(_msg)
	var row := HBoxContainer.new()
	row.position = Vector2(40, 600)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var refresh = UIKit.make_button("刷新候选（教程免费）", 240)
	refresh.pressed.connect(func():
		GameState.refresh_tavern()
		_refresh()
	)
	row.add_child(refresh)
	var hire = UIKit.make_accent_button(Locale.t("recruit"), 140)
	hire.pressed.connect(_hire)
	row.add_child(hire)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.pressed.connect(_back)
	row.add_child(back)

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if GameState.tavern_candidates.is_empty():
		_list.add_child(UIKit.empty_state("今夜柜上无人。点刷新再碰运气。"))
		_detail.text = ""
		_portrait.texture = UnitArt.banner(128, 128, false)
		return
	for cand in GameState.tavern_candidates:
		var b = UIKit.make_button("%s　%s　月薪%d" % [cand.name, cand.rank_name(), cand.salary], 420)
		var captured = cand
		b.pressed.connect(func(): _select(captured))
		_list.add_child(b)
	_select(GameState.tavern_candidates[0])

func _select(c: CKCharacter) -> void:
	_selected = c
	_portrait.texture = UnitArt.portrait(c, 128)
	_detail.text = UIKit.char_card_text(c) + "\n\n招募费约 %d 银\n\n[i]掌柜低声：看脸，也看数。旗面亮的团，人肯跟。[/i]" % (25 + c.rank_index() * 15)

func _hire() -> void:
	if _selected == null:
		return
	var r = GameState.recruit(_selected)
	_msg.text = str(r.get("msg", ""))
	_refresh()

func _back() -> void:
	if str(GameState.chapter0_beat) == "0.2" and not GameState.flag("hub_open"):
		get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
