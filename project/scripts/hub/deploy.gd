extends Control
## v8.6 — layout-matched to Stitch 05_deploy.png: editorial head · BATTLE VANGUARD MATRIX (slot cards, selected
## slots frost-stroked, vacant slots dashed) · FOCUSED UNIT METRICS panel with stat bars · 出战 CTA · footer.
## Deploy logic unchanged: toggles GameState.deploy_ids within GameState.max_deploy().

var _cards: Control
var _metrics: Control
var _focus: CKCharacter
var _count: Label
var _head: Control
var _matrix: Control

func _ready() -> void:
	UIKit.void_bg(self)
	var dchips := [["编制上限", "%d 人" % GameState.max_deploy(), UIKit.ACCENT], ["厅堂", "LV %d" % GameState.building_level("hall"), UIKit.TEXT], ["历", Calendar.label(), UIKit.TEXT_DIM]]
	UIKit.top_bar(self, "出战编成 · DEPLOYMENT", dchips, "返回城堡", _back)
	_head = UIKit.page_head(self, 42, 70, "TACTICAL DEPLOYMENT // PROT.07", "出战编成", "CENTURY KNIGHTS : THE FROST MARCH", "点选卡片切换出战；棋盘上以立绘棋子示人。")
	_matrix = UIKit.mono("BATTLE VANGUARD MATRIX", 9, UIKit.ACCENT, false)
	_matrix.position = Vector2(42, 168)
	add_child(_matrix)
	_count = UIKit.body_label("", UIKit.TEXT_DIM, 11)
	_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	_count.position = Vector2(220, 165)
	add_child(_count)
	_cards = Control.new()
	_cards.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_cards)
	_metrics = Control.new()
	_metrics.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_metrics)
	var roster: Array = GameState.roster()
	for c in roster:
		if c.id in GameState.deploy_ids:
			_focus = c
			break
	if _focus == null and not roster.is_empty():
		_focus = roster[0]
	UIKit.footer_bar(self, [["A", "切换出战"], ["←→", "移动选位"], ["ENTER", "出战"], ["ESC", "返回城堡"]], "DEPLOYMENT // MAX %d · v8.6" % GameState.max_deploy())
	## 团徽 + leader 族徽|旗徽 strip under the top bar (desktop default; mobile repositions).
	CKHeraldryChrome.place_muster_crest_strip(self, GameState.get_leader(), Vector2(980, 8), Vector2(40, 48))
	resized.connect(_on_resized)
	_fit_chrome()
	_render()
	UIFX.page_enter(self)
	UIFX.wire_tree(self)


func _on_resized() -> void:
	_fit_chrome()
	_render()


## Phone chrome calls this after the safe-area fit. Use the tall viewport instead of a scaled 1280x720 page.
func apply_mobile_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor_right = 0.0
	anchor_bottom = 0.0
	scale = Vector2.ONE
	position = Vector2.ZERO
	size = vp
	var strip_w := 40.0 * 2.0 + 8.0
	CKHeraldryChrome.place_muster_crest_strip(self, GameState.get_leader(), Vector2(maxf(8.0, vp.x - strip_w - 12.0), 6.0), Vector2(40, 48))
	_fit_chrome()
	_render()


func _view() -> Vector2:
	if size.x >= 64.0 and size.y >= 64.0:
		return size
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(1280, 720)


