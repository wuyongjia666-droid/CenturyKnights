extends Control

var _given: LineEdit
var _surname: LineEdit
var _color_idx: int = 0
var _field_idx: int = 0
var _partition_idx: int = 0
var _charge_idx: int = 0
var _border_idx: int = 0
var _emblem_idx: int = 0
var _nation_idx: int = 0
var _colors: Array = []
var _color_names: Array = []
var _divisions: PackedStringArray = []
var _partitions: PackedStringArray = []
var _ordinaries: PackedStringArray = []
var _nations: PackedStringArray = []
var _preview: ColorRect
var _banner: TextureRect
var _shield: TextureRect
var _portrait: TextureRect
var _color_name_label: Label
var _field_label: Label
var _partition_label: Label
var _charge_label: Label
var _border_label: Label
var _emblem_label: Label
var _nation_label: Label
var _warn: Label
var _scroll: ScrollContainer
var _starting := false

const FIELD_KEYS := {
	"solid": "ux_field_solid",
	"per_fess": "ux_field_per_fess",
	"per_pale": "ux_field_per_pale",
	"per_bend": "ux_div_per_bend",
	"per_bend_sinister": "ux_div_per_bend_sinister",
	"quarterly": "ux_div_quarterly",
	"per_chevron": "ux_div_per_chevron",
	"per_saltire": "ux_div_per_saltire",
	"gyronny": "ux_div_gyronny",
}
const PART_KEYS := {
	"straight": "ux_part_straight",
	"wavy": "ux_part_wavy",
	"engrailed": "ux_part_engrailed",
	"embattled": "ux_part_embattled",
	"invected": "ux_part_invected",
	"nebuly": "ux_part_nebuly",
}
const CHARGE_KEYS := {
	"none": "ux_charge_none",
	"fess": "ux_charge_fess",
	"pale": "ux_charge_pale",
	"bend": "ux_charge_bend",
	"bend_sinister": "ux_ord_bend_sinister",
	"chevron": "ux_charge_chevron",
	"pale_thin": "ux_charge_pale_thin",
	"cross": "ux_ord_cross",
	"saltire": "ux_ord_saltire",
	"chief": "ux_ord_chief",
	"bordure": "ux_ord_bordure",
	"orle": "ux_ord_orle",
	"pile": "ux_ord_pile",
	"pall": "ux_ord_pall",
}
const BORDER_KEYS := ["ux_border_none", "ux_border_line", "ux_border_double", "ux_border_dentil"]
const EMBLEM_KEYS := {
	"ring": "ux_emblem_ring", "arc": "ux_emblem_arc", "wave": "ux_emblem_wave", "leaf": "ux_emblem_leaf",
	"chevron": "ux_emblem_chevron", "chevron_mark": "ux_emblem_chevron", "spark": "ux_emblem_spark",
	"filament": "ux_emblem_filament", "tide": "ux_emblem_tide", "notch": "ux_emblem_notch",
	"bars": "ux_emblem_bars", "bend": "ux_emblem_bend", "bend_mark": "ux_emblem_bend", "hollow": "ux_emblem_hollow",
	"mullet": "ux_emblem_spark", "crescent": "ux_emblem_arc", "annulet": "ux_emblem_ring",
	"ash_plume": "ux_emblem_bars", "shadow_arc": "ux_emblem_arc", "jade_wave": "ux_emblem_wave",
	"glass_lantern": "ux_emblem_filament", "ice_crown": "ux_emblem_ring", "ember_notch": "ux_emblem_notch",
	"salt_crystal": "ux_emblem_spark", "iron_chevron": "ux_emblem_chevron", "constellation": "ux_emblem_spark",
	"fog_leaf": "ux_emblem_leaf", "lantern": "ux_emblem_filament", "flake": "ux_emblem_spark",
	"reed": "ux_emblem_wave", "anvil": "ux_emblem_notch", "starbridge": "ux_emblem_spark",
	"zephyr": "ux_emblem_leaf", "tower": "ux_emblem_bars", "bridge": "ux_emblem_bend",
	"lozenge": "ux_emblem_leaf", "plume": "ux_emblem_bars",
}
const COLOR_KEYS := [
	"ux_color_frost_cyan", "ux_color_mint", "ux_color_frost_silver", "ux_color_river", "ux_color_clear_frost", "ux_color_tide_ink",
	"ux_color_ice_river", "ux_color_sky", "ux_color_tide_cyan", "ux_color_plume", "ux_color_frost_white", "ux_color_iron_frost",
	"ux_color_pine_mist", "ux_color_coral", "ux_color_ember_haze", "ux_color_silver_gray", "ux_color_mist_blue", "ux_color_bay",
	"ux_color_haze_gray", "ux_color_thin_mist", "ux_color_lake", "ux_color_shallow_tide", "ux_color_cloud", "ux_color_plain",
]

