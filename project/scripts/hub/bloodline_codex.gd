extends Control
## 血脉图鉴 — ten nations, royal / noble / folk lines, law icons, discovered traits, royal skills.

var _body: Control
var _nation := ""

func _ready() -> void:
	UIKit.void_bg(self)
	UIKit.top_bar(self, "血脉图鉴", [["历", Calendar.label(), UIKit.TEXT_DIM]], "返回族谱", _back)
	UIKit.page_head(self, 42, 72, "CODEX // TEN NATIONS", "十邦血脉", "BLOODLINE CODEX", "血是所携，冕是所显。谱系公开，单条特征要见过或验过才写进图鉴。")
	var rail := UIKit.panel_at(self, Rect2(42, 168, 236, 508), 12)
	var cap := UIKit.mono("NATIONS", 9, UIKit.TEXT_FAINT)
	cap.position = Vector2(16, 12)
	rail.add_child(cap)
	var sc := ScrollContainer.new()
	sc.position = Vector2(12, 36)
	sc.size = Vector2(212, 456)
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
		var b := UIKit.ghost_button("%s  %s" % [CKCourtChrome.law_glyph(str(nat.get("law", ""))), str(nat.get("name", nid))], 212, 44)
		b.name = "Nation_" + str(nid)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var captured := str(nid)
		b.pressed.connect(func():
			Sfx.click()
			_show(captured))
		box.add_child(b)
	_body = Control.new()
	_body.name = "CodexBody"
	_body.position = Vector2(294, 168)
	_body.size = Vector2(944, 508)
	add_child(_body)
	UIKit.footer_bar(self, [["ESC", "返回族谱"]], "BLOODLINE CODEX · FROST")
	if not ids.is_empty():
		_show(str(ids[0]))
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func apply_mobile_layout() -> void:
	MobileLayout.pin_footer(get_node_or_null("StitchFooter"))

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
	var head := UIKit.panel_at(_body, Rect2(0, 0, 944, 92), 12, true)
	var law := str(nat.get("law", ""))
	var chip := CKCourtChrome.law_chip(law)
	chip.position = Vector2(18, 22)
	head.add_child(chip)
	var title := UIKit.title_label(str(nat.get("name", nid)), 26)
	title.position = Vector2(74, 14)
	head.add_child(title)
	var sub := UIKit.body_label("%s · %s" % [str(CKBloodline.data().get("laws", {}).get(law, {}).get("name", law)), str(nat.get("motto", ""))], UIKit.TEXT_DIM, 13)
	sub.position = Vector2(74, 50)
	sub.size = Vector2(640, 28)
	head.add_child(sub)
	var skill := _royal_skill(nid)
	var sk := UIKit.body_label(skill, UIKit.ACCENT, 12)
	sk.name = "RoyalSkill"
	sk.position = Vector2(620, 18)
	sk.size = Vector2(300, 56)
	sk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(sk)
	var scroll := ScrollContainer.new()
	scroll.name = "LineScroll"
	scroll.position = Vector2(0, 104)
	scroll.size = Vector2(944, 404)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(920, 0)
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
	desc.custom_minimum_size = Vector2(860, 0)
	inner.add_child(desc)
	var traits := HFlowContainer.new()
	traits.add_theme_constant_override("h_separation", 8)
	traits.add_theme_constant_override("v_separation", 8)
	inner.add_child(traits)
	var set: Array = ln.get("trait_set", [])
	if set.is_empty():
		traits.add_child(UIKit.body_label("此脉未列特征组。", UIKit.TEXT_FAINT, 12))
	for state_id in set:
		var meta := CKCourtChrome.state_meta(str(state_id))
		var seen: bool = known.has(str(state_id))
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 6)
		chip.custom_minimum_size = Vector2(0, 44)
		traits.add_child(chip)
		if str(meta.get("law", "")) != "":
			chip.add_child(CKCourtChrome.law_chip(str(meta["law"])))
		if seen:
			var lab := UIKit.tag_chip(str(meta.get("zh", state_id)), UIKit.OK, true)
			lab.tooltip_text = str(meta.get("desc", ""))
			chip.add_child(lab)
		else:
			var hid := UIKit.tag_chip("未识征", UIKit.TEXT_FAINT)
			hid.tooltip_text = "见过或在祠堂验到之后，图鉴才写下名字。"
			chip.add_child(hid)

func _royal_skill(nid: String) -> String:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs == null:
		return ""
	for s in gs.data_skills.get("skills", []):
		if str(s.get("blood_sig", "")) != nid:
			continue
		return "王技 · %s\n%s" % [str(s.get("name", "")), str(s.get("desc", ""))]
	return "此邦没有单独的王技。"
