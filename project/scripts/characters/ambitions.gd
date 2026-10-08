class_name CKAmbitions
extends RefCounted
## DYN-02: one data-driven ambition per generation.
## Month hook is a no-op until a leader chooses. Completion stores a stele title
## and a morale note. It does not touch silver, food, traits, roster, or GameState.rng.
## Company stream: after each succession call generation_probe(). It records a title
## only when the current house already meets one offered ambition.

const DATA_PATH := "res://data/ambitions.json"

static var _doc: Dictionary = {}


static func rows() -> Array:
	_load()
	return _doc.get("ambitions", [])


static func row(id: String) -> Dictionary:
	for item in rows():
		if str(item.get("id", "")) == id:
			return item
	return {}


static func on_month(_ctx: Dictionary) -> void:
	var id := str(GameState.house_mods.get("dyn_amb", ""))
	if id != "" and not _already(id) and met(row(id)):
		_complete(id)
	_apply_note()


static func on_banner(heir: CKCharacter) -> void:
	GameState.house_mods["dyn_amb"] = ""
	GameState.house_mods["dyn_offers"] = ""
	GameState.house_mods["dyn_leader"] = heir.id if heir != null else ""


static func open_offer(leader: CKCharacter) -> Array:
	if leader == null:
		return []
	var current := str(GameState.house_mods.get("dyn_amb", ""))
	if current != "":
		return [current]
	var stored := str(GameState.house_mods.get("dyn_offers", ""))
	if stored != "" and str(GameState.house_mods.get("dyn_leader", "")) == leader.id:
		return _split(stored)
	var ids: Array = []
	for item in rows():
		ids.append(str(item.get("id", "")))
	ids.sort()
	if ids.is_empty():
		return []
	var start := absi(hash(leader.id)) % ids.size()
	var picked: PackedStringArray = PackedStringArray()
	var cursor := start
	while picked.size() < mini(3, ids.size()):
		var candidate := str(ids[cursor % ids.size()])
		if not picked.has(candidate):
			picked.append(candidate)
		cursor += 1
	GameState.house_mods["dyn_leader"] = leader.id
	GameState.house_mods["dyn_offers"] = "|".join(picked)
	return _split(str(GameState.house_mods["dyn_offers"]))


static func needs_choice() -> bool:
	var leader := GameState.get_leader()
	if leader == null:
		return false
	if str(GameState.house_mods.get("dyn_amb", "")) != "":
		return false
	if str(GameState.house_mods.get("dyn_gen_done", "")) == leader.id:
		return false
	return open_offer(leader).size() >= 3


static func choose(id: String) -> bool:
	if row(id).is_empty():
		return false
	var leader := GameState.get_leader()
	if leader == null:
		return false
	var offered := open_offer(leader)
	if id not in offered:
		return false
	GameState.house_mods["dyn_amb"] = id
	return true


static func met(spec: Dictionary) -> bool:
	if spec.is_empty():
		return false
	var metric := str(spec.get("metric", ""))
	var need := int(spec.get("min", 1))
	match metric:
		"blood":
			return _blood(str(spec.get("line", "")), float(spec.get("min", 0.5)))
		"lamp":
			return _lamp()
		"spouse_nations":
			return _spouse_nations() >= need
		"academy":
			return int(GameState.house_mods.get("dyn_academy", 0)) >= need
		"masters":
			return _masters(int(spec.get("job_tier", 2)), int(spec.get("level", 3))) >= need
		"children":
			return _children() >= need
		"rank":
			var leader := GameState.get_leader()
			return leader != null and leader.rank_index() >= need
		"year":
			return Calendar.year >= need
		"rep":
			return _rep_at(str(spec.get("realm", "")), str(spec.get("tier", "known")))
		"paths":
			return _paths() >= need
		"roster":
			return _roster() >= need
		"food":
			return GameState.food >= need
		"building":
			return GameState.building_level(str(spec.get("building", ""))) >= need
		"holding":
			return GameState.holding_level(str(spec.get("holding", ""))) >= need
		"trait":
			return _has_trait(str(spec.get("trait", "")))
		"friendly":
			return _friendly() >= need
		_:
			return false


static func note_academy(tier: int) -> void:
	GameState.house_mods["dyn_academy"] = maxi(int(GameState.house_mods.get("dyn_academy", 0)), tier)


static func honor_bonus() -> Dictionary:
	var note := int(GameState.house_mods.get("dyn_honor", 0))
	return {"stele": note, "morale": 1 if note > 0 else 0}


