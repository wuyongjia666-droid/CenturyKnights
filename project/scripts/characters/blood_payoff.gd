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


## Per-nation odds that a child shows crown tier 1/2/3. Purity is the midparent
## blood weight. Copy count follows the same rules as _copies(). No extra draw.
static func royal_tier_forecast(father: Object, mother: Object) -> Array:
	if father == null or mother == null:
		return []
	_prepare(father)
	_prepare(mother)
	var mix := _mix_blood(father, mother)
	var fg := _genome(father)
	var mg := _genome(mother)
	var out: Array = []
	for nid_v in CKBloodline.nation_ids():
		var nid := str(nid_v)
		var locus := str(CKBloodline.nation(nid).get("locus", ""))
		var ld := CKBloodline.locus_def(locus)
		if ld.is_empty():
			continue
		var purity := float(mix.get(str(CKBloodline.nation(nid).get("royal", "")), 0.0))
		var buckets := {"0": 0.0, "1": 0.0, "2": 0.0, "3": 0.0}
		var kind := str(ld.get("kind", "diploid"))
		if kind == "value":
			_fill_value_tiers(buckets, fg, mg, father, mother, locus, ld, purity)
		else:
			for sex in ["f", "m"]:
				for row in CKBloodline._child_pairs(fg, mg, locus, kind, sex):
					var alleles: Array = row[0]
					var g := {"loci": {"mark": ["none", "none"]}, "sig": {locus: alleles, "pen": {locus: 0.0}}}
					var e := CKBloodline.express_nation(g, nid, {"sex": sex, "age": 30, "rank": 0, "honors": []})
					var tier := 0
					if str(e.get("tier", "")) == "royal":
						tier = _tier_from(purity, _forecast_copies(kind, ld, alleles, purity))
					var key := str(tier)
					buckets[key] = float(buckets.get(key, 0.0)) + 0.5 * float(row[1])
		var shown := 1.0 - float(buckets["0"])
		if shown < 0.005:
			continue
		out.append({
			"nation": nid,
			"zh": str(CKBloodline.nation(nid).get("name", nid)),
			"purity": purity,
			"p0": float(buckets["0"]),
			"p1": float(buckets["1"]),
			"p2": float(buckets["2"]),
			"p3": float(buckets["3"]),
			"p_shown": shown,
		})
	out.sort_custom(func(a, b): return float(a["p_shown"]) > float(b["p_shown"]))
	return out


static func royal_tier_forecast_zh(father: Object, mother: Object, limit: int = 1) -> String:
	var rows := royal_tier_forecast(father, mother)
	if rows.is_empty():
		return "王技阶：这对父母没有可预期的显冕。"
	var names := {1: "残响", 2: "正冕", 3: "满冕"}
	var bits: Array = []
	for row in rows.slice(0, limit):
		var best := 1
		var bp := float(row["p1"])
		for tier in [2, 3]:
			var p := float(row["p%d" % tier])
			if p > bp:
				bp = p
				best = tier
		bits.append("%s · %s %d%%" % [str(row.get("zh", "")), names[best], int(round(bp * 100.0))])
	return "王技阶 " + "；".join(bits)


static func _mix_blood(a: Object, b: Object) -> Dictionary:
	var keys := {}
	for src_c in [a, b]:
		var src = src_c.get("blood_mix") if src_c != null else {}
		if typeof(src) != TYPE_DICTIONARY:
			continue
		for k in (src as Dictionary).keys():
			keys[k] = true
	var out := {}
	var total := 0.0
	for k in keys.keys():
		var wa := 0.0
		var wb := 0.0
		var ma = a.get("blood_mix") if a != null else {}
		var mb = b.get("blood_mix") if b != null else {}
		if typeof(ma) == TYPE_DICTIONARY:
			wa = float(ma.get(k, 0.0))
		if typeof(mb) == TYPE_DICTIONARY:
			wb = float(mb.get(k, 0.0))
		var w := 0.5 * wa + 0.5 * wb
		out[k] = w
		total += w
	if total <= 0.0:
		return {"common_ash": 1.0}
	for k in out.keys():
		out[k] = float(out[k]) / total
	return out


static func _fill_value_tiers(buckets: Dictionary, fg: Dictionary, mg: Dictionary, father: Object, mother: Object, locus: String, ld: Dictionary, purity: float) -> void:
	var law := str(ld.get("law", ""))
	var blood := _mix_blood(father, mother)
	var mu := CKBloodline._value(mg, locus)
	var sd := float(ld.get("drift", 0.07))
	if law == "threshold":
		var mid := 0.5 * (CKBloodline._value(fg, locus) + CKBloodline._value(mg, locus))
		mu = mid + float(ld.get("regress", 0.15)) * (CKBloodline.line_mean(blood, locus) - mid)
		sd = float(ld.get("noise", 0.06))
	var z := maxf(sd, 0.001)
	var royal_min := float(ld.get("royal_min", 0.7))
	var p_royal := clampf(1.0 - CKBloodline._ncdf((royal_min - mu) / z), 0.0, 1.0)
	var p_full := clampf(1.0 - CKBloodline._ncdf((royal_min + 0.1 - mu) / z), 0.0, p_royal)
	var p_thin := maxf(0.0, p_royal - p_full)
	if purity >= 0.75:
		buckets["3"] = p_full
		buckets["2"] = p_thin
	elif purity >= 0.5:
		buckets["2"] = p_royal
	else:
		buckets["2"] = p_full
		buckets["1"] = p_thin
	buckets["0"] = maxf(0.0, 1.0 - p_royal)


static func _forecast_copies(kind: String, ld: Dictionary, alleles: Array, purity: float) -> int:
	if kind == "x" or kind == "y":
		return 2 if purity >= 0.75 else 1
	if str(ld.get("law", "")) == "complement":
		var n := 0
		for al in ld.get("pair", []):
			if str(al) in alleles:
				n += 1
		return n
	var allele := str(ld.get("royal", ""))
	if allele == "":
		return 0
	return int(alleles.count(allele))


static func _tier_from(purity: float, copies: int) -> int:
	if copies >= 2 and purity >= 0.75:
		return 3
	if copies >= 2 or purity >= 0.5:
		return 2
	return 1


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
