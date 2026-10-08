extends Control
## 血脉图鉴 — ten nations, royal / noble / folk lines, law icons, discovered traits, royal skills.

var _body: Control
var _nation := ""
var _panel_w := 920.0

func _ready() -> void:
	UIKit.void_bg(self)
	UIKit.top_bar(self, "血脉图鉴", [["历", Calendar.label(), UIKit.TEXT_DIM]], "返回族谱", _back)
	UIKit.page_head(self, 42, 72, "CODEX // TEN NATIONS", "十邦血脉", "BLOODLINE CODEX", "血是所携，冕是所显。谱系公开，单条特征要见过或验过才写进图鉴。", "", 18)
	var rail := UIKit.panel_at(self, Rect2(42, 220, 236, 456), 12)
	rail.name = "NationRailPanel"
	var cap := UIKit.mono("NATIONS", 9, UIKit.TEXT_FAINT)
	cap.position = Vector2(16, 12)
	rail.add_child(cap)
	var sc := ScrollContainer.new()
	sc.position = Vector2(12, 36)
	sc.size = Vector2(212, 404)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail.add_child(sc)
	var box := VBoxContainer.new()
	box.name = "NationRail"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(200, 0)
	box.add_theme_constant_override("separation", 4)
	sc.add_child(box)
	var ids: Array = CKBloodline.nation_ids()
	for nid in ids:
		var nat: Dictionary = CKBloodline.nation(str(nid))
		var b := UIKit.ghost_button("", 200, 44)
		b.text = ""
		b.name = "Nation_" + str(nid)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = "%s · %s" % [str(nat.get("name", nid)), str(nat.get("motto", ""))]
		var mark := CKCourtChrome.nation_mark(str(nid))
		mark.position = Vector2(6, 4)
		b.add_child(mark)
		var nm := UIKit.body_label(str(nat.get("name", nid)), UIKit.TEXT, 14)
		nm.name = "NationName"
		nm.position = Vector2(48, 12)
		nm.size = Vector2(144, 22)
		nm.clip_text = true
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nm)
		var captured := str(nid)
		b.pressed.connect(func():
			_show(captured))
		box.add_child(b)
	_body = Control.new()
	_body.name = "CodexBody"
	_body.position = Vector2(294, 220)
	_body.size = Vector2(944, 456)
	add_child(_body)
	UIKit.footer_bar(self, [["ESC", "返回族谱"]], "BLOODLINE CODEX · FROST")
	if not ids.is_empty():
		_show(str(ids[0]))
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/lineage_view.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()

func _show(nid: String) -> void:
	_nation = nid
	for ch in _body.get_children():
		ch.queue_free()
	var nat: Dictionary = CKBloodline.nation(nid)
	var known := CKCourtChrome.known_states()
	var bw := _body.size.x
	var narrow := bw < 700.0
	_panel_w = maxf(240.0, bw - 24.0)
	var head_h := 176.0 if narrow else 96.0
	var head := UIKit.panel_at(_body, Rect2(0, 0, bw, head_h), 12, true)
	var law := str(nat.get("law", ""))
	var mark := CKCourtChrome.nation_mark(nid)
	mark.position = Vector2(16, 28)
	head.add_child(mark)
	var title := UIKit.title_label(str(nat.get("name", nid)), 26)
	title.position = Vector2(64, 12)
	title.size = Vector2(260.0 if not narrow else maxf(96.0, bw - 72.0), 34)
	title.clip_text = true
	head.add_child(title)
	var sub := UIKit.body_label("%s · %s" % [str(CKBloodline.data().get("laws", {}).get(law, {}).get("name", law)), str(nat.get("motto", ""))], UIKit.TEXT_DIM, 13)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.clip_text = true
	sub.position = Vector2(64, 50)
	sub.size = Vector2(maxf(96.0, bw - 72.0) if narrow else 400.0, 28)
	head.add_child(sub)
	var skill := _royal_skill(nid)
	var side := VBoxContainer.new()
	side.name = "PayoffColumn"
	side.add_theme_constant_override("separation", 2)
	if narrow:
		side.position = Vector2(12, 76)
		side.size = Vector2(bw - 24, 92)
	else:
		side.position = Vector2(500, 8)
		side.size = Vector2(bw - 516, 80)
	head.add_child(side)
	var sk := UIKit.body_label(str(skill.get("line", "")).split("\n")[0], UIKit.ACCENT, 12)
	sk.name = "RoyalSkill"
	sk.autowrap_mode = TextServer.AUTOWRAP_OFF
	sk.clip_text = true
	sk.tooltip_text = str(skill.get("tip", ""))
	side.add_child(sk)
	for t in CKBloodPayoff.for_nation(nid):
		var line := UIKit.body_label("%s · %s" % [str(t.get("zh", "")), str(t.get("effect", ""))], UIKit.TEXT, 12)
		line.name = "TacticEffect"
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.clip_text = true
		line.tooltip_text = str(t.get("effect", ""))
		side.add_child(line)
	var legend := UIKit.body_label(CKBloodPayoff.legend_zh(), UIKit.TEXT_DIM, 11)
	legend.autowrap_mode = TextServer.AUTOWRAP_OFF
	legend.clip_text = true
	side.add_child(legend)
	var scroll := ScrollContainer.new()
	scroll.name = "LineScroll"
	scroll.position = Vector2(0, (head_h + 12.0) if narrow else 108.0)
	scroll.size = Vector2(bw, maxf(160.0, _body.size.y - scroll.position.y))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(_panel_w, 0)
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)
	_line_card(col, str(nat.get("royal", "")), "王胤", known)
	for noble in nat.get("noble", []):
		_line_card(col, str(noble), "贵胤", known)
	_line_card(col, str(nat.get("folk", "")), "民胤", known)
	UIFX.stagger_children(col, 0.04, 0.22)
	UIFX.wire_tree(self)

