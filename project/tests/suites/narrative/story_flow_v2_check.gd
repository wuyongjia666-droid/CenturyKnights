extends Node
## 新手剧情 v2（docs/design/tutorial-story-v2.md）：
## 原著十段都有标题卡且按序；动机线兑现由团长亲口说；结尾回报拍在结算之后；
## 点屏推进、跳过只跳台词不跳选择；中途存档按拍恢复；战中插话只播一次、可整体跳过。

const CH0 := "res://data/story/chapters/ch0.json"
const CARDS := ["一　麦未黄", "二　断杆", "三　写下的那个字", "四　窄路", "五　功劳簿", "六　烽火酒馆", "七　空椅子", "八　春令", "九　共席", "十　初啼与簿", "那个字"]

var _player

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL story flow v2: ", err)
		get_tree().quit(1)
	else:
		print("STORY FLOW V2 PASS")
		get_tree().quit(0)

func _run() -> String:
	var e := _data()
	if e != "":
		return "data: " + e
	e = await _player_flow()
	if e != "":
		return "player: " + e
	e = await _resume_mid()
	if e != "":
		return "resume: " + e
	e = _battle_story()
	if e != "":
		return "battle: " + e
	return ""

func _chapter() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CH0))

func _data() -> String:
	var ch := _chapter()
	var order: Array = []
	var ids: Array = []
	var fulfil := false
	for b in ch.get("beats", []):
		ids.append(str(b.get("id", "")))
		for l in b.get("lines", []):
			var st = l.get("stage", {})
			if typeof(st) == TYPE_DICTIONARY and st.has("card") and not order.has(str(st["card"])):
				order.append(str(st["card"]))
			if str(l.get("speaker", "")) == "leader" and str(l.get("text", "")).find("身后站着谁") >= 0 and str(b.get("id", "")) == "0.39":
				fulfil = true
	if order != CARDS:
		return "title cards %s want %s" % [str(order), str(CARDS)]
	if not fulfil:
		return "0.39 fulfilment is not spoken by the leader"
	var i6 := ids.find("0.6")
	if i6 < 0 or ids.find("0.65") != i6 + 1 or ids.find("0.7") != i6 + 2:
		return "payoff beats out of order %s" % str(ids)
	# The motive must be planted before it is paid off.
	var flat := JSON.stringify(ch)
	if flat.find("划掉") < 0 or flat.find("划不掉") < 0:
		return "motive line missing"
	return ""

func _open() -> void:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
		await get_tree().process_frame
	_player = (load("res://scenes/story/chapter_player.tscn") as PackedScene).instantiate()
	_player.chapter_path = CH0
	_player.lock_path = true
	_player.suppress_scene_change = true
	add_child(_player)
	await get_tree().process_frame

func _player_flow() -> String:
	GameState.new_game("岑", "试旗", GameState.crest_color)
	await _open()
	if _player.current_beat_id() != "0.0":
		return "start beat " + _player.current_beat_id()
	if not (_player.test_capture.get("cards", []) as Array).has("一　麦未黄"):
		return "opening title card not shown %s" % str(_player.test_capture.get("cards", []))
	if str(_player.test_capture.get("bg", "")) != "slope":
		return "opening background %s" % str(_player.test_capture.get("bg", ""))
	_player._hide_card()
	var before: int = _player._line_idx
	_player.tap_advance()  # first tap finishes the slow line
	_player.tap_advance()
	if _player._line_idx != before + 1:
		return "tap did not advance (%d -> %d)" % [before, _player._line_idx]
	_player.skip_lines()
	await get_tree().process_frame
	var labels: Array = _player.action_labels()
	if not str(labels).contains("让这个颜色落进旗心"):
		return "skip did not reveal the choices %s" % str(labels)
	var sk = _player.find_child("SkipLines", true, false)
	if sk == null or (sk as Control).custom_minimum_size.y < 48:
		return "skip button missing or under 48px"
	# The leader speaks under their own name.
	_player.simulate_goto_beat("0.39")
	if _player._speaker_label("leader") != str(GameState.get_leader().name):
		return "leader label %s" % _player._speaker_label("leader")
	return ""

func _resume_mid() -> String:
	GameState.new_game("岑", "试旗", GameState.crest_color)
	GameState.set_flag("pro_merit_own", true)
	GameState.set_beat("0.18")
	await _open()
	if _player.current_beat_id() != "0.18":
		return "reopened at " + _player.current_beat_id()
	var first: Dictionary = _player._visible_lines()[0]
	if str(first.get("text", "")).find("景伯一个人回来") < 0:
		return "night visit is not the first thing after refusing: " + str(first)
	return ""

func _battle_story() -> String:
	var host := Node.new()
	add_child(host)
	for k in ["start", "turn_1", "turn_2", "turn_3", "first_lock", "first_kill", "victory"]:
		GameState.set_flag("bs_ch0_pass_" + k, false)
	if BattleStory.fire(host, "ch0_pass", "start") != 3:
		return "start lines"
	if not BattleStory.is_showing(host):
		return "bar not showing"
	if BattleStory.fire(host, "ch0_pass", "start") != 0:
		return "start replayed"
	BattleStory.on_player_turn(host, "ch0_pass")
	if not (host.get_meta("bs_log", []) as Array).has("turn:1"):
		return "turn:1 did not fire %s" % str(host.get_meta("bs_log", []))
	BattleStory.on_player_turn(host, "ch0_pass")
	BattleStory.on_player_turn(host, "ch0_pass")
	if not (host.get_meta("bs_log", []) as Array).has("turn:3"):
		return "turn:3 did not fire %s" % str(host.get_meta("bs_log", []))
	BattleStory.skip_all(host)
	if BattleStory.is_showing(host):
		return "skip left the bar up"
	if BattleStory.fire(host, "ch0_pass", "first_lock") != 0:
		return "skipped battle still interrupts"
	if not GameState.flag("bs_ch0_pass_start"):
		return "played flag not saved"
	if BattleStory.fire(Node.new(), "no_such_map", "start") != 0:
		return "unknown map fired"
	for k2 in ["start", "turn_2", "first_lock", "first_kill", "victory"]:
		GameState.set_flag("bs_e1_reed_escort_" + k2, false)
	host.set_meta("bs_skipped", false)
	host.set_meta("bs_log", [])
	if BattleStory.fire(host, "e1_reed_escort", "start") != 3:
		return "e1 start lines"
	host.queue_free()
	return ""
