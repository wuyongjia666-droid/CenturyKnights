extends Node
## 序章端到端：两条路线从田埂走到上路。
## 路线甲：完整引导（战斗、酒馆、委托板、舆图、联姻廷、族谱、沙漏都由故事拍送进去）。
## 路线乙：教学从简（战斗、招募、入席可直接结算），并走另一半分支。
## 断言：每个机制门都由某一拍打开；分支旗标写入存档旗标；第一纪元读得到它们。

const CH0 := "res://data/story/chapters/ch0.json"
const RET := "res://scenes/story/chapter0.tscn"

var _player

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL prologue e2e: ", err)
		get_tree().quit(1)
	else:
		print("PROLOGUE E2E PASS")
		get_tree().quit(0)

func _run() -> String:
	var err := await _route_full()
	if err != "":
		return "full route: " + err
	err = await _route_brief()
	if err != "":
		return "brief route: " + err
	return ""

func _open() -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
		await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/story/chapter_player.tscn")
	_player = packed.instantiate()
	_player.chapter_path = CH0
	_player.lock_path = true
	_player.suppress_scene_change = true
	add_child(_player)
	await get_tree().process_frame

func _press(beat: String, label: String) -> String:
	if _player.current_beat_id() != beat:
		return "at %s want %s before %s" % [_player.current_beat_id(), beat, label]
	_player.simulate_finish_dialogue()
	await get_tree().process_frame
	if not _player.simulate_press_action_containing(label):
		return "%s: no action %s in %s" % [beat, label, str(_player.action_labels())]
	await get_tree().process_frame
	return ""

func _scene_was(path: String) -> String:
	var got := str(_player.test_capture.get("scene", ""))
	_player.test_capture["scene"] = ""
	if got != path:
		return "scene %s want %s" % [got, path]
	return ""

func _resume(beat: String) -> void:
	# The side screen returns to chapter0.tscn, which reopens at the stored beat.
	GameState.set_beat(beat)
	await _open()

func _texts(beat: String) -> Array:
	_player.simulate_goto_beat(beat)
	var out: Array = []
	for line in _player._visible_lines():
		out.append(_player._line_text(line))
	return out

func _route_full() -> String:
	GameState.new_game("岑", "试旗", GameState.crest_color)
	if GameState.chapter0_beat != "0.0":
		return "new game beat " + str(GameState.chapter0_beat)
	await _open()
	if (_player.test_capture.get("stage_log", []) as Array).is_empty():
		return "opening line carried no staging cue"
	for step in [["0.0", "让这个颜色落进旗心"], ["0.05", "走向已经亮起的烽"]]:
		var e: String = await _press(step[0], step[1])
		if e != "":
			return e
	# Movement and combat: the beacon battle.
	var e1: String = await _press("0.1", "走进隘口")
	if e1 != "":
		return e1
	if str(_player.test_capture.get("battle_map", "")) != "ch0_pass":
		return "battle map %s" % str(_player.test_capture)
	if str(GameState.get_meta("battle_return", "")) != RET:
		return "battle return " + str(GameState.get_meta("battle_return", ""))
	GameState.set_flag("battle_done")
	await _resume("0.1")
	for step in [["0.1", "听烟散"], ["0.15", "跟着粮车"], ["0.17", "不换"], ["0.18", "押给账房"]]:
		var e: String = await _press(step[0], step[1])
		if e != "":
			return e
	if not GameState.flag("pro_survivor_kept") or not GameState.flag("pro_merit_own") or not GameState.flag("pro_lease_pawned"):
		return "branch flags A %s" % str(GameState.story.flags)
	return await _full_b()

func _full_b() -> String:
	# Hiring and wages: the tavern screen.
	var e2: String = await _press("0.2", "进烽火酒馆")
	if e2 != "":
		return e2
	var s2 := _scene_was("res://scenes/hub/tavern.tscn")
	if s2 != "":
		return s2
	GameState.refresh_tavern()
	GameState.silver = maxi(GameState.silver, 400)
	if not GameState.recruit(GameState.tavern_candidates[0]).get("ok", false):
		return "recruit failed"
	await _resume("0.2")
	for step in [["0.2", "让陌生人站进队列"], ["0.25", "入驻灰旗堡"], ["0.3", "第一行写石垒·晚担"]]:
		var e: String = await _press(step[0], step[1])
		if e != "":
			return e
	if not GameState.flag("hub_open") or not GameState.flag("pro_roster_wantan"):
		return "keep flags"
	return await _full_c()

