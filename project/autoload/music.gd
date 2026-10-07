extends Node
## 程序生成 ambient / battle / castle 床（WAV 循环）

var _player: AudioStreamPlayer
var _current: String = ""
var enabled: bool = true

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -14.0
	add_child(_player)

func play_hub() -> void:
	_play("res://assets/sfx/music_hub.wav", -14.0)

func play_battle() -> void:
	_play("res://assets/sfx/music_battle.wav", -11.5)

func play_castle() -> void:
	_play("res://assets/sfx/music_castle.wav", -15.0)

func stop() -> void:
	if _player:
		_player.stop()
	_current = ""

func _play(path: String, vol: float) -> void:
	if not enabled:
		return
	if _current == path and _player.playing:
		return
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = -1
	_player.stream = stream
	_player.volume_db = vol
	_player.play()
	_current = path
