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
		var saved_ck := str(leader.cast_key)
		if str(row.job) != "":
			leader.job_id = str(row.job)
			leader.is_leader = bool(row.leader)
			# Job cards must resolve outfit_<job>, not cast_leader.
			leader.cast_key = "leader" if bool(row.leader) else ""
		if str(row.team) == "enemy":
			leader.cast_key = ""
			leader.is_leader = false
		CKBoardFigure._pal_cache.clear()
		var tex: Texture2D = await _render_card(c, str(row.team), str(row.tmpl))
		leader.job_id = saved_job
		leader.is_leader = saved_lead
		leader.cast_key = saved_ck
		if tex:
			var img: Image = tex.get_image()
			if img:
				img.save_png("%s/cards/%s.png" % [out, row.name])
				print("CARD ", row.name)
				if str(row.name) == "captain":
					await _captain_vs_portrait(out, c, img)


func _render_card(c, team: String, tmpl: String) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 400)
	vp.transparent_bg = false
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
	cam.size = 2.45
	cam.current = true
	world.add_child(cam)
	cam.global_position = Vector3(0, 1.65, 2.45)
	cam.look_at(Vector3(0, 1.05, 0), Vector3.UP)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.78, 0.80, 0.84)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.87, 0.92)
	e.ambient_light_energy = 0.75
	we.environment = e
	world.add_child(we)
	for i in 5:
		await get_tree().process_frame
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


func _captain_vs_portrait(out: String, c, fig_img: Image) -> void:
	## Figure + portrait + hair/skin/coat swatches (plate-sampled palette).
	DirAccess.make_dir_recursive_absolute(out + "/vs_portrait")
	var pal: Dictionary = CKBoardFigure.palette_for(c, "player")
	var portrait: Texture2D = UnitArt.portrait(c) if c != null else null
	var pw := 280
	var ph := 360
	var strip_h := 72
	var canvas := Image.create(pw * 2 + 24, ph + strip_h + 16, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.05, 0.06, 0.09, 1))
	var fig := fig_img.duplicate()
	fig.resize(pw, ph, Image.INTERPOLATE_NEAREST)
	canvas.blit_rect(fig, Rect2i(0, 0, pw, ph), Vector2i(8, 8))
	if portrait != null:
		var pimg: Image = portrait.get_image()
		if pimg:
			pimg = pimg.duplicate()
			pimg.resize(pw, ph, Image.INTERPOLATE_BILINEAR)
			canvas.blit_rect(pimg, Rect2i(0, 0, pw, ph), Vector2i(pw + 16, 8))
	var keys = ["hair", "skin", "coat", "coat_dark"]
	var sw = int((pw * 2 + 8) / keys.size())
	var y0 = ph + 12
	for i in keys.size():
		var col: Color = pal.get(keys[i], Color(0.5, 0.5, 0.5)) as Color
		var x0 = 8 + i * sw
		for yy in range(y0, y0 + 44):
			for xx in range(x0, x0 + sw - 6):
				canvas.set_pixel(xx, yy, col)
		var edge := Color(0.08, 0.09, 0.11, 1)
		for xx in range(x0, x0 + sw - 6):
			canvas.set_pixel(xx, y0, edge)
			canvas.set_pixel(xx, y0 + 43, edge)
	canvas.save_png("%s/vs_portrait/captain_vs_plate.png" % out)
	var f := FileAccess.open("%s/vs_portrait/captain_palette.json" % out, FileAccess.WRITE)
	if f:
		var row := {}
		for k in keys:
			var cc: Color = pal.get(k, Color.WHITE) as Color
			row[k] = "#%s" % cc.to_html(false)
		row["plate_stem"] = str(pal.get("plate_stem", ""))
		row["style"] = str(pal.get("style", ""))
		f.store_string(JSON.stringify(row, "\t"))
		f.close()
	print("CARD captain_vs_portrait")
