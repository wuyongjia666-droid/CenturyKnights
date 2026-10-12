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

func _paint() -> void:
	if _host:
		_host.queue_free()
	_host = Control.new()
	_host.name = "Ladder"
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)
	var now := CKCourt.current_title(_leader)
	var step := HBoxContainer.new()
	step.position = Vector2(42, CKPageKit.TOP + 8)
	step.add_theme_constant_override("separation", 10)
	_host.add_child(step)
	var ni := CKCourt.LADDER.find(now)
	for i in CKCourt.LADDER.size():
		var id := str(CKCourt.LADDER[i])
		var col: Color = UIKit.ACCENT if i == ni else (UIKit.OK if i < ni else (UIKit.TEXT if i == ni + 1 else UIKit.TEXT_FAINT))
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(228, 64)
		p.add_theme_stylebox_override("panel", UIKit.flat_box(Color(col, 0.12), col, 10, 2 if i == ni else 1))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		p.add_child(v)
		var t := UIKit.title_label(CKCourt.ladder_zh(id), 18, UIKit.TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var tag := Locale.t("lb_title_now") if i == ni else (Locale.t("lb_title_done") if i < ni else (Locale.t("lb_title_next") if i == ni + 1 else ""))
		var s := UIKit.body_label(tag, col, 12)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
		step.add_child(p)
	var rows: Array = CKCourt.requirement_rows(_leader, {})
	var grid := HBoxContainer.new()
	grid.position = Vector2(42, CKPageKit.TOP + 92)
	grid.add_theme_constant_override("separation", 12)
	_host.add_child(grid)
	if rows.is_empty():
		grid.add_child(CKPageKit.empty(Locale.t("lb_title_top"), Locale.t("lb_title_top_why"), "", 1100))
	for row in rows:
		grid.add_child(_req_card(row))
	var miss: Array = []
	for row in rows:
		var have := int(row.get("have", 0))
		var need := int(row.get("need", 0))
		if need > 0 and have < need:
			miss.append(_miss_text(row, need - have))
	var info := CKPageKit.card(_host, Rect2(42, CKPageKit.TOP + 260, 1196, 150), "Missing")
	CKPageKit.card_head(info, Locale.t("lb_title_miss_head") if not miss.is_empty() else Locale.t("lb_title_ready_head"), "")
	var body := CKPageKit.text("\n".join(miss) if not miss.is_empty() else (Locale.t("lb_title_ready") if not rows.is_empty() else ""), UIKit.DANGER if not miss.is_empty() else UIKit.OK, 15, 1150)
	body.position = Vector2(18, 50)
	body.size = Vector2(1150, 90)
	info.add_child(body)
	var block := CKCourt.promotion_block(_leader, {})
	var go := CKPageKit.button(Locale.t("lb_title_go"), true, 260)
	go.name = "PromoteTitle"
	go.position = Vector2(42, CKPageKit.TOP + 426)
	CKPageKit.lock(go, Locale.t("lb_title_block", [block]) if block != "" else "")
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

func _req_card(row: Dictionary) -> Control:
	var have := int(row.get("have", 0))
	var need := int(row.get("need", 0))
	var ok := need <= 0 or have >= need
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(290, 140)
	p.add_theme_stylebox_override("panel", UIKit.glass(12, 0.8, ok))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(UIKit.title_label(str(row.get("label", "")), 16, UIKit.TEXT))
	top.add_child(UIKit.tag_chip(Locale.t("lb_title_met") if ok else Locale.t("lb_title_unmet"), UIKit.OK if ok else UIKit.DANGER))
	var shown := mini(have, need) if need > 0 else have
	var num := UIKit.title_label("%d / %d" % [shown, need] if need > 0 else Locale.t("lb_title_not_needed"), 28, UIKit.OK if ok else UIKit.TEXT)
	v.add_child(num)
	if need > 0 and have > need:
		v.add_child(UIKit.body_label(Locale.t("lb_title_over", [have]), UIKit.TEXT_DIM, 12))
	v.add_child(UIKit.slim_bar(float(mini(have, maxi(need, 1))), float(maxi(need, 1)), UIKit.OK if ok else UIKit.DANGER, 250, 6))
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
