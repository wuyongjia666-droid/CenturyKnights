extends Node
## DYN-07: two royal lines can fuse, and congenital limits stay a read of existing loci.
## LOCUS_ORDER and the draw are not extended.

const HEAD := ["sig_ashbanner", "sig_shuoying", "jade", "sig_lantern", "sig_frostcrown", "sig_emberold", "sig_saltmarsh", "sig_irongorge", "sig_starriver", "glow"]


func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_order(fails)
	_fusion(fails)
	_limits(fails)
	if fails.is_empty():
		print("FUSION PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL fusion: ", f)
	get_tree().quit(1)


func _order(fails: Array) -> void:
	var order: Array = CKBloodline.LOCUS_ORDER
	for i in HEAD.size():
		if str(order[i]) != HEAD[i]:
			fails.append("LOCUS_ORDER[%d]=%s" % [i, str(order[i])])
			return
	for row in CKBloodFusion.rows():
		if str(row.get("id", "")) in order:
			fails.append("fusion id landed in LOCUS_ORDER")


func _fusion(fails: Array) -> void:
	var both := _crown(true)
	var rows: Array = CKBloodFusion.active(both)
	if rows.is_empty() or str(rows[0].get("zh", "")) != "灯霜对读":
		fails.append("homozygous lamp+frost did not fuse")
	if int(rows[0].get("amount", 0)) != 4:
		fails.append("fusion amount drifted")
	var half := _crown(false)
	if not CKBloodFusion.active(half).is_empty():
		fails.append("single-copy lantern must not fuse")
	var thin := _crown(true)
	thin.blood_mix = {"lt_filament": 0.2, "frost_crown": 0.2, "common_ash": 0.6}
	if not CKBloodFusion.active(thin).is_empty():
		fails.append("purity below 0.35 must not fuse")


func _limits(fails: Array) -> void:
	var plain := _crown(true)
	if CKBloodFusion.is_sterile(plain) or CKBloodFusion.is_frail(plain):
		fails.append("a fused heir without the burden loci is not limited")
	var sterile := _crown(true)
	sterile.genome["sig"]["tr_ash_spoke"] = ["ash_spoke", "ash_spoke"]
	if not CKBloodFusion.is_sterile(sterile):
		fails.append("closed hearth did not read the spoke pair")
	if CKFamilyState.conception_rate(sterile) != 0.0:
		fails.append("sterile conception rate should be 0")
	sterile.age = 22
	if CKFamilyState.begin_pregnancy(GameState, sterile):
		fails.append("sterile wedding conceived")
	var frail := CKCharacter.new()
	frail.age = 20
	frail.blood_mix = {"common_ash": 1.0}
	frail.genome = {"loci": {"mark": ["none", "none"]}, "sig": {
		"tr_eo_stroma": ["eo_stroma", "eo_stroma"],
		"tr_fc_storm": ["fc_storm", "fc_storm"],
	}, "pen": {}}
	# Allele ids are the royal tokens on those loci. Confirm before asserting.
	if not CKBloodFusion.is_frail(frail):
		fails.append("thin marrow did not read the two recessive pairs, alleles %s / %s" % [
			str(CKBloodline.locus_def("tr_eo_stroma").get("royal", "")),
			str(CKBloodline.locus_def("tr_fc_storm").get("royal", "")),
		])
	frail.stats = {"str": 8, "vit": 10, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	frail.apt_min = {"vit": 6}
	frail.apt_max = {"vit": 14}
	CKBloodFusion.apply_birth(frail)
	if int(frail.apt_max.get("vit", 0)) != 12 or int(frail.stats.get("vit", 0)) != 10:
		fails.append("frail vit cap %s stats %s" % [str(frail.apt_max.get("vit", "")), str(frail.stats.get("vit", ""))])
	var untouched := CKCharacter.new()
	untouched.stats = {"vit": 10}
	untouched.apt_max = {"vit": 14}
	untouched.genome = {"loci": {"mark": ["none", "none"]}, "sig": {}, "pen": {}}
	CKBloodFusion.apply_birth(untouched)
	if int(untouched.stats.get("vit", 0)) != 10 or int(untouched.apt_max.get("vit", 0)) != 14:
		fails.append("apply_birth wrote a healthy child")


func _crown(full_lantern: bool) -> CKCharacter:
	var c := CKCharacter.new()
	c.age = 24
	c.gender = "f"
	c.blood_mix = {"lt_filament": 0.5, "frost_crown": 0.5}
	var lamp := ["filament", "filament"] if full_lantern else ["filament", "none"]
	c.genome = {"loci": {"mark": ["none", "none"]}, "sig": {
		"sig_lantern": lamp,
		"sig_frostcrown": ["rime_lash", "rime_lash"],
	}, "pen": {}}
	return c
