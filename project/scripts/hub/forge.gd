extends Control
## v8.6 — layout-matched to Stitch 13_forge.png: top bar · OPERATIVE PROFILE + EQUIPMENT SLOTS (left) ·
## ARMAMENT REFORGING MATRIX current → next tier with stat deltas + material check + CTA (centre) ·
## DEPOT INVENTORY material grid + catalyst telemetry (right) · footer keycaps.

var _sel: CKCharacter
var _left: Control
var _mid: Control
var _right: Control
var _msg: Label
var _chips: Control

func _ready() -> void:
	UIKit.void_bg(self)
	_left = Control.new()
	_mid = Control.new()
	_right = Control.new()
	for n in [_left, _mid, _right]:
		n.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(n)
	var roster: Array = GameState.roster()
	if not roster.is_empty():
		_sel = roster[0]
	_render_all()
	UIKit.footer_bar(self, [["A", "确认打造"], ["↑↓", "切换骑士"], ["W", "去工事升级工坊"], ["ESC", "返回城堡"]], "FORGE FACILITY // LV %d · v8.6" % GameState.building_level("forge"))
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func apply_mobile_layout() -> void:
	var scroll := find_child("SmithListScroll", true, false) as ScrollContainer
	var foot := find_child("StitchFooter", true, false) as Control
	MobileLayout.fill_scroll(scroll, foot, 346)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()
	elif e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_W:
		get_tree().change_scene_to_file("res://scenes/hub/works.tscn")

func _clear(n: Control) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()

func _render_all() -> void:
	if _chips:
		_chips.queue_free()
	_chips = UIKit.top_bar(self, "炉火工坊 · FORGE", [["银币", str(GameState.silver), UIKit.ACCENT], ["铁", str(GameState.iron), UIKit.TEXT], ["工坊", "LV %d" % GameState.building_level("forge"), UIKit.OK], ["历", Calendar.label(), UIKit.TEXT_DIM]], "返回城堡", _back)
	_render_left()
	_render_mid()
	_render_right()
	if DeviceProfile.is_mobile() and is_inside_tree() and find_child("StitchFooter", true, false):
		apply_mobile_layout()

func _weapon_name(wid: String) -> String:
	if World.is_world_item(wid):
		return str(World.item(wid).get("name", wid))
	match wid:
		"ash_blade_fine":
			return "灰刃·精"
		"":
			return "制式长剑"
		_:
			return "灰刃"

func _wbonus(wid: String) -> int:
	if World.is_world_item(wid):
		return int(World.item(wid).get("stats", {}).get("atk", 0))
	return 3 if wid == "ash_blade_fine" else (0 if wid == "" else 2)

func _next_wid() -> String:
	return "ash_blade_fine" if GameState.building_level("forge") >= 4 else "ash_blade"

func _render_left() -> void:
	_clear(_left)
	UIKit.panel_at(_left, Rect2(24, 72, 360, 196), 10)
	UIKit.section_head(_left, Vector2(40, 86), "骑士档案", "OPERATIVE PROFILE", 328, "")
	if _sel:
		UIKit.portrait_plate(_left, Rect2(40, 114, 104, 136), _sel, "LV.%02d" % _sel.level, true)
		var nm := UIKit.title_label(_sel.name, 22)
		nm.position = Vector2(158, 112)
		_left.add_child(nm)
		var sub := UIKit.body_label("%s · %d 岁" % [GameState.get_job(_sel.job_id).get("name", ""), _sel.age], UIKit.TEXT_DIM, 12)
		sub.autowrap_mode = TextServer.AUTOWRAP_OFF
		sub.position = Vector2(158, 146)
		_left.add_child(sub)
		var g := GridContainer.new()
		g.columns = 2
		g.position = Vector2(158, 176)
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 8)
		_left.add_child(g)
		g.add_child(UIKit.stat_box("ATK", str(_sel.derived_atk()), UIKit.ACCENT))
		g.add_child(UIKit.stat_box("HIT", str(_sel.derived_hit()), UIKit.TEXT))
	UIKit.panel_at(_left, Rect2(24, 280, 360, 400), 10)
	UIKit.section_head(_left, Vector2(40, 294), "选择骑士", "EQUIPMENT SLOTS", 328, "[%d 名]" % GameState.roster().size())
	var scroll := ScrollContainer.new()
	scroll.name = "SmithListScroll"
	scroll.position = Vector2(36, 322)
	scroll.size = Vector2(336, 346)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)
	for c in GameState.roster():
		vb.add_child(_slot(c))

