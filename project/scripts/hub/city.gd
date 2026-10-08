extends Control
## v8.7 城镇 — every settlement on the atlas opens here. Tabs:
## 概览 (rep ladder · turn-ins · intel) · 铁匠铺 (regional line + signature arms, buy / forge with materials)
## 市集 (regional goods, supply-driven prices, known best sell elsewhere) · 委托榜 (city board, accept / turn in)
## 酒馆 (regional-blood recruits) · 军械库 (equip world arms on the roster, live stat compare)

const _Atlas = preload("res://scripts/art/atlas_art.gd")
const ATLAS := "res://scenes/hub/atlas_view.tscn"
const TABS := [["overview", "概览"], ["smith", "铁匠铺"], ["market", "市集"], ["board", "委托榜"], ["tavern", "酒馆"], ["armory", "军械库"], ["lamp", "灯籍"]]
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

func _ready() -> void:
	city = str(GameState.get_meta("city_id", World.pos)) if GameState.has_meta("city_id") else World.pos
	if not World.nodes.has(city) or city != World.pos:
		city = World.pos
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
	for t in TABS:
		var b := UIKit.ghost_button(str(t[1]), 108, 34)
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
	_toast = UIKit.body_label("", UIKit.TEXT, 12)
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
	UIKit.footer_bar(self, [["Q/E", "切换页签"], ["A", "选择 / 确认"], ["ESC", "返回舆图"]], "SETTLEMENT · FROST_TACTICAL v8.7")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

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
	UIKit.top_bar(_top, "%s · %s" % [World.kind_zh(city), n.get("name", city)], [
		["银", str(GameState.silver), UIKit.ACCENT],
		["粮", str(GameState.food), UIKit.TEXT],
		["铁", str(GameState.iron), UIKit.TEXT],
		["货舱", "%d/%d" % [World.cargo_used(), World.cargo_cap()], UIKit.TEXT],
		["历", World.date_label(), UIKit.TEXT_DIM],
	], "返回舆图", _back)

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
	var eb := UIKit.mono("%s // %s" % [str(nat.get("en", "")), World.kind_zh(city)], 9, UIKit.ACCENT)
	eb.position = Vector2(18, 150)
	p.add_child(eb)
	var t := UIKit.title_label(str(n.get("name", city)), 26)
	t.position = Vector2(18, 166)
	p.add_child(t)
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
	lore.size = Vector2(348, 90)
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
	var back := UIKit.cta_button("返回舆图", "ESC", 348, 40)
	back.name = "BackToAtlas"
	back.position = Vector2(18, 566)
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
	_render_tab()

func _render_tab() -> void:
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
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match tab:
		"overview": _tab_overview()
		"smith": _tab_smith()
		"market": _tab_market()
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
	var e := UIKit.mono(en, 9, UIKit.ACCENT)
	e.position = pos
	p.add_child(e)
	var t := UIKit.title_label(zh, 17)
	t.position = pos + Vector2(0, 14)
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
	var p := _panel(Rect2(0, 0, 420, 576))
	_head(p, Vector2(18, 14), "声望阶梯", "REPUTATION LADDER")
	var tiers: Array = World.rules.get("rep_tiers", [0, 10, 30, 55, 80])
	var names: Array = World.REP_TIER_ZH
	var unlocks: Array = World.CITY_UNLOCKS
	var rep := World.rep_of(city)
	var v := VBoxContainer.new()
	v.position = Vector2(18, 56)
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	for i in tiers.size():
		var reached := rep >= int(tiers[i])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var chip := UIKit.tag_chip("%s %d" % [names[i] if i < names.size() else "", int(tiers[i])], UIKit.ACCENT if reached else UIKit.TEXT_FAINT, reached)
		chip.custom_minimum_size = Vector2(76, 0)
		row.add_child(chip)
		row.add_child(_para(str(unlocks[i]) if i < unlocks.size() else "", UIKit.TEXT if reached else UIKit.TEXT_FAINT, 12, 300))
		v.add_child(row)
	var nid := str(n.get("nation", ""))
	var nrep := World.nation_rep(nid)
	var nt := World.rep_tier_index(nrep)
	var nl := UIKit.mono("NATION %s · %d · %s" % [str(World.nations.get(nid, {}).get("en", "")), nrep, World.rep_tier_name(nrep)], 9, UIKit.ACCENT)
	nl.position = Vector2(18, 232)
	p.add_child(nl)
	var nx := _para("当前：%s\n下一阶：%s" % [World.NATION_UNLOCKS[nt], World.NATION_UNLOCKS[mini(nt + 1, 4)] if nt < 4 else "已达最高"], UIKit.TEXT_DIM, 11, 384)
	nx.position = Vector2(18, 250)
	p.add_child(nx)
	var sq: Dictionary = n.get("sig_quest", {})
	if not sq.is_empty():
		var sl := UIKit.mono("HONOUR COMMISSION", 9, UIKit.EMBER)
		sl.position = Vector2(18, 330)
		p.add_child(sl)
		var st := UIKit.title_label("「%s」" % sq.get("title", ""), 15, UIKit.TEXT)
		st.position = Vector2(18, 346)
		p.add_child(st)
		var sb := _para(str(sq.get("brief", "")), UIKit.TEXT_DIM, 12, 384)
		sb.position = Vector2(18, 372)
		p.add_child(sb)
		var done := World.done_sig.has(str(sq.get("id", "")))
		var running := not World.quest_by_id(str(sq.get("id", ""))).is_empty()
		var stxt := "已完成 · 传奇兵器已解锁" if done else ("进行中 · 完成后解锁传奇兵器" if running else "声望「友善」(30) 后出现在委托榜")
		var sst := UIKit.tag_chip(stxt, UIKit.OK if done else (UIKit.ACCENT if running else UIKit.TEXT_DIM), done)
		sst.position = Vector2(18, 440)
		p.add_child(sst)
	var p2 := _panel(Rect2(432, 0, 416, 576))
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
		v2.add_child(_para("没有可在此交付的委托。递送 / 护送 / 防守在目标地交付；追缉 / 清剿 / 收购 / 探查回发布城复命。", UIKit.TEXT_FAINT, 12, 370))
	var il := UIKit.mono("TRADE INTEL", 9, UIKit.ACCENT)
	il.position = Vector2(18, 304)
	p2.add_child(il)
	var v3 := VBoxContainer.new()
	v3.position = Vector2(18, 322)
	v3.add_theme_constant_override("separation", 4)
	p2.add_child(v3)
	for g in n.get("produce", []):
		var best: Dictionary = World.best_known_sell(str(g), city)
		var here := World.price(city, str(g), "buy")
		var txt := "%s：本地 %d 银买入" % [World.good_name(str(g)), here]
		if str(best.get("city", "")) != "":
			txt += " → %s 卖 %d（%+d）" % [World.node(str(best.city)).get("name", ""), int(best.price), int(best.price) - here]
		else:
			txt += " → 暂无他处行情（到访或打听后可见）"
		v3.add_child(_line(txt, UIKit.TEXT_DIM, 12, 380))
	for t in World.tips.slice(0, 3):
		v3.add_child(_line("情报：%s" % str(t), UIKit.ACCENT, 11, 380))
	var mm: Dictionary = World.mainline_marker()
	if str(mm.get("node", "")) == city:
		var mb := UIKit.cta_button("★ %s" % mm.label, "", 380, 38)
		mb.position = Vector2(18, 520)
		mb.disabled = not bool(mm.get("exists", false))
		mb.pressed.connect(func(): get_tree().change_scene_to_file(str(mm.path)))
		p2.add_child(mb)

