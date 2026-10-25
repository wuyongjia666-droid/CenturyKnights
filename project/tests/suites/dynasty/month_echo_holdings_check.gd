extends Node
## Y1-B: 产业月结 holdings_monthly_yield → house_mods.month_echo.holdings;
## estates + hourglass EchoLine_holdings 回读（estates_check 已覆盖空态/属地面板，本刀补沙漏）.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo holdings: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO HOLDINGS PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	World.rivals_enabled = false

	var err := _audit_write()
	if err != "":
		return err
	err = await _audit_panel("holdings", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("holdings", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _audit_write() -> String:
	GameState.holdings = {}
	if GameState.holdings.is_empty():
		var hid: String = str(GameState.HOLDING_DEFS.keys()[0])
		var msg := GameState.unlock_holding(hid)
		if GameState.holdings.is_empty():
			return "unlock_holding failed: %s" % msg
	GameState.house_mods.erase("month_echo")
	var before_silver := int(GameState.silver)
	var before_food := int(GameState.food)
	## 走真实 Calendar 月结 → _tick_holdings → month_echo_note("holdings").
	Calendar.advance(1)
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("holdings", ""))
	if tx == "":
		return "holdings echo empty after advance: %s holdings=%s" % [str(snap), str(GameState.holdings.keys())]
	print(
		"month-echo holdings write ok line=%s silver=%d→%d food=%d→%d"
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
	print("month-echo holdings panel ok %s" % scene_path)
	page.queue_free()
	await get_tree().process_frame
	return ""