func _ready() -> void:
	_colors = BannerSpec.palette().duplicate()
	_color_names = []
	for k in COLOR_KEYS:
		_color_names.append(Locale.t(k))
	_divisions = CKHeraldry.division_ids()
	_partitions = CKHeraldry.partition_line_ids()
	_ordinaries = CKHeraldry.ordinary_ids()
	_nations = PackedStringArray(CKHeraldry.table().get("nations", {}).keys())
	if _nations.is_empty():
		_nations = PackedStringArray(["ashbanner"])
	_build()
	_refresh_preview_art()

func _current_spec() -> Dictionary:
	var field := str(_colors[_color_idx])
	var pair := str(_colors[(_color_idx + 6) % _colors.size()])
	var division := str(_divisions[_field_idx]) if _divisions.size() > 0 else "solid"
	var ordinary := str(_ordinaries[_charge_idx]) if _ordinaries.size() > 0 else "none"
	var emblem_id: String = str(BannerSpec.EMBLEMS[_emblem_idx])
	var nation := str(_nations[_nation_idx])
	var charge_col := "#" + UIKit.TEXT.to_html(false)
	# Prefer a legal tincture for ordinary / emblem against field.
	if not CKHeraldry.tincture_ok(field, charge_col):
		charge_col = CKHeraldry.tincture_hex("argent") if CKHeraldry.tincture_class(field) == "colour" else CKHeraldry.tincture_hex("sable")
	return BannerSpec.normalize({
		"schema": 2,
		"field": division if division in BannerSpec.FIELDS else "solid",
		"division": division,
		"partition_line": str(_partitions[_partition_idx]) if _partitions.size() > 0 else "straight",
		"field_a": field,
		"field_b": pair,
		"charge": ordinary if ordinary in BannerSpec.CHARGES else "none",
		"ordinary": ordinary,
		"ordinary_tincture": charge_col,
		"charge_color": charge_col,
		"border": BannerSpec.BORDERS[_border_idx],
		"border_color": "#" + UIKit.ACCENT_HOVER.to_html(false),
		"emblem": emblem_id,
		"emblem_color": charge_col,
		"charges": [{"id": emblem_id, "tincture": charge_col, "placement": "center"}],
		"nation": nation,
		"shield_shape": str(CKHeraldry.nation_style(nation).get("shield", "heater")),
	})