func _slot(c: CKCharacter) -> Button:
	var on := _sel == c
	var b := Button.new()
	var row_h := 58.0
	if DeviceProfile.is_mobile():
		row_h = maxf(row_h, DeviceProfile.hit_px())
	b.custom_minimum_size = Vector2(328, row_h)
	b.focus_mode = Control.FOCUS_ALL
	UIKit._apply_states(b, {
		"normal": UIKit.flat_box(Color(UIKit.ACCENT, 0.08) if on else Color(1, 1, 1, 0.02), Color(UIKit.ACCENT, 0.9) if on else Color(1, 1, 1, 0.10), 6, 2 if on else 1),
		"hover": UIKit.flat_box(Color(0.07, 0.09, 0.12, 0.95), Color(UIKit.ACCENT, 0.45), 6),
		"pressed": UIKit.flat_box(Color(UIKit.ACCENT, 0.12), Color(UIKit.ACCENT, 0.8), 6, 2),
		"focus": UIKit._focus_ring(UIKit.FOCUS_RING, 8),
		"disabled": UIKit.flat_box(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.05), 6),
	})
	b.pressed.connect(func():
		_sel = c
		_render_all())
	var pr := UIKit.make_portrait_rect(c, 40)
	pr.position = Vector2(9, 9)
	pr.custom_minimum_size = Vector2(40, 40)
	pr.size = Vector2(40, 40)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pr)
	var h := HBoxContainer.new()
	h.position = Vector2(60, 8)
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.add_child(UIKit.title_label(c.name, 14))
	if c.weapon_id != "":
		h.add_child(UIKit.tag_chip("+%d" % _wbonus(c.weapon_id), UIKit.OK))
	var w := UIKit.body_label("%s · 攻 %d" % [_weapon_name(c.weapon_id), c.derived_atk()], UIKit.TEXT_FAINT, 11)
	w.autowrap_mode = TextServer.AUTOWRAP_OFF
	w.position = Vector2(60, 32)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(w)
	if on:
		var t := UIKit.tag_chip("TARGET", UIKit.ACCENT, true)
		t.position = Vector2(258, 18)
		b.add_child(t)
	return b

