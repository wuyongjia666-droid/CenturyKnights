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
var _halt_after_leg := false
var _halted_dest := ""
var _travel_abort := false
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
var _list_btn: Dictionary = {}  # nation id -> left-list Button (WS-C #41)
var _hilit := ""
const MobileReflow := preload("res://scripts/platform/mobile_reflow.gd")
var _col_w := 480.0
var _mob := false
var _mbase := 1.0
var _lift := 24.0
var _drawer := false  # narrow phones: side column slides over the map
var _side: Control
const M_SHEET_MIN := 420.0
const M_SHEET_W := 470.0
var _sheet_tab := "place"
var _sheet_btn: Dictionary = {}
var _sheet_scroll: ScrollContainer
var _actions: VBoxContainer
var _side_toggle: Button
var _map_frame: Control
var _map_full := Rect2()
var _map_side := Rect2()

func _ready() -> void:
	UIKit.void_bg(self)
	_build_frame()
	if not World.city_visit.is_empty():
		World.close_city_visit()
	World.world_changed.connect(_on_world_changed)
	var start_view := World.nation_of(World.pos)
	if GameState.has_meta("atlas_view"):
		start_view = str(GameState.get_meta("atlas_view"))
		GameState.remove_meta("atlas_view")
	var focus := World.pos
	var guided := false
	if GameState.has_meta("atlas_select"):
		var want := str(GameState.get_meta("atlas_select"))
		GameState.remove_meta("atlas_select")
		if World.nodes.has(want):
			focus = want
			guided = true
			var nv := World.nation_of(want)
			if nv != "":
				start_view = nv
	_show_view(start_view if start_view != "" else "ashbanner")
	_select_node(focus)
	if guided:
		hilite(focus)
		call_deferred("_toast_quest_guide", focus)
	if not _mob:
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
	_mobile_frame(mp)

