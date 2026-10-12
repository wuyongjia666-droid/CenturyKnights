extends Control

var _given: LineEdit
var _surname: LineEdit
var _color_idx: int = 0
var _field_idx: int = 0
var _charge_idx: int = 0
var _border_idx: int = 0
var _emblem_idx: int = 0
var _colors: Array = []
var _color_names: Array = []
var _preview: ColorRect
var _banner: TextureRect
var _portrait: TextureRect
var _color_name_label: Label
var _field_label: Label
var _charge_label: Label
var _border_label: Label
var _emblem_label: Label
var _warn: Label
var _scroll: ScrollContainer

const FIELD_KEYS := ["ux_field_solid", "ux_field_per_fess", "ux_field_per_pale"]
const CHARGE_KEYS := ["ux_charge_none", "ux_charge_fess", "ux_charge_pale", "ux_charge_bend", "ux_charge_chevron", "ux_charge_pale_thin"]
const BORDER_KEYS := ["ux_border_none", "ux_border_line", "ux_border_double", "ux_border_dentil"]
const EMBLEM_KEYS := [
	"ux_emblem_ring", "ux_emblem_arc", "ux_emblem_wave", "ux_emblem_leaf", "ux_emblem_chevron", "ux_emblem_spark",
	"ux_emblem_filament", "ux_emblem_tide", "ux_emblem_notch", "ux_emblem_bars", "ux_emblem_bend", "ux_emblem_hollow",
]
const COLOR_KEYS := [
	"ux_color_frost_cyan", "ux_color_mint", "ux_color_frost_silver", "ux_color_river", "ux_color_clear_frost", "ux_color_tide_ink",
	"ux_color_ice_river", "ux_color_sky", "ux_color_tide_cyan", "ux_color_plume", "ux_color_frost_white", "ux_color_iron_frost",
	"ux_color_pine_mist", "ux_color_coral", "ux_color_ember_haze", "ux_color_silver_gray", "ux_color_mist_blue", "ux_color_bay",
	"ux_color_haze_gray", "ux_color_thin_mist", "ux_color_lake", "ux_color_shallow_tide", "ux_color_cloud", "ux_color_plain",
]

func _ready() -> void:
	_colors = BannerSpec.PALETTE.duplicate()
	_color_names = []
	for k in COLOR_KEYS:
		_color_names.append(Locale.t(k))
	_build()
	_refresh_preview_art()

func _current_spec() -> Dictionary:
	var field := str(_colors[_color_idx])
	var pair := str(_colors[(_color_idx + 6) % _colors.size()])
	return BannerSpec.normalize({
		"field": BannerSpec.FIELDS[_field_idx],
		"field_a": field,
		"field_b": pair,
		"charge": BannerSpec.CHARGES[_charge_idx],
		"charge_color": "#" + UIKit.TEXT.to_html(false),
		"border": BannerSpec.BORDERS[_border_idx],
		"border_color": "#" + UIKit.ACCENT_HOVER.to_html(false),
		"emblem": BannerSpec.EMBLEMS[_emblem_idx],
		"emblem_color": "#" + UIKit.TEXT.to_html(false),
	})

