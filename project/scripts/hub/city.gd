extends Control
## v8.7 城镇 — every settlement on the atlas opens here. Tabs:
## 概览 (rep ladder · turn-ins · intel) · 铁匠铺 (regional line + signature arms, buy / forge with materials)
## 市集 (regional goods, supply-driven prices, known best sell elsewhere) · 委托榜 (city board, accept / turn in)
## 酒馆 (regional-blood recruits) · 军械库 (equip world arms on the roster, live stat compare)

const _Atlas = preload("res://scripts/art/atlas_art.gd")
const ATLAS := "res://scenes/hub/atlas_view.tscn"
var tabs := [["overview", "概览"], ["smith", "铁匠铺"], ["market", "市集"], ["sundry", Locale.t("sundry_title")], ["board", "委托榜"], ["tavern", "酒馆"], ["armory", "军械库"], ["lamp", "灯籍"]]
const TYPE_GLYPH := {"sword": "剑", "blade": "刀", "spear": "枪", "lance": "骑", "axe": "斧", "bow": "弓", "crossbow": "弩", "staff": "杖", "focus": "器", "armor": "甲", "shield": "盾", "charm": "符"}
const TIER_COL := [Color("#9AA6B8"), Color("#9AA6B8"), Color("#5EE0B5"), Color("#6ED4FF"), Color("#C9B8FF")]
const CONTENT := Rect2(416, 108, 848, 576)

var city := ""
var tab := "overview"
var _sel_item := ""
var _sel_quest := ""
var _sel_char := ""
var _board_filter := "all"   # all / battle / trade
const BOARD_FILTERS := [["all", "全部"], ["battle", "战斗"], ["trade", "商旅"]]
var _top: Control
var _side: Control
var _tabbar: HBoxContainer
var _body: Control
var _toast: Label
var _tab_btn: Dictionary = {}
const MobileReflow := preload("res://scripts/platform/mobile_reflow.gd")
const M_SIDE_W := 420.0
var _mob := false
var _m_body_w := 800.0
var _m_w := 1280.0
var _m_top := 180.0

func _ready() -> void:
	city = str(GameState.get_meta("city_id", World.pos)) if GameState.has_meta("city_id") else World.pos
	if not World.nodes.has(city) or city != World.pos:
		city = World.pos
	World.note_city_gate("in")
	UIKit.void_bg(self)
	_add_backdrop()
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	_side = Control.new()
	_side.name = "CityCard"
	add_child(_side)
	_tabbar = HBoxContainer.new()
	_tabbar.name = "Tabs"
	_tabbar.position = Vector2(416, 64)
	_tabbar.add_theme_constant_override("separation", 6)
	add_child(_tabbar)
	## 八个页签要挤进内容区 848 宽，不能超出屏幕右边。
	var tab_w := int(floor((CONTENT.size.x - 6.0 * (tabs.size() - 1)) / tabs.size()))
	for t in tabs:
		var b := UIKit.ghost_button(str(t[1]), tab_w, 34)
		b.name = "Tab_" + str(t[0])
		var tid := str(t[0])
		b.pressed.connect(func(): _set_tab(tid))
		_tabbar.add_child(b)
		_tab_btn[tid] = b
	_body = Control.new()
	_body.name = "Body"
	_body.position = CONTENT.position
	_body.size = CONTENT.size
	add_child(_body)
	_mobile_frame()
	_toast = UIKit.body_label("", UIKit.TEXT, 12)
	_toast.name = "CityToast"
	_toast.autowrap_mode = TextServer.AUTOWRAP_OFF
	_toast.position = Vector2(416, 652)
	var tst := UIKit.flat_box(Color(0.03, 0.04, 0.06, 0.92), Color(UIKit.ACCENT, 0.45), 6)
	tst.content_margin_top = 4
	tst.content_margin_bottom = 4
	_toast.add_theme_stylebox_override("normal", tst)
	_toast.visible = false
	add_child(_toast)
	if not World.visited.has(city):
		World.arrive(city)
	_refresh_all()
	if GameState.has_meta("city_tab"):
		_set_tab(str(GameState.get_meta("city_tab")))
		GameState.remove_meta("city_tab")
	if _mob:
		_toast.position = Vector2(32.0, 720.0 - 72.0)
		_toast.z_index = 20
		_toast.add_theme_font_size_override("font_size", MobilePage.FONT)
	else:
		UIKit.footer_bar(self, [["Q/E", "切换页签"], ["A", "选择 / 确认"], ["ESC", Locale.t("atlas_gate_leave")]], "SETTLEMENT · FROST_TACTICAL v8.7")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

## Landscape phone (docs/design/mobile-landscape.md): 76px top bar; every tab visible in one
## full-width tab row; below it the tab's panels sit side by side as content cards (desktop
## width ratios kept). The city card is the left column of 概览 only, so the shop, board and
## tavern tabs get the whole width.
func _mobile_frame() -> void:
	if not MobilePage.active(self):
		return
	_mob = true
	var vp := get_viewport().get_visible_rect().size
	var w := maxf(1280.0, vp.x * 720.0 / maxf(1.0, vp.y))
	_m_w = w
	var top := MobilePage.TOP + 4.0
	# Eight tabs at 22px often need horizontal scroll on 16:9 phones.
	var tab_host := get_node_or_null("TabScroll") as ScrollContainer
	if tab_host == null:
		tab_host = ScrollContainer.new()
		tab_host.name = "TabScroll"
		tab_host.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tab_host.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		remove_child(_tabbar)
		add_child(tab_host)
		tab_host.add_child(_tabbar)
	tab_host.position = Vector2(16, top)
	tab_host.size = Vector2(w - 32.0, MobilePage.HIT)
	_tabbar.position = Vector2.ZERO
	_tabbar.add_theme_constant_override("separation", 8)
	for b in _tabbar.get_children():
		var bc := b as Button
		bc.custom_minimum_size = Vector2(148.0, MobilePage.HIT)
		bc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bc.add_theme_font_size_override("font_size", MobilePage.FONT)
		bc.clip_text = false
	_m_top = top + MobilePage.HIT + 12.0
	var h := 720.0 - _m_top - 12.0
	var side_stack := MobileReflow.column(self, "MobileSide", Rect2(16, _m_top, M_SIDE_W, h))
	remove_child(_side)
	side_stack.add_child(_side)
	_swap_box(_side, side_stack, func(b): _side = b)
	var body_stack := MobileReflow.column(self, "MobileBody", Rect2(16, _m_top, w - 32.0, h))
	remove_child(_body)
	body_stack.add_child(_body)
	var row := HBoxContainer.new()
	row.name = "Body"
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_stack.remove_child(_body)
	_body.queue_free()
	body_stack.add_child(row)
	_body = row
	row.child_entered_tree.connect(func(_n): _queue_reflow(row))


## Chrome calls this on fit/resize. First landscape pass frames the page; later
## passes only retarget width so TabScroll / columns stay inside the safe area.
func apply_mobile_layout() -> void:
	if not MobilePage.active(self):
		return
	if not _mob:
		_mobile_frame()
		if _mob:
			_toast.position = Vector2(32.0, 720.0 - 72.0)
			_toast.z_index = 20
			_toast.add_theme_font_size_override("font_size", MobilePage.FONT)
			var foot := find_child("StitchFooter", true, false) as CanvasItem
			if foot:
				foot.visible = false
			_refresh_all()
		return
	var vp := get_viewport().get_visible_rect().size
	var w := maxf(1280.0, vp.x * 720.0 / maxf(1.0, vp.y))
	if absf(w - _m_w) < 1.0:
		_m_layout()
		return
	_m_w = w
	var tab_host := get_node_or_null("TabScroll") as Control
	if tab_host:
		tab_host.size = Vector2(w - 32.0, MobilePage.HIT)
	else:
		_tabbar.size = Vector2(w - 32.0, MobilePage.HIT)
	_m_layout()
	_refresh_top()


## 概览 keeps the city card on the left; other tabs use the full width.
func _m_layout() -> void:
	if not _mob:
		return
	var side_sc := get_node_or_null("MobileSide") as Control
	var body_sc := get_node_or_null("MobileBody") as Control
	if side_sc == null or body_sc == null:
		return
	var with_card := tab == "overview"
	side_sc.visible = with_card
	var x := 16.0 + (M_SIDE_W + 16.0 if with_card else 0.0)
	body_sc.position = Vector2(x, _m_top)
	body_sc.size = Vector2(_m_w - x - 16.0, 720.0 - _m_top - 12.0)
	_m_body_w = body_sc.size.x
	(body_sc as ScrollContainer).scroll_vertical = 0


func _swap_box(old: Control, stack: Control, assign: Callable) -> void:
	var box := VBoxContainer.new()
	box.name = old.name
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.remove_child(old)
	old.queue_free()
	stack.add_child(box)
	assign.call(box)
	box.child_entered_tree.connect(func(_n): _queue_reflow(box))


func _queue_reflow(box: Control) -> void:
	if box.has_meta("m_pending"):
		return
	box.set_meta("m_pending", true)
	(func():
		if is_instance_valid(box):
			box.remove_meta("m_pending")
			if box == _body:
				_m_reflow_body()
				return
			var bw := (box.get_parent() as Control).size.x if box.get_parent() else _m_body_w
			MobileReflow.reflow_children(box, maxf(200.0, bw - 24.0))).call_deferred()


## Body panels become side-by-side cards; each keeps its desktop share of the width.
func _m_reflow_body() -> void:
	var kids: Array = []
	var total := 0.0
	for c in _body.get_children():
		if c is Control and not c.is_queued_for_deletion() and (c as Control).visible:
			var dw := maxf(120.0, maxf((c as Control).size.x, (c as Control).custom_minimum_size.x))
			kids.append([c.get_index(), dw])
			total += dw
	if kids.is_empty():
		return
	var avail := _m_body_w - 12.0 * (kids.size() - 1) - 8.0
	var narrow := false
	for k in kids:
		if avail * float(k[1]) / total < 400.0:
			narrow = true
	if narrow and kids.size() > 1:
		# too tight for side-by-side cards: stack them full width instead
		avail = _m_body_w - 8.0
		for k in kids:
			k[1] = total
	for k in kids:
		var c := _body.get_child(int(k[0])) as Control
		var cw := floorf(avail * float(k[1]) / total)
		if c.has_meta("m_reflowed"):
			continue
		MobileReflow.reflow(c, cw)
	for k in kids:
		var c := _body.get_child(int(k[0])) as Control
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_stretch_ratio = float(k[1])
		c.custom_minimum_size.x = 0
	if narrow and kids.size() > 1:
		var col := VBoxContainer.new()
		col.set_meta("m_reflowed", true)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 12)
		var moving: Array = []
		for k in kids:
			moving.append(_body.get_child(int(k[0])))
		for c in moving:
			_body.remove_child(c)
			col.add_child(c)
		_body.add_child(col)
	_m_fix_rows(_body)
	for l in _body.find_children("*", "Label", true, false):
		var lab := l as Label
		if lab.text.length() <= 6 and not lab.text.contains("\n") and not (lab.get_parent() is HBoxContainer):
			lab.autowrap_mode = TextServer.AUTOWRAP_OFF
			lab.custom_minimum_size.x = 0
		elif lab.autowrap_mode != TextServer.AUTOWRAP_OFF and lab.text.strip_edges().length() >= 8:
			# Wrap copy in a row must keep a readable column (gate: rw < font*1.6 squashed).
			var par := lab.get_parent()
			if par is HBoxContainer or par is FlowContainer:
				lab.custom_minimum_size.x = maxf(lab.custom_minimum_size.x, 200.0)
				lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## List rows: text spans the row; the left badge column stacks glyph over tier.
func _m_fix_rows(root: Node) -> void:
	for b in root.find_children("*", "Button", true, false):
		if not (b as Node).has_meta("m_row"):
			continue
		var left: Array = []
		for k in (b as Node).get_children():
			if k is Label and (k as Label).position.x < 50.0:
				left.append(k)
		left.sort_custom(func(x, y): return x.position.y < y.position.y)
		var y := 6.0
		for l in left:
			var lab := l as Label
			lab.size = lab.get_minimum_size()
			lab.position = Vector2(12, y)
			y += 38.0


func _add_backdrop() -> void:
	var tr := TextureRect.new()
	tr.name = "Backdrop"
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = Color(0.42, 0.48, 0.58, 0.55)
	var farm := AtlasArt.city_plate(city)
	if farm != "":
		tr.texture = load(farm)
	else:
		var p := _Atlas.plate_path(str(World.nations.get(World.nation_of(city), {}).get("plate", "")))
		if p != "":
			tr.texture = load(p)
	add_child(tr)
	UIKit.side_veil(self, false, 0.75, 0.94)

func _refresh_all() -> void:
	_refresh_top()
	_render_side()
	_render_tab()

func _refresh_top() -> void:
	for c in _top.get_children():
		c.queue_free()
	var n: Dictionary = World.node(city)
	var title := "%s · %s" % [World.kind_zh(city), n.get("name", city)]
	var chips := [
		["银", str(GameState.silver), UIKit.ACCENT],
		["粮", str(GameState.food), UIKit.TEXT],
		["铁", str(GameState.iron), UIKit.TEXT],
		["货舱", "%d/%d" % [World.cargo_used(), World.cargo_cap()], UIKit.TEXT],
		["历", World.date_label(), UIKit.TEXT_DIM],
	]
	var back_t := Locale.t("atlas_gate_leave")
	if _mob:
		var parts := PackedStringArray()
		for ch in chips:
			parts.append("%s %s" % [ch[0], ch[1]])
		var vp := get_viewport().get_visible_rect().size
		_top.size = Vector2(maxf(1280.0, vp.x * 720.0 / maxf(1.0, vp.y)), MobilePage.TOP)
		MobilePage.top_bar(_top, title, " · ".join(parts), [[back_t, _back]])
		return
	UIKit.top_bar(_top, title, chips, back_t, _back)

