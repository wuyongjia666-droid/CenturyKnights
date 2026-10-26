class_name BattleBanter
extends RefCounted
## Theme-keyed battle log lines + SFX. Extracted from battle_controller so the
## 3000-line gate stays green; host only calls play(self, kind).

static var _idx: int = 0
static var _kill: int = 0
static var _pack: Dictionary = {}
static var _played: Dictionary = {}


static func reset() -> void:
	_idx = 0
	_kill = 0
	_pack = {}
	_played = {}


static func table() -> Dictionary:
	if not _pack.is_empty():
		return _pack
	var f := FileAccess.open("res://data/battle_banter.json", FileAccess.READ)
	if f == null:
		return _pack
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_pack = parsed
	return _pack


static func _play_sfx(method: String) -> void:
	if method == "" or not Sfx.has_method(method):
		return
	Sfx.call(method)


static func theme_of(host) -> String:
	if host == null:
		return ""
	if host.has_method("_map_theme"):
		return str(host._map_theme())
	var mid := str(host.get("map_id"))
	return str(BattleMaps.get_map(mid).get("theme", ""))


static func play(host, kind: String) -> void:
	if host == null:
		return
	var theme := theme_of(host)
	var themes: Dictionary = table().get("themes", {})
	if not themes.has(theme):
		return
	var key := theme + kind + str(_idx if kind == "turn" else _kill)
	if _played.has(key):
		return
	var pack: Dictionary = themes[theme]
	var pool: Array = pack.get(kind, [])
	if pool.is_empty():
		return
	var line := ""
	if kind == "turn":
		line = str(pool[_idx % pool.size()])
		_idx += 1
	elif kind == "kill":
		line = str(pool[_kill % pool.size()])
		_kill += 1
		_play_sfx(str(pack.get("kill_sfx", "")))
	else:
		line = str(pool[0] if _idx == 0 else pool[mini(1, pool.size() - 1)])
		_play_sfx(str(pack.get("start_sfx", "")))
	_played[key] = true
	if host.has_method("_log"):
		host._log(line)


static func played_count() -> int:
	return _played.size()


static func capture() -> Dictionary:
	return {
		"banter_idx": _idx,
		"banter_kill": _kill,
		"banter_played": _played.duplicate(true),
	}


static func restore(snap: Dictionary) -> void:
	_idx = int(snap.get("banter_idx", 0))
	_kill = int(snap.get("banter_kill", 0))
	_played = (snap.get("banter_played", {}) as Dictionary).duplicate(true)

