class_name Endings
extends RefCounted
## NAR-09: one substantial ending from the dynasty already on GameState.
## The only ambition call is CKAmbitions.generation_probe(), and only when that
## script exists. This file does not write silver, food, or the campaign RNG.

const DATA := "res://data/story/endings.json"
const AMBITION_SCRIPT := "res://scripts/characters/ambitions.gd"
const KEY_COMPANIONS := ["pingmei", "qiaowai", "ceju"]
const ROYAL_WEIGHT := 0.5
const PRESTIGE_REP := 55
const TITLE_REP := 30
const SHRINE_FAITH := 3
const DOCTRINE_MONTHS := 12
const LEDGER_HOLDINGS := 2
const LEDGER_SILVER := 500

static var _doc: Dictionary = {}


static func resolve() -> Dictionary:
	var axes := measure()
	var ending := _ending(_pick(axes))
	var lines := _lines(ending, axes)
	var title_key := str(ending.get("title_key", ""))
	return {
		"id": str(ending.get("id", "")),
		"title_key": title_key,
		"title": Locale.t(title_key),
		"axes": axes,
		"lines": lines,
	}


static func ids() -> Array:
	var out: Array = []
	for ending in _endings():
		out.append(str(ending.get("id", "")))
	return out


static func measure() -> Dictionary:
	return {
		"generation_closed": _probe(),
		"sign": _sign(),
		"married_house": _married_house(),
		"prestige": _prestige(),
		"faith": _faith(),
		"holdings": GameState.unlocked_holdings_count(),
		"silver": int(GameState.silver),
		"companions": _companion_count(),
	}


static func _pick(axes: Dictionary) -> String:
	if bool(axes.get("sign", false)):
		return "end_sign"
	if str(axes.get("married_house", "")) != "":
		return "end_marry"
	if bool(axes.get("prestige", false)) and bool(axes.get("faith", false)):
		return "end_rite"
	if int(axes.get("holdings", 0)) >= LEDGER_HOLDINGS and int(axes.get("silver", 0)) >= LEDGER_SILVER:
		return "end_ledger"
	if int(axes.get("companions", 0)) >= 2:
		return "end_people"
	return "end_empty"


static func _probe() -> bool:
	if not FileAccess.file_exists(AMBITION_SCRIPT):
		return _probe_mark()
	var script = load(AMBITION_SCRIPT)
	if script == null:
		return _probe_mark()
	return bool(script.call("generation_probe"))


static func _probe_mark() -> bool:
	var leader := GameState.get_leader()
	if leader != null and str(GameState.house_mods.get("dyn_gen_done", "")) == leader.id:
		return true
	return str(GameState.house_mods.get("dyn_done", "")) != ""


static func _sign() -> bool:
	for c in GameState.characters.values():
		if c == null or not c.alive or not _house_blood(c):
			continue
		if _carries_royal(c):
			return true
	return false


static func _married_house() -> String:
	var fallback := ""
	for c in GameState.characters.values():
		if c == null or not c.alive or not _house_blood(c) or str(c.spouse_id) == "":
			continue
		var spouse: CKCharacter = GameState.characters.get(c.spouse_id)
		if spouse == null or not spouse.alive or _house_blood(spouse):
			continue
		if not _carries_royal(spouse):
			continue
		var house := _house_label(spouse)
		if house == "":
			continue
		if c.is_leader:
			return house
		fallback = house
	return fallback


static func _prestige() -> bool:
	var best := 0
	for realm in GameState.reputation.keys():
		best = maxi(best, int(GameState.reputation[realm]))
	if best >= PRESTIGE_REP:
		return true
	var leader := GameState.get_leader()
	return leader != null and leader.rank_index() >= 2 and best >= TITLE_REP


static func _faith() -> bool:
	if GameState.building_level("shrine") >= SHRINE_FAITH:
		return true
	var doctrine := str(GameState.house_mods.get("doctrine", ""))
	return doctrine != "" and GameState.doctrine_months >= DOCTRINE_MONTHS


