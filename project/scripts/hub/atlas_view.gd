extends Control
## v8.7 — playable atlas (跑图). Two levels on the Stitch 03 layout:
##   世界 (v8_atlas_world: 10 nations + 陆桥, party region, cross-border lanes)
##   疆域 (nation plate: settlements as interactive nodes, roads, border gateways, party token, quest/mainline markers)
## Bottom strip = travel HUD (route preview, days / rations / tolls / danger, 启程 / 进城 / 迎战, road log).
## Right column = settlement / region profile. Event + encounter modals drive World.choose_event / launch_encounter.

const _Atlas = preload("res://scripts/art/atlas_art.gd")
const MAP := Rect2(200, 64, 800, 450)
const CITY_SCENE := "res://scenes/hub/city.tscn"
const CASTLE_SCENE := "res://scenes/hub/castle_hub.tscn"
const NODE_PX := {"capital": 36, "castle": 34, "city": 30, "port": 30, "fortress": 28, "town": 26, "village": 24}
const GLYPH := {"capital": "都", "castle": "堡", "city": "城", "port": "港", "fortress": "塞", "town": "镇", "village": "村"}
const STEP_SEC := 0.42
const BIOME_ZH := {"archive": "书院", "fog": "雾谷", "ford": "渡口", "forge": "工坊", "fort": "城寨", "harbor": "港湾", "hill": "丘陵", "marsh": "沼泽", "nightcamp": "夜营", "pass": "关隘", "plain": "平原", "shrine": "神社", "snow": "雪原", "urban": "街巷"}

var _view := ""                 # "" = world, else nation id
var _sel := ""                  # selected node id (nation view) / region id (world view)
var _preview: Dictionary = {}
var _busy := false
var _clip: Control
var _plate: TextureRect
var _roads: Control
var _layer: Control
var _token: Panel
var _node_btn: Dictionary = {}  # id -> Button
var _left: Control
var _right: Control
var _hud: Control
var _modal: Control
var _top: Control
var _toast: Label
var _pulse_t := 0.0
var _map_content: Control
var _map_router := InputRouter.new()
var _map_zoom := 1.0
var _map_pan := Vector2.ZERO

func _ready() -> void:
	UIKit.void_bg(self)
	_build_frame()
	World.world_changed.connect(_on_world_changed)
	var start_view := World.nation_of(World.pos)
	if GameState.has_meta("atlas_view"):
		start_view = str(GameState.get_meta("atlas_view"))
		GameState.remove_meta("atlas_view")
	_show_view(start_view if start_view != "" else "ashbanner")
	_select_node(World.pos)
	UIKit.footer_bar(self, [["A", "选定 / 启程"], ["Y", "进入城镇"], ["X", "世界 / 疆域"], ["ESC", "返回"]], "OVERWORLD · FROST_TACTICAL v8.7")
	UIFX.page_enter(self)
	UIFX.wire_tree(self)
	call_deferred("_resume_state")

func _exit_tree() -> void:
	if World.world_changed.is_connected(_on_world_changed):
		World.world_changed.disconnect(_on_world_changed)

func _process(dt: float) -> void:
	_pulse_t += dt
	if _map_router and _clip and _modal and _modal.get_children().is_empty() and not _busy:
		for g in _map_router.poll(Time.get_ticks_msec()):
			_apply_map_gesture(g)
	if _roads and not _preview.is_empty():
		_roads.queue_redraw()

# ── frame ─────────────────────────────────────────────
func _build_frame() -> void:
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	_refresh_top()
	var mp := UIKit.panel_at(self, Rect2(MAP.position - Vector2(2, 2), MAP.size + Vector2(4, 4)), 10)
	mp.name = "MapFrame"
	_clip = Control.new()
	_clip.name = "MapClip"
	_clip.position = MAP.position
	_clip.size = MAP.size
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_map_content = Control.new()
	_map_content.name = "MapContent"
	_map_content.size = MAP.size
	_map_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_map_content)
	_plate = TextureRect.new()
	_plate.name = "Plate"
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_SCALE
	_plate.size = MAP.size
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_content.add_child(_plate)
	var veil := ColorRect.new()
	veil.color = Color(UIKit.BG, 0.18)
	veil.size = MAP.size
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_content.add_child(veil)
	_roads = Control.new()
	_roads.name = "Roads"
	_roads.size = MAP.size
	_roads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roads.draw.connect(_draw_roads)
	_map_content.add_child(_roads)
	_layer = Control.new()
	_layer.name = "Nodes"
	_layer.size = MAP.size
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_content.add_child(_layer)
	_token = Panel.new()
	_token.name = "PartyToken"
	_token.size = Vector2(26, 26)
	_token.pivot_offset = Vector2(13, 13)
	var ts := UIKit.flat_box(Color(UIKit.ACCENT, 0.95), Color.WHITE, 13, 2)
	ts.shadow_color = Color(UIKit.ACCENT, 0.55)
	ts.shadow_size = 10
	_token.add_theme_stylebox_override("panel", ts)
	_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tg := UIKit.title_label("旗", 13, UIKit.ON_ACCENT)
	tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tg.size = Vector2(26, 26)
	_token.add_child(tg)
	_map_content.add_child(_token)
	UIFX.breathe(_token, 0.05, 1.8)
	_toast = UIKit.body_label("", UIKit.TEXT, 12)
	_toast.name = "Toast"
	_toast.autowrap_mode = TextServer.AUTOWRAP_OFF
	_toast.position = Vector2(MAP.position.x + 14, MAP.position.y + MAP.size.y - 34)
	var tst := UIKit.flat_box(Color(0.03, 0.04, 0.06, 0.86), Color(UIKit.ACCENT, 0.4), 6)
	tst.content_margin_top = 4
	tst.content_margin_bottom = 4
	tst.content_margin_left = 10
	tst.content_margin_right = 10
	_toast.add_theme_stylebox_override("normal", tst)
	_toast.visible = false
	add_child(_toast)
	_left = Control.new()
	_left.name = "LeftColumn"
	add_child(_left)
	_right = Control.new()
	_right.name = "RightColumn"
	add_child(_right)
	_hud = Control.new()
	_hud.name = "TravelHUD"
	add_child(_hud)
	_modal = Control.new()
	_modal.name = "Modal"
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_modal)

func _refresh_top() -> void:
	for c in _top.get_children():
		c.queue_free()
	var here: Dictionary = World.node(World.pos)
	var fpd := World.food_per_day()
	var food_days := GameState.food / maxi(1, fpd)
	UIKit.top_bar(_top, "世界舆图 · 跑图", [
		["位置", str(here.get("name", "—"))],
		["历", World.date_label(), UIKit.TEXT_DIM],
		["银", str(GameState.silver), UIKit.ACCENT],
		["粮", "%d（%d 日）" % [GameState.food, food_days], UIKit.OK if food_days >= 6 else UIKit.DANGER],
		["士气", str(GameState.morale), UIKit.OK if GameState.morale >= 50 else UIKit.DANGER],
	], "返回城堡", _back)

# ── views ─────────────────────────────────────────────
func _show_view(v: String) -> void:
	_view = v
	var path := _Atlas.world_plate() if v == "" else str(_Atlas.plate_path(str(World.nations.get(v, {}).get("plate", "v8_atlas_nation_" + v))))
	if path != "":
		_plate.texture = load(path)
	_plate.modulate = Color(0.78, 0.84, 0.94) if v == "" else Color(0.86, 0.9, 0.98)
	_build_nodes()
	_render_left()
	_place_token(false)
	_roads.queue_redraw()
	UIFX.fade_in(_layer, 0.22)

