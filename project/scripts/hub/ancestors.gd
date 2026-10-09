extends Control
## Ancestor stele. Castle entry is left for the UX stream.

var _title: Label
var _honor: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _back: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UIKit.make_themed_bg(self, "castle")
	_title = UIKit.make_label(Locale.t("ancestor_title"), true)
	add_child(_title)
	_honor = UIKit.body_label("", UIKit.ACCENT, 15)
	add_child(_honor)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	add_child(_scroll)
	_back = UIKit.make_button(Locale.t("btn_back"))
	_back.pressed.connect(_on_back)
	add_child(_back)
	resized.connect(_on_resize)
	_on_resize()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")

func _on_resize() -> void:
	_place()
	_fill()

func _place() -> void:
	var vp := get_viewport_rect().size
	if vp.x < 8.0:
		vp = Vector2(1280, 720)
	var pad := 16.0 if vp.x < 1100.0 else 48.0
	var top := 28.0
	_title.position = Vector2(pad, top)
	_title.size = Vector2(vp.x - pad * 2.0, 40)
	_honor.position = Vector2(pad, top + 44.0)
	_honor.size = Vector2(vp.x - pad * 2.0, 28)
	_back.position = Vector2(pad, vp.y - pad - 40.0)
	_scroll.position = Vector2(pad, top + 84.0)
	_scroll.size = Vector2(vp.x - pad * 2.0, maxf(80.0, vp.y - (top + 84.0) - pad - 56.0))
	_list.custom_minimum_size = Vector2(maxf(120.0, _scroll.size.x - 8.0), 0)

func _fill() -> void:
	for node in _list.get_children():
		_list.remove_child(node)
		node.free()
	var rows: Array = Lineage.ancestor_rows()
	_honor.text = Locale.t("ancestor_honor", [Lineage.honor_bonus()])
	if rows.is_empty():
		var empty := UIKit.body_label(Locale.t("ancestor_empty"), UIKit.TEXT_DIM, 15)
		empty.custom_minimum_size = Vector2(_list.custom_minimum_size.x, 0)
		_list.add_child(empty)
		return
	var width := _list.custom_minimum_size.x
	for row in rows:
		var card := UIKit.make_panel()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var text := Locale.t("ancestor_card", [
			str(row.get("name", "")),
			int(row.get("born_year", 0)),
			int(row.get("death_year", 0)),
			str(row.get("cause_zh", "")),
			str(row.get("words", "")),
			str(row.get("deeds", "")),
			str(row.get("titles", "")),
		]).replace("\\n", "\n")
		var body := UIKit.body_label(text, UIKit.TEXT, 15)
		body.custom_minimum_size = Vector2(maxf(80.0, width - 48.0), 0)
		card.add_child(body)
		_list.add_child(card)
