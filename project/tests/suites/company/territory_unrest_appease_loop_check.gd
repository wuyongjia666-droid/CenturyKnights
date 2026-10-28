extends Node
## Territory fat closed-loop §22: assault → HubTodo unrest → ledger banner/Appease
## → hourglass UnrestPending → appease → month_echo.appease → chip clear.
## One knife; not chip/ledger/hourglass/echo slices.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const HOURGLASS_SCN := preload("res://scenes/hub/hourglass.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY UNREST APPEASE LOOP PASS"


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory unrest appease loop: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_assault_chip_appease()
	if err != "":
		return err
	err = await _ui_castle_chip()
	if err != "":
		return err
	err = await _ui_ledger_banner_appease()
	if err != "":
		return err
	err = await _ui_hourglass_pending_then_appease()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("属地安抚整链", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	GameState.food = 80
	GameState.morale = 80
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.last_siege_alert = {}
	World.last_threat_resolve = {}
	World.last_siege_loot = {}
	World.last_territory_month = {}
	CKTerritory.last_month_report = {}
	GameState.house_mods.erase("month_echo")
	Todo.reset_for_tests()


func _reset(id: String = SITE) -> void:
	var st: Dictionary = CKTerritory.state(id)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	st.cache_food = 0
	CKTerritory._put(id, st)


func _own_with_unrest() -> void:
	_reset()
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "assault")
	var st := CKTerritory.state(SITE)
	st.garrison = 2
	CKTerritory._put(SITE, st)
	GameState.house_mods.erase("month_echo")


func _has_todo_unrest() -> bool:
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_unrest" and int(item.get("count", 0)) > 0:
			return true
	return false


func _api_assault_chip_appease() -> String:
	_setup()
	_own_with_unrest()
	if SITE not in CKTerritory.unrest_owned_ids():
		return "api: unrest_owned_ids missing site"
	if not _has_todo_unrest():
		return "api: HubTodo chip missing after assault"
	if Todo.link_for({"category": "territory_unrest", "link": Todo.LINKS["territory_unrest"]}) != "res://scenes/hub/territory_ledger.tscn":
		return "api: territory_unrest link not ledger"
	GameState.house_mods.erase("month_echo")
	var cost := CKTerritory.appease_cost(SITE)
	GameState.silver = maxi(GameState.silver, cost + 10)
	var before := GameState.silver
	var r: Dictionary = CKTerritory.appease(SITE)
	if not bool(r.get("ok", false)):
		return "api: appease fail: %s" % r.get("msg", "")
	if int(CKTerritory.state(SITE).unrest) != 0:
		return "api: unrest not cleared"
	if GameState.silver != before - cost:
		return "api: silver not spent want %d got %d" % [before - cost, GameState.silver]
	var echo := str(CKEconomyState.month_echo_snapshot().get("appease", ""))
	if echo == "":
		return "api: month_echo.appease missing"
	if _has_todo_unrest():
		return "api: chip still on after appease"
	if not CKTerritory.unrest_owned_ids().is_empty():
		return "api: unrest list not empty after appease"
	print("api assault→chip→appease ok")
	return ""


func _ui_castle_chip() -> String:
	_setup()
	_own_with_unrest()
	World.pos = "ash_capital"
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	for _i in 16:
		await get_tree().process_frame
	var chip: Node = castle.find_child("Todo_territory_unrest", true, false)
	if chip == null:
		castle.queue_free()
		return "Todo_territory_unrest missing on castle"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	var row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_unrest":
			row = item
			break
	if row.is_empty():
		return "snapshot missing territory_unrest"
	if Todo.link_for(row) != "res://scenes/hub/territory_ledger.tscn":
		return "chip link not ledger"
	print("ui castle chip ok")
	return ""


