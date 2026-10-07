extends Node
## 原创程序 WAV 音效（无授权曲库）

var _players: Dictionary = {}
var enabled: bool = true

func _ready() -> void:
	for id in ["ui_click", "ui_confirm", "hit", "miss", "win", "lose", "move", "turn", "fanfare", "lineage_chime", "skill", "deal", "crit", "heal", "escort_whip", "cart_rattle", "escort_horn", "wave_splash", "paper_tear", "anvil_clang", "lamp_flicker", "grain_pour", "frost_crackle", "bamboo_creak", "post_horn", "bell_toll", "rain_patter", "ink_drip", "bee_buzz", "flute_tone", "shadow_whoosh", "salt_crunch", "dye_splash"]:
		var p := AudioStreamPlayer.new()
		p.name = id
		var path = "res://assets/sfx/%s.wav" % id
		if ResourceLoader.exists(path):
			p.stream = load(path)
		p.bus = "Master"
		p.volume_db = -6.0
		add_child(p)
		_players[id] = p

func play(id: String) -> void:
	if not enabled:
		return
	var p: AudioStreamPlayer = _players.get(id)
	if p and p.stream:
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
