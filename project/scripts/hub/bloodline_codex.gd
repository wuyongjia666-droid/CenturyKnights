extends Control
## 血脉图鉴 — ten nations, royal / noble / folk lines, law icons, discovered traits, royal skills.

const YeartraceUi := preload("res://scripts/hub/sui_yeartrace_ui.gd")
var _body: Control
var _nation := ""
var _panel_w := 920.0
var _hint: Label

func _ready() -> void:
	UIKit.void_bg(self)
	UIKit.top_bar(self, "血脉图鉴", [["历", Calendar.label(), UIKit.TEXT_DIM]], "返回族谱", _back)
	UIKit.page_head(self, 42, 72, "CODEX // TEN NATIONS", "十邦血脉", "BLOODLINE CODEX", Locale.t("lb_codex_legend"), "", 18)
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
		var rail_arms := CKHeraldryChrome.make_city_nation_arms(str(nid), Vector2(22, 26))
		rail_arms.position = Vector2(170, 8)
		b.add_child(rail_arms)
		var nm := UIKit.body_label(str(nat.get("name", nid)), UIKit.TEXT, 14)
		nm.name = "NationName"
		nm.position = Vector2(48, 12)
		nm.size = Vector2(144, 22)
		nm.clip_text = true
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nm)
		var captured := str(nid)
		b.pressed.connect(func():
			_show(captured))
		box.add_child(b)
	_body = Control.new()
	_body.name = "CodexBody"
	_body.position = Vector2(294, 220)
	_body.size = Vector2(944, 436)
	add_child(_body)
	CKPageKit.footer(self, [["ESC", Locale.t("btn_back")]], "BLOODLINE CODEX · FROST")
	_hint = CKPageKit.feedback(self)
	_hint.position = Vector2(294, 662)
	_hint.size = Vector2(944, 20)
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	if not ids.is_empty():
		_show(str(ids[0]))
	UIFX.page_enter(self)
	UIFX.wire_tree(self)
	apply_mobile_layout()

func _back() -> void:
	CKNav.up("res://scenes/hub/lineage_view.tscn")


func _show(nid: String) -> void:
	_nation = nid
	# Free immediately so a same-frame rebuild can reuse names (LineScroll).
	# queue_free leaves the old node in-tree until idle, and Godot then renames
	# the replacement to @ScrollContainer@N — court_ui looks up "LineScroll".
	for ch in _body.get_children():
		_body.remove_child(ch)
		ch.free()
	var nat: Dictionary = CKBloodline.nation(nid)
	var known := CKCourtChrome.known_states()
	var bw := _body.size.x
	var narrow := bw < 700.0
	_panel_w = maxf(240.0, bw - 24.0)
	var head_h := 176.0 if narrow else 96.0
	var phone := DeviceProfile.is_mobile() and not narrow
	if phone:
		head_h = 168.0  # 22px phone type: skill + effects + legend need ~4 lines
	var head := UIKit.panel_at(_body, Rect2(0, 0, bw, head_h), 12, true)
	var law := str(nat.get("law", ""))
	var mark := CKCourtChrome.nation_mark(nid)
	mark.position = Vector2(16, 28)
	head.add_child(mark)
	var strip_at := Vector2(bw - 96.0, 12.0) if not narrow else Vector2(maxf(12.0, bw - 100.0), 8.0)
	CKHeraldryField.place_nation_crest_strip(head, nid, strip_at, Vector2(36, 44) if not narrow else Vector2(32, 38))
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
		side.size = Vector2(bw - 516, (head_h - 16.0) if phone else 80.0)
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
	scroll.position = Vector2(0, (head_h + 12.0) if (narrow or phone) else 108.0)
	scroll.size = Vector2(bw, maxf(160.0, _body.size.y - scroll.position.y))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(_panel_w, 0)
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)
	GameState.set_meta("yeartrace_back", "res://scenes/hub/bloodline_codex.tscn")
	YeartraceUi.mount_house(col, maxf(200.0, _panel_w - 16.0), 6)
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
	var trait_ids: Array = ln.get("trait_set", [])
	if trait_ids.is_empty():
		traits.add_child(UIKit.body_label("此脉未列特征组。", UIKit.TEXT_FAINT, 12))
	for state_id in trait_ids:
		var meta := CKCourtChrome.state_meta(str(state_id))
		var seen: bool = known.has(str(state_id))
		if seen:
			traits.add_child(CKCourtChrome.trait_known(meta))
		else:
			traits.add_child(_unknown(str(meta.get("law", ""))))

