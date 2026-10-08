extends Node
## Royal signatures and projectiles on an ink plate. CK_CUTSCENE_OUT sets the folder.
## Fails when the warm-pixel ratio exceeds style-lock max_warm_ratio 0.22.

func _ready() -> void:
	var dir := OS.get_environment("CK_CUTSCENE_OUT")
	if dir == "":
		dir = "/tmp/ck_vfx"
	DirAccess.make_dir_recursive_absolute(dir)
	var world := Node3D.new()
	add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(7, 8, 12)
	env.ambient_light_color = Color(0.42, 0.50, 0.64)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.look_at_from_position(Vector3(0, 0.9, 7.2), Vector3(0, 0.7, 0), Vector3.UP)
	cam.current = true
	world.add_child(cam)
	var i := 0
	for id in CutsceneVfx.royal_ids():
		var col := i % 5
		var row := int(i / 5)
		var at := Vector3(-2.4 + float(col) * 1.2, 1.55 - float(row) * 1.35, 0)
		CutsceneVfx.spawn_signature(world, at, str(id), "", 0.35)
		i += 1
	CutsceneVfx.spawn_projectile(world, Vector3(-1.4, -0.15, 1.2), Vector3(0.2, -0.15, 1.2), "arrow", CutsceneVfx.FROST, 0.35)
	CutsceneVfx.spawn_projectile(world, Vector3(0.4, -0.15, 1.2), Vector3(1.8, -0.15, 1.2), "bolt", CutsceneVfx.MINT, 0.35)
	for _k in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("CAPTURE FAIL no image")
		get_tree().quit(1)
		return
	var path := dir.path_join("royal_vfx.png")
	if img.save_png(path) != OK:
		print("CAPTURE FAIL save")
		get_tree().quit(1)
		return
	var warm := _warm_ratio(img)
	print("warm_ratio %.4f" % warm)
	print("still ", path)
	if warm > 0.22:
		print("CAPTURE FAIL warm")
		get_tree().quit(1)
		return
	world.queue_free()
	var shot := await _cutscene_still(dir)
	if shot != "":
		print("CAPTURE FAIL ", shot)
		get_tree().quit(1)
		return
	print("CAPTURE OK ", dir)
	get_tree().quit(0)

func _cutscene_still(dir: String) -> String:
	GameState.settings["cutscene_mode"] = "full"
	GameState.settings["reduced_motion"] = false
	CombatCutscene.speed = 1.0
	var ally := _person("ally", "霜灯", "player", "hunter", "leader")
	var foe := _person("foe", "峡影", "enemy", "light_inf", "")
	var strike := {
		"from": "right", "hit": true, "crit": false, "killed": false,
		"skill": "北斗定星", "skill_id": "dipper_fix",
		"dmg": 11, "hp_after": 21, "ranged": true, "weight": "light", "job_id": "hunter",
	}
	var rec := {
		"right": {"char": ally, "team": "player", "hp0": 32, "hit": 80, "dmg": 9, "crit": 8},
		"left": {"char": foe, "team": "enemy", "template": "bandit", "hp0": 32, "hit": 55, "dmg": 6, "crit": 3},
		"strikes": [strike],
		"ground": "snow",
		"grade": Color(0.82, 0.88, 0.94),
		"backdrop": "res://assets/art/battle/v8_battle_biome_snow.png",
		"title": "dipper",
	}
	var cs := CombatCutscene.new()
	cs.setup(rec)
	add_child(cs)
	var start := Time.get_ticks_msec()
	var ready := false
	while Time.get_ticks_msec() - start < 8000:
		if _has_id(cs, "dipper_fix"):
			ready = true
			break
		await get_tree().process_frame
	if not ready:
		return "cutscene missed"
	for _i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return "cutscene image"
	var path := dir.path_join("dipper_shot.png")
	if img.save_png(path) != OK:
		return "cutscene save"
	print("still ", path)
	return ""

func _person(id: String, who: String, team: String, job: String, cast: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = who
	c.gender = "m"
	c.job_id = job
	c.level = 8
	c.hp = 32
	c.max_hp = 32
	c.faction = team
	c.cast_key = cast
	c.blood_mix = {"common_ash": 1.0}
	c.appearance = {"hair": "ink_black", "eyes": "slate", "brow": "straight", "scar": "none"}
	return c

func _has_id(n: Node, id: String) -> bool:
	if n.has_meta("vfx_id") and str(n.get_meta("vfx_id")) == id:
		return true
	for ch in n.get_children():
		if _has_id(ch, id):
			return true
	return false

func _warm_ratio(img: Image) -> float:
	var warm := 0
	var n := 0
	var h := img.get_height()
	var w := img.get_width()
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			n += 1
			if _is_warm(img.get_pixel(x, y)):
				warm += 1
	if n == 0:
		return 1.0
	return float(warm) / float(n)

func _is_warm(c: Color) -> bool:
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	if mx < 0.28:
		return false
	var sat := 0.0 if mx <= 0.001 else (mx - mn) / mx
	if sat < 0.32:
		return false
	var d := mx - mn
	var hue := 0.0
	if mx == c.r:
		hue = fposmod((c.g - c.b) / d, 6.0)
	elif mx == c.g:
		hue = (c.b - c.r) / d + 2.0
	else:
		hue = (c.r - c.g) / d + 4.0
	hue /= 6.0
	return hue >= 0.04 and hue <= 0.16
