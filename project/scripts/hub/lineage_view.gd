extends Control
## v8.6 — layout-matched to Stitch 18_lineage.png: header + legend · generational tree (GEN rows, node cards,
## spouse/parent connectors, ghost slots) · RETAINERS strip · right TRAIT HERITAGE DOSSIER · footer.

var _tree: Control
var _dossier: Control
var _selected: CKCharacter
var _link_fx: TextureRect
const TREE := Rect2(42, 150, 800, 440)

func _ready() -> void:
	_build()
	_refresh()

func _back() -> void:
	if str(GameState.chapter0_beat) in ["0.5", "0.55"]:
		get_tree().change_scene_to_file("res://scenes/story/chapter0.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_back()

func _build() -> void:
	UIKit.void_bg(self)
	var leader = GameState.get_leader()
	var alive_n := 0
	for ch in GameState.characters.values():
		if ch.alive:
			alive_n += 1
	UIKit.top_bar(self, "%s氏家族谱系" % GameState.surname, [["在世族人", "%d" % alive_n, UIKit.OK], ["历", Calendar.label(), UIKit.TEXT_DIM]], "返回城堡", _back)
	UIKit.page_head(self, 42, 70, "LINEAGE CHRONICLE // SECTOR 07", "%s氏家谱" % GameState.surname, "HOUSE GENEALOGY", "血胤混合是两条河在旗下交汇。托孤之约后，族谱即同盟凭证；子嗣成年可行授旗礼。")
	# legend pill
	var lg := UIKit.panel_at(self, Rect2(520, 72, 322, 30), 15)
	lg.add_theme_stylebox_override("panel", UIKit.flat_box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.10), 15))
	var lh := HBoxContainer.new()
	lh.position = Vector2(14, 5)
	lh.add_theme_constant_override("separation", 6)
	lg.add_child(lh)
	for it in [["●", UIKit.OK, "在世成员"], ["○", UIKit.TEXT_FAINT, "亡故先祖"], ["◆", UIKit.ACCENT, "当前选中"]]:
		var d := UIKit.body_label(str(it[0]), it[1], 11)
		d.autowrap_mode = TextServer.AUTOWRAP_OFF
		lh.add_child(d)
		var l := UIKit.body_label(str(it[2]), UIKit.TEXT_DIM, 11)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		lh.add_child(l)
		var g := Control.new()
		g.custom_minimum_size = Vector2(8, 0)
		lh.add_child(g)
	_tree = Control.new()
	_tree.position = TREE.position
	_tree.size = TREE.size
	_tree.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_tree)
	_dossier = Control.new()
	_dossier.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_dossier)
	_link_fx = TextureRect.new()
	_link_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_link_fx.stretch_mode = TextureRect.STRETCH_SCALE
	_link_fx.size = Vector2(256, 64)
	_link_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_link_fx.modulate = Color(1, 1, 1, 0)
	_link_fx.z_index = 5
	add_child(_link_fx)
	UIKit.footer_bar(self, [["A", "检视成员档案"], ["X", "比对血胤"], ["Y", "授旗礼"], ["ESC", "返回城堡"]], "GENEALOGY PROTOCOL · FROST_TACTICAL v8.6")
	UIFX.page_enter(self)

func _gen_of(c: CKCharacter, memo: Dictionary) -> int:
	if memo.has(c.id):
		return memo[c.id]
	memo[c.id] = 0
	var g := 0
	for pid in c.parent_ids:
		var p = GameState.characters.get(str(pid))
		if p != null:
			g = maxi(g, _gen_of(p, memo) + 1)
	memo[c.id] = g
	return g

func _family() -> Array:
	## leader + spouse + blood descendants + anyone linked by parent ids
	var fam: Dictionary = {}
	var leader = GameState.get_leader()
	if leader:
		fam[leader.id] = leader
	var changed := true
	while changed:
		changed = false
		for ch in GameState.characters.values():
			if fam.has(ch.id):
				continue
			var linked := false
			if str(ch.spouse_id) != "" and fam.has(str(ch.spouse_id)):
				linked = true
			for pid in ch.parent_ids:
				if fam.has(str(pid)):
					linked = true
			for cid in ch.children_ids:
				if fam.has(str(cid)):
					linked = true
			if linked:
				fam[ch.id] = ch
				changed = true
	return fam.values()

