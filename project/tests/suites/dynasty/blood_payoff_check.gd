extends Node
## DYN-01: tactical traits are a read of the existing genome.
## 10,000 heterozygous tr_ash_spoke crosses must land within 3 points of the forecast.
## Three generations of directed tr_ash_wire mating must beat birth-order mating
## on expected child damage (10 + 6 × P(range_high)) at least 60% of the time.

const SAMPLES := 10000
const TRIALS := 160
const LITTER := 12
const FORBID := ["精灵", "尖耳", "金瞳", "金发", "蓝胎记", "青胎记", "冠冕"]

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_catalog(fails)
	var freq := _frequency(fails)
	var breed := _breeding(fails)
	_tiers(fails)
	_atk_untouched(fails)
	if fails.is_empty():
		print("BLOOD PAYOFF PASS freq=%.4f forecast=%.4f breed=%.3f" % [freq.x, freq.y, breed])
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL blood payoff: ", f)
	get_tree().quit(1)

func _catalog(fails: Array) -> void:
	var rows: Array = CKBloodPayoff.rows()
	if rows.size() < 20:
		fails.append("expected >= 20 tactics, got %d" % rows.size())
	var nations := {}
	for t in rows:
		var locus := str(t.get("locus", ""))
		var nid := str(t.get("nation", ""))
		var ld := CKBloodline.locus_def(locus)
		if ld.is_empty():
			fails.append("missing locus %s" % locus)
		elif str(ld.get("nation", "")) != nid:
			fails.append("%s nation %s != %s" % [locus, ld.get("nation", ""), nid])
		nations[nid] = int(nations.get(nid, 0)) + 1
		var blob := "%s %s" % [t.get("zh", ""), t.get("effect", "")]
		for w in FORBID:
			if blob.find(w) >= 0:
				fails.append("%s hits %s" % [locus, w])
	if nations.size() != 10:
		fails.append("tactics must cover 10 nations, got %d" % nations.size())
	for nid in nations.keys():
		if int(nations[nid]) < 2:
			fails.append("%s has %d tactics" % [nid, int(nations[nid])])

func _person(sex: String, locus: String, alleles: Array, mix: Dictionary = {"common_ash": 1.0}) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = "%s_%s" % [locus, sex]
	c.name = "试"
	c.gender = sex
	c.age = 30
	c.blood_mix = mix.duplicate()
	c.genome = {"loci": {"mark": ["none", "none"]}, "sig": {locus: alleles.duplicate(), "pen": {}}}
	return c

func _frequency(fails: Array) -> Vector2:
	var fa := _person("m", "tr_ash_spoke", ["ash_spoke", "none"])
	var mo := _person("f", "tr_ash_spoke", ["ash_spoke", "none"])
	var forecast := CKBloodPayoff.expression_prob(fa, mo, "tr_ash_spoke")
	if absf(forecast - 0.25) > 0.001:
		fails.append("spoke forecast %.4f, expected 0.25" % forecast)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9101
	var shown := 0
	for i in SAMPLES:
		var sex := "m" if i % 2 == 0 else "f"
		var sig: Dictionary = CKBloodline.cross_sig(fa.genome, mo.genome, {"common_ash": 1.0}, sex, rng)
		var g := {"loci": {"mark": ["none", "none"]}, "sig": sig}
		var e := CKBloodline.express_trait(g, "tr_ash_spoke", {"sex": sex, "age": 18, "rank": 0, "honors": []})
		if str(e.get("tier", "")) in ["royal", "noble"]:
			shown += 1
	var rate := float(shown) / float(SAMPLES)
	if absf(rate - forecast) > 0.03:
		fails.append("spoke rate %.4f vs forecast %.4f" % [rate, forecast])
	return Vector2(rate, forecast)

func _power(c: CKCharacter) -> float:
	return 10.0 + c.tactical_amount("range_high") * 6.0

func _wire_copies(c: CKCharacter) -> int:
	return int(CKBloodline._dip(c.genome, "tr_ash_wire").count("ash_wire"))

func _child(fa: CKCharacter, mo: CKCharacter, rng: RandomNumberGenerator, n: int) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = "k%d" % n
	c.gender = "m" if rng.randf() < 0.5 else "f"
	c.age = 18
	c.blood_mix = {"common_ash": 1.0}
	c.genome = {
		"loci": {"mark": ["none", "none"]},
		"sig": CKBloodline.cross_sig(fa.genome, mo.genome, c.blood_mix, c.gender, rng),
	}
	return c

func _litter(team: Array, rng: RandomNumberGenerator) -> Array:
	var kids: Array = []
	for i in LITTER:
		var fa: CKCharacter = team[i % team.size()]
		var mo: CKCharacter = team[(i * 2 + 1) % team.size()]
		if fa.gender == mo.gender:
			mo = team[(i + 1) % team.size()]
		kids.append(_child(fa, mo, rng, i))
	return kids

func _keep_directed(kids: Array) -> Array:
	kids.sort_custom(func(a, b):
		var pa := _power(a)
		var pb := _power(b)
		if not is_equal_approx(pa, pb):
			return pa > pb
		return _wire_copies(a) > _wire_copies(b))
	return kids.slice(0, 4)

## Expected damage of a random pairing inside the squad. A child's power is 10 + 6 when range_high shows.
func _expected(team: Array) -> float:
	var s := 0.0
	var n := 0
	for i in team.size():
		for j in team.size():
			if i == j:
				continue
			var p := CKBloodPayoff.expression_prob(team[i], team[j], "tr_ash_wire")
			s += 10.0 + 6.0 * p
			n += 1
	return s / float(maxi(n, 1))

