extends Node
## Y1-B: 堡志达成 → house_mods.month_echo.ambition;
## estates + hourglass EchoLine_ambition 回读（耐玩中长期目标闭环可感）.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo ambition: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO AMBITION PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	World.rivals_enabled = false

	var err := _audit_write_vow()
	if err != "":
		return err
	err = await _audit_panel("ambition", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("ambition", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	err = _audit_write_silver()
	if err != "":
		return err
	err = await _audit_panel("ambition", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _audit_write_vow() -> String:
	## 立家训 → Calendar → tick_doctrine → check_ambitions → 家训既立.
	GameState.house_mods.erase("month_echo")
	GameState.ambition_done.erase("vow_house")
	GameState.house_mods["doctrine"] = "strict"
	GameState.doctrine_months = 0
	Calendar.advance(1)
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("ambition", ""))
	if tx == "":
		return "ambition echo empty after vow_house: %s" % str(snap)
	if tx.find("家训既立") < 0 and tx.find("堡志") < 0:
		return "ambition echo wording: %s" % tx
	if not bool(GameState.ambition_done.get("vow_house", false)):
		return "vow_house not marked done"
	print("month-echo ambition vow ok line=%s" % tx)
	return ""


func _audit_write_silver() -> String:
	## 库银盈柜：银≥300 直调 check_ambitions（Y1 三月征募会先扣光银，不宜再走 Calendar）.
	GameState.house_mods.erase("month_echo")
	GameState.ambition_done.erase("silver_hoard")
	GameState.silver = 300
	var ams: Array = GameState.check_ambitions()
	if ams.is_empty():
		return "check_ambitions returned empty at silver=300"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("ambition", ""))
	if tx == "":
		return "ambition echo empty after silver_hoard: %s" % str(snap)
	if tx.find("库银盈柜") < 0 and tx.find("堡志") < 0:
		return "ambition silver wording: %s" % tx
	if not bool(GameState.ambition_done.get("silver_hoard", false)):
		return "silver_hoard not marked done"
	print("month-echo ambition silver ok line=%s" % tx)
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
	print("month-echo ambition panel ok %s" % scene_path)
	page.queue_free()
	await get_tree().process_frame
	return ""