func _line_card(parent: Node, line_id: String, tier_zh: String, known: Dictionary) -> void:
	if line_id == "":
		return
	var ln: Dictionary = CKBloodline.line(line_id)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UIKit.glass(12, 0.82))
	parent.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	inner.add_child(h)
	h.add_child(UIKit.tag_chip(tier_zh, UIKit.ACCENT if tier_zh == "王胤" else (UIKit.OK if tier_zh == "贵胤" else UIKit.TEXT_DIM)))
	var nm := UIKit.title_label(str(ln.get("name", line_id)), 18)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nm)
	var desc := UIKit.body_label(str(ln.get("desc", "")), UIKit.TEXT_DIM, 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(_panel_w - 8.0, 0)
	inner.add_child(desc)
	var traits := HFlowContainer.new()
	traits.add_theme_constant_override("h_separation", 8)
	traits.add_theme_constant_override("v_separation", 8)
	traits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	traits.custom_minimum_size = Vector2(_panel_w - 8.0, 0)
	inner.add_child(traits)
	var set: Array = ln.get("trait_set", [])
	if set.is_empty():
		traits.add_child(UIKit.body_label("此脉未列特征组。", UIKit.TEXT_FAINT, 12))
	for state_id in set:
		var meta := CKCourtChrome.state_meta(str(state_id))
		var seen: bool = known.has(str(state_id))
		if seen:
			traits.add_child(CKCourtChrome.trait_known(meta))
		else:
			traits.add_child(CKCourtChrome.trait_silhouette(str(meta.get("law", ""))))

func _royal_skill(nid: String) -> Dictionary:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs == null:
		return {"line": "", "tip": ""}
	for s in gs.data_skills.get("skills", []):
		if str(s.get("blood_sig", "")) != nid:
			continue
		var desc := str(s.get("desc", ""))
		return {"line": "王技 · %s\n%s" % [str(s.get("name", "")), desc], "tip": "%s\n%s" % [desc, CKBloodPayoff.legend_zh()]}
	return {"line": "此邦没有单独的王技。", "tip": CKBloodPayoff.legend_zh()}

func apply_mobile_layout() -> void:
	MobileLayout.pin_footer(get_node_or_null("StitchFooter"))
	var w := get_viewport_rect().size.x
	if w >= 1000.0 or _body == null:
		return
	var rail := get_node_or_null("NationRailPanel") as Control
	if rail:
		rail.position = Vector2(8, 168)
		rail.size = Vector2(112, 520)
	_body.position = Vector2(128, 168)
	_body.size = Vector2(maxf(220.0, w - 136.0), 560)
	if _nation != "":
		_show(_nation)
