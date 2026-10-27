extends Node
## Mobile twin: lose → Todo_territory_reclaim → ledger banner under CK_FORCE_MOBILE.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY RECLAIM CLOSED LOOP PASS"
const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory reclaim closed loop: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	_own_then_lose()
	World.pos = "ash_capital"
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	for _i in 16:
		await get_tree().process_frame
	var chip: Node = castle.find_child("Todo_territory_reclaim", true, false)
	if chip == null:
		castle.queue_free()
		return "mobile Todo_territory_reclaim missing"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	var ledger: Node = LEDGER_SCN.instantiate()
	add_child(ledger)
	for _k in 20:
		await get_tree().process_frame
	var banner: Node = ledger.find_child("TerritoryReclaimBanner", true, false)
	if banner == null or not bool(banner.visible):
		ledger.queue_free()
		return "mobile TerritoryReclaimBanner missing/hidden"
	var btn: Button = ledger.find_child("TerritoryReclaimGoto", true, false) as Button
	if btn == null or not bool(btn.visible):
		ledger.queue_free()
		return "mobile TerritoryReclaimGoto missing/hidden"
	if GameState.has_meta("atlas_territory_site"):
		GameState.remove_meta("atlas_territory_site")
	btn.pressed.emit()
	for _m in 6:
		await get_tree().process_frame
	if str(GameState.get_meta("atlas_territory_site", "")) != SITE:
		ledger.queue_free()
		return "mobile ledger goto did not focus"
	CKTerritory._finish_reclaim(SITE)
	ledger.queue_free()
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_reclaim" and int(item.get("count", 0)) > 0:
			return "mobile chip still on after finish"
	return ""


func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	for _i in 4:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("移动反夺整链", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	GameState.food = 80
	World.active.clear()
	GameState.house_mods.erase("month_echo")
	Todo.reset_for_tests()


func _own_then_lose() -> void:
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.threat = {}
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	st = CKTerritory.state(SITE)
	st.garrison = 2
	CKTerritory._put(SITE, st)
	CKTerritory.lose(SITE, "rival:salt_crow")
