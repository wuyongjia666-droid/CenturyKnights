extends Node
## CUT-05: three hit-stop tiers, time_scale restored, reduced-motion punch is zero.

func _ready() -> void:
	var err: String = await _run()
	if err != "":
		print("FAIL impact: ", err)
		get_tree().quit(1)
	else:
		print("IMPACT PASS")
		get_tree().quit(0)

func _run() -> String:
	Engine.time_scale = 1.0
	var prev := -1.0
	for w in ["light", "mid", "heavy"]:
		var want := CutsceneVfx.hit_stop_seconds(w)
		var t0 := Time.get_ticks_msec()
		await CutsceneVfx.play_hit_stop(get_tree(), w)
		var dt := float(Time.get_ticks_msec() - t0) / 1000.0
		if absf(dt - want) > 0.08:
			return "%s measured %.3f want %.3f" % [w, dt, want]
		if dt <= prev + 0.01:
			return "tiers not ordered at %s (%.3f after %.3f)" % [w, dt, prev]
		prev = dt
		if not is_equal_approx(Engine.time_scale, 1.0):
			return "time_scale left at %s after %s" % [Engine.time_scale, w]
		print("hitstop %s %.3fs scale %.2f" % [w, dt, CutsceneVfx.time_scale_for(w)])
	if not is_equal_approx(Engine.time_scale, 1.0):
		return "time_scale final"
	if not is_equal_approx(CutsceneVfx.punch_strength(true, "heavy"), 0.0):
		return "reduced punch"
	if not is_equal_approx(CutsceneVfx.punch_strength(true, "light"), 0.0):
		return "reduced punch light"
	var light_p := CutsceneVfx.punch_strength(false, "light")
	var mid_p := CutsceneVfx.punch_strength(false, "mid")
	var heavy_p := CutsceneVfx.punch_strength(false, "heavy")
	if not (light_p > 0.0 and light_p < mid_p and mid_p < heavy_p):
		return "punch tiers"
	if CutsceneVfx.weight_of_job("warrior") != "heavy" or CutsceneVfx.weight_of_job("heavy_inf") != "heavy":
		return "heavy jobs"
	if CutsceneVfx.weight_of_job("hunter") != "light" or CutsceneVfx.weight_of_job("priest") != "light":
		return "light jobs"
	if CutsceneVfx.weight_of_job("light_inf") != "mid" or CutsceneVfx.weight_of_job("squire") != "mid":
		return "mid jobs"
	var src := FileAccess.get_file_as_string("res://shaders/frost_dissolve.gdshader")
	if src.find("0.431") < 0 or src.find("discard") < 0:
		return "dissolve shader"
	var banned_gold := "#" + "c9a227"
	if src.to_lower().find("blood") >= 0 or src.find(banned_gold) >= 0:
		return "dissolve palette"
	var heavy_kill := {
		"from": "left", "hit": true, "crit": true, "killed": true,
		"skill": "破旗斩", "weight": "heavy", "dmg": 9, "hp_after": 0,
	}
	var built := CutsceneTimeline.build_strike(heavy_kill, {"seen_skills": {}})
	if not CutsceneTimeline.within_budget(built):
		return "heavy kill over budget %.3f" % float(built.get("total", 0.0))
	return ""
