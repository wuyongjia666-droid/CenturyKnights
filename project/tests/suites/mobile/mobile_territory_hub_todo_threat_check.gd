extends Node
## Mobile twin: castle Todo_territory_threat → atlas SiegeAlertModal under CK_FORCE_MOBILE.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY HUB TODO THREAT PASS"
const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory hub todo threat: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	World.take_siege_alert()
	World.pos = "ash_capital"
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	for _i in 16:
		await get_tree().process_frame
	var chip: Node = castle.find_child("Todo_territory_threat", true, false)
	if chip == null:
		castle.queue_free()
		return "mobile Todo_territory_threat missing"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	var row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_threat":
			row = item
	if int(row.get("count", 0)) < 1:
		return "mobile snapshot missing threat"
	Todo.prepare_nav(row)
	if World.last_siege_alert.is_empty():
		return "mobile prepare_nav empty alert"
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _k in 16:
		await get_tree().process_frame
	var modal: Node = page.find_child("SiegeAlertModal", true, false)
	if modal == null and page.has_method("_check_siege_alert"):
		page.call("_check_siege_alert")
		for _m in 8:
			await get_tree().process_frame
		modal = page.find_child("SiegeAlertModal", true, false)
	if modal == null:
		page.queue_free()
		return "mobile SiegeAlertModal missing"
	page.queue_free()
	return ""


func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	for _i in 4:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("城堡领地威胁机", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	GameState.food = 80
	Todo.reset_for_tests()
	World.last_siege_alert = {}
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.threat = {}
	st.cache_food = 0
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	var st2 := CKTerritory.state(SITE)
	st2.garrison = 2
	st2.stockade = true
	st2.cache_food = 4
	st2.threat = {}
	CKTerritory._put(SITE, st2)
	CKTerritory.start_threat(SITE)
