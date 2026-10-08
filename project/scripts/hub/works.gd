extends Control
## v8.6 — Stitch language (tokens of 02/16): top bar · editorial head · FORTIFICATION MATRIX (five building
## rows: level pips, effect, cost check, upgrade CTA) · AMBITION LEDGER (堡志 checklist) + HOUSE MODIFIERS · footer.
## Logic unchanged: GameState.upgrade_building(id), BUILDING_COST, ambition_list().

const ICON := {"hall": "res://assets/art/ui/v86/kpi_fortify.png", "barracks": "res://assets/art/ui/v86/mk_iron.png", "market": "res://assets/art/ui/v86/kpi_cash.png", "forge": "res://assets/art/ui/v86/mk_iron.png", "shrine": "res://assets/art/ui/v86/mk_herb.png"}
const EN := {"hall": "COUNCIL HALL", "barracks": "DRILL YARD", "market": "MARKET", "forge": "FORGE", "shrine": "SANCTUARY"}

var _msg := ""
var _msg_ok := true
var _body: Control
var _bar: Control

func _ready() -> void:
	UIKit.void_bg(self)
	Music.play_castle()
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_body)
	_render()
	UIKit.footer_bar(self, [["A", "升级"], ["↑↓", "切换工事"], ["ESC", "返回城堡"]], "FORTIFICATION WORKS · v8.6")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

func _back() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()

func _render() -> void:
	if _bar:
		_bar.queue_free()
	_bar = UIKit.top_bar(self, "城堡工事 · WORKS", [["银币", str(GameState.silver), UIKit.ACCENT], ["铁", str(GameState.iron), UIKit.TEXT], ["粮", str(GameState.food), UIKit.TEXT], ["历", Calendar.label(), UIKit.TEXT_DIM]], "返回城堡", _back)
	for n in _body.get_children():
		_body.remove_child(n)
		n.queue_free()
	UIKit.page_head(_body, 42, 70, "FORTIFICATION // CASTLE WORKS", "城堡工事", "FORTIFICATION MATRIX", "工事至 Lv%d；升级扩编、降价、增产。全部工事 Lv3 / Lv5 达成堡志。" % GameState.BUILDING_MAX)
	var view_b := UIKit.ghost_button(Locale.t("castle_view_open"), 160, 36)
	view_b.position = Vector2(480, 118)
	view_b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/castle_view.tscn"))
	_body.add_child(view_b)
	var total := 0
	for id in ["hall", "barracks", "market", "forge", "shrine"]:
		total += GameState.building_level(id)
	var k := UIKit.stat_box("工事总等级", "%d / %d" % [total, 5 * GameState.BUILDING_MAX], UIKit.ACCENT)
	k.position = Vector2(756, 82)
	_body.add_child(k)
	var k2 := UIKit.stat_box("出战上限", "%d 人" % GameState.max_deploy(), UIKit.TEXT)
	k2.position = Vector2(884, 82)
	_body.add_child(k2)
	UIKit.panel_at(_body, Rect2(24, 160, 828, 520), 10)
	UIKit.section_head(_body, Vector2(42, 174), "工事矩阵", "BUILDINGS", 792, "LV MAX %d" % GameState.BUILDING_MAX)
	var descs := {
		"hall": "扩编队上限（现 %d 人）。Lv2→5人，Lv3→6人。" % GameState.max_deploy(),
		"barracks": "演武花费现 %d 银；Lv2+ 月结士气，Lv3 有概率双加。" % GameState.train_cost(),
		"market": "买价更低、卖价更高。商路旁注可再叠加。",
		"forge": "打造更省铁银；Lv4 产出精灰刃（+3攻）。",
		"shrine": "丰收粮产与祈愈强度随等级上升。",
	}
	var y := 204.0
	var first: Button = null
	for id in ["hall", "barracks", "market", "forge", "shrine"]:
		var b := _row(id, Rect2(38, y, 800, 88), str(descs[id]))
		if first == null and b != null and not b.disabled:
			first = b
		y += 94
	if _msg != "":
		var m := UIKit.body_label(_msg, UIKit.OK if _msg_ok else UIKit.DANGER, 12)
		m.autowrap_mode = TextServer.AUTOWRAP_OFF
		m.position = Vector2(500, 176)
		_body.add_child(m)
	if first:
		first.call_deferred("grab_focus")
	# ambitions
	UIKit.panel_at(_body, Rect2(864, 160, 392, 400), 10)
	var amb: Array = GameState.ambition_list()
	var done := 0
	for a in amb:
		if a.get("done"):
			done += 1
	UIKit.section_head(_body, Vector2(882, 174), "堡志", "AMBITION LEDGER", 356, "%d / %d" % [done, amb.size()])
	var sc := ScrollContainer.new()
	sc.position = Vector2(876, 202)
	sc.size = Vector2(368, 346)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	sc.add_child(vb)
	for a in amb:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(356, 0)
		var ok: bool = bool(a.get("done"))
		var ps := UIKit.flat_box(Color(UIKit.OK, 0.06) if ok else Color(1, 1, 1, 0.02), Color(UIKit.OK, 0.4) if ok else Color(1, 1, 1, 0.07), 6)
		ps.content_margin_top = 6
		ps.content_margin_bottom = 6
		ps.content_margin_left = 10
		ps.content_margin_right = 10
		p.add_theme_stylebox_override("panel", ps)
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 1)
		p.add_child(pv)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		pv.add_child(h)
		h.add_child(UIKit.mono("✓" if ok else "○", 11, UIKit.OK if ok else UIKit.TEXT_FAINT, false))
		var n := UIKit.title_label(str(a.name), 13, UIKit.TEXT if ok else UIKit.TEXT_DIM)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var d := UIKit.body_label("%s · 奖：%s" % [a.desc, a.reward], UIKit.TEXT_FAINT, 11)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(334, 0)
		pv.add_child(d)
		vb.add_child(p)
	UIKit.panel_at(_body, Rect2(864, 572, 392, 108), 10)
	UIKit.section_head(_body, Vector2(882, 586), "家族旁注", "HOUSE MODIFIERS", 356, "")
	var mods := UIKit.body_label(_house_mod_text(), UIKit.TEXT_DIM, 12)
	mods.position = Vector2(882, 612)
	mods.size = Vector2(356, 56)
	mods.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(mods)

