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
	for id in data.get("year_one", []) + data.get("always", []):
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
	for id in data.get("year_one", []) + data.get("always", []):
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
		if bool(row.get("death", false)) and _someone_died():
			return true
		var flag := str(row.get("flag", ""))
		if flag != "" and _flag(flag):
			return true
	return false


## P0-IA-01 contract. Never fails: unknown entries come back locked with an empty reason.
## {"open": bool, "locked": bool, "reason": String, "link": String}
## link "mainline" means the lock lifts by playing the main line ("带我去" opens the next chapter).
static func state(entry: String) -> Dictionary:
	if allows(entry):
		return {"open": true, "locked": false, "reason": "", "link": ""}
	var row := _row_for(entry)
	if row.is_empty():
		return {"open": false, "locked": true, "reason": "", "link": ""}
	if bool(row.get("heir", false)):
		return {"open": false, "locked": true, "reason": Locale.t("ux_lock_heir"), "link": ""}
	if bool(row.get("death", false)):
		return {"open": false, "locked": true, "reason": Locale.t("ux_lock_death"), "link": ""}
	var flag := str(row.get("flag", ""))
	return {"open": false, "locked": true, "reason": lock_reason(flag), "link": "mainline" if _is_story_flag(flag) else ""}

static func lock_reason(flag: String) -> String:
	if flag == "chapter0_done" or flag == "hub_open":
		return Locale.t("ux_lock_ch0")
	if flag == "battle_done":
		return Locale.t("ux_lock_battle")
	if _is_story_flag(flag):
		var cid := flag.trim_suffix("_fought")
		var era := int(cid.substr(1, 1))
		var num := int(cid.substr(3, 2))
		var digits := Locale.t("ux_era_digits")
		var era_txt := digits.substr(clampi(era, 0, 9), 1) if digits.length() >= 10 else str(era)
		return Locale.t("ux_lock_chapter") % [era_txt, num, _chapter_title(cid)]
	return Locale.t("ux_lock_generic")

static func _is_story_flag(flag: String) -> bool:
	return flag == "chapter0_done" or (flag.begins_with("e") and flag.ends_with("_fought") and flag.length() == 12)

static var _titles: Dictionary = {}

static func _chapter_title(cid: String) -> String:
	if _titles.is_empty():
		var path := "res://data/story/campaign_v92.json"
		if FileAccess.file_exists(path):
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(d) == TYPE_DICTIONARY:
				for ch in d.get("chapters", []):
					if typeof(ch) == TYPE_DICTIONARY:
						_titles[str(ch.get("id", ""))] = str(ch.get("title", ""))
	return str(_titles.get(cid, cid))

static func _row_for(entry: String) -> Dictionary:
	for row in load_data().get("unlocks", []):
		if typeof(row) == TYPE_DICTIONARY and entry in row.get("entries", []):
			return row
	return {}

## Every flag the table depends on, for the "each flag is set somewhere" test.
static func flags() -> Array:
	var out: Array = []
	for row in load_data().get("unlocks", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("flag", "")) != "":
			out.append(str(row.get("flag", "")))
	return out

static func _someone_died() -> bool:
	for c in GameState.characters.values():
		if c != null and not c.alive:
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
