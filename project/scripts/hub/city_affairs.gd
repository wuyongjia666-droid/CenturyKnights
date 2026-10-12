class_name CKCityAffairs
extends RefCounted
## v9.2 本城之事：每座城一件小事，办完记旗标 affair_<节点>。职印要先把这件事办了。
## 头一回来（声望不到「认识」）就是报个名，不花钱；之后按城的特产/类型给一件花点资源的事。

const DATA := "res://data/city_affairs_v92.json"
const ACQUAINTED := 10
static var _doc: Dictionary = {}


static func _load() -> Dictionary:
	if _doc.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
		_doc = parsed if typeof(parsed) == TYPE_DICTIONARY else {"templates": []}
	return _doc


static func flag_key(city: String) -> String:
	return "affair_%s" % city


static func done(city: String) -> bool:
	return bool(GameState.story.flags.get(flag_key(city), false))


static func _row(id: String) -> Dictionary:
	for r in _load().get("templates", []):
		if str(r.get("id", "")) == id:
			return r
	return {}


static func template_for(city: String) -> Dictionary:
	if World.rep_of(city) < ACQUAINTED:
		return _row("first_meet")
	var n: Dictionary = World.node(city)
	var spec := str(n.get("specialty", "")) + str(n.get("name", ""))
	for r in _load().get("templates", []):
		for s in r.get("specialties", []):
			if str(s) != "" and spec.find(str(s)) >= 0:
				return r
	var by_kind := {"village": "rest", "port": "gossip", "capital": "honor", "fortress": "honor", "town": "supply", "city": "forge"}
	var r2 := _row(str(by_kind.get(str(n.get("kind", "")), "supply")))
	return r2 if not r2.is_empty() else _row("supply")


static func cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "不花钱"
	var parts: Array = []
	var names := {"silver": "银", "food": "粮", "iron": "铁"}
	for k in cost.keys():
		parts.append("%d %s" % [int(cost[k]), names.get(k, k)])
	return "花 " + "、".join(parts)


static func label(city: String) -> String:
	if done(city):
		return "本城之事：已办完"
	var r := template_for(city)
	return "本城之事：%s（%s）" % [str(r.get("label", "")), cost_text(r.get("cost", {}))]


## 能不能办；不能办就给一句原因。
static func can_do(city: String) -> Dictionary:
	if city == "" or World.node(city).is_empty():
		return {"ok": false, "msg": "这里不是城镇"}
	if done(city):
		return {"ok": false, "msg": "这座城的事已经办过了"}
	var cost: Dictionary = template_for(city).get("cost", {})
	var have := {"silver": int(GameState.silver), "food": int(GameState.food), "iron": int(GameState.iron)}
	var names := {"silver": "银", "food": "粮", "iron": "铁"}
	for k in cost.keys():
		if int(have.get(k, 0)) < int(cost[k]):
			return {"ok": false, "msg": "%s不够：要 %d，现在 %d" % [names.get(k, k), int(cost[k]), int(have.get(k, 0))]}
	return {"ok": true, "msg": ""}


static func do_affair(city: String) -> Dictionary:
	var chk := can_do(city)
	if not bool(chk.get("ok", false)):
		return chk
	var r := template_for(city)
	var cost: Dictionary = r.get("cost", {})
	GameState.silver -= int(cost.get("silver", 0))
	GameState.food -= int(cost.get("food", 0))
	GameState.iron -= int(cost.get("iron", 0))
	GameState.set_flag(flag_key(city), true)
	World.add_city_rep(city, 2)
	GameState.mark_dirty()
	return {"ok": true, "msg": "办好了：%s。城里人记住你们了，声望 +2" % str(r.get("label", ""))}
