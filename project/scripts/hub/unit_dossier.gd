extends Control
## One unit: expressed and carried traits, parent source, purity, age stage, title, family tree.

var _focus: CKCharacter

func _ready() -> void:
	_focus = _resolve()
	UIKit.void_bg(self)
	var who := _focus.name if _focus != null else "无人"
	UIKit.top_bar(self, "血脉详档 · %s" % who, [["历", Calendar.label(), UIKit.TEXT_DIM]], "返回", _back)
	UIKit.page_head(self, 42, 72, "UNIT DOSSIER", who, "EXPRESSED / CARRIED", "明征写在脸上。携因要祠堂验过才展开，并注明来自父或母。")
	_build()
	UIKit.footer_bar(self, [["Y", "血脉图鉴"], ["ESC", "返回"]], "UNIT DOSSIER · FROST")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func apply_mobile_layout() -> void:
	MobileLayout.pin_footer(get_node_or_null("StitchFooter"))

func _resolve() -> CKCharacter:
	var want := ""
	if GameState.has_meta("dossier_id"):
		want = str(GameState.get_meta("dossier_id"))
	if want != "" and GameState.characters.has(want):
		return GameState.characters[want]
	return GameState.get_leader()

func _back() -> void:
	var dest := "res://scenes/hub/roster.tscn"
	if GameState.has_meta("dossier_back"):
		dest = str(GameState.get_meta("dossier_back"))
	get_tree().change_scene_to_file(dest)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()
	elif e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_Y:
		get_tree().change_scene_to_file("res://scenes/hub/bloodline_codex.tscn")

func _build() -> void:
	var c := _focus
	var sheet: Dictionary = CKCourtChrome.unit_sheet(c)
	var left := UIKit.panel_at(self, Rect2(42, 168, 300, 508), 12, true)
	left.name = "PortraitColumn"
	if c != null:
		UIKit.portrait_plate(left, Rect2(18, 16, 264, 300), c, CKGenomePortrait.STAGE_ZH.get(str(sheet.get("stage", "")), ""))
	var stage := UIKit.tag_chip("龄段 · %s" % str(sheet.get("stage_zh", "—")), UIKit.ACCENT, true)
	stage.name = "AgeStage"
	stage.position = Vector2(18, 328)
	left.add_child(stage)
	var title := UIKit.tag_chip("爵 · %s" % str(sheet.get("title", "—")), UIKit.TEXT)
	title.name = "TitleChip"
	title.position = Vector2(150, 328)
	left.add_child(title)
	var line := UIKit.title_label(str(sheet.get("line_zh", "—")), 18)
	line.position = Vector2(18, 368)
	left.add_child(line)
	var pur := UIKit.mono("纯度 %d%%" % int(sheet.get("purity", 0)), 16, UIKit.ACCENT, false)
	pur.name = "PurityReadout"
	pur.position = Vector2(18, 398)
	left.add_child(pur)
	var pbar := UIKit.slim_bar(float(sheet.get("purity", 0)), 100.0, UIKit.ACCENT, 260, 6)
	pbar.name = "PurityBar"
	pbar.position = Vector2(18, 426)
	left.add_child(pbar)
	var verified := "已验血" if bool(sheet.get("verified", false)) else "尚未验血 · 携因不公开"
	var note := UIKit.body_label(verified, UIKit.OK if bool(sheet.get("verified", false)) else UIKit.TEXT_FAINT, 12)
	note.position = Vector2(18, 446)
	note.size = Vector2(264, 40)
	left.add_child(note)
	var mid := UIKit.panel_at(self, Rect2(358, 168, 440, 508), 12)
	mid.name = "TraitList"
	var sh := UIKit.mono("EXPRESSED", 9, UIKit.ACCENT)
	sh.position = Vector2(16, 14)
	mid.add_child(sh)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 36)
	scroll.size = Vector2(416, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(400, 0)
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	_trait_block(col, "显出", sheet.get("shown", []), UIKit.OK)
	var carry_title := "携因" if bool(sheet.get("verified", false)) else "携因 · 验血后可见"
	_trait_block(col, carry_title, sheet.get("carried", []) if bool(sheet.get("verified", false)) else [], UIKit.ACCENT)
	if not bool(sheet.get("verified", false)):
		col.add_child(UIKit.body_label("祠堂验血之前，潜征保持未识。", UIKit.TEXT_FAINT, 12))
	var right := UIKit.panel_at(self, Rect2(814, 168, 424, 508), 12)
	right.name = "FamilyTree"
	var fh := UIKit.mono("FAMILY · TRAIT HIGHLIGHT", 9, UIKit.TEXT_FAINT)
	fh.position = Vector2(16, 14)
	right.add_child(fh)
	var tree_scroll := ScrollContainer.new()
	tree_scroll.position = Vector2(12, 40)
	tree_scroll.size = Vector2(400, 400)
	tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(tree_scroll)
	var tree := VBoxContainer.new()
	tree.custom_minimum_size = Vector2(380, 0)
	tree.add_theme_constant_override("separation", 8)
	tree_scroll.add_child(tree)
	_tree(tree, c, sheet)
	var codex := UIKit.ghost_button("打开血脉图鉴", 180, 44)
	codex.name = "OpenCodex"
	codex.position = Vector2(220, 452)
	codex.pressed.connect(func():
		Sfx.click()
		get_tree().change_scene_to_file("res://scenes/hub/bloodline_codex.tscn"))
	right.add_child(codex)

func _trait_block(parent: Node, title: String, rows: Array, col: Color) -> void:
	parent.add_child(UIKit.mono(title, 11, col, false))
	if rows.is_empty():
		parent.add_child(UIKit.body_label("（无）", UIKit.TEXT_FAINT, 12))
		return
	for e in rows:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(380, 44)
		card.add_theme_stylebox_override("panel", UIKit.flat_box(Color(col, 0.08), Color(col, 0.35), 8))
		parent.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 6)
		v.add_child(top)
		top.add_child(CKCourtChrome.law_chip(str(e.get("law", ""))))
		var nm := UIKit.body_label(str(e.get("zh", e.get("state", ""))), UIKit.TEXT, 14)
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(nm)
		v.add_child(UIKit.body_label("%s · %s" % [str(e.get("law_zh", "")), str(e.get("from", ""))], UIKit.TEXT_DIM, 12))

