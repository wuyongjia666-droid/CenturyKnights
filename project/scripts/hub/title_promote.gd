extends Control
## Merit ladder (line B, audit #21). Ladder row, four requirement cards (met ones read as met
## even when over the cap), a red list of what is still missing, and a request button that
## says why when it cannot be pressed. CKCourt.promote() is unchanged.
## Mobile: body stacks in a ScrollContainer so court_ui bounds / overlap stay clean on the
## 1280×720 design canvas (and on a real phone after safe-area scale).

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
	if DeviceProfile.is_mobile():
		_paint_mobile()
	else:
		_paint_desktop()

func _paint_desktop() -> void:
	var now := CKCourt.current_title(_leader)
	var step := HBoxContainer.new()
	step.name = "LadderSteps"
	step.position = Vector2(42, CKPageKit.TOP + 8)
	step.add_theme_constant_override("separation", 10)
	_host.add_child(step)
	var ni := CKCourt.LADDER.find(now)
	for i in CKCourt.LADDER.size():
		step.add_child(_ladder_chip(str(CKCourt.LADDER[i]), i, ni, false, 228.0))
	var rows: Array = CKCourt.requirement_rows(_leader, {})
	var grid := HBoxContainer.new()
	grid.name = "ReqGrid"
	grid.position = Vector2(42, CKPageKit.TOP + 92)
	grid.add_theme_constant_override("separation", 12)
	_host.add_child(grid)
	if rows.is_empty():
		_add_top_empty(grid, 1100.0)
	for row in rows:
		grid.add_child(_req_card(row, 0.0))
	var miss: Array = _miss_list(rows)
	var info := CKPageKit.card(_host, Rect2(42, CKPageKit.TOP + 260, 1196, 150), "Missing")
	CKPageKit.card_head(info, Locale.t("lb_title_miss_head") if not miss.is_empty() else Locale.t("lb_title_ready_head"), "")
	var said := "\n".join(miss) if not miss.is_empty() else (Locale.t("lb_title_ready") if not rows.is_empty() else "")
	var body := CKPageKit.text(said, UIKit.DANGER if not miss.is_empty() else UIKit.OK, 15, 1150)
	body.position = Vector2(18, 50)
	body.size = Vector2(1150, 90)
	info.add_child(body)
	var go := _promote_btn(false, 1196.0)
	go.position = Vector2(42, CKPageKit.TOP + 418)
	_host.add_child(go)
	UIFX.wire_tree(_host)
	UIFX.stagger_children(step, 0.05, 0.2)