func _insets() -> Dictionary:
	var raw = get_meta("mobile_insets", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	return raw


func _portrait() -> bool:
	var v := _view()
	if v.x < 64.0:
		return false
	return v.x < 1240.0 or v.y > v.x * 1.2


func _fit_chrome() -> void:
	var v := _view()
	var ins := _insets()
	var bar := get_node_or_null("StitchTopBar") as Control
	var foot := get_node_or_null("StitchFooter") as Control
	if not _portrait():
		return
	var left := maxf(16.0, float(ins.get("left", 0.0)))
	var right := maxf(12.0, float(ins.get("right", 0.0)))
	if bar:
		bar.size.x = v.x
		for ch in bar.get_children():
			if ch is Control and float(ch.size.x) >= 1200.0:
				ch.size.x = v.x
		var row := bar.get_child(bar.get_child_count() - 1) as Control
		if row:
			row.position.x = minf(400.0, maxf(220.0, v.x * 0.28))
			row.size.x = maxf(120.0, v.x - row.position.x - right)
	if _head:
		_head.position.x = left
		_head.size.x = maxf(120.0, v.x - left - right)
		_head.clip_contents = true
	if _matrix:
		_matrix.position.x = left
	if _count:
		_count.position = Vector2(left + 200.0, 148.0)
	if foot:
		var bottom := maxf(0.0, float(ins.get("bottom", 0.0)))
		foot.position = Vector2(0, v.y - bottom - foot.size.y)
		foot.size.x = v.x
		for ch in foot.get_children():
			if ch is Control and float(ch.size.x) >= 1200.0:
				ch.size.x = v.x
			elif ch is Label and ch.position.x > 800.0:
				ch.position.x = v.x - right - ch.get_minimum_size().x

func _reserve_who():
	var rid := CKDeployReserve.appointed_id()
	if rid == "":
		return null
	return GameState.characters.get(rid, null)


func _sync_reserve_strip(parent: Node, at: Vector2) -> void:
	var shield := Vector2(32, 38) if DeviceProfile.is_mobile() else Vector2(36, 44)
	CKHeraldryField.place_reserve_crest_strip(parent, _reserve_who(), at, shield)


func _back() -> void:
	var back := "res://scenes/hub/castle_hub.tscn"
	if GameState.has_meta("deploy_return"):
		back = str(GameState.get_meta("deploy_return"))
		GameState.remove_meta("deploy_return")
	CKNav.up(back)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()
	elif e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_fight()
	elif e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_LEFT:
		_nudge_slot(-1)
	elif e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_RIGHT:
		_nudge_slot(1)

func _fight() -> void:
	GameState.set_meta("battle_return", "res://scenes/hub/castle_hub.tscn")
	GameState.set_meta("battle_map", "quest_bandit")
	GameState.set_meta("battle_sortie", true)
	CKNav.replace("res://scenes/battle/battle.tscn")

func _nudge_slot(dir: int) -> void:
	if _focus == null:
		return
	var ids: Array = GameState.deploy_ids
	var i := ids.find(_focus.id)
	if i < 0:
		return
	var j := i + dir
	if j < 0 or j >= ids.size():
		return
	var swap = ids[i]
	ids[i] = ids[j]
	ids[j] = swap
	_render()

func _toggle(c: CKCharacter) -> void:
	_focus = c
	if DeployBrief.bench_reason(c) != "":
		_render()
		return
	if c.id in GameState.deploy_ids:
		GameState.deploy_ids.erase(c.id)
	elif GameState.deploy_ids.size() < GameState.max_deploy():
		GameState.deploy_ids.append(c.id)
	_render()

func _clear(n: Control) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()

func _render() -> void:
	_clear(_cards)
	_clear(_metrics)
	if _phone_land():
		_render_phone()
		return
	var roster: Array = GameState.roster()
	var kept: Array = []
	for cid in GameState.deploy_ids:
		var who: CKCharacter = GameState.characters.get(cid)
		if who != null and DeployBrief.bench_reason(who) == "":
			kept.append(cid)
	GameState.deploy_ids = kept
	_count.text = "%s · %d" % [DeployBrief.cap_line(), GameState.deploy_ids.size()]
	var slots := maxi(roster.size(), GameState.max_deploy())
	slots = mini(slots, 6)
	var gap := 12.0
	var origin := Vector2(42, 192)
	var row_w := 818.0
	var ch := 470.0
	var cols := slots
	if _portrait():
		var v := _view()
		var ins := _insets()
		var left := maxf(16.0, float(ins.get("left", 0.0)))
		var right := maxf(12.0, float(ins.get("right", 0.0)))
		origin = Vector2(left, maxf(188.0, float(ins.get("top", 0.0)) + 92.0))
		row_w = maxf(160.0, v.x - left - right)
		cols = 2 if row_w < 640.0 else mini(3, slots)
		ch = 248.0
	var cw := minf(196.0, floorf((row_w - gap * float(maxi(cols - 1, 0))) / float(maxi(cols, 1))))
	var focus_btn: Button = null
	for i in range(slots):
		var col := i % cols
		var row := int(i / cols)
		var r := Rect2(origin.x + col * (cw + gap), origin.y + row * (ch + gap), cw, ch)
		if i < roster.size():
			var b := _card(roster[i], i, r)
			if roster[i] == _focus:
				focus_btn = b
		else:
			_vacant(i, r)
	if roster.size() > 6:
		var more := UIKit.body_label("另有 %d 名在花名册中（前六名显示）" % (roster.size() - 6), UIKit.TEXT_FAINT, 11)
		more.position = Vector2(42, 664)
		_cards.add_child(more)
	if focus_btn:
		focus_btn.call_deferred("grab_focus")
	_render_metrics()

func _card(c: CKCharacter, i: int, r: Rect2) -> Button:
	var on: bool = c.id in GameState.deploy_ids
	var hurt := DeployBrief.bench_reason(c)
	var b := Button.new()
	b.position = r.position
	b.custom_minimum_size = r.size
	b.size = r.size
	b.focus_mode = Control.FOCUS_ALL
	var n := UIKit.flat_box(Color(UIKit.ACCENT, 0.06) if on else Color(0.055, 0.067, 0.090, 0.9), Color(UIKit.ACCENT, 0.85) if on else Color(1, 1, 1, 0.10), 8, 2 if on else 1)
	if on:
		n.shadow_color = Color(UIKit.ACCENT, 0.18)
		n.shadow_size = 12
	UIKit._apply_states(b, {
		"normal": n,
		"hover": UIKit.flat_box(Color(0.07, 0.09, 0.12, 0.95), Color(UIKit.ACCENT, 0.5), 8),
		"pressed": UIKit.flat_box(Color(UIKit.ACCENT, 0.12), Color(UIKit.ACCENT, 0.9), 8, 2),
		"focus": UIKit._focus_ring(UIKit.FOCUS_RING, 10),
		"disabled": UIKit.flat_box(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.05), 8),
	})
	b.disabled = hurt != ""
	b.pressed.connect(func(): _toggle(c))
	b.focus_entered.connect(func():
		if _focus != c:
			_focus = c
			_clear(_metrics)
			_render_metrics())
	_cards.add_child(b)
	var slot := GameState.deploy_ids.find(c.id)
	var hd_txt := "#%02d %s" % [i + 1, "LEADER" if c.is_leader else "UNIT"]
	if slot >= 0:
		hd_txt = BattleObjectives.text("deploy_slot") % (slot + 1)
	var hd := UIKit.mono(hd_txt, 8, UIKit.ACCENT if on else UIKit.TEXT_FAINT, false)
	hd.position = Vector2(10, 12)
	b.add_child(hd)
	var chip := hurt if hurt != "" else ("出战" if on else "待命")
	var chip_col := UIKit.DANGER if hurt != "" else (UIKit.ACCENT if on else UIKit.TEXT_FAINT)
	var st := UIKit.tag_chip(chip, chip_col, on and hurt == "")
	st.position = Vector2(r.size.x - 10 - st.get_minimum_size().x, 8)
	b.add_child(st)
	var compact := r.size.y < 320.0
	var plate := Panel.new()
	plate.position = Vector2(14, 44)
	plate.size = Vector2(r.size.x - 28, 88.0 if compact else 160.0)
	plate.clip_contents = true
	plate.add_theme_stylebox_override("panel", UIKit.flat_box(Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.12), 6))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(plate)
	var pr := UIKit.make_portrait_rect(c, 160)
	pr.position = Vector2(1, 1)
	pr.size = plate.size - Vector2(2, 2)
	pr.custom_minimum_size = pr.size
	pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not on:
		pr.modulate = Color(0.7, 0.74, 0.82)
	plate.add_child(pr)
	var arms_sz := Vector2(28, 34) if compact else Vector2(36, 44)
	CKHeraldryChrome.attach_deploy_chrome(b, c, Rect2(plate.position, plate.size), arms_sz)
	var name_y := plate.position.y + plate.size.y + 8.0
	var nm := UIKit.title_label(c.name, 15, UIKit.TEXT)
	nm.position = Vector2((r.size.x - nm.get_minimum_size().x) * 0.5, name_y)
	b.add_child(nm)
	var jb := UIKit.body_label(str(GameState.get_job(c.job_id).get("name", "")), UIKit.ACCENT if on else UIKit.TEXT_DIM, 12)
	jb.autowrap_mode = TextServer.AUTOWRAP_OFF
	jb.position = Vector2((r.size.x - jb.get_minimum_size().x) * 0.5, name_y + 26.0)
	b.add_child(jb)
	var lv := UIKit.mono("LV.%02d · %d 岁" % [c.level, c.age], 8, UIKit.TEXT_FAINT, false)
	lv.position = Vector2((r.size.x - lv.get_minimum_size().x) * 0.5, name_y + 48.0)
	b.add_child(lv)
	if compact:
		return b
	var hl := UIKit.hairline(Color(1, 1, 1, 0.08))
	hl.position = Vector2(12, r.size.y - 126)
	hl.size = Vector2(r.size.x - 24, 1)
	b.add_child(hl)
	var kv := VBoxContainer.new()
	kv.position = Vector2(12, r.size.y - 114)
	kv.add_theme_constant_override("separation", 6)
	kv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(kv)
	kv.add_child(UIKit.kv_row("HP", "%d / %d" % [c.hp, c.max_hp], UIKit.DANGER if c.injured else UIKit.TEXT, r.size.x - 24))
	kv.add_child(UIKit.kv_row("攻击", str(c.derived_atk()), UIKit.ACCENT, r.size.x - 24))
	kv.add_child(UIKit.kv_row("移动", str(c.derived_move()), UIKit.TEXT, r.size.x - 24))
	var act := UIKit.mono("● 当前出战中" if on else "＋ 点击上阵", 9, UIKit.ACCENT if on else UIKit.TEXT_DIM, false)
	act.position = Vector2((r.size.x - act.get_minimum_size().x) * 0.5, r.size.y - 30)
	b.add_child(act)
	return b

