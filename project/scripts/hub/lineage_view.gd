extends Control
## Genealogy overview: generation-banded portrait wall, info panel on the right.
## "详情" opens the focused lineage tree. "血脉详档" opens unit_dossier for the same person.
## Familyless roster stay on the banner band (旗徽); house members keep family arms (族徽).

const TREE_SCENE := "res://scenes/hub/lineage_tree.tscn"
const GRID := Rect2(24, 72, 820, 520)
const CELL := Vector2(136, 176)

var _scroll: ScrollContainer
var _grid: VBoxContainer
var _info: Control
var _selected: CKCharacter
var _members: Array = []
var _mob := false
var _info_rect := Rect2()
var _cols := 5
var _wall_people: Array = []
const CELL_M := Vector2(168, 236)

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
	CKHeraldryChrome.place_company_header(self, Vector2(800, 2), Vector2(44, 52))
	_scroll = ScrollContainer.new()
	_scroll.name = "LineageGridScroll"
	_scroll.position = GRID.position
	_scroll.size = GRID.size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.scroll_deadzone = 8
	add_child(_scroll)
	_cols = maxi(1, int(GRID.size.x / (CELL.x + 8.0)))
	_grid = VBoxContainer.new()
	_grid.name = "LineageGrid"
	_grid.add_theme_constant_override("separation", 12)
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid.custom_minimum_size.x = GRID.size.x
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
	if not MobilePage.active(self):
		return
	var first := not _mob
	_mob = true
	var w := MobilePage.width(self)
	var h := maxf(size.y, 720.0)
	var alive_n := 0
	for ch in GameState.characters.values():
		if ch.alive:
			alive_n += 1
	var info := "%s %d · %s" % [Locale.t("gen2_25"), alive_n, Calendar.label()]
	if first:
		MobilePage.top_bar(self, Locale.t("gen2_24") % GameState.surname, info, [[Locale.t("gen2_27"), _back]])
	# Mobile parity: refresh 团徽 header via Chrome (same core as desktop genealogy).
	CKHeraldryChrome.place_company_header(self, Vector2(w - 64.0, 6.0), Vector2(52, 60))
	# Keep a hard gap so band titles / cells never paint under the kin panel (mobile gate overlap).
	var iw := minf(470.0, maxf(360.0, w * 0.34))
	var gap := 28.0
	_info_rect = Rect2(w - iw - 24.0, MobilePage.TOP + 4.0, iw, h - MobilePage.TOP - 16.0)
	var gw := maxf(280.0, _info_rect.position.x - 24.0 - gap)
	var jy := h - MobilePage.HIT - 12.0
	_scroll.position = Vector2(24, MobilePage.TOP + 4.0)
	_scroll.size = Vector2(gw, maxf(160.0, jy - MobilePage.TOP - 16.0))
	_scroll.clip_contents = true
	_cols = maxi(1, int((gw + 10.0) / (CELL_M.x + 10.0)))
	_grid.custom_minimum_size.x = gw
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_grid.add_theme_constant_override("separation", 12)
	var jumps := get_node("LineageJumps") as HBoxContainer
	jumps.position = Vector2(24, jy)
	jumps.size = Vector2(gw, MobilePage.HIT)
	for b in jumps.get_children():
		var bt := b as Button
		bt.custom_minimum_size = Vector2(0, MobilePage.HIT)
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.add_theme_font_size_override("font_size", MobilePage.FONT)
	_refresh()
	_mobile_empty_hint(Rect2(24, MobilePage.TOP + 4.0 + CELL_M.y + 20.0, gw, jy - (MobilePage.TOP + CELL_M.y + 44.0)))

## Mobile audit v1: a one-person family left the whole tree area blank. Say what grows it.
func _mobile_empty_hint(r: Rect2) -> void:
	if _wall_people.size() > 1 or r.size.y < 120.0:
		return
	var v := MobilePage.panel(self, r, 18)
	(v.get_parent() as Control).name = "LineageEmptyHint"
	v.add_child(MobilePage.label(Locale.t("ux_lin_empty_title"), UIKit.TEXT, 26, false))
	v.add_child(MobilePage.label(Locale.t("ux_lin_empty_body"), UIKit.TEXT_DIM))
	MobilePage.spacer(v)
	var go := MobilePage.button(Locale.t("ux_lin_empty_go"), true, func(): CKNav.go("res://scenes/hub/marriage.tscn"), 260)
	go.name = "LineageGoMarry"
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(go)

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
	var leader = GameState.get_leader()
	_members = CKLineageInfo.family_of(GameState.characters, leader)
	var bands: Array = CKLineageInfo.wall_bands(GameState.characters, leader)
	_wall_people = []
	if bands.is_empty():
		var l := UIKit.body_label(Locale.t("gen2_32"), UIKit.TEXT_FAINT, 15)
		l.name = "LineageEmpty"
		l.position = GRID.position + Vector2(24, 40)
		l.size = Vector2(GRID.size.x - 48, 80)
		add_child(l)
	else:
		_grid.custom_minimum_size.x = maxf(_scroll.size.x, 200.0)
		for band in bands:
			_grid.add_child(_band(band))
	var pick: CKCharacter = _selected if _wall_has(_selected) else null
	if pick == null:
		pick = _find_wall(str(CKNav.params().get("focus", "")))
	if pick == null and GameState.has_meta("lineage_focus"):
		pick = _find_wall(str(GameState.get_meta("lineage_focus")))
	if pick == null and not _members.is_empty():
		pick = _members[0]
	if pick == null and not _wall_people.is_empty():
		pick = _wall_people[0]
	_selected = pick
	_render_info()

