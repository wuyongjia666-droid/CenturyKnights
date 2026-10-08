extends Node
## 确认 locale 读到 S09 的 audio.csv，曲名不会原样吐回 key。

func _ready() -> void:
	await get_tree().process_frame
	var samples := {
		"audio_mus_title": "主菜单",
		"audio_mus_castle_winter": "冬静",
		"audio_mus_battle_boss": "首领",
		"audio_mus_city_southzephyr": "南泽邦",
	}
	for key in samples.keys():
		var text := Locale.t(key)
		if text == key or text.find(str(samples[key])) < 0:
			print("FAIL locale audio: %s -> %s" % [key, text])
			get_tree().quit(1)
			return
	print("LOCALE_AUDIO PASS")
	get_tree().quit(0)
