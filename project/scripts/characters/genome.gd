class_name CKGenome
extends RefCounted
## v8.7 genome: diploid Mendelian loci (dominance ranks -> recessive / skip-generation traits),
## polygenic face/body (family resemblance), bloodline-weighted founders. Phenotype feeds BOTH the 2D paper-doll
## (portrait_doll.gd) and the 3D modular rig (unit_model.gd). See docs/art/character-system-v87.md.

## locus -> alleles in dominance order (index 0 = most dominant)
const LOCI := {
	"hair": ["ink_black", "ash_brown", "ember_red", "wheat", "frost_silver"],
	"eyes": ["dusk", "slate", "pine", "river_blue", "amber", "rime"],
	"brow": ["thick", "straight", "arch", "soft"],
	"ears": ["round", "crest"],
	"mark": ["none", "ember_sigil", "crown_rime"],
}
## incompletely dominant alleles: heterozygotes show them faintly
const PARTIAL := {"ember_sigil": 0.45}
const FACE_KEYS := ["width", "jaw", "cheek", "nose", "eye_tilt", "eye_size", "brow_height"]
const BODY_KEYS := ["height", "build"]
## bloodline -> allele weights for founders + polygenic means + skin
const BLOOD := {
	"common_ash": {"hair": {"ash_brown": 4.0, "ink_black": 3.0, "wheat": 1.0}, "eyes": {"slate": 4.0, "pine": 2.0, "amber": 1.0},
		"brow": {"thick": 2.0, "straight": 3.0}, "ears": {"round": 1.0}, "mark": {"none": 1.0},
		"face": {"width": 0.45, "jaw": 0.4, "cheek": -0.1, "nose": 0.2}, "body": {"height": -0.1, "build": 0.4}, "skin": "#C99A7E"},
	"river_ward": {"hair": {"ink_black": 2.0, "wheat": 3.0, "ash_brown": 1.0, "frost_silver": 0.4}, "eyes": {"river_blue": 4.0, "pine": 2.0, "slate": 1.0},
		"brow": {"arch": 3.0, "straight": 1.0}, "ears": {"round": 6.0, "crest": 0.6}, "mark": {"none": 1.0},
		"face": {"width": -0.35, "eye_tilt": 0.35, "eye_size": -0.1}, "body": {"height": 0.2, "build": -0.3}, "skin": "#E2C1AC"},
	"ember_noble": {"hair": {"ember_red": 3.0, "ink_black": 3.0, "ash_brown": 1.0}, "eyes": {"amber": 4.0, "dusk": 2.0},
		"brow": {"straight": 3.0, "thick": 2.0}, "ears": {"round": 1.0}, "mark": {"none": 4.0, "ember_sigil": 1.5},
		"face": {"cheek": 0.5, "brow_height": -0.3, "jaw": 0.2}, "body": {"height": 0.1, "build": 0.2}, "skin": "#C69C78"},
	"frost_crown": {"hair": {"frost_silver": 4.0, "ink_black": 2.0, "wheat": 1.0}, "eyes": {"rime": 3.0, "river_blue": 2.0, "dusk": 1.0},
		"brow": {"soft": 3.0, "arch": 2.0}, "ears": {"crest": 3.0, "round": 2.0}, "mark": {"crown_rime": 2.0, "none": 2.0},
		"face": {"width": -0.5, "nose": -0.3, "eye_size": 0.25}, "body": {"height": 0.45, "build": -0.2}, "skin": "#F1DCD0"},
}
const HAIR_HEX := {"ink_black": "#1B1D24", "ash_brown": "#5C4A40", "ember_red": "#8E3A34", "wheat": "#C9B184", "frost_silver": "#D8E2EC"}
const EYE_HEX := {"dusk": "#6B4C7A", "slate": "#5A6570", "pine": "#3D6B4F", "river_blue": "#3A6EA5", "amber": "#B8862B", "rime": "#BFEFFF"}

static func _pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights.keys():
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights.keys():
		r -= float(weights[k])
		if r <= 0.0:
			return str(k)
	return str(weights.keys()[0])

## v8.9: res://data/bloodlines_v89.json is canonical for all 31 lines; BLOOD above is the offline fallback.
static func _blood(bl: String) -> Dictionary:
	var t := CKBloodline.genome_table(bl)
	if not t.is_empty():
		return t
	return BLOOD.get(bl, BLOOD["common_ash"])