## Landscape phone (docs/design/mobile-landscape.md): the map takes the whole height and
## as much width as its 16:9 plate allows; one side sheet with three tabs (地点 / 日志 / 列国)
## holds the place profile, route, road log and region list, with the main action pinned
## at the bottom. When the phone is too narrow for map + sheet side by side, the sheet is a
## drawer over the right of the map (the map stays visible) toggled from the top bar.
func _mobile_frame(mp: Control) -> void:
	if not MobilePage.active(self):
		return
	_mob = true
	# map captions/targets are sized to on-screen 22px / 76px through the map scale (_mobile_nodes)
	_map_content.set_meta("font_floor_exempt", true)
	_map_content.set_meta("touch_exempt", true)
	var vp := get_viewport().get_visible_rect().size
	var w := maxf(1280.0, vp.x * 720.0 / maxf(1.0, vp.y))
	var top := MobilePage.TOP + 4.0
	var h := 720.0 - top - 12.0
	var map_w := floorf(h * MAP.size.x / MAP.size.y)
	_col_w = w - map_w - 48.0
	_drawer = _col_w < M_SHEET_MIN
	if _drawer:
		_col_w = minf(M_SHEET_W, w - 64.0)
		map_w = minf(map_w, w - 32.0)
	var area := Rect2(16, top, map_w, h) if not _drawer else Rect2((w - map_w) * 0.5, top, map_w, h)
	_mbase = minf(area.size.x / MAP.size.x, area.size.y / MAP.size.y)
	var shown := MAP.size * _mbase
	_clip.position = (area.position + (area.size - shown) * 0.5).floor()
	_clip.size = shown
	mp.position = _clip.position - Vector2(2, 2)
	mp.size = shown + Vector2(4, 4)
	_map_frame = mp
	_map_full = Rect2(_clip.position, shown)
	_toast.position = _clip.position + Vector2(16, shown.y - 60)
	_toast.add_theme_font_size_override("font_size", MobilePage.FONT)
	_toast.z_index = 20
	var col_rect := Rect2(w - _col_w - 16.0, top, _col_w, h)
	var left_w := col_rect.position.x - 32.0
	_map_side = Rect2(Vector2(16, _clip.position.y), Vector2(minf(left_w, shown.x), shown.y))
	var sheet := PanelContainer.new()
	sheet.name = "MobileSheet"
	sheet.position = col_rect.position
	sheet.size = col_rect.size
	var sb := UIKit.flat_box(Color(0.035, 0.045, 0.065, 0.97 if _drawer else 0.92), Color(UIKit.ACCENT, 0.30), 12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	if _drawer:
		sb.shadow_color = Color(0, 0, 0, 0.55)
		sb.shadow_size = 18
	sheet.add_theme_stylebox_override("panel", sb)
	add_child(sheet)
	if _drawer:
		sheet.z_index = 10
		sheet.visible = false
		_side = sheet
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	sheet.add_child(v)
	var tabs := HBoxContainer.new()
	tabs.name = "SheetTabs"
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for spec in [["place", Locale.t("mob_ui_001")], ["log", Locale.t("mob_ui_002")], ["regions", Locale.t("mob_ui_003")]]:
		var key := str(spec[0])
		var tb := MobilePage.button(str(spec[1]), false, func(): _set_sheet_tab(key))
		tb.name = "SheetTab_" + key
		tb.toggle_mode = true
		tabs.add_child(tb)
		_sheet_btn[key] = tb
	var sc := ScrollContainer.new()
	sc.name = "MobileSideCol"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(stack)
	_sheet_scroll = sc
	for nm in ["RightColumn", "TravelHUD", "LeftColumn"]:
		var old := get_node(nm) as Control
		remove_child(old)
		old.queue_free()
		var box := VBoxContainer.new()
		box.name = nm
		box.add_theme_constant_override("separation", 12)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(box)
		match nm:
			"RightColumn":
				_right = box
			"TravelHUD":
				_hud = box
			_:
				_left = box
	_actions = VBoxContainer.new()
	_actions.name = "SheetActions"
	_actions.add_theme_constant_override("separation", 8)
	v.add_child(_actions)
	var ts := ceilf(40.0 / _mbase)
	_token.size = Vector2(ts, ts)
	_token.pivot_offset = _token.size * 0.5
	var tg := _token.get_child(0) as Label
	tg.size = _token.size
	_lift = ceilf(MobilePage.HIT / _mbase) * 0.5 + ts * 0.5 + 10.0
	tg.add_theme_font_size_override("font_size", ceili(MobilePage.FONT / _mbase))
	_set_sheet_tab("place")
	_refresh_top()
	_apply_map_xform()
	if GameState.has_meta("atlas_open_side"):
		GameState.remove_meta("atlas_open_side")
		_show_side.call_deferred(true)
	if GameState.has_meta("atlas_sheet_tab"):
		var st := str(GameState.get_meta("atlas_sheet_tab"))
		GameState.remove_meta("atlas_sheet_tab")
		(func(): _set_sheet_tab(st); _show_side(true)).call_deferred()


## mobile_chrome fit/safe-area hook. First call builds phone chrome; later calls only reflow
## map + sheet geometry so we never duplicate MobileSheet.
func apply_mobile_layout() -> void:
	if not MobilePage.active(self):
		return
	var mp := _map_frame
	if mp == null:
		mp = find_child("MapFrame", true, false) as Control
	if mp == null:
		return
	if not _mob:
		_mobile_frame(mp)
		_build_nodes()
		_render_left()
		_render_right()
		_render_hud()
		return
	_reflow_mobile(mp)


func _reflow_mobile(mp: Control) -> void:
	var vp := get_viewport().get_visible_rect().size
	var w := maxf(1280.0, vp.x * 720.0 / maxf(1.0, vp.y))
	var top := MobilePage.TOP + 4.0
	var h := 720.0 - top - 12.0
	var map_w := floorf(h * MAP.size.x / MAP.size.y)
	_col_w = w - map_w - 48.0
	_drawer = _col_w < M_SHEET_MIN
	if _drawer:
		_col_w = minf(M_SHEET_W, w - 64.0)
		map_w = minf(map_w, w - 32.0)
	var area := Rect2(16, top, map_w, h) if not _drawer else Rect2((w - map_w) * 0.5, top, map_w, h)
	_mbase = minf(area.size.x / MAP.size.x, area.size.y / MAP.size.y)
	var shown := MAP.size * _mbase
	_clip.position = (area.position + (area.size - shown) * 0.5).floor()
	_clip.size = shown
	mp.position = _clip.position - Vector2(2, 2)
	mp.size = shown + Vector2(4, 4)
	_map_frame = mp
	_map_full = Rect2(_clip.position, shown)
	_toast.position = _clip.position + Vector2(16, shown.y - 60)
	_toast.add_theme_font_size_override("font_size", MobilePage.FONT)
	var col_rect := Rect2(w - _col_w - 16.0, top, _col_w, h)
	var left_w := col_rect.position.x - 32.0
	_map_side = Rect2(Vector2(16, _clip.position.y), Vector2(minf(left_w, shown.x), shown.y))
	var sheet := find_child("MobileSheet", true, false) as Control
	if sheet:
		sheet.position = col_rect.position
		sheet.size = col_rect.size
		if _drawer:
			sheet.z_index = 10
			_side = sheet
		else:
			sheet.visible = true
			_side = null
	var ts := ceilf(40.0 / _mbase)
	_token.size = Vector2(ts, ts)
	_token.pivot_offset = _token.size * 0.5
	var tg := _token.get_child(0) as Label
	if tg:
		tg.size = _token.size
		tg.add_theme_font_size_override("font_size", ceili(MobilePage.FONT / _mbase))
	_lift = ceilf(MobilePage.HIT / _mbase) * 0.5 + ts * 0.5 + 10.0
	_refresh_top()
	_mobile_nodes()
	_apply_map_xform()
	if _drawer and _side and _side.visible:
		_show_side(true)



func _set_sheet_tab(key: String) -> void:
	_sheet_tab = key
	for k in _sheet_btn.keys():
		var b: Button = _sheet_btn[k]
		b.set_pressed_no_signal(str(k) == key)
		b.add_theme_color_override("font_color", UIKit.ACCENT if str(k) == key else UIKit.TEXT_DIM)
	if _right:
		_right.visible = key == "place"
		_hud.visible = key == "log"
		_left.visible = key == "regions"
	if _sheet_scroll:
		_sheet_scroll.scroll_vertical = 0


## Narrow phones: the sheet slides over the right of the map; the map stays visible and pannable.
func _show_side(on: bool) -> void:
	if _side == null:
		return
	_side.visible = on
	if _side_toggle:
		_side_toggle.text = Locale.t("mob_ui_004") if on else Locale.t("gen2_34")
	# the map moves to the strip left of the sheet and keeps the selection in view
	var r := _map_side if on else _map_full
	_clip.position = r.position
	_clip.size = r.size
	if _map_frame:
		_map_frame.position = r.position - Vector2(2, 2)
		_map_frame.size = r.size + Vector2(4, 4)
	_toast.position = r.position + Vector2(16, r.size.y - 60)
	if on:
		var focus := World.pos
		if _view == "" and World.nations.has(_sel):
			focus = ""
		elif World.nodes.has(_sel):
			focus = _sel
		var fp := _region_pos(_sel) if focus == "" else _np(focus)
		_map_pan = r.size * 0.5 - fp * _mbase * _map_zoom
		var shown := MAP.size * _mbase * _map_zoom
		_map_pan.x = clampf(_map_pan.x, minf(0.0, r.size.x - shown.x), 0.0)
		_map_pan.y = clampf(_map_pan.y, minf(0.0, r.size.y - shown.y), 0.0)
	else:
		_map_pan = Vector2.ZERO
	_apply_map_xform()


## Map labels and buttons are scaled with the map: size them so they land at 22px / 76px on screen.
func _mobile_nodes() -> void:
	if not _mob:
		return
	var fs := ceili(MobilePage.FONT / _mbase)
	var hit := ceilf(MobilePage.HIT / _mbase)
	for c in _layer.find_children("*", "Control", true, false):
		if c is Label:
			var l := c as Label
			if l.get_theme_font_size("font_size") < fs:
				var before := l.get_minimum_size().x
				l.add_theme_font_size_override("font_size", fs)
				if l.get_parent() == _layer:
					l.position.x -= (l.get_minimum_size().x - before) * 0.5
		elif c is BaseButton and c.get_parent() == _layer:
			var b := c as Control
			var sz := b.size
			if sz.x < hit or sz.y < hit:
				var ns := Vector2(maxf(sz.x, hit), maxf(sz.y, hit))
				b.custom_minimum_size = ns
				b.position -= (ns - sz) * 0.5
				b.size = ns
				for k in b.get_children():
					if k is Label and (k as Label).anchor_right < 0.5:
						var kl := k as Label
						kl.add_theme_font_size_override("font_size", fs)
						kl.size = kl.get_minimum_size()
						kl.position = Vector2((ns.x - kl.size.x) * 0.5, ns.y + 1.0)
						var below := Rect2(b.position + kl.position, kl.size)
						for o in _layer.get_children():
							if o != b and o is BaseButton and below.intersects(Rect2(o.position, o.size)):
								kl.position.y = -kl.size.y - 1.0
								break
			b.add_theme_font_size_override("font_size", maxi(fs, b.get_theme_font_size("font_size")))
	# Captions: try below / above / right / left of the node they belong to and keep the
	# first spot that hits no button and no caption already placed; badges sit on the node's corner.
	var btns: Array = []
	for c in _layer.get_children():
		if c is BaseButton and not c.is_queued_for_deletion():
			btns.append(c)
	var taken: Array = []
	for b in btns:
		taken.append(Rect2((b as Control).position, (b as Control).size).grow(2.0))
	var bounds := Rect2(Vector2(2, 2), MAP.size - Vector2(4, 4))
	for c in _layer.get_children():
		if not (c is Label) or c.is_queued_for_deletion():
			continue
		var l := c as Label
		if bool(l.get_meta("ck_node_badge", false)):
			continue
		l.size = l.get_minimum_size()
		var own: Control = null
		var best := 1e9
		var lc := l.position + l.size * 0.5
		var single := l.text.length() <= 1
		for b in btns:
			if single and not (str(b.name).begins_with("Node_") or str(b.name).begins_with("Region_")):
				continue
			var bc := (b as Control).position + (b as Control).size * 0.5
			var d := bc.distance_to(lc)
			if d < best:
				best = d
				own = b
		if own == null:
			continue
		var br := Rect2(own.position, own.size)
		if l.text.length() <= 1:
			# Node badges (★/◆/✓) are placed in _add_node_button; do not drag them
			# back onto the disc. Other single-char marks stay above-right past 1.18×.
			if bool(l.get_meta("ck_node_badge", false)):
				continue
			var bh := 22.0
			l.custom_minimum_size = Vector2(maxi(18, int(l.size.x)), int(bh))
			l.size = Vector2(maxi(18, int(l.size.x)), int(bh))
			l.position = Vector2(
				br.end.x + br.size.x * 0.18 + 4.0,
				br.position.y - bh - 6.0
			)
			continue
		var cands := [
			Vector2(br.get_center().x - l.size.x * 0.5, br.end.y + 1.0),
			Vector2(br.get_center().x - l.size.x * 0.5, br.position.y - l.size.y - 1.0),
			Vector2(br.end.x + 4.0, br.get_center().y - l.size.y * 0.5),
			Vector2(br.position.x - l.size.x - 4.0, br.get_center().y - l.size.y * 0.5),
			Vector2(br.get_center().x - l.size.x * 0.5, br.end.y + l.size.y + 2.0),
		]
		var pick: Vector2 = cands[0]
		for cand in cands:
			var cp: Vector2 = cand
			cp.x = clampf(cp.x, bounds.position.x, bounds.end.x - l.size.x)
			cp.y = clampf(cp.y, bounds.position.y, bounds.end.y - l.size.y)
			var r := Rect2(cp, l.size)
			var free := true
			for t in taken:
				if (t as Rect2).intersects(r):
					free = false
					break
			if free:
				pick = cp
				break
		pick.x = clampf(pick.x, bounds.position.x, bounds.end.x - l.size.x)
		pick.y = clampf(pick.y, bounds.position.y, bounds.end.y - l.size.y)
		l.position = pick
		taken.append(Rect2(pick, l.size).grow(1.0))


func _refresh_top() -> void:
	for c in _top.get_children():
		c.queue_free()
	var here: Dictionary = World.node(World.pos)
	var fpd := World.food_per_day()
	var food_days := GameState.food / maxi(1, fpd)
	var title := "世界舆图 · 跑图"
	var ration := World.food_ration_info()
	var season_chip := Locale.t("atlas_season_%s" % str(ration.season_id))
	var chips := [
		["位置", str(here.get("name", "—"))],
		["历", World.date_label(), UIKit.TEXT_DIM],
		[Locale.t("atlas_chip_season"), season_chip, UIKit.ACCENT],
		["银", str(GameState.silver), UIKit.ACCENT],
		["粮", "%d（%d 日）" % [GameState.food, food_days], UIKit.OK if food_days >= 6 else UIKit.DANGER],
		["士气", str(GameState.morale), UIKit.OK if GameState.morale >= 50 else UIKit.DANGER],
	]
	var back_t := "返回城堡"
	if _mob:
		var parts := PackedStringArray()
		for ch in chips:
			parts.append("%s %s" % [ch[0], ch[1]])
		_top.size = Vector2(maxf(1280.0, get_viewport().get_visible_rect().size.x * 720.0 / maxf(1.0, get_viewport().get_visible_rect().size.y)), MobilePage.TOP)
		var bar_btns: Array = [[back_t, _back]]
		if _drawer:
			bar_btns.push_front([Locale.t("gen2_34"), func(): _show_side(not _side.visible)])
		var bar := MobilePage.top_bar(_top, title, " · ".join(parts), bar_btns)
		if _drawer:
			_side_toggle = bar.get_child(2) as Button
			_side_toggle.name = "SheetToggle"
			if _side and _side.visible:
				_side_toggle.text = Locale.t("mob_ui_004")
		return
	UIKit.top_bar(_top, title, chips, back_t, _back)

# ── views ─────────────────────────────────────────────
func _show_view(v: String) -> void:
	_view = v
	var path := _Atlas.world_plate() if v == "" else str(_Atlas.plate_path(str(World.nations.get(v, {}).get("plate", "v8_atlas_nation_" + v))))
	if path != "":
		_plate.texture = CKArtPaths.load_texture(path)
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
		_mobile_nodes()
		return
	for n in World.nodes_in(_view):
		_add_node_button(n, markers, mm)
	CKAtlasTerritory.add_markers(_layer, _view, MAP.size, _busy, _open_territory_site)
	# border gateways: roads leaving this region
	for n in World.nodes_in(_view):
		for r in World.roads_from(str(n.id)):
			var o := World.other_end(r, str(n.id))
			if World.nation_of(o) != _view:
				_add_gateway(str(n.id), o, r)
	_mobile_nodes()

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
	b.mouse_entered.connect(func(): hilite(nid))
	b.mouse_exited.connect(func(): hilite(""))
	_layer.add_child(b)
	_node_btn[nid] = b
	_stamp_court_mark(b, marker)
	var sub := UIKit.mono("%s · %d" % [World.rep_tier_name(rep), World.nodes_in(nid).size()] + CKAtlasTerritory.region_badge(nid), 8, UIKit.TEXT_DIM, false)
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

func _on_node_focus(id: String) -> void:
	if not _busy:
		_select_node(id)

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
	b.focus_entered.connect(_on_node_focus.bind(id))
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
	# Outside the node ink box so ★ / ◆ never overlap the kind glyph (都/堡/…).
	# Theme/font-floor inflates a 16px title_label to ~66px tall; gate-0 _ink centers
	# in that box, so the badge must sit fully above the disc (+ past 1.18× select).
	var badge_box := 68.0
	var bx := _np(id).x + px * 0.5 * 1.18 + 8.0
	var by := _np(id).y - px * 0.5 * 1.18 - badge_box - 8.0
	by = maxf(2.0, by)
	for bd in badges:
		var bl := UIKit.title_label(str(bd[0]), 16, bd[1])
		bl.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
		bl.add_theme_constant_override("outline_size", 2)
		bl.position = Vector2(bx, by)
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bl.set_meta("ck_node_badge", true)
		_layer.add_child(bl)
		UIFX.breathe(bl, 0.1, 1.2)
		bx += 16.0

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
	b.add_theme_font_size_override("font_size", UIKit.desk_sz(10))
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
	var p := _np(id) - _token.size * 0.5 + (Vector2(0, -_lift) if _view != "" else Vector2(0, -_lift - 6.0))
	if _mob:
		# phone: the flag takes the first spot around its node that covers no marker or caption
		var c0 := _np(id)
		var half := _token.size * 0.5
		var cands := [p, c0 + Vector2(_lift, 0) - half, c0 + Vector2(-_lift, 0) - half,
			c0 + Vector2(_lift * 0.75, -_lift * 0.75) - half, c0 + Vector2(-_lift * 0.75, -_lift * 0.75) - half, c0 + Vector2(0, _lift) - half]
		for cand in cands:
			var tr := Rect2(cand, _token.size)
			var hit := false
			for c in _layer.get_children():
				if c.is_queued_for_deletion() or not (c is Control) or c.name == "Node_" + id:
					continue
				if (c is BaseButton or c is Label) and tr.intersects(Rect2(c.position, (c as Control).size)):
					hit = true
					break
			if not hit:
				p = cand
				break
	if anim:
		var tw := create_tween()
		tw.tween_property(_token, "position", p, STEP_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_token.position = p

# ── left column: regions + party ──────────────────────
func _render_left() -> void:
	for c in _left.get_children():
		c.queue_free()
	if _mob:
		_m_regions()
		return
	var lp := UIKit.panel_at(_left, Rect2(16, 64, 176, 620), 10)
	var eh := UIKit.mono("REGIONS 11", 9, UIKit.ACCENT)
	eh.position = Vector2(14, 10)
	lp.add_child(eh)
	_list_btn.clear()
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
		b.mouse_entered.connect(func(): hilite(nid_s))
		b.focus_entered.connect(func(): hilite(nid_s))
		b.mouse_exited.connect(func(): hilite(""))
		_list_btn[nid_s] = b
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
	var party_row := UIKit.kv_row("编制", "%d 人" % World.party_size(), UIKit.TEXT, 140)
	party_row.name = "PartyMusterRow"
	kv.add_child(party_row)
	var ration_row := UIKit.kv_row(Locale.t("atlas_ration_label"), World.food_ration_text(), UIKit.TEXT, 140)
	ration_row.name = "MarchRationRow"
	kv.add_child(ration_row)
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
	if World.active.is_empty() and World.last_city_sortie.is_empty():
		var el := UIKit.body_label("暂无委托 · 进城看委托榜", UIKit.TEXT_FAINT, 10)
		el.autowrap_mode = TextServer.AUTOWRAP_OFF
		ql.add_child(el)
	if not World.last_city_sortie.is_empty():
		var sp := UIKit.body_label(World.city_sortie_party_text(), UIKit.EMBER, 10)
		sp.name = "CitySortieParty"
		sp.autowrap_mode = TextServer.AUTOWRAP_OFF
		sp.clip_text = true
		sp.custom_minimum_size = Vector2(140, 0)
		ql.add_child(sp)
	var ab := UIKit.ghost_button("出战编成", 140, 26)
	ab.position = Vector2(10, 196)
	ab.name = "AtlasDeploy"
	ab.pressed.connect(_open_deploy)
	pb.add_child(ab)

# ── right column: profile ─────────────────────────────
func _engage_quest_id_here() -> String:
	for q2 in World.active:
		if str(q2.state) != "active":
			continue
		var k := str(q2.kind)
		if k in ["hunt", "defend"] and str(q2.target) == _sel:
			return str(q2.id)
		if k == "clear" and q2.has("edge"):
			var e: Array = q2.edge
			if e.size() >= 2 and (str(e[0]) == _sel or str(e[1]) == _sel):
				return str(q2.id)
	return ""

func _render_right() -> void:
	for c in _right.get_children():
		_right.remove_child(c)
		c.free()
	if _mob:
		_m_place()
		_m_actions()
		return
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
	th.size = Vector2(224, 88)
	th.clip_contents = true
	p.add_child(th)
	_fill_vignette(th, _sel)
	# Quotes, lore, and quests share one column that ends above the action row.
	# Absolute y=296 lore used to sit on top of the produce block.
	var col_w := 224.0
	var stack_top := 184.0
	var actions_top := 462.0
	var scroll := ScrollContainer.new()
	scroll.name = "ProfileScroll"
	scroll.position = Vector2(16, stack_top)
	scroll.size = Vector2(col_w, actions_top - stack_top)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.name = "ProfileStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.custom_minimum_size = Vector2(col_w, 0)
	stack.add_theme_constant_override("separation", 4)
	scroll.add_child(stack)
	var kv := VBoxContainer.new()
	kv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kv.add_theme_constant_override("separation", 3)
	stack.add_child(kv)
	var rep := World.rep_of(_sel)
	kv.add_child(UIKit.kv_row("城声望", "%d · %s" % [rep, World.rep_tier_name(rep)], UIKit.ACCENT, col_w))
	kv.add_child(UIKit.kv_row("特产", str(n.get("specialty", "")), UIKit.TEXT, col_w))
	var prod: Array = []
	for g in n.get("produce", []):
		prod.append(World.good_name(str(g)))
	var dem: Array = []
	for g in n.get("demand", []):
		dem.append(World.good_name(str(g)))
	kv.add_child(UIKit.kv_row("出产", "、".join(prod) if not prod.is_empty() else "—", UIKit.OK, col_w))
	kv.add_child(UIKit.kv_row("求购", "、".join(dem) if not dem.is_empty() else "—", UIKit.EMBER, col_w))
	var loop_box := VBoxContainer.new()
	loop_box.name = "TradeLoop"
	loop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loop_box.add_theme_constant_override("separation", 2)
	stack.add_child(loop_box)
	loop_box.add_child(UIKit.mono(Locale.t("atlas_trade_loop_en"), 8, UIKit.EMBER, false))
	var loops: Array = World.produce_trade_loop(_sel)
	var shown := 0
	for row in loops:
		if shown >= 2:
			break
		var line := ""
		if bool(row.get("known", false)):
			line = Locale.t("atlas_trade_loop_line") % [str(row.name), int(row.buy), str(row.sell_name), int(row.sell), int(row.margin)]
		else:
			line = Locale.t("atlas_trade_loop_unknown") % [str(row.name), int(row.buy)]
		var ll := UIKit.body_label(line, UIKit.OK if int(row.get("margin", 0)) > 0 else UIKit.TEXT_DIM, 12)
		ll.name = "TradeLoop_%d" % shown
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.clip_text = false
		ll.custom_minimum_size = Vector2(col_w, 0)
		ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		loop_box.add_child(ll)
		shown += 1
	if _sel == World.pos and not loops.is_empty():
		var tb := UIKit.ghost_button(Locale.t("atlas_trade_loop_goto"), int(col_w), 26)
		tb.name = "TradeLoopGoto"
		tb.pressed.connect(func():
			GameState.set_meta("city_tab", "market")
			_enter_here())
		loop_box.add_child(tb)
		var best_row: Dictionary = World.best_produce_trade(_sel)
		if not best_row.is_empty() and bool(best_row.get("known", false)) and World.arbitrage.is_empty():
			var arb := UIKit.ghost_button(Locale.t("atlas_arb_run"), int(col_w), 26)
			arb.name = "ArbitrageRun"
			arb.pressed.connect(_start_arbitrage_from_profile.bind(str(best_row.get("good", "")), str(best_row.get("sell_city", ""))))
			loop_box.add_child(arb)
	elif _sel == World.pos and not World.arbitrage.is_empty():
		var plan: Dictionary = World.arbitrage
		var pending := UIKit.body_label(_arb_pending_text(plan), UIKit.EMBER, 12)
		pending.name = "ArbitragePending"
		pending.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pending.custom_minimum_size = Vector2(col_w, 0)
		loop_box.add_child(pending)
		if str(plan.get("sell_city", "")) == World.pos:
			var sellb := UIKit.ghost_button(Locale.t("atlas_arb_sell_now"), int(col_w), 26)
			sellb.name = "ArbitrageSell"
			sellb.pressed.connect(_complete_arbitrage_ui)
			loop_box.add_child(sellb)
		else:
			var march := UIKit.ghost_button(Locale.t("atlas_arb_march"), int(col_w), 26)
			march.name = "ArbitrageMarch"
			march.pressed.connect(func():
				_select_node(str(plan.get("sell_city", "")))
				_start_travel())
			loop_box.add_child(march)
	var lore := UIKit.body_label(str(n.get("lore", "")), UIKit.TEXT_DIM, 12)
	lore.name = "ProfileLore"
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.clip_text = false
	lore.custom_minimum_size = Vector2(col_w, 0)
	lore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(lore)
	var mm: Dictionary = World.mainline_marker()
	for mk in World.quest_markers().get(_sel, []):
		var q: Dictionary = mk.quest
		var ql := UIKit.body_label("%s %s" % ["✓ 交付" if str(mk.kind) == "turnin" else "◆ 目标", q.title], UIKit.OK if str(mk.kind) == "turnin" else UIKit.DANGER, 12)
		ql.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ql.clip_text = false
		ql.custom_minimum_size = Vector2(col_w, 0)
		ql.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(ql)
	if str(mm.get("node", "")) == _sel:
		var ml := UIKit.body_label("★ %s（在此展开）" % mm.label, UIKit.EMBER, 12)
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ml.custom_minimum_size = Vector2(col_w, 0)
		ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(ml)
	# ChainStart lives in the scroll stack (panel is only 256 wide — footer x=250 overflowed desktop gate).
	var start_cid := _startable_chain_here()
	if start_cid != "" and _sel == World.pos:
		var chain_row := {}
		for row in World.scripted_chains():
			if str(row.get("id", "")) == start_cid:
				chain_row = row
				break
		var cname := str(chain_row.get("title", start_cid))
		var cs := UIKit.ghost_button(Locale.t("atlas_chain_start") % cname, int(col_w), 28)
		cs.name = "ChainStart"
		cs.disabled = _busy
		cs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cs.pressed.connect(func():
			var sr: Dictionary = World.start_scripted_chain(start_cid)
			if not bool(sr.get("ok", false)):
				_show_toast(str(sr.get("msg", "")), UIKit.DANGER)
				return
			var q0: Dictionary = sr.get("quest", {})
			var acc: Dictionary = World.accept_quest(str(q0.get("issuer", World.pos)), str(q0.get("id", "")))
			_show_toast(str(acc.get("msg", sr.get("msg", ""))), UIKit.OK if bool(acc.get("ok", false)) else UIKit.DANGER)
			var dest := str(q0.get("target", ""))
			# Defer rebuild — ChainStart lives in the right panel we are about to free.
			call_deferred("_after_chain_start", dest))
		stack.add_child(cs)
	# actions
	var go := UIKit.cta_button("启程前往", "A", 224, 40)
	go.name = "GoButton"
	go.position = Vector2(16, 470)
	go.disabled = _busy or _sel == World.pos or _preview.is_empty() or not bool(_preview.get("ok", false))
	go.pressed.connect(_start_travel)
	p.add_child(go)
	var readies := World.ready_turn_ins_here().size() if _sel == World.pos else 0
	var enter_label := Locale.t("atlas_enter_turnin") % readies if readies > 0 else Locale.t("atlas_enter_kind") % World.kind_zh(_sel)
	var enter := UIKit.ghost_button(enter_label, 148 if readies > 0 else 108, 32)
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
	var eng := UIKit.ghost_button(Locale.t("atlas_engage_cta"), 108, 28)
	eng.name = "EngageButton"
	eng.position = Vector2(16, 556)
	var engage_q := _engage_quest_id_here()
	eng.disabled = _busy or engage_q == "" or _sel != World.pos
	eng.pressed.connect(func():
		var e: Dictionary = World.quest_engage(engage_q)
		if not e.is_empty():
			_show_encounter_modal(e))
	p.add_child(eng)
	var rv_here: Dictionary = World.rival_here() if _sel == World.pos else {}
	var show_rival := not rv_here.is_empty() and World.encounter.is_empty()
	if show_rival:
		var rival_btn := UIKit.ghost_button(Locale.t("atlas_rival_clash_cta"), 108, 28)
		rival_btn.name = "RivalClash"
		rival_btn.position = Vector2(132, 556)
		rival_btn.disabled = _busy or _sel != World.pos
		rival_btn.tooltip_text = Locale.t("atlas_rival_clash_tip") % str(rv_here.get("name", ""))
		rival_btn.pressed.connect(func():
			var e2: Dictionary = World.rival_clash()
			if not e2.is_empty():
				_show_encounter_modal(e2))
		p.add_child(rival_btn)
	else:
		var terr := UIKit.ghost_button(Locale.t("terr_ui_button") + " %d" % CKTerritory.sites_at(_sel).size(), 108, 28)
		terr.name = "TerritoryButton"
		terr.position = Vector2(132, 556)
		terr.disabled = _busy or CKTerritory.sites_at(_sel).is_empty()
		var anchor_id := _sel
		terr.pressed.connect(func(): _open_territory(anchor_id))
		p.add_child(terr)
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
		_hud.remove_child(c)
		c.free()
	if _mob:
		_m_log()
		_m_actions()
		return
	var p := UIKit.panel_at(_hud, Rect2(200, 522, 800, 162), 10)
	var terr_nid := World.nation_of(World.pos)
	if terr_nid == "" and not World.encounter.is_empty():
		terr_nid = str(World.encounter.get("nation", ""))
	CKHeraldryChrome.place_travel_crest_strip(p, Vector2(700, 8), terr_nid, Vector2(32, 38))
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
		if not World.last_city_sortie.is_empty():
			_paint_sortie_garrison(p)
			return
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
	var t3 := UIKit.title_label(Locale.t("atlas_route_to") % dest.get("name", ""), 16)
	t3.position = Vector2(16, 18)
	p.add_child(t3)
	var names: Array = []
	for id in pv.path:
		names.append(str(World.node(str(id)).get("name", id)))
	var chain := UIKit.body_label(" › ".join(names), UIKit.TEXT_DIM, 11)
	chain.position = Vector2(16, 42)
	chain.autowrap_mode = TextServer.AUTOWRAP_OFF
	chain.clip_text = true
	chain.size = Vector2(476, 16)
	p.add_child(chain)
	var stats := HBoxContainer.new()
	stats.position = Vector2(16, 62)
	stats.add_theme_constant_override("separation", 6)
	p.add_child(stats)
	stats.add_child(UIKit.res_chip(Locale.t("atlas_chip_days"), Locale.t("atlas_chip_days_v") % int(pv.days), UIKit.TEXT))
	stats.add_child(UIKit.res_chip(Locale.t("atlas_chip_food"), str(pv.food), UIKit.DANGER if bool(pv.short_food) else UIKit.TEXT))
	var march_info: Dictionary = World.food_ration_info()
	var march_col := UIKit.TEXT
	if int(march_info.mod_pct) > 0:
		march_col = UIKit.DANGER
	elif int(march_info.mod_pct) < 0:
		march_col = UIKit.OK
	var march_lbl := UIKit.res_chip(
		Locale.t("atlas_chip_ration_mod"), World.food_ration_text(), march_col)
	march_lbl.name = "MarchRationChip"
	stats.add_child(march_lbl)
	var cost := int(pv.tolls) + int(pv.fare)
	stats.add_child(UIKit.res_chip(Locale.t("atlas_chip_toll"), Locale.t("atlas_chip_silver") % cost, UIKit.DANGER if GameState.silver < cost else UIKit.TEXT))
	var dang := int(pv.danger)
	stats.add_child(UIKit.res_chip(Locale.t("atlas_chip_danger"), World.danger_bars(dang), UIKit.DANGER if dang >= 3 else UIKit.ACCENT))
	var hot_n := int(pv.get("hot_legs", 0))
	if hot_n > 0:
		stats.add_child(UIKit.res_chip(Locale.t("atlas_chip_hot"), Locale.t("atlas_chip_hot_v") % hot_n, UIKit.DANGER))
	# Per-leg danger readout (跑图手感)
	var legs_box := VBoxContainer.new()
	legs_box.name = "RouteLegs"
	legs_box.position = Vector2(16, 92)
	legs_box.add_theme_constant_override("separation", 1)
	p.add_child(legs_box)
	var sortie_note := World.city_sortie_route_note(_sel)
	if sortie_note != "":
		var sn := UIKit.body_label(sortie_note, UIKit.EMBER, 10)
		sn.name = "CommissionMarchNote"
		sn.autowrap_mode = TextServer.AUTOWRAP_OFF
		sn.clip_text = true
		sn.custom_minimum_size = Vector2(340, 0)
		sn.size = Vector2(340, 14)
		legs_box.add_child(sn)
	var readouts: Array = pv.get("leg_readouts", [])
	var show_n := mini(3 if sortie_note != "" else 4, readouts.size())
	for i in show_n:
		var leg: Dictionary = readouts[i]
		var dng := int(leg.get("danger", 1))
		var cost_s := ""
		if int(leg.get("cost", 0)) > 0:
			cost_s = " · " + Locale.t("atlas_chip_silver") % int(leg.cost)
		var line := Locale.t("atlas_leg_line") % [
			str(leg.get("from_name", "")), str(leg.get("to_name", "")),
			int(leg.get("days", 1)), World.danger_bars(dng),
			str(leg.get("kind_zh", "")), cost_s]
		var ll := UIKit.body_label(line, UIKit.DANGER if dng >= 3 else UIKit.TEXT_DIM, 10)
		ll.name = "Leg_%d" % i
		ll.autowrap_mode = TextServer.AUTOWRAP_OFF
		ll.clip_text = true
		ll.custom_minimum_size = Vector2(340, 0)
		ll.size = Vector2(340, 14)
		legs_box.add_child(ll)
	if readouts.size() > show_n:
		var more := UIKit.body_label(Locale.t("atlas_leg_more") % (readouts.size() - show_n), UIKit.TEXT_FAINT, 10)
		more.name = "LegMore"
		legs_box.add_child(more)
	var note_rows := 1 if sortie_note != "" else 0
	var warn_y := 92.0 + float(show_n + note_rows + (1 if readouts.size() > show_n else 0)) * 15.0 + 4.0
	var warn := ""
	if bool(pv.short_food):
		warn = Locale.t("atlas_warn_food")
	elif not (pv.borders as Array).is_empty():
		warn = Locale.t("atlas_warn_border") % "、".join(pv.borders)
	elif hot_n > 0:
		warn = Locale.t("atlas_warn_hot") % hot_n
	if warn != "":
		var wl := UIKit.body_label(warn, UIKit.EMBER if bool(pv.short_food) or hot_n > 0 else UIKit.TEXT_DIM, 11)
		wl.name = "RouteWarn"
		wl.autowrap_mode = TextServer.AUTOWRAP_OFF
		wl.clip_text = true
		wl.size = Vector2(340, 16)
		wl.position = Vector2(16, warn_y)
		p.add_child(wl)
	var go := UIKit.cta_button(Locale.t("atlas_hud_go"), "A", 120, 34)
	go.name = "HudGo"
	go.position = Vector2(376, maxf(112.0, warn_y - 4.0))
	go.disabled = _busy or GameState.silver < int(pv.fare)
	go.pressed.connect(_start_travel)
	p.add_child(go)

# ── interaction ───────────────────────────────────────
func _fit_hit(visual: float) -> float:
	if not DeviceProfile.is_mobile():
		return visual
	if _mob:
		return maxf(visual, ceilf(MobilePage.HIT / _mbase))
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
	if _drawer:
		_show_side(true)
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
	if _drawer:
		_show_side(true)
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
	if _mob and _sheet_tab != "place":
		_set_sheet_tab("place")
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
	World.begin_city_visit()
	GameState.set_meta("city_id", World.pos)
	_goto(CITY_SCENE)

func _start_travel() -> void:
	if _drawer:
		_show_side(false)
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
	_halt_after_leg = false
	_travel_abort = false
	for _i in 64:
		if _travel_abort:
			break
		if not World.is_traveling():
			break
		var path: Array = World.travel.get("route", [])
		var li := int(World.travel.get("leg", 0))
		var nxt := str(path[li + 1]) if li + 1 < path.size() else World.pos
		var cal0 := Calendar.label()
		var info: Dictionary = World.step_travel()
		_month_feedback(cal0)
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
		if _halt_after_leg:
			World.cancel_travel()
			_halt_after_leg = false
			_show_toast(Locale.t("atlas_travel_halted") % World.node(World.pos).get("name", ""), UIKit.ACCENT)
			_set_busy(false)
			_refresh_top()
			_build_nodes()
			_render_left()
			_place_token(false)
			_select_node(World.pos)
			_show_stopover_modal()
			return
		if _check_supply_halt():
			_set_busy(false)
			_refresh_top()
			return
		if _check_territory_month():
			_set_busy(false)
			_refresh_top()
			return
		if _check_siege_alert():
			_set_busy(false)
			_refresh_top()
			return
		if bool(info.get("arrived", false)):
			break
	_set_busy(false)
	if _travel_abort:
		_travel_abort = false
		_halt_after_leg = false
		World.cancel_travel()
		return
	_after_arrival()

## WS-C #42: crossing a month on the road says so (date, rations, territory income) instead of passing silently.
func _month_feedback(before: String) -> void:
	if Calendar.label() == before or World.month_reports.is_empty():
		return
	var rep: Dictionary = World.month_reports[World.month_reports.size() - 1]
	var bits: Array = []
	for e in rep.get("events", []):
		var tx := str(e.get("text", "")) if typeof(e) == TYPE_DICTIONARY else str(e)
		if tx != "" and bits.size() < 2:
			bits.append(tx)
	var line := Locale.t("wsc_t_month") % [str(rep.get("label", Calendar.label())), GameState.food]
	if not bits.is_empty():
		line += " · " + " · ".join(bits)
	_show_toast(line, UIKit.ACCENT)

func _animate_leg(to_id: String) -> void:
	if _view != "" and World.nation_of(to_id) != _view:
		_show_view(World.nation_of(to_id))
	_place_token(true, to_id)
	_refresh_top()

func _animate_leg_half(to_id: String) -> void:
	if not _token.visible or _view == "" or World.nation_of(to_id) != _view:
		return
	var p := (_np(World.pos) + _np(to_id)) * 0.5 - _token.size * 0.5 + Vector2(0, -_lift)
	var tw := create_tween()
	tw.tween_property(_token, "position", p, STEP_SEC).set_trans(Tween.TRANS_SINE)

func _after_arrival() -> void:
	_refresh_top()
	_build_nodes()
	_render_left()
	_place_token(false)
	_select_node(World.pos)
	var n: Dictionary = World.node(World.pos)
	var readies := World.ready_turn_ins_here().size()
	if _check_territory_month():
		return
	if _check_siege_alert():
		return
	if _check_march_muster():
		return
	if _check_losses():
		return
	if _check_chain_fail():
		return
	if _check_supply_halt():
		return
	if _check_rival_thefts():
		return
	if _check_arbitrage_arrival():
		return
	if readies > 0:
		_show_toast(Locale.t("atlas_arrive_turnin") % [n.get("name", ""), readies], UIKit.OK)
		_show_turnin_modal(readies)
	else:
		_show_toast(Locale.t("atlas_arrive_plain") % n.get("name", ""), UIKit.OK)

func _resume_state() -> void:
	## returning from a battle / load: re-open pending modal or continue a journey
	if World.pending_event.is_empty() and World.encounter.is_empty() and _check_territory_month():
		return
	if World.pending_event.is_empty() and World.encounter.is_empty() and _check_siege_alert():
		return
	if World.pending_event.is_empty() and World.encounter.is_empty() and _check_march_muster():
		return
	if World.pending_event.is_empty() and World.encounter.is_empty() and not World.is_traveling() and _check_losses():
		return
	if World.pending_event.is_empty() and World.encounter.is_empty() and not World.is_traveling() and _check_chain_fail():
		return
	if World.pending_event.is_empty() and World.encounter.is_empty() and _check_supply_halt():
		return
	if World.pending_event.is_empty() and World.encounter.is_empty() and not World.is_traveling() and _check_rival_thefts():
		return
	if World.pending_event.is_empty() and World.encounter.is_empty() and not World.is_traveling() and _check_arbitrage_arrival():
		return
	if not World.pending_event.is_empty():
		_show_event_modal(World.pending_event)
	elif not World.encounter.is_empty():
		_render_hud()
		_show_encounter_modal(World.encounter)
	elif GameState.has_meta("atlas_after_battle"):
		GameState.remove_meta("atlas_after_battle")
		var af: Dictionary = World.last_battle_aftermath
		if typeof(af) == TYPE_DICTIONARY and not af.is_empty():
			await _show_battle_aftermath_modal(af)
			if bool(af.get("resume_travel", false)) and World.is_traveling() and World.encounter.is_empty():
				_run_travel()
			elif not World.encounter.is_empty():
				_show_encounter_modal(World.encounter)
			elif not World.is_traveling():
				_after_arrival()
		elif not World.travel_log.is_empty():
			_show_toast(str(World.travel_log[0]), UIKit.ACCENT)
	elif World.is_traveling():
		_show_toast("继续行军……", UIKit.ACCENT)
		_run_travel()
	elif _check_city_sortie():
		return


func _check_city_sortie() -> bool:
	if not _modal.get_children().is_empty():
		return false
	if World.last_city_sortie.is_empty():
		return false
	if bool(World.last_city_sortie.get("shown", false)):
		return false
	if str(World.last_city_sortie.get("state", "")) == "turned_in":
		return false
	World.last_city_sortie["shown"] = true
	_show_city_sortie_modal(World.last_city_sortie)
	return true


func _sortie_line(text: String, node_name: String, y: float, col: Color) -> void:
	var host: Node = _modal.get_child(_modal.get_child_count() - 1)
	var lab := UIKit.body_label(text, col, 13)
	lab.name = node_name
	lab.position = Vector2(24, y)
	lab.size = Vector2(452, 28)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.clip_text = true
	host.add_child(lab)


func _show_city_sortie_modal(card: Dictionary) -> void:
	var h := 430.0
	var panel := _modal_panel(h)
	panel.name = "CitySortieModal"
	var el := UIKit.mono(Locale.t("atlas_sortie_en"), 9, UIKit.ACCENT)
	el.position = Vector2(24, 16)
	panel.add_child(el)
	var title := UIKit.title_label(Locale.t("atlas_sortie_title"), 22)
	title.position = Vector2(24, 34)
	title.size = Vector2(452, 28)
	panel.add_child(title)
	var sig := str(card.get("signature_name", ""))
	var sig_txt := Locale.t("atlas_sortie_sig", [sig]) if sig != "" else Locale.t("atlas_sortie_sig_none")
	_sortie_line(sig_txt, "CitySortieSig", 78, UIKit.OK if sig != "" else UIKit.TEXT_DIM)
	var prod_qty := int(card.get("produce_qty", 0))
	var prod_txt := Locale.t("atlas_sortie_produce_none")
	if prod_qty > 0:
		prod_txt = Locale.t("atlas_sortie_produce", [
			str(card.get("produce_name", "")), prod_qty,
			int(card.get("cargo_used", 0)), int(card.get("cargo_cap", 0)),
		])
	_sortie_line(prod_txt, "CitySortieProduce", 112, UIKit.OK if prod_qty > 0 else UIKit.TEXT_DIM)
	var qtitle := str(card.get("quest_title", ""))
	var quest_txt := Locale.t("atlas_sortie_quest_none")
	if qtitle != "":
		quest_txt = Locale.t("atlas_sortie_quest", [
			qtitle, str(card.get("turn_in_name", "")), int(card.get("days_left", 0)),
		])
	_sortie_line(quest_txt, "CitySortieQuest", 146, UIKit.EMBER if qtitle != "" else UIKit.TEXT_DIM)
	var guide := str(card.get("guide", ""))
	var route_txt := Locale.t("atlas_sortie_route_here")
	if guide != "" and guide != World.pos and int(card.get("days", 0)) > 0:
		route_txt = Locale.t("atlas_sortie_route", [
			str(card.get("guide_name", "")), int(card.get("days", 0)),
			int(card.get("food", 0)), World.danger_bars(int(card.get("danger", 0))),
		])
	_sortie_line(route_txt, "CitySortieRoute", 188, UIKit.TEXT)
	var summary := UIKit.body_label(World.city_sortie_hud_text(), UIKit.ACCENT, 12)
	summary.name = "CitySortieBody"
	summary.position = Vector2(24, 228)
	summary.size = Vector2(452, 40)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(summary)
	var march := UIKit.cta_button(Locale.t("atlas_sortie_march"), "A", 452, 40)
	march.name = "CitySortieMarch"
	march.position = Vector2(24, 278)
	var can_march := guide != "" and guide != World.pos and World.nodes.has(guide)
	var can_turn := guide == World.pos and World.ready_turn_ins_here().size() > 0
	march.disabled = not can_march and not can_turn
	march.pressed.connect(_march_city_sortie)
	panel.add_child(march)
	var later := UIKit.ghost_button(Locale.t("atlas_sortie_later"), 220, 36)
	later.name = "CitySortieLater"
	later.position = Vector2(24, 328)
	later.pressed.connect(func():
		_clear_modal()
		_render_left()
		_render_hud())
	panel.add_child(later)
	var dismiss := UIKit.ghost_button(Locale.t("atlas_sortie_dismiss"), 200, 36)
	dismiss.name = "CitySortieDismiss"
	dismiss.position = Vector2(256, 328)
	dismiss.pressed.connect(func():
		World.dismiss_city_sortie()
		_clear_modal()
		_render_left()
		_render_hud())
	panel.add_child(dismiss)
	if not march.disabled:
		march.call_deferred("grab_focus")
	else:
		later.call_deferred("grab_focus")


func _march_city_sortie() -> void:
	var card := World.last_city_sortie
	if card.is_empty() or str(card.get("state", "")) == "turned_in":
		return
	var guide := str(card.get("guide", ""))
	_clear_modal()
	if guide != "" and guide != World.pos and World.nodes.has(guide):
		_select_node(guide)
		_start_travel()
		return
	if World.ready_turn_ins_here().size() > 0:
		_show_turnin_modal(World.ready_turn_ins_here().size())


func _paint_sortie_garrison(p: Control) -> void:
	var sortie_l := UIKit.body_label(World.city_sortie_hud_text(), UIKit.EMBER, 12)
	sortie_l.name = "CitySortieHud"
	sortie_l.position = Vector2(16, 96)
	sortie_l.size = Vector2(470, 32)
	sortie_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sortie_l.clip_text = true
	p.add_child(sortie_l)
	var turned := str(World.last_city_sortie.get("state", "")) == "turned_in"
	var go_s := UIKit.ghost_button(
		Locale.t("atlas_sortie_dismiss") if turned else Locale.t("atlas_sortie_go"), 160, 28)
	go_s.name = "CitySortieDismiss" if turned else "CitySortieGo"
	go_s.position = Vector2(16, 128)
	go_s.disabled = _busy
	if turned:
		go_s.pressed.connect(func():
			World.dismiss_city_sortie()
			_render_left()
			_render_hud())
	else:
		go_s.pressed.connect(_march_city_sortie)
	p.add_child(go_s)


# ── modals ────────────────────────────────────────────
func _show_travel_halt_modal() -> void:
	var p := _modal_panel(260)
	p.name = "TravelHaltModal"
	CKHeraldryChrome.place_travel_crest_strip(p, Vector2(400, 14), World.nation_of(World.pos), Vector2(36, 44))
	var t := UIKit.title_label(Locale.t("atlas_travel_halt_title"), 22)
	t.position = Vector2(24, 24)
	p.add_child(t)
	var body := UIKit.body_label(Locale.t("atlas_travel_halt_body"), UIKit.TEXT, 14)
	body.position = Vector2(24, 70)
	body.size = Vector2(452, 70)
	body.custom_minimum_size = Vector2(452, 0)
	p.add_child(body)
	var v := VBoxContainer.new()
	v.position = Vector2(24, 150)
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var b1 := UIKit.cta_button(Locale.t("atlas_travel_halt_stop"), "A", 452, 40)
	b1.name = "HaltStop"
	b1.pressed.connect(func():
		_halt_after_leg = true
		_halted_dest = str(World.travel.get("dest", "")) if World.is_traveling() else _halted_dest
		_clear_modal()
		if not _busy and World.is_traveling():
			_run_travel())
	v.add_child(b1)
	var b2 := UIKit.ghost_button(Locale.t("atlas_travel_halt_continue"), 452, 36)
	b2.name = "HaltContinue"
	b2.pressed.connect(_clear_modal)
	v.add_child(b2)
	var b3 := UIKit.ghost_button(Locale.t("atlas_travel_halt_leave"), 452, 36)
	b3.name = "HaltLeave"
	b3.pressed.connect(func():
		_travel_abort = true
		_halt_after_leg = false
		World.cancel_travel()
		_set_busy(false)
		_clear_modal()
		_goto(StoryCatalog.take_story_return(CASTLE_SCENE)))
	v.add_child(b3)

func _show_stopover_modal() -> void:
	var here := World.pos
	var n: Dictionary = World.node(here)
	var per := World.food_per_day()
	var cover := 0 if per <= 0 else int(GameState.food / per)
	var days := 7
	var q: Dictionary = World.resupply_quote(here, days)
	var h := 320.0
	if _halted_dest != "" and _halted_dest != here:
		h = 360.0
	var p := _modal_panel(h)
	p.name = "StopoverModal"
	CKHeraldryChrome.place_travel_crest_strip(p, Vector2(400, 14), World.nation_of(here), Vector2(36, 44))
	var t := UIKit.title_label(Locale.t("atlas_stopover_title"), 22)
	t.position = Vector2(24, 20)
	p.add_child(t)
	var body := UIKit.body_label(Locale.t("atlas_stopover_body") % [n.get("name", here), GameState.food, per], UIKit.TEXT, 13)
	body.position = Vector2(24, 58)
	body.size = Vector2(452, 52)
	body.custom_minimum_size = Vector2(452, 0)
	p.add_child(body)
	var food_l := UIKit.body_label(Locale.t("atlas_stopover_food") % [GameState.food, cover], UIKit.OK if cover >= days else UIKit.DANGER, 13)
	food_l.name = "StopoverFood"
	food_l.position = Vector2(24, 112)
	p.add_child(food_l)
	# Produce loop teaser at stopover
	var best: Dictionary = World.best_produce_trade(here)
	if not best.is_empty():
		var tip := UIKit.body_label(Locale.t("atlas_trade_loop_best") % [str(best.name), str(best.sell_name), int(best.margin)], UIKit.EMBER, 12)
		tip.name = "StopoverTradeTip"
		tip.position = Vector2(24, 134)
		tip.size = Vector2(452, 18)
		tip.autowrap_mode = TextServer.AUTOWRAP_OFF
		tip.clip_text = true
		p.add_child(tip)
	var v := VBoxContainer.new()
	v.name = "StopoverActions"
	v.position = Vector2(24, 160)
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var buy := UIKit.cta_button(Locale.t("atlas_stopover_buy") % [int(q.get("days", days)), int(q.get("qty", 0)), int(q.get("cost", 0))], "A", 452, 40)
	buy.name = "StopoverBuy"
	buy.disabled = not bool(q.get("ok", false)) or bool(q.get("short_silver", false))
	buy.pressed.connect(func():
		var r: Dictionary = World.resupply_food(here, days)
		if bool(r.get("ok", false)):
			_show_toast(Locale.t("atlas_resupply_ok") % [int(r.get("qty", 0)), int(r.get("cost", 0)), GameState.food], UIKit.OK)
			_refresh_top()
			_show_stopover_modal()
		else:
			_show_toast(str(r.get("msg", "")), UIKit.DANGER))
	v.add_child(buy)
	var mkt := UIKit.ghost_button(Locale.t("atlas_stopover_market"), 452, 36)
	mkt.name = "StopoverMarket"
	mkt.pressed.connect(func():
		_clear_modal()
		GameState.set_meta("city_tab", "market")
		_enter_here())
	v.add_child(mkt)
	if _halted_dest != "" and _halted_dest != here:
		var dest_n := str(World.node(_halted_dest).get("name", _halted_dest))
		var resume := UIKit.ghost_button(Locale.t("atlas_stopover_resume") % dest_n, 452, 36)
		resume.name = "StopoverResume"
		resume.pressed.connect(func():
			var dest := _halted_dest
			_halted_dest = ""
			_clear_modal()
			_select_node(dest)
			var st: Dictionary = World.begin_travel(dest)
			if bool(st.get("ok", false)):
				_run_travel()
			else:
				_show_toast(str(st.get("msg", "")), UIKit.DANGER))
		v.add_child(resume)
	var later := UIKit.ghost_button(Locale.t("atlas_stopover_dismiss"), 452, 32)
	later.name = "StopoverDismiss"
	later.pressed.connect(func():
		_clear_modal())
	v.add_child(later)

func _show_turnin_modal(readies: int) -> void:
	var ready: Array = World.ready_turn_ins_here()
	var list_bits: Array = []
	for q in ready:
		list_bits.append(Locale.t("atlas_turnin_list_row") % [str(q.get("title", "")), int(q.get("reward_silver", 0))])
	var list_txt := "\n".join(list_bits) if not list_bits.is_empty() else Locale.t("atlas_turnin_modal_body") % readies
	var h := 260.0 + 18.0 * mini(4, list_bits.size())
	var p := _modal_panel(h)
	p.name = "TurnInReadyModal"
	var t := UIKit.title_label(Locale.t("atlas_turnin_modal_title"), 22)
	t.position = Vector2(24, 20)
	p.add_child(t)
	var body := UIKit.body_label(Locale.t("atlas_turnin_modal_body") % maxi(readies, ready.size()), UIKit.TEXT, 13)
	body.name = "TurnInBody"
	body.position = Vector2(24, 58)
	body.size = Vector2(452, 28)
	p.add_child(body)
	var lst := UIKit.body_label(list_txt, UIKit.OK, 12)
	lst.name = "TurnInList"
	lst.position = Vector2(24, 90)
	lst.size = Vector2(452, 18.0 * mini(4, maxi(1, list_bits.size())) + 8.0)
	lst.custom_minimum_size = Vector2(452, 0)
	p.add_child(lst)
	var y := h - 100.0
	var now := UIKit.cta_button(Locale.t("atlas_turnin_modal_now"), "A", 452, 40)
	now.name = "TurnInNow"
	now.position = Vector2(24, y)
	now.pressed.connect(func():
		var gained := 0
		var titles: Array = []
		var follow: Dictionary = {}
		for q2 in World.ready_turn_ins_here().duplicate():
			var tr: Dictionary = World.turn_in(str(q2.get("id", "")))
			if bool(tr.get("ok", false)):
				gained += int(q2.get("reward_silver", 0))
				titles.append(str(q2.get("title", "")))
				var nxt = tr.get("follow", {})
				if typeof(nxt) == TYPE_DICTIONARY and not (nxt as Dictionary).is_empty():
					follow = nxt
		_clear_modal()
		_refresh_top()
		_build_nodes()
		_render_right()
		_render_left()
		_render_hud()
		if not titles.is_empty():
			_show_toast(Locale.t("atlas_turnin_now_toast") % [titles.size(), gained], UIKit.OK)
		else:
			_show_toast(Locale.t("atlas_turnin_now_none"), UIKit.DANGER)
		if not follow.is_empty():
			await _show_chain_advance_modal(follow))
	p.add_child(now)
	var go := UIKit.ghost_button(Locale.t("atlas_turnin_modal_go"), 220, 36)
	go.name = "TurnInEnter"
	go.position = Vector2(24, y + 48)
	go.pressed.connect(func():
		_clear_modal()
		GameState.set_meta("city_tab", "board")
		_enter_here())
	p.add_child(go)
	var later := UIKit.ghost_button(Locale.t("atlas_turnin_modal_later"), 200, 36)
	later.name = "TurnInLater"
	later.position = Vector2(256, y + 48)
	later.pressed.connect(_clear_modal)
	p.add_child(later)

func _after_chain_start(dest: String) -> void:
	_refresh_top()
	_build_nodes()
	_render_right()
	if dest != "" and World.nodes.has(dest):
		_select_node(dest)

func _startable_chain_here() -> String:
	## First idle scripted chain whose step-0 issuer is the selected (current) city.
	if _sel == "" or _sel != World.pos:
		return ""
	for row in World.scripted_chains():
		var cid := str(row.get("id", ""))
		if cid == "":
			continue
		var st: Dictionary = World.chain_status(cid)
		var sst := str(st.get("status", "idle"))
		if sst != "idle" and sst != "":
			continue
		var steps: Array = row.get("steps", [])
		if steps.is_empty():
			continue
		if str(steps[0].get("issuer", "")) == World.pos:
			return cid
	return ""

func _show_chain_advance_modal(follow: Dictionary) -> void:
	## After turn-in: next multi-city chain step — accept / march / later.
	if follow.is_empty():
		return
	var chain_id := str(follow.get("scripted_chain", ""))
	var chain: Dictionary = {}
	if chain_id != "":
		for row in World.scripted_chains():
			if str(row.get("id", "")) == chain_id:
				chain = row
				break
	var step_i := int(follow.get("scripted_step", 0))
	var steps_n := int(chain.get("steps", []).size()) if not chain.is_empty() else 0
	var issuer := str(follow.get("issuer", ""))
	var target := str(follow.get("target", ""))
	var title_q := str(follow.get("title", ""))
	var chain_title := str(chain.get("title", chain_id)) if not chain.is_empty() else Locale.t("atlas_chain_follow_fallback")
	var h := 320.0
	var p := _modal_panel(h)
	p.name = "ChainAdvanceModal"
	var el := UIKit.mono(Locale.t("atlas_chain_en"), 9, UIKit.OK)
	el.position = Vector2(24, 16)
	p.add_child(el)
	var tlabel := UIKit.title_label(Locale.t("atlas_chain_title") % chain_title, 20)
	tlabel.position = Vector2(24, 34)
	tlabel.size = Vector2(452, 30)
	p.add_child(tlabel)
	var prog := ""
	if steps_n > 0:
		prog = Locale.t("atlas_chain_step") % [step_i + 1, steps_n]
	var body := UIKit.body_label(
		Locale.t("atlas_chain_body") % [title_q, World.node(issuer).get("name", issuer), World.node(target).get("name", target), prog],
		UIKit.TEXT, 13)
	body.name = "ChainAdvanceBody"
	body.position = Vector2(24, 72)
	body.size = Vector2(452, 64)
	body.custom_minimum_size = Vector2(452, 0)
	p.add_child(body)
	var done := false
	var y := 150.0
	var acc := UIKit.cta_button(Locale.t("atlas_chain_accept"), "A", 300, 42)
	acc.name = "ChainAccept"
	acc.position = Vector2(24, y)
	acc.pressed.connect(func():
		var ar: Dictionary = World.accept_quest(issuer, str(follow.get("id", "")))
		_show_toast(str(ar.get("msg", "")), UIKit.OK if bool(ar.get("ok", false)) else UIKit.DANGER)
		var dest2 := target if bool(ar.get("ok", false)) else ""
		done = true
		_clear_modal()
		call_deferred("_after_chain_start", dest2))
	p.add_child(acc)
	y += 50.0
	var march := UIKit.cta_button(Locale.t("atlas_chain_march"), "B", 300, 42)
	march.name = "ChainMarch"
	march.position = Vector2(24, y)
	march.pressed.connect(func():
		var st2: Dictionary = World.chain_status(chain_id) if chain_id != "" else {}
		if bool(st2.get("on_board", false)) or str(follow.get("state", "")) == "offer":
			World.accept_quest(issuer, str(follow.get("id", "")))
		var qlive := World.quest_by_id(str(follow.get("id", "")))
		var dest := str(qlive.get("target", target))
		if dest == "":
			dest = target
		done = true
		_clear_modal()
		_refresh_top()
		_build_nodes()
		if dest != "":
			_select_node(dest)
			_start_travel())
	p.add_child(march)
	var later := UIKit.ghost_button(Locale.t("atlas_chain_later"), 140, 42)
	later.name = "ChainLater"
	later.position = Vector2(24, h - 64)
	later.pressed.connect(func():
		done = true
		_clear_modal())
	p.add_child(later)
	acc.call_deferred("grab_focus")
	World.last_chain_follow = {}
	while not done and is_instance_valid(p) and p.get_parent() != null:
		await get_tree().process_frame

## Mid-march food=0 → SupplyHaltModal (觅食 / 硬闯 / 强制停靠).
func _check_supply_halt() -> bool:
	if not _modal.get_children().is_empty():
		return false
	if World.last_supply_halt.is_empty():
		return false
	var halt: Dictionary = World.take_supply_halt()
	if halt.is_empty():
		return false
	_show_supply_halt_modal(halt)
	return true

func _show_supply_halt_modal(halt: Dictionary) -> void:
	var dest := str(halt.get("dest", ""))
	var starved := int(halt.get("starved_days", 1))
	var h := 360.0
	var panel := _modal_panel(h)
	panel.name = "SupplyHaltModal"
	var el := UIKit.mono(Locale.t("atlas_supply_halt_en"), 9, UIKit.DANGER)
	el.position = Vector2(24, 16)
	panel.add_child(el)
	var tlabel := UIKit.title_label(Locale.t("atlas_supply_halt_title"), 20, UIKit.DANGER)
	tlabel.position = Vector2(24, 34)
	tlabel.size = Vector2(452, 30)
	panel.add_child(tlabel)
	var dest_n := str(World.node(dest).get("name", dest)) if dest != "" else "—"
	var body := UIKit.body_label(
		Locale.t("atlas_supply_halt_body") % [World.node(World.pos).get("name", World.pos), dest_n, starved, GameState.morale],
		UIKit.TEXT, 13)
	body.name = "SupplyHaltBody"
	body.position = Vector2(24, 72)
	body.size = Vector2(452, 78)
	body.custom_minimum_size = Vector2(452, 0)
	panel.add_child(body)
	var y := 164.0
	var forage := UIKit.cta_button(Locale.t("atlas_supply_forage"), "A", 452, 42)
	forage.name = "SupplyForage"
	forage.position = Vector2(24, y)
	forage.pressed.connect(func():
		var r: Dictionary = World.forage_supply()
		_show_toast(str(r.get("msg", "")), UIKit.OK if bool(r.get("ok", false)) else UIKit.DANGER)
		_clear_modal()
		_refresh_top()
		if World.is_traveling():
			call_deferred("_resume_travel_after_supply"))
	panel.add_child(forage)
	y += 50.0
	var press := UIKit.ghost_button(Locale.t("atlas_supply_press"), 452, 36)
	press.name = "SupplyPressOn"
	press.position = Vector2(24, y)
	press.pressed.connect(func():
		var r2: Dictionary = World.press_on_starving()
		_show_toast(str(r2.get("msg", "")), UIKit.EMBER)
		_clear_modal()
		_refresh_top()
		if World.is_traveling():
			call_deferred("_resume_travel_after_supply"))
	panel.add_child(press)
	y += 44.0
	var stop := UIKit.ghost_button(Locale.t("atlas_supply_forced_stop"), 452, 36)
	stop.name = "SupplyForcedStop"
	stop.position = Vector2(24, y)
	stop.pressed.connect(func():
		var r3: Dictionary = World.forced_halt_march()
		_halted_dest = str(r3.get("dest", dest))
		_show_toast(str(r3.get("msg", "")), UIKit.ACCENT)
		_clear_modal()
		_refresh_top()
		_build_nodes()
		_render_left()
		_place_token(false)
		_select_node(World.pos)
		_show_stopover_modal())
	panel.add_child(stop)
	var later := UIKit.ghost_button(Locale.t("atlas_supply_halt_later"), 140, 36)
	later.name = "SupplyHaltLater"
	later.position = Vector2(24, h - 56)
	later.pressed.connect(func():
		World.last_supply_halt = halt.duplicate(true)
		_clear_modal())
	panel.add_child(later)
	forage.call_deferred("grab_focus")

## Month crossed with owned holdings → TerritoryMonthModal (yield / drain / lost / reclaim).
func _check_territory_month() -> bool:
	if not _modal.get_children().is_empty():
		return false
	if World.last_territory_month.is_empty():
		return false
	var rep: Dictionary = World.take_territory_month()
	if rep.is_empty():
		return false
	_show_territory_month_modal(rep)
	return true


func _show_territory_month_modal(rep: Dictionary) -> void:
	var silver := int(rep.get("silver", 0))
	var food := int(rep.get("food", 0))
	var owned := int(rep.get("owned", 0))
	var drains: Array = rep.get("drains", [])
	var lost: Array = rep.get("lost", [])
	var held: Array = rep.get("held", [])
	var threats: Array = rep.get("threats", [])
	var reclaims: Array = rep.get("reclaims", [])
	# Month modal already surfaces lost+reclaim — consume contest news so LossModal does not stack.
	if not lost.is_empty():
		CKTerritory.take_news()
	var bits: Array = []
	if not drains.is_empty():
		var names: Array = []
		for d in drains:
			names.append("%s→%d" % [str(d.get("name", "")), int(d.get("garrison", 0))])
		bits.append(Locale.t("atlas_terr_month_drain") % "、".join(names))
	if not lost.is_empty():
		var ln: Array = []
		for row in lost:
			ln.append(str(row.get("name", "")))
		bits.append(Locale.t("atlas_terr_month_lost") % "、".join(ln))
	if not held.is_empty():
		var hn: Array = []
		for row in held:
			hn.append("%s(%d→%d)" % [str(row.get("name", "")), int(row.get("garrison_before", 0)), int(row.get("garrison", 0))])
		bits.append(Locale.t("atlas_terr_month_held") % "、".join(hn))
	if not threats.is_empty():
		var tn: Array = []
		for row in threats:
			tn.append("%s·%s" % [str(row.get("name", "")), str(row.get("by", ""))])
		bits.append(Locale.t("atlas_terr_month_threat") % "、".join(tn))
	var extra := " ".join(bits) if not bits.is_empty() else Locale.t("atlas_terr_month_none")
	var h := 340.0 if reclaims.is_empty() else 390.0
	var panel := _modal_panel(h)
	panel.name = "TerritoryMonthModal"
	var el := UIKit.mono(Locale.t("atlas_terr_month_en"), 9, UIKit.ACCENT)
	el.position = Vector2(24, 16)
	panel.add_child(el)
	var tlabel := UIKit.title_label(Locale.t("atlas_terr_month_title"), 20, UIKit.ACCENT)
	tlabel.position = Vector2(24, 34)
	tlabel.size = Vector2(452, 30)
	panel.add_child(tlabel)
	var body := UIKit.body_label(
		Locale.t("atlas_terr_month_body") % [silver, food, owned, extra],
		UIKit.TEXT, 13)
	body.name = "TerritoryMonthBody"
	body.position = Vector2(24, 72)
	body.size = Vector2(452, 120)
	body.custom_minimum_size = Vector2(452, 0)
	panel.add_child(body)
	var y := 210.0
	var ok := UIKit.cta_button(Locale.t("atlas_terr_month_ok"), "A", 452, 42)
	ok.name = "TerritoryMonthOk"
	ok.position = Vector2(24, y)
	ok.pressed.connect(func():
		_clear_modal()
		_refresh_top()
		_build_nodes()
		if _check_siege_alert():
			return
		if _check_march_muster():
			return
		if World.is_traveling():
			call_deferred("_resume_travel_after_territory_month"))
	panel.add_child(ok)
	y += 50.0
	if not reclaims.is_empty():
		var rid := str(reclaims[0])
		var anchor := str(CKTerritory.site(rid).get("anchor", ""))
		var reclaim_btn := UIKit.ghost_button(Locale.t("atlas_terr_month_reclaim"), 452, 36)
		reclaim_btn.name = "TerritoryMonthReclaim"
		reclaim_btn.position = Vector2(24, y)
		reclaim_btn.pressed.connect(func():
			_clear_modal()
			_refresh_top()
			_build_nodes()
			_render_left()
			if anchor != "" and World.nodes.has(anchor):
				_select_node(anchor)
			_show_toast(Locale.t("terr_54"), UIKit.EMBER)
			if World.is_traveling():
				World.cancel_travel())
		panel.add_child(reclaim_btn)
		y += 44.0
	var later := UIKit.ghost_button(Locale.t("atlas_terr_month_later"), 140, 36)
	later.name = "TerritoryMonthLater"
	later.position = Vector2(24, h - 56)
	later.pressed.connect(func():
		World.last_territory_month = rep.duplicate(true)
		_clear_modal())
	panel.add_child(later)
	ok.call_deferred("grab_focus")


func _resume_travel_after_territory_month() -> void:
	if World.is_traveling() and World.pending_event.is_empty() and World.encounter.is_empty():
		_run_travel()


## Rival siege / threat → SiegeAlertModal (relief / bribe / scout / later).
func _check_siege_alert() -> bool:
	if not _modal.get_children().is_empty():
		return false
	if World.last_siege_alert.is_empty():
		return false
	var alert: Dictionary = World.take_siege_alert()
	if alert.is_empty():
		return false
	_show_siege_alert_modal(alert)
	return true


func _show_siege_alert_modal(alert: Dictionary) -> void:
	var site_id := str(alert.get("id", ""))
	var site_name := str(alert.get("name", site_id))
	var by_name := str(alert.get("by_name", ""))
	var anchor := str(alert.get("anchor", ""))
	var anchor_name := str(alert.get("anchor_name", World.node(anchor).get("name", anchor)))
	var garrison := int(alert.get("garrison", 0))
	var phase := str(alert.get("phase", "declared"))
	var scouted := bool(alert.get("scouted", false))
	var hold_pct := int(alert.get("hold_pct", -1))
	var bribe_c := int(alert.get("bribe_cost", 50))
	if site_id != "":
		bribe_c = int(alert.get("bribe_cost", CKTerritory.bribe_cost(site_id)))
	var scout_c := int(alert.get("scout_cost", 20))
	if site_id != "":
		scout_c = int(alert.get("scout_cost", CKTerritory.scout_cost(site_id)))
	var at_anchor := World.pos == anchor and anchor != ""
	var phase_line := Locale.t("atlas_siege_phase_imminent") if phase == "imminent" else Locale.t("atlas_siege_phase_declared")
	var intel_line := Locale.t("atlas_siege_intel") % hold_pct if scouted and hold_pct >= 0 else Locale.t("atlas_siege_intel_unknown")
	var h := 420.0
	var panel := _modal_panel(h)
	panel.name = "SiegeAlertModal"
	var el := UIKit.mono(Locale.t("atlas_siege_en"), 9, UIKit.DANGER)
	el.position = Vector2(24, 16)
	panel.add_child(el)
	var tlabel := UIKit.title_label(Locale.t("atlas_siege_title"), 20, UIKit.DANGER)
	tlabel.position = Vector2(24, 34)
	tlabel.size = Vector2(452, 30)
	panel.add_child(tlabel)
	var body := UIKit.body_label(
		Locale.t("atlas_siege_body") % [by_name, site_name, anchor_name, garrison, phase_line, intel_line],
		UIKit.TEXT, 13)
	body.name = "SiegeAlertBody"
	body.position = Vector2(24, 72)
	body.size = Vector2(452, 100)
	body.custom_minimum_size = Vector2(452, 0)
	panel.add_child(body)
	var y := 186.0
	var relief_label := Locale.t("atlas_siege_intercept") if at_anchor else Locale.t("atlas_siege_relief")
	var relief := UIKit.cta_button(relief_label, "A", 452, 42)
	relief.name = "SiegeRelief"
	relief.position = Vector2(24, y)
	relief.pressed.connect(func():
		if site_id == "":
			_clear_modal()
			return
		if World.pos == anchor:
			var r: Dictionary = CKTerritory.intercept(site_id)
			_show_toast(str(r.get("msg", "")), UIKit.OK if bool(r.get("ok", false)) else UIKit.DANGER)
			_clear_modal()
			_refresh_top()
			_build_nodes()
			if bool(r.get("ok", false)) and not World.encounter.is_empty():
				_show_encounter_modal(World.encounter)
			return
		var st: Dictionary = World.begin_travel(anchor)
		if bool(st.get("ok", false)):
			_show_toast(Locale.t("atlas_siege_relief_go") % anchor_name, UIKit.ACCENT)
			_clear_modal()
			_refresh_top()
			call_deferred("_run_travel")
		else:
			_show_toast(str(st.get("msg", "")), UIKit.DANGER)
			World.last_siege_alert = alert.duplicate(true)
			_clear_modal()
			_show_siege_alert_modal(alert))
	panel.add_child(relief)
	y += 50.0
	var bribe := UIKit.ghost_button(Locale.t("atlas_siege_bribe") % bribe_c, 452, 36)
	bribe.name = "SiegeBribe"
	bribe.position = Vector2(24, y)
	bribe.pressed.connect(func():
		var r2: Dictionary = CKTerritory.bribe_threat(site_id)
		_show_toast(str(r2.get("msg", "")), UIKit.OK if bool(r2.get("ok", false)) else UIKit.DANGER)
		_clear_modal()
		_refresh_top()
		_build_nodes()
		if World.is_traveling():
			call_deferred("_resume_travel_after_siege"))
	panel.add_child(bribe)
	y += 44.0
	var scout := UIKit.ghost_button(Locale.t("atlas_siege_scout") % scout_c, 452, 36)
	scout.name = "SiegeScout"
	scout.position = Vector2(24, y)
	scout.pressed.connect(func():
		var r3: Dictionary = CKTerritory.scout_threat(site_id)
		_show_toast(str(r3.get("msg", "")), UIKit.OK if bool(r3.get("ok", false)) else UIKit.DANGER)
		if bool(r3.get("ok", false)):
			var intel: Dictionary = r3.get("intel", {})
			alert["scouted"] = true
			alert["hold_pct"] = int(intel.get("hold_pct", int(round(CKTerritory.hold_chance(site_id) * 100.0))))
			alert["garrison"] = int(intel.get("garrison", garrison))
			var bl: Label = panel.get_node_or_null("SiegeAlertBody") as Label
			if bl != null:
				var pl := Locale.t("atlas_siege_phase_imminent") if str(alert.get("phase", "")) == "imminent" else Locale.t("atlas_siege_phase_declared")
				var il := Locale.t("atlas_siege_intel") % int(alert["hold_pct"])
				bl.text = Locale.t("atlas_siege_body") % [by_name, site_name, anchor_name, int(alert["garrison"]), pl, il]
			scout.disabled = true
		else:
			pass)
	panel.add_child(scout)
	var later := UIKit.ghost_button(Locale.t("atlas_siege_later"), 140, 36)
	later.name = "SiegeLater"
	later.position = Vector2(24, h - 56)
	later.pressed.connect(func():
		World.last_siege_alert = alert.duplicate(true)
		_clear_modal()
		if World.is_traveling():
			call_deferred("_resume_travel_after_siege"))
	panel.add_child(later)
	relief.call_deferred("grab_focus")


func _resume_travel_after_siege() -> void:
	if World.is_traveling() and World.pending_event.is_empty() and World.encounter.is_empty():
		_run_travel()


## Road merc hire → MarchMusterModal (编制 / 日耗粮 refresh).
func _check_march_muster() -> bool:
	if not _modal.get_children().is_empty():
		return false
	if World.last_march_muster.is_empty():
		return false
	var mm: Dictionary = World.take_march_muster()
	if mm.is_empty():
		return false
	_show_march_muster_modal(mm)
	return true


func _show_march_muster_modal(mm: Dictionary) -> void:
	var who := str(mm.get("name", ""))
	var cost := int(mm.get("cost", 0))
	var p0 := int(mm.get("party_before", 0))
	var p1 := int(mm.get("party_after", World.party_size()))
	var r0 := int(mm.get("ration_before", 0))
	var r1 := int(mm.get("ration_after", World.food_per_day()))
	var ration_txt := str(mm.get("ration_text", World.food_ration_text()))
	var on_march := bool(mm.get("traveling", World.is_traveling()))
	var note := Locale.t("atlas_muster_on_march") if on_march else Locale.t("atlas_muster_in_camp")
	var h := 320.0
	var panel := _modal_panel(h)
	panel.name = "MarchMusterModal"
	var el := UIKit.mono(Locale.t("atlas_muster_en"), 9, UIKit.OK)
	el.position = Vector2(24, 16)
	panel.add_child(el)
	var tlabel := UIKit.title_label(Locale.t("atlas_muster_title"), 20, UIKit.OK)
	tlabel.position = Vector2(24, 34)
	tlabel.size = Vector2(452, 30)
	panel.add_child(tlabel)
	var body := UIKit.body_label(
		Locale.t("atlas_muster_body") % [who, p0, p1, r0, r1, note],
		UIKit.TEXT, 13)
	body.name = "MarchMusterBody"
	body.position = Vector2(24, 72)
	body.size = Vector2(452, 72)
	body.custom_minimum_size = Vector2(452, 0)
	panel.add_child(body)
	var cost_l := UIKit.body_label(Locale.t("atlas_muster_cost") % cost, UIKit.EMBER, 13)
	cost_l.name = "MarchMusterCost"
	cost_l.position = Vector2(24, 152)
	cost_l.size = Vector2(452, 24)
	panel.add_child(cost_l)
	var ration_l := UIKit.body_label(Locale.t("atlas_muster_ration") % ration_txt, UIKit.ACCENT, 13)
	ration_l.name = "MarchMusterRation"
	ration_l.position = Vector2(24, 180)
	ration_l.size = Vector2(452, 36)
	panel.add_child(ration_l)
	var ok := UIKit.cta_button(Locale.t("atlas_muster_continue"), "A", 220, 42)
	ok.name = "MarchMusterOk"
	ok.position = Vector2(24, h - 64)
	ok.pressed.connect(func():
		World.dismiss_march_muster()
		_clear_modal()
		_refresh_top()
		_render_left())
	panel.add_child(ok)
	ok.call_deferred("grab_focus")


func _await_march_muster_closed() -> void:
	while true:
		var panel: Node = _modal.get_node_or_null("MarchMusterModal")
		if panel == null:
			break
		await get_tree().process_frame


func _resume_travel_after_supply() -> void:
	if World.is_traveling() and World.pending_event.is_empty() and World.encounter.is_empty():
		_run_travel()

## Scripted-chain expire/abandon → ChainFailModal (改道 / 确认失败 / 稍后).
func _check_chain_fail() -> bool:
	if not _modal.get_children().is_empty():
		return false
	if World.last_chain_fail.is_empty():
		return false
	var fail: Dictionary = World.take_chain_fail()
	if fail.is_empty():
		return false
	_show_chain_fail_modal(fail)
	return true

func _show_chain_fail_modal(fail: Dictionary) -> void:
	var chain_id := str(fail.get("chain_id", ""))
	var chain_title := str(fail.get("chain_title", chain_id))
	var reason := str(fail.get("reason", "expire"))
	var why := Locale.t("atlas_chain_fail_reason_expire") if reason == "expire" else Locale.t("atlas_chain_fail_reason_abandon")
	var step_i := int(fail.get("step", 0))
	var issuer := str(fail.get("issuer", ""))
	var target := str(fail.get("target", ""))
	var title_q := str(fail.get("title", ""))
	var h := 340.0
	var p := _modal_panel(h)
	p.name = "ChainFailModal"
	var el := UIKit.mono(Locale.t("atlas_chain_fail_en"), 9, UIKit.DANGER)
	el.position = Vector2(24, 16)
	p.add_child(el)
	var tlabel := UIKit.title_label(Locale.t("atlas_chain_fail_title") % chain_title, 20, UIKit.DANGER)
	tlabel.position = Vector2(24, 34)
	tlabel.size = Vector2(452, 30)
	p.add_child(tlabel)
	var body := UIKit.body_label(
		Locale.t("atlas_chain_fail_body") % [title_q, why, step_i + 1, World.node(issuer).get("name", issuer), World.node(target).get("name", target)],
		UIKit.TEXT, 13)
	body.name = "ChainFailBody"
	body.position = Vector2(24, 72)
	body.size = Vector2(452, 72)
	body.custom_minimum_size = Vector2(452, 0)
	p.add_child(body)
	var y := 160.0
	var reroute := UIKit.cta_button(Locale.t("atlas_chain_reroute"), "A", 300, 42)
	reroute.name = "ChainReroute"
	reroute.position = Vector2(24, y)
	reroute.pressed.connect(func():
		var rr: Dictionary = World.reroute_failed_chain(chain_id)
		_show_toast(str(rr.get("msg", "")), UIKit.OK if bool(rr.get("ok", false)) else UIKit.DANGER)
		_clear_modal()
		if bool(rr.get("ok", false)):
			var q: Dictionary = rr.get("quest", {})
			var dest := str(q.get("issuer", issuer))
			call_deferred("_after_chain_start", dest))
	p.add_child(reroute)
	y += 50.0
	var drop := UIKit.ghost_button(Locale.t("atlas_chain_fail_confirm"), 300, 42)
	drop.name = "ChainFailConfirm"
	drop.position = Vector2(24, y)
	drop.pressed.connect(func():
		World.dismiss_chain_fail()
		_show_toast(Locale.t("atlas_chain_fail_done") % chain_title, UIKit.EMBER)
		_clear_modal()
		_refresh_top()
		_build_nodes())
	p.add_child(drop)
	var later := UIKit.ghost_button(Locale.t("atlas_chain_later"), 140, 42)
	later.name = "ChainFailLater"
	later.position = Vector2(24, h - 64)
	later.pressed.connect(func():
		# Keep fail status; restore payload so modal can reopen next arrival/resume.
		World.last_chain_fail = fail.duplicate(true)
		_clear_modal())
	p.add_child(later)
	reroute.call_deferred("grab_focus")

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
	var rect := Rect2(390, 360 - h * 0.5, 500, h)
	if _mob:
		var w := MobilePage.width(self)
		var pw := minf(560.0, w - 48.0)
		var ph := minf(maxf(h, 220.0), 720.0 - MobilePage.TOP - 24.0)
		rect = Rect2((w - pw) * 0.5, maxf(MobilePage.TOP, (720.0 - ph) * 0.5), pw, ph)
	var p := UIKit.panel_at(_modal, rect, 14, true)
	p.add_theme_stylebox_override("panel", UIKit.glass(14, 0.92, true))
	UIFX.pop_in(p)
	return p

func _show_event_modal(ev: Dictionary) -> void:
	var opts: Array = ev.get("options", [])
	var is_camp := str(ev.get("kind", "")) == "camp" or str(ev.get("id", "")) == "camp_night"
	var p := _modal_panel(210 + 58 * opts.size() + (28 if is_camp else 0))
	p.name = "EventModal"
	var kind := str(ev.get("kind", "road"))
	var camp_like := kind == "camp" or str(ev.get("id", "")) == "camp_night"
	var ev_nid := World.nation_of(str(ev.get("b", ev.get("node", World.pos))))
	if ev_nid == "":
		ev_nid = World.nation_of(World.pos)
	if camp_like:
		CKHeraldryChrome.place_camp_crest_strip(p, Vector2(400, 12), ev_nid, Vector2(36, 44))
	else:
		CKHeraldryChrome.place_travel_crest_strip(p, Vector2(400, 12), ev_nid, Vector2(36, 44))
	var tag := "NIGHT CAMP" if camp_like else "ROAD EVENT"
	var el := UIKit.mono("%s // %s" % [tag, World.node(str(ev.get("b", ""))).get("name", "")], 9, UIKit.ACCENT)
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
	var camp_y := 182.0
	if kind == "camp" or str(ev.get("id", "")) == "camp_night":
		var cr: Dictionary = World.camp_readout(ev)
		var short_s := Locale.t("atlas_camp_short") if bool(cr.get("short", false)) else Locale.t("atlas_camp_ok")
		var ctxt := Locale.t("atlas_camp_readout") % [int(cr.food), int(cr.per_day), int(cr.remain_days), int(cr.remain_food), short_s]
		var cl := UIKit.body_label(ctxt, UIKit.DANGER if bool(cr.get("short", false)) else UIKit.OK, 12)
		cl.name = "CampReadout"
		cl.position = Vector2(24, 168)
		cl.size = Vector2(452, 20)
		cl.autowrap_mode = TextServer.AUTOWRAP_OFF
		cl.clip_text = true
		p.add_child(cl)
		camp_y = 196.0
	var v := VBoxContainer.new()
	v.position = Vector2(24, camp_y)
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var first: Button = null
	var ctx: Dictionary = ev.get("ctx", {})
	for i in opts.size():
		var o: Dictionary = opts[i]
		var fx: Dictionary = o.get("fx", {})
		var hint := _fx_hint(fx, ctx, ev)
		var b := UIKit.index_button("%d" % (i + 1), str(o.get("label", "")), 452)
		b.custom_minimum_size = Vector2(452, 38)
		b.add_theme_font_size_override("font_size", 14)
		UIKit.compact(b, 38)
		b.name = "EventOpt%d" % i
		b.tooltip_text = hint
		var idx := i
		b.pressed.connect(func(): _choose_event(idx))
		v.add_child(b)
		if hint != "":
			var hl := UIKit.body_label(hint, UIKit.TEXT_DIM, 11)
			hl.name = "EventFx%d" % i
			hl.custom_minimum_size = Vector2(452, 16)
			hl.autowrap_mode = TextServer.AUTOWRAP_OFF
			hl.clip_text = true
			v.add_child(hl)
		if first == null:
			first = b
	if first:
		first.call_deferred("grab_focus")

func _fx_hint(fx: Dictionary, ctx: Dictionary = {}, ev: Dictionary = {}) -> String:
	var bits: Array = World.event_fx_preview(fx, ctx, ev)
	if bits.is_empty():
		# camp flags still surface via camp_* keys
		if fx.has("heal"):
			bits.append(Locale.t("camp_hint_heal"))
		if fx.has("morale"):
			bits.append(Locale.t("camp_hint_morale") % int(fx.morale))
		if str(fx.get("flag", "")) == "camp_watch":
			bits.append(Locale.t("camp_hint_watch"))
	return " · ".join(bits)

func _choose_event(idx: int) -> void:
	var r: Dictionary = World.choose_event(idx)
	_clear_modal()
	if not r.get("encounter", {}).is_empty():
		_show_encounter_modal(r.encounter)
		return
	var af: Dictionary = r.get("aftermath", World.last_aftermath)
	if typeof(af) == TYPE_DICTIONARY and not af.is_empty():
		await _show_aftermath_modal(af)
	else:
		_show_toast(str(r.get("msg", "")), UIKit.ACCENT)
	_refresh_top()
	_render_left()
	if _check_march_muster():
		await _await_march_muster_closed()
		_refresh_top()
		_render_left()
	if World.is_traveling() and World.encounter.is_empty():
		_place_token(true)
		await get_tree().create_timer(STEP_SEC).timeout
		_run_travel()
	elif not World.encounter.is_empty():
		_show_encounter_modal(World.encounter)
	else:
		_after_arrival()



func _show_battle_aftermath_modal(af: Dictionary) -> void:
	var win := bool(af.get("win", false))
	var lines: Array = af.get("lines", [])
	var detail := " · ".join(lines) if not lines.is_empty() else str(af.get("msg", ""))
	var h := 280.0 + 16.0 * mini(3, lines.size())
	var p := _modal_panel(h)
	p.name = "BattleAftermathModal"
	var foe_nid := str(af.get("nation", ""))
	if foe_nid == "":
		foe_nid = str(World.encounter.get("nation", ""))
	CKHeraldryChrome.place_aftermath_crest_strip(p, Vector2(400, 14), foe_nid, Vector2(36, 44))
	var tag := Locale.t("atlas_battle_aftermath_win_en") if win else Locale.t("atlas_battle_aftermath_lose_en")
	if str(af.get("kind", "")) == "rival":
		tag = Locale.t("atlas_rival_aftermath_en") if win else Locale.t("atlas_rival_aftermath_lose_en")
	var el := UIKit.mono("%s // %s" % [tag, str(af.get("title", ""))], 9, UIKit.OK if win else UIKit.DANGER)
	el.position = Vector2(24, 18)
	p.add_child(el)
	var t := UIKit.title_label(Locale.t("atlas_battle_aftermath_title_win") if win else Locale.t("atlas_battle_aftermath_title_lose"), 22)
	t.position = Vector2(24, 36)
	p.add_child(t)
	var dl := UIKit.body_label(detail, UIKit.TEXT, 13)
	dl.name = "BattleAftermathLines"
	dl.position = Vector2(24, 78)
	dl.size = Vector2(452, 72)
	dl.custom_minimum_size = Vector2(452, 0)
	p.add_child(dl)
	var sum := Locale.t("atlas_battle_aftermath_summary") % [int(af.get("silver_now", GameState.silver)), int(af.get("silver_delta", 0))]
	if str(af.get("quest_note", "")) != "":
		sum += " · " + Locale.t("atlas_battle_aftermath_quest") % str(af.quest_note)
	var sl := UIKit.body_label(sum, UIKit.OK if win else UIKit.DANGER, 13)
	sl.name = "BattleAftermathSummary"
	sl.position = Vector2(24, 158)
	sl.size = Vector2(452, 36)
	p.add_child(sl)
	var resume := bool(af.get("resume_travel", false)) and World.is_traveling()
	var cta_label := Locale.t("atlas_battle_aftermath_resume") if resume else Locale.t("atlas_battle_aftermath_continue")
	var done := false
	var cont := UIKit.cta_button(cta_label, "A", 280, 42)
	cont.name = "BattleAftermathContinue"
	cont.position = Vector2(24, h - 64)
	cont.pressed.connect(func():
		done = true
		_clear_modal())
	p.add_child(cont)
	cont.call_deferred("grab_focus")
	while not done and is_instance_valid(p) and p.get_parent() != null:
		await get_tree().process_frame
	if bool(af.get("site_captured", false)):
		await _show_occupy_garrison_modal(af)

func _show_occupy_garrison_modal(af: Dictionary) -> void:
	## Post-assault occupy: reinforce / stockade before the player leaves the captured seat.
	var sid := str(af.get("site", ""))
	if sid == "" or not CKTerritory.owned(sid):
		return
	var st0: Dictionary = CKTerritory.state(sid)
	var sname := str(af.get("site_name", CKTerritory.site(sid).get("name", "")))
	var h := 310.0
	var p := _modal_panel(h)
	p.name = "OccupyGarrisonModal"
	var el := UIKit.mono(Locale.t("atlas_occupy_en"), 9, UIKit.OK)
	el.position = Vector2(24, 18)
	p.add_child(el)
	var t := UIKit.title_label(Locale.t("atlas_occupy_title") % sname, 22)
	t.position = Vector2(24, 36)
	t.size = Vector2(452, 32)
	p.add_child(t)
	var body := UIKit.body_label(
		Locale.t("atlas_occupy_body") % [int(st0.get("garrison", 0)), CKTerritory.garrison_max(sid)],
		UIKit.TEXT, 13)
	body.name = "OccupyBody"
	body.position = Vector2(24, 78)
	body.size = Vector2(452, 48)
	body.custom_minimum_size = Vector2(452, 0)
	p.add_child(body)
	var done := false
	var y := 140.0
	if int(st0.get("garrison", 0)) < CKTerritory.garrison_max(sid):
		var rf := UIKit.cta_button(Locale.t("atlas_occupy_reinforce") % CKTerritory.garrison_cost(sid), "A", 300, 42)
		rf.name = "OccupyReinforce"
		rf.position = Vector2(24, y)
		rf.pressed.connect(func():
			var rr: Dictionary = CKTerritory.reinforce(sid)
			_show_toast(str(rr.get("msg", "")), UIKit.OK if bool(rr.get("ok", false)) else UIKit.DANGER)
			_refresh_top()
			_build_nodes()
			af["garrison"] = int(CKTerritory.state(sid).garrison)
			var b2: Label = p.get_node_or_null("OccupyBody") as Label
			if b2:
				b2.text = Locale.t("atlas_occupy_body") % [
					int(CKTerritory.state(sid).garrison), CKTerritory.garrison_max(sid)]
			rf.disabled = int(CKTerritory.state(sid).garrison) >= CKTerritory.garrison_max(sid)
			if rf.disabled:
				rf.text = Locale.t("atlas_occupy_reinforce") % 0)
		p.add_child(rf)
		y += 50.0
	if not bool(st0.get("stockade", false)):
		var sk := UIKit.cta_button(Locale.t("atlas_occupy_stockade") % CKTerritory.stockade_cost(), "B", 300, 42)
		sk.name = "OccupyStockade"
		sk.position = Vector2(24, y)
		sk.pressed.connect(func():
			var sr: Dictionary = CKTerritory.build_stockade(sid)
			_show_toast(str(sr.get("msg", "")), UIKit.OK if bool(sr.get("ok", false)) else UIKit.DANGER)
			_refresh_top()
			_build_nodes()
			done = true
			_clear_modal())
		p.add_child(sk)
	var later := UIKit.ghost_button(Locale.t("atlas_occupy_later"), 140, 42)
	later.name = "OccupyLater"
	later.position = Vector2(24, h - 64)
	later.pressed.connect(func():
		done = true
		_clear_modal())
	p.add_child(later)
	var focus_n: Control = p.get_node_or_null("OccupyReinforce")
	if focus_n == null:
		focus_n = p.get_node_or_null("OccupyStockade")
	if focus_n == null:
		focus_n = later
	if focus_n:
		focus_n.call_deferred("grab_focus")
	while not done and is_instance_valid(p) and p.get_parent() != null:
		await get_tree().process_frame

func _show_aftermath_modal(af: Dictionary) -> void:
	var lines: Array = af.get("lines", [])
	var body_bits: Array = []
	for ln in lines:
		body_bits.append(str(ln))
	if str(af.get("route_note", "")) != "":
		body_bits.append(str(af.route_note))
	var food_d := int(af.get("food_delta", 0))
	var silver_d := int(af.get("silver_delta", 0))
	var summary := Locale.t("atlas_aftermath_summary") % [
		int(af.get("food_now", GameState.food)),
		int(af.get("silver_now", GameState.silver)),
		food_d,
		silver_d,
	]
	var h := 260.0 + 18.0 * mini(4, body_bits.size())
	var p := _modal_panel(h)
	p.name = "AftermathModal"
	var is_danger := bool(af.get("danger", false))
	if is_danger:
		var road_nid := str(af.get("nation", ""))
		if road_nid == "":
			road_nid = World.nation_of(str(af.get("node", World.pos)))
		CKHeraldryChrome.place_aftermath_crest_strip(p, Vector2(400, 14), road_nid, Vector2(36, 44))
	else:
		CKHeraldryChrome.place_aftermath_crest_strip(p, Vector2(436, 14), "", Vector2(36, 44))
	var tag := Locale.t("atlas_aftermath_en")
	if is_danger:
		tag = Locale.t("atlas_aftermath_danger_en")
	var el := UIKit.mono("%s // %s" % [tag, str(af.get("title", ""))], 9, UIKit.DANGER if is_danger else UIKit.ACCENT)
	el.position = Vector2(24, 18)
	p.add_child(el)
	var t := UIKit.title_label(Locale.t("atlas_aftermath_title"), 22)
	t.position = Vector2(24, 36)
	p.add_child(t)
	var choice := UIKit.body_label(Locale.t("atlas_aftermath_choice") % str(af.get("choice", "")), UIKit.EMBER, 13)
	choice.name = "AftermathChoice"
	choice.position = Vector2(24, 72)
	choice.size = Vector2(452, 20)
	p.add_child(choice)
	var detail := UIKit.body_label(" · ".join(body_bits) if not body_bits.is_empty() else Locale.t("atlas_aftermath_none"), UIKit.TEXT, 13)
	detail.name = "AftermathLines"
	detail.position = Vector2(24, 98)
	detail.size = Vector2(452, 56)
	detail.custom_minimum_size = Vector2(452, 0)
	p.add_child(detail)
	var sum_l := UIKit.body_label(summary, UIKit.OK if food_d >= 0 and silver_d >= 0 else UIKit.DANGER, 13)
	sum_l.name = "AftermathSummary"
	sum_l.position = Vector2(24, 160)
	sum_l.size = Vector2(452, 36)
	p.add_child(sum_l)
	var done := false
	var cont := UIKit.cta_button(Locale.t("atlas_aftermath_continue"), "A", 220, 42)
	cont.name = "AftermathContinue"
	cont.position = Vector2(24, h - 64)
	cont.pressed.connect(func():
		done = true
		_clear_modal())
	p.add_child(cont)
	cont.call_deferred("grab_focus")
	while not done and is_instance_valid(p) and p.get_parent() != null:
		await get_tree().process_frame

func _show_encounter_modal(enc: Dictionary) -> void:
	var p := _modal_panel(300)
	p.name = "EncounterModal"
	CKHeraldryChrome.place_encounter_crest_strip(p, Vector2(400, 14), str(enc.get("nation", "")), Vector2(36, 44))
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
		var af: Dictionary = r.get("aftermath", World.last_battle_aftermath)
		if typeof(af) == TYPE_DICTIONARY and not af.is_empty():
			await _show_battle_aftermath_modal(af)
		else:
			_show_toast(str(r.get("msg", "")), UIKit.DANGER))
	p.add_child(rb)
	fb.call_deferred("grab_focus")

func _open_territory_site(site_id: String) -> void:
	var anchor := str(CKTerritory.site(site_id).get("anchor", ""))
	if anchor == "":
		return
	_select_node(anchor)
	_open_territory(anchor)

func _open_territory(anchor: String) -> void:
	if CKTerritory.sites_at(anchor).is_empty():
		return
	var p := _modal_panel(CKAtlasTerritory.modal_height(anchor))
	p.name = "TerritoryModal"
	CKAtlasTerritory.fill_modal(p, anchor, func(kind: String, sid: String): _territory_act(kind, sid, anchor))

func _territory_act(kind: String, site_id: String, anchor: String) -> void:
	if kind == "close":
		_clear_modal()
		return
	var r: Dictionary = CKAtlasTerritory.run(kind, site_id)
	_refresh_top()
	_build_nodes()
	_render_right()
	if not r.get("encounter", {}).is_empty():
		_show_encounter_modal(r.encounter)
		return
	_open_territory(anchor)
	_show_toast(str(r.get("msg", "")), UIKit.OK if bool(r.get("ok", false)) else UIKit.DANGER)

func _launch_battle() -> void:
	GameState.set_meta("atlas_after_battle", true)
	GameState.save_game()
	UIFX.page_exit(self)
	World.launch_encounter(get_tree())

func _toast_quest_guide(nid: String) -> void:
	var place := str(World.node(nid).get("name", nid))
	for mk in World.quest_markers().get(nid, []):
		var q: Dictionary = mk.quest
		var col := UIKit.OK if str(mk.kind) == "turnin" else UIKit.DANGER
		_show_toast(Locale.t("wq_atlas_focus") % [str(q.get("title", "")), place], col)
		return
	# gather (no map marker) or deep-link without an active marker
	for q2 in World.active:
		if World.quest_guide_node(q2) == nid:
			_show_toast(Locale.t("wq_atlas_focus") % [str(q2.get("title", "")), place], UIKit.ACCENT)
			return
	_show_toast(Locale.t("wq_atlas_focus_plain") % place, UIKit.ACCENT)


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

## WS-C #41: left list <-> map. World view lights the region button; nation view lights that nation's settlements.
func hilite(nid: String) -> void:
	_hilit = nid
	for k in _list_btn.keys():
		var lb: Button = _list_btn[k]
		if is_instance_valid(lb):
			lb.modulate = Color(1.25, 1.25, 1.35) if k == nid else Color(1, 1, 1)
	for id in _node_btn.keys():
		var nb: Button = _node_btn[id]
		if not is_instance_valid(nb):
			continue
		var on: bool = nid != "" and (id == nid or World.nation_of(str(id)) == nid)
		nb.modulate = Color(1.4, 1.4, 1.5) if on else Color(1, 1, 1)
		nb.pivot_offset = nb.size * 0.5
		nb.scale = Vector2(1.12, 1.12) if on else Vector2.ONE

func _open_deploy() -> void:
	GameState.set_meta("deploy_return", "res://scenes/hub/atlas_view.tscn")
	GameState.set_meta("atlas_view", _view)
	_goto("res://scenes/hub/deploy.tscn")

## WS-C #45: a lost site shows up as a modal the next time the atlas is on screen.
## Improve-plan #1: show the contest report card and point at the auto「反夺」commission.
func _check_losses() -> bool:
	if not _modal.get_children().is_empty():
		return false
	var news: Array = CKTerritory.take_news()
	var lines: Array = []
	var reports: Array = []
	var first_id := ""
	for e in news:
		var s := CKTerritory.site(str(e.get("id", "")))
		if s.is_empty():
			continue
		if first_id == "":
			first_id = str(e.id)
		lines.append(Locale.t("wsc_t_lost_line") % [str(e.get("date", "")), str(s.get("name", "")), str(e.get("who", ""))])
		var rep := str(e.get("report", ""))
		if rep != "":
			reports.append(rep)
	if lines.is_empty():
		return false
	var extra := ("\n" + "\n".join(reports)) if not reports.is_empty() else ""
	var p := _modal_panel(250 + 28 * lines.size() + 22 * reports.size())
	p.name = "LossModal"
	var t := UIKit.title_label(Locale.t("wsc_t_lost_title"), 24, UIKit.DANGER)
	t.position = Vector2(24, 24)
	p.add_child(t)
	var body := UIKit.body_label("\n".join(lines) + extra + "\n" + Locale.t("wsc_t_lost_hint") + "\n" + Locale.t("terr_54"), UIKit.TEXT, 14)
	body.position = Vector2(24, 70)
	body.size = Vector2(452, 80 + 28 * lines.size() + 22 * reports.size())
	p.add_child(body)
	var go := UIKit.ghost_button(Locale.t("wsc_t_lost_go"), 200, 44)
	go.name = "LossGo"
	go.position = Vector2(24, p.size.y - 64)
	go.pressed.connect(_retake.bind(first_id))
	p.add_child(go)
	var ok := UIKit.ghost_button(Locale.t("wsc_t_lost_ok"), 200, 44)
	ok.name = "LossOk"
	ok.position = Vector2(276, p.size.y - 64)
	ok.pressed.connect(_clear_modal)
	p.add_child(ok)
	go.call_deferred("grab_focus")
	return true

func _rival_display_name(rid: String) -> String:
	for rv in World.rivals:
		if str(rv.get("id", "")) == rid:
			return str(rv.get("name", rid))
	return rid

## Drain rival_thefts into RivalTheftModal (atlas surface for CMP-04 thefts).
func _check_rival_thefts() -> bool:
	if not _modal.get_children().is_empty():
		return false
	var news: Array = World.take_rival_thefts()
	if news.is_empty():
		return false
	var lines: Array = []
	var first_city := ""
	for e in news:
		var by := _rival_display_name(str(e.get("by", "")))
		var city := str(e.get("city", ""))
		var cname := str(World.node(city).get("name", city))
		var title := str(e.get("title", ""))
		lines.append(Locale.t("atlas_rival_theft_line") % [by, cname, title])
		if first_city == "" and city != "":
			first_city = city
	var p := _modal_panel(220 + 24 * lines.size())
	p.name = "RivalTheftModal"
	var t := UIKit.title_label(Locale.t("atlas_rival_theft_title"), 24, UIKit.DANGER)
	t.position = Vector2(24, 24)
	p.add_child(t)
	var body := UIKit.body_label("\n".join(lines) + "\n" + Locale.t("atlas_rival_theft_hint"), UIKit.TEXT, 14)
	body.position = Vector2(24, 70)
	body.size = Vector2(452, 60 + 24 * lines.size())
	p.add_child(body)
	var ok := UIKit.ghost_button(Locale.t("atlas_rival_theft_ok"), 200, 44)
	ok.name = "RivalTheftOk"
	ok.position = Vector2(24, p.size.y - 64)
	ok.pressed.connect(_clear_modal)
	p.add_child(ok)
	if first_city != "":
		var go := UIKit.ghost_button(Locale.t("atlas_rival_theft_go"), 200, 44)
		go.name = "RivalTheftGo"
		go.position = Vector2(276, p.size.y - 64)
		go.pressed.connect(func():
			_clear_modal()
			_select_node(first_city)
			if first_city != World.pos:
				_start_travel())
		p.add_child(go)
	ok.call_deferred("grab_focus")
	return true

func _check_arbitrage_arrival() -> bool:
	if not _modal.get_children().is_empty():
		return false
	if World.arbitrage.is_empty():
		return false
	if str(World.arbitrage.get("sell_city", "")) != World.pos:
		return false
	_show_arbitrage_sell_modal()
	return true

func _arb_pending_text(plan: Dictionary) -> String:
	var g := str(plan.get("good", ""))
	var dest := str(plan.get("sell_city", ""))
	var dname := str(World.node(dest).get("name", dest))
	return Locale.t("atlas_arb_pending") % [World.good_name(g), int(plan.get("qty", 1)), dname]

func _start_arbitrage_from_profile(good: String, sell_city: String) -> void:
	var r: Dictionary = World.begin_arbitrage(good, 1, sell_city)
	_show_toast(str(r.get("msg", "")), UIKit.OK if bool(r.get("ok", false)) else UIKit.DANGER)
	if not bool(r.get("ok", false)):
		return
	## Defer rebuild so the ArbitrageRun pressed signal can finish (avoids free-during-emit).
	call_deferred("_after_arbitrage_armed")

func _after_arbitrage_armed() -> void:
	_render_left()
	var dest := str(World.arbitrage.get("sell_city", ""))
	if dest != "" and dest != World.pos:
		_select_node(dest)

func _complete_arbitrage_ui() -> void:
	var r: Dictionary = World.complete_arbitrage()
	_clear_modal()
	_show_toast(str(r.get("msg", "")), UIKit.OK if bool(r.get("ok", false)) else UIKit.DANGER)
	call_deferred("_render_left")

func _show_arbitrage_sell_modal() -> void:
	var plan: Dictionary = World.arbitrage
	var p := _modal_panel(240)
	p.name = "ArbitrageSellModal"
	var t := UIKit.title_label(Locale.t("atlas_arb_sell_title"), 24, UIKit.OK)
	t.position = Vector2(24, 24)
	p.add_child(t)
	var body := UIKit.body_label(_arb_pending_text(plan), UIKit.TEXT, 14)
	body.position = Vector2(24, 70)
	body.size = Vector2(452, 80)
	p.add_child(body)
	var sell := UIKit.ghost_button(Locale.t("atlas_arb_sell_now"), 200, 44)
	sell.name = "ArbitrageSell"
	sell.position = Vector2(24, p.size.y - 64)
	sell.pressed.connect(_complete_arbitrage_ui)
	p.add_child(sell)
	var later := UIKit.ghost_button(Locale.t("atlas_rival_theft_ok"), 200, 44)
	later.name = "ArbitrageLater"
	later.position = Vector2(276, p.size.y - 64)
	later.pressed.connect(_clear_modal)
	p.add_child(later)
	sell.call_deferred("grab_focus")

func _retake(site_id: String) -> void:
	_clear_modal()
	var nat := str(CKTerritory.site(site_id).get("nation", ""))
	if nat != "" and nat != _view:
		_show_view(nat)
	_open_territory_site(site_id)

func _goto(path: String) -> void:
	UIFX.page_exit(self)
	CKNav.go(path)

func _back() -> void:
	if not _modal.get_children().is_empty() and not World.pending_event.is_empty():
		return
	if _busy or World.is_traveling():
		_show_travel_halt_modal()
		return
	_goto(StoryCatalog.take_story_return(CASTLE_SCENE))

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
	_map_content.scale = Vector2(_map_zoom, _map_zoom) * _mbase

func _clamp_map() -> void:
	var shown := MAP.size * _map_zoom * _mbase
	var frame := _clip.size if _clip != null else MAP.size
	_map_pan.x = clampf(_map_pan.x, 40.0 - shown.x, frame.x - 40.0)
	_map_pan.y = clampf(_map_pan.y, 40.0 - shown.y, frame.y - 40.0)

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
		if not World.pending_event.is_empty() and str(World.pending_event.get("id", "")) == "camp_night":
			await _choose_event(0)
			continue
		if not _busy and World.pending_event.is_empty() and World.encounter.is_empty():
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
	var flags := 0
	for c in _layer.get_children():
		if str(c.name).begins_with("Site_"):
			flags += 1
	if flags != CKTerritory.sites_in(_view).size():
		return {"ok": false, "msg": "territory flags %d != %d" % [flags, CKTerritory.sites_in(_view).size()]}
	if flags > 0:
		_open_territory_site(str(CKTerritory.sites_in(_view)[0]))
		if _modal.get_node_or_null("TerritoryModal") == null:
			return {"ok": false, "msg": "territory modal missing"}
		_clear_modal()
	msgs.append("%d territory flags" % flags)
	return {"ok": true, "msg": ", ".join(msgs)}

# ── phone side sheet (container layout only; no reflow of desktop panels) ──
func _m_inner_w() -> float:
	return _col_w - 28.0 - 14.0

func _m_label(t: String, col: Color, fs: int = MobilePage.FONT) -> Label:
	var l := MobilePage.label(t, col, fs, true)
	l.custom_minimum_size.x = 0
	return l

func _m_section(parent: Control, en: String) -> void:
	var hl := UIKit.mono(en, MobilePage.FONT, UIKit.ACCENT, true, false)
	parent.add_child(hl)

func _m_kv(grid: GridContainer, k: String, v: String, col: Color) -> void:
	var kl := _m_label(k, UIKit.TEXT_DIM)
	kl.autowrap_mode = TextServer.AUTOWRAP_OFF
	kl.size_flags_horizontal = Control.SIZE_FILL
	grid.add_child(kl)
	var vl := _m_label(v, col)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(vl)

func _m_grid(parent: Control, cols: int = 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 6)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)
	return g