func _np(id: String) -> Vector2:
	## local map position of a node in the current view
	if _view == "":
		var nat: Dictionary = World.nations.get(World.nation_of(id), {})
		var w: Array = nat.get("wpos", [0.5, 0.5])
		return Vector2(float(w[0]) * MAP.size.x, float(w[1]) * MAP.size.y)
	var p: Array = World.node(id).get("pos", [0.5, 0.5])
	return Vector2(float(p[0]) * MAP.size.x, float(p[1]) * MAP.size.y)

func _region_pos(nid: String) -> Vector2:
	var w: Array = World.nations.get(nid, {}).get("wpos", [0.5, 0.5])
	return Vector2(float(w[0]) * MAP.size.x, float(w[1]) * MAP.size.y)

func _build_nodes() -> void:
	for c in _layer.get_children():
		c.queue_free()
	_node_btn.clear()
	var markers: Dictionary = World.quest_markers()
	var mm: Dictionary = World.mainline_marker()
	if _view == "":
		for nid in World.nation_ids():
			_add_region_button(str(nid))
		return
	for n in World.nodes_in(_view):
		_add_node_button(n, markers, mm)
	# border gateways: roads leaving this region
	for n in World.nodes_in(_view):
		for r in World.roads_from(str(n.id)):
			var o := World.other_end(r, str(n.id))
			if World.nation_of(o) != _view:
				_add_gateway(str(n.id), o, r)

func _add_region_button(nid: String) -> void:
	var nat: Dictionary = World.nations.get(nid, {})
	var b := Button.new()
	b.name = "Region_" + nid
	b.text = str(nat.get("name", nid))
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 13)
	var here := World.nation_of(World.pos) == nid
	var rep := World.nation_rep(nid)
	var col: Color = UIKit.ACCENT if here else (UIKit.OK if rep >= 30 else (UIKit.TEXT if rep >= 0 else UIKit.DANGER))
	_style_node(b, col, here, 8)
	var rh := _fit_hit(30.0)
	b.custom_minimum_size = Vector2(b.get_minimum_size().x + 6, rh)
	b.size = Vector2(b.get_minimum_size().x + 6, rh)
	b.position = _region_pos(nid) - b.size * 0.5
	var marker := CKCourt.latest_marker(nid)
	var tip := "%s · 声望 %d（%s）· 聚落 %d" % [nat.get("name", ""), rep, World.rep_tier_name(rep), World.nodes_in(nid).size()]
	if not marker.is_empty():
		tip += " · 朝报：%s" % str(marker.get("text", ""))
	b.tooltip_text = tip
	_bind_press(b, func(): _on_region_pressed(nid), func(): _info_region(nid))
	_layer.add_child(b)
	_node_btn[nid] = b
	_stamp_court_mark(b, marker)
	var sub := UIKit.mono("%s · %d" % [World.rep_tier_name(rep), World.nodes_in(nid).size()], 8, UIKit.TEXT_DIM, false)
	sub.position = b.position + Vector2(4, 33)
	sub.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	sub.add_theme_constant_override("outline_size", 3)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(sub)

func _court_glyph(kind: String) -> String:
	return {"birth": "生", "death": "丧", "succession": "嗣", "crisis": "危", "marriage": "婚", "recall": "归"}.get(kind, "报")

func _court_color(kind: String) -> Color:
	if kind == "birth":
		return UIKit.OK
	if kind == "death" or kind == "crisis":
		return UIKit.DANGER
	return UIKit.ACCENT

func _stamp_court_mark(b: Button, marker: Dictionary) -> void:
	if marker.is_empty():
		return
	var kind := str(marker.get("kind", ""))
	var mark := Label.new()
	mark.name = "CourtMark"
	mark.text = _court_glyph(kind)
	mark.position = Vector2(b.size.x - 16, -6)
	mark.add_theme_font_size_override("font_size", 12)
	mark.add_theme_color_override("font_color", _court_color(kind))
	mark.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 1))
	mark.add_theme_constant_override("outline_size", 4)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.tooltip_text = str(marker.get("text", ""))
	b.add_child(mark)
	UIFX.breathe(mark, 0.06, 1.8)

func _style_node(b: Button, col: Color, filled: bool, radius: int, pad: int = 6) -> void:
	var n := UIKit.flat_box(Color(col, 0.92) if filled else Color(0.03, 0.04, 0.06, 0.82), Color(col, 0.9), radius, 2 if filled else 1)
	var h := UIKit.flat_box(Color(UIKit.ACCENT, 0.28), UIKit.ACCENT_HOVER, radius, 2)
	h.shadow_color = Color(UIKit.ACCENT, 0.45)
	h.shadow_size = 8
	var p := UIKit.flat_box(Color(UIKit.ACCENT_PRESSED, 0.9), Color.WHITE, radius, 2)
	var f := UIKit.flat_box(Color(0, 0, 0, 0), UIKit.FOCUS_RING, radius + 3, 2)
	f.draw_center = false
	f.expand_margin_left = 3
	f.expand_margin_right = 3
	f.expand_margin_top = 3
	f.expand_margin_bottom = 3
	var d := UIKit.flat_box(UIKit.DISABLED_BG, UIKit.DISABLED_BORDER, radius, 1)
	for s in [n, h, p, d]:
		s.content_margin_left = pad
		s.content_margin_right = pad
		s.content_margin_top = mini(pad, 2)
		s.content_margin_bottom = mini(pad, 2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("focus", f)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_color_override("font_color", UIKit.ON_ACCENT if filled else col)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", UIKit.ON_ACCENT if filled else Color.WHITE)
	b.add_theme_color_override("font_disabled_color", UIKit.DISABLED_TEXT)

func _add_node_button(n: Dictionary, markers: Dictionary, mm: Dictionary) -> void:
	var id := str(n.id)
	var kind := str(n.kind)
	var px := int(_fit_hit(float(NODE_PX.get(kind, 20))))
	var b := Button.new()
	b.name = "Node_" + id
	b.text = ""
	b.focus_mode = Control.FOCUS_ALL
	var here := id == World.pos
	var seen := World.visited.has(id)
	var col: Color = UIKit.ACCENT if (here or seen) else UIKit.TEXT_DIM
	if kind == "fortress":
		col = Color("#B8C6FF") if seen or here else Color("#7F8AA8")
	_style_node(b, col, here, px / 2 if kind != "fortress" else 5, 0)
	b.custom_minimum_size = Vector2(px, px)
	b.size = Vector2(px, px)
	b.position = _np(id) - b.size * 0.5
	b.tooltip_text = "%s · %s" % [n.get("name", id), World.kind_zh(id)]
	b.disabled = _busy
	_bind_press(b, func(): _on_node_pressed(id), func(): _select_node(id))
	b.focus_entered.connect(func(): if not _busy: _select_node(id))
	_layer.add_child(b)
	b.size = Vector2(px, px)
	b.position = _np(id) - b.size * 0.5
	var gl := UIKit.title_label(str(GLYPH.get(kind, "·")), 15 if px >= 30 else 13, UIKit.ON_ACCENT if here else col)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gl.offset_top = -1
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(gl)
	_node_btn[id] = b
	var nm := UIKit.body_label(str(n.get("name", id)), UIKit.TEXT if (here or seen) else UIKit.TEXT_DIM, 11)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	nm.add_theme_constant_override("outline_size", 4)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ms := nm.get_minimum_size()
	nm.position = _np(id) + Vector2(-ms.x * 0.5, px * 0.5 + 1)
	nm.position.x = clampf(nm.position.x, 2, MAP.size.x - ms.x - 2)
	if nm.position.y + ms.y > MAP.size.y - 2:
		nm.position.y = _np(id).y - px * 0.5 - ms.y - 1
	_layer.add_child(nm)
	# overlays: quest objective ◆ / turn-in ✓ / mainline ★
	var badges: Array = []
	for mk in markers.get(id, []):
		badges.append(["✓", UIKit.OK] if str(mk.kind) == "turnin" else ["◆", UIKit.DANGER])
	if str(mm.get("node", "")) == id:
		badges.append(["★", UIKit.EMBER])
	if id == str(World.nations.get(_view, {}).get("capital", "")):
		var marker := CKCourt.latest_marker(_view)
		if not marker.is_empty():
			badges.append([_court_glyph(str(marker.get("kind", ""))), _court_color(str(marker.get("kind", "")))])
	var bx := _np(id).x + px * 0.5 - 4
	for bd in badges:
		var bl := UIKit.title_label(str(bd[0]), 12, bd[1])
		bl.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 1))
		bl.add_theme_constant_override("outline_size", 4)
		bl.position = Vector2(bx, _np(id).y - px * 0.5 - 12)
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(bl)
		UIFX.breathe(bl, 0.08, 1.4)
		bx += 12

