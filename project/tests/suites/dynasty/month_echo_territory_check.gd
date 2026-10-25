extends Node
## Y1-B: Calendar → World._territory_month → CKTerritory.apply_month → month_echo.territory;
## estates MonthEchoPanel + hourglass EchoLine_territory 回读（真实月结路径，非手动注入）.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo territory: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO TERRITORY PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	World.rivals_enabled = false
	World.encounter = {}
	World.active.clear()
	GameState.silver = 500

	var err := _audit_write()
	if err != "":
		return err
	err = await _audit_panel("territory", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("territory", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _audit_write() -> String:
	## Capture a village so World._territory_month / apply_month yields a line.
	var id := "t_ash_millrun"
	var s := CKTerritory.site(id)
	if s.is_empty():
		return "site %s missing" % id
	World.pos = str(s.anchor)
	var cap: Dictionary = CKTerritory.capture(id, "chain")
	if not bool(cap.get("ok", false)):
		return "capture failed: %s" % str(cap.get("msg", ""))
	if not CKTerritory.owned(id):
		return "not owned after capture"
	## Real Calendar path (World registers _territory_month). Reseed until apply_month
	## yields a non-empty line under default roll — no manual month_echo_note inject.
	var ok := false
	var tx := ""
	var before_silver := 0
	for seed in range(1, 120):
		GameState.house_mods.erase("month_echo")
		GameState.rng.seed = seed
		before_silver = int(GameState.silver)
		Calendar.advance(1)
		var snap: Dictionary = CKEconomyState.month_echo_snapshot()
		tx = str(snap.get("territory", ""))
		if tx != "":
			ok = true
			break
	if not ok:
		return "territory echo empty after Calendar.advance×119 (owned=%s)" % str(CKTerritory.owned_ids())
	if tx.find(str(CKTerritory.owned_ids().size())) < 0 and GameState.silver == before_silver and tx.length() < 4:
		return "territory echo too thin: %s" % tx
	print("month-echo territory calendar-path ok line=%s silver=%d→%d" % [tx, before_silver, int(GameState.silver)])
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
	print("month-echo territory panel ok %s" % scene_path)
	page.queue_free()
	await get_tree().process_frame
	return ""
