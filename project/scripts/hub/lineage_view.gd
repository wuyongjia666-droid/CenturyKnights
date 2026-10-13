extends Control
## Genealogy v2 overview (docs/design/genealogy-v2.md): avatar grid on the left, info panel on the right.
## "详情" opens scenes/hub/lineage_tree.tscn focused on the selected person.

const TREE_SCENE := "res://scenes/hub/lineage_tree.tscn"
const GRID := Rect2(24, 72, 820, 520)
const CELL := Vector2(112, 132)

var _scroll: ScrollContainer
var _grid: GridContainer
var _info: Control
var _selected: CKCharacter
var _members: Array = []
var _mob := false
var _info_rect := Rect2()
const CELL_M := Vector2(160, 204)

func _ready() -> void:
	_build()
	_refresh()

func _back() -> void:
	if str(GameState.chapter0_beat) in ["0.5", "0.55"]:
		get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
	else:
		CKNav.home()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()

func _build() -> void:
	UIKit.void_bg(self)
	var alive_n := 0
	for ch in GameState.characters.values():
		if ch.alive:
			alive_n += 1
	var chips := [[Locale.t("gen2_25"), "%d" % alive_n, UIKit.OK], [Locale.t("gen2_26"), Calendar.label(), UIKit.TEXT_DIM]]
	UIKit.top_bar(self, Locale.t("gen2_24") % GameState.surname, chips, Locale.t("gen2_27"), _back)
	var castle_arms := TextureRect.new()
	castle_arms.name = "CastleArms"
	castle_arms.texture = UnitArt.shield_arms(GameState.banner_spec if typeof(GameState.banner_spec) == TYPE_DICTIONARY else {}, 44, 52)
	castle_arms.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	castle_arms.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	castle_arms.position = Vector2(800, 2)
	castle_arms.size = Vector2(44, 52)
	castle_arms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(castle_arms)
	_scroll = ScrollContainer.new()
	_scroll.name = "LineageGridScroll"
	_scroll.position = GRID.position
	_scroll.size = GRID.size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.scroll_deadzone = 8
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "LineageGrid"
	_grid.columns = int(GRID.size.x / (CELL.x + 8))
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)
	_info = Control.new()
	_info.name = "InfoHost"
	_info.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_info)
	var jumps := HBoxContainer.new()
	jumps.name = "LineageJumps"
	jumps.position = Vector2(24, 604)
	jumps.add_theme_constant_override("separation", 8)
	add_child(jumps)
	var codex := UIKit.ghost_button(Locale.t("gen2_28"), 140, 48)
	codex.name = "OpenCodex"
	codex.pressed.connect(func():
		Sfx.click()
		CKNav.go("res://scenes/hub/bloodline_codex.tscn"))
	jumps.add_child(codex)
	var dossier := UIKit.ghost_button(Locale.t("gen2_29"), 140, 48)
	dossier.name = "OpenDossier"
	dossier.pressed.connect(func(): _open_dossier())
	jumps.add_child(dossier)
	var news := UIKit.ghost_button(Locale.t("gen2_30"), 120, 48)
	news.name = "OpenNews"
	news.pressed.connect(func():
		Sfx.click()
		CKNav.go("res://scenes/hub/court_news.tscn"))
	jumps.add_child(news)
	var pace := UIKit.ghost_button(_pace_label(), 168, 48)
	pace.name = "FastFamily"
	pace.pressed.connect(func():
		CKFamilyState.set_fast_family(GameState, not CKFamilyState.fast_family(GameState))
		pace.text = _pace_label()
		Sfx.click())
	jumps.add_child(pace)
	if not DeviceProfile.is_mobile():
		UIKit.footer_bar(self, [["A", Locale.t("gen2_31")], ["ESC", Locale.t("gen2_27")]], "GENEALOGY v2")
	UIFX.page_enter(self)

func _pace_label() -> String:
	return Locale.t("fertility_to_term") if CKFamilyState.fast_family(GameState) else Locale.t("fertility_to_fast")

func apply_mobile_layout() -> void:
	MobileLayout.pin_footer(get_node_or_null("StitchFooter"))
	if _mob or not MobilePage.active(self):
		return
	_mob = true
	var w := MobilePage.width(self)
	var alive_n := 0
	for ch in GameState.characters.values():
		if ch.alive:
			alive_n += 1
	var info := "%s %d · %s" % [Locale.t("gen2_25"), alive_n, Calendar.label()]
	MobilePage.top_bar(self, Locale.t("gen2_24") % GameState.surname, info, [[Locale.t("gen2_27"), _back]])
	(get_node("CastleArms") as Control).visible = false
	var iw := 470.0
	_info_rect = Rect2(w - iw - 24.0, MobilePage.TOP + 4.0, iw, 720.0 - MobilePage.TOP - 16.0)
	var gw := _info_rect.position.x - 48.0
	var jy := 720.0 - MobilePage.HIT - 12.0
	_scroll.position = Vector2(24, MobilePage.TOP + 4.0)
	_scroll.size = Vector2(gw, jy - MobilePage.TOP - 16.0)
	_grid.columns = maxi(1, int((gw + 10.0) / (CELL_M.x + 10.0)))
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	var jumps := get_node("LineageJumps") as HBoxContainer
	jumps.position = Vector2(24, jy)
	jumps.size = Vector2(gw, MobilePage.HIT)
	for b in jumps.get_children():
		var bt := b as Button
		bt.custom_minimum_size = Vector2(0, MobilePage.HIT)
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.add_theme_font_size_override("font_size", MobilePage.FONT)
	_refresh()

