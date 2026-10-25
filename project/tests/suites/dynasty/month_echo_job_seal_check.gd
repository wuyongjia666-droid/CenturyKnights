extends Node
## Y1-B: CKJobSeals.stamp → house_mods.month_echo.job_seal;
## estates / hourglass EchoLine_job_seal 回读（职印可感）.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo job_seal: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO JOB_SEAL PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	World.rivals_enabled = false

	var err := _audit_stamp()
	if err != "":
		return err
	err = await _audit_panel("job_seal", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("job_seal", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _audit_stamp() -> String:
	GameState.house_mods.erase("month_echo")
	var city := "lt_capital"
	var c := GameState.get_leader()
	if c == null:
		return "no leader"
	c.job_id = "priest"
	c.blood_meta = {}
	# rep + affair gates (mirror job_seal_check)
	var need := 30
	if World.rep_of(city) < need:
		World.add_city_rep(city, need - World.rep_of(city) + 10)
	GameState.silver = maxi(GameState.silver, 200)
	if not CKCityAffairs.done(city):
		var ar := CKCityAffairs.do_affair(city)
		if not bool(ar.get("ok", false)):
			return "affair: %s" % str(ar.get("msg", ""))
	var seal_nm := str(CKJobSeals.seal_row("yan_zhan").get("name", "yan_zhan"))
	var rr := CKJobSeals.stamp(c, "yan_zhan", city)
	if not bool(rr.get("ok", false)):
		return "stamp: %s" % str(rr.get("msg", ""))
	if not CKJobSeals.has_seal(c, "yan_zhan"):
		return "seal not on character"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("job_seal", ""))
	if tx == "":
		return "job_seal echo empty: %s" % str(snap)
	if tx.find(c.name) < 0:
		return "job_seal echo missing name: %s" % tx
	if tx.find(seal_nm) < 0 and tx.find("yan_zhan") < 0:
		return "job_seal echo missing seal: %s" % tx
	if tx.find("职印") < 0 and tx.find("盖") < 0 and tx.find("seal") < 0 and tx.find("stamp") < 0:
		return "job_seal echo wording: %s" % tx
	print("month-echo job_seal ok line=%s" % tx)
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