# ── side card ─────────────────────────────────────────
func _render_side() -> void:
	for c in _side.get_children():
		c.queue_free()
	var n: Dictionary = World.node(city)
	var nat: Dictionary = World.nations.get(str(n.get("nation", "")), {})
	var p := UIKit.panel_at(_side, Rect2(16, 64, 384, 620), 12)
	var th := Control.new()
	th.position = Vector2(1, 1)
	th.size = Vector2(382, 214)
	th.clip_contents = true
	p.add_child(th)
	_fill_vignette(th)
	var fade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.055, 0.067, 0.09, 0.0))
	g.set_color(1, Color(0.055, 0.067, 0.09, 0.96))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.35)
	gt.fill_to = Vector2(0, 1)
	fade.texture = gt
	fade.size = th.size
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	th.add_child(fade)
	if not _mob:
		var eb := UIKit.mono("%s // %s" % [str(nat.get("en", "")), World.kind_zh(city)], 9, UIKit.ACCENT)
		eb.position = Vector2(18, 150)
		p.add_child(eb)
	var t := UIKit.title_label(str(n.get("name", city)), 26 if not _mob else 28)
	t.position = Vector2(18, 166 if not _mob else 150)
	if _mob:
		t.add_theme_font_size_override("font_size", 28)
	p.add_child(t)
	## 团徽 + 邦徽 on the side card (desktop + mobile).
	CKHeraldryField.place_city_crest_strip(p, city, Vector2(292, 12) if not _mob else Vector2(280, 8), Vector2(36, 44) if not _mob else Vector2(40, 48))
	var chips := HBoxContainer.new()
	chips.position = Vector2(18, 222)
	chips.add_theme_constant_override("separation", 5)
	p.add_child(chips)
	chips.add_child(UIKit.tag_chip(str(nat.get("name", "")), UIKit.ACCENT))
	chips.add_child(UIKit.tag_chip("规模 " + "▮".repeat(int(n.get("size", 1))), UIKit.TEXT_DIM))
	chips.add_child(UIKit.tag_chip("铁匠 %d 阶" % World.smith_tier(city), UIKit.TEXT_DIM))
	# rep ladder
	var rep := World.rep_of(city)
	var tiers: Array = World.rules.get("rep_tiers", [0, 10, 30, 55, 80])
	var ti := World.rep_tier_index(rep)
	var nxt := int(tiers[mini(ti + 1, tiers.size() - 1)])
	var rl := UIKit.kv_row("城声望 · %s" % World.rep_tier_name(rep), "%d / %d" % [rep, nxt], UIKit.ACCENT, 348)
	rl.position = Vector2(18, 254)
	p.add_child(rl)
	var bar := UIKit.slim_bar(rep, maxi(1, nxt), UIKit.ACCENT, 348, 4)
	bar.position = Vector2(18, 274)
	p.add_child(bar)
	var nr := UIKit.kv_row("%s 邦交" % nat.get("name", ""), "%d · %s" % [World.nation_rep(str(n.nation)), World.rep_tier_name(World.nation_rep(str(n.nation)))], UIKit.TEXT, 348)
	nr.position = Vector2(18, 284)
	p.add_child(nr)
	var kv := VBoxContainer.new()
	kv.position = Vector2(18, 312)
	kv.add_theme_constant_override("separation", 4)
	p.add_child(kv)
	kv.add_child(UIKit.kv_row("特产", str(n.get("specialty", "")), UIKit.TEXT, 348))
	kv.add_child(UIKit.kv_row("出产（贱）", _goods_list(n.get("produce", [])), UIKit.OK, 348))
	kv.add_child(UIKit.kv_row("求购（贵）", _goods_list(n.get("demand", [])), UIKit.EMBER, 348))
	var lore := UIKit.body_label(str(n.get("lore", "")), UIKit.TEXT_DIM, 12)
	lore.position = Vector2(18, 392)
	lore.size = Vector2(348, 68)
	lore.custom_minimum_size = Vector2(348, 0)
	p.add_child(lore)
	var hl := UIKit.hairline(Color(1, 1, 1, 0.07))
	hl.position = Vector2(18, 494)
	hl.size = Vector2(348, 1)
	p.add_child(hl)
	var party := VBoxContainer.new()
	party.position = Vector2(18, 504)
	party.add_theme_constant_override("separation", 3)
	p.add_child(party)
	party.add_child(UIKit.kv_row("编制 / 日耗粮", "%d 人 / %d" % [World.party_size(), World.food_per_day()], UIKit.TEXT, 348))
	party.add_child(UIKit.kv_row("委托进行", "%d / %d" % [World.active.size(), int(World.rules.get("active_limit", 5))], UIKit.TEXT, 348))
	var ready := 0
	for q in World.active:
		if World.can_turn_in(q, city):
			ready += 1
	party.add_child(UIKit.kv_row("可在此交付", "%d" % ready, UIKit.OK if ready > 0 else UIKit.TEXT_DIM, 348))
	var gate := UIKit.body_label(World.city_gate_text(), UIKit.EMBER if bool(World.city_gate.get("warn", false)) else UIKit.ACCENT, 12)
	gate.name = "CityGateBanner"
	gate.position = Vector2(18, 462)
	gate.size = Vector2(348, 28)
	gate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(gate)
	var seal_offer: Dictionary = World.city_seal_resupply_offer()
	var back_y := 566.0
	if bool(seal_offer.get("needed", false)):
		var days := int(seal_offer.get("days", 7))
		var seal_btn := UIKit.cta_button(Locale.t("atlas_city_seal_resupply_btn") % days, "R", 348, 36)
		seal_btn.name = "CitySealResupply"
		seal_btn.position = Vector2(18, 498)
		seal_btn.disabled = not bool(seal_offer.get("ok", false))
		seal_btn.pressed.connect(_on_city_seal_resupply)
		p.add_child(seal_btn)
		back_y = 548.0
	var back := UIKit.cta_button(Locale.t("atlas_gate_leave"), "ESC", 348, 40)
	back.name = "BackToAtlas"
	back.position = Vector2(18, back_y)
	back.pressed.connect(_back)
	p.add_child(back)

func _goods_list(arr: Array) -> String:
	var out: Array = []
	for g in arr:
		out.append(World.good_name(str(g)))
	return "、".join(out) if not out.is_empty() else "—"

func _fill_vignette(th: Control) -> void:
	var farm := AtlasArt.city_plate(city)
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if farm != "":
		tr.texture = load(farm)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size = th.size
	else:
		var path := _Atlas.plate_path(str(World.nations.get(World.nation_of(city), {}).get("plate", "")))
		if path != "":
			tr.texture = load(path)
			var pp: Array = World.node(city).get("pos", [0.5, 0.5])
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.size = Vector2(th.size.x * 3.2, th.size.x * 3.2 * 9.0 / 16.0)
			tr.position = Vector2(th.size.x * 0.5 - float(pp[0]) * tr.size.x, th.size.y * 0.42 - float(pp[1]) * tr.size.y)
			tr.position = Vector2(clampf(tr.position.x, th.size.x - tr.size.x, 0), clampf(tr.position.y, th.size.y - tr.size.y, 0))
	th.add_child(tr)

# ── tabs ──────────────────────────────────────────────
func _set_tab(t: String) -> void:
	tab = t
	if t in ["smith", "market", "tavern"]:
		World.mark_hub_seen(city, t)
	_render_tab()

func _render_tab() -> void:
	_m_layout()
	for k in _tab_btn.keys():
		var b: Button = _tab_btn[k]
		var on := str(k) == tab
		b.add_theme_color_override("font_color", UIKit.ACCENT if on else UIKit.TEXT_DIM)
		var sb := UIKit.flat_box(Color(UIKit.ACCENT, 0.14) if on else Color(1, 1, 1, 0.03), Color(UIKit.ACCENT, 0.7) if on else Color(1, 1, 1, 0.1), 8)
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override("normal", sb)
	var n: Dictionary = World.node(city)
	(_tab_btn["smith"] as Button).disabled = World.smith_tier(city) <= 0
	(_tab_btn["tavern"] as Button).disabled = int(n.get("tavern_slots", 0)) <= 0
	(_tab_btn["lamp"] as Button).disabled = World.nation_of(city) != "lantern"
	(_tab_btn["smith"] as Button).tooltip_text = "此地没有铁匠铺" if World.smith_tier(city) <= 0 else ""
	(_tab_btn["tavern"] as Button).tooltip_text = "此地没有酒馆" if int(n.get("tavern_slots", 0)) <= 0 else ""
	(_tab_btn["lamp"] as Button).tooltip_text = "灯籍只在灯市联开拍" if World.nation_of(city) != "lantern" else ""
	# WS-C #44: a door that does not exist here is hidden, not an empty page behind a grey button
	for k in ["smith", "tavern", "lamp"]:
		(_tab_btn[k] as Button).visible = not (_tab_btn[k] as Button).disabled
	if (_tab_btn.get(tab) as Button) != null and (_tab_btn[tab] as Button).disabled:
		tab = "overview"
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match tab:
		"overview": _tab_overview()
		"smith": _tab_smith()
		"market": _tab_market()
		"sundry": _tab_sundry()
		"board": _tab_board()
		"tavern": _tab_tavern()
		"armory": _tab_armory()
		"lamp": _tab_lamp()
	UIFX.wire_tree(_body)
	UIFX.fade_in(_body, 0.18)

func _panel(r: Rect2) -> Panel:
	var p := UIKit.panel_at(_body, r, 10)
	return p

func _head(p: Control, pos: Vector2, zh: String, en: String) -> void:
	if not _mob:
		var e := UIKit.mono(en, 9, UIKit.ACCENT, false)
		e.clip_text = true
		e.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		e.position = pos
		e.size = Vector2(220, 14)
		p.add_child(e)
	var t := UIKit.title_label(zh, MobilePage.FONT + 4 if _mob else 17)
	t.position = pos + Vector2(0, 0 if _mob else 18)
	if _mob:
		t.add_theme_font_size_override("font_size", MobilePage.FONT + 4)
	else:
		# Fixed line box under the EN kicker. A wide size would share ink with
		# the board filters; width stays the text's own minimum.
		var tw := t.get_combined_minimum_size()
		t.size = Vector2(maxf(tw.x, 24.0), 28)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(t)

func _para(text: String, col: Color, size: int, w: float) -> Label:
	var l := UIKit.body_label(text, col, size)
	l.custom_minimum_size = Vector2(w, 0)
	l.size = Vector2(w, 0)
	return l

func _line(text: String, col: Color, size: int, w: float) -> Label:
	var l := UIKit.body_label(text, col, size)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(w, 0)
	return l

func _scroll(p: Control, r: Rect2) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.position = r.position
	sc.size = r.size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(r.size.x - 10, 0)
	v.add_theme_constant_override("separation", 4)
	if _mob:
		v.custom_minimum_size.x = 0
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	return v

func _row_button(text: String, sub: String, w: float, on: bool, locked: bool) -> Button:
	var b := Button.new()
	b.text = ""
	b.custom_minimum_size = Vector2(w, 46)
	b.focus_mode = Control.FOCUS_ALL
	var nrm := UIKit.flat_box(Color(UIKit.ACCENT, 0.12) if on else Color(1, 1, 1, 0.025), Color(UIKit.ACCENT, 0.7) if on else Color(1, 1, 1, 0.08), 8)
	var hov := UIKit.flat_box(Color(UIKit.ACCENT, 0.10), Color(UIKit.ACCENT, 0.5), 8)
	var prs := UIKit.flat_box(Color(UIKit.ACCENT, 0.2), UIKit.ACCENT, 8)
	var foc := UIKit.flat_box(Color(0, 0, 0, 0), UIKit.FOCUS_RING, 9, 2)
	foc.draw_center = false
	var dis := UIKit.flat_box(UIKit.DISABLED_BG, UIKit.DISABLED_BORDER, 8)
	b.add_theme_stylebox_override("normal", nrm)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", prs)
	b.add_theme_stylebox_override("focus", foc)
	b.add_theme_stylebox_override("disabled", dis)
	var l := UIKit.body_label(text, UIKit.TEXT_FAINT if locked else UIKit.TEXT, 13)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.position = Vector2(54, 5)
	l.size = Vector2(w - 64, 18)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	var s := UIKit.body_label(sub, UIKit.TEXT_FAINT if locked else UIKit.TEXT_DIM, 11)
	s.autowrap_mode = TextServer.AUTOWRAP_OFF
	s.clip_text = true
	s.position = Vector2(54, 25)
	s.size = Vector2(w - 64, 16)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(s)
	if _mob:
		# phone: two 22px lines need a taller row; the row spans its card
		b.set_meta("m_row", true)
		b.custom_minimum_size.x = 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for lab in [l, s]:
			(lab as Label).anchor_right = 1.0
			(lab as Label).offset_left = 60.0
			(lab as Label).offset_right = -10.0
		b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 84.0)
		l.position.y = 6.0
		l.size.y = 30.0
		s.position.y = 44.0
		s.size.y = 30.0
		for lab in [l, s]:
			(lab as Label).add_theme_font_size_override("font_size", MobilePage.FONT)
	return b

