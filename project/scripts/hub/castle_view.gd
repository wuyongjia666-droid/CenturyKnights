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
	UIKit.top_bar(self, Locale.t("a1_view_title"), UIKit.std_resource_chips(), Locale.t("a1_view_back"), _back)
	_msg = UIKit.body_label(Locale.t("a1_view_head"), UIKit.TEXT_DIM, 13)
	_msg.name = "Msg"
	_msg.position = Vector2(ORIGIN.x, 60)
	_msg.size = Vector2(1232, 20)
	add_child(_msg)
	for i in SLOTS.size():
		_card(str(SLOTS[i]), i)
	refresh()

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

func _say(t: String, ok: bool) -> void:
	_msg.text = t
	_msg.add_theme_color_override("font_color", UIKit.OK if ok else UIKit.DANGER)
