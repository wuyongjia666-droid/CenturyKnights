extends Node
## Mobile twin: SiegeSisterCall + EchoLine_sister under CK_FORCE_MOBILE.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const SISTER := "t_ash_millrun"
const MARKER := "MOBILE TERRITORY SISTER RELIEF ECHO PASS"

func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory sister relief echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("姊妹回读机", "灰旗", GameState.crest_color)
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
	World.last_siege_sister = {}
	for id in [SITE, SISTER]:
		var st: Dictionary = CKTerritory.state(id)
		st.owner = CKTerritory.NEUTRAL
		st.garrison = 0
		st.stockade = false
		st.threat = {}
		CKTerritory._put(id, st)
	for pair in [[SISTER, 3], [SITE, 1]]:
		var id2 := str(pair[0])
		var g := int(pair[1])
		var anchor := str(CKTerritory.site(id2).get("anchor", ""))
		World.pos = anchor
		World.arrive(anchor)
		CKTerritory.capture(id2, "chain")
		var st2 := CKTerritory.state(id2)
		st2.garrison = g
		st2.stockade = true
		st2.cache_food = 5 if id2 == SITE else 0
		st2.threat = {}
		CKTerritory._put(id2, st2)
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
	var btn := panel.find_child("SiegeSisterCall", true, false) as Button
	if btn == null or btn.disabled:
		atlas.queue_free()
		return "SiegeSisterCall missing/disabled (mobile)"
	btn.pressed.emit()
	for _k in 12:
		await get_tree().process_frame
	if str(CKEconomyState.month_echo_snapshot().get("sister", "")) == "":
		atlas.queue_free()
		return "mobile missing month_echo.sister"
	panel = atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null or panel.find_child("EchoLine_sister", true, false) == null:
		atlas.queue_free()
		return "EchoLine_sister missing (mobile)"
	print("mobile sister echo ok")
	atlas.queue_free()
	await get_tree().process_frame
	return ""