func _gate_dir(from_id: String, to_id: String) -> Vector2:
	var a := _region_pos(World.nation_of(from_id))
	var b := _region_pos(World.nation_of(to_id))
	var d := (b - a)
	if d.length() < 1.0:
		return Vector2.RIGHT
	return d.normalized()

func _gate_pos(from_id: String, to_id: String) -> Vector2:
	## where the road leaves the plate: ray from the node toward the neighbour region, clipped to an inset rect
	var p := _np(from_id)
	var d := _gate_dir(from_id, to_id)
	var inset := Rect2(Vector2(54, 16), MAP.size - Vector2(108, 32))
	var t := 99999.0
	if absf(d.x) > 0.001:
		t = minf(t, ((inset.end.x if d.x > 0 else inset.position.x) - p.x) / d.x)
	if absf(d.y) > 0.001:
		t = minf(t, ((inset.end.y if d.y > 0 else inset.position.y) - p.y) / d.y)
	t = maxf(t, 40.0)
	var q := p + d * t
	return Vector2(clampf(q.x, inset.position.x, inset.end.x), clampf(q.y, inset.position.y, inset.end.y))

func _add_gateway(from_id: String, to_id: String, r: Dictionary) -> void:
	var nat: Dictionary = World.nations.get(World.nation_of(to_id), {})
	var b := Button.new()
	b.name = "Gate_%s_%s" % [from_id, to_id]
	b.text = ("⛵ " if str(r.kind) == "sea" else "⇢ ") + str(nat.get("name", ""))
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 10)
	_style_node(b, Color("#B8C6FF"), false, 6)
	var gh := _fit_hit(22.0)
	b.custom_minimum_size = Vector2(maxf(b.get_minimum_size().x, gh), gh)
	b.size = Vector2(maxf(b.get_minimum_size().x, gh), gh)
	b.position = _gate_pos(from_id, to_id) - b.size * 0.5
	# stack gateways that land on the same spot
	var dir_y := 26.0 if b.position.y < MAP.size.y * 0.5 else -26.0
	for _pass in 6:
		var hit := false
		for k in _node_btn.keys():
			var ob: Button = _node_btn[k]
			var orect := Rect2(ob.position, ob.size).grow(2)
			if not str(k).begins_with("gate_"):
				orect = orect.grow_individual(30, 4, 30, 18)  # node + its name label
			if orect.intersects(Rect2(b.position, b.size)):
					b.position.y += dir_y
					hit = true
		if not hit:
			break
	b.position.y = clampf(b.position.y, 2, MAP.size.y - b.size.y - 2)
	b.position.x = clampf(b.position.x, 2, MAP.size.x - b.size.x - 2)
	b.tooltip_text = "%s · %s %d 日 · %s" % [World.node(to_id).get("name", to_id), "海路" if str(r.kind) == "sea" else "过境", int(r.days), "关税 %d 银" % World.toll_for(World.nation_of(to_id)) if str(r.kind) == "border" else "船资 %d 银" % int(r.get("fare", 30))]
	b.disabled = _busy
	_bind_press(b, func(): _on_gateway(to_id), func(): _info_gateway(to_id))
	_layer.add_child(b)
	_node_btn["gate_" + to_id] = b

# ── drawing ───────────────────────────────────────────
func _draw_roads() -> void:
	var c := _roads
	var route_pairs := {}
	if not _preview.is_empty():
		var path: Array = _preview.get("path", [])
		for i in path.size() - 1:
			route_pairs["%s|%s" % [path[i], path[i + 1]]] = true
			route_pairs["%s|%s" % [path[i + 1], path[i]]] = true
	if _view == "":
		var seen := {}
		for r in World.data.get("roads", []):
			var na := World.nation_of(str(r.a))
			var nb := World.nation_of(str(r.b))
			if na == nb:
				continue
			var key := "%s|%s" % [na, nb] if na < nb else "%s|%s" % [nb, na]
			if seen.has(key):
				continue
			seen[key] = true
			var col := Color("#B8C6FF", 0.55) if str(r.kind) == "border" else Color(UIKit.ACCENT, 0.35)
			_dashed(c, _region_pos(na), _region_pos(nb), col, 2.0, 10.0 if str(r.kind) == "sea" else 6.0)
		if not _preview.is_empty():
			var path2: Array = _preview.get("path", [])
			for i in path2.size() - 1:
				var ra := World.nation_of(str(path2[i]))
				var rb := World.nation_of(str(path2[i + 1]))
				if ra != rb:
					c.draw_line(_region_pos(ra), _region_pos(rb), Color(UIKit.ACCENT, 0.9), 3.0, true)
		return
	for n in World.nodes_in(_view):
		var a := str(n.id)
		for r in World.roads_from(a):
			var b := World.other_end(r, a)
			var on_route := route_pairs.has("%s|%s" % [a, b])
			if World.nation_of(b) != _view:
				var g := _gate_pos(a, b)
				_dashed(c, _np(a), g, Color(UIKit.ACCENT, 0.95) if on_route else Color("#B8C6FF", 0.6), 2.0 if on_route else 1.5, 5.0)
				continue
			if a > b:
				continue
			var danger := int(r.get("danger", 1))
			var col: Color = Color(UIKit.TEXT, 0.30) if danger <= 1 else (Color(UIKit.ACCENT, 0.32) if danger == 2 else Color(UIKit.DANGER, 0.42))
			var w := 2.0 if danger <= 2 else 2.5
			if on_route:
				col = Color(UIKit.ACCENT, 0.95)
				w = 3.5
			c.draw_line(_np(a), _np(b), Color(0.02, 0.03, 0.05, 0.55), w + 2.5, true)
			c.draw_line(_np(a), _np(b), col, w, true)
			if danger >= 3:
				var mid := (_np(a) + _np(b)) * 0.5
				c.draw_circle(mid, 3.0, Color(UIKit.DANGER, 0.8))
	# animated route chevrons
	if not _preview.is_empty():
		var path3: Array = _preview.get("path", [])
		for i in path3.size() - 1:
			var pa := str(path3[i])
			var pb := str(path3[i + 1])
			if World.nation_of(pa) != _view:
				continue
			var p0 := _np(pa)
			var p1 := _gate_pos(pa, pb) if World.nation_of(pb) != _view else _np(pb)
			var t := fmod(_pulse_t * 0.6, 1.0)
			c.draw_circle(p0.lerp(p1, t), 3.5, Color.WHITE)

func _dashed(c: Control, a: Vector2, b: Vector2, col: Color, w: float, dash: float) -> void:
	var L := a.distance_to(b)
	if L < 1.0:
		return
	var d := (b - a) / L
	var t := 0.0
	while t < L:
		c.draw_line(a + d * t, a + d * minf(t + dash, L), col, w, true)
		t += dash * 2.0

