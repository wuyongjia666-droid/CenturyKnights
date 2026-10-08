extends Node
## Hundred-year scripted campaign. Structural bands stay in docs/design/balance-v91.md.
## Silver checkpoints are the v9.2 curve in docs/design/balance-v92.md.

func _ready() -> void:
	await get_tree().process_frame
	var theme_err := CKTacticsAI.themes_are_distinct()
	if theme_err != "":
		_fail("themes: " + theme_err)
		return
	if not _skill_policy():
		return
	if not _generation_probe():
		return
	var t0 := Time.get_ticks_msec()
	var report: Dictionary = CKCampaignSim.run(100, 91)
	var sec := (Time.get_ticks_msec() - t0) / 1000.0
	print("CAMPAIGN REPORT ", JSON.stringify(report))
	var err := _invariants(report)
	if err != "":
		_fail(err)
		return
	print("CAMPAIGN CENTURY PASS years=%d gen=%d silver=%d roster=%d houses=%d crises=%d commissions=%d smith=%d royal_casts=%d in %.1fs" % [
		int(report["years"]), int(report["generations"]), int(report["silver_end"]), int(report["roster_end"]),
		int(report["royal_houses_alive"]), int(report["crises"]), int(report["commissions"]), int(report["smith_buys"]),
		int(report["royal_casts"]), sec])
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("FAIL campaign: ", msg)
	get_tree().quit(1)

func _skill_policy() -> bool:
	var rally := CKCharacter.new()
	rally.skills = ["chart_rally"]
	rally.skill_uses = {"chart_rally": 1}
	var ready := func(_sid: String) -> bool: return true
	var sit := {"hp_frac": 0.9, "locked": false, "on_ground": false, "ally_hurt": false, "allies_near": 3, "foe_near": true, "foe_hp_frac": 0.8, "foe_on_cover": false}
	var picked := CKTacticsAI.best_skill(rally.skills, ready, sit, "prep", 0.8)
	if picked != "chart_rally":
		_fail("chart rally not chosen, got %s" % picked)
		return false
	var kiln := CKCharacter.new()
	kiln.skills = ["power_strike", "kiln_reforge"]
	var sit2 := {"hp_frac": 0.9, "locked": false, "on_ground": false, "ally_hurt": false, "allies_near": 1, "foe_near": true, "foe_hp_frac": 0.3, "foe_on_cover": false}
	var off := CKTacticsAI.best_skill(kiln.skills, ready, sit2, "offense", 0.5)
	if off != "kiln_reforge":
		_fail("kiln reforge not preferred on a wounded foe, got %s" % off)
		return false
	var lamp := CKCharacter.new()
	lamp.skills = ["lamp_feint", "guard_stance"]
	var sit3 := {"hp_frac": 0.4, "locked": true, "on_ground": false, "ally_hurt": false, "allies_near": 0, "foe_near": true, "foe_hp_frac": 0.9, "foe_on_cover": false}
	var slip := CKTacticsAI.best_skill(lamp.skills, ready, sit3, "prep", 0.4)
	if slip != "lamp_feint":
		_fail("lamp feint not used to break a lock, got %s" % slip)
		return false
	var drum := CKTacticsAI.behavior_for("drum")
	var ink := CKTacticsAI.behavior_for("ink")
	if float(drum["aggression"]) <= float(ink["aggression"]) or float(ink["skill"]) <= float(drum["skill"]):
		_fail("drum/ink weights collapsed")
		return false
	return true

## The first parent id is often the childless spouse. Depth has to follow the house, not that outsider.
func _generation_probe() -> bool:
	var founder := CKCharacter.new()
	founder.id = "depth_founder"
	var outsider := CKCharacter.new()
	outsider.id = "depth_out"
	var child := CKCharacter.new()
	child.id = "depth_child"
	child.parent_ids = [outsider.id, founder.id]
	var grand := CKCharacter.new()
	grand.id = "depth_grand"
	grand.parent_ids = [outsider.id, child.id]
	GameState.characters[founder.id] = founder
	GameState.characters[outsider.id] = outsider
	GameState.characters[child.id] = child
	GameState.characters[grand.id] = grand
	var depth := Lineage.generation_depth(grand)
	for id in ["depth_founder", "depth_out", "depth_child", "depth_grand"]:
		GameState.characters.erase(id)
	if depth < 2:
		_fail("generation depth followed the outsider spouse (%d)" % depth)
		return false
	return true

func _at(r: Dictionary, year: int) -> int:
	for s in r.get("samples", []):
		if int(s.get("year", -1)) == year:
			return int(s.get("silver", -1))
	return -1

