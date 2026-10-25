extends Node
## Y1-B: Calendar retire / death / succession → house_mods.month_echo;
## estates + hourglass EchoLine_retire / EchoLine_death / EchoLine_succession 回读.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo life: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO LIFE PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	GameState.add_rep("ashland", 80)

	var err := _audit_retire()
	if err != "":
		return err
	err = await _audit_panel("retire", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("retire", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	err = _audit_death()
	if err != "":
		return err
	err = await _audit_panel("death", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("death", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	err = _audit_succession()
	if err != "":
		return err
	err = await _audit_panel("succession", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("succession", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _next_bday_month() -> int:
	var m := int(Calendar.month) + 1
	if m > 12:
		m = 1
	return m


func _audit_retire() -> String:
	GameState.house_mods.erase("month_echo")
	var c := _roster("echo_ret", 24)
	c.age = Calendar.RETIRE_AGE - 1
	c.birthday_month = _next_bday_month()
	c.retired = false
	c.in_roster = true
	c.is_leader = false
	Calendar.advance(1)
	if not c.retired:
		return "retire did not fire age=%d" % c.age
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("retire", ""))
	if tx == "":
		return "retire echo empty: %s" % str(snap)
	if tx.find(c.name) < 0:
		return "retire echo missing name: %s" % tx
	if tx.find("退役") < 0 and tx.find("retires") < 0:
		return "retire echo wording: %s" % tx
	print("month-echo retire ok line=%s" % tx)
	return ""


func _audit_death() -> String:
	GameState.house_mods.erase("month_echo")
	## Isolate death: already off roster so RETIRE_AGE branch does not also fire.
	var c := _roster("echo_die", 30)
	c.age = Calendar.DEATH_AGE - 1
	c.birthday_month = _next_bday_month()
	c.retired = true
	c.in_roster = false
	c.is_leader = false
	c.alive = true
	Calendar.advance(1)
	if c.alive:
		return "death did not fire age=%d" % c.age
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("death", ""))
	if tx == "":
		return "death echo empty: %s" % str(snap)
	if tx.find(c.name) < 0:
		return "death echo missing name: %s" % tx
	if tx.find("辞世") < 0 and tx.find("passes") < 0:
		return "death echo wording: %s" % tx
	print("month-echo death ok line=%s" % tx)
	return ""


func _audit_succession() -> String:
	GameState.house_mods.erase("month_echo")
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return "no leader"
	## Ensure a living adult roster heir before leader death.
	var heir := _roster("echo_heir", 28)
	heir.in_roster = true
	heir.alive = true
	heir.retired = false
	heir.is_leader = false
	heir.family_id = str(leader.family_id)
	leader.age = Calendar.DEATH_AGE - 1
	leader.birthday_month = _next_bday_month()
	leader.retired = false
	leader.in_roster = true
	leader.alive = true
	Calendar.advance(1)
	if leader.alive:
		return "leader still alive after death birthday"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var dtx := str(snap.get("death", ""))
	var stx := str(snap.get("succession", ""))
	if dtx == "":
		return "succession path missing death echo: %s" % str(snap)
	if stx == "":
		return "succession echo empty: %s" % str(snap)
	if stx.find(heir.name) < 0 and stx.find(leader.name) < 0:
		return "succession echo missing names: %s" % stx
	var new_lead: CKCharacter = GameState.get_leader()
	if new_lead == null or new_lead.id == leader.id:
		return "banner not handed"
	print("month-echo succession ok line=%s heir=%s" % [stx, new_lead.name])
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


func _roster(tag: String, age: int) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = tag
	c.name = tag
	c.gender = "m"
	c.age = age
	c.rank = "knight"
	c.alive = true
	c.in_roster = true
	c.retired = false
	c.is_leader = false
	c.is_child = false
	c.blood_mix = {"common_ash": 1.0}
	c.stats = {"str": 8, "vit": 7, "skl": 6, "agi": 5, "per": 4, "wil": 9}
	GameState.characters[c.id] = c
	return c
