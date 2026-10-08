extends Node
## v8.9 bloodlines: data wiring, the ten blood laws, tavern pools and pricing, edge blood, shrine verification,
## succession crises, kinship, royal skills, and the Plan A portrait clause (+ fixtures).
## Regenerate fixtures: CK_UPDATE_FIXTURES=1 godot --headless --path project --scene res://tests/bloodline_v89_check.tscn

const FIXTURES := "res://tests/fixtures/bloodline_portraits_v89.json"
const N := 4000

var _fails: Array = []
var _notes: Array = []

func _ready() -> void:
	await get_tree().process_frame
	_data()
	_laws()
	_legacy()
	_pools()
	_pricing()
	_social()
	_skills()
	_portraits()
	var fx := _fixtures()
	CKBloodline.people.clear()
	if _fails.is_empty():
		for n in _notes:
			print("NOTE ", n)
		print("BLOODLINE V89 PASS lines=%d nations=%d fixtures=%d" % [CKBloodline.lines().size(), CKBloodline.nation_ids().size(), fx])
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL bloodline: ", f)
		get_tree().quit(1)

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _near(v: float, want: float, tol: float, msg: String) -> void:
	_ok(absf(v - want) <= tol, "%s: %.3f (want %.3f±%.3f)" % [msg, v, want, tol])

func _mk(id: String, sex: String, blood: Dictionary, nid: String = "", tier: String = "royal", age: int = 30, rank: String = "knight") -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = id
	c.gender = sex
	c.age = age
	c.rank = rank
	c.job_id = "light_inf"
	c.faction = "player"
	c.blood_mix = blood.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	c.genome = CKGenome.founder(c.blood_mix, {}, rng, sex)
	if nid != "":
		CKBloodline.force_tier(c.genome, nid, tier, sex)
	CKGenome.sync_appearance(c)
	return c

func _royal(nid: String, sex: String, id: String = "") -> CKCharacter:
	var nat := CKBloodline.nation(nid)
	return _mk(id if id != "" else "r_%s_%s" % [nid, sex], sex, {str(nat.royal): 1.0}, nid, "royal", 30, "count")

func _tier_of_child(nid: String, fa: CKCharacter, mo: CKCharacter, sex: String, rng: RandomNumberGenerator) -> String:
	var blood := {}
	for k in fa.blood_mix.keys():
		blood[k] = float(blood.get(k, 0.0)) + 0.5 * float(fa.blood_mix[k])
	for k in mo.blood_mix.keys():
		blood[k] = float(blood.get(k, 0.0)) + 0.5 * float(mo.blood_mix[k])
	var g := CKGenome.cross(fa.genome, mo.genome, blood, rng, sex)
	return str(CKBloodline.express_nation(g, nid, {"sex": sex, "rank": 0, "honors": []})["tier"])

