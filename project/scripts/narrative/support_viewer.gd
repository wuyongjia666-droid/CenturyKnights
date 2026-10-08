extends Control
## NAR-04：在城堡里看已解锁的支援对话。UX 把按钮指到 VIEWER 场景即可。

const VIEWER := "res://scenes/story/support_viewer.tscn"

@export var suppress_scene_change: bool = false

var _lines: Array = []
var _idx := 0
var _open_id := ""
var _list: VBoxContainer
var _speaker: Label
var _body: RichTextLabel
var _actions: VBoxContainer


func _ready() -> void:
	Bonds.conversations()
	UIKit.make_screen_bg(self)
	var title := UIKit.make_label(Locale.t("nar04_title"), true)
	title.position = Vector2(48, 28)
	add_child(title)
	_list = VBoxContainer.new()
	_list.position = Vector2(48, 80)
	_list.custom_minimum_size = Vector2(420, 520)
	_list.add_theme_constant_override("separation", 8)
	add_child(_list)
	_speaker = UIKit.make_label("")
	_speaker.position = Vector2(500, 80)
	add_child(_speaker)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = false
	_body.position = Vector2(500, 120)
	_body.custom_minimum_size = Vector2(720, 280)
	_body.scroll_active = false
	_body.add_theme_color_override("default_color", UIKit.TEXT)
	_body.add_theme_font_size_override("normal_font_size", 16)
	add_child(_body)
	_actions = VBoxContainer.new()
	_actions.position = Vector2(500, 440)
	add_child(_actions)
	var back := UIKit.make_button(Locale.t("nar04_back"), 160)
	back.position = Vector2(1060, 28)
	back.pressed.connect(_back)
	add_child(back)
	_refresh_list()


func titles() -> Array:
	var out: Array = []
	for child in _list.get_children():
		if child is BaseButton:
			out.append(str(child.text))
	return out


func open_containing(fragment: String) -> bool:
	for child in _list.get_children():
		if child is BaseButton and str(child.text).find(fragment) >= 0:
			child.pressed.emit()
			return true
	return false


func current_text() -> String:
	return _body.text


func press_continue() -> void:
	for child in _actions.get_children():
		if child is BaseButton and not child.disabled:
			child.pressed.emit()
			return


func _refresh_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	var rows: Array = Bonds.available()
	if rows.is_empty():
		var empty := UIKit.make_label(Locale.t("nar04_empty"))
		_list.add_child(empty)
		return
	for convo in rows:
		var label := "%s  %s" % [Bonds.pair_names(convo), str(convo.get("title", ""))]
		var button := UIKit.make_accent_button(label, 460)
		var row: Dictionary = convo
		button.pressed.connect(_open.bind(row))
		_list.add_child(button)


func _open(convo: Dictionary) -> void:
	_open_id = str(convo.get("id", ""))
	_lines = convo.get("lines", [])
	_idx = 0
	_show()
	for child in _actions.get_children():
		child.queue_free()
	var next := UIKit.make_accent_button(Locale.t("nar04_continue"), 200)
	next.pressed.connect(_advance)
	_actions.add_child(next)


func _show() -> void:
	if _idx < 0 or _idx >= _lines.size():
		_speaker.text = ""
		_body.text = Locale.t("nar04_done")
		if _open_id != "":
			GameState.set_flag("bond_seen:" + _open_id, true)
		return
	var line: Dictionary = _lines[_idx]
	_speaker.text = str(line.get("speaker", ""))
	_body.text = str(line.get("text", ""))


func _advance() -> void:
	if _idx >= _lines.size():
		return
	_idx += 1
	_show()


func _back() -> void:
	if suppress_scene_change:
		return
	get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")
