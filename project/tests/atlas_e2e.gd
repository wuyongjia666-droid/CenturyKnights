extends Node
## v8.7 atlas e2e: data counts → travel (days/food/calendar) → city → smith buy+equip (stats) → market trade →
## accept commission → battle encounter (real battle scene, _finish) → turn in → deliver → save/load round-trip → UI scenes.

var errors: Array = []

func _ready() -> void:
	await get_tree().process_frame
	print("=== CenturyKnights atlas e2e start ===")
	GameState.new_game("烬行", "灰旗", "#c9a227")
	World.events_enabled = false
	_step_counts()
	_step_travel()
	_step_smith()
	_step_market()
	await _step_quest_battle()
	_step_deliver()
	_step_events()
	_step_tavern()
	_step_depth()
	_step_save_load()
	await _step_scenes()
	if errors.is_empty():
		print("=== ATLAS E2E PASS ===")
		get_tree().quit(0)
	else:
		print("=== ATLAS E2E FAIL ===")
		for e in errors:
			print("ERR: ", e)
		get_tree().quit(1)

func _err(m: String) -> void:
	errors.append(m)
	print("ERR: ", m)

func _ok(cond: bool, m: String) -> void:
	if cond:
		print("OK ", m)
	else:
		_err(m)

func _step_counts() -> void:
	print("--- STEP: counts ---")
	var s: Dictionary = World.summary_counts()
	print("counts ", s)
	_ok(int(s.nations) == 11, "11 regions (10 nations + landbridge)")
	_ok(int(s.nodes) >= 70, "nodes >= 70")
	_ok(int(s.items) >= 200, "items >= 200")
	_ok(int(s.signature) >= 140, "signature arms >= 140")
	_ok(int(s.sig_quests) >= 70, "signature commissions >= 70")
	for nid in World.nation_ids():
		var ns: Array = World.nodes_in(str(nid))
		_ok(ns.size() >= 4, "%s has %d settlements" % [nid, ns.size()])
		for n in ns:
			var p: Array = n.pos
			if float(p[0]) < 0.03 or float(p[0]) > 0.97 or float(p[1]) < 0.03 or float(p[1]) > 0.97:
				_err("node %s off-plate %s" % [n.id, p])
	# every node reachable from the castle
	for id in World.nodes.keys():
		if World.route("hq", str(id)).is_empty():
			_err("unreachable " + str(id))

func _step_travel() -> void:
	print("--- STEP: travel ---")
	var food0 := GameState.food
	var d0: int = World.days_total
	var pv: Dictionary = World.travel_preview("ash_capital")
	_ok(bool(pv.ok) and int(pv.days) >= 1, "preview hq→ash_capital %s days" % pv.get("days"))
	var r: Dictionary = World.travel_to("ash_capital")
	_ok(World.pos == "ash_capital", "arrived ash_capital (pos=%s)" % World.pos)
	_ok(World.days_total == d0 + int(pv.days), "days advanced by route days")
	_ok(GameState.food == food0 - int(pv.food), "rations consumed %d" % int(pv.food))
	# long trip crosses a month boundary → Calendar advances (aging/upkeep pipeline)
	var m0 := Calendar.month
	var y0 := Calendar.year
	World.advance_days(31)
	_ok(Calendar.month != m0 or Calendar.year != y0, "31 road days advanced the calendar month")
	GameState.food = 200

func _step_smith() -> void:
	print("--- STEP: smith ---")
	var city := "ash_capital"
	var st: Array = World.smith_stock(city)
	_ok(st.size() >= 7, "smith stock %d" % st.size())
	var sig1 := "ash_capital_sig1"
	var e := {}
	for x in st:
		if str(x.item.id) == sig1:
			e = x
	_ok(not e.is_empty() and bool(e.available), "signature 白垣制式长剑 available at rep %d" % World.rep_of(city))
	var leg: Dictionary = {}
	for x in st:
		if str(x.item.id) == "ash_capital_sig2":
			leg = x
	_ok(not leg.is_empty() and not bool(leg.available), "legendary locked behind commission: %s" % leg.get("reason", ""))
	GameState.silver = 2000
	var r: Dictionary = World.buy_item(city, sig1)
	_ok(bool(r.ok), "buy: " + str(r.msg))
	var leader: CKCharacter = GameState.get_leader()
	var atk0 := leader.derived_atk()
	var hit0 := leader.derived_hit()
	var eq: Dictionary = World.equip(leader.id, sig1)
	_ok(bool(eq.ok), "equip: " + str(eq.msg))
	_ok(leader.derived_atk() > atk0, "atk %d → %d" % [atk0, leader.derived_atk()])
	_ok(leader.derived_hit() > hit0, "hit %d → %d" % [hit0, leader.derived_hit()])
	var chars := [leader]
	World.grant_gear_skills(leader)
	_ok("banner_crash" in leader.skills, "signature grants 旗锋裂阵 in battle")
	# forge with materials
	var t1 := "ashbanner_sword_1"
	GameState.iron = 10
	var fr: Dictionary = World.forge_item(city, t1)
	_ok(bool(fr.ok), "forge: " + str(fr.msg))

