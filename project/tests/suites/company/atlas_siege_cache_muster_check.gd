extends Node
## Fat atlas: under siege, spend stockade cache food → +1 garrison; SiegeMuster E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_api_need_threat()
	_api_need_food()
	_api_muster_ok()
	_api_cap_full()
	await _ui_siege_muster_btn()
	if _fails.is_empty():
		print("ATLAS SIEGE CACHE MUSTER PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas siege cache muster: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("SiegeMuster", "AshBanner", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
	GameState.silver = 9000
	GameState.morale = 80
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_siege_alert = {}
	World.last_siege_loot = {}
	World.last_siege_convoy = {}
	World.last_siege_muster = {}
	CKTerritory.last_month_report = {}

func _reset(id: String) -> void:
	var st: Dictionary = CKTerritory.state(id)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.cache_food = 0
	CKTerritory._put(id, st)

func _own_stockade(id: String, cache: int, garrison: int = 1) -> void:
	_reset(id)
	var anchor := str(CKTerritory.site(id).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(id, "chain")
	var st := CKTerritory.state(id)
	st.garrison = garrison
	st.stockade = true
	st.cache_food = cache
	st.threat = {}
	CKTerritory._put(id, st)

func _api_need_threat() -> void:
	_setup()
	_own_stockade(SITE, 12, 1)
	var r: Dictionary = CKTerritory.muster_from_cache(SITE)
	_ok(not bool(r.get("ok", false)), "refuse without threat")
	_ok(CKTerritory.cache_food(SITE) == 12, "cache untouched")
	_ok(int(CKTerritory.state(SITE).garrison) == 1, "garrison untouched")

func _api_need_food() -> void:
	_setup()
	var cost := CKTerritory.muster_cache_cost(SITE)
	_own_stockade(SITE, maxi(0, cost - 1), 1)
	CKTerritory.start_threat(SITE)
	var r: Dictionary = CKTerritory.muster_from_cache(SITE)
	_ok(not bool(r.get("ok", false)), "refuse short cache")
	_ok(int(CKTerritory.state(SITE).garrison) == 1, "garrison still 1")

func _api_muster_ok() -> void:
	_setup()
	var cost := CKTerritory.muster_cache_cost(SITE)
	_own_stockade(SITE, cost + 3, 1)
	CKTerritory.start_threat(SITE)
	World.last_siege_muster = {}
	var hold0 := CKTerritory.hold_chance(SITE)
	var r: Dictionary = CKTerritory.muster_from_cache(SITE)
	_ok(bool(r.get("ok", false)), "muster ok: %s" % r.get("msg", ""))
	_ok(int(r.get("spent", 0)) == cost, "spent %d" % cost)
	_ok(CKTerritory.cache_food(SITE) == 3, "cache left 3")
	_ok(int(CKTerritory.state(SITE).garrison) == 2, "garrison 2")
	_ok(CKTerritory.hold_chance(SITE) > hold0, "hold_chance up")
	_ok(not World.last_siege_muster.is_empty(), "muster payload set")
	_ok(int(World.last_siege_muster.get("garrison", 0)) == 2, "payload garrison")

func _api_cap_full() -> void:
	_setup()
	_own_stockade(SITE, 20, 1)
	CKTerritory.start_threat(SITE)
	var gmax := CKTerritory.garrison_max(SITE)
	var st := CKTerritory.state(SITE)
	st.garrison = gmax
	CKTerritory._put(SITE, st)
	var r: Dictionary = CKTerritory.muster_from_cache(SITE)
	_ok(not bool(r.get("ok", false)), "refuse at cap")
	_ok(CKTerritory.cache_food(SITE) == 20, "cache untouched at cap")

func _ui_siege_muster_btn() -> void:
	_setup()
	var cost := CKTerritory.muster_cache_cost(SITE)
	_own_stockade(SITE, cost + 2, 1)
	World.last_siege_alert = {}
	World.last_territory_month = {}
	CKTerritory.start_threat(SITE)
	_ok(int(World.last_siege_alert.get("cache", 0)) == cost + 2, "alert cache set")
	var atlas: Node = ATLAS_SCN.instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await get_tree().process_frame
	if atlas.has_method("_check_siege_alert"):
		atlas.call("_check_siege_alert")
	await get_tree().process_frame
	var panel = atlas.find_child("SiegeAlertModal", true, false)
	_ok(panel != null, "SiegeAlertModal shown")
	if panel != null:
		var btn = panel.get_node_or_null("SiegeMuster")
		_ok(btn != null, "SiegeMuster present")
		if btn != null:
			btn.emit_signal("pressed")
			await get_tree().process_frame
			_ok(int(CKTerritory.state(SITE).garrison) == 2, "UI muster +1 garrison")
			_ok(CKTerritory.cache_food(SITE) == 2, "UI spent cache")
	atlas.queue_free()
	await get_tree().process_frame
