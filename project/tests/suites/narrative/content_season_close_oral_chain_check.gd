extends Node
## Hub → 章末 ledger 收束口头 `_cls` → 回到灰旗堡。
## S01–S10 二十章：战后回家、章末收束、季尾灯影。不碰开场 `_thm`、二拍、访月、战拍 `_bpl`、酒馆 `_tvp`、入谱回程 `_ldg`。
## 禁 EmptyHost / month_echo，禁跨章套话。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"

const BANNED := [
	"存档不刊也行。不丢，就是缝。",
	"你留下两行。议会仍爱一行。柜子认灯。",
	"更还在交。下次挂嗣，下行先响。",
	"侧室回执还在。红脸还诚实。",
	"并排入柜。裁半本的，我不收。",
	"下次挂嗣，下行先响。",
	"擦过急圈的墙，更值钱。",
	"催条再来，封面压得住。",
	"灯还在。灯在，这一季就还没把人骗完。",
	"灯还在。灯在，就还没骗完这一季。",
	"灯还在。灯在，这一季就还没骗完。",
	"下次挂嗣，下行先响。响了再谈名。",
]

## home = 战后回家 `_cls1`；close = 章末收束 `_cls8`（季尾灯影在 `_cls7`，说话人苇原·灯影）。
const ROWS := [
	{"cid": "cs01_01", "home": "厅前那一锋收了。巷口的脚声没再跟来。", "close": "无按进去了。我把西阁的灯捻小，人回堡。"},
	{"cid": "cs01_02", "home": "桥上的锋停了。吴钩的影子缩回桥栏。", "close": "副页进柜。桥上的欠，今天补到边角为止。"},
	{"cid": "cs02_01", "home": "院墙外的影子散了。婚约灯还在廊下，没被风吹灭。", "close": "两行都在匣里。产房的灯我不提前报，先回家。"},
	{"cid": "cs02_02", "home": "护脉的那一锋停在桥心。纸上的跳，这回听得见。", "close": "偏格按平了。谁要结论，明天带着条来，今晚回。"},
	{"cid": "cs03_01", "home": "桥铃不响了。拓片收回袖里，粮袋还沉在肩上。", "close": "袋还在肩上。功和粮都进册，我回仓门那边睡。"},
	{"cid": "cs03_02", "home": "护粮的人散回坡下。袋口扎紧，谷壳香还在袖里。", "close": "榜阴夹好了。假数留在风里，人不跟去捡。"},
	{"cid": "cs03_03", "home": "护工的人散回坡下。袋口扎紧，泥香还在袖里。", "close": "工账夹好了。假数留在风里，人不跟去捡。"},
	{"cid": "cs04_01", "home": "门廊的步走完了。训条还在牌上，没被人揭走。", "close": "绣词留在门外。我带着今天的步数回屋。"},
	{"cid": "cs04_02", "home": "契上的墨干了。干了的字，才跟着人离开门廊。", "close": "契角压平，人就走。墨干了，不用守着看。"},
	{"cid": "cs04_03", "home": "契上的墨干了。干了的字，才跟着人离开门廊。碑廊认。", "close": "契角压平，人就走。墨干了，不用守着看。碑空守。"},

	{"cid": "cs05_01", "home": "问座的人退到椅后。椅子还空着，空得干净。", "close": "椅子空着我才走。名的事，明天再对，今晚不坐。"},
	{"cid": "cs05_02", "home": "回读页前没有人再抽链。链还并排，页还没干透。", "close": "回读页还潮。潮着我也回，不站到它干。"},
	{"cid": "cs05_03", "home": "契上的墨干了。干了的字，才跟着人离开门廊。空栏认。", "close": "契角压平，人就走。墨干了，不用守着看。椅空守。"},
	{"cid": "cs06_03", "home": "契上的墨干了。干了的字，才跟着人离开门廊。空桩认。", "close": "契角压平，人就走。墨干了，不用守着看。桩空守。"},
	{"cid": "cs06_01", "home": "校场上的尘往下落。鼓不响，人才能把脚从圈里迈出来。", "close": "鼓停了人才走。胜名没钉上，旗带回旗杆下。"},
	{"cid": "cs06_02", "home": "场边没有新写的胜名。空条还空着，旗才从地上捡起来。", "close": "空条还空着。我把册子合上，不在酒醒前填。"},
	{"cid": "cs07_01", "home": "礼序牌前的人退开了。路还在，路名没有抢先钉上。", "close": "路走到门槛为止。名字的事，不在灯下抢。"},
	{"cid": "cs07_02", "home": "续谱的笔停在半空。人还没齐，空条就还空着。", "close": "人没齐，谱就合上。齐了的那天再续，不今晚。"},
	{"cid": "cs08_01", "home": "祠阶上的问声停了。香还稳，碑名没有被谁喊上去。", "close": "香稳过我就离开祠阶。碑名不在路上补。"},
	{"cid": "cs08_02", "home": "拓纸按在碑上，风没有把它掀走。手上的凉还在。", "close": "拓纸进柜，缺角不补。手凉着回去，正好。"},
	{"cid": "cs09_01", "home": "墙边问血的人散了。谁的血，谁的名，问清了才离墙。", "close": "自己的血认过了。新泼的留在案上，人不带回去。"},
	{"cid": "cs09_02", "home": "血案前的第二问结束了。巾上两星已干，墙边没有人再拦。", "close": "两星都干了，册可以合。第三笔今晚不添。"},
	{"cid": "cs10_01", "home": "印案前的手稳住了。场清了，印还停在案上，不急着盖。", "close": "边验过，印慢盖。毛刺留在盒里，人先回。"},
	{"cid": "cs10_02", "home": "第二圈印泥干得干净。催盖的人退到门边，案上只剩空框。", "close": "第二圈干了才夹进柜。催印的话，我留在门外。"},
]

