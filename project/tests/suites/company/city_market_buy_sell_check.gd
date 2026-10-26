extends Node
## City market buy/sell loop: regional prices, 旗库/cargo, stock, refresh, broke/full failures, save/load, UI buttons.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_regional_prices_and_stock()
	_api_store_vs_cargo()
	_api_failures()
	_api_refresh()
	_api_save_load()
	await _ui_buy_sell_refresh()
	if _fails.is_empty():
		print("CITY MARKET BUY SELL PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL city market: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("市集", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 20
	GameState.silver = 12000
	World.hub_tour.clear()
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.cargo.clear()
	World.cargo_basis.clear()

func _api_regional_prices_and_stock() -> void:
	var cap := "ash_capital"
	var prod := "ashsteel"
	var st0 := World.stock(cap, prod)
	_ok(st0 > 0, "capital has ashsteel stock %d" % st0)
	var here := World.price(cap, prod, "buy")
	World.pos = "fog_vale"
	World.arrive("fog_vale")
	var there := World.price("fog_vale", prod, "buy")
	_ok(here < there, "regional produce cheaper at home %d vs %d" % [here, there])
	World.pos = cap
	World.arrive(cap)

func _api_store_vs_cargo() -> void:
	World.pos = "ash_capital"
	var food0 := GameState.food
	var r_grain: Dictionary = World.market_buy("ash_capital", "grain", 3)
	_ok(bool(r_grain.get("ok", false)), "buy grain into 旗库: %s" % r_grain.get("msg", ""))
	_ok(GameState.food == food0 + 3, "food +3 got %d" % GameState.food)
	_ok(World.stock("ash_capital", "grain") < World._target_stock("ash_capital", "grain"), "grain stock dropped after buy")
	var cargo0 := int(World.cargo.get("ashsteel", 0))
	var r_steel: Dictionary = World.market_buy("ash_capital", "ashsteel", 2)
	_ok(bool(r_steel.get("ok", false)), "buy ashsteel into cargo")
	_ok(int(World.cargo.get("ashsteel", 0)) == cargo0 + 2, "cargo ashsteel +2")

func _api_failures() -> void:
	World.pos = "ash_capital"
	GameState.silver = 0
	var broke: Dictionary = World.market_buy("ash_capital", "grain", 1)
	_ok(not bool(broke.get("ok", false)) and str(broke.get("msg", "")).find("银币") >= 0, "broke buy rejected")
	GameState.silver = 50000
	World.market["ash_capital"]["grain"] = 0
	var empty: Dictionary = World.market_buy("ash_capital", "grain", 1)
	_ok(not bool(empty.get("ok", false)) and str(empty.get("msg", "")).find("存货") >= 0, "empty stock rejected")
	World.market["ash_capital"]["grain"] = World._target_stock("ash_capital", "grain")
	World.cargo.clear()
	for g in World.goods.keys():
		if str(World.goods[g].get("store", "")) == "":
			World.cargo[g] = World.cargo_cap()
			break
	var cap_good := ""
	for g in World.goods.keys():
		if str(World.goods[g].get("store", "")) == "":
			cap_good = str(g)
			break
	if cap_good != "":
		var full: Dictionary = World.market_buy("ash_capital", cap_good, 1)
		_ok(not bool(full.get("ok", false)) and str(full.get("msg", "")).find("货舱") >= 0, "full cargo rejected")
	World.cargo.clear()

func _api_refresh() -> void:
	World.pos = "ash_capital"
	GameState.silver = 500
	World.market["ash_capital"]["ashsteel"] = 1
	var st := World.stock("ash_capital", "ashsteel")
	var rr: Dictionary = World.refresh_market("ash_capital")
	_ok(bool(rr.get("ok", false)), "refresh ok: %s" % rr.get("msg", ""))
	_ok(World.stock("ash_capital", "ashsteel") > st, "refresh raised ashsteel stock")
	for g in World.goods.keys():
		World.market["ash_capital"][str(g)] = World._target_stock("ash_capital", str(g))
	GameState.silver = 500
	var full_shelf: Dictionary = World.refresh_market("ash_capital")
	_ok(not bool(full_shelf.get("ok", false)), "refresh full shelves rejected")
	_ok(GameState.silver == 500, "full refresh does not charge")
	World.market["ash_capital"]["ashsteel"] = World._target_stock("ash_capital", "ashsteel") + 8
	var over := World.stock("ash_capital", "ashsteel")
	var over_r: Dictionary = World.refresh_market("ash_capital")
	_ok(not bool(over_r.get("ok", false)), "overstock refresh rejected")
	_ok(World.stock("ash_capital", "ashsteel") == over, "rejected refresh does not pull overstock")
	_ok(GameState.silver == 500, "rejected refresh does not charge")
	GameState.silver = 0
	World.market["ash_capital"]["ashsteel"] = 1
	var broke_ref: Dictionary = World.refresh_market("ash_capital")
	_ok(not bool(broke_ref.get("ok", false)), "broke refresh rejected")
	_ok(World.stock("ash_capital", "ashsteel") == 1, "broke refresh does not restock")
	World.market["ash_capital"]["ashsteel"] = World._target_stock("ash_capital", "ashsteel")

func _api_save_load() -> void:
	World.pos = "ash_capital"
	GameState.silver = 8000
	World.cargo.clear()
	var bought: Dictionary = World.market_buy("ash_capital", "ashsteel", 2)
	_ok(bool(bought.get("ok", false)), "pre-save buy")
	var snap_stock := World.stock("ash_capital", "ashsteel")
	var snap_cargo := int(World.cargo.get("ashsteel", 0))
	var snap_silver := GameState.silver
	_ok(GameState.save_game(), "save_game")
	World.reset()
	GameState.silver = 1
	World.cargo.clear()
	_ok(GameState.load_game(), "load_game")
	_ok(World.stock("ash_capital", "ashsteel") == snap_stock, "stock round-trip")
	_ok(int(World.cargo.get("ashsteel", 0)) == snap_cargo, "cargo round-trip")
	_ok(GameState.silver == snap_silver, "silver round-trip")

func _ui_buy_sell_refresh() -> void:
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.cargo.clear()
	World.cargo_basis.clear()
	GameState.silver = 12000
	GameState.set_meta("city_id", "ash_capital")
	GameState.set_meta("city_tab", "market")
	var city: Control = CITY_SCN.instantiate()
	get_tree().root.add_child(city)
	for _i in 6:
		await get_tree().process_frame
	var g := "ashsteel"
	var buy := city.find_child("Mkt_%s_buy1" % g, true, false) as Button
	_ok(buy != null and not buy.disabled, "UI buy button")
	var c0 := int(World.cargo.get(g, 0))
	if buy != null:
		buy.emit_signal("pressed")
		for _j in 4:
			await get_tree().process_frame
	_ok(int(World.cargo.get(g, 0)) == c0 + 1, "UI buy mutates cargo")
	World.pos = "fog_vale"
	World.arrive("fog_vale")
	city.queue_free()
	await get_tree().process_frame
	GameState.set_meta("city_id", "fog_vale")
	GameState.set_meta("city_tab", "market")
	var city2: Control = CITY_SCN.instantiate()
	get_tree().root.add_child(city2)
	for _k in 6:
		await get_tree().process_frame
	var sell := city2.find_child("Mkt_%s_sell1" % g, true, false) as Button
	_ok(sell != null and not sell.disabled, "UI sell button at demand city")
	var s0 := GameState.silver
	if sell != null:
		sell.emit_signal("pressed")
		for _m in 4:
			await get_tree().process_frame
	_ok(GameState.silver > s0, "UI sell adds silver")
	city2.queue_free()
	await get_tree().process_frame
