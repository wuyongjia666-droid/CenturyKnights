extends Node
## 主菜单「序章回顾」：沙盒重玩第零章，不写盘；结束（回堡/上路/退出/主菜单）后原存档原样回来。

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL prologue replay: ", err)
		get_tree().quit(1)
	else:
		print("PROLOGUE REPLAY PASS")
		get_tree().quit(0)

func _disk() -> Dictionary:
	var out := {}
	_scan("user://", out)
	return out

func _scan(path: String, out: Dictionary) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		var p := path.path_join(f)
		out[p] = FileAccess.get_md5(p)
	for sub in d.get_directories():
		_scan(path.path_join(sub), out)

func _run() -> String:
	GameState.new_game("甲", "乙", GameState.crest_color)
	GameState.silver = 777
	GameState.set_beat("0.3")
	GameState.set_flag("hub_open", true)
	if not GameState.save_game():
		return "baseline save failed"
	var before := _disk()
	var lead_id := str(GameState.get_leader().id)
	GameState.begin_prologue_replay()
	if not GameState.replay_mode or GameState.chapter0_beat != "0.0" or GameState.flag("hub_open"):
		return "replay did not start a fresh prologue"
	var p = (load("res://scenes/story/chapter_player.tscn") as PackedScene).instantiate()
	p.chapter_path = "res://data/story/chapters/ch0.json"
	p.lock_path = true
	p.suppress_scene_change = true
	add_child(p)
	await get_tree().process_frame
	if p.find_child("LeaveReplay", true, false) == null:
		return "no leave button in replay"
	p.simulate_finish_dialogue()
	p.simulate_press_action_containing("让这个颜色落进旗心")
	if GameState.save_game():
		return "save wrote during replay"
	GameState.silver = 1
	p._go_scene(p.HUB_SCENE)
	if GameState.replay_mode:
		return "leaving to the castle did not end the replay"
	if str(p.test_capture.get("scene", "")) != p.MENU_SCENE:
		return "replay exit went to %s" % str(p.test_capture.get("scene", ""))
	if GameState.silver != 777 or str(GameState.get_leader().id) != lead_id or GameState.chapter0_beat != "0.3":
		return "game not restored silver=%d beat=%s" % [GameState.silver, GameState.chapter0_beat]
	if _disk() != before:
		return "disk changed during replay"
	p.queue_free()
	return ""
