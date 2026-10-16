extends Node
## marriage-all-cast P0: non-leader suitor can wed; candidate sex follows suitor;
## chapter0 married flag does not block other cast weddings (A2/A3/A11/A12).

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL all-cast marry: ", err)
		get_tree().quit(1)
	else:
		print("ALL-CAST MARRY PASS")
		get_tree().quit(0)

func _run() -> String:
	var e := _a2_merc_after_leader()
	if e != "":
		return e
	e = _a3_gender_follows_suitor()
	if e != "":
		return e
	e = _a11_flag_not_global_lock()
	if e != "":
		return e
	e = _a13_hero_vs_merc_reroll()
	if e != "":
		return e
	e = _a14_monthly_reroll_cap()
	if e != "":
		return e
	e = _a15_month_rotates_posts()
	if e != "":
		return e
	e = await _a10_page_after_leader_wed()
	if e != "":
		return e
	e = await _a5_dossier_propose()
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

func _a2_merc_after_leader() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var lead: CKCharacter = GameState.get_leader()
	lead.gender = "m"
	GameState.reputation["ashland"] = 90
	GameState.silver = 200
	GameState.refresh_marriage_candidates("", lead)
	var cand: CKCharacter = GameState.marriage_candidates[0]
	var r: Dictionary = Lineage.marry(lead, cand, 40)
	if not bool(r.get("ok", false)):
		return "A2 leader marry failed: %s" % str(r.get("msg"))
	if not GameState.flag("married"):
		return "A2 teaching flag missing after leader wed"
	var merc := _add_merc("merc_m1", "m")
	GameState.marriage_focus_id = merc.id
	GameState.refresh_marriage_candidates("", merc)
	if GameState.marriage_candidates.is_empty():
		return "A2 no court posts for merc"
	for c in GameState.marriage_candidates:
		if str(c.gender) != "f":
			return "A2 merc-m got %s candidate" % c.gender
	var target: CKCharacter = GameState.marriage_candidates[0]
	var r2: Dictionary = Lineage.marry(merc, target, 40)
	if not bool(r2.get("ok", false)):
		return "A2 merc marry failed: %s" % str(r2.get("msg"))
	if str(merc.spouse_id) != str(target.id) or str(target.spouse_id) != str(merc.id):
		return "A2 spouse_id not mutual"
	if str(merc.blood_meta.get("marriage_phase", "")) != "wed":
		return "A2 marriage_phase not wed"
	return ""

func _a3_gender_follows_suitor() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var fem := _add_merc("merc_f1", "f")
	GameState.marriage_focus_id = fem.id
	for _k in 3:
		GameState.refresh_marriage_candidates("", fem)
		for c in GameState.marriage_candidates:
			if str(c.gender) != "m":
				return "A3 female suitor got %s" % c.gender
	var male := _add_merc("merc_m2", "m")
	GameState.refresh_marriage_candidates("", male)
	for c2 in GameState.marriage_candidates:
		if str(c2.gender) != "f":
			return "A3 male suitor got %s" % c2.gender
	return ""

func _a11_flag_not_global_lock() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	## Simulate teaching flag set without blocking other cast.
	GameState.chapter0_flags["married"] = true
	var merc := _add_merc("merc_m3", "m")
	GameState.reputation["ashland"] = 90
	GameState.silver = 200
	GameState.refresh_marriage_candidates("", merc)
	var target: CKCharacter = GameState.marriage_candidates[0]
	var check: Dictionary = Lineage.can_propose(merc, target)
	if not bool(check.get("ok", false)):
		return "A11 can_propose blocked: %s" % str(check.get("msg"))
	var r: Dictionary = Lineage.marry(merc, target, 40)
	if not bool(r.get("ok", false)):
		return "A11 merc marry blocked by teaching flag: %s" % str(r.get("msg"))
	## Non-leader wed must not be the sole owner of the teaching flag semantics —
	## flag may stay true from chapter0; spouse_id proves the merc wedding landed.
	if str(merc.spouse_id) == "":
		return "A11 merc spouse_id empty"
	return ""

func _a10_page_after_leader_wed() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var lead: CKCharacter = GameState.get_leader()
	lead.gender = "m"
	GameState.reputation["ashland"] = 90
	GameState.silver = 200
	GameState.refresh_marriage_candidates("", lead)
	var r: Dictionary = Lineage.marry(lead, GameState.marriage_candidates[0], 40)
	if not bool(r.get("ok", false)):
		return "A10 setup marry failed"
	var merc := _add_merc("merc_m4", "m")
	GameState.marriage_focus_id = merc.id
	var page = load("res://scenes/hub/marriage.tscn").instantiate()
	add_child(page)
	for i in 4:
		await get_tree().process_frame
	if page._get_suitor() == null or str(page._get_suitor().id) != merc.id:
		return "A10 page suitor not merc"
	if page.is_married_view():
		return "A10 unmarried merc shown as married view"
	if page._suitor_bar == null or page._suitor_bar.get_child_count() < 2:
		return "A10 suitor bar missing entries"
	## Switch back to leader → married view
	page._set_suitor(lead)
	for i in 3:
		await get_tree().process_frame
	if not page.is_married_view():
		return "A10 leader focus not married view"
	page.queue_free()
	await get_tree().process_frame
	return ""