func _full_c() -> String:
	# Commissions board, then back to the same beat.
	var e3: String = await _press("0.32", "委托板")
	if e3 != "":
		return e3
	var s3 := _scene_was("res://scenes/hub/quests.tscn")
	if s3 != "":
		return s3
	if StoryCatalog.take_story_return("hub") != RET:
		return "quests did not hold the story return"
	if StoryCatalog.take_story_return("hub") != "hub":
		return "story return was not consumed"
	await _resume("0.32")
	var e4: String = await _press("0.32", "陆桥驿的护送")
	if e4 != "":
		return e4
	# World map travel.
	var e5: String = await _press("0.33", "摊开舆图")
	if e5 != "":
		return e5
	var s5 := _scene_was("res://scenes/hub/atlas_view.tscn")
	if s5 != "":
		return s5
	StoryCatalog.take_story_return("")
	await _resume("0.33")
	var receipt: Array = _texts("0.35")
	if str(receipt[0]).find("「试旗」") < 0:
		return "surname not spoken at the toll: " + str(receipt[0])
	for step in [["0.35", "春令那张桌子"]]:
		var e: String = await _press(step[0], step[1])
		if e != "":
			return e
	return await _full_d()

func _full_d() -> String:
	var climax: Array = _texts("0.38")
	if not _has(climax, "灰马是他的") or _has(climax, "押进哨所第三天"):
		return "climax ignored the survivor choice %s" % str(climax)
	for step in [["0.38", "给衡舟留一行"], ["0.39", "入席"]]:
		var e: String = await _press(step[0], step[1])
		if e != "":
			return e
	return await _full_e()

func _full_e() -> String:
	# Marriage.
	var e6: String = await _press("0.4", "前往联姻廷")
	if e6 != "":
		return e6
	if int(GameState.reputation.get("ashland", 0)) < 30:
		return "spring reputation not prepared"
	var s6 := _scene_was("res://scenes/hub/marriage.tscn")
	if s6 != "":
		return s6
	var wed := _marry()
	if wed != "":
		return wed
	await _resume("0.4")
	for step in [["0.4", "赴双姓共席"], ["0.45", "等待初啼"], ["0.5", "让月份走到孩子落地"]]:
		var e: String = await _press(step[0], step[1])
		if e != "":
			return e
	if not GameState.flag("child_born"):
		return "advance until child_born did not deliver"
	var e7: String = await _press("0.5", "去听那一声哭")
	if e7 != "":
		return e7
	# Lineage page.
	return await _full_f()

func _full_f() -> String:
	var e8: String = await _press("0.55", "族谱")
	if e8 != "":
		return e8
	var s8 := _scene_was("res://scenes/hub/lineage_view.tscn")
	if s8 != "":
		return s8
	await _resume("0.55")
	var e9: String = await _press("0.55", "粮饷结清")
	if e9 != "":
		return e9
	var harvest: Array = _texts("0.6")
	if not _has(harvest, "赎不回来") or _has(harvest, "一张一张挣来"):
		return "harvest ignored the lease choice"
	# Economy: wages settle at harvest.
	var e10: String = await _press("0.6", "把月份推到丰收")
	if e10 != "":
		return e10
	if not GameState.flag("harvest_done"):
		return "harvest not settled"
	var e11: String = await _press("0.6", "写下这一年")
	if e11 != "":
		return e11
	if not GameState.flag("chapter0_done"):
		return "journal did not close the prologue"
	return _echoes(["e1_01_echo_kept", "e1_01_echo_spared"], ["e1_01_echo_handed", "e1_01_echo_exposed"], "era1_01")