func _icon(it: Dictionary, sz: float) -> Control:
	## farm icon if ingested, else a procedural glass glyph tile (type glyph, tier colour, signature ring)
	var box := Panel.new()
	box.custom_minimum_size = Vector2(sz, sz)
	box.size = Vector2(sz, sz)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tier := clampi(int(it.get("tier", 1)), 0, 4)
	var col: Color = TIER_COL[tier]
	var sig := int(it.get("signature", 0))
	var st := UIKit.flat_box(Color(col, 0.10), Color(col, 0.9 if sig > 0 else 0.45), 8, 2 if sig > 0 else 1)
	if sig == 2:
		st.shadow_color = Color(col, 0.45)
		st.shadow_size = 8
	box.add_theme_stylebox_override("panel", st)
	var path := AtlasArt.item_icon(str(it.get("id", "")))
	if path != "":
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(2, 2)
		tr.size = Vector2(sz - 4, sz - 4)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
	else:
		var gl := UIKit.title_label(str(TYPE_GLYPH.get(str(it.get("type", "")), "器")), int(sz * 0.46), col)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gl.size = Vector2(sz, sz)
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(gl)
		if sig > 0:
			var star := UIKit.mono("★" if sig == 2 else "◆", 8, col, false)
			star.position = Vector2(sz - 12, 2)
			box.add_child(star)
	return box

# ── 概览 ──────────────────────────────────────────────
func _tab_overview() -> void:
	var n: Dictionary = World.node(city)
	var y_off := 0.0
	if World.needs_hub_discover(city):
		y_off = _hub_discover_strip()
	var p := _panel(Rect2(0, y_off, 420, 576 - y_off))
	_head(p, Vector2(18, 14), "声望阶梯", "REPUTATION LADDER")
	var tiers: Array = World.rules.get("rep_tiers", [0, 10, 30, 55, 80])
	var names: Array = World.REP_TIER_ZH
	var unlocks: Array = World.CITY_UNLOCKS
	var rep := World.rep_of(city)
	var v := VBoxContainer.new()
	v.position = Vector2(18, 56)
	v.add_theme_constant_override("separation", 6 if not _mob else 10)
	if _mob:
		# One column so MobileReflow does not pack this tall stack into an HFlow with
		# the nation / honour / affair siblings (that crush unlock lines to ~14px).
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(v)
	for i in tiers.size():
		var reached := rep >= int(tiers[i])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		if _mob:
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chip := UIKit.tag_chip("%s %d" % [names[i] if i < names.size() else "", int(tiers[i])], UIKit.ACCENT if reached else UIKit.TEXT_FAINT, reached)
		chip.custom_minimum_size = Vector2(76, 0)
		row.add_child(chip)
		var unlock := _para(str(unlocks[i]) if i < unlocks.size() else "", UIKit.TEXT if reached else UIKit.TEXT_FAINT, 12 if not _mob else MobilePage.FONT, 300 if not _mob else 0)
		if _mob:
			unlock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# Floor so a leftover HBox cannot collapse the wrap column to a glyph strip.
			unlock.custom_minimum_size = Vector2(200, 0)
		row.add_child(unlock)
		v.add_child(row)
	var nid := str(n.get("nation", ""))
	var nrep := World.nation_rep(nid)
	var nt := World.rep_tier_index(nrep)
	if not _mob:
		var nl := UIKit.mono("NATION %s · %d · %s" % [str(World.nations.get(nid, {}).get("en", "")), nrep, World.rep_tier_name(nrep)], 9, UIKit.ACCENT)
		nl.position = Vector2(18, 232)
		p.add_child(nl)
	var next_u: String = str(World.NATION_UNLOCKS[mini(nt + 1, 4)]) if nt < 4 else "已达最高"
	var nx := _para("当前：%s\n下一阶：%s" % [World.NATION_UNLOCKS[nt], next_u], UIKit.TEXT_DIM, 11 if not _mob else MobilePage.FONT, 384 if not _mob else 0)
	if _mob:
		nx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nx.custom_minimum_size = Vector2(0, 0)
		v.add_child(nx)
	else:
		nx.position = Vector2(18, 250)
		p.add_child(nx)
	# Discover strip shrinks the panel from the top. Pin the action to the panel
	# bottom so it stays inside the 720 viewport instead of at absolute y=510.
	var aff_h := 48.0 if not _mob else 0.0
	var aff_y := p.size.y - aff_h - 12.0
	var sq: Dictionary = n.get("sig_quest", {})
	if sq.is_empty():
		if _mob:
			v.add_child(UIKit.title_label(Locale.t("wsc_c_rumor_title"), MobilePage.FONT + 2, UIKit.TEXT))
			for line in rumors(city).slice(0, 6):
				var rl := _para("· " + str(line), UIKit.TEXT_DIM, MobilePage.FONT, 0)
				rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				v.add_child(rl)
		else:
			_rumor_box(p, Rect2(18, 318, 384, maxf(72.0, aff_y - 326.0)))
	var sst: Control = null
	if not sq.is_empty():
		var st := UIKit.title_label("「%s」" % sq.get("title", ""), 15 if not _mob else MobilePage.FONT + 2, UIKit.TEXT)
		var sb := _para(str(sq.get("brief", "")), UIKit.TEXT_DIM, 12 if not _mob else MobilePage.FONT, 384 if not _mob else 0)
		var done := World.done_sig.has(str(sq.get("id", "")))
		var running := not World.quest_by_id(str(sq.get("id", ""))).is_empty()
		var stxt := "已完成 · 传奇兵器已解锁" if done else ("进行中 · 完成后解锁传奇兵器" if running else "声望「友善」(30) 后出现在委托榜")
		sst = UIKit.tag_chip(stxt, UIKit.OK if done else (UIKit.ACCENT if running else UIKit.TEXT_DIM), done)
		if _mob:
			st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.custom_minimum_size = Vector2(0, 0)
			v.add_child(st)
			v.add_child(sb)
			v.add_child(sst)
		else:
			var mid := ScrollContainer.new()
			mid.name = "HonourScroll"
			mid.position = Vector2(12, 318)
			mid.size = Vector2(396, maxf(72.0, aff_y - 326.0))
			mid.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			p.add_child(mid)
			var hv := VBoxContainer.new()
			hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hv.custom_minimum_size = Vector2(372, 0)
			hv.add_theme_constant_override("separation", 4)
			mid.add_child(hv)
			hv.add_child(UIKit.mono("HONOUR COMMISSION", 9, UIKit.EMBER))
			st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			st.custom_minimum_size = Vector2(372, 0)
			sb.custom_minimum_size = Vector2(372, 0)
			hv.add_child(st)
			hv.add_child(sb)
			hv.add_child(sst)
	## v9.2 本城之事 / 职印：一个 48 高的按钮，点开浮层
	var aff := UIKit.ghost_button(CKCityAffairs.label(city), 384 if not _mob else 0, 48 if not _mob else MobilePage.HIT)
	aff.name = "AffairBtn"
	aff.clip_text = true
	aff.pressed.connect(open_affairs)
	if _mob:
		aff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		aff.custom_minimum_size = Vector2(0, MobilePage.HIT)
		v.add_child(aff)
	else:
		var aff_need := maxf(aff_h, aff.get_combined_minimum_size().y)
		aff.position = Vector2(18, p.size.y - aff_need - 8.0)
		p.add_child(aff)
	var p2 := _panel(Rect2(432, y_off, 416, 576 - y_off))
	_head(p2, Vector2(18, 14), "可在此交付", "TURN IN HERE")
	var v2 := _scroll(p2, Rect2(18, 56, 384, 236))
	var any := false
	for q in World.active:
		if not World.can_turn_in(q, city):
			continue
		any = true
		var b := UIKit.cta_button("交付「%s」 +%d 银" % [q.title, int(q.reward_silver)], "", 380, 36)
		b.name = "TurnIn_" + str(q.id)
		var qid := str(q.id)
		b.pressed.connect(func(): _do(World.turn_in(qid)))
		v2.add_child(b)
	if not any:
		v2.add_child(_para(Locale.t("wsc_c_noturnin"), UIKit.TEXT_FAINT, 12, 370))
		for q in World.active:
			var where := str(World.node(World.turn_in_city(q)).get("name", ""))
			v2.add_child(_line(Locale.t("wsc_c_turnat") % [str(q.get("title", "")), where], UIKit.TEXT_DIM, 11, 370))
		v2.name = "Rumors"
		v2.add_child(_line(Locale.t("wsc_c_rumor_title"), UIKit.ACCENT, 12, 370))
		for line in rumors(city).slice(0, 5):
			v2.add_child(_para("· " + str(line), UIKit.TEXT_DIM, 12, 370))
	var show_main := str(World.mainline_marker().get("node", "")) == city
	# cta chrome is taller than the requested 38px; reserve the real slot above the footer.
	var main_h := 64.0
	var main_y := p2.size.y - main_h - 8.0
	var v3 := VBoxContainer.new()
	v3.name = "TradeLoop"
	v3.add_theme_constant_override("separation", 4)
	if _mob:
		# Phone reflow owns this column; keep the pre-strip absolute stack.
		var il_m := UIKit.mono("TRADE INTEL", 9, UIKit.ACCENT)
		il_m.position = Vector2(18, 304)
		p2.add_child(il_m)
		v3.position = Vector2(18, 322)
		p2.add_child(v3)
	else:
		var intel := ScrollContainer.new()
		intel.name = "TradeIntelScroll"
		intel.position = Vector2(12, 300)
		var intel_bottom := main_y - 6.0 if show_main else p2.size.y - 8.0
		intel.size = Vector2(392, maxf(80.0, intel_bottom - 300.0))
		intel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		p2.add_child(intel)
		var intel_box := VBoxContainer.new()
		intel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		intel_box.custom_minimum_size = Vector2(372, 0)
		intel_box.add_theme_constant_override("separation", 4)
		intel.add_child(intel_box)
		intel_box.add_child(UIKit.mono("TRADE INTEL", 9, UIKit.ACCENT))
		intel_box.add_child(v3)
	var ti := 0
	for g in n.get("produce", []):
		var best: Dictionary = World.best_known_sell(str(g), city)
		var here := World.price(city, str(g), "buy")
		var gname := World.good_name(str(g))
		var txt := ""
		if str(best.get("city", "")) != "":
			txt = Locale.t("atlas_trade_loop_line") % [gname, here, str(World.node(str(best.city)).get("name", "")), int(best.price), int(best.price) - here]
		else:
			txt = Locale.t("atlas_trade_loop_unknown") % [gname, here]
		var ln := _line(txt, UIKit.TEXT_DIM, 12, 380)
		ln.name = "TradeLoop_%d" % ti
		v3.add_child(ln)
		ti += 1
	if not n.get("produce", []).is_empty():
		var go_mkt := UIKit.ghost_button(Locale.t("atlas_trade_loop_goto"), 200, 28 if not _mob else MobilePage.HIT)
		go_mkt.name = "TradeLoopGoto"
		if _mob:
			go_mkt.custom_minimum_size = Vector2(0, MobilePage.HIT)
		go_mkt.pressed.connect(func(): _set_tab("market"))
		v3.add_child(go_mkt)
	for t in World.tips.slice(0, 3):
		v3.add_child(_line("情报：%s" % str(t), UIKit.ACCENT, 11, 380))
	var mm: Dictionary = World.mainline_marker()
	if str(mm.get("node", "")) == city:
		var mb := UIKit.cta_button("★ %s" % mm.label, "", 380, 38)
		mb.name = "MainlineBtn"
		mb.position = Vector2(18, 520 if _mob else main_y)
		mb.disabled = not bool(mm.get("exists", false))
		mb.pressed.connect(func(): CKNav.go(str(mm.path)))
		p2.add_child(mb)


## First-visit strip: push player to open smith / market / tavern once.
func _hub_discover_strip() -> float:
	var hubs: Array = World.hub_discover_list(city)
	if hubs.is_empty():
		return 0.0
	var h := 78.0 if not _mob else float(MobilePage.HIT + 56)
	var band := _panel(Rect2(0, 0, 848 if not _mob else 0, h if not _mob else 0))
	band.name = "HubDiscover"
	if _mob:
		band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		band.custom_minimum_size = Vector2(0, h)
	var title := UIKit.mono(Locale.t("hub_discover_en"), 9, UIKit.EMBER)
	title.position = Vector2(18, 8)
	band.add_child(title)
	var zh := UIKit.title_label(Locale.t("hub_discover_title"), 14 if not _mob else MobilePage.FONT, UIKit.TEXT)
	zh.position = Vector2(18, 22)
	if _mob:
		zh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.add_child(zh)
	var row := HBoxContainer.new()
	row.name = "HubDiscoverRow"
	row.position = Vector2(18, 44 if not _mob else 50)
	row.add_theme_constant_override("separation", 8)
	if _mob:
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.add_child(row)
	for hub in hubs:
		var hid := str(hub.get("id", ""))
		var b := UIKit.ghost_button(str(hub.get("label", hid)), 120 if not _mob else 0, 28 if not _mob else MobilePage.HIT)
		b.name = "GotoHub_" + hid
		if _mob:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, MobilePage.HIT)
		var tab_id := hid
		b.pressed.connect(func(): _set_tab(tab_id))
		row.add_child(b)
	var dismiss := UIKit.ghost_button(Locale.t("hub_discover_later"), 72 if not _mob else 0, 28 if not _mob else MobilePage.HIT)
	dismiss.name = "HubDiscoverLater"
	if _mob:
		dismiss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dismiss.custom_minimum_size = Vector2(0, MobilePage.HIT)
	dismiss.pressed.connect(func():
		for hub2 in World.hub_discover_list(city):
			World.mark_hub_seen(city, str(hub2.get("id", "")))
		_set_tab("overview"))
	row.add_child(dismiss)
	return h if not _mob else 0.0  # mobile reflow stacks; no y shift needed


