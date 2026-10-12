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
	for f in [_assault, _chain, _month, _contest, _home, _save]:
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
