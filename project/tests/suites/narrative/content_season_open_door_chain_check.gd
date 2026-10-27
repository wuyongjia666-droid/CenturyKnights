extends Node
## Hub → 章 → 开场入门口头 `_opn`。
## S01–S10；插在首拍拍首、`_thm` 前。不碰 `_bpl`/`_arr`/`_lop`/`_tvx`/`_vop`/`_cls`/`_sec`。
## 禁 EmptyHost / month_echo / 新 season。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"

const ROWS := [
	{"cid": "cs01_01", "beat": "open", "needle": "我进门。风过靴净，再接岁课纸。"},
	{"cid": "cs01_02", "beat": "slip", "needle": "我进门。副页晾过，再认空行。"},
	{"cid": "cs02_01", "beat": "seal", "needle": "我进门。约在怀，门开一线，我侧身入。"},
	{"cid": "cs02_02", "beat": "slip", "needle": "我进门。脉案静，再认并排空。"},
	{"cid": "cs03_01", "beat": "merit", "needle": "我进门。功粮分清，再对榜。"},
	{"cid": "cs03_02", "beat": "back", "needle": "我进门。阴面离潮，再认空。"},
	{"cid": "cs03_03", "beat": "lab", "needle": "我进门。工册离潮，再认空。"},
	{"cid": "cs04_01", "beat": "preach", "needle": "我进门。训在臂，再听讲。"},
	{"cid": "cs04_02", "beat": "back", "needle": "我进门。契在袖，再翻训阴。"},
	{"cid": "cs04_03", "beat": "hall", "needle": "我进门。帖在袖，再进训堂。"},

	{"cid": "cs05_01", "beat": "court", "needle": "我进门。空椅影在，人先站定。"},
	{"cid": "cs05_02", "beat": "reread", "needle": "我进门。图卷齐，再回读。"},
	{"cid": "cs05_03", "beat": "atrium", "needle": "我进门。帖在袖，再进嗣庭。"},
	{"cid": "cs06_01", "beat": "yard", "needle": "我进门。场沙尽，再挂栏。"},
	{"cid": "cs06_02", "beat": "yard", "needle": "我进门。鼓皮晾外，再认空条。"},
	{"cid": "cs07_01", "beat": "yard", "needle": "我进门。礼香散尽，再走序。"},
	{"cid": "cs07_02", "beat": "yard", "needle": "我进门。笔事稳，再认未续。"},
	{"cid": "cs08_01", "beat": "yard", "needle": "我进门。灰洗过，再验碑。"},
	{"cid": "cs08_02", "beat": "yard", "needle": "我进门。阴面包好，再认缺角。"},
	{"cid": "cs09_01", "beat": "yard", "needle": "我进门。针盘盖着，再看验栏。"},
	{"cid": "cs09_02", "beat": "yard", "needle": "我进门。朱丝收紧，再认空行。"},
	{"cid": "cs10_01", "beat": "yard", "needle": "我进门。匣边净，再验印边。"},
	{"cid": "cs10_02", "beat": "yard", "needle": "我进门。框在廊，再认空边。"},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_open_door_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON OPEN DOOR CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_plates()
	if err != "":
		return err
	err = await _hub_entry()
	if err != "":
		return err
	for row in ROWS:
		err = await _opn_leg(row)
		if err != "":
			return err
	return ""


func  _plate_id(cid: String, n: int) -> String:
	return "%s_opn%d" % [cid.replace("_", ""), n]


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
	print("OK static open-door plates ×%d" % ROWS.size())
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
				err = "%s opn not at head got %s" % [cid, str(first_ids)]
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


func _opn_leg(row: Dictionary) -> String:
	var cid := str(row["cid"])
	var needle := str(row["needle"])
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	var beat := str(row["beat"])
	var player = await _spawn(cid, beat)
	var err := ""
	if player.current_beat_id() != beat:
		err = "%s want %s got %s" % [cid, beat, player.current_beat_id()]
	if err == "":
		err = await _see(player, needle)
	player.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK open-door %s" % cid)
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
