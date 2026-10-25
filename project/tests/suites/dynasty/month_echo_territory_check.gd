extends Node
## Y1-B: 属地月结 CKTerritory.apply_month → house_mods.month_echo.territory;
## estates MonthEchoPanel + hourglass EchoLine_territory 回读（耐玩领地闭环可感）.

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
	## Capture a village so apply_month yields a non-empty line (mirrors World._territory_month).
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
	GameState.house_mods.erase("month_echo")
	var before_silver := int(GameState.silver)
	## force_roll 0.99：跳过 contest 随机，专测月结写入（同 territory_check._month）.
	var line := CKTerritory.apply_month(0.99)
	if line == "":
		return "apply_month empty with owned=%s" % str(CKTerritory.owned_ids())
	## 与 World._territory_month 同一写入点.
	CKEconomyState.month_echo_note("territory", line)
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("territory", ""))
	if tx == "":
		return "territory echo empty: %s" % str(snap)
	if tx != line:
		return "territory echo mismatch want=%s got=%s" % [line, tx]
	## 至少应出现属地数量或银两变化痕迹（terr_30 形）.
	if tx.find(str(CKTerritory.owned_ids().size())) < 0 and GameState.silver == before_silver and tx.length() < 4:
		return "territory echo too thin: %s" % tx
	print("month-echo territory write ok line=%s silver=%d→%d" % [tx, before_silver, int(GameState.silver)])
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
