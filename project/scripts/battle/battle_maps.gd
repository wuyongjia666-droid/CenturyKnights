class_name BattleMaps
extends RefCounted

static var _maps: Dictionary = {}
static var _ready := false

static func ensure_loaded() -> void:
	if _ready:
		return
	_ready = true
	if not GameState.data_maps.is_empty():
		_maps = GameState.data_maps.get("maps", {})
	if _maps.is_empty():
		_maps = _read_json("res://data/maps.json").get("maps", {})
	_merge_side_files()

## Narrative (and tests) drop extra battle maps in res://data/maps/*.json.
## A file is either {"maps": {id: map}} or one map object with an "id" field.
## Ids already defined in maps.json stay owned by that file.
static func _merge_side_files() -> void:
	var dir := DirAccess.open("res://data/maps")
	if dir == null:
		return
	var names: PackedStringArray = dir.get_files()
	var ordered: Array = []
	for fn in names:
		ordered.append(str(fn))
	ordered.sort()
	for fn in ordered:
		if not str(fn).ends_with(".json"):
			continue
		var parsed: Dictionary = _read_json("res://data/maps/%s" % str(fn))
		var batch: Dictionary = {}
		if typeof(parsed.get("maps", null)) == TYPE_DICTIONARY:
			batch = parsed["maps"]
		elif str(parsed.get("id", "")) != "":
			batch = {str(parsed["id"]): parsed}
		for id in batch.keys():
			var mid := str(id)
			if _maps.has(mid):
				continue
			_maps[mid] = batch[id]

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

## v8.7: overworld encounters register generated maps (biome base map + regional foes) at runtime
static func register_map(map_id: String, m: Dictionary) -> void:
	ensure_loaded()
	_maps[map_id] = m

static func get_map(map_id: String) -> Dictionary:
	ensure_loaded()
	if _maps.has(map_id):
		return _maps[map_id]
	if _maps.has("ch0_pass"):
		return _maps["ch0_pass"]
	return {}

static func terrain_grid(map_id: String) -> Array:
	var m = get_map(map_id)
	return m.get("terrain", [])

static func size(map_id: String) -> Vector2i:
	var m = get_map(map_id)
	return Vector2i(int(m.get("w", 8)), int(m.get("h", 6)))
