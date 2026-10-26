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


func _place_forge_crests() -> void:
	## Forge chrome: 团徽 header + banner strip + Field focus (团徽+选中铁匠 族徽|旗徽).
	var mob := DeviceProfile.is_mobile()
	var hdr := Vector2(44, 52) if not mob else Vector2(40, 48)
	CKHeraldryChrome.place_company_header(self, Vector2(1180, 8) if not mob else Vector2(1180, 4), hdr)
	CKHeraldryChrome.place_castle_banner_strip(self, Vector2(1120, 8) if not mob else Vector2(1120, 4), hdr, Vector2(28, 38))
	var shield := Vector2(36, 44) if not mob else Vector2(32, 38)
	var strip_w := shield.x if _sel == null else shield.x * 2.0 + 8.0
	var at := Vector2(980, 10) if not mob else Vector2(maxf(8.0, size.x - strip_w - 200.0), 6.0)
	var bar := find_child("MobileTopBar", true, false)
	if mob and bar != null:
		CKHeraldryField.place_forge_focus_strip(bar, _sel, Vector2(8, 6), shield)
	else:
		CKHeraldryField.place_forge_focus_strip(self, _sel, at, shield)

func apply_mobile_layout() -> void:
	if MobilePage.active(self):
		_m_render_all()
		return
	var scroll := find_child("SmithListScroll", true, false) as ScrollContainer
	var foot := find_child("StitchFooter", true, false) as Control
	MobileLayout.fill_scroll(scroll, foot, 346)

func _back() -> void:
	CKNav.up()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()
	elif e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_W:
		CKNav.go("res://scenes/hub/works.tscn")

func _clear(n: Control) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()

func _render_all() -> void:
	if MobilePage.active(self):
		_m_render_all()
		return
	if _chips:
		_chips.queue_free()
	_chips = UIKit.top_bar(self, "炉火工坊 · FORGE", [["银币", str(GameState.silver), UIKit.ACCENT], ["铁", str(GameState.iron), UIKit.TEXT], ["工坊",
			"LV %d" % GameState.building_level("forge"), UIKit.OK], ["历", Calendar.label(), UIKit.TEXT_DIM]], "返回城堡", _back)
	_place_forge_crests()
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
	b.name = "ForgeKnight_" + str(c.id)
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
	CKHeraldryField.attach_forge_slot_arms(b, c, Vector2(24, 30))
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
		var el := UIKit.body_label(Locale.t("wsc_f_empty"), UIKit.TEXT_DIM, 14)
		el.name = "ForgeEmpty"
		el.position = Vector2(414, 140)
		el.size = Vector2(452, 80)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_mid.add_child(el)
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
	# WS-C #39: upgrade the forge right here instead of bouncing to 工事
	var flv := GameState.building_level("forge")
	var fcost: Dictionary = CKEconomyState.BUILDING_COST.get(flv + 1, {})
	var wlabel := Locale.t("wsc_f_maxed") if flv >= CKEconomyState.BUILDING_MAX else Locale.t("wsc_f_up") % [flv + 1, int(fcost.get("silver", 0)), int(fcost.get("iron", 0))]
	var works := UIKit.ghost_button(wlabel, 220, 44)
	works.name = "ForgeUpgrade"
	works.position = Vector2(414, 620)
	works.disabled = flv >= CKEconomyState.BUILDING_MAX
	works.pressed.connect(upgrade_forge)
	_mid.add_child(works)
	var go := UIKit.cta_button("确认打造", "A", 220, 44)
	go.name = "ForgeCraft"
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

func upgrade_forge() -> void:
	var r: Dictionary = GameState.upgrade_building("forge")
	_render_all()
	var ok := bool(r.get("ok", false))
	_msg.text = (Locale.t("wsc_f_up_ok") % GameState.building_level("forge")) if ok else str(r.get("msg", ""))
	_msg.add_theme_color_override("font_color", UIKit.OK if ok else UIKit.DANGER)
	if ok:
		GameState.save_game()

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
	var items := [["铁", "IRON · 锻造主料", GameState.iron, UIKit.ACCENT], ["银币", "SILVER · 工钱", GameState.silver, UIKit.ACCENT], ["粮", "FOOD · 军需", GameState.food,
			UIKit.TEXT], ["士气", "MORALE · 炉火映旗", GameState.morale, UIKit.OK]]
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
	var mod := UIKit.ghost_button(Locale.t("forge_modify"), 160, 36)
	mod.position = Vector2(912, 600)
	mod.pressed.connect(func():
		if _sel == null:
			return
		var r: Dictionary = CKHeirloom.try_modify(GameState, _sel.id)
		_msg.text = str(r.get("msg", ""))
		_render_all())
	_right.add_child(mod)
	var vault := UIKit.ghost_button(Locale.t("heirloom_store"), 140, 36)
	vault.position = Vector2(1088, 600)
	vault.pressed.connect(func():
		if _sel == null:
			return
		var r: Dictionary = CKHeirloom.store(GameState, _sel.id)
		_msg.text = str(r.get("msg", ""))
		_render_all())
	_right.add_child(vault)
	heir.position = Vector2(912, 526)
	heir.size = Vector2(328, 68)
	heir.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right.add_child(heir)
	var foot := UIKit.mono("工坊等级 LV %d · 上限随议事厅" % GameState.building_level("forge"), 9, UIKit.TEXT_FAINT, false)
	foot.position = Vector2(912, 644)
	_right.add_child(foot)


