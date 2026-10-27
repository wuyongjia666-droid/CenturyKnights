extends Node
## Mobile twin: SiegeMuster + EchoLine_muster under CK_FORCE_MOBILE.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY SIEGE MUSTER ECHO PASS"

func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory siege muster echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("围城募兵机", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	GameState.food = 80
	GameState.house_mods.erase("month_echo")
	World.last_siege_alert = {}
	World.last_siege_muster = {}
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.threat = {}
	st.cache_food = 0
	CKTerritory._put(SITE, st)
	var cost := CKTerritory.muster_cache_cost(SITE)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	var st2 := CKTerritory.state(SITE)
	st2.garrison = 1
	st2.stockade = true
	st2.cache_food = cost + 5
	st2.threat = {}
	CKTerritory._put(SITE, st2)
	CKTerritory.start_threat(SITE)
	var atlas: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(atlas)
	for _i in 10:
		await get_tree().process_frame
	if atlas.has_method("_check_siege_alert"):
		atlas.call("_check_siege_alert")
	for _j in 10:
		await get_tree().process_frame
	var panel := atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null:
		atlas.queue_free()
		return "SiegeAlertModal missing (mobile)"
	var btn := panel.find_child("SiegeMuster", true, false) as Button
	if btn == null or btn.disabled:
		atlas.queue_free()
		return "SiegeMuster missing/disabled (mobile)"
	btn.pressed.emit()
	for _k in 12:
		await get_tree().process_frame
	if str(CKEconomyState.month_echo_snapshot().get("muster", "")) == "":
		atlas.queue_free()
		return "mobile missing month_echo.muster"
	panel = atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null or panel.find_child("EchoLine_muster", true, false) == null:
		atlas.queue_free()
		return "EchoLine_muster missing (mobile)"
	print("mobile muster echo ok")
	atlas.queue_free()
	await get_tree().process_frame
	return ""
