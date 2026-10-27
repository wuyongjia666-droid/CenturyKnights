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
## Opening review B-03: the preview face is a real leader built once; on start its genome is
## carried onto the in-game captain so the face on screen is the face you get.
var _face: CKCharacter = null
## Opening review B-04: gender + four face presets the player picks (preview == result).
var _gender: String = "m"
var _face_idx: int = 0
var _face_gen: int = 0  # bumped on reroll so fixed seed slots still change
var _faces: Array = []  # four CKCharacter presets for the current gender
var _face_btns: Array = []  # Button thumbnails with face icons
var _gender_m_btn: Button = null
var _gender_f_btn: Button = null
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
var _art_row: HBoxContainer
var _start_btn: Button
var _back_btn: Button
var _last_edit_ms := 0
## P1-BNR-02: hub/settings reopen this page to re-edit 团徽 only (no new_game).
var _reedit := false

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
	_reedit = bool(CKNav.params().get("reedit", false)) or str(CKNav.params().get("mode", "")) == "banner_reedit"
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
	if _reedit:
		_apply_reedit_mode()
	_refresh_preview_art()

func _heart() -> String:
	return str(_colors[_color_idx])

func _current_spec() -> Dictionary:
	# Opening review B-09: the cloth is ash grey for every company ("灰底是灰烬邦给的");
	# the colour the player picks is the heart of the banner (charges and emblem).
	# Greys come from the heraldry table (no raw hex — style_lint ratchet).
	var heart := str(_colors[_color_idx])
	var field := CKHeraldry.tincture_hex("ash")
	var pair := CKHeraldry.tincture_hex("ash_deep")
	var division := str(_divisions[_field_idx]) if _divisions.size() > 0 else "solid"
	var ordinary := str(_ordinaries[_charge_idx]) if _ordinaries.size() > 0 else "none"
	var emblem_id: String = str(BannerSpec.EMBLEMS[_emblem_idx])
	var nation := str(_nations[_nation_idx])
	var charge_col := heart
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

## Founding page: the preview pane (shield, banner, portrait, name fields, raise/back) never scrolls.
## Only the heraldry options scroll, beside the pane when wide, below it when tall.
var _split: BoxContainer
var _pane: VBoxContainer
var _opts: VBoxContainer

