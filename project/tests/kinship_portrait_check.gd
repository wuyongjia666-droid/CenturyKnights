extends Node
## Three generations of CKGenome.cross: heirs share portrait descriptors; recessives skip and return.

func _ready() -> void:
	var err := _run()
	if err != "":
		print("FAIL kinship: ", err)
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _face(v: float) -> Dictionary:
	var face := {}
	for k in CKGenome.FACE_KEYS:
		face[k] = v
	return face

func _person(id: String, gender: String, loci: Dictionary, face_v: float) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = id
	c.gender = gender
	c.age = 26
	c.blood_mix = {"ember_noble": 0.55, "frost_crown": 0.25, "river_ward": 0.20}
	c.faction = "player"
	c.job_id = "light_inf"
	c.genome = {"loci": loci.duplicate(true), "face": _face(face_v), "body": {"height": 0.2, "build": 0.1}, "v": 2}
	CKGenome.sync_appearance(c)
	return c

func _child(id: String, father: CKCharacter, mother: CKCharacter, rng: RandomNumberGenerator) -> CKCharacter:
	var c := CKCharacter.new()
	c.id = id
	c.name = id
	c.gender = "f" if rng.randf() < 0.5 else "m"
	c.age = 22
	c.blood_mix = {"ember_noble": 0.5, "frost_crown": 0.25, "river_ward": 0.25}
	c.faction = "player"
	c.job_id = "light_inf"
	c.genome = CKGenome.cross(father.genome, mother.genome, c.blood_mix, rng)
	CKGenome.sync_appearance(c)
	return c

func _loci(side: bool) -> Dictionary:
	if side:
		return {
			"hair": ["ash_brown", "frost_silver"],
			"eyes": ["slate", "rime"],
			"brow": ["straight", "soft"],
			"ears": ["round", "crest"],
			"mark": ["none", "crown_rime"],
		}
	return {
		"hair": ["ink_black", "frost_silver"],
		"eyes": ["amber", "dusk"],
		"brow": ["thick", "straight"],
		"ears": ["round", "crest"],
		"mark": ["none", "ember_sigil"],
	}

func _has(tokens: Array, tok: String) -> bool:
	return tokens.find(tok) >= 0

func _run() -> String:
	var chain_a: Array = CKGenomePortrait.demo_lineage(89)
	var chain_b: Array = CKGenomePortrait.demo_lineage(89)
	if chain_a.size() != 3 or chain_b.size() != 3:
		return "demo lineage length"
	if str(chain_a[2]["child"].id) != str(chain_b[2]["child"].id):
		return "demo lineage not deterministic"
	var acc := 0.0
	var n := 0
	var gen_acc := [0.0, 0.0, 0.0]
	var gen_n := [0, 0, 0]
	var weak := 0
	for s in 36:
		var chain: Array = CKGenomePortrait.demo_lineage(2000 + s)
		if chain.size() != 3:
			return "short chain"
		for row in chain:
			var frac := float(row["report"]["fraction"])
			var gen := int(row["gen"]) - 1
			acc += frac
			n += 1
			gen_acc[gen] += frac
			gen_n[gen] += 1
			if frac < 0.34:
				weak += 1
			var father_h: Array = row["report"]["father_heritable"]
			var child_h: Array = row["report"]["child_heritable"]
			if father_h.is_empty() or child_h.is_empty():
				return "empty heritable tokens"
	var mean := acc / float(n)
	if mean < 0.55:
		return "mean shared fraction %.3f" % mean
	for g in 3:
		var gm: float = float(gen_acc[g]) / float(gen_n[g])
		if gm < 0.45:
			return "gen %d fraction %.3f" % [g + 1, gm]
	if float(weak) / float(n) > 0.12:
		return "too many weak heirs %d/%d" % [weak, n]
	var rng := RandomNumberGenerator.new()
	rng.seed = 8901
	var eligible := 0
	var returned := 0
	var crest_back := 0
	var found_skip := false
	for i in 500:
		var father := _person("sf%d" % i, "m", _loci(false), 0.62)
		var mother := _person("sm%d" % i, "f", _loci(true), 0.58)
		if _has(CKGenomePortrait.descriptors(father)["heritable"], "hair:frost_silver"):
			return "founder should hide frost_silver"
		if _has(CKGenomePortrait.descriptors(mother)["heritable"], "ears:crest"):
			return "founder should hide crest"
		var c1 := _child("s1_%d" % i, father, mother, rng)
		var d1: Dictionary = CKGenomePortrait.descriptors(c1)
		if _has(d1["heritable"], "hair:frost_silver"):
			continue
		eligible += 1
		var spouse := _person("sp%d" % i, "m" if c1.gender == "f" else "f", _loci(false), 0.60)
		var c2 := _child("s2_%d" % i, c1 if c1.gender == "m" else spouse, c1 if c1.gender == "f" else spouse, rng)
		var d2: Dictionary = CKGenomePortrait.descriptors(c2)
		if _has(d2["heritable"], "hair:frost_silver"):
			returned += 1
			if not found_skip:
				var p_tokens: Array = CKGenomePortrait.descriptors(c1)["heritable"]
				var s_tokens: Array = CKGenomePortrait.descriptors(spouse)["heritable"]
				if _has(p_tokens, "hair:frost_silver") or _has(s_tokens, "hair:frost_silver"):
					return "skip parents visibly silver"
				if not _has(d2["heritable"], "hair:frost_silver"):
					return "skip child missing portrait token"
				var c3 := _child("s3_%d" % i, c2 if c2.gender == "m" else spouse, c2 if c2.gender == "f" else spouse, rng)
				if c3.genome.is_empty():
					return "gen3 genome"
				found_skip = true
		if _has(d2["heritable"], "ears:crest"):
			crest_back += 1
	if eligible < 300:
		return "too few non-expressing gen1 %d" % eligible
	var rate := float(returned) / float(eligible)
	if rate < 0.10 or rate > 0.26:
		return "frost_silver skip rate %.3f (%d/%d)" % [rate, returned, eligible]
	if not found_skip:
		return "no 3-gen skip example"
	if float(crest_back) / float(eligible) < 0.05:
		return "crest barely returned"
	print("KINSHIP PASS mean=%.3f silver_skip=%.3f n=%d" % [mean, rate, n])
	return ""
