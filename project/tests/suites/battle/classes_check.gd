extends Node
## BTL-06: twenty jobs, a scene proof for each tier-3 mechanic, and a 1v1 band.


const TRIALS := 24
## Role pairs the formula already treats as counters. Everyone else must stay in band.
const COUNTER_ROLES := [
	["cavalry", "mage"],
	["cavalry", "skirmisher"],
	["tank", "skirmisher"],
	["tank", "cavalry"],
	["tank", "ranger"],
	["ranger", "skirmisher"],
	["ranger", "cavalry"],
	["mage", "tank"],
]


var _battle


func _ready() -> void:
	await get_tree().process_frame
	var err := _roster()
	if err == "":
		err = await _scene()
	if err == "":
		err = _balance()
	if err != "":
		print("FAIL classes: ", err)
		get_tree().quit(1)
		return
	print("CLASSES PASS")
	get_tree().quit(0)


func _roster() -> String:
	var jobs: Array = GameState.data_jobs.get("jobs", [])
	if jobs.size() < 20:
		return "job count %d" % jobs.size()
	if GameState.data_skills.get("skills", []).size() < 90:
		return "skill count"
	var mechs := {}
	for row in jobs:
		if int(row.get("tier", 0)) != 3:
			continue
		if str(row.get("promote_from", "")) == "":
			return "missing promote_from %s" % row.get("id")
		var mech := str(row.get("mechanic", ""))
		if mech == "" or mechs.has(mech):
			return "mechanic %s" % mech
		mechs[mech] = true
	if mechs.size() < 9:
		return "tier3 count"
	return ""


func _scene() -> String:
	var err := _formulas()
	if err != "":
		return err
	GameState.new_game("Probe", "Ash", "#" + "6ED4FF")
	var leader: CKCharacter = GameState.get_leader()
	GameState.deploy_ids = [leader.id]
	GameState.set_meta("battle_map", "obj_rout")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var ai := _index("player")
	var di := _index("enemy")
	if ai < 0 or di < 0:
		return "deploy"
	leader.job_id = "outrider"
	_battle.units[di].char.hp = 80
	_battle._do_attack(ai, di)
	if not bool(_battle.units[ai].get("canto_used", false)) or bool(_battle.units[ai].done):
		return "canto did not reopen movement"
	leader.job_id = "marksman"
	var near: Vector2i = _battle.units[ai].pos + Vector2i(1, 0)
	var far: Vector2i = _battle.units[ai].pos + Vector2i(2, 0)
	if _battle._can_attack_from(_battle.units[ai], near):
		return "marksman shot point blank"
	if not _battle._can_attack_from(_battle.units[ai], far):
		return "marksman lost the extra range"
	var guard := CKCharacter.new()
	guard.job_id = "bulwark"
	guard.hp = 20
	guard.max_hp = 20
	guard.alive = true
	_battle.units.append({"char": guard, "pos": _battle.units[ai].pos + Vector2i(0, 1), "team": "player", "done": false})
	var extras: Dictionary = _battle._combat_extras(di, ai)
	if int(extras.get("flat_def", 0)) < 3:
		return "guard did not cover the ally"
	var train = load("res://scenes/hub/train.tscn").instantiate()
	add_child(train)
	await get_tree().process_frame
	var paths: Node = train.find_child("ClassPaths", true, false)
	if paths == null or paths.get_child_count() < 9:
		return "train paths missing"
	var line := str(paths.get_child(0).text)
	if line.split(" / ").size() != 3:
		return "path text %s" % line
	return ""


func _formulas() -> String:
	var medic := _unit("medic")
	var patient := _unit("squire")
	patient.hp = patient.max_hp
	var healed: Dictionary = BattleRules.apply_class_heal(medic, patient, 6)
	if int(healed.get("shield", 0)) != 6:
		return "overheal"
	var pierce := _unit("warlock")
	var plain := _unit("cantor")
	var wall := _unit("heavy_inf")
	wall.stats["vit"] = 18
	var hi: Vector2i = BattleRules.calc_damage_range(pierce, wall, "plain")
	var lo: Vector2i = BattleRules.calc_damage_range(plain, wall, "plain")
	if hi.x <= lo.x:
		return "pierce"
	var vet := _unit("veteran")
	var foe := _unit("squire")
	var back := BattleRules.calc_hit(vet, foe, "plain", {"counter": true})
	var front := BattleRules.calc_hit(vet, foe, "plain", {})
	if back < front + 10:
		return "riposte"
	var scout := _unit("pathfinder")
	var amb := BattleRules.calc_hit(scout, foe, "plain", {"flank": true})
	var open := BattleRules.calc_hit(scout, foe, "plain", {})
	if amb < open + 10:
		return "ambush"
	if BattleRules.heal_pulse(_unit("chorister")) < 2:
		return "hymn"
	var units := [
		{"char": _unit("squire"), "pos": Vector2i(1, 1), "team": "player"},
		{"char": _unit("captain"), "pos": Vector2i(2, 1), "team": "player"},
	]
	if BattleRules.adjacent_class_def(units, 0) != 1:
		return "rally"
	var student := _unit("outrider")
	for _i in 3:
		BattleRules.note_class_mastery(student)
	if "outrider_oath" not in student.skills:
		return "mastery"
	return ""


func _balance() -> String:
	var jobs: Array = []
	for row in GameState.data_jobs.get("jobs", []):
		jobs.append(str(row.get("id", "")))
	var bad: Array = []
	for i in jobs.size():
		for j in range(i + 1, jobs.size()):
			var a: String = jobs[i]
			var b: String = jobs[j]
			var rate := _rate(a, b)
			if rate >= 0.25 and rate <= 0.75:
				continue
			if _listed_counter(a, b):
				continue
			bad.append("%s/%s %.2f" % [a, b, rate])
	if not bad.is_empty():
		return "band " + ", ".join(bad)
	return ""


func _listed_counter(a: String, b: String) -> bool:
	var left := BattleRules.job_role(a)
	var right := BattleRules.job_role(b)
	for pair in COUNTER_ROLES:
		if (left == str(pair[0]) and right == str(pair[1])) or (left == str(pair[1]) and right == str(pair[0])):
			return true
	return false


func _rate(a: String, b: String) -> float:
	var wins := 0.0
	for n in TRIALS:
		var left := _unit(a)
		var right := _unit(b)
		left.hp = 28
		left.max_hp = 28
		right.hp = 28
		right.max_hp = 28
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + n
		var open := true
		for _round in 16:
			if not _swing(left, right, rng):
				wins += 1.0
				open = false
				break
			if not _swing(right, left, rng):
				open = false
				break
		if open:
			if left.hp > right.hp:
				wins += 1.0
			elif left.hp == right.hp:
				wins += 0.5
	return wins / float(TRIALS)


func _swing(atk: CKCharacter, defender: CKCharacter, rng: RandomNumberGenerator) -> bool:
	if atk.hp <= 0:
		return false
	var rolled: Dictionary = BattleRules.roll_attack(atk, defender, "plain", rng, {})
	if bool(rolled.get("hit", false)):
		defender.hp -= int(rolled.get("damage", 1))
	return defender.hp > 0


func _unit(job_id: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.job_id = job_id
	c.level = 1
	c.alive = true
	c.hp = 20
	c.max_hp = 20
	for key in ["str", "agi", "vit", "skl", "per", "wil"]:
		c.stats[key] = 8
	return c


func _index(team: String) -> int:
	for i in _battle.units.size():
		if str(_battle.units[i].team) == team:
			return i
	return -1
