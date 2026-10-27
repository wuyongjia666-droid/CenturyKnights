extends Node
## Mobile twin: SiegeBribe/SiegeScout + EchoLine_* under CK_FORCE_MOBILE.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY SIEGE BRIBE SCOUT ECHO PASS"


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory siege bribe/scout echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _boot() -> void:
	GameState.new_game("围城收买斥候机", "灰旗", GameState.crest_color)
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


func _run() -> String:
	await get_tree().process_frame
	_boot()
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
	var scout := panel.find_child("SiegeScout", true, false) as Button
	if scout == null or scout.disabled:
		atlas.queue_free()
		return "SiegeScout missing/disabled (mobile)"
	scout.pressed.emit()
	for _k in 12:
		await get_tree().process_frame
	if str(CKEconomyState.month_echo_snapshot().get("scout", "")) == "":
		atlas.queue_free()
		return "mobile missing month_echo.scout"
	panel = atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null or panel.find_child("EchoLine_scout", true, false) == null:
		atlas.queue_free()
		return "EchoLine_scout missing (mobile)"
	var bribe := panel.find_child("SiegeBribe", true, false) as Button
	if bribe == null or bribe.disabled:
		atlas.queue_free()
		return "SiegeBribe missing/disabled (mobile)"
	bribe.pressed.emit()
	for _m in 12:
		await get_tree().process_frame
	if str(CKEconomyState.month_echo_snapshot().get("bribe", "")) == "":
		atlas.queue_free()
		return "mobile missing month_echo.bribe"
	panel = atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null or panel.find_child("EchoLine_bribe", true, false) == null:
		atlas.queue_free()
		return "EchoLine_bribe missing (mobile)"
	print("mobile bribe/scout echo ok")
	atlas.queue_free()
	await get_tree().process_frame
	return ""
