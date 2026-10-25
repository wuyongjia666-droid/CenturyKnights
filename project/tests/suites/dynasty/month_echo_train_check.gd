extends Node
## Y1-B: 旗塾 teach(结业) / try_promote(晋升) → house_mods.month_echo
## tutor / promo; estates + hourglass EchoLine_* 回读.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo train: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO TRAIN PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	World.rivals_enabled = false

	var err := _audit_tutor()
	if err != "":
		return err
	err = await _audit_panel("tutor", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("tutor", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err

	err = _audit_promo()
	if err != "":
		return err
	err = await _audit_panel("promo", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("promo", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _audit_tutor() -> String:
	GameState.house_mods.erase("month_echo")
	var leader := GameState.get_leader()
	if leader == null:
		return "no leader"
	leader.age = 30
	leader.injured = false
	leader.in_roster = true
	leader.stats["str"] = 14
	var kid := CKCharacter.new()
	kid.id = "echo_pupil"
	kid.name = "传习童"
	kid.alive = true
	kid.is_child = true
	kid.in_roster = false
	kid.age = 10
	kid.parent_ids = [leader.id]
	kid.apt_max = {"str": 20, "vit": 20, "skl": 20, "agi": 20, "per": 20, "wil": 20}
	kid.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	kid.blood_meta = {}
	GameState.characters[kid.id] = kid
	var ar := CKTutor.assign(kid.id, leader.id)
	if not bool(ar.get("ok", false)):
		return "assign: %s" % str(ar.get("msg", ""))
	var tr := CKTutor.teach(kid.id)
	if not bool(tr.get("ok", false)):
		return "teach: %s" % str(tr.get("msg", ""))
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("tutor", ""))
	if tx == "":
		return "tutor echo empty: %s" % str(snap)
	if tx.find(kid.name) < 0:
		return "tutor echo missing pupil: %s" % tx
	if tx.find(leader.name) < 0:
		return "tutor echo missing tutor: %s" % tx
	if tx.find("传习") < 0 and tx.find("taught") < 0:
		return "tutor echo wording: %s" % tx
	print("month-echo tutor ok line=%s" % tx)
	return ""


func _audit_promo() -> String:
	GameState.house_mods.erase("month_echo")
	var c := GameState.get_leader()
	if c == null:
		return "no leader for promo"
	c.job_id = "squire"
	c.stats["str"] = 12
	c.stats["agi"] = 12
	GameState.iron = maxi(GameState.iron, 5)
	var want_job := "light_cavalry"
	var jname := str(GameState.get_job(want_job).get("name", want_job))
	var pr: Dictionary = GameState.try_promote(c.id, want_job)
	if not bool(pr.get("ok", false)):
		return "promote: %s" % str(pr.get("msg", ""))
	if c.job_id != want_job:
		return "job not set after promote"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("promo", ""))
	if tx == "":
		return "promo echo empty: %s" % str(snap)
	if tx.find(c.name) < 0:
		return "promo echo missing name: %s" % tx
	if tx.find(jname) < 0 and tx.find(want_job) < 0:
		return "promo echo missing job: %s" % tx
	if tx.find("转职") < 0 and tx.find("promoted") < 0:
		return "promo echo wording: %s" % tx
	print("month-echo promo ok line=%s" % tx)
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
