extends Node
## Hub → 章 → 访月落笔口头 `_aud`。
## S01–S10；插在 visit 拍 `_vhg` 前（验/产/沙漏正文后）。不碰 `_vop`/`_vhg`/`_msr`/`_bpl`/`_lop`。
## 禁 EmptyHost / month_echo / 新 season。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"

const ROWS := [
	{"cid": "cs01_01", "beat": "audit", "needle": "我落笔。无，验过的无。"},
	{"cid": "cs01_02", "beat": "hourglass", "needle": "我写无。婚约灯下，也认这一笔。"},
	{"cid": "cs02_01", "beat": "birth", "needle": "我落笔。无征兆——我认。"},
	{"cid": "cs02_02", "beat": "hourglass", "needle": "我写无。脉清，栏也清。"},
	{"cid": "cs03_01", "beat": "hourglass", "needle": "我落笔。无——田里的实数我另记。"},
	{"cid": "cs03_02", "beat": "hourglass", "needle": "我写无。粮在仓，字在栏。"},
	{"cid": "cs03_03", "beat": "hourglass", "needle": "我写空。工在田，字在栏。"},
	{"cid": "cs04_01", "beat": "hourglass", "needle": "我落笔。无——训在胸，栏在纸。"},
	{"cid": "cs04_02", "beat": "hourglass", "needle": "我写无。契在袖，字在栏。"},
	{"cid": "cs04_03", "beat": "hourglass", "needle": "我写无。帖在袖，字在栏。"},

	{"cid": "cs05_01", "beat": "hourglass", "needle": "我落笔。无——椅空，字不空。"},
	{"cid": "cs05_02", "beat": "hourglass", "needle": "我写无。链收好，栏认清。"},
	{"cid": "cs05_03", "beat": "hourglass", "needle": "我写空。栏在袖，字在椅。"},
	{"cid": "cs06_03", "beat": "hourglass", "needle": "我写空。圈在袖，字在桩。"},
	{"cid": "cs07_03", "beat": "hourglass", "needle": "我写空。印在袖，字在印。"},
	{"cid": "cs06_01", "beat": "hourglass", "needle": "我落笔。无——沙在场，字在纸。"},
	{"cid": "cs06_02", "beat": "hourglass", "needle": "我写无。鼓歇了，栏也歇实。"},
	{"cid": "cs07_01", "beat": "hourglass", "needle": "我落笔。无——礼收了，字留下。"},
	{"cid": "cs07_02", "beat": "hourglass", "needle": "我写无。笔事先搁，字先定。"},
	{"cid": "cs08_01", "beat": "hourglass", "needle": "我落笔。无——碑过了，栏还在。"},
	{"cid": "cs08_02", "beat": "hourglass", "needle": "我写无。阴面收好，栏面清。"},
	{"cid": "cs09_01", "beat": "hourglass", "needle": "我落笔。无——针事收起，字留下。"},
	{"cid": "cs09_02", "beat": "hourglass", "needle": "我写无。丝收好，栏认完。"},
	{"cid": "cs10_01", "beat": "hourglass", "needle": "我落笔。无——印边验过，字先定。"},
	{"cid": "cs10_02", "beat": "hourglass", "needle": "我写无。框收好，栏合上。"},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_audit_pen_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON AUDIT PEN CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_plates()
	if err != "":
		return err
	err = await _hub_entry()
	if err != "":
		return err
	for row in ROWS:
		err = await _aud_leg(row)
		if err != "":
			return err
	return ""


func _plate_id(cid: String, n: int) -> String:
	return "%s_aud%d" % [cid.replace("_", ""), n]


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
	print("OK static audit-pen plates ×%d" % ROWS.size())
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
	var err := ""
	var got_needle := false
	var first_aud := -1
	var vhg_at := -1
	var idx := 0
	for line in beat.get("lines", []):
		if err != "":
			break
		var lid := str(line.get("id", ""))
		var text := str(line.get("text", ""))
		if lid.ends_with("_vhg1"):
			vhg_at = idx
		if text == needle:
			got_needle = true
		if want.has(lid):
			if first_aud < 0:
				first_aud = idx
			if line.has("when"):
				err = "%s plate gated %s" % [cid, lid]
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
	elif err == "" and (vhg_at < 0 or first_aud < 0 or first_aud + 6 != vhg_at):
		err = "%s aud not before vhg1 (aud=%d vhg=%d)" % [cid, first_aud, vhg_at]
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


func _aud_leg(row: Dictionary) -> String:
	var cid := str(row["cid"])
	var beat := str(row["beat"])
	var needle := str(row["needle"])
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	var player = await _spawn(cid, beat)
	var err := ""
	if player.current_beat_id() != beat:
		err = "%s want %s got %s" % [cid, beat, player.current_beat_id()]
	if err == "":
		err = await _see(player, needle)
	player.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK audit-pen %s" % cid)
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
	while guard < 220:
		if str(player._body.text).find(needle) >= 0:
			return ""
		if not player.tap_advance():
			return "needle missing %s at %s body=%s" % [
				needle, player.current_beat_id(), str(player._body.text)]
		guard += 1
	return "needle not reached %s" % needle
