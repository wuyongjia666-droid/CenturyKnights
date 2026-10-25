extends Node
## Y1-B: 战棋遭遇 win/lose → house_mods.month_echo.battle;
## estates MonthEchoPanel + hourglass EchoLine_battle 回读（耐玩战棋闭环可感）.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo battle: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO BATTLE PASS")
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
	World.encounter = {}
	World.active.clear()

	var err := _audit_win()
	if err != "":
		return err
	err = await _audit_panel("battle", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("battle", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	err = _audit_lose()
	if err != "":
		return err
	return ""


func _seed_encounter(at: String, danger: int) -> void:
	World.pos = at
	World.encounter = {
		"id": "echo_battle_seed",
		"kind": "ambush",
		"node": at,
		"from": at,
		"quest": "",
		"label": "试探伏击",
		"base": "bandit",
		"nation": "ashland",
		"danger": danger,
		"event": "",
		"rep_win": 0,
	}


func _audit_win() -> String:
	GameState.house_mods.erase("month_echo")
	_seed_encounter("ash_capital", 2)
	var before := GameState.silver
	var r: Dictionary = World.on_battle_end(true)
	if not bool(r.get("ok", false)):
		return "win on_battle_end: %s" % str(r)
	if not bool(r.get("win", false)):
		return "win flag missing"
	if GameState.silver <= before:
		return "win loot not applied silver=%d before=%d" % [GameState.silver, before]
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("battle", ""))
	if tx == "":
		return "battle echo empty after win: %s" % str(snap)
	if tx.find("得胜") < 0 and tx.find("won") < 0 and tx.find("Battle") < 0:
		return "battle win wording: %s" % tx
	var loot := 10 + 8 * 2
	if tx.find(str(loot)) < 0:
		return "battle win missing loot %d: %s" % [loot, tx]
	print("month-echo battle win ok line=%s" % tx)
	return ""


func _audit_lose() -> String:
	GameState.house_mods.erase("month_echo")
	_seed_encounter("ash_capital", 1)
	GameState.morale = 40
	var r: Dictionary = World.on_battle_end(false)
	if not bool(r.get("ok", false)):
		return "lose on_battle_end: %s" % str(r)
	if bool(r.get("win", true)):
		return "lose should set win=false"
	if GameState.morale > 35:
		return "lose morale not dropped: %d" % GameState.morale
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("battle", ""))
	if tx == "":
		return "battle echo empty after lose: %s" % str(snap)
	if tx.find("败退") < 0 and tx.find("lost") < 0 and tx.find("Defeated") < 0 and tx.find("Battle") < 0:
		return "battle lose wording: %s" % tx
	print("month-echo battle lose ok line=%s" % tx)
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
	print("month-echo battle panel ok %s" % scene_path)
	page.queue_free()
	await get_tree().process_frame
	return ""
