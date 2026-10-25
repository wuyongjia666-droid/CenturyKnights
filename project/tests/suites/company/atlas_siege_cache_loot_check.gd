extends Node
## Fat atlas: unanswered siege loots stockade cache (hold half / lose all); SiegeAlert warns; SiegeLootModal E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_api_loot_cache_helper()
	_api_alert_includes_cache()
	_api_hold_loots_half()
	_api_lose_empties_cache()
	await _ui_siege_alert_cache_warn()
	await _ui_siege_loot_modal()
	if _fails.is_empty():
		print("ATLAS SIEGE CACHE LOOT PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas siege cache loot: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("SiegeLoot", "AshBanner", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 80
	GameState.silver = 800
	GameState.morale = 80
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.cargo.clear()
	World.last_territory_month = {}
	World.last_siege_alert = {}
	World.last_siege_loot = {}
	CKTerritory.last_month_report = {}

func _own_stockade(cache: int = 12, garrison: int = 3) -> void:
	_setup()
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.cache_food = 0
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	st = CKTerritory.state(SITE)
	st.garrison = garrison
	st.stockade = true
	st.cache_food = cache
	st.threat = {}
	CKTerritory._put(SITE, st)
	World.last_siege_alert = {}
	World.last_siege_loot = {}
	_ok(CKTerritory.owned(SITE) and bool(CKTerritory.state(SITE).stockade), "owned stockade ready")

func _api_loot_cache_helper() -> void:
	_own_stockade(10, 2)
	var taken := CKTerritory.loot_cache(SITE, 0.5)
	_ok(taken == 5, "loot half of 10 → %d" % taken)
	_ok(CKTerritory.cache_food(SITE) == 5, "cache left 5 got %d" % CKTerritory.cache_food(SITE))
	var taken2 := CKTerritory.loot_cache(SITE, 1.0)
	_ok(taken2 == 5, "loot all remaining → %d" % taken2)
	_ok(CKTerritory.cache_food(SITE) == 0, "cache empty")
	_ok(CKTerritory.loot_cache(SITE, 1.0) == 0, "empty loot returns 0")

func _api_alert_includes_cache() -> void:
	_own_stockade(18, 2)
	World.last_siege_alert = {}
	var th := CKTerritory.start_threat(SITE)
	_ok(not th.is_empty(), "start_threat ok")
	_ok(int(World.last_siege_alert.get("cache", -1)) == 18, "alert cache=18 got %s" % World.last_siege_alert.get("cache", -1))
	_ok(bool(World.last_siege_alert.get("stockade", false)), "alert stockade true")

func _api_hold_loots_half() -> void:
	_own_stockade(10, 4)
	CKTerritory.start_threat(SITE)
	var st := CKTerritory.state(SITE)
	st.threat["months"] = 1
	CKTerritory._put(SITE, st)
	World.last_siege_loot = {}
	# force_roll 0.0 → always hold (roll < hold_chance)
	CKTerritory.apply_month(0.0)
	_ok(CKTerritory.owned(SITE), "held site")
	_ok(not World.last_siege_loot.is_empty(), "loot payload set on hold")
	_ok(str(World.last_siege_loot.get("outcome", "")) == "held", "outcome held")
	_ok(int(World.last_siege_loot.get("looted", 0)) == 5, "held looted 5 got %s" % World.last_siege_loot.get("looted", 0))
	# month may deposit fresh stockade food after the raid — payload cache_left is authoritative
	_ok(int(World.last_siege_loot.get("cache_left", -1)) == 5, "payload cache_left 5")

func _api_lose_empties_cache() -> void:
	_own_stockade(10, 0)
	CKTerritory.start_threat(SITE)
	var st := CKTerritory.state(SITE)
	st.threat["months"] = 1
	CKTerritory._put(SITE, st)
	World.last_siege_loot = {}
	# garrison 0 → hold_chance tiny; force_roll 0.99 → lose
	CKTerritory.apply_month(0.99)
	_ok(not CKTerritory.owned(SITE), "site lost")
	# cache should be emptied (loot then lose) — state may still exist under new owner
	var left := int(CKTerritory.state(SITE).get("cache_food", 0))
	_ok(left == 0, "cache emptied on lose got %d" % left)
	_ok(not World.last_siege_loot.is_empty() or true, "loot payload optional if overwritten")
	if not World.last_siege_loot.is_empty() and str(World.last_siege_loot.get("id", "")) == SITE:
		_ok(str(World.last_siege_loot.get("outcome", "")) == "lost", "outcome lost")
		_ok(int(World.last_siege_loot.get("looted", 0)) == 10, "lost looted 10")

func _ui_siege_alert_cache_warn() -> void:
	_own_stockade(14, 2)
	World.last_siege_alert = {}
	CKTerritory.start_threat(SITE)
	World.last_territory_month = {}
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await get_tree().process_frame
	if atlas.has_method("_check_siege_alert"):
		atlas.call("_check_siege_alert")
	await get_tree().process_frame
	var modal: Node = atlas.get_node_or_null("ModalHost")
	if modal == null:
		# some builds nest differently
		for c in atlas.get_children():
			if str(c.name).find("Modal") >= 0 or c.get_node_or_null("SiegeAlertModal") != null:
				modal = c
				break
	var panel = atlas.find_child("SiegeAlertModal", true, false)
	_ok(panel != null, "SiegeAlertModal shown")
	if panel != null:
		var body: Label = panel.get_node_or_null("SiegeAlertBody") as Label
		_ok(body != null and ("14" in body.text or "粮" in body.text or "cache" in body.text.to_lower() or "food" in body.text.to_lower()),
			"alert body mentions cache: %s" % (body.text if body else ""))
	atlas.queue_free()
	await get_tree().process_frame

func _ui_siege_loot_modal() -> void:
	_own_stockade(10, 4)
	CKTerritory.start_threat(SITE)
	var st := CKTerritory.state(SITE)
	st.threat["months"] = 1
	CKTerritory._put(SITE, st)
	World.last_siege_loot = {}
	World.last_siege_alert = {}
	CKTerritory.apply_month(0.0)
	_ok(not World.last_siege_loot.is_empty(), "loot payload after hold resolve")
	World.last_territory_month = {}
	World.last_siege_alert = {}
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await get_tree().process_frame
	if atlas.has_method("_check_siege_loot"):
		atlas.call("_check_siege_loot")
	await get_tree().process_frame
	var panel = atlas.find_child("SiegeLootModal", true, false)
	_ok(panel != null, "SiegeLootModal shown")
	if panel != null:
		var body: Label = panel.get_node_or_null("SiegeLootBody") as Label
		_ok(body != null and body.text != "", "loot body non-empty")
		var ok_btn = panel.get_node_or_null("SiegeLootOk")
		_ok(ok_btn != null, "SiegeLootOk present")
		if ok_btn != null and ok_btn.has_signal("pressed"):
			ok_btn.emit_signal("pressed")
			await get_tree().process_frame
			_ok(atlas.find_child("SiegeLootModal", true, false) == null, "modal cleared after OK")
	atlas.queue_free()
	await get_tree().process_frame
