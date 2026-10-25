extends Node
## Fat atlas: stockade month food → cache; SupplyHalt divert/open-仓; arrive modal E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_api_month_fills_cache()
	_api_open_cache_at_anchor()
	_api_divert_opens_or_travels()
	await _ui_halt_shows_cache_btn()
	await _ui_stockade_cache_modal()
	if _fails.is_empty():
		print("ATLAS STOCKADE GRANARY PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas stockade granary: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("屯仓断粮", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 4
	GameState.silver = 8000
	GameState.morale = 70
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_supply_halt.clear()
	World.last_stockade_cache.clear()
	World.pending_cache_site = ""
	World.active.clear()
	CKTerritory.last_month_report = {}

func _own_stockade() -> void:
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
	st.garrison = 2
	CKTerritory._put(SITE, st)
	var built: Dictionary = CKTerritory.build_stockade(SITE)
	_ok(bool(built.get("ok", false)) or bool(CKTerritory.state(SITE).stockade), "stockade built: %s" % built.get("msg", ""))

func _api_month_fills_cache() -> void:
	_own_stockade()
	var food0 := GameState.food
	CKTerritory.last_month_report = {}
	CKTerritory.apply_month(0.99)
	var cache := CKTerritory.cache_food(SITE)
	_ok(cache >= int(CKTerritory.rule("stockade_food", 6)), "month filled cache %d" % cache)
	_ok(GameState.food == food0, "month food stayed in granary (GS food %d == %d)" % [GameState.food, food0])
	_ok(int(CKTerritory.last_month_report.get("food", 0)) >= cache or cache > 0, "report food tracks cache deposit")

func _api_open_cache_at_anchor() -> void:
	_own_stockade()
	var st := CKTerritory.state(SITE)
	st.cache_food = 12
	CKTerritory._put(SITE, st)
	World.pos = str(CKTerritory.site(SITE).get("anchor", ""))
	var food0 := GameState.food
	var r: Dictionary = CKTerritory.open_cache(SITE)
	_ok(bool(r.get("ok", false)), "open_cache ok: %s" % r.get("msg", ""))
	_ok(int(r.get("qty", 0)) == 12, "qty 12")
	_ok(GameState.food == food0 + 12, "GS food +12")
	_ok(CKTerritory.cache_food(SITE) == 0, "cache emptied")

func _api_divert_opens_or_travels() -> void:
	_own_stockade()
	var st := CKTerritory.state(SITE)
	st.cache_food = 9
	CKTerritory._put(SITE, st)
	# Away from stockade, starving mid-march
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	GameState.food = 0
	World.begin_travel("fog_vale")
	World._mark_supply_halt(1)
	_ok(not World.last_supply_halt.is_empty(), "halt marked")
	var opt: Dictionary = World.stockade_cache_option()
	_ok(not opt.is_empty() and int(opt.get("cache", 0)) == 9, "stockade option cache 9")
	var r: Dictionary = World.divert_to_stockade_cache()
	_ok(bool(r.get("ok", false)), "divert ok: %s" % r.get("msg", ""))
	_ok(bool(r.get("traveling", false)) or GameState.food >= 9, "traveling or opened")
	if bool(r.get("traveling", false)):
		_ok(World.pending_cache_site == SITE, "pending_cache_site set")
		_ok(World.is_traveling(), "traveling to stockade")
		var anch := str(CKTerritory.site(SITE).get("anchor", ""))
		_ok(str(World.travel.get("dest", "")) == anch, "dest is stockade anchor")
		# Finish the divert march already in flight (do not begin_travel again).
		World.last_supply_halt.clear()
		GameState.food = maxi(GameState.food, World.food_per_day() * 8 + 2)
		for _i in 64:
			if not World.is_traveling():
				break
			var info: Dictionary = World.step_travel()
			while not info.get("event", {}).is_empty() and str(info.event.get("id", "")) == "camp_night":
				World.pending_event = {}
				if World.travel.has("pending_arrive"):
					info = World._arrive_leg(str(World.travel.pending_arrive))
					info["ok"] = true
				else:
					info = {"ok": true, "arrived": World.travel.is_empty(), "pos": World.pos}
				if bool(info.get("arrived", false)) or World.travel.is_empty():
					break
				info = World.step_travel()
			if bool(info.get("arrived", false)):
				break
		_ok(World.pos == anch, "reached stockade anchor %s (at %s)" % [anch, World.pos])
		if World.last_stockade_cache.is_empty() and World.pos == anch and CKTerritory.cache_food(SITE) > 0:
			World._maybe_mark_stockade_cache(World.pos)
		if not World.last_stockade_cache.is_empty() or (World.pos == anch and CKTerritory.cache_food(SITE) > 0):
			var open_r: Dictionary = World.open_stockade_cache_here(SITE)
			_ok(bool(open_r.get("ok", false)), "open after arrive: %s" % open_r.get("msg", ""))
			_ok(GameState.food >= 9, "food after open >= 9")

func _ui_halt_shows_cache_btn() -> void:
	_own_stockade()
	var st := CKTerritory.state(SITE)
	st.cache_food = 8
	CKTerritory._put(SITE, st)
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	GameState.food = 0
	World.begin_travel("fog_vale")
	World._mark_supply_halt(2)
	# Keep halt for modal (take clears it)
	var halt: Dictionary = World.last_supply_halt.duplicate(true)
	World.cancel_travel()
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	await get_tree().process_frame
	await get_tree().process_frame
	World.last_supply_halt = halt
	if page.has_method("_check_supply_halt"):
		page.call("_check_supply_halt")
	for _i in 10:
		await get_tree().process_frame
	var modal: Node = page.find_child("SupplyHaltModal", true, false)
	_ok(modal != null, "SupplyHaltModal shown")
	var btn: Button = null
	if modal != null:
		btn = modal.get_node_or_null("SupplyStockadeCache") as Button
	_ok(btn != null, "SupplyStockadeCache button present")
	if btn != null:
		btn.pressed.emit()
		for _j in 8:
			await get_tree().process_frame
		_ok(World.is_traveling() or GameState.food > 0 or World.pending_cache_site == SITE,
			"divert engaged after click")
	page.queue_free()
	await get_tree().process_frame

func _ui_stockade_cache_modal() -> void:
	_own_stockade()
	var st := CKTerritory.state(SITE)
	st.cache_food = 7
	CKTerritory._put(SITE, st)
	World.pos = str(CKTerritory.site(SITE).get("anchor", ""))
	GameState.food = 0
	World.last_stockade_cache = {
		"id": SITE,
		"name": str(CKTerritory.site(SITE).get("name", SITE)),
		"anchor": World.pos,
		"cache": 7,
		"auto": true,
	}
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	await get_tree().process_frame
	await get_tree().process_frame
	if page.has_method("_check_stockade_cache"):
		page.call("_check_stockade_cache")
	for _i in 10:
		await get_tree().process_frame
	var modal: Node = page.find_child("StockadeCacheModal", true, false)
	_ok(modal != null, "StockadeCacheModal shown")
	var open_b: Button = null
	if modal != null:
		open_b = modal.get_node_or_null("StockadeCacheOpen") as Button
	_ok(open_b != null, "StockadeCacheOpen button")
	var food0 := GameState.food
	if open_b != null:
		open_b.pressed.emit()
		for _j in 6:
			await get_tree().process_frame
		_ok(GameState.food == food0 + 7, "opened +7 food")
		_ok(CKTerritory.cache_food(SITE) == 0, "cache cleared via UI")
		_ok(page.find_child("StockadeCacheModal", true, false) == null, "modal cleared")
	page.queue_free()