func _build() -> void:
	## Audit #8: two columns inside the 1280x720 design frame. Form scrolls on the left,
	## preview and the start button stay on the right, so nothing leaves the screen.
	UIKit.void_bg(self)
	UIKit.top_bar(self, Locale.t("ux_name_title"), [], Locale.t("btn_back"), func(): CKNav.replace(CKNav.TITLE))
	var head := UIKit.page_head(self, 42, 50, "FOUNDING // NAME & BANNER", Locale.t("ux_name_title"), "", "", "", 22)
	head.name = "PageHead"
	var blurb := CKPageKit.text(Locale.t("ux_name_blurb"), UIKit.TEXT_DIM, 13, 700)
	blurb.position = Vector2(42, 104)
	add_child(blurb)

	var form_card := CKPageKit.card(self, Rect2(42, 132, 760, 556), "FormCard")
	_scroll = ScrollContainer.new()
	_scroll.name = "FormScroll"
	_scroll.position = Vector2(16, 12)
	_scroll.size = Vector2(728, 532)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	form_card.add_child(_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	_scroll.add_child(box)

	var names := GridContainer.new()
	names.columns = 2
	names.add_theme_constant_override("h_separation", 16)
	box.add_child(names)
	_surname = LineEdit.new()
	_surname.text = "灰旗"
	_surname.max_length = 6
	_surname.custom_minimum_size = Vector2(340, 48)
	_surname.text_changed.connect(func(_t): _refresh_preview_art())
	_given = LineEdit.new()
	_given.text = "烬行"
	_given.max_length = 6
	_given.custom_minimum_size = Vector2(340, 48)
	_given.text_changed.connect(func(_t): _refresh_preview_art())
	names.add_child(UIKit.make_label(Locale.t("ux_name_surname")))
	names.add_child(UIKit.make_label(Locale.t("ux_name_given")))
	names.add_child(_surname)
	names.add_child(_given)

	var grid := GridContainer.new()
	grid.name = "LayerGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var color_cell := VBoxContainer.new()
	color_cell.custom_minimum_size = Vector2(340, 0)
	grid.add_child(color_cell)
	color_cell.add_child(UIKit.make_label(Locale.t("ux_name_field_color")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	color_cell.add_child(row)
	var prev_btn = UIKit.make_button("◀", 48)
	prev_btn.pressed.connect(func(): _shift_color(-1))
	row.add_child(prev_btn)
	_preview = ColorRect.new()
	_preview.custom_minimum_size = Vector2(56, 44)
	_preview.color = Color(str(_colors[_color_idx]))
	row.add_child(_preview)
	var next_btn = UIKit.make_button("▶", 48)
	next_btn.pressed.connect(func(): _shift_color(1))
	row.add_child(next_btn)
	_color_name_label = UIKit.make_label(str(_color_names[_color_idx]))
	_color_name_label.add_theme_color_override("font_color", UIKit.ACCENT)
	row.add_child(_color_name_label)

	_nation_label = _layer_row(grid, Locale.t("ux_name_nation_rand"), func(d): _shift_enum("nation", d))
	_field_label = _layer_row(grid, Locale.t("ux_name_field_split"), func(d): _shift_enum("field", d))
	_partition_label = _layer_row(grid, Locale.t("ux_name_partition"), func(d): _shift_enum("partition", d))
	_charge_label = _layer_row(grid, Locale.t("ux_name_ordinary"), func(d): _shift_enum("charge", d))
	_border_label = _layer_row(grid, Locale.t("ux_name_border"), func(d): _shift_enum("border", d))
	_emblem_label = _layer_row(grid, Locale.t("ux_name_emblem"), func(d): _shift_enum("emblem", d))
	CKPageKit.drag_through(box)

	var side := CKPageKit.card(self, Rect2(818, 132, 420, 556), "PreviewCard")
	CKPageKit.card_head(side, Locale.t("ux_name_preview"), "BANNER PREVIEW")
	var art_row := HBoxContainer.new()
	art_row.name = "ArtRow"
	art_row.position = Vector2(16, 56)
	art_row.size = Vector2(388, 220)
	art_row.alignment = BoxContainer.ALIGNMENT_CENTER
	art_row.add_theme_constant_override("separation", 10)
	side.add_child(art_row)
	_shield = TextureRect.new()
	_shield.custom_minimum_size = Vector2(110, 130)
	_shield.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shield.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_row.add_child(_shield)
	_banner = TextureRect.new()
	_banner.custom_minimum_size = Vector2(120, 200)
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_row.add_child(_banner)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(130, 160)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_row.add_child(_portrait)

	var rand_btn := CKPageKit.button(Locale.t("ux_name_nation_rand"), false, 388)
	rand_btn.name = "RandomNation"
	rand_btn.position = Vector2(16, 300)
	rand_btn.pressed.connect(_on_randomize_nation)
	side.add_child(rand_btn)
	_warn = UIKit.make_dim_label("")
	_warn.name = "NameWarn"
	_warn.add_theme_color_override("font_color", UIKit.DANGER)
	_warn.position = Vector2(16, 372)
	_warn.size = Vector2(388, 40)
	_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_warn)
	var start := CKPageKit.button(Locale.t("ux_name_raise"), true, 388)
	start.name = "StartButton"
	start.position = Vector2(16, 480)
	start.pressed.connect(_on_start)
	side.add_child(start)

func _layer_row(grid: Container, title: String, cb: Callable) -> Label:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(340, 0)
	grid.add_child(box)
	box.add_child(UIKit.make_label(title))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var prev_btn = UIKit.make_button("◀", 48)
	prev_btn.pressed.connect(func(): cb.call(-1))
	row.add_child(prev_btn)
	var lab := UIKit.make_label("")
	lab.add_theme_color_override("font_color", UIKit.ACCENT)
	lab.custom_minimum_size = Vector2(140, 0)
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
			_field_idx = (_field_idx + d + _divisions.size()) % maxi(1, _divisions.size())
		"partition":
			_partition_idx = (_partition_idx + d + _partitions.size()) % maxi(1, _partitions.size())
		"charge":
			_charge_idx = (_charge_idx + d + _ordinaries.size()) % maxi(1, _ordinaries.size())
		"border":
			_border_idx = (_border_idx + d + BannerSpec.BORDERS.size()) % BannerSpec.BORDERS.size()
		"emblem":
			_emblem_idx = (_emblem_idx + d + BannerSpec.EMBLEMS.size()) % BannerSpec.EMBLEMS.size()
		"nation":
			_nation_idx = (_nation_idx + d + _nations.size()) % maxi(1, _nations.size())
	_refresh_preview_art()

func _on_randomize_nation() -> void:
	var nid := str(_nations[_nation_idx])
	var spec := CKHeraldry.randomize_for_nation(nid, GameState.rng if GameState.get("rng") else null)
	# Sync UI indices from randomized spec.
	var div := str(spec.get("division", "solid"))
	_field_idx = maxi(0, _divisions.find(div))
	var part := str(spec.get("partition_line", "straight"))
	_partition_idx = maxi(0, _partitions.find(part))
	var ord := str(spec.get("ordinary", "none"))
	_charge_idx = maxi(0, _ordinaries.find(ord))
	var fa := str(spec.get("field_a", "")).to_lower()
	for i in _colors.size():
		if str(_colors[i]).to_lower() == fa:
			_color_idx = i
			break
	var chs: Array = spec.get("charges", [])
	if not chs.is_empty() and typeof(chs[0]) == TYPE_DICTIONARY:
		var eid := str((chs[0] as Dictionary).get("id", "ring"))
		var ix := BannerSpec.EMBLEMS.find(eid)
		if ix < 0:
			# Map nation charge to closest emblem slot.
			ix = BannerSpec.EMBLEMS.find("ring")
		_emblem_idx = maxi(0, ix)
	_preview.color = Color(str(_colors[_color_idx]))
	_color_name_label.text = str(_color_names[_color_idx])
	_refresh_preview_art()

func _sync_layer_labels() -> void:
	if _field_label and _divisions.size() > 0:
		var d := str(_divisions[_field_idx])
		_field_label.text = Locale.t(str(FIELD_KEYS.get(d, "ux_field_solid")))
	if _partition_label and _partitions.size() > 0:
		var p := str(_partitions[_partition_idx])
		_partition_label.text = Locale.t(str(PART_KEYS.get(p, "ux_part_straight")))
	if _charge_label and _ordinaries.size() > 0:
		var o := str(_ordinaries[_charge_idx])
		_charge_label.text = Locale.t(str(CHARGE_KEYS.get(o, "ux_charge_none")))
	if _border_label:
		_border_label.text = Locale.t(BORDER_KEYS[_border_idx])
	if _emblem_label:
		var e: String = str(BannerSpec.EMBLEMS[_emblem_idx])
		_emblem_label.text = Locale.t(str(EMBLEM_KEYS.get(e, "ux_emblem_ring")))
	if _nation_label and _nations.size() > 0:
		var st := CKHeraldry.nation_style(str(_nations[_nation_idx]))
		_nation_label.text = str(st.get("zh", _nations[_nation_idx]))

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
	if _shield:
		_shield.texture = ImageTexture.create_from_image(BannerSpec.compose_shield(spec, 120, 140))
	var tmp := CKCharacter.new()
	tmp.name = GameState.surname + (_given.text.strip_edges() if _given else "烬行")
	tmp.is_leader = true
	tmp.job_id = "squire"
	tmp.gender = "m"
	tmp.appearance = {"hair": "ash_brown", "eyes": "river_blue", "brow": "thick", "scar": "none"}
	_portrait.texture = UnitArt.portrait(tmp, 140, CKArtPaths.TIER_MEDIUM)
	if _warn:
		var bits: PackedStringArray = []
		if not BannerSpec.contrast_ok(spec):
			bits.append(Locale.t("ux_name_contrast"))
		if not BannerSpec.tincture_ok(spec):
			bits.append(Locale.t("ux_heraldry_tincture_warn"))
		_warn.text = " · ".join(bits)
		_warn.add_theme_color_override("font_color", UIKit.DANGER if not bits.is_empty() else UIKit.OK)
		if bits.is_empty():
			_warn.text = Locale.t("ux_heraldry_ok")
	GameState.crest_color = prev_c
	GameState.surname = prev_s
	GameState.banner_spec = prev_b

func _on_start() -> void:
	var g = _given.text.strip_edges()
	var s = _surname.text.strip_edges()
	if g == "" or s == "":
		_warn.text = Locale.t("ux_name_empty")
		Sfx.miss()
		return
	if _starting:
		return
	_starting = true
	var spec := _current_spec()
	GameState.new_game(g, s, str(spec.field_a))
	GameState.banner_spec = spec
	GameState.ensure_unique_arms()  # company banner is set once here; a colliding family core re-rolls
	GameState.crest_color = str(spec.field_a)
	UnitArt.clear_cache()
	GameState.save_game()
	CKNav.replace("res://scenes/story/chapter0.tscn")

func apply_mobile_layout() -> void:
	pass   # layout already fits the 1280x720 frame on every aspect
