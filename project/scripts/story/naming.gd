extends Control

var _given: LineEdit
var _surname: LineEdit
var _color_idx: int = 0
var _colors := ["#c9a227", "#8b2e2e", "#3a6ea5", "#3d6b4f", "#6b4c7a"]
var _color_names := ["灰烬金", "旗红", "河蓝", "松绿", "暮紫"]
var _preview: ColorRect

func _ready() -> void:
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.position = Vector2(360, 120)
	box.custom_minimum_size = Vector2(560, 480)
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	box.add_child(UIKit.make_label("破旗 · 立姓", true))
	box.add_child(UIKit.make_label("朔澜陆桥边境，灰烬旗需要一个姓氏与纹章色。"))

	box.add_child(UIKit.make_label("姓氏"))
	_surname = LineEdit.new()
	_surname.text = "灰旗"
	_surname.custom_minimum_size = Vector2(240, 36)
	box.add_child(_surname)

	box.add_child(UIKit.make_label("名字"))
	_given = LineEdit.new()
	_given.text = "烬行"
	_given.custom_minimum_size = Vector2(240, 36)
	box.add_child(_given)

	box.add_child(UIKit.make_label("纹章色"))
	var row := HBoxContainer.new()
	box.add_child(row)
	var prev_btn = UIKit.make_button("◀", 48)
	prev_btn.pressed.connect(func(): _shift_color(-1))
	row.add_child(prev_btn)
	_preview = ColorRect.new()
	_preview.custom_minimum_size = Vector2(64, 36)
	_preview.color = Color(_colors[_color_idx])
	row.add_child(_preview)
	var next_btn = UIKit.make_button("▶", 48)
	next_btn.pressed.connect(func(): _shift_color(1))
	row.add_child(next_btn)
	var cname = UIKit.make_label(_color_names[_color_idx])
	cname.name = "ColorName"
	row.add_child(cname)

	var start = UIKit.make_button("升起灰旗", 200)
	start.pressed.connect(_on_start)
	box.add_child(start)

	var back = UIKit.make_button(Locale.t("btn_back"), 200)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	box.add_child(back)

func _shift_color(d: int) -> void:
	_color_idx = (_color_idx + d + _colors.size()) % _colors.size()
	_preview.color = Color(_colors[_color_idx])

func _on_start() -> void:
	var g = _given.text.strip_edges()
	var s = _surname.text.strip_edges()
	if g == "" or s == "":
		return
	GameState.new_game(g, s, _colors[_color_idx])
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
