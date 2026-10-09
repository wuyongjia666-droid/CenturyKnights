extends Node
## BTL-09: bond rank sets the link chance, the forecast names the partner,
## and the cutscene payload carries the link segment.


var _battle


func _ready() -> void:
	await get_tree().process_frame
	var err := _table()
	if err == "":
		err = await _scene()
	if err != "":
		print("FAIL link: ", err)
		get_tree().quit(1)
		return
	print("LINK PASS")
	get_tree().quit(0)


func _table() -> String:
	if BattleRules.link_chance("C", false) != 25:
		return "C chance"
	if BattleRules.link_chance("B", false) != 45:
		return "B chance"
	if BattleRules.link_chance("A", false) != 70:
		return "A chance"
	if BattleRules.link_chance("A", true) != 85:
		return "kin resonance"
	if BattleRules.link_chance("", true) != 0:
		return "kin without a bond"
	return ""


func _scene() -> String:
	GameState.new_game("Probe", "Ash", "#" + "6ED4FF")
	var leader: CKCharacter = GameState.get_leader()
	GameState.deploy_ids = [leader.id]
	GameState.set_meta("battle_map", "obj_rout")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var ai := -1
	var di := -1
	for i in _battle.units.size():
		if str(_battle.units[i].team) == "player" and ai < 0:
			ai = i
		elif str(_battle.units[i].team) == "enemy" and di < 0:
			di = i
	if ai < 0 or di < 0:
		return "deployment missing"
	leader.cast_key = "dengying"
	leader.parent_ids = ["shared_parent"]
	var partner := CKCharacter.new()
	partner.id = "link_partner"
	partner.name = "Zhegan"
	partner.alive = true
	partner.hp = 20
	partner.max_hp = 20
	partner.job_id = "squire"
	partner.cast_key = "zhegan"
	partner.name = "Zhegan"
	partner.parent_ids = ["shared_parent"]
	partner.hp = 20
	partner.max_hp = 20
	GameState.characters[partner.id] = partner
	var beside: Vector2i = _battle.units[ai].pos + Vector2i(1, 0)
	_battle.units.append({"char": partner, "pos": beside, "team": "player", "done": false})
	Bonds.note_event("dengying", "zhegan", 9)
	if Bonds.rank("dengying", "zhegan") != "A":
		return "bond did not reach A"
	var names: Array = BattleRules.link_names(_battle.units, ai)
	if names.is_empty() or str(names[0]) != "Zhegan":
		return "forecast names %s" % str(names)
	var info := ForecastPanel.sides(leader, _battle.units[di].char, "plain", _battle._combat_extras(ai, di), _battle.units[ai].pos, _battle.units[di].pos)
	var shown: Array = info.get("link_names", [])
	if shown.is_empty() or str(shown[0]) != "Zhegan":
		return "panel payload missed the partner"
	var found := false
	for seed in range(1, 40):
		_battle.rng.seed = seed
		_battle.units[di].char.hp = 400
		_battle.units[di].char.max_hp = 400
		_battle._link_seg = {}
		_battle._do_attack(ai, di)
		var seg: Array = _battle.get_meta("cut_links", [])
		if seg.is_empty():
			continue
		var row: Dictionary = seg[0]
		if str(row.get("name", "")) != "Zhegan":
			return "segment name"
		if str(row.get("kind", "")) not in ["strike", "guard"]:
			return "segment kind"
		found = true
		break
	if not found:
		return "no link segment in 39 seeds"
	return ""
