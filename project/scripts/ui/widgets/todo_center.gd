class_name CKTodoCenter
extends RefCounted
## v9.2 本月待办：只数真的还没做完的事（提案 4.9）。计数为 0 不出现。

static var _extra: Array = []
static var _mainline_cache: Array = []

static func reset_for_tests() -> void:
	_extra.clear()

static func register(category: String, group: String, label: String, count: int) -> void:
	_extra.append({
		"category": category,
		"group": group,
		"label": label,
		"count": count,
	})

static func is_unlocked(entry: String) -> bool:
	UnlockSchedule.install()
	return UnlockSchedule.allows(entry)

static func narrow_scale(width: float) -> float:
	if width >= 1200.0 or width < 64.0:
		return 1.0
	return width / 1280.0

static func count_for(group_id: String) -> int:
	var n := 0
	for item in snapshot():
		if str(item.get("group", "")) == group_id:
			n += maxi(0, int(item.get("count", 0)))
	return n

static func snapshot() -> Array:
	var rows: Array = []
	_add(rows, "sui_ke", "family", Locale.t("ux_todo_sui_ke"), CKSuiKe.pending_count())
	_add(rows, "life", "family", Locale.t("ux_todo_life"), _life_pending_count())
	_add(rows, "marriage", "family", Locale.t("ux_todo_marriage"), _marriage_count())
	_add(rows, "injured", "military", Locale.t("ux_todo_injured"), _injured_count())
	_add(rows, "quests", "civil", Locale.t("ux_todo_quests"), _quest_urgent())
	_add(rows, "tutor", "military", Locale.t("ux_todo_tutor"), _tutor_need())
	_add(rows, "buildings", "civil", Locale.t("ux_todo_buildings"), _building_finishing())
	_add(rows, "field", "civil", Locale.t("ux_todo_field"), _field_open())
	for extra in _extra:
		if extra is Dictionary and int(extra.get("count", 0)) > 0:
			rows.append((extra as Dictionary).duplicate())
	return rows

static func snapshot_or_empty_label() -> Dictionary:
	var rows := snapshot()
	if rows.is_empty():
		return {"empty": true, "label": Locale.t("ux_todo_none"), "rows": []}
	return {"empty": false, "label": "", "rows": rows}

static func _add(rows: Array, category: String, group: String, label: String, count: int) -> void:
	if count <= 0:
		return
	rows.append(_row(category, group, label, count))

static func _row(category: String, group: String, label: String, count: int) -> Dictionary:
	return {"category": category, "group": group, "label": label, "count": count}

static func _life_pending_count() -> int:
	var raw = GameState.house_mods.get("life_pending", null)
	if typeof(raw) != TYPE_ARRAY:
		return 0
	# Only count entries that already have a UI surface
	var n := 0
	for item in raw:
		if typeof(item) == TYPE_DICTIONARY and bool(item.get("ui", true)):
			n += 1
	return n

static func _marriage_count() -> int:
	var n := 0
	# Vow stuck mid-step
	if int(GameState.house_mods.get("vow_step", 0)) > 0:
		n += 1
	# Retinue seat leaving this month-end
	var ret = GameState.house_mods.get("marriage_retinue", null)
	if typeof(ret) == TYPE_DICTIONARY and bool(ret.get("leave_next", false)):
		n += 1
	return n

static func _injured_count() -> int:
	var n := 0
	var clinic := CKEconomyState.building_level(GameState, "infirmary") >= 1 or int(GameState.herb) > 0
	if not clinic:
		return 0
	for c in GameState.roster():
		if c.injured:
			n += 1
	return n

static func _quest_urgent() -> int:
	var n := 0
	for q in GameState.quests:
		if typeof(q) != TYPE_DICTIONARY:
			continue
		if int(q.get("months_left", 99)) <= 1 and bool(q.get("accepted", true)):
			n += 1
	return n

static func _tutor_need() -> int:
	var n := 0
	for c in GameState.characters.values():
		if c == null or not c.alive:
			continue
		if int(c.age) < 6 or int(c.age) > 15:
			continue
		if c.in_roster:
			continue
		if not CKSuiKe.is_house_child_for_life_queue(c) and not c.is_child:
			continue
		if str(c.blood_meta.get("tutor_id", "")) == "":
			n += 1
	return n

