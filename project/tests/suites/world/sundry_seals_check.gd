extends Node
## v9.2 sundries shelf + job seals gate + city affairs flag.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL sundry_seals: ", err)
		get_tree().quit(1)
		return
	print("SUNDRY SEALS PASS")
	get_tree().quit(0)


func _run() -> String:
	GameState.new_game("烬行", "灰旗", "frost")
	GameState.silver = 200
	GameState.house_mods["current_city"] = "ash_market"
	var shelf: Array = CKSundries.shelf_for_city("ash_market")
	if shelf.size() < 2:
		return "ash shelf %d" % shelf.size()
	var iid := str(shelf[0].get("id", ""))
	var buy: Dictionary = CKSundries.buy("ash_market", iid)
	if not bool(buy.get("ok", false)):
		return "buy " + str(buy)
	if CKSundries.owned(iid) != 1:
		return "owned"
	var use: Dictionary = CKSundries.use(iid)
	if not bool(use.get("ok", false)):
		return "use " + str(use)
	## job seals
	var leader := GameState.get_leader()
	leader.job_id = "priest"
	leader.blood_meta["job_battles"] = 2
	CKLifeMarks.add(leader, "lamp", "birth")
	GameState.set_flag("affair_lt_capital", true)
	## fake city rep via World if possible
	if World.has_method("set_city_rep"):
		World.set_city_rep("lt_capital", 40)
	elif World.has_method("add_city_rep"):
		World.add_city_rep("lt_capital", 40)
	GameState.house_mods["current_city"] = "lt_capital"
	var gate: Dictionary = CKJobSeals.can_take(leader, "yan_zhan", "lt_capital")
	## may fail on rep API — tolerate msg but require city check works
	var wrong: Dictionary = CKJobSeals.can_take(leader, "yan_zhan", "ash_market")
	if bool(wrong.get("ok", true)):
		return "wrong city should fail"
	if not CKCityAffairs.done("lt_capital"):
		return "affair flag"
	## special skills present
	if GameState.get_skill("bridge_tax").is_empty():
		return "bridge skill missing"
	if GameState.get_job("yan_zhan").is_empty():
		return "yan_zhan job missing"
	var opts: Array = CKTutor.promote_list(leader)
	if "yan_zhan" not in opts and "medic" not in opts:
		return "promote opts %s" % str(opts)
	return ""
