extends Node
## Fat atlas block: road-leg danger readout + city first-visit hub discoverability.

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_leg_readouts()
	_api_hub_discover()
	await _ui_atlas_route_legs()
	await _ui_city_hub_discover()
	if _fails.is_empty():
		print("ATLAS TRAVEL FEEL HUB DISCOVER PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas travel/hub: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("跑图手感", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 999
	GameState.silver = 8000
	World.hub_tour.clear()

func _api_leg_readouts() -> void:
	World.pos = "ash_capital"
	World.travel = {}
	var pv: Dictionary = World.travel_preview("fog_vale")
	_ok(bool(pv.get("ok", false)), "preview ash_capital→fog_vale ok")
	if not bool(pv.get("ok", false)):
		return
	var legs: Array = pv.get("leg_readouts", [])
	_ok(legs.size() >= 2, "leg_readouts count %d >= 2" % legs.size())
	_ok(int(pv.get("days", 0)) > 0, "preview days > 0")
	_ok(pv.has("hot_legs"), "preview exposes hot_legs")
	if not legs.is_empty():
		var leg: Dictionary = legs[0]
		_ok(str(leg.get("from_name", "")) != "", "leg has from_name")
		_ok(str(leg.get("kind_zh", "")) != "", "leg has kind_zh")
		_ok(leg.has("danger"), "leg has danger")
		_ok(World.danger_bars(3).contains("▮"), "danger_bars renders")
	# single-hop still one readout
	var one: Dictionary = World.travel_preview("hq")
	_ok(bool(one.get("ok", false)) and (one.get("leg_readouts", []) as Array).size() == 1, "single-hop one leg")

func _api_hub_discover() -> void:
	var city := "ash_capital"
	World.hub_tour.erase(city)
	_ok(World.needs_hub_discover(city), "needs discover before tour")
	var list: Array = World.hub_discover_list(city)
	_ok(list.size() >= 2, "discover list has hubs %d" % list.size())
	var ids: Array = []
	for h in list:
		ids.append(str(h.get("id", "")))
	_ok("market" in ids, "market in discover list")
	World.mark_hub_seen(city, "market")
	_ok(not World.needs_hub_discover(city) or World.hub_discover_list(city).size() < list.size(), "mark_hub_seen reduces list")
	# mark all remaining
	for h2 in World.hub_discover_list(city):
		World.mark_hub_seen(city, str(h2.get("id", "")))
	_ok(not World.needs_hub_discover(city), "tour complete clears discover")
	# persist roundtrip
	var saved: Dictionary = World.to_save()
	_ok(saved.has("hub_tour"), "to_save has hub_tour")
	World.hub_tour.clear()
	World.from_save(saved)
	_ok(not World.needs_hub_discover(city), "hub_tour survives from_save")

func _ui_atlas_route_legs() -> void:
	World.pos = "ash_capital"
	World.travel = {}
	World.encounter = {}
	World.pending_event = {}
	var packed: PackedScene = load("res://scenes/hub/atlas_view.tscn")
	_ok(packed != null, "atlas scene loads")
	if packed == null:
		return
	var page: Control = packed.instantiate()
	get_tree().root.add_child(page)
	for _i in 8:
		await get_tree().process_frame
	# select multi-leg destination
	if page.has_method("_select_node"):
		page.call("_select_node", "fog_vale")
	for _j in 4:
		await get_tree().process_frame
	var legs := page.find_child("RouteLegs", true, false)
	_ok(legs != null, "desktop RouteLegs present")
	if legs != null:
		var leg0 := legs.find_child("Leg_0", true, false)
		_ok(leg0 != null, "Leg_0 row present")
	var go := page.find_child("HudGo", true, false) as Button
	_ok(go != null, "HudGo present with legs")
	page.queue_free()
	await get_tree().process_frame

func _ui_city_hub_discover() -> void:
	World.pos = "ash_capital"
	World.hub_tour.erase("ash_capital")
	GameState.set_meta("city_id", "ash_capital")
	var packed: PackedScene = load("res://scenes/hub/city.tscn")
	_ok(packed != null, "city scene loads")
	if packed == null:
		return
	var page: Control = packed.instantiate()
	get_tree().root.add_child(page)
	for _i in 8:
		await get_tree().process_frame
	var band := page.find_child("HubDiscover", true, false)
	_ok(band != null, "HubDiscover strip on first visit")
	var goto_m := page.find_child("GotoHub_market", true, false) as Button
	_ok(goto_m != null, "GotoHub_market CTA")
	if goto_m != null:
		goto_m.emit_signal("pressed")
		for _k in 6:
			await get_tree().process_frame
		_ok(bool(World.hub_tour.get("ash_capital", {}).get("market", false)), "opening market marks seen")
		# back to overview — strip should still show remaining hubs if any
		if page.has_method("_set_tab"):
			page.call("_set_tab", "overview")
		for _n in 4:
			await get_tree().process_frame
		var still := page.find_child("HubDiscover", true, false)
		var remain := World.hub_discover_list("ash_capital").size()
		if remain > 0:
			_ok(still != null, "strip remains while hubs unseen")
		else:
			_ok(still == null, "strip gone when tour done")
	page.queue_free()
	await get_tree().process_frame
