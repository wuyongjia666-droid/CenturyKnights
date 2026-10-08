class_name CKAutosave
extends RefCounted
## Auto slot writes. Month saves are throttled to one per game month.
## Battle and background saves are explicit so a mid-month pause still lands.

static var month_writes: int = 0
static var _last_month: String = ""

static func reset_throttle() -> void:
	month_writes = 0
	_last_month = ""

static func on_month() -> void:
	var stamp := "%d-%d" % [Calendar.year, Calendar.month]
	if stamp == _last_month:
		return
	_last_month = stamp
	if GameState.save_to_slot("auto"):
		month_writes += 1

static func before_battle() -> bool:
	return GameState.save_to_slot("auto")

static func after_battle() -> bool:
	return GameState.save_to_slot("auto")

static func on_background() -> bool:
	return GameState.save_to_slot("auto")
