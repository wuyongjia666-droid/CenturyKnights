class_name BattleMaps
extends RefCounted

static var _maps: Dictionary = {}

static func ensure_loaded() -> void:
	if not _maps.is_empty():
		return
	if GameState.data_maps.is_empty():
		return
	_maps = GameState.data_maps.get("maps", {})

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
