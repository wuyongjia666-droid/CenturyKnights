class_name CKStoryState
extends RefCounted
## Chapter beats and chapter JSON. Beats live in one dictionary; chapter files load on demand.

const CHAPTER_COUNT := 235
static var load_count: int = 0

var beats: Dictionary = {}
var flags: Dictionary = {}
var _cache: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	beats = {}
	for i in CHAPTER_COUNT:
		beats[str(i)] = default_beat(i)
	flags = {}

func default_beat(id: int) -> String:
	return "%d.0" % id

func beat(id: int) -> String:
	return str(beats.get(str(id), default_beat(id)))

func set_beat(id: int, value: String) -> void:
	if id < 0 or id >= CHAPTER_COUNT:
		return
	beats[str(id)] = value

func export_beats() -> Dictionary:
	var out := {}
	for i in CHAPTER_COUNT:
		out[str(i)] = beat(i)
	return out

func current_chapter() -> int:
	var current := 0
	for i in CHAPTER_COUNT:
		if beat(i) != default_beat(i):
			current = i
	return current

func unlocked_count() -> int:
	return current_chapter() + 1

func chapter_data(id: int) -> Dictionary:
	if id < 0 or id >= CHAPTER_COUNT:
		return {}
	var key := str(id)
	if _cache.has(key):
		return _cache[key]
	var parsed := _parse_chapter(id)
	_cache[key] = parsed
	return parsed

func set_chapter_data(id: int, value) -> void:
	if id < 0 or id >= CHAPTER_COUNT:
		return
	if typeof(value) == TYPE_DICTIONARY:
		_cache[str(id)] = value
	else:
		_cache[str(id)] = {}

func import_save(data: Dictionary) -> void:
	var block = data.get("story", null)
	if typeof(block) == TYPE_DICTIONARY and typeof((block as Dictionary).get("beats", null)) == TYPE_DICTIONARY:
		_import_beats(block["beats"])
	else:
		_import_legacy_beats(data)
	var raw_flags = data.get("chapter0_flags", {})
	if typeof(raw_flags) == TYPE_DICTIONARY:
		flags = (raw_flags as Dictionary).duplicate(true)
	else:
		flags = {}

func _import_beats(raw: Dictionary) -> void:
	beats = {}
	for i in CHAPTER_COUNT:
		var key := str(i)
		if raw.has(key):
			beats[key] = str(raw[key])
		elif raw.has(i):
			beats[key] = str(raw[i])
		else:
			beats[key] = default_beat(i)

func _import_legacy_beats(data: Dictionary) -> void:
	beats = {}
	for i in CHAPTER_COUNT:
		beats[str(i)] = str(data.get("chapter%d_beat" % i, default_beat(i)))

func _parse_chapter(id: int) -> Dictionary:
	var path := "res://data/chapter%d.json" % id
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	load_count += 1
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