static func _companion_count() -> int:
	var n := 0
	for key in KEY_COMPANIONS:
		if _companion_alive(str(key)):
			n += 1
	return n


static func _companion_alive(key: String) -> bool:
	for c in GameState.characters.values():
		if c == null or not c.alive or not c.in_roster or c.retired:
			continue
		if str(c.cast_key) == key:
			return true
	return false


static func _house_blood(c: CKCharacter) -> bool:
	if c.is_leader:
		return true
	return c.parent_ids.size() > 0


static func _carries_royal(c: CKCharacter) -> bool:
	if CKBloodline.royal_nations(c).size() > 0:
		return true
	for key in c.blood_mix.keys():
		if CKBloodline.tier_of(str(key)) == "royal" and float(c.blood_mix[key]) >= ROYAL_WEIGHT:
			return true
	return false


static func _house_label(c: CKCharacter) -> String:
	var best_id := ""
	var best_w := -1.0
	for key in c.blood_mix.keys():
		var weight := float(c.blood_mix[key])
		if CKBloodline.tier_of(str(key)) != "royal" or weight <= best_w:
			continue
		best_w = weight
		best_id = str(key)
	if best_id != "":
		var row: Dictionary = CKBloodline.line(best_id)
		var house := str(row.get("house", ""))
		if house != "":
			return house
		var named := str(row.get("name", ""))
		return named if named != "" else best_id
	var nations: Array = CKBloodline.royal_nations(c)
	if nations.is_empty():
		return ""
	var nation: Dictionary = CKBloodline.nation(str(nations[0]))
	var label := str(nation.get("name", ""))
	return label if label != "" else str(nations[0])


static func _lines(ending: Dictionary, axes: Dictionary) -> Array:
	var out: Array = []
	var beats: Array = []
	for beat in ending.get("beats", []):
		beats.append(beat)
	var echoes = _doc.get("echoes", []) if not _doc.is_empty() else []
	if typeof(echoes) == TYPE_DICTIONARY:
		beats.append(echoes)
	for beat in beats:
		if typeof(beat) != TYPE_DICTIONARY or not _when_ok(beat.get("when", {}), axes):
			continue
		for line in beat.get("lines", []):
			if typeof(line) != TYPE_DICTIONARY or not _when_ok(line.get("when", {}), axes):
				continue
			out.append({
				"id": str(line.get("id", "")),
				"speaker": str(line.get("speaker", "")),
				"text": _fill(str(line.get("text", "")), axes),
			})
	return out


static func _when_ok(spec, axes: Dictionary) -> bool:
	if typeof(spec) != TYPE_DICTIONARY or (spec as Dictionary).is_empty():
		return true
	var cond: Dictionary = spec
	if cond.has("ambition") and bool(cond["ambition"]) != bool(axes.get("generation_closed", false)):
		return false
	if cond.has("companion") and not _companion_alive(str(cond["companion"])):
		return false
	if cond.has("flag") and not GameState.flag(str(cond["flag"])):
		return false
	return true


static func _fill(text: String, axes: Dictionary) -> String:
	return text.replace("{house}", str(axes.get("married_house", ""))).replace("{surname}", GameState.surname).replace("{silver}", str(int(axes.get("silver", 0)))).replace("{holdings}", str(int(axes.get("holdings", 0))))


static func _ending(id: String) -> Dictionary:
	for ending in _endings():
		if str(ending.get("id", "")) == id:
			return ending
	return {}


static func _endings() -> Array:
	_load()
	var rows = _doc.get("endings", [])
	return rows if typeof(rows) == TYPE_ARRAY else []


static func _load() -> void:
	if not _doc.is_empty():
		return
	if not FileAccess.file_exists(DATA):
		_doc = {"endings": []}
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_doc = parsed if typeof(parsed) == TYPE_DICTIONARY else {"endings": []}
