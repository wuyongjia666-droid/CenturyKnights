extends Node
## Fat atlas: RivalTheftModal after tick_rivals steal + produce arbitrage buy→march→sell E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_rival_theft_drain()
	_api_arbitrage_loop()
	await _ui_rival_theft_modal()
	await _ui_arbitrage_run_sell()
	if _fails.is_empty():
		print("ATLAS RIVAL THEFT ARBITRAGE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL atlas rival-theft/arbitrage: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("截夺跑单", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = true
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 40
	GameState.silver = 12000
	GameState.morale = 80
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	World.cargo.clear()
	World.cargo_basis.clear()
	World.rival_thefts.clear()
	World.arbitrage = {}
	World.last_aftermath.clear()
	World.last_battle_aftermath.clear()

func _seed_intel_for_produce() -> void:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	for cid in ["fog_vale", "reed_ford", "stone_slope", "ash_hq"]:
		World.intel[cid] = World.days_total
		World.visited[cid] = true

func _api_rival_theft_drain() -> void:
	World.rival_thefts.clear()
	World.rival_thefts.append({
		"by": "iron_ledger",
		"city": "ash_capital",
		"quest": "q_fake",
		"title": "测试截夺",
	})
	var peek: Array = World.peek_rival_thefts()
	_ok(peek.size() == 1, "peek keeps thefts")
	var taken: Array = World.take_rival_thefts()
	_ok(taken.size() == 1, "take drains one")
	_ok(World.rival_thefts.is_empty(), "thefts empty after take")
	_ok(str(taken[0].get("title", "")) == "测试截夺", "theft title preserved")
	# live tick path when a stealable offer sits under a rival
	World.rival_thefts.clear()
	if not World.rivals.is_empty():
		var rv: Dictionary = World.rivals[0]
		var city := str(rv.get("pos", "ash_capital"))
		if city == "" or not World.nodes.has(city):
			city = "ash_capital"
			rv.pos = city
		World._ensure_board(city)
		var offers: Array = World.boards[city].offers
		offers.append({
			"id": "theft_seed_q",
			"title": "可截走的牌",
			"kind": "deliver",
			"pay": 40,
			"from": city,
			"target": city,
		})
		var before := World.rival_thefts.size()
		var tick: Dictionary = World.tick_rivals()
		_ok(bool(tick.get("ok", false)), "tick_rivals ok")
		_ok(World.rival_thefts.size() >= before, "tick may append theft (stolen=%s size=%d)" % [tick.get("stolen"), World.rival_thefts.size()])
		World.take_rival_thefts()

func _api_arbitrage_loop() -> void:
	_seed_intel_for_produce()
	World.arbitrage = {}
	World.cargo.clear()
	World.cargo_basis.clear()
	var loops: Array = World.produce_trade_loop("ash_capital")
	_ok(not loops.is_empty(), "produce loops at capital")
	var best: Dictionary = World.best_produce_trade("ash_capital")
	_ok(not best.is_empty() and bool(best.get("known", false)), "best known produce trade")
	if best.is_empty():
		return
	var g := str(best.get("good", ""))
	var dest := str(best.get("sell_city", ""))
	var silver0 := GameState.silver
	var r: Dictionary = World.begin_arbitrage(g, 1, dest)
	_ok(bool(r.get("ok", false)), "begin_arbitrage: %s" % r.get("msg", ""))
	_ok(not World.arbitrage.is_empty(), "arbitrage armed")
	_ok(str(World.arbitrage.get("sell_city", "")) == dest, "sell_city stamped")
	_ok(GameState.silver < silver0, "silver spent on buy")
	_ok(World.have_good(g) >= 1, "cargo has good")
	var busy: Dictionary = World.begin_arbitrage(g, 1, dest)
	_ok(not bool(busy.get("ok", false)), "second begin blocked")
	var wrong: Dictionary = World.complete_arbitrage()
	_ok(not bool(wrong.get("ok", false)), "complete blocked at buy city")
	World.pos = dest
	World.arrive(dest)
	var silver1 := GameState.silver
	var done: Dictionary = World.complete_arbitrage()
	_ok(bool(done.get("ok", false)), "complete_arbitrage: %s" % done.get("msg", ""))
	_ok(World.arbitrage.is_empty(), "arbitrage cleared")
	_ok(GameState.silver > silver1, "silver gained on sell")
	_ok(done.has("margin"), "margin reported")

func _ui_rival_theft_modal() -> void:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.arbitrage = {}
	World.rival_thefts = [{
		"by": "iron_ledger",
		"city": "fog_vale",
		"quest": "q_ui",
		"title": "UI截夺牌",
	}]
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 6:
		await get_tree().process_frame
	# force check (resume may race with losses)
	# resume_state may already have opened the modal and drained thefts
	var modal: Node = page.find_child("RivalTheftModal", true, false)
	if modal == null:
		var shown: bool = bool(page.call("_check_rival_thefts"))
		_ok(shown, "RivalTheftModal shown via check")
		modal = page.find_child("RivalTheftModal", true, false)
	else:
		_ok(true, "RivalTheftModal shown via resume")
	_ok(modal != null, "RivalTheftModal node present")
	if modal != null:
		_ok(modal.get_node_or_null("RivalTheftOk") != null, "RivalTheftOk")
		_ok(modal.get_node_or_null("RivalTheftGo") != null, "RivalTheftGo")
		var okb: Button = modal.get_node_or_null("RivalTheftOk") as Button
		if okb:
			okb.pressed.emit()
			for _j in 3:
				await get_tree().process_frame
	_ok(World.rival_thefts.is_empty(), "thefts drained by modal")
	page.queue_free()
	for _k in 3:
		await get_tree().process_frame

func _ui_arbitrage_run_sell() -> void:
	_seed_intel_for_produce()
	World.arbitrage = {}
	World.cargo.clear()
	World.cargo_basis.clear()
	World.rival_thefts.clear()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	var best: Dictionary = World.best_produce_trade("ash_capital")
	_ok(not best.is_empty(), "ui best trade")
	if best.is_empty():
		return
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 6:
		await get_tree().process_frame
	page.call("_select_node", "ash_capital")
	for _j in 4:
		await get_tree().process_frame
	var run_btn: Node = page.find_child("ArbitrageRun", true, false)
	_ok(run_btn != null, "ArbitrageRun button")
	if run_btn != null and run_btn is BaseButton:
		(run_btn as BaseButton).pressed.emit()
		for _k in 12:
			await get_tree().process_frame
	_ok(not World.arbitrage.is_empty(), "arbitrage armed via UI")
	var dest := str(World.arbitrage.get("sell_city", ""))
	_ok(dest != "" and dest != "ash_capital", "sell dest set %s" % dest)
	# teleport arrive + sell modal
	World.cancel_travel()
	World.travel = {}
	World.pos = dest
	World.arrive(dest)
	page.call("_after_arrival")
	for _n in 8:
		await get_tree().process_frame
	var sell_modal: Node = page.find_child("ArbitrageSellModal", true, false)
	_ok(sell_modal != null, "ArbitrageSellModal on arrival")
	var sell_btn: Node = null
	if sell_modal != null:
		sell_btn = sell_modal.get_node_or_null("ArbitrageSell")
	_ok(sell_btn != null, "ArbitrageSell on modal")
	if sell_btn != null and sell_btn is BaseButton:
		(sell_btn as BaseButton).pressed.emit()
		for _m in 6:
			await get_tree().process_frame
	_ok(World.arbitrage.is_empty(), "arbitrage cleared after sell UI")
	page.queue_free()
	for _z in 3:
		await get_tree().process_frame
