extends Node
## marriage-all-cast A4/A6: 同袍内婚 deepen on #473.
## Bond gate rejects → note_company_bond → cheaper bride price → Lineage.marry
## → 同袍 tab UI readback → month_echo.marriage names non-leader → estates EchoLine.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL internal marriage durability: ", err)
		get_tree().quit(1)
	else:
		print("INTERNAL MARRIAGE DURABILITY PASS")
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var e := _api_bond_gate_and_price()
	if e != "":
		return e
	e = _api_month_echo_non_leader()
	if e != "":
		return e
	e = await _ui_comrade_tab_wed()
	if e != "":
		return e
	e = await _ui_estates_echo()
	if e != "":
		return e
	return ""


func _add_merc(id: String, gender: String, age: int = 22) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = "佣兵·%s" % id
	c.gender = gender
	c.age = age
	c.alive = true
	c.in_roster = true
	c.retired = false
	c.is_leader = false
	c.job_id = "light_inf"
	c.rank = "knight"
	c.blood_mix = {"common_ash": 1.0}
	c.blood_meta = {}
	c.spouse_id = ""
	GameState.characters[id] = c
	return c


func _fresh() -> void:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	GameState.house_mods.erase("month_echo")
	GameState.house_mods.erase("company_bond")
	GameState.silver = maxi(GameState.silver, 200)
	World.events_enabled = false
	World.rivals_enabled = false


func _api_bond_gate_and_price() -> String:
	_fresh()
	var a := _add_merc("im_a", "m")
	var b := _add_merc("im_b", "f")
	var targets: Array = CKFamilyState.internal_marriage_targets(GameState, a)
	var ids: Array = []
	for t in targets:
		ids.append(str(t.id))
	var err := ""
	if not ("im_b" in ids):
		err = "A4 target missing from internal list: %s" % str(ids)
	var blocked: Dictionary = Lineage.can_propose(a, b)
	if err == "" and bool(blocked.get("ok", false)):
		err = "A4 bond gate should reject before acquaintance"
	var bmsg := str(blocked.get("msg", ""))
	if err == "" and bmsg.find(str(CKFamilyState.INTERNAL_BOND_NEED)) < 0 \
			and bmsg.find("羁绊") < 0 and bmsg.find("Bond") < 0:
		err = "A4 reject msg weak: %s" % bmsg
	if err == "":
		CKFamilyState.note_company_bond(a, b, CKFamilyState.INTERNAL_BOND_NEED)
		if not CKFamilyState.internal_bond_ok(a, b):
			err = "A4 bond still short after note"
	var ok: Dictionary = {}
	if err == "":
		ok = Lineage.can_propose(a, b)
		if not bool(ok.get("ok", false)):
			err = "A4 can_propose after bond: %s" % str(ok.get("msg"))
	if err == "" and CKFamilyState.bride_price_for(a, b) != CKFamilyState.INTERNAL_BRIDE_PRICE:
		err = "A4 internal price %d != %d" % [
			CKFamilyState.bride_price_for(a, b), CKFamilyState.INTERNAL_BRIDE_PRICE]
	if err == "":
		GameState.refresh_marriage_candidates("", a)
		if GameState.marriage_candidates.is_empty():
			err = "A4 no court posts to contrast price"
		else:
			var court: CKCharacter = GameState.marriage_candidates[0]
			if CKFamilyState.bride_price_for(a, court) != CKFamilyState.COURT_BRIDE_PRICE:
				err = "A4 court price drifted"
	if err == "":
		var silver0 := GameState.silver
		var wed: Dictionary = Lineage.marry(a, b, CKFamilyState.COURT_BRIDE_PRICE, null, false)
		if not bool(wed.get("ok", false)):
			err = "A4 marry failed: %s" % str(wed.get("msg"))
		else:
			var spent := silver0 - GameState.silver
			if spent != CKFamilyState.INTERNAL_BRIDE_PRICE:
				err = "A4 spent %d want internal %d (default 40 must auto-cut)" % [
					spent, CKFamilyState.INTERNAL_BRIDE_PRICE]
			elif str(a.spouse_id) != str(b.id) or str(b.spouse_id) != str(a.id):
				err = "A4 spouse_id not mutual"
			elif not bool(a.in_roster) or not bool(b.in_roster):
				err = "A4 roster cleared on internal wed"
			else:
				print("ROW PASS bond+price spent=%d" % spent)
	return err


func _api_month_echo_non_leader() -> String:
	_fresh()
	var a := _add_merc("im_echo_a", "m")
	var b := _add_merc("im_echo_b", "f")
	CKFamilyState.note_company_bond(a, b, CKFamilyState.INTERNAL_BOND_NEED)
	var wed: Dictionary = Lineage.marry(a, b, CKFamilyState.INTERNAL_BRIDE_PRICE, null, false)
	if not bool(wed.get("ok", false)):
		return "A6 marry: %s" % str(wed.get("msg"))
	GameState.house_mods.erase("month_echo")
	Calendar.advance(1)
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var tx := str(snap.get("marriage", ""))
	if tx == "":
		return "A6 marriage echo empty: %s" % str(snap)
	## Non-leader name should appear in the month line (family_state uses non-leader name).
	if tx.find(a.name) < 0 and tx.find(b.name) < 0:
		return "A6 echo missing roster spouse name: %s" % tx
	print("ROW PASS month_echo marriage=%s" % tx)
	return ""


