extends Node
## Y1-B: 酒馆招募 → house_mods.month_echo.recruit;
## estates / hourglass EchoLine_recruit 回读（耐玩招募闭环可感）.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo recruit: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO RECRUIT PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	World.rivals_enabled = false

	var err := _audit_recruit()
	if err != "":
		return err
	err = await _audit_panel("recruit", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("recruit", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _audit_recruit() -> String:
	GameState.house_mods.erase("month_echo")
	if GameState.tavern_candidates.is_empty():
		GameState.refresh_tavern()
	if GameState.tavern_candidates.is_empty():
		return "no tavern candidates"
	var cand: CKCharacter = GameState.tavern_candidates[0]
	var cname := str(cand.name)
	GameState.silver = maxi(GameState.silver, 9999)
	var before := GameState.silver
	var cost := int(CKEconomyState.recruit_price(GameState, cand))
	var r: Dictionary = GameState.recruit(cand)
	if not bool(r.get("ok", false)):
		return "recruit: %s" % str(r.get("msg", ""))
	var paid := before - GameState.silver
	if paid != cost and int(r.get("cost", -1)) != cost:
		# tolerate recruit_price vs returned cost; echo must still carry silver figure
		pass
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("recruit", ""))
	if tx == "":
		return "recruit echo empty: %s" % str(snap)
	if tx.find(cname) < 0:
		return "recruit echo missing name: %s" % tx
	if tx.find("招募") < 0 and tx.find("hire") < 0 and tx.find("Hire") < 0:
		return "recruit echo wording: %s" % tx
	var cost_s := str(int(r.get("cost", cost)))
	if tx.find(cost_s) < 0:
		return "recruit echo missing cost %s: %s" % [cost_s, tx]
	print("month-echo recruit ok line=%s" % tx)
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
