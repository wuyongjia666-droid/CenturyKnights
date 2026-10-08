extends Node
## AUD-03：五路线性音量为 0 时静音，并随 GameState.settings 存档往返。

const BUSES := ["Master", "Music", "SFX", "Ambience", "UI"]

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL volume: ", err)
		get_tree().quit(1)
	else:
		print("VOLUME PASS")
		get_tree().quit(0)

func _run() -> String:
	if Music == null or GameState == null or Sfx == null:
		return "autoloads not ready"
	var route := _check_routing()
	if route != "":
		return route
	var mute := _check_mute()
	if mute != "":
		return mute
	return _check_roundtrip()

func _check_routing() -> String:
	var ui := Sfx.get_node_or_null("ui_click") as AudioStreamPlayer
	if ui == null or ui.bus != "UI":
		return "ui_click bus got %s" % (ui.bus if ui else "missing")
	var confirm := Sfx.get_node_or_null("ui_confirm") as AudioStreamPlayer
	if confirm == null or confirm.bus != "UI":
		return "ui_confirm bus"
	var hit := Sfx.get_node_or_null("hit") as AudioStreamPlayer
	if hit == null or hit.bus != "SFX":
		return "hit bus got %s" % (hit.bus if hit else "missing")
	if Sfx.bus_for("amb_marsh") != "Ambience":
		return "ambience route"
	if Sfx.bus_for("ui_back") != "UI":
		return "ui route"
	if Sfx.bus_for("hit_sword_0") != "SFX":
		return "sfx route"
	Sfx.play_spatial("hit", Vector2(80, 0), -18.0)
	var spatial := Sfx.get_node_or_null("hit_2d") as AudioStreamPlayer2D
	if spatial == null or spatial.bus != "SFX":
		return "spatial bus"
	return ""

func _check_mute() -> String:
	for bus_name in BUSES:
		Music.set_bus_volume(bus_name, 0.0)
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			return "missing bus " + bus_name
		if not AudioServer.is_bus_mute(idx):
			return bus_name + " not muted at 0"
		if Music.get_bus_volume(bus_name) > 0.0001:
			return bus_name + " stored above 0"
	Music.set_bus_volume("Music", 0.35)
	var music_idx := AudioServer.get_bus_index("Music")
	if AudioServer.is_bus_mute(music_idx):
		return "music stayed muted"
	var expected := linear_to_db(0.35)
	if absf(AudioServer.get_bus_volume_db(music_idx) - expected) > 0.05:
		return "music db %.3f vs %.3f" % [AudioServer.get_bus_volume_db(music_idx), expected]
	return ""

func _check_roundtrip() -> String:
	var save_path: String = GameState.SAVE_PATH
	var had := FileAccess.file_exists(save_path)
	var backup := ""
	if had:
		backup = FileAccess.get_file_as_string(save_path)
	Music.set_bus_volume("Master", 0.8)
	Music.set_bus_volume("Music", 0.0)
	Music.set_bus_volume("SFX", 0.25)
	Music.set_bus_volume("Ambience", 0.5)
	Music.set_bus_volume("UI", 0.1)
	if not GameState.save_game():
		_restore_save(save_path, had, backup)
		return "save_game failed"
	Music.set_bus_volume("Master", 1.0)
	Music.set_bus_volume("Music", 1.0)
	Music.set_bus_volume("SFX", 1.0)
	Music.set_bus_volume("Ambience", 1.0)
	Music.set_bus_volume("UI", 1.0)
	if AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")):
		_restore_save(save_path, had, backup)
		return "pre-load music still muted"
	if not GameState.load_game():
		_restore_save(save_path, had, backup)
		return "load_game failed"
	var err := ""
	if not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")):
		err = "music mute lost after load"
	elif absf(Music.get_bus_volume("SFX") - 0.25) > 0.002:
		err = "sfx gain lost %.4f" % Music.get_bus_volume("SFX")
	elif absf(Music.get_bus_volume("Ambience") - 0.5) > 0.002:
		err = "ambience gain lost"
	elif absf(Music.get_bus_volume("UI") - 0.1) > 0.002:
		err = "ui gain lost"
	elif absf(Music.get_bus_volume("Master") - 0.8) > 0.002:
		err = "master gain lost"
	else:
		var stored = GameState.settings.get("audio_bus", null)
		if typeof(stored) != TYPE_DICTIONARY:
			err = "settings.audio_bus missing"
		elif float(stored.get("Music", 1.0)) > 0.002:
			err = "settings music not zero"
	for bus_name in BUSES:
		Music.set_bus_volume(bus_name, 1.0)
	_restore_save(save_path, had, backup)
	return err

func _restore_save(save_path: String, had: bool, backup: String) -> void:
	if had:
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		if f != null:
			f.store_string(backup)
			f.close()
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
