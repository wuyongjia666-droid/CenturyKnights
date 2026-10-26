extends Control
## Court gazette (line B, audit #25): births, deaths, succession crises of the ten courts.
## Filters carry a count; an empty filter says what would land there; before the first
## new year the page still shows the company's own first entries and when the gazette starts.

const KINDS := [
	["all", "FilterAll"], ["birth", "FilterBirth"], ["death", "FilterDeath"],
	["succession", "FilterSuccession"], ["marriage", "FilterMarriage"], ["recall", "FilterRecall"],
]

var _filter := "all"
var _list: VBoxContainer

func _ready() -> void:
	CKPageKit.shell(self, Locale.t("lb_news_ctx"), "COURT GAZETTE", Locale.t("lb_news_title"), Locale.t("lb_news_desc"))
	_place_gazette_crests()
	var bar := HBoxContainer.new()
	bar.name = "FilterBar"
	bar.position = Vector2(42, CKPageKit.TOP + 6)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	var counts := _counts()
	for it in KINDS:
		var kind := str(it[0])
		var b := CKPageKit.button(_filter_label(kind, int(counts.get(kind, 0))), false, 150)
		b.name = str(it[1])
		b.toggle_mode = true
		b.button_pressed = kind == "all"
		b.pressed.connect(func(): _set_filter(kind))
		bar.add_child(b)
	var panel := CKPageKit.card(self, Rect2(42, CKPageKit.TOP + 66, 1196, 470), "NewsList")
	_list = CKPageKit.list(panel, Rect2(16, 16, 1164, 438), "NewsRows")
	_fill()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "COURT GAZETTE · FROST")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func _filter_label(kind: String, n: int) -> String:
	var zh: String = Locale.t("lb_news_all") if kind == "all" else str(CKCourtChrome.KIND_ZH.get(kind, kind))
	return "%s  %d" % [zh, n]

func _counts() -> Dictionary:
	var out := {"all": 0}
	for ev in CKCourt.news_events():
		var k := str(ev.get("kind", ""))
		out[k] = int(out.get(k, 0)) + 1
		out["all"] = int(out["all"]) + 1
	return out

func _set_filter(kind: String) -> void:
	Sfx.click()
	_filter = kind
	var bar := get_node_or_null("FilterBar")
	if bar:
		for ch in bar.get_children():
			if ch is Button:
				(ch as Button).set_pressed_no_signal(str(ch.name).trim_prefix("Filter").to_lower() == kind)
	if kind == "death":
		Sfx.play("bell_toll")
	elif kind == "birth":
		Sfx.lineage_chime()
	_fill()