func _render_mid() -> void:
	_clear(_mid)
	UIKit.panel_at(_mid, Rect2(396, 72, 488, 608), 10)
	UIKit.section_head(_mid, Vector2(414, 86), "武器锻造推演", "ARMAMENT REFORGING MATRIX", 452, "FORGE LV %d" % GameState.building_level("forge"))
	if _sel == null:
		return
	var cur := _sel.weapon_id
	var nxt := _next_wid()
	var cb := _wbonus(cur)
	var nb := _wbonus(nxt)
	var same := cur == nxt
	# current → next tier cards
	_tier_card(Rect2(430, 142, 170, 128), "CURRENT // 当前阶位", "+%d" % cb, _weapon_name(cur), "ATK %d" % _sel.derived_atk(), false)
	var arrow := UIKit.mono("→", 22, UIKit.ACCENT, false)
	arrow.position = Vector2(628, 186)
	_mid.add_child(arrow)
	var rs := UIKit.mono("REFORGE", 8, UIKit.TEXT_FAINT, false)
	rs.position = Vector2(618, 218)
	_mid.add_child(rs)
	_tier_card(Rect2(680, 142, 170, 128), "NEXT TIER // 打造后", "+%d" % nb, _weapon_name(nxt), "ATK %d" % (_sel.derived_atk() - cb + nb), true)
	# stat delta strip
	var strip := UIKit.panel_at(_mid, Rect2(414, 290, 452, 64), 8)
	strip.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.08), 8))
	var hb := HBoxContainer.new()
	hb.position = Vector2(430, 300)
	hb.add_theme_constant_override("separation", 34)
	_mid.add_child(hb)
	var atk0 := _sel.derived_atk()
	var atk1 := atk0 - cb + nb
	hb.add_child(_delta("基础物攻 ATK", atk0, atk1))
	hb.add_child(_delta("命中 HIT", _sel.derived_hit(), _sel.derived_hit()))
	hb.add_child(_delta("暴击 CRIT", _sel.derived_crit(), _sel.derived_crit()))
	# success / material check
	var cost: Dictionary = GameState.forge_craft_cost()
	var ok_iron := GameState.iron >= int(cost.iron)
	var ok_silver := GameState.silver >= int(cost.silver)
	var sh := HBoxContainer.new()
	sh.position = Vector2(414, 374)
	sh.add_theme_constant_override("separation", 10)
	_mid.add_child(sh)
	sh.add_child(UIKit.title_label("打造成功率 100%", 13, UIKit.TEXT))
	sh.add_child(UIKit.tag_chip("炉火稳定" if not same else "已是当前最高阶", UIKit.OK if not same else UIKit.TEXT_DIM))
	var bar := UIKit.slim_bar(100, 100, UIKit.ACCENT, 452, 3)
	bar.position = Vector2(414, 402)
	_mid.add_child(bar)
	_mat(Rect2(414, 418, 220, 56), "铁 IRON", "需求 %d / 持有 %d" % [cost.iron, GameState.iron], ok_iron)
	_mat(Rect2(646, 418, 220, 56), "银币 SILVER", "需求 %d / 持有 %d" % [cost.silver, GameState.silver], ok_silver)
	var hint := UIKit.body_label("工坊 Lv4 起打造「灰刃·精」(+3)。三柄精刃满匣可达成堡志。" if GameState.building_level("forge") < 4 else "工坊已达 Lv4：打造「灰刃·精」(+3)。三柄精刃满匣可达成堡志。", UIKit.TEXT_DIM, 12)
	hint.position = Vector2(414, 490)
	hint.size = Vector2(452, 40)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mid.add_child(hint)
	_msg = UIKit.body_label("", UIKit.OK, 13)
	_msg.position = Vector2(414, 540)
	_msg.size = Vector2(452, 20)
	_mid.add_child(_msg)
	var works := UIKit.ghost_button("升级工坊  [W]", 150, 44)
	works.position = Vector2(414, 620)
	works.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/works.tscn"))
	_mid.add_child(works)
	var go := UIKit.cta_button("确认打造", "A", 220, 44)
	go.position = Vector2(646, 620)
	go.disabled = not (ok_iron and ok_silver) or same
	go.tooltip_text = "已装备同阶武器" if same else ("材料不足" if go.disabled else "为 %s 打造 %s" % [_sel.name, _weapon_name(nxt)])
	var cid := _sel.id
	go.pressed.connect(func():
		var r: Dictionary = GameState.craft_weapon(cid)
		var m := str(r.get("msg"))
		_render_all()
		_msg.text = m
		_msg.add_theme_color_override("font_color", UIKit.OK if bool(r.get("ok")) else UIKit.DANGER))
	_mid.add_child(go)
	if not go.disabled:
		go.call_deferred("grab_focus")

func _tier_card(r: Rect2, eyebrow: String, big: String, wname: String, stat: String, focus: bool) -> void:
	UIKit.panel_at(_mid, r, 8, focus)
	var e := UIKit.mono(eyebrow, 8, UIKit.ACCENT if focus else UIKit.TEXT_FAINT, false)
	e.position = r.position + Vector2((r.size.x - e.get_minimum_size().x) * 0.5, 14)
	_mid.add_child(e)
	var b := UIKit.mono(big, 30, UIKit.ACCENT if focus else UIKit.TEXT, false)
	b.position = r.position + Vector2((r.size.x - b.get_minimum_size().x) * 0.5, 32)
	_mid.add_child(b)
	var n := UIKit.title_label(wname, 13, UIKit.ACCENT if focus else UIKit.TEXT_DIM)
	n.position = r.position + Vector2((r.size.x - n.get_minimum_size().x) * 0.5, 78)
	_mid.add_child(n)
	var s := UIKit.mono(stat, 9, UIKit.TEXT_FAINT, false)
	s.position = r.position + Vector2((r.size.x - s.get_minimum_size().x) * 0.5, 102)
	_mid.add_child(s)

