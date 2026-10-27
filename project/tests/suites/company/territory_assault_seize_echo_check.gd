extends Node
## Territory fat: assault battle win → month_echo.assault
## + TerritoryMonth UnrestLine/EchoLine_assault E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY ASSAULT SEIZE ECHO PASS"


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory assault seize echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_rejects()
	if err != "":
		return err
	err = _api_assault_win_echo()
	if err != "":
		return err
	err = _api_assault_lose_no_echo()
	if err != "":
		return err
	err = _api_chain_no_assault_echo()
	if err != "":
		return err
	err = await _ui_month_assault_echo()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("强攻得手回读", "灰旗", GameState.crest_color)
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


func _at_anchor() -> void:
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	World.encounter = {}


func _api_rejects() -> String:
	_setup()
	_reset()
	# not at anchor → assault rejects
	World.pos = "ash_capital"
	var r := CKTerritory.assault(SITE)
	if bool(r.get("ok", false)):
		return "assault away from anchor should fail"
	if str(CKEconomyState.month_echo_snapshot().get("assault", "")) != "":
		return "echo leaked on reject"
	print("api assault rejects ok")
	return ""


func _api_assault_win_echo() -> String:
	_setup()
	_reset()
	_at_anchor()
	GameState.house_mods.erase("month_echo")
	var enc := {
		"kind": "territory_assault",
		"site": SITE,
		"node": str(CKTerritory.site(SITE).get("anchor", "")),
	}
	var msg := CKTerritory.on_battle(enc, true)
	if msg == "":
		return "on_battle assault win empty msg"
	if not CKTerritory.owned(SITE):
		return "not owned after assault win"
	var st := CKTerritory.state(SITE)
	if int(st.unrest) <= 0:
		return "assault should set unrest"
	var echo := str(CKEconomyState.month_echo_snapshot().get("assault", ""))
	if echo == "":
		return "month_echo.assault empty after win"
	if "强攻" not in echo and "Assault" not in echo:
		return "echo looks wrong: %s" % echo
	if str(CKTerritory.site(SITE).name) not in echo:
		return "echo missing site: %s" % echo
	print("api assault win echo ok: ", echo)
	return ""


func _api_assault_lose_no_echo() -> String:
	_setup()
	_reset()
	_at_anchor()
	GameState.house_mods.erase("month_echo")
	var enc := {"kind": "territory_assault", "site": SITE}
	var msg := CKTerritory.on_battle(enc, false)
	# lose path returns "" for assault (no capture)
	if CKTerritory.owned(SITE):
		return "assault lose should not capture"
	var echo := str(CKEconomyState.month_echo_snapshot().get("assault", ""))
	if echo != "":
		return "assault lose should not write seize echo: %s" % echo
	print("api assault lose no echo ok msg=", msg)
	return ""


func _api_chain_no_assault_echo() -> String:
	_setup()
	_reset()
	_at_anchor()
	GameState.house_mods.erase("month_echo")
	CKTerritory.capture(SITE, "chain")
	if not CKTerritory.owned(SITE):
		return "chain capture failed"
	var echo := str(CKEconomyState.month_echo_snapshot().get("assault", ""))
	if echo != "":
		return "chain must not write assault echo: %s" % echo
	print("api chain no assault echo ok")
	return ""


func _ui_month_assault_echo() -> String:
	_setup()
	_reset()
	_at_anchor()
	GameState.house_mods.erase("month_echo")
	CKTerritory.on_battle({"kind": "territory_assault", "site": SITE}, true)
	var echo := str(CKEconomyState.month_echo_snapshot().get("assault", ""))
	if echo == "":
		return "ui need assault echo"
	if int(CKTerritory.state(SITE).unrest) <= 0:
		return "ui need unrest for UnrestLine"
	CKTerritory.last_month_report = {
		"silver": 8, "food": 0, "owned": 1, "owned_before": 0,
		"drains": [], "lost": [], "held": [],
		"threats": [], "contests": [], "contest_open": [],
		"line": "assault", "reclaims": [],
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
	var echo_n: Node = modal.find_child("EchoLine_assault", true, false)
	if echo_n == null:
		page.queue_free()
		return "EchoLine_assault missing"
	var elabel := echo_n as Label
	if elabel != null and str(elabel.text) == "":
		page.queue_free()
		return "EchoLine_assault empty text"
	var uline: Node = modal.find_child("UnrestLine", true, false)
	if uline == null:
		page.queue_free()
		return "UnrestLine missing"
	print("ui month assault echo ok")
	page.queue_free()
	return ""
