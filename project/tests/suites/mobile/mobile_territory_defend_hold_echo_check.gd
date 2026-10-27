extends Node
## Mobile twin: DefendLine + EchoLine_defend under CK_FORCE_MOBILE.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY DEFEND HOLD ECHO PASS"


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory defend hold echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("守卫得手机", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	GameState.food = 40
	GameState.morale = 80
	World.hub_tour.clear()
	World.active.clear()
	World.last_territory_month = {}
	CKTerritory.last_month_report = {}
	GameState.house_mods.erase("month_echo")
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	st = CKTerritory.state(SITE)
	st.garrison = 2
	CKTerritory._put(SITE, st)
	GameState.house_mods.erase("month_echo")
	var th := CKTerritory.start_threat(SITE)
	if th.is_empty():
		return "start_threat empty"
	CKTerritory.on_battle({"kind": "territory_defend", "site": SITE}, true)
	var echo := str(CKEconomyState.month_echo_snapshot().get("defend", ""))
	if echo == "":
		return "no defend echo"
	CKTerritory.last_month_report = {
		"silver": 8, "food": 0, "owned": 1, "owned_before": 1,
		"drains": [], "lost": [], "held": [],
		"threats": [{"id": SITE, "name": str(CKTerritory.site(SITE).name), "by": str(th.get("name", "匪"))}],
		"contests": [], "contest_open": [],
		"line": "defend", "reclaims": [],
	}
	World.last_territory_month = CKTerritory.last_month_report.duplicate(true)
	CKTerritory.take_news()
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 12:
		await get_tree().process_frame
	if page.has_method("_check_territory_month"):
		page.call("_check_territory_month")
		for _j in 10:
			await get_tree().process_frame
	var modal: Node = page.find_child("TerritoryMonthModal", true, false)
	if modal == null:
		page.queue_free()
		return "TerritoryMonthModal missing"
	if modal.find_child("EchoLine_defend", true, false) == null:
		page.queue_free()
		return "EchoLine_defend missing"
	if modal.find_child("DefendLine", true, false) == null:
		page.queue_free()
		return "DefendLine missing"
	page.queue_free()
	return ""
