extends Node
## v9.3 territory: data, two capture routes, month yield/upkeep, contest/defend/loss,
## home castle never lost, save round trip and old-save migration.

func _ready() -> void:
	await get_tree().process_frame
	var err := _run()
	if err != "":
		print("FAIL territory: ", err)
		get_tree().quit(1)
		return
	print("TERRITORY PASS")
	get_tree().quit(0)

func _run() -> String:
	var err := _data_checks()
	if err != "":
		return err
	GameState.new_game("领地", "灰旗", GameState.crest_color)
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	for f in [_seat_migration, _assault, _chain, _month, _contest, _reclaim, _counter, _home, _save, _stockade]:
		err = f.call()
		if err != "":
			return err
	return ""

func _data_checks() -> String:
	var ids := CKTerritory.site_ids()
	if ids.size() < 32:
		return "sites %d < 32" % ids.size()
	var per := {}
	for id in ids:
		var s := CKTerritory.site(id)
		var a := World.node(str(s.anchor))
		if a.is_empty():
			return "%s anchor missing" % id
		if str(a.kind) in ["castle", "capital"] or CKTerritory.is_home(id):
			return "%s anchored on castle/capital" % id
		if str(a.nation) != str(s.nation):
			return "%s nation mismatch" % id
		var g := str(s.good)
		if g != "":
			var nat: Dictionary = World.nations.get(str(s.nation), {})
			var table: Array = [str(nat.get("mat", ""))]
			for n in World.nodes_in(str(s.nation)):
				table.append_array(World.node(str(n) if typeof(n) == TYPE_STRING else str(n.id)).get("produce", []))
			if not g in table:
				return "%s good %s not in %s resource table" % [id, g, s.nation]
		per[str(s.nation)] = int(per.get(str(s.nation), 0)) + 1
	for nid in World.nations.keys():
		if str(nid) != "landbridge" and int(per.get(str(nid), 0)) < 3:
			return "nation %s has %d sites" % [nid, int(per.get(str(nid), 0))]
	return ""

func _assault() -> String:
	var id := "t_ash_cinderpit"
	var s := CKTerritory.site(id)
	if CKTerritory.assault(id).get("ok", false):
		return "assault allowed away from anchor"
	World.pos = str(s.anchor)
	var r := CKTerritory.assault(id)
	if not r.get("ok", false):
		return "assault refused: %s" % r.get("msg", "")
	if str(World.encounter.get("site", "")) != id or str(World.encounter.kind) != "territory_assault":
		return "assault encounter not tagged"
	World.on_battle_end(true)
	if not CKTerritory.owned(id) or int(CKTerritory.state(id).unrest) != 2:
		return "assault win did not capture with unrest"
	# losing an assault keeps it neutral
	var id2 := "t_ash_millrun"
	World.pos = str(CKTerritory.site(id2).anchor)
	CKTerritory.assault(id2)
	World.on_battle_end(false)
	if CKTerritory.owned(id2):
		return "assault loss captured"
	return ""

func _chain() -> String:
	var id := "t_ash_millrun"
	var anchor := str(CKTerritory.site(id).anchor)
	World.pos = anchor
	var r := CKTerritory.post_chain(id)
	if not r.get("ok", false):
		return "chain refused: %s" % r.get("msg", "")
	var q: Dictionary = r.quest
	if not World.accept_quest(anchor, str(q.id)).get("ok", false):
		return "chain step 1 not acceptable"
	World._add_good(str(q.good), int(q.qty))
	World._check_gather_ready()
	var t := World.turn_in(str(q.id))
	if not t.get("ok", false):
		return "chain step 1 turn in: %s" % t.get("msg", "")
	var q2 := {}
	for o in World.board(anchor):
		if str(o.get("territory", "")) == id:
			q2 = o
	if q2.is_empty() or str(q2.kind) != "hunt":
		return "chain step 2 not posted"
	World.accept_quest(anchor, str(q2.id))
	World.quest_by_id(str(q2.id)).state = "ready"
	t = World.turn_in(str(q2.id))
	if not t.get("ok", false) or not CKTerritory.owned(id):
		return "chain did not capture: %s" % t.get("msg", "")
	if int(CKTerritory.state(id).unrest) != 0:
		return "chain capture has unrest"
	return ""