static func _building_finishing() -> int:
	## 已付款、本月落成的升级
	var raw = GameState.house_mods.get("building_due", null)
	if typeof(raw) != TYPE_ARRAY:
		return 0
	var key := "%d-%d" % [Calendar.year, Calendar.month]
	var n := 0
	for row in raw:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("due", "")) == key:
			n += 1
	return n

static func _field_open() -> int:
	var free_kin := 0
	for c in GameState.characters.values():
		if c == null or not c.alive:
			continue
		if int(c.age) < 8:
			continue
		if CKPurse.is_following(GameState, c.id):
			continue
		if str(c.blood_meta.get("estate_job", "")) != "":
			continue
		if bool(c.blood_meta.get("retinue", false)):
			continue
		if CKPurse.is_care_locked(c):
			continue
		if c.in_roster and c.parent_ids.is_empty() and str(c.spouse_id) == "" and not c.is_leader and not c.is_child:
			continue  # hireling
		if c.is_child or (not c.parent_ids.is_empty()) or str(c.spouse_id) != "" or c.is_leader:
			free_kin += 1
	if free_kin <= 0:
		return 0
	var slots := 0
	for hid in GameState.holdings.keys():
		if not CKEconomyState.holding_unlocked(GameState, str(hid)):
			continue
		var cap := CKEconomyState.holding_level(GameState, str(hid))
		var used := 0
		for c2 in GameState.characters.values():
			if c2 != null and str(c2.blood_meta.get("estate_job", "")) == str(hid):
				used += 1
		slots += maxi(0, cap - used)
	return 1 if slots > 0 and free_kin > 0 else 0

static func mainline_rows() -> Array:
	if not _mainline_cache.is_empty():
		return _mainline_cache
	var built: Array = []
	for entry in StoryCatalog.mainline_entries():
		var path := str(entry.get("path", ""))
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = parsed
		var beats: Array = data.get("beats", [])
		var last := ""
		if not beats.is_empty() and typeof(beats[beats.size() - 1]) == TYPE_DICTIONARY:
			last = str((beats[beats.size() - 1] as Dictionary).get("id", ""))
		var id := str(entry.get("id", ""))
		built.append({
			"id": id,
			"title": str(entry.get("title", id)),
			"index": int(data.get("legacy_index", 0)),
			"last_beat": last,
			"era": _era_of(id),
		})
	built.sort_custom(func(a, b): return int(a["index"]) < int(b["index"]))
	_mainline_cache = built
	return _mainline_cache

static func mainline_target() -> Dictionary:
	var rows := mainline_rows()
	var story := _story()
	if rows.is_empty():
		return {"id": "ch0", "title": "", "index": 0, "era": 0, "place": 1, "done": false, "last_beat": ""}
	var place := 1
	for row in rows:
		if not _finished(row, story):
			var out: Dictionary = (row as Dictionary).duplicate()
			out["place"] = place
			out["done"] = false
			if story != null:
				out["story_chapter"] = story.current_chapter()
			return out
		place += 1
	var last: Dictionary = (rows[rows.size() - 1] as Dictionary).duplicate()
	last["place"] = rows.size()
	last["done"] = true
	if story != null:
		last["story_chapter"] = story.current_chapter()
	return last

static func _story() -> CKStoryState:
	return GameState.story as CKStoryState

static func _era_of(id: String) -> int:
	if id.length() >= 2 and id.begins_with("e") and id.substr(1, 1).is_valid_int():
		return int(id.substr(1, 1))
	return 0

static func _finished(row: Dictionary, story: CKStoryState) -> bool:
	if str(row.get("id", "")) == "ch0":
		return GameState.flag("chapter0_done")
	if story == null:
		return false
	var idx := int(row.get("index", 0))
	var beat := story.beat(idx)
	var last := str(row.get("last_beat", ""))
	if last == "" or beat == story.default_beat(idx):
		return false
	return beat == last