func _m_chips(parent: Control, chips: Array) -> void:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 6)
	parent.add_child(f)
	for c in chips:
		var chip := UIKit.tag_chip(str(c[0]), c[1], c.size() > 2 and bool(c[2]))
		chip.add_theme_font_size_override("font_size", MobilePage.FONT)
		f.add_child(chip)

func _m_picture(parent: Control, path: String, sel: String) -> void:
	var th := Control.new()
	th.clip_contents = true
	th.custom_minimum_size = Vector2(_m_inner_w(), 170)
	th.size = th.custom_minimum_size
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(th)
	if sel != "":
		_fill_vignette(th, sel)
	elif path != "":
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size = th.size
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		th.add_child(tr)

func _m_button_grid(parent: Control, specs: Array) -> void:
	if specs.is_empty():
		return
	var g := _m_grid(parent, 2)
	for sp in specs:
		var b := MobilePage.button(str(sp[1]), false, sp[2])
		b.name = str(sp[0])
		b.disabled = _busy or (sp.size() > 3 and bool(sp[3]))
		g.add_child(b)

func _m_place() -> void:
	var box := _right
	if _view == "" and World.nations.has(_sel):
		_m_region_profile(box, _sel)
		return
	if not World.nodes.has(_sel):
		box.add_child(_m_label(Locale.t("mob_ui_005"), UIKit.TEXT_DIM))
		return
	var n: Dictionary = World.node(_sel)
	var nat: Dictionary = World.nations.get(str(n.nation), {})
	box.add_child(UIKit.mono("%s // %s" % [str(nat.get("en", "")), World.kind_zh(_sel)], MobilePage.FONT, UIKit.TEXT_FAINT, false, false))
	box.add_child(UIKit.title_label(str(n.get("name", _sel)), 32))
	var chips := [[str(nat.get("name", "")), UIKit.ACCENT], [Locale.t("mob_ui_006") % "▮".repeat(int(n.get("size", 1))), UIKit.TEXT_DIM]]
	if _sel == World.pos:
		chips.append([Locale.t("mob_ui_007"), UIKit.OK, true])
	elif World.visited.has(_sel):
		chips.append([Locale.t("mob_ui_008"), UIKit.TEXT_DIM])
	_m_chips(box, chips)
	if not World.encounter.is_empty():
		var et := UIKit.title_label("⚔ %s" % World.encounter.label, 26, UIKit.DANGER)
		et.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(et)
		box.add_child(_m_label(Locale.t("mob_ui_009"), UIKit.TEXT_DIM))
	elif not _preview.is_empty() and bool(_preview.get("ok", false)):
		_m_route(box)
	var g := _m_grid(box)
	var rep := World.rep_of(_sel)
	_m_kv(g, Locale.t("mob_ui_010"), "%d · %s" % [rep, World.rep_tier_name(rep)], UIKit.ACCENT)
	_m_kv(g, Locale.t("mob_ui_011"), str(n.get("specialty", "")), UIKit.TEXT)
	var prod: Array = []
	for gd in n.get("produce", []):
		prod.append(World.good_name(str(gd)))
	var dem: Array = []
	for gd in n.get("demand", []):
		dem.append(World.good_name(str(gd)))
	_m_kv(g, Locale.t("mob_ui_012"), "、".join(prod) if not prod.is_empty() else "—", UIKit.OK)
	_m_kv(g, Locale.t("mob_ui_013"), "、".join(dem) if not dem.is_empty() else "—", UIKit.EMBER)
	_m_kv(g, Locale.t("mob_ui_014"), Locale.t("mob_ui_015") % World.toll_for(str(n.nation)), UIKit.TEXT)
	var loops_m: Array = World.produce_trade_loop(_sel)
	if not loops_m.is_empty():
		_m_section(box, Locale.t("atlas_trade_loop_title"))
		var loop_sec := VBoxContainer.new()
		loop_sec.name = "TradeLoop"
		loop_sec.add_theme_constant_override("separation", 4)
		box.add_child(loop_sec)
		var shown_m := 0
		for row2 in loops_m:
			if shown_m >= 3:
				break
			var line2 := ""
			if bool(row2.get("known", false)):
				line2 = Locale.t("atlas_trade_loop_line") % [str(row2.name), int(row2.buy), str(row2.sell_name), int(row2.sell), int(row2.margin)]
			else:
				line2 = Locale.t("atlas_trade_loop_unknown") % [str(row2.name), int(row2.buy)]
			var ll2 := _m_label(line2, UIKit.OK if int(row2.get("margin", 0)) > 0 else UIKit.TEXT_DIM)
			ll2.name = "TradeLoop_%d" % shown_m
			loop_sec.add_child(ll2)
			shown_m += 1
		if _sel == World.pos:
			var tbg := MobilePage.button(Locale.t("atlas_trade_loop_goto"), false, func():
				GameState.set_meta("city_tab", "market")
				_enter_here())
			tbg.name = "TradeLoopGoto"
			loop_sec.add_child(tbg)
			var best_m: Dictionary = World.best_produce_trade(_sel)
			if not best_m.is_empty() and bool(best_m.get("known", false)) and World.arbitrage.is_empty():
				var arbm := MobilePage.button(Locale.t("atlas_arb_run"), false, func():
					_start_arbitrage_from_profile(str(best_m.get("good", "")), str(best_m.get("sell_city", ""))))
				arbm.name = "ArbitrageRun"
				loop_sec.add_child(arbm)
			elif not World.arbitrage.is_empty():
				var plan_m: Dictionary = World.arbitrage
				loop_sec.add_child(_m_label(_arb_pending_text(plan_m), UIKit.EMBER))
				if str(plan_m.get("sell_city", "")) == World.pos:
					var sellm := MobilePage.button(Locale.t("atlas_arb_sell_now"), true, func(): _complete_arbitrage_ui())
					sellm.name = "ArbitrageSell"
					loop_sec.add_child(sellm)
				else:
					var marchm := MobilePage.button(Locale.t("atlas_arb_march"), false, func():
						_select_node(str(plan_m.get("sell_city", "")))
						_start_travel())
					marchm.name = "ArbitrageMarch"
					loop_sec.add_child(marchm)
	_m_picture(box, "", _sel)
	var lore := str(n.get("lore", ""))
	if lore != "":
		box.add_child(_m_label(lore, UIKit.TEXT_DIM))
	for mk in World.quest_markers().get(_sel, []):
		var q: Dictionary = mk.quest
		var turnin := str(mk.kind) == "turnin"
		var qt := "%s %s" % [Locale.t("mob_ui_016") if turnin else Locale.t("mob_ui_017"), q.title]
		box.add_child(_m_label(qt, UIKit.OK if turnin else UIKit.DANGER))
	var mm: Dictionary = World.mainline_marker()
	if str(mm.get("node", "")) == _sel:
		box.add_child(_m_label(Locale.t("mob_ui_018") % mm.label, UIKit.EMBER))
	# secondary actions: only the ones that apply here
	var specs: Array = []
	var here := _sel == World.pos
	if here and str(mm.get("node", "")) == _sel and bool(mm.get("exists", false)):
		specs.append(["ChapterButton", Locale.t("mob_ui_019"), func(): _goto(str(mm.path))])
	var engage_q := _engage_quest_id_here()
	if here and engage_q != "":
		specs.append(["EngageButton", Locale.t("mob_ui_020"), func():
			var e: Dictionary = World.quest_engage(engage_q)
			if not e.is_empty():
				_show_encounter_modal(e)])
	if here and not World.rival_here().is_empty() and World.encounter.is_empty():
		specs.append(["RivalClash", Locale.t("atlas_rival_clash_cta"), func():
			var e3: Dictionary = World.rival_clash()
			if not e3.is_empty():
				_show_encounter_modal(e3)])
	var sites := CKTerritory.sites_at(_sel).size()
	if sites > 0:
		var anchor_id := _sel
		specs.append(["TerritoryButton", Locale.t("terr_ui_button") + " %d" % sites, func(): _open_territory(anchor_id)])
	_m_button_grid(box, specs)