## WS-C #43: 城内传闻 / 街上的人——拿现有的城市数据拼几句口语，填满概览页的空栏。
static func rumors(cid: String) -> Array:
	var n: Dictionary = World.node(cid)
	var out: Array = []
	var nm := str(n.get("name", ""))
	for g in n.get("demand", []):
		out.append(Locale.t("wsc_c_r_demand") % [nm, World.good_name(str(g))])
	for g in n.get("produce", []):
		out.append(Locale.t("wsc_c_r_produce") % [World.good_name(str(g)), World.price(cid, str(g), "buy")])
	var sig: Array = n.get("sig_items", [])
	if not sig.is_empty():
		out.append(Locale.t("wsc_c_r_smith") % str(World.item(str(sig[0])).get("name", sig[0])))
	for rv in World.rivals:
		if str(rv.get("pos", "")) == cid:
			out.append(Locale.t("wsc_c_r_rival") % str(rv.get("name", "")))
	for sid in CKTerritory.sites_at(cid):
		var site := CKTerritory.site(sid)
		var own := CKTerritory.owner(sid)
		var key := "wsc_c_r_site_own" if own == CKTerritory.OWN else ("wsc_c_r_site_rival" if own.begins_with("rival:") else "wsc_c_r_site_free")
		out.append(Locale.t(key) % str(site.get("name", "")))
	for r in World.roads_from(cid):
		if int(r.get("danger", 0)) >= 3:
			out.append(Locale.t("wsc_c_r_road") % str(World.node(World.other_end(r, cid)).get("name", "")))
			break
	if out.is_empty():
		out.append(Locale.t("wsc_c_r_quiet"))
	return out

func _rumor_box(p: Control, r: Rect2) -> void:
	var hl := UIKit.mono("RUMOURS", 9, UIKit.ACCENT)
	hl.position = r.position
	p.add_child(hl)
	var t := UIKit.title_label(Locale.t("wsc_c_rumor_title"), 15, UIKit.TEXT)
	t.position = r.position + Vector2(0, 16)
	p.add_child(t)
	var v := _scroll(p, Rect2(r.position + Vector2(0, 44), r.size - Vector2(0, 44)))
	v.name = "RumorsBox"
	for line in rumors(city).slice(0, 6):
		v.add_child(_para("· " + str(line), UIKit.TEXT_DIM, 12, r.size.x - 8))

# ── 铁匠铺 ────────────────────────────────────────────
func _tab_smith() -> void:
	var sp := AtlasArt.smith_plate(World.nation_of(city))
	if sp != "" and not _mob:
		var bg := TextureRect.new()
		bg.texture = load(sp)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.size = CONTENT.size
		bg.modulate = Color(1, 1, 1, 0.22)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(bg)
	var st: Array = World.smith_stock(city)
	var nat: Dictionary = World.nations.get(World.nation_of(city), {})
	var p := _panel(Rect2(0, 0, 420, 576))
	_head(p, Vector2(18, 14), str(nat.get("smith", "铁匠铺")), "SMITHY · TIER %d" % World.smith_tier(city))
	CKHeraldryField.place_city_crest_strip(p, city, Vector2(328, 10), Vector2(36, 44))
	var v := _scroll(p, Rect2(12, 58, 400, 508))
	if _sel_item == "" or not World.items.has(_sel_item):
		_sel_item = str(st[0].item.id) if not st.is_empty() else ""
	for e in st:
		var it: Dictionary = e.item
		var iid := str(it.id)
		var sig := int(e.get("signature", 0))
		var lab := ("★ " if sig == 2 else ("◆ " if sig == 1 else "")) + str(it.name)
		var sub := "%s · %d 阶 · %s · %d 银" % [it.type_name, int(it.tier), World.item_stats_text(it), World.smith_price(city, iid)]
		if not bool(e.available):
			sub = "🔒 " + str(e.reason)
		var b := _row_button(lab, sub, 388, iid == _sel_item, not bool(e.available))
		b.name = "Item_" + iid
		var ic := _icon(it, 38)
		ic.position = Vector2(6, 4)
		b.add_child(ic)
		b.pressed.connect(func(): _sel_item = iid; _render_tab())
		v.add_child(b)
	if st.is_empty():
		v.add_child(_para("此地没有铁匠铺。", UIKit.TEXT_FAINT, 12, 380))
		return
	_item_detail(Rect2(432, 0, 416, 576), _sel_item, true)
	call_deferred("_maybe_smith_reveal")

func _maybe_smith_reveal() -> void:
	if find_child("SmithReveal", true, false) != null:
		return
	var it: Dictionary = World.next_smith_reveal(city)
	if it.is_empty():
		return
	_show_smith_reveal(it)

func _show_smith_reveal(it: Dictionary) -> void:
	var overlay := Control.new()
	overlay.name = "SmithReveal"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 80
	add_child(overlay)
	var dim := ColorRect.new()
	# Opaque so mobile-gate OCR does not read the smith page underneath.
	dim.color = Color(0.04, 0.05, 0.08, 1.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var phone := DeviceProfile.is_mobile() or _mob
	var cw := minf(size.x - 48.0, 640.0) if phone else 520.0
	var ch := minf(size.y - 48.0, 460.0) if phone else 360.0
	var card := Panel.new()
	card.position = Vector2((size.x - cw) * 0.5, (size.y - ch) * 0.5)
	card.size = Vector2(cw, ch)
	card.add_theme_stylebox_override("panel", UIKit.glass(16, 0.96, true))
	overlay.add_child(card)
	var nid := World.nation_of(city)
	var sp := AtlasArt.smith_plate(nid)
	if sp != "":
		var bg := TextureRect.new()
		bg.texture = load(sp)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.modulate = Color(1, 1, 1, 0.22)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bg)
	var tag_sz := 22 if phone else 12
	var title_sz := 28 if phone else 28
	var body_sz := 22 if phone else 15
	var mono := UIKit.mono(Locale.t("smith_reveal_tag"), tag_sz, UIKit.ACCENT)
	mono.position = Vector2(24, 18)
	card.add_child(mono)
	CKHeraldryField.place_city_crest_strip(card, city, Vector2(cw - 96, 12), Vector2(36, 44) if not phone else Vector2(40, 48))
	var ic := _icon(it, 110.0 if not phone else 96.0)
	ic.position = Vector2(24, 56)
	card.add_child(ic)
	var title := UIKit.title_label(str(it.get("name", "")), title_sz)
	title.position = Vector2(152, 56)
	title.size = Vector2(cw - 176, 44)
	card.add_child(title)
	var sub := UIKit.body_label("%s · %s" % [str(it.get("type_name", "")), World.nations.get(str(it.get("nation", "")), {}).get("name", "")], UIKit.TEXT_DIM, body_sz)
	sub.position = Vector2(152, 108)
	card.add_child(sub)
	var lore := UIKit.body_label(str(it.get("lore", "")), UIKit.TEXT, body_sz)
	lore.position = Vector2(24, 190 if not phone else 170)
	lore.size = Vector2(cw - 48, 120 if not phone else 140)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(lore)
	var btn_h := 76 if phone else 44
	var skip := UIKit.ghost_button(Locale.t("smith_reveal_skip"), int(cw - 48), btn_h)
	skip.position = Vector2(24, ch - btn_h - 16)
	skip.name = "SmithRevealSkip"
	skip.add_theme_font_size_override("font_size", body_sz)
	var iid := str(it.get("id", ""))
	var closed := {"v": false}
	var close := func():
		if bool(closed.v):
			return
		closed.v = true
		World.mark_smith_revealed(iid)
		if is_instance_valid(overlay):
			overlay.queue_free()
	skip.pressed.connect(close)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close.call())
	card.add_child(skip)
	UIFX.pop_in(card)
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(close)


func _item_detail(r: Rect2, iid: String, shop: bool) -> void:
	var it: Dictionary = World.item(iid)
	if it.is_empty():
		return
	var p := _panel(r)
	p.name = "ItemDetail"
	var ic := _icon(it, 96)
	ic.position = Vector2(18, 18)
	p.add_child(ic)
	var sig := int(it.get("signature", 0))
	var e := UIKit.mono(("LEGENDARY // " if sig == 2 else ("SIGNATURE // " if sig == 1 else "")) + "%s · T%d" % [str(it.type).to_upper(), int(it.tier)], 9, TIER_COL[clampi(int(it.tier), 0, 4)])
	e.position = Vector2(128, 20)
	p.add_child(e)
	var t := _para(str(it.name), UIKit.TEXT, 20, 270)
	t.position = Vector2(128, 36)
	p.add_child(t)
	var tn := UIKit.body_label("%s · %s · %s" % [it.type_name, World.SLOT_ZH.get(str(it.slot), ""), World.nations.get(str(it.nation), {}).get("name", "")], UIKit.TEXT_DIM, 12)
	tn.autowrap_mode = TextServer.AUTOWRAP_OFF
	tn.position = Vector2(128, 84)
	p.add_child(tn)
	# stats grid
	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(18, 128)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	p.add_child(grid)
	var leader: CKCharacter = GameState.characters.get(_sel_char) if GameState.characters.has(_sel_char) else GameState.get_leader()
	var cur_iid := World.equipped(leader, str(it.slot)) if leader else ""
	var cur: Dictionary = World.item(cur_iid)
	for k in ["atk", "def", "hit", "avo", "crit", "move", "hp"]:
		var v := int(it.get("stats", {}).get(k, 0))
		if v == 0 and int(cur.get("stats", {}).get(k, 0)) == 0:
			continue
		var d := v - int(cur.get("stats", {}).get(k, 0))
		grid.add_child(UIKit.stat_box(str(World.STAT_ZH.get(k, k)), "%+d" % v, UIKit.TEXT, ("%+d" % d) if d != 0 and leader else ""))
	if leader:
		var cmp := UIKit.body_label("对比 %s 当前：%s" % [leader.name, cur.get("name", "（无 / 旧式兵器）") if not cur.is_empty() else "（无 / 旧式兵器）"], UIKit.TEXT_FAINT, 11)
		cmp.autowrap_mode = TextServer.AUTOWRAP_OFF
		cmp.position = Vector2(18, 236)
		p.add_child(cmp)
	var sk := str(it.get("skill", ""))
	var y := 258.0
	if sk != "":
		var skd: Dictionary = GameState.get_skill(sk)
		var sl := _para("战技：%s — %s" % [skd.get("name", sk), skd.get("desc", "")], UIKit.ACCENT, 12, 380)
		sl.position = Vector2(18, y)
		p.add_child(sl)
		y += 40
	var lore := _para(str(it.get("lore", "")), UIKit.TEXT_DIM, 12, 380)
	lore.position = Vector2(18, y)
	p.add_child(lore)
	var jobs: Array = []
	for j in it.get("jobs", []):
		jobs.append(str(GameState.get_job(str(j)).get("name", j)))
	var jl := _para("适用：%s" % "、".join(jobs), UIKit.TEXT_FAINT, 11, 380)
	jl.position = Vector2(18, y + 52)
	p.add_child(jl)
	if not shop:
		return
	# materials
	var ml := UIKit.mono("FORGE MATERIALS", 9, UIKit.ACCENT)
	ml.position = Vector2(18, 392)
	p.add_child(ml)
	var mh := HBoxContainer.new()
	mh.position = Vector2(18, 410)
	mh.add_theme_constant_override("separation", 6)
	p.add_child(mh)
	var miss: Dictionary = World.mats_ok(it)
	for g in it.get("mats", {}).keys():
		var need := int(it.mats[g])
		var have := World.have_good(str(g))
		mh.add_child(UIKit.res_chip(World.good_name(str(g)), "%d/%d" % [have, need], UIKit.OK if have >= need else UIKit.DANGER))
	var e2: Dictionary = {}
	for x in World.smith_stock(city):
		if str(x.item.id) == iid:
			e2 = x
	var avail := bool(e2.get("available", false))
	var price := World.smith_price(city, iid)
	var buy := UIKit.cta_button("购买 · %d 银" % price, "A", 184, 42)
	buy.name = "BuyItem"
	buy.position = Vector2(18, 470)
	buy.disabled = not avail or GameState.silver < price
	buy.tooltip_text = str(e2.get("reason", "")) if not avail else ("银币不足" if GameState.silver < price else "")
	buy.pressed.connect(func(): _do(World.buy_item(city, iid)))
	p.add_child(buy)
	var fg := UIKit.ghost_button("打造 · 工钱 %d" % int(it.get("forge_silver", 0)), 184, 42)
	fg.name = "ForgeItem"
	fg.position = Vector2(214, 470)
	fg.disabled = not avail or not miss.is_empty() or GameState.silver < int(it.get("forge_silver", 0))
	fg.tooltip_text = "材料不足" if not miss.is_empty() else ""
	fg.pressed.connect(func(): _do(World.forge_item(city, iid)))
	p.add_child(fg)
	var why := ""
	if not avail:
		why = "🔒 " + str(e2.get("reason", ""))
	elif not miss.is_empty():
		why = "打造需自备材料（市集可购）；直接购买无需材料。"
	else:
		why = "材料齐备：打造只付工钱，比直接购买便宜 %d 银。" % maxi(0, price - int(it.get("forge_silver", 0)))
	var wl := _para(why, UIKit.EMBER if not avail else UIKit.TEXT_DIM, 11, 380)
	wl.position = Vector2(18, 522)
	p.add_child(wl)
	var own := int(World.armory.get(iid, 0))
	if own > 0:
		var ol := UIKit.tag_chip("军械库 ×%d" % own, UIKit.OK)
		ol.position = Vector2(330, 20)
		p.add_child(ol)

