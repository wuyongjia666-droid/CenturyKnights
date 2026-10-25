extends Control
## One page per castle annex (医所 / 书院 / 宝库 / 使馆), audit #1.
## CKNav params: {"annex": id}. Shows the real effect now and after the next level,
## who it serves (empty state when nobody), an upgrade with failure text, and a link
## to the page that uses it.

const LINK := {
	"infirmary": ["a1_go_shrine", "res://scenes/hub/shrine.tscn"],
	"academy": ["a1_go_train", "res://scenes/hub/train.tscn"],
	"treasury": ["a1_go_estates", "res://scenes/hub/estates.tscn"],
	"embassy": ["a1_go_rival", "res://scenes/hub/rival_houses.tscn"],
}

var id := "infirmary"
var _body: Control
var _msg := ""
var _msg_ok := true

func _ready() -> void:
	var p: Dictionary = CKNav.params()
	var want := str(p.get("annex", get_meta("annex", id)))
	if CKCastleServices.ANNEX.has(want):
		id = want
	UIKit.void_bg(self)
	_body = Control.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.size = Vector2(1280, 720)
	add_child(_body)
	render()

func nav_back() -> void:
	CKNav.up()

func level() -> int:
	return CKCastleServices.annex_level(GameState, id)

static func effect_text(annex: String, lv: int) -> String:
	match annex:
		"infirmary":
			return Locale.t("a1_eff_infirmary") % lv
		"academy":
			return Locale.t("a1_eff_academy") % (1 + lv)
		"treasury":
			return Locale.t("a1_eff_treasury") % lv
		_:
			return Locale.t("a1_eff_embassy_on") if lv >= 1 else Locale.t("a1_eff_embassy_off")

func rows() -> Array:
	var out: Array = []
	match id:
		"infirmary":
			for c in GameState.roster():
				if c.injured or c.hp < c.max_hp:
					out.append(Locale.t("a1_hp_row") % [c.name, c.hp, c.max_hp])
		"academy":
			for c in GameState.characters.values():
				if c.alive and c.is_child:
					out.append(Locale.t("a1_child_row") % [c.name, c.age])
		"treasury":
			out.append(Locale.t("a1_treasury_row") % [GameState.silver, GameState.iron, GameState.food])
		"embassy":
			for h in GameState.data_rivals.get("houses", []):
				out.append(str(h.get("name", h.get("id", ""))))
	return out


func _place_annex_crests() -> void:
	## Castle annex chrome: 团徽 header + castle banner strip on the page body.
	var mob := DeviceProfile.is_mobile()
	var hdr := Vector2(44, 52) if not mob else Vector2(40, 48)
	var host: Node = _body if _body != null else self
	CKHeraldryChrome.place_company_header(host, Vector2(1180, 8) if not mob else Vector2(1180, 4), hdr)
	CKHeraldryChrome.place_castle_banner_strip(host, Vector2(1120, 8) if not mob else Vector2(1120, 4), hdr, Vector2(28, 38))

func apply_mobile_layout() -> void:
	if MobilePage.active(self):
		render()