func _m_route(box: Control) -> void:
	var pv := _preview
	var pth: Array = pv.get("path", [])
	var dest: Dictionary = World.node(str(pth[pth.size() - 1]) if not pth.is_empty() else _sel)
	_m_section(box, Locale.t("mob_ui_021"))
	var names: Array = []
	for id in pth:
		names.append(str(World.node(str(id)).get("name", id)))
	box.add_child(_m_label("→ " + " › ".join(names) if not names.is_empty() else "→ %s" % dest.get("name", ""), UIKit.TEXT))
	var sortie_note := World.city_sortie_route_note(_sel)
	if sortie_note != "":
		var sn := _m_label(sortie_note, UIKit.EMBER)
		sn.name = "CommissionMarchNote"
		box.add_child(sn)
	var g := _m_grid(box, 4)
	var cost := int(pv.tolls) + int(pv.fare)
	for kv in [[Locale.t("mob_ui_022"), Locale.t("mob_ui_023") % int(pv.days), UIKit.TEXT],
			[Locale.t("mob_ui_024"), str(pv.food), UIKit.DANGER if bool(pv.short_food) else UIKit.TEXT],
			[Locale.t("mob_ui_025"), Locale.t("mob_ui_015") % cost, UIKit.DANGER if GameState.silver < cost else UIKit.TEXT],
			[Locale.t("mob_ui_026"), "▮".repeat(int(pv.danger)) + "▯".repeat(maxi(0, 4 - int(pv.danger))), UIKit.DANGER if int(pv.danger) >= 3 else UIKit.ACCENT]]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		var k := _m_label(str(kv[0]), UIKit.TEXT_FAINT)
		k.autowrap_mode = TextServer.AUTOWRAP_OFF
		cell.add_child(k)
		var v := _m_label(str(kv[1]), kv[2])
		v.autowrap_mode = TextServer.AUTOWRAP_OFF
		cell.add_child(v)
		g.add_child(cell)
	var legs_sec := VBoxContainer.new()
	legs_sec.name = "RouteLegs"
	legs_sec.add_theme_constant_override("separation", 2)
	box.add_child(legs_sec)
	var readouts: Array = pv.get("leg_readouts", [])
	var show_n := mini(5, readouts.size())
	for i in show_n:
		var leg: Dictionary = readouts[i]
		var dng := int(leg.get("danger", 1))
		var cost_s := ""
		if int(leg.get("cost", 0)) > 0:
			cost_s = " · " + Locale.t("atlas_chip_silver") % int(leg.cost)
		var line := Locale.t("atlas_leg_line") % [
			str(leg.get("from_name", "")), str(leg.get("to_name", "")),
			int(leg.get("days", 1)), World.danger_bars(dng),
			str(leg.get("kind_zh", "")), cost_s]
		var ll := _m_label(line, UIKit.DANGER if dng >= 3 else UIKit.TEXT_DIM)
		ll.name = "Leg_%d" % i
		legs_sec.add_child(ll)
	if readouts.size() > show_n:
		var more := _m_label(Locale.t("atlas_leg_more") % (readouts.size() - show_n), UIKit.TEXT_FAINT)
		more.name = "LegMore"
		legs_sec.add_child(more)
	var hot_n := int(pv.get("hot_legs", 0))
	if bool(pv.short_food):
		box.add_child(_m_label(Locale.t("mob_ui_027"), UIKit.EMBER))
	elif not (pv.borders as Array).is_empty():
		box.add_child(_m_label(Locale.t("mob_ui_028") % "、".join(pv.borders), UIKit.TEXT_DIM))
	elif hot_n > 0:
		var hw := _m_label(Locale.t("atlas_warn_hot") % hot_n, UIKit.EMBER)
		hw.name = "RouteWarn"
		box.add_child(hw)

