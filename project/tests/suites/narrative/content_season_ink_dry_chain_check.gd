extends Node
## Hub → 章 → 墨干合页口头 `_ink`。
## S01–S10；插在 ledger 拍 `_ldg_end` 后、`_cls1` 前。不碰 `_lop`/`_ldg`/`_cls`/`_bpl`/`_aud`/`_vex`。
## 禁 EmptyHost / month_echo / 新 season。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"

const ROWS := [
	{"cid": "cs01_01", "beat": "ledger", "needle": "无干了。我合页，灯留给西阁自己矮。"},
	{"cid": "cs01_02", "beat": "ledger", "needle": "边干了。副页进柜，欠停在角上，人回。"},
	{"cid": "cs02_01", "beat": "ledger", "needle": "两行干了。匣扣上，产房的事明天再报。"},
	{"cid": "cs02_02", "beat": "ledger", "needle": "偏格干平了。结论不今晚写，人先离开案。"},
	{"cid": "cs03_01", "beat": "ledger", "needle": "铃干了。袋还在肩，功和粮都进册，我回仓门。"},
	{"cid": "cs03_02", "beat": "ledger", "needle": "秤星干了。榜阴夹好，假数留在风里，人不捡。"},
	{"cid": "cs03_03", "beat": "ledger", "needle": "秤星干了。工账夹好，假数留在风里，人不捡。"},
	{"cid": "cs04_01", "beat": "ledger", "needle": "训干了。绣词门外，步数我带走，字留下。"},
	{"cid": "cs04_02", "beat": "ledger", "needle": "墨干了。契角压平，人走，不用守着看。"},
	{"cid": "cs04_03", "beat": "ledger", "needle": "墨干了。契角压平，人走，不用守着看。堂碑守。"},

	{"cid": "cs05_01", "beat": "ledger", "needle": "空栏干了。椅子空着我才走，名的事明天对。"},
	{"cid": "cs05_02", "beat": "ledger", "needle": "页干了。潮着我也回过；干了，我才真离开案。"},
	{"cid": "cs05_03", "beat": "ledger", "needle": "墨干了。契角压平，人走，不用守着看。栏椅守。"},
	{"cid": "cs06_03", "beat": "ledger", "needle": "墨干了。契角压平，人走，不用守着看。栏场守。"},
	{"cid": "cs07_03", "beat": "ledger", "needle": "墨干了。契角压平，人走，不用守着看。栏仪守。"},
	{"cid": "cs08_03", "beat": "ledger", "needle": "墨干了。契角压平，人走，不用守着看。栏祠守。"},
	{"cid": "cs09_03", "beat": "ledger", "needle": "墨干了。契角压平，人走，不用守着看。栏验守。"},
	{"cid": "cs10_03", "beat": "ledger", "needle": "墨干了。契角压平，人走，不用守着看。栏泥守。"},
	{"cid": "cs06_01", "beat": "ledger", "needle": "鼓点干了。胜名没钉，旗我带回旗杆下。"},
	{"cid": "cs06_02", "beat": "ledger", "needle": "空条还空，可干了。册合上，不在酒醒前填。"},
	{"cid": "cs07_01", "beat": "ledger", "needle": "序干了。路走到门槛为止，名字不在灯下抢。"},
	{"cid": "cs07_02", "beat": "ledger", "needle": "绳旁干了。人没齐，谱先合；齐了的那天再续。"},
	{"cid": "cs08_01", "beat": "ledger", "needle": "香行干了。我离祠阶，碑名不在路上补。"},
	{"cid": "cs08_02", "beat": "ledger", "needle": "拓纸干凉。缺角不补，手凉着回去正好。"},
	{"cid": "cs09_01", "beat": "ledger", "needle": "缝旁干了。自己的血认过；新泼的不带回。"},
	{"cid": "cs09_02", "beat": "ledger", "needle": "两星都干了。册可合，第三笔今晚不添。"},
	{"cid": "cs10_01", "beat": "ledger", "needle": "边干了。印慢盖，毛刺留盒里，人先回。"},
	{"cid": "cs10_02", "beat": "ledger", "needle": "第二圈干了才夹柜。催印的话，我留在门外。"},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_ink_dry_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON INK DRY CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_plates()
	if err != "":
		return err
	err = await _hub_entry()
	if err != "":
		return err
	for row in ROWS:
		err = await _ink_leg(row)
		if err != "":
			return err
	return ""


func _plate_id(cid: String, n: int) -> String:
	return "%s_ink%d" % [cid.replace("_", ""), n]


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
	print("OK static ink-dry plates ×%d" % ROWS.size())
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
	var first_ink := -1
	var ldg_end_at := -1
	var cls1_at := -1
	var idx := 0
	for line in beat.get("lines", []):
		if err != "":
			break
		var lid := str(line.get("id", ""))
		var text := str(line.get("text", ""))
		if lid.ends_with("_ldg_end"):
			ldg_end_at = idx
		if lid.ends_with("_cls1"):
			cls1_at = idx
		if text == needle:
			got_needle = true
		if want.has(lid):
			if first_ink < 0:
				first_ink = idx
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
	elif err == "" and (ldg_end_at < 0 or first_ink < 0 or cls1_at < 0):
		err = "%s anchors missing ldg=%d ink=%d cls=%d" % [cid, ldg_end_at, first_ink, cls1_at]
	elif err == "" and (first_ink != ldg_end_at + 1 or first_ink + 6 != cls1_at):
		err = "%s ink not between ldg_end and cls1 (ldg=%d ink=%d cls=%d)" % [cid, ldg_end_at, first_ink, cls1_at]
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


func _ink_leg(row: Dictionary) -> String:
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
		print("OK ink-dry %s" % cid)
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
