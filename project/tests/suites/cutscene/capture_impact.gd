extends Node
## Stills for hit-stop weight and the frost break. CK_CUTSCENE_OUT sets the folder.

func _ready() -> void:
	var dir := OS.get_environment("CK_CUTSCENE_OUT")
	if dir == "":
		dir = "/tmp/ck_impact"
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.settings["cutscene_mode"] = "full"
	GameState.settings["reduced_motion"] = false
	CombatCutscene.speed = 1.0
	var ally := _person("ally", "霜灯", "player", "light_inf", "leader")
	var foe := _person("foe", "峡影", "enemy", "warrior", "")
	var err := await _snap(dir, "heavy_hit", ally, foe, {
		"crit": true, "killed": false, "dmg": 14, "hp_after": 18, "weight": "heavy", "job_id": "warrior",
	})
	if err == "":
		err = await _snap(dir, "frost_break", ally, foe, {
			"crit": true, "killed": true, "dmg": 32, "hp_after": 0, "weight": "heavy", "job_id": "warrior",
		})
	if err != "":
		print("CAPTURE FAIL ", err)
		get_tree().quit(1)
		return
	print("CAPTURE OK ", dir)
	get_tree().quit(0)

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

func _snap(dir: String, tag: String, ally: CKCharacter, foe: CKCharacter, extra: Dictionary) -> String:
	var strike := {
		"from": "right", "hit": true,
		"crit": bool(extra.get("crit", false)),
		"killed": bool(extra.get("killed", false)),
		"skill": "",
		"dmg": int(extra.get("dmg", 8)),
		"hp_after": int(extra.get("hp_after", 20)),
		"weight": str(extra.get("weight", "mid")),
		"job_id": str(extra.get("job_id", "light_inf")),
		"ranged": false,
	}
	var rec := {
		"right": {"char": ally, "team": "player", "hp0": 32, "hit": 80, "dmg": 9, "crit": 8},
		"left": {"char": foe, "team": "enemy", "template": "bandit", "hp0": 32, "hit": 55, "dmg": 6, "crit": 3},
		"strikes": [strike],
		"ground": "snow",
		"grade": Color(0.82, 0.88, 0.94),
		"backdrop": "res://assets/art/battle/v8_battle_biome_snow.png",
		"title": tag,
	}
	var cs := CombatCutscene.new()
	cs.setup(rec)
	add_child(cs)
	# Frame time on llvmpipe overshoots the 50ms wait slices, so a wall-clock
	# fraction of the timeline lands before the hit. Wait for the beat itself.
	var killed := bool(extra.get("killed", false))
	var start := Time.get_ticks_msec()
	var ready := false
	while Time.get_ticks_msec() - start < 12000:
		if not is_instance_valid(cs):
			return "%s closed" % tag
		if killed:
			if _max_dissolve(cs) > 0.16:
				ready = true
				break
		elif _has_label(cs):
			ready = true
			break
		await get_tree().process_frame
	if not ready:
		return "%s missed beat" % tag
	for _i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return "%s no image" % tag
	var path := dir.path_join("%s.png" % tag)
	if img.save_png(path) != OK:
		return "%s save" % tag
	print("still ", path)
	if is_instance_valid(cs):
		cs.queue_free()
	await get_tree().process_frame
	return ""

func _has_label(n: Node) -> bool:
	if n is Label3D:
		return true
	for ch in n.get_children():
		if _has_label(ch):
			return true
	return false

func _max_dissolve(n: Node) -> float:
	var best := -1.0
	if n is MeshInstance3D:
		var mat := (n as MeshInstance3D).material_override
		if mat is ShaderMaterial:
			best = float((mat as ShaderMaterial).get_shader_parameter("dissolve"))
	for ch in n.get_children():
		best = maxf(best, _max_dissolve(ch))
	return best