# ── 铁匠铺 ────────────────────────────────────────────
func _tab_smith() -> void:
	var sp := AtlasArt.smith_plate(World.nation_of(city))
	if sp != "":
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
	var cap := UIKit.mono("货舱 %d/%d   ·   粮/铁/药材直接入库，不占货舱" % [World.cargo_used(), World.cargo_cap()], 9, UIKit.TEXT_DIM, false)
	cap.position = Vector2(420, 20)
	p.add_child(cap)
	var hdr := HBoxContainer.new()
	hdr.position = Vector2(18, 56)
	hdr.add_theme_constant_override("separation", 0)
	p.add_child(hdr)
	for h in [["货物", 130], ["存货", 54], ["买价", 60], ["卖价", 60], ["持有", 54], ["已知最佳卖处", 230], ["", 230]]:
		var l := UIKit.mono(str(h[0]), 9, UIKit.TEXT_FAINT, false)
		l.custom_minimum_size = Vector2(int(h[1]), 0)
		hdr.add_child(l)
	var v := _scroll(p, Rect2(12, 76, 830, 490))
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
		var nm := _line(World.good_name(gs) + tag, col, 13, 130)
		row.add_child(nm)
		row.add_child(_line(str(World.stock(city, gs)), UIKit.TEXT_DIM, 12, 54))
		var bp := World.price(city, gs, "buy")
		var sp := World.price(city, gs, "sell")
		row.add_child(_line(str(bp), UIKit.TEXT, 13, 60))
		row.add_child(_line(str(sp), UIKit.TEXT, 13, 60))
		var have := World.have_good(gs)
		row.add_child(_line(str(have), UIKit.ACCENT if have > 0 else UIKit.TEXT_FAINT, 13, 54))
		var best: Dictionary = World.best_known_sell(gs, city)
		var bt := "—"
		var bcol := UIKit.TEXT_FAINT
		if str(best.get("city", "")) != "":
			var margin := int(best.price) - bp
			bt = "%s %d（%+d）" % [World.node(str(best.city)).get("name", ""), int(best.price), margin]
			bcol = UIKit.OK if margin > 0 else UIKit.TEXT_DIM
		row.add_child(_line(bt, bcol, 12, 230))
		var acts := HBoxContainer.new()
		acts.add_theme_constant_override("separation", 4)
		for a in [["买1", 1, true], ["买5", 5, true], ["卖1", 1, false], ["卖全", -1, false]]:
			var qty := int(a[1])
			var is_buy := bool(a[2])
			var q2 := qty if qty > 0 else have
			var b := UIKit.ghost_button(str(a[0]), 52, 28)
			b.name = "Mkt_%s_%s" % [gs, str(a[0])]
			if is_buy:
				b.disabled = World.stock(city, gs) < q2 or GameState.silver < World.quote_buy(city, gs, q2) or (str(World.goods[gs].get("store", "")) == "" and World.cargo_used() + q2 > World.cargo_cap())
				b.tooltip_text = "共 %d 银" % World.quote_buy(city, gs, q2)
				b.pressed.connect(func(): _do(World.market_buy(city, gs, q2)))
			else:
				b.disabled = have <= 0 or q2 <= 0
				b.tooltip_text = "共 %d 银" % World.quote_sell(city, gs, maxi(1, q2))
				b.pressed.connect(func(): _do(World.market_sell(city, gs, q2)))
			acts.add_child(b)
		row.add_child(acts)
		v.add_child(row)