func _m_region_profile(box: Control, nid: String) -> void:
	var nat: Dictionary = World.nations.get(nid, {})
	box.add_child(UIKit.mono("NATION // %s" % str(nat.get("en", "")), MobilePage.FONT, UIKit.TEXT_FAINT, false, false))
	box.add_child(UIKit.title_label(str(nat.get("name", nid)), 32))
	if not _preview.is_empty() and bool(_preview.get("ok", false)):
		_m_route(box)
	_m_picture(box, _Atlas.plate_path(str(nat.get("plate", ""))), "")
	var g := _m_grid(box)
	var rep := World.nation_rep(nid)
	_m_kv(g, Locale.t("mob_ui_029"), "%d · %s" % [rep, World.rep_tier_name(rep)], UIKit.ACCENT)
	_m_kv(g, Locale.t("mob_ui_030"), Locale.t("mob_ui_031") % World.nodes_in(nid).size(), UIKit.TEXT)
	_m_kv(g, Locale.t("mob_ui_032"), str(World.node(str(nat.get("capital", ""))).get("name", "—")), UIKit.TEXT)
	_m_kv(g, Locale.t("mob_ui_033"), Locale.t("mob_ui_015") % World.toll_for(nid), UIKit.TEXT)
	_m_kv(g, Locale.t("mob_ui_034"), str(nat.get("smith", "")), UIKit.TEXT)
	var cul := str(nat.get("culture", ""))
	if cul != "":
		box.add_child(_m_label(cul, UIKit.TEXT_DIM))

