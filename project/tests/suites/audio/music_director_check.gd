extends Node
## AUD-01：曲目元数据、交叉淡入、旧 API、字节级重跑。

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL music director: ", err)
		get_tree().quit(1)
	else:
		print("MUSIC DIRECTOR PASS")
		get_tree().quit(0)

func _run() -> String:
	if Music == null or Calendar == null:
		return "autoloads not ready"
	var meta_err := _check_library()
	if meta_err != "":
		return meta_err
	var api_err := _check_api()
	if api_err != "":
		return api_err
	var fade_err := _check_crossfade()
	if fade_err != "":
		return fade_err
	return _check_repro()

func _check_library() -> String:
	var dir := DirAccess.open("res://assets/music")
	if dir == null:
		return "music dir missing"
	var oggs: Array = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".ogg"):
			oggs.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	oggs.sort()
	if oggs.size() < 12:
		return "need >= 12 ogg, got %d" % oggs.size()
	for file_name in oggs:
		var path := "res://assets/music/%s" % file_name
		var info := _probe(path)
		if info.is_empty():
			return "unreadable %s" % file_name
		if int(info["channels"]) != 2 or int(info["rate"]) != 44100:
			return "%s not stereo 44.1k: %s" % [file_name, str(info)]
		if float(info["seconds"]) < 60.0:
			return "%s shorter than 60s (%.2f)" % [file_name, float(info["seconds"])]
	for bus_name in ["Music", "SFX", "Ambience", "UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			return "bus missing " + bus_name
	if Music.crossfade_sec() > 1.5:
		return "crossfade longer than 1.5s"
	return ""

func _check_api() -> String:
	Calendar.month = 1
	Calendar.year = 1
	Music.play_hub()
	if Music.current_state() != "hub" or Music.current_track() != "mus_castle_winter":
		return "play_hub winter got %s %s" % [Music.current_state(), Music.current_track()]
	Calendar.month = 7
	Music.play_castle()
	if Music.current_state() != "castle" or Music.current_track() != "mus_castle_summer":
		return "play_castle summer got %s" % Music.current_track()
	Calendar.year = 50
	Music.play_battle()
	if Music.current_state() != "player_turn" or Music.current_track() != "mus_battle_era3":
		return "play_battle era got %s" % Music.current_track()
	Music.play_player_turn(5)
	if Music.current_track() != "mus_battle_era5":
		return "era override"
	Music.play_enemy_turn()
	if Music.current_track() != "mus_battle_enemy":
		return "enemy"
	Music.play_boss()
	if Music.current_track() != "mus_battle_boss":
		return "boss"
	Music.play_menu()
	if Music.current_track() != "mus_title":
		return "menu"
	Music.play_atlas("lantern")
	if Music.current_track() != "mus_atlas_lantern":
		return "atlas nation"
	Music.play_atlas("")
	if Music.current_track() != "mus_atlas":
		return "atlas default"
	Music.play_city("irongorge")
	if Music.current_track() != "mus_city_irongorge":
		return "city"
	Music.play_victory()
	if Music.current_track() != "mus_victory":
		return "victory"
	Music.play_defeat()
	if Music.current_track() != "mus_defeat":
		return "defeat"
	for moment in ["birth", "inheritance", "marriage", "funeral"]:
		Music.play_dynasty(moment)
		if Music.current_state() != moment or Music.current_track() != "mus_%s" % moment:
			return "dynasty " + moment
	Music.play_menu()
	Music.advance(2.0)
	var before := Music.front_linear()
	Music.set_dialogue_active(true)
	Music.advance(0.0)
	if Music.front_linear() > before * 0.7:
		return "duck did not lower music"
	Music.set_dialogue_active(false)
	Music.advance(0.0)
	Music.play_player_turn(1)
	Music.advance(2.0)
	Music.set_tension(0.0)
	Music.advance(0.0)
	if Music.tension_linear() > 0.02:
		return "tension leaked"
	Music.set_tension(1.0)
	Music.advance(0.0)
	var tension := Music.tension_linear()
	if tension < 0.2 or tension > 0.7:
		return "tension gain %s" % tension
	if Music.front_linear() < 0.9:
		return "bed dropped when tension raised"
	Music.stop()
	if Music.current_state() != "":
		return "stop"
	Music.enabled = false
	Music.play_menu()
	if Music.current_state() != "":
		return "enabled gate"
	Music.enabled = true
	return ""

func _check_crossfade() -> String:
	Music.play_menu()
	Music.advance(0.0)
	Music.play_victory()
	var saw_overlap := false
	for _i in 40:
		Music.advance(0.04)
		var gains: Array = Music.player_linears()
		var hot := 0
		var audible := 0
		for g in gains:
			if float(g) > 0.95:
				hot += 1
			if float(g) > 0.2:
				audible += 1
		if hot > 1:
			return "two tracks at full gain"
		if audible >= 2:
			saw_overlap = true
	if not saw_overlap:
		return "crossfade never overlapped"
	Music.advance(2.0)
	var after: Array = Music.player_linears()
	var still := 0
	for g in after:
		if float(g) > 0.9:
			still += 1
	if still != 1:
		return "fade did not settle"
	Music.stop()
	return ""

func _check_repro() -> String:
	var project := ProjectSettings.globalize_path("res://")
	var script := project.path_join("../tools/audio/compose_v92.py")
	var output: Array = []
	var code := OS.execute("python3", [script, "--verify"], output, true)
	var text := ""
	for line in output:
		text += str(line)
	if code != 0 or text.find("COMPOSE VERIFY PASS") < 0:
		return "byte verify failed (%d) %s" % [code, text.right(500)]
	return ""

func _probe(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data := f.get_buffer(f.get_length())
	f.close()
	if data.size() < 64 or data.slice(0, 4).get_string_from_ascii() != "OggS":
		return {}
	var nseg := int(data[26])
	var header := 27 + nseg
	var body_len := 0
	for i in nseg:
		body_len += int(data[27 + i])
	if header + body_len > data.size():
		return {}
	var body := data.slice(header, header + body_len)
	if body.size() < 16 or int(body[0]) != 1 or body.slice(1, 7).get_string_from_ascii() != "vorbis":
		return {}
	var channels := int(body[11])
	var rate := int(body.decode_u32(12))
	var i := 0
	var granule := 0
	while i + 27 <= data.size():
		if data.slice(i, i + 4).get_string_from_ascii() != "OggS":
			break
		var ns := int(data[i + 26])
		var h := 27 + ns
		var bl := 0
		for s in ns:
			bl += int(data[i + 27 + s])
		granule = int(data.decode_s64(i + 6))
		i += h + bl
	if rate <= 0:
		return {}
	return {"channels": channels, "rate": rate, "seconds": float(granule) / float(rate)}