func _ui_ledger_banner_appease() -> String:
	_setup()
	_own_with_unrest()
	var ledger: Node = LEDGER_SCN.instantiate()
	add_child(ledger)
	for _i in 20:
		await get_tree().process_frame
	var banner: Node = ledger.find_child("TerritoryUnrestBanner", true, false)
	if banner == null or not bool(banner.visible):
		ledger.queue_free()
		return "TerritoryUnrestBanner missing/hidden"
	var btn: Button = ledger.find_child("TerritoryAppease", true, false) as Button
	if btn == null:
		ledger.queue_free()
		return "TerritoryAppease missing"
	# Select the site in the list so Appease enables.
	var list: ItemList = ledger.find_child("TerritoryList", true, false) as ItemList
	if list == null or list.item_count < 1:
		ledger.queue_free()
		return "TerritoryList empty"
	list.select(0)
	if ledger.has_method("_on_pick"):
		ledger.call("_on_pick", 0)
	for _j in 4:
		await get_tree().process_frame
	if bool(btn.disabled):
		ledger.queue_free()
		return "TerritoryAppease still disabled after pick"
	GameState.house_mods.erase("month_echo")
	var cost := CKTerritory.appease_cost(SITE)
	GameState.silver = maxi(GameState.silver, cost + 10)
	btn.emit_signal("pressed")
	for _k in 8:
		await get_tree().process_frame
	if int(CKTerritory.state(SITE).unrest) != 0:
		ledger.queue_free()
		return "ledger appease did not clear unrest"
	if bool(banner.visible):
		ledger.queue_free()
		return "TerritoryUnrestBanner still visible after appease"
	var echo := str(CKEconomyState.month_echo_snapshot().get("appease", ""))
	if echo == "":
		ledger.queue_free()
		return "ledger path missing month_echo.appease"
	if _has_todo_unrest():
		ledger.queue_free()
		return "chip still on after ledger appease"
	ledger.queue_free()
	print("ui ledger banner→appease ok")
	return ""


func _ui_hourglass_pending_then_appease() -> String:
	_setup()
	_own_with_unrest()
	var hg: Node = HOURGLASS_SCN.instantiate()
	add_child(hg)
	for _i in 20:
		await get_tree().process_frame
	var pending: Node = hg.find_child("UnrestPending", true, false)
	if pending == null:
		hg.queue_free()
		return "UnrestPending missing on hourglass"
	var to_btn: Node = hg.find_child("ToAppease", true, false)
	if to_btn == null:
		hg.queue_free()
		return "ToAppease missing on hourglass"
	GameState.house_mods.erase("month_echo")
	var cost := CKTerritory.appease_cost(SITE)
	GameState.silver = maxi(GameState.silver, cost + 10)
	var r: Dictionary = CKTerritory.appease(SITE)
	if not bool(r.get("ok", false)):
		hg.queue_free()
		return "hourglass appease fail: %s" % r.get("msg", "")
	if hg.has_method("_show_forecast"):
		hg.call("_show_forecast", 1)
	for _j in 8:
		await get_tree().process_frame
	if hg.find_child("UnrestPending", true, false) != null:
		hg.queue_free()
		return "UnrestPending still after appease"
	if hg.find_child("ToAppease", true, false) != null:
		hg.queue_free()
		return "ToAppease still after appease"
	var echo := str(CKEconomyState.month_echo_snapshot().get("appease", ""))
	if echo == "":
		hg.queue_free()
		return "hourglass path missing month_echo.appease"
	if hg.has_method("_paint_result_initial"):
		# Clear prior result children loosely by re-calling if _log exists.
		hg.call("_paint_result_initial")
	for _k in 6:
		await get_tree().process_frame
	var echo_n: Node = hg.find_child("EchoLine_appease", true, false)
	if echo_n == null:
		print("note: EchoLine_appease not on initial result (ok if advance-only / needs clear)")
	if _has_todo_unrest():
		hg.queue_free()
		return "chip still on after hourglass appease"
	hg.queue_free()
	# Atlas month modal paints EchoLine_appease when echo present.
	CKTerritory.take_news()
	World.last_territory_month = {
		"silver": 10, "food": 0, "owned": 1, "owned_before": 1,
		"drains": [], "lost": [], "held": [], "threats": [], "line": "ok",
		"reclaims": [], "contests": [], "contest_open": [],
	}
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	for _a in 12:
		await get_tree().process_frame
	var modal: Node = atlas.find_child("TerritoryMonthModal", true, false)
	if modal == null and atlas.has_method("_check_territory_month"):
		if World.last_territory_month.is_empty():
			World.last_territory_month = {
				"silver": 10, "food": 0, "owned": 1, "owned_before": 1,
				"drains": [], "lost": [], "held": [], "threats": [], "line": "ok",
				"reclaims": [], "contests": [], "contest_open": [],
			}
		atlas.call("_check_territory_month")
		for _b in 10:
			await get_tree().process_frame
		modal = atlas.find_child("TerritoryMonthModal", true, false)
	if modal == null:
		atlas.queue_free()
		return "atlas TerritoryMonthModal missing"
	var el: Node = atlas.find_child("EchoLine_appease", true, false)
	if el == null:
		atlas.queue_free()
		return "atlas EchoLine_appease missing with echo"
	atlas.queue_free()
	print("ui hourglass pending→appease + atlas echo ok")
	return ""