func _refresh() -> void:
	for c in _tree.get_children():
		_tree.remove_child(c)
		c.queue_free()
	var fam := _family()
	var memo := {}
	var rows: Dictionary = {}
	for c in fam:
		var g := _gen_of(c, memo)
		if str(c.spouse_id) != "" and GameState.characters.has(str(c.spouse_id)):
			var sp = GameState.characters[str(c.spouse_id)]
			if sp.parent_ids.size() > c.parent_ids.size():
				g = _gen_of(sp, memo)
		if not rows.has(g):
			rows[g] = []
		rows[g].append(c)
	var gens: Array = rows.keys()
	gens.sort()
	if gens.is_empty():
		gens = [0]
		rows[0] = []
	if gens.size() < 2:
		gens.append(int(gens[-1]) + 1)
		rows[gens[-1]] = []
	var row_h := 150.0
	var pos: Dictionary = {}
	var roman := ["I", "II", "III", "IV", "V", "VI"]
	for gi in gens.size():
		var y := 14.0 + gi * row_h
		var gl := UIKit.mono("GEN %s // %s" % [roman[mini(gi, 5)], ["始祖 · 家主", "子嗣", "孙辈", "曾孙"][mini(gi, 3)]], 9, UIKit.ACCENT if gi == 0 else UIKit.TEXT_FAINT)
		gl.position = Vector2(0, y + 48)
		_tree.add_child(gl)
		var dash := UIKit.hairline(Color(1, 1, 1, 0.06))
		dash.position = Vector2(0, y + 66)
		dash.size = Vector2(96, 1)
		_tree.add_child(dash)
		var members: Array = rows[gens[gi]]
		members.sort_custom(func(a, b): return (1 if a.is_leader else 0) > (1 if b.is_leader else 0))
		var x := 150.0
		for c in members:
			pos[c.id] = Vector2(x, y)
			_node_card(c, Vector2(x, y))
			x += 236.0
		if members.size() < 3:
			var ghost_label := "联姻后子嗣将载入此代" if gi > 0 else "联姻配偶席位"
			if gi == 0 and members.size() >= 2:
				ghost_label = "旁支待录"
			_ghost(Vector2(x, y), ghost_label)
	# connectors (spouse horizontal, parent→child elbow)
	for c in fam:
		if not pos.has(c.id):
			continue
		var a: Vector2 = pos[c.id]
		if str(c.spouse_id) != "" and pos.has(str(c.spouse_id)) and str(c.id) < str(c.spouse_id):
			var b: Vector2 = pos[str(c.spouse_id)]
			_line([a + Vector2(220, 56), b + Vector2(0, 56)], UIKit.OK)
		for pid in c.parent_ids:
			if pos.has(str(pid)):
				var p: Vector2 = pos[str(pid)]
				var top := p + Vector2(110, 112)
				var bot := a + Vector2(110, 0)
				var mid := (top.y + bot.y) * 0.5
				_line([top, Vector2(top.x, mid), Vector2(bot.x, mid), bot], UIKit.ACCENT)
				break
	# retainers strip (non-family roster)
	var fam_ids := {}
	for c in fam:
		fam_ids[c.id] = true
	var rl := UIKit.mono("RETAINERS // 旗下骑士（非血亲）", 9, UIKit.TEXT_FAINT, false)
	rl.position = Vector2(0, 340)
	_tree.add_child(rl)
	var rh := HBoxContainer.new()
	rh.position = Vector2(0, 358)
	rh.add_theme_constant_override("separation", 6)
	_tree.add_child(rh)
	for ch in GameState.characters.values():
		if not ch.alive or fam_ids.has(ch.id):
			continue
		var b := UIKit.ghost_button("%s · %d岁" % [ch.name, ch.age], 0, 28)
		var cap = ch
		b.pressed.connect(func(): _select(cap))
		rh.add_child(b)
	if _selected == null or not _selected.alive:
		_selected = GameState.get_leader()
		if _selected == null and not fam.is_empty():
			_selected = fam[0]
	_render_dossier()
	_highlight()

