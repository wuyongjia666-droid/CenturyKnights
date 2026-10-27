extends Node
## Hub → 章 → 板后耳语口头 `_aft`。
## S01–S10；插在 tavern `_tvp6` 后、`_tvn1` 前。不碰 `_arr`/`_tvp`/`_tvn`/`_tvx`/`_brd`/`_rtn`/`_lop`/`_cls`/`_wex`/`_ink`/`_aud`。
## 禁 EmptyHost / month_echo / 新 season。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"

const ROWS := [
	{"cid": "cs01_01", "beat": "tavern", "needle": "板后静着。我按住回执，先不接闲话。"},
	{"cid": "cs01_02", "beat": "tavern", "needle": "副页按稳了。板后这一息，我先听灯，不听人。"},
	{"cid": "cs02_01", "beat": "tavern", "needle": "真名在钉上。板后我闭一口，先不接酒话。"},
	{"cid": "cs02_02", "beat": "tavern", "needle": "脉纸在钉。板后这一息，我护着偏，不接催。"},
	{"cid": "cs03_01", "beat": "tavern", "needle": "功粮钉稳。板后我按住栏，先不接骂。"},
	{"cid": "cs03_02", "beat": "tavern", "needle": "阴面留着。板后这一息，我守空格，不接催功。"},
	{"cid": "cs03_03", "beat": "tavern", "needle": "工面留着。板后这一息，我守空格，不接催工。"},
	{"cid": "cs04_01", "beat": "tavern", "needle": "训行钉齐。板后我踏实靴，先不接空庙话。"},
	{"cid": "cs04_02", "beat": "tavern", "needle": "年迹在钉。板后这一息，我验针脚，不接催绣。"},
	{"cid": "cs04_03", "beat": "tavern", "needle": "堂迹在钉。板后这一息，我验碑纹，不接催训。"},

	{"cid": "cs05_01", "beat": "tavern", "needle": "空椅过了。板后我认格，先不抢名。"},
	{"cid": "cs05_02", "beat": "tavern", "needle": "回读贴平。板后这一息，我守链，不接催坐。"},
	{"cid": "cs05_03", "beat": "tavern", "needle": "庭迹在钉。板后这一息，我验栏纹，不接催嗣。"},
	{"cid": "cs06_01", "beat": "tavern", "needle": "胜名在钉。板后我拍净袖土，先不接哄声。"},
	{"cid": "cs06_02", "beat": "tavern", "needle": "鼓歇了。板后这一息，我守空条，不接封胜。"},
	{"cid": "cs07_01", "beat": "tavern", "needle": "路过钉稳。板后我收香，先不抢路名。"},
	{"cid": "cs07_02", "beat": "tavern", "needle": "年迹在钉。板后这一息，我先问齐，不接续。"},
	{"cid": "cs08_01", "beat": "tavern", "needle": "碑录钉稳。板后我接手温，先不接热话。"},
	{"cid": "cs08_02", "beat": "tavern", "needle": "阴面按平。板后这一息，我认缺角，不接催名。"},
	{"cid": "cs09_01", "beat": "tavern", "needle": "验栏认完。板后我按住血名，先不听赌挂。"},
	{"cid": "cs09_02", "beat": "tavern", "needle": "复验钉稳。板后这一息，我收丝，不接催名。"},
	{"cid": "cs10_01", "beat": "tavern", "needle": "印边验过。板后我护着红，先不接快话。"},
	{"cid": "cs10_02", "beat": "tavern", "needle": "岁课按稳。板后这一息，我认泥痕，不接催印。"},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_after_board_hush_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON AFTER BOARD HUSH CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_plates()
	if err != "":
		return err
	err = await _hub_entry()
	if err != "":
		return err
	for row in ROWS:
		err = await _aft_leg(row)
		if err != "":
			return err
	return ""


func _plate_id(cid: String, n: int) -> String:
	return "%s_aft%d" % [cid.replace("_", ""), n]


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
	print("OK static after-board-hush plates ×%d" % ROWS.size())
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
	var first_aft := -1
	var tvp6_at := -1
	var tvn1_at := -1
	var idx := 0
	for line in beat.get("lines", []):
		if err != "":
			break
		var lid := str(line.get("id", ""))
		var text := str(line.get("text", ""))
		if lid.ends_with("_tvp6"):
			tvp6_at = idx
		if lid.ends_with("_tvn1"):
			tvn1_at = idx
		if text == needle:
			got_needle = true
		if want.has(lid):
			if first_aft < 0:
				first_aft = idx
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
	elif err == "" and (tvp6_at < 0 or first_aft < 0 or tvn1_at < 0):
		err = "%s anchors missing tvp6=%d aft=%d tvn=%d" % [cid, tvp6_at, first_aft, tvn1_at]
	elif err == "" and (first_aft != tvp6_at + 1 or first_aft + 6 != tvn1_at):
		err = "%s aft not between tvp6 and tvn1 (tvp6=%d aft=%d tvn=%d)" % [cid, tvp6_at, first_aft, tvn1_at]
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


func _aft_leg(row: Dictionary) -> String:
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
		print("OK after-board-hush %s" % cid)
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