func _paint_mobile() -> void:
	## Design canvas stays 1280×720 under CK_FORCE_MOBILE; stack + scroll so cards never sit on
	## absolute Y that collides with the miss panel / PromoteTitle lock hint.
	var w := MobilePage.width(self)
	var pad := 24.0
	var content_w := maxf(280.0, w - pad * 2.0)
	var sc := ScrollContainer.new()
	sc.name = "TitleScroll"
	sc.position = Vector2(0, CKPageKit.TOP)
	sc.size = Vector2(w, maxf(360.0, 720.0 - CKPageKit.TOP - 56.0))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_host.add_child(sc)
	var col := VBoxContainer.new()
	col.name = "TitleCol"
	col.custom_minimum_size = Vector2(content_w, 0)
	col.add_theme_constant_override("separation", 12)
	sc.add_child(col)
	# left pad via empty margin row
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", int(pad))
	wrap.add_theme_constant_override("margin_right", int(pad))
	wrap.add_theme_constant_override("margin_top", 8)
	wrap.add_theme_constant_override("margin_bottom", 12)
	col.add_child(wrap)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	wrap.add_child(inner)
	var now := CKCourt.current_title(_leader)
	var ni := CKCourt.LADDER.find(now)
	var step := HFlowContainer.new()
	step.name = "LadderSteps"
	step.add_theme_constant_override("h_separation", 10)
	step.add_theme_constant_override("v_separation", 8)
	step.custom_minimum_size = Vector2(content_w, 0)
	inner.add_child(step)
	var step_w := floorf((content_w - 40.0) / 5.0)
	step_w = maxf(100.0, step_w)
	for i in CKCourt.LADDER.size():
		step.add_child(_ladder_chip(str(CKCourt.LADDER[i]), i, ni, true, step_w))
	var rows: Array = CKCourt.requirement_rows(_leader, {})
	var grid := HFlowContainer.new()
	grid.name = "ReqGrid"
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.custom_minimum_size = Vector2(content_w, 0)
	inner.add_child(grid)
	if rows.is_empty():
		_add_top_empty(grid, content_w - 40.0)
	for row in rows:
		grid.add_child(_req_card(row, content_w))
	var miss: Array = _miss_list(rows)
	var info := PanelContainer.new()
	info.name = "Missing"
	info.custom_minimum_size = Vector2(content_w, 0)
	info.add_theme_stylebox_override("panel", UIKit.glass(12, 0.8, miss.is_empty()))
	inner.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 8)
	info.add_child(iv)
	iv.add_child(UIKit.title_label(Locale.t("lb_title_miss_head") if not miss.is_empty() else Locale.t("lb_title_ready_head"), MobilePage.FONT, UIKit.TEXT))
	var said := "\n".join(miss) if not miss.is_empty() else (Locale.t("lb_title_ready") if not rows.is_empty() else "")
	var body := UIKit.body_label(said, UIKit.DANGER if not miss.is_empty() else UIKit.OK, MobilePage.FONT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(content_w - 28.0, 0)
	iv.add_child(body)
	var go := _promote_btn(true, content_w)
	inner.add_child(go)
	UIFX.wire_tree(_host)
	UIFX.stagger_children(step, 0.05, 0.2)


func _add_top_empty(parent: Control, width: float) -> void:
	## Y1-B / heir #30: top-of-ladder empty gets how + named ToCity (职印 / 本城之事).
	var host := VBoxContainer.new()
	host.name = "EmptyHost"
	host.add_theme_constant_override("separation", 12)
	host.add_child(CKPageKit.empty(Locale.t("lb_title_top"), Locale.t("lb_title_top_why"), Locale.t("lb_title_top_how"), width))
	var acts := HBoxContainer.new()
	acts.name = "EmptyActions"
	acts.add_theme_constant_override("separation", 12)
	var to_c := CKPageKit.button(Locale.t("lb_title_to_city"), true, mini(360, int(width)))
	to_c.name = "ToCity"
	to_c.pressed.connect(func(): CKNav.go("res://scenes/hub/city.tscn"))
	acts.add_child(to_c)
	UIFX.wire_button(to_c)
	host.add_child(acts)
	parent.add_child(host)

func _ladder_chip(id: String, i: int, ni: int, mob: bool, step_w: float) -> Control:
	var col: Color = UIKit.ACCENT if i == ni else (UIKit.OK if i < ni else (UIKit.TEXT if i == ni + 1 else UIKit.TEXT_FAINT))
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(step_w, 76 if mob else 64)
	p.add_theme_stylebox_override("panel", UIKit.flat_box(Color(col, 0.12), col, 10, 2 if i == ni else 1))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var fs := MobilePage.FONT if mob else 18
	var t := UIKit.title_label(CKCourt.ladder_zh(id, CKCourt._sex(_leader)), fs, UIKit.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if mob else TextServer.AUTOWRAP_OFF
	v.add_child(t)
	var tag := Locale.t("lb_title_now") if i == ni else (Locale.t("lb_title_done") if i < ni else (Locale.t("lb_title_next") if i == ni + 1 else ""))
	var s := UIKit.body_label(tag, col, MobilePage.FONT if mob else 12)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	return p

func _miss_list(rows: Array) -> Array:
	var miss: Array = []
	for row in rows:
		var have := int(row.get("have", 0))
		var need := int(row.get("need", 0))
		if need > 0 and have < need:
			miss.append(_miss_text(row, need - have))
	return miss

func _promote_btn(mob: bool, content_w: float) -> Button:
	var block := CKCourt.promotion_block(_leader, {})
	var go := CKPageKit.button(Locale.t("lb_title_go"), true, 260 if not mob else int(minf(360.0, content_w)))
	go.name = "PromoteTitle"
	if mob:
		go.size = Vector2(minf(360.0, content_w), MobilePage.HIT)
		go.custom_minimum_size = Vector2(minf(360.0, content_w), MobilePage.HIT)
		go.add_theme_font_size_override("font_size", MobilePage.FONT)
	CKPageKit.lock(go, Locale.t("lb_title_block", [block]) if block != "" else "", true)
	go.pressed.connect(_promote)
	return go

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
	card_w = maxf(140.0, card_w)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(card_w, 150 if mob else 140)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_theme_stylebox_override("panel", UIKit.glass(12, 0.8, ok))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var title := UIKit.title_label(str(row.get("label", "")), MobilePage.FONT if mob else 16, UIKit.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	top.add_child(title)
	top.add_child(UIKit.tag_chip(Locale.t("lb_title_met") if ok else Locale.t("lb_title_unmet"), UIKit.OK if ok else UIKit.DANGER))
	var shown := mini(have, need) if need > 0 else have
	var num := UIKit.title_label("%d / %d" % [shown, need] if need > 0 else Locale.t("lb_title_not_needed"), 28, UIKit.OK if ok else UIKit.TEXT)
	v.add_child(num)
	if need > 0 and have > need:
		v.add_child(UIKit.body_label(Locale.t("lb_title_over", [have]), UIKit.TEXT_DIM, MobilePage.FONT if mob else 12))
	var bar_w := maxf(120.0, card_w - 40.0)
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