func _vacant(i: int, r: Rect2) -> void:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	var s := UIKit.flat_box(Color(1, 1, 1, 0.01), Color(1, 1, 1, 0.06), 8)
	p.add_theme_stylebox_override("panel", s)
	# WS-D #46: a vacant slot is a shortcut to the tavern instead of a dead card.
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.name = "Vacant%d" % i
	p.gui_input.connect(func(ev: InputEvent): _vacant_input(ev))
	_cards.add_child(p)
	var hd := UIKit.mono("#%02d VACANT" % (i + 1), 8, UIKit.TEXT_FAINT, false)
	hd.position = r.position + Vector2(10, 12)
	_cards.add_child(hd)
	var plus := UIKit.mono("+", 26, UIKit.TEXT_FAINT, false)
	plus.position = r.position + Vector2((r.size.x - plus.get_minimum_size().x) * 0.5, 190)
	_cards.add_child(plus)
	var t := UIKit.body_label("空位", UIKit.TEXT_DIM, 14)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.position = r.position + Vector2((r.size.x - t.get_minimum_size().x) * 0.5, 236)
	_cards.add_child(t)
	var e := UIKit.mono("SLOT AVAILABLE", 8, UIKit.TEXT_FAINT, false)
	e.position = r.position + Vector2((r.size.x - e.get_minimum_size().x) * 0.5, 262)
	_cards.add_child(e)
	var tip := UIKit.body_label("去酒馆招募骑士", UIKit.TEXT_FAINT, 11)
	tip.autowrap_mode = TextServer.AUTOWRAP_OFF
	tip.position = r.position + Vector2((r.size.x - tip.get_minimum_size().x) * 0.5, r.size.y - 30)
	_cards.add_child(tip)

