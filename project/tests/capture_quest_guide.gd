extends Node
## Screenshot: accept commission → toast/hint → atlas focus with ◆ marker.

var out_dir := "/workspace/quest_guide_shots"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	GameState.new_game("指引", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	GameState.silver = 2000
	GameState.food = 200
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = "ash_capital"
	World.rep_city["ash_capital"] = 80
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	World.active.clear()
	World.boards.erase("ash_capital")
	var offers: Array = World.board("ash_capital")
	var pick: Dictionary = {}
	for q in offers:
		if World.quest_locked_reason(q) == "" and str(q.get("kind", "")) != "gather":
			pick = q
			break
	if pick.is_empty():
		print("FAIL no offer")
		get_tree().quit(1)
		return
	var acc: Dictionary = World.accept_quest("ash_capital", str(pick.id))
	print("accept: ", acc.get("msg", ""))
	var guide := str(acc.get("guide_node", ""))
	# City board with active + GotoAtlas
	GameState.set_meta("city_id", "ash_capital")
	var city = (load("res://scenes/hub/city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	city._set_tab("board")
	city._sel_quest = str(pick.id)
	city._render_tab()
	await _wait(0.5)
	await _snap("01_city_board_after_accept")
	city.queue_free()
	await _wait(0.2)
	# Atlas focused on objective
	GameState.set_meta("atlas_select", guide)
	GameState.set_meta("atlas_view", World.nation_of(guide))
	var atlas = (load("res://scenes/hub/atlas_view.tscn") as PackedScene).instantiate()
	add_child(atlas)
	await get_tree().process_frame
	await _wait(0.8)
	await _snap("02_atlas_quest_focus")
	atlas.queue_free()
	await _wait(0.2)
	# Quests book with 去舆图
	var quests = (load("res://scenes/hub/quests.tscn") as PackedScene).instantiate()
	add_child(quests)
	await get_tree().process_frame
	await _wait(0.4)
	await _snap("03_quests_book_active")
	quests.queue_free()
	print("QUEST GUIDE SHOTS DONE ", out_dir)
	get_tree().quit(0)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("shot ", name, " ", img.get_size())
