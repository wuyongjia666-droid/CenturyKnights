extends Node
## 音乐导演：交叉淡入、季节/国度/纪元选曲、紧张层、对白压低。
## 曲目由 tools/audio/compose_v92.py 合成，见 assets/music/LICENSES.md。

const CROSSFADE_SEC := 1.2
const DUCK_LINEAR := 0.3981071705534972  # -8 dB
const TENSION_MAX := 0.55

var enabled: bool = true
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _layer: AudioStreamPlayer
var _to: AudioStreamPlayer
var _from: AudioStreamPlayer
var _fade: float = 1.0
var _state: String = ""
var _track: String = ""
var _tension: float = 0.0
var _dialogue: bool = false
var _nation: String = ""
var _era: int = 0
var _cache: Dictionary = {}
var _volumes: Dictionary = {
	"Master": 1.0,
	"Music": 1.0,
	"SFX": 1.0,
	"Ambience": 1.0,
	"UI": 1.0,
}

func _ready() -> void:
	_ensure_buses()
	_a = _make_player("MusicA")
	_b = _make_player("MusicB")
	_layer = _make_player("MusicTension")
	_to = _a
	if not GameState.state_changed.is_connected(_sync_volumes_from_save):
		GameState.state_changed.connect(_sync_volumes_from_save)
	_sync_volumes_from_save()

func set_bus_volume(bus: String, linear: float) -> void:
	var gain := clampf(linear, 0.0, 1.0)
	_volumes[bus] = gain
	_apply_bus(bus, gain)
	if is_instance_valid(GameState) and typeof(GameState.settings) == TYPE_DICTIONARY:
		GameState.settings["audio_bus"] = _volumes.duplicate()

func get_bus_volume(bus: String) -> float:
	return float(_volumes.get(bus, 1.0))

func _apply_bus(bus: String, gain: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	if gain <= 0.0001:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(gain))

func _sync_volumes_from_save() -> void:
	if not is_instance_valid(GameState) or typeof(GameState.settings) != TYPE_DICTIONARY:
		return
	var stored = GameState.settings.get("audio_bus", null)
	if typeof(stored) != TYPE_DICTIONARY:
		return
	for key in stored.keys():
		var bus := str(key)
		var gain := clampf(float(stored[key]), 0.0, 1.0)
		_volumes[bus] = gain
		_apply_bus(bus, gain)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if _fade < 1.0:
		_fade = minf(1.0, _fade + delta / CROSSFADE_SEC)
		if _fade >= 1.0 and _from != null:
			_from.stop()
			_from = null
	_apply_gains()

func play_hub() -> void:
	play_state("hub")

func play_battle() -> void:
	_era = 0
	play_state("player_turn")

func play_castle() -> void:
	play_state("castle")

func play_menu() -> void:
	play_state("menu")

func play_atlas(nation: String = "") -> void:
	_nation = nation
	play_state("atlas")

func play_city(nation: String = "") -> void:
	if nation != "":
		_nation = nation
	play_state("city")

func play_player_turn(era: int = 0) -> void:
	_era = era
	play_state("player_turn")

func play_enemy_turn() -> void:
	play_state("enemy_turn")

func play_boss() -> void:
	play_state("boss")

func play_victory() -> void:
	play_state("victory")

func play_defeat() -> void:
	play_state("defeat")

func play_dynasty(moment: String) -> void:
	play_state(moment)

func set_tension(value: float) -> void:
	_tension = clampf(value, 0.0, 1.0)
	_ensure_layer()
	_apply_gains()

func set_dialogue_active(active: bool) -> void:
	_dialogue = active
	_apply_gains()

func stop() -> void:
	if _a:
		_a.stop()
	if _b:
		_b.stop()
	if _layer:
		_layer.stop()
	_from = null
	_fade = 1.0
	_state = ""
	_track = ""
	_apply_gains()

func play_state(state: String) -> void:
	if not enabled:
		return
	var track := resolve_track(state)
	if track == "":
		return
	if track == _track and _to != null and _to.playing:
		_state = state
		return
	var stream: AudioStream = _load_track(track)
	if stream == null:
		_play_legacy(state)
		return
	var nxt: AudioStreamPlayer = _b if _to == _a else _a
	if _from != null and _from != nxt:
		_from.stop()
	if _to != null and _to.playing and _to != nxt:
		_from = _to
		_fade = 0.0
	else:
		_from = null
		_fade = 1.0
	nxt.stream = stream
	nxt.play()
	_to = nxt
	_state = state
	_track = track
	_ensure_layer()
	_apply_gains()