func _line(pts: Array, col: Color) -> void:
	var l := Line2D.new()
	for p in pts:
		l.add_point(p)
	l.width = 1.5
	l.default_color = Color(col, 0.55)
	l.antialiased = true
	_tree.add_child(l)
	_tree.move_child(l, 0)

func _ghost(at: Vector2, label: String) -> void:
	var p := Panel.new()
	p.position = at
	p.size = Vector2(220, 112)
	var s := UIKit.flat_box(Color(1, 1, 1, 0.012), Color(1, 1, 1, 0.08), 8)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tree.add_child(p)
	var l := UIKit.body_label(label, UIKit.TEXT_FAINT, 11)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.position = Vector2(0, 46)
	l.size = Vector2(220, 18)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)

func _node_card(c: CKCharacter, at: Vector2) -> void:
	var b := Button.new()
	b.name = "Node_%s" % c.id
	b.set_meta("cid", c.id)
	b.position = at
	b.size = Vector2(220, 112)
	b.focus_mode = Control.FOCUS_ALL
	var mk := func(bg: Color, bd: Color, bw: int) -> StyleBoxFlat:
		return UIKit.flat_box(bg, bd, 8, bw)
	UIKit._apply_states(b, {
		"normal": mk.call(Color(0.055, 0.067, 0.090, 0.92), Color(1, 1, 1, 0.10), 1),
		"hover": mk.call(Color(0.07, 0.09, 0.12, 0.95), Color(UIKit.ACCENT, 0.45), 1),
		"pressed": mk.call(Color(UIKit.ACCENT, 0.10), Color(UIKit.ACCENT, 0.8), 2),
		"focus": UIKit._focus_ring(UIKit.FOCUS_RING, 10),
		"disabled": mk.call(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.05), 1),
	})
	b.pressed.connect(func():
		UIFX.press_feedback(b)
		_select(c))
	UIFX.wire_button(b)
	_tree.add_child(b)
	var tag := "当前家主" if c.is_leader else ("子嗣" if c.is_child else ("联姻" if str(c.spouse_id) != "" else "族人"))
	var tc := UIKit.tag_chip(tag, UIKit.ACCENT if c.is_leader else (UIKit.OK if not c.is_child else UIKit.TEXT_DIM))
	tc.position = Vector2(12, 10)
	b.add_child(tc)
	var st := UIKit.body_label(("● " if c.alive else "○ ") + "%d 岁" % c.age, UIKit.OK if c.alive else UIKit.TEXT_FAINT, 11)
	st.autowrap_mode = TextServer.AUTOWRAP_OFF
	st.position = Vector2(150, 10)
	st.size = Vector2(58, 16)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_child(st)
	var th := Control.new()
	th.position = Vector2(12, 38)
	th.size = Vector2(48, 60)
	th.clip_contents = true
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(th)
	var pt = UnitArt.portrait(c, 128)
	if pt:
		var tr := TextureRect.new()
		tr.texture = pt
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size = th.size
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		th.add_child(tr)
	var ring := Panel.new()
	ring.position = th.position
	ring.size = th.size
	var rs := UIKit.flat_box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.18), 4)
	rs.draw_center = false
	ring.add_theme_stylebox_override("panel", rs)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ring)
	var nm := UIKit.title_label(c.name, 16)
	nm.add_theme_font_override("font", UIKit.font("bold"))
	nm.position = Vector2(70, 36)
	nm.size = Vector2(140, 22)
	nm.clip_text = true
	b.add_child(nm)
	var pb := str(c.primary_bloodline())
	var sub := UIKit.body_label("%s · %s" % [GameState.get_job(c.job_id).get("name", ""), c.rank_name()], UIKit.TEXT_DIM, 11)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.position = Vector2(70, 60)
	sub.size = Vector2(140, 16)
	sub.clip_text = true
	b.add_child(sub)
	var bl := UIKit.body_label("%s %d%%" % [GameState.get_bloodline(pb).get("name", pb), int(round(float(c.blood_mix.get(pb, 1.0)) * 100))], UIKit.ACCENT, 11)
	bl.autowrap_mode = TextServer.AUTOWRAP_OFF
	bl.position = Vector2(70, 78)
	bl.size = Vector2(140, 16)
	b.add_child(bl)

