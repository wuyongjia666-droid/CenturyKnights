extends Node
## Store/economy: city sundry buy → cargo bag sync → use (ration / medicine / forge oil /
## night-market half) → sell-abroad, gates, save/load, named SundryBuy_/Use_/Sell_ UI.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const SY := "sy_capital"       # food (ration) + intel
const IG := "ig_capital"       # forge_iron oil
const EO := "eo_capital"       # medicine
const LT := "lt_capital"       # lantern_half coupon
const ASH := "ash_capital"     # home shelf (sell-abroad source)

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_setup()
	_api_gates_and_ration()
	_api_forge_oil()
	_api_medicine_heal()
	_api_night_market_half()
	_api_sell_abroad()
	_api_save_load()
	await _ui_buy_use_sell()
	if _fails.is_empty():
		print("SUNDRY BUY USE SELL PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL sundry buy use sell: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)

func _setup() -> void:
	GameState.new_game("杂货环", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 80000
	GameState.food = 40
	GameState.iron = 8
	CKSundries.bag().clear()
	World.cargo.clear()
	GameState.house_mods.erase("sundry_ration_pending")
	GameState.house_mods.erase("sundry_forge_iron")
	GameState.house_mods.erase("sundry_half_city")
	GameState.house_mods.erase("sundry_half_day")
	GameState.house_mods.erase("sundry_half_armed")

func _food_id(city: String) -> String:
	for o in CKSundries.shelf_for_city(city):
		var k := CKSundries._kind_of(str(o.id))
		if k == "food" or k == "food_morale_only":
			return str(o.id)
	return ""

func _other_id(city: String, kind: String) -> String:
	for o in CKSundries.shelf_for_city(city):
		if CKSundries._kind_of(str(o.id)) == kind:
			return str(o.id)
	return ""

func _api_gates_and_ration() -> void:
	var food := _food_id(SY)
	_ok(food != "", "sy food on shelf")
	GameState.silver = 0
	_ok(not bool(CKSundries.buy(SY, food).get("ok", false)), "buy rejected when broke")
	GameState.silver = 80000
	CKSundries.bag().clear()
	World.cargo.clear()
	for i in CKSundries.max_stack():
		_ok(bool(CKSundries.buy(SY, food).get("ok", false)), "buy stack %d" % i)
	_ok(not bool(CKSundries.buy(SY, food).get("ok", false)), "stack cap enforced")
	_ok(CKSundries.owned(food) == CKSundries.max_stack(), "owned at cap")
	_ok(int(World.cargo.get(food, 0)) == CKSundries.max_stack(), "cargo synced at cap")
	# home nation refuses dump
	_ok(not bool(CKSundries.sell_half(SY, food).get("ok", false)), "sell rejected at home nation")
	# ration: use food → pending → monthly wages clears
	_ok(bool(CKSundries.use(food, "", SY).get("ok", false)), "use food ok")
	_ok(bool(GameState.house_mods.get("sundry_ration_pending", false)) or CKSundries._kind_of(food) == "food_morale_only",
		"ration pending or morale-only food")
	if CKSundries._kind_of(food) == "food":
		GameState.food = 100
		CKPurse.apply_monthly_wages(GameState)
		_ok(not bool(GameState.house_mods.get("sundry_ration_pending", false)), "ration consumed on wages")
	CKSundries.bag().clear()
	World.cargo.clear()
	# cargo full gate
	var cap := World.cargo_cap()
	for i in cap:
		World.cargo["pad_%d" % i] = 1
	_ok(not bool(CKSundries.buy(SY, food).get("ok", false)), "buy rejected when cargo full")
	World.cargo.clear()

func _api_forge_oil() -> void:
	var oil := _other_id(IG, "forge_iron")
	_ok(oil != "", "ig forge oil on shelf")
	GameState.house_mods.erase("sundry_forge_iron")
	var before := int(CKEconomyState.forge_craft_cost(GameState).iron)
	_ok(bool(CKSundries.buy(IG, oil).get("ok", false)), "buy forge oil")
	_ok(bool(CKSundries.use(oil, "", IG).get("ok", false)), "use forge oil")
	var after := int(CKEconomyState.forge_craft_cost(GameState).iron)
	_ok(before > 1 and after == before - 1, "forge iron cost %d → %d" % [before, after])
	CKSundries.bag().clear()
	World.cargo.clear()
	GameState.house_mods.erase("sundry_forge_iron")

func _api_medicine_heal() -> void:
	var med := _other_id(EO, "medicine")
	_ok(med != "", "eo medicine on shelf")
	var leader: CKCharacter = GameState.get_leader()
	leader.hp = maxi(1, int(leader.max_hp) - 6)
	var hp0 := int(leader.hp)
	_ok(bool(CKSundries.buy(EO, med).get("ok", false)), "buy medicine")
	var r: Dictionary = CKSundries.use(med, leader.id, EO)
	_ok(bool(r.get("ok", false)), "use medicine: %s" % r.get("msg", ""))
	_ok(int(leader.hp) == mini(int(leader.max_hp), hp0 + 4), "medicine healed +4")
	CKSundries.bag().clear()
	World.cargo.clear()

func _api_night_market_half() -> void:
	var coupon := _other_id(LT, "lantern_half")
	var food := _food_id(LT)
	_ok(coupon != "" and food != "", "lt coupon+food on shelf")
	_ok(bool(CKSundries.buy(LT, coupon).get("ok", false)), "buy night coupon")
	_ok(bool(CKSundries.use(coupon, "", LT).get("ok", false)), "arm night-market half")
	_ok(bool(GameState.house_mods.get("sundry_half_armed", false)), "half_armed set")
	var half: Dictionary = CKSundries.buy(LT, food)
	_ok(bool(half.get("ok", false)), "half-price first buy")
	_ok(not bool(GameState.house_mods.get("sundry_half_armed", false)), "half_armed consumed")
	var full: Dictionary = CKSundries.buy(LT, food)
	_ok(bool(full.get("ok", false)), "full-price second buy")
	_ok(int(half.get("price", 0)) < int(full.get("price", 0)), "half %s < full %s" % [half.get("price"), full.get("price")])
	CKSundries.bag().clear()
	World.cargo.clear()
	GameState.house_mods.erase("sundry_half_city")
	GameState.house_mods.erase("sundry_half_day")
	GameState.house_mods.erase("sundry_half_armed")

func _api_sell_abroad() -> void:
	var ash_food := _food_id(ASH)
	_ok(ash_food != "", "ash food on shelf")
	_ok(bool(CKSundries.buy(ASH, ash_food).get("ok", false)), "buy ash food at home")
	_ok(not bool(CKSundries.sell_half(ASH, ash_food).get("ok", false)), "cannot dump at home")
	var sil0 := GameState.silver
	var sold: Dictionary = CKSundries.sell_half(SY, ash_food)
	_ok(bool(sold.get("ok", false)), "sell abroad ok: %s" % sold.get("msg", ""))
	_ok(GameState.silver == sil0 + int(sold.get("price", 0)), "silver +sell price")
	_ok(CKSundries.owned(ash_food) == 0, "bag emptied after sell")
	_ok(int(World.cargo.get(ash_food, 0)) == 0, "cargo cleared after sell")

func _api_save_load() -> void:
	var food := _food_id(SY)
	CKSundries.bag().clear()
	World.cargo.clear()
	_ok(bool(CKSundries.buy(SY, food).get("ok", false)), "buy before save")
	_ok(GameState.save_game(), "save_game")
	CKSundries.bag().clear()
	World.cargo.clear()
	_ok(GameState.load_game(), "load_game")
	_ok(CKSundries.owned(food) >= 1, "bag restored")
	_ok(int(World.cargo.get(food, 0)) >= 1, "cargo restored")
	CKSundries.bag().clear()
	World.cargo.clear()

func _ui_buy_use_sell() -> void:
	GameState.silver = 80000
	CKSundries.bag().clear()
	World.cargo.clear()
	World.pos = ASH
	World.arrive(ASH)
	GameState.set_meta("city_id", ASH)
	var ash_food := _food_id(ASH)
	var city: Control = CITY_SCN.instantiate()
	add_child(city)
	city.set_anchors_preset(Control.PRESET_TOP_LEFT)
	city.position = Vector2.ZERO
	city.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame
	if not city.has_method("_set_tab"):
		_ok(false, "city.gd failed to load")
		city.queue_free()
		return
	city.call("_set_tab", "sundry")
	for _j in 6:
		await get_tree().process_frame
	var buy := city.find_child("SundryBuy_" + ash_food, true, false) as Button
	_ok(buy != null and not buy.disabled, "UI SundryBuy_%s" % ash_food)
	if buy:
		buy.emit_signal("pressed")
		for _k in 5:
			await get_tree().process_frame
	_ok(CKSundries.owned(ash_food) >= 1, "UI buy mutates bag")
	var use := city.find_child("SundryUse_" + ash_food, true, false) as Button
	_ok(use != null and not use.disabled, "UI SundryUse_%s enabled after buy" % ash_food)
	if use:
		use.emit_signal("pressed")
		for _m in 5:
			await get_tree().process_frame
	# buy again so foreign bag has stock to sell abroad
	buy = city.find_child("SundryBuy_" + ash_food, true, false) as Button
	if buy and not buy.disabled:
		buy.emit_signal("pressed")
		for _n in 4:
			await get_tree().process_frame
	city.queue_free()
	await get_tree().process_frame
	# reopen in foreign city for sell row
	World.pos = SY
	World.arrive(SY)
	GameState.set_meta("city_id", SY)
	var city2: Control = CITY_SCN.instantiate()
	add_child(city2)
	city2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	city2.position = Vector2.ZERO
	city2.size = Vector2(1280, 720)
	for _p in 8:
		await get_tree().process_frame
	city2.call("_set_tab", "sundry")
	for _q in 6:
		await get_tree().process_frame
	var sell := city2.find_child("SundrySell_" + ash_food, true, false) as Button
	_ok(sell != null and not sell.disabled, "UI SundrySell_%s abroad" % ash_food)
	var owned0 := CKSundries.owned(ash_food)
	if sell:
		sell.emit_signal("pressed")
		for _r in 5:
			await get_tree().process_frame
	_ok(CKSundries.owned(ash_food) == owned0 - 1, "UI sell mutates bag")
	city2.queue_free()
	await get_tree().process_frame
