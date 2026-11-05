class_name BattleCombatSfx
extends RefCounted
## 战棋反馈音层整链：选中/确认/命中/暴击/击破/胜/负 可辨事件钩，与 RematchJuice 同拍。
## 音量分层 UI 轻 / 命中中 / 结算重；走既有 AudioBus（UI / SFX）。禁单独换 BGM、禁无钩堆 wav。

const META_LAST := "m_combat_sfx"
const HALF_BEAT_MSEC := 250
const LOG_CAP := 64

## UI light / hit mid / settle heavy (dB into Sfx.play_vol).
const VOL_SELECT := -12.0
const VOL_CONFIRM := -10.0
const VOL_HIT := -6.0
const VOL_CRIT := -4.0
const VOL_KILL := -2.0
const VOL_MISS := -8.0
const VOL_WIN := -1.0
const VOL_LOSE := -1.0

static var _log: Array = []


static func clear_log() -> void:
	_log.clear()


static func play_log() -> Array:
	return _log.duplicate(true)


static func events_seen() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for row in _log:
		if row is Dictionary:
			out.append(str((row as Dictionary).get("event", "")))
	return out


static func last_for(event: String) -> Dictionary:
	var want := event
	for i in range(_log.size() - 1, -1, -1):
		var row = _log[i]
		if row is Dictionary and str((row as Dictionary).get("event", "")) == want:
			return (row as Dictionary).duplicate(true)
	return {}


static func volume_for(event: String) -> float:
	match event:
		"select":
			return VOL_SELECT
		"confirm_move", "confirm_attack":
			return VOL_CONFIRM
		"hit":
			return VOL_HIT
		"crit":
			return VOL_CRIT
		"kill":
			return VOL_KILL
		"miss":
			return VOL_MISS
		"win", "lose":
			return VOL_WIN if event == "win" else VOL_LOSE
		_:
			return VOL_HIT


static func sfx_id_for(event: String) -> String:
	match event:
		"select":
			return "ui_click"
		"confirm_move", "confirm_attack":
			return "ui_confirm"
		"hit":
			return "hit"
		"crit":
			return "crit"
		"kill":
			return "drum_thump"
		"miss":
			return "miss"
		"win":
			return "win"
		"lose":
			return "lose"
		_:
			return "hit"


static func layer_for(event: String) -> String:
	match event:
		"select", "confirm_move", "confirm_attack":
			return "ui"
		"hit", "crit", "miss":
			return "hit"
		"kill", "win", "lose":
			return "settle"
		_:
			return "hit"


static func bus_for_event(event: String) -> String:
	var id := sfx_id_for(event)
	if Sfx != null and Sfx.has_method("bus_for"):
		return str(Sfx.bus_for(id))
	if id.begins_with("ui_"):
		return "UI"
	return "SFX"


## Emit one distinguishable combat SFX event; records play log for suite.
static func emit(event: String, host = null, extra: Dictionary = {}) -> Dictionary:
	var id := sfx_id_for(event)
	var vol := volume_for(event)
	var layer := layer_for(event)
	var bus := bus_for_event(event)
	var msec := Time.get_ticks_msec()
	if Sfx != null and Sfx.has_method("play_vol"):
		Sfx.play_vol(id, vol)
	var row: Dictionary = {
		"event": event,
		"id": id,
		"vol": vol,
		"layer": layer,
		"bus": bus,
		"msec": msec,
	}
	for k in extra.keys():
		row[k] = extra[k]
	_log.append(row)
	while _log.size() > LOG_CAP:
		_log.pop_front()
	if host != null:
		host.set_meta(META_LAST, row.duplicate(true))
	return row


static func on_select(host) -> Dictionary:
	return emit("select", host)


static func on_confirm(host, kind: String) -> Dictionary:
	var event := "confirm_move" if kind == "move" else "confirm_attack"
	return emit(event, host, {"confirm": kind})


## Same call site as BattleRematchJuice.after_attack_hit — juice + SFX share one msec window.
static func on_settle(host, kind: String) -> Dictionary:
	var event := "hit"
	match kind:
		"kill":
			event = "kill"
		"crit":
			event = "crit"
		"miss":
			event = "miss"
		"hit":
			event = "hit"
		_:
			event = "hit"
	var row := emit(event, host, {"settle_kind": kind})
	# Co-stamp juice meta age so suite can prove ≤ half-beat desync.
	if host != null and host.has_meta(BattleRematchJuice.META_HIT):
		var juice: Dictionary = host.get_meta(BattleRematchJuice.META_HIT)
		var juice_msec := int(juice.get("msec", row["msec"]))
		row["juice_msec"] = juice_msec
		row["desync_msec"] = int(row["msec"]) - juice_msec
		host.set_meta(META_LAST, row.duplicate(true))
		# Keep log row in sync with stamped meta.
		if not _log.is_empty():
			_log[_log.size() - 1] = row.duplicate(true)
	return row


static func on_result(host, win: bool) -> Dictionary:
	return emit("win" if win else "lose", host, {"win": win})


static func assert_layers_ordered() -> String:
	if VOL_SELECT >= VOL_HIT:
		return "UI select must be quieter than hit"
	if VOL_CONFIRM >= VOL_HIT:
		return "UI confirm must be quieter than hit"
	if VOL_HIT >= VOL_KILL:
		return "hit must be quieter than kill/settle"
	if VOL_CRIT >= VOL_KILL:
		return "crit must be quieter than kill"
	if VOL_KILL > VOL_WIN:
		return "kill should not exceed win settle weight"
	return ""


static func within_half_beat(sfx_msec: int, juice_msec: int) -> bool:
	return absi(sfx_msec - juice_msec) <= HALF_BEAT_MSEC