func _select(c: CKCharacter) -> void:
	_selected = c
	_render_dossier()
	_highlight()
	_play_link_fx()

func _highlight() -> void:
	for n in _tree.get_children():
		if n is Button and n.has_meta("cid"):
			var on: bool = _selected != null and str(n.get_meta("cid")) == str(_selected.id)
			var s := UIKit.flat_box(Color(UIKit.ACCENT, 0.07) if on else Color(0.055, 0.067, 0.090, 0.92), Color(UIKit.ACCENT, 0.9) if on else Color(1, 1, 1, 0.10), 8, 2 if on else 1)
			if on:
				s.shadow_color = Color(UIKit.ACCENT, 0.25)
				s.shadow_size = 12
			n.add_theme_stylebox_override("normal", s)

func _play_link_fx() -> void:
	if _link_fx == null or _selected == null:
		return
	var node = _tree.get_node_or_null("Node_%s" % _selected.id)
	if node == null:
		return
	var frames: Array = []
	for i in range(8):
		var fp = "res://assets/art/fx/lineage_link_%d.png" % i
		if ResourceLoader.exists(fp):
			frames.append(load(fp))
	if frames.is_empty():
		return
	_link_fx.position = _tree.position + node.position + Vector2(-18, 86)
	_link_fx.texture = frames[0]
	_link_fx.modulate = Color(1, 1, 1, 0.9)
	for i in range(1, frames.size()):
		var fi = i
		get_tree().create_timer(0.06 * fi).timeout.connect(func():
			if is_instance_valid(_link_fx): _link_fx.texture = frames[fi])
	var tw = _link_fx.create_tween()
	tw.tween_interval(0.06 * frames.size())
	tw.tween_property(_link_fx, "modulate:a", 0.0, 0.35)

