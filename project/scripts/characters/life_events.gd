class_name CKLifeEvents
extends RefCounted
## DYN-04: life-event cards (岁课口吻：title / body / left / right).
## Month hook fires a card, auto-picks left/right with a stable seed
## (character id + year + month + event id), applies effects, and
## queues a read-only inbox row. No player A/B choice. 岁课 keeps choices.

const DATA_PATH := "res://data/life_events.json"

static var _doc: Dictionary = {}
static var _installed := false


static func ensure() -> void:
	if _installed:
		return
	_installed = true
	Calendar.register("family", Callable(CKLifeEvents, "on_month"), 40)
	_drain_legacy_pending()


static func events() -> Array:
	_load()
	return _doc.get("events", [])


static func on_month(_ctx: Dictionary) -> void:
	_drain_legacy_pending()
	var people: Array = GameState.characters.values()
	people.sort_custom(func(a, b): return str(a.id) < str(b.id))
	for c in people:
		if not c.alive:
			continue
		# v9.2：1–15 岁家中子嗣走岁课，退出每月重卡队列
		if CKSuiKe.is_house_child_for_life_queue(c):
			continue
		var pool := eligible(c)
		if pool.is_empty():
			continue
		var idx := absi(hash("%s|%d|%d" % [c.id, Calendar.year, Calendar.month])) % pool.size()
		var event: Dictionary = pool[idx]
		var eid := str(event.get("id", ""))
		_mark(c.id, eid)
		fire_and_resolve(c.id, eid)


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


## Stable left/right pick for a fired card. Reload yields the same side.
static func pick_side(cid: String, event_id: String, year: int = -1, month: int = -1) -> String:
	var y := Calendar.year if year < 0 else year
	var m := Calendar.month if month < 0 else month
	var h := absi(hash("%s|%d|%d|%s" % [cid, y, m, event_id]))
	return "left" if (h % 2) == 0 else "right"


## Apply the seeded side, append a read-only inbox row, log lineage.
## Returns the inbox row (empty on failure).
static func fire_and_resolve(cid: String, event_id: String, year: int = -1, month: int = -1) -> Dictionary:
	var y := Calendar.year if year < 0 else year
	var m := Calendar.month if month < 0 else month
	var event := find(event_id)
	if event.is_empty():
		return {}
	var c: CKCharacter = GameState.characters.get(cid)
	if c == null:
		return {}
	var side := pick_side(cid, event_id, y, m)
	var opt := _option(event, side)
	if opt.is_empty():
		# Prefer the other side if the seeded one is missing.
		side = "right" if side == "left" else "left"
		opt = _option(event, side)
	if opt.is_empty():
		return {}
	apply_option(c, opt)
	_drop_pending(cid, event_id)
	var side_row: Dictionary = event.get(side, {})
	if typeof(side_row) != TYPE_DICTIONARY:
		side_row = {}
	var outcome := choice_label({
		"act": str(side_row.get("act", opt.get("act", ""))),
		"hint": str(side_row.get("hint", "")),
	})
	var row := {
		"cid": cid,
		"id": event_id,
		"side": side,
		"outcome": outcome,
		"year": y,
		"month": m,
		"band": str(event.get("band", "")),
	}
	_inbox_rows().append(row)
	var title := card_title(event)
	var who := str(c.name)
	if GameState.has_method("add_lineage_event"):
		GameState.add_lineage_event(Locale.t("life_auto_log", [title, who, outcome]))
	return row


## Unread auto-resolved results (read-only cards).
static func inbox() -> Array:
	return _inbox_rows().duplicate()


static func inbox_for(cid: String) -> Array:
	var out: Array = []
	for item in _inbox_rows():
		if str(item.get("cid", "")) == cid:
			out.append(item)
	return out


static func ack(cid: String, event_id: String) -> void:
	var kept: Array = []
	var dropped := false
	for item in _inbox_rows():
		if not dropped and str(item.get("cid", "")) == cid and str(item.get("id", "")) == event_id:
			dropped = true
			continue
		kept.append(item)
	GameState.house_mods["life_inbox"] = kept


