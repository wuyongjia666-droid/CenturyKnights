extends Node
## Territory fat: threat → defend battle win → month_echo.defend
## + TerritoryMonth DefendLine/EchoLine_defend E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY DEFEND HOLD ECHO PASS"


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory defend hold echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_rejects()
	if err != "":
		return err
	err = _api_defend_win_echo()
	if err != "":
		return err
	err = _api_defend_lose_no_echo()
	if err != "":
		return err
	err = await _ui_month_defend_echo()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("守卫得手回读", "灰旗", GameState.crest_color)
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
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.cargo.clear()
	World.cargo_basis.clear()
	World.last_territory_month = {}
	CKTerritory.last_month_report = {}
	GameState.house_mods.erase("month_echo")


func _reset(id: String = SITE) -> void:
	var st: Dictionary = CKTerritory.state(id)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	st.cache_food = 0
	CKTerritory._put(id, st)


func _own(g: int = 2) -> void:
	_reset()
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	var st := CKTerritory.state(SITE)
	st.garrison = g
	CKTerritory._put(SITE, st)
	GameState.house_mods.erase("month_echo")


func _threaten() -> Dictionary:
	var th := CKTerritory.start_threat(SITE)
	return th


func _api_rejects() -> String:
	_setup()
	_reset()
	# no threat → defend rejects
	_own(1)
	var r := CKTerritory.defend(SITE)
	if bool(r.get("ok", false)):
		return "defend without threat should fail"
	if str(CKEconomyState.month_echo_snapshot().get("defend", "")) != "":
		return "echo leaked on reject"
	print("api defend rejects ok")
	return ""


func _api_defend_win_echo() -> String:
	_setup()
	_own(2)
	GameState.house_mods.erase("month_echo")
	var th := _threaten()
	if th.is_empty():
		return "start_threat empty"
	var by_name := str(th.get("name", ""))
	var enc := {
		"kind": "territory_defend",
		"site": SITE,
		"node": str(CKTerritory.site(SITE).get("anchor", "")),
	}
	var msg := CKTerritory.on_battle(enc, true)
	if msg == "":
		return "on_battle win empty msg"
	if not (CKTerritory.state(SITE).threat as Dictionary).is_empty():
		return "threat not cleared on win"
	if not CKTerritory.owned(SITE):
		return "lost ownership on defend win"
	var echo := str(CKEconomyState.month_echo_snapshot().get("defend", ""))
	if echo == "":
		return "month_echo.defend empty after win"
	if "守卫" not in echo and "Defend" not in echo:
		return "echo looks wrong: %s" % echo
	if by_name != "" and by_name not in echo:
		# by_name should appear in echo template %s
		if str(CKTerritory.site(SITE).name) not in echo:
			return "echo missing site/by: %s" % echo
	print("api defend win echo ok: ", echo)
	return ""


func _api_defend_lose_no_echo() -> String:
	_setup()
	_own(1)
	GameState.house_mods.erase("month_echo")
	var th := _threaten()
	if th.is_empty():
		return "need threat for lose path"
	var enc := {
		"kind": "territory_defend",
		"site": SITE,
		"node": str(CKTerritory.site(SITE).get("anchor", "")),
	}
	var msg := CKTerritory.on_battle(enc, false)
	if msg == "":
		return "on_battle lose empty"
	if CKTerritory.owned(SITE):
		return "should lose ownership on defend fail"
	var echo := str(CKEconomyState.month_echo_snapshot().get("defend", ""))
	if echo != "":
		return "defend lose should not write hold echo: %s" % echo
	print("api defend lose no echo ok")
	return ""


func _ui_month_defend_echo() -> String:
	_setup()
	_own(2)
	GameState.house_mods.erase("month_echo")
	var th := _threaten()
	if th.is_empty():
		return "ui need threat"
	var enc := {"kind": "territory_defend", "site": SITE}
	CKTerritory.on_battle(enc, true)
	var echo := str(CKEconomyState.month_echo_snapshot().get("defend", ""))
	if echo == "":
		return "ui need defend echo"
	# Prime month report with a pending threat row so DefendLine renders,
	# plus the hold echo for EchoLine_defend.
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
	var modal: Node = page.find_child("TerritoryMonthModal", true, false)
	if modal == null and page.has_method("_check_territory_month"):
		page.call("_check_territory_month")
		for _j in 10:
			await get_tree().process_frame
		modal = page.find_child("TerritoryMonthModal", true, false)
	if modal == null:
		page.queue_free()
		return "TerritoryMonthModal missing"
	var echo_n: Node = modal.find_child("EchoLine_defend", true, false)
	if echo_n == null:
		page.queue_free()
		return "EchoLine_defend missing"
	var elabel := echo_n as Label
	if elabel != null and str(elabel.text) == "":
		page.queue_free()
		return "EchoLine_defend empty text"
	var dline: Node = modal.find_child("DefendLine", true, false)
	if dline == null:
		page.queue_free()
		return "DefendLine missing"
	print("ui month defend echo ok")
	page.queue_free()
	return ""
