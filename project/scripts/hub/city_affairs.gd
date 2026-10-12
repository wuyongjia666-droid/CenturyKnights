class_name CKCityAffairs
extends RefCounted
## v9.2 本城之事：6 模板，旗标 affair_<节点>。

const DATA := "res://data/city_affairs_v92.json"
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


static func flag_key(city: String) -> String:
	return "affair_%s" % city


static func done(city: String) -> bool:
	return bool(GameState.flags.get(flag_key(city), false))


static func mark_done(city: String) -> void:
	GameState.set_flag(flag_key(city), true)


static func template_for(city: String) -> Dictionary:
	var n: Dictionary = World.node(city) if World.has_method("node") else {}
	var spec := str(n.get("specialty", "")) + str(n.get("kind", "")) + str(n.get("name", ""))
	var templates: Array = _load().get("templates", [])
	## first_meet if rep below 认识
	var rep := 0
	if World.has_method("city_rep"):
		rep = int(World.city_rep(city))
	if rep < 10:
		for row in templates:
			if str(row.get("id", "")) == "first_meet":
				return row
	for row in templates:
		var specs: Array = row.get("specialties", [])
		for s in specs:
			if str(s) != "" and spec.find(str(s)) >= 0:
				return row
	## fallback by kind
	var kind := str(n.get("kind", ""))
	var by_kind := {"village": "rest", "port": "gossip", "capital": "honor", "fortress": "honor", "town": "supply", "city": "forge"}
	var want := str(by_kind.get(kind, "supply"))
	for row in templates:
		if str(row.get("id", "")) == want:
			return row
	return templates[0] if templates.size() > 0 else {}


static func label(city: String) -> String:
	if done(city):
		return Locale.t("affair_done")
	var row := template_for(city)
	var tid := str(row.get("id", "supply"))
	return Locale.t("affair_" + tid)


static func try_complete_from_action(city: String, action: String) -> bool:
	if done(city):
		return false
	var row := template_for(city)
	if str(row.get("action", "")) != action and action != "force":
		return false
	mark_done(city)
	return true