## Primary action pinned under the sheet: one obvious next step for the selection.
func _m_actions() -> void:
	if _actions == null:
		return
	for c in _actions.get_children():
		_actions.remove_child(c)
		c.free()
	var b: Button
	if not World.encounter.is_empty():
		b = MobilePage.button(Locale.t("mob_ui_035"), true, func(): _show_encounter_modal(World.encounter))
		b.name = "FightButton"
	elif _view == "" and World.nations.has(_sel):
		var nid := _sel
		var nat: Dictionary = World.nations.get(nid, {})
		var dest := str(nat.get("capital", "")) if World.nation_of(World.pos) != nid else World.pos
		b = MobilePage.button(Locale.t("mob_ui_036") % str(nat.get("name", nid)), true, func(): _show_view(nid); _select_node(dest))
		b.name = "EnterRegion"
	elif _sel != "" and _sel == World.pos and World.nodes.has(_sel) and not World.rival_here().is_empty() and World.encounter.is_empty() and World.ready_turn_ins_here().is_empty():
		b = MobilePage.button(Locale.t("atlas_rival_clash_cta"), true, func():
			var e4: Dictionary = World.rival_clash()
			if not e4.is_empty():
				_show_encounter_modal(e4))
		b.name = "RivalClash"
	elif _sel != "" and _sel == World.pos and World.nodes.has(_sel) and _startable_chain_here() != "" and World.ready_turn_ins_here().is_empty():
		var cid_m := _startable_chain_here()
		var crow := {}
		for row in World.scripted_chains():
			if str(row.get("id", "")) == cid_m:
				crow = row
				break
		b = MobilePage.button(Locale.t("atlas_chain_start") % str(crow.get("title", cid_m)), true, func():
			var sr: Dictionary = World.start_scripted_chain(cid_m)
			if not bool(sr.get("ok", false)):
				_show_toast(str(sr.get("msg", "")), UIKit.DANGER)
				return
			var q0: Dictionary = sr.get("quest", {})
			World.accept_quest(str(q0.get("issuer", World.pos)), str(q0.get("id", "")))
			_refresh_top()
			_build_nodes()
			var dest := str(q0.get("target", ""))
			if dest != "":
				_select_node(dest)
				_m_actions())
		b.name = "ChainStart"
	elif _sel != "" and _sel == World.pos and World.nodes.has(_sel):
		var n: Dictionary = World.node(_sel)
		var ready_n := World.ready_turn_ins_here().size()
		if ready_n > 0:
			b = MobilePage.button(Locale.t("atlas_enter_turnin") % ready_n, true, func():
				GameState.set_meta("city_tab", "board")
				_enter_here())
		else:
			b = MobilePage.button(Locale.t("mob_ui_037") % [Locale.t("mob_ui_038") if str(n.kind) == "castle" else World.kind_zh(_sel), str(n.get("name", ""))], true, _enter_here)
		b.name = "EnterButton"
	elif not _preview.is_empty() and bool(_preview.get("ok", false)):
		b = MobilePage.button(Locale.t("mob_ui_039") % int(_preview.days), true, _start_travel)
		b.name = "GoButton"
		b.disabled = GameState.silver < int(_preview.get("fare", 0))
	else:
		b = MobilePage.button(Locale.t("mob_ui_040"), true, func(): pass)
		b.name = "GoButton"
		b.disabled = true
	if _busy:
		b.disabled = true
	_actions.add_child(b)