func _breeding(fails: Array) -> float:
	var wins := 0
	for trial in TRIALS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77000 + trial
		var directed: Array = []
		var randoms: Array = []
		for i in 4:
			var sex := "m" if i % 2 == 0 else "f"
			directed.append(_person(sex, "tr_ash_wire", ["ash_wire", "none"]))
			randoms.append(_person(sex, "tr_ash_wire", ["ash_wire", "none"]))
		for _gen in 3:
			var dk := _litter(directed, rng)
			var rk := _litter(randoms, rng)
			directed = _keep_directed(dk)
			randoms = rk.slice(0, 4)
		if _expected(directed) > _expected(randoms) + 0.001:
			wins += 1
	var rate := float(wins) / float(TRIALS)
	if rate < 0.60:
		fails.append("directed expected-damage win rate %.3f < 0.60" % rate)
	return rate

func _with_crown(nid: String, sex: String, mix: Dictionary, tier: String) -> CKCharacter:
	var c := _person(sex, "marker", ["none", "none"], mix)
	c.genome = {"loci": {"mark": ["none", "none"]}, "sig": {"pen": {}}}
	CKBloodline.force_tier(c.genome, nid, tier, sex)
	return c

func _tiers(fails: Array) -> void:
	var full := _with_crown("frostcrown", "f", {"frost_crown": 1.0}, "royal")
	if full.royal_skill_tier("frostcrown") != 3 or not is_equal_approx(full.royal_skill_scale("frostcrown"), 1.35):
		fails.append("homozygote purity 1 should be full crown, got %d / %.2f" % [full.royal_skill_tier("frostcrown"), full.royal_skill_scale("frostcrown")])
	var two_low := _with_crown("frostcrown", "f", {"frost_crown": 0.4, "common_ash": 0.6}, "royal")
	if two_low.royal_skill_tier("frostcrown") != 2:
		fails.append("two copies at purity 0.4 should be tier 2, got %d" % two_low.royal_skill_tier("frostcrown"))
	var one := _with_crown("lantern", "m", {"lt_filament": 0.2, "common_ash": 0.8}, "royal")
	var locus := str(CKBloodline.nation("lantern").get("locus", ""))
	var allele := str(CKBloodline.locus_def(locus).get("royal", ""))
	one.genome["sig"][locus] = [allele, "none"]
	if one.royal_skill_tier("lantern") != 1:
		fails.append("single dominant copy at purity 0.2 should be tier 1, got %d" % one.royal_skill_tier("lantern"))
	var half := _with_crown("lantern", "m", {"lt_filament": 0.6, "common_ash": 0.4}, "royal")
	half.genome["sig"][locus] = [allele, "none"]
	if half.royal_skill_tier("lantern") != 2 or not is_equal_approx(half.royal_skill_scale("lantern"), 1.0):
		fails.append("purity 0.6 single copy should be tier 2")
	var quiet := _person("m", "tr_ash_wire", ["none", "none"])
	if quiet.royal_skill_tier() != 0 or quiet.royal_skill_scale() != 0.0:
		fails.append("no crown should be tier 0")
	var tide := _with_crown("saltmarsh", "m", {"sm_tide": 0.8, "common_ash": 0.2}, "royal")
	if tide.royal_skill_tier("saltmarsh") != 3:
		fails.append("shown X crown at purity 0.8 should count as full, got %d" % tide.royal_skill_tier("saltmarsh"))
	var jade := _with_crown("qinghe", "f", {"qh_jade": 1.0}, "royal")
	var jade_locus := str(CKBloodline.nation("qinghe").get("locus", ""))
	jade.genome["sig"][jade_locus] = float(CKBloodline.locus_def(jade_locus).get("royal_min", 0.72)) + 0.05
	if jade.royal_skill_tier("qinghe") != 2:
		fails.append("value just above royal_min is one copy, got %d" % jade.royal_skill_tier("qinghe"))
	jade.genome["sig"][jade_locus] = float(CKBloodline.locus_def(jade_locus).get("royal_min", 0.72)) + 0.1
	if jade.royal_skill_tier("qinghe") != 3:
		fails.append("value at royal_min+0.1 with pure blood should be tier 3, got %d" % jade.royal_skill_tier("qinghe"))
	var spoke := _person("f", "tr_ash_spoke", ["ash_spoke", "ash_spoke"])
	if not is_equal_approx(spoke.tactical_amount("counter"), 3.0):
		fails.append("homozygous spoke should grant counter 3, got %.2f" % spoke.tactical_amount("counter"))
	var wire := _person("m", "tr_ash_wire", ["ash_wire", "none"])
	if not is_equal_approx(wire.tactical_amount("range_high"), 1.0):
		fails.append("wire heterozygote should grant range_high 1")
	var hidden := _person("m", "tr_ash_spoke", ["ash_spoke", "none"])
	if hidden.tactical_amount("counter") != 0.0:
		fails.append("latent spoke must not grant counter")

func _atk_untouched(fails: Array) -> void:
	var a := _person("m", "tr_ash_wire", ["ash_wire", "none"])
	var b := _person("m", "tr_ash_wire", ["none", "none"])
	a.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	b.stats = a.stats.duplicate()
	a.job_id = "light_inf"
	b.job_id = "light_inf"
	if a.derived_atk() != b.derived_atk():
		fails.append("derived_atk changed with a tactical trait")
