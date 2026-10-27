extends Node
## Hub → 章 → 战后收锋口头 `_wex`。
## S01–S10；插在 `_win4` 后、`mid_lost`（若有）前。不碰 `_bpl`/`_tvx`/`_lop`/`_vop`/`_opn`/`_vex`。
## 禁 EmptyHost / month_echo / 新 season。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"

const ROWS := [
	{"cid": "cs01_01", "beat": "hall", "needle": "锋落定。我去验盏——灯下把回执认完。"},
	{"cid": "cs01_02", "beat": "bridge", "needle": "这一锋补过欠。桥我还过，副页我认。"},
	{"cid": "cs02_01", "beat": "estate", "needle": "锋验过。灯下签婚约，字是我的。"},
	{"cid": "cs02_02", "beat": "bridge", "needle": "锋护过脉。纸我按得，跳我认。"},
	{"cid": "cs03_01", "beat": "bridge", "needle": "锋问过话。拓片归袋，人归桥。"},
	{"cid": "cs03_02", "beat": "bridge", "needle": "锋护过粮。袋我背得，埂我过。"},
	{"cid": "cs03_03", "beat": "bridge", "needle": "锋护过工账。袋我背得，埂我过。"},
	{"cid": "cs04_01", "beat": "bridge", "needle": "锋跟步走完。训条我背得，廊我过。"},
	{"cid": "cs04_02", "beat": "bridge", "needle": "锋护过契。字我签得，廊外不理。"},
	{"cid": "cs04_03", "beat": "bridge", "needle": "锋护过帖。字我签得，廊外不理。堂帖按。"},

	{"cid": "cs05_01", "beat": "bridge", "needle": "锋问过座。空椅我守，纸角我压。"},
	{"cid": "cs05_02", "beat": "bridge", "needle": "锋护过链。扣我锁得，阶下不问。"},
	{"cid": "cs05_03", "beat": "bridge", "needle": "锋护过帖。字我签得，廊外不理。庭帖按。"},
	{"cid": "cs06_03", "beat": "bridge", "needle": "锋护过帖。字我签得，廊外不理。圈帖按。"},
	{"cid": "cs07_03", "beat": "bridge", "needle": "锋护过帖。字我签得，廊外不理。印帖按。"},
	{"cid": "cs08_03", "beat": "bridge", "needle": "锋护过帖。字我签得，廊外不理。香帖按。"},
	{"cid": "cs09_03", "beat": "bridge", "needle": "锋护过帖。字我签得，廊外不理。香帖按。"},
	{"cid": "cs06_01", "beat": "bridge", "needle": "锋跟圈走完。墙牌我挂得，场我认。"},
	{"cid": "cs06_02", "beat": "bridge", "needle": "锋再走一圈。牌还挂着，我还在场。"},
	{"cid": "cs07_01", "beat": "bridge", "needle": "锋不问代嘴。仪典我自己应。"},
	{"cid": "cs07_02", "beat": "bridge", "needle": "锋再清一次。仪典仍我应，不问旁人。"},
	{"cid": "cs08_01", "beat": "bridge", "needle": "锋拦过抢。祖祠我跪得，香我守。"},
	{"cid": "cs08_02", "beat": "bridge", "needle": "锋护过碑。拓我按得，阴面我收。"},
	{"cid": "cs09_01", "beat": "bridge", "needle": "锋问明白。血我认自己的，名我担。"},
	{"cid": "cs09_02", "beat": "bridge", "needle": "锋再问一次。血仍我的，巾我收。"},
	{"cid": "cs10_01", "beat": "bridge", "needle": "锋验过场。印我盖得，框我认。"},
	{"cid": "cs10_02", "beat": "bridge", "needle": "锋再验场。印我复盖，谱我收。"},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_battle_settle_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON BATTLE SETTLE CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_plates()
	if err != "":
		return err
	err = await _hub_entry()
	if err != "":
		return err
	for row in ROWS:
		err = await _wex_leg(row)
		if err != "":
			return err
	return ""


func _plate_id(cid: String, n: int) -> String:
	return "%s_wex%d" % [cid.replace("_", ""), n]


func _chapter(cid: String):
	var path := "res://data/story/chapters/%s.json" % cid
	if not FileAccess.file_exists(path):
		return "missing %s" % cid
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return "parse %s" % cid
	return data


func _hanzi(text: String) -> int:
	var n := 0
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 0x4E00 and c <= 0x9FFF:
			n += 1
	return n


func _beat_named(data: Dictionary, beat_id: String):
	for beat in data.get("beats", []):
		if str(beat.get("id", "")) == beat_id:
			return beat
	return null


func _static_plates() -> String:
	if StoryCatalog.content_season_entries().size() != ROWS.size():
		return "catalog %d" % StoryCatalog.content_season_entries().size()
	var seen := {}
	for row in ROWS:
		var err := _static_one(row, seen)
		if err != "":
			return err
	print("OK static battle-settle plates ×%d" % ROWS.size())
	return ""


func _static_one(row: Dictionary, seen: Dictionary) -> String:
	var cid := str(row["cid"])
	var data = _chapter(cid)
	if typeof(data) == TYPE_STRING:
		return str(data)
	if str(data.get("return_scene", "")) != HUB:
		return "%s return_scene" % cid
	var body := FileAccess.get_file_as_string("res://data/story/chapters/%s.json" % cid)
	if body.find("EmptyHost") >= 0 or body.find("month_echo") >= 0:
		return "%s residue" % cid
	var beat = _beat_named(data, str(row["beat"]))
	if beat == null:
		return "%s no beat %s" % [cid, str(row["beat"])]
	var err := _static_plate_lines(cid, beat, str(row["needle"]))
	if err != "":
		return err
	return _static_unique(data, cid, seen)


func _fought_flag(cid: String) -> String:
	var season := cid.substr(2, 2)
	return "cs%s_mid_fought" % season


func _static_plate_lines(cid: String, beat, needle: String) -> String:
	var want := {}
	for n in range(1, 7):
		want[_plate_id(cid, n)] = n
	var found := 0
	var err := ""
	var got_needle := false
	var last_win := -1
	var first_wex := -1
	var idx := 0
	var fought := _fought_flag(cid)
	for line in beat.get("lines", []):
		if err != "":
			break
		var lid := str(line.get("id", ""))
		var text := str(line.get("text", ""))
		if lid.ends_with("_win4"):
			last_win = idx
		if text == needle:
			got_needle = true
		if want.has(lid):
			if first_wex < 0:
				first_wex = idx
			var gate = line.get("when", null)
			if typeof(gate) != TYPE_DICTIONARY or str(gate.get("flag", "")) != fought:
				err = "%s plate missing fought when %s" % [cid, lid]
			elif _hanzi(text) > 60 or _hanzi(text) < 8:
				err = "%s plate hanzi %s" % [cid, lid]
			elif int(want[lid]) == 6 and str(line.get("speaker", "")) == "旁白":
				err = "%s plate-final narrator" % cid
			else:
				found += 1
		idx += 1
	if err == "" and found != 6:
		err = "%s plates %d" % [cid, found]
	elif err == "" and not got_needle:
		err = "%s needle mismatch" % cid
	elif err == "" and (last_win < 0 or first_wex != last_win + 1):
		err = "%s wex not after win4 (win=%d wex=%d)" % [cid, last_win, first_wex]
	return err


func _static_unique(data: Dictionary, cid: String, seen: Dictionary) -> String:
	for beat_row in data.get("beats", []):
		for line in beat_row.get("lines", []):
			var text := str(line.get("text", ""))
			if text == "":
				continue
			if seen.has(text):
				return "echo %s == %s:%s" % [seen[text], cid, str(line.get("id", ""))]
			seen[text] = "%s:%s" % [cid, str(line.get("id", ""))]
	return ""


func _hub_entry() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var packed: PackedScene = load(HUB)
	if packed == null:
		return "castle_hub missing"
	var hub = packed.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	if hub.find_child("ContentSeasonRow", true, false) == null:
		hub.queue_free()
		return "ContentSeasonRow missing"
	if hub.has_method("_open_content_season_sheet"):
		hub.call("_open_content_season_sheet")
		await get_tree().process_frame
		await get_tree().process_frame
	for row in ROWS:
		var cid := str(row["cid"])
		var chip := hub.find_child("Season_%s" % cid, true, false)
		if chip == null:
			hub.queue_free()
			return "hub chip %s missing" % cid
		if StoryCatalog.request_chapter(cid) != StoryCatalog.player_scene():
			hub.queue_free()
			return "%s request_chapter" % cid
	hub.queue_free()
	await get_tree().process_frame
	print("OK hub chips ×%d" % ROWS.size())
	return ""


func _wex_leg(row: Dictionary) -> String:
	var cid := str(row["cid"])
	var beat := str(row["beat"])
	var needle := str(row["needle"])
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	GameState.set_flag(_fought_flag(cid))
	var player = await _spawn(cid, beat)
	var err := ""
	if player.current_beat_id() != beat:
		err = "%s want %s got %s" % [cid, beat, player.current_beat_id()]
	if err == "":
		err = await _see(player, needle)
	player.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK battle-settle %s" % cid)
	return err


func _spawn(cid: String, beat: String):
	StoryCatalog.request_chapter(cid)
	var packed: PackedScene = load(PLAYER)
	var player = packed.instantiate()
	player.suppress_scene_change = true
	player.lock_path = false
	player.chapter_path = ""
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	if beat != "" and player.current_beat_id() != beat:
		player.simulate_goto_beat(beat)
		await get_tree().process_frame
	return player


func _see(player, needle: String) -> String:
	var guard := 0
	while guard < 200:
		if str(player._body.text).find(needle) >= 0:
			return ""
		if not player.tap_advance():
			return "needle missing %s at %s body=%s" % [
				needle, player.current_beat_id(), str(player._body.text)]
		guard += 1
	return "needle not reached %s" % needle
