extends Control
## Shrine (line B, audit #22). Three service cards (heal / blood test / restore) with real
## state: who is hurt, the per-head test price, what the next shrine level adds. Below, the
## year's five festivals with this month marked and how long until the next one.

var _msg: Label
var _heal_btn: Button
var _heal_card: Control
var _blood_card: Control
var _fix_card: Control
var _fest_card: Control
var _mob := false
var _cw := 388.0
var _ch := 300.0
var _th := 90.0

## Desktop keeps the 1280 grid. Phone (22px type, 76px buttons): cards share the full width and grow.
func _geo() -> void:
	_mob = DeviceProfile.is_mobile()
	if not _mob:
		_cw = 388.0
		_ch = 300.0
		_th = 90.0
		return
	set_meta("ck_page_kit", false)  # this page spans the full phone width itself
	var w := MobilePage.width(self) if is_inside_tree() else maxf(get_viewport().get_visible_rect().size.x, 1280.0)
	_cw = floorf((w - 84.0 - 32.0) / 3.0)
	_ch = 340.0
	_th = 120.0

func _ready() -> void:
	var lv := GameState.building_level("shrine")
	CKPageKit.shell(self, Locale.t("lb_shrine_ctx"), "SANCTUARY", Locale.t("lb_shrine_title"), Locale.t("lb_shrine_desc"))
	_place_shrine_crests()
	var hurt := _hurt()
	_geo()
	_heal_card = CKPageKit.card(self, Rect2(42, CKPageKit.TOP + 8, _cw, _ch), "HealCard", true)
	var heal := _heal_card
	CKPageKit.card_head(heal, Locale.t("lb_shrine_heal"), "HEALING")
	CKPageKit.stat(heal, Vector2(18, 64), Locale.t("lb_shrine_hurt"), Locale.t("lb_people", [hurt.size()]), UIKit.DANGER if not hurt.is_empty() else UIKit.OK)
	CKPageKit.stat(heal, Vector2(_cw * 0.5, 64), Locale.t("lb_shrine_cost"), Locale.t("lb_shrine_free"), UIKit.OK)
	var names := CKPageKit.text(_hurt_text(hurt), UIKit.TEXT_DIM, 13, 352)
	names.name = "HurtList"
	names.position = Vector2(18, 112 if _mob else 124)
	names.size = Vector2(_cw - 36, _th)
	heal.add_child(names)
	_heal_btn = CKPageKit.button(Locale.t("lb_shrine_heal_go"), true, 352)
	_heal_btn.name = "HealButton"
	_heal_btn.position = Vector2(18, _ch - 20 - (MobilePage.HIT if _mob else CKPageKit.HIT))
	_heal_btn.size = Vector2(_cw - 36, MobilePage.HIT if _mob else _heal_btn.size.y)
	CKPageKit.lock(_heal_btn, "" if not hurt.is_empty() else Locale.t("lb_shrine_heal_none"))
	_heal_btn.pressed.connect(_heal)
	heal.add_child(_heal_btn)
	_place_heal_strip(hurt)
	_blood_card = CKPageKit.card(self, Rect2(42 + (_cw + 16) * 1, CKPageKit.TOP + 8, _cw, _ch), "BloodCard")
	var blood := _blood_card
	CKPageKit.card_head(blood, Locale.t("lb_shrine_blood"), "BLOOD TEST")
	CKPageKit.stat(blood, Vector2(18, 64), Locale.t("lb_shrine_cost"), Locale.t("lb_shrine_per_head", [CKBloodline.verify_cost(lv)]), UIKit.ACCENT)
	var bt := CKPageKit.text(Locale.t("lb_shrine_blood_body"), UIKit.TEXT_DIM, 13, 352)
	bt.position = Vector2(18, 112 if _mob else 124)
	bt.size = Vector2(_cw - 36, _th)
	blood.add_child(bt)
	var vb := CKPageKit.button(Locale.t("lb_shrine_blood_go"), false, 352)
	vb.name = "VerifyBlood"
	vb.position = Vector2(18, _ch - 20 - (MobilePage.HIT if _mob else CKPageKit.HIT))
	vb.size = Vector2(_cw - 36, MobilePage.HIT if _mob else vb.size.y)
	vb.pressed.connect(func(): Sfx.click(); CKNav.go("res://scenes/hub/blood_test.tscn"))
	blood.add_child(vb)
	_fix_card = CKPageKit.card(self, Rect2(42 + (_cw + 16) * 2, CKPageKit.TOP + 8, _cw, _ch), "RestoreCard")
	var fix := _fix_card
	CKPageKit.card_head(fix, Locale.t("lb_shrine_fix"), "RESTORATION")
	CKPageKit.stat(fix, Vector2(18, 64), Locale.t("lb_shrine_level"), "LV %d / 3" % lv, UIKit.ACCENT)
	var ft := CKPageKit.text(Locale.t("lb_shrine_fix_max") if lv >= 3 else Locale.t("lb_shrine_fix_body"), UIKit.TEXT_DIM, 13, 352)
	ft.position = Vector2(18, 112 if _mob else 124)
	ft.size = Vector2(_cw - 36, _th)
	fix.add_child(ft)
	var wb := CKPageKit.button(Locale.t("lb_shrine_fix_go"), false, 352)
	wb.name = "GoWorks"
	wb.position = Vector2(18, _ch - 20 - (MobilePage.HIT if _mob else CKPageKit.HIT))
	wb.size = Vector2(_cw - 36, MobilePage.HIT if _mob else wb.size.y)
	CKPageKit.lock(wb, Locale.t("lb_shrine_fix_max_short") if lv >= 3 else "")
	wb.pressed.connect(func(): Sfx.click(); CKNav.go("res://scenes/hub/works.tscn"))
	fix.add_child(wb)
	_festivals()
	_msg = CKPageKit.feedback(self)
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "SANCTUARY · LV %d" % lv)
	UIFX.page_enter(self)
	UIFX.wire_tree(self)



