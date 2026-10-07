extends Node
## Headless smoke: 立团→模拟战规则→婚→生子→推进月 → quit 0/1

func _ready() -> void:
	await get_tree().process_frame
	var ok := true
	var errors: Array = []
	print("=== CenturyKnights smoke start ===")

	if GameState.data_bloodlines.get("bloodlines", []).size() < 4:
		ok = false; errors.append("bloodlines < 4")
	if GameState.data_traits.get("traits", []).size() < 5:
		ok = false; errors.append("traits too few")
	if GameState.data_jobs.get("jobs", []).size() < 9:
		ok = false; errors.append("jobs incomplete")
	if GameState.data_chapter0.get("beats", []).size() < 7:
		ok = false; errors.append("chapter0 beats missing")

	GameState.new_game("烬行", "灰旗", "#c9a227")
	var leader = GameState.get_leader()
	if leader == null or leader.name != "灰旗烬行":
		ok = false; errors.append("leader naming failed: %s" % (leader.name if leader else "null"))

	var enemy = CharacterFactory.make_enemy("bandit", GameState.rng)
	var prev = BattleRules.preview(leader, enemy, "forest")
	if int(prev.hit) < 1 or int(prev.dmg.x) < 1:
		ok = false; errors.append("battle preview invalid %s" % str(prev))
	var atk = BattleRules.roll_attack(leader, enemy, "plain", GameState.rng)
	print("sample attack: ", atk)
	GameState.set_flag("battle_done")

	GameState.refresh_tavern()
	if GameState.tavern_candidates.is_empty():
		ok = false; errors.append("tavern empty")
	else:
		GameState.silver += 100
		var r = GameState.recruit(GameState.tavern_candidates[0])
		print("recruit: ", r)
		if not GameState.flag("recruited"):
			ok = false; errors.append("recruit flag")

	GameState.set_flag("hub_open")
	GameState.reputation["ashland"] = 85
	GameState.reputation["riverland"] = 60
	GameState.refresh_marriage_candidates()
	var cand = GameState.marriage_candidates[0]
	var expect = Lineage.heir_expectation(leader, cand)
	if not expect.has("apt_min") or not expect.has("appearance_probs"):
		ok = false; errors.append("heir expectation missing")
	print("heir expect traits: ", expect.trait_probs.size())

	var marry = Lineage.marry(leader, cand, 40)
	print("marry: ", marry)
	if not marry.get("ok", false):
		ok = false; errors.append("marry failed: " + str(marry.get("msg")))

	var evs = Calendar.advance(1)
	print("after 1 month: ", Calendar.label(), " events=", evs.size())
	if not GameState.flag("child_born"):
		var spouse_id = leader.spouse_id
		if spouse_id != "" and GameState.characters.has(spouse_id):
			var mother = GameState.characters[spouse_id]
			if mother.gender != "f":
				mother = leader
			mother.pregnant_months = 0
			Calendar.advance(1)
	if not GameState.flag("child_born"):
		ok = false; errors.append("child not born")
	else:
		var kids = 0
		for c in GameState.characters.values():
			if c.is_child:
				kids += 1
				print("child: ", c.name, " blood=", c.bloodline_display())
		if kids < 1:
			ok = false; errors.append("no child entity")

	var fc = Calendar.forecast(3)
	print("forecast 3m: ", fc.size(), " items")

	var guard = 0
	while not GameState.flag("harvest_done") and guard < 20:
		Calendar.advance(1)
		guard += 1
	if not GameState.flag("harvest_done"):
		ok = false; errors.append("harvest not reached")

	print("leader age now: ", leader.age, " calendar: ", Calendar.label())

	var journal = GameState.build_dynasty_journal()
	if journal.find("王朝手记") < 0:
		ok = false; errors.append("journal missing")
	print(journal)

	if not GameState.save_game():
		ok = false; errors.append("save failed")
	var silver_before = GameState.silver
	GameState.silver = -999
	if not GameState.load_game():
		ok = false; errors.append("load failed")
	if GameState.silver != silver_before:
		ok = false; errors.append("save/load silver mismatch %s vs %s" % [GameState.silver, silver_before])

	var map: Array = []
	for y in 6:
		var row: Array = []
		for x in 8:
			row.append("plain" if x % 2 == 0 else "forest")
		map.append(row)
	var costs = BattleRules.move_costs(map, Vector2i(0, 0), 4)
	if costs.size() < 3:
		ok = false; errors.append("move_costs too small")

	for k in ["menu_new", "menu_continue", "menu_settings", "menu_quit"]:
		var s = Locale.t(k)
		if s == k or s.length() < 2:
			ok = false; errors.append("locale " + k)

	# Chinese titles check for beats
	for b in GameState.data_chapter0.get("beats", []):
		if str(b.get("title", "")).is_empty():
			ok = false; errors.append("empty beat title")

	if ok:
		print("=== SMOKE PASS ===")
		get_tree().quit(0)
	else:
		print("=== SMOKE FAIL ===")
		for e in errors:
			print("ERR: ", e)
		get_tree().quit(1)