# ── 市集 ──────────────────────────────────────────────
func _tab_market() -> void:
	var p := _panel(Rect2(0, 0, 848, 576))
	_head(p, Vector2(18, 14), "市集", "MARKET · SUPPLY-DRIVEN PRICES")
	CKHeraldryField.place_city_crest_strip(p, city, Vector2(328, 10), Vector2(36, 44))
	var cap := UIKit.mono("货舱 %d/%d   ·   粮/铁/药材直接入库，不占货舱" % [World.cargo_used(), World.cargo_cap()], 9, UIKit.TEXT_DIM, false)
	var refresh := UIKit.ghost_button(Locale.t("city_market_refresh_btn"), 108, 28 if not _mob else MobilePage.HIT)
	refresh.name = "MarketRefresh"
	refresh.pressed.connect(func(): _do(World.refresh_market(city)))
	if _mob:
		refresh.custom_minimum_size = Vector2(108, MobilePage.HIT)
		var top_row := HBoxContainer.new()
		top_row.name = "MarketTopRow"
		top_row.position = Vector2(18, 40)
		top_row.size = Vector2(maxf(320.0, _m_body_w - 36.0), MobilePage.HIT)
		top_row.add_theme_constant_override("separation", 8)
		cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		top_row.add_child(cap)
		top_row.add_child(refresh)
		p.add_child(top_row)
	else:
		cap.position = Vector2(420, 20)
		p.add_child(cap)
		refresh.position = Vector2(728, 14)
		p.add_child(refresh)
	var y0 := 56.0
	var loops: Array = World.produce_trade_loop(city)
	var known_loops: Array = []
	for row in loops:
		if bool(row.get("known", false)) and int(row.get("margin", 0)) > 0:
			known_loops.append(row)
	if not known_loops.is_empty() or not loops.is_empty():
		var strip := Panel.new()
		strip.name = "TradeLoopStrip"
		# 「市集」 title sits at y=32; live Label min-height ~66 → end ~98.
		# Keep ≥8px air before 产线 EN chrome (gate-0). Do NOT drop the EN (suite asserts it).
		var strip_y := 108.0 if not _mob else 48.0
		strip.position = Vector2(18, strip_y)
		strip.size = Vector2(812, 40 if not _mob else float(MobilePage.HIT + 8))
		var ss := UIKit.flat_box(Color(UIKit.EMBER.r, UIKit.EMBER.g, UIKit.EMBER.b, 0.12), Color(UIKit.EMBER, 0.35), 8)
		strip.add_theme_stylebox_override("panel", ss)
		p.add_child(strip)
		var st := UIKit.mono(Locale.t("atlas_trade_loop_en"), 8, UIKit.EMBER, false)
		st.name = "TradeLoopStripEn"
		st.position = Vector2(10, 4)
		st.custom_minimum_size = Vector2(48, 12)
		st.size = Vector2(80, 14)
		strip.add_child(st)
		var best: Dictionary = World.best_produce_trade(city)
		var tip := ""
		if not best.is_empty():
			tip = Locale.t("atlas_trade_loop_best") % [str(best.name), str(best.sell_name), int(best.margin)]
		elif not loops.is_empty():
			tip = Locale.t("atlas_trade_loop_unknown") % [str(loops[0].name), int(loops[0].buy)]
		var sl := UIKit.body_label(tip, UIKit.TEXT, 12)
		sl.name = "TradeLoopStripLine"
		sl.position = Vector2(10, 20)
		sl.size = Vector2(790, 20)
		sl.autowrap_mode = TextServer.AUTOWRAP_OFF
		sl.clip_text = true
		strip.add_child(sl)
		y0 = 156.0 if not _mob else float(48 + MobilePage.HIT + 16)
	var pickups: Array = World.gather_pickups_here() if city == World.pos else []
	if not pickups.is_empty():
		var offer: Dictionary = World.gather_buy_offer()
		var need_g := str(offer.get("good", ""))
		var need_q := int(offer.get("qty", 0))
		var cost_n := int(offer.get("cost", 0))
		var gb := Panel.new()
		gb.name = "GatherSupplyStrip"
		var gy := y0
		gb.position = Vector2(18, gy)
		gb.size = Vector2(812, 56 if not _mob else float(MobilePage.HIT + 20))
		gb.add_theme_stylebox_override("panel", UIKit.flat_box(Color(UIKit.OK.r, UIKit.OK.g, UIKit.OK.b, 0.12), Color(UIKit.OK, 0.4), 8))
		p.add_child(gb)
		var banner := Locale.t("wq_mkt_gather_banner") % [str(offer.get("good_name", need_g)), int(pickups[0].get("qty", need_q)), need_q]
		if cost_n > 0:
			banner += " · " + (Locale.t("wq_mkt_gather_cost") % cost_n)
		var turnin_days := int(offer.get("turnin_days", 0))
		var turnin_food := int(offer.get("turnin_food", 0))
		if turnin_days > 0:
			banner += " · " + (Locale.t("wq_mkt_gather_turnin_days") % turnin_days)
			if turnin_food > 0:
				banner += " · " + (Locale.t("wq_mkt_gather_turnin_food") % turnin_food)
			if bool(offer.get("turnin_seal_bypass", false)):
				banner += " · " + Locale.t("wq_mkt_gather_turnin_bypass")
		var gl := UIKit.body_label(banner, UIKit.OK, 12)
		gl.name = "GatherSupplyLine"
		gl.position = Vector2(10, 6)
		gl.size = Vector2(560, 44)
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gb.add_child(gl)
		var buy_n := maxi(1, need_q)
		var gbb := UIKit.cta_button(Locale.t("wq_mkt_gather_buy") % buy_n, "A", 200, 32 if not _mob else MobilePage.HIT)
		gbb.name = "GatherBuy"
		gbb.position = Vector2(590, 10 if not _mob else 4)
		gbb.disabled = not bool(offer.get("ok", false))
		gbb.pressed.connect(func(): _do(World.gather_buy_here()))
		gb.add_child(gbb)
		y0 = gy + gb.size.y + 10.0
	var hdr := HBoxContainer.new()
	hdr.position = Vector2(18, y0)
	hdr.add_theme_constant_override("separation", 0)
	p.add_child(hdr)
	var k := 1.4 if _mob else 1.0  # phone: columns sized for 22px text
	for h in [["货物", 130], ["存货", 54], ["买价", 60], ["卖价", 60], ["持有", 54], ["已知最佳卖处", 230], ["", 230]]:
		var l := UIKit.mono(str(h[0]), 9, UIKit.TEXT_FAINT, false)
		l.custom_minimum_size = Vector2(int(h[1] * k), 0)
		hdr.add_child(l)
	var scroll_y := y0 + 20.0
	var v := _scroll(p, Rect2(12, scroll_y, 830, maxf(200.0, 566.0 - scroll_y)))
	var n: Dictionary = World.node(city)
	var keys: Array = World.goods.keys()
	keys.sort_custom(func(a, b):
		var ra := 0 if a in n.get("produce", []) else (2 if a in n.get("demand", []) else 1)
		var rb := 0 if b in n.get("produce", []) else (2 if b in n.get("demand", []) else 1)
		if ra != rb:
			return ra < rb
		return str(a) < str(b))
	for g in keys:
		var gs := str(g)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.custom_minimum_size = Vector2(820, 34)
		var tag := ""
		var col := UIKit.TEXT
		if gs in n.get("produce", []):
			tag = " 产"
			col = UIKit.OK
		elif gs in n.get("demand", []):
			tag = " 缺"
			col = UIKit.EMBER
		var nm := _line(World.good_name(gs) + tag, col, 13, 130 * k)
		row.add_child(nm)
		row.add_child(_line(str(World.stock(city, gs)), UIKit.TEXT_DIM, 12, 54 * k))
		var bp := World.price(city, gs, "buy")
		var sp := World.price(city, gs, "sell")
		row.add_child(_line(str(bp), UIKit.TEXT, 13, 60 * k))
		row.add_child(_line(str(sp), UIKit.TEXT, 13, 60 * k))
		var have := World.have_good(gs)
		row.add_child(_line(str(have), UIKit.ACCENT if have > 0 else UIKit.TEXT_FAINT, 13, 54 * k))
		var best: Dictionary = World.best_known_sell(gs, city)
		var bt := "—"
		var bcol := UIKit.TEXT_FAINT
		if str(best.get("city", "")) != "":
			var margin := int(best.price) - bp
			bt = "%s %d（%+d）" % [World.node(str(best.city)).get("name", ""), int(best.price), margin]
			bcol = UIKit.OK if margin > 0 else UIKit.TEXT_DIM
		row.add_child(_line(bt, bcol, 12, 230 * k))
		var acts := HBoxContainer.new()
		acts.add_theme_constant_override("separation", 4)
		for a in [["买1", "buy1", 1, true], ["买5", "buy5", 5, true], ["卖1", "sell1", 1, false], ["卖全", "sell_all", -1, false]]:
			var qty := int(a[2])
			var is_buy := bool(a[3])
			var q2 := qty if qty > 0 else have
			var good_id := gs
			var trade_qty := q2
			var b := UIKit.ghost_button(str(a[0]), 52, 28)
			b.name = "Mkt_%s_%s" % [gs, str(a[1])]
			if is_buy:
				var stock_ok := World.stock(city, good_id) >= trade_qty
				var silver_ok := GameState.silver >= World.quote_buy(city, good_id, trade_qty)
				var store_kind := str(World.goods[good_id].get("store", ""))
				var cargo_ok := store_kind != "" or World.cargo_used() + trade_qty <= World.cargo_cap()
				b.disabled = not (stock_ok and silver_ok and cargo_ok)
				b.tooltip_text = "共 %d 银" % World.quote_buy(city, good_id, trade_qty)
				b.pressed.connect(func(): _do(World.market_buy(city, good_id, trade_qty)))
			else:
				b.disabled = have <= 0 or trade_qty <= 0
				b.tooltip_text = "共 %d 银" % World.quote_sell(city, good_id, maxi(1, trade_qty))
				b.pressed.connect(func(): _do(World.market_sell(city, good_id, trade_qty)))
			acts.add_child(b)
		if _mob and _m_body_w >= 1200.0:
			# wide phone: trade buttons stay on the price row, pushed to the right
			row.custom_minimum_size = Vector2(0, 76)
			var gap := Control.new()
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(gap)
			row.add_child(acts)
			v.add_child(row)
		elif _mob:
			# phone: trade buttons get their own line under the price row
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 4)
			row.custom_minimum_size = Vector2(0, 34)
			cell.add_child(row)
			cell.add_child(acts)
			v.add_child(cell)
		else:
			row.add_child(acts)
			v.add_child(row)

