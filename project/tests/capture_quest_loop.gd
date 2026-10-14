extends Node
## Screenshots of the commission loop (desktop, or phone with CK_FORCE_MOBILE=1).

var out_dir := "/workspace/quest_loop_audit"
var res := Vector2i(1280, 720)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		if a.begins_with("--res="):
			var wh := a.substr(6).split("x")
			res = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = res
	await _wait(0.3)
	GameState.new_game("闭环", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	GameState.silver = 2000
	GameState.food = 300
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = "ash_capital"
	World.rep_city["ash_capital"] = 80
	var r := RandomNumberGenerator.new()
	r.seed = hash("loop:hunt")
	var q: Dictionary = {}
	for _t in 20:
		q = World._make_quest("ash_capital", "hunt", 1, r)
		if str(q.get("target", "")) != "ash_capital":
			break
	World._ensure_board("ash_capital")
	World.boards["ash_capital"].offers.append(q)
	var qid := str(q.id)
	GameState.set_meta("city_id", "ash_capital")
	var city = await _open("res://scenes/hub/city.tscn")
	city._set_tab("board")
	city._sel_quest = qid
	city._render_tab()
	await _wait(0.3)
	await _snap("01_city_offer")
	city._accept_offer(qid)
	await _wait(0.5)
	await _snap("02_city_accepted_toast_cta")
	city.queue_free()
	var castle = await _open("res://scenes/hub/castle_hub.tscn")
	await _wait(0.5)
	await _snap("03_castle_todo_active")
	castle.queue_free()
	var book = await _open("res://scenes/hub/quests.tscn")
	await _snap("04_quests_book")
	book.queue_free()
	GameState.set_meta("atlas_select", World.quest_guide_node(World.quest_by_id(qid)))
	var atlas = await _open("res://scenes/hub/atlas_view.tscn")
	await _wait(0.8)
	await _snap("05_atlas_focus_marker")
	World.travel_to(str(q.target))
	atlas.queue_free()
	atlas = await _open("res://scenes/hub/atlas_view.tscn")
	await _wait(0.8)
	await _snap("06_atlas_arrive_encounter")
	World.on_battle_end(true)
	atlas.queue_free()
	GameState.set_meta("atlas_select", World.quest_guide_node(World.quest_by_id(qid)))
	atlas = await _open("res://scenes/hub/atlas_view.tscn")
	await _wait(0.8)
	await _snap("07_atlas_turnin_marker")
	atlas.queue_free()
	World.travel_to(World.turn_in_city(World.quest_by_id(qid)))
	GameState.set_meta("city_id", World.pos)
	city = await _open("res://scenes/hub/city.tscn")
	city._set_tab("board")
	city._sel_quest = qid
	city._render_tab()
	await _wait(0.3)
	await _snap("08_city_ready_turnin")
	city._do(World.turn_in(qid))
	await _wait(0.4)
	await _snap("09_city_turned_in")
	city.queue_free()
	castle = await _open("res://scenes/hub/castle_hub.tscn")
	await _wait(0.5)
	await _snap("10_castle_todo_cleared")
	print("QUEST LOOP SHOTS DONE ", out_dir)
	get_tree().quit(0)

func _open(path: String) -> Node:
	var n := (load(path) as PackedScene).instantiate()
	add_child(n)
	await _wait(0.4)
	return n

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _snap(shot: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, shot])
	print("SHOT ", shot, " ", img.get_size())