func _place_token(anim: bool, to_id: String = "") -> void:
	var id := to_id if to_id != "" else World.pos
	var vis := _view == "" or World.nation_of(id) == _view
	_token.visible = vis
	if not vis:
		return
	var p := _np(id) - _token.size * 0.5 + (Vector2(0, -24) if _view != "" else Vector2(0, -30))
	if anim:
		var tw := create_tween()
		tw.tween_property(_token, "position", p, STEP_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_token.position = p

# ── left column: regions + party ──────────────────────
func _render_left() -> void:
	for c in _left.get_children():
		c.queue_free()
	var lp := UIKit.panel_at(_left, Rect2(16, 64, 176, 620), 10)
	var eh := UIKit.mono("REGIONS 11", 9, UIKit.ACCENT)
	eh.position = Vector2(14, 10)
	lp.add_child(eh)
	var v := VBoxContainer.new()
	v.position = Vector2(6, 28)
	v.add_theme_constant_override("separation", 1)
	lp.add_child(v)
	var wb := UIKit.index_button("00", "世界全图", 164)
	UIKit.compact(wb, 28)
	wb.custom_minimum_size = Vector2(164, 28)
	wb.add_theme_font_size_override("font_size", 12)
	wb.name = "ViewWorld"
	wb.pressed.connect(func(): _show_view(""))
	if _view == "":
		wb.add_theme_color_override("font_color", UIKit.ACCENT)
	v.add_child(wb)
	var i := 0
	for nid in World.nation_ids():
		i += 1
		var nat: Dictionary = World.nations.get(nid, {})
		var rep := World.nation_rep(str(nid))
		var here := World.nation_of(World.pos) == str(nid)
		var b := UIKit.index_button("%02d" % i, "%s%s" % [nat.get("name", nid), "  ◉" if here else ""], 164)
		UIKit.compact(b, 28)
		b.custom_minimum_size = Vector2(164, 28)
		b.add_theme_font_size_override("font_size", 12)
		b.name = "View_" + str(nid)
		b.tooltip_text = "声望 %d · %s" % [rep, World.rep_tier_name(rep)]
		var nid_s := str(nid)
		b.pressed.connect(func(): _show_view(nid_s))
		if _view == str(nid):
			b.add_theme_color_override("font_color", UIKit.ACCENT)
		v.add_child(b)
	# party box
	var pb := UIKit.panel_at(lp, Rect2(8, 382, 160, 228), 8)
	pb.add_theme_stylebox_override("panel", UIKit.flat_box(Color(UIKit.ACCENT, 0.05), Color(UIKit.ACCENT, 0.25), 8))
	var pt := UIKit.mono("PARTY", 9, UIKit.ACCENT)
	pt.position = Vector2(10, 8)
	pb.add_child(pt)
	var kv := VBoxContainer.new()
	kv.position = Vector2(10, 26)
	kv.add_theme_constant_override("separation", 3)
	pb.add_child(kv)
	kv.add_child(UIKit.kv_row("编制", "%d 人" % World.party_size(), UIKit.TEXT, 140))
	kv.add_child(UIKit.kv_row("日耗粮", "%d" % World.food_per_day(), UIKit.TEXT, 140))
	kv.add_child(UIKit.kv_row("货舱", "%d / %d" % [World.cargo_used(), World.cargo_cap()], UIKit.TEXT, 140))
	kv.add_child(UIKit.kv_row("委托", "%d / %d" % [World.active.size(), int(World.rules.get("active_limit", 5))], UIKit.ACCENT, 140))
	kv.add_child(UIKit.kv_row("战力层级", "T%d" % World.world_tier(), UIKit.TEXT, 140))
	var ql := VBoxContainer.new()
	ql.position = Vector2(10, 128)
	ql.add_theme_constant_override("separation", 1)
	pb.add_child(ql)
	var shown := 0
	for q in World.active:
		if shown >= 4:
			break
		shown += 1
		var mark := "✓" if str(q.state) == "ready" else "◆"
		var l := UIKit.body_label("%s %s" % [mark, q.title], UIKit.OK if str(q.state) == "ready" else UIKit.TEXT_DIM, 10)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		l.custom_minimum_size = Vector2(140, 0)
		ql.add_child(l)
	if World.active.is_empty():
		var el := UIKit.body_label("暂无委托 · 进城看委托榜", UIKit.TEXT_FAINT, 10)
		el.autowrap_mode = TextServer.AUTOWRAP_OFF
		ql.add_child(el)
	var ab := UIKit.ghost_button("出战编成", 140, 26)
	ab.position = Vector2(10, 196)
	ab.pressed.connect(func(): _goto("res://scenes/hub/deploy.tscn"))
	pb.add_child(ab)

# ── right column: profile ─────────────────────────────
func _render_right() -> void:
	for c in _right.get_children():
		c.queue_free()
	var p := UIKit.panel_at(_right, Rect2(1008, 64, 256, 620), 10)
	var top := ColorRect.new()
	top.color = UIKit.ACCENT
	top.size = Vector2(256, 2)
	p.add_child(top)
	if _view == "" and World.nations.has(_sel):
		_render_region_profile(p, _sel)
		return
	if not World.nodes.has(_sel):
		return
	var n: Dictionary = World.node(_sel)
	var nat: Dictionary = World.nations.get(str(n.nation), {})
	var el := UIKit.mono("%s // %s" % [str(nat.get("en", "")), World.kind_zh(_sel)], 9, UIKit.TEXT_FAINT, false)
	el.position = Vector2(16, 14)
	p.add_child(el)
	var t := UIKit.title_label(str(n.get("name", _sel)), 20)
	t.position = Vector2(16, 30)
	p.add_child(t)
	var chips := HBoxContainer.new()
	chips.position = Vector2(16, 62)
	chips.add_theme_constant_override("separation", 4)
	p.add_child(chips)
	chips.add_child(UIKit.tag_chip(str(nat.get("name", "")), UIKit.ACCENT))
	chips.add_child(UIKit.tag_chip("规模 %s" % "▮".repeat(int(n.get("size", 1))), UIKit.TEXT_DIM))
	if _sel == World.pos:
		chips.add_child(UIKit.tag_chip("驻扎", UIKit.OK, true))
	elif World.visited.has(_sel):
		chips.add_child(UIKit.tag_chip("到访", UIKit.TEXT_DIM))
	# vignette (farm plate or nation-plate crop)
	var th := Control.new()
	th.position = Vector2(16, 88)
	th.size = Vector2(224, 112)
	th.clip_contents = true
	p.add_child(th)
	_fill_vignette(th, _sel)
	var kv := VBoxContainer.new()
	kv.position = Vector2(16, 208)
	kv.add_theme_constant_override("separation", 3)
	p.add_child(kv)
	var rep := World.rep_of(_sel)
	kv.add_child(UIKit.kv_row("城声望", "%d · %s" % [rep, World.rep_tier_name(rep)], UIKit.ACCENT, 224))
	kv.add_child(UIKit.kv_row("特产", str(n.get("specialty", "")), UIKit.TEXT, 224))
	var prod: Array = []
	for g in n.get("produce", []):
		prod.append(World.good_name(str(g)))
	var dem: Array = []
	for g in n.get("demand", []):
		dem.append(World.good_name(str(g)))
	kv.add_child(UIKit.kv_row("出产", "、".join(prod) if not prod.is_empty() else "—", UIKit.OK, 224))
	kv.add_child(UIKit.kv_row("求购", "、".join(dem) if not dem.is_empty() else "—", UIKit.EMBER, 224))
	var lore := UIKit.body_label(str(n.get("lore", "")), UIKit.TEXT_DIM, 11)
	lore.position = Vector2(16, 296)
	lore.size = Vector2(224, 84)
	lore.custom_minimum_size = Vector2(224, 0)
	lore.clip_text = true
	p.add_child(lore)
	# quests here
	var qy := 384.0
	for mk in World.quest_markers().get(_sel, []):
		var q: Dictionary = mk.quest
		var ql := UIKit.body_label("%s %s" % ["✓ 交付" if str(mk.kind) == "turnin" else "◆ 目标", q.title], UIKit.OK if str(mk.kind) == "turnin" else UIKit.DANGER, 11)
		ql.autowrap_mode = TextServer.AUTOWRAP_OFF
		ql.clip_text = true
		ql.size = Vector2(224, 16)
		ql.position = Vector2(16, qy)
		p.add_child(ql)
		qy += 17
	var mm: Dictionary = World.mainline_marker()
	if str(mm.get("node", "")) == _sel:
		var ml := UIKit.body_label("★ %s（在此展开）" % mm.label, UIKit.EMBER, 11)
		ml.autowrap_mode = TextServer.AUTOWRAP_OFF
		ml.position = Vector2(16, qy)
		p.add_child(ml)
	# actions
	var go := UIKit.cta_button("启程前往", "A", 224, 40)
	go.name = "GoButton"
	go.position = Vector2(16, 470)
	go.disabled = _busy or _sel == World.pos or _preview.is_empty() or not bool(_preview.get("ok", false))
	go.pressed.connect(_start_travel)
	p.add_child(go)
	var enter := UIKit.ghost_button("进入%s" % ("城堡" if str(n.kind) == "castle" else World.kind_zh(_sel)), 108, 32)
	enter.name = "EnterButton"
	enter.position = Vector2(16, 518)
	enter.disabled = _busy or _sel != World.pos or not World.encounter.is_empty()
	enter.pressed.connect(_enter_here)
	p.add_child(enter)
	var ch := UIKit.ghost_button("主线章节", 108, 32)
	ch.name = "ChapterButton"
	ch.position = Vector2(132, 518)
	ch.disabled = _busy or str(mm.get("node", "")) != _sel or _sel != World.pos or not bool(mm.get("exists", false))
	ch.tooltip_text = "主线在 ★ 标记处展开"
	ch.pressed.connect(func(): _goto(str(mm.path)))
	p.add_child(ch)
	var eng := UIKit.ghost_button("进剿目标", 224, 28)
	eng.name = "EngageButton"
	eng.position = Vector2(16, 556)
	var engage_q := ""
	for q2 in World.active:
		if str(q2.state) == "active" and str(q2.kind) in ["hunt", "defend"] and str(q2.target) == _sel:
			engage_q = str(q2.id)
	eng.disabled = _busy or engage_q == "" or _sel != World.pos
	eng.pressed.connect(func():
		var e: Dictionary = World.quest_engage(engage_q)
		if not e.is_empty():
			_show_encounter_modal(e))
	p.add_child(eng)
	var ap := UIKit.mono("关税 %d 银 · %s" % [World.toll_for(str(n.nation)), str(nat.get("smith", ""))], 8, UIKit.TEXT_FAINT, false)
	ap.position = Vector2(16, 596)
	p.add_child(ap)

func _render_region_profile(p: Panel, nid: String) -> void:
	var nat: Dictionary = World.nations.get(nid, {})
	var el := UIKit.mono("NATION PROFILE // %s" % str(nat.get("en", "")), 9, UIKit.TEXT_FAINT, false)
	el.position = Vector2(16, 14)
	p.add_child(el)
	var t := UIKit.title_label(str(nat.get("name", nid)), 22)
	t.position = Vector2(16, 30)
	p.add_child(t)
	var th := Control.new()
	th.position = Vector2(16, 70)
	th.size = Vector2(224, 126)
	th.clip_contents = true
	p.add_child(th)
	var path := _Atlas.plate_path(str(nat.get("plate", "")))
	if path != "":
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size = th.size
		th.add_child(tr)
	var kv := VBoxContainer.new()
	kv.position = Vector2(16, 206)
	kv.add_theme_constant_override("separation", 4)
	p.add_child(kv)
	var rep := World.nation_rep(nid)
	kv.add_child(UIKit.kv_row("邦交声望", "%d · %s" % [rep, World.rep_tier_name(rep)], UIKit.ACCENT, 224))
	kv.add_child(UIKit.kv_row("聚落", "%d 处" % World.nodes_in(nid).size(), UIKit.TEXT, 224))
	kv.add_child(UIKit.kv_row("都城", str(World.node(str(nat.get("capital", ""))).get("name", "—")), UIKit.TEXT, 224))
	kv.add_child(UIKit.kv_row("过境关税", "%d 银" % World.toll_for(nid), UIKit.TEXT, 224))
	kv.add_child(UIKit.kv_row("名匠", str(nat.get("smith", "")), UIKit.TEXT, 224))
	var pv: Dictionary = World.travel_preview(str(nat.get("capital", "")))
	kv.add_child(UIKit.kv_row("至都城", "%d 日" % int(pv.get("days", 0)) if bool(pv.get("ok", false)) else "已在此", UIKit.TEXT, 224))
	var cl := UIKit.body_label(str(nat.get("culture", "")), UIKit.TEXT_DIM, 11)
	cl.position = Vector2(16, 348)
	cl.size = Vector2(224, 100)
	cl.custom_minimum_size = Vector2(224, 0)
	p.add_child(cl)
	var go := UIKit.cta_button("进入疆域", "A", 224, 40)
	go.name = "EnterRegion"
	go.position = Vector2(16, 470)
	go.pressed.connect(func(): _show_view(nid); _select_node(str(nat.get("capital", "")) if World.nation_of(World.pos) != nid else World.pos))
	p.add_child(go)

func _fill_vignette(th: Control, id: String) -> void:
	var farm := AtlasArt.city_plate(id)
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if farm != "":
		tr.texture = load(farm)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size = th.size
	else:
		var path := _Atlas.plate_path(str(World.nations.get(World.nation_of(id), {}).get("plate", "")))
		if path != "":
			tr.texture = load(path)
			# 4x zoomed crop of the painted plate around the settlement
			var p: Array = World.node(id).get("pos", [0.5, 0.5])
			var z := 4.0
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.size = Vector2(th.size.x * z, th.size.x * z * 9.0 / 16.0)
			tr.position = Vector2(th.size.x * 0.5 - float(p[0]) * tr.size.x, th.size.y * 0.5 - float(p[1]) * tr.size.y)
			tr.position = Vector2(clampf(tr.position.x, th.size.x - tr.size.x, 0), clampf(tr.position.y, th.size.y - tr.size.y, 0))
	th.add_child(tr)
	var ring := Panel.new()
	ring.size = th.size
	var rs := UIKit.flat_box(Color(0, 0, 0, 0), Color(UIKit.ACCENT, 0.4), 4)
	rs.draw_center = false
	ring.add_theme_stylebox_override("panel", rs)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	th.add_child(ring)

# ── bottom travel HUD ─────────────────────────────────
func _render_hud() -> void:
	for c in _hud.get_children():
		c.queue_free()
	var p := UIKit.panel_at(_hud, Rect2(200, 522, 800, 162), 10)
	var eh := UIKit.mono("TRAVEL // 行军推演", 9, UIKit.ACCENT)
	eh.position = Vector2(16, 10)
	p.add_child(eh)
	var lv := VBoxContainer.new()
	lv.position = Vector2(520, 10)
	lv.add_theme_constant_override("separation", 2)
	p.add_child(lv)
	var news_b := UIKit.ghost_button("朝报", 88, 44)
	news_b.name = "CourtNewsOpen"
	news_b.position = Vector2(400, 8)
	news_b.pressed.connect(func():
		Sfx.click()
		_goto("res://scenes/hub/court_news.tscn"))
	p.add_child(news_b)
	lv.add_child(UIKit.mono("ROAD LOG", 9, UIKit.TEXT_FAINT))
	for i in mini(6, World.travel_log.size()):
		var l := UIKit.body_label(str(World.travel_log[i]), UIKit.TEXT_DIM if i > 0 else UIKit.TEXT, 10)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		l.custom_minimum_size = Vector2(266, 0)
		l.size = Vector2(266, 14)
		lv.add_child(l)
	var hl := UIKit.hairline(Color(1, 1, 1, 0.07))
	hl.position = Vector2(506, 12)
	hl.size = Vector2(1, 138)
	p.add_child(hl)
	if not World.encounter.is_empty():
		var t := UIKit.title_label("⚔ %s" % World.encounter.label, 16, UIKit.DANGER)
		t.position = Vector2(16, 28)
		p.add_child(t)
		var d := UIKit.body_label("敌军拦路，必须迎战或败退。", UIKit.TEXT_DIM, 12)
		d.autowrap_mode = TextServer.AUTOWRAP_OFF
		d.position = Vector2(16, 58)
		p.add_child(d)
		var fb := UIKit.cta_button("迎战", "A", 160, 40)
		fb.name = "FightButton"
		fb.position = Vector2(16, 104)
		fb.pressed.connect(func(): _show_encounter_modal(World.encounter))
		p.add_child(fb)
		return
	if _preview.is_empty() or not bool(_preview.get("ok", false)):
		var here: Dictionary = World.node(World.pos)
		var t2 := UIKit.title_label("驻扎于 %s" % here.get("name", ""), 16)
		t2.position = Vector2(16, 28)
		p.add_child(t2)
		var d2 := UIKit.body_label("在地图上选择一处聚落查看路线；跨国经陆桥关隘，海港可走海路。", UIKit.TEXT_DIM, 12)
		d2.position = Vector2(16, 56)
		d2.size = Vector2(476, 40)
		d2.custom_minimum_size = Vector2(476, 0)
		p.add_child(d2)
		var tipy := 96.0
		for tp in World.tips.slice(0, 2):
			var tl := UIKit.body_label("情报：%s" % str(tp), UIKit.ACCENT, 11)
			tl.position = Vector2(16, tipy)
			tl.autowrap_mode = TextServer.AUTOWRAP_OFF
			tl.clip_text = true
			tl.size = Vector2(476, 16)
			p.add_child(tl)
			tipy += 18
		return
	var pv := _preview
	var pth: Array = pv.get("path", [])
	var dest: Dictionary = World.node(str(pth[pth.size() - 1]) if not pth.is_empty() else _sel)
	var t3 := UIKit.title_label("→ %s" % dest.get("name", ""), 16)
	t3.position = Vector2(16, 26)
	p.add_child(t3)
	var names: Array = []
	for id in pv.path:
		names.append(str(World.node(str(id)).get("name", id)))
	var chain := UIKit.body_label(" › ".join(names), UIKit.TEXT_DIM, 11)
	chain.position = Vector2(16, 52)
	chain.autowrap_mode = TextServer.AUTOWRAP_OFF
	chain.clip_text = true
	chain.size = Vector2(476, 16)
	p.add_child(chain)
	var stats := HBoxContainer.new()
	stats.position = Vector2(16, 74)
	stats.add_theme_constant_override("separation", 6)
	p.add_child(stats)
	stats.add_child(UIKit.res_chip("日程", "%d 日" % int(pv.days), UIKit.TEXT))
	stats.add_child(UIKit.res_chip("耗粮", str(pv.food), UIKit.DANGER if bool(pv.short_food) else UIKit.TEXT))
	var cost := int(pv.tolls) + int(pv.fare)
	stats.add_child(UIKit.res_chip("关税/船资", "%d 银" % cost, UIKit.DANGER if GameState.silver < cost else UIKit.TEXT))
	stats.add_child(UIKit.res_chip("险", "▮".repeat(int(pv.danger)) + "▯".repeat(maxi(0, 4 - int(pv.danger))), UIKit.DANGER if int(pv.danger) >= 3 else UIKit.ACCENT))
	var warn := ""
	if bool(pv.short_food):
		warn = "粮草不足以走完全程——断粮会每日损失士气。"
	elif not (pv.borders as Array).is_empty():
		warn = "过境：%s" % "、".join(pv.borders)
	if warn != "":
		var wl := UIKit.body_label(warn, UIKit.EMBER if bool(pv.short_food) else UIKit.TEXT_DIM, 11)
		wl.autowrap_mode = TextServer.AUTOWRAP_OFF
		wl.clip_text = true
		wl.size = Vector2(340, 16)
		wl.position = Vector2(16, 120)
		p.add_child(wl)
	var go := UIKit.cta_button("启程", "A", 120, 34)
	go.name = "HudGo"
	go.position = Vector2(376, 112)
	go.disabled = _busy or GameState.silver < int(pv.fare)
	go.pressed.connect(_start_travel)
	p.add_child(go)

# ── interaction ───────────────────────────────────────
func _fit_hit(visual: float) -> float:
	if not DeviceProfile.is_mobile():
		return visual
	return maxf(visual, minf(64.0, DeviceProfile.hit_px()))

func _bind_press(b: Button, on_tap: Callable, on_info: Callable) -> void:
	b.set_meta("ck_long", false)
	b.button_down.connect(func():
		if not is_instance_valid(b):
			return
		b.set_meta("ck_long", false)
		var timer := b.get_tree().create_timer(float(InputRouter.LONG_MS) / 1000.0)
		timer.timeout.connect(func():
			if is_instance_valid(b) and b.button_pressed:
				b.set_meta("ck_long", true)
				on_info.call()))
	b.pressed.connect(func():
		if bool(b.get_meta("ck_long")):
			b.set_meta("ck_long", false)
			return
		on_tap.call())

func _info_region(nid: String) -> void:
	_sel = nid
	_preview = {}
	var cap := str(World.nations.get(nid, {}).get("capital", ""))
	if World.nation_of(World.pos) != nid and cap != "":
		_preview = World.travel_preview(cap)
	_render_right()
	_render_hud()
	_roads.queue_redraw()

func _info_gateway(to_id: String) -> void:
	_show_toast("关口通往 %s" % str(World.node(to_id).get("name", to_id)), UIKit.ACCENT)

func _on_region_pressed(nid: String) -> void:
	if _sel == nid:
		_show_view(nid)
		_select_node(World.pos if World.nation_of(World.pos) == nid else str(World.nations.get(nid, {}).get("capital", "")))
		return
	_sel = nid
	_preview = {}
	var cap := str(World.nations.get(nid, {}).get("capital", ""))
	if World.nation_of(World.pos) != nid and cap != "":
		_preview = World.travel_preview(cap)
	_render_right()
	_render_hud()
	_roads.queue_redraw()

func _on_node_pressed(id: String) -> void:
	if _busy:
		return
	if _sel == id and id != World.pos and not _preview.is_empty() and bool(_preview.get("ok", false)):
		_start_travel()
		return
	if _sel == id and id == World.pos:
		_enter_here()
		return
	_select_node(id)

func _on_gateway(to_id: String) -> void:
	if _busy:
		return
	_show_view(World.nation_of(to_id))
	_select_node(to_id)

func _select_node(id: String) -> void:
	if _view == "":
		_sel = World.nation_of(id)
		_preview = {}
	else:
		_sel = id
		_preview = World.travel_preview(id) if id != World.pos else {}
	for k in _node_btn.keys():
		var b: Button = _node_btn[k]
		b.scale = Vector2(1.18, 1.18) if str(k) == id else Vector2.ONE
		b.pivot_offset = b.size * 0.5
	_render_right()
	_render_hud()
	_roads.queue_redraw()

func _enter_here() -> void:
	if _busy or not World.encounter.is_empty():
		return
	if str(World.node(World.pos).get("kind", "")) == "castle":
		_goto(CASTLE_SCENE)
		return
	GameState.set_meta("city_id", World.pos)
	_goto(CITY_SCENE)

func _start_travel() -> void:
	var target := _sel
	if _view == "" and World.nations.has(_sel):
		target = str(World.nations.get(_sel, {}).get("capital", ""))
	if _busy or target == "" or target == World.pos or not World.nodes.has(target):
		return
	var r: Dictionary = World.begin_travel(target)
	if not bool(r.get("ok", false)):
		_show_toast(str(r.get("msg", "无法启程")), UIKit.DANGER)
		UIFX.soft_deny(_right)
		return
	Sfx.play("cart_rattle")
	_run_travel()

func _set_busy(v: bool) -> void:
	_busy = v
	for k in _node_btn.keys():
		var b: Button = _node_btn[k]
		b.disabled = v
	_render_right()
	_render_hud()

func _run_travel() -> void:
	_set_busy(true)
	for _i in 64:
		if not World.is_traveling():
			break
		var path: Array = World.travel.get("route", [])
		var li := int(World.travel.get("leg", 0))
		var nxt := str(path[li + 1]) if li + 1 < path.size() else World.pos
		var info: Dictionary = World.step_travel()
		var arrived_at := str(info.get("pos", World.pos))
		if not info.get("event", {}).is_empty():
			_animate_leg_half(nxt)
			await get_tree().create_timer(STEP_SEC).timeout
			_set_busy(false)
			_show_event_modal(info.event)
			return
		if not info.get("encounter", {}).is_empty():
			_animate_leg(arrived_at)
			await get_tree().create_timer(STEP_SEC).timeout
			_set_busy(false)
			_show_encounter_modal(info.encounter)
			return
		_animate_leg(arrived_at)
		await get_tree().create_timer(STEP_SEC + 0.05).timeout
		if bool(info.get("arrived", false)):
			break
	_set_busy(false)
	_after_arrival()

func _animate_leg(to_id: String) -> void:
	if _view != "" and World.nation_of(to_id) != _view:
		_show_view(World.nation_of(to_id))
	_place_token(true, to_id)
	_refresh_top()

func _animate_leg_half(to_id: String) -> void:
	if not _token.visible or _view == "" or World.nation_of(to_id) != _view:
		return
	var p := (_np(World.pos) + _np(to_id)) * 0.5 - _token.size * 0.5 + Vector2(0, -24)
	var tw := create_tween()
	tw.tween_property(_token, "position", p, STEP_SEC).set_trans(Tween.TRANS_SINE)

func _after_arrival() -> void:
	_refresh_top()
	_build_nodes()
	_render_left()
	_place_token(false)
	_select_node(World.pos)
	var n: Dictionary = World.node(World.pos)
	var readies := 0
	for q in World.active:
		if str(q.state) == "ready" and World.can_turn_in(q, World.pos):
			readies += 1
	_show_toast("抵达 %s%s" % [n.get("name", ""), "  ·  %d 件委托可交付" % readies if readies > 0 else ""], UIKit.OK)

func _resume_state() -> void:
	## returning from a battle / load: re-open pending modal or continue a journey
	if not World.pending_event.is_empty():
		_show_event_modal(World.pending_event)
	elif not World.encounter.is_empty():
		_render_hud()
		_show_encounter_modal(World.encounter)
	elif World.is_traveling():
		_show_toast("继续行军……", UIKit.ACCENT)
		_run_travel()
	elif not World.travel_log.is_empty() and GameState.has_meta("atlas_after_battle"):
		GameState.remove_meta("atlas_after_battle")
		_show_toast(str(World.travel_log[0]), UIKit.ACCENT)

# ── modals ────────────────────────────────────────────
func _clear_modal() -> void:
	for c in _modal.get_children():
		c.queue_free()
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _modal_panel(h: float) -> Panel:
	_clear_modal()
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.025, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var p := UIKit.panel_at(_modal, Rect2(390, 360 - h * 0.5, 500, h), 14, true)
	p.add_theme_stylebox_override("panel", UIKit.glass(14, 0.92, true))
	UIFX.pop_in(p)
	return p

func _show_event_modal(ev: Dictionary) -> void:
	var opts: Array = ev.get("options", [])
	var p := _modal_panel(210 + 46 * opts.size())
	p.name = "EventModal"
	var el := UIKit.mono("ROAD EVENT // %s" % World.node(str(ev.get("b", ""))).get("name", ""), 9, UIKit.ACCENT)
	el.position = Vector2(24, 18)
	p.add_child(el)
	var t := UIKit.title_label(str(ev.get("title", "")), 24)
	t.position = Vector2(24, 36)
	p.add_child(t)
	var body := UIKit.body_label(str(ev.get("text", "")), UIKit.TEXT, 14)
	body.position = Vector2(24, 80)
	body.size = Vector2(452, 90)
	body.custom_minimum_size = Vector2(452, 0)
	p.add_child(body)
	var v := VBoxContainer.new()
	v.position = Vector2(24, 182)
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var first: Button = null
	for i in opts.size():
		var o: Dictionary = opts[i]
		var b := UIKit.index_button("%d" % (i + 1), str(o.get("label", "")), 452)
		b.custom_minimum_size = Vector2(452, 38)
		b.add_theme_font_size_override("font_size", 14)
		UIKit.compact(b, 38)
		b.name = "EventOpt%d" % i
		var fx: Dictionary = o.get("fx", {})
		b.tooltip_text = _fx_hint(fx)
		var idx := i
		b.pressed.connect(func(): _choose_event(idx))
		v.add_child(b)
		if first == null:
			first = b
	if first:
		first.call_deferred("grab_focus")

func _fx_hint(fx: Dictionary) -> String:
	var bits: Array = []
	if fx.has("battle"):
		bits.append("触发战斗")
	if fx.has("silver"):
		bits.append("银两变动")
	if fx.has("food"):
		bits.append("粮 %+d" % int(fx.food))
	if fx.has("days"):
		bits.append("耽搁 %d 日" % int(fx.days))
	if fx.has("risk"):
		bits.append("有风险")
	return "，".join(bits)

func _choose_event(idx: int) -> void:
	var r: Dictionary = World.choose_event(idx)
	_clear_modal()
	if not r.get("encounter", {}).is_empty():
		_show_encounter_modal(r.encounter)
		return
	_show_toast(str(r.get("msg", "")), UIKit.ACCENT)
	_refresh_top()
	if World.is_traveling() and World.encounter.is_empty():
		_place_token(true)
		await get_tree().create_timer(STEP_SEC).timeout
		_run_travel()
	elif not World.encounter.is_empty():
		_show_encounter_modal(World.encounter)
	else:
		_after_arrival()

func _show_encounter_modal(enc: Dictionary) -> void:
	var p := _modal_panel(300)
	p.name = "EncounterModal"
	var el := UIKit.mono("ENCOUNTER // %s" % str(World.data.get("biome_keyword", {}).get(str(World.node(str(enc.get("node", ""))).get("biome", "")), "")).to_upper(), 9, UIKit.DANGER)
	el.position = Vector2(24, 18)
	p.add_child(el)
	var t := UIKit.title_label(str(enc.get("label", "遭遇战")), 22)
	t.position = Vector2(24, 36)
	p.add_child(t)
	var m: Dictionary = enc.get("map", {})
	var foes: Array = m.get("enemy_templates", [])
	var kv := VBoxContainer.new()
	kv.position = Vector2(24, 80)
	kv.add_theme_constant_override("separation", 5)
	p.add_child(kv)
	var bz: String = str(BIOME_ZH.get(str(World.node(str(enc.get("node", ""))).get("biome", "")), "野地"))
	kv.add_child(UIKit.kv_row("战场", "%s · %s地形" % [World.node(str(enc.get("node", ""))).get("name", ""), bz], UIKit.TEXT, 452))
	kv.add_child(UIKit.kv_row("敌势", "%d 人 · %s" % [foes.size(), World.nations.get(str(enc.get("nation", "")), {}).get("name", "")], UIKit.DANGER, 452))
	kv.add_child(UIKit.kv_row("危险度", "▮".repeat(int(enc.get("danger", 1))) + "▯".repeat(maxi(0, 4 - int(enc.get("danger", 1)))), UIKit.DANGER, 452))
	var q: Dictionary = World.quest_by_id(str(enc.get("quest", "")))
	if not q.is_empty():
		kv.add_child(UIKit.kv_row("委托", str(q.title), UIKit.ACCENT, 452))
	var note := UIKit.body_label("得胜：缴获银两与本地材料，委托目标达成，继续行程。\n败退：退回出发地，士气 -5，货物折损四分之一。", UIKit.TEXT_DIM, 12)
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.position = Vector2(24, 182)
	p.add_child(note)
	var fb := UIKit.cta_button("迎战", "A", 220, 42)
	fb.name = "EncounterFight"
	fb.position = Vector2(24, 238)
	fb.pressed.connect(_launch_battle)
	p.add_child(fb)
	var rb := UIKit.ghost_button("弃战败退", 140, 42)
	rb.name = "EncounterRetreat"
	rb.position = Vector2(256, 238)
	rb.pressed.connect(func():
		var r: Dictionary = World.on_battle_end(false)
		_clear_modal()
		_show_view(World.nation_of(World.pos))
		_select_node(World.pos)
		_refresh_top()
		_show_toast(str(r.get("msg", "")), UIKit.DANGER))
	p.add_child(rb)
	fb.call_deferred("grab_focus")

func _launch_battle() -> void:
	GameState.set_meta("atlas_after_battle", true)
	GameState.save_game()
	UIFX.page_exit(self)
	World.launch_encounter(get_tree())

func _show_toast(text: String, col: Color) -> void:
	if not World.milestones.is_empty():
		var ms: Dictionary = World.milestones.pop_back()
		World.milestones.clear()
		text = str(ms.text)
		col = UIKit.OK
	if text == "":
		return
	_toast.text = text
	_toast.add_theme_color_override("font_color", col)
	_toast.visible = true
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _toast.visible = false)