# ── 委托榜 ────────────────────────────────────────────
func _tab_board() -> void:
	var offers: Array = World.board(city)
	var p := _panel(Rect2(0, 0, 420, 576))
	_head(p, Vector2(18, 14), "委托榜", "COMMISSION BOARD · REFRESH %d 日" % int(World.rules.get("board_refresh_days", 30)))
	var fh := HBoxContainer.new()
	fh.position = Vector2(250, 14) if DeviceProfile.is_mobile() else Vector2(248, 36)  # desktop: below EN line after desk floor
	fh.add_theme_constant_override("separation", 4)
	p.add_child(fh)
	for f in BOARD_FILTERS:
		var fb := UIKit.ghost_button(str(f[1]), 48, 24)
		fb.name = "Filter_" + str(f[0])
		var fid := str(f[0])
		if fid == _board_filter:
			fb.add_theme_color_override("font_color", UIKit.ACCENT)
			var fs := UIKit.flat_box(Color(UIKit.ACCENT, 0.16), Color(UIKit.ACCENT, 0.7), 6)
			fs.content_margin_top = 2
			fs.content_margin_bottom = 2
			fb.add_theme_stylebox_override("normal", fs)
		fb.pressed.connect(func(): _board_filter = fid; _render_tab())
		fh.add_child(fb)
	var v := _scroll(p, Rect2(12, 58, 400, 300))
	var all_q: Array = []
	var shown: Array = []
	for q in offers:
		all_q.append(q)
		var is_battle := bool(q.get("battle", false))
		if _board_filter == "all" or (_board_filter == "battle" and is_battle) or (_board_filter == "trade" and not is_battle):
			shown.append(q)
	if _sel_quest == "" and not shown.is_empty():
		_sel_quest = str(shown[0].id)
	for q in shown:
		var why := World.quest_locked_reason(q)
		var lab := "%s【%s】%s%s" % ["★" if bool(q.get("sig", false)) else "", World.quest_kind_label(str(q.kind)), q.title, "  ⛓" if bool(q.get("chain", false)) else ""]
		var sub := "%d 银 · 声望 +%d · 期限 %d 日 · 险 %s" % [int(q.reward_silver), int(q.reward_rep), int(q.days_budget), "▮".repeat(int(q.danger))]
		if why != "":
			sub = "🔒 " + why
		var b := _row_button(lab, sub, 388, str(q.id) == _sel_quest, why != "")
		b.name = "Offer_" + str(q.id)
		var badge := UIKit.title_label(World.quest_kind_label(str(q.kind)).substr(0, 1), 18, UIKit.EMBER if bool(q.get("sig", false)) else (Color("#C9B8FF") if bool(q.get("chain", false)) else UIKit.ACCENT))
		var tier_l := UIKit.mono("T%d" % int(q.tier), 8, UIKit.TEXT_FAINT, false)
		tier_l.position = Vector2(14, 32)
		tier_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tier_l)
		badge.position = Vector2(14, 10)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		# Issuer crest (团徽 for hq, nation plate otherwise) — right edge of the offer row.
		CKHeraldryField.pin_board_row_arms(b, str(q.get("issuer", city)), Vector2(388.0 - 28.0 - 8.0, 6.0), Vector2(28, 34))
		var qid := str(q.id)
		b.pressed.connect(func(): _sel_quest = qid; _render_tab())
		v.add_child(b)
	if shown.is_empty() and not offers.is_empty():
		v.add_child(_para("此筛选下没有委托。", UIKit.TEXT_FAINT, 12, 380))
	if offers.is_empty():
		v.add_child(_para("榜上暂无委托——%d 日后刷新。" % (int(World.rules.get("board_refresh_days", 30)) - World.days_total % int(World.rules.get("board_refresh_days", 30))), UIKit.TEXT_FAINT, 12, 380))
		# empty state: point a new player at the capital, whose board always has work
		var cap := str(World.nations.get(World.nation_of(city), {}).get("capital", ""))
		if cap != "" and cap != city:
			v.add_child(_para(Locale.t("mob_ui_059") % str(World.node(cap).get("name", cap)), UIKit.ACCENT, 12, 380))
			var gb := UIKit.ghost_button(Locale.t("mob_ui_060") % str(World.node(cap).get("name", cap)), 300, 40)
			gb.name = "BoardGoCapital"
			gb.pressed.connect(func(): GameState.set_meta("atlas_view", World.nation_of(cap)); _back())
			v.add_child(gb)
	var al := UIKit.mono("ACTIVE %d/%d" % [World.active.size(), int(World.rules.get("active_limit", 5))], 9, UIKit.ACCENT)
	al.position = Vector2(18, 366)
	p.add_child(al)
	var v2 := _scroll(p, Rect2(12, 384, 400, 184))
	for q in World.active:
		all_q.append(q)
		var here := World.can_turn_in(q, city)
		var st := "可交付" if here else ("待交付 @%s" % World.node(World.turn_in_city(q)).get("name", "") if str(q.state) == "ready" else "进行中 · 剩 %d 日" % maxi(0, int(q.get("deadline", 0)) - World.days_total))
		var b2 := _row_button(str(q.title), st, 388, str(q.id) == _sel_quest, false)
		b2.name = "Active_" + str(q.id)
		var badge2 := UIKit.title_label("✓" if str(q.state) == "ready" else World.quest_kind_label(str(q.kind)).substr(0, 1), 18, UIKit.OK if str(q.state) == "ready" else UIKit.TEXT_DIM)
		badge2.position = Vector2(14, 10)
		badge2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b2.add_child(badge2)
		var qid2 := str(q.id)
		b2.pressed.connect(func(): _sel_quest = qid2; _render_tab())
		v2.add_child(b2)
	var sel: Dictionary = {}
	for q in all_q:
		if str(q.id) == _sel_quest:
			sel = q
	if sel.is_empty():
		return
	var d := _panel(Rect2(432, 0, 416, 576))
	d.name = "QuestDetail"
	var is_active := str(sel.get("state", "offer")) != "offer"
	var e := UIKit.mono("%s // %s" % ["ACTIVE" if is_active else "OFFER", str(sel.kind).to_upper()], 9, UIKit.EMBER if bool(sel.get("sig", false)) else UIKit.ACCENT)
	e.position = Vector2(18, 16)
	d.add_child(e)
	CKHeraldryField.place_board_crest(d, str(sel.get("issuer", city)), Vector2(352, 14), Vector2(44, 52))
	var t := _para(str(sel.title), UIKit.TEXT, 19, 320)
	t.position = Vector2(18, 32)
	d.add_child(t)
	var desc := _para(str(sel.get("desc", "")), UIKit.TEXT_DIM, 12, 380)
	desc.position = Vector2(18, 90)
	d.add_child(desc)
	var kv := VBoxContainer.new()
	kv.position = Vector2(18, 210)
	kv.add_theme_constant_override("separation", 5)
	d.add_child(kv)
	kv.add_child(UIKit.kv_row("发布", "%s · T%d%s" % [World.node(str(sel.issuer)).get("name", ""), int(sel.tier), " · 委托链" if bool(sel.get("chain", false)) else ""], UIKit.TEXT, 380))
	var need_n := World.quest_req_nation(sel)
	kv.add_child(UIKit.kv_row("门槛", "城声望 %d%s" % [int(sel.get("req_rep", 0)), " · 邦交 %d" % need_n if need_n > 0 else ""], UIKit.TEXT_DIM, 380))
	if str(sel.kind) == "gather":
		kv.add_child(UIKit.kv_row("所需", "%s ×%d（持有 %d）" % [World.good_name(str(sel.good)), int(sel.qty), World.have_good(str(sel.good))], UIKit.TEXT, 380))
		var supply := World.gather_supply_city(sel)
		if supply != "":
			kv.add_child(UIKit.kv_row(Locale.t("wq_board_supply"), str(World.node(supply).get("name", supply)), UIKit.ACCENT, 380))
			var march: Dictionary = World.gather_supply_march_preview(sel)
			if not march.is_empty() and int(march.get("days", 0)) >= 0:
				var march_txt := Locale.t("wq_board_supply_days") % [int(march.get("days", 0)), int(march.get("food", 0))]
				if bool(march.get("seal_bypass", false)):
					march_txt += Locale.t("wq_board_supply_bypass")
				var march_lbl := UIKit.kv_row(Locale.t("wq_board_supply_march"), march_txt, UIKit.OK, 380)
				march_lbl.name = "BoardSupplyMarch"
				kv.add_child(march_lbl)
	elif str(sel.kind) == "clear":
		kv.add_child(UIKit.kv_row("目标路段", "%s — %s" % [World.node(str(sel.edge[0])).get("name", ""), World.node(str(sel.edge[1])).get("name", "")], UIKit.DANGER, 380))
	else:
		kv.add_child(UIKit.kv_row("目标", "%s（%d 日路程）" % [World.node(str(sel.target)).get("name", ""), int(sel.get("route_days", 0))], UIKit.DANGER if bool(sel.get("battle", false)) else UIKit.TEXT, 380))
	kv.add_child(UIKit.kv_row("交付地点", str(World.node(World.turn_in_city(sel)).get("name", "")), UIKit.OK, 380))
	kv.add_child(UIKit.kv_row("报酬", "%d 银 · 声望 +%d%s" % [int(sel.reward_silver), int(sel.reward_rep), " · %s ×%d" % [World.good_name(str(sel.reward_good)), int(sel.reward_qty)] if sel.has("reward_good") else ""], UIKit.ACCENT, 380))
	kv.add_child(UIKit.kv_row("期限", "%d 日" % int(sel.days_budget) if not is_active else "剩 %d 日" % maxi(0, int(sel.get("deadline", 0)) - World.days_total), UIKit.TEXT, 380))
	kv.add_child(UIKit.kv_row("战斗", "是 · 危险 %s" % "▮".repeat(int(sel.danger)) if bool(sel.get("battle", false)) else "否", UIKit.DANGER if bool(sel.get("battle", false)) else UIKit.TEXT_DIM, 380))
	if sel.has("unlock"):
		kv.add_child(UIKit.kv_row("名誉奖励", "解锁「%s」" % World.item(str(sel.unlock)).get("name", ""), UIKit.EMBER, 380))
	if not is_active:
		var why := World.quest_locked_reason(sel)
		var ab := UIKit.cta_button("接下委托", "A", 380, 44)
		ab.name = "AcceptQuest"
		ab.position = Vector2(18, 470)
		ab.disabled = why != ""
		ab.tooltip_text = why
		var sid := str(sel.id)
		ab.pressed.connect(func(): _accept_offer(sid))
		d.add_child(ab)
		if why != "":
			var wl := _para("🔒 " + why, UIKit.EMBER, 12, 380)
			wl.position = Vector2(18, 524)
			d.add_child(wl)
	else:
		var sid2 := str(sel.id)
		var here := World.can_turn_in(sel, city)
		var guide := World.quest_guide_node(sel)
		# Not deliverable here: the primary slot points at the atlas (phones clip the lower row).
		var to_atlas := guide != "" and not here
		if to_atlas:
			var gb := UIKit.cta_button(Locale.t("wq_goto_atlas"), "A", 240, 44)
			gb.name = "GotoAtlasQuest"
			gb.position = Vector2(18, 470)
			gb.pressed.connect(func(): _open_atlas_for_quest(World.quest_by_id(sid2)))
			d.add_child(gb)
		var ti_text := "交付"
		var tb := UIKit.cta_button(ti_text, "A", 240, 44) if not to_atlas else UIKit.ghost_button(ti_text, 240, 36)
		tb.name = "TurnInQuest"
		tb.position = Vector2(18, 470 if not to_atlas else 524)
		tb.disabled = not here
		tb.pressed.connect(func(): _do(World.turn_in(sid2)); _sel_quest = "")
		d.add_child(tb)
		var xb := UIKit.ghost_button("放弃（声望 -4）", 130, 44)
		xb.name = "AbandonQuest"
		xb.position = Vector2(268, 470)
		xb.pressed.connect(func(): _do(World.abandon(sid2)); _sel_quest = "")
		d.add_child(xb)

# ── 酒馆 ──────────────────────────────────────────────
func _tab_tavern() -> void:
	var lst: Array = World.city_recruits(city)
	var nat: Dictionary = World.nations.get(World.nation_of(city), {})
	var p := _panel(Rect2(0, 0, 848, 576))
	_head(p, Vector2(18, 14), "酒馆", "TAVERN · %s 血脉" % str(nat.get("en", "")))
	var note_txt := "此地出身多为：%s。每 %d 日换一批人。" % [_blood_pool_text(nat), int(World.rules.get("board_refresh_days", 30))]
	var rumor := CKCourt.latest_rumor()
	if rumor != "":
		note_txt += "  闲话：%s" % rumor
	var note := UIKit.body_label(note_txt, UIKit.TEXT_DIM, 12)
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.position = Vector2(300, 22)
	p.add_child(note)
	var h := HBoxContainer.new()
	h.position = Vector2(18, 60)
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	if lst.is_empty():
		h.add_child(_para("酒馆里只剩醉汉——下月再来。", UIKit.TEXT_FAINT, 13, 400))
	var inspect := CKBloodline.inspect_level()
	for i in lst.size():
		var c: CKCharacter = lst[i]
		var card := Panel.new()
		card.custom_minimum_size = Vector2(260, 500)
		card.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.1), 10))
		h.add_child(card)
		var pr := UIKit.make_portrait_rect(c, 150)
		pr.position = Vector2(55, 14)
		pr.size = Vector2(150, 150)
		card.add_child(pr)
		var nm := UIKit.title_label(c.name, 18)
		nm.position = Vector2(16, 172)
		card.add_child(nm)
		var bl := UIKit.tag_chip(c.bloodline_display(), UIKit.ACCENT)
		bl.position = Vector2(16, 202)
		card.add_child(bl)
		var kv := VBoxContainer.new()
		kv.position = Vector2(16, 232)
		kv.add_theme_constant_override("separation", 3)
		card.add_child(kv)
		kv.add_child(UIKit.kv_row("职业", str(GameState.get_job(c.job_id).get("name", c.job_id)), UIKit.TEXT, 228))
		kv.add_child(UIKit.kv_row("年龄 / 等级", "%d / Lv%d" % [c.age, c.level], UIKit.TEXT, 228))
		kv.add_child(UIKit.kv_row("攻 / 防 / 命中", "%d / %d / %d" % [c.derived_atk(), c.derived_def(), c.derived_hit()], UIKit.TEXT, 228))
		kv.add_child(UIKit.kv_row("生命", str(c.max_hp), UIKit.TEXT, 228))
		kv.add_child(UIKit.kv_row("月俸", "%d 银" % c.salary, UIKit.TEXT_DIM, 228))
		var tr: Array = []
		for t in c.traits:
			tr.append(str(GameState.get_trait(str(t)).get("name", t)))
		var tl := _para("特质：%s" % ("、".join(tr) if not tr.is_empty() else "—"), UIKit.TEXT_DIM, 11, 228)
		tl.position = Vector2(16, 360)
		card.add_child(tl)
		var shown_sigs := CKBloodline.visible_signatures(c, inspect)
		var sig_line := CKBloodline.summary_zh(c, inspect)
		var obs := CKBloodline.observe_zh(c, inspect)
		if obs != "":
			sig_line += "\n" + obs
		var sg := _para(sig_line, UIKit.ACCENT if not shown_sigs.is_empty() else UIKit.TEXT_FAINT, 11, 228)
		sg.name = "Sig%d" % i
		sg.position = Vector2(16, 404)
		card.add_child(sg)
		var cost := World.hire_cost(c)
		var hb := UIKit.cta_button("雇佣 · %d 银" % cost, "", 228, 40)
		hb.name = "Hire%d" % i
		hb.position = Vector2(16, 444)
		hb.disabled = GameState.silver < cost
		hb.tooltip_text = "银币不足" if GameState.silver < cost else ""
		var idx := i
		hb.pressed.connect(func():
			var hr: Dictionary = World.hire(city, idx)
			if bool(hr.get("ok", false)) and str(hr.get("id", "")) != "":
				_sel_char = str(hr.id)  # armory opens on the fresh hire
			_do(hr))
		card.add_child(hb)
		if _mob:
			# phone: the card becomes a column so 22px rows stack instead of overlapping
			var cw := clampf((_m_body_w - 80.0) / maxf(1.0, float(lst.size())) - 12.0, 280.0, 460.0)
			card.custom_minimum_size = Vector2(cw, 0)
			var out := MobileReflow.reflow(card, cw)
			out.custom_minimum_size.x = cw
			out.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _tab_lamp() -> void:
	var leader = GameState.get_leader()
	var board := CKCourt.lamp_board(leader, World.nation_rep("lantern"), Calendar.year)
	CKCourt.build_lamp_ui(_body, board, Callable(self, "_on_lamp_bid"))

func _on_lamp_bid(amount: int) -> void:
	var leader = GameState.get_leader()
	if leader == null:
		_toast_msg("没有家主", UIKit.DANGER)
		return
	var r := CKCourt.place_bid(leader, amount, World.nation_rep("lantern"), Calendar.year)
	_toast_msg(str(r.get("msg", "")), UIKit.OK if bool(r.get("ok", false)) else UIKit.DANGER)
	_refresh_all()

