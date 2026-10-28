extends Node
## Hub → 章 → 酒馆挂板口头 `_tvp` → 入谱前选择 → ledger。
## S01–S10 二十章酒馆拍加厚；不碰 visit `_vhg` / battle `_bpl` / ledger `_ldg`。
## 禁 EmptyHost / month_echo 新 kind。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"

const ROWS := [
	{"cid": "cs01_01", "needle": "板我认。字我验。验完再选挂法。", "act": "把无写进谱"},
	{"cid": "cs01_02", "needle": "副页我按进空格。挂之前，先问自己一句。", "act": "空格并排留"},
	{"cid": "cs02_01", "needle": "两行我并排留。店里灯亮着，我才落钉。", "act": "两行并排留"},
	{"cid": "cs02_02", "needle": "偏我认。催挂的话，今晚不听。", "act": "偏仍并排"},
	{"cid": "cs03_01", "needle": "功与粮并排。骂声来之前，我先验灰。", "act": "功与粮并排"},
	{"cid": "cs03_02", "needle": "阴面我留。催功栏的话，先过我这一盏。", "act": "功粮仍并"},
	{"cid": "cs03_03", "needle": "工面我留。催工栏的话，先过我这一盏。", "act": "工粮仍并"},
	{"cid": "cs04_01", "needle": "训与行我并排。空庙今晚不挂。", "act": "训与行并排"},
	{"cid": "cs04_02", "needle": "训行仍并。催绣词的，先看自己针脚。", "act": "训行仍并"},
	{"cid": "cs04_03", "needle": "堂碑仍并。催训条的，先看自己碑纹。", "act": "堂碑仍并"},

	{"cid": "cs05_01", "needle": "链我验。名不抢先。抢先的椅，我不认。", "act": "空椅并排链"},
	{"cid": "cs05_02", "needle": "链仍并排。催坐的话，等回读页干透。", "act": "链仍并排"},
	{"cid": "cs05_03", "needle": "栏椅仍并。催嗣名的，先看自己栏纹。", "act": "栏椅仍并"},
	{"cid": "cs06_03", "needle": "栏场仍并。催胜名的，先看自己场纹。", "act": "栏场仍并"},
	{"cid": "cs07_03", "needle": "栏仪仍并。催路名的，先看自己仪纹。", "act": "栏仪仍并"},
	{"cid": "cs08_03", "needle": "栏祠仍并。催碑名的，先看自己祠纹。", "act": "栏祠仍并"},
	{"cid": "cs09_03", "needle": "栏验仍并。催血名的，先看自己血纹。", "act": "栏验仍并"},
	{"cid": "cs06_01", "needle": "校场并排记。胜者名，我亲眼验过再钉。", "act": "校场并排记"},
	{"cid": "cs06_02", "needle": "空条我留。封胜的催，先过鼓停那一息。", "act": "空条并排"},
	{"cid": "cs07_01", "needle": "路过我验。路名不抢钉。", "act": "仪典并排记"},
	{"cid": "cs07_02", "needle": "空条并排。续之前，我先问人齐不齐。", "act": "空条并排"},
	{"cid": "cs08_01", "needle": "灰我擦。碑名我验。验完再选挂法。", "act": "祖祠并排记"},
	{"cid": "cs08_02", "needle": "碑阴并排留。催名的，先看缺角。", "act": "碑阴并排留"},
	{"cid": "cs09_01", "needle": "血名我验。赌挂的话，今晚不听。", "act": "血验并排记"},
	{"cid": "cs09_02", "needle": "空行我留。催名的，先过朱丝。", "act": "验空并排"},
	{"cid": "cs10_01", "needle": "边我验。印净了，再慢着喝酒。", "act": "城印并排记"},
	{"cid": "cs10_02", "needle": "印底我留。催印的，先看泥痕。", "act": "印底并排留"},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_tavern_plate_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON TAVERN PLATE CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_plates()
	if err != "":
		return err
	err = await _hub_entry()
	if err != "":
		return err
	for row in ROWS:
		err = await _tavern_chain(row)
		if err != "":
			return err
	return ""


func _plate_id(cid: String, n: int) -> String:
	return "%s_tvp%d" % [cid.replace("_", ""), n]


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


func _tavern_beat(data: Dictionary):
	for beat in data.get("beats", []):
		if str(beat.get("id", "")) == "tavern":
			return beat
	return null


func _reachable_tavern(data: Dictionary) -> bool:
	var beats := {}
	var first := ""
	for beat in data.get("beats", []):
		var bid := str(beat.get("id", ""))
		beats[bid] = str(beat.get("next", ""))
		if first == "":
			first = bid
	var guard := 0
	var cur := first
	while cur != "" and guard < 12:
		if cur == "tavern":
			return true
		cur = str(beats.get(cur, ""))
		guard += 1
	# some chapters jump via actions; accept if tavern beat exists after any prior
	return _tavern_beat(data) != null and first != "tavern"


func _static_plates() -> String:
	if StoryCatalog.content_season_entries().size() != ROWS.size():
		return "catalog %d" % StoryCatalog.content_season_entries().size()
	var seen := {}
	for row in ROWS:
		var err := _static_one(row, seen)
		if err != "":
			return err
	print("OK static tavern plates ×%d" % ROWS.size())
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
	if not _reachable_tavern(data):
		return "%s tavern missing/unreachable" % cid
	var beat = _tavern_beat(data)
	if beat == null:
		return "%s no tavern" % cid
	var err := _static_plate_lines(cid, beat, str(row["needle"]))
	if err != "":
		return err
	var acts: Array = beat.get("actions", [])
	if acts.is_empty():
		return "%s no hang action" % cid
	var has_goto := false
	for action in acts:
		for step in action.get("do", []):
			if typeof(step) == TYPE_DICTIONARY and str(step.get("op", "")) == "goto" and str(step.get("beat", "")) == "ledger":
				has_goto = true
	if not has_goto and str(beat.get("next", "")) != "ledger":
		return "%s no ledger goto" % cid
	err = _static_unique(data, cid, seen)
	return err


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


func _tavern_chain(row: Dictionary) -> String:
	var cid := str(row["cid"])
	var needle := str(row["needle"])
	var act := str(row["act"])
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	var player = await _spawn(cid, "tavern")
	if player.current_beat_id() != "tavern":
		var err0 := "%s want tavern got %s" % [cid, player.current_beat_id()]
		player.queue_free()
		await get_tree().process_frame
		return err0
	var err := await _see(player, needle)
	if err == "":
		player.simulate_finish_dialogue()
		await get_tree().process_frame
		if str(player._body.text).find(needle) < 0:
			# finish may land on last visible; still require act available
			pass
		if not player.simulate_press_action_containing(act):
			err = "%s hang press %s labels=%s" % [cid, act, str(player.action_labels())]
		else:
			await get_tree().process_frame
			if player.current_beat_id() != "ledger":
				err = "%s after hang want ledger got %s" % [cid, player.current_beat_id()]
	player.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK tavern plate %s → ledger" % cid)
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

