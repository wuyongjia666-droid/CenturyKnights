extends SceneTree
## Headless smoke: 立团→模拟战→婚→生子→推进月 → exit 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ok := true
	var errors: Array = []
	print("=== CenturyKnights smoke start ===")
	# Wait autoloads
	await process_frame
	await process_frame

	if GameState.data_bloodlines.get("bloodlines", []).size() < 4:
		ok = false
		errors.append("bloodlines < 4")
	if GameState.data_traits.get("traits", []).size() < 5:
		ok = false
		errors.append("traits too few")
	if GameState.data_jobs.get("jobs", []).size() < 9:
		ok = false
		errors.append("jobs incomplete")
	if GameState.data_chapter0.get("beats", []).size() < 7:
		ok = false
		errors.append("chapter0 beats missing")

	GameState.new_game("烬行", "灰旗", "#c9a227")
	var leader = GameState.get_leader()
	GameState.grant_job_skills(leader)
	if leader.skills.is_empty():
		ok = false
		errors.append("leader skills empty after grant")
	else:
		print("leader skills: ", leader.skills)
	if leader == null or leader.name != "灰旗烬行":
		ok = false
		errors.append("leader naming failed")

	# Simulate battle win flag + damage rules
	var enemy = CharacterFactory.make_enemy("bandit", GameState.rng)
	var prev = BattleRules.preview(leader, enemy, "forest")
	if prev.hit < 1 or prev.dmg.x < 1:
		ok = false
		errors.append("battle preview invalid")
	var atk = BattleRules.roll_attack(leader, enemy, "plain", GameState.rng)
	print("sample attack: ", atk)
	GameState.set_flag("battle_done")

	# Recruit
	GameState.refresh_tavern()
	if GameState.tavern_candidates.is_empty():
		ok = false
		errors.append("tavern empty")
	else:
		var r = GameState.recruit(GameState.tavern_candidates[0])
		if not r.get("ok", false):
			# try with more silver
			GameState.silver += 100
			r = GameState.recruit(GameState.tavern_candidates[0])
		if not GameState.flag("recruited"):
			ok = false
			errors.append("recruit flag")

	GameState.set_flag("hub_open")
	GameState.reputation["ashland"] = 85
	GameState.reputation["riverland"] = 60
	GameState.refresh_marriage_candidates()
	var cand = GameState.marriage_candidates[0]
	var expect = Lineage.heir_expectation(leader, cand)
	if not expect.has("apt_min") or not expect.has("appearance_probs"):
		ok = false
		errors.append("heir expectation missing")
	print("heir expect traits: ", expect.trait_probs.size())

	var marry = Lineage.marry(leader, cand, 40)
	if not marry.get("ok", false):
		ok = false
		errors.append("marry failed: " + str(marry.get("msg")))
	else:
		print("married: ", marry.msg)

	# Advance for birth
	var evs = Calendar.advance(1)
	print("after 1 month: ", Calendar.label(), " events=", evs.size())
	if not GameState.flag("child_born"):
		# force
		var mother = GameState.characters[leader.spouse_id]
		if mother.pregnant_months >= 0:
			mother.pregnant_months = 0
			Calendar.advance(1)
	if not GameState.flag("child_born"):
		ok = false
		errors.append("child not born")
	else:
		var kids = 0
		for c in GameState.characters.values():
			if c.is_child:
				kids += 1
				print("child: ", c.name, " blood=", c.bloodline_display())
		if kids < 1:
			ok = false
			errors.append("no child entity")

	# Forecast X5
	var fc = Calendar.forecast(3)
	print("forecast 3m: ", fc.size(), " items")

	# Advance to harvest
	var guard = 0
	while not GameState.flag("harvest_done") and guard < 20:
		Calendar.advance(1)
		guard += 1
	if not GameState.flag("harvest_done"):
		ok = false
		errors.append("harvest not reached")

	# Age changed?
	if leader.age < 22:
		ok = false
		errors.append("age did not increase plausibly")

	var journal = GameState.build_dynasty_journal()
	if journal.find("王朝手记") < 0:
		ok = false
		errors.append("journal missing")
	print(journal)

	# Save / load
	if not GameState.save_game():
		ok = false
		errors.append("save failed")
	var silver_before = GameState.silver
	GameState.silver = -999
	if not GameState.load_game():
		ok = false
		errors.append("load failed")
	if GameState.silver != silver_before:
		ok = false
		errors.append("save/load silver mismatch")

	# Move costs / terrain
	var map = []
	for y in 6:
		var row = []
		for x in 8:
			row.append("plain" if x % 2 == 0 else "forest")
		map.append(row)
	var costs = BattleRules.move_costs(map, Vector2i(0, 0), 4)
	if costs.size() < 3:
		ok = false
		errors.append("move_costs too small")

	# Locale Chinese menu keys
	for k in ["menu_new", "menu_continue", "menu_settings", "menu_quit"]:
		var s = Locale.t(k)
		if s == k or s.length() < 2:
			ok = false
			errors.append("locale " + k)

	if ok:
		print("=== SMOKE PASS ===")
		quit(0)
	else:
		print("=== SMOKE FAIL ===")
		for e in errors:
			print("ERR: ", e)
		quit(1)