const TAVERN := "res://scenes/hub/tavern.tscn"

func _vacant_input(ev: InputEvent) -> void:
	var tap: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
	if tap:
		set_meta("vacant_go", TAVERN)
		if is_inside_tree() and not has_meta("no_nav"):
			CKNav.go(TAVERN)

func _render_metrics() -> void:
	var R := Rect2(880, 112, 376, 568)
	if _portrait():
		var v := _view()
		var ins := _insets()
		var left := maxf(16.0, float(ins.get("left", 0.0)))
		var right := maxf(12.0, float(ins.get("right", 0.0)))
		var bottom := maxf(8.0, float(ins.get("bottom", 0.0)))
		var foot := get_node_or_null("StitchFooter") as Control
		var foot_top := v.y - bottom - 28.0
		if foot:
			foot_top = foot.position.y
		var top := 188.0
		if _cards.get_child_count() > 0:
			var lowest := 0.0
			for ch in _cards.get_children():
				if ch is Control:
					lowest = maxf(lowest, ch.position.y + ch.size.y)
			top = lowest + 16.0
		var height := maxf(240.0, foot_top - 12.0 - top)
		R = Rect2(left, top, maxf(160.0, v.x - left - right), height)
	UIKit.panel_at(_metrics, R, 10, true)
	if _focus == null:
		return
	var c := _focus
	var x := R.position.x + 20
	var w := R.size.x - 40
	var nm := UIKit.title_label(c.name, 22, UIKit.TEXT)
	nm.position = Vector2(x, R.position.y + 18)
	_metrics.add_child(nm)
	var focus_arms := CKHeraldryChrome.make_person_arms(c, Vector2(40, 48))
	focus_arms.name = "FocusArms"
	focus_arms.position = Vector2(R.end.x - 64.0, R.position.y + 14.0)
	_metrics.add_child(focus_arms)
	var jb := UIKit.body_label(str(GameState.get_job(c.job_id).get("name", "")), UIKit.ACCENT, 12)
	jb.autowrap_mode = TextServer.AUTOWRAP_OFF
	jb.position = Vector2(x + nm.get_minimum_size().x + 10, R.position.y + 28)
	_metrics.add_child(jb)
	var ff := UIKit.mono("FOCUSED UNIT METRICS // PLATE #%02d" % (GameState.roster().find(c) + 1), 8, UIKit.TEXT_FAINT, false)
	ff.position = Vector2(x, R.position.y + 56)
	_metrics.add_child(ff)
	var tag := UIKit.tag_chip("主力队长" if c.is_leader else ("已上阵" if c.id in GameState.deploy_ids else "待命"), UIKit.ACCENT if c.id in GameState.deploy_ids else UIKit.TEXT_DIM)
	tag.position = Vector2(R.end.x - 20 - tag.get_minimum_size().x, R.position.y + 24)
	_metrics.add_child(tag)
	DeployBrief.attach(_metrics, DeployBrief.practice_map_id(), Rect2(x, R.position.y + 78, w, 128))
	var stats := [["生命值 (HP)", c.max_hp, "max_hp"], ["攻击 (ATK)", c.derived_atk(), "atk"]]
	var y := R.position.y + 224
	for s in stats:
		var best := 1
		for o in GameState.roster():
			var v: int
			match str(s[2]):
				"max_hp":
					v = int(o.max_hp)
				"atk":
					v = o.derived_atk()
				"def":
					v = o.derived_def()
				"hit":
					v = o.derived_hit()
				_:
					v = o.derived_avo()
			best = maxi(best, v)
		var row := Panel.new()
		row.position = Vector2(x, y)
		row.size = Vector2(w, 52)
		row.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.07), 6))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_metrics.add_child(row)
		var k := UIKit.body_label(str(s[0]), UIKit.TEXT_DIM, 12)
		k.autowrap_mode = TextServer.AUTOWRAP_OFF
		k.position = Vector2(x + 12, y + 8)
		_metrics.add_child(k)
		var v2 := UIKit.mono(str(s[1]), 15, UIKit.TEXT, false)
		v2.position = Vector2(x + w - 12 - v2.get_minimum_size().x, y + 6)
		_metrics.add_child(v2)
		var bar := UIKit.slim_bar(float(s[1]), float(best) * 1.15, UIKit.ACCENT, w - 24, 4)
		bar.position = Vector2(x + 12, y + 36)
		_metrics.add_child(bar)
		y += 60
	var tr := ""
	for t in c.traits:
		tr += str(GameState.get_trait(str(t)).get("name", t)) + " · "
	var note := UIKit.body_label("◈ 特质：" + (tr.trim_suffix(" · ") if tr != "" else "无"), UIKit.TEXT_DIM, 12)
	note.position = Vector2(x, y + 6)
	note.size = Vector2(w, 40)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_metrics.add_child(note)
	var rb := UIKit.ghost_button(CKDeployReserve.button_text(), int(w), 48)
	rb.name = "ReserveBtn"
	rb.clip_text = true
	rb.position = Vector2(x, R.end.y - 132)
	var reserve_at := Vector2(x, R.end.y - 188)
	_sync_reserve_strip(_metrics, reserve_at)
	rb.pressed.connect(func():
		var rr := CKDeployReserve.cycle()
		rb.text = CKDeployReserve.button_text()
		rb.tooltip_text = str(rr.get("msg", ""))
		_sync_reserve_strip(_metrics, reserve_at))
	_metrics.add_child(rb)
	var go := UIKit.cta_button("出战 · 练习战（清匪）", "ENTER", int(w), 52)
	go.name = "Fight"
	go.position = Vector2(x, R.end.y - 76)
	go.disabled = GameState.deploy_ids.is_empty()
	go.tooltip_text = "至少选择一名出战者" if go.disabled else "START CRUSADE"
	go.pressed.connect(_fight)
	_metrics.add_child(go)
	var hint := UIKit.mono("START CRUSADE →", 8, UIKit.TEXT_FAINT, false)
	hint.position = Vector2(x, R.end.y - 18)
	_metrics.add_child(hint)


