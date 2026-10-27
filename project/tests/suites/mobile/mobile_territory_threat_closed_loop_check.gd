extends Node
## Mobile twin: ThreatPending/ToSiegeThreat on hourglass + castle threat chip under CK_FORCE_MOBILE.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const HOURGLASS_SCN := preload("res://scenes/hub/hourglass.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY THREAT CLOSED LOOP PASS"
const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory threat closed loop: ", err)
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
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	for _i in 16:
		await get_tree().process_frame
	if castle.find_child("Todo_territory_threat", true, false) == null:
		castle.queue_free()
		return "mobile Todo_territory_threat missing"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	var hg: Control = HOURGLASS_SCN.instantiate()
	get_tree().root.add_child(hg)
	for _i in 12:
		await get_tree().process_frame
	if hg.find_child("ThreatPending", true, false) == null:
		hg.queue_free()
		return "mobile ThreatPending missing"
	if hg.find_child("ToSiegeThreat", true, false) == null:
		hg.queue_free()
		return "mobile ToSiegeThreat missing"
	hg.queue_free()
	# settle clears
	CKTerritory._resolve_unanswered(SITE, 0.0)
	hg = HOURGLASS_SCN.instantiate()
	get_tree().root.add_child(hg)
	for _i in 12:
		await get_tree().process_frame
	if hg.find_child("ThreatPending", true, false) != null:
		hg.queue_free()
		return "mobile ThreatPending still after settle"
	if hg.find_child("EchoLine_threat_held", true, false) == null:
		hg.queue_free()
		return "mobile EchoLine_threat_held missing"
	hg.queue_free()
	return ""


func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	for _i in 4:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("移动属地威胁整链", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 9000
	World.last_siege_alert = {}
	World.last_threat_resolve = {}
	GameState.house_mods.erase("month_echo")
	Todo.reset_for_tests()
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
	st.garrison = 4
	st.stockade = true
	st.cache_food = 4
	CKTerritory._put(SITE, st)
	CKTerritory.start_threat(SITE)