func _m_log() -> void:
	var box := _hud
	var here: Dictionary = World.node(World.pos)
	var crest_row := Control.new()
	crest_row.name = "TravelCrestHost"
	crest_row.custom_minimum_size = Vector2(0, 44)
	box.add_child(crest_row)
	CKHeraldryChrome.place_travel_crest_strip(crest_row, Vector2(0, 2), World.nation_of(World.pos), Vector2(36, 44))
	box.add_child(UIKit.title_label(Locale.t("mob_ui_041") % here.get("name", ""), 28))
	if not World.last_city_sortie.is_empty():
		var sh := _m_label(World.city_sortie_hud_text(), UIKit.EMBER)
		sh.name = "CitySortieHud"
		sh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(sh)
		var turned := str(World.last_city_sortie.get("state", "")) == "turned_in"
		var sb := MobilePage.button(
			Locale.t("atlas_sortie_dismiss") if turned else Locale.t("atlas_sortie_go"),
			false,
			func():
				if turned:
					World.dismiss_city_sortie()
					_render_left()
					_render_hud()
				else:
					_march_city_sortie())
		sb.name = "CitySortieDismiss" if turned else "CitySortieGo"
		box.add_child(sb)
	box.add_child(_m_label(Locale.t("mob_ui_042"), UIKit.TEXT_DIM))
	for tp in World.tips.slice(0, 3):
		box.add_child(_m_label(Locale.t("mob_ui_043") % str(tp), UIKit.ACCENT))
	_m_button_grid(box, [["CourtNewsOpen", Locale.t("mob_ui_044"), func():
		Sfx.click()
		_goto("res://scenes/hub/court_news.tscn")], ["AtlasDeploy", Locale.t("mob_ui_045"), _open_deploy]])
	_m_section(box, Locale.t("mob_ui_046"))
	if World.travel_log.is_empty():
		box.add_child(_m_label(Locale.t("mob_ui_047"), UIKit.TEXT_FAINT))
	for i in mini(10, World.travel_log.size()):
		box.add_child(_m_label(str(World.travel_log[i]), UIKit.TEXT if i == 0 else UIKit.TEXT_DIM))