func _band(r: Dictionary, year: int, lo: int, hi: int) -> String:
	var silver := _at(r, year)
	if silver < lo or silver > hi:
		return "year %d silver %d outside %d..%d" % [year, silver, lo, hi]
	return ""

func _silver_curve(r: Dictionary) -> String:
	if int(r.get("tight_years", 0)) < 1:
		return "no tight year in 1..10"
	if int(r.get("pressure_mid", 0)) <= 0:
		return "mid-campaign sinks did not fire"
	if int(r.get("pressure_late", 0)) <= 0:
		return "late sinks did not fire"
	if int(r.get("spring_purse", 0)) != 180:
		return "spring purse %s" % str(r.get("spring_purse", 0))
	var checkpoints := [
		[10, 600, 2000],
		[30, 400, 2000],
		[60, 400, 2500],
		[100, 200, 2000],
	]
	for row in checkpoints:
		var why := _band(r, int(row[0]), int(row[1]), int(row[2]))
		if why != "":
			return why
	var silver := int(r.get("silver_end", 0))
	if silver < 100 or silver > 2000:
		return "end silver %d" % silver
	if int(r.get("silver_max", 0)) > 3500:
		return "silver exploded %s" % str(r.get("silver_max", 0))
	return ""

func _invariants(r: Dictionary) -> String:
	if str(r.get("stuck", "")) != "":
		return str(r["stuck"])
	if int(r.get("end_year", 0)) < 101:
		return "calendar %s" % str(r.get("end_year", 0))
	if not bool(r.get("leader_alive", false)):
		return "no living leader"
	if int(r.get("generations", 0)) < 4:
		return "generations %s" % str(r.get("generations", 0))
	if int(r.get("births", 0)) < 4:
		return "births %s" % str(r.get("births", 0))
	if int(r.get("successions", 0)) < 3:
		return "successions %s" % str(r.get("successions", 0))
	if int(r.get("royal_houses_alive", 0)) < 8:
		return "royal houses alive %s" % str(r.get("royal_houses_alive", 0))
	if int(r.get("royal_lines_with_sign", 0)) < 1:
		return "every royal sign gone"
	if int(r.get("recalls", 0)) > 25:
		return "too many cadet recalls %s" % str(r.get("recalls", 0))
	var crises := int(r.get("crises", 0))
	if crises < 8 or crises > 160:
		return "crises %d outside 8..160" % crises
	var curve := _silver_curve(r)
	if curve != "":
		return curve
	if int(r.get("years_broke", 0)) > 6:
		return "broke years %s" % str(r.get("years_broke", 0))
	if int(r.get("years_starved", 0)) > 20:
		return "starved years %s" % str(r.get("years_starved", 0))
	var food_end := int(r.get("food_end", 0))
	if food_end < 40 or food_end > 800:
		return "food %d outside the granary band" % food_end
	var roster := int(r.get("roster_end", 0))
	if roster < 2 or roster > 16:
		return "roster %d" % roster
	if float(r.get("malnourished_rate", 1.0)) > 0.25:
		return "malnourished %.2f" % float(r.get("malnourished_rate", 1.0))
	if int(r.get("positive_traits", 0)) < 4:
		return "positive traits %s" % str(r.get("positive_traits", 0))
	var alive := maxi(1, int(r.get("family_alive", 1)))
	for tid in (r.get("traits", {}) as Dictionary).keys():
		var share := float(int(r["traits"][tid])) / float(alive)
		if share > 0.92 and str(tid) != "heir_mark":
			return "trait %s dominates %.2f" % [tid, share]
	if int(r.get("promotions", 0)) < 2:
		return "promotions %s" % str(r.get("promotions", 0))
	var title := str(r.get("title_end", "knight"))
	if CKCharacter.RANK_ORDER.find(title) < 2:
		return "title stuck at %s" % title
	if int(r.get("chapters", 0)) < 80:
		return "chapters %s" % str(r.get("chapters", 0))
	if int(r.get("commissions", 0)) < 25:
		return "commissions %s" % str(r.get("commissions", 0))
	if int(r.get("commission_gold", 0)) < 400:
		return "commission gold %s" % str(r.get("commission_gold", 0))
	if int(r.get("smith_buys", 0)) < 3:
		return "smith buys %s" % str(r.get("smith_buys", 0))
	if int(r.get("smith_gold", 0)) <= 0:
		return "smith gold did not flow"
	if int(r.get("royal_casts", 0)) < 1:
		return "royal skills never cast"
	var lamp: Dictionary = r.get("lamp", {})
	if lamp.is_empty():
		return "lamp seat never considered"
	return ""
