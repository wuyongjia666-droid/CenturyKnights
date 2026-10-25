extends Node
## Y1-B: begin_pregnancy + Calendar tick_conception → house_mods.month_echo.pregnancy;
## estates + hourglass EchoLine_pregnancy 回读. Odds unchanged (no fertility boost).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL month echo pregnancy: ", err)
		get_tree().quit(1)
	else:
		print("MONTH ECHO PREGNANCY PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	World.events_enabled = false
	World.rivals_enabled = false

	var err := _audit_begin_pregnancy()
	if err != "":
		return err
	err = await _audit_panel("pregnancy", "res://scenes/hub/estates.tscn", "MonthEchoPanel")
	if err != "":
		return err
	err = await _audit_panel("pregnancy", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	err = _audit_calendar_tick()
	if err != "":
		return err
	err = await _audit_panel("pregnancy", "res://scenes/hub/hourglass.tscn", "")
	if err != "":
		return err
	return ""


func _couple(tag: String, age: int) -> Array:
	var hus := CKCharacter.new()
	hus.id = "%s_h" % tag
	hus.name = "%s夫" % tag
	hus.gender = "m"
	hus.age = age
	hus.rank = "knight"
	hus.alive = true
	hus.in_roster = true
	hus.retired = false
	hus.is_leader = false
	hus.is_child = false
	hus.blood_mix = {"common_ash": 1.0}
	hus.stats = {"str": 8, "vit": 7, "skl": 6, "agi": 5, "per": 4, "wil": 9}
	var wife := CKCharacter.new()
	wife.id = "%s_w" % tag
	wife.name = "%s妻" % tag
	wife.gender = "f"
	wife.age = age
	wife.rank = "knight"
	wife.alive = true
	wife.in_roster = true
	wife.retired = false
	wife.is_leader = false
	wife.is_child = false
	wife.pregnant_months = -1
	wife.blood_mix = {"common_ash": 1.0}
	wife.blood_meta = {"children_born": 0}
	wife.stats = {"str": 5, "vit": 8, "skl": 6, "agi": 6, "per": 5, "wil": 8}
	GameState.characters[hus.id] = hus
	GameState.characters[wife.id] = wife
	return [hus, wife]


func _audit_begin_pregnancy() -> String:
	## Wedding/paced path: real PEAK_CONCEPTION_CHANCE (0.72); reseed until success — no rate boost.
	GameState.house_mods.erase("month_echo")
	var couple := _couple("echo_pg", 24)
	var mother: CKCharacter = couple[1]
	var father: CKCharacter = couple[0]
	father.spouse_id = mother.id
	mother.spouse_id = father.id
	var ok := false
	for seed in range(1, 80):
		mother.pregnant_months = -1
		mother.blood_meta.erase("gestation_term")
		mother.blood_meta.erase("litter")
		GameState.house_mods.erase("month_echo")
		GameState.rng.seed = seed
		if CKFamilyState.begin_pregnancy(GameState, mother):
			ok = true
			break
	if not ok:
		return "begin_pregnancy never succeeded in 79 seeds (odds gate?)"
	if mother.pregnant_months < 0:
		return "begin_pregnancy ok but pregnant_months unset"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("pregnancy", ""))
	if tx == "":
		return "pregnancy echo empty after begin_pregnancy: %s" % str(snap)
	if tx.find(mother.name) < 0:
		return "pregnancy echo missing mother: %s" % tx
	if tx.find("身孕") < 0 and tx.find("with child") < 0:
		return "pregnancy echo wording: %s" % tx
	print("month-echo pregnancy begin ok line=%s seed_term=%s" % [tx, str(mother.blood_meta.get("gestation_term", "?"))])
	return ""


func _audit_calendar_tick() -> String:
	## Monthly natural conception: real BASE_MONTHLY×fertility odds; advance until hit.
	GameState.house_mods.erase("month_echo")
	var couple := _couple("echo_ct", 26)
	var mother: CKCharacter = couple[1]
	var father: CKCharacter = couple[0]
	father.spouse_id = mother.id
	mother.spouse_id = father.id
	mother.pregnant_months = -1
	mother.blood_meta["children_born"] = 0
	mother.blood_meta.erase("last_birth_abs")
	GameState.rng.seed = 20261025
	var hit := false
	for _i in 180:
		Calendar.advance(1)
		if mother.pregnant_months >= 0:
			hit = true
			break
	if not hit:
		return "calendar tick_conception no hit in 180 months (seed/odds)"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("pregnancy", ""))
	if tx == "":
		return "pregnancy echo empty after calendar: %s" % str(snap)
	if tx.find(mother.name) < 0 and tx.find("身孕") < 0:
		return "calendar pregnancy echo weak: %s" % tx
	print("month-echo pregnancy calendar ok line=%s month=%d y=%d" % [tx, Calendar.month, Calendar.year])
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
