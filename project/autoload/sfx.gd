extends Node
## 原创程序 WAV 音效（无授权曲库）

const WEAPONS := ["sword", "lance", "axe", "bow", "spell"]
const TERRAINS := ["plain", "forest", "hill", "water", "bridge", "fort"]
const BIOMES := ["fort", "urban", "ford", "hill", "fog", "nightcamp", "snow", "pass", "harbor", "plain", "archive", "forge", "shrine", "marsh"]
const UI_SET := ["ui_hover", "ui_back", "ui_deny", "ui_open", "ui_close"]

var _players: Dictionary = {}
var _players2d: Dictionary = {}  # id -> AudioStreamPlayer2D
var enabled: bool = true
var _listener_origin: Vector2 = Vector2.ZERO
var _groups: Dictionary = {}
var _last_pick: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _ambience: AudioStreamPlayer
var _ambience_id: String = ""

func _ready() -> void:
	_rng.randomize()
	for id in ["ui_click", "ui_confirm", "hit", "miss", "win", "lose", "move", "turn", "fanfare", "lineage_chime", "skill", "deal", "crit", "heal", "escort_whip", "cart_rattle", "escort_horn", "wave_splash", "paper_tear", "anvil_clang", "lamp_flicker", "grain_pour", "frost_crackle", "bamboo_creak", "post_horn", "bell_toll", "rain_patter", "ink_drip", "bee_buzz", "flute_tone", "shadow_whoosh", "salt_crunch", "dye_splash", "drum_thump", "incense_hiss", "tide_wash", "porcelain_chime", "zoc_pulse", "zoc_leave"]:
		var p := AudioStreamPlayer.new()
		p.name = id
		var path = "res://assets/sfx/%s.wav" % id
		if ResourceLoader.exists(path):
			p.stream = load(path)
		p.bus = bus_for(id)
		p.volume_db = -6.0
		add_child(p)
		_players[id] = p
	_load_generated()
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "AmbienceBed"
	_ambience.bus = bus_for("amb_bed")
	add_child(_ambience)

func _load_generated() -> void:
	for weapon in WEAPONS:
		var ids: Array = []
		for i in 3:
			var id := "hit_%s_%d" % [weapon, i]
			_ensure_player(id)
			ids.append(id)
		_groups[weapon] = ids
	for terrain in TERRAINS:
		var ids: Array = []
		for i in 2:
			var id := "step_%s_%d" % [terrain, i]
			_ensure_player(id)
			ids.append(id)
		_groups["step_" + terrain] = ids
	for id in UI_SET:
		_ensure_player(id)

func _ensure_player(id: String) -> void:
	if _players.has(id):
		return
	var p := AudioStreamPlayer.new()
	p.name = id
	var wav := "res://assets/sfx/%s.wav" % id
	var ogg := "res://assets/sfx/%s.ogg" % id
	if ResourceLoader.exists(wav):
		p.stream = load(wav)
	elif ResourceLoader.exists(ogg):
		p.stream = load(ogg)
	p.bus = bus_for(id)
	p.volume_db = -6.0
	add_child(p)
	_players[id] = p

func bus_for(id: String) -> String:
	var bus_name := "SFX"
	if id.begins_with("ui_"):
		bus_name = "UI"
	elif id.begins_with("amb_"):
		bus_name = "Ambience"
	if AudioServer.get_bus_index(bus_name) < 0:
		return "Master"
	return bus_name

func pick_variant(group: String) -> String:
	var ids: Array = _groups.get(group, [])
	if ids.is_empty():
		return ""
	var last := str(_last_pick.get(group, ""))
	var pool: Array = []
	for id in ids:
		if str(id) != last:
			pool.append(id)
	if pool.is_empty():
		pool = ids.duplicate()
	var pick := str(pool[_rng.randi() % pool.size()])
	_last_pick[group] = pick
	return pick

func next_pitch() -> float:
	return _rng.randf_range(0.96, 1.05)

func play_weapon(weapon: String) -> void:
	var id := pick_variant(weapon)
	if id == "":
		play("hit")
		return
	_play_pitched(id)

func play_attack(atk_type: String) -> void:
	var weapon := "sword"
	if atk_type == "ranged":
		weapon = "bow"
	elif atk_type == "magic":
		weapon = "spell"
	play_weapon(weapon)

func play_footstep(terrain: String) -> void:
	var id := pick_variant("step_" + terrain)
	if id == "":
		play("move")
		return
	_play_pitched(id)

