extends Node
## One still per camera template. CK_CUTSCENE_OUT sets the folder.

const SHOTS := [
	{"id": "over_shoulder", "t": 0.35, "index": 0, "extra": {}},
	{"id": "side_follow", "t": 0.22, "index": 1, "extra": {}},
	{"id": "low_hero", "t": 0.40, "index": 0, "extra": {"killed": true, "dmg": 32, "hp_after": 0}},
	{"id": "crit_push", "t": 0.62, "index": 0, "extra": {"crit": true, "dmg": 14, "hp_after": 18}},
	{"id": "projectile_follow", "t": 0.50, "index": 0, "extra": {"ranged": true, "dmg": 8, "hp_after": 24}},
	{"id": "skill_orbit", "t": 0.18, "index": 0, "extra": {"skill": "燃图号令", "dmg": 9, "hp_after": 23}},
]

func _ready() -> void:
	var dir := OS.get_environment("CK_CUTSCENE_OUT")
	if dir == "":
		dir = "/tmp/ck_cameras"
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.settings["cutscene_mode"] = "full"
	GameState.settings["cutscenes"] = true
	GameState.settings["reduced_motion"] = false
	CombatCutscene.speed = 1.0
	var ally := _person("ally", "霜灯", "player", "leader")
	var foe := _person("foe", "峡影", "enemy", "")
	for shot in SHOTS:
		var err := await _snap(dir, shot, ally, foe)
		if err != "":
			print("CAPTURE FAIL ", err)
			get_tree().quit(1)
			return
	print("CAPTURE OK ", dir)
	get_tree().quit(0)

func _person(id: String, who: String, team: String, cast: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = who
	c.gender = "m"
	c.age = 28
	c.job_id = "hunter" if cast == "" else "light_inf"
	c.level = 6
	c.hp = 32
	c.max_hp = 32
	c.faction = team
	c.cast_key = cast
	c.blood_mix = {"common_ash": 1.0}
	c.appearance = {"hair": "ink_black", "eyes": "slate", "brow": "straight", "scar": "none"}
	return c

func _snap(dir: String, shot: Dictionary, ally: CKCharacter, foe: CKCharacter) -> String:
	var extra: Dictionary = shot.get("extra", {})
	var strike := {
		"from": "right",
		"hit": true,
		"crit": bool(extra.get("crit", false)),
		"dmg": int(extra.get("dmg", 7)),
		"killed": bool(extra.get("killed", false)),
		"skill": str(extra.get("skill", "")),
		"hp_after": int(extra.get("hp_after", 25)),
		"ranged": bool(extra.get("ranged", false)),
	}
	if bool(strike.ranged):
		ally.job_id = "hunter"
		ally.cast_key = "dengying"
	else:
		ally.job_id = "light_inf"
		ally.cast_key = "leader"
	var rec := {
		"right": {"char": ally, "team": "player", "template": "", "hp0": 32, "hit": 84, "dmg": 8, "crit": 6},
		"left": {"char": foe, "team": "enemy", "template": "bandit_archer" if bool(strike.ranged) else "bandit", "hp0": 32, "hit": 61, "dmg": 5, "crit": 4},
		"strikes": [strike],
		"camera_index": int(shot.get("index", 0)),
		"ground": "grass",
		"grade": Color(0.78, 0.84, 0.90),
		"backdrop": "res://assets/art/battle/v8_battle_biome_pass.png",
		"title": str(shot.get("id", "")),
	}
	var want := CutsceneCameras.select(strike, int(shot.get("index", 0)))
	if want != str(shot.get("id", "")):
		return "%s selected %s" % [shot.get("id", ""), want]
	var cs := CombatCutscene.new()
	cs.setup(rec)
	add_child(cs)
	var built := CutsceneTimeline.build_strike(strike, {"seen_skills": {}, "ranged": bool(strike.ranged)})
	var hold := float(built.get("total", 1.0)) * float(shot.get("t", 0.4))
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(hold * 1000.0):
		if not is_instance_valid(cs):
			return "%s closed early" % shot.get("id", "")
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return "%s no image" % shot.get("id", "")
	var path := dir.path_join("%s.png" % str(shot.get("id", "cam")))
	if img.save_png(path) != OK:
		return "%s save" % shot.get("id", "")
	print("still ", path)
	if is_instance_valid(cs):
		cs.queue_free()
	await get_tree().process_frame
	return ""