func _build() -> void:
	UIKit.make_screen_bg(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	_split = BoxContainer.new()
	_split.add_theme_constant_override("separation", 24)
	margin.add_child(_split)

	_pane = VBoxContainer.new()
	_pane.name = "PreviewPane"
	_pane.add_theme_constant_override("separation", 8)
	_split.add_child(_pane)
	_pane.add_child(UIKit.make_label(Locale.t("ux_name_title"), true))
	var blurb := UIKit.make_dim_label(Locale.t("ux_name_blurb"))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pane.add_child(blurb)

	var art_row := HBoxContainer.new()
	_art_row = art_row
	art_row.name = "ArtRow"
	art_row.alignment = BoxContainer.ALIGNMENT_CENTER
	art_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_row.add_theme_constant_override("separation", 16)
	_pane.add_child(art_row)
	_shield = _art_rect(Vector2(110, 130))
	art_row.add_child(_shield)
	_banner = _art_rect(Vector2(160, 230))  # B-10: larger flag in the fixed preview pane
	art_row.add_child(_banner)
	_portrait = _art_rect(Vector2(130, 130))
	art_row.add_child(_portrait)

	_warn = UIKit.make_dim_label("")
	_warn.add_theme_color_override("font_color", UIKit.DANGER)
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pane.add_child(_warn)

	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 12)
	_pane.add_child(names)
	_surname = _name_field(names, Locale.t("ux_name_surname"), "")
	_surname.max_length = 2
	_surname.placeholder_text = Locale.t("ux_name_surname_hint")
	_given = _name_field(names, Locale.t("ux_name_given"), "烬行")
	_given.max_length = 4

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	_pane.add_child(actions)
	var start = UIKit.make_accent_button(Locale.t("ux_name_raise"), 200)
	start.custom_minimum_size = Vector2(200, 52)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_on_start)
	actions.add_child(start)
	_start_btn = start
	var back = UIKit.make_button(Locale.t("btn_back"), 140)
	back.custom_minimum_size = Vector2(140, 52)
	back.pressed.connect(func(): CKNav.replace(CKNav.TITLE))
	actions.add_child(back)
	_back_btn = back

	_scroll = ScrollContainer.new()
	_scroll.name = "OptionsScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if DeviceProfile.is_mobile():
		# Phone: the scroll hint sits under the options column, never over an option.
		var col := VBoxContainer.new()
		col.name = "OptionsColumn"
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		_split.add_child(col)
		col.add_child(_scroll)
		_more_hint = UIKit.body_label(Locale.t("ux_name_more_hint"), UIKit.ACCENT, 22)
		_more_hint.name = "OptionsMoreHint"
		_more_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_more_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_more_hint.custom_minimum_size = Vector2(0, 32)
		col.add_child(_more_hint)
	else:
		_split.add_child(_scroll)
	var box := VBoxContainer.new()
	_opts = box
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	_scroll.add_child(box)

	# B-04: gender + four face cards live in the scrolling options so the
	# fixed preview pane (raise button) still fits 1280×720.
	box.add_child(UIKit.make_label(Locale.t("ux_name_gender")))
	var gender_row := HBoxContainer.new()
	gender_row.name = "GenderRow"
	gender_row.add_theme_constant_override("separation", 8)
	box.add_child(gender_row)
	_gender_m_btn = UIKit.make_button(Locale.t("ux_name_gender_m"), 72)
	_gender_m_btn.name = "GenderM"
	_gender_m_btn.custom_minimum_size = Vector2(72, 44)
	_gender_m_btn.pressed.connect(func(): _set_gender("m"))
	gender_row.add_child(_gender_m_btn)
	_gender_f_btn = UIKit.make_button(Locale.t("ux_name_gender_f"), 72)
	_gender_f_btn.name = "GenderF"
	_gender_f_btn.custom_minimum_size = Vector2(72, 44)
	_gender_f_btn.pressed.connect(func(): _set_gender("f"))
	gender_row.add_child(_gender_f_btn)
	var face_reroll = UIKit.make_button(Locale.t("ux_name_face_reroll"), 140)
	face_reroll.name = "FaceReroll"
	face_reroll.custom_minimum_size = Vector2(140, 44)
	face_reroll.pressed.connect(_reroll_faces)
	gender_row.add_child(face_reroll)

	box.add_child(UIKit.make_label(Locale.t("ux_name_face")))
	var face_row := HBoxContainer.new()
	face_row.name = "FaceRow"
	face_row.add_theme_constant_override("separation", 8)
	box.add_child(face_row)
	_face_btns.clear()
	for i in 4:
		var tb := Button.new()
		tb.name = "FacePick%d" % i
		tb.custom_minimum_size = Vector2(72, 72)
		tb.expand_icon = true
		tb.focus_mode = Control.FOCUS_ALL
		var idx := i
		tb.pressed.connect(func(): _pick_face(idx))
		face_row.add_child(tb)
		_face_btns.append(tb)

	box.add_child(UIKit.make_label(Locale.t("ux_name_field_color")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var prev_btn = UIKit.make_button("◀", 48)
	prev_btn.pressed.connect(func(): _shift_color(-1))
	row.add_child(prev_btn)
	_preview = ColorRect.new()
	_preview.custom_minimum_size = Vector2(72, 48)
	_preview.color = Color(str(_colors[_color_idx]))
	row.add_child(_preview)
	var next_btn = UIKit.make_button("▶", 48)
	next_btn.pressed.connect(func(): _shift_color(1))
	row.add_child(next_btn)
	_color_name_label = UIKit.make_label(str(_color_names[_color_idx]))
	_color_name_label.add_theme_color_override("font_color", UIKit.ACCENT)
	row.add_child(_color_name_label)

	_nation_label = _layer_row(box, Locale.t("ux_name_nation_style"), func(d): _shift_enum("nation", d))
	_field_label = _layer_row(box, Locale.t("ux_name_field_split"), func(d): _shift_enum("field", d))
	_partition_label = _layer_row(box, Locale.t("ux_name_partition"), func(d): _shift_enum("partition", d))
	_charge_label = _layer_row(box, Locale.t("ux_name_ordinary"), func(d): _shift_enum("charge", d))
	_border_label = _layer_row(box, Locale.t("ux_name_border"), func(d): _shift_enum("border", d))
	_emblem_label = _layer_row(box, Locale.t("ux_name_emblem"), func(d): _shift_enum("emblem", d))

	_build_nation_preset_strip(box)
	var preset_btn = UIKit.make_button(Locale.t("ux_name_nation_preset_btn"), 280)
	preset_btn.name = "NationPresetBtn"
	preset_btn.custom_minimum_size = Vector2(240, 48)
	preset_btn.pressed.connect(func(): _on_apply_nation_preset(""))
	box.add_child(preset_btn)
	var rand_btn = UIKit.make_button(Locale.t("ux_name_nation_rand_btn"), 280)
	rand_btn.name = "NationRandBtn"
	rand_btn.custom_minimum_size = Vector2(240, 48)
	rand_btn.pressed.connect(_on_randomize_nation)
	box.add_child(rand_btn)
	resized.connect(_apply_layout)
	_apply_layout.call_deferred()

func _art_rect(min_size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = min_size
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t

func _name_field(parent: Container, title: String, value: String) -> LineEdit:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	col.add_child(UIKit.make_label(title))
	var e := LineEdit.new()
	e.text = value
	e.custom_minimum_size = Vector2(140, 48)
	e.text_changed.connect(func(_t): _on_name_typed())
	col.add_child(e)
	return e

## Wide (desktop, landscape phone): pane left, options right. Tall: pane on top, options below.
func _apply_layout() -> void:
	if _split == null:
		return
	var wide := size.x >= size.y * 1.05
	_split.vertical = not wide
	if wide:
		_pane.custom_minimum_size = Vector2(clampf(size.x * 0.42, 460.0, 820.0), 0)
		_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		_pane.custom_minimum_size = Vector2(0, 0)
		_pane.size_flags_vertical = Control.SIZE_FILL
		_art_row.custom_minimum_size = Vector2(0, clampf(size.y * 0.28, 160.0, 360.0))

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

func _build_nation_preset_strip(box: VBoxContainer) -> void:
	## Ten nation chips: tap one to apply that nation's recommended company banner.
	box.add_child(UIKit.make_label(Locale.t("ux_name_nation_preset_strip")))
	var strip := HBoxContainer.new()
	strip.name = "NationPresetStrip"
	strip.add_theme_constant_override("separation", 6)
	box.add_child(strip)
	for nid in _nations:
		var mark: Dictionary = CKCourtChrome.NATION_MARK.get(str(nid), {"letters": str(nid).substr(0, 2).to_upper()})
		var btn := Button.new()
		btn.name = "NationPreset_%s" % str(nid)
		btn.text = str(mark.get("letters", str(nid).substr(0, 2).to_upper()))
		btn.custom_minimum_size = Vector2(52, 44)
		btn.focus_mode = Control.FOCUS_ALL
		var st := CKHeraldry.nation_style(str(nid))
		btn.tooltip_text = Locale.t("ux_nation_preset_tip", [str(st.get("zh", nid))])
		var ink_s := str(mark.get("ink", "")).strip_edges()
		var ink := Color(ink_s) if ink_s != "" else Color(0.431, 0.831, 1.0)
		btn.add_theme_color_override("font_color", ink)
		btn.add_theme_color_override("font_hover_color", ink.lightened(0.15))
		var captured := str(nid)
		btn.pressed.connect(func(): _on_apply_nation_preset(captured))
		strip.add_child(btn)


func _on_apply_nation_preset(nid: String = "") -> void:
	## Deterministic nation recommended suit (ash cloth + nation heart/emblem/ordinary).
	var id := nid.strip_edges()
	if id == "":
		id = str(_nations[_nation_idx]) if _nations.size() > 0 else "ashbanner"
	var nix := _nations.find(id)
	if nix >= 0:
		_nation_idx = nix
	var mark: Dictionary = CKCourtChrome.NATION_MARK.get(id, {})
	var ink := str(mark.get("ink", "")).strip_edges()
	var preset := CKHeraldry.company_preset_from_nation(id, ink)
	_load_from_banner_spec(preset)
	# Keep nation index even if banner_spec.nation was remapped.
	if nix >= 0:
		_nation_idx = nix
	if _preview:
		_preview.color = Color(str(_colors[_color_idx]))
	if _color_name_label:
		_color_name_label.text = str(_color_names[_color_idx])
	_refresh_preview_art()


func _on_randomize_nation() -> void:
	var nid := str(_nations[_nation_idx])
	var raw := CKHeraldry.randomize_for_nation(nid, GameState.rng if GameState.get("rng") else null)
	# Remap onto company ash cloth so preview/_current_spec stay honest (B-09).
	var mark: Dictionary = CKCourtChrome.NATION_MARK.get(nid, {})
	var ink := str(mark.get("ink", "")).strip_edges()
	var heart := ink if ink != "" else str(raw.get("ordinary_tincture", ""))
	var eid := CKHeraldry.company_emblem_id(str(raw.get("emblem", "ring")))
	var chs: Array = raw.get("charges", [])
	if not chs.is_empty() and typeof(chs[0]) == TYPE_DICTIONARY:
		eid = CKHeraldry.company_emblem_id(str((chs[0] as Dictionary).get("id", eid)))
	var preset := CKHeraldry.company_preset_from_nation(nid, heart)
	# Keep the randomized division/ordinary/partition/emblem (not the deterministic defaults).
	preset["division"] = str(raw.get("division", preset.get("division", "solid")))
	preset["field"] = preset["division"] if str(preset["division"]) in ["solid", "per_fess", "per_pale"] else "solid"
	preset["partition_line"] = str(raw.get("partition_line", "straight"))
	preset["ordinary"] = str(raw.get("ordinary", "none"))
	preset["charge"] = preset["ordinary"] if str(preset["ordinary"]) in ["none", "fess", "pale", "bend", "chevron", "pale_thin"] else "none"
	preset["emblem"] = eid
	preset["charges"] = [{"id": eid, "tincture": str(preset.get("ordinary_tincture", heart)), "placement": "center"}]
	preset["emblem_color"] = str(preset.get("ordinary_tincture", heart))
	preset = BannerSpec.normalize(preset)
	_load_from_banner_spec(preset)
	if _preview:
		_preview.color = Color(str(_colors[_color_idx]))
	if _color_name_label:
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

func _on_name_typed() -> void:
	## Typing only needs the banner tag + raise-button state — not a full portrait rebuild.
	var s := _surname.text.strip_edges() if _surname else ""
	if _banner:
		BannerName.attach(_banner, s)
	_sync_start()

func _refresh_preview_art() -> void:
	_sync_layer_labels()
	var spec := _current_spec()
	var prev_c = GameState.crest_color
	var prev_s = GameState.surname
	var prev_b = GameState.banner_spec.duplicate(true)
	GameState.crest_color = _heart()
	GameState.banner_spec = spec
	GameState.surname = _surname.text.strip_edges() if _surname else ""
	## Keep portrait mem/caches: wiping them re-lists thousands of bank plates on Android.
	_banner.texture = UnitArt.banner_layers(spec, 280, 400)
	BannerName.attach(_banner, GameState.surname)
	if _shield:
		_shield.texture = ImageTexture.create_from_image(BannerSpec.compose_shield(spec, 240, 280))
	var faces_before := _faces.size()
	_ensure_faces()
	if _face == null and not _faces.is_empty():
		_face = _faces[_face_idx]
	if _face != null:
		_face.name = GameState.surname + (_given.text.strip_edges() if _given else "烬行")
		_face.gender = _gender
	_portrait.texture = UnitArt.unit_portrait(_face) if _face else null
	## Thumbs only when the four face seeds changed (gender / reroll), not every colour tick.
	if faces_before != _faces.size() or _face_btns_need_paint():
		_paint_face_thumbs()
	_sync_gender_btns()
	if _warn:
		var bits: PackedStringArray = []
		if not BannerSpec.contrast_ok(spec):
			bits.append(Locale.t("ux_name_contrast"))
		# B-07: the grey cloth is outside the metal/colour rule; only far-sight contrast is flagged.
		_warn.text = " · ".join(bits)
		_warn.add_theme_color_override("font_color", UIKit.DANGER if not bits.is_empty() else UIKit.OK)
		if bits.is_empty():
			_warn.text = Locale.t("ux_heraldry_ok")
	GameState.crest_color = prev_c
	GameState.surname = prev_s
	GameState.banner_spec = prev_b
	_sync_start()

func _clear_face_thumb_icons() -> void:
	for tb in _face_btns:
		if tb is Button:
			(tb as Button).icon = null

func _face_btns_need_paint() -> bool:
	if _face_btns.is_empty() or _faces.size() != 4:
		return false
	for i in mini(4, _face_btns.size()):
		var tb: Button = _face_btns[i]
		if tb.icon == null:
			return true
	return false

func _sync_start() -> void:
	if _start_btn == null or _surname == null or _given == null:
		return
	if _reedit:
		_start_btn.disabled = false
		return
	var missing := ""
	if _surname.text.strip_edges() == "":
		missing = Locale.t("ux_name_need_surname")
	elif _given.text.strip_edges() == "":
		missing = Locale.t("ux_name_need_given")
	_start_btn.disabled = missing != ""
	if missing != "" and _warn:
		_warn.text = missing
		_warn.add_theme_color_override("font_color", UIKit.DANGER)

func _on_start() -> void:
	if _reedit:
		_save_reedit()
		return
	var g = _given.text.strip_edges()
	var s = _surname.text.strip_edges()
	if g == "" or s == "":
		_sync_start()
		return
	var spec := _current_spec()
	GameState.new_game(g, s, _heart())
	GameState.banner_spec = spec
	GameState.ensure_unique_arms()  # company banner is set once here; a colliding family core re-rolls
	GameState.crest_color = _heart()
	var lead: CKCharacter = GameState.get_leader()
	if lead != null and _face != null:
		lead.gender = _gender
		lead.genome = _face.genome.duplicate(true)
		lead.appearance = _face.appearance.duplicate(true)
		CKGenomePortrait.clear_mem()
		# Marriage candidates flip to the opposite sex of the captain (character_factory).
		GameState.refresh_marriage_candidates()
	UnitArt.clear_cache()
	GameState.save_game()
	CKNav.replace("res://scenes/story/chapter0.tscn")


## Hub / settings re-open: load current 团徽, hide founding-only controls, save back to hub.
func _apply_reedit_mode() -> void:
	_load_from_banner_spec(BannerSpec.normalize(GameState.banner_spec if typeof(GameState.banner_spec) == TYPE_DICTIONARY else {}))
	if _surname:
		_surname.text = str(GameState.surname)
		_surname.editable = false
	if _given:
		var lead: CKCharacter = GameState.get_leader()
		_given.text = str(lead.name) if lead != null else ""
		_given.editable = false
	# Founding-only: gender / face stay hidden in reedit — cloth only.
	for n in ["GenderRow", "FaceRow"]:
		var node := find_child(n, true, false)
		if node:
			node.visible = false
	# Also hide the gender/face section labels that sit just above those rows.
	if _opts != null:
		for child in _opts.get_children():
			if child is Label:
				var t := str(child.text)
				if t == Locale.t("ux_name_gender") or t == Locale.t("ux_name_face"):
					child.visible = false
	if _start_btn:
		_start_btn.text = Locale.t("ux_banner_reedit_save")
		_start_btn.disabled = false
	if _back_btn:
		# Drop founding TITLE hop; return to hub stack.
		for c in _back_btn.pressed.get_connections():
			_back_btn.pressed.disconnect(c["callable"])
		_back_btn.pressed.connect(func(): CKNav.up())
	if _warn:
		_warn.text = Locale.t("ux_banner_reedit_hint")
		_warn.add_theme_color_override("font_color", UIKit.ACCENT)


func _nearest_color_idx(hex: String) -> int:
	var want := hex.strip_edges().to_lower()
	if want == "":
		return _color_idx
	if not want.begins_with("#"):
		want = "#" + want
	for i in _colors.size():
		var c := str(_colors[i]).to_lower()
		if c == want or c.trim_prefix("#") == want.trim_prefix("#"):
			return i
	var target := Color(want)
	var best := _color_idx
	var best_d := 999.0
	for i in _colors.size():
		var c := Color(str(_colors[i]))
		var d := absf(c.r - target.r) + absf(c.g - target.g) + absf(c.b - target.b)
		if d < best_d:
			best_d = d
			best = i
	return best


func _load_from_banner_spec(spec: Dictionary) -> void:
	if spec.is_empty():
		return
	var div := str(spec.get("division", spec.get("field", "solid")))
	_field_idx = maxi(0, _divisions.find(div))
	var part := str(spec.get("partition_line", "straight"))
	_partition_idx = maxi(0, _partitions.find(part))
	var ord := str(spec.get("ordinary", spec.get("charge", "none")))
	_charge_idx = maxi(0, _ordinaries.find(ord))
	var heart := str(spec.get("charge_color", spec.get("ordinary_tincture", spec.get("emblem_color", ""))))
	if heart.strip_edges() == "":
		heart = str(spec.get("field_a", ""))
	_color_idx = _nearest_color_idx(heart)
	var border := str(spec.get("border", "none"))
	var bix := BannerSpec.BORDERS.find(border)
	_border_idx = maxi(0, bix)
	var eid := str(spec.get("emblem", "ring"))
	var chs: Array = spec.get("charges", [])
	if not chs.is_empty() and typeof(chs[0]) == TYPE_DICTIONARY:
		eid = str((chs[0] as Dictionary).get("id", eid))
	eid = CKHeraldry.company_emblem_id(eid)
	var eix := BannerSpec.EMBLEMS.find(eid)
	_emblem_idx = maxi(0, eix if eix >= 0 else BannerSpec.EMBLEMS.find("ring"))
	var nid := str(spec.get("nation", ""))
	var nix := _nations.find(nid)
	if nix >= 0:
		_nation_idx = nix
	if _preview:
		_preview.color = Color(str(_colors[_color_idx]))
	if _color_name_label:
		_color_name_label.text = str(_color_names[_color_idx])


func _save_reedit() -> void:
	var spec := _current_spec()
	if not BannerSpec.contrast_ok(spec):
		if _warn:
			_warn.text = Locale.t("ux_name_contrast")
			_warn.add_theme_color_override("font_color", UIKit.DANGER)
		Sfx.miss()
		return
	GameState.banner_spec = spec
	GameState.crest_color = _heart()
	UnitArt.clear_cache()
	GameState.save_game()
	Sfx.confirm()
	CKNav.up()


func _set_gender(g: String) -> void:
	if g != "m" and g != "f":
		return
	if _gender == g and not _faces.is_empty():
		_sync_gender_btns()
		return
	_gender = g
	_faces.clear()
	_face = null
	_face_idx = 0
	_clear_face_thumb_icons()
	_refresh_preview_art()

func _reroll_faces() -> void:
	_face_gen += 1
	_faces.clear()
	_face = null
	_clear_face_thumb_icons()
	_refresh_preview_art()

func _pick_face(idx: int) -> void:
	_ensure_faces()
	if idx < 0 or idx >= _faces.size():
		return
	_face_idx = idx
	_face = _faces[idx]
	_refresh_preview_art()

func _ensure_faces() -> void:
	if _faces.size() == 4:
		return
	_faces.clear()
	# Fixed ids so the four presets stay distinct across refreshes of the same gender.
	var seeds: Array
	if _gender == "m":
		seeds = ["founding_m0", "founding_m1", "founding_m2", "founding_m3"]
	else:
		seeds = ["founding_f0", "founding_f1", "founding_f2", "founding_f3"]
	var looks := [
		{"hair": "ash_brown", "eyes": "river_blue", "brow": "thick", "scar": "none"},
		{"hair": "ink_black", "eyes": "slate", "brow": "straight", "scar": "none"},
		{"hair": "wheat", "eyes": "pine", "brow": "arch", "scar": "none"},
		{"hair": "frost_silver", "eyes": "dusk", "brow": "thick", "scar": "none"},
	]
	for i in 4:
		# Build locally — do not call make_leader (it bumps id seq and writes GameState).
		var c := CKCharacter.new()
		c.id = "%s_g%d" % [str(seeds[i]), _face_gen]
		c.cast_key = "leader"
		c.name = "烬行"
		c.gender = _gender
		c.age = 22
		c.is_leader = true
		c.job_id = "squire"
		c.rank = "knight"
		c.blood_mix = {"common_ash": 0.6, "river_ward": 0.4}
		c.traits = ["brave", "heir_mark"]
		c.appearance = looks[i].duplicate()
		c.birthday_month = 3
		c.ensure_genome()
		_faces.append(c)
	_face_idx = clampi(_face_idx, 0, 3)
	_face = _faces[_face_idx]

func _paint_face_thumbs() -> void:
	if _face_btns.is_empty() or _faces.size() != 4:
		return
	for i in 4:
		var tb: Button = _face_btns[i]
		var tex: Texture2D = UnitArt.unit_portrait(_faces[i])
		tb.icon = tex
		# Selected card gets a brighter modulate; others stay dimmer.
		tb.modulate = Color(1, 1, 1, 1) if i == _face_idx else Color(0.72, 0.72, 0.78, 1)

func _sync_gender_btns() -> void:
	UIKit.mark_choice(_gender_m_btn, _gender == "m")
	UIKit.mark_choice(_gender_f_btn, _gender == "f")

func apply_mobile_layout() -> void:
	_apply_layout()

var _more_hint: Label = null

## Phone: the options column scrolls; the hint under it stays lit until the player reaches the end.
func _sync_more_hint() -> void:
	if _more_hint == null or _scroll == null:
		return
	var bar := _scroll.get_v_scroll_bar()
	var more := bar != null and bar.max_value - bar.page > 4.0 and _scroll.scroll_vertical < bar.max_value - bar.page - 4.0
	_more_hint.text = Locale.t("ux_name_more_hint") if more else ""

func _process(_d: float) -> void:
	_sync_more_hint()
	var f := get_viewport().gui_get_focus_owner()
	if f is LineEdit:
		_last_edit_ms = Time.get_ticks_msec()

## Android back: closing the soft keyboard also sends back; never pop the pause menu here.
func nav_back() -> void:
	if Time.get_ticks_msec() - _last_edit_ms < 800:
		return
	if _reedit:
		CKNav.up()
		return
	CKNav.replace(CKNav.TITLE)
