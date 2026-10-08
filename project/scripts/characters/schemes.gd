class_name CKSchemes
extends RefCounted
## Rival-house schemes. One house per nation, tied to that nation's living court.
## Kinds: proposal, probe, seat, poach, frame. Embassy counter is CKSchemes.counter_scheme (CMP-03 calls it).

const DATA_PATH := "res://data/rival_houses.json"
const KINDS := ["proposal", "probe", "seat", "poach", "frame"]
const KIND_ZH := {
	"proposal": "提亲",
	"probe": "刺探伪胤",
	"seat": "争座",
	"poach": "挖角",
	"frame": "构陷",
}
const DELTAS := {
	"proposal": -2,
	"probe": -4,
	"seat": -6,
	"poach": -5,
	"frame": -8,
}
const OPENING := {
	"hostile": -40,
	"wary": -10,
	"neutral": 20,
	"cordial": 50,
	"sworn": 80,
}

static var _doc: Dictionary = {}

static func doc() -> Dictionary:
	if not _doc.is_empty():
		return _doc
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			_doc = parsed
	return _doc

static func houses() -> Array:
	return doc().get("houses", [])

static func house(id: String) -> Dictionary:
	for h in houses():
		if str(h.get("id", "")) == id:
			return h
	return {}

static func band_of(value: int) -> String:
	if value >= 70:
		return "sworn"
	if value >= 40:
		return "cordial"
	if value >= 10:
		return "neutral"
	if value >= -20:
		return "wary"
	return "hostile"

static func band_zh(band: String) -> String:
	return {
		"hostile": "敌对",
		"wary": "对峙",
		"neutral": "中立",
		"cordial": "并席",
		"sworn": "共烛",
	}.get(band, band)

static func opening_relation(id: String) -> int:
	return int(OPENING.get(str(house(id).get("stance", "neutral")), 20))

static func _index(nid: String) -> int:
	var ids: Array = CKBloodline.nation_ids()
	var i := ids.find(nid)
	return i if i >= 0 else 0

static func fires(nid: String, year: int) -> bool:
	if year <= 0:
		return false
	return posmod(year, 10) == posmod(_index(nid), 10)

static func kind_for(house_row: Dictionary, nid: String, year: int) -> String:
	if str(house_row.get("crisis_name", "")) != "":
		return "seat"
	var cycle := ["proposal", "probe", "poach", "frame", "seat"]
	return str(cycle[posmod(year + _index(nid), cycle.size())])

static func line_zh(nid: String, kind: String, year: int) -> String:
	var nm := str(house(nid).get("name", nid))
	var nat := str(CKBloodline.nation(nid).get("name", nid))
	return "第%d年 %s对%s发起%s。" % [year, nm, nat, str(KIND_ZH.get(kind, kind))]

## Append this year's scheme onto the court house. Does not touch the court log or the rumor list.
static func record_year(court_house: Dictionary, nid: String, year: int) -> Dictionary:
	if not fires(nid, year):
		return {}
	if not court_house.has("relation"):
		court_house["relation"] = opening_relation(nid)
	var kind := kind_for(court_house, nid, year)
	var delta := int(DELTAS.get(kind, -3))
	var event := {
		"year": year,
		"house": nid,
		"kind": kind,
		"kind_zh": str(KIND_ZH.get(kind, kind)),
		"relation_delta": delta,
		"foiled": false,
		"text": line_zh(nid, kind, year),
	}
	var schemes: Array = court_house.get("schemes", []) if typeof(court_house.get("schemes")) == TYPE_ARRAY else []
	schemes.append(event)
	if schemes.size() > 24:
		schemes = schemes.slice(schemes.size() - 24)
	court_house["schemes"] = schemes
	court_house["relation"] = clampi(int(court_house.get("relation", 0)) + delta, -100, 100)
	court_house["relation_band"] = band_of(int(court_house["relation"]))
	return event

## CMP-03 embassy calls this. The scheme is marked foiled and the relation hit becomes a small recovery.
static func counter_scheme(event: Dictionary) -> Dictionary:
	var out := event.duplicate(true)
	out["foiled"] = true
	out["counter"] = "embassy"
	out["undo"] = int(event.get("relation_delta", 0))
	out["relation_delta"] = 4
	out["text"] = str(event.get("text", "")) + "使馆把这步图谋挡了回去。"
	return out

static func apply_counter(court_house: Dictionary, event: Dictionary) -> Dictionary:
	var fixed := counter_scheme(event)
	var was := int(event.get("relation_delta", 0))
	court_house["relation"] = clampi(int(court_house.get("relation", opening_relation(str(event.get("house", ""))))) - was + int(fixed["relation_delta"]), -100, 100)
	court_house["relation_band"] = band_of(int(court_house["relation"]))
	var schemes: Array = court_house.get("schemes", []) if typeof(court_house.get("schemes")) == TYPE_ARRAY else []
	schemes.append(fixed)
	court_house["schemes"] = schemes
	return fixed

static func latest(court_house: Dictionary) -> Dictionary:
	var schemes: Array = court_house.get("schemes", []) if typeof(court_house.get("schemes")) == TYPE_ARRAY else []
	if schemes.is_empty():
		return {}
	var last = schemes[schemes.size() - 1]
	return last if typeof(last) == TYPE_DICTIONARY else {}
