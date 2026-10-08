extends Node
## CUT-01: timeline budgets, key-only gate, hold-to-3× speed. No mesh instantiate.

func _ready() -> void:
	var err: String = await _run()
	if err != "":
		print("FAIL timeline budget: ", err)
		get_tree().quit(1)
	else:
		print("TIMELINE BUDGET PASS")
		get_tree().quit(0)

func _strike(hit: bool, crit: bool = false, killed: bool = false, skill: String = "") -> Dictionary:
	return {
		"from": "left",
		"hit": hit,
		"crit": crit,
		"dmg": 6 if hit else 0,
		"killed": killed,
		"skill": skill,
		"hp_after": 0 if killed else 12,
	}

func _run() -> String:
	Engine.time_scale = 1.0
	var card := {
		"attack": 2.2,
		"dodge": 2.2,
		"crit": 3.0,
		"skill": 3.0,
		"kill": 3.0,
		"first_skill": 4.0,
	}
	var cases := [
		["attack", _strike(true), {}],
		["dodge", _strike(false), {}],
		["crit", _strike(true, true), {}],
		["first_skill", _strike(true, false, false, "破旗斩"), {}],
		["skill", _strike(true, false, false, "破旗斩"), {"破旗斩": true}],
		["kill", _strike(true, false, true), {}],
		["kill", _strike(true, true, true, "朔夜凝视"), {}],
	]
	for row in cases:
		var want: String = row[0]
		var strike: Dictionary = row[1]
		var seen: Dictionary = row[2]
		var built := CutsceneTimeline.build_strike(strike, {"seen_skills": seen, "ranged": false})
		if str(built.get("kind", "")) != want:
			return "kind %s got %s" % [want, built.get("kind")]
		if float(built.get("total", 99.0)) > float(card[want]) + 0.0001:
			return "%s total %.3f over %.2f" % [want, float(built.get("total", 0.0)), float(card[want])]
		if not CutsceneTimeline.within_budget(built):
			return "%s budget helper" % want
		var impact := float(built.get("impact", -1.0))
		var swing_at := _swing_start(built.get("segments", []))
		var action := str(built.get("action", "attack"))
		if not is_equal_approx(impact - swing_at, CutsceneTimeline.action_impact(action)):
			return "%s impact %.3f != %s" % [want, impact - swing_at, action]
		print("timeline %s %.3fs budget %.1f impact %.3f" % [want, built.total, card[want], impact])
	if not is_equal_approx(CutsceneTimeline.action_impact("attack"), 0.458):
		return "attack impact drifted"
	if not is_equal_approx(CutsceneTimeline.action_impact("skill"), 0.792):
		return "skill impact drifted"
	if not is_equal_approx(CutsceneTimeline.action_impact("crit"), 0.5):
		return "crit impact drifted"
	var royals := CutsceneTimeline.royal_table()
	if royals.size() != 10:
		return "royal skills %d" % royals.size()
	var royal_name := ""
	for id in royals.keys():
		royal_name = str(royals[id].get("name", ""))
		break
	if royal_name == "" or not CutsceneTimeline.is_royal_skill(royal_name):
		return "royal name lookup"
	var plain := {"strikes": [_strike(true)], "left": {"template": "bandit"}, "right": {"template": "bandit_weak"}}
	if CutsceneTimeline.should_instantiate(plain, CutsceneTimeline.MODE_KEY):
		return "key mode instantiated a normal attack"
	if not CutsceneTimeline.should_instantiate(plain, CutsceneTimeline.MODE_FULL):
		return "full mode dropped a normal attack"
	if CutsceneTimeline.should_instantiate(plain, CutsceneTimeline.MODE_OFF):
		return "off mode instantiated"
	var crit_rec := {"strikes": [_strike(true, true)], "left": {"template": "bandit"}, "right": {}}
	if not CutsceneTimeline.should_instantiate(crit_rec, CutsceneTimeline.MODE_KEY):
		return "key mode dropped a crit"
	var royal_rec := {"strikes": [_strike(true, false, false, royal_name)], "left": {}, "right": {}}
	if not CutsceneTimeline.should_instantiate(royal_rec, CutsceneTimeline.MODE_KEY):
		return "key mode dropped a royal skill"
	var kill_rec := {"strikes": [_strike(true, false, true)], "left": {}, "right": {}}
	if not CutsceneTimeline.should_instantiate(kill_rec, CutsceneTimeline.MODE_KEY):
		return "key mode dropped a kill"
	var boss := {"strikes": [_strike(true)], "left": {"template": "bandit_chief"}, "right": {"template": "bandit"}}
	if not CutsceneTimeline.should_instantiate(boss, CutsceneTimeline.MODE_KEY):
		return "key mode dropped a boss"
	if CutsceneTimeline.should_instantiate({"strikes": []}, CutsceneTimeline.MODE_FULL):
		return "empty record instantiated"
	var mixed := {
		"strikes": [_strike(true), _strike(true, true), _strike(false)],
		"left": {"template": "bandit"},
		"right": {"template": "snow_thug"},
	}
	var tl := CutsceneTimeline.for_record(mixed, CutsceneTimeline.MODE_KEY)
	var kept: Array = tl.get("strikes", [])
	if kept.size() != 1:
		return "key playback kept %d strikes" % kept.size()
	if str(kept[0].get("kind", "")) != "crit":
		return "key playback kind %s" % str(kept[0].get("kind", ""))
	var settings_off := {"cutscenes": false}
	if CutsceneTimeline.resolve_mode(settings_off) != CutsceneTimeline.MODE_OFF:
		return "legacy cutscenes=false"
	if CutsceneTimeline.resolve_mode({"cutscene_mode": "key", "cutscenes": true}) != CutsceneTimeline.MODE_KEY:
		return "cutscene_mode key"
	if not is_equal_approx(CutsceneTimeline.effective_speed(1.0, true), 3.0):
		return "hold speed"
	if not is_equal_approx(CutsceneTimeline.effective_speed(2.0, false), 2.0):
		return "base speed"
	var gate := await _early_out(plain)
	if gate != "":
		return gate
	if not is_equal_approx(Engine.time_scale, 1.0):
		return "time_scale %s" % Engine.time_scale
	return ""

func _swing_start(segs: Array) -> float:
	var t := 0.0
	for s in segs:
		if str(s.get("id", "")) == "swing":
			return t
		t += float(s.get("dur", 0.0))
	return -1.0

func _early_out(record: Dictionary) -> String:
	GameState.settings["cutscene_mode"] = CutsceneTimeline.MODE_KEY
	CombatCutscene.stages_built = 0
	var cs := CombatCutscene.new()
	cs.setup(record)
	var flag := {"done": false}
	cs.finished.connect(func(): flag["done"] = true)
	add_child(cs)
	for _i in 30:
		await get_tree().process_frame
		if bool(flag["done"]):
			break
	if not bool(flag["done"]):
		return "key-mode normal attack did not close"
	if CombatCutscene.stages_built != 0:
		return "key-mode normal attack built a stage"
	return ""
