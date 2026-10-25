extends Node
## Y1-B: 无家训时 Calendar 月结仍 check_ambitions → month_echo.ambition;
## estates + hourglass EchoLine_ambition 回读（堡志不靠家训门闩）.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo ambition ungate: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO AMBITION UNGATE PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	GameState.house_mods.erase("doctrine")
	GameState.doctrine_months = 0
	World.events_enabled = false
	World.rivals_enabled = false

	var err := _audit_write_no_doctrine()
	if err != "":
		return err
	err = await _audit_panel("ambition", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("ambition", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _audit_write_no_doctrine() -> String:
	GameState.house_mods.erase("month_echo")
	GameState.house_mods.erase("doctrine")
	GameState.ambition_done.erase("silver_hoard")
	## Y1 三月征募会扣银；从月1→2 推进，银抬高避开 dues.
	GameState.silver = 800
	if str(GameState.house_mods.get("doctrine", "")) != "":
		return "doctrine still set — ungate test invalid"
	Calendar.advance(1)
	if str(GameState.house_mods.get("doctrine", "")) != "":
		return "doctrine appeared after advance"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("ambition", ""))
	if tx == "":
		return "ambition echo empty without doctrine: %s" % str(snap)
	if tx.find("库银盈柜") < 0 and tx.find("堡志") < 0:
		return "ambition ungate wording: %s" % tx
	if not bool(GameState.ambition_done.get("silver_hoard", false)):
		return "silver_hoard not done without doctrine"
	## 家训 echo 不应被误写.
	if str(snap.get("doctrine", "")) != "":
		return "unexpected doctrine echo: %s" % str(snap.get("doctrine", ""))
	print("month-echo ambition ungate ok line=%s" % tx)
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
	print("month-echo ambition ungate panel ok %s" % scene_path)
	page.queue_free()
	await get_tree().process_frame
	return ""