# ── landscape phone (mobile audit v1: deploy) ──────────────────────────────
# Container layout in the roster/tavern style: one 76px top bar, a horizontally scrolling strip of
# big unit cards on the left, the focused unit + 出战 on the right. Text 22px (≈12dp), buttons 76px.
const PHONE_SIDE := 470.0
var _phone_bar: Control = null

func _phone_land() -> bool:
	return MobilePage.active(self) and not _portrait()

func _render_phone() -> void:
	var v := _view()
	var w := maxf(v.x, 1280.0)
	if _phone_bar == null:
		for n in [_head, _matrix, _count]:
			if n:
				(n as CanvasItem).visible = false
		var info0 := Locale.t("ux_dep_info") % [DeployBrief.cap_line(), GameState.deploy_ids.size()]
		_phone_bar = MobilePage.top_bar(self, Locale.t("ux_dep_title"), info0, [[Locale.t("ux_dep_back"), _back]])
	var roster: Array = GameState.roster()
	var kept: Array = []
	for cid in GameState.deploy_ids:
		var who: CKCharacter = GameState.characters.get(cid)
		if who != null and DeployBrief.bench_reason(who) == "":
			kept.append(cid)
	GameState.deploy_ids = kept
	_count.text = "%s · %d" % [DeployBrief.cap_line(), GameState.deploy_ids.size()]
	var info := _phone_bar.get_child(1) as Label
	if info:
		info.set_meta("m_raw", Locale.t("ux_dep_info") % [DeployBrief.cap_line(), GameState.deploy_ids.size()])
		info.text = str(info.get_meta("m_raw"))
	var top := MobilePage.TOP
	var h := 720.0 - top - 16.0
	var side_x := w - 26.0 - PHONE_SIDE
	var scroll := ScrollContainer.new()
	scroll.name = "PhoneCardStrip"
	scroll.position = Vector2(26, top)
	scroll.size = Vector2(side_x - 26.0 - 16.0, h)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cards.add_child(scroll)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 14)
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(strip)
	var slots := mini(maxi(roster.size(), GameState.max_deploy()), 6)
	var card_h := h - 12.0
	var focus_btn: Button = null
	for i in range(slots):
		if i < roster.size():
			var b := _phone_card(roster[i], i, card_h)
			strip.add_child(b)
			if roster[i] == _focus:
				focus_btn = b
		else:
			strip.add_child(_phone_vacant(i, card_h))
	if focus_btn:
		focus_btn.call_deferred("grab_focus")
	_phone_metrics(Rect2(side_x, top, PHONE_SIDE, h))