func _place_heal_strip(hurt: Array = []) -> void:
	## Field strip on HealCard: 团徽 + first hurt 族徽|旗徽. Empty → 团徽 only.
	if _heal_card == null:
		return
	if hurt.is_empty():
		hurt = _hurt()
	var focus = hurt[0] if not hurt.is_empty() else null
	var shield := Vector2(32, 40) if not _mob else Vector2(28, 34)
	var pair_w := shield.x * (2.0 if focus != null else 1.0) + (8.0 if focus != null else 0.0)
	CKHeraldryField.place_shrine_heal_strip(
		_heal_card, focus, Vector2(maxf(8.0, _cw - pair_w - 24.0), 10.0), shield)


func _place_shrine_crests() -> void:
	## 团徽 header + banner strip + NationCrestStrip (home/current nation 邦徽).
	var mob := DeviceProfile.is_mobile()
	var hdr := Vector2(44, 52) if not mob else Vector2(40, 48)
	CKHeraldryField.place_company_header(self, Vector2(1180, 8) if not mob else Vector2(1180, 4), hdr)
	CKHeraldryField.place_banner_plate(self, Vector2(1120, 8) if not mob else Vector2(1120, 4), hdr, Vector2(28, 38))
	var nid := str(World.nation_of(str(World.pos))) if str(World.pos) != "" else ""
	if nid == "":
		var ids: Array = CKBloodline.nation_ids()
		if not ids.is_empty():
			nid = str(ids[0])
	CKHeraldryField.place_nation_crest_strip(self, nid, Vector2(980, 10) if not mob else Vector2(900, 8), Vector2(36, 44) if not mob else Vector2(32, 38))

func apply_mobile_layout() -> void:
	if not MobilePage.active(self):
		return
	set_meta("m_center_ok", true)
	_geo()
	_place_shrine_crests()
	var top := CKPageKit.TOP + 8.0
	var x0 := 42.0
	var gap := 16.0
	var services: Array = [_heal_card, _blood_card, _fix_card]
	for i in services.size():
		var c := services[i] as Control
		if c == null:
			continue
		c.position = Vector2(x0 + (_cw + gap) * float(i), top)
		c.size = Vector2(_cw, _ch)
		_resize_service_card(c)
	_place_heal_strip()
	if _fest_card:
		var full := _cw * 3.0 + gap * 2.0
		var fy := top + _ch + 14.0
		_fest_card.position = Vector2(x0, fy)
		_fest_card.size = Vector2(full, maxf(180.0, 712.0 - fy))
		var fest_row: HBoxContainer = null
		for ch in _fest_card.get_children():
			if ch is HBoxContainer:
				fest_row = ch as HBoxContainer
				break
		if fest_row:
			fest_row.position = Vector2(16, 58)
			var pw := floorf((full - 32.0 - 40.0) / 5.0)
			for p in fest_row.get_children():
				if p is Control:
					(p as Control).custom_minimum_size = Vector2(pw, 140)
	MobilePage.upsize(self)

