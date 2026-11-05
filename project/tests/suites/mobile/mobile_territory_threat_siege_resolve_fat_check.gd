extends Node
## Mobile twin fat #4: TerritoryThreatBanner/Goto + ThreatBribedNote under CK_FORCE_MOBILE; CTAs tappable.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const HOURGLASS_SCN := preload("res://scenes/hub/hourglass.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY THREAT SIEGE RESOLVE FAT PASS"
const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory threat siege resolve fat: ", err)
		get_tree().quit(1)
		return
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
	var ledger: Control = LEDGER_SCN.instantiate()
	get_tree().root.add_child(ledger)
	for _i in 14:
		await get_tree().process_frame
	var banner := ledger.find_child("TerritoryThreatBanner", true, false) as Control
	var goto_btn := ledger.find_child("TerritoryThreatGoto", true, false) as Button
	if banner == null or not banner.visible:
		ledger.queue_free()
		return "mobile TerritoryThreatBanner missing"
	if goto_btn == null or not goto_btn.visible:
		ledger.queue_free()
		return "mobile TerritoryThreatGoto missing"
	if goto_btn.size.x < 40 or goto_btn.size.y < 20:
		ledger.queue_free()
		return "mobile TerritoryThreatGoto clipped"
	if CKTerritory.hub_requeue_siege_alert() == "":
		ledger.queue_free()
		return "mobile threat goto requeue empty"
	ledger.queue_free()
	for _j2 in 4:
		await get_tree().process_frame
	var atlas: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(atlas)
	for _i in 10:
		await get_tree().process_frame
	if atlas.has_method("_check_siege_alert"):
		atlas.call("_check_siege_alert")
	for _j3 in 10:
		await get_tree().process_frame
	var panel := atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null:
		atlas.queue_free()
		return "mobile SiegeAlertModal missing"
	var bribe := panel.find_child("SiegeBribe", true, false) as Button
	var relief := panel.find_child("SiegeRelief", true, false) as Button
	if bribe == null or relief == null:
		atlas.queue_free()
		return "mobile siege CTAs missing"
	if bribe.size.x < 40 or relief.size.x < 40:
		atlas.queue_free()
		return "mobile siege CTAs clipped"
	bribe.pressed.emit()
	for _k2 in 12:
		await get_tree().process_frame
	atlas.queue_free()
	for _j4 in 4:
		await get_tree().process_frame
	var hg: Control = HOURGLASS_SCN.instantiate()
	get_tree().root.add_child(hg)
	for _i in 14:
		await get_tree().process_frame
	if hg.find_child("ThreatPending", true, false) == null:
		hg.queue_free()
		return "mobile ThreatPending missing"
	if hg.find_child("ThreatBribedNote", true, false) == null:
		hg.queue_free()
		return "mobile ThreatBribedNote missing"
	var to_siege := hg.find_child("ToSiegeThreat", true, false) as Control
	if to_siege == null:
		hg.queue_free()
		return "mobile ToSiegeThreat missing"
	if to_siege.size.x < 40:
		hg.queue_free()
		return "mobile ToSiegeThreat clipped"
	var surf: Dictionary = CKTerritory.threat_surface_state()
	if int(surf.get("count", 0)) < 1 or int(surf.get("bribed", 0)) < 1:
		hg.queue_free()
		return "mobile surface bribed disagree: %s" % str(surf)
	hg.queue_free()
	return ""


func _boot() -> void:
	GameState.new_game("移动威胁围城", "灰旗", GameState.crest_color)
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
	CKTerritory.last_month_report = {}
	GameState.house_mods.erase("month_echo")
	Todo.reset_for_tests()
	var id := SITE
	var st: Dictionary = CKTerritory.state(id)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.cache_food = 0
	CKTerritory._put(id, st)
	var anchor := str(CKTerritory.site(id).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(id, "chain")
	st = CKTerritory.state(id)
	st.garrison = 4
	st.stockade = true
	st.cache_food = 4
	st.threat = {}
	CKTerritory._put(id, st)
	CKTerritory.start_threat(id)


func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	for _i in 4:
		await get_tree().process_frame
