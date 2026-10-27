extends Node
## Hub → 章 → 酒馆到店口头 `_arr`。
## S01–S10；插在 tavern 拍首、`_tvp` 前。不碰 `_bpl`/`_cls`/`_sec`/`_msr`/`_ldg`。
## 禁 EmptyHost / month_echo / 新 season。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"

const ROWS := [
	{"cid": "cs01_01", "beat": "tavern", "needle": "我进店。靴净、手空，再看板。"},
	{"cid": "cs01_02", "beat": "tavern", "needle": "我到店。气匀了，再认挂板。"},
	{"cid": "cs02_01", "beat": "tavern", "needle": "我进店。约在怀，板在前。"},
	{"cid": "cs02_02", "beat": "tavern", "needle": "我到店。脉认过，再看挂板。"},
	{"cid": "cs03_01", "beat": "tavern", "needle": "我进店。粮在旁，板在上。"},
	{"cid": "cs03_02", "beat": "tavern", "needle": "我到店。仓事放下，再认板。"},
	{"cid": "cs03_03", "beat": "tavern", "needle": "我到店。账事放下，再认板。"},
	{"cid": "cs04_01", "beat": "tavern", "needle": "我进店。训在胸，板在眼。"},
	{"cid": "cs04_02", "beat": "tavern", "needle": "我到店。契在袖，再看挂板。"},
	{"cid": "cs04_03", "beat": "tavern", "needle": "我到店。帖在袖，再看挂板。"},

	{"cid": "cs05_01", "beat": "tavern", "needle": "我进店。空椅过了，板还在。"},
	{"cid": "cs05_02", "beat": "tavern", "needle": "我到店。链收好，再认挂板。"},
	{"cid": "cs05_03", "beat": "tavern", "needle": "我到店。栏在袖，再看挂板。"},
	{"cid": "cs06_03", "beat": "tavern", "needle": "我到店。圈在袖，再看挂板。"},
	{"cid": "cs06_01", "beat": "tavern", "needle": "我进店。场上的沙，不带上板。"},
	{"cid": "cs06_02", "beat": "tavern", "needle": "我到店。鼓停了，再看挂板。"},
	{"cid": "cs07_01", "beat": "tavern", "needle": "我进店。礼过了，板还等着。"},
	{"cid": "cs07_02", "beat": "tavern", "needle": "我到店。笔事放下，再认板。"},
	{"cid": "cs08_01", "beat": "tavern", "needle": "我进店。碑过了，板在梁上。"},
	{"cid": "cs08_02", "beat": "tavern", "needle": "我到店。阴面收好，再看挂板。"},
	{"cid": "cs09_01", "beat": "tavern", "needle": "我进店。针事收起，再认板。"},
	{"cid": "cs09_02", "beat": "tavern", "needle": "我到店。丝收好，再看挂板。"},
	{"cid": "cs10_01", "beat": "tavern", "needle": "我进店。印边验过，再认板。"},
	{"cid": "cs10_02", "beat": "tavern", "needle": "我到店。框收好，再看挂板。"},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_tavern_arrival_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON TAVERN ARRIVAL CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_plates()
	if err != "":
		return err
	err = await _hub_entry()
	if err != "":
		return err
	for row in ROWS:
		err = await _arr_leg(row)
		if err != "":
			return err
	return ""


func _plate_id(cid: String, n: int) -> String:
	return "%s_arr%d" % [cid.replace("_", ""), n]


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
	print("OK static tavern-arrival plates ×%d" % ROWS.size())
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
	var beat = _beat_named(data, "tavern")
	if beat == null:
		return "%s no tavern" % cid
	var err := _static_plate_lines(cid, beat, str(row["needle"]))
	if err != "":
		return err
	return _static_unique(data, cid, seen)


func _static_plate_lines(cid: String, beat, needle: String) -> String:
	var want := {}
	for n in range(1, 7):
		want[_plate_id(cid, n)] = n
	var found := 0
	var saw_gate := false
	var err := ""
	var got_needle := false
	var first_ids: Array = []
	for line in beat.get("lines", []):
		if err != "":
			break
		var lid := str(line.get("id", ""))
		var text := str(line.get("text", ""))
		if first_ids.size() < 6:
			first_ids.append(lid)
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
	elif err == "":
		for n in range(1, 7):
			if str(first_ids[n - 1]) != _plate_id(cid, n):
				err = "%s arr not at head got %s" % [cid, str(first_ids)]
				break
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


func _arr_leg(row: Dictionary) -> String:
	var cid := str(row["cid"])
	var needle := str(row["needle"])
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	var player = await _spawn(cid, "tavern")
	var err := ""
	if player.current_beat_id() != "tavern":
		err = "%s want tavern got %s" % [cid, player.current_beat_id()]
	if err == "":
		err = await _see(player, needle)
	player.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK tavern-arrival %s" % cid)
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
	while guard < 160:
		if str(player._body.text).find(needle) >= 0:
			return ""
		if not player.tap_advance():
			return "needle missing %s at %s body=%s" % [
				needle, player.current_beat_id(), str(player._body.text)]
		guard += 1
	return "needle not reached %s" % needle