func play_ambience(biome: String) -> void:
	if not enabled:
		return
	if not BIOMES.has(biome):
		stop_ambience()
		return
	var id := "amb_" + biome
	var path := "res://assets/sfx/%s.ogg" % id
	if not ResourceLoader.exists(path):
		stop_ambience()
		return
	if _ambience_id == id and _ambience.playing:
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_ambience.stream = stream
	_ambience.bus = bus_for(id)
	_ambience.volume_db = -10.0
	_ambience_id = id
	_ambience.play()

func stop_ambience() -> void:
	_ambience_id = ""
	if _ambience != null:
		_ambience.stop()

func _play_pitched(id: String) -> void:
	if not enabled:
		return
	var p: AudioStreamPlayer = _players.get(id)
	if p == null or p.stream == null:
		return
	p.pitch_scale = next_pitch()
	p.volume_db = -6.0
	p.play()

func play(id: String) -> void:
	play_vol(id, -6.0)


func set_listener_origin(origin: Vector2) -> void:
	_listener_origin = origin
	ensure_listener2d()

func ensure_listener2d() -> void:
	if get_node_or_null("ZoCListener") != null:
		var L: AudioListener2D = get_node("ZoCListener")
		L.position = Vector2.ZERO
		L.make_current()
		return
	var listener := AudioListener2D.new()
	listener.name = "ZoCListener"
	add_child(listener)
	listener.make_current()

func play_spatial(id: String, world_pos: Vector2, volume_db: float = -6.0, max_dist: float = 420.0) -> void:
	## Active/web-feel: 距离衰减 + 左右 pan（AudioStreamPlayer2D）
	if not enabled:
		return
	var p2: AudioStreamPlayer2D = _players2d.get(id)
	if p2 == null:
		# lazy create from 1D stream
		var p1: AudioStreamPlayer = _players.get(id)
		if p1 == null or p1.stream == null:
			play_vol(id, volume_db)
			return
		p2 = AudioStreamPlayer2D.new()
		p2.name = id + "_2d"
		p2.stream = p1.stream
		p2.bus = bus_for(id)
		p2.max_distance = max_dist
		p2.attenuation = 1.2
		add_child(p2)
		_players2d[id] = p2
	# 相对听者偏移 → 左右 pan（无 Camera2D 的 Control 战棋也成立）
	p2.position = world_pos - _listener_origin
	p2.volume_db = volume_db
	p2.max_distance = max_dist
	p2.play()

func play_vol(id: String, volume_db: float = -6.0) -> void:
	if not enabled:
		return
	var p: AudioStreamPlayer = _players.get(id)
	if p and p.stream:
		p.volume_db = volume_db
		p.play()

func click() -> void:
	play("ui_click")

func confirm() -> void:
	play("ui_confirm")

func hit() -> void:
	play("hit")

func miss() -> void:
	play("miss")

func win() -> void:
	play("win")

func lose() -> void:
	play("lose")

func move() -> void:
	play("move")

func turn() -> void:
	play("turn")

func fanfare() -> void:
	play("fanfare")

func lineage_chime() -> void:
	play("lineage_chime")

func skill() -> void:
	play("skill")

func deal() -> void:
	play("deal")

func crit() -> void:
	play("crit")

func heal() -> void:
	play("heal")

func escort_whip() -> void:
	play("escort_whip")

func cart_rattle() -> void:
	play("cart_rattle")

func escort_horn() -> void:
	play("escort_horn")

func wave_splash() -> void:
	play("wave_splash")

func paper_tear() -> void:
	play("paper_tear")

func anvil_clang() -> void:
	play("anvil_clang")

func lamp_flicker() -> void:
	play("lamp_flicker")

func grain_pour() -> void:
	play("grain_pour")

func frost_crackle() -> void:
	play("frost_crackle")

func bamboo_creak() -> void:
	play("bamboo_creak")

func post_horn() -> void:
	play("post_horn")

func bell_toll() -> void:
	play("bell_toll")

func rain_patter() -> void:
	play("rain_patter")

func ink_drip() -> void:
	play("ink_drip")

func bee_buzz() -> void:
	play("bee_buzz")

func flute_tone() -> void:
	play("flute_tone")

func shadow_whoosh() -> void:
	play("shadow_whoosh")

func salt_crunch() -> void:
	play("salt_crunch")

func dye_splash() -> void:
	play("dye_splash")

func drum_thump() -> void:
	play("drum_thump")

func incense_hiss() -> void:
	play("incense_hiss")

func tide_wash() -> void:
	play("tide_wash")

func porcelain_chime() -> void:
	play("porcelain_chime")

func zoc_pulse(volume_db: float = -4.0) -> void:
	play_vol("zoc_pulse", volume_db)

func zoc_leave(volume_db: float = -6.0) -> void:
	play_vol("zoc_leave", volume_db)
