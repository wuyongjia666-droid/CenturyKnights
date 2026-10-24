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
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	Bonds.conversations()
	UIKit.void_bg(self)
	UIKit.top_bar(self, Locale.t("nar04_title"), [], Locale.t("nar04_back"), _back)
	var scroll := ScrollContainer.new()
	scroll.name = "BondScroll"
	scroll.position = Vector2(48, 80)
	scroll.size = Vector2(430, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "BondList"
	_list.custom_minimum_size = Vector2(420, 0)
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_speaker = UIKit.make_label("")
	_speaker.position = Vector2(500, 80)
	add_child(_speaker)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = false
	_body.fit_content = false
	_body.scroll_following = false
	_body.position = Vector2(500, 120)
	_body.custom_minimum_size = Vector2(720, 280)
	_body.size = Vector2(720, 280)
	_body.scroll_active = true
	_body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_body.add_theme_color_override("default_color", UIKit.TEXT)
	_body.add_theme_font_override("normal_font", UIKit.font("regular"))
	_body.add_theme_font_size_override("normal_font_size", 16)
	add_child(_body)
	_actions = VBoxContainer.new()
	_actions.position = Vector2(500, 440)
	add_child(_actions)
	_refresh_list()


## Landscape phone: wider list on the left, a framed reading pane on the right with a prompt
## until a bond is opened (mobile audit v1: the right half was blank).
var _pane: Control = null

func apply_mobile_layout() -> void:
	if not MobilePage.active(self):
		return
	var w := MobilePage.width(self)
	var bar := get_node_or_null("StitchTopBar") as Control
	if bar:
		MobileLayout.stretch_top_bar(bar, w - bar.size.x)
	var scroll := get_node_or_null("BondScroll") as ScrollContainer
	var lw := clampf(w * 0.38, 440.0, 600.0)
	if scroll:
		scroll.position = Vector2(32, 72)
		scroll.size = Vector2(lw, 720.0 - 72.0 - 16.0)
		_list.custom_minimum_size = Vector2(lw - 14.0, 0)
	var x := 32.0 + lw + 20.0
	var pw := w - x - 32.0
	if _pane == null:
		_pane = Panel.new()
		_pane.name = "ReadPane"
		_pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pane.add_theme_stylebox_override("panel", UIKit.flat_box(Color(0.055, 0.067, 0.090, 0.92), Color(1, 1, 1, 0.10), 10))
		add_child(_pane)
		move_child(_pane, _speaker.get_index())
	_pane.position = Vector2(x, 72)
	_pane.size = Vector2(pw, 720.0 - 72.0 - 16.0)
	_speaker.position = Vector2(x + 20.0, 88)
	_speaker.size = Vector2(pw - 40.0, 34)
	_body.position = Vector2(x + 20.0, 132)
	_body.custom_minimum_size = Vector2(pw - 40.0, 340)
	_body.size = Vector2(pw - 40.0, 340)
	_body.add_theme_font_size_override("normal_font_size", 24)
	_actions.position = Vector2(x + 20.0, 720.0 - 16.0 - 20.0 - MobilePage.HIT)
	_actions.custom_minimum_size = Vector2(pw - 40.0, 0)
	if _open_id == "" and _body.text == "":
		_body.text = Locale.t("ux_bond_pick")


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
	var shut: Array = Bonds.locked()
	if rows.is_empty():
		## Y1-B / heir #30: no unlocked talks → EmptyHost + ToRoster (fight side by side).
		var host := VBoxContainer.new()
		host.name = "EmptyHost"
		host.add_theme_constant_override("separation", 12)
		host.add_child(CKPageKit.empty(
			Locale.t("nar04_empty"),
			Locale.t("a1_bond_why"),
			Locale.t("nar04_empty_how"),
			420
		))
		var acts := HBoxContainer.new()
		acts.name = "EmptyActions"
		acts.add_theme_constant_override("separation", 12)
		var to_r := CKPageKit.button(Locale.t("nar04_to_roster"), true, 300)
		to_r.name = "ToRoster"
		to_r.pressed.connect(func(): CKNav.go("res://scenes/hub/roster.tscn"))
		acts.add_child(to_r)
		UIFX.wire_button(to_r)
		host.add_child(acts)
		_list.add_child(host)
	for convo in rows:
		var label := "%s  %s" % [Bonds.pair_names(convo), str(convo.get("title", ""))]
		var button := UIKit.make_accent_button(label, 460)
		var row: Dictionary = convo
		button.pressed.connect(_open.bind(row))
		_list.add_child(button)
	if not shut.is_empty():
		_list.add_child(CKPageKit.text(Locale.t("a1_bond_locked_head"), UIKit.TEXT_DIM, 13, 420))
	for convo in shut:
		var r := CKPageKit.row(UIKit.TEXT_FAINT, 52)
		r[0].name = "LockedBond"
		var v: VBoxContainer = r[1]
		v.add_child(CKPageKit.text("%s  %s" % [Bonds.pair_names(convo), str(convo.get("title", ""))], UIKit.TEXT_DIM, 14, 390))
		v.add_child(CKPageKit.text(Locale.t("a1_bond_need") % Bonds.missing(convo), UIKit.TEXT_FAINT, 12, 390))
		_list.add_child(r[0])
	CKPageKit.drag_through(_list)


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
		_body.scroll_to_line(0)
		if _open_id != "":
			GameState.set_flag("bond_seen:" + _open_id, true)
		return
	var line: Dictionary = _lines[_idx]
	_speaker.text = str(line.get("speaker", ""))
	_body.text = str(line.get("text", ""))
	_body.scroll_to_line(0)


func _advance() -> void:
	if _idx >= _lines.size():
		return
	_idx += 1
	_show()


func _back() -> void:
	if suppress_scene_change:
		return
	CKNav.up()
