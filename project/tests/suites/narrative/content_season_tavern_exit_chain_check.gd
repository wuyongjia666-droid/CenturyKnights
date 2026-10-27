extends Node
## Hub → 章 → 酒馆离店口头 `_tvx`。
## S01–S10；插在 `_tvn`（及可选 `_sth`）后、`ret_mv` 前。不碰 `_bpl`/`_arr`/`_lop`/`_cls`/`_sec`/`_sth`。
## 禁 EmptyHost / month_echo / 新 season。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"

const ROWS := [
	{"cid": "cs01_01", "beat": "tavern", "needle": "板验完。我出店，字跟我回堡。"},
	{"cid": "cs01_02", "beat": "tavern", "needle": "挂完了。我掀帘，路回堡。"},
	{"cid": "cs02_01", "beat": "tavern", "needle": "两栏认过。我出店，约在怀。"},
	{"cid": "cs02_02", "beat": "tavern", "needle": "脉对过。我出店，行回堡。"},
	{"cid": "cs03_01", "beat": "tavern", "needle": "粮验完。我出店，袋跟肩回堡。"},
	{"cid": "cs03_02", "beat": "tavern", "needle": "仓事挂完。我出店，路回堡。"},
	{"cid": "cs03_03", "beat": "tavern", "needle": "账事挂完。我出店，路回堡。"},
	{"cid": "cs04_01", "beat": "tavern", "needle": "训验完。我出店，卷在胸回堡。"},
	{"cid": "cs04_02", "beat": "tavern", "needle": "契收好。我出店，字回堡。"},
	{"cid": "cs04_03", "beat": "tavern", "needle": "契收好。我出店，字回堡。碑廊认。"},

	{"cid": "cs05_01", "beat": "tavern", "needle": "空椅过了。我出店，链不响。"},
	{"cid": "cs05_02", "beat": "tavern", "needle": "链收好。我出店，回堡认栏。"},
	{"cid": "cs05_03", "beat": "tavern", "needle": "契收好。我出店，字回堡。空栏认。"},
	{"cid": "cs06_01", "beat": "tavern", "needle": "场沙卸尽。我出店，鼓声抛在后。"},
	{"cid": "cs06_02", "beat": "tavern", "needle": "鼓停在店里。我出店，路回堡。"},
	{"cid": "cs07_01", "beat": "tavern", "needle": "礼收完。我出店，册回堡。"},
	{"cid": "cs07_02", "beat": "tavern", "needle": "笔事搁下。我出店，字回堡。"},
	{"cid": "cs08_01", "beat": "tavern", "needle": "碑过了。我出店，拓在怀回堡。"},
	{"cid": "cs08_02", "beat": "tavern", "needle": "阴面收好。我出店，复页回堡。"},
	{"cid": "cs09_01", "beat": "tavern", "needle": "针事收起。我出店，丝不露。"},
	{"cid": "cs09_02", "beat": "tavern", "needle": "丝收好。我出店，验栏回堡。"},
	{"cid": "cs10_01", "beat": "tavern", "needle": "印边验过。我出店，框在怀回堡。"},
	{"cid": "cs10_02", "beat": "tavern", "needle": "框收好。我出店，岁课回堡。"},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_tavern_exit_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON TAVERN EXIT CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_plates()
	if err != "":
		return err
	err = await _hub_entry()
	if err != "":
		return err
	for row in ROWS:
		err = await _tvx_leg(row)
		if err != "":
			return err
	return ""


func _plate_id(cid: String, n: int) -> String:
	return "%s_tvx%d" % [cid.replace("_", ""), n]


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
	print("OK static tavern-exit plates ×%d" % ROWS.size())
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
	var last_tvn := -1
	var first_tvx := -1
	var lids: Array = []
	var idx := 0
	for line in beat.get("lines", []):
		if err != "":
			break
		var lid := str(line.get("id", ""))
		var text := str(line.get("text", ""))
		lids.append(lid)
		if lid.find("_tvn") >= 0:
			last_tvn = idx
		if text == needle:
			got_needle = true
		if want.has(lid):
			if first_tvx < 0:
				first_tvx = idx
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
		idx += 1
	if err == "" and found != 6:
		err = "%s plates %d" % [cid, found]
	elif err == "" and not got_needle:
		err = "%s needle mismatch" % cid
	elif err == "" and (last_tvn < 0 or first_tvx < 0 or first_tvx <= last_tvn):
		err = "%s tvx not after tvn (tvn=%d tvx=%d)" % [cid, last_tvn, first_tvx]
	elif err == "":
		# `_sth` 席末静口可夹在 `_tvn` 与 `_tvx` 之间
		for i in range(last_tvn + 1, first_tvx):
			var mid := str(lids[i])
			if mid.find("_sth") < 0:
				err = "%s gap before tvx not sth (%s)" % [cid, mid]
				break
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


func _tvx_leg(row: Dictionary) -> String:
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
		print("OK tavern-exit %s" % cid)
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
