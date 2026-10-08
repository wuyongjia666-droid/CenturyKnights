class_name CKBloodPayoff
extends RefCounted
## Combat readout for v8.9 trait loci and royal-skill tiers.
## Reads a genome CKBloodline already rolled. Does not draw, mutate, or reorder loci.
## Damage formulas stay in battle_rules.gd; this class only exposes amounts and scales.

const SHOWN := ["royal", "noble"]


static func rows() -> Array:
	var raw = CKBloodline.data().get("tactics", [])
	return raw if typeof(raw) == TYPE_ARRAY else []


static func tier_rows() -> Array:
	var raw = CKBloodline.data().get("royal_skill_tiers", [])
	return raw if typeof(raw) == TYPE_ARRAY else []


static func for_nation(nid: String) -> Array:
	var out: Array = []
	for t in rows():
		if str(t.get("nation", "")) == nid:
			out.append(t)
	return out


static func _prepare(c: Object) -> void:
	if c != null and c.has_method("ensure_genome"):
		c.call("ensure_genome")


static func _genome(c: Object) -> Dictionary:
	_prepare(c)
	if c == null:
		return {}
	var g = c.get("genome")
	return g if typeof(g) == TYPE_DICTIONARY else {}


static func _ctx(c: Object) -> Dictionary:
	if c == null:
		return {"sex": "m", "age": 30, "rank": 0, "honors": []}
	return CKBloodline.ctx_of(c)


static func is_shown(c: Object, locus: String) -> bool:
	var e := CKBloodline.express_trait(_genome(c), locus, _ctx(c))
	return str(e.get("tier", "")) in SHOWN


static func tactical_mods(c: Object) -> Dictionary:
	var mods := {}
	for t in rows():
		if not is_shown(c, str(t.get("locus", ""))):
			continue
		var key := str(t.get("key", ""))
		if key == "":
			continue
		mods[key] = float(mods.get(key, 0.0)) + float(t.get("amount", 0))
	return mods


static func tactical_amount(c: Object, key: String) -> float:
	return float(tactical_mods(c).get(key, 0.0))


## Shown-trait probability for one locus. Sexes are weighted 1/2 each.
## Discrete loci use CKBloodline._child_pairs; value loci use the same normal forecast as trait_odds.
static func expression_prob(father: Object, mother: Object, locus: String) -> float:
	_prepare(father)
	_prepare(mother)
	var fg: Dictionary = _genome(father)
	var mg: Dictionary = _genome(mother)
	var ld := CKBloodline.locus_def(locus)
	var kind := str(ld.get("kind", "diploid"))
	var acc := 0.0
	for sex in ["f", "m"]:
		var p := 0.0
		if kind == "value":
			p = _value_shown(fg, mg, father, mother, locus, ld)
		else:
			for row in CKBloodline._child_pairs(fg, mg, locus, kind, sex):
				var tmp := {"loci": {"mark": ["none", "none"]}, "sig": {locus: row[0], "pen": {locus: 0.0}}}
				var e := CKBloodline.express_trait(tmp, locus, {"sex": sex, "age": 30, "rank": 0, "honors": []})
				if str(e.get("tier", "")) in SHOWN:
					p += float(row[1])
		acc += 0.5 * p
	return acc


static func _value_shown(fg: Dictionary, mg: Dictionary, father: Object, mother: Object, locus: String, ld: Dictionary) -> float:
	var law := str(ld.get("law", ""))
	var blood := {}
	for src_c in [father, mother]:
		if src_c == null:
			continue
		var src = src_c.get("blood_mix")
		if typeof(src) != TYPE_DICTIONARY:
			continue
		for k in (src as Dictionary).keys():
			blood[k] = float(blood.get(k, 0.0)) + 0.5 * float(src[k])
	var mu := CKBloodline._value(mg, locus)
	var sd := float(ld.get("drift", 0.07))
	if law == "threshold":
		var mid := 0.5 * (CKBloodline._value(fg, locus) + CKBloodline._value(mg, locus))
		mu = mid + float(ld.get("regress", 0.15)) * (CKBloodline.line_mean(blood, locus) - mid)
		sd = float(ld.get("noise", 0.06))
	var z_scale := maxf(sd, 0.001)
	var pr := 1.0 - CKBloodline._ncdf((float(ld.get("royal_min", 0.7)) - mu) / z_scale)
	var pn := 1.0 - CKBloodline._ncdf((float(ld.get("noble_min", 0.45)) - mu) / z_scale) - pr
	return maxf(0.0, pr) + maxf(0.0, pn)