# ── nav ───────────────────────────────────────────────
func _on_world_changed() -> void:
	if not is_inside_tree() or _busy:
		return
	_refresh_top()

func _goto(path: String) -> void:
	UIFX.page_exit(self)
	get_tree().change_scene_to_file(path)

func _back() -> void:
	if not _modal.get_children().is_empty() and not World.pending_event.is_empty():
		return
	_goto(CASTLE_SCENE)

func _input(e: InputEvent) -> void:
	if not (e is InputEventMouse or e is InputEventScreenTouch or e is InputEventScreenDrag):
		return
	if _clip == null or _map_content == null or _modal == null:
		return
	if _busy or not _modal.get_children().is_empty():
		return
	var pos := _event_pos(e)
	var inside := pos.x > -10000.0 and _clip.get_global_rect().has_point(pos)
	if not inside and not _map_router.has_pointers():
		return
	var gestures := _map_router.push(e, Time.get_ticks_msec())
	var swallow := _map_router.gesture_locked()
	for g in gestures:
		var kind := str(g.get("kind", ""))
		if kind in ["pan", "pinch", "wheel", "swallow"]:
			swallow = true
		_apply_map_gesture(g)
	if swallow:
		get_viewport().set_input_as_handled()

func _event_pos(e: InputEvent) -> Vector2:
	if e is InputEventMouse:
		return (e as InputEventMouse).position
	if e is InputEventScreenTouch:
		return (e as InputEventScreenTouch).position
	if e is InputEventScreenDrag:
		return (e as InputEventScreenDrag).position
	return Vector2(-99999, -99999)

