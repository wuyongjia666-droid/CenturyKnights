extends Node

var _battle
var _deploy


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL deploy: ", err)
		get_tree().quit(1)
		return
	print("DEPLOY PASS")
	get_tree().quit(0)


func _run() -> String:
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	GameState.set_meta("cutscenes_on", false)
	GameState.settings["cutscenes"] = false
	if DeployBrief.cap_line() != BattleObjectives.text("deploy_cap") % GameState.max_deploy():
		return "cap %s" % DeployBrief.cap_line()
	if GameState.max_deploy() != 4:
		return "hall1 %s" % GameState.max_deploy()
	GameState.buildings["hall"] = 3
	if GameState.max_deploy() != 6:
		return "hall3 %s" % GameState.max_deploy()
	if DeployBrief.cap_line() != BattleObjectives.text("deploy_cap") % 6:
		return "cap6 %s" % DeployBrief.cap_line()
	GameState.buildings["hall"] = 1
	var m: Dictionary = BattleMaps.get_map("quest_bandit")
	var suggest := DeployBrief.suggest_line(m)
	if suggest.find(_job("heavy_inf")) < 0 or suggest.find(_job("hunter")) < 0:
		return "suggest %s" % suggest
	var mix := DeployBrief.mix_line(m)
	if mix.find(_job("light_inf")) < 0 or mix.find("2") < 0:
		return "mix %s" % mix
	if DeployBrief.objective_line(m).find(BattleObjectives.text("obj_rout")) < 0:
		return "objective %s" % DeployBrief.objective_line(m)
	var ally: CKCharacter = GameState.characters[GameState.deploy_ids[1]]
	ally.injured = true
	if DeployBrief.bench_reason(ally) != BattleObjectives.text("deploy_hurt"):
		return "bench"
	GameState.set_meta("battle_map", "quest_bandit")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if _player_pos(ally.id) != Vector2i(-1, -1):
		return "injured spawned"
	var leader_id := str(GameState.deploy_ids[0])
	if _player_pos(leader_id) != Vector2i(1, 4):
		return "leader spot %s" % _player_pos(leader_id)
	ally.injured = false
	GameState.deploy_ids = [ally.id, leader_id]
	_battle._deploy()
	if _player_pos(ally.id) != Vector2i(1, 4) or _player_pos(leader_id) != Vector2i(2, 5):
		return "swapped spots %s %s" % [_player_pos(ally.id), _player_pos(leader_id)]
	_deploy = load("res://scenes/hub/deploy.tscn").instantiate()
	add_child(_deploy)
	await get_tree().process_frame
	var before: Array = GameState.deploy_ids.duplicate()
	var saw_map := false
	for n in _deploy._metrics.get_children():
		if n is DeployMinimap:
			saw_map = true
	if not saw_map:
		return "minimap missing"
	_deploy._focus = GameState.characters[before[0]]
	_deploy._nudge_slot(1)
	if GameState.deploy_ids[0] != before[1] or GameState.deploy_ids[1] != before[0]:
		return "nudge %s" % GameState.deploy_ids
	return ""


func _player_pos(cid: String) -> Vector2i:
	for u in _battle.units:
		if str(u.team) == "player" and str(u.char.id) == cid:
			return u.pos
	return Vector2i(-1, -1)


func _job(job_id: String) -> String:
	return str(GameState.get_job(job_id).get("name", job_id))
