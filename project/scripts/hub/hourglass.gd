extends Control
## Hourglass (line B, audit #27). KPIs on top, "what next month brings" on the left, the last
## result on the right (empty until the first advance), two advance buttons. The tutorial
## jump to harvest only shows with CK_DEBUG_TOOLS=1.

var _forecast: VBoxContainer
var _log: VBoxContainer
var _kpi: HBoxContainer
var _msg: Label
var _busy := false

func _ready() -> void:
	UIKit.make_themed_bg(self, "hourglass")
	CKPageKit.shell(self, Locale.t("lb_hg_ctx"), "HOURGLASS", Locale.t("lb_hg_title"), Locale.t("lb_hg_desc"), "none")
	_kpi = HBoxContainer.new()
	_kpi.name = "Kpis"
	_kpi.position = Vector2(42, CKPageKit.TOP + 8)
	_kpi.add_theme_constant_override("separation", 12)
	add_child(_kpi)
	var fc := CKPageKit.card(self, Rect2(42, CKPageKit.TOP + 92, 590, 360), "ForecastCard")
	CKPageKit.card_head(fc, Locale.t("lb_hg_next"), "FORECAST")
	_forecast = CKPageKit.list(fc, Rect2(14, 58, 562, 290), "Forecast")
	var lc := CKPageKit.card(self, Rect2(648, CKPageKit.TOP + 92, 590, 360), "ResultCard")
	CKPageKit.card_head(lc, Locale.t("lb_hg_last"), "RESULT")
	_log = CKPageKit.list(lc, Rect2(14, 58, 562, 290), "Result")
	_paint_result_initial()
	var row := HBoxContainer.new()
	row.name = "AdvanceRow"
	row.position = Vector2(42, CKPageKit.TOP + 466)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var m1 := CKPageKit.button(Locale.t("advance_month"), true, 220)
	m1.name = "AdvanceMonth"
	m1.pressed.connect(func(): _advance(1, m1))
	row.add_child(m1)
	var m3 := CKPageKit.button(Locale.t("advance_season"), false, 220)
	m3.name = "AdvanceSeason"
	m3.pressed.connect(func(): _advance(3, m3))
	row.add_child(m3)
	if OS.get_environment("CK_DEBUG_TOOLS") == "1":
		var hv := CKPageKit.button(Locale.t("lb_hg_debug_harvest"), false, 220)
		hv.pressed.connect(_to_harvest)
		row.add_child(hv)
	if DeviceProfile.is_mobile():
		# Phone: the primary advance sits bottom-right under the thumb, season to its left.
		row.size = Vector2(1196, MobilePage.HIT)
		row.alignment = BoxContainer.ALIGNMENT_END
		row.move_child(m1, row.get_child_count() - 1)
		for b in row.get_children():
			(b as Control).custom_minimum_size = Vector2(260, MobilePage.HIT)
	_msg = CKPageKit.feedback(self)
	_paint_kpis()
	_show_forecast(1)
	_feel_dynasty_end()
	_place_hourglass_crests()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "HOURGLASS · FROST")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

## Story screens opened from a chapter go back to it once (StoryCatalog).


func _place_hourglass_crests() -> void:
	var mob := DeviceProfile.is_mobile()
	var at := Vector2(1120, 8) if not mob else Vector2(maxf(20.0, MobilePage.width(self) - 120.0), 4)
	var sh := Vector2(36, 44) if not mob else Vector2(32, 40)
	CKHeraldryField.place_hourglass_crest_strip(self, at, sh, Vector2(24, 34) if not mob else Vector2(22, 30))

func apply_mobile_layout() -> void:
	if not MobilePage.active(self):
		return
	CKPageKit.phone_fill(self)
	_place_hourglass_crests()
	var w := MobilePage.width(self)
	if _kpi:
		_kpi.position = Vector2(24, CKPageKit.TOP + 8)
		_kpi.size = Vector2(w - 48.0, 80)
		for ch in _kpi.get_children():
			if ch is Control:
				(ch as Control).custom_minimum_size = Vector2(maxf(140.0, (w - 48.0 - 48.0) / 5.0), 76)
	var row := find_child("AdvanceRow", true, false) as Control
	if row:
		row.position = Vector2(24, CKPageKit.BOTTOM - MobilePage.HIT - 8.0)
		row.size = Vector2(w - 48.0, MobilePage.HIT)
		for b in row.get_children():
			if b is BaseButton:
				(b as BaseButton).custom_minimum_size = Vector2(220, MobilePage.HIT)
				(b as BaseButton).add_theme_font_size_override("font_size", MobilePage.FONT)


func _paint_result_initial() -> void:
	## Re-read last holdings/territory echo after leave; empty still nudges advance.
	if CKEconomyState.month_echo_has_any():
		_log.add_child(UIKit.mono(Locale.t("lb_hg_echo_head"), 11, UIKit.ACCENT, false))
		var snap := CKEconomyState.month_echo_snapshot()
		_log.add_child(CKPageKit.text(Locale.t("lb_est_echo_when", [str(snap.get("label", ""))]), UIKit.TEXT_DIM, 12, 520))
		for row in CKEconomyState.month_echo_lines():
			var line := _line(str(row.get("text", "")), UIKit.OK)
			line.name = "EchoLine_%s" % str(row.get("kind", "x"))
			_log.add_child(line)
		var to_e := CKPageKit.button(Locale.t("lb_hg_to_estates"), false, 220)
		to_e.name = "ToEstates"
		to_e.pressed.connect(func(): CKNav.go("res://scenes/hub/estates.tscn"))
		_log.add_child(to_e)
		UIFX.wire_button(to_e)
	else:
		## Y1-B: no month echo yet → EmptyHost + how + ToCourtNews (advance stays on-page).
		var host := VBoxContainer.new()
		host.name = "EmptyHost"
		host.add_theme_constant_override("separation", 12)
		host.add_child(CKPageKit.empty(
			Locale.t("lb_hg_empty"),
			Locale.t("lb_hg_empty_why"),
			Locale.t("lb_hg_empty_how"),
			520
		))
		var acts := HBoxContainer.new()
		acts.name = "EmptyActions"
		acts.add_theme_constant_override("separation", 12)
		var to_n := CKPageKit.button(Locale.t("lb_hg_to_court_news"), true, 260)
		to_n.name = "ToCourtNews"
		to_n.pressed.connect(func(): CKNav.go("res://scenes/hub/court_news.tscn"))
		acts.add_child(to_n)
		UIFX.wire_button(to_n)
		host.add_child(acts)
		_log.add_child(host)