func _resize_service_card(card: Control) -> void:
	if card == null:
		return
	for ch in card.get_children():
		if not (ch is Control):
			continue
		var c := ch as Control
		if c is Label and c.position.y >= 100.0:
			c.position = Vector2(18, 112)
			c.size = Vector2(_cw - 36.0, _th)
			c.add_theme_font_size_override("font_size", MobilePage.FONT)
		elif c is BaseButton:
			c.position = Vector2(18, _ch - 20.0 - MobilePage.HIT)
			c.size = Vector2(_cw - 36.0, MobilePage.HIT)
			c.custom_minimum_size = Vector2(_cw - 36.0, MobilePage.HIT)
			c.add_theme_font_size_override("font_size", MobilePage.FONT)

func _hurt() -> Array:
	return GameState.roster().filter(func(c): return c.injured or c.hp < c.max_hp or not CKInjury.record(c).is_empty())

func _hurt_text(hurt: Array) -> String:
	if hurt.is_empty():
		return Locale.t("lb_shrine_all_well")
	var bits: Array = []
	for c in hurt:
		bits.append(Locale.t("lb_shrine_hurt_one", [c.name, c.hp, c.max_hp]) + (Locale.t("lb_shrine_injured") if c.injured else ""))
	return "　".join(bits)

func _festivals() -> void:
	var full := _cw * 3 + 32
	var fy := CKPageKit.TOP + 8 + _ch + 14
	_fest_card = CKPageKit.card(self, Rect2(42, fy, full, maxf(214.0, 712.0 - fy) if _mob else 214.0), "FestivalCard")
	var card := _fest_card
	var rows: Array = CKFestivals.rows().duplicate()
	rows.sort_custom(func(a, b): return int(a.get("month", 0)) < int(b.get("month", 0)))
	var m := Calendar.month
	var next: Dictionary = {}
	var gap := 99
	for r in rows:
		var d := (int(r.get("month", 0)) - m + 12) % 12
		if d > 0 and d < gap:
			gap = d
			next = r
	var today := CKFestivals.row_for_month(m)
	var head := Locale.t("lb_shrine_fest_head")
	if not today.is_empty():
		head = Locale.t("lb_shrine_fest_today", [Locale.t(str(today.get("name_key", "")))])
	elif not next.is_empty():
		head = Locale.t("lb_shrine_fest_next", [Locale.t(str(next.get("name_key", ""))), gap])
	CKPageKit.card_head(card, head, "FESTIVALS")
	var h := HBoxContainer.new()
	h.position = Vector2(16, 58)
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	for r in rows:
		var on := int(r.get("month", 0)) == m
		var col: Color = UIKit.OK if on else (UIKit.ACCENT if r == next else UIKit.TEXT_FAINT)
		var p := PanelContainer.new()
		var pw := floorf((full - 32 - 40) / 5.0) if _mob else 224.0
		p.custom_minimum_size = Vector2(pw, 140)
		var sb := UIKit.flat_box(Color(col, 0.08), Color(col, 0.5), 10, 2 if on else 1)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 10
		p.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		p.add_child(v)
		v.add_child(UIKit.mono(Locale.t("lb_month", [int(r.get("month", 0))]), 12, col, false))
		v.add_child(UIKit.title_label(Locale.t(str(r.get("name_key", ""))), 16, UIKit.TEXT))
		v.add_child(CKPageKit.text(Locale.t(str(r.get("blurb_key", ""))), UIKit.TEXT_DIM, 12, pw - 26))
		h.add_child(p)

func _heal() -> void:
	var msg := GameState.heal_at_shrine()
	CKPageKit.say(_msg, msg, true)
	UIFX.confirm(_heal_btn)
	var names := find_child("HurtList", true, false) as Label
	if names:
		names.text = _hurt_text(_hurt())
	CKPageKit.lock(_heal_btn, "" if not _hurt().is_empty() else Locale.t("lb_shrine_heal_done"))
	_place_heal_strip()
