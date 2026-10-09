class_name CKLifeEvents
extends RefCounted
## DYN-04: life-event cards. The month hook only queues a card.
## Choices apply traits, stats, regard, paths, or the academy note when resolved.
## Queuing does not touch GameState.rng, silver, or food.

const DATA_PATH := "res://data/life_events.json"

static var _doc: Dictionary = {}
static var _installed := false


static func ensure() -> void:
	if _installed:
		return
	_installed = true
	Calendar.register("family", Callable(CKLifeEvents, "on_month"), 40)


static func events() -> Array:
	_load()
	return _doc.get("events", [])


static func on_month(_ctx: Dictionary) -> void:
	var people: Array = GameState.characters.values()
	people.sort_custom(func(a, b): return str(a.id) < str(b.id))
	for c in people:
		if not c.alive or _has_pending(c.id):
			continue
		var pool := eligible(c)
		if pool.is_empty():
			continue
		var idx := absi(hash("%s|%d|%d" % [c.id, Calendar.year, Calendar.month])) % pool.size()
		var event: Dictionary = pool[idx]
		_mark(c.id, str(event.get("id", "")))
		_pending_rows().append({"cid": c.id, "id": str(event.get("id", ""))})


static func eligible(c: CKCharacter) -> Array:
	var out: Array = []
	for event in events():
		var id := str(event.get("id", ""))
		if _fired(c.id).has(id):
			continue
		if not _fits(c, event):
			continue
		out.append(event)
	out.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	return out


static func pending_band(cid: String, band: String) -> Dictionary:
	for item in _pending_rows():
		if str(item.get("cid", "")) != cid:
			continue
		var event := find(str(item.get("id", "")))
		if str(event.get("band", "")) == band:
			return event
	return {}


static func find(id: String) -> Dictionary:
	for event in events():
		if str(event.get("id", "")) == id:
			return event
	return {}


static func resolve(cid: String, event_id: String, option_id: String) -> bool:
	var event := find(event_id)
	var opt := _option(event, option_id)
	if opt.is_empty():
		return false
	var c: CKCharacter = GameState.characters.get(cid)
	if c == null:
		return false
	var changed := apply_option(c, opt)
	_drop_pending(cid, event_id)
	return changed


static func apply_option(c: CKCharacter, opt: Dictionary) -> bool:
	var changed := false
	for fx in opt.get("effects", []):
		if typeof(fx) != TYPE_DICTIONARY:
			continue
		if _apply(c, fx):
			changed = true
	return changed


static func fired_ids(cid: String) -> Array:
	var out: Array = []
	for id in _fired(cid):
		out.append(str(id))
	return out


static func _fits(c: CKCharacter, event: Dictionary) -> bool:
	var age := int(c.age)
	if age < int(event.get("age_min", 0)) or age > int(event.get("age_max", 200)):
		return false
	match str(event.get("need", "")):
		"spouse":
			if str(c.spouse_id) == "" or not GameState.characters.has(c.spouse_id):
				return false
		"sibling":
			if not _sibling(c):
				return false
		"academy":
			if int(GameState.house_mods.get("dyn_academy", 0)) < 1:
				return false
		_:
			pass
	return true


static func _sibling(c: CKCharacter) -> bool:
	for other in GameState.characters.values():
		if other == null or other.id == c.id or not other.alive:
			continue
		for pid in c.parent_ids:
			if str(pid) != "" and str(pid) in other.parent_ids:
				return true
	return false


static func _apply(c: CKCharacter, fx: Dictionary) -> bool:
	match str(fx.get("op", "")):
		"flag":
			var key := str(fx.get("key", ""))
			if key == "" or str(c.blood_meta.get(key, "")) == "1":
				return false
			c.blood_meta[key] = "1"
			return true
		"stat":
			var stat := str(fx.get("key", "wil"))
			var before := int(c.stats.get(stat, 0))
			c.stats[stat] = clampi(before + int(fx.get("delta", 1)), 1, 30)
			return int(c.stats.get(stat, 0)) != before
		"trait":
			var trait_id := str(fx.get("trait", ""))
			if trait_id == "" or trait_id in c.traits:
				return false
			c.traits.append(trait_id)
			return true
		"rep":
			var realm := str(fx.get("realm", "ashland"))
			var before_rep := int(GameState.reputation.get(realm, 0))
			GameState.add_rep(realm, int(fx.get("delta", 1)))
			return int(GameState.reputation.get(realm, 0)) != before_rep
		"path":
			var path := str(fx.get("path", ""))
			if path == "":
				return false
			GameState.lineage_path[c.id] = path
			return true
		"academy":
			var cur := int(GameState.house_mods.get("dyn_academy", 0))
			var nxt := maxi(cur, int(fx.get("tier", 1)))
			if nxt == cur:
				return false
			GameState.house_mods["dyn_academy"] = nxt
			return true
		_:
			return false


static func _option(event: Dictionary, option_id: String) -> Dictionary:
	for opt in event.get("options", []):
		if str(opt.get("id", "")) == option_id:
			return opt
	return {}


static func _has_pending(cid: String) -> bool:
	for item in _pending_rows():
		if str(item.get("cid", "")) == cid:
			return true
	return false


static func _drop_pending(cid: String, event_id: String) -> void:
	var kept: Array = []
	for item in _pending_rows():
		if str(item.get("cid", "")) == cid and str(item.get("id", "")) == event_id:
			continue
		kept.append(item)
	GameState.house_mods["life_pending"] = kept


static func _pending_rows() -> Array:
	var raw = GameState.house_mods.get("life_pending", null)
	if typeof(raw) != TYPE_ARRAY:
		raw = []
		GameState.house_mods["life_pending"] = raw
	return raw


static func _fired(cid: String) -> Array:
	var book = GameState.house_mods.get("life_fired", null)
	if typeof(book) != TYPE_DICTIONARY:
		book = {}
		GameState.house_mods["life_fired"] = book
	if typeof(book.get(cid, null)) != TYPE_ARRAY:
		book[cid] = []
	return book[cid]


static func _mark(cid: String, event_id: String) -> void:
	var row := _fired(cid)
	if not row.has(event_id):
		row.append(event_id)


static func _load() -> void:
	if not _doc.is_empty():
		return
	if not FileAccess.file_exists(DATA_PATH):
		_doc = {"events": []}
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_doc = parsed if typeof(parsed) == TYPE_DICTIONARY else {"events": []}
