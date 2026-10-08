class_name CKTodoCenter
extends RefCounted
## UX-06：本月待办注册表。各领域用 register() 追加事项，城堡只读 snapshot()。

static var _extra: Array = []

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