func _a5_dossier_propose() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var merc := _add_merc("merc_m5", "f")
	GameState.set_meta("dossier_id", merc.id)
	var page = load("res://scenes/hub/unit_dossier.tscn").instantiate()
	add_child(page)
	for i in 3:
		await get_tree().process_frame
	var btn = page.find_child("OpenMarriage", true, false)
	if btn == null:
		return "A5 dossier missing 议亲 button"
	page.queue_free()
	await get_tree().process_frame
	return ""

func _a13_hero_vs_merc_reroll() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var lead: CKCharacter = GameState.get_leader()
	if not CKFamilyState.is_hero_party(lead):
		return "A13 leader not hero_party"
	if CKFamilyState.can_reroll_court(lead):
		return "A13 leader must not reroll court"
	var blocked: Dictionary = GameState.reroll_marriage_candidates("", lead)
	if bool(blocked.get("ok", false)):
		return "A13 hero reroll should fail"
	var merc := _add_merc("merc_reroll", "m")
	if CKFamilyState.is_hero_party(merc):
		return "A13 plain merc flagged hero"
	if not CKFamilyState.can_reroll_court(merc):
		return "A13 merc should reroll"
	GameState.silver = CKFamilyState.COURT_REROLL_SILVER
	GameState.refresh_marriage_candidates("", merc)
	var r: Dictionary = GameState.reroll_marriage_candidates("", merc)
	if not bool(r.get("ok", false)):
		return "A13 merc reroll failed: %s" % str(r.get("msg"))
	if GameState.silver != 0:
		return "A13 silver not charged (%d)" % GameState.silver
	## Companion cast_key: hero, no court posts
	var dy := _add_merc("dy_story", "f")
	dy.cast_key = "dengying"
	dy.name = "苇原·灯影"
	if not CKFamilyState.is_hero_party(dy):
		return "A13 dengying cast_key not hero"
	GameState.refresh_marriage_candidates("", dy)
	if not GameState.marriage_candidates.is_empty():
		return "A13 companion should not get court posts"
	var r2: Dictionary = GameState.reroll_marriage_candidates("", dy)
	if bool(r2.get("ok", false)):
		return "A13 companion reroll should fail"
	return ""

func _a14_monthly_reroll_cap() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var merc := _add_merc("merc_cap", "m")
	var cap := CKFamilyState.COURT_REROLL_MONTHLY_CAP
	var cost := CKFamilyState.COURT_REROLL_SILVER
	GameState.silver = cost * (cap + 2)
	GameState.marriage_rerolls_used = 0
	GameState.refresh_marriage_candidates("", merc)
	for i in cap:
		var r: Dictionary = GameState.reroll_marriage_candidates("", merc)
		if not bool(r.get("ok", false)):
			return "A14 reroll %d failed: %s" % [i + 1, str(r.get("msg"))]
	if CKFamilyState.court_rerolls_left(GameState) != 0:
		return "A14 expected 0 left after cap"
	var blocked: Dictionary = GameState.reroll_marriage_candidates("", merc)
	if bool(blocked.get("ok", false)):
		return "A14 third reroll should hit monthly cap"
	if not str(blocked.get("msg", "")).contains("本月"):
		return "A14 cap msg odd: %s" % str(blocked.get("msg"))
	## Month tick resets (same hook as Calendar family / doctrine month)
	CKFamilyState.reset_court_rerolls_month(GameState)
	if CKFamilyState.court_rerolls_used(GameState) != 0:
		return "A14 month reset did not clear counter"
	GameState.marriage_rerolls_used = cap
	var _msgs: Array = CKFamilyState.tick_doctrine_and_marriage_month(GameState)
	if CKFamilyState.court_rerolls_used(GameState) != 0:
		return "A14 doctrine/marriage month tick did not reset"
	var again: Dictionary = GameState.reroll_marriage_candidates("", merc)
	if not bool(again.get("ok", false)):
		return "A14 post-reset reroll failed: %s" % str(again.get("msg"))
	if GameState.marriage_rerolls_used != 1:
		return "A14 used should be 1 after reset+reroll"
	return ""

func _a15_month_rotates_posts() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	var merc := _add_merc("merc_rotate", "m")
	GameState.marriage_focus_id = merc.id
	GameState.refresh_marriage_candidates("", merc)
	if GameState.marriage_candidates.size() != 3:
		return "A15 expected 3 posts"
	var before: Array = []
	for c in GameState.marriage_candidates:
		before.append(str(c.id))
	## Month tick while merc is focus → free rotate, discard last month's three
	var msgs: Array = CKFamilyState.tick_doctrine_and_marriage_month(GameState)
	if GameState.marriage_candidates.size() != 3:
		return "A15 after tick expected 3 posts"
	var after: Array = []
	for c2 in GameState.marriage_candidates:
		after.append(str(c2.id))
	var same := 0
	for id in before:
		if id in after:
			same += 1
	if same == 3:
		return "A15 posts not rotated (all ids identical)"
	if GameState.marriage_rerolls_used != 0:
		return "A15 rotate must not consume reroll quota"
	## Hero captain: month tick must not wipe teaching snapshot into empty / force-farm
	GameState.marriage_focus_id = str(GameState.get_leader().id)
	GameState.refresh_marriage_candidates("", GameState.get_leader())
	var hero_ids: Array = []
	for c3 in GameState.marriage_candidates:
		hero_ids.append(str(c3.id))
	CKFamilyState.tick_doctrine_and_marriage_month(GameState)
	var hero_after: Array = []
	for c4 in GameState.marriage_candidates:
		hero_after.append(str(c4.id))
	if hero_ids != hero_after:
		return "A15 hero captain posts should stay put across month tick"
	return ""