func _month() -> String:
	var id := "t_ash_millrun"  # village, grain -> castle store
	var food0 := GameState.food
	var silver0 := GameState.silver
	var line := CKTerritory.apply_month(0.99)
	if line == "":
		return "month produced nothing"
	if GameState.food <= food0:
		return "grain yield not stored"
	var s := CKTerritory.site(id)
	var expect: int = int(s.yield_silver) - CKTerritory.upkeep(id)
	var pit := CKTerritory.site("t_ash_cinderpit")
	expect += int(pit.yield_silver) / 2 - CKTerritory.upkeep("t_ash_cinderpit")
	if GameState.silver - silver0 != expect:
		return "month silver %d != %d" % [GameState.silver - silver0, expect]
	# unpaid upkeep drops garrison
	GameState.silver = 0
	var g0 := int(CKTerritory.state(id).garrison)
	CKTerritory.site(id)["yield_silver"] = 0
	CKTerritory.apply_month(0.99)
	CKTerritory.site(id)["yield_silver"] = int(s.get("yield_silver", 10)) if int(s.yield_silver) > 0 else 10
	if g0 > 0 and int(CKTerritory.state(id).garrison) >= g0:
		return "unpaid upkeep kept garrison"
	GameState.silver = 500
	if not CKTerritory.reinforce(id).get("ok", false):
		return "reinforce failed"
	return ""

func _contest() -> String:
	var id := "t_ash_millrun"
	CKTerritory.start_threat(id)
	if CKTerritory.state(id).threat.is_empty():
		return "no threat"
	var anchor := str(CKTerritory.site(id).anchor)
	World.pos = "hq"
	var arr := World._arrive_leg(anchor)
	if arr.get("encounter", {}).is_empty() or str(World.encounter.kind) != "territory_defend":
		return "arrival did not open defend battle"
	World.on_battle_end(true)
	if not CKTerritory.owned(id) or not CKTerritory.state(id).threat.is_empty():
		return "defend win did not clear threat"
	# defend loss -> lost
	CKTerritory.start_threat(id)
	CKTerritory.defend(id)
	World.on_battle_end(false)
	if CKTerritory.owned(id):
		return "defend loss kept site"
	# unanswered threat: garrison 0, roll high -> lost to rival
	World.pos = str(CKTerritory.site(id).anchor)
	CKTerritory.capture(id, "chain")
	var st := CKTerritory.state(id)
	st.garrison = 0
	st.threat = {"by": "rival:salt_crow", "name": "盐鸦队", "day": 0, "months": 1}
	World.territory.sites[id] = st
	CKTerritory.apply_month(0.99)
	if CKTerritory.owner(id) != "rival:salt_crow":
		return "unanswered threat did not hand site to rival (%s)" % CKTerritory.owner(id)
	if CKTerritory.assault_danger(id) <= int(CKTerritory.site(id).danger) + 1:
		return "rival site not harder"
	# unanswered with strong garrison and low roll holds
	CKTerritory.capture(id, "chain")
	st = CKTerritory.state(id)
	st.garrison = 3
	st.threat = {"by": "", "name": "匪", "day": 0, "months": 1}
	World.territory.sites[id] = st
	CKTerritory.apply_month(0.5)
	if not CKTerritory.owned(id) or int(CKTerritory.state(id).garrison) != 2:
		return "garrison self-defence failed"
	return ""