func _blood_pool_text(nat: Dictionary) -> String:
	var seen := {}
	var out: Array = []
	for b in nat.get("blood", []):
		if seen.has(b):
			continue
		seen[b] = true
		out.append(str(GameState.get_bloodline(str(b)).get("name", b)))
	return "、".join(out)

# ── 军械库 ────────────────────────────────────────────
func _tab_armory() -> void:
	var roster: Array = GameState.roster()
	if (_sel_char == "" or not GameState.characters.has(_sel_char)) and not roster.is_empty():
		_sel_char = str(roster[0].id)
	var p := _panel(Rect2(0, 0, 300, 576))
	_head(p, Vector2(18, 14), "编制", "ROSTER")
	var v := _scroll(p, Rect2(12, 58, 280, 508))
	for c in roster:
		var cc: CKCharacter = c
		var w: Dictionary = World.item(cc.weapon_id)
		var b := _row_button(cc.name, "%s · 攻%d 防%d · %s" % [GameState.get_job(cc.job_id).get("name", ""), cc.derived_atk(), cc.derived_def(), w.get("name", "旧式兵器")], 268, cc.id == _sel_char, false)
		b.name = "Char_" + cc.id
		var pr := UIKit.make_portrait_rect(cc, 38)
		pr.position = Vector2(6, 4)
		pr.size = Vector2(38, 38)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pr)
		var cid := cc.id
		b.pressed.connect(func(): _sel_char = cid; _render_tab())
		v.add_child(b)
	var c2: CKCharacter = GameState.characters.get(_sel_char)
	if c2 == null:
		return
	var d := _panel(Rect2(312, 0, 536, 576))
	d.name = "ArmoryDetail"
	_head(d, Vector2(18, 14), c2.name, "LOADOUT // %s" % str(GameState.get_job(c2.job_id).get("name", "")))
	var sh := HBoxContainer.new()
	sh.position = Vector2(18, 58)
	sh.add_theme_constant_override("separation", 8)
	d.add_child(sh)
	for k in [["攻", c2.derived_atk()], ["防", c2.derived_def()], ["命中", c2.derived_hit()], ["回避", c2.derived_avo()], ["暴击", c2.derived_crit()], ["生命", c2.max_hp]]:
		sh.add_child(UIKit.stat_box(str(k[0]), str(k[1])))
	var slots := VBoxContainer.new()
	slots.position = Vector2(18, 128)
	slots.add_theme_constant_override("separation", 6)
	d.add_child(slots)
	for slot in ["weapon", "armor", "charm"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var cur := World.equipped(c2, slot)
		var it: Dictionary = World.item(cur)
		row.add_child(_line("%s：%s" % [World.SLOT_ZH[slot], it.get("name", "（无）" if slot != "weapon" else ("旧式兵器" if cur != "" else "（无）"))], UIKit.TEXT if not it.is_empty() else UIKit.TEXT_FAINT, 13, 300))
		row.add_child(_line(World.item_stats_text(it), UIKit.ACCENT, 12, 100))
		var ub := UIKit.ghost_button("卸下", 64, 28)
		ub.name = "Unequip_" + slot
		ub.disabled = it.is_empty()
		var sl = slot
		ub.pressed.connect(func(): World.unequip(c2.id, sl); _toast_msg("已卸下", UIKit.TEXT); _refresh_all())
		row.add_child(ub)
		slots.add_child(row)
	var al := UIKit.mono("ARMORY · 世界装备 %d 件" % _armory_count(), 9, UIKit.ACCENT)
	al.position = Vector2(18, 236 if not _mob else 420)
	d.add_child(al)
	# phone: rows are regrouped by y, so keep the armory list clearly below the slot rows
	var v2 := _scroll(d, Rect2(12, 254, 518, 314) if not _mob else Rect2(12, 460, 518, 314))
	var ids: Array = World.armory.keys()
	ids.sort()
	for iid in ids:
		var it2: Dictionary = World.item(str(iid))
		var why := World.can_equip(c2, it2)
		var cur2: Dictionary = World.item(World.equipped(c2, str(it2.slot)))
		var dlt: Array = []
		for k in ["atk", "def", "hit", "avo", "crit", "move", "hp"]:
			var dv := int(it2.get("stats", {}).get(k, 0)) - int(cur2.get("stats", {}).get(k, 0))
			if dv != 0:
				dlt.append("%s%+d" % [World.STAT_ZH[k], dv])
		var b2 := _row_button("%s ×%d" % [it2.name, int(World.armory[iid])], why if why != "" else ("较当前：" + (" ".join(dlt) if not dlt.is_empty() else "持平")), 500, false, why != "")
		b2.name = "Equip_" + str(iid)
		var ic := _icon(it2, 38)
		ic.position = Vector2(6, 4)
		b2.add_child(ic)
		b2.disabled = why != ""
		b2.tooltip_text = why
		var iid_s := str(iid)
		b2.pressed.connect(func(): _do(World.equip(c2.id, iid_s)))
		v2.add_child(b2)
	if ids.is_empty():
		v2.add_child(_para("军械库是空的。到各城铁匠铺购买或打造世界装备。", UIKit.TEXT_FAINT, 12, 480))

func _armory_count() -> int:
	var n := 0
	for k in World.armory.keys():
		n += int(World.armory[k])
	return n

# ── shared ────────────────────────────────────────────

func _accept_offer(qid: String) -> void:
	var r: Dictionary = World.accept_quest(city, qid)
	_sel_quest = qid
	_do(r)


func _open_atlas_for_quest(q: Dictionary) -> void:
	var guide := World.quest_guide_node(q)
	if guide == "":
		guide = str(q.get("target", ""))
	if guide != "" and World.nodes.has(guide):
		GameState.set_meta("atlas_select", guide)
		var nv := World.nation_of(guide)
		if nv != "":
			GameState.set_meta("atlas_view", nv)
	_back()


func _do(r: Dictionary) -> void:
	var ok := bool(r.get("ok", false))
	var msg := str(r.get("msg", ""))
	if not World.milestones.is_empty():
		var ms: Dictionary = World.milestones.pop_back()
		World.milestones.clear()
		msg = str(ms.text)
		UIFX.confirm_burst(_side)
	_toast_msg(msg, UIKit.OK if ok else UIKit.DANGER)
	if ok:
		Sfx.play("anvil_clang" if tab == "smith" else ("deal" if tab == "market" else "ui_confirm"))
	else:
		UIFX.soft_deny(_body)
	_refresh_all()

func _toast_msg(text: String, col: Color) -> void:
	if text == "":
		return
	_toast.text = text
	_toast.add_theme_color_override("font_color", col)
	_toast.visible = true
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _toast.visible = false)


func _on_city_seal_resupply() -> void:
	var r: Dictionary = World.city_seal_resupply()
	if bool(r.get("ok", false)):
		_toast_msg(str(r.get("msg", "")), UIKit.OK)
		_refresh_all()
	else:
		_toast_msg(str(r.get("msg", Locale.t("atlas_resupply_fail_stock"))), UIKit.DANGER)

func _back() -> void:
	World.note_city_gate("out")
	UIFX.page_exit(self)
	CKNav.up(ATLAS)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		if k == KEY_Q or k == KEY_E:
			var ids: Array = []
			for t in tabs:
				if not (_tab_btn[str(t[0])] as Button).disabled:
					ids.append(str(t[0]))
			var i := ids.find(tab)
			_set_tab(str(ids[(i + (1 if k == KEY_E else -1) + ids.size()) % ids.size()]))

# ── e2e hook ──────────────────────────────────────────
func selftest() -> Dictionary:
	var msgs: Array = []
	for t in tabs:
		if (_tab_btn[str(t[0])] as Button).disabled:
			continue
		_set_tab(str(t[0]))
		await get_tree().process_frame
		if _body.get_child_count() == 0:
			return {"ok": false, "msg": "tab %s empty" % t[0]}
	msgs.append("tabs ok")
	# smith: buy an item the leader can equip (atlas e2e may already hold a stronger
	# signature sword; first-available stock is often a job-gated bow).
	_set_tab("smith")
	await get_tree().process_frame
	var reveal := find_child("SmithRevealSkip", true, false) as Button
	if reveal:
		reveal.pressed.emit()
		await get_tree().process_frame
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return {"ok": false, "msg": "no leader"}
	_sel_item = ""
	for e in World.smith_stock(city):
		if not bool(e.available):
			continue
		var cand: Dictionary = e.item
		if World.can_equip(leader, cand) != "":
			continue
		_sel_item = str(cand.id)
		# prefer a weapon so the atk assertion is meaningful
		if str(cand.get("slot", "")) == "weapon":
			break
	if _sel_item == "":
		return {"ok": false, "msg": "no smith stock the leader can equip"}
	var arm0 := _armory_count()
	GameState.silver += 2000
	_render_tab()
	await get_tree().process_frame
	var buy := _body.find_child("BuyItem", true, false) as Button
	if buy == null or buy.disabled:
		return {"ok": false, "msg": "no BuyItem"}
	buy.pressed.emit()
	await get_tree().process_frame
	if _armory_count() != arm0 + 1:
		return {"ok": false, "msg": "smith buy via UI failed"}
	msgs.append("smith buy")
	# armory: equip the just-bought piece (unequip slot first so atk can't drop)
	var bought_id := str(_sel_item)
	if bought_id == "" or int(World.armory.get(bought_id, 0)) <= 0:
		return {"ok": false, "msg": "bought item missing from armory"}
	var slot := str(World.item(bought_id).get("slot", "weapon"))
	World.unequip(leader.id, slot)
	_set_tab("armory")
	await get_tree().process_frame
	_sel_char = leader.id
	_render_tab()
	await get_tree().process_frame
	var atk0 := leader.derived_atk()
	var eq := _body.find_child("Equip_" + bought_id, true, false) as Button
	if eq == null or eq.disabled:
		return {"ok": false, "msg": "Equip_%s missing/disabled" % bought_id}
	eq.pressed.emit()
	await get_tree().process_frame
	if World.equipped(leader, slot) != bought_id:
		return {"ok": false, "msg": "equip via UI failed"}
	if slot == "weapon" and leader.derived_atk() <= atk0:
		return {"ok": false, "msg": "equip did not raise atk"}
	msgs.append("smith equip")
	# tavern: hire face 0, then equip a weapon still in the armory.
	# Smith equip consumed the bought copy; unequip put the previous piece back.
	_set_tab("tavern")
	await get_tree().process_frame
	var hire_btn := _body.find_child("Hire0", true, false) as Button
	if hire_btn == null:
		return {"ok": false, "msg": "no Hire0"}
	GameState.silver += 5000
	_render_tab()
	await get_tree().process_frame
	hire_btn = _body.find_child("Hire0", true, false) as Button
	var roster0 := GameState.roster().size()
	hire_btn.pressed.emit()
	await get_tree().process_frame
	if GameState.roster().size() != roster0 + 1:
		return {"ok": false, "msg": "tavern hire via UI failed"}
	var hired_id := _sel_char
	if hired_id == "" or hired_id == GameState.get_leader().id:
		# fall back: newest non-leader
		for c3 in GameState.roster():
			if c3.id != GameState.get_leader().id:
				hired_id = c3.id
				break
	msgs.append("tavern hire")
	_set_tab("armory")
	await get_tree().process_frame
	_sel_char = hired_id
	_render_tab()
	await get_tree().process_frame
	var char_row := _body.find_child("Char_" + hired_id, true, false) as Button
	if char_row == null:
		return {"ok": false, "msg": "Char_%s missing" % hired_id}
	var hired: CKCharacter = GameState.characters.get(hired_id)
	var eq_id := ""
	for k in World.armory.keys():
		var itk: Dictionary = World.item(str(k))
		if str(itk.get("slot", "")) != "weapon":
			continue
		if World.can_equip(hired, itk) == "":
			eq_id = str(k)
			break
	if eq_id == "":
		# force job so regional sword fits
		hired.job_id = "squire"
		for k2 in World.armory.keys():
			var itk2: Dictionary = World.item(str(k2))
			if str(itk2.get("slot", "")) != "weapon":
				continue
			if World.can_equip(hired, itk2) == "":
				eq_id = str(k2)
				break
		_render_tab()
		await get_tree().process_frame
	var eqh := _body.find_child("Equip_" + eq_id, true, false) as Button
	if eqh == null or eqh.disabled:
		return {"ok": false, "msg": "Equip_%s missing/disabled on hire" % eq_id}
	var atk_h0 := hired.derived_atk()
	eqh.pressed.emit()
	await get_tree().process_frame
	if World.equipped(hired, "weapon") != eq_id:
		return {"ok": false, "msg": "equip hire via UI failed"}
	if hired.derived_atk() < atk_h0:
		return {"ok": false, "msg": "hire equip did not hold atk"}
	msgs.append("hire equip")
	# market: buy 1 of the first produced good, sell 1 back, refresh when stock drained
	_set_tab("market")
	await get_tree().process_frame
	var g := str(World.node(city).get("produce", ["grain"])[0])
	var mb := _body.find_child("Mkt_%s_buy1" % g, true, false) as Button
	if mb == null or mb.disabled:
		return {"ok": false, "msg": "market buy button missing/disabled for " + g}
	var h0 := World.have_good(g)
	var silver0 := GameState.silver
	mb.pressed.emit()
	await get_tree().process_frame
	if World.have_good(g) != h0 + 1:
		return {"ok": false, "msg": "market buy via UI failed"}
	if GameState.silver >= silver0:
		return {"ok": false, "msg": "market buy did not spend silver"}
	msgs.append("market buy")
	var sell_btn := _body.find_child("Mkt_%s_sell1" % g, true, false) as Button
	if sell_btn == null or sell_btn.disabled:
		return {"ok": false, "msg": "market sell button missing/disabled for " + g}
	var h1 := World.have_good(g)
	sell_btn.pressed.emit()
	await get_tree().process_frame
	if World.have_good(g) != h1 - 1:
		return {"ok": false, "msg": "market sell via UI failed"}
	msgs.append("market sell")
	# drain one unit of stock then refresh
	World.market[city][g] = 0
	_render_tab()
	await get_tree().process_frame
	var ref := _body.find_child("MarketRefresh", true, false) as Button
	if ref == null:
		return {"ok": false, "msg": "MarketRefresh missing"}
	var st0 := World.stock(city, g)
	ref.pressed.emit()
	await get_tree().process_frame
	if World.stock(city, g) <= st0:
		return {"ok": false, "msg": "market refresh did not restock"}
	msgs.append("market refresh")
	# board: accept first unlocked offer via the detail button
	_set_tab("board")
	for q in World.board(city):
		if World.quest_locked_reason(q) == "":
			_sel_quest = str(q.id)
			break
	_render_tab()
	await get_tree().process_frame
	var ab := _body.find_child("AcceptQuest", true, false) as Button
	var a0 := World.active.size()
	if ab and not ab.disabled:
		ab.pressed.emit()
		await get_tree().process_frame
		if World.active.size() != a0 + 1:
			return {"ok": false, "msg": "accept via UI failed"}
		msgs.append("accept")
	_set_tab("armory")
	await get_tree().process_frame
	return {"ok": true, "msg": ", ".join(msgs)}