func _step_market() -> void:
	print("--- STEP: market ---")
	var city := "ash_capital"
	var buy_p: int = World.price(city, "ashsteel", "buy")
	var r: Dictionary = World.market_buy(city, "ashsteel", 5)
	_ok(bool(r.ok), "buy ashsteel x5 " + str(r.msg))
	_ok(World.have_good("ashsteel") == 5, "cargo ashsteel 5")
	_ok(World.price(city, "ashsteel", "buy") >= buy_p, "price rose with demand")
	# demand city pays more than producer
	_ok(World.price("ash_capital", "silk", "sell") > World.price("qh_capital", "silk", "sell"), "silk dearer in 白垣 than 玉澜 (produce vs demand)")

func _step_quest_battle() -> void:
	print("--- STEP: commission + battle ---")
	var city := "ash_capital"
	World.rep_city[city] = 40
	World.boards.erase(city)
	var offers: Array = World.board(city)
	_ok(offers.size() >= 3, "board %d offers" % offers.size())
	var sig := {}
	for q in offers:
		if bool(q.get("sig", false)):
			sig = q
	_ok(not sig.is_empty(), "signature commission on board: " + str(sig.get("title", "")))
	var a: Dictionary = World.accept_quest(city, str(sig.id))
	_ok(bool(a.ok), "accept: " + str(a.msg))
	var q: Dictionary = World.quest_by_id(str(sig.id))
	# go fight: clear → traverse edge ; hunt/defend → arrive at target
	var info := {}
	if str(q.kind) == "clear":
		var e: Array = q.edge
		var start := str(e[0]) if World.pos != str(e[0]) else str(e[1])
		var other := str(e[1]) if start == str(e[0]) else str(e[0])
		if World.pos != start:
			World.travel_to(start)
		info = World.travel_to(other)
	else:
		info = World.travel_to(str(q.target))
	_ok(not World.encounter.is_empty(), "encounter started (%s) at %s" % [q.kind, World.encounter.get("node", "?")])
	if World.encounter.is_empty():
		return
	World.ensure_encounter_map()
	GameState.set_meta("battle_map", str(World.encounter.id))
	GameState.set_meta("battle_return", World.ATLAS_SCENE)
	GameState.set_meta("world_encounter", true)
	var m: Dictionary = BattleMaps.get_map(str(World.encounter.id))
	_ok(m.get("enemy_templates", []).size() >= 3, "generated map has %d regional foes" % m.get("enemy_templates", []).size())
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	battle.size = Vector2(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(str(battle.map_id) == str(World.encounter.id), "battle loaded generated map %s" % battle.map_id)
	battle._finish(true)
	await get_tree().process_frame
	battle.queue_free()
	await get_tree().process_frame
	q = World.quest_by_id(str(sig.id))
	_ok(str(q.get("state", "")) == "ready", "objective ready after victory (state=%s)" % q.get("state", ""))
	_ok(not GameState.has_meta("world_encounter"), "encounter meta cleared")
	var back: String = World.turn_in_city(q)
	if World.pos != back:
		World.travel_to(back)
	var silver0 := GameState.silver
	var rep0: int = World.rep_of(city)
	var t: Dictionary = World.turn_in(str(sig.id))
	_ok(bool(t.ok), "turn in: " + str(t.msg))
	_ok(GameState.silver > silver0 and World.rep_of(city) > rep0, "reward silver+rep")
	_ok(World.done_sig.has(str(sig.id)), "signature commission recorded")
	World.rep_city[city] = 60
	var leg := {}
	for x in World.smith_stock(city):
		if str(x.item.id) == "ash_capital_sig2":
			leg = x
	_ok(bool(leg.get("available", false)), "legendary 议会之誓·烬冠剑 unlocked")

func _step_deliver() -> void:
	print("--- STEP: deliver ---")
	var city := World.pos
	World.boards.erase(city)
	var q := {}
	for x in World.board(city):
		if str(x.kind) in ["deliver", "scout", "escort"] and World.quest_locked_reason(x) == "":
			q = x
			break
	if q.is_empty():
		var r := RandomNumberGenerator.new()
		r.seed = 7
		q = World._make_quest(city, "deliver", 1, r)
		World.boards[city].offers.append(q)
	var a: Dictionary = World.accept_quest(city, str(q.id))
	_ok(bool(a.ok), "accept %s: %s" % [q.kind, a.msg])
	World.travel_to(str(q.target))
	var live: Dictionary = World.quest_by_id(str(q.id))
	_ok(str(live.get("state", "")) == "ready", "%s objective ready on arrival" % q.kind)
	var dest: String = World.turn_in_city(live)
	if World.pos != dest:
		World.travel_to(dest)
	var t: Dictionary = World.turn_in(str(q.id))
	_ok(bool(t.ok), "turn in %s: %s" % [q.kind, t.msg])

func _step_events() -> void:
	print("--- STEP: road events ---")
	var ev: Dictionary = World.make_event("refugees", "hq", "stone_slope")
	_ok(not ev.is_empty(), "event instantiated: " + str(ev.get("title", "")))
	var food0 := GameState.food
	var r: Dictionary = World.choose_event(0)
	_ok(bool(r.ok) and GameState.food == food0 - 6, "refugee choice applied (%s)" % r.get("msg", ""))
	var ev2: Dictionary = World.make_event("ambush", World.pos, World.pos)
	var r2: Dictionary = World.choose_event(0)
	_ok(not r2.get("encounter", {}).is_empty(), "ambush choice → encounter")
	World.on_battle_end(true)
	_ok(World.encounter.is_empty(), "encounter resolved")

func _step_tavern() -> void:
	print("--- STEP: tavern ---")
	var lst: Array = World.city_recruits("qh_capital")
	_ok(lst.size() == 3, "玉澜 tavern 3 recruits")
	var rw := 0
	for c in lst:
		if c.primary_bloodline() in ["river_ward", "common_ash"]:
			rw += 1
	_ok(rw == lst.size(), "regional bloodlines (清河 → 河卫/民胤)")

func _step_depth() -> void:
	print("--- STEP: board depth + reputation unlocks ---")
	var city := "qh_capital"
	World.rep_city[city] = 8
	var sz0: int = World.board_size(city)
	World.milestones.clear()
	World.add_city_rep(city, 3)
	_ok(World.board_size(city) == sz0 + 1, "认识 tier grows the board (%d → %d)" % [sz0, World.board_size(city)])
	_ok(not World.milestones.is_empty() and str(World.milestones[-1].text).contains("认识"), "milestone raised: %s" % (World.milestones[-1].text if not World.milestones.is_empty() else "none"))
	# hostile nation gating (朔影国)
	var sy := ""
	for n in World.nodes_in("shuoying"):
		if str(n.kind) != "castle":
			sy = str(n.id)
			break
	World.rep_nation["shuoying"] = 0
	var r := RandomNumberGenerator.new()
	r.seed = 11
	var hq: Dictionary = World._make_quest(sy, "deliver", 1, r)
	_ok(World.quest_locked_reason(hq).contains("邦交"), "hostile nation locks commissions: %s" % World.quest_locked_reason(hq))
	World.rep_nation["shuoying"] = 12
	_ok(World.quest_locked_reason(hq) == "", "邦交「认识」opens them")
	# nation tolls waived at 友善
	World.rep_nation["frostcrown"] = 30
	_ok(World.toll_for("frostcrown") == 0, "友善邦交 waives tolls")
	# commission chain
	var q: Dictionary = World._make_quest("ash_capital", "deliver", 1, r)
	q["chain"] = true
	var f: Dictionary = World._spawn_follow_up(q)
	_ok(not f.is_empty() and str(f.title).begins_with("续·") and int(f.tier) == 2, "follow-up commission spawned: %s" % f.get("title", ""))
	var found := false
	for o in World.board(World.turn_in_city(q)):
		if str(o.id) == str(f.get("id", "")):
			found = true
	_ok(found, "follow-up sits on the turn-in city's board")
	# 盟誓 tavern noble
	World.rep_city["ash_capital"] = 85
	var lst: Array = World.city_recruits("ash_capital")
	_ok(lst.size() == int(World.node("ash_capital").tavern_slots) + 1 and (lst[-1] as CKCharacter).rank == "baron", "盟誓 adds a titled recruit")

func _step_save_load() -> void:
	print("--- STEP: save/load ---")
	var snap: Dictionary = World.to_save()
	var leader: CKCharacter = GameState.get_leader()
	var wpn := leader.weapon_id
	var atk := leader.derived_atk()
	_ok(GameState.save_game(), "save_game")
	World.reset()
	leader.weapon_id = ""
	_ok(World.pos == "hq", "reset moved party home")
	_ok(GameState.load_game(), "load_game")
	leader = GameState.get_leader()
	_ok(World.pos == str(snap.pos), "position restored %s" % World.pos)
	_ok(World.days_total == int(snap.days_total), "days restored")
	_ok(World.rep_of("ash_capital") == int(snap.rep_city.ash_capital), "city rep restored")
	_ok(World.done_sig.size() == snap.done_sig.size(), "signature progress restored")
	_ok(World.armory.size() == snap.armory.size(), "armory restored")
	_ok(World.have_good("ashsteel") == int(snap.cargo.get("ashsteel", 0)), "cargo restored")
	_ok(leader.weapon_id == wpn and leader.derived_atk() == atk, "equipped weapon + stats restored")
	_ok(World.quest_log.size() == snap.quest_log.size(), "quest log restored")

func _step_scenes() -> void:
	print("--- STEP: scenes ---")
	for p in ["res://scenes/hub/atlas_view.tscn", "res://scenes/hub/city.tscn"]:
		if not ResourceLoader.exists(p):
			_err("missing scene " + p)
			continue
		var s = load(p).instantiate()
		add_child(s)
		s.size = Vector2(1280, 720)
		await get_tree().process_frame
		await get_tree().process_frame
		if s.has_method("selftest"):
			var r: Dictionary = await s.selftest()
			_ok(bool(r.get("ok", false)), "%s selftest: %s" % [p.get_file(), r.get("msg", "")])
		s.queue_free()
		await get_tree().process_frame
