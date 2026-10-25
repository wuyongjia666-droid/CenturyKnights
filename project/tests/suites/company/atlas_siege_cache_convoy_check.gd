extends Node
## Fat atlas: under siege, evacuate stockade cache to sister stockade / company; SiegeEvacuate E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const DEST := "t_ash_millrun"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_api_need_threat()
	_api_evacuate_to_sister()
	_api_evacuate_to_company()
	_api_loot_skips_empty_cache()
	await _ui_siege_evacuate_btn()
	if _fails.is_empty():
		print("ATLAS SIEGE CACHE CONVOY PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas siege cache convoy: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("SiegeConvoy", "AshBanner", GameState.crest_color)
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

func _own_stockade(id: String, cache: int, garrison: int = 2) -> void:
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
	_own_stockade(SITE, 10)
	var r: Dictionary = CKTerritory.evacuate_cache(SITE)
	_ok(not bool(r.get("ok", false)), "refuse without threat")
	_ok(CKTerritory.cache_food(SITE) == 10, "cache untouched")

func _api_evacuate_to_sister() -> void:
	_setup()
	_own_stockade(DEST, 0, 1)
	_own_stockade(SITE, 12, 2)
	CKTerritory.start_threat(SITE)
	World.last_siege_convoy = {}
	var food0 := GameState.food
	var r: Dictionary = CKTerritory.evacuate_cache(SITE)
	_ok(bool(r.get("ok", false)), "evacuate ok: %s" % r.get("msg", ""))
	_ok(CKTerritory.cache_food(SITE) == 0, "source emptied")
	_ok(str(r.get("via", "")) == "stockade", "via stockade")
	_ok(CKTerritory.cache_food(DEST) == int(r.get("delivered", 0)), "dest received %d" % CKTerritory.cache_food(DEST))
	_ok(GameState.food == food0, "company food unchanged")
	_ok(not World.last_siege_convoy.is_empty(), "convoy payload set")
	_ok(int(World.last_siege_convoy.get("delivered", 0)) == int(r.get("delivered", -1)), "payload delivered matches")

func _api_evacuate_to_company() -> void:
	_setup()
	_own_stockade(SITE, 8, 2)
	# no sister stockade
	CKTerritory.start_threat(SITE)
	World.last_siege_convoy = {}
	var food0 := GameState.food
	var r: Dictionary = CKTerritory.evacuate_cache(SITE)
	_ok(bool(r.get("ok", false)), "evacuate to company ok")
	_ok(str(r.get("via", "")) == "company", "via company")
	_ok(CKTerritory.cache_food(SITE) == 0, "source empty")
	_ok(GameState.food == food0 + int(r.get("delivered", 0)), "food gained %d" % (GameState.food - food0))

func _api_loot_skips_empty_cache() -> void:
	_setup()
	_own_stockade(SITE, 10, 4)
	CKTerritory.start_threat(SITE)
	CKTerritory.evacuate_cache(SITE)
	_ok(CKTerritory.cache_food(SITE) == 0, "evacuated")
	var st := CKTerritory.state(SITE)
	st.threat["months"] = 1
	CKTerritory._put(SITE, st)
	World.last_siege_loot = {}
	CKTerritory.apply_month(0.0)
	_ok(World.last_siege_loot.is_empty(), "no loot when cache empty")
	_ok(CKTerritory.owned(SITE), "still held")

func _ui_siege_evacuate_btn() -> void:
	_setup()
	_own_stockade(DEST, 0, 1)
	_own_stockade(SITE, 14, 2)
	World.last_siege_alert = {}
	World.last_territory_month = {}
	CKTerritory.start_threat(SITE)
	_ok(int(World.last_siege_alert.get("cache", 0)) == 14, "alert cache 14")
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
		var btn = panel.get_node_or_null("SiegeEvacuate")
		_ok(btn != null, "SiegeEvacuate present")
		if btn != null:
			btn.emit_signal("pressed")
			await get_tree().process_frame
			_ok(CKTerritory.cache_food(SITE) == 0, "UI evacuate emptied source")
			_ok(CKTerritory.cache_food(DEST) > 0 or GameState.food > 40, "food landed somewhere")
	atlas.queue_free()
	await get_tree().process_frame
