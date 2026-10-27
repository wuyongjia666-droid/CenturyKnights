extends Node
## Territory fat J14: castle HubTodo territory_threat chip → atlas SiegeAlertModal E2E.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY HUB TODO THREAT PASS"


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory hub todo threat: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_threatened_owned()
	if err != "":
		return err
	err = await _ui_castle_chip()
	if err != "":
		return err
	err = await _ui_chip_opens_siege_modal()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("城堡领地威胁待办", "灰旗", GameState.crest_color)
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
	World.last_siege_alert = {}
	World.last_territory_month = {}
	CKTerritory.last_month_report = {}
	Todo.reset_for_tests()


func _reset(id: String) -> void:
	var st: Dictionary = CKTerritory.state(id)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.cache_food = 0
	CKTerritory._put(id, st)


func _own_threatened(id: String) -> void:
	_reset(id)
	var anchor := str(CKTerritory.site(id).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(id, "chain")
	var st := CKTerritory.state(id)
	st.garrison = 2
	st.stockade = true
	st.cache_food = 4
	st.threat = {}
	CKTerritory._put(id, st)
	World.last_siege_alert = {}
	CKTerritory.start_threat(id)


func _api_threatened_owned() -> String:
	_setup()
	_reset(SITE)
	if not CKTerritory.threatened_owned().is_empty():
		return "threatened_owned non-empty before own"
	_own_threatened(SITE)
	var ids: Array = CKTerritory.threatened_owned()
	if ids.size() != 1 or str(ids[0]) != SITE:
		return "threatened_owned=%s" % str(ids)
	World.take_siege_alert()
	if CKTerritory.hub_requeue_siege_alert() != SITE:
		return "hub_requeue missed site"
	if World.last_siege_alert.is_empty() or str(World.last_siege_alert.get("id", "")) != SITE:
		return "hub_requeue empty alert"
	if str(World.last_siege_alert.get("phase", "")) != "declared":
		return "phase want declared got %s" % World.last_siege_alert.get("phase", "")
	var st := CKTerritory.state(SITE)
	st.threat["months"] = 1
	CKTerritory._put(SITE, st)
	World.last_siege_alert = {}
	CKTerritory.hub_requeue_siege_alert()
	if str(World.last_siege_alert.get("phase", "")) != "imminent":
		return "phase want imminent got %s" % World.last_siege_alert.get("phase", "")
	return ""


func _ui_castle_chip() -> String:
	_setup()
	_own_threatened(SITE)
	World.take_siege_alert()  # dismissed — chip must still show from live threat
	World.pos = "ash_capital"
	var page: Node = CASTLE_SCN.instantiate()
	add_child(page)
	for _i in 16:
		await get_tree().process_frame
	var chip: Node = page.find_child("Todo_territory_threat", true, false)
	if chip == null:
		page.queue_free()
		return "Todo_territory_threat missing on castle"
	var row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_threat":
			row = item
	if int(row.get("count", 0)) != 1:
		page.queue_free()
		return "snapshot count %s" % str(row)
	if Todo.link_for(row) != "res://scenes/hub/atlas_view.tscn":
		page.queue_free()
		return "chip link missing"
	page.queue_free()
	for _j in 4:
		await get_tree().process_frame
	# No threat → no chip
	_setup()
	_reset(SITE)
	var page2: Node = CASTLE_SCN.instantiate()
	add_child(page2)
	for _k in 12:
		await get_tree().process_frame
	if page2.find_child("Todo_territory_threat", true, false) != null:
		page2.queue_free()
		return "chip shown without threat"
	page2.queue_free()
	return ""


func _ui_chip_opens_siege_modal() -> String:
	_setup()
	_own_threatened(SITE)
	World.take_siege_alert()
	World.pos = "ash_capital"
	# Simulate chip press: prepare_nav + atlas
	var row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_threat":
			row = item
	if row.is_empty():
		return "no territory_threat row before nav"
	Todo.prepare_nav(row)
	if World.last_siege_alert.is_empty():
		return "prepare_nav left alert empty"
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 16:
		await get_tree().process_frame
	var modal: Node = page.find_child("SiegeAlertModal", true, false)
	if modal == null and page.has_method("_check_siege_alert"):
		page.call("_check_siege_alert")
		for _j in 8:
			await get_tree().process_frame
		modal = page.find_child("SiegeAlertModal", true, false)
	if modal == null:
		page.queue_free()
		return "SiegeAlertModal missing after castle deep-link"
	page.queue_free()
	return ""
