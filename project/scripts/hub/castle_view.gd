extends Control
## Castle overview (audit #1/#2). Nine building cards with the v92 tier art.
## Every card opens that building's own page; annexes open scenes/hub/annex.tscn.
## Back goes through CKNav (castle hub by default), never to works.

const SLOTS := ["hall", "barracks", "market", "forge", "shrine", "infirmary", "academy", "treasury", "embassy"]
const ART := "res://assets/art/castle/v92_castle_%s_t%d.webp"
const ANNEX_SCENE := "res://scenes/hub/annex.tscn"
const PAGE := {
	"hall": "res://scenes/hub/works.tscn",
	"barracks": "res://scenes/hub/train.tscn",
	"market": "res://scenes/hub/market.tscn",
	"forge": "res://scenes/hub/forge.tscn",
	"shrine": "res://scenes/hub/shrine.tscn",
}
const CARD := Vector2(400, 196)
const GAP := Vector2(16, 10)
const ORIGIN := Vector2(24, 84)

var _msg: Label
var _cards: Dictionary = {}   # id -> {"art": {tier: TextureRect}, "ghost": TextureRect, "lv": Label, "up": Button, "go": Button}

static func art_key(id: String) -> String:
	return "vault" if id == "treasury" else id

static func is_annex(id: String) -> bool:
	return CKCastleServices.ANNEX.has(id)

static func page_for(id: String) -> String:
	return ANNEX_SCENE if is_annex(id) else str(PAGE.get(id, ""))

static func name_of(id: String) -> String:
	if is_annex(id):
		return Locale.t(str(CKCastleServices.ANNEX[id]))
	return str(GameState.BUILDING_NAMES.get(id, id))

func _ready() -> void:
	UIKit.void_bg(self)
	if MobilePage.active(self):
		_m_build()
		resized.connect(_m_relayout)
		_place_castle_view_crests()
		refresh()
		return
	UIKit.top_bar(self, Locale.t("a1_view_title"), UIKit.std_resource_chips(), Locale.t("a1_view_back"), _back)
	_msg = UIKit.body_label(Locale.t("a1_view_head"), UIKit.TEXT_DIM, 13)
	_msg.name = "Msg"
	_msg.position = Vector2(ORIGIN.x, 60)
	_msg.size = Vector2(1232, 20)
	add_child(_msg)
	for i in SLOTS.size():
		_card(str(SLOTS[i]), i)
	_place_castle_view_crests()
	refresh()


func _place_castle_view_crests() -> void:
	var mob := DeviceProfile.is_mobile()
	var at := Vector2(1120, 8) if not mob else Vector2(maxf(20.0, MobilePage.width(self) - 120.0), 4)
	var sh := Vector2(36, 44) if not mob else Vector2(32, 40)
	CKHeraldryChrome.place_castle_view_crest_strip(self, at, sh, Vector2(24, 34) if not mob else Vector2(22, 30))

func _back() -> void:
	CKNav.up()

func nav_back() -> void:
	_back()

func _card(id: String, i: int) -> void:
	var pos := ORIGIN + Vector2(float(i % 3) * (CARD.x + GAP.x), float(i / 3) * (CARD.y + GAP.y))
	var p := UIKit.panel_at(self, Rect2(pos, CARD), 10)
	p.name = "card_%s" % id
	var entry := {"art": {}}
	var ghost := TextureRect.new()
	ghost.name = "ghost_%s" % id
	_fit_art(ghost, pos + Vector2(8, 8))
	ghost.texture = _tex(id, 1)
	ghost.modulate = Color(1, 1, 1, 0.22)
	add_child(ghost)
	entry.ghost = ghost
	for tier in [1, 2, 3]:
		var t := TextureRect.new()
		t.name = "sil_%s_%d" % [id, tier]
		_fit_art(t, pos + Vector2(8, 8))
		t.texture = _tex(id, tier)
		t.visible = false
		add_child(t)
		entry.art[tier] = t
	var hot := Button.new()   # the art itself is a big tap target
	hot.flat = true
	hot.name = "hot_%s" % id
	hot.position = pos + Vector2(8, 8)
	hot.size = Vector2(196, 180)
	hot.focus_mode = Control.FOCUS_NONE
	hot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hot.tooltip_text = name_of(id)
	# visible tap feedback on the art: frost frame on hover, brighter on press
	hot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hot.add_theme_stylebox_override("hover", UIKit.flat_box(Color(UIKit.ACCENT, 0.06), Color(UIKit.ACCENT, 0.55), 6))
	hot.add_theme_stylebox_override("pressed", UIKit.flat_box(Color(UIKit.ACCENT, 0.14), Color(UIKit.ACCENT, 0.9), 6))
	hot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	hot.pressed.connect(func(): _open(id))
	add_child(hot)
	var x := pos.x + 216
	var title := UIKit.title_label(name_of(id), 19, UIKit.TEXT)
	title.position = Vector2(x, pos.y + 10)
	title.size = Vector2(176, 28)
	add_child(title)
	var lv := UIKit.body_label("", UIKit.ACCENT, 13)
	lv.position = Vector2(x, pos.y + 40)
	lv.size = Vector2(176, 20)
	lv.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(lv)
	entry.lv = lv
	var d := UIKit.body_label(Locale.t("a1_desc_%s" % id), UIKit.TEXT_DIM, 12)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.position = Vector2(x, pos.y + 62)
	d.size = Vector2(172, 70)
	add_child(d)
	var go := UIKit.ghost_button(Locale.t("a1_enter"), 84, 48)
	go.name = "go_%s" % id
	go.position = Vector2(x, pos.y + CARD.y - 56)
	go.pressed.connect(func(): _open(id))
	add_child(go)
	entry.go = go
	var up := UIKit.make_accent_button(Locale.t("a1_upgrade"), 84)
	up.name = "up_%s" % id
	up.custom_minimum_size = Vector2(84, 48)
	up.position = Vector2(x + 92, pos.y + CARD.y - 56)
	up.size = Vector2(84, 48)
	up.pressed.connect(func(): _upgrade(id))
	add_child(up)
	entry.up = up
	_cards[id] = entry