func _clip_local(vp: Vector2) -> Vector2:
	return _clip.get_global_transform_with_canvas().affine_inverse() * vp

func _apply_map_xform() -> void:
	_clamp_map()
	_map_content.position = _map_pan
	_map_content.scale = Vector2(_map_zoom, _map_zoom)

func _clamp_map() -> void:
	var shown := MAP.size * _map_zoom
	_map_pan.x = clampf(_map_pan.x, 40.0 - shown.x, MAP.size.x - 40.0)
	_map_pan.y = clampf(_map_pan.y, 40.0 - shown.y, MAP.size.y - 40.0)

func _zoom_map(factor: float, focal: Vector2) -> void:
	var old := _map_zoom
	var next := clampf(old * factor, 0.85, 2.8)
	if is_equal_approx(next, old) or old <= 0.001:
		return
	var applied := next / old
	_map_zoom = next
	_map_pan = focal - (focal - _map_pan) * applied
	_apply_map_xform()

func _apply_map_gesture(g: Dictionary) -> void:
	var kind := str(g.get("kind", ""))
	var pos: Vector2 = g.get("pos", Vector2.ZERO)
	match kind:
		"pan":
			var sc := _clip.get_global_transform_with_canvas().get_scale()
			var sx := sc.x if absf(sc.x) > 0.01 else 1.0
			var sy := sc.y if absf(sc.y) > 0.01 else 1.0
			var delta: Vector2 = g.get("delta", Vector2.ZERO)
			_map_pan += Vector2(delta.x / sx, delta.y / sy)
			_apply_map_xform()
		"pinch", "wheel":
			_zoom_map(float(g.get("factor", 1.0)), _clip_local(pos))
		"long_press":
			var id := _node_at(pos)
			if id.begins_with("gate_"):
				_info_gateway(id.trim_prefix("gate_"))
			elif id != "":
				if _view == "":
					_info_region(id)
				else:
					_select_node(id)
			elif _sel != "":
				_show_toast("长按聚落查看情报", UIKit.TEXT_DIM)

