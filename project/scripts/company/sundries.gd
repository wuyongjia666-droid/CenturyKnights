class_name CKSundries
extends RefCounted
## v9.2 杂货铺：十国日用品 + 陆桥过路货。货舱占用，不进粮铁仓。

const DATA := "res://data/sundries_v92.json"
const HALF_SELL := 0.5

static var _doc: Dictionary = {}


static func _load() -> Dictionary:
	if not _doc.is_empty():
		return _doc
	if not FileAccess.file_exists(DATA):
		_doc = {}
		return _doc
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_doc = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _doc


static func base_price() -> int:
	return int(_load().get("base_price", 6))


static func max_stack() -> int:
	return int(_load().get("max_stack", 5))


static func shelf_for_city(city: String) -> Array:
	_load()
	var nid := World.nation_of(city)
	var out: Array = []
	if str(nid) == "landbridge" or city.begins_with("lb_"):
		return _bridge_shelf(city)
	var row: Dictionary = _load().get("nations", {}).get(nid, {})
	for key in ["food", "other"]:
		var item: Dictionary = row.get(key, {})
		if item.is_empty():
			continue
		out.append(_offer(item, nid, 1.0, city))
	return out


static func _bridge_shelf(city: String) -> Array:
	var linked: Array = _bridge_nations(city)
	var out: Array = []
	var markup := float(_load().get("bridge", {}).get("markup", 1.4))
	for nid in linked:
		var row: Dictionary = _load().get("nations", {}).get(str(nid), {})
		var food: Dictionary = row.get("food", {})
		if food.is_empty():
			continue
		out.append(_offer(food, str(nid), markup, city))
	return out


static func _bridge_nations(city: String) -> Array:
	## 与陆桥节点道路相连的两侧国度（最多两国）。
	var seen := {}
	var n: Dictionary = World.nodes.get(city, {}) if typeof(World.nodes) == TYPE_DICTIONARY else {}
	if n.is_empty():
		for row in World.nodes.values() if typeof(World.nodes) == TYPE_DICTIONARY else []:
			pass
		## nodes may be array-backed via World API
	var links: Array = []
	if World.has_method("node_links"):
		links = World.node_links(city)
	elif World.has_method("neighbors"):
		links = World.neighbors(city)
	else:
		links = _fallback_links(city)
	for other in links:
		var oid := World.nation_of(str(other))
		if oid == "" or oid == "landbridge":
			continue
		seen[oid] = true
	return seen.keys()


static func _fallback_links(city: String) -> Array:
	## 西/中/东桥硬编码两侧，避免 World API 差异卡住杂货。
	match city:
		"lb_west":
			return ["ash_market", "lb_mid"]
		"lb_mid":
			return ["lb_west", "lb_east"]
		"lb_east":
			return ["lb_mid", "sy_coast"]
		_:
			return []


static func _offer(item: Dictionary, nation: String, markup: float, city: String) -> Dictionary:
	var price := int(round(float(base_price()) * markup))
	price = _rep_price(city, price)
	return {
		"id": str(item.get("id", "")),
		"name": str(item.get("name", "")),
		"kind": str(item.get("kind", "")),
		"desc": str(item.get("desc", "")),
		"nation": nation,
		"price": price,
		"owned": owned(str(item.get("id", ""))),
	}


static func _rep_price(city: String, base: int) -> int:
	## 友善及以上沿用市集价优比例。
	if World.has_method("quote_buy_factor"):
		return maxi(1, int(round(float(base) * float(World.quote_buy_factor(city)))))
	var rep := World.city_rep(city) if World.has_method("city_rep") else 0
	if rep >= 30:
		return maxi(1, int(round(float(base) * 0.9)))
	return base


static func bag() -> Dictionary:
	var raw = GameState.house_mods.get("sundry_bag", null)
	if typeof(raw) != TYPE_DICTIONARY:
		raw = {}
		GameState.house_mods["sundry_bag"] = raw
	return raw


static func owned(iid: String) -> int:
	return int(bag().get(iid, 0))


static func buy(city: String, iid: String) -> Dictionary:
	var offer := {}
	for row in shelf_for_city(city):
		if str(row.get("id", "")) == iid:
			offer = row
			break
	if offer.is_empty():
		return {"ok": false, "msg": Locale.t("sundry_not_here")}
	if owned(iid) >= max_stack():
		return {"ok": false, "msg": Locale.t("sundry_stack_cap")}
	if World.cargo_used() + 1 > World.cargo_cap():
		return {"ok": false, "msg": Locale.t("sundry_cargo_full")}
	var price := int(offer.get("price", base_price()))
	if str(GameState.house_mods.get("sundry_half_city", "")) == city and str(GameState.house_mods.get("sundry_half_day", "")) == _day_key():
		## 夜市剩券：第二件半价（本城本日）
		if bool(GameState.house_mods.get("sundry_half_armed", false)):
			price = maxi(1, int(price / 2))
			GameState.house_mods["sundry_half_armed"] = false
	if GameState.silver < price:
		return {"ok": false, "msg": Locale.t("sundry_no_silver")}
	GameState.silver -= price
	bag()[iid] = owned(iid) + 1
	World.cargo[iid] = int(World.cargo.get(iid, 0)) + 1
	GameState.mark_dirty()
	return {"ok": true, "msg": Locale.t("sundry_bought") % [str(offer.get("name", "")), price], "price": price}


