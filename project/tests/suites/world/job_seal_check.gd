extends Node
## 本城之事 → 职印 → 验盏转职 → 战斗命中加成；三阶照旧可转；失败/重复都有原因。

func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL job_seal: ", err)
		get_tree().quit(1)
		return
	print("JOB SEAL PASS")
	get_tree().quit(0)


func _run() -> String:
	var fails: Array = []
	GameState.new_game("烬行", "灰旗", "frost")
	var city := "lt_capital"
	var c := GameState.get_leader()
	c.job_id = "priest"
	if not bool(CKJobSeals.promote_gate(c, "medic").get("ok", false)):
		fails.append("medic gated")
	if "yan_zhan" not in CKTutor.promote_list(c):
		fails.append("yan_zhan not offered")
	if bool(GameState.try_promote(c.id, "yan_zhan").get("ok", false)):
		fails.append("promoted without seal")
	if World.rep_of(city) >= 10:
		World.add_city_rep(city, -World.rep_of(city))
	if str(CKCityAffairs.template_for(city).get("id", "")) != "first_meet":
		fails.append("first_meet template")
	World.add_city_rep(city, 40)
	var r0 := CKJobSeals.stamp(c, "yan_zhan", city)
	if bool(r0.get("ok", false)) or str(r0.get("msg", "")).find("本城之事") < 0:
		fails.append("stamp w/o affair: %s" % r0)
	GameState.silver = 0
	if bool(CKCityAffairs.do_affair(city).get("ok", false)):
		fails.append("affair with no silver")
	GameState.silver = 100
	if not bool(CKCityAffairs.do_affair(city).get("ok", false)):
		fails.append("affair failed")
	if int(GameState.silver) != 80:
		fails.append("affair cost %d" % int(GameState.silver))
	if bool(CKCityAffairs.do_affair(city).get("ok", false)):
		fails.append("affair repeat")
	if bool(CKJobSeals.can_stamp(c, "yan_zhan", "ash_market").get("ok", false)):
		fails.append("wrong city stamped")
	c.job_id = "mage"
	if bool(CKJobSeals.can_stamp(c, "yan_zhan", city).get("ok", false)):
		fails.append("wrong job stamped")
	c.job_id = "priest"
	if not bool(CKJobSeals.stamp(c, "yan_zhan", city).get("ok", false)):
		fails.append("stamp failed")
	if bool(CKJobSeals.stamp(c, "yan_zhan", city).get("ok", false)):
		fails.append("stamp repeat")
	var pr := GameState.try_promote(c.id, "yan_zhan")
	if c.job_id != "yan_zhan":
		fails.append("promote after seal: %s" % pr)
	var fake := Node.new()
	add_child(fake)
	var atk := {"char": c, "team": "player"}
	var foe := CKCharacter.new()
	foe.id = "foe1"; foe.name = "杂兵"; foe.blood_meta = {}
	var foe2 := CKCharacter.new()
	foe2.id = "foe2"; foe2.name = "另一个"; foe2.blood_meta = {}
	var b1 := CKYanZhan.strike_bonus(fake, atk, {"char": foe, "team": "enemy"})
	if b1 != CKYanZhan.BLOODLESS_HIT:
		fails.append("first strike bonus %d" % b1)
	var ally := CKCharacter.new()
	ally.id = "al"; ally.job_id = "warrior"
	if CKYanZhan.strike_bonus(fake, {"char": ally, "team": "player"}, {"char": foe, "team": "enemy"}) != CKYanZhan.BLOODLESS_HIT:
		fails.append("ally bonus on marked")
	if CKYanZhan.strike_bonus(fake, atk, {"char": foe2, "team": "enemy"}) != 0:
		fails.append("second target got bonus")
	if CKYanZhan.strike_bonus(fake, {"char": foe, "team": "enemy"}, {"char": c, "team": "player"}) != 0:
		fails.append("enemy got bonus")
	var scene: Node = load("res://scenes/hub/city.tscn").instantiate()
	scene.set("city", city)
	add_child(scene)
	await get_tree().process_frame
	scene.open_affairs()
	await get_tree().process_frame
	await get_tree().process_frame
	var ov: Node = scene.find_child("AffairOverlay", true, false)
	if ov == null:
		fails.append("no overlay")
	for b in ov.find_children("*", "Button", true, false):
		if b.get_combined_minimum_size().y < 48:
			fails.append("small button %s" % b.text)
	return "; ".join(fails)
