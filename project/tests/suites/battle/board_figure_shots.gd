extends Node
## P1 review shots: desktop A/B + priority unit cards (captain / hunter / bandit*).
## args: --out=DIR

func _ready() -> void:
	var out := "res://../docs/art/review/board_figure_p1"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	# Prefer absolute path under workspace
	if out.begins_with("res://"):
		out = ProjectSettings.globalize_path(out)
	if DisplayServer.get_name() == "headless":
		print("BOARD FIGURE SHOTS headless-skip")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.make_dir_recursive_absolute(out + "/cards")
	await _desktop_ab(out)
	await _unit_cards(out)
	print("BOARD FIGURE SHOTS DONE ", out)
	get_tree().quit(0)


func _desktop_ab(out: String) -> void:
	for label in ["before", "after"]:
		GameState.new_game("Ash", "Banner", "#6ED4FF")
		GameState.set_meta("battle_map", "ch0_pass")
		GameState.set_meta("cutscenes_on", false)
		GameState.settings["cutscenes"] = false
		GameState.settings["board_units_3d"] = label == "after"
		get_window().size = Vector2i(1280, 720)
		await get_tree().process_frame
		var node = load("res://scenes/battle/battle.tscn").instantiate()
		get_tree().root.add_child(node)
		get_tree().current_scene = node
		GameState.settings["board_units_3d"] = label == "after"
		await get_tree().create_timer(1.6).timeout
		node.map_draw.queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/desktop_%s_1280x720.png" % [out, label])
		print("SHOT desktop ", label)
		node.queue_free()
		await get_tree().process_frame


func _unit_cards(out: String) -> void:
	GameState.new_game("Ash", "Banner", "#6ED4FF")
	await get_tree().process_frame
	var leader = GameState.get_leader()
	var jobs := [
		{"name": "captain", "team": "player", "tmpl": "", "job": "captain", "leader": true},
		{"name": "hunter", "team": "player", "tmpl": "", "job": "hunter", "leader": false},
		{"name": "bandit_weak", "team": "enemy", "tmpl": "bandit_weak", "job": "", "leader": false},
		{"name": "bandit", "team": "enemy", "tmpl": "bandit", "job": "", "leader": false},
		{"name": "bandit_archer", "team": "enemy", "tmpl": "bandit_archer", "job": "", "leader": false},
		{"name": "bandit_chief", "team": "enemy", "tmpl": "bandit_chief", "job": "", "leader": false},
	]
	for row in jobs:
		var c = leader
		var saved_job := str(leader.job_id)
		var saved_lead := bool(leader.is_leader)
		if str(row.job) != "":
			leader.job_id = str(row.job)
			leader.is_leader = bool(row.leader)
		CKBoardFigure._pal_cache.clear()
		var tex: Texture2D = await _render_card(c, str(row.team), str(row.tmpl))
		leader.job_id = saved_job
		leader.is_leader = saved_lead
		if tex:
			var img: Image = tex.get_image()
			if img:
				img.save_png("%s/cards/%s.png" % [out, row.name])
				print("CARD ", row.name)


func _render_card(c, team: String, tmpl: String) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 400)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var fig := CKBoardFigure.build(c, team, tmpl)
	fig.rotation_degrees.y = 35.0 if team != "enemy" else -35.0
	world.add_child(fig)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.15
	cam.current = true
	world.add_child(cam)
	cam.global_position = Vector3(0, 1.55, 2.35)
	cam.look_at(Vector3(0, 0.92, 0), Vector3.UP)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.76, 0.86)
	e.ambient_light_energy = 0.55
	we.environment = e
	world.add_child(we)
	for i in 5:
		await get_tree().process_frame
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	if img == null:
		return null
	return ImageTexture.create_from_image(img)