func _node_at(vp: Vector2) -> String:
	for k in _node_btn.keys():
		var b: Button = _node_btn[k]
		if is_instance_valid(b) and b.get_global_rect().has_point(vp):
			return str(k)
	return ""

func _unhandled_input(e: InputEvent) -> void:
	if _busy or not _modal.get_children().is_empty():
		return
	if e.is_action_pressed("ui_cancel"):
		if _view != "" and _view != World.nation_of(World.pos):
			_show_view(World.nation_of(World.pos))
			_select_node(World.pos)
		else:
			_back()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		if k == KEY_X:
			if _view == "":
				_show_view(World.nation_of(World.pos))
				_select_node(World.pos)
			else:
				_show_view("")
				_select_node(World.pos)
		elif k == KEY_Y:
			_enter_here()

# ── e2e hook ──────────────────────────────────────────
func selftest() -> Dictionary:
	var msgs: Array = []
	var n_here := World.nodes_in(_view).size()
	var n_btn := 0
	for k in _node_btn.keys():
		if not str(k).begins_with("gate_"):
			n_btn += 1
	if n_btn != n_here:
		return {"ok": false, "msg": "node buttons %d != %d" % [n_btn, n_here]}
	msgs.append("%d nodes" % n_btn)
	# pick an adjacent node and travel through the UI path
	var dest := ""
	for r in World.roads_from(World.pos):
		var o := World.other_end(r, World.pos)
		if World.nation_of(o) == _view:
			dest = o
			break
	if dest == "":
		return {"ok": false, "msg": "no neighbour"}
	_on_node_pressed(dest)
	if _preview.is_empty():
		return {"ok": false, "msg": "no preview for " + dest}
	var days0 := World.days_total
	_start_travel()
	for _i in 60:
		await get_tree().process_frame
		if not _busy:
			break
		await get_tree().create_timer(0.1).timeout
	if World.pos != dest:
		return {"ok": false, "msg": "token did not arrive (%s vs %s)" % [World.pos, dest]}
	if World.days_total <= days0:
		return {"ok": false, "msg": "days did not advance"}
	msgs.append("travelled to %s" % dest)
	_show_view("")
	if _node_btn.size() != World.nation_ids().size():
		return {"ok": false, "msg": "world view regions %d" % _node_btn.size()}
	msgs.append("world view %d regions" % _node_btn.size())
	_show_view(World.nation_of(World.pos))
	_select_node(World.pos)
	return {"ok": true, "msg": ", ".join(msgs)}
