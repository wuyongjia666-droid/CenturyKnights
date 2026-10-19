extends Node
## Route C 3D unit layer: headless falls back to 2D tokens; path walk BFS; P3 caps/idle.

func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL unit layer: ", err)
		get_tree().quit(1)
		return
	print("UNIT LAYER PASS")
	get_tree().quit(0)

func _run() -> String:
	var err := _check_caps()
	if err == "":
		err = await _check_path()
	return err

func _check_caps() -> String:
	if DisplayServer.get_name() == "headless" and CKUnitLayer3D.enabled():
		return "headless must use 2D tokens"
	if CKUnitLayer3D.enabled(CKUnitLayer3D.max_units() + 1):
		return "unit cap ignored"
	if CKUnitLayer3D.max_units() > CKUnitLayer3D.MAX_UNITS:
		return "max_units above absolute ceiling"
	if CKUnitLayer3D.IDLE_HZ < 12.0 or CKUnitLayer3D.IDLE_HZ > 15.0:
		return "IDLE_HZ out of 12–15 band"
	var prev_m := OS.get_environment("CK_FORCE_MOBILE")
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var bad := ""
	if DeviceProfile.max_board_units_3d() != 32:
		bad = "desktop max_board_units_3d want 32"
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if bad == "" and DeviceProfile.max_board_units_3d() != 24:
		bad = "mobile max_board_units_3d want 24"
	elif bad == "" and not DeviceProfile.prefer_halo_in_viewport():
		bad = "mobile should prefer halo-in-viewport"
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if bad == "" and DeviceProfile.prefer_halo_in_viewport():
		bad = "desktop should not prefer halo-in-viewport"
	OS.set_environment("CK_FORCE_LOW_END", "1")
	OS.set_environment("CK_FORCE_MOBILE", "1")
	GameState.settings.erase("board_units_3d")
	if bad == "" and CKUnitLayer3D.default_on():
		bad = "low-end default_on should be false"
	GameState.settings["board_units_3d"] = true
	if bad == "" and DisplayServer.get_name() != "headless" and not CKUnitLayer3D.enabled():
		bad = "user toggle should allow 3D on low-end"
	GameState.settings.erase("board_units_3d")
	OS.set_environment("CK_FORCE_LOW_END", "")
	OS.set_environment("CK_FORCE_MOBILE", prev_m)
	return bad

func _check_path() -> String:
	GameState.new_game("层", "灰旗", GameState.crest_color)
	GameState.set_meta("battle_map", "ch0_pass")
	GameState.settings["cutscenes"] = false
	var b = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(b)
	await get_tree().process_frame
	await get_tree().process_frame
	var u = null
	for x in b.units:
		if str(x.team) == "player":
			u = x
			break
	if u == null:
		b.queue_free()
		return "no player unit"
	var a: Vector2i = u.pos
	var to := a
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var c2: Vector2i = a + d * 2
		if b._in_bounds(c2) and not b._terrain_blocked().has(c2) and not b._terrain_blocked().has(a + d):
			to = c2
			break
	if to == a:
		b.queue_free()
		return "no free cell"
	var path: Array = CKBoardUnits.path(b, u, a, to)
	var bad := ""
	if path.is_empty() or path.back() != to:
		bad = "path does not end at target: %s" % [path]
	else:
		var prev := a
		for c in path:
			if absi(c.x - prev.x) + absi(c.y - prev.y) != 1:
				bad = "path not step-by-step: %s" % [path]
				break
			prev = c
	b.queue_free()
	return bad