func _rate(nid: String, fa: CKCharacter, mo: CKCharacter, sex: String, tier: String, seed_i: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var hit := 0
	for i in N:
		var s := sex if sex != "" else ("f" if i % 2 == 0 else "m")
		if _tier_of_child(nid, fa, mo, s, rng) == tier:
			hit += 1
	return float(hit) / float(N)

func _forecast(fa: CKCharacter, mo: CKCharacter, nid: String) -> Dictionary:
	for r in CKBloodline.forecast(fa, mo):
		if str(r.nation) == nid:
			return r
	return {"royal": 0.0, "royal_f": 0.0, "royal_m": 0.0, "noble": 0.0, "carrier": 0.0}

# ── data ──────────────────────────────────────────────
func _data() -> void:
	_ok(CKBloodline.lines().size() == 31, "31 lines (got %d)" % CKBloodline.lines().size())
	_ok(CKBloodline.nation_ids().size() == 10, "10 nations")
	for nid in CKBloodline.nation_ids():
		var nat := CKBloodline.nation(nid)
		_ok(CKBloodline.tier_of(str(nat.royal)) == "royal" and CKBloodline.nation_of_line(str(nat.royal)) == nid, "%s royal line" % nid)
		_ok(CKBloodline.tier_of(str(nat.folk)) == "folk" and CKBloodline.nation_of_line(str(nat.folk)) == nid, "%s folk line" % nid)
		for nb in nat.noble:
			_ok(CKBloodline.tier_of(str(nb)) == "noble" and CKBloodline.nation_of_line(str(nb)) == nid, "%s noble %s" % [nid, nb])
		var sk := str(CKBloodline.line(str(nat.royal)).get("skill_bias", {}).get("royal_skill", ""))
		_ok(str(GameState.get_skill(sk).get("blood_sig", "")) == nid, "%s royal skill %s" % [nid, sk])
	for l in CKBloodline.lines():
		var gb: Dictionary = GameState.get_bloodline(str(l.id))
		_ok(str(gb.get("name", "")) == str(l.name), "GameState.get_bloodline(%s)" % l.id)
		for k in CKCharacter.STAT_KEYS:
			_ok(int(l.stat_min[k]) <= int(l.stat_max[k]) and int(l.stat_max[k]) <= 20, "%s stat %s" % [l.id, k])
	for nid in World.nation_ids():
		for b in World.nations[nid].get("blood", []):
			_ok(CKBloodline.has_line(str(b)), "world %s blood %s exists" % [nid, b])
			_ok(CKBloodline.tier_of(str(b)) != "royal", "world %s open pool has no royal (%s)" % [nid, b])
			if nid != "landbridge":
				_ok(CKBloodline.nation_of_line(str(b)) == nid, "world %s blood %s belongs to it" % [nid, b])
	# legacy tables keep the v8.7 polygenic means (genome_check / kinship numbers depend on them)
	for id in ["common_ash", "river_ward", "ember_noble", "frost_crown"]:
		var t := CKBloodline.genome_table(id)
		var legacy: Dictionary = CKGenome.BLOOD[id]
		_ok(JSON.stringify(t.face) == JSON.stringify(legacy.face) and JSON.stringify(t.body) == JSON.stringify(legacy.body) and str(t.skin) == str(legacy.skin), "legacy %s face/body/skin" % id)

# ── the ten laws ──────────────────────────────────────
func _laws() -> void:
	var folk_f := _mk("law_folk_f", "f", {"common_ash": 1.0})
	var folk_m := _mk("law_folk_m", "m", {"common_ash": 1.0})
	for nid in CKBloodline.nation_ids():
		CKBloodline.force_tier(folk_f.genome, nid, "none", "f")
		CKBloodline.force_tier(folk_m.genome, nid, "none", "m")
	# awakened: carriers stay latent until a deed
	var ash := _mk("law_ash", "m", {"ash_chart": 1.0}, "ashbanner", "latent")
	_ok(CKBloodline.express_nation(ash.genome, "ashbanner", CKBloodline.ctx_of(ash))["tier"] == "latent", "awakened: knight carrier is latent")
	ash.rank = "count"
	_ok(CKBloodline.express_nation(ash.genome, "ashbanner", CKBloodline.ctx_of(ash))["tier"] == "royal", "awakened: count awakens")
	ash.rank = "knight"
	ash.honors.append("banner_oath")
	_ok(CKBloodline.express_nation(ash.genome, "ashbanner", CKBloodline.ctx_of(ash))["tier"] == "royal", "awakened: banner oath awakens")
	_near(_rate("ashbanner", ash, folk_f, "", "latent", 11), 0.5, 0.03, "awakened carrier x none -> 50% latent")
	# dose
	var cres_m := _mk("law_sy_m", "m", {"sy_night": 1.0}, "shuoying", "noble")
	var cres_f := _mk("law_sy_f", "f", {"sy_night": 1.0}, "shuoying", "noble")
	_near(_rate("shuoying", cres_m, cres_f, "", "royal", 12), 0.25, 0.025, "dose crescent x crescent -> 25% full")
	_near(_rate("shuoying", cres_m, cres_f, "", "noble", 13), 0.5, 0.03, "dose crescent x crescent -> 50% crescent")
	_near(float(_forecast(cres_m, cres_f, "shuoying").royal), 0.25, 0.001, "dose forecast")
	# threshold
	var jade_m := _mk("law_qh_m", "m", {"qh_jade": 1.0}, "qinghe", "royal")
	var jade_f := _mk("law_qh_f", "f", {"qh_jade": 1.0}, "qinghe", "royal")
	var delta_f := _mk("law_qh_d", "f", {"qh_delta": 1.0}, "qinghe", "none")
	var in_reg := _rate("qinghe", jade_m, jade_f, "", "royal", 14)
	var out_reg := _rate("qinghe", jade_m, delta_f, "", "royal", 15)
	_ok(in_reg > 0.9 and out_reg < 0.02, "threshold: register marriage keeps the jade lock (%.2f), outbreeding loses it (%.2f)" % [in_reg, out_reg])
	_near(float(_forecast(jade_m, jade_f, "qinghe").royal), in_reg, 0.04, "threshold forecast")
	# dominant
	var fil := _mk("law_lt", "m", {"lt_filament": 1.0})
	fil.genome.sig.sig_lantern = ["filament", "none"]
	_near(_rate("lantern", fil, folk_f, "", "royal", 16), 0.5, 0.03, "dominant het x none -> 50%")
	# recessive
	var car_m := _mk("law_fc_m", "m", {"fc_hall": 1.0}, "frostcrown", "latent")
	var car_f := _mk("law_fc_f", "f", {"fc_hall": 1.0}, "frostcrown", "latent")
	_ok(CKBloodline.express_nation(car_m.genome, "frostcrown", CKBloodline.ctx_of(car_m))["tier"] == "latent", "recessive carrier hidden")
	_near(_rate("frostcrown", car_m, car_f, "", "royal", 17), 0.25, 0.025, "recessive carrier x carrier -> 25%")
	# Y
	var kiln := _royal("emberold", "m")
	_ok(_rate("emberold", kiln, folk_f, "m", "royal", 18) >= 0.985, "Y: every son of a crackled father (loss-only mutation aside)")
	_ok(_rate("emberold", kiln, folk_f, "f", "royal", 19) == 0.0, "Y: no daughter")
	var fk := _forecast(kiln, folk_f, "emberold")
	_ok(absf(float(fk.royal_m) - 1.0) < 0.01 and float(fk.royal_f) < 0.01, "Y forecast by sex")
	# X dominant
	var tide_m := _royal("saltmarsh", "m", "law_sm_king")
	_ok(_rate("saltmarsh", tide_m, folk_f, "f", "royal", 20) >= 0.985, "X: ringed father -> every daughter")
	_ok(_rate("saltmarsh", tide_m, folk_f, "m", "royal", 21) == 0.0, "X: ringed father -> no son")
	var tide_het := _mk("law_sm_het", "f", {"sm_tide": 1.0})
	tide_het.genome.sig.sig_saltmarsh = ["tide_ring", "none"]
	_near(_rate("saltmarsh", folk_m, tide_het, "m", "royal", 22), 0.5, 0.03, "X: het mother -> half the sons")
	_near(_rate("saltmarsh", folk_m, tide_het, "f", "royal", 23), 0.5, 0.03, "X: het mother -> half the daughters")
	var fx := _forecast(tide_m, folk_f, "saltmarsh")
	_ok(absf(float(fx.royal_f) - 1.0) < 0.01 and float(fx.royal_m) < 0.01, "X forecast by sex")
	# penetrance
	var gorge := _royal("irongorge", "m")
	var shown := _rate("irongorge", gorge, folk_f, "", "royal", 24)
	_near(shown, 0.6, 0.03, "penetrance: 60% of carriers show")
	_near(float(_forecast(gorge, folk_f, "irongorge").royal), 0.6, 0.01, "penetrance forecast")
	# complement
	var east := _mk("law_sr_e", "m", {"sr_east_arc": 1.0}, "starriver", "noble")
	var west := _mk("law_sr_w", "f", {"sr_west_arc": 1.0})
	west.genome.sig.sig_starriver = ["si_fu", "si_fu"]
	_ok(_rate("starriver", east, west, "", "royal", 25) >= 0.985, "complement: san_tai x si_fu -> seven stars")
	var d1 := _royal("starriver", "m", "law_sr_d1")
	var d2 := _royal("starriver", "f", "law_sr_d2")
	_near(_rate("starriver", d1, d2, "", "royal", 26), 0.5, 0.03, "complement: dipper x dipper -> 50%")
	# maternal
	var ff_m := _royal("southzephyr", "m", "law_sz_son")
	var ff_f := _royal("southzephyr", "f", "law_sz_mother")
	var dark_f := _mk("law_sz_dark", "f", {"sz_fogwood": 1.0}, "southzephyr", "none")
	_ok(_rate("southzephyr", folk_m, ff_f, "", "royal", 27) > 0.95, "maternal: a firefly mother lights every child")
	_ok(_rate("southzephyr", ff_m, dark_f, "", "royal", 28) == 0.0, "maternal: a firefly son passes nothing")
	_ok(float(_forecast(ff_m, dark_f, "southzephyr").royal) < 0.01, "maternal forecast")
	# loss-only mutation: unmarked parents never produce a sign on a discrete locus
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var gained := 0
	for i in N:
		var g := CKGenome.cross(folk_m.genome, folk_f.genome, {"common_ash": 1.0}, rng, "f" if i % 2 else "m")
		for nid in ["ashbanner", "shuoying", "lantern", "frostcrown", "emberold", "saltmarsh", "irongorge", "starriver"]:
			var e := CKBloodline.express_nation(g, nid, {"sex": "f" if i % 2 else "m", "rank": 3, "honors": []})
			if e["tier"] != "none" and not (nid == "emberold" and e["tier"] == "noble"):
				gained += 1
	_ok(gained == 0, "signs only appear through inheritance (%d gained)" % gained)

func _legacy() -> void:
	var c := CKCharacter.new()
	c.id = "legacy_fc"
	c.name = "霜冕旧档"
	c.gender = "f"
	c.blood_mix = {"frost_crown": 1.0}
	c.genome = {"loci": {"hair": ["frost_silver", "frost_silver"], "eyes": ["rime", "rime"], "brow": ["soft", "soft"], "ears": ["crest", "crest"], "mark": ["crown_rime", "crown_rime"]},
		"face": {"width": -0.5}, "body": {"height": 0.4}, "v": 2}
	var twin: CKCharacter = CKCharacter.from_dict(c.to_dict())
	c.ensure_genome()
	twin.ensure_genome()
	_ok(int(c.genome.get("v", 0)) == 3 and c.genome.has("sig"), "legacy genome upgraded to v3")
	_ok(JSON.stringify(c.genome.sig) == JSON.stringify(twin.genome.sig), "legacy upgrade deterministic")
	_ok(CKBloodline.royal_nations(c).has("frostcrown"), "crown_rime x2 carries over as rime lashes")
	var pos := CKGenomePortrait.positive_prompt(c)
	_ok(not pos.contains("pointed") and not pos.contains("frost-crystal birthmark"), "legacy crest / crown_rime have no trope prose")
	_ok(pos.contains("rime-white eyelashes"), "legacy royal gets the v89 Frostcrown sign")
	var save: CKCharacter = CKCharacter.from_dict(c.to_dict())
	_ok(JSON.stringify(save.genome.sig) == JSON.stringify(c.genome.sig) and save.blood_meta == c.blood_meta, "sig + blood_meta survive save/load")

# ── taverns ───────────────────────────────────────────
func _pools() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for nid in CKBloodline.nation_ids():
		var own := CKBloodline.lines_of(nid)
		var royal := str(CKBloodline.nation(nid).royal)
		var royal_seen := 0
		var stray := 0
		for i in 300:
			var r := CKBloodline.roll_recruit(nid, "capital", rng, {"city_rep": 0, "nation_rep": 0, "slot": 1})
			if str(r.exile) != "":
				continue
			if not (str(r.line) in own):
				stray += 1
			if str(r.line) == royal:
				royal_seen += 1
		_ok(stray == 0, "%s pool draws its own lines (%d strays)" % [nid, stray])
		if nid != "lantern":
			_ok(royal_seen == 0, "%s royal gated at rep 0 (%d)" % [nid, royal_seen])
		var sworn := CKBloodline.roll_recruit(nid, "capital", rng, {"city_rep": 90, "nation_rep": 85, "slot": 0})
		_ok(str(sworn.line) == royal and bool(sworn.get("vouched", false)) and (sworn.pretend as Dictionary).is_empty(), "%s 盟誓 seats the royal line" % nid)
	var lt := 0
	for i in 400:
		if CKBloodline.roll_recruit("lantern", "port", rng, {"slot": 1})["tier"] == "royal":
			lt += 1
	_ok(lt > 0, "lantern ports sell filament-bearers without rep")
	var lb_royal := 0
	var lb_exile := 0
	for i in 400:
		var r2 := CKBloodline.roll_recruit("landbridge", "town", rng, {"city_rep": 90, "nation_rep": 90, "slot": 0})
		if str(r2.exile) != "":
			lb_exile += 1
		elif r2.tier == "royal":
			lb_royal += 1
	_ok(lb_royal == 0 and lb_exile > 80, "landbridge: no throne, many wanderers (%d)" % lb_exile)
	# exiles keep their house sign however thin the blood
	var sons := 0
	var lit := 0
	for i in 600:
		var r3 := CKBloodline.roll_recruit("lantern", "port", rng, {"slot": 1})
		if str(r3.exile) != "firefly_sons":
			continue
		var c := CKCharacter.new()
		c.id = "fs_%d" % i
		c.name = c.id
		CKBloodline.apply_recruit(c, r3, rng)
		sons += 1
		if c.gender == "m" and "southzephyr" in CKBloodline.royal_nations(c):
			lit += 1
	_ok(sons > 0 and float(lit) / float(sons) > 0.9, "萤子 glow in foreign taverns (%d/%d)" % [lit, sons])
	# real city taverns
	var qh: Array = World.city_recruits("qh_capital")
	for c in qh:
		_ok(CKBloodline.nation_of_line(c.primary_bloodline()) == "qinghe" or str(c.blood_meta.get("exile", "")) != "", "qh_capital recruit %s is Qinghe or a wanderer" % c.primary_bloodline())
	var home := CharacterFactory.make_tavern_candidate(rng)
	_ok(not home.genome.is_empty() and home.genome.has("sig"), "castle tavern recruit has a v89 genome")

func _pricing() -> void:
	var fc := _royal("frostcrown", "f", "price_fc")
	_ok(CKBloodline.hire_premium(fc) == 110, "shown Frostcrown royal keeps the 110 premium (%d)" % CKBloodline.hire_premium(fc))
	var fc_c := _mk("price_fc_c", "f", {"frost_crown": 1.0}, "frostcrown", "latent")
	_ok(CKBloodline.hire_premium(fc_c) == 55, "unproven crown sells at half (%d)" % CKBloodline.hire_premium(fc_c))
	var tide_folk := _mk("price_lt", "m", {"lt_tide": 1.0})
	tide_folk.genome.sig.sig_lantern = ["filament", "none"]
	_ok(CKBloodline.hire_premium(tide_folk) == 40, "folk with an overt royal sign costs more (%d)" % CKBloodline.hire_premium(tide_folk))
	var edge := _mk("price_sy_edge", "f", {"sy_night": 0.6, "sy_eclipse": 0.4}, "shuoying", "noble")
	_ok(CKBloodline.hire_premium(edge, "shuoying") < CKBloodline.hire_premium(edge, "lantern"), "弦外 stigma discounts in Shuoying")
	_ok(not CKBloodline.edge_blood(edge).is_empty() and str(CKBloodline.edge_blood(edge)[0].name) == "弦外", "edge blood named 弦外")

# ── edge, verify, succession, kinship, marriage ───────
func _social() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# 熄萤: a firefly son's child has the blood but not the light
	var son := _royal("southzephyr", "m", "soc_ff_son")
	var dark := _mk("soc_dark", "f", {"lt_tide": 1.0}, "southzephyr", "none")
	var kid := _mk("soc_kid", "m", {"sz_firefly": 0.5, "lt_tide": 0.5})
	kid.genome = CKGenome.cross(son.genome, dark.genome, kid.blood_mix, rng, "m")
	kid.parent_ids = [son.id, dark.id]
	var eb := CKBloodline.edge_blood(kid)
	_ok(not eb.is_empty() and str(eb[0].name) == "熄萤", "熄萤 edge blood")
	# verify: pretenders, false fathers, false fireflies
	var fake := CKCharacter.new()
	fake.id = "soc_fake"
	fake.name = "伪澜"
	CKBloodline.apply_recruit(fake, {"blood_mix": {"qh_jade": 1.0}, "tier": "royal", "line": "qh_jade", "pretend": {"claimed": "qh_jade", "true": "qh_delta"}}, rng)
	_ok(CKBloodline.portrait_clause(fake).contains("dye-stained roots"), "pretender portrait carries the forgery tell")
	var v := CKBloodline.verify_and_record(fake)
	_ok(str(v.verdict) == "false" and fake.primary_bloodline() == "qh_delta" and bool(fake.blood_meta.verified), "shrine unmasks a 染缕 pretender")
	var plain := _mk("soc_plain_father", "m", {"eo_ashland": 1.0}, "emberold", "none")
	var crackled := _royal("emberold", "m", "soc_crackled")
	crackled.parent_ids = [plain.id, "soc_nobody"]
	var chars := {plain.id: plain}
	_ok(str(CKBloodline.verify(crackled, chars).contradictions).contains("冒窑"), "Y law exposes a false father")
	var glow_kid := _royal("southzephyr", "f", "soc_glow_kid")
	glow_kid.parent_ids = ["soc_nobody", dark.id]
	_ok(str(CKBloodline.verify(glow_kid, {dark.id: dark}).contradictions).contains("伪萤"), "maternal law exposes a false firefly")
	# succession
	var elder := _mk("succ_elder", "f", {"sy_night": 1.0}, "shuoying", "noble", 40)
	var young := _mk("succ_young", "m", {"sy_eclipse": 1.0}, "shuoying", "royal", 19)
	var sy := CKBloodline.succession([elder, young], "shuoying")
	_ok(str(sy.heir) == "succ_young" and str(sy.crisis) == "younger_full" and str(sy.crisis_name) == "弦朔之乱", "全朔为尊 → 弦朔之乱 %s" % str(sy.crisis))
	var king := _royal("emberold", "m", "succ_kiln_king")
	var daughter := _mk("succ_kiln_daughter", "f", {"eo_kiln": 0.5, "eo_ashland": 0.5})
	daughter.genome = CKGenome.cross(king.genome, dark.genome, daughter.blood_mix, rng, "f")
	daughter.parent_ids = [king.id, dark.id]
	_ok(str(CKBloodline.succession([daughter], "emberold", {king.id: king}).crisis) == "canon", "a kiln daughter alone → 典争")
	_ok(str(CKBloodline.succession([], "emberold").crisis) == "cold", "no sons → 冷窑")
	var q1 := _mk("succ_sm_a", "f", {"sm_tide": 1.0}, "saltmarsh", "royal", 24)
	var q2 := _mk("succ_sm_b", "f", {"sm_tide": 1.0}, "saltmarsh", "royal", 22)
	q1.parent_ids = ["tide_king", "mother_a"]
	q2.parent_ids = ["tide_king", "mother_b"]
	_ok(str(CKBloodline.succession([q1, q2], "saltmarsh").crisis) == "many_daughters", "众女潮")
	var hidden := _mk("succ_ig_hidden", "m", {"ig_forge": 1.0}, "irongorge", "latent")
	hidden.stats = {"str": 20, "vit": 20, "skl": 5, "agi": 5, "per": 5, "wil": 5}
	hidden.blood_meta = {"verified": true}
	var shown := _royal("irongorge", "m", "succ_ig_shown")
	shown.stats = {"str": 8, "vit": 8, "skl": 5, "agi": 5, "per": 5, "wil": 5}
	var ig := CKBloodline.succession([shown, hidden], "irongorge")
	_ok(str(ig.heir) == "succ_ig_hidden" and str(ig.crisis) == "hidden_top", "藏钢之争")
	_ok(str(CKBloodline.succession([elder], "frostcrown").crisis) == "vacant", "候冕之年")
	# kinship + paper patents
	var pa := _mk("kin_pa", "m", {"common_ash": 1.0})
	var ma := _mk("kin_ma", "f", {"common_ash": 1.0})
	var s1 := _mk("kin_s1", "m", {"common_ash": 1.0})
	var s2 := _mk("kin_s2", "f", {"common_ash": 1.0})
	s1.parent_ids = [pa.id, ma.id]
	s2.parent_ids = [pa.id, ma.id]
	var c1 := _mk("kin_c1", "m", {"common_ash": 1.0})
	var c2 := _mk("kin_c2", "f", {"common_ash": 1.0})
	var x1 := _mk("kin_x1", "f", {"common_ash": 1.0})
	var x2 := _mk("kin_x2", "m", {"common_ash": 1.0})
	c1.parent_ids = [s1.id, x1.id]
	c2.parent_ids = [x2.id, s2.id]
	var fam := {pa.id: pa, ma.id: ma, s1.id: s1, s2.id: s2, x1.id: x1, x2.id: x2}
	_ok(CKBloodline.kinship_degree(s1, s2, fam) == 2 and CKBloodline.marriage_barrier(s1, s2, fam) != "", "siblings blocked")
	_ok(CKBloodline.kinship_degree(c1, c2, fam) == 4 and CKBloodline.marriage_barrier(c1, c2, fam) == "", "cousins allowed")
	_ok(CKBloodline.kinship_degree(pa, x1, fam) == 99, "strangers unrelated")
	var patent := _mk("kin_patent", "m", {"lt_tide": 1.0})
	patent.honors.append("paper_patent")
	var hall := _mk("kin_hall", "f", {"fc_hall": 1.0})
	_ok(CKBloodline.marriage_barrier(patent, hall).contains("纸冕"), "霜阙 refuses paper patents")
	# marriage diplomacy
	var lamp := _royal("lantern", "f", "mar_lamp")
	var leader := _mk("mar_leader", "m", {"common_ash": 1.0})
	leader.is_leader = true
	var fxl := CKBloodline.marriage_effects(leader, lamp)
	_ok(int(fxl.dowry) == 120 and int(fxl.rep.get("lantern", 0)) == 12, "灯市 royal dowry + rep %s" % str(fxl))
	var night := _mk("mar_night", "f", {"sy_night": 0.7, "sy_ridge": 0.3})
	var fxs := CKBloodline.marriage_effects(leader, night)
	_ok(int(fxs.rep.get("shuoying", 0)) == 13 and int(fxs.rep.get("ashbanner", 0)) == -2, "朔影 marriage eases the feud %s" % str(fxs))
	# marriage offers lean toward friendly nations and away from hostile ones
	var counts := {}
	for i in 600:
		var mr := CKBloodline.roll_marriage(rng, "baron", {"rep": {"ashbanner": 40}, "stance": {"ashbanner": "home", "shuoying": "hostile"}})
		counts[mr.nation] = int(counts.get(mr.nation, 0)) + 1
	_ok(int(counts.get("ashbanner", 0)) > int(counts.get("shuoying", 0)) * 3, "marriage offers follow diplomacy %s" % str(counts))
	# births
	var notes := CKBloodline.on_birth(daughter, king, dark)
	_ok(str(notes).contains("窑女"), "birth note for a kiln daughter %s" % str(notes))

func _skills() -> void:
	var fc := _royal("frostcrown", "f", "skill_fc")
	GameState.grant_job_skills(fc)
	_ok("bell_hush" in fc.skills, "shown rime lashes grant 冰钟静域")
	var folk := _mk("skill_folk", "m", {"common_ash": 1.0}, "ashbanner", "latent")
	GameState.grant_job_skills(folk)
	_ok(not ("chart_rally" in folk.skills), "a latent chart grants nothing")
	folk.honors.append("banner_oath")
	GameState.grant_job_skills(folk)
	_ok("chart_rally" in folk.skills, "banner oath awakens 燃图号令")
	var sk := GameState.get_skill("chart_rally")
	_ok((sk.get("jobs", []) as Array).is_empty() and not (str(sk.get("tree", "")) in ["melee", "range", "faith", "cavalry"]), "royal skills stay out of the job trees")

func _portraits() -> void:
	var lock: Dictionary = CKGenomePortrait.style_lock()
	_ok(str(lock.get("version", "")).begins_with("v8.9"), "portraits use style-lock v8.9")
	var forbid: Array = lock.get("anti_trope", {}).get("forbid_in_positive", [])
	for nid in CKBloodline.nation_ids():
		var r := _royal(nid, "m" if nid in ["ashbanner", "lantern", "emberold", "irongorge"] else "f", "pp_" + nid)
		var clause := CKBloodline.portrait_clause(r)
		var state := str(CKBloodline.express_nation(r.genome, nid, CKBloodline.ctx_of(r)).state)
		var sp := str(CKBloodline.signature_def(state).get("prompt", ""))
		_ok(sp != "" and clause.contains(sp), "%s clause carries its royal sign" % nid)
		_ok(CKGenomePortrait.positive_prompt(r).ends_with(clause), "%s clause registered through the hook" % nid)
		var bad := _forbidden(clause, forbid)
		_ok(bad == "", "%s clause free of tropes (%s)" % [nid, bad])
	for sid in CKBloodline.data().signatures.keys():
		var bad2 := _forbidden(str(CKBloodline.signature_def(sid).get("prompt", "")), forbid)
		_ok(bad2 == "", "signature %s free of tropes (%s)" % [sid, bad2])
	var lead := CharacterFactory.make_leader("烬行", "灰旗", "#c9a227")
	_ok(str(CKBloodline.express_nation(lead.genome, "ashbanner", CKBloodline.ctx_of(lead)).tier) == "latent", "灰旗 founder carries half a River Chart")
	_ok(CKBloodline.summary_zh(lead, 0) == "冕征：未见", "latent chart invisible in taverns")
	_ok(CKBloodline.summary_zh(lead, 2).contains("未见") and not CKBloodline.summary_zh(lead, 2).contains("河图"), "unverified latent stays hidden")
	lead.blood_meta = {"verified": true}
	_ok(CKBloodline.summary_zh(lead, 0).contains("河图纹·潜"), "verified latent shows as 潜")

func _forbidden(text: String, forbid: Array) -> String:
	var low := text.to_lower()
	for w in forbid:
		var re := RegEx.create_from_string("\\b" + str(w).to_lower())
		if re.search(low) != null:
			return str(w)
	return ""

# ── Plan A fixtures ───────────────────────────────────
func _fixture_people() -> Array:
	var out: Array = []
	for nid in CKBloodline.nation_ids():
		var sex := "m" if nid in ["ashbanner", "lantern", "emberold", "irongorge"] else "f"
		var r := _royal(nid, sex, "fx_royal_" + nid)
		r.job_id = str(CKBloodline.line(str(CKBloodline.nation(nid).royal)).jobs[0])
		out.append(["royal_" + nid, r, "%s王胤：%s" % [CKBloodline.nation(nid).name, CKBloodline.signature_def(str(CKBloodline.express_nation(r.genome, nid, CKBloodline.ctx_of(r)).state)).get("zh", "")]])
	var cres := _mk("fx_noble_sy_night", "f", {"sy_night": 1.0}, "shuoying", "noble", 27, "baron")
	out.append(["noble_shuoying", cres, "夜阙卿：弦朔瞳（隐征）"])
	var east := _mk("fx_noble_sr_east", "m", {"sr_east_arc": 1.0}, "starriver", "noble", 33, "baron")
	out.append(["noble_starriver_east", east, "东虹：三台痣（隐征）"])
	# dual crown: Iron Gorge forge lord x Saltmarsh tide queen -> a daughter showing both signs
	var fa := _royal("irongorge", "m", "fx_parent_gorge")
	var mo := _royal("saltmarsh", "f", "fx_parent_tide")
	CKBloodline.people[fa.id] = fa
	CKBloodline.people[mo.id] = mo
	var dual: CKCharacter = null
	for s in range(1, 80):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var ch := _mk("fx_heir_dual", "f", {"ig_gorge": 0.5, "sm_tide": 0.5}, "", "royal", 19)
		ch.genome = CKGenome.cross(fa.genome, mo.genome, ch.blood_mix, rng, "f")
		ch.parent_ids = [fa.id, mo.id]
		CKGenome.sync_appearance(ch)
		if CKBloodline.royal_nations(ch).size() >= 2:
			dual = ch
			break
	if dual != null:
		out.append(["heir_dual_crown", dual, "双冕：峡眉（父）＋潮痕发（母）"])
	# 灰旗 heir: carrier father x Qinghe delta mother -> a son carrying the latent chart
	var lf := _mk("fx_parent_banner", "m", {"common_ash": 0.6, "river_ward": 0.4}, "ashbanner", "latent", 41)
	var lm := _mk("fx_parent_delta", "f", {"qh_delta": 1.0}, "", "royal", 38)
	CKBloodline.people[lf.id] = lf
	CKBloodline.people[lm.id] = lm
	for s2 in range(1, 80):
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 100 + s2
		var ch2 := _mk("fx_heir_banner", "m", {"common_ash": 0.3, "river_ward": 0.2, "qh_delta": 0.5}, "", "royal", 18)
		ch2.genome = CKGenome.cross(lf.genome, lm.genome, ch2.blood_mix, rng2, "m")
		ch2.parent_ids = [lf.id, lm.id]
		CKGenome.sync_appearance(ch2)
		if str(CKBloodline.express_nation(ch2.genome, "ashbanner", CKBloodline.ctx_of(ch2)).tier) == "latent":
			out.append(["heir_banner_latent", ch2, "灰旗之子：携潜图，肖像不显，仅父母特征"])
			break
	# 熄萤: a firefly son's son
	var fs := _royal("southzephyr", "m", "fx_parent_firefly_son")
	var tm := _mk("fx_parent_tide_lamp", "f", {"lt_tide": 1.0}, "southzephyr", "none", 30)
	CKBloodline.people[fs.id] = fs
	CKBloodline.people[tm.id] = tm
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 303
	var dk := _mk("fx_heir_dark_firefly", "m", {"sz_firefly": 0.5, "lt_tide": 0.5}, "", "royal", 18)
	dk.genome = CKGenome.cross(fs.genome, tm.genome, dk.blood_mix, rng3, "m")
	dk.parent_ids = [fs.id, tm.id]
	CKGenome.sync_appearance(dk)
	out.append(["edge_dark_firefly", dk, "熄萤：萤母血 50%，脸上一片黑暗"])
	# pretender, paper patent, exile, legacy
	var rng4 := RandomNumberGenerator.new()
	rng4.seed = 404
	var fake := CKCharacter.new()
	fake.id = "fx_pretender_jade"
	fake.name = fake.id
	fake.gender = "f"
	fake.age = 26
	fake.rank = "baron"
	fake.job_id = "apprentice"
	CKBloodline.apply_recruit(fake, {"blood_mix": {"qh_jade": 1.0}, "tier": "royal", "line": "qh_jade", "pretend": {"claimed": "qh_jade", "true": "qh_delta"}}, rng4)
	out.append(["pretender_dyed_jade", fake, "伪胤：染缕（发根发黑）"])
	var paper := _mk("fx_paper_patent", "m", {"lt_tide": 1.0}, "lantern", "none", 35, "baron")
	paper.honors.append("paper_patent")
	out.append(["paper_patent_lantern", paper, "纸冕：灯籍男爵，无灯丝"])
	var ex := CKCharacter.new()
	ex.id = "fx_exile_firefly_son"
	ex.name = ex.id
	ex.age = 24
	ex.job_id = "hunter"
	var ex_roll := {"line": "sz_firefly", "tier": "royal", "blood_mix": {"sz_firefly": 0.5, "lt_tide": 0.5}, "sex": "m", "exile": "firefly_sons", "force": "sz_firefly"}
	CKBloodline.apply_recruit(ex, ex_roll, rng4)
	out.append(["exile_firefly_son", ex, "流裔·萤子：有萤斑而无徽记"])
	var leg := CKCharacter.new()
	leg.id = "fx_legacy_frost"
	leg.name = leg.id
	leg.gender = "f"
	leg.age = 52
	leg.rank = "count"
	leg.job_id = "priest"
	leg.blood_mix = {"frost_crown": 1.0}
	leg.genome = {"loci": {"hair": ["ink_black", "frost_silver"], "eyes": ["river_blue", "rime"], "brow": ["soft", "soft"], "ears": ["crest", "crest"], "mark": ["crown_rime", "crown_rime"]},
		"face": {"width": -0.5, "nose": -0.3, "eye_size": 0.25}, "body": {"height": 0.45, "build": -0.2}, "v": 2}
	out.append(["legacy_v87_frost_royal", leg, "v8.7 存档：crown_rime×2 → 霜睫；冕耳不再画成尖耳"])
	return out

func _fixtures() -> int:
	var rows: Array = []
	for item in _fixture_people():
		var c: CKCharacter = item[1]
		c.ensure_genome()
		var sigs: Array = []
		var zh: Array = []
		for e in CKBloodline.signatures(c, false):
			sigs.append(str(e.state))
			zh.append(str(e.zh))
		var m: Dictionary = CKGenomePortrait.manifest_entry(c)
		rows.append({"case": str(item[0]), "notes_zh": str(item[2]), "unit_id": str(m.unit_id), "line": c.primary_bloodline(),
			"sex": c.gender, "age": c.age, "signatures": sigs, "signatures_zh": zh, "clause": CKBloodline.portrait_clause(c),
			"seed": int(m.seed), "positive": str(m.positive), "negative": str(m.negative), "out_path": str(m.out_path)})
	_ok(rows.size() >= 18, "fixture cases %d" % rows.size())
	var cases := {}
	for r in rows:
		cases[str(r.case)] = r
	_ok(cases.has("heir_dual_crown") and (cases["heir_dual_crown"].signatures as Array).size() >= 2, "a dual-crown heir fixture exists")
	_ok(cases.has("heir_banner_latent") and str(cases["heir_banner_latent"].clause).contains("father"), "heir clause names the parents")
	_ok(cases.has("exile_firefly_son") and str(cases["exile_firefly_son"].clause).contains("without any house insignia"), "exile wears no insignia")
	_ok(cases.has("paper_patent_lantern") and str(cases["paper_patent_lantern"].clause).contains("patent pin") and (cases["paper_patent_lantern"].signatures as Array).is_empty(), "paper royal: regalia without a sign")
	var path := ProjectSettings.globalize_path(FIXTURES)
	if OS.get_environment("CK_UPDATE_FIXTURES") == "1":
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"version": "v8.9-bloodline-portraits-1", "note": "Plan A examples: CKGenomePortrait.manifest_entry + CKBloodline.portrait_clause. Regenerate with CK_UPDATE_FIXTURES=1.", "rows": rows}, "\t") + "\n")
		f.close()
		_notes.append("fixtures written: " + path)
		return rows.size()
	var raw := FileAccess.get_file_as_string(FIXTURES)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		_ok(false, "fixtures missing: run with CK_UPDATE_FIXTURES=1")
		return 0
	var old := {}
	for r in parsed.get("rows", []):
		old[str(r.case)] = r
	for r in rows:
		var o: Dictionary = old.get(str(r.case), {})
		_ok(not o.is_empty(), "fixture %s missing (CK_UPDATE_FIXTURES=1)" % r.case)
		if o.is_empty():
			continue
		_ok(str(o.clause) == str(r.clause), "fixture %s clause drifted (CK_UPDATE_FIXTURES=1)" % r.case)
		_ok(JSON.stringify(o.signatures) == JSON.stringify(r.signatures), "fixture %s signatures drifted" % r.case)
		if str(o.positive) != str(r.positive) or int(o.seed) != int(r.seed):
			_notes.append("fixture %s base prompt or seed changed upstream; regenerate examples with CK_UPDATE_FIXTURES=1" % r.case)
	return rows.size()
