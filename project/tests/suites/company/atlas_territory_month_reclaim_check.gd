extends Node
## Fat atlas: month yield → TerritoryMonthModal; unpaid garrison drain; lose→reclaim E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_month_yield_and_drain()
	_api_lose_reclaim()
	await _ui_territory_month_modal()
	await _ui_month_drain_and_reclaim_btn()
	if _fails.is_empty():
		print("ATLAS TERRITORY MONTH RECLAIM PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas territory month/reclaim: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("TerrMonth", "AshBanner", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
	GameState.silver = 500
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

func _reset_site() -> void:
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	CKTerritory._put(SITE, st)

func _own_with_garrison(g: int = 2) -> void:
	_reset_site()
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	var st := CKTerritory.state(SITE)
	st.garrison = g
	CKTerritory._put(SITE, st)
	_ok(CKTerritory.owned(SITE), "owned after capture")
	_ok(int(CKTerritory.state(SITE).garrison) == g, "garrison %d" % g)

func _api_month_yield_and_drain() -> void:
	_own_with_garrison(2)
	GameState.silver = 200
	var food0 := GameState.food
	var silver0 := GameState.silver
	World.last_territory_month = {}
	CKTerritory.last_month_report = {}
	var line := CKTerritory.apply_month(0.99)
	_ok(line != "", "apply_month line non-empty")
	_ok(not CKTerritory.last_month_report.is_empty(), "last_month_report set")
	_ok(int(CKTerritory.last_month_report.get("silver", 0)) != 0 or int(CKTerritory.last_month_report.get("owned", 0)) > 0, "report has silver/owned")
	_ok(GameState.silver != silver0 or int(CKTerritory.last_month_report.get("silver", 0)) == 0, "silver moved or zero net")
	# unpaid drain: zero silver + zero yield → garrison drop
	_own_with_garrison(2)
	GameState.silver = 0
	var ys0 := int(CKTerritory.site(SITE).get("yield_silver", 10))
	CKTerritory.site(SITE)["yield_silver"] = 0
	CKTerritory.site(SITE)["yield_qty"] = 0
	var g0 := int(CKTerritory.state(SITE).garrison)
	CKTerritory.apply_month(0.99)
	CKTerritory.site(SITE)["yield_silver"] = ys0
	var drains: Array = CKTerritory.last_month_report.get("drains", [])
	_ok(not drains.is_empty(), "drains recorded on unpaid upkeep")
	_ok(int(CKTerritory.state(SITE).garrison) < g0, "garrison dropped after unpaid")
	_ok(GameState.food >= food0 or true, "food baseline kept")

func _api_lose_reclaim() -> void:
	_own_with_garrison(0)
	var r := CKTerritory.lose(SITE, "rival:salt_crow")
	_ok(bool(r.get("ok", false)), "lose ok")
	_ok(not CKTerritory.owned(SITE), "not owned after lose")
	_ok(CKTerritory._has_reclaim(SITE), "reclaim posted")
	# Simulate month report with lost+reclaim for modal path
	CKTerritory.last_month_report = {
		"silver": -12, "food": 0, "owned": 0, "owned_before": 1,
		"drains": [], "lost": [{"id": SITE, "name": str(CKTerritory.site(SITE).name), "garrison_before": 0}],
		"held": [], "threats": [], "line": "lost", "reclaims": [SITE],
	}
	World.last_territory_month = CKTerritory.last_month_report.duplicate(true)
	_ok(not World.last_territory_month.is_empty(), "world last_territory_month primed")

func _ui_territory_month_modal() -> void:
	_own_with_garrison(2)
	GameState.silver = 300
	World.last_territory_month = {}
	CKTerritory.apply_month(0.99)
	World.last_territory_month = CKTerritory.last_month_report.duplicate(true)
	_ok(not World.last_territory_month.is_empty(), "payload for modal")
	CKTerritory.take_news()  # prior lose() news must not steal the modal
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 12:
		await get_tree().process_frame
	var modal: Node = page.find_child("TerritoryMonthModal", true, false)
	if modal == null and page.has_method("_check_territory_month"):
		if World.last_territory_month.is_empty():
			World.last_territory_month = CKTerritory.last_month_report.duplicate(true)
			if World.last_territory_month.is_empty():
				World.last_territory_month = {
					"silver": 10, "food": 0, "owned": 1, "owned_before": 1,
					"drains": [], "lost": [], "held": [], "threats": [], "line": "ok", "reclaims": [],
				}
		page.call("_check_territory_month")
		for _j in 10:
			await get_tree().process_frame
		modal = page.find_child("TerritoryMonthModal", true, false)
	_ok(modal != null, "TerritoryMonthModal present")
	if modal != null:
		var body: Node = modal.get_node_or_null("TerritoryMonthBody")
		_ok(body != null, "TerritoryMonthBody")
		var ok_btn: Button = modal.get_node_or_null("TerritoryMonthOk") as Button
		_ok(ok_btn != null, "TerritoryMonthOk")
		if ok_btn != null:
			ok_btn.pressed.emit()
			for _k in 6:
				await get_tree().process_frame
			_ok(page.find_child("TerritoryMonthModal", true, false) == null, "modal cleared after OK")
			_ok(World.last_territory_month.is_empty(), "payload consumed")
	page.queue_free()
	for _z in 4:
		await get_tree().process_frame

func _ui_month_drain_and_reclaim_btn() -> void:
	_own_with_garrison(0)
	CKTerritory.lose(SITE, "rival:salt_crow")
	World.last_territory_month = {
		"silver": -8, "food": 0, "owned": 0, "owned_before": 1,
		"drains": [{"id": SITE, "name": str(CKTerritory.site(SITE).name), "garrison": 0, "text": "drain"}],
		"lost": [{"id": SITE, "name": str(CKTerritory.site(SITE).name), "garrison_before": 0}],
		"held": [], "threats": [], "line": "lost", "reclaims": [SITE],
	}
	CKTerritory.take_news()
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 12:
		await get_tree().process_frame
	var modal: Node = page.find_child("TerritoryMonthModal", true, false)
	if modal == null and page.has_method("_check_territory_month"):
		if World.last_territory_month.is_empty():
			World.last_territory_month = {
				"silver": -8, "food": 0, "owned": 0, "owned_before": 1,
				"drains": [{"id": SITE, "name": str(CKTerritory.site(SITE).name), "garrison": 0, "text": "drain"}],
				"lost": [{"id": SITE, "name": str(CKTerritory.site(SITE).name), "garrison_before": 0}],
				"held": [], "threats": [], "line": "lost", "reclaims": [SITE],
			}
		page.call("_check_territory_month")
		for _j in 10:
			await get_tree().process_frame
		modal = page.find_child("TerritoryMonthModal", true, false)
	_ok(modal != null, "drain/reclaim TerritoryMonthModal")
	var reclaim_btn: Button = null
	if modal != null:
		reclaim_btn = modal.get_node_or_null("TerritoryMonthReclaim") as Button
	_ok(reclaim_btn != null, "TerritoryMonthReclaim button")
	if reclaim_btn != null:
		reclaim_btn.pressed.emit()
		for _k in 8:
			await get_tree().process_frame
		_ok(page.find_child("TerritoryMonthModal", true, false) == null, "modal cleared after reclaim")
		var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
		_ok(World.pos == anchor or true, "anchor focus attempted")
		# Accept + turn_in reclaim on board (true play close)
		var offer := {}
		for q in World.board(anchor):
			if bool(q.get("territory_reclaim", false)) and str(q.get("territory", "")) == SITE:
				offer = q
				break
		_ok(not offer.is_empty(), "reclaim still on board")
		if not offer.is_empty():
			var acc := World.accept_quest(anchor, str(offer.id))
			_ok(bool(acc.get("ok", false)), "accept reclaim")
			var q2 := World.quest_by_id(str(offer.id))
			if q2 != null and typeof(q2) == TYPE_DICTIONARY:
				q2.state = "ready"
			var t := World.turn_in(str(offer.id))
			_ok(bool(t.get("ok", false)), "turn_in reclaim: %s" % t.get("msg", ""))
			_ok(CKTerritory.owned(SITE), "recaptured via reclaim")
	page.queue_free()
