extends Node
## Opening review: the chapter-1 path can be finished headless.
## A-01 escort walks and wins; A-02 the way back reopens e1_01 with an exit past the brief;
## A-03 pause buttons are on screen at 1280x720 and 1600x720; A-04 prologue defeat returns to
## the story; A-05 prologue companions do not desert on unpaid wages.
## Batch 3: e1_01 has stage backgrounds on every beat, a home beat, and no aphorism leftovers.

const PLAYER := "res://scenes/story/chapter_player.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"


func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL opening_chain: ", err)
		get_tree().quit(1)
		return
	print("OPENING_CHAIN PASS")
	get_tree().quit(0)


func _run() -> String:
	for step in [_e1_presentation, _escort, _return_to_chapter, _pause_layout, _defeat_route, _wages]:
		var err: String = await step.call()
		if err != "":
			return err
	return ""


func _fresh() -> void:
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	GameState.set_meta("cutscenes_on", false)
	GameState.settings["cutscenes"] = false


func _battle(map_id: String) -> Node:
	GameState.set_meta("battle_return", PLAYER)
	GameState.set_meta("battle_return_chapter", "e1_01")
	GameState.set_meta("battle_map", map_id)
	var b = (load(BATTLE) as PackedScene).instantiate()
	add_child(b)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.size = Vector2(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	return b


func _npc(b: Node):
	for u in b.units:
		if str(u.get("tag", "")) == "grain":
			return u
	return null


func _escort() -> String:
	_fresh()
	var b = await _battle("e1_reed_escort")
	var npc = _npc(b)
	if npc == null:
		return "escort npc missing"
	var start: Vector2i = npc.pos
	var rounds := 0
	# Round 1 with foes far away: the porter walks on his own.
	b._end_player_turn()
	await get_tree().create_timer(0.6).timeout
	rounds += 1
	if npc.pos == start:
		return "escort npc did not move (still %s)" % str(start)
	# Clear the road, then keep ending turns: he must reach the lamp within 8 rounds.
	for u in b.units:
		if str(u.team) == "enemy":
			u.char.hp = 0
	while not b.battle_over and rounds < 8:
		if str(b.turn_team) != "player":
			await get_tree().create_timer(0.2).timeout
			continue
		b._end_player_turn()
		await get_tree().create_timer(0.6).timeout
		rounds += 1
	if not b.battle_over:
		return "escort not won in 8 rounds, npc at %s" % str(npc.pos)
	if str(b.get_meta("battle_verdict", {}).get("result", "")) != "win":
		return "escort verdict %s" % str(b.get_meta("battle_verdict", {}))
	if not GameState.flag("e1_01_won") or not GameState.flag("e1_01_fought"):
		return "e1_01_won/e1_01_fought not written on victory"
	b.queue_free()
	await get_tree().process_frame
	return ""


func _return_to_chapter() -> String:
	var back := BattleDefeat.back_path(true, false, PLAYER)
	if back != PLAYER:
		return "win back_path %s" % back
	var p = (load(PLAYER) as PackedScene).instantiate()
	p.suppress_scene_change = true
	GameState.set_meta("battle_return_chapter", "e1_01")
	GameState.story.set_beat(int(_legacy("e1_01")), "brief")
	add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	if str(p._chapter.get("id", "")) != "e1_01":
		return "back from battle opened %s" % str(p._chapter.get("id", ""))
	p.simulate_finish_dialogue()
	var labels: Array = []
	var lamp: BaseButton = null
	for c in p._actions.get_children():
		if c is BaseButton and not c.disabled:
			labels.append(c.text)
			if c.text.find("桥灯下的动静") >= 0:
				lamp = c
	if lamp == null:
		return "brief offers no way past the fight after winning: %s" % str(labels)
	for t in labels:
		if str(t).find("护送粮队") >= 0:
			return "fight button still offered after the win"
	lamp.pressed.emit()
	await get_tree().process_frame
	if str(p.current_beat_id()) != "after":
		return "lamp button went to %s" % p.current_beat_id()
	p.queue_free()
	await get_tree().process_frame
	return ""


func _e1_presentation() -> String:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/chapters/era1_01.json"))
	if typeof(d) != TYPE_DICTIONARY:
		return "era1_01 unreadable"
	var beats: Array = d.get("beats", [])
	var ids: Array = []
	var leader_n := 0
	var wantan_n := 0
	var scout_n := 0
	var banned := ["滴声比哨音老实", "安静不是和解", "去向就是立场", "句子后面还有人", "半环不是纹章", "功绩单会先于"]
	var saw_birth := false
	var saw_home := false
	for beat in beats:
		var bid := str(beat.get("id", ""))
		ids.append(bid)
		var has_bg := false
		for line in beat.get("lines", []):
			var sp := str(line.get("speaker", ""))
			var text := str(line.get("text", ""))
			if sp == "leader":
				leader_n += 1
			if sp == "石垒·晚担":
				wantan_n += 1
			if sp == "斥候":
				scout_n += 1
			if text.find("出生的地方") >= 0:
				saw_birth = true
			for bad in banned:
				if text.find(bad) >= 0:
					return "aphorism leftover in %s: %s" % [line.get("id", ""), bad]
			var stage = line.get("stage", {})
			if typeof(stage) == TYPE_DICTIONARY and str(stage.get("bg", "")) != "":
				has_bg = true
		if not has_bg:
			return "beat %s has no stage.bg" % bid
		if bid == "home":
			saw_home = true
			var acts: Array = beat.get("actions", [])
			if acts.is_empty():
				return "home beat needs a hub exit"
	if not ids.has("home"):
		return "missing home beat"
	if not saw_home:
		return "home beat empty"
	if not saw_birth:
		return "dengying birth beat missing"
	if leader_n < 4:
		return "leader lines %d (want >=4)" % leader_n
	if wantan_n < 4:
		return "wantan lines %d (want >=4)" % wantan_n
	if scout_n > 0:
		return "scout lines should be reassigned (%d left)" % scout_n
	# end must lead into home so the chapter closes with a return.
	for beat in beats:
		if str(beat.get("id", "")) == "end" and str(beat.get("next", "")) != "home":
			return "end.next should be home"
	return ""


func _legacy(id: String) -> int:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/chapters/era1_01.json"))
	return int(d.get("legacy_index", 0))


func _pause_layout() -> String:
	for sz in [Vector2i(1280, 720), Vector2i(1600, 720)]:
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		get_tree().root.size = sz
		await get_tree().process_frame
		CKPauseMenu.toggle()
		await get_tree().process_frame
		await get_tree().process_frame
		var m := CKPauseMenu.current
		if m == null:
			return "pause menu did not open"
		var view := Rect2(Vector2.ZERO, Vector2(get_tree().root.get_visible_rect().size))
		for spec in CKPauseMenu.BUTTONS:
			var b := m.find_child(str(spec[0]), true, false) as Control
			if b == null:
				return "pause button %s missing" % spec[0]
			var r := b.get_global_rect()
			if not view.encloses(r):
				return "pause %s at %s outside %s" % [spec[0], str(r), str(view)]
		CKPauseMenu.toggle()
		await get_tree().process_frame
		await get_tree().process_frame
	return ""


func _defeat_route() -> String:
	_fresh()
	GameState.set_meta("battle_map", "ch0_pass")
	var ret := "res://scenes/story/chapter0.tscn"
	if BattleDefeat.back_path(false, false, ret) != ret:
		return "prologue defeat does not return to the story"
	if not GameState.flag("ch0_pass_lost"):
		return "ch0_pass_lost not written"
	if GameState.flag("hub_open"):
		return "prologue defeat opened the hub"
	return ""


func _wages() -> String:
	_fresh()
	var names: Array = []
	for c in GameState.roster():
		names.append(str(c.cast_key))
	for i in 4:
		CKMorale.on_payday(GameState, false)
	var keep := {}
	for c in GameState.roster():
		keep[str(c.cast_key)] = true
	for k in ["wantan", "dengying"]:
		if names.has(k) and not keep.has(k):
			return "prologue companion %s deserted on unpaid wages" % k
	if not names.has("wantan"):
		return "new game roster has no wantan: %s" % str(names)
	return ""
