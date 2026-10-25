extends Node
## Y1-B: Calendar SPRING_MONTH → refresh_marriage_candidates → house_mods.month_echo.spring;
## estates + hourglass EchoLine_spring 回读（耐玩春令联姻池可感）.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo spring: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO SPRING PASS")
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
	err = await _audit_panel("spring", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("spring", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _audit_write() -> String:
	GameState.house_mods.erase("month_echo")
	GameState.marriage_candidates.clear()
	## Land exactly on SPRING_MONTH so _tick_spring fires once.
	Calendar.year = 1
	Calendar.month = Calendar.SPRING_MONTH - 1
	Calendar.advance(1)
	if int(Calendar.month) != Calendar.SPRING_MONTH:
		return "expected month=%d got %d" % [Calendar.SPRING_MONTH, Calendar.month]
	var pool_n := GameState.marriage_candidates.size()
	if pool_n <= 0:
		return "spring refresh left marriage_candidates empty"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("spring", ""))
	if tx == "":
		return "spring echo empty after advance: %s" % str(snap)
	if tx.find("春令") < 0 and tx.find("Spring") < 0:
		return "spring echo wording: %s" % tx
	if tx.find(str(pool_n)) < 0:
		return "spring echo missing pool count %d: %s" % [pool_n, tx]
	print("month-echo spring write ok line=%s pool=%d" % [tx, pool_n])
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