static func sell_half(city: String, iid: String) -> Dictionary:
	if owned(iid) <= 0:
		return {"ok": false, "msg": Locale.t("sundry_none")}
	var nation := _nation_of_item(iid)
	if nation != "" and nation == World.nation_of(city) and not city.begins_with("lb_"):
		return {"ok": false, "msg": Locale.t("sundry_sell_home")}
	var price := maxi(1, int(round(float(base_price()) * HALF_SELL)))
	bag()[iid] = owned(iid) - 1
	if owned(iid) <= 0:
		bag().erase(iid)
	World.cargo[iid] = maxi(0, int(World.cargo.get(iid, 0)) - 1)
	if int(World.cargo.get(iid, 0)) <= 0:
		World.cargo.erase(iid)
	GameState.silver += price
	GameState.mark_dirty()
	return {"ok": true, "msg": Locale.t("sundry_sold") % price, "price": price}


static func use(iid: String, target_id: String = "") -> Dictionary:
	if owned(iid) <= 0:
		return {"ok": false, "msg": Locale.t("sundry_none")}
	var kind := _kind_of(iid)
	var r := {"ok": false, "msg": Locale.t("sundry_no_effect")}
	match kind:
		"food", "food_morale_only":
			r = _use_food(kind == "food")
		"medicine":
			r = _use_medicine(target_id)
		"intel", "intel_route":
			r = _use_intel(kind == "intel_route")
		"lantern_half":
			r = _use_lantern_half()
		"salt_fare":
			GameState.house_mods["sundry_salt_fare"] = 4
			r = {"ok": true, "msg": Locale.t("sundry_salt_ok")}
		"forge_iron":
			GameState.house_mods["sundry_forge_iron"] = 1
			r = {"ok": true, "msg": Locale.t("sundry_forge_ok")}
		"pepper_bonus":
			GameState.house_mods["sundry_pepper"] = 5
			r = {"ok": true, "msg": Locale.t("sundry_pepper_ok")}
		_:
			pass
	if not bool(r.get("ok", false)):
		return r
	bag()[iid] = owned(iid) - 1
	if owned(iid) <= 0:
		bag().erase(iid)
	World.cargo[iid] = maxi(0, int(World.cargo.get(iid, 0)) - 1)
	if int(World.cargo.get(iid, 0)) <= 0:
		World.cargo.erase(iid)
	GameState.mark_dirty()
	return r


static func _use_food(save_ration: bool) -> Dictionary:
	var ym := "%d-%d" % [Calendar.year, Calendar.month]
	var key := str(_load().get("morale_month_key", "sundry_morale_ym"))
	var morale_ok := str(GameState.house_mods.get(key, "")) != ym
	if morale_ok:
		GameState.morale = mini(100, int(GameState.morale) + 1)
		GameState.house_mods[key] = ym
	if save_ration:
		GameState.house_mods["sundry_ration_day"] = _day_key()
	var msg := Locale.t("sundry_food_morale") if morale_ok else Locale.t("sundry_food_only")
	return {"ok": true, "msg": msg}


static func _use_medicine(target_id: String) -> Dictionary:
	var c: CKCharacter = GameState.characters.get(target_id) if target_id != "" else null
	if c == null:
		for person in GameState.roster():
			if person != null and person.alive and int(person.hp) < int(person.max_hp) and int(person.hp) > 0:
				c = person
				break
	if c == null or not c.alive:
		return {"ok": false, "msg": Locale.t("sundry_no_wounded")}
	c.hp = mini(int(c.max_hp), int(c.hp) + 4)
	return {"ok": true, "msg": Locale.t("sundry_healed") % c.name}


static func _use_intel(route: bool) -> Dictionary:
	var city := str(GameState.house_mods.get("current_city", World.current_city if "current_city" in World else ""))
	if city == "":
		city = str(GameState.flags.get("last_city", ""))
	var talk_key := "affair_talk_%s" % city
	if city != "" and not bool(GameState.flags.get(talk_key, false)):
		GameState.set_flag(talk_key, true)
		if World.has_method("add_city_rep"):
			World.add_city_rep(city, 1)
		elif World.has_method("city_rep_add"):
			World.city_rep_add(city, 1)
	if route:
		GameState.house_mods["sundry_route_preview"] = true
	return {"ok": true, "msg": Locale.t("sundry_intel_ok")}


static func _use_lantern_half() -> Dictionary:
	var city := str(GameState.house_mods.get("current_city", ""))
	GameState.house_mods["sundry_half_city"] = city
	GameState.house_mods["sundry_half_day"] = _day_key()
	GameState.house_mods["sundry_half_armed"] = true
	return {"ok": true, "msg": Locale.t("sundry_half_ok")}


static func _kind_of(iid: String) -> String:
	for nid in _load().get("nations", {}).keys():
		var row: Dictionary = _load().get("nations", {})[nid]
		for key in ["food", "other"]:
			var item: Dictionary = row.get(key, {})
			if str(item.get("id", "")) == iid:
				return str(item.get("kind", ""))
	return ""


static func _nation_of_item(iid: String) -> String:
	for nid in _load().get("nations", {}).keys():
		var row: Dictionary = _load().get("nations", {})[nid]
		for key in ["food", "other"]:
			if str(row.get(key, {}).get("id", "")) == iid:
				return str(nid)
	return ""


static func _day_key() -> String:
	return "%d-%d" % [Calendar.year, Calendar.month]
