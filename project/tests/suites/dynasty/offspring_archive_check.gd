extends Node
## DYN-01 remainder: the offspring sheet reads parents from CKFamilyState
## and reports aptitude band, tactical odds, and royal-skill tier odds.

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_pair(fails)
	_archive(fails)
	_expectation(fails)
	if fails.is_empty():
		print("OFFSPRING ARCHIVE PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL offspring archive: ", f)
	get_tree().quit(1)


func _person(sex: String, id: String, locus: String, alleles: Array, mix: Dictionary) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = id
	c.gender = sex
	c.age = 24
	c.blood_mix = mix.duplicate()
	c.genome = {"loci": {"mark": ["none", "none"]}, "sig": {locus: alleles.duplicate(), "pen": {}}}
	return c


func _pair(fails: Array) -> void:
	var mix := {"frost_crown": 1.0}
	var fa := _person("m", "arc_fa", "sig_frostcrown", ["rime_lash", "rime_lash"], mix)
	var mo := _person("f", "arc_mo", "sig_frostcrown", ["rime_lash", "rime_lash"], mix)
	var sheet: Dictionary = CKFamilyState.combat_expectation(fa, mo)
	if str(sheet.get("apt_zh", "")).find("资质区间") < 0:
		fails.append("apt band missing: %s" % str(sheet.get("apt_zh", "")))
	var amin: Dictionary = sheet.get("apt_min", {})
	var amax: Dictionary = sheet.get("apt_max", {})
	if int(amin.get("str", 99)) > int(amax.get("str", 0)):
		fails.append("apt min above max")
	var spoke_f := _person("m", "sp_f", "tr_ash_spoke", ["ash_spoke", "none"], {"common_ash": 1.0})
	var spoke_m := _person("f", "sp_m", "tr_ash_spoke", ["ash_spoke", "none"], {"common_ash": 1.0})
	var tactics: Array = CKFamilyState.combat_expectation(spoke_f, spoke_m).get("tactics", [])
	var spoke_p := -1.0
	for t in tactics:
		if str(t.get("locus", "")) == "tr_ash_spoke":
			spoke_p = float(t.get("p", -1.0))
	if absf(spoke_p - 0.25) > 0.001:
		fails.append("spoke archive prob %.4f, expected 0.25" % spoke_p)
	var tiers: Array = sheet.get("royal_tiers", [])
	var p3 := -1.0
	for row in tiers:
		if str(row.get("nation", "")) == "frostcrown":
			p3 = float(row.get("p3", -1.0))
	if absf(p3 - 1.0) > 0.001:
		fails.append("frostcrown full crown %.4f, expected 1" % p3)


func _archive(fails: Array) -> void:
	var mix := {"frost_crown": 1.0}
	var fa := _person("m", "dad_arc", "sig_frostcrown", ["rime_lash", "rime_lash"], mix)
	var mo := _person("f", "mom_arc", "sig_frostcrown", ["rime_lash", "rime_lash"], mix)
	var child := _person("f", "kid_arc", "sig_frostcrown", ["rime_lash", "rime_lash"], mix)
	child.parent_ids = [fa.id, mo.id]
	child.apt_min = {"str": 7, "vit": 7, "skl": 7, "agi": 7, "per": 7, "wil": 7}
	child.apt_max = {"str": 14, "vit": 14, "skl": 14, "agi": 14, "per": 14, "wil": 14}
	GameState.characters[fa.id] = fa
	GameState.characters[mo.id] = mo
	GameState.characters[child.id] = child
	var arch: Dictionary = CKFamilyState.child_archive(GameState, child)
	if arch.get("parents", []).size() != 2:
		fails.append("archive did not read both parents from the family roster")
	if str(arch.get("apt_zh", "")).find("力7-14") < 0:
		fails.append("child apt band %s" % str(arch.get("apt_zh", "")))
	var forecast: Dictionary = arch.get("forecast", {})
	if forecast.is_empty():
		fails.append("archive forecast empty")
	var royal := str(arch.get("royal_zh", ""))
	if royal.find("满冕") < 0:
		fails.append("royal line %s" % royal)


func _expectation(fails: Array) -> void:
	var fa := _person("m", "ex_fa", "tr_ash_wire", ["ash_wire", "none"], {"common_ash": 1.0})
	var mo := _person("f", "ex_mo", "tr_ash_wire", ["ash_wire", "none"], {"common_ash": 1.0})
	var ex: Dictionary = Lineage.heir_expectation(fa, mo)
	if not ex.has("combat") or not ex.has("royal_tiers") or str(ex.get("apt_zh", "")).find("资质区间") < 0:
		fails.append("heir_expectation missing family archive fields")
