extends Node
## Territory fat §24 closed-loop: start_neutral_contest → HubTodo territory_contest →
## atlas focus / ledger goto → hourglass ContestPending → capture → month_echo.contest → chip clear.
## One knife; not chip/ledger/hourglass/echo slices.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const HOURGLASS_SCN := preload("res://scenes/hub/hourglass.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY CONTEST CLOSED LOOP PASS"


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory contest closed loop: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_start_chip_finish()
	if err != "":
		return err
	err = await _ui_castle_chip_focus()
	if err != "":
		return err
	err = await _ui_ledger_banner_goto()
	if err != "":
		return err
	err = await _ui_hourglass_pending_then_finish()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("属地拉锯整链", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = true
	World.rivals = [
		{"id": "rv_a", "name": "灰烬狼团", "pos": "ash_capital", "home": "ash_capital", "stolen": {}, "price_mul": 1.0},
		{"id": "rv_b", "name": "盐湾镖旗", "pos": "ash_capital", "home": "ash_capital", "stolen": {}, "price_mul": 1.0},
	]
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
	World.last_neutral_contest = {}
	CKTerritory.last_month_report = {}
	GameState.house_mods.erase("month_echo")
	Todo.reset_for_tests()
	if GameState.has_meta("atlas_territory_site"):
		GameState.remove_meta("atlas_territory_site")
	if GameState.has_meta("atlas_select"):
		GameState.remove_meta("atlas_select")


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
	World.last_neutral_contest = {}


func _force_factions() -> Array:
	return [
		{"id": "rival:rv_a", "name": "灰烬狼团", "pressure": 3},
		{"id": "rival:rv_b", "name": "盐湾镖旗", "pressure": 2},
	]


func _start() -> String:
	_reset()
	var c := CKTerritory.start_neutral_contest(SITE, _force_factions())
	if c.is_empty():
		return "start_neutral_contest failed"
	return ""


func _has_todo_contest() -> bool:
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_contest" and int(item.get("count", 0)) > 0:
			return true
	return false


func _api_start_chip_finish() -> String:
	_setup()
	var err := _start()
	if err != "":
		return "api: " + err
	var ids: Array = CKTerritory.pending_contest_ids()
	if SITE not in ids:
		return "api: pending_contest_ids missing site: %s" % str(ids)
	if not _has_todo_contest():
		return "api: HubTodo chip missing after start"
	var focused := CKTerritory.hub_focus_contest()
	if focused != SITE:
		return "api: hub_focus_contest want %s got %s" % [SITE, focused]
	if not GameState.has_meta("atlas_territory_site") or str(GameState.get_meta("atlas_territory_site")) != SITE:
		return "api: atlas_territory_site meta missing"
	if World.last_neutral_contest.is_empty():
		return "api: hub_focus did not re-emit contest"
	GameState.house_mods.erase("month_echo")
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	var cap := CKTerritory.capture(SITE, "contest")
	if not CKTerritory.owned(SITE):
		return "api: capture did not own: %s" % str(cap)
	var echo := str(CKEconomyState.month_echo_snapshot().get("contest", ""))
	if echo == "":
		return "api: month_echo.contest missing"
	if _has_todo_contest():
		return "api: chip still on after capture"
	if not CKTerritory.pending_contest_ids().is_empty():
		return "api: pending list not empty after capture"
	print("api start→chip→capture ok")
	return ""


func _ui_castle_chip_focus() -> String:
	_setup()
	var err := _start()
	if err != "":
		return "ui castle: " + err
	World.pos = "ash_capital"
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	for _i in 16:
		await get_tree().process_frame
	var chip: Node = castle.find_child("Todo_territory_contest", true, false)
	if chip == null:
		castle.queue_free()
		return "Todo_territory_contest missing on castle"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	var row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_contest":
			row = item
			break
	if row.is_empty():
		return "snapshot missing territory_contest"
	if Todo.link_for(row) != "res://scenes/hub/atlas_view.tscn":
		return "chip link not atlas"
	if GameState.has_meta("atlas_territory_site"):
		GameState.remove_meta("atlas_territory_site")
	Todo.prepare_nav(row)
	if str(GameState.get_meta("atlas_territory_site", "")) != SITE:
		return "prepare_nav did not set atlas_territory_site"
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	for _k in 16:
		await get_tree().process_frame
	if GameState.has_meta("atlas_territory_site"):
		atlas.queue_free()
		return "atlas did not consume atlas_territory_site"
	atlas.queue_free()
	print("ui castle chip→atlas focus ok")
	return ""


func _ui_ledger_banner_goto() -> String:
	_setup()
	var err := _start()
	if err != "":
		return "ui ledger: " + err
	var ledger: Node = LEDGER_SCN.instantiate()
	add_child(ledger)
	for _i in 20:
		await get_tree().process_frame
	var banner: Node = ledger.find_child("TerritoryContestBanner", true, false)
	if banner == null or not bool(banner.visible):
		ledger.queue_free()
		return "TerritoryContestBanner missing/hidden"
	var btn: Button = ledger.find_child("TerritoryContestGoto", true, false) as Button
	if btn == null or not bool(btn.visible):
		ledger.queue_free()
		return "TerritoryContestGoto missing/hidden"
	if GameState.has_meta("atlas_territory_site"):
		GameState.remove_meta("atlas_territory_site")
	var focused := CKTerritory.hub_focus_contest()
	if focused != SITE:
		ledger.queue_free()
		return "ledger hub_focus_contest want %s got %s" % [SITE, focused]
	if str(GameState.get_meta("atlas_territory_site", "")) != SITE:
		ledger.queue_free()
		return "ledger focus did not set atlas_territory_site"
	ledger.queue_free()
	for _m in 4:
		await get_tree().process_frame
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	for _k in 16:
		await get_tree().process_frame
	if GameState.has_meta("atlas_territory_site"):
		atlas.queue_free()
		return "atlas did not consume contest focus from ledger"
	atlas.queue_free()
	print("ui ledger banner→goto ok")
	return ""


func _ui_hourglass_pending_then_finish() -> String:
	_setup()
	var err := _start()
	if err != "":
		return "ui hourglass: " + err
	var hg: Node = HOURGLASS_SCN.instantiate()
	add_child(hg)
	for _i in 20:
		await get_tree().process_frame
	var pending: Node = hg.find_child("ContestPending", true, false)
	if pending == null:
		hg.queue_free()
		return "ContestPending missing on hourglass"
	var to_btn: Node = hg.find_child("ToContest", true, false)
	if to_btn == null:
		hg.queue_free()
		return "ToContest missing on hourglass"
	GameState.house_mods.erase("month_echo")
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	var cap := CKTerritory.capture(SITE, "contest")
	if not CKTerritory.owned(SITE):
		hg.queue_free()
		return "hourglass capture fail: %s" % str(cap)
	if hg.has_method("_show_forecast"):
		hg.call("_show_forecast", 1)
	for _j in 8:
		await get_tree().process_frame
	if hg.find_child("ContestPending", true, false) != null:
		hg.queue_free()
		return "ContestPending still after capture"
	if hg.find_child("ToContest", true, false) != null:
		hg.queue_free()
		return "ToContest still after capture"
	var echo := str(CKEconomyState.month_echo_snapshot().get("contest", ""))
	if echo == "":
		hg.queue_free()
		return "hourglass path missing month_echo.contest"
	if _has_todo_contest():
		hg.queue_free()
		return "chip still on after hourglass capture"
	hg.queue_free()
	print("ui hourglass pending→capture ok")
	return ""
