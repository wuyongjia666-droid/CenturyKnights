extends Node
## Playtest shots: ch0 pregnancy wait — month report panel + back-to-castle choice.
const OUT_DEFAULT := "/workspace/ch0_month_shots"
const RES := [
	["desk_1280x720", Vector2i(1280, 720), false],
	["desk_1920x1080", Vector2i(1920, 1080), false],
	["m_2400x1080", Vector2i(2400, 1080), true],
	["m_1920x1080", Vector2i(1920, 1080), true],
]

var _out := OUT_DEFAULT

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	var err := await _run()
	if err != "":
		print("FAIL ch0 month shots: ", err)
		get_tree().quit(1)
	else:
		print("CH0 MONTH SHOTS PASS")
		get_tree().quit(0)

func _run() -> String:
	GameState.new_game("吴", "灰旗", GameState.crest_color)
	GameState.set_flag("married")
	GameState.set_flag("recruited")
	# Seed pregnancy so the wait beat is meaningful.
	var mother = GameState.get_leader()
	if mother != null and str(mother.gender) != "f":
		for c in GameState.characters.values():
			if c != null and c.alive and str(c.gender) == "f":
				mother = c
				break
	if mother != null:
		mother.pregnant_months = 3
	GameState.silver = 14  # force pay warning on advance
	GameState.set_beat("0.5")
	for row in RES:
		var tag: String = row[0]
		var size: Vector2i = row[1]
		var mobile: bool = row[2]
		if mobile:
			OS.set_environment("CK_FORCE_MOBILE", "1")
		else:
			OS.set_environment("CK_FORCE_MOBILE", "0")
		DisplayServer.window_set_size(size)
		await get_tree().process_frame
		await get_tree().process_frame
		var packed: PackedScene = load("res://scenes/story/chapter_player.tscn")
		var p = packed.instantiate()
		p.chapter_path = "res://data/story/chapters/ch0.json"
		p.lock_path = true
		p.suppress_scene_change = true
		add_child(p)
		await get_tree().process_frame
		await get_tree().process_frame
		p.simulate_finish_dialogue()
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s_choices.png" % [_out, tag])
		# Pay-short first press (no month advanced).
		p.simulate_press_action_containing("过一个月")
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s_paywarn.png" % [_out, tag])
		# Ack and advance one month so the report has events.
		p.simulate_press_action_containing("过一个月")
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/%s_report.png" % [_out, tag])
		var report = p.find_child("MonthReport", true, false)
		if report == null or not report.visible:
			p.queue_free()
			return "%s: MonthReport missing" % tag
		var labels: Array = p.action_labels()
		if not labels.has("先回城堡揭委托、看账") and not GameState.flag("child_born"):
			p.queue_free()
			return "%s: missing back-to-castle %s" % [tag, str(labels)]
		p.queue_free()
		await get_tree().process_frame
		# Fresh beat state for next resolution.
		GameState.set_beat("0.5")
		GameState.silver = 14
		if mother != null:
			mother.pregnant_months = 3
		GameState.set_flag("child_born", false)
	return ""