func _ui_comrade_tab_wed() -> String:
	_fresh()
	var a := _add_merc("im_ui_a", "m")
	var b := _add_merc("im_ui_b", "f")
	CKFamilyState.note_company_bond(a, b, CKFamilyState.INTERNAL_BOND_NEED)
	GameState.marriage_focus_id = a.id
	var page: Control = load("res://scenes/hub/marriage.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame
	var err := ""
	if page.has_method("_set_suitor"):
		page.call("_set_suitor", a)
	if not page.has_method("_set_source_mode"):
		err = "UI missing _set_source_mode"
	else:
		page.call("_set_source_mode", "comrade")
	for _j in 6:
		await get_tree().process_frame
	if err == "":
		var bar: Node = page.find_child("SourceModeBar", true, false)
		if bar == null or bar.get_child_count() < 2:
			err = "SourceModeBar missing"
		elif str(page.get("_source_mode")) != "comrade":
			err = "comrade mode not set (got %s)" % str(page.get("_source_mode"))
		else:
			var comrade_btn: Button = null
			for ch in bar.get_children():
				if ch is Button and str(ch.name) == "Source_comrade":
					comrade_btn = ch as Button
					break
			if comrade_btn == null or not comrade_btn.button_pressed:
				err = "comrade tab not selected"
	if err == "":
		var reroll: Button = page.find_child("Reroll", true, false) as Button
		if reroll != null and reroll.visible:
			err = "reroll still visible on comrade tab"
	if err == "":
		var pool: Array = page.call("_candidate_pool")
		var found := false
		for c in pool:
			if str(c.id) == str(b.id):
				found = true
				break
		if not found:
			err = "UI pool missing im_ui_b"
	if err == "":
		if page.has_method("_select"):
			page.call("_select", b)
		for _k in 4:
			await get_tree().process_frame
		var cta: Button = page.get("_marry_btn") as Button
		if cta == null:
			err = "marry CTA missing"
		elif "20" not in cta.text and str(CKFamilyState.INTERNAL_BRIDE_PRICE) not in cta.text:
			err = "CTA price not internal: %s" % cta.text
	if err == "":
		var silver0 := GameState.silver
		page.set("_selected", b)
		var price := CKFamilyState.bride_price_for(a, b)
		var wed: Dictionary = Lineage.marry(a, b, price, null, false)
		if not bool(wed.get("ok", false)):
			err = "UI lineage marry: %s" % str(wed.get("msg"))
		else:
			for _m in 4:
				await get_tree().process_frame
			if page.has_method("_refresh"):
				page.call("_refresh")
			for _n in 4:
				await get_tree().process_frame
			if str(a.spouse_id) != str(b.id):
				err = "UI wed did not bind spouses"
			else:
				var spent := silver0 - GameState.silver
				if spent != CKFamilyState.INTERNAL_BRIDE_PRICE:
					err = "UI wed spent %d want %d" % [spent, CKFamilyState.INTERNAL_BRIDE_PRICE]
				else:
					var cta2: Button = page.get("_marry_btn") as Button
					if cta2 != null and not cta2.disabled and "20" in cta2.text:
						err = "CTA still looks unmarried after wed: %s" % cta2.text
					else:
						print("ROW PASS ui comrade tab spent=%d" % spent)
	page.queue_free()
	return err


func _ui_estates_echo() -> String:
	## Reuse month echo already written in _api_month_echo_non_leader path: re-seed cleanly.
	_fresh()
	var a := _add_merc("im_est_a", "m")
	var b := _add_merc("im_est_b", "f")
	CKFamilyState.note_company_bond(a, b, CKFamilyState.INTERNAL_BOND_NEED)
	var wed: Dictionary = Lineage.marry(a, b, CKFamilyState.INTERNAL_BRIDE_PRICE, null, false)
	if not bool(wed.get("ok", false)):
		return "estates setup: %s" % str(wed.get("msg"))
	GameState.house_mods.erase("month_echo")
	Calendar.advance(1)
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	var want := str(snap.get("marriage", ""))
	if want == "":
		return "estates: no marriage echo"
	var page: Control = load("res://scenes/hub/estates.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame
	var line: Node = page.find_child("EchoLine_marriage", true, false)
	if line == null:
		page.queue_free()
		return "EchoLine_marriage missing on estates"
	var shown := ""
	if line is Label:
		shown = (line as Label).text
	elif line.get("text") != null:
		shown = str(line.get("text"))
	if shown == "" or (shown.find(want.substr(0, mini(6, want.length()))) < 0 and shown.find("联姻") < 0):
		page.queue_free()
		return "EchoLine_marriage text mismatch got=%s want=%s" % [shown, want]
	page.queue_free()
	print("ROW PASS estates EchoLine_marriage")
	return ""
