extends Node
## WS-C #14/#34/#38/#39：酒馆价格带+刷新说明、联姻三个关键数+详情、市集季节价、铁匠就地升级+空状态。

var _fails: Array = []


func _ready() -> void:
	await get_tree().process_frame
	GameState.new_game("霜行", "灰旗", GameState.crest_color)
	_market()
	await _forge()
	_tavern()
	await _marriage()
	if _fails.is_empty():
		print("LINE C SHOPS PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL line_c_shops: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _market() -> void:
	var m0 := Calendar.month
	Calendar.month = 1
	var flat: Dictionary = GameState.market_buy_prices()
	Calendar.month = 3
	var spring: Dictionary = GameState.market_buy_prices()
	_ok(int(spring.food) == int(flat.food) + 1, "spring food not dearer %s vs %s" % [spring, flat])
	for mo in range(1, 13):
		Calendar.month = mo
		var b: Dictionary = GameState.market_buy_prices()
		var s: Dictionary = GameState.market_sell_prices()
		for k in b.keys():
			_ok(int(s[k]) <= int(b[k]), "month %d %s sell %d > buy %d" % [mo, k, int(s[k]), int(b[k])])
	Calendar.month = m0


func _forge() -> void:
	var packed: PackedScene = load("res://scenes/hub/forge.tscn")
	var f := packed.instantiate()
	add_child(f)
	await get_tree().process_frame
	var lv := GameState.building_level("forge")
	GameState.silver = 0
	GameState.iron = 0
	f.call("upgrade_forge")
	_ok(GameState.building_level("forge") == lv, "upgrade without money")
	_ok(str(f.get("_msg").text) != "", "no failure reason")
	GameState.silver = 9999
	GameState.iron = 999
	GameState.food = 999
	f.call("upgrade_forge")
	_ok(GameState.building_level("forge") == lv + 1, "forge did not upgrade in place")
	_ok(f.find_child("ForgeUpgrade", true, false) != null, "upgrade button missing")
	f.queue_free()
	await get_tree().process_frame


func _tavern() -> void:
	var prices := {}
	for i in 40:
		GameState.refresh_tavern()
		for c in GameState.tavern_candidates:
			prices[CKEconomyState.recruit_price(GameState, c)] = true
	_ok(prices.size() >= 4, "tavern prices barely vary: %s" % str(prices.keys()))
	_ok(CKEconomyState.recruit_band(20) == "cheap" and CKEconomyState.recruit_band(45) == "prime", "bands")
	_ok(FileAccess.get_file_as_string("res://scripts/hub/tavern.gd").find("wsc_tv_rule") >= 0, "refresh rule tooltip missing")


func _marriage() -> void:
	var packed: PackedScene = load("res://scenes/hub/marriage.tscn")
	var m := packed.instantiate()
	add_child(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var k := m.find_child("KeyFacts", true, false) as Label
	if GameState.marriage_candidates.is_empty():
		_ok(k != null, "key facts label missing")
	else:
		_ok(k != null and k.text.find("礼银") >= 0, "key facts not shown: %s" % (k.text if k else "null"))
	m.call("show_details")
	_ok(m.find_child("MarriageDetails", false, false) != null, "details box missing")
	m.queue_free()
	await get_tree().process_frame
