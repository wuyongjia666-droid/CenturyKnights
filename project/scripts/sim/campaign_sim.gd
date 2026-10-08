class_name CKCampaignSim
extends RefCounted
## Headless century: a scripted company plays chapters, tactics, the castle, marriage,
## birth, aging and succession for `years` years on the real rules. Travel is resolved
## as a successful contract (road events off) so a hundred years stays inside CI.

const CASTLE_QUESTS := ["q_escort", "q_herb", "q_bridge", "q_bandit"]

static func run(years: int = 100, seed_i: int = 91) -> Dictionary:
	var report := {
		"years": years, "seed": seed_i, "chapters": 0, "successions": 0, "promotions": 0,
		"commission_gold": 0, "commissions": 0, "smith_gold": 0, "smith_buys": 0,
		"lamp": {}, "crises": 0, "recalls": 0, "royal_casts": 0, "births": 0,
		"silver_min": 999999, "silver_max": 0, "years_broke": 0, "years_starved": 0,
		"samples": [], "stuck": "", "opening": "", "line": [],
	}
	GameState.rng.seed = seed_i
	World.rng.seed = seed_i + 17
	World.events_enabled = false
	GameState.new_game("烬行", "灰旗", "#c9a227")
	World.events_enabled = false
	# The scripted company has already stood the opening chapter, the way a loaded campaign would.
	GameState.add_rep("ashland", 16)
	World.add_nation_rep("ashbanner", 8)
	report["opening"] = "chapter-0 cleared, ashland rep %d" % int(GameState.reputation.get("ashland", 0))
	var start_abs := _abs()
	var end_abs := start_abs + years * 12
	var guard := 0
	var last_year := -1
	while _abs() < end_abs and guard < years * 14:
		guard += 1
		var advanced := false
		if Calendar.month == 1 and Calendar.year != last_year:
			last_year = Calendar.year
			_january(report, Calendar.year)
			_sample(report)
		if Calendar.month == 5:
			_try_marry()
		if Calendar.month == 6:
			advanced = _try_child()
		_buy_food()
		if not advanced:
			Calendar.advance(1)
	if _abs() < end_abs:
		report["stuck"] = "calendar stopped at %s" % Calendar.label()
	report["end_year"] = Calendar.year
	report["end_month"] = Calendar.month
	report["silver_end"] = GameState.silver
	report["food_end"] = GameState.food
	report["roster_end"] = GameState.roster().size()
	report["family_alive"] = _alive_count()
	var leader := GameState.get_leader()
	var births := 0
	for c in GameState.characters.values():
		if c.parent_ids.size() > 0:
			births += 1
	report["births"] = births
	report["leader_alive"] = leader != null and leader.alive and not leader.retired
	report["leader_name"] = leader.name if leader else ""
	var wage := 0
	for c2 in GameState.roster():
		wage += int(c2.salary)
	report["wage_month"] = wage
	report["generations"] = Lineage.generation_depth(leader) + 1 if leader else 0
	report["title_end"] = CKCourt.current_title(leader) if leader else ""
	report["traits"] = _trait_counts()
	report["malnourished_rate"] = _malnourished_rate()
	var houses := _royal_snapshot()
	report["royal_houses_alive"] = int(houses["alive"])
	report["royal_lines_with_sign"] = int(houses["signed"])
	report["crises"] = int(houses["crises"])
	report["recalls"] = int(houses["recalls"])
	report["positive_traits"] = _positive_trait_kinds()
	return report

static func _abs() -> int:
	return Calendar.year * 12 + Calendar.month

static func _january(report: Dictionary, year: int) -> void:
	_enlist_ready()
	_abdicate(report)
	_promote(report)
	_castle_quests(report)
	_skirmish(report, year)
	_commission(report, year)
	if year % 4 == 0:
		_smith(report)
	if year % 5 == 0 and GameState.silver > 80:
		GameState.verify_bloodlines_at_shrine()
	if year == 40 or (year > 40 and report.get("lamp", {}).is_empty()):
		_lamp(report)
	_upgrade_castle()
	if GameState.roster().size() < 5 and year % 6 == 0:
		_recruit(report)

