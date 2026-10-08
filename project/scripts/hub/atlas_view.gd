extends Control
## v8.6 — layout-matched to Stitch 03_atlas.png: top bar · left 参谋总席 nav (十国疆域 list + readiness) ·
## centre map viewport (plate + tactical grid + coords + legend) · right NATION PROFILE card · footer.

const _Atlas = preload("res://scripts/art/atlas_art.gd")
var _map: TextureRect
var _profile: Control
var _sel := ""
var _nav: Array = []
var _world := ""

func _ready() -> void:
	UIKit.void_bg(self)
	UIKit.top_bar(self, "世界舆图 · STRATEGIC ATLAS", [["邦国", "10 / 10", UIKit.ACCENT], ["历", Calendar.label(), UIKit.TEXT_DIM]], "返回城堡", _back)
	var d: Dictionary = _Atlas.data()
	# left nav
	var lp := UIKit.panel_at(self, Rect2(26, 72, 168, 612), 10)
	var hb := UIKit.panel_at(lp, Rect2(12, 12, 144, 48), 6)
	hb.add_theme_stylebox_override("panel", UIKit.flat_box(Color(UIKit.ACCENT, 0.06), Color(UIKit.ACCENT, 0.35), 6))
	var ht := UIKit.title_label("参谋总席", 14, UIKit.TEXT)
	ht.position = Vector2(12, 6)
	hb.add_child(ht)
	var hs := UIKit.mono("十国疆域 · 战略中枢", 8, UIKit.TEXT_FAINT, false)
	hs.position = Vector2(12, 28)
	hb.add_child(hs)
	var nl := UIKit.mono("NATIONS 10/10", 9, UIKit.ACCENT)
	nl.position = Vector2(14, 72)
	lp.add_child(nl)
	var v := VBoxContainer.new()
	v.position = Vector2(8, 92)
	v.add_theme_constant_override("separation", 2)
	lp.add_child(v)
	var i := 0
	for n in d.get("nations", []):
		i += 1
		var nid := str(n.get("id", ""))
		var b := UIKit.index_button("%02d" % i, str(n.get("name", nid)), 152)
		b.custom_minimum_size = Vector2(152, 34)
		b.add_theme_font_size_override("font_size", 13)
		UIKit.compact(b, 34)
		b.set_meta("nid", nid)
		b.pressed.connect(func(): _select(nid, str(n.get("name", nid))))
		v.add_child(b)
		_nav.append(b)
	var rl := UIKit.body_label("全军战备率", UIKit.TEXT_DIM, 11)
	rl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rl.position = Vector2(14, 552)
	lp.add_child(rl)
	var rv := UIKit.mono("%d%%" % GameState.morale, 11, UIKit.OK, false)
	rv.position = Vector2(154 - rv.get_minimum_size().x, 552)
	lp.add_child(rv)
	var bar := UIKit.slim_bar(GameState.morale, 100, UIKit.OK, 140, 3)
	bar.position = Vector2(14, 572)
	lp.add_child(bar)
	var gb := UIKit.ghost_button("出战编成", 140, 28)
	gb.position = Vector2(14, 582)
	gb.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/deploy.tscn"))
	lp.add_child(gb)
	# centre map viewport
	var mp := UIKit.panel_at(self, Rect2(206, 72, 796, 612), 10)
	var clip := Control.new()
	clip.position = Vector2(1, 1)
	clip.size = Vector2(794, 610)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp.add_child(clip)
	_map = TextureRect.new()
	_map.name = "MapPlate"
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_map.size = clip.size
	_map.modulate = Color(0.64, 0.72, 0.86)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_map)
	var grid := ColorRect.new()
	grid.size = clip.size
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/frost_void.gdshader")
	gm.set_shader_parameter("base", Color(0, 0, 0, 1))
	gm.set_shader_parameter("glow", Color(0, 0, 0, 1))
	gm.set_shader_parameter("grid_a", 0.06)
	gm.set_shader_parameter("size_px", clip.size)
	grid.material = gm
	grid.color = Color(1, 1, 1, 1)
	clip.add_child(grid)
	var gmat := CanvasItemMaterial.new()
	gmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	grid.use_parent_material = false
	var veil := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(UIKit.BG, 0.0))
	g.set_color(1, Color(UIKit.BG, 0.72))
	g.set_offset(0, 0.55)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	veil.texture = gt
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.size = clip.size
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(veil)
	_grid_overlay = grid
	grid.visible = false   # grid shader is opaque; rely on void grid outside — keep map clean
	var coord := UIKit.mono("GRID  CN-742-SEC.NORD  //  LAT 47°18'N · LON 12°04'E  //  战棋层级：实时",  9, UIKit.TEXT_DIM, false)
	coord.position = Vector2(16, 14)
	mp.add_child(coord)
	var lg := UIKit.panel_at(mp, Rect2(16, 486, 250, 108), 8)
	var lt := UIKit.body_label("舆图图例 // LEGEND", UIKit.TEXT_DIM, 11)
	lt.autowrap_mode = TextServer.AUTOWRAP_OFF
	lt.position = Vector2(12, 8)
	lg.add_child(lt)
	var lgg := GridContainer.new()
	lgg.columns = 2
	lgg.position = Vector2(12, 32)
	lgg.add_theme_constant_override("h_separation", 18)
	lgg.add_theme_constant_override("v_separation", 6)
	lg.add_child(lgg)
	for it in [["◉ 重要据点", UIKit.ACCENT], ["┄ 行军轨迹", UIKit.ACCENT], ["◎ 盟友邦国", UIKit.OK], ["◎ 敌对战区", UIKit.DANGER]]:
		var ll := UIKit.body_label(str(it[0]), it[1], 11)
		ll.autowrap_mode = TextServer.AUTOWRAP_OFF
		lgg.add_child(ll)
	var lh := UIKit.mono("[L-STICK] 平移视图    [RT] 战术放大", 8, UIKit.TEXT_FAINT, false)
	lh.position = Vector2(12, 86)
	lg.add_child(lh)
	_world = _Atlas.world_plate()
	if _world == "" and ResourceLoader.exists("res://assets/art/ui/atlas_world.png"):
		_world = "res://assets/art/ui/atlas_world.png"
	if _world != "":
		_map.texture = load(_world)
	_profile = Control.new()
	_profile.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_profile)
	_render_profile("", "全图 · 十国")
	UIKit.footer_bar(self, [["A", "选定 / 进军"], ["X", "行军推演"], ["Y", "势力情报"], ["ESC", "返回城堡"]], "STRATEGIC ATLAS · FROST_TACTICAL v8.6")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)