const SPEAKERS := ["旁白", "老旗手", "石垒·晚担", "槐里·青禾", "老管事", "岁吏", "苇原·灯影", "leader"]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_close_oral_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON CLOSE ORAL CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_all()
	if err != "":
		return err
	err = await _hub_entry()
	if err != "":
		return err
	for row in ROWS:
		err = await _close_leg(row)
		if err != "":
			return err
	return ""


func _cls_id(cid: String, n: int) -> String:
	return "%s_cls%d" % [cid.replace("_", ""), n]


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


func _ledger(data: Dictionary):
	for beat in data.get("beats", []):
		if str(beat.get("id", "")) == "ledger":
			return beat
	return null


func _reachable_ledger(data: Dictionary) -> bool:
	var beats := {}
	var jumps := {}
	var first := ""
	for beat in data.get("beats", []):
		var bid := str(beat.get("id", ""))
		if first == "":
			first = bid
		beats[bid] = str(beat.get("next", ""))
		var outs: Array = []
		for action in beat.get("actions", []):
			if typeof(action) != TYPE_DICTIONARY:
				continue
			for step in action.get("do", []):
				if typeof(step) == TYPE_DICTIONARY and str(step.get("op", "")) == "goto":
					var target := str(step.get("beat", ""))
					if target != "" and target != "next":
						outs.append(target)
		jumps[bid] = outs
	var seen := {first: true}
	var queue: Array = [first]
	while not queue.is_empty():
		var cur: String = str(queue.pop_front())
		if cur == "ledger":
			return true
		var nxt := str(beats.get(cur, ""))
		if nxt != "" and not seen.has(nxt):
			seen[nxt] = true
			queue.append(nxt)
		for hop in jumps.get(cur, []):
			var hop_s := str(hop)
			if hop_s != "" and not seen.has(hop_s):
				seen[hop_s] = true
				queue.append(hop_s)
	return false


func _static_all() -> String:
	if StoryCatalog.content_season_entries().size() != ROWS.size():
		return "catalog %d" % StoryCatalog.content_season_entries().size()
	var seen := {}
	for row in ROWS:
		var err := _static_one(row, seen)
		if err != "":
			return err
	print("OK static close-oral ×%d" % ROWS.size())
	return ""


func _static_one(row: Dictionary, seen: Dictionary) -> String:
	var cid := str(row["cid"])
	var data = _chapter(cid)
	if typeof(data) == TYPE_STRING:
		return str(data)
	var err := _static_chapter_shell(cid, data, seen)
	if err != "":
		return err
	return _static_ledger_tail(cid, data, row)