## ── Phone landscape: knights (left) · reforge preview + craft (centre) · depot + heirloom (right) ──
func _m_render_all() -> void:
	for nm in ["MobileTopBar", "StitchTopBar", "StitchFooter"]:
		var n := get_node_or_null(nm)
		if n:
			remove_child(n)
			n.queue_free()
	if _chips and is_instance_valid(_chips):
		_chips.queue_free()
	_chips = null
	for n in [_left, _mid, _right]:
		_clear(n)
	var w := MobilePage.width(self)
	var h := size.y if size.y > 400.0 else 720.0
	var flv := GameState.building_level("forge")
	MobilePage.top_bar(self, Locale.t("mw_897be971"), Locale.t("mw_ac33f494") % [GameState.silver, GameState.iron, flv, Calendar.label()], [[Locale.t("btn_back"), _back]])
	_place_forge_crests()
	var top := MobilePage.TOP
	var bh := h - top - 16.0
	var lw := clampf(w * 0.24, 300.0, 380.0)
	var rw := clampf(w * 0.26, 320.0, 400.0)
	var mw := w - 40.0 - lw - rw - 24.0
	# knights
	var lv := MobilePage.panel(_left, Rect2(20, top, lw, bh), 10)
	lv.add_child(MobilePage.label(Locale.t("mw_fe82b96f") % GameState.roster().size(), UIKit.ACCENT, 24, false))
	var sc := ScrollContainer.new()
	sc.name = "SmithListScroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	sc.add_child(vb)
	for c in GameState.roster():
		var on: bool = _sel == c
		var b := MobilePage.button(Locale.t("mw_5cda7737") % [c.name, _weapon_name(c.weapon_id), c.derived_atk()], on, func():
			_sel = c
			_m_render_all())
		b.name = "ForgeKnight_" + str(c.id)
		b.custom_minimum_size = Vector2(0, 100)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pr := UIKit.make_portrait_rect(c, 72)
		pr.position = Vector2(12, 14)
		pr.size = Vector2(72, 72)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pr)
		CKHeraldryField.attach_forge_slot_arms(b, c, Vector2(28, 34))
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := b.get_theme_stylebox(st)
			if sb:
				var d := sb.duplicate()
				d.content_margin_left = 96
				b.add_theme_stylebox_override(st, d)
		vb.add_child(b)
	# centre
	var mv := MobilePage.panel(_mid, Rect2(20 + lw + 12, top, mw, bh), 14)
	mv.add_theme_constant_override("separation", 12)
	if _sel == null:
		var el := MobilePage.label(Locale.t("wsc_f_empty"), UIKit.TEXT_DIM, MobilePage.FONT, true)
		el.name = "ForgeEmpty"
		mv.add_child(el)
		_msg = MobilePage.label("", UIKit.OK, MobilePage.FONT, true)
		mv.add_child(_msg)
		_m_right(rw, w, top, bh)
		return
	var cur := _sel.weapon_id
	var nxt := _next_wid()
	var cb := _wbonus(cur)
	var nb := _wbonus(nxt)
	var same := cur == nxt
	var atk0 := _sel.derived_atk()
	var atk1 := atk0 - cb + nb
	mv.add_child(MobilePage.label(Locale.t("mw_35c262dc") % _sel.name, UIKit.TEXT, 26, false))
	var tiers := HBoxContainer.new()
	tiers.add_theme_constant_override("separation", 12)
	mv.add_child(tiers)
	for spec in [[Locale.t("mw_48ac4797"), "+%d" % cb, _weapon_name(cur), Locale.t("mw_c7b9ef3a") % atk0, false], [Locale.t("mw_199dfef6"), "+%d" % nb, _weapon_name(nxt),
			Locale.t("mw_c7b9ef3a") % atk1, true]]:
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := UIKit.flat_box(Color(UIKit.ACCENT, 0.08) if spec[4] else Color(1, 1, 1, 0.03), Color(UIKit.ACCENT, 0.8) if spec[4] else Color(1, 1, 1, 0.10), 10,
				2 if spec[4] else 1)
		for side in ["left", "right", "top", "bottom"]:
			sb.set("content_margin_" + side, 12)
		p.add_theme_stylebox_override("panel", sb)
		tiers.add_child(p)
		var tv := VBoxContainer.new()
		p.add_child(tv)
		var col: Color = UIKit.ACCENT if spec[4] else UIKit.TEXT
		tv.add_child(MobilePage.label(str(spec[0]), UIKit.TEXT_FAINT, MobilePage.FONT, false))
		tv.add_child(MobilePage.label("%s  %s" % [spec[1], spec[2]], col, 30, false))
		tv.add_child(MobilePage.label(str(spec[3]), UIKit.TEXT_DIM, MobilePage.FONT, false))
	var cost: Dictionary = GameState.forge_craft_cost()
	var ok_iron := GameState.iron >= int(cost.iron)
	var ok_silver := GameState.silver >= int(cost.silver)
	mv.add_child(MobilePage.label(Locale.t("mw_382b1167") % [atk0, atk1, _sel.derived_hit(), _sel.derived_crit()], UIKit.OK if atk1 > atk0 else UIKit.TEXT_DIM,
			MobilePage.FONT, true))
	mv.add_child(MobilePage.label(Locale.t("mw_e0de40ca") % [cost.iron, GameState.iron, "✓" if ok_iron else "!", cost.silver, GameState.silver,
			"✓" if ok_silver else "!"], UIKit.TEXT if ok_iron and ok_silver else UIKit.DANGER, MobilePage.FONT, true))
	mv.add_child(MobilePage.label(Locale.t("mw_0ddf557e") if flv < 4 else Locale.t("mw_2f47eea1"), UIKit.TEXT_FAINT, MobilePage.FONT, true))
	_msg = MobilePage.label("", UIKit.OK, MobilePage.FONT, true)
	mv.add_child(_msg)
	MobilePage.spacer(mv)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	mv.add_child(row)
	var fcost: Dictionary = CKEconomyState.BUILDING_COST.get(flv + 1, {})
	var wlabel := Locale.t("wsc_f_maxed") if flv >= CKEconomyState.BUILDING_MAX else Locale.t("wsc_f_up") % [flv + 1, int(fcost.get("silver", 0)), int(fcost.get("iron", 0))]
	var works := MobilePage.button(wlabel, false, upgrade_forge)
	works.name = "ForgeUpgrade"
	works.disabled = flv >= CKEconomyState.BUILDING_MAX
	row.add_child(works)
	var cid := _sel.id
	var go := MobilePage.button(Locale.t("mw_e536313c"), true, func():
		var r: Dictionary = GameState.craft_weapon(cid)
		var m := str(r.get("msg"))
		_m_render_all()
		_msg.text = m
		_msg.add_theme_color_override("font_color", UIKit.OK if bool(r.get("ok")) else UIKit.DANGER))
	go.name = "ForgeCraft"
	go.disabled = not (ok_iron and ok_silver) or same
	row.add_child(go)
	if not go.disabled:
		go.call_deferred("grab_focus")
	_m_right(rw, w, top, bh)

