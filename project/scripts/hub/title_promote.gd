extends Control
## Merit ladder (line B, audit #21). Ladder row, four requirement cards (met ones read as met
## even when over the cap), a red list of what is still missing, and a request button that
## says why when it cannot be pressed. CKCourt.promote() is unchanged.

var _leader: CKCharacter
var _host: Control
var _msg: Label

func _ready() -> void:
	_leader = GameState.get_leader()
	CKPageKit.shell(self, Locale.t("lb_title_ctx"), "TITLE LADDER", Locale.t("lb_title_title"), Locale.t("lb_title_desc"))
	_msg = CKPageKit.feedback(self)
	_paint()
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "TITLE LADDER · FROST")
	UIFX.page_enter(self)

func apply_mobile_layout() -> void:
	if not MobilePage.active(self):
		return
	set_meta("m_center_ok", true)
	_paint()
	MobilePage.upsize(self)

func _paint() -> void:
	if _host:
		_host.queue_free()
	_host = Control.new()
	_host.name = "Ladder"
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)
	var mob := DeviceProfile.is_mobile()
	var w := MobilePage.width(self) if mob and is_inside_tree() else 1280.0
	var pad := 42.0 if not mob else 24.0
	var content_w := w - pad * 2.0
	var now := CKCourt.current_title(_leader)
	var step: Container = HFlowContainer.new() if mob else HBoxContainer.new()
	step.name = "LadderSteps"
	step.position = Vector2(pad, CKPageKit.TOP + 8)
	if mob:
		(step as HFlowContainer).add_theme_constant_override("h_separation", 10)
		(step as HFlowContainer).add_theme_constant_override("v_separation", 8)
		step.size = Vector2(content_w, 0)
	else:
		(step as HBoxContainer).add_theme_constant_override("separation", 10)
	_host.add_child(step)
	var ni := CKCourt.LADDER.find(now)
	var step_w := floorf((content_w - 40.0) / 5.0) if mob else 228.0
	for i in CKCourt.LADDER.size():
		var id := str(CKCourt.LADDER[i])
		var col: Color = UIKit.ACCENT if i == ni else (UIKit.OK if i < ni else (UIKit.TEXT if i == ni + 1 else UIKit.TEXT_FAINT))
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(step_w, 76 if mob else 64)
		p.add_theme_stylebox_override("panel", UIKit.flat_box(Color(col, 0.12), col, 10, 2 if i == ni else 1))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		p.add_child(v)
		var t := UIKit.title_label(CKCourt.ladder_zh(id, CKCourt._sex(_leader)), MobilePage.FONT if mob else 18, UIKit.TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if mob else TextServer.AUTOWRAP_OFF
		v.add_child(t)
		var tag := Locale.t("lb_title_now") if i == ni else (Locale.t("lb_title_done") if i < ni else (Locale.t("lb_title_next") if i == ni + 1 else ""))
		var s := UIKit.body_label(tag, col, MobilePage.FONT if mob else 12)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
		step.add_child(p)
	var rows: Array = CKCourt.requirement_rows(_leader, {})
	var grid_y := CKPageKit.TOP + (100.0 if mob else 92.0)
	var grid: Container = HFlowContainer.new() if mob else HBoxContainer.new()
	grid.name = "ReqGrid"
	grid.position = Vector2(pad, grid_y)
	if mob:
		(grid as HFlowContainer).add_theme_constant_override("h_separation", 12)
		(grid as HFlowContainer).add_theme_constant_override("v_separation", 10)
		grid.size = Vector2(content_w, 0)
	else:
		(grid as HBoxContainer).add_theme_constant_override("separation", 12)
	_host.add_child(grid)
	if rows.is_empty():
		grid.add_child(CKPageKit.empty(Locale.t("lb_title_top"), Locale.t("lb_title_top_why"), "", content_w - 40.0))
	for row in rows:
		grid.add_child(_req_card(row, content_w if mob else 0.0))
	var miss: Array = []
	for row in rows:
		var have := int(row.get("have", 0))
		var need := int(row.get("need", 0))
		if need > 0 and have < need:
			miss.append(_miss_text(row, need - have))
	var info_y := CKPageKit.TOP + (280.0 if mob else 260.0)
	var info := CKPageKit.card(_host, Rect2(pad, info_y, content_w, 150 if not mob else 170), "Missing")
	CKPageKit.card_head(info, Locale.t("lb_title_miss_head") if not miss.is_empty() else Locale.t("lb_title_ready_head"), "")
	var said := "\n".join(miss) if not miss.is_empty() else (Locale.t("lb_title_ready") if not rows.is_empty() else "")
	var body := CKPageKit.text(said, UIKit.DANGER if not miss.is_empty() else UIKit.OK, MobilePage.FONT if mob else 15, content_w - 46.0)
	body.position = Vector2(18, 50)
	body.size = Vector2(content_w - 46.0, 100 if mob else 90)
	info.add_child(body)
	var block := CKCourt.promotion_block(_leader, {})
	var go := CKPageKit.button(Locale.t("lb_title_go"), true, 260)
	go.name = "PromoteTitle"
	# Sit above the feedback strip so LockHint (why the button is grey) stays on-screen.
	var go_y := CKPageKit.TOP + (448.0 if mob else 418.0)
	go.position = Vector2(pad, go_y)
	if mob:
		go.size = Vector2(minf(360.0, content_w), MobilePage.HIT)
		go.custom_minimum_size = Vector2(220, MobilePage.HIT)
		go.add_theme_font_size_override("font_size", MobilePage.FONT)
	CKPageKit.lock(go, Locale.t("lb_title_block", [block]) if block != "" else "", true)
	go.pressed.connect(_promote)
	_host.add_child(go)
	UIFX.wire_tree(_host)
	UIFX.stagger_children(step, 0.05, 0.2)

func _miss_text(row: Dictionary, gap: int) -> String:
	match str(row.get("id", "")):
		"merit":
			return Locale.t("lb_title_miss_merit", [gap])
		"fiefs":
			return Locale.t("lb_title_miss_fiefs", [gap])
		"married":
			return Locale.t("lb_title_miss_married")
		"rep":
			return Locale.t("lb_title_miss_rep", [gap])
	return "%s %d" % [str(row.get("label", "")), gap]

func _req_card(row: Dictionary, host_w: float = 0.0) -> Control:
	var have := int(row.get("have", 0))
	var need := int(row.get("need", 0))
	var ok := need <= 0 or have >= need
	var mob := host_w > 0.0
	var card_w := floorf((host_w - 12.0) / 2.0) if mob else 290.0
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(card_w, 150 if mob else 140)
	p.add_theme_stylebox_override("panel", UIKit.glass(12, 0.8, ok))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(UIKit.title_label(str(row.get("label", "")), MobilePage.FONT if mob else 16, UIKit.TEXT))
	top.add_child(UIKit.tag_chip(Locale.t("lb_title_met") if ok else Locale.t("lb_title_unmet"), UIKit.OK if ok else UIKit.DANGER))
	var shown := mini(have, need) if need > 0 else have
	var num := UIKit.title_label("%d / %d" % [shown, need] if need > 0 else Locale.t("lb_title_not_needed"), 28, UIKit.OK if ok else UIKit.TEXT)
	v.add_child(num)
	if need > 0 and have > need:
		v.add_child(UIKit.body_label(Locale.t("lb_title_over", [have]), UIKit.TEXT_DIM, MobilePage.FONT if mob else 12))
	var bar_w := maxf(160.0, card_w - 40.0)
	v.add_child(UIKit.slim_bar(float(mini(have, maxi(need, 1))), float(maxi(need, 1)), UIKit.OK if ok else UIKit.DANGER, bar_w, 6))
	p.name = "Req" + str(row.get("id", "")).capitalize()
	return p

func _promote() -> void:
	if _leader == null:
		return
	var r := CKCourt.promote(_leader)
	CKPageKit.say(_msg, str(r.get("msg", "")), bool(r.get("ok", false)))
	if bool(r.get("ok", false)):
		Sfx.lineage_chime()
		UIFX.confirm_burst(_msg)
		_paint()