func _reclaim() -> String:
	# Improve-plan #1: lose() posts a retake commission and a report card in news.
	var id := "t_ash_millrun"
	World.pos = str(CKTerritory.site(id).anchor)
	CKTerritory.capture(id, "chain")
	var st := CKTerritory.state(id)
	st.garrison = 2
	World.territory.sites[id] = st
	var r := CKTerritory.lose(id, "rival:salt_crow")
	if not r.get("ok", false):
		return "lose failed"
	if CKTerritory.owned(id):
		return "still owned after lose"
	var news: Array = CKTerritory.take_news()
	if news.is_empty() or str(news[0].get("report", "")) == "":
		return "no contest report on loss"
	var anchor := str(CKTerritory.site(id).anchor)
	var offer := {}
	for q in World.board(anchor):
		if bool(q.get("territory_reclaim", false)) and str(q.get("territory", "")) == id:
			offer = q
			break
	if offer.is_empty():
		return "reclaim not posted on %s board" % anchor
	# Accept and turn in as a ready hunt → site returns
	if not World.accept_quest(anchor, str(offer.id)).get("ok", false):
		return "reclaim not acceptable"
	var q := World.quest_by_id(str(offer.id))
	q.state = "ready"
	var t := World.turn_in(str(offer.id))
	if not bool(t.get("ok", false)):
		return "reclaim turn_in: %s" % t.get("msg", "")
	if not CKTerritory.owned(id):
		return "reclaim did not recapture"
	if int(CKTerritory.state(id).unrest) != 1:
		return "reclaim unrest %d != 1" % int(CKTerritory.state(id).unrest)
	# Second loss does not stack a duplicate reclaim while one sits on the board
	CKTerritory.lose(id, "")
	CKTerritory.capture(id, "chain")
	CKTerritory.lose(id, "")
	var n := 0
	for q2 in World.board(anchor):
		if bool(q2.get("territory_reclaim", false)) and str(q2.get("territory", "")) == id:
			n += 1
	for q2 in World.active:
		if bool(q2.get("territory_reclaim", false)) and str(q2.get("territory", "")) == id:
			n += 1
	if n != 1:
		return "duplicate reclaim offers: %d" % n
	return ""


func _counter() -> String:
	# Improve-plan #1: bribe delays a month; scout reveals hold %; intercept opens defend.
	var id := "t_ash_millrun"
	World.pos = str(CKTerritory.site(id).anchor)
	CKTerritory.capture(id, "chain")
	var st := CKTerritory.state(id)
	st.garrison = 2
	World.territory.sites[id] = st
	CKTerritory.start_threat(id)
	if CKTerritory.state(id).threat.is_empty():
		return "no threat for counter"
	GameState.silver = 500
	var sc := CKTerritory.scout_threat(id)
	if not sc.get("ok", false):
		return "scout failed: %s" % sc.get("msg", "")
	if not bool(CKTerritory.state(id).threat.get("scouted", false)):
		return "scout flag missing"
	if int(sc.get("intel", {}).get("hold_pct", -1)) < 0:
		return "scout intel missing hold_pct"
	# Advance threat to resolve-next month, then bribe resets months.
	st = CKTerritory.state(id)
	st.threat["months"] = 1
	World.territory.sites[id] = st
	var br := CKTerritory.bribe_threat(id)
	if not br.get("ok", false):
		return "bribe failed: %s" % br.get("msg", "")
	if int(CKTerritory.state(id).threat.get("months", -1)) != 0:
		return "bribe did not reset months"
	if CKTerritory.bribe_threat(id).get("ok", false):
		return "second bribe should fail"
	World.encounter = {}
	var ic := CKTerritory.intercept(id)
	if not ic.get("ok", false):
		return "intercept failed: %s" % ic.get("msg", "")
	if str(World.encounter.get("kind", "")) != "territory_defend":
		return "intercept did not open defend"
	World.on_battle_end(true)
	if not CKTerritory.state(id).threat.is_empty():
		return "intercept win left threat"
	return ""

func _home() -> String:
	var home := str(World.data.get("home", "hq"))
	if not CKTerritory.site(home).is_empty():
		return "home is a site"
	if CKTerritory.lose(home, "").get("ok", false) or CKTerritory.capture(home, "assault").get("ok", false):
		return "home can change hands"
	for i in 24:
		CKTerritory.apply_month(0.0)
	if World.pos == "" or not World.nodes.has(home):
		return "home vanished"
	return ""

