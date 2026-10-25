extends Node
## Y1-B: Calendar HARVEST_MONTH → apply_harvest → house_mods.month_echo.harvest;
## estates + hourglass EchoLine_harvest 回读（耐玩丰收岁课闭环可感）.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo harvest: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO HARVEST PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.chapter0_flags.erase("harvest_done")
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	World.rivals_enabled = false

	var err := _audit_write()
	if err != "":
		return err
	err = await _audit_panel("harvest", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("harvest", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _audit_write() -> String:
	GameState.house_mods.erase("month_echo")
	var before_silver := int(GameState.silver)
	var before_food := int(GameState.food)
	## Land exactly on HARVEST_MONTH so post._tick_harvest fires once.
	Calendar.year = 1
	Calendar.month = Calendar.HARVEST_MONTH - 1
	Calendar.advance(1)
	if int(Calendar.month) != Calendar.HARVEST_MONTH:
		return "expected month=%d got %d" % [Calendar.HARVEST_MONTH, Calendar.month]
	if not bool(GameState.chapter0_flags.get("harvest_done", false)):
		return "harvest_done flag missing after advance"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("harvest", ""))
	if tx == "":
		return "harvest echo empty after advance: %s" % str(snap)
	if tx.find("丰收") < 0 and tx.find("粮") < 0:
		return "harvest echo wording: %s" % tx
	if int(GameState.food) <= before_food and int(GameState.silver) <= before_silver:
		return "harvest did not raise food/silver food=%d→%d silver=%d→%d" % [
			before_food, int(GameState.food), before_silver, int(GameState.silver)
		]
	print(
		"month-echo harvest write ok line=%s silver=%d→%d food=%d→%d"
		% [tx, before_silver, int(GameState.silver), before_food, int(GameState.food)]
	)
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
