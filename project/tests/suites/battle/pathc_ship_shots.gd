extends Node
## Path C ship review shots: real battle board with weapons + enemy rim.
## args: --out=DIR --map=ID --w=1280 --h=720

func _ready() -> void:
	var out := "/tmp/pathc_ship_shots"
	var map_id := "ch0_pass"
	var ww := 1280
	var hh := 720
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--map="):
			map_id = a.substr(6)
		elif a.begins_with("--w="):
			ww = int(a.substr(4))
		elif a.begins_with("--h="):
			hh = int(a.substr(4))
	if DisplayServer.get_name() == "headless":
		print("PATHC SHIP SHOTS headless-skip")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(out)
	GameState.new_game("Ash", "Banner", "#" + Color8(110, 212, 255).to_html(false))
	GameState.set_meta("battle_map", map_id)
	GameState.set_meta("cutscenes_on", false)
	GameState.settings["cutscenes"] = false
	GameState.settings["board_units_3d"] = true
	get_window().size = Vector2i(ww, hh)
	await get_tree().process_frame
	var node = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(node)
	get_tree().current_scene = node
	await get_tree().create_timer(2.2).timeout
	node.map_draw.queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/board_%s_%dx%d.png" % [out, map_id, ww, hh])
	var n := 0
	for f in get_tree().root.find_children("*", "Node3D", true, false):
		if not bool(f.get_meta("ck_board_figure", false)):
			continue
		print("FIG ", f.get_meta("ck_source", ""), " ship=", f.get_meta("ck_pathc_ship", false), " model=", f.get_meta("ck_model", ""), " wpn=", f.get_meta("ck_ship_weapon", ""))
		for wpn in f.find_children("ShipWeapon", "", true, false):
			print("  WPN ", wpn, " pos=", wpn.position, " scale=", wpn.scale)
			for mi in wpn.find_children("*", "MeshInstance3D", true, false):
				if mi is MeshInstance3D:
					print("   MI ", mi.name, " aabb=", (mi as MeshInstance3D).get_aabb())
		n += 1
	print("PATHC SHIP SHOTS DONE ", n)
	get_tree().quit(0)