static func generation_probe() -> bool:
	var leader := GameState.get_leader()
	if leader == null:
		return false
	if str(GameState.house_mods.get("dyn_gen_done", "")) == leader.id:
		return true
	if str(GameState.house_mods.get("dyn_amb", "")) == "":
		open_offer(leader)
	for id in open_offer(leader):
		if met(row(str(id))):
			GameState.house_mods["dyn_amb"] = str(id)
			on_month({})
			return str(GameState.house_mods.get("dyn_gen_done", "")) == leader.id
	return false


static func title_of(id: String) -> String:
	return "dyn:" + id


static func _complete(id: String) -> void:
	var leader := GameState.get_leader()
	if leader == null:
		return
	var mark := title_of(id)
	if mark not in leader.honors:
		leader.honors.append(mark)
	GameState.house_mods["dyn_honor"] = int(GameState.house_mods.get("dyn_honor", 0)) + 1
	GameState.house_mods["dyn_amb"] = ""
	GameState.house_mods["dyn_gen_done"] = leader.id
	var done := str(GameState.house_mods.get("dyn_done", ""))
	GameState.house_mods["dyn_done"] = id if done == "" else done + "|" + id
	GameState.add_lineage_event(Locale.t("amb_done_log", [Locale.t("amb_" + id + "_name")]))


static func _apply_note() -> void:
	if int(honor_bonus().get("morale", 0)) <= 0:
		return
	GameState.morale = mini(100, GameState.morale + 1)


static func _already(id: String) -> bool:
	return ("|" + str(GameState.house_mods.get("dyn_done", "")) + "|").contains("|" + id + "|")


static func _blood(line: String, need: float) -> bool:
	for c in GameState.characters.values():
		if c.alive and float(c.blood_mix.get(line, 0.0)) >= need:
			return true
	return false


static func _lamp() -> bool:
	for c in GameState.characters.values():
		if not c.alive:
			continue
		if str(c.blood_meta.get("lamp_seat", "")) != "":
			return true
	return false


static func _spouse_nations() -> int:
	var seen := {}
	for c in GameState.characters.values():
		if not c.alive or str(c.spouse_id) == "":
			continue
		var spouse: CKCharacter = GameState.characters.get(c.spouse_id)
		if spouse == null:
			continue
		var nid := CKBloodline.nation_of_line(spouse.primary_bloodline())
		if nid != "":
			seen[nid] = true
	return seen.size()


static func _masters(tier: int, level: int) -> int:
	var n := 0
	for c in GameState.characters.values():
		if not c.alive or not c.in_roster:
			continue
		if int(GameState.get_job(c.job_id).get("tier", 1)) >= tier and c.level >= level:
			n += 1
	return n


static func _children() -> int:
	var leader := GameState.get_leader()
	if leader == null:
		return 0
	var n := 0
	for cid in leader.children_ids:
		var child: CKCharacter = GameState.characters.get(str(cid))
		if child != null and child.alive:
			n += 1
	return n


static func _rep_at(realm: String, tier: String) -> bool:
	return Lineage.REP_ORDER.find(GameState.get_rep_tier(realm)) >= Lineage.REP_ORDER.find(tier)


static func _paths() -> int:
	var seen := {}
	for cid in GameState.lineage_path.keys():
		var path := str(GameState.lineage_path[cid])
		if path != "":
			seen[path] = true
	return seen.size()


static func _roster() -> int:
	var n := 0
	for c in GameState.characters.values():
		if c.alive and c.in_roster and not c.retired:
			n += 1
	return n


static func _has_trait(trait_id: String) -> bool:
	for c in GameState.characters.values():
		if c.alive and trait_id in c.traits:
			return true
	return false


static func _friendly() -> int:
	var n := 0
	var floor := Lineage.REP_ORDER.find("friendly")
	for realm in GameState.reputation.keys():
		if Lineage.REP_ORDER.find(GameState.get_rep_tier(str(realm))) >= floor:
			n += 1
	return n


static func _split(raw: String) -> Array:
	var out: Array = []
	for part in raw.split("|", false):
		if str(part) != "":
			out.append(str(part))
	return out


static func _load() -> void:
	if not _doc.is_empty():
		return
	if not FileAccess.file_exists(DATA_PATH):
		_doc = {"ambitions": []}
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_doc = parsed if typeof(parsed) == TYPE_DICTIONARY else {"ambitions": []}
