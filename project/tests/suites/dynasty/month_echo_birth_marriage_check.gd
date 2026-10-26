extends Node
## Y1-B: Calendar birth + marriage-month settle → house_mods.month_echo;
## estates + hourglass EchoLine_birth / EchoLine_marriage 回读.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo birth/marriage: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO BIRTH MARRIAGE PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	GameState.add_rep("ashland", 80)

	var err := _audit_birth()
	if err != "":
		return err
	err = await _audit_panel("birth", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("birth", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	err = _audit_marriage()
	if err != "":
		return err
	err = await _audit_panel("marriage", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("marriage", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _audit_birth() -> String:
	GameState.house_mods.erase("month_echo")
	var couple := _couple("echo_b", 22)
	var wed: Dictionary = Lineage.marry(couple[0], couple[1], 0, [], false)
	if not bool(wed.get("ok", false)):
		return "birth setup marry: %s" % str(wed.get("msg", ""))
	var mother: CKCharacter = couple[1]
	## Non-paced marry sets pregnant_months=1; one advance delivers.
	mother.pregnant_months = 0
	mother.blood_meta["litter"] = 1
	var before_kids := mother.children_ids.size()
	Calendar.advance(1)
	if mother.children_ids.size() <= before_kids:
		return "no birth after advance"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("birth", ""))
	if tx == "":
		return "birth echo empty: %s" % str(snap)
	if tx.find(mother.name) < 0:
		return "birth echo missing mother: %s" % tx
	if tx.find("诞下") < 0 and tx.find("bore") < 0:
		return "birth echo wording: %s" % tx
	print("month-echo birth ok line=%s" % tx)
	return ""


func _audit_marriage() -> String:
	GameState.house_mods.erase("month_echo")
	## Leader already may have spouse from new_game; ensure a living pair for month settle.
	var leader: CKCharacter = GameState.get_leader()
	if leader == null:
		return "no leader"
	if str(leader.spouse_id) == "" or not GameState.characters.has(str(leader.spouse_id)):
		var couple := _couple("echo_m", 24)
		couple[0].is_leader = false
		var wed: Dictionary = Lineage.marry(leader, couple[1], 0, [], false)
		if not bool(wed.get("ok", false)):
			## Leader may already be marked married; bind couple as a roster pair instead.
			wed = Lineage.marry(couple[0], couple[1], 0, [], false)
			if not bool(wed.get("ok", false)):
				return "marriage setup: %s" % str(wed.get("msg", ""))
			couple[0].in_roster = true
			couple[1].in_roster = true
		else:
			couple[1].in_roster = true
	else:
		var sp: CKCharacter = GameState.characters[str(leader.spouse_id)]
		if sp != null:
			sp.in_roster = true
			sp.alive = true
	Calendar.advance(1)
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("marriage", ""))
	if tx == "":
		return "marriage echo empty: %s" % str(snap)
	var want_bit := Locale.t("ux_marriage_month_line", ["x", 1]).substr(0, 4)
	if tx.find(want_bit) < 0 and tx.find("联姻月结") < 0 and tx.find("Marriage month") < 0:
		return "marriage echo wording: %s" % tx
	print("month-echo marriage ok line=%s" % tx)
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


func _couple(tag: String, age: int) -> Array:
	var fa := CKCharacter.new()
	fa.id = tag + "_m"
	fa.name = tag
	fa.gender = "m"
	fa.age = age
	fa.rank = "knight"
	fa.alive = true
	fa.blood_mix = {"common_ash": 1.0}
	var mo := CKCharacter.new()
	mo.id = tag + "_f"
	mo.name = tag + "氏"
	mo.gender = "f"
	mo.age = age
	mo.rank = "knight"
	mo.alive = true
	mo.blood_mix = {"common_ash": 1.0}
	mo.in_roster = false  ## court-style; avoid A4 同袍 bond gate
	GameState.characters[fa.id] = fa
	GameState.characters[mo.id] = mo
	return [fa, mo]
