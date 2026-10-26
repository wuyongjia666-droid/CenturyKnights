extends Control
## Ancestor stele (line B, audit #23). Left: family honor and how the stele works.
## Right: one stone per dead family member, newest first. Empty: what lands here and when.

var _list: VBoxContainer
var _honor: Label

func _ready() -> void:
	UIKit.make_themed_bg(self, "castle")
	CKPageKit.shell(self, Locale.t("ancestor_title"), "ANCESTOR STELE", Locale.t("ancestor_title"), Locale.t("lb_anc_desc"), "none")
	_place_ancestor_crests()
	var side := CKPageKit.card(self, Rect2(42, CKPageKit.TOP + 8, 360, 520), "HonorCard")
	CKPageKit.card_head(side, Locale.t("lb_anc_honor_head"), "FAMILY HONOR")
	_honor = UIKit.title_label("", 40, UIKit.ACCENT)
	_honor.name = "HonorValue"
	_honor.position = Vector2(18, 64)
	side.add_child(_honor)
	var how := CKPageKit.text(Locale.t("lb_anc_how"), UIKit.TEXT_DIM, 14, 324)
	how.position = Vector2(18, 128)
	how.size = Vector2(324, 360)
	side.add_child(how)
	var main := CKPageKit.card(self, Rect2(418, CKPageKit.TOP + 8, 820, 520), "SteleWall")
	CKPageKit.card_head(main, Locale.t("lb_anc_wall_head"), "STELE WALL")
	_list = CKPageKit.list(main, Rect2(16, 60, 788, 444), "SteleList")
	_fill()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "ANCESTOR STELE · FROST")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func _fill() -> void:
	CKPageKit.clear(_list)
	var rows: Array = Lineage.ancestor_rows()
	var cap := 3
	_honor.text = Locale.t("ancestor_honor", [Lineage.honor_bonus()])
	var note := Locale.t("lb_anc_count", [rows.size(), cap])
	_honor.tooltip_text = note
	if rows.is_empty():
		_list.add_child(CKPageKit.empty(Locale.t("ancestor_empty"), Locale.t("lb_anc_empty_why"), Locale.t("lb_anc_empty_how"), 740))
		## Empty stele already says deaths fill it; named tap CTA to age/battle time.
		var to_h := CKPageKit.button(Locale.t("lb_anc_to_hourglass"), true, 740)
		to_h.name = "ToHourglass"
		to_h.pressed.connect(func(): CKNav.go("res://scenes/hub/hourglass.tscn"))
		_list.add_child(to_h)
		UIFX.wire_button(to_h)
		for i in 2:
			_list.add_child(_ghost_stone())
		return
	for row in rows:
		_list.add_child(_stone(row))
	CKPageKit.drag_through(_list)
	UIFX.stagger_children(_list, 0.04, 0.22)

func _stone(row: Dictionary) -> Control:
	var battle := str(row.get("cause", "")) == "battle"
	var col: Color = UIKit.DANGER if battle else UIKit.ACCENT
	var r := CKPageKit.row(col, 96)
	var v: VBoxContainer = r[1]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	top.add_child(UIKit.title_label(str(row.get("name", "")), 18))
	top.add_child(UIKit.tag_chip(str(row.get("cause_zh", "")), col))
	top.add_child(UIKit.mono(Locale.t("lb_anc_years", [int(row.get("born_year", 0)), int(row.get("death_year", 0))]), 12, UIKit.TEXT_DIM, false))
	var words := str(row.get("words", ""))
	if words != "":
		v.add_child(CKPageKit.text(Locale.t("lb_anc_words", [words]), UIKit.TEXT, 15, 740))
	v.add_child(CKPageKit.text(Locale.t("lb_anc_deeds", [str(row.get("deeds", "")), str(row.get("titles", ""))]), UIKit.TEXT_DIM, 13, 740))
	return r[0]

func _ghost_stone() -> Control:
	var r := CKPageKit.row(UIKit.TEXT_FAINT, 72)
	(r[0] as Control).modulate = Color(1, 1, 1, 0.45)
	var v: VBoxContainer = r[1]
	v.add_child(UIKit.title_label(Locale.t("lb_anc_ghost_name"), 16, UIKit.TEXT_FAINT))
	v.add_child(CKPageKit.text(Locale.t("lb_anc_ghost_line"), UIKit.TEXT_FAINT, 13, 740))
	return r[0]


func _place_ancestor_crests(mobile: bool = false) -> void:
	## Fat ancestor chrome: 团徽 header + 旗徽 strip.
	for n in ["CastleArms", "CastleBannerStrip"]:
		var oldn := get_node_or_null(n)
		if oldn:
			oldn.name = "_%sDying" % n
			oldn.queue_free()
	var mob := mobile or DeviceProfile.is_mobile()
	var hdr := Vector2(52, 60) if mob else Vector2(44, 52)
	var ban := Vector2(28, 38)
	var w := size.x if size.x > 400.0 else 1280.0
	var at_y := 6.0 if mob else 8.0
	var arms_x := (w - 64.0) if mob else 1180.0
	var strip_x := (w - 140.0) if mob else 1100.0
	CKHeraldryField.place_company_header(self, Vector2(arms_x, at_y), hdr)
	CKHeraldryField.place_banner_plate(self, Vector2(strip_x, at_y), hdr, ban)

func apply_mobile_layout() -> void:
	CKPageKit.phone_fill(self)
	_place_ancestor_crests(true)
