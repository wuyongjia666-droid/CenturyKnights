extends Node
## Visit/hourglass 名著加厚：静态度唯一口头 + hub chip + 活路径
## 去看月份 → hourglass → 同拍回 → 继续。禁 EmptyHost / month_echo。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"
const HOURGLASS := "res://scenes/hub/hourglass.tscn"
const VISIT_LABEL := "去看月份怎么往前走"

const CHAINS := [
	{
		"cid": "cs01_01",
		"beat": "audit",
		"after": "tavern",
		"needle": "沙漏旁摊着回执底联。底联空着岁课栏，像等人敢写无。",
	},
	{
		"cid": "cs01_02",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "副页压在正页下。正页有字，副页空行，像并排的两盏。",
	},
	{
		"cid": "cs02_01",
		"beat": "birth",
		"after": "tavern",
		"needle": "婚约上的并排栏等月份。月份走，栏不替人点头。",
	},
	{
		"cid": "cs02_02",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "副笺比正笺薄。薄处更见字，也更见空。",
	},
	{
		"cid": "cs03_01",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "榜上的收成栏等月份盖印。印未落，数还是数。",
	},
	{
		"cid": "cs03_02",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "榜阴贴着正榜。阴面的空，比阳面更刺眼。",
	},
	{
		"cid": "cs03_03",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "工账贴着功面。工面的空，比功面更刺眼。",
	},
	{
		"cid": "cs04_01",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "家训卷轴立在沙漏侧。训条要月份来验，不靠背熟。",
	},
	{
		"cid": "cs04_02",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "训阴写在轴背。背着的字，要翻过来才见。",
	},
	{
		"cid": "cs04_03",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "训堂写在轴背。背着的字，要翻过来才见。",
	},

	{
		"cid": "cs05_01",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "空椅扶手凉。月份从扶手上滚过去，椅还是空。",
	},
	{
		"cid": "cs05_02",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "回读页夹着空椅图。图上无人，沙漏仍走。",
	},
	{
		"cid": "cs05_03",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "嗣庭写在轴背。背着的字，要翻过来才见。",
	},
	{
		"cid": "cs06_03",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "沙圈写在轴背。背着的字，要翻过来才见。",
	},
	{
		"cid": "cs07_03",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "盖印写在轴背。背着的字，要翻过来才见。",
	},
	{
		"cid": "cs08_03",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "香龛写在轴背。背着的字，要翻过来才见。",
	},
	{
		"cid": "cs06_01",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "校场册摊在沙漏下。胜负栏空，鼓却先响。",
	},
	{
		"cid": "cs06_02",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "胜册副页薄。薄页上的空，像没打完的一鼓。",
	},
	{
		"cid": "cs07_01",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "仪典簿靠着沙漏。礼序栏空，香却先燃。",
	},
	{
		"cid": "cs07_02",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "宗谱副页写着未续。未续不是忘，是还没人敢接。",
	},
	{
		"cid": "cs08_01",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "祖祠香案旁是沙漏。碑文要月份来扫，不靠默念。",
	},
	{
		"cid": "cs08_02",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "碑阴潮着。潮处的空行，比阳面更清楚。",
	},
	{
		"cid": "cs09_01",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "血验册摊开。验栏空，针却先亮。",
	},
	{
		"cid": "cs09_02",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "验册副页薄。薄页上的空，像未刺的第二针。",
	},
	{
		"cid": "cs10_01",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "印匣靠沙漏。印泥未动，月份先走。",
	},
	{
		"cid": "cs10_02",
		"beat": "hourglass",
		"after": "bridge",
		"needle": "印底拓着空框。框在，印未落。",
	},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_visit_oral_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON VISIT ORAL CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_oral()
	if err != "":
		return err
	err = await _hub_chips()
	if err != "":
		return err
	for row in CHAINS:
		err = await _visit_leg(
			str(row["cid"]), str(row["beat"]), str(row["after"]), str(row["needle"]))
		if err != "":
			return err
	return ""


func _static_oral() -> String:
	if StoryCatalog.content_season_entries().size() != CHAINS.size():
		return "catalog entries %d want %d" % [
			StoryCatalog.content_season_entries().size(), CHAINS.size()]
	var seen := {}
	for row in CHAINS:
		var err := _static_one(row, seen)
		if err != "":
			return err
	print("OK static visit-oral unique ×%d" % CHAINS.size())
	return ""


func _static_one(row: Dictionary, seen: Dictionary) -> String:
	var cid := str(row["cid"])
	var path := "res://data/story/chapters/%s.json" % cid
	if not FileAccess.file_exists(path):
		return "missing %s" % cid
	var body := FileAccess.get_file_as_string(path)
	if body.find("EmptyHost") >= 0:
		return "%s EmptyHost" % cid
	if body.find("month_echo") >= 0:
		return "%s month_echo residue" % cid
	var data = JSON.parse_string(body)
	if typeof(data) != TYPE_DICTIONARY:
		return "parse %s" % cid
	if str(data.get("return_scene", "")) != HUB:
		return "%s return_scene" % cid
	var needle := str(row["needle"])
	var found := false
	var want_beat := str(row["beat"])
	for beat in data.get("beats", []):
		var bid := str(beat.get("id", ""))
		if bid == "ledger":
			continue
		for line in beat.get("lines", []):
			var text := str(line.get("text", ""))
			if text == "":
				continue
			if seen.has(text):
				return "echo %s == %s" % [seen[text], "%s:%s" % [cid, bid]]
			seen[text] = "%s:%s:%s" % [cid, bid, str(line.get("id", ""))]
			if bid == want_beat and text == needle:
				found = true
	if not found:
		return "%s missing needle on %s" % [cid, want_beat]
	return ""


func _hub_chips() -> String:
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
		await get_tree().process_frame
		return "ContentSeasonRow missing"
	if hub.has_method("_open_content_season_sheet"):
		hub.call("_open_content_season_sheet")
		await get_tree().process_frame
		await get_tree().process_frame
	for row in CHAINS:
		var cid := str(row["cid"])
		if hub.find_child("Season_%s" % cid, true, false) == null:
			hub.queue_free()
			await get_tree().process_frame
			return "hub chip %s missing" % cid
	hub.queue_free()
	await get_tree().process_frame
	print("OK hub chips ×%d" % CHAINS.size())
	return ""


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


func _ready_beat(player, cid: String, beat: String) -> String:
	if player.current_beat_id() != beat:
		return "%s want beat %s got %s" % [cid, beat, player.current_beat_id()]
	return ""


func _see(player, needle: String) -> String:
	if needle == "":
		return "empty needle"
	var guard := 0
	while guard < 90:
		if str(player._body.text).find(needle) >= 0:
			return ""
		if not player.tap_advance():
			return "needle missing %s at %s body=%s" % [
				needle, player.current_beat_id(), str(player._body.text)]
		guard += 1
	return "needle not reached %s" % needle


func _visit_leg(cid: String, visit_beat: String, after: String, needle: String) -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	var player = await _spawn(cid, visit_beat)
	var err := _ready_beat(player, cid, visit_beat)
	if err == "":
		err = _see(player, needle)
	if err == "":
		player.simulate_finish_dialogue()
		await get_tree().process_frame
		if not player.simulate_press_action_containing(VISIT_LABEL):
			err = "%s visit press %s" % [cid, str(player.action_labels())]
	if err == "":
		await get_tree().process_frame
		if str(player.test_capture.get("scene", "")) != HOURGLASS:
			err = "%s visit scene %s" % [cid, str(player.test_capture.get("scene", ""))]
		elif str(GameState.get_meta("story_return_chapter", "")) != cid:
			err = "%s story_return_chapter" % cid
		elif str(GameState.get_meta("story_return", "")) != StoryCatalog.player_scene():
			err = "%s story_return %s" % [cid, str(GameState.get_meta("story_return", ""))]
		else:
			var ret := StoryCatalog.take_story_return(HUB)
			if ret != StoryCatalog.player_scene():
				err = "%s take %s" % [cid, ret]
			elif GameState.story.season_beat(cid) != visit_beat:
				err = "%s cursor %s" % [cid, GameState.story.season_beat(cid)]
	player.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	var p2 = await _spawn(cid, visit_beat)
	if p2.current_beat_id() != visit_beat:
		err = "%s visit reopen %s" % [cid, p2.current_beat_id()]
	else:
		p2.simulate_finish_dialogue()
		await get_tree().process_frame
		if not p2.simulate_press_action_containing("继续"):
			err = "%s visit-continue %s" % [cid, str(p2.action_labels())]
		else:
			await get_tree().process_frame
			if p2.current_beat_id() != after:
				err = "%s visit-continue want %s got %s" % [
					cid, after, p2.current_beat_id()]
	p2.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK visit-oral chain %s @%s → %s" % [cid, visit_beat, after])
	return err
