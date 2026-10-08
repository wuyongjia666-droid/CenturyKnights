extends Node
## v9.0 court layer: lamp-seat bids, marriage rites, NPC royal houses, the title ladder, retired 3D modules.

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_lamp()
	_rites()
	_titles()
	_modules()
	_ui()
	_courts()
	if _fails.is_empty():
		print("COURT V90 PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL court: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _person(id: String, sex: String, line: String) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = id
	c.gender = sex
	c.age = 28
	c.rank = "knight"
	c.blood_mix = {line: 1.0}
	return c

func _lamp() -> void:
	var folk := _person("lamp_folk", "m", "common_ash")
	var pure := _person("lamp_pure", "f", "lt_filament")
	var low := CKCourt.lamp_board(folk, 40, 4)
	var high := CKCourt.lamp_board(pure, 40, 4)
	var rep := CKCourt.lamp_board(folk, 80, 4)
	_ok(float(high["purity"]) > float(low["purity"]), "lantern royal blood raises purity")
	_ok(int(high["ask_baron"]) < int(low["ask_baron"]), "purer blood lowers the baron ask")
	_ok(int(rep["ask_baron"]) < int(low["ask_baron"]), "higher nation rep lowers the ask")
	_ok(int(rep["cut"]) > int(low["cut"]), "rep cut grows with reputation")
	GameState.silver = 8000
	var shy: Dictionary = CKCourt.place_bid(folk, int(low["top"]) - 1, 40, 4)
	_ok(not bool(shy.get("ok", true)), "a bid under the rival top fails")
	var closed: Dictionary = CKCourt.place_bid(folk, 9000, 10, 4)
	_ok(not bool(closed.get("ok", true)), "lamp seat stays shut below friendly rep")
	var win_amt := maxi(int(low["top"]), int(low["ask_baron"]))
	var win: Dictionary = CKCourt.place_bid(folk, win_amt, 40, 4)
	_ok(bool(win.get("ok", false)), "winning bid: %s" % str(win.get("msg", "")))
	_ok("paper_patent" in folk.honors, "winning bid grants the paper patent")
	folk.ensure_genome()
	var shown: Dictionary = CKBloodline.express_nation(folk.genome, "lantern", CKBloodline.ctx_of(folk))
	_ok(str(shown.get("tier", "")) != "royal", "paper patent does not paint a lantern crown")

func _rites() -> void:
	var ash := _person("rite_ash", "m", "common_ash")
	var qh := _person("rite_qh", "f", "qh_jade")
	var ids: Array = []
	for r in CKCourt.required_rites(ash, qh):
		ids.append(str(r.get("id", "")))
	_ok(ids.has("register"), "qinghe marriage requires 入牒礼")
	_ok(CKCourt.explain_zh(ash, qh).find("入牒礼") >= 0, "vow copy names 入牒礼")
	_ok(CKCourt.rite_block(ash, qh, []) != "", "missing 入牒礼 blocks the vow")
	_ok(CKCourt.rite_block(ash, qh, ["register"]) == "", "accepted 入牒礼 opens the vow")
	CKCourt.apply_rites(ash, qh, ["register"])
	var registered := _person("child_reg", "f", "common_ash")
	registered.parent_ids = [ash.id, qh.id]
	CKCourt.stamp_child(registered, ash, qh)
	_ok(str(registered.blood_meta.get("registered", "")) == "qinghe", "入牒礼 writes the child into the jade register")

	var tide := _person("rite_tide", "f", "sm_tide")
	var fisher := _person("rite_fisher", "m", "common_ash")
	CKCourt.apply_rites(fisher, tide, ["matrilocal"])
	var son := _person("child_son", "m", "sm_tide")
	son.parent_ids = [fisher.id, tide.id]
	var notes: Array = CKCourt.stamp_child(son, fisher, tide)
	_ok(str(son.blood_meta.get("succession_bar", "")) == "saltmarsh", "从母居 bars a son from the tide seat")
	_ok(not CKCourt.can_inherit(son, "saltmarsh"), "barred son cannot inherit saltmarsh")
	_ok(str(notes).find("不承潮座") >= 0, "从母居 explains the son's consequence")
	var daughter := _person("child_daughter", "f", "sm_tide")
	daughter.parent_ids = [fisher.id, tide.id]
	CKCourt.stamp_child(daughter, fisher, tide)
	_ok(CKCourt.can_inherit(daughter, "saltmarsh"), "a daughter under 从母居 can still inherit")

	var grove := _person("rite_grove", "f", "sz_firefly")
	var asked: Array = []
	for r2 in CKCourt.required_rites(ash, grove):
		asked.append(str(r2.get("id", "")))
	_ok(asked.has("firefly"), "a firefly royal requires 萤约")
	CKCourt.apply_rites(ash, grove, ["firefly"])
	var girl := _person("child_grove", "f", "sz_firefly")
	girl.parent_ids = [ash.id, grove.id]
	girl.in_roster = true
	CKCourt.stamp_child(girl, ash, grove)
	_ok(bool(girl.blood_meta.get("return_grove", false)), "萤约 sends the first daughter back to the grove")
	_ok(not girl.in_roster, "the returned daughter leaves the company roll")
	_ok(not CKCourt.can_inherit(girl, "player"), "she is barred from the player's seat")

	var frost := _person("rite_frost", "f", "frost_crown")
	frost.ensure_genome()
	CKBloodline.force_tier(frost.genome, "frostcrown", "clear", "f")
	var plain := _person("rite_plain", "m", "common_ash")
	plain.ensure_genome()
	_ok(CKCourt.rite_block(plain, frost, ["frost"]) != "", "携霜契 cannot be sealed without a carrier")
	CKBloodline.force_tier(frost.genome, "frostcrown", "royal", "f")
	_ok(CKCourt.rite_block(plain, frost, ["frost"]) == "", "a shown frost carrier can seal 携霜契")
	CKCourt.apply_rites(plain, frost, ["frost"])
	var ice := _person("child_ice", "m", "frost_crown")
	ice.parent_ids = [plain.id, frost.id]
	CKCourt.stamp_child(ice, plain, frost)
	_ok(bool(ice.blood_meta.get("frost_heir", false)), "携霜契 marks the child as a frost heir")
	_ok("frost_bond" in frost.honors, "sealing the rite grants frost_bond")

func _titles() -> void:
	var c := _person("title_ash", "m", "ash_chart")
	c.age = 30
	CKBloodline.seed_house_carrier(c)
	var latent: Dictionary = CKBloodline.express_nation(c.genome, "ashbanner", CKBloodline.ctx_of(c))
	_ok(str(latent.get("tier", "")) == "latent", "a chart carrier below count stays latent")
	var step1: Dictionary = CKCourt.promote(c, {"merit": 4, "fiefs": 0, "married": false, "rep": 8})
	_ok(bool(step1.get("ok", false)) and str(step1.get("title", "")) == "baron", "knight promotes to baron")
	var blocked: Dictionary = CKCourt.promote(c, {"merit": 10, "fiefs": 0, "married": true, "rep": 20})
	_ok(not bool(blocked.get("ok", true)) and str(blocked.get("msg", "")).find("封地") >= 0, "viscount requires a fief")
	var step2: Dictionary = CKCourt.promote(c, {"merit": 10, "fiefs": 1, "married": true, "rep": 20})
	_ok(str(step2.get("title", "")) == "viscount" and c.rank == "viscount", "viscount is a real rank")
	var still: Dictionary = CKBloodline.express_nation(c.genome, "ashbanner", CKBloodline.ctx_of(c))
	_ok(str(still.get("tier", "")) == "latent", "viscount does not wake the chart")
	var step3: Dictionary = CKCourt.promote(c, {"merit": 18, "fiefs": 1, "married": true, "rep": 40})
	_ok(str(step3.get("title", "")) == "count" and c.rank == "count", "the ladder reaches count")
	var awake: Dictionary = CKBloodline.express_nation(c.genome, "ashbanner", CKBloodline.ctx_of(c))
	_ok(str(awake.get("tier", "")) == "royal", "reaching count wakes the ash chart")
	var sworn := _person("title_oath", "f", "ash_chart")
	sworn.honors = ["banner_oath"]
	CKBloodline.seed_house_carrier(sworn)
	var oath: Dictionary = CKBloodline.express_nation(sworn.genome, "ashbanner", CKBloodline.ctx_of(sworn))
	_ok(str(oath.get("tier", "")) == "royal" and sworn.rank == "knight", "banner oath still wakes a knight")

func _modules() -> void:
	var c := _person("mod_ash", "m", "ash_chart")
	c.age = 30
	c.rank = "count"
	c.ensure_genome()
	CKBloodline.force_tier(c.genome, "ashbanner", "royal", "m")
	CKBloodline.stamp_traits(c.genome, "ashbanner", "full", "m", false)
	c.genome["loci"]["ears"] = ["crest", "crest"]
	c.genome["loci"]["mark"] = ["crown_rime", "crown_rime"]
	var plan: Dictionary = UnitModel.module_plan(c)
	var ids: Array = []
	for m in plan.get("modules", []):
		ids.append(str(m.get("id", "")))
	_ok(not ids.has("ears_crest"), "no unit wears the crest-ear module")
	for lt in plan.get("lights", []):
		_ok(str(lt.get("id", "")) != "crown_rime", "frost-crown mark does not glow")
	_ok(ids.has("regalia_ash_cloak"), "ash regalia replaces the retired head modules")
	_ok(not (plan.get("palette", {}) as Dictionary).is_empty(), "the cloak carries its palette")
	c.genome["loci"]["mark"] = ["ember_sigil", "ember_sigil"]
	var kiln: Dictionary = UnitModel.module_plan(c)
	var glow := false
	for lt2 in kiln.get("lights", []):
		if str(lt2.get("id", "")) == "ember_sigil":
			glow = true
	_ok(glow, "the kiln ember sigil still lights")

func _ui() -> void:
	var host := Control.new()
	add_child(host)
	var board := CKCourt.lamp_board(_person("ui_folk", "m", "common_ash"), 40, 2)
	CKCourt.build_lamp_ui(host, board, func(_amount: int) -> void: pass)
	_ok(host.find_child("LampBidBaron", true, false) != null, "lamp panel has the baron bid")
	_ok(host.find_child("LampBidCount", true, false) != null, "lamp panel has the count bid")
	var who := _person("ui_knight", "m", "common_ash")
	CKCourt.build_promote_ui(host, who, {"merit": 0, "fiefs": 0, "married": false, "rep": 0}, func() -> void: pass)
	var btn := host.find_child("PromoteTitle", true, false) as Button
	_ok(btn != null, "promote panel has the title button")
	_ok(btn != null and btn.disabled, "the button stays shut when the ladder is short")
	host.queue_free()

func _courts() -> void:
	_ok(CKCourt.recruit_bias("ashbanner") == 0.0, "an empty court does not bias recruits")
	var found: Dictionary = {}
	var crisis_nid := ""
	for seed_i in [7, 3, 11, 19, 2]:
		var st: Dictionary = CKCourt.simulate(40, seed_i)
		var kinds := {}
		var nid_hit := ""
		for nid in (st.get("nations", {}) as Dictionary).keys():
			var house: Dictionary = st["nations"][nid]
			if str(house.get("crisis_name", "")) != "" and nid_hit == "":
				nid_hit = str(nid)
			for ev in house.get("log", []):
				kinds[str(ev.get("kind", ""))] = true
		if kinds.has("birth") and kinds.has("death") and nid_hit != "" and not (st.get("rumors", []) as Array).is_empty():
			found = st
			crisis_nid = nid_hit
			break
	_ok(not found.is_empty(), "forty years produce a birth, a death, a crisis and a rumor")
	if found.is_empty():
		return
	World.royal_courts = found
	_ok(CKCourt.recruit_bias(crisis_nid) > 0.0, "a succession crisis fattens that nation's royal pool")
	_ok(CKCourt.latest_rumor() != "", "the rumor is readable for the tavern")
	var tiers := {}
	for nid2 in CKBloodline.nation_ids():
		tiers[nid2] = World.rep_tier_index(World.nation_rep(nid2))
	CKCourt.tick_live(41)
	for nid3 in tiers.keys():
		_ok(World.rep_tier_index(World.nation_rep(str(nid3))) >= int(tiers[nid3]), "%s diplomacy did not fall a tier" % nid3)
	_ok(not World.travel_log.is_empty() or not World.tips.is_empty(), "the year tick surfaces on the atlas log")
	GameState.new_game("烬行", "灰旗", "#c9a227")
	while Calendar.year < 2:
		Calendar.advance(1)
	_ok(typeof(World.royal_courts) == TYPE_DICTIONARY and not World.royal_courts.is_empty(), "January of year 2 ticks the living courts")
