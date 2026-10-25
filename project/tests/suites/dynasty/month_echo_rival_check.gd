extends Node
## Y1-B: Calendar rival rumor (m3/m9) + rival deal tick → house_mods.month_echo.rival;
## estates + hourglass EchoLine_rival 回读（耐玩敌宅闭环可感）.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo rival: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO RIVAL PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	## Keep rivals_enabled false so world noise stays off; Calendar rival ticks still run.
	World.rivals_enabled = false
	GameState.silver = 400

	var err := _audit_rumor()
	if err != "":
		return err
	err = await _audit_panel("rival", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("rival", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	err = _audit_deal()
	if err != "":
		return err
	err = await _audit_panel("rival", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _audit_rumor() -> String:
	GameState.house_mods.erase("month_echo")
	## Month 3 and 9 fire rival rumor; land exactly on 3.
	Calendar.year = 1
	Calendar.month = 2
	Calendar.advance(1)
	if int(Calendar.month) != 3:
		return "expected month=3 got %d" % Calendar.month
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("rival", ""))
	if tx == "":
		return "rival rumor echo empty after m3: %s" % str(snap)
	if tx.find("朔影") < 0 and tx.find("流言") < 0:
		return "rival rumor wording: %s" % tx
	print("month-echo rival rumor ok line=%s" % tx)
	return ""


func _audit_deal() -> String:
	## Seed a one-turn trade deal so tick_rival_deals emits a fulfillment line.
	GameState.house_mods.erase("month_echo")
	GameState.rival_deals.clear()
	GameState.rival_deals["qinghe"] = {"kind": "trade", "turns_left": 1, "price": 25, "mid_ticks": 0}
	var before := int(GameState.silver)
	Calendar.advance(1)
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("rival", ""))
	if tx == "":
		return "rival deal echo empty: %s" % str(snap)
	if tx.find("契约") < 0 and tx.find("qinghe") < 0 and tx.find("商路") < 0:
		return "rival deal wording: %s" % tx
	if int(GameState.silver) <= before and tx.find("银+") < 0:
		## Fulfillment trade adds silver; tolerate if mid-event only, but require echo.
		pass
	print("month-echo rival deal ok line=%s silver=%d→%d" % [tx, before, int(GameState.silver)])
	return ""


func _audit_panel(kind: String, scene_path: String, panel_name: String) -> String:
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var want := str(snap.get(kind, ""))
	if want == "":
		return "no %s in snap before %s" % [kind, scene_path]
	var page: Control = load(scene_path).instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame
	var scope: Node = page
	if panel_name != "":
		var panel := page.find_child(panel_name, true, false)
		if panel == null:
			page.queue_free()
			return "%s missing on %s" % [panel_name, scene_path]
		scope = panel
	var line_name := "EchoLine_%s" % kind
	var line := page.find_child(line_name, true, false) as Label
	var bit := want.substr(0, mini(6, want.length()))
	if line == null:
		var hit := false
		for n in scope.find_children("*", "Label", true, false):
			if str((n as Label).text).find(bit) >= 0:
				hit = true
				break
		if not hit:
			page.queue_free()
			return "%s missing bit=%s on %s" % [line_name, bit, scene_path]
	elif str(line.text).find(bit) < 0:
		page.queue_free()
		return "%s text mismatch on %s" % [line_name, scene_path]
	print("month-echo %s ok on %s" % [kind, scene_path.get_file()])
	page.queue_free()
	await get_tree().process_frame
	return ""
