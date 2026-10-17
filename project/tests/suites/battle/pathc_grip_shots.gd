extends Node
## Path C grip review: board shot + 3x board crops + front / 3/4 close-ups of each armed ship piece
## (plus a spear probe on the light-infantry body). args: --out=DIR --map=ID --tag=before|after

const VIEWS := {"front": 0.0, "q34": 40.0}

func _ready() -> void:
	var out := "/tmp/pathc_grip"
	var map_id := "ch31_forge"
	var tag := "after"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--map="):
			map_id = a.substr(6)
		elif a.begins_with("--tag="):
			tag = a.substr(6)
	if DisplayServer.get_name() == "headless":
		print("PATHC GRIP SHOTS headless-skip")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(out)
	GameState.new_game("Ash", "Banner", "#" + Color8(110, 212, 255).to_html(false))
	GameState.set_meta("battle_map", map_id)
	GameState.set_meta("cutscenes_on", false)
	GameState.settings["cutscenes"] = false
	GameState.settings["board_units_3d"] = true
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var node = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(node)
	get_tree().current_scene = node
	await get_tree().create_timer(2.2).timeout
	node.map_draw.queue_redraw()
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.save_png("%s/board_%s_%s.png" % [out, map_id, tag])
	var figs: Array = []
	for f in get_tree().root.find_children("*", "Node3D", true, false):
		if bool(f.get_meta("ck_board_figure", false)) and bool(f.get_meta("ck_pathc_ship", false)):
			figs.append(f)
	# board crops (3x) around each armed ship piece
	for f in figs:
		var key := _key(f)
		var cam: Camera3D = f.get_viewport().get_camera_3d()
		var layer: Node = f.get_viewport().get_parent()
		var sp: Vector2 = cam.unproject_position((f as Node3D).global_position + Vector3(0, 0.0, 0))
		var off := Vector2.ZERO
		if layer is Control:
			off = (layer as Control).get_global_rect().position
		var c := sp + off
		var r := Rect2i(int(c.x) - 50, int(c.y) - 125, 100, 140)
		r = r.intersection(Rect2i(0, 0, shot.get_width(), shot.get_height()))
		var crop := shot.get_region(r)
		crop.resize(r.size.x * 3, r.size.y * 3, Image.INTERPOLATE_NEAREST)
		crop.save_png("%s/board_crop3x_%s_%s.png" % [out, key, tag])
	# close-ups in a private world
	var vp := SubViewport.new()
	vp.size = Vector2i(560, 760)
	vp.transparent_bg = false
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var w := Node3D.new()
	vp.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.40, 0.36)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.86)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 20, 0)
	sun.light_energy = 0.95
	w.add_child(sun)
	var cam3 := Camera3D.new()
	cam3.fov = 26.0
	w.add_child(cam3)
	cam3.current = true
	var subjects: Array = []
	for f in figs:
		subjects.append([_key(f), f, ""])
	for f in figs:
		if str(f.get_meta("ck_model", "")).ends_with("outfit_light_inf_t1_m.glb"):
			subjects.append(["spear_probe_light_inf", f, "weapon_spear"])
	for s in subjects:
		var d: Node3D = (s[1] as Node3D).duplicate()
		d.transform = Transform3D.IDENTITY
		var ap := d.find_children("*", "AnimationPlayer", true, false)
		for p in ap:
			(p as AnimationPlayer).stop()
			(p as AnimationPlayer).active = false
		var unit: Node3D = d.get_node_or_null("Unit")
		if str(s[2]) != "" and unit != null:
			for old in unit.find_children("ShipWeapon", "", true, false):
				old.free()
			for old in unit.get_children():
				if str(old.name).begins_with("ShipWeapon"):
					old.free()
			CKBoardFigure._attach_ship_weapon(unit, {"weapon": s[2]}, {}, 1.0, false)
		w.add_child(d)
		var hand_w := Vector3(0, 0.95, 0)
		if unit != null:
			for wpn in unit.get_children():
				if str(wpn.name).begins_with("ShipWeapon") and wpn.has_meta("ck_grip_hand"):
					hand_w = unit.transform * (wpn.get_meta("ck_grip_hand") as Vector3)
		for vn in ["front", "q34", "hand_front", "hand_q34"]:
			var yaw := deg_to_rad(40.0 if vn.ends_with("q34") else 0.0)
			var tgt := Vector3(0, 0.95, 0)
			var dist := 5.2
			if vn.begins_with("hand"):
				tgt = hand_w
				dist = 1.6
			cam3.position = tgt + Vector3(sin(yaw), 0.12, cos(yaw)) * dist
			cam3.look_at(tgt)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("%s/close_%s_%s_%s.png" % [out, s[0], vn, tag])
		d.free()
	print("PATHC GRIP SHOTS DONE ", subjects.size())
	get_tree().quit(0)

func _key(f: Node) -> String:
	var m := str(f.get_meta("ck_model", "")).get_file().get_basename()
	return m