func _fit_art(t: TextureRect, at: Vector2) -> void:
	t.position = at
	t.size = Vector2(196, 180)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.clip_contents = true

func _tex(id: String, tier: int) -> Texture2D:
	var path := ART % [art_key(id), tier]
	return load(path) if ResourceLoader.exists(path) else null

func level_of(id: String) -> int:
	if is_annex(id):
		return CKCastleServices.annex_level(GameState, id)
	return GameState.building_level(id)

func max_of(id: String) -> int:
	return CKCastleServices.ANNEX_MAX if is_annex(id) else int(GameState.BUILDING_MAX)

func refresh() -> void:
	for id in SLOTS:
		var e: Dictionary = _cards.get(id, {})
		if e.is_empty():
			continue
		var lv := level_of(str(id))
		var show_tier := CKCastleServices.tier_of(lv)
		for tier in [1, 2, 3]:
			(e.art[tier] as TextureRect).visible = tier == show_tier
		(e.ghost as TextureRect).visible = show_tier == 0
		var mx := max_of(str(id))
		(e.lv as Label).text = Locale.t("a1_unbuilt") if lv <= 0 else "%s / %d" % [Locale.t("a1_level") % lv, mx]
		(e.lv as Label).add_theme_color_override("font_color", UIKit.TEXT_FAINT if lv <= 0 else UIKit.ACCENT)
		var up := e.up as Button
		up.disabled = lv >= mx
		up.text = Locale.t("a1_maxed") if lv >= mx else (Locale.t("a1_build") if lv <= 0 else Locale.t("a1_upgrade"))
		(e.go as Button).disabled = lv <= 0
	if _m_scroll != null:
		var bar := get_node_or_null("MobileTopBar")
		if bar and bar.get_child_count() > 1:
			var inf := bar.get_child(1) as Label
			var raw := _m_info()
			inf.set_meta("m_raw", raw)
			inf.text = raw

func layer_visible(id: String, tier: int) -> bool:
	var e: Dictionary = _cards.get(id, {})
	if e.is_empty():
		return false
	return (e.art[tier] as TextureRect).visible

func _open(id: String) -> void:
	if level_of(id) <= 0:
		_say(Locale.t("a1_unbuilt_hint"), false)
		Sfx.miss()
		return
	var path := page_for(id)
	if path == "":
		return
	CKNav.go(path, {"annex": id} if is_annex(id) else {})

func _upgrade(id: String) -> void:
	var r: Dictionary = CKCastleServices.upgrade_annex(GameState, id) if is_annex(id) else GameState.upgrade_building(id)
	var ok := bool(r.get("ok", false))
	_say(str(r.get("msg", "")), ok)
	if ok:
		Sfx.confirm()
		GameState.save_game()
	else:
		Sfx.miss()
	refresh()

## ── Phone landscape (docs/design/mobile-landscape.md): one 76px top bar, a status line, then a
## scrolling 3-column grid of building cards built from containers so text wraps instead of
## running into the buttons. Tapping the art or 「进入」 opens the building; only the accent
## 「升级」 button on the far right upgrades (2026-10-12: every tap used to land on upgrade).
var _m_scroll: ScrollContainer
var _m_grid: GridContainer