static func _blend_weights(blood_mix: Dictionary, locus: String) -> Dictionary:
	var out := {}
	for bl in blood_mix.keys():
		var t: Dictionary = _blood(str(bl))
		var w: Dictionary = t.get(locus, {})
		for a in w.keys():
			out[a] = float(out.get(a, 0.0)) + float(w[a]) * float(blood_mix[bl])
	if out.is_empty():
		out[LOCI[locus][0]] = 1.0
	return out

static func _mean(blood_mix: Dictionary, group: String, key: String) -> float:
	var s := 0.0
	for bl in blood_mix.keys():
		var t: Dictionary = _blood(str(bl))
		s += float(t.get(group, {}).get(key, 0.0)) * float(blood_mix[bl])
	return s

static func _gauss(rng: RandomNumberGenerator) -> float:
	return rng.randfn(0.0, 1.0)

## founder (recruit / marriage candidate / NPC): alleles rolled from bloodline tables; if a legacy phenotype is
## given, the expressed allele is forced onto one chromosome so the visible look is preserved.
## v8.9: also rolls the nation signature loci (CKBloodline); sex decides X/Y-linked loci.
static func founder(blood_mix: Dictionary, appearance: Dictionary, rng: RandomNumberGenerator, sex: String = "") -> Dictionary:
	var g := {"loci": {}, "face": {}, "body": {}, "v": 3}
	for locus in LOCI.keys():
		var w := _blend_weights(blood_mix, locus)
		var a := _pick(rng, w)
		var b := _pick(rng, w)
		var shown := str(appearance.get(locus, ""))
		if shown != "" and shown in LOCI[locus]:
			a = shown
			if _rank(locus, b) < _rank(locus, a):
				b = a  # keep the legacy look visible
		g["loci"][locus] = [a, b]
	for k in FACE_KEYS:
		g["face"][k] = clampf(_mean(blood_mix, "face", k) + 0.35 * _gauss(rng), -1.0, 1.0)
	for k in BODY_KEYS:
		g["body"][k] = clampf(_mean(blood_mix, "body", k) + 0.35 * _gauss(rng), -1.0, 1.0)
	g["sig"] = CKBloodline.founder_sig(blood_mix, sex, CKBloodline.fork(rng, "founder"))
	return g

static func _rank(locus: String, allele: String) -> int:
	var arr: Array = LOCI[locus]
	var i := arr.find(allele)
	return i if i >= 0 else arr.size()

## Mendelian cross: one random allele from each parent per locus (+1.5% mutation);
## polygenic = midparent + noise, regressed 10% toward the child's bloodline mean.
## v8.9: nation signature loci follow their own laws (CKBloodline.cross_sig); child_sex drives X/Y.
static func cross(father: Dictionary, mother: Dictionary, child_blood: Dictionary, rng: RandomNumberGenerator, child_sex: String = "") -> Dictionary:
	var g := {"loci": {}, "face": {}, "body": {}, "v": 3}
	for locus in LOCI.keys():
		var fa: Array = father.get("loci", {}).get(locus, [LOCI[locus][0], LOCI[locus][0]])
		var mo: Array = mother.get("loci", {}).get(locus, [LOCI[locus][0], LOCI[locus][0]])
		var a := str(fa[rng.randi() % 2])
		var b := str(mo[rng.randi() % 2])
		if rng.randf() < 0.015:
			a = str(LOCI[locus][rng.randi() % LOCI[locus].size()])
		g["loci"][locus] = [a, b]
	for grp in ["face", "body"]:
		var keys: Array = FACE_KEYS if grp == "face" else BODY_KEYS
		for k in keys:
			var mid := 0.5 * (float(father.get(grp, {}).get(k, 0.0)) + float(mother.get(grp, {}).get(k, 0.0)))
			var pull := _mean(child_blood, grp, k) - mid
			g[grp][k] = clampf(mid + 0.10 * pull + 0.15 * _gauss(rng), -1.0, 1.0)
	g["sig"] = CKBloodline.cross_sig(father, mother, child_blood, child_sex, CKBloodline.fork(rng, "cross"))
	return g