func _build() -> void:
	UIKit.make_screen_bg(self)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var center := MarginContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("margin_left", 24)
	center.add_theme_constant_override("margin_right", 24)
	center.add_theme_constant_override("margin_top", 24)
	center.add_theme_constant_override("margin_bottom", 24)
	_scroll.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	box.add_child(UIKit.make_label(Locale.t("ux_name_title"), true))
	box.add_child(UIKit.make_dim_label(Locale.t("ux_name_blurb")))

	var art_row := HBoxContainer.new()
	art_row.alignment = BoxContainer.ALIGNMENT_CENTER
	art_row.add_theme_constant_override("separation", 24)
	box.add_child(art_row)
	_banner = TextureRect.new()
	_banner.custom_minimum_size = Vector2(140, 200)
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_row.add_child(_banner)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(140, 140)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_row.add_child(_portrait)

	box.add_child(UIKit.make_label(Locale.t("ux_name_surname")))
	_surname = LineEdit.new()
	_surname.text = "灰旗"
	_surname.custom_minimum_size = Vector2(280, 40)
	_surname.text_changed.connect(func(_t): _refresh_preview_art())
	box.add_child(_surname)

	box.add_child(UIKit.make_label(Locale.t("ux_name_given")))
	_given = LineEdit.new()
	_given.text = "烬行"
	_given.custom_minimum_size = Vector2(280, 40)
	_given.text_changed.connect(func(_t): _refresh_preview_art())
	box.add_child(_given)

	box.add_child(UIKit.make_label(Locale.t("ux_name_field_color")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var prev_btn = UIKit.make_button("◀", 48)
	prev_btn.pressed.connect(func(): _shift_color(-1))
	row.add_child(prev_btn)
	_preview = ColorRect.new()
	_preview.custom_minimum_size = Vector2(72, 40)
	_preview.color = Color(str(_colors[_color_idx]))
	row.add_child(_preview)
	var next_btn = UIKit.make_button("▶", 48)
	next_btn.pressed.connect(func(): _shift_color(1))
	row.add_child(next_btn)
	_color_name_label = UIKit.make_label(str(_color_names[_color_idx]))
	_color_name_label.add_theme_color_override("font_color", UIKit.ACCENT)
	row.add_child(_color_name_label)

	_field_label = _layer_row(box, Locale.t("ux_name_field_split"), func(d): _shift_enum("field", d))
	_charge_label = _layer_row(box, Locale.t("ux_name_charge"), func(d): _shift_enum("charge", d))
	_border_label = _layer_row(box, Locale.t("ux_name_border"), func(d): _shift_enum("border", d))
	_emblem_label = _layer_row(box, Locale.t("ux_name_emblem"), func(d): _shift_enum("emblem", d))
	_warn = UIKit.make_dim_label("")
	_warn.add_theme_color_override("font_color", UIKit.DANGER)
	box.add_child(_warn)

	var start = UIKit.make_accent_button(Locale.t("ux_name_raise"), 240)
	start.custom_minimum_size = Vector2(240, 48)
	start.pressed.connect(_on_start)
	box.add_child(start)

	var back = UIKit.make_button(Locale.t("btn_back"), 200)
	back.custom_minimum_size = Vector2(200, 48)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	box.add_child(back)

func _layer_row(box: VBoxContainer, title: String, cb: Callable) -> Label:
	box.add_child(UIKit.make_label(title))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var prev_btn = UIKit.make_button("◀", 48)
	prev_btn.pressed.connect(func(): cb.call(-1))
	row.add_child(prev_btn)
	var lab := UIKit.make_label("")
	lab.add_theme_color_override("font_color", UIKit.ACCENT)
	lab.custom_minimum_size = Vector2(120, 0)
	row.add_child(lab)
	var next_btn = UIKit.make_button("▶", 48)
	next_btn.pressed.connect(func(): cb.call(1))
	row.add_child(next_btn)
	return lab

func _shift_color(d: int) -> void:
	_color_idx = (_color_idx + d + _colors.size()) % _colors.size()
	_preview.color = Color(str(_colors[_color_idx]))
	_color_name_label.text = str(_color_names[_color_idx])
	_refresh_preview_art()

func _shift_enum(which: String, d: int) -> void:
	match which:
		"field":
			_field_idx = (_field_idx + d + BannerSpec.FIELDS.size()) % BannerSpec.FIELDS.size()
		"charge":
			_charge_idx = (_charge_idx + d + BannerSpec.CHARGES.size()) % BannerSpec.CHARGES.size()
		"border":
			_border_idx = (_border_idx + d + BannerSpec.BORDERS.size()) % BannerSpec.BORDERS.size()
		"emblem":
			_emblem_idx = (_emblem_idx + d + BannerSpec.EMBLEMS.size()) % BannerSpec.EMBLEMS.size()
	_refresh_preview_art()

func _sync_layer_labels() -> void:
	if _field_label:
		_field_label.text = Locale.t(FIELD_KEYS[_field_idx])
	if _charge_label:
		_charge_label.text = Locale.t(CHARGE_KEYS[_charge_idx])
	if _border_label:
		_border_label.text = Locale.t(BORDER_KEYS[_border_idx])
	if _emblem_label:
		_emblem_label.text = Locale.t(EMBLEM_KEYS[_emblem_idx])

func _refresh_preview_art() -> void:
	_sync_layer_labels()
	var spec := _current_spec()
	var prev_c = GameState.crest_color
	var prev_s = GameState.surname
	var prev_b = GameState.banner_spec.duplicate(true)
	GameState.crest_color = str(spec.field_a)
	GameState.banner_spec = spec
	GameState.surname = _surname.text.strip_edges() if _surname else "灰旗"
	UnitArt.clear_cache()
	_banner.texture = UnitArt.banner_layers(spec, 140, 200)
	var tmp := CKCharacter.new()
	tmp.name = GameState.surname + (_given.text.strip_edges() if _given else "烬行")
	tmp.is_leader = true
	tmp.job_id = "squire"
	tmp.gender = "m"
	tmp.appearance = {"hair": "ash_brown", "eyes": "river_blue", "brow": "thick", "scar": "none"}
	_portrait.texture = UnitArt.portrait(tmp, 140, CKArtPaths.TIER_MEDIUM)
	if _warn:
		_warn.text = "" if BannerSpec.contrast_ok(spec) else Locale.t("ux_name_contrast")
	GameState.crest_color = prev_c
	GameState.surname = prev_s
	GameState.banner_spec = prev_b

func _on_start() -> void:
	var g = _given.text.strip_edges()
	var s = _surname.text.strip_edges()
	if g == "" or s == "":
		return
	var spec := _current_spec()
	GameState.new_game(g, s, str(spec.field_a))
	GameState.banner_spec = spec
	GameState.crest_color = str(spec.field_a)
	UnitArt.clear_cache()
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")

func apply_mobile_layout() -> void:
	if _scroll:
		_scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
