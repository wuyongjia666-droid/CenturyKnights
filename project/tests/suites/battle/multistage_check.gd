extends Node
## BTL-11: a two-stage map keeps HP and status. An arena fight writes no injury.

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")

var _battle


func _ready() -> void:
	await get_tree().process_frame
	var err := await _stages()
	if err == "":
		err = await _arena()
	if err != "":
		print("FAIL multistage: ", err)
		get_tree().quit(1)
		return
	print("MULTISTAGE PASS")
	get_tree().quit(0)


func _stages() -> String:
	GameState.new_game("Probe", "Ash", "#" + "6ED4FF")
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return "no leader"
	GameState.deploy_ids = [leader.id]
	GameState.set_meta("battle_map", "stage_a")
	_battle = BATTLE_SCENE.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if str(_battle.map_id) != "stage_a":
		return "opened %s" % str(_battle.map_id)
	var ui := _player_index()
	if ui < 0:
		return "player missing"
	leader.hp = mini(11, leader.max_hp)
	leader.temp_combat_lock = 2
	_kill_enemies()
	_battle._check_end()
	if bool(_battle.battle_over):
		return "stage A ended the battle"
	if str(_battle.map_id) != "stage_b":
		return "stayed on %s" % str(_battle.map_id)
	if int(leader.hp) != mini(11, leader.max_hp):
		return "hp changed to %d" % int(leader.hp)
	if int(leader.temp_combat_lock) != 2:
		return "lock dropped"
	_kill_enemies()
	_battle._check_end()
	if not bool(_battle.battle_over):
		return "stage B did not finish"
	_battle.queue_free()
	_battle = null
	await get_tree().process_frame
	return ""


func _arena() -> String:
	GameState.new_game("Probe", "Ash", "#" + "6ED4FF")
	var leader: CKCharacter = GameState.get_leader()
	GameState.deploy_ids = [leader.id]
	GameState.set_meta("battle_map", "arena_yard")
	_battle = BATTLE_SCENE.instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var full := int(leader.hp)
	if full < 1:
		return "arena opened at 0 hp"
	leader.skills.append("power_strike")
	leader.skill_uses["power_strike"] = 1
	leader.skill_cd["power_strike"] = 0
	var ui := _player_index()
	if not _battle._player_skills(ui).is_empty():
		return "arena still offered a skill"
	leader.hp = 0
	leader.injured = false
	_battle._finish(true)
	if int(leader.hp) != full:
		return "arena wrote hp %d" % int(leader.hp)
	if bool(leader.injured):
		return "arena wrote an injury"
	return ""


func _player_index() -> int:
	for i in _battle.units.size():
		if str(_battle.units[i].team) == "player":
			return i
	return -1


func _kill_enemies() -> void:
	for u in _battle.units:
		if str(u.team) == "enemy":
			u.char.hp = 0