func _m_right(rw: float, w: float, top: float, bh: float) -> void:
	var rv := MobilePage.panel(_right, Rect2(w - 20 - rw, top, rw, bh), 12)
	rv.add_child(MobilePage.label(Locale.t("mw_874f9d31"), UIKit.ACCENT, 24, false))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	rv.add_child(g)
	for it in [[Locale.t("mw_81b70668"), GameState.iron], [Locale.t("mw_cac5dd12"), GameState.silver], [Locale.t("mw_b7d19b56"), GameState.food],
			[Locale.t("mw_4791c45f"), GameState.morale]]:
		g.add_child(MobilePage.label("%s %d" % [it[0], int(it[1])], UIKit.TEXT, MobilePage.FONT, false))
	var eq := 0
	for c in GameState.roster():
		if c.weapon_id != "":
			eq += 1
	rv.add_child(MobilePage.label(Locale.t("mw_bebd7f61") % [eq, GameState.roster().size()], UIKit.TEXT_DIM, MobilePage.FONT, false))
	rv.add_child(MobilePage.label(Locale.t("mw_d9999300"), UIKit.ACCENT, 24, false))
	rv.add_child(MobilePage.label(Locale.t("heirloom_preview"), UIKit.TEXT_DIM, MobilePage.FONT, true))
	MobilePage.spacer(rv)
	rv.add_child(MobilePage.button(Locale.t("forge_modify"), false, func():
		if _sel == null:
			return
		var r: Dictionary = CKHeirloom.try_modify(GameState, _sel.id)
		_m_render_all()
		_msg.text = str(r.get("msg", ""))))
	rv.add_child(MobilePage.button(Locale.t("heirloom_store"), false, func():
		if _sel == null:
			return
		var r: Dictionary = CKHeirloom.store(GameState, _sel.id)
		_m_render_all()
		_msg.text = str(r.get("msg", ""))))
