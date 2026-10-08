class_name UnlockSchedule
extends RefCounted
## NAR-05：城堡入口按剧情旗标渐进打开。第 1 年、尚无旗标时只留六扇门。
## CKTodoCenter.is_unlocked 读取 allows()。灯引和百科从同一份 tutorials.json 注册。

const PATH := "res://data/story/tutorials.json"

static var _data: Dictionary = {}


static func load_data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_data = parsed
	return _data


static func known_entries() -> Array:
	var data := load_data()
	var seen := {}
	var out: Array = []
	for id in data.get("year_one", []):
		var key := str(id)
		if key != "" and not seen.has(key):
			seen[key] = true
			out.append(key)
	for row in data.get("unlocks", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		for id in row.get("entries", []):
			var key := str(id)
			if key != "" and not seen.has(key):
				seen[key] = true
				out.append(key)
	return out


static func allows(entry: String) -> bool:
	var data := load_data()
	if not known_entries().has(entry):
		return false
	for id in data.get("year_one", []):
		if str(id) == entry:
			return true
	for row in data.get("unlocks", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var hit := false
		for id in row.get("entries", []):
			if str(id) == entry:
				hit = true
				break
		if not hit:
			continue
		if bool(row.get("heir", false)) and _heir_present():
			return true
		var flag := str(row.get("flag", ""))
		if flag != "" and _flag(flag):
			return true
	return false


static func open_count() -> int:
	var n := 0
	for id in known_entries():
		if allows(str(id)):
			n += 1
	return n


static func install() -> void:
	var data := load_data()
	for system in data.get("systems", []):
		if typeof(system) != TYPE_DICTIONARY:
			continue
		var sid := str(system.get("id", ""))
		if sid == "":
			continue
		CKHelpCodex.register_entry({
			"id": "nar05_" + sid,
			"title_text": _line(str(system.get("title_key", "")), sid),
			"body_text": _line(str(system.get("body_key", "")), ""),
		})
		var tail := str(system.get("scene_tail", ""))
		for step in system.get("steps", []):
			if typeof(step) != TYPE_DICTIONARY:
				continue
			var tip_id := str(step.get("id", ""))
			if tip_id == "":
				continue
			CKTips.register({
				"id": tip_id,
				"scene_tail": tail,
				"anchor": "",
				"text": _line(str(step.get("text_key", "")), ""),
			})


static func system_ids() -> Array:
	var out: Array = []
	for system in load_data().get("systems", []):
		if typeof(system) == TYPE_DICTIONARY and str(system.get("id", "")) != "":
			out.append(str(system.get("id", "")))
	return out


static func _flag(key: String) -> bool:
	return GameState.flag(key)


static func _heir_present() -> bool:
	for c in GameState.characters.values():
		if c == null or not c.alive:
			continue
		if typeof(c.parent_ids) == TYPE_ARRAY and not c.parent_ids.is_empty():
			return true
	return false


static func _line(key: String, fallback: String) -> String:
	if key == "":
		return fallback
	var text := Locale.t(key)
	if text == key:
		return fallback
	return text
