extends Node
## Territory fat: chain attach → month_echo.chain
## + TerritoryMonth ChainLine/EchoLine_chain E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const ALT := "t_ash_millrun"
const MARKER := "TERRITORY CHAIN ATTACH ECHO PASS"


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory chain attach echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_post_chain_no_seize_echo()
	if err != "":
		return err
	err = _api_chain_attach_echo()
	if err != "":
		return err
	err = _api_assault_no_chain_echo()
	if err != "":
		return err
	err = await _ui_month_chain_echo()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("归附得手回读", "灰旗", GameState.crest_color)
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
	World.boards.clear()
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


func _reset(id: String) -> void:
	var st: Dictionary = CKTerritory.state(id)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	st.cache_food = 0
	CKTerritory._put(id, st)


func _at_anchor(id: String = SITE) -> void:
	var anchor := str(CKTerritory.site(id).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	World.encounter = {}


func _api_post_chain_no_seize_echo() -> String:
	_setup()
	_reset(SITE)
	_at_anchor(SITE)
	GameState.house_mods.erase("month_echo")
	var r := CKTerritory.post_chain(SITE)
	if not bool(r.get("ok", false)):
		return "post_chain failed: %s" % str(r.get("msg", ""))
	var echo := str(CKEconomyState.month_echo_snapshot().get("chain", ""))
	if echo != "":
		return "post_chain must not write seize echo: %s" % echo
	print("api post_chain no seize echo ok")
	return ""


func _api_chain_attach_echo() -> String:
	_setup()
	_reset(SITE)
	_at_anchor(SITE)
	GameState.house_mods.erase("month_echo")
	var r := CKTerritory.capture(SITE, "chain")
	if not bool(r.get("ok", false)):
		return "chain capture failed: %s" % str(r.get("msg", ""))
	if not CKTerritory.owned(SITE):
		return "not owned after chain"
	var st := CKTerritory.state(SITE)
	if int(st.garrison) < 1:
		return "chain should set garrison>=1"
	if int(st.unrest) != 0:
		return "chain should clear unrest"
	var echo := str(CKEconomyState.month_echo_snapshot().get("chain", ""))
	if echo == "":
		return "month_echo.chain empty after attach"
	if "归附" not in echo and "Chain" not in echo:
		return "echo looks wrong: %s" % echo
	if str(CKTerritory.site(SITE).name) not in echo:
		return "echo missing site: %s" % echo
	print("api chain attach echo ok: ", echo)
	return ""


func _api_assault_no_chain_echo() -> String:
	_setup()
	_reset(SITE)
	_at_anchor(SITE)
	GameState.house_mods.erase("month_echo")
	CKTerritory.on_battle({"kind": "territory_assault", "site": SITE}, true)
	var echo := str(CKEconomyState.month_echo_snapshot().get("chain", ""))
	if echo != "":
		return "assault must not write chain echo: %s" % echo
	print("api assault no chain echo ok")
	return ""


func _ui_month_chain_echo() -> String:
	_setup()
	_reset(SITE)
	_reset(ALT)
	_at_anchor(SITE)
	GameState.house_mods.erase("month_echo")
	# Pending pledge on SITE → ChainLine
	var pr := CKTerritory.post_chain(SITE)
	if not bool(pr.get("ok", false)):
		return "ui post_chain failed: %s" % str(pr.get("msg", ""))
	# Seize ALT → EchoLine_chain (keeps SITE offer open for ChainLine)
	var cr := CKTerritory.capture(ALT, "chain")
	if not bool(cr.get("ok", false)):
		return "ui chain capture alt failed: %s" % str(cr.get("msg", ""))
	var echo := str(CKEconomyState.month_echo_snapshot().get("chain", ""))
	if echo == "":
		return "ui need chain echo"
	CKTerritory.last_month_report = {
		"silver": 8, "food": 0, "owned": 1, "owned_before": 0,
		"drains": [], "lost": [], "held": [],
		"threats": [], "contests": [], "contest_open": [],
		"line": "chain", "reclaims": [],
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
	var echo_n: Node = modal.find_child("EchoLine_chain", true, false)
	if echo_n == null:
		page.queue_free()
		return "EchoLine_chain missing"
	var elabel := echo_n as Label
	if elabel != null and str(elabel.text) == "":
		page.queue_free()
		return "EchoLine_chain empty text"
	var cline: Node = modal.find_child("ChainLine", true, false)
	if cline == null:
		page.queue_free()
		return "ChainLine missing"
	print("ui month chain echo ok")
	page.queue_free()
	return ""