func _m_regions() -> void:
	var box := _left
	_m_section(box, Locale.t("mob_ui_048"))
	_list_btn.clear()
	var g := _m_grid(box, 2)
	var wb := MobilePage.button(Locale.t("mob_ui_049"), _view == "", func(): _show_view(""))
	wb.name = "ViewWorld"
	g.add_child(wb)
	for nid in World.nation_ids():
		var nat: Dictionary = World.nations.get(nid, {})
		var here := World.nation_of(World.pos) == str(nid)
		var nid_s := str(nid)
		var b := MobilePage.button("%s%s" % [nat.get("name", nid), " ◉" if here else ""], _view == nid_s, func(): _show_view(nid_s); _set_sheet_tab("place"))
		b.name = "View_" + nid_s
		var rep := World.nation_rep(nid_s)
		b.tooltip_text = Locale.t("mob_ui_050") % [rep, World.rep_tier_name(rep)]
		_list_btn[nid_s] = b
		g.add_child(b)
	_m_section(box, Locale.t("mob_ui_051"))
	var kv := _m_grid(box)
	_m_kv(kv, Locale.t("mob_ui_052"), Locale.t("mob_ui_053") % World.party_size(), UIKit.TEXT)
	_m_kv(kv, Locale.t("mob_ui_054"), "%d" % World.food_per_day(), UIKit.TEXT)
	_m_kv(kv, Locale.t("mob_ui_055"), "%d / %d" % [World.cargo_used(), World.cargo_cap()], UIKit.TEXT)
	_m_kv(kv, Locale.t("mob_ui_056"), "%d / %d" % [World.active.size(), int(World.rules.get("active_limit", 5))], UIKit.ACCENT)
	_m_kv(kv, Locale.t("mob_ui_057"), "T%d" % World.world_tier(), UIKit.TEXT)
	for q in World.active.slice(0, 6):
		var ready := str(q.state) == "ready"
		box.add_child(_m_label("%s %s" % ["✓" if ready else "◆", q.title], UIKit.OK if ready else UIKit.TEXT_DIM))
	if World.active.is_empty():
		box.add_child(_m_label(Locale.t("mob_ui_058"), UIKit.TEXT_FAINT))
