extends Node
## Mobile twin: unpaid drain → Todo_territory_drain → ledger DrainBanner under CK_FORCE_MOBILE.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY DRAIN REINFORCE LOOP PASS"
const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory drain reinforce loop: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	for _i in 4:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("属地欠饷耐久移动", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	Todo.reset_for_tests()
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.OWN
	st.garrison = 1
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	CKTerritory._put(SITE, st)
	var nm := str(CKTerritory.site(SITE).name)
	CKTerritory.last_month_report = {
		"silver": 0, "food": 0, "owned": 1, "owned_before": 1,
		"drains": [{"id": SITE, "name": nm, "garrison": 1, "text": "drain"}],
		"lost": [], "held": [], "threats": [], "line": "ok",
		"reclaims": [], "contests": [], "contest_open": [],
	}


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
	var chip: Node = castle.find_child("Todo_territory_drain", true, false)
	if chip == null:
		castle.queue_free()
		return "mobile Todo_territory_drain missing"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	var ledger: Node = LEDGER_SCN.instantiate()
	add_child(ledger)
	for _k in 20:
		await get_tree().process_frame
	var banner: Node = ledger.find_child("TerritoryDrainBanner", true, false)
	if banner == null or not bool(banner.visible):
		ledger.queue_free()
		return "mobile TerritoryDrainBanner missing/hidden"
	ledger.queue_free()
	return ""