static func _sample(report: Dictionary) -> void:
	var leader := GameState.get_leader()
	var silver := GameState.silver
	report["silver_min"] = mini(int(report["silver_min"]), silver)
	report["silver_max"] = maxi(int(report["silver_max"]), silver)
	if silver <= 0:
		report["years_broke"] = int(report["years_broke"]) + 1
	if GameState.food <= 0:
		report["years_starved"] = int(report["years_starved"]) + 1
	if int(report["samples"].size()) < 12 or Calendar.year % 10 == 0:
		report["samples"].append({
			"year": Calendar.year, "silver": silver, "food": GameState.food,
			"roster": GameState.roster().size(), "alive": _alive_count(),
			"title": CKCourt.current_title(leader) if leader else "",
			"gen": Lineage.generation_depth(leader) + 1 if leader else 0,
			"who": leader.name if leader else "",
			"age": leader.age if leader else 0,
		})

static func _note_line(report: Dictionary, reason: String, prev: CKCharacter, handed: Dictionary) -> void:
	var heir: CKCharacter = GameState.get_leader()
	report["line"].append({
		"y": Calendar.year, "why": reason,
		"from": prev.name if prev else "", "from_age": prev.age if prev else 0,
		"to": str(handed.get("heir", "")), "to_age": heir.age if heir else 0,
		"gen": Lineage.generation_depth(heir) + 1 if heir else 0,
	})

static func _buy_food() -> void:
	var mouths := 0
	for c in GameState.characters.values():
		if c.alive and (c.in_roster or c.is_child):
			mouths += 1
	var need := mouths * 4
	if GameState.food >= need or GameState.silver < 8:
		return
	var qty := mini(need - GameState.food, GameState.silver / maxi(1, int(GameState.market_buy_prices().get("food", 2))))
	if qty > 0:
		GameState.market_buy("food", qty)

static func _try_marry() -> void:
	var leader := GameState.get_leader()
	if leader == null or not leader.alive or leader.retired or leader.spouse_id != "" or leader.age < Calendar.ADULT_AGE:
		return
	if int(GameState.reputation.get("ashland", 0)) < 10:
		GameState.add_rep("ashland", 10)
	GameState.refresh_marriage_candidates()
	var cand: CKCharacter = null
	for c in GameState.marriage_candidates:
		if Lineage.can_propose(leader, c).get("ok", false):
			cand = c
			break
	if cand == null:
		cand = CharacterFactory.make_marriage_candidate(GameState.rng, "knight")
		cand.rank = "knight"
		if not Lineage.can_propose(leader, cand).get("ok", false):
			return
	var rites: Array = []
	var cost := 40
	for r in CKCourt.required_rites(leader, cand):
		rites.append(str(r.get("id", "")))
		cost += int(r.get("cost", 0))
	if GameState.silver < cost + 20:
		return
	Lineage.marry(leader, cand, 40, rites)

static func _try_child() -> bool:
	var leader := GameState.get_leader()
	if leader == null or leader.spouse_id == "":
		return false
	var spouse: CKCharacter = GameState.characters.get(leader.spouse_id)
	if spouse == null or not spouse.alive:
		return false
	var mother: CKCharacter = spouse if spouse.gender == "f" else (leader if leader.gender == "f" else spouse)
	if mother.pregnant_months >= 0:
		return false
	var kids := 0
	for c in GameState.characters.values():
		if leader.id in c.parent_ids and c.alive:
			kids += 1
	if kids >= 3 or Calendar.year % 4 != 0:
		return false
	mother.pregnant_months = 1
	return false

static func _enlist_ready() -> void:
	if GameState.roster().size() >= 6:
		return
	var leader := GameState.get_leader()
	for c in GameState.characters.values():
		if GameState.roster().size() >= 6:
			break
		if not c.alive or c.in_roster or c.retired or c.age < Calendar.ADULT_AGE:
			continue
		if leader != null and not (leader.id in c.parent_ids) and c.parent_ids.is_empty():
			continue
		Lineage.enlist_adult(c)

