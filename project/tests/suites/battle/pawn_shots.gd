extends Node
## Board-piece screenshots: battle board at desktop + mobile gate resolutions.
## args: --out=DIR [--before] [--map=ID]

func _ready() -> void:
	var out := "/tmp/ck_pawn"
	var before := false
	var map := "ch0_pass"
	var scene := "battle"
	var seq := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		if a == "--before": before = true
		if a.begins_with("--map="): map = a.substr(6)
		if a.begins_with("--scene="): scene = a.substr(8)
		if a == "--seq": seq = true
	if DisplayServer.get_name() == "headless":
		print("PAWN SHOTS headless-skip")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var res := [Vector2i(1280, 720)] if not DeviceProfile.is_mobile() else [Vector2i(2400, 1080), Vector2i(2340, 1080), Vector2i(1920, 1080), Vector2i(2560, 1600)]
	for r in res:
		GameState.new_game("Ash", "Banner", "#%02x%02x%02x" % [110, 212, 255])
		GameState.set_meta("battle_map", map)
		GameState.set_meta("cutscenes_on", false)
		GameState.settings["cutscenes"] = false
		get_window().size = r
		await get_tree().process_frame
		var node = load("res://scenes/battle/battle.tscn" if scene == "battle" else "res://scenes/hub/%s.tscn" % scene).instantiate()
		get_tree().root.add_child(node)
		get_tree().current_scene = node
		if before:
			var f = node.get_node_or_null("BoardFigures")
			if f: f.queue_free()
		if DeviceProfile.is_mobile():
			MobileChrome.call_deferred("_apply")
		await get_tree().create_timer(1.5).timeout
		if scene == "battle":
			node.map_draw.queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s_%dx%d.png" % [out, scene, "before" if before else "after", r.x, r.y])
		print("SHOT ", r)
		if seq and scene == "battle":
			await _sequence(node, out)
		node.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)


## Frame sequence: walk 2 cells → attack → hit → death fade (drives CKBoardAnim directly).
func _sequence(b, out: String) -> void:
	await get_tree().create_timer(2.5).timeout  # let every strip finish rendering
	var dir := out + "/seq"
	DirAccess.make_dir_recursive_absolute(dir)
	var pl = null
	var en = null
	for u in b.units:
		if pl == null and str(u.team) == "player": pl = u
		if en == null and str(u.team) == "enemy": en = u
	var n := 0
	var target: Vector2i = en.pos + Vector2i(-1, 0)
	pl.pos = target
	b.selected = b.units.find(pl)
	for f in 14:
		await _snap(b, dir, n); n += 1
	var cpx = func(c: Vector2i) -> Vector2: return b.ORIGIN + Vector2(c) * b.CELL + Vector2(b.CELL / 2, b.CELL / 2)
	b._board_anim.note_attack(pl, cpx.call(en.pos), cpx.call(pl.pos))
	b._board_anim.note_hit(en, cpx.call(en.pos) - cpx.call(pl.pos), cpx.call(en.pos))
	for f in 12:
		await _snap(b, dir, n); n += 1
	en.char.hp = 0
	for f in 12:
		await _snap(b, dir, n); n += 1
	print("SEQ ", n)

func _snap(b, dir: String, n: int) -> void:
	await get_tree().create_timer(0.06).timeout
	b.map_draw.queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/f%03d.png" % [dir, n])
