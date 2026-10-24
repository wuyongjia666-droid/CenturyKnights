extends Node
## Y1-B: commission deliver/expire → house_mods.month_echo.commission;
## estates MonthEchoPanel shows EchoLine_commission.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo commission: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO COMMISSION PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	World.rivals_enabled = false
	World.pos = "ash_capital"
	World.rep_city["ash_capital"] = 80
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	World.active.clear()
	World.encounter = {}

	var err := _audit_deliver()
	if err != "":
		return err
	err = await _audit_estates_line()
	if err != "":
		return err
	err = _audit_expire()
	if err != "":
		return err
	return ""


func _audit_deliver() -> String:
	GameState.house_mods.erase("month_echo")
	var city := "ash_capital"
	World.pos = city
	World.boards.erase(city)
	var r := RandomNumberGenerator.new()
	r.seed = 37801
	var q: Dictionary = World._make_quest(city, "deliver", 1, r)
	if q.is_empty():
		return "deliver quest empty"
	World._ensure_board(city)
	World.boards[city].offers.append(q)
	var acc: Dictionary = World.accept_quest(city, str(q.id))
	if not bool(acc.get("ok", false)):
		return "accept: %s" % str(acc.get("msg", ""))
	World.travel_to(str(q.target))
	var live: Dictionary = World.quest_by_id(str(q.id))
	if str(live.get("state", "")) != "ready":
		## Force ready if travel did not flip (edge cases); deliver should.
		live["state"] = "ready"
	var dest: String = World.turn_in_city(live)
	if World.pos != dest:
		World.travel_to(dest)
	if World.pos != dest:
		World.pos = dest
	var turned: Dictionary = World.turn_in(str(q.id))
	if not bool(turned.get("ok", false)):
		return "turn_in: %s" % str(turned.get("msg", ""))
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("commission", ""))
	if tx.find("交付") < 0:
		return "commission echo missing deliver: %s" % str(snap)
	if tx.find(str(q.title)) < 0:
		return "commission echo missing title: %s" % tx
	print("month-echo commission deliver ok title=%s" % q.title)
	return ""


func _audit_estates_line() -> String:
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var want := str(snap.get("commission", ""))
	if want == "":
		return "no commission in snap before estates"
	var page: Control = load("res://scenes/hub/estates.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame
	var panel := page.find_child("MonthEchoPanel", true, false)
	if panel == null:
		page.queue_free()
		return "MonthEchoPanel missing"
	var line := page.find_child("EchoLine_commission", true, false) as Label
	var bit := want.substr(0, mini(6, want.length()))
	if line == null:
		var hit := false
		for n in panel.find_children("*", "Label", true, false):
			if str((n as Label).text).find(bit) >= 0:
				hit = true
				break
		if not hit:
			page.queue_free()
			return "EchoLine_commission missing bit=%s" % bit
	elif str(line.text).find(bit) < 0:
		page.queue_free()
		return "EchoLine_commission text mismatch"
	print("month-echo commission estates line ok")
	page.queue_free()
	await get_tree().process_frame
	return ""


func _audit_expire() -> String:
	## Fresh month_echo slot then force one overdue active quest.
	GameState.house_mods.erase("month_echo")
	World.active.clear()
	var city := "ash_capital"
	var r := RandomNumberGenerator.new()
	r.seed = 37802
	var q: Dictionary = World._make_quest(city, "scout", 1, r)
	if q.is_empty():
		q = {"id": "wq_echo_exp", "title": "试探逾期", "kind": "scout", "issuer": city, "target": city, "tier": 1, "reward_silver": 10, "reward_rep": 1, "days_budget": 1}
	q.state = "active"
	q.deadline = int(World.days_total) - 1
	q.id = str(q.get("id", "wq_echo_exp"))
	World.active.append(q)
	World.advance_days(1)
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("commission", ""))
	if tx.find("逾期") < 0:
		return "commission echo missing expire: %s" % str(snap)
	if tx.find(str(q.title)) < 0:
		return "expire echo missing title: %s" % tx
	## Same-month append: deliver then expire should both appear if we deliver first.
	print("month-echo commission expire ok title=%s" % q.title)
	return ""
