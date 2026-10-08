class_name CKFestivals
extends RefCounted
## CMP-05. Five festivals a year. Spring and harvest already settle in Calendar.
## This bus subscriber records all five and settles the three new ones on demand.
## The October muster does not open a battle; the arena rules wait on BTL-11.

const DATA_PATH := "res://data/festivals.json"

static var _rows: Array = []
static var fired: Dictionary = {}
static var _installed := false

static func install() -> void:
	if _installed:
		return
	_installed = true
	_load()
	Calendar.register("world", Callable(CKFestivals, "on_month"), 15)

static func reset_counts() -> void:
	fired = {}

static func rows() -> Array:
	if _rows.is_empty():
		_load()
	return _rows

static func _load() -> void:
	_rows = []
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var list = parsed.get("festivals", [])
	if typeof(list) == TYPE_ARRAY:
		_rows = list

static func row_for_month(month: int) -> Dictionary:
	for row in rows():
		if int(row.get("month", 0)) == month:
			return row
	return {}

static func on_month(ctx: Dictionary) -> void:
	var row := row_for_month(int(ctx.get("month", 0)))
	if row.is_empty():
		return
	var id := str(row.get("id", ""))
	fired[id] = int(fired.get(id, 0)) + 1
	if bool(row.get("settled_elsewhere", false)):
		return
	var evs: Array = ctx.get("events", [])
	evs.append({
		"type": "festival",
		"id": id,
		"text": Locale.t(str(row.get("name_key", id))),
	})

## Player-facing consequence. The month tick does not call this, so a scripted century keeps its silver.
static func play(host, id: String) -> Dictionary:
	match id:
		"barter":
			if int(host.food) < 8:
				return {"ok": false, "msg": Locale.t("festival_barter_short")}
			host.food -= 8
			host.silver += 6
			host.log_event(Locale.t("festival_barter_done"))
			return {"ok": true, "silver": 6, "food": -8}
		"tourney":
			host.add_rep("ashland", 2)
			host.log_event(Locale.t("festival_tourney_purse"))
			return {"ok": true, "battle": false, "rep": 2, "waiting": "BTL-11"}
		"memorial":
			var left := int(host.house_mods.get("wound_months", 0))
			if left > 0:
				host.house_mods["wound_months"] = left - 1
			var elder = null
			var stele: Array = host.house_mods.get("stele", [])
			if typeof(stele) != TYPE_ARRAY:
				stele = []
			for c in host.characters.values():
				if c == null:
					continue
				if not c.alive and c.id not in stele:
					stele.append(c.id)
				elif c.alive and (elder == null or int(c.age) > int(elder.age)):
					elder = c
			host.house_mods["stele"] = stele
			if elder != null:
				host.house_mods["life_prayer_id"] = elder.id
				host.house_mods["life_prayer_years"] = int(host.house_mods.get("life_prayer_years", 0)) + 1
			host.log_event(Locale.t("festival_memorial_done"))
			host.add_lineage_event(Locale.t("festival_memorial_stele"))
			return {
				"ok": true,
				"wound_months": int(host.house_mods.get("wound_months", 0)),
				"stele": stele.size(),
				"life_prayer_years": int(host.house_mods.get("life_prayer_years", 0)),
			}
		_:
			return {"ok": true, "id": id}