func _static_chapter_shell(cid: String, data: Dictionary, seen: Dictionary) -> String:
	if str(data.get("return_scene", "")) != HUB:
		return "%s return_scene" % cid
	var body := FileAccess.get_file_as_string("res://data/story/chapters/%s.json" % cid)
	if body.find("EmptyHost") >= 0 or body.find("month_echo") >= 0:
		return "%s residue" % cid
	for banned in BANNED:
		if body.find(str(banned)) >= 0:
			return "%s banned filler" % cid
	for beat_row in data.get("beats", []):
		for line in beat_row.get("lines", []):
			var text := str(line.get("text", ""))
			if text == "":
				return "%s empty line" % cid
			if seen.has(text):
				return "echo %s == %s:%s" % [seen[text], cid, str(line.get("id", ""))]
			seen[text] = "%s:%s" % [cid, str(line.get("id", ""))]
	if not _reachable_ledger(data):
		return "%s ledger unreachable" % cid
	return ""


func _static_ledger_tail(cid: String, data: Dictionary, row: Dictionary) -> String:
	var beat = _ledger(data)
	if beat == null:
		return "%s no ledger" % cid
	if str(beat.get("next", "")) != "":
		return "%s ledger has next" % cid
	if not (beat.get("actions", []) as Array).is_empty():
		return "%s ledger has actions" % cid
	var lines: Array = beat.get("lines", [])
	if lines.size() < 8:
		return "%s ledger short" % cid
	var tail: Array = lines.slice(lines.size() - 8, lines.size())
	var err := _static_cls_rows(cid, tail)
	if err != "":
		return err
	if str(tail[0].get("text", "")) != str(row["home"]):
		return "%s home needle" % cid
	if str(tail[7].get("text", "")) != str(row["close"]):
		return "%s close needle" % cid
	if str(tail[7].get("speaker", "")) == "旁白":
		return "%s close narrator" % cid
	if str(tail[6].get("text", "")).find("灯") < 0:
		return "%s lamp line missing 灯" % cid
	return ""


func _static_cls_rows(cid: String, tail: Array) -> String:
	for n in range(8):
		var line = tail[n]
		var lid := str(line.get("id", ""))
		var text := str(line.get("text", ""))
		var speaker := str(line.get("speaker", ""))
		if lid != _cls_id(cid, n + 1):
			return "%s tail id %s" % [cid, lid]
		if line.has("when"):
			return "%s cls gated %s" % [cid, lid]
		if speaker != str(SPEAKERS[n]):
			return "%s speaker %s" % [cid, lid]
		if _hanzi(text) < 8 or _hanzi(text) > 60:
			return "%s hanzi %s" % [cid, lid]
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


func _close_leg(row: Dictionary) -> String:
	var cid := str(row["cid"])
	var home := str(row["home"])
	var close := str(row["close"])
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	var player = await _spawn(cid, "ledger")
	var err := ""
	if player.current_beat_id() != "ledger":
		err = "%s want ledger got %s" % [cid, player.current_beat_id()]
	if err == "":
		err = await _see_pair(player, home, close)
	if err == "":
		if str(player._body.text).strip_edges() == "":
			err = "%s empty close" % cid
		elif not player.simulate_press_action_containing("灰旗堡"):
			err = "%s hub return missing labels=%s" % [cid, str(player.action_labels())]
		else:
			await get_tree().process_frame
			var scene := str(player.test_capture.get("scene", ""))
			if scene != HUB:
				err = "%s return scene %s" % [cid, scene]
	player.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK close-oral %s → hub" % cid)
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


func _see_pair(player, home: String, close: String) -> String:
	var saw_home := false
	var guard := 0
	while guard < 180:
		var body := str(player._body.text)
		if body.find(home) >= 0:
			saw_home = true
		if body.find(close) >= 0:
			if not saw_home:
				return "close before home body=%s" % body
			return ""
		if not player.tap_advance():
			return "stuck beat=%s home=%s body=%s" % [player.current_beat_id(), saw_home, body]
		guard += 1
	return "needles not reached"