func render() -> void:
	for n in _body.get_children():
		_body.remove_child(n)
		n.queue_free()
	if MobilePage.active(self):
		_m_render()
		return
	var nm := Locale.t(str(CKCastleServices.ANNEX[id]))
	UIKit.top_bar(_body, nm, UIKit.std_resource_chips(), Locale.t("shell_0d711744"), nav_back)
	_place_annex_crests()
	var lv := level()
	var tier := maxi(1, CKCastleServices.tier_of(lv))
	# left: art
	UIKit.panel_at(_body, Rect2(24, 72, 620, 624), 12)
	var art := TextureRect.new()
	art.name = "Art"
	art.position = Vector2(36, 84)
	art.size = Vector2(596, 336)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	var path := "res://assets/art/castle/v92_castle_%s_t%d.webp" % ["vault" if id == "treasury" else id, tier]
	if ResourceLoader.exists(path):
		art.texture = load(path)
	art.modulate = Color(1, 1, 1, 1.0 if lv > 0 else 0.3)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(art)
	var t := UIKit.title_label(nm, 28, UIKit.TEXT)
	t.position = Vector2(40, 432)
	t.size = Vector2(588, 40)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF

	_body.add_child(t)
	var lv_text := Locale.t("a1_unbuilt") if lv <= 0 else "%s / %d" % [Locale.t("a1_level") % lv, CKCastleServices.ANNEX_MAX]
	var lvl := UIKit.body_label(lv_text, UIKit.ACCENT if lv > 0 else UIKit.TEXT_FAINT, 15)
	lvl.name = "Level"
	lvl.position = Vector2(40, 474)
	lvl.size = Vector2(588, 22)
	lvl.autowrap_mode = TextServer.AUTOWRAP_OFF

	_body.add_child(lvl)
	var d := UIKit.body_label(Locale.t("a1_desc_%s" % id), UIKit.TEXT_DIM, 14)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.position = Vector2(40, 502)
	d.size = Vector2(588, 44)
	_body.add_child(d)
	var now := UIKit.body_label(Locale.t("a1_now") % effect_text(id, lv), UIKit.TEXT, 14)
	now.name = "Now"
	now.position = Vector2(40, 552)
	now.size = Vector2(588, 22)
	now.autowrap_mode = TextServer.AUTOWRAP_OFF

	_body.add_child(now)
	var up_row := HBoxContainer.new()
	up_row.position = Vector2(40, 628)
	up_row.add_theme_constant_override("separation", 12)
	_body.add_child(up_row)
	var b: Button
	if lv >= CKCastleServices.ANNEX_MAX:
		b = UIKit.ghost_button(Locale.t("a1_maxed"), 160, 48)
		b.disabled = true
	else:
		var cost: Dictionary = CKCastleServices.ANNEX_COST.get(lv + 1, {})
		var nx := UIKit.body_label(Locale.t("a1_next") % effect_text(id, lv + 1), UIKit.ACCENT, 14)
		nx.name = "Next"
		nx.position = Vector2(40, 578)
		nx.size = Vector2(588, 22)
		nx.autowrap_mode = TextServer.AUTOWRAP_OFF

		_body.add_child(nx)
		var cs := UIKit.body_label(Locale.t("a1_cost") % [int(cost.get("silver", 0)), int(cost.get("iron", 0)), int(cost.get("food", 0))], UIKit.TEXT_DIM, 13)
		cs.position = Vector2(40, 602)
		cs.size = Vector2(588, 20)
		cs.autowrap_mode = TextServer.AUTOWRAP_OFF

		_body.add_child(cs)
		b = UIKit.make_accent_button(Locale.t("a1_build") if lv <= 0 else Locale.t("a1_upgrade"), 160)
		b.custom_minimum_size = Vector2(160, 48)
		b.pressed.connect(_upgrade)
	b.name = "Upgrade"
	up_row.add_child(b)
	if _msg != "":
		var m := UIKit.body_label(_msg, UIKit.OK if _msg_ok else UIKit.DANGER, 13)
		m.name = "Msg"
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		up_row.add_child(m)
	# right: who / what it serves
	UIKit.panel_at(_body, Rect2(660, 72, 596, 624), 12)
	var h := UIKit.title_label(Locale.t("a1_list_%s" % id), 19, UIKit.TEXT)
	h.position = Vector2(680, 88)
	h.size = Vector2(540, 28)
	h.autowrap_mode = TextServer.AUTOWRAP_OFF

	_body.add_child(h)
	var sc := ScrollContainer.new()
	sc.name = "List"
	sc.position = Vector2(676, 124)
	sc.size = Vector2(564, 488)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(548, 0)
	sc.add_child(vb)
	var rs := rows()
	if rs.is_empty():
		var e := UIKit.body_label(Locale.t("a1_empty_%s" % id), UIKit.TEXT_FAINT, 14)
		e.name = "Empty"
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(548, 0)
		vb.add_child(e)
	for r in rs:
		var row := UIKit.body_label(str(r), UIKit.TEXT, 15)
		row.custom_minimum_size = Vector2(548, 40)
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		vb.add_child(row)
	var link: Array = LINK[id]
	var go := UIKit.ghost_button(Locale.t(str(link[0])), 200, 48)
	go.name = "Link"
	go.position = Vector2(680, 632)
	go.disabled = lv <= 0
	var dest := str(link[1])
	go.pressed.connect(func(): CKNav.go(dest))
	_body.add_child(go)

func _upgrade() -> void:
	var r: Dictionary = CKCastleServices.upgrade_annex(GameState, id)
	_msg = str(r.get("msg", ""))
	_msg_ok = bool(r.get("ok", false))
	if _msg_ok:
		Sfx.confirm()
		GameState.save_game()
	else:
		Sfx.miss()
	render()