func _row(id: String, r: Rect2, desc: String) -> Button:
	var lv := GameState.building_level(id)
	var mx: int = GameState.BUILDING_MAX
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.08), 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(p)
	var ib := Panel.new()
	ib.position = r.position + Vector2(14, 16)
	ib.size = Vector2(56, 56)
	ib.add_theme_stylebox_override("panel", UIKit.flat_box(Color(UIKit.ACCENT, 0.06), Color(UIKit.ACCENT, 0.35), 6))
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(ib)
	var ic := TextureRect.new()
	if ResourceLoader.exists(ICON[id]):
		ic.texture = load(ICON[id])
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(10, 10)
	ic.size = Vector2(36, 36)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ib.add_child(ic)
	var h := HBoxContainer.new()
	h.position = r.position + Vector2(86, 12)
	h.add_theme_constant_override("separation", 10)
	_body.add_child(h)
	h.add_child(UIKit.title_label(str(GameState.BUILDING_NAMES[id]), 17, UIKit.TEXT))
	var en := UIKit.mono(EN[id], 9, UIKit.TEXT_FAINT, false)
	en.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(en)
	h.add_child(UIKit.tag_chip("LV %d / %d" % [lv, mx], UIKit.OK if lv >= mx else UIKit.ACCENT))
	# level pips
	for i in range(mx):
		var pip := ColorRect.new()
		pip.color = UIKit.ACCENT if i < lv else Color(1, 1, 1, 0.10)
		pip.position = r.position + Vector2(86 + i * 26, 42)
		pip.size = Vector2(22, 3)
		_body.add_child(pip)
	var d := UIKit.body_label(desc, UIKit.TEXT_DIM, 12)
	d.autowrap_mode = TextServer.AUTOWRAP_OFF
	d.position = r.position + Vector2(86, 54)
	_body.add_child(d)
	var b: Button
	if lv < mx:
		var cost: Dictionary = GameState.BUILDING_COST.get(lv + 1, {})
		var need_s := int(cost.get("silver", 0))
		if bool(GameState.house_mods.get("hall_discount", false)) and id == "hall":
			need_s = int(need_s * 0.75)
		var ni := int(cost.get("iron", 0))
		var nf := int(cost.get("food", 0))
		var ok := GameState.silver >= need_s and GameState.iron >= ni and GameState.food >= nf
		var cl := UIKit.mono("COST", 8, UIKit.TEXT_FAINT, false)
		cl.position = r.position + Vector2(470, 18)
		_body.add_child(cl)
		var cv := UIKit.body_label("%d 银 · %d 铁 · %d 粮" % [need_s, ni, nf], UIKit.TEXT if ok else UIKit.DANGER, 12)
		cv.autowrap_mode = TextServer.AUTOWRAP_OFF
		cv.position = r.position + Vector2(470, 34)
		_body.add_child(cv)
		b = UIKit.cta_button("升级", "A", 128, 40)
		b.tooltip_text = "" if ok else "资源不足"
	else:
		b = UIKit.ghost_button("已满级", 128, 40)
		b.disabled = true
	b.position = r.position + Vector2(r.size.x - 142, 24)
	var bid := id
	b.pressed.connect(func(): _upgrade(bid))
	_body.add_child(b)
	return b

func _house_mod_text() -> String:
	var parts: Array = []
	if bool(GameState.house_mods.get("hall_discount", false)):
		parts.append("厅堂折扣")
	if bool(GameState.house_mods.get("trade_route", false)):
		parts.append("河卫商路")
	if bool(GameState.house_mods.get("drill_discount", false)):
		parts.append("校场减价")
	if bool(GameState.house_mods.get("vow_banner", false)):
		parts.append("旗饰遗产")
	if bool(GameState.house_mods.get("vow_prayer", false)):
		parts.append("祷文遗产")
	if bool(GameState.house_mods.get("vow_trade", false)):
		parts.append("商契遗产")
	if int(GameState.house_mods.get("war_memory", 0)) > 0:
		parts.append("战勋×%d" % int(GameState.house_mods.war_memory))
	if parts.is_empty():
		return "尚无永久修正——完成委任首通或联姻誓约会写入。"
	return " · ".join(parts)

func _upgrade(id: String) -> void:
	var r: Dictionary = GameState.upgrade_building(id)
	_msg = str(r.get("msg", ""))
	_msg_ok = bool(r.get("ok"))
	if _msg_ok:
		Sfx.confirm()
		GameState.save_game()
	else:
		Sfx.miss()
	_render()