static func combat_forecast(father: Object, mother: Object) -> Array:
	var out: Array = []
	for t in rows():
		var p := expression_prob(father, mother, str(t.get("locus", "")))
		if p < 0.005:
			continue
		var row: Dictionary = (t as Dictionary).duplicate()
		row["p"] = p
		out.append(row)
	out.sort_custom(func(a, b): return float(a["p"]) > float(b["p"]))
	return out


static func combat_forecast_zh(father: Object, mother: Object, limit: int = 3) -> String:
	if father == null or mother == null:
		return "战斗投影：选定双方后显示子嗣的战术禀性概率。"
	var bits: Array = []
	for t in combat_forecast(father, mother).slice(0, limit):
		bits.append("%s %d%%（%s）" % [str(t.get("zh", "")), int(round(float(t.get("p", 0.0)) * 100.0)), str(t.get("effect", ""))])
	if bits.is_empty():
		return "战斗投影：这对父母没有可预期的战术禀性。"
	return "战斗投影：" + "；".join(bits)


static func royal_skill_tier(c: Object, nation_id: String = "") -> int:
	if c == null:
		return 0
	var shown: Array = CKBloodline.royal_nations(c)
	if nation_id != "":
		if not (nation_id in shown):
			return 0
		return _tier_for(c, nation_id)
	var best := 0
	for nid in shown:
		best = maxi(best, _tier_for(c, str(nid)))
	return best


static func royal_skill_scale(c: Object, nation_id: String = "") -> float:
	var tier := royal_skill_tier(c, nation_id)
	for row in tier_rows():
		if int(row.get("tier", 0)) == tier:
			return float(row.get("scale", 0.0))
	return 0.0


static func legend_zh() -> String:
	var bits: Array = []
	for row in tier_rows():
		bits.append("%s ×%s" % [str(row.get("zh", "")), str(row.get("scale", ""))])
	if bits.is_empty():
		return "王技分阶：未登记"
	return "王技分阶：" + " / ".join(bits)


static func _tier_for(c: Object, nid: String) -> int:
	var copies := _copies(c, nid)
	var purity := _purity(c, nid)
	if copies >= 2 and purity >= 0.75:
		return 3
	if copies >= 2 or purity >= 0.5:
		return 2
	return 1


static func _purity(c: Object, nid: String) -> float:
	var line_id := str(CKBloodline.nation(nid).get("royal", ""))
	var mix = c.get("blood_mix")
	if typeof(mix) != TYPE_DICTIONARY:
		return 0.0
	return float(mix.get(line_id, 0.0))


static func _copies(c: Object, nid: String) -> int:
	var locus := str(CKBloodline.nation(nid).get("locus", ""))
	var ld := CKBloodline.locus_def(locus)
	var kind := str(ld.get("kind", "diploid"))
	var g := _genome(c)
	if kind == "value":
		var v := CKBloodline._value(g, locus)
		return 2 if v >= float(ld.get("royal_min", 0.7)) + 0.1 else 1
	if kind == "x" or kind == "y":
		return 2 if _purity(c, nid) >= 0.75 else 1
	if str(ld.get("law", "")) == "complement":
		var pr: Array = ld.get("pair", [])
		var dip: Array = CKBloodline._dip(g, locus)
		var n := 0
		for al in pr:
			if str(al) in dip:
				n += 1
		return n
	var allele := str(ld.get("royal", ""))
	if allele == "":
		return 0
	return int(CKBloodline._dip(g, locus).count(allele))