func _tab_sundry() -> void:
	var p := _panel(Rect2(0, 0, 848, 576))
	_head(p, Vector2(18, 14), Locale.t("sundry_title"), "SUNDRIES · LOCAL GOODS")
	var note := _para(Locale.t("sundry_note"), UIKit.TEXT_DIM, 13, 812)
	note.position = Vector2(18, 52)
	p.add_child(note)
	var v := _scroll(p, Rect2(12, 92, 830, 474))
	var shelf: Array = CKSundries.shelf_for_city(city)
	if shelf.is_empty():
		v.add_child(_para(Locale.t("sundry_empty_shelf"), UIKit.TEXT_DIM, 14, 800))
	for offer in shelf:
		var iid := str(offer.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(812, 52)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(480, 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var offer_line := Locale.t("sundry_offer_line") % [str(offer.get("name", iid)), int(offer.get("price", 0)), CKSundries.owned(iid), CKSundries.max_stack()]
		info.add_child(_line(offer_line, UIKit.TEXT, 14, 480))
		info.add_child(_line(str(offer.get("desc", "")), UIKit.TEXT_DIM, 12, 480))
		row.add_child(info)
		var buy := UIKit.ghost_button(Locale.t("sundry_buy"), 120, 48)
		buy.name = "SundryBuy_" + iid
		buy.pressed.connect(func(): _sundry_result(CKSundries.buy(city, iid)))
		row.add_child(buy)
		var use := UIKit.ghost_button(Locale.t("sundry_use"), 120, 48)
		use.name = "SundryUse_" + iid
		var can: Dictionary = CKSundries.usable(iid)
		use.disabled = not bool(can.get("ok", false))
		use.tooltip_text = str(can.get("msg", ""))
		use.pressed.connect(func(): _sundry_result(CKSundries.use(iid, "", city)))
		row.add_child(use)
		v.add_child(row)
	## 行李里别国带来的：只能半价清掉
	var foreign: Array = []
	for k in CKSundries.bag().keys():
		var on_shelf := false
		for o in shelf:
			if str(o.get("id", "")) == str(k):
				on_shelf = true
		if not on_shelf and CKSundries.owned(str(k)) > 0:
			foreign.append(str(k))
	if not foreign.is_empty():
		v.add_child(_line(Locale.t("sundry_bag_head"), UIKit.ACCENT, 13, 800))
	for k2 in foreign:
		var r2 := HBoxContainer.new()
		r2.add_theme_constant_override("separation", 8)
		r2.custom_minimum_size = Vector2(812, 52)
		var nm := _line("%s × %d" % [CKSundries.item_name(k2), CKSundries.owned(k2)], UIKit.TEXT, 14, 480)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r2.add_child(nm)
		var ub := UIKit.ghost_button(Locale.t("sundry_use"), 120, 48)
		ub.name = "SundryUse_" + k2
		var can2: Dictionary = CKSundries.usable(k2)
		ub.disabled = not bool(can2.get("ok", false))
		ub.tooltip_text = str(can2.get("msg", ""))
		ub.pressed.connect(func(): _sundry_result(CKSundries.use(k2, "", city)))
		r2.add_child(ub)
		var sb := UIKit.ghost_button(Locale.t("sundry_sell"), 120, 48)
		sb.name = "SundrySell_" + k2
		sb.pressed.connect(func(): _sundry_result(CKSundries.sell_half(city, k2)))
		r2.add_child(sb)
		v.add_child(r2)


func _sundry_result(r: Dictionary) -> void:
	_toast_msg(str(r.get("msg", "")), UIKit.OK if bool(r.get("ok", false)) else UIKit.DANGER)
	_refresh_all()

# ── 本城之事 · 职印 浮层 ─────────────────────────────
var _aff_overlay: Control


func open_affairs(msg: String = "", ok: bool = true) -> void:
	if _aff_overlay != null and is_instance_valid(_aff_overlay):
		_aff_overlay.queue_free()
		_aff_overlay = null
	# city_affairs.gd is RefCounted data only; phone chrome lives here (caller), like lineage_info.
	if _mob:
		_open_affairs_mobile(msg, ok)
		return
	var o := ColorRect.new()
	o.name = "AffairOverlay"
	o.color = Color(0.04, 0.06, 0.1, 0.92)
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(o)
	_aff_overlay = o
	var ash := Vector2(36, 44)
	CKHeraldryField.place_affairs_crest_strip(o, city, Vector2(maxf(8.0, size.x - ash.x * 2.0 - 48.0), 16.0), ash)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 32)
	o.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	_fill_affairs_body(v, msg, ok, false, func():
		o.queue_free()
		_aff_overlay = null
		_refresh_all())


## Phone: MobilePage sheet + scroll so FONT_FLOOR / 76px hits do not crush the affair list.
func _open_affairs_mobile(msg: String, ok: bool) -> void:
	var title := Locale.t("js_76d637f6") % str(World.node(city).get("name", city))
	var sh: Array = MobilePage.sheet(self, "AffairOverlay", title, 40, UIKit.ACCENT)
	var o := sh[0] as Control
	var card := sh[1] as VBoxContainer
	_aff_overlay = o
	var ash := Vector2(32, 38)
	CKHeraldryField.place_affairs_crest_strip(card, city, Vector2(8, 6), ash)
	var list := MobilePage.sheet_scroll(card, MobilePage.HIT + 36.0)
	_fill_affairs_body(list, msg, ok, true, func(): pass)
	var close := MobilePage.button(Locale.t("js_4782a703"), false, func():
		o.queue_free()
		_aff_overlay = null
		_refresh_all())
	close.name = "AffairClose"
	card.add_child(close)


func _fill_affairs_body(v: VBoxContainer, msg: String, ok: bool, mobile: bool, on_close: Callable) -> void:
	var fs := MobilePage.FONT if mobile else 15
	var fs_dim := MobilePage.FONT if mobile else 13
	var hit := int(MobilePage.HIT) if mobile else 48
	if not mobile:
		var head := HBoxContainer.new()
		v.add_child(head)
		var t := UIKit.title_label(Locale.t("js_76d637f6") % str(World.node(city).get("name", city)), 18)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		var close := UIKit.ghost_button(Locale.t("js_4782a703"), 120, hit)
		close.pressed.connect(on_close)
		head.add_child(close)
	if msg != "":
		var ml := UIKit.body_label(msg, UIKit.OK if ok else UIKit.DANGER, fs if mobile else 14)
		ml.name = "AffairMsg"
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if mobile:
			ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(ml)
	var lab := UIKit.body_label(CKCityAffairs.label(city), UIKit.TEXT, fs)
	lab.name = "AffairLabel"
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if mobile:
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(lab)
	var chk: Dictionary = CKCityAffairs.can_do(city)
	var go: Button
	if mobile:
		go = MobilePage.button(Locale.t("js_f05ab037"), true, func():
			var r := CKCityAffairs.do_affair(city)
			open_affairs(str(r.get("msg", "")), bool(r.get("ok", false))))
		go.disabled = not bool(chk.get("ok", false))
	else:
		go = UIKit.ghost_button(Locale.t("js_f05ab037"), 160, hit)
		go.disabled = not bool(chk.get("ok", false))
		go.pressed.connect(func():
			var r := CKCityAffairs.do_affair(city)
			open_affairs(str(r.get("msg", "")), bool(r.get("ok", false))))
	go.name = "AffairDo"
	v.add_child(go)
	if not bool(chk.get("ok", false)):
		var why := UIKit.body_label(str(chk.get("msg", "")), UIKit.TEXT_DIM, fs_dim)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if mobile:
			why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(why)
	_fill_specialty(v, mobile)
	var rows: Array = CKJobSeals.rows_for_city(city)
	if rows.is_empty():
		var empty := UIKit.body_label(Locale.t("js_76942d49"), UIKit.TEXT_DIM, fs_dim)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if mobile:
			empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(empty)
	for r in rows:
		var jid := str(r.get("job", ""))
		var seal_nm := str(r.get("name", jid))
		var from_nm := str(GameState.get_job(str(r.get("from", ""))).get("name", ""))
		var seal_lab := UIKit.body_label(Locale.t("js_76fd6d83") % [seal_nm, from_nm, seal_nm], UIKit.ACCENT, fs if mobile else 14)
		seal_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if mobile:
			seal_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(seal_lab)
		var any := false
		for c in GameState.roster():
			if c == null or not c.alive or c.job_id != str(r.get("from", "")):
				continue
			any = true
			var g: Dictionary = CKJobSeals.can_stamp(c, jid, city)
			var cid := str(c.id)
			if mobile:
				var b := MobilePage.button(Locale.t("js_f6db50d5") % c.name, false, func():
					var rr := CKJobSeals.stamp(GameState.characters[cid], jid, city)
					open_affairs(str(rr.get("msg", "")), bool(rr.get("ok", false))))
				b.name = "AffairSealBtn"
				b.disabled = not bool(g.get("ok", false))
				CKHeraldryField.attach_affairs_seal_arms(b, c, Vector2(28, 34))
				v.add_child(b)
				if not bool(g.get("ok", false)):
					var gm := UIKit.body_label(str(g.get("msg", "")), UIKit.TEXT_DIM, fs_dim)
					gm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					gm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					v.add_child(gm)
			else:
				var row := HBoxContainer.new()
				row.name = "AffairSealRow"
				row.add_theme_constant_override("separation", 8)
				CKHeraldryField.attach_affairs_seal_arms(row, c, Vector2(26, 32))
				var b2 := UIKit.ghost_button(Locale.t("js_f6db50d5") % c.name, 200, hit)
				b2.disabled = not bool(g.get("ok", false))
				b2.pressed.connect(func():
					var rr := CKJobSeals.stamp(GameState.characters[cid], jid, city)
					open_affairs(str(rr.get("msg", "")), bool(rr.get("ok", false))))
				row.add_child(b2)
				if not bool(g.get("ok", false)):
					row.add_child(UIKit.body_label(str(g.get("msg", "")), UIKit.TEXT_DIM, fs_dim))
				v.add_child(row)
		if not any:
			var none := UIKit.body_label(Locale.t("js_7a4485ae") % str(GameState.get_job(str(r.get("from", ""))).get("name", "")), UIKit.TEXT_DIM, fs_dim)
			none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if mobile:
				none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(none)


func _fill_specialty(v: VBoxContainer, mobile: bool) -> void:
	var fs := MobilePage.FONT if mobile else 15
	var fs_dim := MobilePage.FONT if mobile else 13
	var hit := int(MobilePage.HIT) if mobile else 48
	var card: Dictionary = CKCitySpecialty.card(city)
	var head := UIKit.body_label(str(card.get("head", "")), UIKit.ACCENT, fs)
	head.name = "SpecialtyHead"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if mobile:
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(head)
	var body := UIKit.body_label(str(card.get("body", "")), UIKit.TEXT, fs_dim)
	body.name = "SpecialtyBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if mobile:
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var cost := str(card.get("cost", ""))
	if cost != "":
		var cl := UIKit.body_label(cost, UIKit.TEXT, fs_dim)
		cl.name = "SpecialtyCost"
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if mobile:
			cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(cl)
	var pay := str(card.get("pay", ""))
	if pay != "":
		var pl := UIKit.body_label(pay, UIKit.OK, fs_dim)
		pl.name = "SpecialtyPay"
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if mobile:
			pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(pl)
	var hold := str(card.get("hold", ""))
	if hold != "":
		var hl := UIKit.body_label(hold, UIKit.TEXT_DIM, fs_dim)
		hl.name = "SpecialtyHold"
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if mobile:
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(hl)
	var go: Button
	if mobile:
		go = MobilePage.button(str(card.get("action", "")), true, _specialty_act)
	else:
		go = UIKit.ghost_button(str(card.get("action", "")), 220, hit)
		go.pressed.connect(_specialty_act)
	go.name = "SpecialtyDo"
	go.disabled = not bool(card.get("enabled", false))
	v.add_child(go)
	var why_txt := str(card.get("why", ""))
	if why_txt != "":
		var wl := UIKit.body_label(why_txt, UIKit.TEXT_DIM, fs_dim)
		wl.name = "SpecialtyWhy"
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if mobile:
			wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(wl)


func _specialty_act() -> void:
	var r := CKCitySpecialty.act(city)
	open_affairs(str(r.get("msg", "")), bool(r.get("ok", false)))