func apply_mobile_layout() -> void:
	if MobilePage.active(self):
		_place_castle_view_crests()
		_m_relayout()

func _m_build() -> void:
	MobilePage.top_bar(self, Locale.t("a1_view_title"), _m_info(), [[Locale.t("a1_view_back"), _back]])
	_msg = MobilePage.label(Locale.t("a1_view_head"), UIKit.TEXT_DIM, MobilePage.FONT, false)
	_msg.name = "Msg"
	_msg.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_msg.clip_text = true
	add_child(_msg)
	_m_scroll = ScrollContainer.new()
	_m_scroll.name = "MobileGrid"
	_m_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_m_scroll)
	_m_grid = GridContainer.new()
	_m_grid.columns = 3
	_m_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m_grid.add_theme_constant_override("h_separation", 14)
	_m_grid.add_theme_constant_override("v_separation", 14)
	_m_scroll.add_child(_m_grid)
	for id in SLOTS:
		_m_card(str(id))
	_m_relayout()

func _m_info() -> String:
	return Locale.t("mw_41e31e6c") % [GameState.silver, GameState.food, GameState.iron, Calendar.label()]

func _m_relayout() -> void:
	if _m_scroll == null:
		return
	var w := MobilePage.width(self)
	var h := size.y if size.y > 400.0 else 720.0
	var bar := get_node_or_null("MobileTopBar") as Control
	if bar:
		bar.size.x = w - 50.0
	_msg.position = Vector2(26, MobilePage.TOP)
	_msg.size = Vector2(w - 52.0, 30)
	var top := MobilePage.TOP + 40.0
	_m_scroll.position = Vector2(20, top)
	_m_scroll.size = Vector2(w - 40.0, h - top - 12.0)

func _m_card(id: String) -> void:
	var p := PanelContainer.new()
	p.name = "card_%s" % id
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UIKit.flat_box(Color(0.055, 0.067, 0.090, 0.92), Color(1, 1, 1, 0.10), 10)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 12)
	p.add_theme_stylebox_override("panel", sb)
	_m_grid.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var art := Control.new()
	art.custom_minimum_size = Vector2(150, 150)
	art.clip_contents = true
	art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(art)
	var entry := {"art": {}}
	var ghost := _m_art(id, 1)
	ghost.name = "ghost_%s" % id
	ghost.modulate = Color(1, 1, 1, 0.22)
	art.add_child(ghost)
	entry.ghost = ghost
	for tier in [1, 2, 3]:
		var t := _m_art(id, tier)
		t.name = "sil_%s_%d" % [id, tier]
		t.visible = false
		art.add_child(t)
		entry.art[tier] = t
	var hot := Button.new()   # art = enter, never upgrade
	hot.flat = true
	hot.name = "hot_%s" % id
	hot.set_anchors_preset(Control.PRESET_FULL_RECT)
	hot.focus_mode = Control.FOCUS_NONE
	hot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hot.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hot.add_theme_stylebox_override("pressed", UIKit.flat_box(Color(UIKit.ACCENT, 0.14), Color(UIKit.ACCENT, 0.9), 6))
	hot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	hot.pressed.connect(func(): _open(id))
	art.add_child(hot)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var title := MobilePage.label(name_of(id), UIKit.TEXT, 26, false)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(title)
	var lv := MobilePage.label("", UIKit.ACCENT, MobilePage.FONT, false)
	lv.clip_text = true
	col.add_child(lv)
	entry.lv = lv
	var d := MobilePage.label(Locale.t("a1_desc_%s" % id), UIKit.TEXT_DIM, MobilePage.FONT, true)
	d.max_lines_visible = 2
	d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(d)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 18)
	p.set_meta("m_btns", btns)
	var go := MobilePage.button(Locale.t("a1_enter"), false, func(): _open(id))
	go.name = "go_%s" % id
	btns.add_child(go)
	var up := MobilePage.button(Locale.t("a1_upgrade"), true, func(): _upgrade(id))
	up.name = "up_%s" % id
	btns.add_child(up)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	p.remove_child(row)
	p.add_child(outer)
	outer.add_child(row)
	outer.add_child(btns)
	entry.go = go
	entry.up = up
	_cards[id] = entry

func _m_art(id: String, tier: int) -> TextureRect:
	var t := TextureRect.new()
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture = _tex(id, tier)
	return t

func _say(t: String, ok: bool) -> void:
	_msg.text = t
	_msg.add_theme_color_override("font_color", UIKit.OK if ok else UIKit.DANGER)
