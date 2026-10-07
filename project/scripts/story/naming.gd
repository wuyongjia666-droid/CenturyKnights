extends Control

var _given: LineEdit
var _surname: LineEdit
var _color_idx: int = 0
var _colors := ["#c9a227", "#8b2e2e", "#3a6ea5", "#3d6b4f", "#6b4c7a"]
var _color_names := ["灰烬金", "旗红", "河蓝", "松绿", "暮紫"]
var _preview: ColorRect
var _banner: TextureRect
var _portrait: TextureRect
var _color_name_label: Label

func _ready() -> void:
	_build()
	_refresh_preview_art()

func _build() -> void:
	UIKit.make_screen_bg(self)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	box.add_child(UIKit.make_label("破旗 · 立姓", true))
	box.add_child(UIKit.make_dim_label("朔澜陆桥边境，灰烬旗需要一个姓氏与纹章色。旗面与团长立绘将随你的选择即时变化。"))

	var art_row := HBoxContainer.new()
	art_row.alignment = BoxContainer.ALIGNMENT_CENTER
	art_row.add_theme_constant_override("separation", 24)
	box.add_child(art_row)
	_banner = TextureRect.new()
	_banner.custom_minimum_size = Vector2(120, 170)
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_row.add_child(_banner)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(140, 140)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_row.add_child(_portrait)

	box.add_child(UIKit.make_label("姓氏"))
	_surname = LineEdit.new()
	_surname.text = "灰旗"
	_surname.custom_minimum_size = Vector2(280, 36)
	_surname.text_changed.connect(func(_t): _refresh_preview_art())
	box.add_child(_surname)

	box.add_child(UIKit.make_label("名字"))
	_given = LineEdit.new()
	_given.text = "烬行"
	_given.custom_minimum_size = Vector2(280, 36)
	_given.text_changed.connect(func(_t): _refresh_preview_art())
	box.add_child(_given)

	box.add_child(UIKit.make_label("纹章色"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var prev_btn = UIKit.make_button("◀", 48)
	prev_btn.pressed.connect(func(): _shift_color(-1))
	row.add_child(prev_btn)
	_preview = ColorRect.new()
	_preview.custom_minimum_size = Vector2(72, 40)
	_preview.color = Color(_colors[_color_idx])
	row.add_child(_preview)
	var next_btn = UIKit.make_button("▶", 48)
	next_btn.pressed.connect(func(): _shift_color(1))
	row.add_child(next_btn)
	_color_name_label = UIKit.make_label(_color_names[_color_idx])
	_color_name_label.add_theme_color_override("font_color", UIKit.ACCENT)
	row.add_child(_color_name_label)

	var start = UIKit.make_accent_button("升起灰旗", 240)
	start.pressed.connect(_on_start)
	box.add_child(start)

	var back = UIKit.make_button(Locale.t("btn_back"), 200)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	box.add_child(back)

func _shift_color(d: int) -> void:
	_color_idx = (_color_idx + d + _colors.size()) % _colors.size()
	_preview.color = Color(_colors[_color_idx])
	_color_name_label.text = _color_names[_color_idx]
	_refresh_preview_art()

func _refresh_preview_art() -> void:
	# 临时写入以便 UnitArt 取色/姓
	var prev_c = GameState.crest_color
	var prev_s = GameState.surname
	GameState.crest_color = _colors[_color_idx]
	GameState.surname = _surname.text.strip_edges() if _surname else "灰旗"
	UnitArt.clear_cache()
	_banner.texture = UnitArt.banner(120, 170, true)
	var tmp := CKCharacter.new()
	tmp.name = GameState.surname + (_given.text.strip_edges() if _given else "烬行")
	tmp.is_leader = true
	tmp.job_id = "squire"
	tmp.gender = "m"
	tmp.appearance = {"hair": "ash_brown", "eyes": "river_blue", "brow": "thick", "scar": "none"}
	_portrait.texture = UnitArt.portrait(tmp, 140)
	GameState.crest_color = prev_c
	GameState.surname = prev_s

func _on_start() -> void:
	var g = _given.text.strip_edges()
	var s = _surname.text.strip_edges()
	if g == "" or s == "":
		return
	GameState.new_game(g, s, _colors[_color_idx])
	UnitArt.clear_cache()
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
