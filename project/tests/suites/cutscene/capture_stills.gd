extends Node
## Offscreen stills for cutscene review. Not a CI check (no *_check name).
## CK_CUTSCENE_OUT=/path godot --path project --scene res://tests/suites/cutscene/capture_stills.tscn

func _ready() -> void:
	var dir := OS.get_environment("CK_CUTSCENE_OUT")
	if dir == "":
		dir = "/tmp/ck_cutscene"
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.settings["cutscene_mode"] = "full"
	GameState.settings["cutscenes"] = true
	GameState.settings["reduced_motion"] = false
	CombatCutscene.speed = 1.0
	var ally := _person("ally", "霜灯", "player", "light_inf", "leader")
	var foe := _person("foe", "峡影", "enemy", "light_inf", "")
	var err := await _snap(dir, "attack", ally, foe, _strike(false, false))
	if err == "":
		err = await _snap(dir, "crit", ally, foe, _strike(true, false))
	if err == "":
		err = await _snap(dir, "kill", ally, foe, _strike(true, true))
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
	c.age = 28
	c.job_id = job
	c.level = 6
	c.hp = 32
	c.max_hp = 32
	c.faction = team
	c.cast_key = cast
	c.blood_mix = {"common_ash": 1.0}
	c.appearance = {"hair": "ink_black", "eyes": "slate", "brow": "straight", "scar": "none"}
	return c

func _strike(crit: bool, killed: bool) -> Dictionary:
	return {
		"from": "right",
		"hit": true,
		"crit": crit,
		"dmg": 32 if killed else (11 if crit else 7),
		"killed": killed,
		"skill": "",
		"hp_after": 0 if killed else (21 if crit else 25),
		"ranged": false,
	}

func _snap(dir: String, tag: String, ally: CKCharacter, foe: CKCharacter, strike: Dictionary) -> String:
	var rec := {
		"right": {"char": ally, "team": "player", "template": "", "hp0": ally.hp, "hit": 84, "dmg": 8, "crit": 6},
		"left": {"char": foe, "team": "enemy", "template": "bandit", "hp0": foe.max_hp, "hit": 61, "dmg": 5, "crit": 4},
		"strikes": [strike],
		"ground": "grass",
		"grade": Color(0.78, 0.84, 0.90),
		"backdrop": "res://assets/art/battle/v8_battle_biome_pass.png",
		"title": "隘口 · 过场",
	}
	var cs := CombatCutscene.new()
	cs.setup(rec)
	add_child(cs)
	var built := CutsceneTimeline.build_strike(strike, {"seen_skills": {}, "ranged": false})
	var hold := float(built.get("impact", 0.8)) + 0.05
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(hold * 1000.0):
		if not is_instance_valid(cs):
			return "%s closed before impact" % tag
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return "%s no image" % tag
	var path := dir.path_join("%s.png" % tag)
	var save_err := img.save_png(path)
	if save_err != OK:
		return "%s save %s" % [tag, save_err]
	print("still ", path, " ", img.get_width(), "x", img.get_height())
	if is_instance_valid(cs):
		cs.queue_free()
	await get_tree().process_frame
	return ""
