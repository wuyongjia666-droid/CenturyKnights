extends Node
## Hub → 章 → 战/访 → 回（酒馆）：S01–S10 二十章真链路。
## 中章对白（ledger 除外）不得跨拍/跨章复读；试锋失败不写 month_echo.battle。
## 断在 chip、回章拍、锋收回来、胜后继续、据点往返、或口头针时失败。

const PLAYER := "res://scenes/story/chapter_player.tscn"
const HUB := "res://scenes/hub/castle_hub.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const HOURGLASS := "res://scenes/hub/hourglass.tscn"
const FIRST_LABEL := "先试一锋"
const RETRY_LABEL := "再试锋镝"
const VISIT_LABEL := "去看月份怎么往前走"
const MAP_ID := "quest_bandit"
const LOSS_NEEDLE := "锋收回来"

const BANNED := [
	"更还在交。下行先响。",
	"篇幅不够就钉墙。墙比名册宽。",
	"两张纸在风里响。你选怎么收这一季。",
	"议会要听念。栏要写得正，写得能念。",
	"旗册誊栏。旗角不给人卖名。",
	"并排钉。谁撕下行，谁结账。",
	"议会爱一行。两行最好活。",
	"两行都留。去门廊。",
	"牌比纸硬。纸比嘴硬。",
	"谎抄不住。孩子会问为什么空。",
	"闲话快。对照慢。慢的留下。",
	"带牌。去酒馆。",
	"写好看不难。站得住才难。",
	"空着才诚实。写满却站不上去，才是骗人。",
	"烽火酒馆。碗沿两个圈：并排记，先钉名。",
	"灯花爆了一下。爆完，字才肯站住。",
	"假亮捂不热。这格只留真。",
	"我走实步。",
	"碑阴潮。潮处字口更深。",
	"血验灯晃了一下。",
	"印泥盖子轻响。",
	"响说明刚用过。",
	"刚用过的我验边。",
	"更还在交。下行先响，上行后听。",
]