func _render_dossier() -> void:
	for c in _dossier.get_children():
		_dossier.remove_child(c)
		c.queue_free()
	var p := UIKit.panel_at(_dossier, Rect2(862, 72, 376, 612), 12)
	var h1 := UIKit.title_label("血脉溯源与传承特质", 16)
	h1.add_theme_font_override("font", UIKit.font("bold"))
	h1.position = Vector2(20, 18)
	p.add_child(h1)
	var h2 := UIKit.mono("TRAIT HERITAGE DOSSIER", 9, UIKit.TEXT_FAINT)
	h2.position = Vector2(20, 42)
	p.add_child(h2)
	var c := _selected
	if c == null:
		return
	var idc := UIKit.tag_chip(c.name, UIKit.ACCENT)
	idc.position = Vector2(356 - idc.get_combined_minimum_size().x, 20)
	p.add_child(idc)
	# primary bloodline card (focused)
	var pb := str(c.primary_bloodline())
	var bld: Dictionary = GameState.get_bloodline(pb)
	var bc := UIKit.panel_at(p, Rect2(16, 66, 344, 112), 8, true)
	var ib := UIKit.panel_at(bc, Rect2(14, 14, 40, 40), 6)
	var glyph := UIKit.title_label("◆", 18, UIKit.ACCENT)
	glyph.position = Vector2(12, 7)
	ib.add_child(glyph)
	var bn := UIKit.title_label(str(bld.get("name", pb)), 17)
	bn.add_theme_font_override("font", UIKit.font("bold"))
	bn.position = Vector2(66, 12)
	bc.add_child(bn)
	var bsub := UIKit.body_label("主血胤 · 纯度 %d%%" % int(round(float(c.blood_mix.get(pb, 1.0)) * 100)), UIKit.TEXT_DIM, 11)
	bsub.autowrap_mode = TextServer.AUTOWRAP_OFF
	bsub.position = Vector2(66, 36)
	bc.add_child(bsub)
	var bdesc := UIKit.body_label(str(bld.get("desc", "血胤浓度驱动「血胤月泽」月结；联姻改写下一代的混合。")), UIKit.TEXT, 12)
	bdesc.position = Vector2(14, 62)
	bdesc.size = Vector2(316, 40)
	bdesc.custom_minimum_size = Vector2(316, 0)
	bc.add_child(bdesc)
	# blood mix bars
	UIKit.section_head(p, Vector2(20, 192), "血胤混合", "BLOOD MIX", 336, "%d 支" % c.blood_mix.size())
	var y := 216.0
	for bk in c.blood_mix.keys():
		var b2: Dictionary = GameState.get_bloodline(bk)
		var pct := float(c.blood_mix[bk])
		var row := UIKit.kv_row(str(b2.get("name", bk)), "%d%%" % int(round(pct * 100)), UIKit.TEXT, 336)
		row.position = Vector2(20, y)
		p.add_child(row)
		var bar := UIKit.slim_bar(pct * 100.0, 100, UIKit.ACCENT if bk == pb else UIKit.OK, 336, 3)
		bar.position = Vector2(20, y + 20)
		p.add_child(bar)
		y += 32
		if y > 290:
			break
	# traits
	y = maxf(y + 8, 300)
	UIKit.section_head(p, Vector2(20, y), "禀性", "TRAITS", 336, "%d 项" % c.traits.size())
	y += 24
	var shown := 0
	for tr in c.traits:
		if shown >= 3:
			break
		var td: Dictionary = GameState.get_trait(str(tr))
		var tr_row := Control.new()
		tr_row.position = Vector2(20, y)
		tr_row.size = Vector2(336, 26)
		p.add_child(tr_row)
		var ic := UIKit.trait_icon_rect(str(tr), 22.0)
		ic.position = Vector2(0, 2)
		tr_row.add_child(ic)
		var tn := UIKit.body_label(str(td.get("name", tr)), UIKit.TEXT, 13)
		tn.autowrap_mode = TextServer.AUTOWRAP_OFF
		tn.position = Vector2(30, 3)
		tr_row.add_child(tn)
		var pol := str(td.get("polarity", ""))
		var chip := UIKit.tag_chip("增益" if pol == "pos" else ("减益" if pol == "neg" else "中性"), UIKit.OK if pol == "pos" else (UIKit.DANGER if pol == "neg" else UIKit.TEXT_DIM))
		chip.position = Vector2(336 - chip.get_combined_minimum_size().x, 3)
		tr_row.add_child(chip)
		y += 30
		shown += 1
	if c.traits.is_empty():
		var nt := UIKit.body_label("（禀性未显）", UIKit.TEXT_FAINT, 12)
		nt.position = Vector2(20, y)
		p.add_child(nt)
		y += 22
	# aptitude grid
	y += 8
	UIKit.section_head(p, Vector2(20, y), "资质上下限", "APTITUDE", 336)
	y += 24
	var ag := GridContainer.new()
	ag.columns = 2
	ag.position = Vector2(20, y)
	ag.add_theme_constant_override("h_separation", 20)
	ag.add_theme_constant_override("v_separation", 2)
	p.add_child(ag)
	for sk in CKCharacter.STAT_KEYS:
		ag.add_child(UIKit.kv_row(Locale.t("stat_" + sk), "%d  ·  %d–%d" % [c.stats[sk], c.apt_min.get(sk, 0), c.apt_max.get(sk, 0)], UIKit.TEXT, 158))
	# actions
	var hl := UIKit.hairline(Color(1, 1, 1, 0.07))
	hl.position = Vector2(16, 552)
	hl.size = Vector2(344, 1)
	p.add_child(hl)
	var adult: bool = c.is_child and c.age >= Calendar.ADULT_AGE
	var note := UIKit.body_label("可授旗入队" if adult else ("家主为月结与堡志之轴" if c.is_leader else "族谱纪事 %d 条" % GameState.lineage_log.size()), UIKit.OK if adult else UIKit.TEXT_FAINT, 11)
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.position = Vector2(20, 572)
	p.add_child(note)
	var rite := UIKit.cta_button("授旗礼", "Y", 132, 36)
	rite.position = Vector2(228, 564)
	rite.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/lineage_rite.tscn"))
	p.add_child(rite)
