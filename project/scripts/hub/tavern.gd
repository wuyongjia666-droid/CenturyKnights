extends Control

var _list: VBoxContainer
var _detail: RichTextLabel
var _selected: CKCharacter
var _msg: Label

func _ready() -> void:
	_build()
	_refresh()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var t = UIKit.make_label("烽火酒馆", true)
	t.position = Vector2(40, 20)
	add_child(t)
	_list = VBoxContainer.new()
	_list.position = Vector2(40, 80)
	_list.add_theme_constant_override("separation", 8)
	add_child(_list)
	_detail = RichTextLabel.new()
	_detail.position = Vector2(520, 80)
	_detail.custom_minimum_size = Vector2(700, 360)
	_detail.bbcode_enabled = true
	add_child(_detail)
	_msg = UIKit.make_label("")
	_msg.position = Vector2(40, 560)
	add_child(_msg)
	var row := HBoxContainer.new()
	row.position = Vector2(40, 600)
	add_child(row)
	var refresh = UIKit.make_button("刷新候选（教程免费）", 240)
	refresh.pressed.connect(func():
		GameState.refresh_tavern()
		_refresh()
	)
	row.add_child(refresh)
	var hire = UIKit.make_button(Locale.t("recruit"), 120)
	hire.pressed.connect(_hire)
	row.add_child(hire)
	var back = UIKit.make_button(Locale.t("btn_back"), 120)
	back.pressed.connect(_back)
	row.add_child(back)

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for cand in GameState.tavern_candidates:
		var b = UIKit.make_button("%s　%s　月薪%d" % [cand.name, cand.rank_name(), cand.salary], 420)
		var captured = cand
		b.pressed.connect(func(): _select(captured))
		_list.add_child(b)
	if GameState.tavern_candidates.size() > 0:
		_select(GameState.tavern_candidates[0])

func _select(c: CKCharacter) -> void:
	_selected = c
	_detail.text = UIKit.char_card_text(c) + "\n招募费约 %d 银" % (25 + c.rank_index() * 15)

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