func resolve_track(state: String) -> String:
	match state:
		"menu":
			return "mus_title"
		"hub", "castle":
			return "mus_castle_%s" % season_from_month(_month())
		"atlas":
			var atlas_id := "mus_atlas_%s" % _nation
			if _nation != "" and _track_exists(atlas_id):
				return atlas_id
			return "mus_atlas"
		"city":
			var nation := _nation if _nation != "" else "ashbanner"
			var city_id := "mus_city_%s" % nation
			if _track_exists(city_id):
				return city_id
			return "mus_city_ashbanner"
		"player_turn":
			return "mus_battle_era%d" % _current_era()
		"enemy_turn":
			return "mus_battle_enemy"
		"boss":
			return "mus_battle_boss"
		"tension":
			return "mus_tension"
		"victory":
			return "mus_victory"
		"defeat":
			return "mus_defeat"
		"birth":
			return "mus_birth"
		"inheritance":
			return "mus_inheritance"
		"marriage":
			return "mus_marriage"
		"funeral":
			return "mus_funeral"
		_:
			return ""

func current_state() -> String:
	return _state

func current_track() -> String:
	return _track

func crossfade_sec() -> float:
	return CROSSFADE_SEC

func player_linears() -> Array:
	return [_lin(_a), _lin(_b)]

func front_linear() -> float:
	return _lin(_to)

func tension_linear() -> float:
	return _lin(_layer)

func season_from_month(month: int) -> String:
	if month >= 3 and month <= 5:
		return "spring"
	if month >= 6 and month <= 8:
		return "summer"
	if month >= 9 and month <= 11:
		return "autumn"
	return "winter"

func era_from_year(year: int) -> int:
	if year <= 20:
		return 1
	if year <= 40:
		return 2
	if year <= 60:
		return 3
	if year <= 80:
		return 4
	return 5

func _current_era() -> int:
	if _era >= 1:
		return clampi(_era, 1, 5)
	return era_from_year(_year())

func _year() -> int:
	if Engine.has_singleton("Calendar") or is_instance_valid(Calendar):
		return int(Calendar.year)
	return 1

func _month() -> int:
	if is_instance_valid(Calendar):
		return int(Calendar.month)
	return 1

func _track_exists(id: String) -> bool:
	return ResourceLoader.exists("res://assets/music/%s.ogg" % id) or FileAccess.file_exists("res://assets/music/%s.ogg" % id)

func _load_track(id: String) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var path := "res://assets/music/%s.ogg" % id
	if not ResourceLoader.exists(path):
		return null
	var stream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_cache[id] = stream
	return stream

func _ensure_layer() -> void:
	if _layer == null:
		return
	if not _tension_state():
		if _layer.playing:
			_layer.stop()
		return
	if _layer.playing:
		return
	var stream = _load_track("mus_tension_layer")
	if stream == null:
		return
	_layer.stream = stream
	_layer.play()

func _tension_state() -> bool:
	return _state in ["player_turn", "enemy_turn", "boss"]

func _apply_gains() -> void:
	if _a == null:
		return
	var duck := DUCK_LINEAR if _dialogue else 1.0
	var g_in := duck
	var g_out := 0.0
	if _from != null and _state != "":
		var t := clampf(_fade, 0.0, 1.0)
		g_out = cos(t * PI * 0.5) * duck
		g_in = sin(t * PI * 0.5) * duck
	if _state == "":
		g_in = 0.0
	_set_lin(_to, g_in)
	if _from != null:
		_set_lin(_from, g_out)
	var idle: AudioStreamPlayer = _b if _to == _a else _a
	if idle != _from:
		_set_lin(idle, 0.0)
	var layer_gain := 0.0
	if _tension_state():
		layer_gain = _tension * TENSION_MAX * duck
	_set_lin(_layer, layer_gain)

func _set_lin(player: AudioStreamPlayer, gain: float) -> void:
	if player == null:
		return
	if gain <= 0.0008:
		player.volume_db = -80.0
	else:
		player.volume_db = linear_to_db(gain)

func _lin(player: AudioStreamPlayer) -> float:
	if player == null:
		return 0.0
	return db_to_linear(player.volume_db)

func _make_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	player.volume_db = -80.0
	add_child(player)
	return player

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX", "Ambience", "UI"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")

func _play_legacy(state: String) -> void:
	var path := "res://assets/sfx/music_hub.wav"
	if state in ["player_turn", "enemy_turn", "boss", "tension"]:
		path = "res://assets/sfx/music_battle.wav"
	elif state in ["castle", "hub"]:
		path = "res://assets/sfx/music_castle.wav"
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = -1
	var nxt: AudioStreamPlayer = _b if _to == _a else _a
	nxt.stream = stream
	nxt.play()
	_to = nxt
	_from = null
	_fade = 1.0
	_state = state
	_track = path
	_apply_gains()