## ── Phone landscape: art + effect/upgrade card (left) · who it serves + link (right), full width ──
func _m_render() -> void:
	var old := get_node_or_null("MobileTopBar")
	if old:
		remove_child(old)
		old.queue_free()
	var w := MobilePage.width(self)
	var h := size.y if size.y > 400.0 else 720.0
	_body.size = Vector2(w, h)
	var nm := Locale.t(str(CKCastleServices.ANNEX[id]))
	MobilePage.top_bar(self, nm, Locale.t("mw_41e31e6c") % [GameState.silver, GameState.food, GameState.iron, Calendar.label()], [[Locale.t("shell_0d711744"), nav_back]])
	_place_annex_crests()
	var lv := level()
	var tier := maxi(1, CKCastleServices.tier_of(lv))
	var top := MobilePage.TOP
	var bh := h - top - 16.0
	var lw := floorf((w - 52.0) * 0.56)
	var lvx := MobilePage.panel(_body, Rect2(20, top, lw, bh), 14)
	lvx.add_theme_constant_override("separation", 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lvx.add_child(row)
	var art := TextureRect.new()
	art.name = "Art"
	art.custom_minimum_size = Vector2(floorf(lw * 0.40), 0)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	var path := "res://assets/art/castle/v92_castle_%s_t%d.webp" % ["vault" if id == "treasury" else id, tier]
	if ResourceLoader.exists(path):
		art.texture = load(path)
	art.modulate = Color(1, 1, 1, 1.0 if lv > 0 else 0.35)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)
	row.add_child(info)
	var t := MobilePage.label(nm, UIKit.TEXT, 30, false)
	t.add_theme_font_override("font", UIKit.font("bold"))
	info.add_child(t)
	var lvl_txt := Locale.t("a1_unbuilt") if lv <= 0 else "%s / %d" % [Locale.t("a1_level") % lv, CKCastleServices.ANNEX_MAX]
	var lvl := MobilePage.label(lvl_txt, UIKit.ACCENT if lv > 0 else UIKit.TEXT_FAINT, MobilePage.FONT, false)
	lvl.name = "Level"
	info.add_child(lvl)
	info.add_child(MobilePage.label(Locale.t("a1_desc_%s" % id), UIKit.TEXT_DIM, MobilePage.FONT, true))
	var now := MobilePage.label(Locale.t("a1_now") % effect_text(id, lv), UIKit.TEXT, MobilePage.FONT, true)
	now.name = "Now"
	info.add_child(now)
	var b: Button
	if lv >= CKCastleServices.ANNEX_MAX:
		b = MobilePage.button(Locale.t("a1_maxed"), false, func(): pass)
		b.disabled = true
	else:
		var cost: Dictionary = CKCastleServices.ANNEX_COST.get(lv + 1, {})
		var nx := MobilePage.label(Locale.t("a1_next") % effect_text(id, lv + 1), UIKit.ACCENT, MobilePage.FONT, true)
		nx.name = "Next"
		info.add_child(nx)
		info.add_child(MobilePage.label(Locale.t("a1_cost") % [int(cost.get("silver", 0)), int(cost.get("iron", 0)), int(cost.get("food", 0))], UIKit.TEXT_DIM, MobilePage.FONT, true))
		b = MobilePage.button(Locale.t("a1_build") if lv <= 0 else Locale.t("a1_upgrade"), true, _upgrade)
	b.name = "Upgrade"
	if _msg != "":
		var m := MobilePage.label(_msg, UIKit.OK if _msg_ok else UIKit.DANGER, MobilePage.FONT, true)
		m.name = "Msg"
		lvx.add_child(m)
	lvx.add_child(b)
	var rw := w - 52.0 - lw
	var rv := MobilePage.panel(_body, Rect2(32 + lw, top, rw, bh), 14)
	rv.add_child(MobilePage.label(Locale.t("a1_list_%s" % id), UIKit.ACCENT, 24, false))
	var sc := ScrollContainer.new()
	sc.name = "List"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	sc.add_child(vb)
	var rs := rows()
	if rs.is_empty():
		var e := MobilePage.label(Locale.t("a1_empty_%s" % id), UIKit.TEXT_FAINT, MobilePage.FONT, true)
		e.name = "Empty"
		vb.add_child(e)
	for r in rs:
		vb.add_child(MobilePage.label(str(r), UIKit.TEXT, MobilePage.FONT, true))
	var link: Array = LINK[id]
	var dest := str(link[1])
	var go := MobilePage.button(Locale.t(str(link[0])), false, func(): CKNav.go(dest))
	go.name = "Link"
	go.disabled = lv <= 0
	rv.add_child(go)
