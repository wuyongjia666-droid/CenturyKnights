extends Node
## Y1-B: Calendar spring_purse / epoch_dues → house_mods.month_echo.dues;
## estates + hourglass EchoLine_dues 回读（时代压力可感）. Odds untouched.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo dues: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO DUES PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	World.rivals_enabled = false
	## Keep silver high enough that Y1 muster / Y2 January dues actually bite.
	GameState.silver = maxi(int(GameState.silver), 400)

	var err := _audit_muster()
	if err != "":
		return err
	err = await _audit_panel("dues", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("dues", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	err = _audit_spring_purse()
	if err != "":
		return err
	err = await _audit_panel("dues", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	err = _audit_january_y2()
	if err != "":
		return err
	err = await _audit_panel("dues", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	return ""


func _audit_muster() -> String:
	## Y1 MUSTER_MONTH_Y1 (3): silver - (wage*3-1) paid as muster.
	GameState.house_mods.erase("month_echo")
	GameState.silver = maxi(int(GameState.silver), 400)
	Calendar.year = 1
	Calendar.month = Calendar.MUSTER_MONTH_Y1 - 1
	Calendar.advance(1)
	if int(Calendar.month) != Calendar.MUSTER_MONTH_Y1:
		return "expected muster month=%d got %d" % [Calendar.MUSTER_MONTH_Y1, Calendar.month]
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("dues", ""))
	if tx == "":
		return "dues echo empty after Y1 muster: %s epoch=%s" % [str(snap), str(GameState.house_mods.get("epoch_dues", {}))]
	if tx.find("银") < 0 and tx.find("silver") < 0 and tx.find("dues") < 0:
		return "dues muster wording: %s" % tx
	print("month-echo dues muster ok line=%s" % tx)
	return ""


func _audit_spring_purse() -> String:
	## Y1 April: spring purse +180.
	GameState.house_mods.erase("month_echo")
	Calendar.year = 1
	Calendar.month = 3
	var before := int(GameState.silver)
	Calendar.advance(1)
	if int(Calendar.month) != 4:
		return "expected month=4 got %d" % Calendar.month
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("dues", ""))
	if tx == "":
		return "dues echo empty after spring purse: %s" % str(snap)
	if tx.find("春令") < 0 and tx.find("Spring") < 0:
		return "dues spring wording: %s" % tx
	if int(GameState.silver) < before:
		return "spring purse should add silver before=%d after=%d" % [before, int(GameState.silver)]
	print("month-echo dues spring ok line=%s silver=%d→%d" % [tx, before, int(GameState.silver)])
	return ""


func _audit_january_y2() -> String:
	## Y2 January: mini(48, silver-80) drill dues.
	GameState.house_mods.erase("month_echo")
	GameState.silver = maxi(int(GameState.silver), 200)
	Calendar.year = 1
	Calendar.month = 12
	Calendar.advance(1)
	if int(Calendar.year) != 2 or int(Calendar.month) != 1:
		return "expected Y2/1 got %d/%d" % [Calendar.year, Calendar.month]
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("dues", ""))
	if tx == "":
		return "dues echo empty after Y2 January: %s epoch=%s" % [str(snap), str(GameState.house_mods.get("epoch_dues", {}))]
	if tx.find("银") < 0 and tx.find("silver") < 0:
		return "dues january wording: %s" % tx
	print("month-echo dues january ok line=%s" % tx)
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