func _delta(label: String, a: int, b: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var lb := UIKit.body_label(label, UIKit.TEXT_FAINT, 11)
	lb.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(lb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	h.add_child(UIKit.mono("%d → %d" % [a, b], 15, UIKit.TEXT, false))
	if b != a:
		h.add_child(UIKit.tag_chip("%+d" % (b - a), UIKit.OK))
	return v

func _mat(r: Rect2, name_: String, line: String, ok: bool) -> void:
	var p := UIKit.panel_at(_mid, r, 6)
	p.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.02), Color(UIKit.OK if ok else UIKit.DANGER, 0.35), 6))
	var n := UIKit.title_label(name_, 13, UIKit.TEXT)
	n.position = r.position + Vector2(14, 8)
	_mid.add_child(n)
	var l := UIKit.body_label(line, UIKit.TEXT_FAINT, 11)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.position = r.position + Vector2(14, 31)
	_mid.add_child(l)
	var t := UIKit.tag_chip("满足" if ok else "不足", UIKit.OK if ok else UIKit.DANGER)
	t.position = r.position + Vector2(r.size.x - 50, 18)
	_mid.add_child(t)

func _render_right() -> void:
	_clear(_right)
	UIKit.panel_at(_right, Rect2(896, 72, 360, 400), 10)
	UIKit.section_head(_right, Vector2(912, 86), "冶炼素材仓储", "DEPOT INVENTORY", 328, "")
	var g := GridContainer.new()
	g.columns = 2
	g.position = Vector2(912, 118)
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	_right.add_child(g)
	var items := [["铁", "IRON · 锻造主料", GameState.iron, UIKit.ACCENT], ["银币", "SILVER · 工钱", GameState.silver, UIKit.ACCENT], ["粮", "FOOD · 军需", GameState.food, UIKit.TEXT], ["士气", "MORALE · 炉火映旗", GameState.morale, UIKit.OK]]
	for it in items:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(160, 64)
		p.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.09), 6))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		p.add_child(v)
		var h := HBoxContainer.new()
		v.add_child(h)
		var n := UIKit.title_label(str(it[0]), 13, UIKit.TEXT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(UIKit.mono("×%d" % int(it[2]), 13, it[3], false))
		v.add_child(UIKit.mono(str(it[1]), 8, UIKit.TEXT_FAINT, false))
		g.add_child(p)
	var eq := 0
	for c in GameState.roster():
		if c.weapon_id != "":
			eq += 1
	var kv := VBoxContainer.new()
	kv.position = Vector2(912, 296)
	kv.add_theme_constant_override("separation", 8)
	_right.add_child(kv)
	kv.add_child(UIKit.kv_row("已配灰刃", "%d / %d" % [eq, GameState.roster().size()], UIKit.ACCENT, 328))
	kv.add_child(UIKit.kv_row("当前打造", _weapon_name(_next_wid()), UIKit.TEXT, 328))
	kv.add_child(UIKit.kv_row("单次耗材", "%d 铁 + %d 银" % [GameState.forge_craft_cost().iron, GameState.forge_craft_cost().silver], UIKit.TEXT_DIM, 328))
	UIKit.panel_at(_right, Rect2(896, 484, 360, 196), 10)
	UIKit.section_head(_right, Vector2(912, 498), "传家器预告", "CATALYST TELEMETRY", 328, "")
	var heir := UIKit.body_label(Locale.t("heirloom_preview"), UIKit.TEXT_DIM, 12)
	heir.position = Vector2(912, 526)
	heir.size = Vector2(328, 100)
	heir.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right.add_child(heir)
	var foot := UIKit.mono("工坊等级 LV %d · 上限随议事厅" % GameState.building_level("forge"), 9, UIKit.TEXT_FAINT, false)
	foot.position = Vector2(912, 650)
	_right.add_child(foot)