## Audit #58: an unseen trait reads as "?" and tapping it says how to unlock it (no hover on touch).
func _unknown(law: String) -> Control:
	var sil := CKCourtChrome.trait_silhouette(law)
	# Track the silhouette's real width: the phone type floor widens the law chip after build, and a
	# fixed wrapper let the chip spill onto its neighbour in the flow (mobile polish: chip crowding).
	var wrap := Control.new()
	wrap.name = "UnknownTrait"
	wrap.custom_minimum_size = sil.custom_minimum_size
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	wrap.add_child(sil)
	var q := UIKit.title_label("?", 18, UIKit.ACCENT)
	q.name = "UnknownMark"
	q.position = Vector2(124, 4)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(q)
	if DeviceProfile.is_mobile():
		sil.resized.connect(func():
			wrap.custom_minimum_size = Vector2(maxf(sil.custom_minimum_size.x, sil.size.x), sil.custom_minimum_size.y)
			q.position.x = sil.size.x - 24.0)
	sil.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			CKPageKit.say(_hint, Locale.t("lb_codex_unknown"), true))
	return wrap

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
	# Prefer the fitted design root when present so suite / phone-fit paths are
	# deterministic; fall back to the physical viewport only when the root has
	# not been sized yet (court_ui headless load).
	var vp := size
	if vp.x < 64.0 or vp.y < 64.0:
		vp = get_viewport_rect().size
	_fit_chrome(vp)
	if _body == null:
		return
	# Wide root keeps the desktop side rail (court_ui @ 1280×720/1280). Compact
	# nation strip is for portrait / narrow roots only.
	if vp.x >= 1100.0 and vp.y >= 680.0:
		return
	var rail := get_node_or_null("NationRailPanel") as Control
	if rail == null:
		return
	var margin := 8.0
	# Sit below page_head legend so NATIONS / nation chips do not overlap it.
	var top := 200.0
	var rail_h := 56.0
	rail.clip_contents = true
	rail.position = Vector2(margin, top)
	rail.size = Vector2(maxf(160.0, vp.x - margin * 2.0), rail_h)
	# Hide the desktop "NATIONS" mono caption — no room in the strip, and it
	# overlapped the page_head legend + nation name chips under court_ui.
	for ch in rail.get_children():
		if ch is Label:
			(ch as Label).visible = false
	var sc := _rail_scroll(rail)
	if sc:
		sc.position = Vector2(8, 4)
		sc.size = Vector2(maxf(80.0, rail.size.x - 16.0), rail_h - 8.0)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_nation_row(sc)
	var foot := get_node_or_null("StitchFooter") as Control
	var foot_y := vp.y - 8.0
	if foot:
		foot_y = foot.position.y
	_body.clip_contents = true
	_body.position = Vector2(margin, top + rail_h + 8.0)
	_body.size = Vector2(rail.size.x, maxf(120.0, foot_y - 8.0 - _body.position.y))
	if _nation != "":
		_show(_nation)

func _fit_chrome(vp: Vector2) -> void:
	var bar := get_node_or_null("StitchTopBar") as Control
	if bar and vp.x < 1270.0:
		bar.size.x = vp.x
		var right: HBoxContainer = null
		for ch in bar.get_children():
			if ch is ColorRect:
				(ch as ColorRect).size.x = vp.x
			elif ch is HBoxContainer:
				right = ch
		if right:
			var width := minf(right.get_combined_minimum_size().x, maxf(140.0, vp.x * 0.42))
			right.position = Vector2(vp.x - 8.0 - width, right.position.y)
			right.size = Vector2(width, right.size.y)
			right.clip_contents = true
			for ch2 in bar.get_children():
				if ch2 is Label and (ch2 as Label).position.x > 120.0:
					var lab := ch2 as Label
					lab.size = Vector2(maxf(48.0, right.position.x - lab.position.x - 8.0), 26)
					lab.clip_text = true
					lab.autowrap_mode = TextServer.AUTOWRAP_OFF
					lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var foot := get_node_or_null("StitchFooter") as Control
	MobileLayout.pin_footer(foot)
	if foot == null:
		return
	if vp.y < 680.0:
		foot.position.y = vp.y - foot.size.y
	foot.size.x = vp.x
	foot.clip_contents = true
	for ch3 in foot.get_children():
		if ch3 is ColorRect:
			(ch3 as ColorRect).size.x = vp.x
		elif ch3 is Label and vp.x < 1100.0:
			(ch3 as Label).visible = false

func _rail_scroll(rail: Control) -> ScrollContainer:
	for ch in rail.get_children():
		if ch is ScrollContainer:
			return ch
	return null

func _nation_row(sc: ScrollContainer) -> void:
	var box := sc.get_node_or_null("NationRail")
	if box == null:
		return
	var row := box
	if box is VBoxContainer:
		row = HBoxContainer.new()
		row.name = "NationRail"
		row.add_theme_constant_override("separation", 4)
		for k in box.get_children():
			box.remove_child(k)
			row.add_child(k)
		sc.remove_child(box)
		box.queue_free()
		sc.add_child(row)
	for b in row.get_children():
		if not (b is Button):
			continue
		(b as Button).custom_minimum_size = Vector2(128, 44)
		var nm := b.get_node_or_null("NationName") as Label
		if nm == null:
			continue
		nm.position = Vector2(40, 11)
		nm.size = Vector2(82, 22)
		nm.clip_text = true
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