## expressed allele + strength (1.0 full; PARTIAL heterozygotes fainter; adjacent-rank hair/eye blend)
static func express(g: Dictionary, locus: String) -> Dictionary:
	var pair: Array = g.get("loci", {}).get(locus, [LOCI[locus][0], LOCI[locus][0]])
	var a := str(pair[0])
	var b := str(pair[1])
	var ra := _rank(locus, a)
	var rb := _rank(locus, b)
	var dom := a if ra <= rb else b
	var rec := b if ra <= rb else a
	var out := {"id": dom, "strength": 1.0, "carrier": "", "blend": "", "blend_t": 0.0}
	if dom != rec:
		out["carrier"] = rec
		if PARTIAL.has(rec) and dom == "none":
			out["id"] = rec
			out["strength"] = float(PARTIAL[rec])
		elif locus in ["hair", "eyes"] and absi(ra - rb) == 1:
			out["blend"] = rec
			out["blend_t"] = 0.2
	return out

## full phenotype for renderers (legacy appearance keys kept for old UI)
static func phenotype(c: Object) -> Dictionary:
	var g: Dictionary = c.genome
	var p := {}
	for locus in LOCI.keys():
		p[locus] = express(g, locus)
	var hair := Color(HAIR_HEX.get(p["hair"]["id"], "#1B1D24"))
	if str(p["hair"]["blend"]) != "":
		hair = hair.lerp(Color(HAIR_HEX.get(p["hair"]["blend"], "#1B1D24")), float(p["hair"]["blend_t"]))
	# ageing: hair greys toward frost silver from 40, strongly after 55
	var grey := clampf((float(c.age) - 40.0) / 25.0, 0.0, 0.85)
	hair = hair.lerp(Color("#D8E2EC"), grey)
	var eye := Color(EYE_HEX.get(p["eyes"]["id"], "#5A6570"))
	if str(p["eyes"]["blend"]) != "":
		eye = eye.lerp(Color(EYE_HEX.get(p["eyes"]["blend"], "#5A6570")), float(p["eyes"]["blend_t"]))
	var skin := Color(0, 0, 0)
	var tw := 0.0
	for bl in c.blood_mix.keys():
		skin += Color(str(_blood(str(bl)).get("skin", "#C99A7E"))) * float(c.blood_mix[bl])
		tw += float(c.blood_mix[bl])
	skin = skin / maxf(tw, 0.001)
	skin.a = 1.0
	var bls: Array = c.blood_mix.keys()
	bls.sort_custom(func(x, y): return float(c.blood_mix[x]) > float(c.blood_mix[y]))
	var second := str(bls[1]) if bls.size() > 1 and float(c.blood_mix[bls[1]]) >= 0.2 else ""
	return {
		"loci": p, "hair_color": hair, "eye_color": eye, "skin_color": skin,
		"face": g.get("face", {}), "body": g.get("body", {}),
		"bloodline": str(bls[0]) if bls.size() > 0 else "common_ash",
		"bloodline2": second, "bloodline2_w": float(c.blood_mix.get(second, 0.0)) if second != "" else 0.0,
		"age_stage": "young" if c.age < 18 else ("elder" if c.age >= 45 else "adult"),
		"scars": c.scars, "honors": c.honors, "gender": c.gender,
	}

## Punnett probabilities for heir expectation UI: locus -> [{id, prob}] of the EXPRESSED trait
static func punnett(father: Dictionary, mother: Dictionary, locus: String) -> Array:
	var fa: Array = father.get("loci", {}).get(locus, [LOCI[locus][0], LOCI[locus][0]])
	var mo: Array = mother.get("loci", {}).get(locus, [LOCI[locus][0], LOCI[locus][0]])
	var counts := {}
	for a in fa:
		for b in mo:
			var e := express({"loci": {locus: [a, b]}}, locus)
			counts[e["id"]] = float(counts.get(e["id"], 0.0)) + 0.25
	var out: Array = []
	for k in counts.keys():
		out.append({"id": k, "prob": counts[k]})
	out.sort_custom(func(x, y): return float(x["prob"]) > float(y["prob"]))
	return out

## sync the legacy appearance dict from the genome (old UI, unit_art hair/eye colours, save compat)
static func sync_appearance(c: Object) -> void:
	for locus in ["hair", "eyes", "brow"]:
		c.appearance[locus] = express(c.genome, locus)["id"]
	c.appearance["ears"] = express(c.genome, "ears")["id"]
	c.appearance["mark"] = express(c.genome, "mark")["id"]
	c.appearance["scar"] = str(c.scars[0]) if c.scars.size() > 0 else "none"