static func _abdicate(report: Dictionary) -> void:
	var leader := GameState.get_leader()
	if leader == null or leader.age < 38:
		return
	var heir := Lineage.pick_heir(leader, true)
	if heir == null or heir.age < 18:
		return
	var handed: Dictionary = Lineage.transfer_banner("abdicate")
	if bool(handed.get("ok", false)):
		report["successions"] = int(report["successions"]) + 1
		_note_line(report, "abdicate", leader, handed)
	elif report["line"].size() < 24 and Calendar.year % 10 == 0:
		var why := "no heir" if heir == null else "heir %s age %d" % [heir.name, heir.age]
		report["line"].append({"y": Calendar.year, "why": why, "leader": leader.name, "age": leader.age})

static func _promote(report: Dictionary) -> void:
	var leader := GameState.get_leader()
	if leader == null:
		return
	var step: Dictionary = CKCourt.promote(leader)
	if bool(step.get("ok", false)):
		report["promotions"] = int(report["promotions"]) + 1
		CKBloodline.sync_signature_skills(leader)

static func _castle_quests(report: Dictionary) -> void:
	for qid in CASTLE_QUESTS:
		if bool(GameState.quest_done.get(qid, false)):
			continue
		var q := {}
		for item in GameState.quests:
			if str(item.get("id", "")) == qid:
				q = item
				break
		if q.is_empty():
			continue
		if bool(q.get("battle", false)):
			GameState.silver += int(q.get("silver", 0))
			GameState.add_rep("ashland", int(q.get("rep", 0)))
			for c in GameState.roster():
				c.exp += 8 * int(q.get("stars", 1))
				GameState.settle_exp(c)
			GameState.apply_quest_first_clear(qid)
			report["chapters"] = int(report["chapters"]) + 1
		else:
			var before := GameState.silver
			GameState.accept_quest(qid)
			report["commission_gold"] = int(report["commission_gold"]) + maxi(0, GameState.silver - before)
			report["chapters"] = int(report["chapters"]) + 1
		return