## First unread inbox result for this person in a band (heir rivalry succession).
static func pending_band(cid: String, band: String) -> Dictionary:
	for item in _inbox_rows():
		if str(item.get("cid", "")) != cid:
			continue
		var eid := str(item.get("id", ""))
		var event := find(eid)
		var b := str(item.get("band", ""))
		if b == "":
			b = str(event.get("band", ""))
		if b != band:
			continue
		var out := event.duplicate(true)
		out["cid"] = cid
		out["outcome"] = str(item.get("outcome", ""))
		out["side"] = str(item.get("side", ""))
		out["resolved"] = true
		return out
	# Legacy: unfinished choice still in life_pending — auto-resolve then return.
	for item in _pending_rows():
		if str(item.get("cid", "")) != cid:
			continue
		var event2 := find(str(item.get("id", "")))
		if str(event2.get("band", "")) != band:
			continue
		var row := fire_and_resolve(cid, str(item.get("id", "")))
		if row.is_empty():
			continue
		var out2 := event2.duplicate(true)
		out2["cid"] = cid
		out2["outcome"] = str(row.get("outcome", ""))
		out2["side"] = str(row.get("side", ""))
		out2["resolved"] = true
		return out2
	return {}


static func find(id: String) -> Dictionary:
	for event in events():
		if str(event.get("id", "")) == id:
			return event
	return {}


## Normalized choices: id a/left and b/right, with act + effects (+ optional hint).
## Still used by catalog tests / tooling; player UI no longer presents them.
static func choices(event: Dictionary) -> Array:
	var out: Array = []
	if event.has("left") or event.has("right"):
		for pair in [["a", "left"], ["b", "right"]]:
			var side: Dictionary = event.get(pair[1], {})
			if typeof(side) != TYPE_DICTIONARY or side.is_empty():
				continue
			out.append({
				"id": pair[0],
				"side": pair[1],
				"act": str(side.get("act", "")),
				"hint": str(side.get("hint", "")),
				"effects": side.get("effects", []),
			})
		return out
	# Legacy lines/options schema
	for opt in event.get("options", []):
		if typeof(opt) != TYPE_DICTIONARY:
			continue
		var label := ""
		for row in opt.get("lines", []):
			label = str(row.get("text", ""))
			break
		out.append({
			"id": str(opt.get("id", "")),
			"side": str(opt.get("id", "")),
			"act": label,
			"hint": "",
			"effects": opt.get("effects", []),
		})
	return out


static func card_title(event: Dictionary) -> String:
	var t := str(event.get("title", ""))
	if t != "":
		return t
	for row in event.get("lines", []):
		return str(row.get("text", ""))
	return ""


static func card_body(event: Dictionary) -> String:
	var b := str(event.get("body", ""))
	if b != "":
		return b
	var lines: PackedStringArray = PackedStringArray()
	for row in event.get("lines", []):
		lines.append(str(row.get("text", "")))
	return "\n".join(lines)


static func choice_label(choice: Dictionary) -> String:
	var act := str(choice.get("act", ""))
	var hint := str(choice.get("hint", ""))
	if hint == "":
		return act
	return "%s（%s）" % [act, hint]


## Manual resolve (tests / legacy). Prefer fire_and_resolve for gameplay.
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
	var oid := str(option_id)
	var side := ""
	match oid:
		"a", "left":
			side = "left"
		"b", "right":
			side = "right"
		_:
			side = oid
	if event.has("left") or event.has("right"):
		var row: Dictionary = event.get(side, {})
		if typeof(row) == TYPE_DICTIONARY and not row.is_empty():
			return {"id": oid, "effects": row.get("effects", []), "act": str(row.get("act", ""))}
		return {}
	for opt in event.get("options", []):
		if str(opt.get("id", "")) == oid:
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


static func _inbox_rows() -> Array:
	var raw = GameState.house_mods.get("life_inbox", null)
	if typeof(raw) != TYPE_ARRAY:
		raw = []
		GameState.house_mods["life_inbox"] = raw
	return raw


## Old saves may still hold unresolved A/B rows — settle them with the seed.
static func _drain_legacy_pending() -> void:
	var rows: Array = _pending_rows().duplicate()
	if rows.is_empty():
		return
	for item in rows:
		var cid := str(item.get("cid", ""))
		var eid := str(item.get("id", ""))
		if cid == "" or eid == "":
			_drop_pending(cid, eid)
			continue
		fire_and_resolve(cid, eid)


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


## Test helper: clear cached JSON so suite reloads after rewrites.
static func reload_for_tests() -> void:
	_doc = {}
	_load()