var _grid_overlay: ColorRect

func _back() -> void:
	UIFX.page_exit(self)
	get_tree().change_scene_to_file("res://scenes/hub/castle_hub.tscn")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		if _sel != "":
			_select("", "全图 · 十国")
		else:
			_back()

func _select(nid: String, nm: String) -> void:
	_sel = nid
	var path := _Atlas.nation_plate(nid) if nid != "" else _world
	if path != "":
		_map.texture = load(path)
		UIFX.focus_ring(_map)
	for b in _nav:
		var on: bool = str(b.get_meta("nid")) == nid
		b.add_theme_color_override("font_color", UIKit.ACCENT if on else UIKit.TEXT)
	_render_profile(nid, nm)

func _render_profile(nid: String, nm: String) -> void:
	for n in _profile.get_children():
		_profile.remove_child(n)
		n.queue_free()
	var p := UIKit.panel_at(_profile, Rect2(1014, 72, 242, 612), 10)
	var top := ColorRect.new()
	top.color = UIKit.ACCENT
	top.size = Vector2(242, 2)
	p.add_child(top)
	var idx := 0
	var d: Dictionary = _Atlas.data()
	var nations: Array = d.get("nations", [])
	for k in nations.size():
		if str(nations[k].get("id", "")) == nid:
			idx = k + 1
	var el := UIKit.mono("NATION PROFILE // %02d" % idx, 9, UIKit.TEXT_FAINT, false)
	el.position = Vector2(16, 18)
	p.add_child(el)
	var t := UIKit.title_label(nm, 22)
	t.position = Vector2(16, 36)
	p.add_child(t)
	var en := UIKit.mono(nid.to_upper() if nid != "" else "TEN REALMS", 9, UIKit.TEXT_DIM, false)
	en.position = Vector2(16, 68)
	p.add_child(en)
	var kv := VBoxContainer.new()
	kv.position = Vector2(16, 96)
	kv.add_theme_constant_override("separation", 8)
	p.add_child(kv)
	var rep := "—"
	for realm in ["ashland", "riverland"]:
		if nid.begins_with(realm.substr(0, 3)):
			rep = GameState.get_rep_name(realm)
	kv.add_child(UIKit.kv_row("邦交声望", rep if rep != "—" else ("灰烬邦 %s" % GameState.get_rep_name("ashland") if nid == "" else "未建交"), UIKit.ACCENT, 210))
	kv.add_child(UIKit.kv_row("行军距离", "%d 日" % (2 + idx) if nid != "" else "—", UIKit.TEXT, 210))
	kv.add_child(UIKit.kv_row("战区态势", "十国并立" if nid == "" else ("戒备" if idx % 3 == 1 else ("平稳" if idx % 3 == 2 else "前线")), UIKit.DANGER if idx % 3 == 0 and nid != "" else UIKit.OK, 210))
	var hl := UIKit.hairline(Color(1, 1, 1, 0.07))
	hl.position = Vector2(16, 186)
	hl.size = Vector2(210, 1)
	p.add_child(hl)
	var pl := UIKit.mono("REGION PLATE", 9, UIKit.TEXT_FAINT)
	pl.position = Vector2(16, 200)
	p.add_child(pl)
	var th := Control.new()
	th.position = Vector2(16, 220)
	th.size = Vector2(210, 140)
	th.clip_contents = true
	p.add_child(th)
	var path := _Atlas.nation_plate(nid) if nid != "" else _world
	if path != "":
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size = th.size
		th.add_child(tr)
	var ring := Panel.new()
	ring.position = th.position
	ring.size = th.size
	var rs := UIKit.flat_box(Color(0, 0, 0, 0), Color(UIKit.ACCENT, 0.4), 4)
	rs.draw_center = false
	ring.add_theme_stylebox_override("panel", rs)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ring)
	var note := UIKit.panel_at(p, Rect2(16, 374, 210, 92), 6)
	note.add_theme_stylebox_override("panel", UIKit.flat_box(Color(UIKit.EMBER, 0.04), Color(1, 1, 1, 0.08), 6))
	var nb := ColorRect.new()
	nb.color = Color(UIKit.EMBER, 0.8)
	nb.size = Vector2(2, 92)
	note.add_child(nb)
	var nt := UIKit.body_label("情报参谋注记：%s" % ("选择左侧邦国查看地理板块与态势。" if nid == "" else "%s疆域已入舆图；陆桥商路与行军路线以此为准。" % nm), UIKit.TEXT_DIM, 11)
	nt.position = Vector2(12, 10)
	nt.size = Vector2(190, 72)
	nt.custom_minimum_size = Vector2(190, 0)
	note.add_child(nt)
	var go := UIKit.cta_button("下达进军令", "A", 210, 42)
	go.position = Vector2(16, 494)
	go.disabled = nid == ""
	go.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/deploy.tscn"))
	p.add_child(go)
	var row := HBoxContainer.new()
	row.position = Vector2(16, 544)
	row.add_theme_constant_override("separation", 6)
	p.add_child(row)
	var b1 := UIKit.ghost_button("返回全图", 102, 30)
	b1.pressed.connect(func(): _select("", "全图 · 十国"))
	row.add_child(b1)
	var b2 := UIKit.ghost_button("陆桥委托", 102, 30)
	b2.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub/quests.tscn"))
	row.add_child(b2)
	var ap := UIKit.mono("战术执行预算：%d 银" % GameState.silver, 8, UIKit.TEXT_FAINT, false)
	ap.position = Vector2(16, 586)
	p.add_child(ap)
