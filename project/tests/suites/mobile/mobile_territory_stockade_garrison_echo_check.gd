extends Node
## Mobile twin: TerritoryModal Terr_reinforce_/Terr_stockade_ + EchoLine_ under CK_FORCE_MOBILE.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY STOCKADE GARRISON ECHO PASS"

func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory stockade/garrison echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _wait_terr_modal(page: Control, anchor: String) -> Control:
	for _i in 24:
		await get_tree().process_frame
		var m := page.find_child("TerritoryModal", true, false) as Control
		if m != null and is_instance_valid(m) and not m.is_queued_for_deletion():
			return m
	if page.has_method("_open_territory"):
		page.call("_open_territory", anchor)
	for _j in 12:
		await get_tree().process_frame
		var m2 := page.find_child("TerritoryModal", true, false) as Control
		if m2 != null and is_instance_valid(m2) and not m2.is_queued_for_deletion():
			return m2
	return null


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("屯营回读机", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 5000
	GameState.food = 80
	GameState.house_mods.erase("month_echo")
	CKTerritory._st().stockade_credit = 0

	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.threat = {}
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	st = CKTerritory.state(SITE)
	st.garrison = 1
	st.stockade = false
	CKTerritory._put(SITE, st)

	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 12:
		await get_tree().process_frame
	if page.has_method("_open_territory"):
		page.call("_open_territory", anchor)
	var modal: Control = await _wait_terr_modal(page, anchor)
	if modal == null:
		page.queue_free()
		return "TerritoryModal missing (mobile)"
	var rf := modal.find_child("Terr_reinforce_%s" % SITE, true, false) as Button
	if rf == null or rf.disabled:
		page.queue_free()
		return "Terr_reinforce missing/disabled (mobile)"
	rf.pressed.emit()
	for _k in 6:
		await get_tree().process_frame
	if str(CKEconomyState.month_echo_snapshot().get("garrison", "")) == "":
		page.queue_free()
		return "mobile missing month_echo.garrison"
	modal = await _wait_terr_modal(page, anchor)
	if modal == null or modal.find_child("EchoLine_garrison", true, false) == null:
		page.queue_free()
		return "EchoLine_garrison missing (mobile)"
	var sk := modal.find_child("Terr_stockade_%s" % SITE, true, false) as Button
	if sk == null or sk.disabled:
		page.queue_free()
		return "Terr_stockade missing/disabled (mobile)"
	sk.pressed.emit()
	for _m in 6:
		await get_tree().process_frame
	if not bool(CKTerritory.state(SITE).stockade):
		page.queue_free()
		return "mobile stockade not built"
	if str(CKEconomyState.month_echo_snapshot().get("stockade", "")) == "":
		page.queue_free()
		return "mobile missing month_echo.stockade"
	modal = await _wait_terr_modal(page, anchor)
	if modal == null or modal.find_child("EchoLine_stockade", true, false) == null:
		page.queue_free()
		return "EchoLine_stockade missing (mobile)"
	print("mobile reinforce+stockade+echo ok")
	page.queue_free()
	await get_tree().process_frame
	return ""
