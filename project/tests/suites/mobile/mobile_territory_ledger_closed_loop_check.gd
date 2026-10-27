extends Node
## Mobile twin: territory ledger closed loop under CK_FORCE_MOBILE.

const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY LEDGER CLOSED LOOP PASS"
const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory ledger closed loop: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_setup()
	_own(SITE, true)
	World.take_siege_alert()
	GameState.silver = 9000
	var page: Node = LEDGER_SCN.instantiate()
	add_child(page)
	for _i in 24:
		await get_tree().process_frame
	var list: ItemList = page.find_child("TerritoryList", true, false) as ItemList
	if list == null or list.item_count < 1:
		page.queue_free()
		return "TerritoryList empty"
	list.select(0)
	if page.has_method("_on_pick"):
		page.call("_on_pick", 0)
	await get_tree().process_frame
	var before_g := int(CKTerritory.state(SITE).garrison)
	var rein: Button = page.find_child("TerritoryReinforce", true, false) as Button
	if rein == null:
		page.queue_free()
		return "TerritoryReinforce missing"
	rein.emit_signal("pressed")
	for _i in 8:
		await get_tree().process_frame
	if int(CKTerritory.state(SITE).garrison) != before_g + 1:
		page.queue_free()
		return "reinforce failed"
	if CKTerritory.hub_requeue_siege_alert_site(SITE) != SITE:
		page.queue_free()
		return "requeue failed"
	page.queue_free()
	await get_tree().process_frame
	GameState.set_meta("atlas_select", str(CKTerritory.site(SITE).get("anchor", "")))
	GameState.set_meta("atlas_territory_site", SITE)
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	for _i in 40:
		await get_tree().process_frame
	var site_meta_gone := not GameState.has_meta("atlas_territory_site")
	var siege: Node = atlas.find_child("SiegeAlertModal", true, false)
	if siege == null and not site_meta_gone:
		atlas.queue_free()
		return "mobile: neither siege modal nor site consume"
	atlas.queue_free()
	return ""


func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	for _i in 4:
		await get_tree().process_frame


func _setup() -> void:
	GameState.new_game("移动领地簿整链", "灰旗", GameState.crest_color)
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


func _reset(id: String) -> void:
	var st: Dictionary = CKTerritory.state(id)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.cache_food = 0
	CKTerritory._put(id, st)


func _own(id: String, with_threat: bool) -> void:
	_reset(id)
	var anchor := str(CKTerritory.site(id).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(id, "chain")
	var st := CKTerritory.state(id)
	st.garrison = 1
	st.stockade = false
	st.threat = {}
	CKTerritory._put(id, st)
	World.last_siege_alert = {}
	if with_threat:
		CKTerritory.start_threat(id)
