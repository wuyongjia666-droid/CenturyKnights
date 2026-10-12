extends Node
## 杂货铺：本国货架、陆桥过路货、买/用/满五份/没钱/本国不收、口粮少吃 1、冷钢油、页签不出屏。

func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL sundry: ", err)
		get_tree().quit(1)
		return
	print("SUNDRY PASS")
	get_tree().quit(0)


func _run() -> String:
	GameState.new_game("烬行", "灰旗", "frost")
	var city := ""
	for k in World.nodes.keys():
		if str(k).begins_with("lb_"):
			continue
		for o0 in CKSundries.shelf_for_city(str(k)):
			if CKSundries._kind_of(str(o0.id)) == "food":
				city = str(k)
		if city != "":
			break
	if city == "":
		return "no city with shelf"
	var shelf: Array = CKSundries.shelf_for_city(city)
	var food := ""
	for o in shelf:
		if CKSundries._kind_of(str(o.id)) == "food":
			food = str(o.id)
	if food == "":
		return "no food on shelf"
	# failure: no silver
	GameState.silver = 0
	if bool(CKSundries.buy(city, food).get("ok", false)):
		return "bought with 0 silver"
	GameState.silver = 500
	for i in 5:
		if not bool(CKSundries.buy(city, food).get("ok", false)):
			return "buy %d failed" % i
	if bool(CKSundries.buy(city, food).get("ok", false)):
		return "stack cap not enforced"
	# home country won't take dumps
	if bool(CKSundries.sell_half(city, food).get("ok", false)):
		return "sold at home"
	# ration: next month eats one less
	if not bool(CKSundries.use(food, "", city).get("ok", false)):
		return "use food"
	if CKSundries.owned(food) != 4:
		return "owned after use %d" % CKSundries.owned(food)
	CKSundries.use(food, "", city)
	if not bool(GameState.house_mods.get("sundry_ration_pending", false)):
		return "ration flag"
	GameState.food = 100
	CKPurse.apply_monthly_wages(GameState)
	if bool(GameState.house_mods.get("sundry_ration_pending", false)):
		return "ration not consumed"
	# forge oil
	var before: int = int(CKEconomyState.forge_craft_cost(GameState).iron)
	GameState.house_mods["sundry_forge_iron"] = 1
	var after: int = int(CKEconomyState.forge_craft_cost(GameState).iron)
	if before > 1 and after != before - 1:
		return "forge oil %d -> %d" % [before, after]
	# not-yet kinds are blocked and not consumed
	for nid in CKSundries._load().nations.keys():
		for key in ["food", "other"]:
			var it: Dictionary = CKSundries._load().nations[nid].get(key, {})
			if str(it.get("kind", "")) in ["salt_fare", "pepper_bonus"]:
				CKSundries.bag()[str(it.id)] = 1
				if bool(CKSundries.use(str(it.id), "", city).get("ok", false)) or CKSundries.owned(str(it.id)) != 1:
					return "not-yet item consumed"
	# bridge shelf: only neighbours, +40%
	for k in World.nodes.keys():
		if str(k).begins_with("lb_"):
			for o in CKSundries.shelf_for_city(str(k)):
				if int(o.get("price", 0)) <= CKSundries.base_price():
					return "bridge markup missing"
			break
	# UI: tabs stay on screen, buttons 48
	var scene: Node = load("res://scenes/hub/city.tscn").instantiate()
	scene.set("city", city)
	add_child(scene)
	await get_tree().process_frame
	scene._set_tab("sundry")
	await get_tree().process_frame
	await get_tree().process_frame
	var tabs: Control = scene.find_child("Tabs", true, false)
	if tabs != null and tabs.get_global_rect().end.x > 1280.5:
		return "tabs overflow %.0f" % tabs.get_global_rect().end.x
	var body: Node = scene.find_child("Body", true, false)
	for b in body.find_children("SundryBuy_*", "Button", true, false):
		if b.get_combined_minimum_size().y < 48:
			return "buy button too small"
	return ""