func members() -> Array:
	return _members

func selected() -> CKCharacter:
	return _selected

func _refresh() -> void:
	for n in _grid.get_children():
		_grid.remove_child(n)
		n.queue_free()
	var old := get_node_or_null("LineageEmpty")
	if old:
		old.queue_free()
	_members = CKLineageInfo.family_of(GameState.characters, GameState.get_leader())
	if _members.is_empty():
		var l := UIKit.body_label(Locale.t("gen2_32"), UIKit.TEXT_FAINT, 15)
		l.name = "LineageEmpty"
		l.position = GRID.position + Vector2(24, 40)
		l.size = Vector2(GRID.size.x - 48, 80)
		add_child(l)
	for c in _members:
		_grid.add_child(_cell(c))
	if _selected == null or not _members.has(_selected):
		_selected = _members[0] if not _members.is_empty() else null
	_render_info()

func _cell(c: CKCharacter) -> Button:
	var b := Button.new()
	b.name = "Avatar_%s" % c.id
	b.set_meta("cid", c.id)
	b.custom_minimum_size = CELL
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_PASS  # drags reach the ScrollContainer
	b.add_theme_stylebox_override("normal", UIKit.flat_box(Color(0.055, 0.067, 0.090, 0.92), Color(1, 1, 1, 0.10), 8))
	b.add_theme_stylebox_override("hover", UIKit.flat_box(Color(0.07, 0.09, 0.12, 0.95), Color(UIKit.ACCENT, 0.45), 8))
	b.add_theme_stylebox_override("pressed", UIKit.flat_box(Color(UIKit.ACCENT, 0.10), Color(UIKit.ACCENT, 0.8), 8, 2))
	b.add_theme_stylebox_override("focus", UIKit._focus_ring(UIKit.FOCUS_RING, 10))
	var por := CKLineageInfo.portrait_rect(c, Vector2(80, 88))
	por.position = Vector2(16, 6)
	b.add_child(por)
	var nm := UIKit.body_label(c.name, UIKit.TEXT if c.alive else UIKit.TEXT_FAINT, 13)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.position = Vector2(4, 96)
	nm.size = Vector2(CELL.x - 8, 18)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nm)
	var sub := UIKit.body_label((Locale.t("gen2_21") % c.age) if c.alive else Locale.t("gen2_22"), UIKit.OK if c.alive else UIKit.TEXT_FAINT, 11)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(4, 114)
	sub.size = Vector2(CELL.x - 8, 14)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sub)
	if c.is_leader:
		var tc := UIKit.tag_chip(Locale.t("gen2_33"), UIKit.ACCENT)
		tc.position = Vector2(4, 4)
		tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tc)
	b.pressed.connect(func():
		UIFX.press_feedback(b)
		select(c))
	if _mob:
		b.custom_minimum_size = CELL_M
		por.position = Vector2(20, 8)
		por.scale = Vector2(1.5, 1.5)
		for pair in [[nm, 142.0], [sub, 172.0]]:
			var l := pair[0] as Label
			l.add_theme_font_size_override("font_size", MobilePage.FONT)
			l.position = Vector2(4, pair[1])
			l.size = Vector2(CELL_M.x - 8, 30)
		for l in b.find_children("*", "Label", true, false):
			if (l as Label).get_theme_font_size("font_size") < MobilePage.FONT:
				(l as Label).add_theme_font_size_override("font_size", MobilePage.FONT)
	return b

func select(c: CKCharacter) -> void:
	_selected = c
	_render_info()

func _render_info() -> void:
	if _mob:
		CKLineageInfo.render_mobile(_info, _selected, Locale.t("gen2_34"), open_details, _info_rect)
	else:
		CKLineageInfo.render(_info, _selected, Locale.t("gen2_34"), open_details)
	for n in _grid.get_children():
		var on: bool = _selected != null and str(n.get_meta("cid", "")) == str(_selected.id)
		var bg := Color(UIKit.ACCENT, 0.08) if on else Color(0.055, 0.067, 0.090, 0.92)
		var bd := UIKit.ACCENT if on else Color(1, 1, 1, 0.10)
		n.add_theme_stylebox_override("normal", UIKit.flat_box(bg, bd, 8, 2 if on else 1))

func open_details() -> bool:
	if _selected == null:
		return false
	Sfx.click()
	return CKNav.go(TREE_SCENE, {"focus": str(_selected.id)})

func _open_dossier() -> void:
	if _selected == null:
		return
	Sfx.click()
	GameState.set_meta("dossier_id", _selected.id)
	GameState.set_meta("dossier_back", "res://scenes/hub/lineage_view.tscn")
	get_tree().change_scene_to_file("res://scenes/hub/unit_dossier.tscn")
