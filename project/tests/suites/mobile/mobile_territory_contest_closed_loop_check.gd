extends Node
## Mobile twin: start_neutral_contest → Todo_territory_contest → ledger ContestBanner under CK_FORCE_MOBILE.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY CONTEST CLOSED LOOP PASS"
const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory contest closed loop: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	for _i in 4:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("属地拉锯整链移动", "灰旗", GameState.crest_color)
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
	Todo.reset_for_tests()
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	CKTerritory._put(SITE, st)
	CKTerritory.start_neutral_contest(SITE, [
		{"id": "rival:rv_a", "name": "灰烬狼团", "pressure": 3},
		{"id": "rival:rv_b", "name": "盐湾镖旗", "pressure": 2},
	])


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	World.pos = "ash_capital"
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	for _i in 16:
		await get_tree().process_frame
	var chip: Node = castle.find_child("Todo_territory_contest", true, false)
	if chip == null:
		castle.queue_free()
		return "mobile Todo_territory_contest missing"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	var ledger: Node = LEDGER_SCN.instantiate()
	add_child(ledger)
	for _k in 20:
		await get_tree().process_frame
	var banner: Node = ledger.find_child("TerritoryContestBanner", true, false)
	if banner == null or not bool(banner.visible):
		ledger.queue_free()
		return "mobile TerritoryContestBanner missing/hidden"
	ledger.queue_free()
	return ""
