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
	return await _narrow()


func _narrow() -> String:
	var vp := SubViewport.new()
	vp.size = Vector2i(1080, 2400)
	vp.disable_3d = true
	add_child(vp)
	var phone := load("res://scenes/hub/deploy.tscn").instantiate() as Control
	phone.set_meta("mobile_insets", {"left": 0.0, "top": 96.0, "right": 0.0, "bottom": 72.0})
	vp.add_child(phone)
	await get_tree().process_frame
	phone.apply_mobile_layout()
	await get_tree().process_frame
	var view := Vector2(vp.size)
	var map: Control = null
	var fight: Control = null
	for n in phone._metrics.get_children():
		if n is DeployMinimap:
			map = n
		elif n is Button and str(n.name) == "Fight":
			fight = n
	if map == null or fight == null:
		return "narrow widgets"
	if map.position.x < 0.0 or map.position.x + map.size.x > view.x - 8.0:
		return "map x %s" % map.position
	if fight.position.x < 0.0 or fight.position.x + fight.size.x > view.x - 8.0:
		return "fight x %s size %s" % [fight.position, fight.size]
	if fight.position.y + fight.size.y > view.y - 72.0:
		return "fight in safe bottom %s" % fight.position
	var bar := phone.get_node_or_null("StitchTopBar") as Control
	if bar == null or bar.size.x > view.x:
		return "top bar %s" % (bar.size if bar else Vector2.ZERO)
	var foot := phone.get_node_or_null("StitchFooter") as Control
	if foot == null or foot.position.y + foot.size.y > view.y - 72.0 + 0.5:
		return "footer %s" % (foot.position if foot else Vector2.ZERO)
	for ch in phone._cards.get_children():
		if ch is Control and ch.position.x + ch.size.x > view.x - 8.0:
			return "card clip %s" % ch.position
	return ""


func _player_pos(cid: String) -> Vector2i:
	for u in _battle.units:
		if str(u.team) == "player" and str(u.char.id) == cid:
			return u.pos
	return Vector2i(-1, -1)


func _job(job_id: String) -> String:
	return str(GameState.get_job(job_id).get("name", job_id))