func _save() -> String:
	var before := CKTerritory.to_save()
	var blob := World.to_save()
	World.territory = {}
	World.from_save(blob)
	if JSON.stringify(CKTerritory.to_save().sites) != JSON.stringify(before.sites):
		return "round trip mismatch"
	blob.erase("territory")
	World.from_save(blob)
	if not CKTerritory.owned_ids().is_empty():
		return "old save not migrated to neutral"
	var junk := CKTerritory.from_save({"sites": {"hq": {"owner": "company"}, "nope": {}, "t_ash_beacon": {"owner": "company", "garrison": 99}}})
	if junk.sites.has("hq") or junk.sites.has("nope") or int(junk.sites.t_ash_beacon.garrison) != 3:
		return "migration did not sanitise"
	return ""

## Old saves with holdings.second_seat load as an owned site near the same settlement,
## with stockade + contract floor, and never net less than the seat did (+6 silver, +6 food).
func _seat_migration() -> String:
	var data := GameState.build_save_data()
	var hold: Dictionary = data.get("holdings", {}).duplicate(true)
	hold["second_seat"] = {"owned": true, "city": "reed_ford", "reason": "chain", "garrison_home": 2,
		"garrison_away": 4, "yield_silver": 18, "yield_food": 6, "upkeep": 12}
	data["holdings"] = hold
	var w: Dictionary = data.get("world_v87", {}).duplicate(true)
	w.erase("territory")
	w["second_hold_offer"] = "chain_ash"
	data["world_v87"] = w
	if not GameState.apply_save_data(data):
		return "old save did not load"
	World.events_enabled = false
	World.rivals_enabled = false
	if GameState.holdings.has("second_seat"):
		return "second_seat survived migration"
	var ids := CKTerritory.owned_ids()
	if ids.size() != 1 or str(CKTerritory.site(ids[0]).anchor) != "reed_ford":
		return "seat not moved next to reed_ford: %s" % str(ids)
	var st := CKTerritory.state(ids[0])
	if not bool(st.stockade) or not bool(st.contract) or int(st.garrison) != 4:
		return "migrated site missing stockade/contract/garrison: %s" % str(st)
	if CKTerritory.garrison_max(ids[0]) != 4:
		return "stockade did not raise garrison cap"
	var s0 := GameState.silver
	var f0 := GameState.food
	CKTerritory.apply_month(0.99)
	var cache_gain := 0
	for sid in CKTerritory.owned_ids():
		if bool(CKTerritory.state(sid).stockade):
			cache_gain += CKTerritory.cache_food(sid)
	if GameState.silver - s0 < 6 or cache_gain < 6:
		return "migrated seat lost value: silver %+d cache %d (wagon food %+d)" % [
			GameState.silver - s0, cache_gain, GameState.food - f0]
	var blob := World.to_save()
	World.from_save(blob)
	if not bool(CKTerritory.state(ids[0]).contract):
		return "contract lost on round trip"
	# reset for the rest of the suite
	GameState.new_game("领地", "灰旗", GameState.crest_color)
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 40
	if not CKTerritory.owned_ids().is_empty():
		return "new game kept territory"
	return ""

func _stockade() -> String:
	var id := "t_ash_beacon"
	CKTerritory.capture(id, "chain")
	GameState.silver = 0
	if CKTerritory.build_stockade(id).get("ok", false):
		return "stockade built without silver"
	CKTerritory.grant_stockade_credit("chain_ash")
	if CKTerritory.stockade_cost() != 0:
		return "chain credit not applied"
	if not CKTerritory.build_stockade(id).get("ok", false):
		return "free stockade failed"
	if CKTerritory.build_stockade(id).get("ok", false):
		return "stockade built twice"
	var f0 := GameState.food
	CKTerritory.state(id)  # sanity
	var st := CKTerritory.state(id)
	st.threat = {}
	st.cache_food = 0
	World.territory.sites[id] = st
	CKTerritory.apply_month(0.99)
	# 屯营月粮入据点粮仓，不再直灌 GameState.food
	if CKTerritory.cache_food(id) < 6:
		return "stockade food missing (cache %d)" % CKTerritory.cache_food(id)
	if GameState.food != f0:
		return "stockade food leaked to wagon (%+d)" % (GameState.food - f0)
	return ""
