extends Node
## Fat E2E: cross-city produce arbitrage deepen —
## march preview stamps, short-food reject, stock top-up, city TradeLoop one-tap, sell at dest.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const HOME := "ash_capital"

var _fails: Array = []
var _mobile := false


func _ready() -> void:
	await get_tree().process_frame
	_mobile = DeviceProfile.is_mobile()
	if _mobile:
		var win := get_tree().root
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.size = Vector2i(2400, 1080)
		await get_tree().process_frame
		await get_tree().process_frame
	_setup()
	_api_march_preview_and_stamps()
	_setup()
	_api_short_food_reject()
	_setup()
	_api_stock_topup_and_loop()
	_setup()
	await _ui_city_run_and_sell()
	if _fails.is_empty():
		print("MARKET CROSS CITY ARBITRAGE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL market cross-city arbitrage: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _setup() -> void:
	GameState.new_game("产地跑单", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	World.active.clear()
	World.cargo.clear()
	World.cargo_basis.clear()
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.arbitrage = {}
	World.hub_tour.clear()
	World.pos = HOME
	World.visited[HOME] = true
	World.rep_city[HOME] = 40
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	GameState.silver = 8000
	GameState.food = 200
	GameState.morale = 80
	_seed_intel()


func _seed_intel() -> void:
	World.pos = HOME
	World.arrive(HOME)
	for cid in ["fog_vale", "reed_ford", "stone_slope", "ash_hq", "iron_pass"]:
		if World.nodes.has(cid):
			World.intel[cid] = World.days_total
			World.visited[cid] = true


func _best() -> Dictionary:
	return World.best_produce_trade(HOME)


func _api_march_preview_and_stamps() -> void:
	var best: Dictionary = _best()
	_ok(not best.is_empty() and bool(best.get("known", false)), "best known produce trade")
	if best.is_empty():
		return
	var g := str(best.get("good", ""))
	var dest := str(best.get("sell_city", ""))
	var prev: Dictionary = World.arbitrage_march_preview(dest)
	_ok(int(prev.get("days", 0)) > 0, "march preview days>0 (%s)" % prev)
	_ok(int(prev.get("food", 0)) > 0, "march preview food>0")
	_ok(not bool(prev.get("short_food", true)), "food enough for preview")
	var r: Dictionary = World.begin_arbitrage(g, 1, dest, true)
	_ok(bool(r.get("ok", false)), "begin ok: %s" % r.get("msg", ""))
	_ok(not World.arbitrage.is_empty(), "plan armed")
	_ok(int(World.arbitrage.get("march_days", 0)) == int(prev.get("days", -1)), "march_days stamped")
	_ok(int(World.arbitrage.get("march_food", 0)) == int(prev.get("food", -1)), "march_food stamped")
	_ok(bool(World.arbitrage.get("seal_bypass", false)) == bool(prev.get("seal_bypass", false)), "seal_bypass stamped")
	_ok(str(World.arbitrage.get("sell_city", "")) == dest, "sell_city=%s" % dest)
	var busy: Dictionary = World.begin_arbitrage(g, 1, dest, true)
	_ok(not bool(busy.get("ok", false)), "second begin blocked")


func _api_short_food_reject() -> void:
	var best: Dictionary = _best()
	_ok(not best.is_empty(), "short-food best")
	if best.is_empty():
		return
	var g := str(best.get("good", ""))
	var dest := str(best.get("sell_city", ""))
	var prev: Dictionary = World.arbitrage_march_preview(dest)
	var need := int(prev.get("food", 1))
	GameState.food = maxi(0, need - 1)
	World.arbitrage = {}
	World.cargo.clear()
	var r: Dictionary = World.begin_arbitrage(g, 1, dest, true)
	_ok(not bool(r.get("ok", false)), "short food rejected")
	_ok(str(r.get("msg", "")).find(str(need)) >= 0 or str(r.get("msg", "")).find("粮") >= 0, "short-food msg mentions need")
	_ok(World.arbitrage.is_empty(), "no plan when short")
	# without require_food still arms (legacy atlas soft path)
	GameState.food = maxi(0, need - 1)
	var soft: Dictionary = World.begin_arbitrage(g, 1, dest, false)
	_ok(bool(soft.get("ok", false)), "soft begin without require_food still ok")
	World.clear_arbitrage()
	World.cargo.clear()
	GameState.food = 200


func _api_stock_topup_and_loop() -> void:
	var best: Dictionary = _best()
	_ok(not best.is_empty(), "topup best")
	if best.is_empty():
		return
	var g := str(best.get("good", ""))
	var dest := str(best.get("sell_city", ""))
	# drain stall stock
	if not World.market.has(HOME):
		World._init_market(HOME)
	World.market[HOME][g] = 0
	_ok(World.stock(HOME, g) == 0, "stall drained")
	var silver0 := GameState.silver
	var r: Dictionary = World.begin_arbitrage(g, 1, dest, true)
	_ok(bool(r.get("ok", false)), "top-up begin: %s" % r.get("msg", ""))
	_ok(World.have_good(g) >= 1, "cargo after top-up buy")
	_ok(GameState.silver < silver0, "silver spent")
	var wrong: Dictionary = World.complete_arbitrage()
	_ok(not bool(wrong.get("ok", false)), "complete blocked at buy city")
	World.pos = dest
	World.arrive(dest)
	var silver1 := GameState.silver
	var done: Dictionary = World.complete_arbitrage()
	_ok(bool(done.get("ok", false)), "complete at dest: %s" % done.get("msg", ""))
	_ok(World.arbitrage.is_empty(), "cleared after sell")
	_ok(GameState.silver > silver1, "silver gained")
	_ok(done.has("margin"), "margin reported")


func _ui_city_run_and_sell() -> void:
	_seed_intel()
	World.arbitrage = {}
	World.cargo.clear()
	World.cargo_basis.clear()
	World.pos = HOME
	World.arrive(HOME)
	GameState.food = 200
	GameState.silver = 8000
	var best: Dictionary = _best()
	_ok(not best.is_empty(), "ui best")
	if best.is_empty():
		return
	var page: Control = CITY_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 8:
		await get_tree().process_frame
	# overview tab should expose ArbitrageRun
	if page.has_method("_set_tab"):
		page.call("_set_tab", "overview")
	for _j in 6:
		await get_tree().process_frame
	var run_btn: Node = page.find_child("ArbitrageRun", true, false)
	_ok(run_btn != null, "city ArbitrageRun")
	if run_btn != null and run_btn is BaseButton:
		(run_btn as BaseButton).pressed.emit()
		for _k in 10:
			await get_tree().process_frame
	_ok(not World.arbitrage.is_empty(), "armed via city UI")
	var dest := str(World.arbitrage.get("sell_city", ""))
	_ok(dest != "" and dest != HOME, "sell dest %s" % dest)
	_ok(int(World.arbitrage.get("march_days", 0)) > 0, "ui plan has march_days")
	var pend: Node = page.find_child("ArbitragePending", true, false)
	# re-render to show pending
	if page.has_method("_render_tab"):
		page.call("_render_tab")
	for _r in 6:
		await get_tree().process_frame
	pend = page.find_child("ArbitragePending", true, false)
	_ok(pend != null, "ArbitragePending after arm")
	var march_btn: Node = page.find_child("ArbitrageMarch", true, false)
	_ok(march_btn != null, "ArbitrageMarch when not at dest")
	# teleport to dest and sell via city
	World.cancel_travel()
	World.travel = {}
	World.pos = dest
	World.arrive(dest)
	page.queue_free()
	for _z in 3:
		await get_tree().process_frame
	var page2: Control = CITY_SCN.instantiate()
	get_tree().root.add_child(page2)
	for _i2 in 8:
		await get_tree().process_frame
	if page2.has_method("_set_tab"):
		page2.call("_set_tab", "overview")
	for _j2 in 6:
		await get_tree().process_frame
	var sell_btn: Node = page2.find_child("ArbitrageSell", true, false)
	_ok(sell_btn != null, "city ArbitrageSell at dest")
	if sell_btn != null and sell_btn is BaseButton:
		(sell_btn as BaseButton).pressed.emit()
		for _m in 8:
			await get_tree().process_frame
	_ok(World.arbitrage.is_empty(), "cleared after city sell")
	page2.queue_free()
	for _z2 in 3:
		await get_tree().process_frame
