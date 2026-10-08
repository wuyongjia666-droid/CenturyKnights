extends Node
## AUD-02：武器变体不连击、音高变化、地形脚步、群系底噪、响度与字节重跑。

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL sfx: ", err)
		get_tree().quit(1)
	else:
		print("SFX PASS")
		get_tree().quit(0)

func _run() -> String:
	if Sfx == null:
		return "autoloads not ready"
	var api := _check_api()
	if api != "":
		return api
	var loud := _python("loudness_check.py", "LOUDNESS PASS")
	if loud != "":
		return loud
	return _python("sfx_v92.py", "SFX VERIFY PASS", ["--verify"])

func _check_api() -> String:
	if not Sfx.has_method("hit") or not Sfx.has_method("click") or not Sfx.has_method("play"):
		return "old api missing"
	var legacy := Sfx.get_node_or_null("hit") as AudioStreamPlayer
	if legacy == null or legacy.bus != "SFX":
		return "legacy hit bus"
	Sfx._rng.seed = 9202601
	for weapon in Sfx.WEAPONS:
		var ids: Array = Sfx._groups.get(weapon, [])
		if ids.size() < 3:
			return weapon + " variants"
		var previous := ""
		for _i in 12:
			var pick := str(Sfx.pick_variant(weapon))
			if pick == "" or not pick.begins_with("hit_" + weapon + "_"):
				return "bad pick " + pick
			if pick == previous:
				return weapon + " repeated " + pick
			previous = pick
		Sfx.play_weapon(weapon)
		var played := str(Sfx._last_pick.get(weapon, ""))
		var player := Sfx.get_node_or_null(played) as AudioStreamPlayer
		if player == null or player.stream == null or not player.playing:
			return weapon + " stream"
		if player.pitch_scale < 0.96 or player.pitch_scale > 1.05:
			return weapon + " pitch"
	var pitches: Array = []
	for _i in 24:
		pitches.append(Sfx.next_pitch())
	var lo: float = pitches.min()
	var hi: float = pitches.max()
	if hi - lo < 0.02:
		return "pitch span"
	for terrain in Sfx.TERRAINS:
		var a := str(Sfx.pick_variant("step_" + terrain))
		var b := str(Sfx.pick_variant("step_" + terrain))
		if a == "" or a == b or not a.begins_with("step_" + terrain):
			return "step " + terrain
		var step := Sfx.get_node_or_null(a) as AudioStreamPlayer
		if step == null or step.stream == null or step.bus != "SFX":
			return "step stream " + terrain
	for biome in Sfx.BIOMES:
		var path := "res://assets/sfx/amb_%s.ogg" % biome
		if not ResourceLoader.exists(path):
			return "missing ambience " + biome
	Sfx.play_ambience("marsh")
	if Sfx._ambience_id != "amb_marsh" or not Sfx._ambience.playing:
		return "ambience play"
	if Sfx._ambience.bus != "Ambience":
		return "ambience bus"
	Sfx.play_ambience("no-such-biome")
	if Sfx._ambience.playing:
		return "unknown biome kept playing"
	for ui_id in Sfx.UI_SET:
		var ui := Sfx.get_node_or_null(ui_id) as AudioStreamPlayer
		if ui == null or ui.stream == null or ui.bus != "UI":
			return "ui set " + ui_id
	Sfx.play_attack("magic")
	if str(Sfx._last_pick.get("spell", "")) == "":
		return "attack map"
	Sfx.hit()
	Sfx.click()
	Sfx.confirm()
	return ""

func _python(script_name: String, needle: String, extra: Array = []) -> String:
	var project := ProjectSettings.globalize_path("res://")
	var script := project.path_join("../tools/audio/" + script_name)
	var args: Array = [script]
	for item in extra:
		args.append(str(item))
	var output: Array = []
	var code := OS.execute("python3", args, output, true)
	var text := ""
	for line in output:
		text += str(line)
	if code != 0 or text.find(needle) < 0:
		return script_name + " failed (%d) %s" % [code, text.right(400)]
	return ""
