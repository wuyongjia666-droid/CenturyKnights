extends SceneTree
## v8.7 genome laws: recessive skip-generation, partial dominance, polygenic family resemblance, Punnett table.
func _fail(msg: String) -> void:
	print("FAIL genome: ", msg)
	quit(1)

func _init() -> void:
	var err := _run()
	if err != "":
		print("FAIL genome: ", err)
		quit(1)
	else:
		quit(0)

func _run() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 87
	# two carriers of frost_silver / crest show the dominant look...
	var father := {"loci": {"hair": ["ink_black", "frost_silver"], "eyes": ["amber", "dusk"], "brow": ["thick", "soft"], "ears": ["round", "crest"], "mark": ["none", "ember_sigil"]},
		"face": {"width": 0.6, "jaw": 0.5}, "body": {"height": 0.3, "build": 0.4}}
	var mother := {"loci": {"hair": ["wheat", "frost_silver"], "eyes": ["river_blue", "river_blue"], "brow": ["arch", "arch"], "ears": ["round", "crest"], "mark": ["none", "none"]},
		"face": {"width": -0.4, "jaw": -0.2}, "body": {"height": 0.1, "build": -0.2}}
	if CKGenome.express(father, "hair")["id"] != "ink_black" or CKGenome.express(mother, "hair")["id"] != "wheat":
		return ("dominance")
	if CKGenome.express(father, "ears")["carrier"] != "crest":
		return ("carrier flag")
	# ...but 1/4 of their children express both recessives (skip-generation return)
	var pun := CKGenome.punnett(father, mother, "hair")
	var silver := 0.0
	for e in pun:
		if e["id"] == "frost_silver":
			silver = float(e["prob"])
	if absf(silver - 0.25) > 0.001:
		return ("punnett frost_silver %.3f" % silver)
	var n := 4000
	var hits := 0
	var widths := 0.0
	for i in n:
		var c := CKGenome.cross(father, mother, {"ember_noble": 0.35, "frost_crown": 0.15, "river_ward": 0.5}, rng)
		if CKGenome.express(c, "hair")["id"] == "frost_silver":
			hits += 1
		widths += float(c["face"]["width"])
	var r := float(hits) / float(n)
	if r < 0.21 or r > 0.29:
		return ("simulated silver rate %.3f" % r)
	# polygenic: children cluster around the midparent (0.1), not the population
	var mw := widths / float(n)
	if absf(mw - 0.1) > 0.08:
		return ("midparent width %.3f" % mw)
	# partial dominance: heterozygous ember_sigil shows faintly
	var e2 := CKGenome.express(father, "mark")
	if e2["id"] != "ember_sigil" or float(e2["strength"]) >= 1.0:
		return ("partial ember_sigil")
	print("GENOME PASS silver=%.3f midparent_width=%.3f" % [r, mw])
	return ""
