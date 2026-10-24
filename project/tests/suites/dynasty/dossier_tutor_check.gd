extends Node
## Y1-B 专师可感：档案 TutorPanel — 未拜 → ToTrain/ToTavern；已拜 → 专师·课时。

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL dossier tutor: ", err)
		get_tree().quit(1)
	else:
		print("DOSSIER TUTOR PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", "frost")
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	var leader := GameState.get_leader()
	if leader == null:
		return "no leader"
	leader.age = 30
	leader.injured = false
	leader.in_roster = true
	var kid := CKCharacter.new()
	kid.id = "dos_pupil"
	kid.name = "试徒"
	kid.alive = true
	kid.is_child = true
	kid.in_roster = false
	kid.age = 10
	kid.parent_ids = [leader.id]
	kid.apt_max = {"str": 20, "vit": 20, "skl": 20, "agi": 20, "per": 20, "wil": 20}
	kid.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	kid.blood_meta = {}
	GameState.characters[kid.id] = kid

	var e := await _assert_empty(kid.id)
	if e != "":
		return e
	e = await _assert_paired(kid, leader)
	if e != "":
		return e
	e = await _assert_master(leader.id)
	if e != "":
		return e
	return ""


func _open_dossier(cid: String) -> Control:
	GameState.set_meta("dossier_id", cid)
	var page: Control = load("res://scenes/hub/unit_dossier.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	return page


func _await_frames(n: int = 8) -> void:
	for _i in n:
		await get_tree().process_frame


func _assert_empty(cid: String) -> String:
	var page := _open_dossier(cid)
	await _await_frames()
	var tree := page.find_child("FamilyTree", true, false)
	if tree == null:
		page.queue_free()
		return "FamilyTree missing"
	var panel := page.find_child("TutorPanel", true, false)
	if panel == null:
		page.queue_free()
		return "TutorPanel missing (empty)"
	if not tree.is_ancestor_of(panel):
		page.queue_free()
		return "TutorPanel not under FamilyTree"
	var empty := page.find_child("TutorEmpty", true, false) as Label
	if empty == null:
		page.queue_free()
		return "TutorEmpty missing"
	var want_empty := Locale.t("lb_dos_tutor_empty")
	if empty.text != want_empty and str(empty.text).find(want_empty) < 0:
		page.queue_free()
		return "TutorEmpty text want=%s got=%s" % [want_empty, empty.text]
	## Leader is eligible tutor → ToTrain (not tavern).
	var cta: Button = page.find_child("ToTrain", true, false) as Button
	if cta == null:
		page.queue_free()
		return "ToTrain missing (roster has tutors)"
	if not cta.visible or cta.disabled:
		page.queue_free()
		return "ToTrain not usable"
	var want := Locale.t("lb_dos_to_train")
	if cta.text != want:
		page.queue_free()
		return "ToTrain text want=%s got=%s" % [want, cta.text]
	if not panel.is_ancestor_of(cta):
		page.queue_free()
		return "ToTrain not under TutorPanel"
	if page.find_child("ToTavern", true, false) != null:
		page.queue_free()
		return "ToTavern should not show when tutors exist"
	print("dossier-tutor empty ok ToTrain under_tree=1")
	page.queue_free()
	await get_tree().process_frame
	return ""


func _assert_paired(kid: CKCharacter, leader: CKCharacter) -> String:
	var r := CKTutor.assign(kid.id, leader.id)
	if not bool(r.get("ok", false)):
		return "assign failed: %s" % r.get("msg", "")
	## Simulate one lesson used this year without full teach side-effects.
	var yc = GameState.house_mods.get("tutor_year", {})
	if typeof(yc) != TYPE_DICTIONARY:
		yc = {}
	yc["%s|%s|%d" % [kid.id, leader.id, Calendar.year]] = 1
	GameState.house_mods["tutor_year"] = yc
	GameState.mark_dirty()
	var page := _open_dossier(kid.id)
	await _await_frames()
	if page.find_child("ToTrain", true, false) != null:
		page.queue_free()
		return "ToTrain should hide when paired"
	if page.find_child("TutorEmpty", true, false) != null:
		page.queue_free()
		return "TutorEmpty should hide when paired"
	var line := page.find_child("TutorLine", true, false) as Label
	if line == null:
		page.queue_free()
		return "TutorLine missing"
	var lim := CKTutor.year_limit()
	var want := Locale.t("lb_dos_tutor_line", [leader.name, 1, lim])
	if line.text != want and str(line.text).find(leader.name) < 0:
		page.queue_free()
		return "TutorLine want=%s got=%s" % [want, line.text]
	if str(line.text).find("1/%d" % lim) < 0 and str(line.text).find(str(1)) < 0:
		page.queue_free()
		return "TutorLine missing lesson count got=%s" % line.text
	print("dossier-tutor paired ok name=%s lessons=1/%d" % [leader.name, lim])
	page.queue_free()
	await get_tree().process_frame
	return ""


func _assert_master(leader_id: String) -> String:
	var page := _open_dossier(leader_id)
	await _await_frames()
	var master := page.find_child("TutorMaster", true, false) as Label
	if master == null:
		page.queue_free()
		return "TutorMaster missing on tutor dossier"
	var want := Locale.t("lb_dos_tutor_master", [1])
	if master.text != want and str(master.text).find("1") < 0:
		page.queue_free()
		return "TutorMaster want=%s got=%s" % [want, master.text]
	print("dossier-tutor master ok pupils=1")
	page.queue_free()
	return ""
