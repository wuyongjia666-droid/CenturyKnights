extends Node
## Hub → 章入口 → 中途战拍口头 → 试锋败/胜 → 回下一拍。
## S01–S10 二十章战拍 `_bpl` 名著口头必须能点到，且战拍不再出现门廊套话。
## 不碰 visit/hourglass（#522）与 ledger（#514）。禁 EmptyHost / month_echo。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const FIRST_LABEL := "先试一锋"
const RETRY_LABEL := "再试锋镝"
const LOSS_NEEDLE := "锋收回来"
const MAP_ID := "quest_bandit"

const FILLER := [
	"只问你手稳不稳",
	"锋镝在桥上试",
	"桥风大。灯小",
	"墙牌两行一起响",
	"桥木响。响的是鞋",
	"干净靴也留痕",
	"醒着才选得动",
	"谁加字，我认指甲",
	"·婚盏",
	"·朝报",
	"·家训",
	"未试锋——锋未出鞘",
	"试锋未成——伤还在",
]

## battle = 中途战拍；after = 胜后「继续」落地拍。
const ROWS := [
	{"cid": "cs01_01", "battle": "hall", "after": "audit"},
	{"cid": "cs01_02", "battle": "bridge", "after": "tavern"},
	{"cid": "cs02_01", "battle": "estate", "after": "birth"},
	{"cid": "cs02_02", "battle": "bridge", "after": "tavern"},
	{"cid": "cs03_01", "battle": "bridge", "after": "tavern"},
	{"cid": "cs03_02", "battle": "bridge", "after": "tavern"},
	{"cid": "cs03_03", "battle": "bridge", "after": "tavern"},
	{"cid": "cs04_01", "battle": "bridge", "after": "tavern"},
	{"cid": "cs04_02", "battle": "bridge", "after": "tavern"},
	{"cid": "cs04_03", "battle": "bridge", "after": "tavern"},

	{"cid": "cs05_01", "battle": "bridge", "after": "tavern"},
	{"cid": "cs05_02", "battle": "bridge", "after": "tavern"},
	{"cid": "cs05_03", "battle": "bridge", "after": "tavern"},
	{"cid": "cs06_03", "battle": "bridge", "after": "tavern"},
	{"cid": "cs06_01", "battle": "bridge", "after": "tavern"},
	{"cid": "cs06_02", "battle": "bridge", "after": "tavern"},
	{"cid": "cs07_01", "battle": "bridge", "after": "tavern"},
	{"cid": "cs07_02", "battle": "bridge", "after": "tavern"},
	{"cid": "cs08_01", "battle": "bridge", "after": "tavern"},
	{"cid": "cs08_02", "battle": "bridge", "after": "tavern"},
	{"cid": "cs09_01", "battle": "bridge", "after": "tavern"},
	{"cid": "cs09_02", "battle": "bridge", "after": "tavern"},
	{"cid": "cs10_01", "battle": "bridge", "after": "tavern"},
	{"cid": "cs10_02", "battle": "bridge", "after": "tavern"},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_battle_plate_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON BATTLE PLATE CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_plates()
	if err != "":
		return err
	err = await _hub_entry()
	if err != "":
		return err
	for row in ROWS:
		err = await _battle_chain(row)
		if err != "":
			return err
	return ""


func _plate_id(cid: String, n: int) -> String:
	return "%s_bpl%d" % [cid.replace("_", ""), n]


func _chapter(cid: String):
	var path := "res://data/story/chapters/%s.json" % cid
	if not FileAccess.file_exists(path):
		return "missing %s" % cid
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return "parse %s" % cid
	return data


func _battle_beat(data: Dictionary):
	for beat in data.get("beats", []):
		if str(beat.get("id", "")) == "":
			continue
		for action in beat.get("actions", []):
			for step in action.get("do", []):
				if typeof(step) == TYPE_DICTIONARY and str(step.get("op", "")) == "battle":
					return beat
	return null


func _hanzi(text: String) -> int:
	var n := 0
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 0x4E00 and c <= 0x9FFF:
			n += 1
	return n


func _static_plates() -> String:
	if StoryCatalog.content_season_entries().size() != ROWS.size():
		return "catalog %d" % StoryCatalog.content_season_entries().size()
	var seen := {}
	for row in ROWS:
		var err := _static_one(row, seen)
		if err != "":
			return err
	print("OK static battle plates ×%d" % ROWS.size())
	return ""


func _static_one(row: Dictionary, seen: Dictionary) -> String:
	var cid := str(row["cid"])
	var data = _chapter(cid)
	var err := ""
	if typeof(data) == TYPE_STRING:
		err = str(data)
	elif str(data.get("return_scene", "")) != HUB:
		err = "%s return_scene" % cid
	elif not _reachable(data, str(row["battle"])):
		err = "%s battle unreachable from open" % cid
	else:
		var body := FileAccess.get_file_as_string("res://data/story/chapters/%s.json" % cid)
		if body.find("EmptyHost") >= 0 or body.find("month_echo") >= 0:
			err = "%s residue" % cid
	if err == "":
		err = _static_battle(data, row)
	if err == "":
		err = _static_unique(data, cid, seen)
	return err


func _static_battle(data: Dictionary, row: Dictionary) -> String:
	var cid := str(row["cid"])
	var beat = _battle_beat(data)
	if beat == null or str(beat.get("id", "")) != str(row["battle"]):
		return "%s battle beat" % cid
	if str(beat.get("next", "")) != str(row["after"]):
		return "%s next %s" % [cid, str(beat.get("next", ""))]
	var err := _static_plate_lines(cid, beat)
	if err != "":
		return err
	for line in beat.get("lines", []):
		if str(line.get("text", "")).find(LOSS_NEEDLE) >= 0 and line.has("when"):
			return ""
	return "%s loss needle" % cid


func _static_plate_lines(cid: String, beat) -> String:
	var want := {}
	for n in range(1, 7):
		want[_plate_id(cid, n)] = n
	var found := 0
	var saw_gate := false
	var err := ""
	for line in beat.get("lines", []):
		if err != "":
			break
		var lid := str(line.get("id", ""))
		var text := str(line.get("text", ""))
		for sub in FILLER:
			if text.find(str(sub)) >= 0:
				err = "%s filler %s in %s" % [cid, sub, lid]
				break
		if err != "" or not want.has(lid):
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
	return err


func _static_unique(data: Dictionary, cid: String, seen: Dictionary) -> String:
	for beat_row in data.get("beats", []):
		if str(beat_row.get("id", "")) == "ledger":
			continue
		for line in beat_row.get("lines", []):
			var text := str(line.get("text", ""))
			if seen.has(text):
				return "echo %s == %s:%s" % [seen[text], cid, str(line.get("id", ""))]
			seen[text] = "%s:%s" % [cid, str(line.get("id", ""))]
	return ""


func _reachable(data: Dictionary, battle: String) -> bool:
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
		if cur == battle:
			return true
		cur = str(beats.get(cur, ""))
		guard += 1
	return false


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
		if str(GameState.get_meta("story_chapter_id", "")) != cid:
			hub.queue_free()
			return "%s meta" % cid
	hub.queue_free()
	await get_tree().process_frame
	print("OK hub chips ×%d" % ROWS.size())
	return ""


func _battle_chain(row: Dictionary) -> String:
	var cid := str(row["cid"])
	var battle := str(row["battle"])
	var after := str(row["after"])
	var data = _chapter(cid)
	if typeof(data) == TYPE_STRING:
		return str(data)
	var needle := ""
	var beat = _battle_beat(data)
	for line in beat.get("lines", []):
		if str(line.get("id", "")) == _plate_id(cid, 6):
			needle = str(line.get("text", ""))
	if needle == "":
		return "%s plate text" % cid
	var stamp := _battle_stamp(data)
	var fought := str(stamp["fought"])
	var lost := str(stamp["lost"])
	var win_oral := _win_oral(data, fought)
	if fought == "" or lost == "" or win_oral == "":
		return "%s flags" % cid
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	var player = await _spawn(cid, "")
	var err := await _walk_to_battle(player, cid, battle)
	if err == "":
		err = _see(player, needle)
	if err == "":
		player.simulate_finish_dialogue()
		await get_tree().process_frame
		if str(player._body.text).find(needle) < 0:
			err = "%s plate not on close %s" % [cid, str(player._body.text)]
		elif not player.simulate_press_action_containing(FIRST_LABEL):
			err = "%s battle press %s" % [cid, str(player.action_labels())]
	if err == "":
		await get_tree().process_frame
		var lose_stamped: Array = player.test_capture.get("battle_lose_flags", [])
		if str(player.test_capture.get("scene", "")) != BATTLE:
			err = "%s battle scene %s" % [cid, str(player.test_capture.get("scene", ""))]
		elif lose_stamped.size() != 1 or str(lose_stamped[0]) != lost:
			err = "%s lose_flags %s" % [cid, str(lose_stamped)]
		else:
			var back := BattleDefeat.back_path(false, false, StoryCatalog.player_scene())
			if back != StoryCatalog.player_scene():
				err = "%s loss back %s" % [cid, back]
			elif not GameState.flag(lost):
				err = "%s loss flag" % cid
			else:
				err = _echo_quiet(cid, "loss")
	player.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	GameState.set_meta("battle_return_chapter", cid)
	var reopened = await _spawn(cid, "")
	if reopened.current_beat_id() != battle:
		err = "%s loss reopen %s" % [cid, reopened.current_beat_id()]
	else:
		reopened.skip_lines()
		await get_tree().process_frame
		if str(reopened._body.text).find(LOSS_NEEDLE) < 0:
			err = "%s loss needle %s" % [cid, str(reopened._body.text)]
		elif reopened.action_labels().find(RETRY_LABEL) < 0:
			reopened.simulate_finish_dialogue()
			await get_tree().process_frame
			if reopened.action_labels().find(RETRY_LABEL) < 0:
				err = "%s retry %s" % [cid, str(reopened.action_labels())]
		if err == "" and not reopened.simulate_press_action_containing(RETRY_LABEL):
			err = "%s retry press" % cid
		elif err == "":
			await get_tree().process_frame
			BattleVictory.apply(MAP_ID)
			if not GameState.flag(fought):
				err = "%s win flag" % cid
			elif GameState.flag(lost):
				err = "%s lost residue" % cid
			elif GameState.flag(MAP_ID + "_lost"):
				err = "%s map_lost" % cid
			else:
				err = _echo_quiet(cid, "win")
	reopened.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	GameState.set_meta("battle_return_chapter", cid)
	var won = await _spawn(cid, "")
	won.simulate_finish_dialogue()
	await get_tree().process_frame
	var labels: Array = won.action_labels()
	if str(won._body.text).find(win_oral) < 0:
		err = "%s win oral %s" % [cid, str(won._body.text)]
	elif labels.find(FIRST_LABEL) >= 0 or labels.find(RETRY_LABEL) >= 0:
		err = "%s after-win CTA %s" % [cid, str(labels)]
	elif not won.simulate_press_action_containing("继续"):
		err = "%s continue %s" % [cid, str(labels)]
	else:
		await get_tree().process_frame
		if won.current_beat_id() != after:
			err = "%s after %s want %s" % [cid, won.current_beat_id(), after]
	won.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK battle plate %s @%s → %s" % [cid, battle, after])
	return err


func _walk_to_battle(player, cid: String, battle: String) -> String:
	var guard := 0
	while player.current_beat_id() != battle and guard < 8:
		player.simulate_finish_dialogue()
		await get_tree().process_frame
		if not player.simulate_press_action_containing("继续"):
			return "%s walk stuck %s %s" % [cid, player.current_beat_id(), str(player.action_labels())]
		guard += 1
		await get_tree().process_frame
	if player.current_beat_id() != battle:
		return "%s never reached %s at %s" % [cid, battle, player.current_beat_id()]
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


func _see(player, needle: String) -> String:
	var guard := 0
	while guard < 120:
		if str(player._body.text).find(needle) >= 0:
			return ""
		if not player.tap_advance():
			return "needle missing %s at %s" % [needle, player.current_beat_id()]
		guard += 1
	return "needle not reached"


func _echo_quiet(cid: String, where: String) -> String:
	GameState.house_mods.erase("month_echo")
	if BattleVictory.maybe_note_month_echo_battle(true, "山匪", 40, false, false):
		return "%s %s month_echo.battle written" % [cid, where]
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("battle", "")) != "":
		return "%s %s month_echo residue" % [cid, where]
	GameState.house_mods.erase("month_echo")
	return ""


func _battle_stamp(data: Dictionary) -> Dictionary:
	for beat in data.get("beats", []):
		for action in beat.get("actions", []):
			for op in action.get("do", []):
				if str(op.get("op", "")) != "battle":
					continue
				var wins: Array = op.get("win_flags", [])
				var loses: Array = op.get("lose_flags", [])
				return {
					"fought": str(wins[0]) if not wins.is_empty() else "",
					"lost": str(loses[0]) if not loses.is_empty() else "",
				}
	return {"fought": "", "lost": ""}


func _win_oral(data: Dictionary, fought: String) -> String:
	var last := ""
	for beat in data.get("beats", []):
		for line in beat.get("lines", []):
			var gate = line.get("when", null)
			if typeof(gate) == TYPE_DICTIONARY and str(gate.get("flag", "")) == fought:
				last = str(line.get("text", ""))
	return last
