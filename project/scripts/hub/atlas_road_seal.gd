extends Control
## Atlas overlay for winter-sealed roads. Lives beside atlas_view so the
## march page can show a blocked road, a detour, and an arrival sheet
## without editing the travel autoload or the atlas script.

const Seal := preload("res://scripts/company/road_seal.gd")

var _page: Control
var _ink: Control
var _choice: Control
var _march: Label
var _arrive: Control
var _legend: Label
var _mode := ""
var _reason := ""
var _hops: Array = []
var _expect := ""
var _final := ""
var _day0 := 0
var _food0 := 0
var _cmp: Dictionary = {}
var _sig := ""
var _launched := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parent := get_parent()
	if parent != null and not parent.ready.is_connected(_bind):
		if parent.is_node_ready():
			_bind()
		else:
			parent.ready.connect(_bind, CONNECT_ONE_SHOT)

func _bind() -> void:
	_page = get_parent() as Control
	_ensure_ink()

func _process(_dt: float) -> void:
	if _page == null or not is_instance_valid(_page):
		return
	_ensure_ink()
	if _ink != null:
		_ink.queue_redraw()
	_sync_legend()
	if _mode == "detour":
		_tick_detour()
		_paint_march()
		return
	if _mode == "road":
		_tick_road()
		_paint_march()
		return
	if _mode == "arrived":
		return
	_sync_choice()

func _ensure_ink() -> void:
	if _ink != null and is_instance_valid(_ink):
		return
	if _page == null:
		return
	var map := _page.find_child("MapContent", true, false) as Control
	if map == null:
		return
	var ink := Control.new()
	ink.name = "SealMarks"
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.size = map.size
	ink.draw.connect(_paint_marks)
	map.add_child(ink)
	var roads := map.find_child("Roads", false, false)
	if roads != null:
		map.move_child(ink, roads.get_index() + 1)
	_ink = ink

func _sync_legend() -> void:
	var nation := str(_page.get("_view"))
	var show := Seal.view_has_seal(nation)
	if not show:
		if _legend != null:
			_legend.visible = false
		return
	if _legend == null:
		_legend = UIKit.body_label(Locale.t("seal_legend"), UIKit.DANGER, 13)
		_legend.name = "SealLegend"
		_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_legend.autowrap_mode = TextServer.AUTOWRAP_OFF
		add_child(_legend)
	_legend.visible = true
	_legend.text = Locale.t("seal_legend")
	if bool(_page.get("_mob")):
		_legend.position = Vector2(24, 108)
		_legend.size = Vector2(520, 28)
	else:
		_legend.position = Vector2(212, 72)
		_legend.size = Vector2(360, 22)

func _sync_choice() -> void:
	if World.is_traveling() or not World.pending_event.is_empty():
		_clear_choice()
		return
	var sel := str(_page.get("_sel"))
	if sel == "" or sel == World.pos or not World.nodes.has(sel):
		_clear_choice()
		_cmp = {}
		return
	var cmp := Seal.compare(sel)
	_cmp = cmp
	if not bool(cmp.get("sealed", false)):
		_clear_choice()
		return
	var sig := "%s|%s|%d|%d" % [sel, str(cmp.get("direct_text", "")), GameState.food, World.day]
	if _choice == null or sig != _sig:
		_sig = sig
		_build_choice(cmp)
	_lock_depart()

func _clear_choice() -> void:
	if _choice != null and is_instance_valid(_choice):
		_choice.queue_free()
	_choice = null
	_sig = ""

func _lock_depart() -> void:
	if _choice == null:
		return
	for node_name in ["HudGo", "GoButton"]:
		var button := _page.find_child(node_name, true, false) as Button
		if button != null:
			button.disabled = true

