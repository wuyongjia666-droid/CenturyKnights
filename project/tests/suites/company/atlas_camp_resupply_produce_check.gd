extends Node
## Fat atlas block: camp readout, stopover resupply, produce trade-loop discoverability.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const CITY_SCN := preload("res://scenes/hub/city.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_camp_readout()
	_api_resupply()
	_api_produce_loop()
	await _ui_camp_readout()
	await _ui_stopover_modal()
	await _ui_trade_loop_atlas_and_city()
	if _fails.is_empty():
		print("ATLAS CAMP RESUPPLY PRODUCE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas camp/resupply/produce: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("停靠", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 12
	GameState.silver = 8000
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}

func _api_camp_readout() -> void:
	World.pos = "ash_capital"
	GameState.food = 8
	var st: Dictionary = World.begin_travel("stone_slope")
	_ok(bool(st.get("ok", false)), "begin_travel for camp")
	if not bool(st.get("ok", false)):
		return
	var info: Dictionary = World.step_travel()
	var ev: Dictionary = info.get("event", {})
	_ok(str(ev.get("id", "")) == "camp_night", "camp_night event on leg")
	var cr: Dictionary = World.camp_readout(ev)
	_ok(int(cr.get("food", -1)) == GameState.food, "camp_readout food")
	_ok(int(cr.get("per_day", 0)) == World.food_per_day(), "camp_readout per_day")
	_ok(cr.has("remain_days") and cr.has("remain_food") and cr.has("short"), "camp_readout keys")
	World.choose_event(0)
	World.cancel_travel()
	World.pending_event = {}
	World.travel = {}

func _api_resupply() -> void:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	GameState.food = 5
	var before := GameState.food
	var silver0 := GameState.silver
	var q: Dictionary = World.resupply_quote("ash_capital", 7)
	_ok(bool(q.get("ok", false)), "resupply_quote ok qty=%s cost=%s" % [q.get("qty"), q.get("cost")])
	_ok(int(q.get("qty", 0)) >= World.food_per_day(), "resupply qty covers days")
	var r: Dictionary = World.resupply_food("ash_capital", 7)
	_ok(bool(r.get("ok", false)), "resupply_food: %s" % r.get("msg", ""))
	_ok(GameState.food > before, "food increased %d → %d" % [before, GameState.food])
	_ok(GameState.silver < silver0, "silver spent")

func _api_produce_loop() -> void:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	var loops0: Array = World.produce_trade_loop("ash_capital")
	_ok(not loops0.is_empty(), "produce_trade_loop non-empty at capital")
	# Seed intel on cities that demand local produce (ashsteel / iron).
	for row0 in loops0:
		var g0 := str(row0.get("good", ""))
		for cid in World.nodes.keys():
			if str(cid) == "ash_capital":
				continue
			if g0 in World.node(str(cid)).get("demand", []):
				World.intel[str(cid)] = World.days_total
				World.visited[str(cid)] = true
				break
	# fog_vale demands ashsteel — ensure covered
	World.intel["fog_vale"] = World.days_total
	World.visited["fog_vale"] = true
	World.intel["reed_ford"] = World.days_total
	World.visited["reed_ford"] = true
	var loops: Array = World.produce_trade_loop("ash_capital")
	var known := false
	for row in loops:
		if bool(row.get("known", false)):
			known = true
			_ok(int(row.get("sell", 0)) > 0, "known loop has sell price")
			break
	_ok(known, "produce loop known after intel")
	var best: Dictionary = World.best_produce_trade("ash_capital")
	_ok(not best.is_empty() and bool(best.get("known", false)), "best_produce_trade")

func _ui_camp_readout() -> void:
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	GameState.food = 6
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 5:
		await get_tree().process_frame
	World.begin_travel("stone_slope")
	var info: Dictionary = World.step_travel()
	_ok(str(info.get("event", {}).get("id", "")) == "camp_night", "ui camp event ready")
	if page.has_method("_show_event_modal"):
		page.call("_show_event_modal", info.event)
	for _j in 4:
		await get_tree().process_frame
	var cr := page.find_child("CampReadout", true, false)
	_ok(cr != null, "CampReadout label in event modal")
	if cr != null:
		_ok(str(cr.text).find(str(GameState.food)) >= 0 or str(cr.text).length() > 8, "CampReadout has text")
	page.queue_free()
	await get_tree().process_frame
	World.pending_event = {}
	World.travel = {}

func _ui_stopover_modal() -> void:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.travel = {}
	GameState.food = 4
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 5:
		await get_tree().process_frame
	page.set("_halted_dest", "fog_vale")
	if page.has_method("_show_stopover_modal"):
		page.call("_show_stopover_modal")
	for _j in 4:
		await get_tree().process_frame
	var modal := page.find_child("StopoverModal", true, false)
	_ok(modal != null, "StopoverModal present")
	var buy := page.find_child("StopoverBuy", true, false) as Button
	_ok(buy != null, "StopoverBuy CTA")
	var mkt := page.find_child("StopoverMarket", true, false) as Button
	_ok(mkt != null, "StopoverMarket CTA")
	var resume := page.find_child("StopoverResume", true, false) as Button
	_ok(resume != null, "StopoverResume CTA when halted_dest set")
	var food_before := GameState.food
	if buy != null and not buy.disabled:
		buy.emit_signal("pressed")
		for _k in 4:
			await get_tree().process_frame
		_ok(GameState.food > food_before, "StopoverBuy raised food %d → %d" % [food_before, GameState.food])
	else:
		_ok(false, "StopoverBuy missing or disabled")
	page.queue_free()
	await get_tree().process_frame

func _ui_trade_loop_atlas_and_city() -> void:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.intel["fog_vale"] = World.days_total
	World.visited["fog_vale"] = true
	World.intel["reed_ford"] = World.days_total
	World.visited["reed_ford"] = true
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 5:
		await get_tree().process_frame
	if page.has_method("_select_node"):
		page.call("_select_node", "ash_capital")
	for _j in 4:
		await get_tree().process_frame
	var loop := page.find_child("TradeLoop", true, false)
	_ok(loop != null, "atlas TradeLoop on place sheet")
	var goto := page.find_child("TradeLoopGoto", true, false)
	_ok(goto != null, "atlas TradeLoopGoto when here")
	page.queue_free()
	await get_tree().process_frame
	GameState.set_meta("city_id", "ash_capital")
	var city: Control = CITY_SCN.instantiate()
	get_tree().root.add_child(city)
	for _k in 6:
		await get_tree().process_frame
	var ov := city.find_child("TradeLoop", true, false)
	_ok(ov != null, "city overview TradeLoop")
	var go2 := city.find_child("TradeLoopGoto", true, false) as Button
	_ok(go2 != null, "city TradeLoopGoto")
	if go2 != null:
		go2.emit_signal("pressed")
		for _m in 5:
			await get_tree().process_frame
		var strip := city.find_child("TradeLoopStrip", true, false)
		_ok(strip != null, "market TradeLoopStrip after goto")
	city.queue_free()
	await get_tree().process_frame