static func _skirmish(report: Dictionary, year: int) -> void:
	var themes: Array = UnitModel.enemy_themes().get("themes", {}).keys()
	themes.sort()
	if themes.is_empty() or GameState.roster().is_empty():
		return
	var theme := str(themes[(year - 1) % themes.size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("skirmish|%d|%d" % [year, int(report.get("seed", 1))])
	var foes: Array = []
	for tmpl in ["%s_thug" % theme, "%s_boss" % theme]:
		var foe := CharacterFactory.make_enemy(tmpl, rng)
		foe.faction = "enemy"
		GameState.grant_battle_enemy_skills(foe, tmpl.ends_with("boss"), 2, "", tmpl)
		GameState.reset_battle_skills([foe])
		foes.append(foe)
	var party: Array = []
	for c in GameState.roster():
		CKBloodline.sync_signature_skills(c)
		party.append(c)
		if party.size() >= 3:
			break
	GameState.reset_battle_skills(party)
	var rounds := 0
	while rounds < 6 and _any_hp(foes) and _any_hp(party):
		rounds += 1
		for atk in party:
			if atk.hp <= 0:
				continue
			var def := _softest(foes)
			if def == null:
				break
			_strike(atk, def, theme, report, true)
		for atk2 in foes:
			if atk2.hp <= 0:
				continue
			var def2 := _softest(party)
			if def2 == null:
				break
			_strike(atk2, def2, theme, report, false)
	var win := not _any_hp(foes) and _any_hp(party)
	var pay := 28 if win else 10
	GameState.silver += pay
	World.add_nation_rep("ashbanner", 1)
	for c in party:
		if c.hp > 0:
			c.exp += 14 if win else 6
			GameState.settle_exp(c)
			c.hp = c.max_hp
	report["chapters"] = int(report["chapters"]) + 1

static func _any_hp(group: Array) -> bool:
	for c in group:
		if c.hp > 0:
			return true
	return false

static func _softest(group: Array) -> CKCharacter:
	var best: CKCharacter = null
	for c in group:
		if c.hp <= 0:
			continue
		if best == null or c.hp < best.hp:
			best = c
	return best

static func _strike(atk: CKCharacter, def: CKCharacter, theme: String, report: Dictionary, player_side: bool) -> void:
	var sit := {
		"hp_frac": float(atk.hp) / float(maxi(1, atk.max_hp)),
		"locked": false, "on_ground": theme in ["snow", "bamboo", "grain", "porcelain"],
		"ally_hurt": def.hp < def.max_hp, "allies_near": 2, "foe_near": true,
		"foe_hp_frac": float(def.hp) / float(maxi(1, def.max_hp)),
		"foe_on_cover": theme in ["snow", "paper", "porcelain"],
	}
	var known: Array = []
	for sid in atk.skills:
		known.append(sid)
	var ready := func(sid: String) -> bool:
		return int(atk.skill_uses.get(sid, 0)) > 0 and int(atk.skill_cd.get(sid, 0)) <= 0
	var beh := CKTacticsAI.behavior_for(theme if not player_side else "bandit")
	var want := "offense"
	if player_side and float(sit["hp_frac"]) > 0.45:
		var prep := CKTacticsAI.best_skill(known, ready, sit, "prep", 1.2)
		if prep != "":
			want = "prep"
	var sid := CKTacticsAI.best_skill(known, ready, sit, want, 0.6 if want == "offense" else 1.2)
	var mul := 1.0
	if sid != "":
		var sk := GameState.get_skill(sid)
		mul = float(sk.get("dmg_mul", 1.0)) if str(sk.get("type", "")) == "offense" else 0.65
		if str(sk.get("blood_sig", "")) != "":
			report["royal_casts"] = int(report["royal_casts"]) + 1
		atk.skill_uses[sid] = maxi(0, int(atk.skill_uses.get(sid, 1)) - 1)
		if str(sk.get("type", "")) != "offense":
			mul = 0.55
	elif not player_side and float(beh.get("aggression", 0.5)) < 0.25:
		return
	var dmg := BattleRules.expected_damage(atk, def, "plain", {}) * mul
	def.hp -= maxi(1, int(round(dmg)))

static func _commission(report: Dictionary, year: int) -> void:
	var prefer := "lantern" if year % 3 == 0 else ("ashbanner" if year % 3 == 1 else "")
	var ids: Array = World.nodes.keys()
	ids.sort()
	var ordered: Array = []
	for id in ids:
		if prefer != "" and World.nation_of(str(id)) == prefer:
			ordered.append(id)
	for id in ids:
		if id not in ordered:
			ordered.append(id)
	for id in ordered:
		if str(World.node(str(id)).get("kind", "")) == "castle":
			continue
		World.pos = str(id)
		var offers: Array = World.board(str(id))
		var pick: Dictionary = {}
		for q in offers:
			if str(q.get("kind", "")) in ["deliver", "scout", "escort"] and World.quest_locked_reason(q) == "":
				pick = q
				break
		if pick.is_empty():
			continue
		var before := GameState.silver
		var acc: Dictionary = World.accept_quest(str(id), str(pick.get("id", "")))
		if not bool(acc.get("ok", false)):
			continue
		var live := World.quest_by_id(str(pick.get("id", "")))
		if live.is_empty():
			continue
		live["state"] = "ready"
		var where := World.turn_in_city(live)
		if where == "":
			World.abandon(str(live.get("id", "")))
			continue
		World.pos = where
		var turned: Dictionary = World.turn_in(str(live.get("id", "")))
		if bool(turned.get("ok", false)):
			report["commissions"] = int(report["commissions"]) + 1
			report["commission_gold"] = int(report["commission_gold"]) + maxi(0, GameState.silver - before)
			return
		World.abandon(str(live.get("id", "")))

static func _smith(report: Dictionary) -> void:
	if GameState.silver < 280:
		return
	var ids: Array = World.nodes.keys()
	ids.sort()
	for id in ids:
		if World.smith_tier(str(id)) <= 0:
			continue
		World.pos = str(id)
		var best := ""
		var best_price := 999999
		for e in World.smith_stock(str(id)):
			if not bool(e.get("available", false)):
				continue
			var iid := str((e.get("item", {}) as Dictionary).get("id", ""))
			var price := World.smith_price(str(id), iid)
			if price < best_price and price <= 140 and GameState.silver - price >= 160:
				best = iid
				best_price = price
		if best != "":
			var bought: Dictionary = World.buy_item(str(id), best)
			if bool(bought.get("ok", false)):
				report["smith_buys"] = int(report["smith_buys"]) + 1
				report["smith_gold"] = int(report["smith_gold"]) + best_price
				return

static func _lamp(report: Dictionary) -> void:
	var leader := GameState.get_leader()
	if leader == null:
		return
	if typeof(leader.blood_meta) == TYPE_DICTIONARY and str(leader.blood_meta.get("lamp_seat", "")) != "":
		return
	var rep := World.nation_rep("lantern")
	var board := CKCourt.lamp_board(leader, rep, Calendar.year)
	var bid := maxi(int(board.get("top", 0)), int(board.get("ask_baron", 0)))
	if GameState.silver < bid + 120:
		report["lamp"] = {"ok": false, "reason": "silver", "bid": bid, "rep": rep}
		return
	var placed: Dictionary = CKCourt.place_bid(leader, bid, rep, Calendar.year)
	report["lamp"] = {"ok": bool(placed.get("ok", false)), "bid": bid, "rep": rep, "msg": str(placed.get("msg", "")), "tier": str(placed.get("tier", ""))}

static func _upgrade_castle() -> void:
	if GameState.silver < 420 or GameState.food < 30:
		return
	for id in ["shrine", "market", "hall"]:
		if GameState.building_level(id) >= 3:
			continue
		var up: Dictionary = GameState.upgrade_building(id)
		if bool(up.get("ok", false)):
			return

static func _recruit(report: Dictionary) -> void:
	GameState.refresh_tavern()
	var best: CKCharacter = null
	for c in GameState.tavern_candidates:
		if c.rank == "knight" and (best == null or c.salary < best.salary):
			best = c
	if best == null and not GameState.tavern_candidates.is_empty():
		best = GameState.tavern_candidates[0]
	if best == null or GameState.silver < 80:
		return
	var hired: Dictionary = GameState.recruit(best)
	if bool(hired.get("ok", false)):
		report["recruits"] = int(report.get("recruits", 0)) + 1

static func _alive_count() -> int:
	var n := 0
	for c in GameState.characters.values():
		if c.alive:
			n += 1
	return n

static func _trait_counts() -> Dictionary:
	var counts := {}
	for c in GameState.characters.values():
		if not c.alive:
			continue
		for tid in c.traits:
			counts[str(tid)] = int(counts.get(str(tid), 0)) + 1
	return counts

static func _malnourished_rate() -> float:
	var n := 0
	var bad := 0
	for c in GameState.characters.values():
		if not c.alive:
			continue
		n += 1
		if "malnourished" in c.traits:
			bad += 1
	if n <= 0:
		return 1.0
	return float(bad) / float(n)

static func _positive_trait_kinds() -> int:
	var seen := {}
	for c in GameState.characters.values():
		if not c.alive:
			continue
		for tid in c.traits:
			var tr: Dictionary = GameState.get_trait(str(tid))
			if str(tr.get("polarity", "")) == "pos":
				seen[str(tid)] = true
	return seen.size()

static func _royal_snapshot() -> Dictionary:
	var nations: Dictionary = World.royal_courts.get("nations", {}) if typeof(World.royal_courts) == TYPE_DICTIONARY else {}
	var alive := 0
	var signed := 0
	var crises := 0
	var recalls := 0
	for nid in nations.keys():
		var house: Dictionary = nations[nid]
		var living := false
		var shows := false
		for m in house.get("members", []):
			if not bool(m.get("alive", false)):
				continue
			living = true
			var ch := CKCourt._as_char(m)
			if not CKBloodline.royal_nations(ch).is_empty():
				shows = true
		if living:
			alive += 1
		if shows:
			signed += 1
		crises += int(house.get("crisis_total", 0))
		recalls += int(house.get("recall_total", 0))
	return {"alive": alive, "signed": signed, "crises": crises, "recalls": recalls}
