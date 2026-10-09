class_name CKPlayStats
extends RefCounted
## Local play stats for pacing. user:// only. No network.

const PATH := "user://playstats.json"
const EXPORT_PATH := "user://playstats_export.json"
const HUB_MARK := "/hub/"

static var _data: Dictionary = _blank()
static var _tracker: Node = null
static var _burst: int = 0
static var _flush_queued: bool = false
static var _tracking: bool = true
static var _since_save: float = 0.0

static func install(tree: SceneTree) -> void:
	if _tracker != null and is_instance_valid(_tracker):
		return
	_load()
	var node := Tracker.new()
	node.name = "CKPlayStatsTracker"
	_tracker = node
	# Autoload _ready runs while the root is still adopting children.
	tree.root.add_child.call_deferred(node)

static func reset() -> void:
	_data = _blank()
	_burst = 0
	_flush_queued = false
	_since_save = 0.0
	_tracking = true
	var abs_path := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(abs_path)
	var export_abs := ProjectSettings.globalize_path(EXPORT_PATH)
	if FileAccess.file_exists(EXPORT_PATH):
		DirAccess.remove_absolute(export_abs)

static func set_tracking(on: bool) -> void:
	_tracking = on

static func add_time(seconds: float, scene: String) -> void:
	if seconds <= 0.0:
		return
	_data["total_seconds"] = float(_data.get("total_seconds", 0.0)) + seconds
	if scene.find(HUB_MARK) >= 0:
		var hubs: Dictionary = _data.get("hub_seconds", {})
		hubs[scene] = float(hubs.get(scene, 0.0)) + seconds
		_data["hub_seconds"] = hubs
	_since_save += seconds
	if _since_save >= 5.0:
		_save()
		_since_save = 0.0

static func record_battle(turns: int) -> void:
	var n := maxi(1, turns)
	_data["battles"] = int(_data.get("battles", 0)) + 1
	_data["battle_turns"] = int(_data.get("battle_turns", 0)) + n
	_save()

static func note_month() -> void:
	_data["months"] = int(_data.get("months", 0)) + 1
	_burst += 1
	if _flush_queued or _tracker == null or not is_instance_valid(_tracker):
		return
	_flush_queued = true
	_tracker.call_deferred("_flush_skips")

static func flush_skips() -> void:
	_flush_queued = false
	if _burst > 1:
		_data["month_skips"] = int(_data.get("month_skips", 0)) + 1
	_burst = 0
	_save()

static func flush() -> void:
	_save()
	_since_save = 0.0

static func snapshot() -> Dictionary:
	var out: Dictionary = _data.duplicate(true)
	var battles := int(out.get("battles", 0))
	var turns := int(out.get("battle_turns", 0))
	out["battle_turns_avg"] = 0.0 if battles <= 0 else float(turns) / float(battles)
	out["title"] = Locale.t("playstats_title")
	return out

static func export_json() -> String:
	var payload := snapshot()
	var f := FileAccess.open(EXPORT_PATH, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(payload))
	f.flush()
	f.close()
	return EXPORT_PATH

static func _blank() -> Dictionary:
	return {
		"total_seconds": 0.0,
		"hub_seconds": {},
		"battles": 0,
		"battle_turns": 0,
		"months": 0,
		"month_skips": 0,
	}

static func _load() -> void:
	if not FileAccess.file_exists(PATH):
		_data = _blank()
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		_data = _blank()
		return
	_data = _blank()
	var src: Dictionary = parsed
	_data["total_seconds"] = float(src.get("total_seconds", 0.0))
	_data["battles"] = int(src.get("battles", 0))
	_data["battle_turns"] = int(src.get("battle_turns", 0))
	_data["months"] = int(src.get("months", 0))
	_data["month_skips"] = int(src.get("month_skips", 0))
	var hubs = src.get("hub_seconds", {})
	if typeof(hubs) == TYPE_DICTIONARY:
		_data["hub_seconds"] = (hubs as Dictionary).duplicate(true)

static func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_data))
	f.flush()
	f.close()

class Tracker extends Node:
	func _ready() -> void:
		if not Calendar.month_advanced.is_connected(_on_month):
			Calendar.month_advanced.connect(_on_month)
		if not get_tree().node_added.is_connected(_on_node):
			get_tree().node_added.connect(_on_node)
		_scan(get_tree().root)

	func _process(delta: float) -> void:
		if not CKPlayStats._tracking:
			return
		var scene := ""
		var current := get_tree().current_scene
		if current != null:
			scene = str(current.scene_file_path)
		CKPlayStats.add_time(delta, scene)

	func _on_month(_year: int, _month: int, _events: Array) -> void:
		CKPlayStats.note_month()

	func _on_node(node: Node) -> void:
		_watch(node)

	func _flush_skips() -> void:
		CKPlayStats.flush_skips()

	func _scan(node: Node) -> void:
		_watch(node)
		for child in node.get_children():
			_scan(child)

	func _watch(node: Node) -> void:
		if node == null or not node.has_signal("battle_finished"):
			return
		if node.has_meta("ck_playstats_battle"):
			return
		node.set_meta("ck_playstats_battle", true)
		node.battle_finished.connect(_on_battle.bind(node))

	func _on_battle(result: Dictionary, host: Node) -> void:
		var turns := 0
		if result.has("turns"):
			turns = int(result["turns"])
		elif result.has("turn"):
			turns = int(result["turn"])
		elif result.has("round"):
			turns = int(result["round"])
		if turns <= 0 and host != null:
			turns = int(host.get("_round_no"))
		CKPlayStats.record_battle(turns)
