extends Node
## 预备换人：未解锁、没人、轮换、一场一次、不落死者格、从边上进、按钮 48。

class FakeBattle extends Node:
	var units: Array = []
	var terrain: Array = []


func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL reserve: ", err)
		get_tree().quit(1)
		return
	print("RESERVE PASS")
	get_tree().quit(0)


func _run() -> String:
	var fails: Array = []
	GameState.new_game("烬行", "灰旗", "frost")
	GameState.buildings["hall"] = 1
	if bool(CKDeployReserve.cycle().get("ok", false)):
		fails.append("cycle while locked")
	GameState.buildings["hall"] = 4
	var lead := GameState.get_leader()
	GameState.deploy_ids = [lead.id]
	var r := CKDeployReserve.cycle()
	if CKDeployReserve.candidates().is_empty():
		if bool(r.get("ok", false)):
			fails.append("empty roster ok")
		var extra := CKCharacter.new()
		extra.id = "rs1"; extra.name = "替补"; extra.alive = true; extra.in_roster = true; extra.hp = 20; extra.max_hp = 20; extra.job_id = "warrior"; extra.blood_meta = {}
		GameState.characters[extra.id] = extra
		r = CKDeployReserve.cycle()
	var rid := CKDeployReserve.appointed_id()
	if rid == "" or rid == lead.id:
		fails.append("appoint %s" % r)
		return "; ".join(fails)
	var b := FakeBattle.new()
	add_child(b)
	for y in 6:
		var row: Array = []
		for x in 8:
			row.append("water" if (x == 0 and y == 3) else "plain")
		b.terrain.append(row)
	var fallen := {"char": lead, "pos": Vector2i(0, 2), "team": "player"}
	var mate_c := CKCharacter.new()
	mate_c.id = "m"; mate_c.hp = 10
	var mate := {"char": mate_c, "pos": Vector2i(1, 3), "team": "player"}
	lead.hp = 0
	b.units = [fallen, mate]
	var sub := CKDeployReserve.try_swap_in(b, fallen)
	if sub.is_empty():
		fails.append("no swap")
	else:
		var p: Vector2i = sub.pos
		if p == Vector2i(0, 2) or p == Vector2i(0, 3):
			fails.append("bad cell %s" % p)
		if p.x != 0 and p.y != 0 and p.x != 7 and p.y != 5:
			fails.append("not edge %s" % p)
		b.units.append(sub)
	if not CKDeployReserve.try_swap_in(b, mate).is_empty():
		fails.append("second swap")
	var enemy := {"char": mate_c, "pos": Vector2i(3, 3), "team": "enemy"}
	var b2 := FakeBattle.new()
	b2.terrain = b.terrain
	add_child(b2)
	if not CKDeployReserve.try_swap_in(b2, enemy).is_empty():
		fails.append("enemy fall swapped")
	# deploy UI
	GameState.deploy_ids = [lead.id]
	lead.hp = 20
	var scene: Node = load("res://scenes/hub/deploy.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var btn: Control = scene.find_child("ReserveBtn", true, false)
	if btn == null:
		fails.append("no reserve button")
	elif btn.get_combined_minimum_size().y < 48:
		fails.append("button small")
	return "; ".join(fails)