func _back() -> void:
	var ret := StoryCatalog.take_story_return("")
	if ret != "":
		CKNav.replace(ret)
	elif str(GameState.chapter0_beat) == "0.6":
		CKNav.replace("res://scenes/story/chapter0.tscn")
	else:
		CKNav.up()

func _paint_kpis() -> void:
	CKPageKit.clear(_kpi)
	var items := [
		[Locale.t("lb_hg_k_date"), Calendar.label(), UIKit.ACCENT],
		[Locale.t("lb_hg_k_silver"), str(GameState.silver), UIKit.TEXT],
		[Locale.t("lb_hg_k_food"), str(GameState.food), UIKit.TEXT],
		[Locale.t("lb_hg_k_morale"), str(GameState.morale), UIKit.OK if GameState.morale >= 50 else UIKit.DANGER],
		[Locale.t("lb_hg_k_people"), str(GameState.roster().size()), UIKit.TEXT],
	]
	for it in items:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(228, 72)
		var sb := UIKit.flat_box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.12), 10)
		sb.content_margin_left = 14
		sb.content_margin_top = 8
		p.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		p.add_child(v)
		v.add_child(UIKit.mono(str(it[0]), 11, UIKit.TEXT_FAINT, false))
		v.add_child(UIKit.title_label(str(it[1]), 20, it[2]))
		_kpi.add_child(p)

func _show_forecast(months: int) -> void:
	CKPageKit.clear(_forecast)
	var evs: Array = Calendar.forecast(months)
	if evs.is_empty():
		_forecast.add_child(CKPageKit.text(Locale.t("lb_hg_quiet"), UIKit.TEXT_DIM, 14, 520))
	for e in evs:
		_forecast.add_child(_line(str(e.get("text", "")), UIKit.TEXT))
	_paint_threat_pending(_forecast)


## Territory closed-loop: pending siege threats on the forecast + deep-link to SiegeAlert.
func _paint_threat_pending(host: VBoxContainer) -> void:
	var ids: Array = CKTerritory.threatened_owned()
	if ids.is_empty():
		return
	var warn := _line(Locale.t("lb_hg_threat_pending", [ids.size()]), UIKit.DANGER)
	warn.name = "ThreatPending"
	host.add_child(warn)
	var btn := CKPageKit.button(Locale.t("lb_hg_to_siege"), true, 220)
	btn.name = "ToSiegeThreat"
	btn.pressed.connect(func():
		CKTerritory.hub_requeue_siege_alert()
		CKNav.go("res://scenes/hub/atlas_view.tscn")
	)
	host.add_child(btn)
	UIFX.wire_button(btn)

func _line(t: String, col: Color) -> Control:
	var r := CKPageKit.row(col, 40)
	(r[1] as VBoxContainer).add_child(CKPageKit.text(t, col, 14, 520))
	return r[0]

func _feel_dynasty_end() -> void:
	## Y1-B stub: empty-company / no-heir mid-run end — panel + freeze advance.
	if not Lineage.is_dynasty_ended():
		return
	Lineage.attach_dynasty_end_feel(_log, 520.0)
	for n in ["AdvanceMonth", "AdvanceSeason"]:
		var b := find_child(n, true, false) as BaseButton
		if b != null:
			b.disabled = true


func _advance(months: int, btn: Control) -> void:
	if _busy:
		return
	if Lineage.is_dynasty_ended():
		CKPageKit.say(_msg, Locale.t("lb_dynasty_end_blocked"), false)
		return
	_busy = true
	var evs: Array = Calendar.advance(months)
	CKPageKit.clear(_log)
	_log.add_child(UIKit.title_label(Locale.t("lb_hg_after", [Calendar.label(), months]), 15, UIKit.ACCENT))
	if evs.is_empty():
		_log.add_child(CKPageKit.text(Locale.t("lb_hg_after_quiet"), UIKit.TEXT_DIM, 14, 520))
	for e in evs:
		var deal := str(e.get("type", "")) == "rival_deal"
		_log.add_child(_line(str(e.get("text", "")), UIKit.ACCENT if deal else UIKit.TEXT))
	CKPageKit.drag_through(_log)
	UIFX.stagger_children(_log, 0.03, 0.2)
	_paint_kpis()
	_show_forecast(1)
	GameState.save_game()
	CKPageKit.say(_msg, Locale.t("lb_hg_done", [months, evs.size()]), true)
	UIFX.confirm(btn)
	_busy = false

func _to_harvest() -> void:
	var guard := 0
	while not GameState.flag("harvest_done") and guard < 24:
		Calendar.advance(1)
		guard += 1
	_paint_kpis()
	_show_forecast(1)
	CKPageKit.say(_msg, Calendar.label(), true)
	GameState.save_game()