const CHAINS := [
	{
		"cid": "cs01_01",
		"order": "battle_then_visit",
		"battle": "hall",
		"after_battle": "audit",
		"battle_line": "cs01_hall_y23",
		"visit": "audit",
		"after_visit": "tavern",
		"visit_line": "cs01_audit_y22",
		"tavern_line": "cs01_tav_y20",
	},
	{
		"cid": "cs01_02",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs01_02_bridge_y21",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs01_02_hourglass_y18",
		"tavern_line": "cs01_02_tavern_y19",
	},
	{
		"cid": "cs02_01",
		"order": "battle_then_visit",
		"battle": "estate",
		"after_battle": "birth",
		"battle_line": "cs02_estate_y22",
		"visit": "birth",
		"after_visit": "tavern",
		"visit_line": "cs02_birth_y22",
		"tavern_line": "cs02_tavern_y21",
	},
	{
		"cid": "cs02_02",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs02_02_bridge_y21",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs02_02_hourglass_y18",
		"tavern_line": "cs02_02_tavern_y19",
	},
	{
		"cid": "cs03_01",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs03_mid_y19",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs03_hg_2",
		"tavern_line": "cs03_tavern_y19",
	},
	{
		"cid": "cs03_02",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs03_02_bridge_y21",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs03_02_hourglass_y18",
		"tavern_line": "cs03_02_tavern_y19",
	},
	{
		"cid": "cs04_01",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs04_mid_y19",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs04_hg_2",
		"tavern_line": "cs04_tavern_y19",
	},
	{
		"cid": "cs04_02",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs04_02_bridge_y21",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs04_02_hourglass_y18",
		"tavern_line": "cs04_02_tavern_y19",
	},
	{
		"cid": "cs05_01",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs05_bridge_x2",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs05_hourglass_x3",
		"tavern_line": "cs05_tavern_y18",
	},
	{
		"cid": "cs05_02",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs05b_br_1",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs05b_hg_1",
		"tavern_line": "cs0502_ret_mv4",
	},
	{
		"cid": "cs06_01",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs06_br_1",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs06_hg_1",
		"tavern_line": "cs06_tavern_x7",
	},
	{
		"cid": "cs06_02",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs06b_br_1",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs06b_hg_1",
		"tavern_line": "cs0602_ret_mv4",
	},
	{
		"cid": "cs07_01",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs07_br_1",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs07_hg_1",
		"tavern_line": "cs07_tavern_x8",
	},
	{
		"cid": "cs07_02",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs07b_br_1",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs07b_hg_1",
		"tavern_line": "cs0702_ret_mv4",
	},
	{
		"cid": "cs08_01",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs08_br_1",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs08_hg_1",
		"tavern_line": "cs08_tavern_y18",
	},
	{
		"cid": "cs08_02",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs08b_br_y22",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs08b_ho_y21",
		"tavern_line": "cs08b_ta_y22",
	},
	{
		"cid": "cs09_01",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs09_br_1",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs09_hg_1",
		"tavern_line": "cs09_tavern_y18",
	},
	{
		"cid": "cs09_02",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs09b_br_y22",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs09b_ho_y21",
		"tavern_line": "cs09b_ta_y22",
	},
	{
		"cid": "cs10_01",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs10_br_1",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs10_hg_1",
		"tavern_line": "cs10_tavern_y18",
	},
	{
		"cid": "cs10_02",
		"order": "visit_then_battle",
		"battle": "bridge",
		"after_battle": "tavern",
		"battle_line": "cs10b_br_y22",
		"visit": "hourglass",
		"after_visit": "bridge",
		"visit_line": "cs10b_ho_y21",
		"tavern_line": "cs10b_ta_y22",
	},
]


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL content_season_mid_oral_chain: ", err)
		get_tree().quit(1)
		return
	print("CONTENT SEASON MID ORAL CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _static_oral()
	if err != "":
		return err
	err = await _hub_chips()
	if err != "":
		return err
	for row in CHAINS:
		err = await _chain_one(row)
		if err != "":
			return err
	return ""


func _chapter(cid: String):
	var path := "res://data/story/chapters/%s.json" % cid
	if not FileAccess.file_exists(path):
		return "missing %s" % cid
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return "parse %s" % cid
	return data


func _line_text(data: Dictionary, line_id: String) -> String:
	for beat in data.get("beats", []):
		for line in beat.get("lines", []):
			if str(line.get("id", "")) == line_id:
				return str(line.get("text", ""))
	return ""


func _static_oral() -> String:
	if StoryCatalog.content_season_entries().size() != CHAINS.size():
		return "catalog entries %d want %d" % [StoryCatalog.content_season_entries().size(), CHAINS.size()]
	var seen := {}
	for row in CHAINS:
		var err := _static_one(row, seen)
		if err != "":
			return err
	print("OK static oral unique ×%d banned=%d" % [CHAINS.size(), BANNED.size()])
	return ""


func _static_one(row: Dictionary, seen: Dictionary) -> String:
	var cid := str(row["cid"])
	var data = _chapter(cid)
	if typeof(data) == TYPE_STRING:
		return str(data)
	if str(data.get("return_scene", "")) != HUB:
		return "%s return_scene" % cid
	var body := FileAccess.get_file_as_string("res://data/story/chapters/%s.json" % cid)
	if body.find("EmptyHost") >= 0:
		return "%s EmptyHost" % cid
	if body.find("month_echo") >= 0:
		return "%s month_echo residue" % cid
	var plate_n := 0
	for beat in data.get("beats", []):
		var bid := str(beat.get("id", ""))
		if bid == "ledger":
			continue
		var vis: Array = []
		for line in beat.get("lines", []):
			var text := str(line.get("text", ""))
			for banned in BANNED:
				if text == str(banned):
					return "%s banned %s" % [cid, banned]
			var key := text
			if seen.has(key):
				return "echo %s == %s (%s)" % [seen[key], "%s:%s:%s" % [cid, bid, str(line.get("id", ""))], text]
			seen[key] = "%s:%s:%s" % [cid, bid, str(line.get("id", ""))]
			if not line.has("when"):
				vis.append(line)
		if plate_n < 3:
			if vis.is_empty():
				return "%s %s empty plate" % [cid, bid]
			if str(vis.back().get("speaker", "")) == "旁白":
				return "%s %s plate-final narrator" % [cid, bid]
			plate_n += 1
	for key in ["battle_line", "visit_line", "tavern_line"]:
		var lid := str(row[key])
		if _line_text(data, lid) == "":
			return "%s missing line %s" % [cid, lid]
	var stamp := _battle_stamp(data)
	if str(stamp["fought"]) == "" or str(stamp["lost"]) == "":
		return "%s battle flags" % cid
	if _win_oral(data, str(stamp["fought"])) == "":
		return "%s win oral ungated on %s" % [cid, str(stamp["fought"])]
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


func _chain_one(row: Dictionary) -> String:
	var cid := str(row["cid"])
	var data = _chapter(cid)
	if typeof(data) != TYPE_STRING:
		pass
	else:
		return str(data)
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.set_flag("hub_open")
	StoryCatalog.request_chapter(cid)
	var stamp := _battle_stamp(data)
	var err := ""
	if str(row["order"]) == "battle_then_visit":
		err = await _battle_leg(
			cid,
			str(row["battle"]),
			str(row["after_battle"]),
			_line_text(data, str(row["battle_line"])),
			str(stamp["fought"]),
			str(stamp["lost"]),
			_win_oral(data, str(stamp["fought"])),
		)
		if err != "":
			return err
		err = await _visit_leg(cid, str(row["visit"]), str(row["after_visit"]), _line_text(data, str(row["visit_line"])))
		if err != "":
			return err
	else:
		err = await _visit_leg(cid, str(row["visit"]), str(row["after_visit"]), _line_text(data, str(row["visit_line"])))
		if err != "":
			return err
		err = await _battle_leg(
			cid,
			str(row["battle"]),
			str(row["after_battle"]),
			_line_text(data, str(row["battle_line"])),
			str(stamp["fought"]),
			str(stamp["lost"]),
			_win_oral(data, str(stamp["fought"])),
		)
		if err != "":
			return err
	err = await _tavern_needle(cid, _line_text(data, str(row["tavern_line"])))
	if err != "":
		return err
	print("OK mid-oral chain %s (%s)" % [cid, str(row["order"])])
	return ""


func _spawn(cid: String, beat: String):
	# chapter_player._resolve_path consumes story_chapter_id. Re-request before
	# every spawn so a freed player cannot fall through to ch0 beat 0.0.
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
	if needle == "":
		return "empty needle"
	var guard := 0
	while guard < 90:
		if str(player._body.text).find(needle) >= 0:
			return ""
		if not player.tap_advance():
			return "needle missing %s at %s body=%s" % [needle, player.current_beat_id(), str(player._body.text)]
		guard += 1
	return "needle not reached %s" % needle


func _echo_quiet(cid: String, where: String) -> String:
	GameState.house_mods.erase("month_echo")
	if BattleVictory.maybe_note_month_echo_battle(true, "山匪", 40, false, false):
		return "%s %s month_echo.battle written" % [cid, where]
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("battle", "")) != "":
		return "%s %s month_echo residue" % [cid, where]
	GameState.house_mods.erase("month_echo")
	return ""


