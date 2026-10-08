class_name CKSaveService
extends RefCounted
## Multi-slot saves: atomic replace, three rotating backups, and a schema chain.
## Slot metadata lives beside the body so a truncated file can still be listed.

const SCHEMA := "v9.2"
const SLOTS := ["manual_0", "manual_1", "manual_2", "auto", "quick"]
const MANUAL_0 := "user://century_knights_save.json"
const CHAIN := ["v8.7", "v8.8", "v9.1", "v9.2"]

static func body_path(slot: String) -> String:
	if slot == "manual_0":
		return MANUAL_0
	return "user://saves/%s.json" % slot

static func meta_path(slot: String) -> String:
	return body_path(slot) + ".meta.json"

static func save_slot(host, slot: String) -> bool:
	if slot not in SLOTS:
		return false
	var data: Dictionary = host.build_save_data()
	var text := JSON.stringify(data)
	if not _atomic_write(body_path(slot), text):
		return false
	var path := body_path(slot)
	var meta: Dictionary = host.save_meta(slot)
	meta["sha256"] = FileAccess.get_sha256(path)
	meta["bytes"] = _file_length(path)
	return _atomic_write(meta_path(slot), JSON.stringify(meta))

static func load_slot(host, slot: String) -> bool:
	if slot not in SLOTS:
		return false
	var found := read_best(slot)
	if not bool(found.get("ok", false)):
		host.save_notice = Locale.t("save_unreadable")
		host.save_backup_used = ""
		return false
	var data: Dictionary = found["data"]
	data = migrate(data)
	var source := str(found.get("source", "primary"))
	if source != "primary":
		host.save_notice = Locale.t("save_corrupt_rollback")
		host.save_backup_used = source
	elif str(data.get("migrated_from", "")) != "" and str(data.get("migrated_from", "")) != SCHEMA:
		host.save_notice = Locale.t("save_migrated", [str(data.get("migrated_from"))])
		host.save_backup_used = ""
	else:
		host.save_notice = ""
		host.save_backup_used = ""
	return host.apply_save_data(data)

static func read_meta(slot: String) -> Dictionary:
	var path := meta_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func read_best(slot: String) -> Dictionary:
	var names := ["primary", "bak1", "bak2", "bak3"]
	var paths := [
		body_path(slot),
		body_path(slot) + ".bak1",
		body_path(slot) + ".bak2",
		body_path(slot) + ".bak3",
	]
	for i in paths.size():
		var parsed = _parse_file(paths[i])
		if typeof(parsed) == TYPE_DICTIONARY and not (parsed as Dictionary).is_empty():
			return {"ok": true, "data": parsed, "source": names[i]}
	return {"ok": false}

