extends Node
## Hub → 章 → 开场拍主题口头 `_thm` → 进下一拍。
## S01–S10 二十章首拍加厚；不碰 visit `_vhg` / battle `_bpl` / tavern `_tvp` / ledger `_ldg`。
## 禁 EmptyHost / month_echo 新 kind。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"

const ROWS := [
	{"cid": "cs01_01", "beat": "open", "after": "hall", "needle": "纸我接。空格我验。验完再进厅。"},
	{"cid": "cs01_02", "beat": "slip", "after": "wu", "needle": "副页我按平。空行我留。留完再往下走。"},
	{"cid": "cs02_01", "beat": "seal", "after": "estate", "needle": "约我验。栏我留。留完再去对月。"},
	{"cid": "cs02_02", "beat": "slip", "after": "pulse", "needle": "偏我认。并排我守。守完再往下走。"},
	{"cid": "cs03_01", "beat": "merit", "after": "estate", "needle": "功粮我并验。验完再去对月结。"},
	{"cid": "cs03_02", "beat": "back", "after": "grain", "needle": "阴面我留。空我认。认完再往回走。"},
	{"cid": "cs03_03", "beat": "lab", "after": "wheel", "needle": "工面我留。空我认。认完再往水车。"},
	{"cid": "cs04_01", "beat": "preach", "after": "echo", "needle": "训我验。行我对。对完再去看月份。"},
	{"cid": "cs04_02", "beat": "back", "after": "deed", "needle": "训阴我翻。空行我留。留完再往下。"},
	{"cid": "cs04_03", "beat": "hall", "after": "aisle", "needle": "训堂我翻。碑空我留。留完再往下。"},

	{"cid": "cs05_01", "beat": "court", "after": "chair", "needle": "椅我验。链我留。留完再去看月份。"},
	{"cid": "cs05_02", "beat": "reread", "after": "chain", "needle": "图我按。空我认。认完再往下走。"},
	{"cid": "cs05_03", "beat": "atrium", "after": "rail", "needle": "嗣庭我翻。椅空我留。留完再往下。"},
	{"cid": "cs06_01", "beat": "yard", "after": "spar", "needle": "栏我挂。空我留。留完再去看校场。"},
	{"cid": "cs06_02", "beat": "yard", "after": "spar", "needle": "空条我留。回读我验。验完再往下。"},
	{"cid": "cs07_01", "beat": "yard", "after": "rite", "needle": "礼序我验。路我走。走完再去看月份。"},
	{"cid": "cs07_02", "beat": "yard", "after": "rite", "needle": "未续我认。空条我留。留完再往下。"},
	{"cid": "cs08_01", "beat": "yard", "after": "stele", "needle": "碑我验。灰我擦。擦完再去看月份。"},
	{"cid": "cs08_02", "beat": "yard", "after": "stele", "needle": "阴面我留。缺角我认。认完再往下。"},
	{"cid": "cs09_01", "beat": "yard", "after": "blood", "needle": "验栏我留。针我看。看完再去对月。"},
	{"cid": "cs09_02", "beat": "yard", "after": "blood", "needle": "空行我留。朱丝我验。验完再往下。"},
	{"cid": "cs10_01", "beat": "yard", "after": "affairs", "needle": "匣我验。边我留。留完再去看月份。"},
	{"cid": "cs10_02", "beat": "yard", "after": "seal", "needle": "空框我留。边我验。验完再往下走。"},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_theme_open_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON THEME OPEN CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_plates()
	if err != "":
		return err
	err = await _hub_entry()
	if err != "":
		return err
	for row in ROWS:
		err = await _theme_leg(row)
		if err != "":
			return err
	return ""


func _plate_id(cid: String, n: int) -> String:
	return "%s_thm%d" % [cid.replace("_", ""), n]


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


func _first_beat(data: Dictionary):
	var beats = data.get("beats", [])
	if beats.is_empty():
		return null
	return beats[0]


func _static_plates() -> String:
	if StoryCatalog.content_season_entries().size() != ROWS.size():
		return "catalog %d" % StoryCatalog.content_season_entries().size()
	var seen := {}
	for row in ROWS:
		var err := _static_one(row, seen)
		if err != "":
			return err
	print("OK static theme-open plates ×%d" % ROWS.size())
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
	var beat = _first_beat(data)
	if beat == null:
		return "%s no first beat" % cid
	if str(beat.get("id", "")) != str(row["beat"]):
		return "%s first beat %s want %s" % [cid, str(beat.get("id", "")), str(row["beat"])]
	var err := _static_plate_lines(cid, beat, str(row["needle"]))
	if err != "":
		return err
	var nxt := str(beat.get("next", ""))
	if nxt != str(row["after"]):
		return "%s next %s want %s" % [cid, nxt, str(row["after"])]
	return _static_unique(data, cid, seen)


func _static_plate_lines(cid: String, beat, needle: String) -> String:
	var want := {}
	for n in range(1, 7):
		want[_plate_id(cid, n)] = n
	var found := 0
	var saw_gate := false
	var err := ""
	var got_needle := false
	for line in beat.get("lines", []):
		if err != "":
			break
		var lid := str(line.get("id", ""))
		var text := str(line.get("text", ""))
		if text == needle:
			got_needle = true
		if not want.has(lid):
			if line.has("when"):
				saw_gate = true
			continue
		if line.has("when") or saw_gate:
			err = "%s plate gated %s" % [cid, lid]
		elif _hanzi(text) > 60 or _hanzi(text) < 8:
			err = "%s plate hanzi %s" % [cid, lid]
		elif int(want[lid]) == 6 and str(line.get("speaker", "")) == "旁白":
			err = "%s plate-final narrator" % cid
		else:
			found += 1
		if line.has("when"):
			saw_gate = true
	if err == "" and found != 6:
		err = "%s plates %d" % [cid, found]
	elif err == "" and not got_needle:
		err = "%s needle mismatch" % cid
	return err


func _static_unique(data: Dictionary, cid: String, seen: Dictionary) -> String:
	for beat_row in data.get("beats", []):
		if str(beat_row.get("id", "")) == "ledger":
			continue
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


func _theme_leg(row: Dictionary) -> String:
	var cid := str(row["cid"])
	var beat := str(row["beat"])
	var after := str(row["after"])
	var needle := str(row["needle"])
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	var player = await _spawn(cid, beat)
	if player.current_beat_id() != beat:
		var err0 := "%s want %s got %s" % [cid, beat, player.current_beat_id()]
		player.queue_free()
		await get_tree().process_frame
		return err0
	var err := await _see(player, needle)
	if err == "":
		player.simulate_finish_dialogue()
		await get_tree().process_frame
		if after == "":
			pass
		elif not player.simulate_press_action_containing("继续"):
			err = "%s continue press labels=%s" % [cid, str(player.action_labels())]
		else:
			await get_tree().process_frame
			if player.current_beat_id() != after:
				err = "%s after theme want %s got %s" % [cid, after, player.current_beat_id()]
	player.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK theme-open %s → %s" % [cid, after])
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
	while guard < 120:
		if str(player._body.text).find(needle) >= 0:
			return ""
		if not player.tap_advance():
			return "needle missing %s at %s body=%s" % [
				needle, player.current_beat_id(), str(player._body.text)]
		guard += 1
	return "needle not reached %s" % needle