func _build_choice(cmp: Dictionary) -> void:
	_clear_choice()
	_sig = "%s|%s|%d|%d" % [str(cmp.get("dest", "")), str(cmp.get("direct_text", "")), GameState.food, World.day]
	var mob := bool(_page.get("_mob"))
	var rect := Rect2(212, 100, 560, 330) if not mob else Rect2(24, 148, 680, 420)
	var panel := UIKit.panel_at(self, rect, 12)
	panel.name = "BlockedRoadSheet"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 4
	_choice = panel
	var box := VBoxContainer.new()
	box.position = Vector2(16, 12)
	box.size = Vector2(rect.size.x - 32, rect.size.y - 24)
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var en := UIKit.mono(Locale.t("seal_sheet_en"), 11, UIKit.DANGER)
	en.name = "SealEyebrow"
	box.add_child(en)
	var title := UIKit.title_label(Locale.t("seal_sheet_title"), 22 if not mob else 28, UIKit.DANGER)
	title.name = "SealTitle"
	box.add_child(title)
	var reason := _line(Locale.t("seal_reason") % [
		Seal.WINDOW_DAYS, Seal.SEAL_DANGER,
		int(cmp.get("direct_days", 0)), int(cmp.get("direct_food", 0)),
	], UIKit.TEXT, rect.size.x - 32)
	reason.name = "SealReason"
	box.add_child(reason)
	var direct := _line(Locale.t("seal_direct") % str(cmp.get("direct_text", "")), UIKit.DANGER, rect.size.x - 32)
	direct.name = "SealDirect"
	box.add_child(direct)
	var detour: Dictionary = cmp.get("detour", {})
	var detour_line := Locale.t("seal_detour_none")
	if bool(detour.get("ok", false)):
		detour_line = Locale.t("seal_detour") % [
			str(detour.get("text", "")), int(detour.get("extra_days", 0)), int(detour.get("food", 0)),
		]
	var detour_lbl := _line(detour_line, UIKit.ACCENT if bool(detour.get("ok", false)) else UIKit.TEXT_DIM, rect.size.x - 32)
	detour_lbl.name = "SealDetourPath"
	box.add_child(detour_lbl)
	var food := _line(Locale.t("seal_food") % [
		int(cmp.get("food_now", 0)), int(cmp.get("per_day", 0)),
		int(cmp.get("direct_food", 0)), int(detour.get("food", 0)), int(cmp.get("wait_food", 0)),
	], UIKit.TEXT, rect.size.x - 32)
	food.name = "SealFood"
	box.add_child(food)
	if bool(cmp.get("short_direct", false)) or bool(cmp.get("short_detour", false)) or bool(cmp.get("short_wait", false)):
		var short := _line(Locale.t("seal_short"), UIKit.EMBER, rect.size.x - 32)
		short.name = "SealShort"
		box.add_child(short)
	var wait_hint := _line(Locale.t("seal_wait_hint") % [int(cmp.get("wait_days", 0)), int(cmp.get("wait_food", 0))], UIKit.TEXT_DIM, rect.size.x - 32)
	wait_hint.name = "SealWaitHint"
	box.add_child(wait_hint)
	var force_hint := _line(Locale.t("seal_force_hint") % int(cmp.get("force_morale", Seal.FORCE_MORALE)), UIKit.TEXT_DIM, rect.size.x - 32)
	force_hint.name = "SealForceHint"
	box.add_child(force_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var hit := 48 if not mob else int(MobilePage.HIT)
	var detour_btn := UIKit.cta_button(Locale.t("seal_btn_detour"), "A", 160, hit)
	detour_btn.name = "SealDetour"
	detour_btn.disabled = not bool(detour.get("ok", false))
	detour_btn.pressed.connect(_on_detour)
	row.add_child(detour_btn)
	var wait_btn := UIKit.ghost_button(Locale.t("seal_btn_wait"), 168, hit)
	wait_btn.name = "SealWait"
	wait_btn.disabled = int(cmp.get("wait_days", 0)) <= 0
	wait_btn.pressed.connect(_on_wait)
	row.add_child(wait_btn)
	var force_btn := UIKit.ghost_button(Locale.t("seal_btn_force"), 148, hit)
	force_btn.name = "SealForce"
	force_btn.pressed.connect(_on_force)
	row.add_child(force_btn)

func _line(text: String, col: Color, width: float) -> Label:
	var label := UIKit.body_label(text, col, 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.size = Vector2(width, 0)
	return label

func _on_detour() -> void:
	var detour: Dictionary = _cmp.get("detour", {})
	if not bool(detour.get("ok", false)):
		return
	var path: Array = detour.get("path", [])
	if path.size() < 2:
		return
	var dest_name := str(_cmp.get("dest_name", ""))
	_begin("detour", str(_cmp.get("dest", "")), path)
	World._tlog(Locale.t("seal_log_detour") % dest_name)

func _on_wait() -> void:
	var dest := str(_cmp.get("dest", ""))
	_food0 = GameState.food
	_day0 = World.days_total
	var waited := Seal.commit_wait()
	if not bool(waited.get("ok", false)):
		_toast(str(waited.get("msg", "")))
		return
	_begin("road", dest, [])
	_reason = "wait"
	_food0 = int(waited.get("food_before", _food0))
	_day0 = World.days_total - int(waited.get("days", 0))

func _on_force() -> void:
	var dest := str(_cmp.get("dest", ""))
	var food0 := GameState.food
	var day0 := World.days_total
	var forced := Seal.commit_force(dest)
	if not bool(forced.get("ok", false)):
		_toast(str(forced.get("msg", "")))
		return
	_begin("road", dest, [])
	_reason = "force"
	_food0 = food0
	_day0 = day0

func _begin(mode: String, dest: String, path: Array) -> void:
	_mode = mode
	_reason = mode
	_final = dest
	_hops = path.duplicate()
	_expect = World.pos
	_day0 = World.days_total
	_food0 = GameState.food
	_launched = false
	_clear_choice()
	_cmp = {}
	if mode == "detour" and path.size() >= 2:
		World.note_seal_detour(dest, path)
	_paint_march()

func _tick_detour() -> void:
	if _blocked():
		return
	if World.pos != _expect:
		return
	while _hops.size() > 1 and str(_hops[0]) != World.pos:
		_hops.pop_front()
	if _hops.size() <= 1:
		_show_arrive()
		return
	var nxt := str(_hops[1])
	_expect = nxt
	_launch(nxt)

func _tick_road() -> void:
	if _blocked():
		return
	if not _launched:
		_launch(_final)
		return
	if World.pos == _final:
		_show_arrive()

func _blocked() -> bool:
	if bool(_page.get("_busy")) or World.is_traveling():
		return true
	if not World.pending_event.is_empty() or not World.encounter.is_empty():
		return true
	var modal := _page.get_node_or_null("Modal") as Control
	return modal != null and modal.get_child_count() > 0

func _launch(dest: String) -> void:
	_launched = true
	_page.set("_sel", dest)
	if _page.has_method("_start_travel"):
		_page.call("_start_travel")
	if not World.is_traveling() and World.pos != dest:
		_fail_march()

func _fail_march() -> void:
	_mode = ""
	_toast(Locale.t("seal_march_fail"))

func _paint_march() -> void:
	if _march == null or not is_instance_valid(_march):
		_march = UIKit.body_label("", UIKit.TEXT, 14)
		_march.name = "MarchPathStrip"
		_march.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_march.autowrap_mode = TextServer.AUTOWRAP_OFF
		_march.clip_text = true
		add_child(_march)
	var nxt := _expect if _expect != "" else _final
	var nxt_name := str(World.node(nxt).get("name", nxt))
	_march.text = Locale.t("seal_march") % [nxt_name, World.days_total - _day0, GameState.food]
	_march.visible = _mode == "detour" or _mode == "road"
	if bool(_page.get("_mob")):
		_march.position = Vector2(24, 140)
		_march.size = Vector2(760, 28)
	else:
		_march.position = Vector2(212, 72)
		_march.size = Vector2(560, 24)
	if _legend != null and _march.visible:
		_legend.visible = false

func _show_arrive() -> void:
	if _mode == "arrived":
		return
	if World.pos == _final:
		World.clear_seal_detour()
	var why := Locale.t("seal_arrive_detour")
	if _reason == "force":
		why = Locale.t("seal_arrive_force")
	elif _reason == "wait":
		why = Locale.t("seal_arrive_wait")
	_mode = "arrived"
	if _march != null:
		_march.visible = false
	_clear_choice()
	var mob := bool(_page.get("_mob"))
	var rect := Rect2(360, 180, 520, 300) if not mob else Rect2(180, 140, 720, 380)
	var panel := UIKit.panel_at(self, rect, 12)
	panel.name = "ArriveSheet"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 5
	_arrive = panel
	var box := VBoxContainer.new()
	box.position = Vector2(18, 14)
	box.size = Vector2(rect.size.x - 36, rect.size.y - 28)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UIKit.mono(Locale.t("seal_arrive_en"), 11, UIKit.OK))
	var title := UIKit.title_label(Locale.t("seal_arrive_title") % str(World.node(World.pos).get("name", World.pos)), 22)
	title.name = "ArriveTitle"
	box.add_child(title)
	var body := _line(Locale.t("seal_arrive_body") % [
		why, World.days_total - _day0, GameState.food, _food0,
	], UIKit.TEXT, rect.size.x - 36)
	body.name = "ArriveDays"
	box.add_child(body)
	var food := _line(Locale.t("seal_food") % [
		GameState.food, World.food_per_day(), 0, 0, 0,
	], UIKit.TEXT_DIM, rect.size.x - 36)
	food.name = "ArriveFood"
	box.add_child(food)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var hit := 48 if not mob else int(MobilePage.HIT)
	_add_enter(row, "ArriveEnter", Locale.t("seal_arrive_enter"), "", hit)
	_add_enter(row, "ArriveMarket", Locale.t("seal_arrive_market"), "market", hit)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	box.add_child(row2)
	if World.smith_tier(World.pos) > 0:
		_add_enter(row2, "ArriveSmith", Locale.t("seal_arrive_smith"), "smith", hit)
	if int(World.node(World.pos).get("tavern_slots", 0)) > 0:
		_add_enter(row2, "ArriveTavern", Locale.t("seal_arrive_tavern"), "tavern", hit)
	_add_enter(row2, "ArriveBoard", Locale.t("seal_arrive_board"), "board", hit)

func _add_enter(row: HBoxContainer, node_name: String, text: String, tab: String, hit: int) -> void:
	var button := UIKit.cta_button(text, "", 150, hit) if tab == "market" else UIKit.ghost_button(text, 140, hit)
	button.name = node_name
	button.pressed.connect(func(): _enter(tab))
	row.add_child(button)

func _enter(tab: String) -> void:
	if tab != "":
		GameState.set_meta("city_tab", tab)
	if _page.has_method("_enter_here"):
		_page.call("_enter_here")

func _toast(text: String) -> void:
	if text == "":
		return
	if _page.has_method("_show_toast"):
		_page.call("_show_toast", text, UIKit.DANGER)

func _paint_marks() -> void:
	if _ink == null or _page == null:
		return
	var nation := str(_page.get("_view"))
	if nation == "" or not _page.has_method("_np"):
		return
	for road in World.data.get("roads", []):
		var a := str(road.get("a", ""))
		var b := str(road.get("b", ""))
		if World.nation_of(a) != nation or World.nation_of(b) != nation:
			continue
		if not Seal.is_sealed(a, b):
			continue
		var p0: Vector2 = _page.call("_np", a)
		var p1: Vector2 = _page.call("_np", b)
		_ink.draw_line(p0, p1, Color(UIKit.DANGER, 0.9), 3.0, true)
		var mid := (p0 + p1) * 0.5
		_ink.draw_line(mid + Vector2(-7, -7), mid + Vector2(7, 7), UIKit.DANGER, 2.5, true)
		_ink.draw_line(mid + Vector2(-7, 7), mid + Vector2(7, -7), UIKit.DANGER, 2.5, true)
	var detour: Dictionary = _cmp.get("detour", {})
	var path: Array = detour.get("path", [])
	if _mode == "detour" and _hops.size() >= 2:
		path = _hops
	for i in range(maxi(0, path.size() - 1)):
		var from_id := str(path[i])
		var to_id := str(path[i + 1])
		if World.nation_of(from_id) != nation or World.nation_of(to_id) != nation:
			continue
		var q0: Vector2 = _page.call("_np", from_id)
		var q1: Vector2 = _page.call("_np", to_id)
		_ink.draw_line(q0, q1, Color(UIKit.ACCENT, 0.95), 4.0, true)
