extends Node
## Y1-B: 家训月结 → house_mods.month_echo.doctrine;
## estates + hourglass EchoLine_doctrine 回读（耐玩家训闭环可感）.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo doctrine: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO DOCTRINE PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	World.rivals_enabled = false

	var err := _audit_write("strict", "严教")
	if err != "":
		return err
	err = await _audit_panel("doctrine", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("doctrine", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	err = _audit_write("mercy", "仁恤")
	if err != "":
		return err
	err = await _audit_panel("doctrine", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	err = _audit_write("trade", "商本")
	if err != "":
		return err
	return ""


func _audit_write(doctrine_id: String, bit: String) -> String:
	GameState.house_mods.erase("month_echo")
	GameState.house_mods["doctrine"] = doctrine_id
	GameState.house_mods.erase("doctrine_mature")
	GameState.doctrine_months = 0
	## 真实 Calendar → _tick_doctrine → tick_doctrine_and_marriage_month 写入.
	## 不比净粮/银/士气：同月俸饷/天候/征募会冲掉 +1，以 echo 文案锁定家训效果.
	Calendar.advance(1)
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("doctrine", ""))
	if tx == "":
		return "doctrine echo empty id=%s snap=%s" % [doctrine_id, str(snap)]
	if tx.find(bit) < 0 and tx.find("家训") < 0:
		return "doctrine echo wording id=%s: %s" % [doctrine_id, tx]
	if GameState.doctrine_months < 1:
		return "doctrine_months not advanced"
	match doctrine_id:
		"strict":
			if tx.find("士气+") < 0:
				return "strict echo missing morale bit: %s" % tx
		"mercy":
			if tx.find("粮+") < 0:
				return "mercy echo missing food bit: %s" % tx
		"trade", "commerce":
			if tx.find("银+") < 0:
				return "trade echo missing silver bit: %s" % tx
	print("month-echo doctrine write ok id=%s line=%s" % [doctrine_id, tx])
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
	print("month-echo doctrine panel ok %s" % scene_path)
	page.queue_free()
	await get_tree().process_frame
	return ""