func _battle_leg(cid: String, mid: String, after: String, needle: String, fought: String, lost: String, win_oral: String) -> String:
	var player = await _spawn(cid, mid)
	var err := _ready_beat(player, cid, mid)
	if err == "":
		err = _see(player, needle)
	if err == "":
		player.simulate_finish_dialogue()
		await get_tree().process_frame
		if not player.simulate_press_action_containing(FIRST_LABEL):
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
				err = "%s loss flag missing" % cid
			else:
				err = _echo_quiet(cid, "loss")
	player.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	GameState.set_meta("battle_return_chapter", cid)
	var p2 = await _spawn(cid, mid)
	if p2.current_beat_id() != mid:
		err = "%s loss reopen %s" % [cid, p2.current_beat_id()]
	else:
		p2.skip_lines()
		await get_tree().process_frame
		if str(p2._body.text).find(LOSS_NEEDLE) < 0:
			err = "%s loss needle %s" % [cid, str(p2._body.text)]
		elif p2.action_labels().find(RETRY_LABEL) < 0:
			p2.simulate_finish_dialogue()
			await get_tree().process_frame
			if p2.action_labels().find(RETRY_LABEL) < 0:
				err = "%s retry CTA %s" % [cid, str(p2.action_labels())]
		if err == "" and not p2.simulate_press_action_containing(RETRY_LABEL):
			err = "%s retry press" % cid
		elif err == "":
			await get_tree().process_frame
			BattleVictory.apply(MAP_ID)
			if not GameState.flag(fought):
				err = "%s win flag missing" % cid
			elif GameState.flag(lost):
				err = "%s mid_lost residue" % cid
			elif GameState.flag(MAP_ID + "_lost"):
				err = "%s map_lost residue" % cid
			else:
				err = _echo_quiet(cid, "win")
	p2.queue_free()
	await get_tree().process_frame
	if err != "":
		return err
	GameState.set_meta("battle_return_chapter", cid)
	var p3 = await _spawn(cid, mid)
	p3.simulate_finish_dialogue()
	await get_tree().process_frame
	var labels: Array = p3.action_labels()
	if win_oral != "" and str(p3._body.text).find(win_oral) < 0:
		err = "%s win oral hidden got %s" % [cid, str(p3._body.text)]
	elif labels.find(FIRST_LABEL) >= 0 or labels.find(RETRY_LABEL) >= 0:
		err = "%s after-win CTA %s" % [cid, str(labels)]
	elif not p3.simulate_press_action_containing("继续"):
		err = "%s after-win continue %s" % [cid, str(labels)]
	else:
		await get_tree().process_frame
		if p3.current_beat_id() != after:
			err = "%s after-win want %s got %s" % [cid, after, p3.current_beat_id()]
	p3.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK oral battle %s @%s → %s" % [cid, mid, after])
	return err


func _visit_leg(cid: String, visit_beat: String, after: String, needle: String) -> String:
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
				err = "%s visit-continue want %s got %s" % [cid, after, p2.current_beat_id()]
	p2.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK oral visit %s @%s → %s" % [cid, visit_beat, after])
	return err


func _tavern_needle(cid: String, needle: String) -> String:
	var player = await _spawn(cid, "tavern")
	var err := _ready_beat(player, cid, "tavern")
	if err == "":
		err = _see(player, needle)
	player.queue_free()
	await get_tree().process_frame
	if err == "":
		print("OK oral tavern %s" % cid)
	return err


func _ready_beat(player, cid: String, beat: String) -> String:
	if player.current_beat_id() != beat:
		return "%s beat want %s got %s" % [cid, beat, player.current_beat_id()]
	return ""
