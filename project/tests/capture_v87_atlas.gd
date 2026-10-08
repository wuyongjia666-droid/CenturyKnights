extends Node
## v8.7 atlas/cities real-render capture (xvfb + opengl3). Saves to OUT for art/UX QA.

var OUT := "/workspace/atlas_v87_screens"
var only := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.substr(6)
		if a.begins_with("--only="):
			only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", "#c9a227")
	GameState.silver = 1600
	GameState.food = 160
	World.events_enabled = false
	# a lived-in state: a couple of visits, an accepted commission, cargo
	World.travel_to("ash_capital")
	World.rep_city["ash_capital"] = 34
	World.boards.erase("ash_capital")
	var offers: Array = World.board("ash_capital")
	var took := 0
	for q in offers:
		if took < 3 and World.quest_locked_reason(q) == "":
			var ar: Dictionary = World.accept_quest("ash_capital", str(q.id))
			print("accept ", q.title, " ", ar.msg)
			if bool(ar.ok):
				took += 1
	World.market_buy("ash_capital", "ashsteel", 6)
	if _want("atlas"):
		var s = await _open("res://scenes/hub/atlas_view.tscn")
		await _snap("01_atlas_nation")
		s._on_node_pressed("fog_vale")
		await _wait(0.4)
		await _snap("02_atlas_route_preview")
		s._show_view("")
		s._on_region_pressed("qinghe")
		await _wait(0.4)
		await _snap("03_atlas_world")
		s._show_view("landbridge")
		s._select_node("lb_west")
		await _wait(0.4)
		await _snap("04_atlas_landbridge")
		s._show_view("ashbanner")
		World.make_event("refugees", "ash_capital", "stone_slope")
		s._show_event_modal(World.pending_event)
		await _wait(0.5)
		await _snap("05_atlas_event")
		World.pending_event = {}
		var enc: Dictionary = World.start_encounter("road", {"node": "ash_capital", "from": "stone_slope"})
		s._render_hud()
		s._show_encounter_modal(enc)
		await _wait(0.5)
		await _snap("06_atlas_encounter")
		World.encounter = {}
		s.queue_free()
		await _wait(0.2)
	if _want("nations"):
		for nid in World.nation_ids():
			GameState.set_meta("atlas_view", str(nid))
			var s2 = await _open("res://scenes/hub/atlas_view.tscn")
			s2._select_node(str(World.nations[nid].capital))
			await _wait(0.3)
			await _snap("n_%s" % nid)
			s2.queue_free()
			await _wait(0.1)
	if _want("city"):
		GameState.set_meta("city_id", "ash_capital")
		var c = await _open("res://scenes/hub/city.tscn")
		var tabs := ["overview", "smith", "market", "board", "tavern", "armory"]
		for i in tabs.size():
			c._set_tab(tabs[i])
			await _wait(0.45)
			await _snap("1%d_city_%s" % [i, tabs[i]])
		c.queue_free()
		await _wait(0.2)
		GameState.set_meta("city_id", "fc_capital")
		World.pos = "fc_capital"
		var c2 = await _open("res://scenes/hub/city.tscn")
		c2._set_tab("smith")
		await _wait(0.45)
		await _snap("17_city_frost_smith")
		c2.queue_free()
	if _want("battle"):
		World.pos = "fog_vale"
		var e2: Dictionary = World.start_encounter("road", {"node": "fog_vale", "from": "stone_slope"})
		GameState.set_meta("battle_map", str(e2.id))
		GameState.set_meta("battle_return", World.ATLAS_SCENE)
		GameState.set_meta("world_encounter", true)
		var b = load("res://scenes/battle/battle.tscn").instantiate()
		add_child(b)
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _wait(1.2)
		await _snap("20_encounter_battle")
		b._finish(true)
		await _wait(1.0)
		await _snap("21_encounter_result")
		b.queue_free()
	print("CAPTURE_DONE ", OUT)
	get_tree().quit(0)

func _want(k: String) -> bool:
	return only == "" or only == k

func _open(path: String):
	var s = load(path).instantiate()
	add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(0.9)
	return s

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, name])
	print("SHOT ", name)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