func _tree(parent: Node, focus: CKCharacter, sheet: Dictionary) -> void:
	if focus == null:
		parent.add_child(UIKit.empty_state("谱上还没有这个人。"))
		return
	var focus_states := {}
	for e in sheet.get("shown", []):
		focus_states[str(e.get("state", ""))] = str(e.get("zh", ""))
	var rows: Array = []
	rows.append({"label": "父母", "people": _people(focus.parent_ids)})
	var self_row: Array = [focus]
	if str(focus.spouse_id) != "" and GameState.characters.has(str(focus.spouse_id)):
		self_row.append(GameState.characters[str(focus.spouse_id)])
	rows.append({"label": "本人", "people": self_row})
	rows.append({"label": "子女", "people": _people(focus.children_ids)})
	for row in rows:
		parent.add_child(UIKit.mono(str(row["label"]), 10, UIKit.TEXT_FAINT, false))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		parent.add_child(h)
		var people: Array = row["people"]
		if people.is_empty():
			h.add_child(UIKit.body_label("—", UIKit.TEXT_FAINT, 12))
			continue
		for p in people:
			h.add_child(_person_chip(p, focus, focus_states))

func _people(ids) -> Array:
	var out: Array = []
	if typeof(ids) != TYPE_ARRAY:
		return out
	for id in ids:
		if GameState.characters.has(str(id)):
			out.append(GameState.characters[str(id)])
	return out

func _person_chip(p: CKCharacter, focus: CKCharacter, focus_states: Dictionary) -> Control:
	var share := ""
	var their: Dictionary = CKCourtChrome.unit_sheet(p)
	for e in their.get("shown", []):
		if focus_states.has(str(e.get("state", ""))):
			share = str(e.get("zh", ""))
			break
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 64)
	b.focus_mode = Control.FOCUS_ALL
	b.text = "%s\n%s · %s" % [p.name, CKGenomePortrait.STAGE_ZH.get(CKGenomePortrait.stage_for_age(p.age), ""), CKCourt.ladder_zh(CKCourt.current_title(p))]
	if share != "" and p != focus:
		b.text += "\n同征 " + share
	var on := p == focus
	var bd := UIKit.OK if share != "" else (UIKit.ACCENT if on else Color(1, 1, 1, 0.16))
	UIKit._apply_states(b, {
		"normal": UIKit.flat_box(Color(UIKit.OK, 0.10) if share != "" else Color(1, 1, 1, 0.03), bd, 8, 2 if share != "" or on else 1),
		"hover": UIKit.flat_box(Color(UIKit.ACCENT, 0.12), UIKit.ACCENT, 8, 1),
		"pressed": UIKit.flat_box(Color(UIKit.ACCENT, 0.2), UIKit.ACCENT, 8, 2),
		"focus": UIKit._focus_ring(UIKit.FOCUS_RING, 10),
		"disabled": UIKit.flat_box(UIKit.DISABLED_BG, UIKit.DISABLED_BORDER, 8, 1),
	})
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", UIKit.TEXT)
	var captured := p
	b.pressed.connect(func():
		Sfx.click()
		UIFX.press_feedback(b)
		GameState.set_meta("dossier_id", captured.id)
		get_tree().change_scene_to_file("res://scenes/hub/unit_dossier.tscn"))
	return b