func _band(band: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.name = "GenBand_%s" % str(band.get("id", ""))
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	# Shrink: full-row band titles counted as overlap against the kin panel in mobile_gate.
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override("separation", 6)
	var title := UIKit.body_label(str(band.get("title", "")), UIKit.ACCENT, 15)
	title.name = "GenBandTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var title_h := 32.0 if _mob else 22.0
	if _mob:
		title.add_theme_font_size_override("font_size", MobilePage.FONT)
	# Ink-sized title only — never stretch under InfoHost.
	var title_w := 220.0 if _mob else 160.0
	title.custom_minimum_size = Vector2(title_w, title_h)
	title.size = Vector2(title_w, title_h)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.name = "GenGrid_%s" % str(band.get("id", ""))
	grid.columns = maxi(1, _cols)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 10 if _mob else 8)
	grid.add_theme_constant_override("v_separation", 10 if _mob else 8)
	box.add_child(grid)
	for c in band.get("people", []):
		_wall_people.append(c)
		grid.add_child(_cell(c))
	return box

func _wall_has(c) -> bool:
	return c != null and _wall_people.has(c)

func _find_wall(id: String) -> CKCharacter:
	if id == "":
		return null
	for c in _wall_people:
		if str(c.id) == id:
			return c
	return null

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
	por.position = Vector2(28, 6)
	b.add_child(por)
	var rel := _cell_label(CKLineageInfo.relation_label(GameState.characters, GameState.get_leader(), c), UIKit.ACCENT, 12)
	rel.name = "CellRelation"
	rel.position = Vector2(4, 98)
	b.add_child(rel)
	var nm := _cell_label(c.name, UIKit.TEXT if c.alive else UIKit.TEXT_FAINT, 13)
	nm.position = Vector2(4, 118)
	b.add_child(nm)
	var life := (Locale.t("gen2_21") % c.age) if c.alive else Locale.t("gen2_22")
	var tail := Locale.t("lin_minor") if c.age < Calendar.ADULT_AGE else c.rank_name()
	var meta := _cell_label("%s · %s" % [life, tail], UIKit.OK if c.alive else UIKit.TEXT_FAINT, 12)
	meta.name = "CellRank"
	meta.position = Vector2(4, 140)
	b.add_child(meta)
	if c.is_leader:
		var tc := UIKit.tag_chip(Locale.t("gen2_33"), UIKit.ACCENT)
		tc.position = Vector2(4, 4)
		tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tc)
	CKHeraldryField.attach_wall_tile_arms(b, c, CELL if not _mob else CELL_M, 6.0 if not _mob else 8.0)
	var badge := b.get_node_or_null("CellBadge")
	if badge != null:
		badge.set_meta("rank_id", str(c.rank))
	b.pressed.connect(func():
		UIFX.press_feedback(b)
		select(c))
	if _mob:
		b.custom_minimum_size = CELL_M
		por.position = Vector2(24, 8)
		por.scale = Vector2(1.5, 1.5)
		rel.position = Vector2(4, 148)
		nm.position = Vector2(4, 178)
		meta.position = Vector2(4, 208)
		for lab in [rel, nm, meta]:
			lab.add_theme_font_size_override("font_size", MobilePage.FONT)
			lab.size = Vector2(CELL_M.x - 8, 28)
			lab.custom_minimum_size = Vector2(CELL_M.x - 8, 28)
		for l in b.find_children("*", "Label", true, false):
			var lab2 := l as Label
			if lab2.get_theme_font_size("font_size") < MobilePage.FONT:
				lab2.add_theme_font_size_override("font_size", MobilePage.FONT)
			if lab2.size.y < 28.0:
				lab2.size.y = 28.0
				lab2.custom_minimum_size.y = 28.0
	return b

func _cell_label(text: String, col: Color, size: int) -> Label:
	var lab := UIKit.body_label(text, col, size)
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.clip_text = true
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.size = Vector2(CELL.x - 8, 20)
	lab.custom_minimum_size = Vector2(CELL.x - 8, 20)
	return lab

func select(c: CKCharacter) -> void:
	_selected = c
	if c != null:
		GameState.set_meta("lineage_focus", str(c.id))
	_render_info()

func _render_info() -> void:
	var dossier_text := ""
	var dossier_cb := Callable()
	if _selected != null:
		dossier_text = Locale.t("gen2_29")
		dossier_cb = Callable(self, "_open_dossier")
	if _mob:
		CKLineageInfo.render_mobile(_info, _selected, Locale.t("gen2_34"), open_details, _info_rect, dossier_text, dossier_cb)
	else:
		CKLineageInfo.render(_info, _selected, Locale.t("gen2_34"), open_details, dossier_text, dossier_cb)
	for n in find_children("*", "Button", true, false):
		if not str(n.name).begins_with("Avatar_"):
			continue
		var on: bool = _selected != null and str(n.get_meta("cid", "")) == str(_selected.id)
		var bg := Color(UIKit.ACCENT, 0.08) if on else Color(0.055, 0.067, 0.090, 0.92)
		var bd := UIKit.ACCENT if on else Color(1, 1, 1, 0.10)
		n.add_theme_stylebox_override("normal", UIKit.flat_box(bg, bd, 8, 2 if on else 1))

func open_details() -> bool:
	if _selected == null:
		return false
	Sfx.click()
	GameState.set_meta("lineage_focus", str(_selected.id))
	return CKNav.go(TREE_SCENE, {"focus": str(_selected.id)})

func _open_dossier() -> void:
	if _selected == null:
		return
	Sfx.click()
	CKLineageInfo.open_dossier(_selected, "res://scenes/hub/lineage_view.tscn")
