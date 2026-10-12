extends Node
## WS-D #48: planner behaviours — soft focus fire, retreat to cover when low, healers hold back,
## guards screen the healer. Plus a headless duel sim: the smart planner must beat the old rush.


func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL ai behavior: ", err)
		get_tree().quit(1)
		return
	print("AI BEHAVIOR PASS")
	get_tree().quit(0)


static func _u(id: String, team: String, x: int, y: int, hp: int, extra: Dictionary = {}) -> Dictionary:
	var u := {"id": id, "team": team, "pos": [x, y], "hp": hp, "max_hp": 20, "move": 3, "reach": 1, "power": 5}
	u.merge(extra, true)
	return u


static func _plan(units: Array, cover: Dictionary = {}) -> Dictionary:
	var out := {}
	for a in AIPlanner.plan({"w": 12, "h": 9, "tier": 1, "objective": {"type": "rout"}, "units": units, "cover": cover}):
		out[str(a["id"])] = a
	return out


func _run() -> String:
	# soft focus: nobody can kill, both enemies hit the same (healer) target
	var p := _plan([_u("e1", "enemy", 0, 4, 20), _u("e2", "enemy", 6, 4, 20),
		_u("pa", "player", 3, 3, 20), _u("ph", "player", 3, 5, 18, {"healer": true})])
	if str(p["e1"]["target"]) != "ph" or str(p["e2"]["target"]) != "ph":
		return "soft focus %s / %s" % [p["e1"], p["e2"]]
	# retreat: wounded enemy with no kill moves to lower threat, prefers cover
	p = _plan([_u("e1", "enemy", 5, 4, 5), _u("pa", "player", 3, 4, 20, {"power": 2})], {"8,4": 2.0})
	if str(p["e1"]["action"]) != "retreat":
		return "no retreat %s" % p["e1"]
	var cell: Vector2i = p["e1"]["cell"]
	if absi(cell.x - 3) + absi(cell.y - 4) <= 2:
		return "retreat stayed close %s" % cell
	# wounded but can finish someone: keeps fighting
	p = _plan([_u("e1", "enemy", 5, 4, 5), _u("pa", "player", 4, 4, 3)])
	if str(p["e1"]["action"]) != "attack":
		return "wounded killer retreated %s" % p["e1"]
	# boss never retreats
	p = _plan([_u("b", "enemy", 5, 4, 5, {"boss": true, "max_hp": 10})], {})
	if str(p["b"]["action"]) == "retreat":
		return "boss retreated"
	# healer holds outside threat; a guard steps between healer and the foe
	p = _plan([_u("h", "enemy", 8, 4, 20, {"healer": true}), _u("g", "enemy", 9, 2, 20), _u("w", "enemy", 7, 6, 9),
		_u("pa", "player", 3, 4, 20, {"power": 2})])
	if str(p["h"]["action"]) not in ["move", "wait"]:
		return "healer %s" % p["h"]
	var th := AIPlanner.threat_map({"w": 12, "h": 9, "units": [_u("pa", "player", 3, 4, 20)]})
	var hc: Vector2i = p["h"]["cell"]
	if int(th.get("%d,%d" % [hc.x, hc.y], 0)) > 0:
		return "healer walked into threat %s" % hc
	if str(p["g"]["action"]) != "guard" or str(p["g"]["target"]) != "h":
		return "guard %s" % p["g"]
	# duel sim: focus fire must finish fights faster than tier-0 rush
	var smart := _duel(1)
	var rush := _duel(0)
	if smart > rush:
		return "smart AI slower (%d vs %d rounds)" % [smart, rush]
	return ""


## Tiny deterministic sim on the planner board: enemies act from the plan, players stand still.
static func _duel(tier: int) -> int:
	var units: Array = [_u("e1", "enemy", 0, 0, 20, {"power": 6, "move": 4}), _u("e2", "enemy", 0, 8, 20, {"power": 6, "move": 4}),
		_u("e3", "enemy", 11, 4, 20, {"power": 6, "move": 4}),
		_u("p1", "player", 5, 3, 22), _u("p2", "player", 5, 5, 22), _u("p3", "player", 6, 4, 22)]
	for rnd in range(1, 30):
		var alive := 0
		for u in units:
			if u["team"] == "player" and int(u["hp"]) > 0:
				alive += 1
		if alive < 3:
			return rnd
		for a in AIPlanner.plan({"w": 12, "h": 9, "tier": tier, "objective": {"type": "rout"}, "units": units}):
			for u in units:
				if str(u["id"]) == str(a["id"]):
					var c: Vector2i = a["cell"]
					u["pos"] = [c.x, c.y]
			if str(a["action"]) == "attack":
				for t in units:
					if str(t["id"]) == str(a["target"]):
						t["hp"] = int(t["hp"]) - 6
	return 30
