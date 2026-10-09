class_name CKTodoCenter
extends RefCounted
## UX-06：本月待办注册表。各领域用 register() 追加事项，城堡只读 snapshot()。
## 主线读 CKStoryState 的节拍，场景路径交给 StoryCatalog。

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
	# NAR-05 的日程。未知入口仍是锁上的。
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
	var rows: Array = [
		_row("buildings", "civil", Locale.t("ux_todo_buildings"), _building_count()),
		_row("quests", "civil", Locale.t("ux_todo_quests"), GameState.quests.size()),
		_row("marriage", "family", Locale.t("ux_todo_marriage"), GameState.marriage_candidates.size()),
		_row("injured", "military", Locale.t("ux_todo_injured"), _injured_count()),
		_row("festival", "court", Locale.t("ux_todo_festival"), _festival_count()),
		_row("train", "military", Locale.t("ux_todo_train"), _train_count()),
	]
	for extra in _extra:
		if extra is Dictionary:
			rows.append((extra as Dictionary).duplicate())
	return rows

static func _row(category: String, group: String, label: String, count: int) -> Dictionary:
	return {"category": category, "group": group, "label": label, "count": count}

static func _building_count() -> int:
	var n := 0
	for id in GameState.BUILDING_NAMES.keys():
		if GameState.building_level(str(id)) < int(GameState.BUILDING_MAX):
			n += 1
	return n

static func _injured_count() -> int:
	var n := 0
	for c in GameState.roster():
		if c.injured or int(c.hp) < int(c.max_hp):
			n += 1
	return n

static func _festival_count() -> int:
	var m := int(Calendar.month)
	if m == 3 or m == Calendar.SPRING_MONTH or m == Calendar.HARVEST_MONTH or m == 9:
		return 1
	return 0

static func _train_count() -> int:
	if GameState.roster().is_empty():
		return 0
	if int(GameState.silver) < int(GameState.train_cost()):
		return 0
	return 1

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
	# 第零章看旗标。其余章看 CKStoryState 里记下的最后一拍。
	# 序号超出 CHAPTER_COUNT 时 set_beat 不会写入，这一章就留在游标上。
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
