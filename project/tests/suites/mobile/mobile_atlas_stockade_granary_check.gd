extends Node
## Mobile E2E: SupplyHalt → SupplyStockadeCache divert / StockadeCacheModal open.

const PHONE := Vector2i(2400, 1080)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas stockade granary: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS STOCKADE GRANARY PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.cache_food = 0
	st.threat = {}
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	st = CKTerritory.state(SITE)
	st.garrison = 2
	st.stockade = true
	st.cache_food = 10
	CKTerritory._put(SITE, st)
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	GameState.food = 0
	World.begin_travel("fog_vale")
	World._mark_supply_halt(2)
	var halt: Dictionary = World.last_supply_halt.duplicate(true)
	World.cancel_travel()
	var page := await _mount_atlas()
	World.last_supply_halt = halt
	if page.has_method("_check_supply_halt"):
		page.call("_check_supply_halt")
	for _j in 10:
		await get_tree().process_frame
	var modal: Node = page.find_child("SupplyHaltModal", true, false)
	if modal == null:
		page.queue_free()
		return "SupplyHaltModal missing"
	var btn: Button = modal.get_node_or_null("SupplyStockadeCache") as Button
	if btn == null:
		page.queue_free()
		return "SupplyStockadeCache missing"
	btn.pressed.emit()
	for _k in 10:
		await get_tree().process_frame
	if not (World.is_traveling() or World.pending_cache_site == SITE or GameState.food > 0):
		page.queue_free()
		return "divert did not engage"
	# Seed arrive modal at stockade on a fresh atlas page
	page.queue_free()
	await get_tree().process_frame
	World.pos = anchor
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.pending_cache_site = ""
	World.last_supply_halt.clear()
	st = CKTerritory.state(SITE)
	st.cache_food = 10
	CKTerritory._put(SITE, st)
	GameState.food = 0
	var payload := {
		"id": SITE, "name": str(CKTerritory.site(SITE).get("name", SITE)),
		"anchor": anchor, "cache": 10, "auto": true,
	}
	World.last_stockade_cache = payload.duplicate(true)
	page = await _mount_atlas()
	var cm: Node = page.find_child("StockadeCacheModal", true, false)
	if cm == null and page.has_method("_check_stockade_cache"):
		World.last_stockade_cache = payload.duplicate(true)
		page.call("_check_stockade_cache")
		for _m in 12:
			await get_tree().process_frame
		cm = page.find_child("StockadeCacheModal", true, false)
	if cm == null and page.has_method("_show_stockade_cache_modal"):
		page.call("_show_stockade_cache_modal", payload.duplicate(true))
		for _m2 in 8:
			await get_tree().process_frame
		cm = page.find_child("StockadeCacheModal", true, false)
	if cm == null:
		page.queue_free()
		return "StockadeCacheModal missing"
	var open_b: Button = cm.get_node_or_null("StockadeCacheOpen") as Button
	if open_b == null:
		page.queue_free()
		return "StockadeCacheOpen missing"
	var food0 := GameState.food
	open_b.pressed.emit()
	for _n in 8:
		await get_tree().process_frame
	if GameState.food != food0 + 10:
		page.queue_free()
		return "food not +10 after open (%d)" % GameState.food
	if CKTerritory.cache_food(SITE) != 0:
		page.queue_free()
		return "cache not emptied"
	page.queue_free()
	return ""

func _boot() -> void:
	GameState.new_game("Mobile屯仓", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 8000
	GameState.morale = 70
	World.hub_tour.clear()
	World.pending_event = {}
	World.encounter = {}
	World.last_supply_halt.clear()
	World.last_stockade_cache.clear()
	World.pending_cache_site = ""

func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	await get_tree().process_frame

func _mount_atlas() -> Node:
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	await get_tree().process_frame
	await get_tree().process_frame
	return page