func _phone_card(c: CKCharacter, i: int, card_h: float) -> Button:
	var on: bool = c.id in GameState.deploy_ids
	var hurt := DeployBrief.bench_reason(c)
	var b := Button.new()
	b.name = "Card%d" % i
	b.custom_minimum_size = Vector2(250, card_h)
	b.focus_mode = Control.FOCUS_ALL
	var n := UIKit.flat_box(Color(UIKit.ACCENT, 0.08) if on else Color(0.055, 0.067, 0.090, 0.92), Color(UIKit.ACCENT, 0.9) if on else Color(1, 1, 1, 0.12), 10, 2 if on else 1)
	UIKit._apply_states(b, {
		"normal": n,
		"hover": UIKit.flat_box(Color(0.07, 0.09, 0.12, 0.95), Color(UIKit.ACCENT, 0.5), 10),
		"pressed": UIKit.flat_box(Color(UIKit.ACCENT, 0.12), Color(UIKit.ACCENT, 0.9), 10, 2),
		"focus": UIKit._focus_ring(UIKit.FOCUS_RING, 12),
		"disabled": UIKit.flat_box(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.05), 10),
	})
	b.disabled = hurt != ""
	b.pressed.connect(func(): _toggle(c))
	b.focus_entered.connect(func():
		if _focus != c:
			_focus = c
			_clear(_metrics)
			_phone_metrics(Rect2(maxf(_view().x, 1280.0) - 26.0 - PHONE_SIDE, MobilePage.TOP, PHONE_SIDE, 720.0 - MobilePage.TOP - 16.0)))
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	b.add_child(m)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	m.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var slot := GameState.deploy_ids.find(c.id)
	var hd_txt := BattleObjectives.text("deploy_slot") % (slot + 1) if slot >= 0 else Locale.t("ux_dep_idle")
	var hd := MobilePage.label(hd_txt, UIKit.ACCENT if on else UIKit.TEXT_FAINT, MobilePage.FONT, false)
	head.add_child(hd)
	var chip_txt := hurt if hurt != "" else (Locale.t("ux_dep_on") if on else Locale.t("ux_dep_tap"))
	var chip_col := UIKit.DANGER if hurt != "" else (UIKit.ACCENT if on else UIKit.TEXT_DIM)
	var chip := UIKit.tag_chip(chip_txt, chip_col, on and hurt == "")
	head.add_child(chip)
	var pr := UIKit.make_portrait_rect(c, 220)
	pr.custom_minimum_size = Vector2(0, maxf(180.0, card_h - 300.0))
	pr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not on:
		pr.modulate = Color(0.7, 0.74, 0.82)
	col.add_child(pr)
	var nm := MobilePage.label(c.name, UIKit.TEXT, 26, false)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	col.add_child(nm)
	var jb := MobilePage.label("%s · LV %d" % [str(GameState.get_job(c.job_id).get("name", "")), c.level], UIKit.ACCENT if on else UIKit.TEXT_DIM, MobilePage.FONT, false)
	jb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jb.clip_text = true
	col.add_child(jb)
	var st := MobilePage.label(Locale.t("ux_dep_stats") % [c.hp, c.derived_atk(), c.derived_move()], UIKit.DANGER if c.injured else UIKit.TEXT, MobilePage.FONT, false)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.clip_text = true
	col.add_child(st)
	for l in [hd, nm, jb, st]:
		(l as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var darms := CKHeraldryChrome.make_person_arms(c, Vector2(36, 44))
	darms.name = "DeployArms"
	darms.position = Vector2(16.0, maxf(48.0, card_h - 60.0))
	b.add_child(darms)
	return b

func _phone_vacant(i: int, card_h: float) -> Control:
	var p := PanelContainer.new()
	p.name = "Vacant%d" % i
	p.custom_minimum_size = Vector2(250, card_h)
	p.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.015), Color(1, 1, 1, 0.10), 10))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(ev: InputEvent): _vacant_input(ev))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(col)
	for spec in [["+", 64, UIKit.ACCENT], [Locale.t("ux_dep_vacant"), 26, UIKit.TEXT_DIM], [Locale.t("ux_dep_recruit"), MobilePage.FONT, UIKit.TEXT_FAINT]]:
		var l := MobilePage.label(str(spec[0]), spec[2], int(spec[1]), true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(l)
	return p

func _phone_metrics(r: Rect2) -> void:
	var v := MobilePage.panel(_metrics, r, 18)
	(v.get_parent() as Control).name = "PhoneMetrics"
	if _focus == null:
		v.add_child(MobilePage.label(Locale.t("ux_dep_empty"), UIKit.TEXT_DIM))
		return
	var c := _focus
	var on: bool = c.id in GameState.deploy_ids
	var head := HBoxContainer.new()
	v.add_child(head)
	var focus_arms := CKHeraldryChrome.make_person_arms(c, Vector2(36, 44))
	focus_arms.name = "FocusArms"
	focus_arms.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(focus_arms)
	var nm := MobilePage.label(c.name, UIKit.TEXT, 28, false)
	head.add_child(nm)
	var tag_txt := Locale.t("ux_dep_leader") if c.is_leader else (Locale.t("ux_dep_fielded") if on else Locale.t("ux_dep_idle"))
	head.add_child(UIKit.tag_chip(tag_txt, UIKit.ACCENT if on else UIKit.TEXT_DIM))
	v.add_child(MobilePage.label(Locale.t("ux_dep_stats2", [str(GameState.get_job(c.job_id).get("name", "")), c.hp, c.max_hp, c.derived_atk(), c.derived_move()]), UIKit.ACCENT))
	var board := DeployMinimap.new()
	board.map_id = DeployBrief.practice_map_id()
	board.custom_minimum_size = Vector2(0, 96)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(board)
	var m := BattleMaps.get_map(DeployBrief.practice_map_id())
	for line in [DeployBrief.objective_line(m), DeployBrief.enemy_line(m), DeployBrief.suggest_line(m)]:
		v.add_child(MobilePage.label(str(line), UIKit.TEXT_DIM))
	var tr := ""
	for t in c.traits:
		tr += str(GameState.get_trait(str(t)).get("name", t)) + " · "
	v.add_child(MobilePage.label(Locale.t("ux_dep_traits") + (tr.trim_suffix(" · ") if tr != "" else Locale.t("ux_dep_none")), UIKit.TEXT_DIM))
	MobilePage.spacer(v)
	var slot := Control.new()
	slot.name = "ReserveCrestSlot"
	slot.custom_minimum_size = Vector2(180, 48)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(slot)
	_sync_reserve_strip(slot, Vector2.ZERO)
	var rb := MobilePage.button(CKDeployReserve.button_text(), false, func(): pass)
	rb.name = "ReserveBtn"
	rb.pressed.connect(func():
		var rr := CKDeployReserve.cycle()
		rb.text = CKDeployReserve.button_text()
		rb.tooltip_text = str(rr.get("msg", ""))
		_sync_reserve_strip(slot, Vector2.ZERO))
	v.add_child(rb)
	var go := MobilePage.button(Locale.t("ux_dep_go"), true, _fight)
	go.name = "Fight"
	go.disabled = GameState.deploy_ids.is_empty()
	v.add_child(go)
	if go.disabled:
		v.add_child(MobilePage.label(Locale.t("ux_dep_need"), UIKit.DANGER))
