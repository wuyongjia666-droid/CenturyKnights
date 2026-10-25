class_name CKStoryState
extends RefCounted
## Chapter beats and chapter JSON. Beats live in one dictionary; chapter files load on demand.

## legacy_index space: 0 = ch0, 1–234 retired chapters, 101–399 volume chapters (eN_MM -> N*100+MM).
## Content-season cs* chapters keep a string cursor in season_beats (keyed by chapter id).
## Their JSON still carries legacy_index 401+ as a marker; those ints are NOT stored in beats[].
## Saves written before v9.2.1 only carry 0–234; missing keys load as the default beat.
const CHAPTER_COUNT := 400
const LEGACY_COUNT := 235
static var load_count: int = 0

var beats: Dictionary = {}
## chapter_id (e.g. "cs08_01") -> last beat id. Owned resume for content seasons.
var season_beats: Dictionary = {}
var flags: Dictionary = {}
var _cache: Dictionary = {}

func _init() -> void:
	reset()

func reset() -> void:
	beats = {}
	for i in CHAPTER_COUNT:
		beats[str(i)] = default_beat(i)
	season_beats = {}
	flags = {}

func default_beat(id: int) -> String:
	return "%d.0" % id

func beat(id: int) -> String:
	return str(beats.get(str(id), default_beat(id)))

func set_beat(id: int, value: String) -> void:
	if id < 0 or id >= CHAPTER_COUNT:
		return
	beats[str(id)] = value

func season_beat(chapter_id: String) -> String:
	return str(season_beats.get(chapter_id, ""))

func set_season_beat(chapter_id: String, value: String) -> void:
	if chapter_id == "":
		return
	if value == "":
		season_beats.erase(chapter_id)
		return
	season_beats[chapter_id] = value

func export_season_beats() -> Dictionary:
	return season_beats.duplicate(true)

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
		_import_season_beats(block.get("season_beats", {}))
	else:
		_import_legacy_beats(data)
		_import_season_beats({})
	var raw_flags = data.get("chapter0_flags", {})
	if typeof(raw_flags) == TYPE_DICTIONARY:
		flags = (raw_flags as Dictionary).duplicate(true)
	else:
		flags = {}

func _import_season_beats(raw) -> void:
	season_beats = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for k in (raw as Dictionary).keys():
		var cid := str(k)
		var bid := str((raw as Dictionary).get(k, ""))
		if cid != "" and bid != "":
			season_beats[cid] = bid

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
