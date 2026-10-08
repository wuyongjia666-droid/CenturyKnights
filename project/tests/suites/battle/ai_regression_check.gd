extends Node

const FIXTURE := "res://tests/suites/battle/fixtures/ai_cases.json"


func _ready() -> void:
	var err := _cases()
	if err == "":
		err = _threat()
	if err == "":
		err = _tier()
	if err == "":
		err = _budget()
	if err != "":
		print("FAIL ai regression: ", err)
		get_tree().quit(1)
		return
	print("AI REGRESSION PASS")
	get_tree().quit(0)


func _cases() -> String:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if typeof(parsed) != TYPE_ARRAY:
		return "fixture"
	var cases: Array = parsed
	if cases.size() != 20:
		return "case count %d" % cases.size()
	for case in cases:
		var board := {
			"w": 12,
			"h": 9,
			"tier": int(case.get("tier", 1)),
			"objective": case.get("objective", {}),
			"units": case.get("units", []),
			"summoned": bool(case.get("summoned", false)),
			"boss_phase": float(case.get("boss_phase", 0.5)),
		}
		var got := {}
		for act in AIPlanner.plan(board):
			got[str(act.get("id", ""))] = AIPlanner.code_of(act)
		var expect: Dictionary = case.get("expect", {})
		for eid in expect.keys():
			var allow: Array = expect[eid]
			if str(got.get(eid, "")) not in allow:
				return "%s %s got %s want %s" % [case.get("name", ""), eid, got.get(eid, ""), allow]
	return ""


func _threat() -> String:
	var board := {
		"w": 12, "h": 9, "tier": 1, "objective": {"type": "rout"},
		"units": [{"id": "p1", "team": "player", "pos": [1, 1], "hp": 10, "max_hp": 10, "move": 0, "reach": 1, "power": 1}],
	}
	var threat := AIPlanner.threat_map(board)
	if int(threat.get("1,2", 0)) < 1:
		return "near threat"
	if int(threat.get("8,8", 0)) != 0:
		return "far threat"
	return ""


func _tier() -> String:
	var saved = GameState.settings.get("battle_mode", null)
	GameState.settings["battle_mode"] = "casual"
	if AIPlanner.tier_of(GameState) != 0:
		return "casual tier"
	GameState.settings["battle_mode"] = "classic"
	if AIPlanner.tier_of(GameState) != 2:
		return "classic tier"
	GameState.settings.erase("battle_mode")
	if AIPlanner.tier_of(GameState) != 1:
		return "default tier"
	if saved != null:
		GameState.settings["battle_mode"] = saved
	return ""


func _budget() -> String:
	var units: Array = []
	for i in 12:
		units.append({
			"id": "e%d" % i, "team": "enemy", "pos": [i % 12, 0],
			"hp": 20, "max_hp": 20, "move": 4, "reach": 1, "power": 8,
		})
	for i in 6:
		units.append({
			"id": "p%d" % i, "team": "player", "pos": [i * 2, 6],
			"hp": 12, "max_hp": 20, "move": 4, "reach": 1, "power": 6,
		})
	var board := {"w": 12, "h": 9, "tier": 2, "objective": {"type": "rout"}, "units": units}
	var t0 := Time.get_ticks_usec()
	for _i in 20:
		AIPlanner.plan(board)
		AIPlanner.threat_map(board)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 20.0
	if ms > 50.0:
		return "budget %.2fms" % ms
	print("ai budget %.2fms" % ms)
	return ""