func _route_brief() -> String:
	GameState.new_game("岑", "试旗", GameState.crest_color)
	await _open()
	var silver0 := int(GameState.silver)
	for step in [["0.0", "跳过教学"], ["0.05", "走向已经亮起的烽"], ["0.1", "直接听烟散"]]:
		var e: String = await _press(step[0], step[1])
		if e != "":
			return e
	if not GameState.flag("battle_done") or not bool(_player.test_capture.get("skipped_battle", false)):
		return "battle skip"
	for step in [["0.15", "交给哨堡"], ["0.17", "记在槐里家"]]:
		var e: String = await _press(step[0], step[1])
		if e != "":
			return e
	if int(GameState.silver) != silver0 + 80:
		return "patron silver %d want %d" % [GameState.silver, silver0 + 80]
	# The lease beat only exists when the merit was kept.
	if _player.current_beat_id() != "0.2":
		return "lease beat not skipped: " + _player.current_beat_id()
	return await _brief_b()

func _brief_b() -> String:
	var e1: String = await _press("0.2", "直接进列")
	if e1 != "":
		return e1
	if not GameState.flag("recruited"):
		return "auto recruit"
	for step in [["0.25", "入驻灰旗堡"], ["0.3", "第一行空着"], ["0.32", "陆桥驿的护送"], ["0.33", "陆桥耳语"], ["0.35", "春令那张桌子"]]:
		var e: String = await _press(step[0], step[1])
		if e != "":
			return e
	return await _brief_c()

func _brief_c() -> String:
	var climax: Array = _texts("0.38")
	if not _has(climax, "押进哨所第三天") or _has(climax, "灰马是他的"):
		return "climax ignored handed survivor"
	for step in [["0.38", "带走衡舟"], ["0.39", "入席"], ["0.4", "直接入席"]]:
		var e: String = await _press(step[0], step[1])
		if e != "":
			return e
	if not GameState.flag("married"):
		return "auto marry"
	for step in [["0.4", "赴双姓共席"], ["0.45", "等待初啼"], ["0.5", "让月份走到孩子落地"], ["0.5", "去听那一声哭"], ["0.55", "粮饷结清"], ["0.6", "把月份推到丰收"], ["0.6", "踏上第一卷"]]:
		var e: String = await _press(step[0], step[1])
		if e != "":
			return e
	if not GameState.flag("chapter0_done"):
		return "brief route did not finish"
	if str(GameState.get_meta("story_chapter_id", "")) != "e1_01":
		return "departure did not request e1_01"
	GameState.set_meta("story_chapter_id", "")
	return await _brief_d()

func _brief_d() -> String:
	for f in ["pro_survivor_handed", "pro_merit_patron", "pro_roster_blank", "pro_rival_exposed"]:
		if not GameState.flag(f):
			return "missing " + f
	# Flags must ride the save.
	var blob = GameState.build_save_data()
	if blob.has("chapter0_flags"):
		if not bool((blob["chapter0_flags"] as Dictionary).get("pro_merit_patron", false)):
			return "branch flag missing from save blob"
	return _echoes(["e1_01_echo_handed", "e1_01_echo_exposed"], ["e1_01_echo_kept", "e1_01_echo_spared"], "era1_01")

func _marry() -> String:
	var leader = GameState.get_leader()
	GameState.reputation["ashland"] = maxi(35, int(GameState.reputation.get("ashland", 0)))
	GameState.refresh_marriage_candidates()
	GameState.silver = maxi(GameState.silver, 200)
	for c in GameState.marriage_candidates:
		if Lineage.can_propose(leader, c).get("ok", false):
			if Lineage.marry(leader, c, 40).get("ok", false):
				return ""
	var cand := CharacterFactory.make_marriage_candidate(GameState.rng, "knight")
	if Lineage.marry(leader, cand, 40).get("ok", false):
		return ""
	return "no marriage"

func _has(lines: Array, needle: String) -> bool:
	for t in lines:
		if str(t).find(needle) >= 0:
			return true
	return false

func _echoes(want: Array, not_want: Array, chapter: String) -> String:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/chapters/%s.json" % chapter))
	var shown := {}
	for beat in data.get("beats", []):
		for line in beat.get("lines", []):
			if StoryConditions.met(line.get("when", {})):
				shown[str(line.get("id", ""))] = true
	for id in want:
		if not shown.has(id):
			return "%s did not remember %s" % [chapter, id]
	for id in not_want:
		if shown.has(id):
			return "%s showed the other branch %s" % [chapter, id]
	print("OK %s echoes %s" % [chapter, str(want)])
	return ""
