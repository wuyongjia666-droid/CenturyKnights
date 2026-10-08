class_name DeployBrief
extends RefCounted

static func cap_line() -> String:
	return BattleObjectives.text("deploy_cap") % GameState.max_deploy()


static func practice_map_id() -> String:
	return "quest_bandit"


static func bench_reason(c: CKCharacter) -> String:
	if c == null or not c.alive:
		return BattleObjectives.text("deploy_down")
	if c.injured:
		return BattleObjectives.text("deploy_hurt")
	return ""


static func enemy_line(m: Dictionary) -> String:
	var templates = m.get("enemy_templates", [])
	var n := 0
	if typeof(templates) == TYPE_ARRAY:
		n = templates.size()
	return BattleObjectives.text("deploy_enemy_n") % n


static func objective_line(m: Dictionary) -> String:
	var kind := str(BattleObjectives.spec(m).get("type", "rout"))
	var title := BattleObjectives.text("obj_" + kind)
	if title == "obj_" + kind:
		title = BattleObjectives.text("obj_unknown")
	return BattleObjectives.text("deploy_obj") % title


static func mix_line(m: Dictionary) -> String:
	var counts: Dictionary = {}
	var order: Array = []
	for job_id in _foe_jobs(m):
		if not counts.has(job_id):
			order.append(job_id)
			counts[job_id] = 0
		counts[job_id] = int(counts[job_id]) + 1
	var parts: Array = []
	for job_id in order:
		var name := str(GameState.get_job(str(job_id)).get("name", job_id))
		parts.append("%s %d" % [name, int(counts[job_id])])
	return BattleObjectives.text("deploy_mix") % " / ".join(parts)


static func suggest_line(m: Dictionary) -> String:
	var roles: Dictionary = {}
	for job_id in _foe_jobs(m):
		var role := BattleRules.job_role(str(job_id))
		roles[role] = int(roles.get(role, 0)) + 1
	var names: Array = []
	if int(roles.get("ranger", 0)) > 0:
		names.append(_job_name("heavy_inf"))
	if int(roles.get("tank", 0)) > 0:
		names.append(_job_name("apprentice"))
	if int(roles.get("skirmisher", 0)) > 0 or int(roles.get("mage", 0)) > 0:
		names.append(_job_name("hunter"))
	if names.is_empty():
		names.append(_job_name("light_inf"))
	var uniq: Array = []
	for n in names:
		if n not in uniq:
			uniq.append(n)
	return BattleObjectives.text("deploy_jobs") % " / ".join(uniq)


static func attach(parent: Control, map_id: String, rect: Rect2) -> void:
	var board := DeployMinimap.new()
	board.map_id = map_id
	board.position = rect.position
	board.size = Vector2(rect.size.x, 72)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(board)
	var m := BattleMaps.get_map(map_id)
	var lines: Array = [objective_line(m), enemy_line(m), mix_line(m), suggest_line(m)]
	var y := rect.position.y + 74.0
	for line in lines:
		var lab := UIKit.body_label(str(line), UIKit.TEXT_DIM, 12)
		lab.position = Vector2(rect.position.x, y)
		lab.size = Vector2(rect.size.x, 16)
		lab.clip_text = true
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF
		parent.add_child(lab)
		y += 16.0


static func _job_name(job_id: String) -> String:
	return str(GameState.get_job(job_id).get("name", job_id))


static func _foe_jobs(m: Dictionary) -> Array:
	var saved := CharacterFactory._id_seq
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var jobs: Array = []
	var templates = m.get("enemy_templates", [])
	if typeof(templates) != TYPE_ARRAY:
		CharacterFactory._id_seq = saved
		return jobs
	for t in templates:
		var foe: CKCharacter = CharacterFactory.make_enemy(str(t), rng)
		jobs.append(str(foe.job_id))
	CharacterFactory._id_seq = saved
	return jobs