func _fill() -> void:
	CKPageKit.clear(_list)
	var all: Array = CKCourt.news_events()
	var rows: Array = all.filter(func(ev): return _filter == "all" or str(ev.get("kind", "")) == _filter)
	if rows.is_empty():
		if all.is_empty():
			_list.add_child(CKPageKit.empty(Locale.t("lb_news_empty_title"), Locale.t("lb_news_empty_why", [Calendar.year + 1]), Locale.t("lb_news_empty_how"), 1100))
			_list.add_child(_own_entry())
			## Empty gazette already has how-text (advance months); named tap CTA.
			var to_h := CKPageKit.button(Locale.t("lb_news_to_hourglass"), true, 300)
			to_h.name = "ToHourglass"
			to_h.pressed.connect(func(): CKNav.go("res://scenes/hub/hourglass.tscn"))
			_list.add_child(to_h)
			UIFX.wire_button(to_h)
		else:
			var zh := str(CKCourtChrome.KIND_ZH.get(_filter, _filter))
			## Kind filter empty: how + EmptyHost; ToHourglass waits the next gazette.
			var host := VBoxContainer.new()
			host.name = "EmptyHost"
			host.add_theme_constant_override("separation", 12)
			host.add_child(CKPageKit.empty(Locale.t("lb_news_kind_empty", [zh]), Locale.t("lb_news_kind_why"), Locale.t("lb_news_kind_how"), 1100))
			var acts := HBoxContainer.new()
			acts.name = "EmptyActions"
			acts.add_theme_constant_override("separation", 12)
			var to_h := CKPageKit.button(Locale.t("lb_news_to_hourglass"), true, 300)
			to_h.name = "ToHourglass"
			to_h.pressed.connect(func(): CKNav.go("res://scenes/hub/hourglass.tscn"))
			acts.add_child(to_h)
			UIFX.wire_button(to_h)
			host.add_child(acts)
			_list.add_child(host)
		return
	var crisis := {}
	for ev in rows:
		if str(ev.get("crisis", "")) != "":
			crisis[str(ev.get("nation_zh", ""))] = str(ev.get("crisis", ""))
	for nz in crisis.keys():
		var r := CKPageKit.row(UIKit.DANGER, 44)
		(r[1] as VBoxContainer).add_child(CKPageKit.text(Locale.t("lb_news_crisis", [nz, str(crisis[nz])]), UIKit.DANGER, 15, 1100))
		_list.add_child(r[0])
	for ev2 in rows:
		var kind2 := str(ev2.get("kind", ""))
		var col: Color = UIKit.OK if kind2 == "birth" else (UIKit.DANGER if kind2 == "death" else UIKit.ACCENT)
		var r2 := CKPageKit.row(col, 60)
		var v: VBoxContainer = r2[1]
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		v.add_child(top)
		var nid_row := str(ev2.get("nation", ""))
		if nid_row != "":
			CKHeraldryField.attach_news_row_arms(top, nid_row, Vector2(26, 32) if DeviceProfile.is_mobile() else Vector2(28, 34))
		top.add_child(UIKit.tag_chip(CKCourtChrome.KIND_ZH.get(kind2, kind2), col))
		top.add_child(UIKit.mono(Locale.t("lb_news_when", [int(ev2.get("year", 0)), str(ev2.get("nation_zh", ""))]), 12, UIKit.TEXT_DIM, false))
		v.add_child(CKPageKit.text(str(ev2.get("text", "")), UIKit.TEXT, 15, 1100))
		_list.add_child(r2[0])
	CKPageKit.drag_through(_list)
	UIFX.stagger_children(_list, 0.03, 0.2)

## Before the first gazette: our own founding entry, so the page is not a blank sheet.
func _own_entry() -> Control:
	var r := CKPageKit.row(UIKit.OK, 60)
	var v: VBoxContainer = r[1]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(UIKit.tag_chip(Locale.t("lb_news_own_tag"), UIKit.OK))
	top.add_child(UIKit.mono(Calendar.label(), 12, UIKit.TEXT_DIM, false))
	var lead: CKCharacter = GameState.get_leader()
	var who := lead.name if lead != null else Locale.t("lb_news_own_nobody")
	v.add_child(CKPageKit.text(Locale.t("lb_news_own_text", [who, GameState.roster().size()]), UIKit.TEXT, 15, 1100))
	return r[0]


func _place_gazette_crests(mobile: bool = false) -> void:
	## Fat gazette chrome: 团徽 header + 旗徽 strip + 朝徽 gazette strip.
	for n in ["CastleArms", "CastleBannerStrip", "GazetteCrestStrip"]:
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
	CKHeraldryChrome.place_company_header(self, Vector2(arms_x, at_y), hdr)
	CKHeraldryChrome.place_castle_banner_strip(self, Vector2(strip_x, at_y), hdr, ban)
	var nid := World.nation_of(str(World.pos))
	if nid == "":
		nid = "ashbanner"
	var gat := Vector2(42, 10) if mob else Vector2(42, 8)
	CKHeraldryField.place_gazette_crest_strip(self, nid, gat, Vector2(34, 42) if mob else Vector2(36, 44))

func apply_mobile_layout() -> void:
	CKPageKit.phone_fill(self)
	_place_gazette_crests(true)