static func migrate(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return data
	var schema := _normalize_schema(str(data.get("schema", "")))
	if schema == SCHEMA:
		return data
	var origin := schema
	if schema == "":
		origin = _infer_origin(data)
		schema = "v9.1" if origin == "v9.0" else origin
	if origin == "v9.0":
		data = _migrate_v88_to_v91(data, origin)
		schema = "v9.1"
	if schema not in CHAIN:
		schema = "v8.8"
	data["schema"] = schema
	var guard := 0
	while schema != SCHEMA and guard < CHAIN.size():
		guard += 1
		var idx := CHAIN.find(schema)
		if idx < 0 or idx + 1 >= CHAIN.size():
			break
		var nxt: String = CHAIN[idx + 1]
		if schema == "v8.8":
			data = _migrate_v88_to_v91(data, origin)
		elif schema == "v9.1":
			data = _migrate_v91_to_v92(data)
		data["schema"] = nxt
		schema = nxt
	if origin != "" and origin != SCHEMA:
		data["migrated_from"] = origin
	return data

static func _migrate_v88_to_v91(data: Dictionary, origin: String) -> Dictionary:
	for id in data.get("characters", {}).keys():
		var row: Dictionary = data["characters"][id]
		data["characters"][id] = _migrate_character_row(row)
	for bucket in ["tavern", "marriage"]:
		var arr: Array = data.get(bucket, [])
		for i in arr.size():
			if typeof(arr[i]) == TYPE_DICTIONARY:
				arr[i] = _migrate_character_row(arr[i])
		data[bucket] = arr
	var world: Dictionary = data.get("world_v87", {}) if typeof(data.get("world_v87", {})) == TYPE_DICTIONARY else {}
	if typeof(world.get("royal_courts", {})) != TYPE_DICTIONARY or (world.get("royal_courts", {}) as Dictionary).is_empty():
		if origin in ["v8.7", "v8.8"]:
			world["royal_courts"] = CKCourt.blank_courts(int(data.get("year", 1)) * 17 + 3)
	data["world_v87"] = world
	data["version"] = 1
	return data

static func _migrate_v91_to_v92(data: Dictionary) -> Dictionary:
	if not data.has("play_seconds"):
		data["play_seconds"] = 0
	return data

static func _migrate_character_row(row: Dictionary) -> Dictionary:
	if typeof(row.get("blood_meta")) != TYPE_DICTIONARY:
		row["blood_meta"] = {}
	var meta: Dictionary = row["blood_meta"]
	if not meta.has("verified"):
		meta["verified"] = false
	if not meta.has("verdict"):
		meta["verdict"] = ""
	if typeof(meta.get("rites")) != TYPE_ARRAY:
		meta["rites"] = []
	if str(meta.get("title", "")) == "":
		var rank := str(row.get("rank", "knight"))
		meta["title"] = rank if rank in CKCharacter.RANK_ORDER else "knight"
	if not meta.has("lamp_seat"):
		meta["lamp_seat"] = ""
	row["blood_meta"] = meta
	if str(row.get("age_stage", "")) == "":
		row["age_stage"] = CKGenomePortrait.stage_for_age(int(row.get("age", 20)))
	if typeof(row.get("honors")) != TYPE_ARRAY:
		row["honors"] = []
	if typeof(row.get("genome")) != TYPE_DICTIONARY:
		row["genome"] = {}
	return row

static func _infer_origin(data: Dictionary) -> String:
	var saw_genome := false
	var saw_sig := false
	for id in data.get("characters", {}).keys():
		var row: Dictionary = data["characters"][id]
		if typeof(row.get("genome", {})) == TYPE_DICTIONARY and not (row.get("genome", {}) as Dictionary).is_empty():
			saw_genome = true
			if (row["genome"] as Dictionary).has("sig"):
				saw_sig = true
	if saw_genome and not saw_sig:
		return "v8.8"
	if saw_sig:
		return "v9.0"
	return "v8.7"

static func _normalize_schema(schema: String) -> String:
	if schema == "8.7":
		return "v8.7"
	if schema == "8.8":
		return "v8.8"
	return schema

static func _atomic_write(path: String, text: String) -> bool:
	_ensure_parent(path)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	_rotate_backups(path)
	return _rename(tmp, path)

static func _rotate_backups(path: String) -> void:
	var bak3 := path + ".bak3"
	var bak2 := path + ".bak2"
	var bak1 := path + ".bak1"
	if FileAccess.file_exists(bak3):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bak3))
	if FileAccess.file_exists(bak2):
		_rename(bak2, bak3)
	if FileAccess.file_exists(bak1):
		_rename(bak1, bak2)
	if FileAccess.file_exists(path):
		_rename(path, bak1)

static func _rename(from_path: String, to_path: String) -> bool:
	var src := ProjectSettings.globalize_path(from_path)
	var dst := ProjectSettings.globalize_path(to_path)
	if FileAccess.file_exists(to_path):
		DirAccess.remove_absolute(dst)
	return DirAccess.rename_absolute(src, dst) == OK

static func _ensure_parent(path: String) -> void:
	if path.begins_with("user://saves/"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))

static func _parse_file(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func _file_length(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n
