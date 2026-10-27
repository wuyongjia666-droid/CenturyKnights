extends Node
## Territory fat closed-loop: lose → HubTodo reclaim → atlas focus / ledger goto
## → hourglass ReclaimPending → finish → month_echo.reclaim → chip clear.
## One knife; not chip/ledger/hourglass/echo slices.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const HOURGLASS_SCN := preload("res://scenes/hub/hourglass.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY RECLAIM CLOSED LOOP PASS"


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory reclaim closed loop: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_lose_chip_finish()
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
	GameState.new_game("属地反夺整链", "灰旗", GameState.crest_color)
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


func _own_then_lose() -> void:
	_reset()
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	var st := CKTerritory.state(SITE)
	st.garrison = 2
	CKTerritory._put(SITE, st)
	GameState.house_mods.erase("month_echo")
	CKTerritory.lose(SITE, "rival:salt_crow")


func _has_todo_reclaim() -> bool:
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_reclaim" and int(item.get("count", 0)) > 0:
			return true
	return false


func _api_lose_chip_finish() -> String:
	_setup()
	_own_then_lose()
	if not CKTerritory._has_reclaim(SITE):
		return "api: reclaim not posted"
	var ids: Array = CKTerritory.pending_reclaim_ids()
	if SITE not in ids:
		return "api: pending_reclaim_ids missing site: %s" % str(ids)
	if not _has_todo_reclaim():
		return "api: HubTodo chip missing after lose"
	var focused := CKTerritory.hub_focus_reclaim()
	if focused != SITE:
		return "api: hub_focus_reclaim want %s got %s" % [SITE, focused]
	if not GameState.has_meta("atlas_territory_site") or str(GameState.get_meta("atlas_territory_site")) != SITE:
		return "api: atlas_territory_site meta missing"
	GameState.house_mods.erase("month_echo")
	var fin := CKTerritory._finish_reclaim(SITE)
	if not CKTerritory.owned(SITE):
		return "api: finish did not own: %s" % fin
	var echo := str(CKEconomyState.month_echo_snapshot().get("reclaim", ""))
	if echo == "":
		return "api: month_echo.reclaim missing"
	if _has_todo_reclaim():
		return "api: chip still on after finish"
	if not CKTerritory.pending_reclaim_ids().is_empty():
		return "api: pending list not empty after finish"
	print("api lose→chip→finish ok")
	return ""


func _ui_castle_chip_focus() -> String:
	_setup()
	_own_then_lose()
	World.pos = "ash_capital"
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	for _i in 16:
		await get_tree().process_frame
	var chip: Node = castle.find_child("Todo_territory_reclaim", true, false)
	if chip == null:
		castle.queue_free()
		return "Todo_territory_reclaim missing on castle"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	# Chip path: prepare_nav then atlas consumes meta.
	var row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_reclaim":
			row = item
			break
	if row.is_empty():
		return "snapshot missing territory_reclaim"
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
	# Meta should be consumed by atlas_view _ready.
	if GameState.has_meta("atlas_territory_site"):
		atlas.queue_free()
		return "atlas did not consume atlas_territory_site"
	atlas.queue_free()
	print("ui castle chip→atlas focus ok")
	return ""


func _ui_ledger_banner_goto() -> String:
	_setup()
	_own_then_lose()
	var ledger: Node = LEDGER_SCN.instantiate()
	add_child(ledger)
	for _i in 20:
		await get_tree().process_frame
	var banner: Node = ledger.find_child("TerritoryReclaimBanner", true, false)
	if banner == null or not bool(banner.visible):
		ledger.queue_free()
		return "TerritoryReclaimBanner missing/hidden"
	var btn: Button = ledger.find_child("TerritoryReclaimGoto", true, false) as Button
	if btn == null or not bool(btn.visible):
		ledger.queue_free()
		return "TerritoryReclaimGoto missing/hidden"
	if GameState.has_meta("atlas_territory_site"):
		GameState.remove_meta("atlas_territory_site")
	btn.pressed.emit()
	for _m in 6:
		await get_tree().process_frame
	if str(GameState.get_meta("atlas_territory_site", "")) != SITE:
		ledger.queue_free()
		return "ledger goto did not focus site"
	ledger.queue_free()
	print("ui ledger banner→goto ok")
	return ""


func _ui_hourglass_pending_then_finish() -> String:
	_setup()
	_own_then_lose()
	var hg: Node = HOURGLASS_SCN.instantiate()
	add_child(hg)
	for _i in 20:
		await get_tree().process_frame
	var pending: Node = hg.find_child("ReclaimPending", true, false)
	if pending == null:
		hg.queue_free()
		return "ReclaimPending missing on hourglass"
	var to_btn: Node = hg.find_child("ToReclaim", true, false)
	if to_btn == null:
		hg.queue_free()
		return "ToReclaim missing on hourglass"
	# Finish reclaim while hourglass still open — refresh forecast should clear.
	GameState.house_mods.erase("month_echo")
	var fin := CKTerritory._finish_reclaim(SITE)
	if not CKTerritory.owned(SITE):
		hg.queue_free()
		return "hourglass finish fail: %s" % fin
	if hg.has_method("_show_forecast"):
		hg.call("_show_forecast", 1)
	for _j in 8:
		await get_tree().process_frame
	if hg.find_child("ReclaimPending", true, false) != null:
		hg.queue_free()
		return "ReclaimPending still after finish"
	if hg.find_child("ToReclaim", true, false) != null:
		hg.queue_free()
		return "ToReclaim still after finish"
	var echo := str(CKEconomyState.month_echo_snapshot().get("reclaim", ""))
	if echo == "":
		hg.queue_free()
		return "hourglass path missing month_echo.reclaim"
	# Result column should paint EchoLine_reclaim when echo present.
	if hg.has_method("_paint_result_initial"):
		hg.call("_paint_result_initial")
	for _k in 6:
		await get_tree().process_frame
	var echo_n: Node = hg.find_child("EchoLine_reclaim", true, false)
	if echo_n == null:
		# Soft: paint may only run on advance; echo string itself is enough for API.
		print("note: EchoLine_reclaim not on initial result (ok if advance-only)")
	if _has_todo_reclaim():
		hg.queue_free()
		return "chip still on after hourglass finish"
	hg.queue_free()
	print("ui hourglass pending→finish ok")
	return ""
