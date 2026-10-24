extends Node
## Y1-B 职印可感：档案 JobSealsPanel — 空则 ToCity；盖印后列出职印名。
## 不中途 emit CTA（CKNav.go 会换页拖死后续断言）。

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL dossier job seals: ", err)
		get_tree().quit(1)
	else:
		print("DOSSIER JOB SEALS PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", "frost")
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	var leader := GameState.get_leader()
	if leader == null:
		return "no leader"

	var e := await _assert_empty(leader)
	if e != "":
		return e
	e = await _assert_stamped(leader)
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


func _assert_empty(leader: CKCharacter) -> String:
	var page := _open_dossier(leader.id)
	await _await_frames()
	var panel := page.find_child("JobSealsPanel", true, false)
	if panel == null:
		page.queue_free()
		return "JobSealsPanel missing (empty)"
	var empty := page.find_child("JobSealsEmpty", true, false) as Label
	if empty == null:
		page.queue_free()
		return "JobSealsEmpty missing"
	var want_empty := Locale.t("lb_dos_seals_empty")
	if empty.text != want_empty and str(empty.text).find(want_empty) < 0:
		page.queue_free()
		return "JobSealsEmpty text want=%s got=%s" % [want_empty, empty.text]
	var cta: Button = page.find_child("ToCity", true, false) as Button
	if cta == null:
		page.queue_free()
		return "ToCity missing"
	if not cta.visible or not cta.is_visible_in_tree():
		page.queue_free()
		return "ToCity not visible"
	if cta.disabled:
		page.queue_free()
		return "ToCity disabled"
	var want := Locale.t("lb_dos_to_city")
	if cta.text != want:
		page.queue_free()
		return "ToCity text want=%s got=%s" % [want, cta.text]
	if not panel.is_ancestor_of(cta):
		page.queue_free()
		return "ToCity not under JobSealsPanel"
	## City hint: set meta the same way the button would, without CKNav.go.
	var hint := CKJobSeals.stamp_city_hint(leader)
	GameState.set_meta("city_id", hint)
	if str(GameState.get_meta("city_id", "")) != hint:
		page.queue_free()
		return "city_id write failed"
	## priest → seal city; default leader usually not priest → World.pos.
	leader.job_id = "priest"
	var priest_hint := CKJobSeals.stamp_city_hint(leader)
	if priest_hint != "lt_capital":
		page.queue_free()
		return "stamp_city_hint priest want=lt_capital got=%s" % priest_hint
	print("dossier-seals empty ok ToCity under_panel=1 hint=%s priest=%s" % [hint, priest_hint])
	page.queue_free()
	await get_tree().process_frame
	return ""


func _assert_stamped(leader: CKCharacter) -> String:
	leader.blood_meta["job_seals"] = ["yan_zhan"]
	GameState.mark_dirty()
	var page := _open_dossier(leader.id)
	await _await_frames()
	var panel := page.find_child("JobSealsPanel", true, false)
	if panel == null:
		page.queue_free()
		return "JobSealsPanel missing (stamped)"
	if page.find_child("ToCity", true, false) != null:
		page.queue_free()
		return "ToCity should hide when stamped"
	if page.find_child("JobSealsEmpty", true, false) != null:
		page.queue_free()
		return "JobSealsEmpty should hide when stamped"
	var line := page.find_child("JobSeal_0", true, false) as Label
	if line == null:
		page.queue_free()
		return "JobSeal_0 missing"
	var nm := str(CKJobSeals.seal_row("yan_zhan").get("name", "yan_zhan"))
	if str(line.text).find(nm) < 0:
		page.queue_free()
		return "JobSeal_0 missing name %s got=%s" % [nm, line.text]
	print("dossier-seals stamped ok name=%s" % nm)
	page.queue_free()
	return ""