# ── 委托榜 ────────────────────────────────────────────
func _tab_board() -> void:
	var offers: Array = World.board(city)
	var p := _panel(Rect2(0, 0, 420, 576))
	_head(p, Vector2(18, 14), "委托榜", "COMMISSION BOARD · REFRESH %d 日" % int(World.rules.get("board_refresh_days", 30)))
	var fh := HBoxContainer.new()
	fh.position = Vector2(250, 14)
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
		var qid := str(q.id)
		b.pressed.connect(func(): _sel_quest = qid; _render_tab())
		v.add_child(b)
	if shown.is_empty() and not offers.is_empty():
		v.add_child(_para("此筛选下没有委托。", UIKit.TEXT_FAINT, 12, 380))
	if offers.is_empty():
		v.add_child(_para("榜上暂无委托——%d 日后刷新。" % (int(World.rules.get("board_refresh_days", 30)) - World.days_total % int(World.rules.get("board_refresh_days", 30))), UIKit.TEXT_FAINT, 12, 380))
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
	var t := _para(str(sel.title), UIKit.TEXT, 19, 380)
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
		ab.pressed.connect(func(): _do(World.accept_quest(city, sid)); _sel_quest = sid)
		d.add_child(ab)
		if why != "":
			var wl := _para("🔒 " + why, UIKit.EMBER, 12, 380)
			wl.position = Vector2(18, 524)
			d.add_child(wl)
	else:
		var tb := UIKit.cta_button("交付", "A", 240, 44)
		tb.name = "TurnInQuest"
		tb.position = Vector2(18, 470)
		tb.disabled = not World.can_turn_in(sel, city)
		var sid2 := str(sel.id)
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
		hb.pressed.connect(func(): _do(World.hire(city, idx)))
		card.add_child(hb)

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
	al.position = Vector2(18, 236)
	d.add_child(al)
	var v2 := _scroll(d, Rect2(12, 254, 518, 314))
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

func _back() -> void:
	UIFX.page_exit(self)
	get_tree().change_scene_to_file(ATLAS)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		if k == KEY_Q or k == KEY_E:
			var ids: Array = []
			for t in TABS:
				if not (_tab_btn[str(t[0])] as Button).disabled:
					ids.append(str(t[0]))
			var i := ids.find(tab)
			_set_tab(str(ids[(i + (1 if k == KEY_E else -1) + ids.size()) % ids.size()]))

# ── e2e hook ──────────────────────────────────────────
func selftest() -> Dictionary:
	var msgs: Array = []
	for t in TABS:
		if (_tab_btn[str(t[0])] as Button).disabled:
			continue
		_set_tab(str(t[0]))
		await get_tree().process_frame
		if _body.get_child_count() == 0:
			return {"ok": false, "msg": "tab %s empty" % t[0]}
	msgs.append("tabs ok")
	# smith: buy the first available item through the detail button
	_set_tab("smith")
	await get_tree().process_frame
	var buy := _body.find_child("BuyItem", true, false) as Button
	if buy == null:
		return {"ok": false, "msg": "no BuyItem"}
	var arm0 := _armory_count()
	GameState.silver += 2000
	_render_tab()
	await get_tree().process_frame
	buy = _body.find_child("BuyItem", true, false) as Button
	if buy.disabled:
		for e in World.smith_stock(city):
			if bool(e.available):
				_sel_item = str(e.item.id)
				break
		_render_tab()
		await get_tree().process_frame
		buy = _body.find_child("BuyItem", true, false) as Button
	buy.pressed.emit()
	await get_tree().process_frame
	if _armory_count() != arm0 + 1:
		return {"ok": false, "msg": "smith buy via UI failed"}
	msgs.append("smith buy")
	# market: buy 1 of the first produced good
	_set_tab("market")
	await get_tree().process_frame
	var g := str(World.node(city).get("produce", ["grain"])[0])
	var mb := _body.find_child("Mkt_%s_买1" % g, true, false) as Button
	if mb == null or mb.disabled:
		return {"ok": false, "msg": "market buy button missing/disabled for " + g}
	var h0 := World.have_good(g)
	mb.pressed.emit()
	await get_tree().process_frame
	if World.have_good(g) != h0 + 1:
		return {"ok": false, "msg": "market buy via UI failed"}
	msgs.append("market buy")
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
