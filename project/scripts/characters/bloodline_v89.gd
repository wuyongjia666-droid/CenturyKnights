class_name CKBloodline
extends RefCounted
## v8.9 nation bloodlines: 10 nations x (royal / high noble / folk).
## The original crown locus (LOCUS_ORDER) still decides succession, skills and pricing.
## trait_order (appended, never inserted) is the multi-trait house set: hair, iris, bone, skin,
## bearing, regalia and a rare pure-line expression. Blood is what you carry; the crown is what you show.
## Data: res://data/bloodlines_v89.json. Design: docs/design/bloodlines-v89.md.

const DATA_PATH := "res://data/bloodlines_v89.json"
## Draw order for the original ten crown loci. Do not insert or reorder: seeded recruits and the
## v8.9 law tests depend on these draws happening first on the forked RNG. New trait loci append via trait_order.
const LOCUS_ORDER := ["sig_ashbanner", "sig_shuoying", "jade", "sig_lantern", "sig_frostcrown", "sig_emberold", "sig_saltmarsh", "sig_irongorge", "sig_starriver", "glow"]
const TIER_RANK := {"none": 0, "latent": 1, "noble": 2, "royal": 3}
const RANKS := ["knight", "baron", "count", "duke"]

static var _data: Dictionary = {}
static var _lines: Dictionary = {}
## Extra characters for parent lookups outside GameState (fixtures, debug scenes).
static var people: Dictionary = {}

# ── data ──────────────────────────────────────────────
static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_data = parsed
		_lines.clear()
		for l in _data.get("lines", []):
			_lines[str(l.get("id", ""))] = l
	return _data

static func lines() -> Array:
	return data().get("lines", [])

static func has_line(id: String) -> bool:
	data()
	return _lines.has(id)

static func line(id: String) -> Dictionary:
	data()
	return _lines.get(id, {})

static func nation_ids() -> Array:
	return data().get("nations", {}).keys()

static func nation(nid: String) -> Dictionary:
	var d := data()
	if d.get("nations", {}).has(nid):
		return d["nations"][nid]
	return d.get("regions", {}).get(nid, {})

static func nation_of_line(id: String) -> String:
	return str(line(id).get("nation", ""))

static func tier_of(id: String) -> String:
	return str(line(id).get("tier", "folk"))

static func genome_table(id: String) -> Dictionary:
	return line(id).get("genome", {})

static func locus_def(locus: String) -> Dictionary:
	return data().get("loci", {}).get(locus, {})

## Original crown loci, then the appended trait loci. Order is part of the save-stable RNG.
static func _locus_order() -> Array:
	var out: Array = []
	for locus in LOCUS_ORDER:
		out.append(locus)
	for locus in data().get("trait_order", []):
		var id := str(locus)
		if not (id in out):
			out.append(id)
	return out

static func trait_order() -> Array:
	var out: Array = []
	for locus in data().get("trait_order", []):
		out.append(str(locus))
	return out

static func signature_def(state: String) -> Dictionary:
	return data().get("signatures", {}).get(state, {})

static func folk_of(nid: String) -> String:
	return str(nation(nid).get("folk", "common_ash"))

static func nobles_of(nid: String) -> Array:
	return nation(nid).get("noble", [])

static func lines_of(nid: String) -> Array:
	var out: Array = []
	for l in lines():
		if str(l.get("nation", "")) == nid:
			out.append(str(l.id))
	return out

static func _pool(nid: String) -> Dictionary:
	var base: Dictionary = data().get("pool_default", {}).duplicate(true)
	var over: Dictionary = nation(nid).get("pool", {})
	for k in over.keys():
		if typeof(over[k]) == TYPE_DICTIONARY and typeof(base.get(k)) == TYPE_DICTIONARY:
			var merged: Dictionary = base[k]
			merged.merge(over[k], true)
			base[k] = merged
		else:
			base[k] = over[k]
	return base

# ── small helpers ─────────────────────────────────────
static func _pick_weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights.keys():
		total += maxf(0.0, float(weights[k]))
	if total <= 0.0:
		return ""
	var r := rng.randf() * total
	for k in weights.keys():
		r -= maxf(0.0, float(weights[k]))
		if r <= 0.0:
			return str(k)
	return str(weights.keys()[weights.size() - 1])

static func _sig(g: Dictionary) -> Dictionary:
	var s = g.get("sig", {})
	return s if typeof(s) == TYPE_DICTIONARY else {}

static func _pair(g: Dictionary, locus: String) -> Array:
	var p = _sig(g).get(locus, [])
	return p if typeof(p) == TYPE_ARRAY else []

static func _dip(g: Dictionary, locus: String) -> Array:
	var p := _pair(g, locus)
	var a := str(p[0]) if p.size() > 0 else "none"
	var b := str(p[1]) if p.size() > 1 else a
	if b == "-":
		b = a
	return [a, b]

static func _value(g: Dictionary, locus: String) -> float:
	return float(_sig(g).get(locus, 0.0))

static func _lose(allele: String, p: float, rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	if allele != "none" and allele != "-" and r < p:
		return "none"
	return allele

## A fresh generator derived from the caller's state without advancing it, so adding signature loci
## never changes the legacy loci a seeded caller already produced.
static func fork(rng: RandomNumberGenerator, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d|%s" % [rng.state, salt])
	return r

static func _line_value(id: String, locus: String) -> Array:
	for e in line(id).get("sig", []):
		if str(e.get("locus", "")) == locus and e.has("value"):
			return e["value"]
	return []

## blood-weighted mean of a value locus (jade / glow), used for founders and threshold regression
static func line_mean(blood_mix: Dictionary, locus: String) -> float:
	var s := 0.0
	var tw := 0.0
	for bl in blood_mix.keys():
		var w := float(blood_mix[bl])
		tw += w
		var v := _line_value(str(bl), locus)
		if not v.is_empty():
			s += float(v[0]) * w
	return s / tw if tw > 0.0 else 0.0

static func _genotype_table(src: String, locus: String, kind: String, sex: String) -> Dictionary:
	if src == "":
		return {}
	for e in line(src).get("sig", []):
		if str(e.get("locus", "")) != locus:
			continue
		if kind == "x":
			return e.get("m" if sex == "m" else "f", {})
		if kind == "y":
			return e.get("m", {}) if sex == "m" else {}
		return e.get("genotypes", {})
	return {}

static func _genotype(gt: String, kind: String, sex: String) -> Array:
	var parts: PackedStringArray = gt.split("|") if gt != "" else PackedStringArray()
	match kind:
		"y":
			if sex != "m":
				return []
			return [parts[0] if parts.size() > 0 else "none"]
		"x":
			if sex == "m":
				return [parts[0] if parts.size() > 0 else "none", "-"]
			return [parts[0] if parts.size() > 0 else "none", parts[1] if parts.size() > 1 else "none"]
		_:
			return [parts[0] if parts.size() > 0 else "none", parts[1] if parts.size() > 1 else "none"]

static func _source_line(blood_mix: Dictionary, locus: String, rng: RandomNumberGenerator, force_line: String) -> String:
	if force_line != "":
		for e in line(force_line).get("sig", []):
			if str(e.get("locus", "")) == locus:
				return force_line
	var src := _pick_weighted(blood_mix, rng)
	for e in line(src).get("sig", []):
		if str(e.get("locus", "")) == locus:
			return src
	return ""

# ── genetics ──────────────────────────────────────────
## Founder signature genome (recruits, candidates, NPCs). One source line is drawn per locus by blood weight.
## force_line pins that line's discrete loci (exiles keep their house sign however diluted the blood is).
static func founder_sig(blood_mix: Dictionary, sex: String, rng: RandomNumberGenerator, force_line: String = "") -> Dictionary:
	var out := {"pen": {}}
	for locus in _locus_order():
		var ld := locus_def(locus)
		var kind := str(ld.get("kind", "diploid"))
		var law := str(ld.get("law", ""))
		if kind == "value":
			var fv: Array = _line_value(force_line, locus) if force_line != "" and law == "maternal" else []
			if not fv.is_empty():
				out[locus] = clampf(float(fv[0]) + float(fv[1]) * rng.randfn(0.0, 1.0), 0.0, 1.0)
			else:
				var sd := 0.05
				for bl in blood_mix.keys():
					var v := _line_value(str(bl), locus)
					if not v.is_empty():
						sd = maxf(sd, float(v[1]))
				out[locus] = clampf(line_mean(blood_mix, locus) + sd * rng.randfn(0.0, 1.0), 0.0, 1.0)
			continue
		var src := _source_line(blood_mix, locus, rng, force_line)
		var table := _genotype_table(src, locus, kind, sex)
		out[locus] = _genotype(_pick_weighted(table, rng), kind, sex)
		if law == "penetrance":
			out["pen"][locus] = rng.randf()
	return out

static func _x_of(g: Dictionary, locus: String) -> Array:
	var p := _pair(g, locus)
	var a := str(p[0]) if p.size() > 0 else "none"
	var b := str(p[1]) if p.size() > 1 else "-"
	return [a, b]

## Child signature genome. Autosomal loci: one allele per parent. X: daughters get the father's X and one of the
## mother's; sons get one of the mother's. Y: sons copy the father. Maternal value: the mother's, drifting.
## Threshold value: midparent + noise, regressed toward the child's blood mean. Mutations only ever lose a sign.
static func cross_sig(father: Dictionary, mother: Dictionary, child_blood: Dictionary, child_sex: String, rng: RandomNumberGenerator) -> Dictionary:
	var out := {"pen": {}}
	for locus in _locus_order():
		var ld := locus_def(locus)
		var kind := str(ld.get("kind", "diploid"))
		var law := str(ld.get("law", ""))
		var loss := float(ld.get("mutation_loss", 0.0))
		match kind:
			"value":
				if law == "maternal":
					out[locus] = clampf(_value(mother, locus) + float(ld.get("drift", 0.07)) * rng.randfn(0.0, 1.0), 0.0, 1.0)
				else:
					var mid := 0.5 * (_value(father, locus) + _value(mother, locus))
					var pull := line_mean(child_blood, locus) - mid
					out[locus] = clampf(mid + float(ld.get("regress", 0.15)) * pull + float(ld.get("noise", 0.06)) * rng.randfn(0.0, 1.0), 0.0, 1.0)
			"y":
				var fy := _pair(father, locus)
				var ya := _lose(str(fy[0]) if fy.size() > 0 else "none", loss, rng)
				out[locus] = [ya] if child_sex == "m" else []
			"x":
				var mx := _x_of(mother, locus)
				if str(mx[1]) == "-":
					mx[1] = mx[0]
				var from_m := _lose(str(mx[rng.randi() % 2]), loss, rng)
				var from_f := _lose(str(_x_of(father, locus)[0]), loss, rng)
				out[locus] = [from_m, "-"] if child_sex == "m" else [from_f, from_m]
			_:
				var fp := _dip(father, locus)
				var mp := _dip(mother, locus)
				out[locus] = [_lose(str(fp[rng.randi() % 2]), loss, rng), _lose(str(mp[rng.randi() % 2]), loss, rng)]
		if law == "penetrance":
			out["pen"][locus] = rng.randf()
	return out

## Pre-v8.9 genomes get signature loci on first use, seeded by identity. The v8.7 crown_rime mark was the
## Frostcrown royal sign; its zygosity carries over 1:1 to rime_lash so legacy royals keep their status.
static func upgrade_genome(c: Object) -> void:
	var g: Dictionary = c.get("genome")
	if g.is_empty() or g.has("sig"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|v89" % [str(c.get("id")), str(c.get("name"))])
	var blood: Dictionary = c.get("blood_mix") if typeof(c.get("blood_mix")) == TYPE_DICTIONARY else {}
	var s := founder_sig(blood, str(c.get("gender")), rng)
	var legacy := str(locus_def("sig_frostcrown").get("legacy_mark", "crown_rime"))
	var mk: Array = g.get("loci", {}).get("mark", [])
	var n := 0
	for a in mk:
		if str(a) == legacy:
			n += 1
	s["sig_frostcrown"] = ["rime_lash", "rime_lash"] if n >= 2 else (["rime_lash", "none"] if n == 1 else ["none", "none"])
	g["sig"] = s
	g["v"] = 3

# ── expression ────────────────────────────────────────
static func ctx_of(c: Object) -> Dictionary:
	var honors: Array = c.get("honors") if typeof(c.get("honors")) == TYPE_ARRAY else []
	var meta: Dictionary = c.get("blood_meta") if typeof(c.get("blood_meta")) == TYPE_DICTIONARY else {}
	return {
		"sex": "f" if str(c.get("gender")) == "f" else "m",
		"age": int(c.get("age")),
		"rank": RANKS.find(str(c.get("rank"))),
		"honors": honors,
		"verified": bool(meta.get("verified", false)),
	}

static func _deed(ctx: Dictionary, deed: Dictionary) -> bool:
	if int(ctx.get("rank", 0)) >= RANKS.find(str(deed.get("rank_min", "count"))):
		return true
	for h in deed.get("honors_any", []):
		if h in ctx.get("honors", []):
			return true
	return false

static func _put(res: Dictionary, tier: String, state: String, strength: float) -> void:
	res["tier"] = tier
	res["state"] = state
	res["strength"] = strength

## One nation's crown: tier none / latent / noble / royal. Trait loci do not pass through here.
static func express_nation(g: Dictionary, nid: String, ctx: Dictionary) -> Dictionary:
	var res := express_trait(g, str(nation(nid).get("locus", "")), ctx)
	res["nation"] = nid
	return res

## Phenotype of one signature locus (crown or trait). Same laws as express_nation.
static func express_trait(g: Dictionary, locus: String, ctx: Dictionary) -> Dictionary:
	var ld := locus_def(locus)
	var law := str(ld.get("law", ""))
	var states: Dictionary = ld.get("states", {})
	var sex := str(ctx.get("sex", "m"))
	var age := int(ctx.get("age", 30))
	var res := {"nation": str(ld.get("nation", "")), "locus": locus, "law": law, "slot": str(ld.get("slot", "mark")), "scope": str(ld.get("scope", "crown")), "tier": "none", "state": "", "strength": 0.0, "carrier": false, "hidden": false}
	var R := str(ld.get("royal", ""))
	var N := str(ld.get("noble", ""))
	match law:
		"awakened":
			var p := _dip(g, locus)
			if R in p:
				res["carrier"] = true
				if _deed(ctx, ld.get("deed", {})):
					_put(res, "royal", str(states.get("royal", "")), 1.0)
				elif N in p:
					_put(res, "noble", str(states.get("noble", "")), 1.0)
				else:
					_put(res, "latent", str(states.get("royal", "")), 0.0)
			elif N in p:
				_put(res, "noble", str(states.get("noble", "")), 1.0)
		"dose":
			var n := _dip(g, locus).count(R)
			if n >= 2:
				_put(res, "royal", str(states.get("royal", "")), 1.0)
			elif n == 1:
				res["carrier"] = true
				_put(res, "noble", str(states.get("noble", "")), float(ld.get("partial", 0.45)))
		"threshold", "maternal":
			var v := _value(g, locus)
			res["value"] = v
			if v >= float(ld.get("royal_min", 0.7)):
				var lo := float(ld.get("royal_min", 0.7))
				_put(res, "royal", str(states.get("royal", "")), clampf(0.7 + 0.3 * (v - lo) / maxf(0.001, 1.0 - lo), 0.7, 1.0))
			elif v >= float(ld.get("noble_min", 0.45)):
				_put(res, "noble", str(states.get("noble", "")), 0.6)
			elif v >= float(ld.get("latent_min", 0.4)):
				res["carrier"] = true
				_put(res, "latent", str(states.get("royal", "")), 0.0)
			if law == "maternal" and sex == "m" and res["tier"] != "none":
				res["dead_end"] = true
		"dominant":
			var p2 := _dip(g, locus)
			if R in p2:
				_put(res, "royal", str(states.get("royal", "")), 1.0)
			elif N in p2:
				_put(res, "noble", str(states.get("noble", "")), 1.0)
		"recessive":
			var p3 := _dip(g, locus)
			var nr := p3.count(R)
			if nr >= 2:
				_put(res, "royal", str(states.get("royal", "")), 1.0)
			elif N in p3:
				res["carrier"] = nr > 0
				_put(res, "noble", str(states.get("noble", "")), 1.0)
			elif nr == 1:
				res["carrier"] = true
				_put(res, "latent", str(states.get("royal", "")), 0.0)
		"y_linked":
			var y := _pair(g, locus)
			if sex == "m" and y.size() > 0 and str(y[0]) == R:
				_put(res, "royal", str(states.get("royal", "")), 1.0)
			elif str(ld.get("noble_from_mark", "")) != "":
				var mk: Dictionary = CKGenome.express(g, "mark")
				if str(mk.get("id", "")) == str(ld.get("noble_from_mark", "")):
					_put(res, "noble", str(states.get("noble", "")), float(mk.get("strength", 1.0)))
		"age_awakened":
			var pa := _dip(g, locus)
			if R in pa:
				res["carrier"] = true
				if age >= int(ld.get("age_min", 28)):
					_put(res, "royal", str(states.get("royal", "")), 1.0)
				elif N != "" and N in pa:
					_put(res, "noble", str(states.get("noble", "")), 1.0)
				else:
					_put(res, "latent", str(states.get("royal", "")), 0.0)
			elif N != "" and N in pa:
				_put(res, "noble", str(states.get("noble", "")), 1.0)
		"pureblood":
			var pb := _dip(g, locus)
			var np := pb.count(R)
			if np >= 2:
				res["carrier"] = true
				if express_nation(g, str(ld.get("nation", "")), ctx)["tier"] == "royal":
					_put(res, "royal", str(states.get("royal", "")), 1.0)
				else:
					_put(res, "latent", str(states.get("royal", "")), 0.0)
			elif np == 1:
				res["carrier"] = true
				_put(res, "latent", str(states.get("royal", "")), 0.0)
		"x_dominant":
			var x := _x_of(g, locus)
			var order: Array = ld.get("alleles", [])
			var shown := str(x[0])
			if sex != "m" and str(x[1]) != "-" and order.find(str(x[1])) >= 0 and (order.find(shown) < 0 or order.find(str(x[1])) < order.find(shown)):
				shown = str(x[1])
			if shown == R:
				_put(res, "royal", str(states.get("royal", "")), 1.0)
			elif N != "" and shown == N:
				_put(res, "noble", str(states.get("noble", "")), 1.0)
		"penetrance":
			var p4 := _dip(g, locus)
			if R in p4:
				res["carrier"] = true
				var pen := float(_sig(g).get("pen", {}).get(locus, 0.0))
				if pen < float(ld.get("penetrance", 0.6)):
					_put(res, "royal", str(states.get("royal", "")), 1.0)
				else:
					res["hidden"] = true
					if N in p4:
						_put(res, "noble", str(states.get("noble", "")), 1.0)
					else:
						_put(res, "latent", str(states.get("royal", "")), 0.0)
			elif N in p4:
				_put(res, "noble", str(states.get("noble", "")), 1.0)
		"complement":
			var p5 := _dip(g, locus)
			var pr: Array = ld.get("pair", [])
			var has_a := pr.size() > 0 and str(pr[0]) in p5
			var has_b := pr.size() > 1 and str(pr[1]) in p5
			if has_a and has_b:
				_put(res, "royal", str(states.get("royal", "")), 1.0)
			elif has_a:
				_put(res, "noble", str(states.get("noble_a", "")), 1.0)
			elif has_b:
				_put(res, "noble", str(states.get("noble_b", "")), 1.0)
	var display := str(ld.get("display_tier", ""))
	if display != "" and str(res["tier"]) == "royal":
		res["tier"] = display
	if str(res["state"]) != "":
		var sd := signature_def(str(res["state"]))
		res["zh"] = str(sd.get("zh", res["state"]))
		res["visibility"] = "latent" if res["tier"] == "latent" else str(sd.get("visibility", "overt"))
	return res

static func _ensure(c: Object) -> void:
	if c.has_method("ensure_genome"):
		c.call("ensure_genome")

## Every nation sign this character carries or shows, strongest first. Latent entries only when asked.
static func signatures(c: Object, include_latent: bool = true) -> Array:
	_ensure(c)
	var g: Dictionary = c.get("genome") if typeof(c.get("genome")) == TYPE_DICTIONARY else {}
	var ctx := ctx_of(c)
	var out: Array = []
	for nid in nation_ids():
		var e := express_nation(g, str(nid), ctx)
		if e["tier"] == "none" or (e["tier"] == "latent" and not include_latent):
			continue
		out.append(e)
	out.sort_custom(func(a, b): return int(TIER_RANK[a["tier"]]) > int(TIER_RANK[b["tier"]]))
	return out

static func royal_nations(c: Object) -> Array:
	var out: Array = []
	for e in signatures(c, false):
		if e["tier"] == "royal":
			out.append(str(e["nation"]))
	return out

## 0: only overt signs. 1: a roster member with high perception or a shrine Lv2 reads subtle signs.
static func inspect_level() -> int:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs == null:
		return 0
	var ins: Dictionary = data().get("pricing", {}).get("inspect", {})
	if gs.has_method("building_level") and int(gs.building_level("shrine")) >= int(ins.get("shrine_level", 2)):
		return 1
	for c in gs.roster():
		if int(c.stats.get("per", 0)) >= int(ins.get("per_min", 14)):
			return 1
	return 0

static func visible_signatures(c: Object, level: int = -1) -> Array:
	if level < 0:
		level = inspect_level()
	var verified := bool(ctx_of(c).get("verified", false))
	var out: Array = []
	for e in signatures(c, true):
		var vis := str(e.get("visibility", "overt"))
		if vis == "overt" or (vis == "subtle" and (level >= 1 or verified)) or (vis == "latent" and verified):
			out.append(e)
	return out

const VIS_ZH := {"overt": "明", "subtle": "隐", "latent": "潜"}

static func summary_zh(c: Object, level: int = -1) -> String:
	var bits: Array = []
	for e in visible_signatures(c, level):
		bits.append("%s·%s" % [str(e.get("zh", "")), VIS_ZH.get(str(e.get("visibility", "")), "")])
	var meta: Dictionary = c.get("blood_meta") if typeof(c.get("blood_meta")) == TYPE_DICTIONARY else {}
	var tail := ""
	var ex := str(meta.get("exile", ""))
	if ex != "":
		for d in data().get("diaspora", []):
			if str(d.get("id", "")) == ex:
				tail = " · 流裔「%s」" % str(d.get("name", ex))
	if bool(meta.get("pretend", {}).get("exposed", false)):
		tail += " · 伪胤已揭"
	return ("冕征：" + ("、".join(bits) if not bits.is_empty() else "未见")) + tail

# ── social: edge blood, claims, succession, kinship, marriage ───────────────────
## Royal blood (>=1/8) without that nation's royal sign. Stigma 0 none, 1 mild, 2 severe.
static func edge_blood(c: Object) -> Array:
	var out: Array = []
	var shown := royal_nations(c)
	var blood: Dictionary = c.get("blood_mix")
	for bl in blood.keys():
		var id := str(bl)
		if tier_of(id) != "royal" or float(blood[bl]) < 0.125:
			continue
		var nid := nation_of_line(id)
		if nid in shown:
			continue
		var e: Dictionary = nation(nid).get("edge", {})
		out.append({"nation": nid, "line": id, "weight": float(blood[bl]), "name": str(e.get("name", "")), "stigma": int(e.get("stigma", 0)), "desc": str(e.get("desc", ""))})
	out.sort_custom(func(a, b): return int(a["stigma"]) > int(b["stigma"]))
	return out

static func claim(c: Object, nid: String) -> Dictionary:
	_ensure(c)
	var ctx := ctx_of(c)
	var e := express_nation(c.get("genome"), nid, ctx)
	var law := str(e["law"])
	var royal: bool = e["tier"] == "royal"
	var female: bool = ctx["sex"] == "f"
	var stats: Dictionary = c.get("stats") if typeof(c.get("stats")) == TYPE_DICTIONARY else {}
	var age := float(c.get("age"))
	var lvl := float(c.get("level"))
	var honors: Array = ctx["honors"]
	var eligible := royal
	var score := 0.0
	match law:
		"awakened":
			score = float(ctx["rank"]) * 10.0 + honors.size() * 3.0 + lvl
		"dose":
			eligible = e["tier"] in ["royal", "noble"]
			score = (100.0 if royal else 50.0) + age
		"threshold":
			score = float(e.get("value", 0.0)) * 100.0
		"dominant":
			score = float(ctx["rank"]) * 10.0 + lvl
		"recessive":
			score = float(stats.get("wil", 8)) * 5.0 + age
		"y_linked":
			score = age
		"x_dominant":
			eligible = royal and female
			score = 100.0 + age
		"penetrance":
			eligible = royal or (bool(e["carrier"]) and bool(ctx["verified"]))
			score = float(stats.get("str", 8)) + float(stats.get("vit", 8)) + lvl
		"complement":
			score = float(stats.get("per", 8)) + float(stats.get("wil", 8))
		"maternal":
			eligible = royal and female
			score = 100.0 + float(e.get("value", 0.0)) * 100.0
	return {"id": str(c.get("id")), "nation": nid, "law": law, "tier": e["tier"], "state": e["state"], "eligible": eligible,
		"score": score, "hidden": bool(e["hidden"]), "female": female, "age": age, "royal": royal}

static func _person(id: String, chars: Dictionary) -> Object:
	if chars.has(id):
		return chars[id]
	if people.has(id):
		return people[id]
	return null

## Ordered claimants under the nation's succession law plus the crisis it produces (if any).
static func succession(cands: Array, nid: String, chars: Dictionary = {}) -> Dictionary:
	var nat := nation(nid)
	var cr: Dictionary = nat.get("crisis", {})
	var rows: Array = []
	var all_rows: Array = []
	for c in cands:
		var cl := claim(c, nid)
		cl["parent_ids"] = c.get("parent_ids") if typeof(c.get("parent_ids")) == TYPE_ARRAY else []
		all_rows.append(cl)
		if cl["eligible"]:
			rows.append(cl)
	rows.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	var key := ""
	var law := str(locus_def(str(nat.get("locus", ""))).get("law", ""))
	if rows.is_empty():
		match nid:
			"emberold":
				key = "cold"
				for r in all_rows:
					var pids: Array = r["parent_ids"]
					var fa: Object = _person(str(pids[0]), chars) if pids.size() > 0 else null
					if r["female"] and fa != null and "emberold" in royal_nations(fa):
						key = "canon"
			"frostcrown", "saltmarsh", "starriver", "southzephyr":
				key = "vacant"
	else:
		var top: Dictionary = rows[0]
		if nid == "shuoying" and top["royal"]:
			for r in rows:
				if not r["royal"] and float(r["age"]) > float(top["age"]):
					key = "younger_full"
		if key == "" and nid == "irongorge" and bool(top["hidden"]):
			key = "hidden_top"
		if key == "" and nid == "lantern" and rows.size() >= 3:
			key = "crowded"
		if key == "" and nid == "saltmarsh" and rows.size() >= 2:
			var by_father := {}
			for r in rows:
				var pids2: Array = r["parent_ids"]
				if pids2.size() >= 2 and str(pids2[0]) != "":
					var fk := str(pids2[0])
					if not by_father.has(fk):
						by_father[fk] = {}
					by_father[fk][str(pids2[1])] = true
			for fk in by_father.keys():
				if (by_father[fk] as Dictionary).size() >= 2:
					key = "many_daughters"
		if key == "" and nid == "emberold":
			var tp: Array = top["parent_ids"]
			var fa2: Object = _person(str(tp[0]), chars) if tp.size() > 0 else null
			if fa2 != null and not ("emberold" in royal_nations(fa2)):
				key = "false_father"
		if key == "" and rows.size() >= 2 and cr.has("contested"):
			var a := float(rows[0]["score"])
			var b := float(rows[1]["score"])
			var close := absf(a - b) < (3.0 if law == "threshold" else maxf(1.0, absf(a) * 0.1))
			if close:
				key = "contested"
	var order: Array = []
	for r in rows:
		order.append(str(r["id"]))
	return {"nation": nid, "law_name": str(nat.get("succession", {}).get("name", "")), "order": order, "rows": rows,
		"heir": order[0] if not order.is_empty() else "", "crisis": key,
		"crisis_name": str(cr.get(key, "")) if key != "" else "", "crisis_desc": str(cr.get(key + "_desc", "")) if key != "" else ""}

static func _ancestors(c: Object, chars: Dictionary, max_depth: int) -> Dictionary:
	var out := {str(c.get("id")): 0}
	var frontier: Array = [c]
	for depth in range(1, max_depth + 1):
		var next: Array = []
		for p in frontier:
			var pids: Array = p.get("parent_ids") if typeof(p.get("parent_ids")) == TYPE_ARRAY else []
			for pid in pids:
				var id := str(pid)
				if id == "" or out.has(id):
					continue
				out[id] = depth
				var pp := _person(id, chars)
				if pp != null:
					next.append(pp)
		frontier = next
	return out

## Generations between a and b through their closest common ancestor (siblings 2, cousins 4); 99 if unrelated.
static func kinship_degree(a: Object, b: Object, chars: Dictionary, max_depth: int = 4) -> int:
	var da := _ancestors(a, chars, max_depth)
	var db := _ancestors(b, chars, max_depth)
	var best := 99
	for id in da.keys():
		if db.has(id):
			best = mini(best, int(da[id]) + int(db[id]))
	return best

static func marriage_barrier(suitor: Object, target: Object, chars: Dictionary = {}) -> String:
	var lim := int(data().get("marriage", {}).get("kin_block_degree", 3))
	var deg := kinship_degree(suitor, target, chars)
	if deg <= lim:
		return "血缘过近（%d 等亲），宗祠不许此婚" % deg
	var paper: Dictionary = nation("lantern").get("paper", {})
	var honor := str(paper.get("honor", "paper_patent"))
	for pair in [[suitor, target], [target, suitor]]:
		var holder: Object = pair[0]
		var other: Object = pair[1]
		var hh: Array = holder.get("honors") if typeof(holder.get("honors")) == TYPE_ARRAY else []
		if not (honor in hh):
			continue
		var ob: String = other.call("primary_bloodline") if other.has_method("primary_bloodline") else ""
		if tier_of(ob) in ["royal", "noble"] and nation_of_line(ob) in paper.get("refused_by", []):
			return "%s贵胤不与纸冕者联姻" % str(line(ob).get("name", ob))
	return ""

## Diplomatic payoff of a marriage, keyed off the spouse who brings the bloodline.
static func marriage_effects(a: Object, b: Object) -> Dictionary:
	var spouse: Object = b
	if b.get("is_leader") == true:
		spouse = a
	var pb: String = spouse.call("primary_bloodline") if spouse.has_method("primary_bloodline") else ""
	var nid := nation_of_line(pb)
	var tier := tier_of(pb)
	var rep := {}
	var notes: Array = []
	var m: Dictionary = data().get("marriage", {})
	if nid != "":
		rep[nid] = int(m.get("rep_by_tier", {}).get(tier, 2))
		var nm: Dictionary = nation(nid).get("marriage", {})
		if tier in ["noble", "royal"]:
			for k in nm.get("rep", {}).keys():
				rep[str(k)] = int(rep.get(str(k), 0)) + int(nm["rep"][k])
		notes.append(str(nm.get("desc", "")))
	var dowry := 0
	if nid != "" and tier in ["noble", "royal"]:
		dowry = int(nation(nid).get("marriage", {}).get("dowry", {}).get(tier, 0))
	return {"nation": nid, "tier": tier, "rep": rep, "dowry": dowry, "notes": notes}

# ── taverns, recruits, marriage candidates ──────────────────────────────────────
static func _pick_diaspora(host: String, sex_hint: String, rng: RandomNumberGenerator) -> Dictionary:
	var w := {}
	var by_id := {}
	for d in data().get("diaspora", []):
		if host in d.get("nations", []):
			w[str(d.id)] = float(d.get("weight", 1.0))
			by_id[str(d.id)] = d
	var pick := _pick_weighted(w, rng)
	return by_id.get(pick, {})

static func _roll_result(lid: String, tier: String, nid: String, rng: RandomNumberGenerator, pool: Dictionary, allow_pretend: bool) -> Dictionary:
	var res := {"line": lid, "tier": tier, "nation": nid, "blood_mix": {lid: 1.0}, "sex": "", "exile": "", "pretend": {}, "force": ""}
	var home := nation_of_line(lid)
	if tier == "noble" and rng.randf() < float(pool.get("noble_mix", 0.3)):
		res["blood_mix"] = {lid: 0.75, folk_of(home): 0.25}
	elif tier == "royal" and rng.randf() < 0.5:
		var nb: Array = nobles_of(home)
		if not nb.is_empty():
			res["blood_mix"] = {lid: 0.7, str(nb[0]): 0.3}
	if allow_pretend and tier in ["noble", "royal"]:
		var rate := float(pool.get("pretend", {}).get(tier, 0.0)) * float(nation(home).get("forgery", {}).get("rate", 1.0))
		if rng.randf() < rate:
			res["pretend"] = {"claimed": lid, "true": folk_of(home)}
	return res

## One tavern slot. ctx: city_rep, nation_rep, slot, folk_only. Royal lines need the nation's gates; at
## nation rep >= slot0 the capital's first seat is always the nation's own royal line (盟誓).
static func roll_recruit(nid: String, kind: String, rng: RandomNumberGenerator, ctx: Dictionary = {}) -> Dictionary:
	var nat := nation(nid)
	if nat.is_empty():
		nid = "ashbanner"
		nat = nation(nid)
	var pool := _pool(nid)
	var royal_id := str(nat.get("royal", ""))
	var rp: Dictionary = pool.get("royal", {})
	var slot := int(ctx.get("slot", -1))
	var nrep := int(ctx.get("nation_rep", 0))
	var crep := int(ctx.get("city_rep", 0))
	var folk_only := bool(ctx.get("folk_only", false))
	if royal_id != "" and kind == "capital" and slot == 0 and nrep >= int(rp.get("slot0_nation_rep", 80)):
		var vouched := _roll_result(royal_id, "royal", nid, rng, pool, false)
		vouched["vouched"] = true
		return vouched
	if not folk_only:
		var fr := float(pool.get("foreign", {}).get(kind, 0.0))
		if fr > 0.0 and rng.randf() < fr:
			var d := _pick_diaspora(nid, "", rng)
			if not d.is_empty():
				var exl := str(d.get("line", ""))
				var mix := float(d.get("mix", 0.5))
				var host_folk := folk_of(nid)
				var bm := {exl: mix}
				if mix < 1.0 and host_folk != exl:
					bm[host_folk] = 1.0 - mix
				return {"line": exl, "tier": tier_of(exl), "nation": nation_of_line(exl), "host": nid, "blood_mix": bm,
					"sex": str(d.get("sex", "")), "exile": str(d.get("id", "")), "pretend": {}, "force": exl}
	var w := {"folk": float(pool.get("folk", {}).get(kind, 5.0))}
	if not folk_only:
		w["noble"] = float(pool.get("noble", {}).get(kind, 1.0))
		if royal_id != "" and kind in rp.get("kinds", []) and crep >= int(rp.get("city_rep_min", 30)) and nrep >= int(rp.get("nation_rep_min", 55)):
			w["royal"] = float(rp.get("weight", 0.8))
			if w.has("royal"):
				w["royal"] = float(w["royal"]) + CKCourt.recruit_bias(nid)
	var tier := _pick_weighted(w, rng)
	var lid := ""
	match tier:
		"royal":
			lid = royal_id
		"noble":
			var nb: Array = nobles_of(nid)
			lid = str(nb[rng.randi() % nb.size()]) if not nb.is_empty() else folk_of(nid)
		_:
			var fm: Array = nat.get("folk_mix", [])
			lid = str(fm[rng.randi() % fm.size()]) if not fm.is_empty() else folk_of(nid)
			tier = "folk"
	return _roll_result(lid, tier_of(lid), nid, rng, pool, true)

## Blood, sex, genome and lineage metadata for a rolled recruit. Pretenders get a folk genome under a
## noble/royal claim; exiles keep their house's sign no matter how thin their blood has run.
static func apply_recruit(c: Object, roll: Dictionary, rng: RandomNumberGenerator) -> void:
	c.set("blood_mix", (roll.get("blood_mix", {"common_ash": 1.0}) as Dictionary).duplicate())
	if str(roll.get("sex", "")) != "":
		c.set("gender", str(roll["sex"]))
	var meta := {}
	if str(roll.get("exile", "")) != "":
		meta["exile"] = str(roll["exile"])
	var pretend: Dictionary = roll.get("pretend", {})
	if not pretend.is_empty():
		meta["pretend"] = pretend.duplicate()
	if bool(roll.get("vouched", false)):
		meta["vouched"] = true
	c.set("blood_meta", meta)
	var true_mix: Dictionary = {str(pretend.get("true", "common_ash")): 1.0} if not pretend.is_empty() else c.get("blood_mix")
	var sex := str(c.get("gender"))
	var g := CKGenome.founder(true_mix, {}, rng, sex)
	var force := str(roll.get("force", ""))
	if force != "":
		var fs := founder_sig({force: 1.0}, sex, fork(rng, "exile"), force)
		var loc := str(nation(nation_of_line(force)).get("locus", ""))
		if fs.has(loc):
			g["sig"][loc] = fs[loc]
			if (fs["pen"] as Dictionary).has(loc):
				g["sig"]["pen"][loc] = fs["pen"][loc]
	c.set("genome", g)
	CKGenome.sync_appearance(c)

static func rank_for(roll: Dictionary, rng: RandomNumberGenerator) -> String:
	match str(roll.get("tier", "folk")):
		"royal":
			return "baron" if rng.randf() < 0.6 else "knight"
		"noble":
			return "baron" if rng.randf() < 0.45 else "knight"
	return "knight"

## Marriage offer: nation by diplomacy, tier by data. ctx: {"rep": {nid: int}, "stance": {nid: str}}.
static func roll_marriage(rng: RandomNumberGenerator, prefer_rank: String, ctx: Dictionary = {}) -> Dictionary:
	var m: Dictionary = data().get("marriage", {})
	var w := {}
	for nid in nation_ids():
		var v := 1.0 + float(ctx.get("rep", {}).get(nid, 0)) / maxf(1.0, float(m.get("rep_weight_per", 20)))
		var stance := str(ctx.get("stance", {}).get(nid, "neutral"))
		if stance == "home":
			v *= float(m.get("home_weight", 1.5))
		elif stance == "hostile":
			v *= float(m.get("hostile_weight", 0.4))
		w[str(nid)] = v
	var nid2 := _pick_weighted(w, rng)
	var tier := _pick_weighted(m.get("tier_p", {"folk": 1.0}), rng)
	var nat := nation(nid2)
	var nb: Array = nobles_of(nid2)
	var noble := str(nb[rng.randi() % nb.size()]) if not nb.is_empty() else folk_of(nid2)
	var res := {"nation": nid2, "tier": tier}
	match tier:
		"royal":
			res["line"] = str(nat.get("royal", ""))
			res["blood_mix"] = {str(nat.get("royal", "")): 0.6, noble: 0.4}
			res["rank"] = "count"
		"noble":
			res["line"] = noble
			res["blood_mix"] = {noble: 0.7, folk_of(nid2): 0.3}
			res["rank"] = prefer_rank if prefer_rank in RANKS else "baron"
		_:
			res["line"] = folk_of(nid2)
			res["blood_mix"] = {folk_of(nid2): 0.6, noble: 0.4}
			res["rank"] = "baron" if rng.randf() < 0.5 else "knight"
	return res

## Tavern blood premium. Royal claims are priced by visible proof (an unproven crown sells at half);
## folk recruits only cost more when the keeper can see a royal sign; severe edge stigma knocks a little off.
static func hire_premium(c: Object, host_nation: String = "") -> int:
	_ensure(c)
	var pr: Dictionary = data().get("pricing", {})
	var pb: String = c.call("primary_bloodline")
	var tier := tier_of(pb)
	var base := float(line(pb).get("tavern", {}).get("premium", 0))
	var e := express_nation(c.get("genome"), nation_of_line(pb), ctx_of(c))
	var total := 0.0
	match tier:
		"royal":
			var proof := float(pr.get("royal_proof", {}).get("none", 0.5))
			if e["tier"] == "royal":
				proof = float(pr.get("royal_proof", {}).get(str(e.get("visibility", "overt")), 1.0))
			total = base * proof
		"noble":
			var shown: bool = e["tier"] in ["royal", "noble"]
			total = base * float(pr.get("noble_proof", {}).get("shown" if shown else "none", 1.0))
		_:
			total = base
			for s in signatures(c, false):
				if str(s.get("visibility", "")) != "overt":
					continue
				if s["tier"] == "royal":
					total += float(pr.get("folk_bonus", {}).get("royal_overt", 40))
					break
	if tier != "royal":
		for eb in edge_blood(c):
			if int(eb["stigma"]) >= 2 and (host_nation == "" or host_nation == str(eb["nation"])):
				total -= float(pr.get("edge_discount", 8))
				break
	return maxi(0, int(round(total)))

static func salary_premium(c: Object) -> int:
	return int(data().get("tiers", {}).get(tier_of(str(c.call("primary_bloodline"))), {}).get("salary", 0))

# ── temple verification ──────────────────────────────
static func verify_cost(shrine_level: int) -> int:
	var vc: Dictionary = data().get("pricing", {}).get("verify_cost", {})
	return maxi(int(vc.get("min", 6)), int(vc.get("base", 14)) + int(vc.get("per_shrine_level", -2)) * shrine_level)

static func _has_allele(g: Dictionary, locus: String, allele: String) -> bool:
	return allele in _pair(g, locus)

## What the shrine sees: carried / shown signs, claim consistency, and parent consistency for the sex-linked,
## maternal, dose and complement laws (a sign neither parent could have passed on is a false lineage).
static func verify(c: Object, chars: Dictionary = {}) -> Dictionary:
	_ensure(c)
	var g: Dictionary = c.get("genome")
	var meta: Dictionary = c.get("blood_meta") if typeof(c.get("blood_meta")) == TYPE_DICTIONARY else {}
	var carried: Array = []
	var shown: Array = []
	var bad: Array = []
	for e in signatures(c, true):
		if e["tier"] in ["royal", "noble"]:
			shown.append(e)
		if e["tier"] == "latent" or bool(e.get("carrier", false)):
			carried.append(e)
	var pretend: Dictionary = meta.get("pretend", {})
	if not pretend.is_empty():
		var cl := str(pretend.get("claimed", ""))
		bad.append("血谱不符：所称「%s」，查无其因，实为%s" % [str(line(cl).get("name", cl)), str(line(str(pretend.get("true", ""))).get("name", ""))])
	var pids: Array = c.get("parent_ids") if typeof(c.get("parent_ids")) == TYPE_ARRAY else []
	var fa: Object = _person(str(pids[0]), chars) if pids.size() > 0 else null
	var mo: Object = _person(str(pids[1]), chars) if pids.size() > 1 else null
	var ctx := ctx_of(c)
	for e in shown:
		var nid := str(e["nation"])
		var locus := str(e["locus"])
		var law := str(e["law"])
		match law:
			"y_linked":
				if e["tier"] == "royal" and fa != null and not ("emberold" in royal_nations(fa)):
					bad.append("冒窑：冰裂之子的父亲没有冰裂")
			"x_dominant":
				var R := str(locus_def(locus).get("royal", ""))
				if e["tier"] == "royal" and fa != null and mo != null:
					var from_f: bool = ctx["sex"] == "f" and _has_allele(fa.get("genome"), locus, R)
					if not from_f and not _has_allele(mo.get("genome"), locus, R):
						bad.append("伪潮：父母都给不出这道潮痕")
			"maternal":
				if mo != null and _value(mo.get("genome"), locus) < float(locus_def(locus).get("latent_min", 0.25)):
					bad.append("伪萤：母亲没有萤光可传")
			"dose":
				if e["tier"] == "royal" and fa != null and mo != null:
					var R2 := str(locus_def(locus).get("royal", ""))
					if not _has_allele(fa.get("genome"), locus, R2) or not _has_allele(mo.get("genome"), locus, R2):
						bad.append("伪朔：全朔须父母各给一份朔因")
			"complement":
				if fa != null and mo != null:
					for al in _dip(g, locus):
						if str(al) != "none" and not _has_allele(fa.get("genome"), locus, str(al)) and not _has_allele(mo.get("genome"), locus, str(al)):
							bad.append("伪星：父母都没有这颗痣的因")
							break
	var verdict := "无冕"
	var verdict_zh := "民胤·无冕"
	if not pretend.is_empty():
		verdict = "false"
		verdict_zh = "伪胤"
	elif not bad.is_empty():
		verdict = "doubt"
		verdict_zh = "存疑"
	elif not shown.is_empty() and shown[0]["tier"] == "royal":
		verdict = "royal"
		verdict_zh = "真胤·显冕"
	elif not carried.is_empty() or not shown.is_empty():
		verdict = "carrier"
		verdict_zh = "真胤·携因"
	var tells: Dictionary = missed_tells(c)
	return {"carried": carried, "shown": shown, "contradictions": bad, "verdict": verdict, "verdict_zh": verdict_zh, "edge": edge_blood(c), "missed_tells": tells.get("alleles", []), "missed_visible": tells.get("visible", [])}

## Shrine service: records the verdict, unmasks pretenders (their blood is corrected to the true line).
static func verify_and_record(c: Object, chars: Dictionary = {}) -> Dictionary:
	var r := verify(c, chars)
	var meta: Dictionary = (c.get("blood_meta") as Dictionary).duplicate(true) if typeof(c.get("blood_meta")) == TYPE_DICTIONARY else {}
	meta["verified"] = true
	meta["verdict"] = str(r["verdict"])
	var pretend: Dictionary = meta.get("pretend", {})
	if not pretend.is_empty() and not bool(pretend.get("exposed", false)):
		pretend["exposed"] = true
		meta["pretend"] = pretend
		c.set("blood_mix", {str(pretend.get("true", "common_ash")): 1.0})
	c.set("blood_meta", meta)
	var bits: Array = []
	for e in r["shown"]:
		bits.append(str(e.get("zh", "")))
	for e in r["carried"]:
		if not (str(e.get("zh", "")) in bits):
			bits.append("携%s" % str(e.get("zh", "")))
	r["line_zh"] = "%s：%s%s" % [str(c.get("name")), str(r["verdict_zh"]), ("（" + "、".join(bits) + "）") if not bits.is_empty() else ""]
	var missed: Array = r.get("missed_tells", [])
	if not missed.is_empty():
		r["line_zh"] += " 缺隐征：" + "、".join(missed)
	return r

# ── skills, births ───────────────────────────────────
## Royal skills follow the shown sign, not blood purity: they appear on awakening and leave if the sign is gone.
static func sync_signature_skills(c: Object) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs == null:
		return
	var shown := royal_nations(c)
	var sk: Array = c.get("skills")
	for s in gs.data_skills.get("skills", []):
		var nid := str(s.get("blood_sig", ""))
		if nid == "":
			continue
		var sid := str(s.get("id", ""))
		if nid in shown and not (sid in sk):
			sk.append(sid)
		elif not (nid in shown) and sid in sk:
			sk.erase(sid)

static func on_birth(child: Object, father: Object, mother: Object) -> Array:
	var out: Array = []
	var nm := str(child.get("name"))
	var royals: Array = []
	for e in signatures(child, false):
		if e["tier"] == "royal":
			royals.append(str(e.get("zh", "")))
	if royals.size() >= 2:
		out.append("双冕：%s 生而同时显出「%s」与「%s」。" % [nm, royals[0], royals[1]])
	elif royals.size() == 1:
		out.append("显冕：%s 生而带「%s」。" % [nm, royals[0]])
	var ctx := ctx_of(child)
	if father != null and "emberold" in royal_nations(father) and ctx["sex"] == "f":
		out.append("窑女：%s 承父之血，却注定不承冰裂。" % nm)
	if ctx["sex"] == "m":
		var gl := express_nation(child.get("genome"), "southzephyr", ctx)
		if gl["tier"] == "royal":
			out.append("萤子：%s 生而发光，萤光止于他这一代。" % nm)
	for eb in edge_blood(child):
		if str(eb["name"]) != "" and str(eb["name"]) != "—":
			out.append("%s 有%s之血而无其征，人称「%s」。" % [nm, str(line(str(eb["line"])).get("name", "")), str(eb["name"])])
			break
	return out.slice(0, 2)

## 旗誓: when Ashbanner relations reach 盟誓 the leader swears the banner oath (the Ash Seat's deed honor).
static func on_nation_milestone(nid: String, tier: int) -> String:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs == null or nid != "ashbanner" or tier < 4:
		return ""
	var leader = gs.get_leader()
	if leader == null or "banner_oath" in leader.honors:
		return ""
	leader.honors.append("banner_oath")
	gs.grant_job_skills(leader)
	var awake: bool = "ashbanner" in royal_nations(leader)
	var txt := "旗誓既成：%s 在烬都立誓护旗。%s" % [leader.name, "颈侧河图纹燃起，可入议会公推。" if awake else "此身无河图之因，誓言只记入族谱。"]
	gs.lineage_log.append(txt)
	gs.log_event(txt)
	return txt

## Same-house carrier mark for the 灰旗 founder: half a River Chart, waiting for a deed to wake it.
static func seed_house_carrier(c: Object) -> void:
	_ensure(c)
	var g: Dictionary = c.get("genome")
	if g.has("sig"):
		g["sig"]["sig_ashbanner"] = ["river_chart", "none"]

## Fixtures / debug: write the canonical genotype for a nation's royal, noble or latent sign into a genome.
static func force_tier(g: Dictionary, nid: String, tier: String, sex: String) -> void:
	var locus := str(nation(nid).get("locus", ""))
	var ld := locus_def(locus)
	if not g.has("sig"):
		g["sig"] = {"pen": {}}
	var s: Dictionary = g["sig"]
	if not s.has("pen"):
		s["pen"] = {}
	var R := str(ld.get("royal", ""))
	var N := str(ld.get("noble", ""))
	var law := str(ld.get("law", ""))
	match law:
		"threshold", "maternal":
			s[locus] = {"royal": 0.86, "noble": 0.55, "latent": float(ld.get("latent_min", 0.4)) + 0.02}.get(tier, 0.05)
		"y_linked":
			s[locus] = ([R] if tier == "royal" else ["none"]) if sex == "m" else []
			if tier == "noble" and g.has("loci"):
				g["loci"]["mark"] = ["ember_sigil", "ember_sigil"]
		"x_dominant":
			var a := R if tier == "royal" else (N if tier == "noble" else "none")
			s[locus] = [a, "-"] if sex == "m" else [a, a]
		"complement":
			var pr: Array = ld.get("pair", [])
			s[locus] = [str(pr[0]), str(pr[1])] if tier == "royal" else ([str(pr[0]), str(pr[0])] if tier == "noble" else ["none", "none"])
		"dose":
			s[locus] = {"royal": [R, R], "noble": [R, "none"]}.get(tier, ["none", "none"])
		_:
			s[locus] = {"royal": [R, R], "noble": [N, "none"], "latent": [R, "none"]}.get(tier, ["none", "none"])
	if law == "penetrance":
		s["pen"][locus] = 0.1 if tier == "royal" else 0.9

# ── heir forecast ─────────────────────────────────────
static func _ncdf(x: float) -> float:
	var t := 1.0 / (1.0 + 0.3275911 * absf(x) / sqrt(2.0))
	var y := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x / 2.0)
	return 0.5 * (1.0 + (y if x >= 0.0 else -y))

static func _child_pairs(fg: Dictionary, mg: Dictionary, locus: String, kind: String, sex: String) -> Array:
	var out: Array = []
	match kind:
		"y":
			var fy := _pair(fg, locus)
			out.append([[str(fy[0]) if fy.size() > 0 else "none"] if sex == "m" else [], 1.0])
		"x":
			var mx := _x_of(mg, locus)
			if str(mx[1]) == "-":
				mx[1] = mx[0]
			var fx := str(_x_of(fg, locus)[0])
			for a in mx:
				out.append([[str(a), "-"] if sex == "m" else [fx, str(a)], 0.5])
		_:
			var fp := _dip(fg, locus)
			var mp := _dip(mg, locus)
			for a in fp:
				for b in mp:
					out.append([[str(a), str(b)], 0.25])
	return out

## Per-nation odds for a child of father x mother: royal / noble / carrier, by sex where the law cares.
static func forecast(father: Object, mother: Object) -> Array:
	_ensure(father)
	_ensure(mother)
	var fg: Dictionary = father.get("genome")
	var mg: Dictionary = mother.get("genome")
	var blood := {}
	for src in [father.get("blood_mix"), mother.get("blood_mix")]:
		for k in (src as Dictionary).keys():
			blood[k] = float(blood.get(k, 0.0)) + 0.5 * float(src[k])
	var rows: Array = []
	for nid in nation_ids():
		var locus := str(nation(nid).get("locus", ""))
		var ld := locus_def(locus)
		var law := str(ld.get("law", ""))
		var kind := str(ld.get("kind", "diploid"))
		var by_sex := {}
		for sex in ["f", "m"]:
			var p := {"royal": 0.0, "noble": 0.0, "carrier": 0.0}
			if kind == "value":
				var mu := _value(mg, locus)
				var sd := float(ld.get("drift", 0.07))
				if law == "threshold":
					var mid := 0.5 * (_value(fg, locus) + _value(mg, locus))
					mu = mid + float(ld.get("regress", 0.15)) * (line_mean(blood, locus) - mid)
					sd = float(ld.get("noise", 0.06))
				var pr := 1.0 - _ncdf((float(ld.get("royal_min", 0.7)) - mu) / sd)
				var pn := 1.0 - _ncdf((float(ld.get("noble_min", 0.45)) - mu) / sd) - pr
				var pl := 1.0 - _ncdf((float(ld.get("latent_min", 0.4)) - mu) / sd) - pr - pn
				p["royal"] = pr
				p["noble"] = pn
				p["carrier"] = pl
			else:
				for row in _child_pairs(fg, mg, locus, kind, sex):
					var tmp := {"loci": {"mark": ["none", "none"]}, "sig": {locus: row[0], "pen": {locus: 0.0}}}
					var e := express_nation(tmp, nid, {"sex": sex, "rank": 0, "honors": []})
					var w := float(row[1])
					if e["tier"] == "royal":
						var pen := float(ld.get("penetrance", 1.0))
						p["royal"] += w * pen
						p["carrier"] += w * (1.0 - pen)
					elif e["tier"] == "noble":
						p["noble"] += w
					if e["tier"] == "latent" or (bool(e.get("carrier", false)) and e["tier"] != "royal"):
						p["carrier"] += w
			by_sex[sex] = p
		var f: Dictionary = by_sex["f"]
		var m: Dictionary = by_sex["m"]
		var royal_avg := 0.5 * (float(f["royal"]) + float(m["royal"]))
		var any := royal_avg + 0.5 * (float(f["noble"]) + float(m["noble"]) + float(f["carrier"]) + float(m["carrier"]))
		if any < 0.005:
			continue
		var states: Dictionary = ld.get("states", {})
		rows.append({"nation": nid, "law": law, "law_zh": str(data().get("laws", {}).get(law, {}).get("name", "")),
			"royal_zh": str(signature_def(str(states.get("royal", ""))).get("zh", "")),
			"royal_f": float(f["royal"]), "royal_m": float(m["royal"]), "royal": royal_avg,
			"noble": 0.5 * (float(f["noble"]) + float(m["noble"])), "carrier": 0.5 * (float(f["carrier"]) + float(m["carrier"])),
			"needs_deed": law == "awakened"})
	rows.sort_custom(func(a, b): return float(a["royal"]) + float(a["carrier"]) * 0.5 > float(b["royal"]) + float(b["carrier"]) * 0.5)
	return rows

## Read-only heir odds for the trait loci. Same pairing rules as forecast(); no RNG, no balance change.
static func trait_odds(father: Object, mother: Object) -> Array:
	_ensure(father)
	_ensure(mother)
	var fg: Dictionary = father.get("genome") if typeof(father.get("genome")) == TYPE_DICTIONARY else {}
	var mg: Dictionary = mother.get("genome") if typeof(mother.get("genome")) == TYPE_DICTIONARY else {}
	var blood := {}
	for src in [father.get("blood_mix"), mother.get("blood_mix")]:
		if typeof(src) != TYPE_DICTIONARY:
			continue
		for k in (src as Dictionary).keys():
			blood[k] = float(blood.get(k, 0.0)) + 0.5 * float(src[k])
	var rows: Array = []
	for locus_v in trait_order():
		var locus := str(locus_v)
		var ld := locus_def(locus)
		if ld.is_empty():
			continue
		var law := str(ld.get("law", ""))
		var kind := str(ld.get("kind", "diploid"))
		var by_sex := {}
		for sex in ["f", "m"]:
			var p := {"royal": 0.0, "noble": 0.0, "carrier": 0.0}
			if kind == "value":
				var mu := _value(mg, locus)
				var sd := float(ld.get("drift", 0.07))
				if law == "threshold":
					var mid := 0.5 * (_value(fg, locus) + _value(mg, locus))
					mu = mid + float(ld.get("regress", 0.15)) * (line_mean(blood, locus) - mid)
					sd = float(ld.get("noise", 0.06))
				var pr := 1.0 - _ncdf((float(ld.get("royal_min", 0.7)) - mu) / maxf(sd, 0.001))
				var pn := 1.0 - _ncdf((float(ld.get("noble_min", 0.45)) - mu) / maxf(sd, 0.001)) - pr
				var pl := 1.0 - _ncdf((float(ld.get("latent_min", 0.4)) - mu) / maxf(sd, 0.001)) - pr - pn
				p["royal"] = pr
				p["noble"] = pn
				p["carrier"] = pl
			else:
				for row in _child_pairs(fg, mg, locus, kind, sex):
					var tmp := {"loci": {"mark": ["none", "none"]}, "sig": {locus: row[0], "pen": {locus: 0.0}}}
					var e := express_trait(tmp, locus, {"sex": sex, "rank": 0, "honors": [], "age": 30})
					var w := float(row[1])
					if e["tier"] == "royal":
						var pen := float(ld.get("penetrance", 1.0))
						p["royal"] += w * pen
						p["carrier"] += w * (1.0 - pen)
					elif e["tier"] == "noble":
						p["noble"] += w
					if e["tier"] == "latent" or (bool(e.get("carrier", false)) and e["tier"] != "royal"):
						p["carrier"] += w
			by_sex[sex] = p
		var f: Dictionary = by_sex["f"]
		var m: Dictionary = by_sex["m"]
		var shown := 0.5 * (float(f["royal"]) + float(m["royal"]) + float(f["noble"]) + float(m["noble"]))
		var carried := 0.5 * (float(f["carrier"]) + float(m["carrier"]))
		if shown + carried < 0.02:
			continue
		var states: Dictionary = ld.get("states", {})
		var zh := str(signature_def(str(states.get("royal", ""))).get("zh", ""))
		if zh == "":
			zh = str(signature_def(str(states.get("noble", ""))).get("zh", locus))
		rows.append({
			"locus": locus, "law": law,
			"law_zh": str(data().get("laws", {}).get(law, {}).get("name", law)),
			"punnett": str(data().get("laws", {}).get(law, {}).get("punnett", "")),
			"zh": zh,
			"shown": shown, "carrier": carried,
			"shown_f": float(f["royal"]) + float(f["noble"]),
			"shown_m": float(m["royal"]) + float(m["noble"]),
		})
	rows.sort_custom(func(a, b): return float(a["shown"]) + float(a["carrier"]) * 0.4 > float(b["shown"]) + float(b["carrier"]) * 0.4)
	return rows

static func forecast_zh(father: Object, mother: Object, limit: int = 2) -> String:
	var bits: Array = []
	for r in forecast(father, mother).slice(0, limit):
		var zh := str(r["royal_zh"])
		if bool(r["needs_deed"]):
			bits.append("%s 携因 %d%%（须立功觉醒）" % [zh, int(round((float(r["carrier"]) + float(r["royal"])) * 100))])
		elif absf(float(r["royal_f"]) - float(r["royal_m"])) > 0.05:
			bits.append("%s 女 %d%% · 男 %d%%" % [zh, int(round(float(r["royal_f"]) * 100)), int(round(float(r["royal_m"]) * 100))])
		else:
			bits.append("%s %d%%" % [zh, int(round(float(r["royal"]) * 100))])
	return "冕征预期：" + ("；".join(bits) if not bits.is_empty() else "无")

# ── multi-trait set (appended loci; does not feed succession or tavern price) ──
static func expressed_traits(c: Object, include_latent: bool = false) -> Array:
	_ensure(c)
	var g: Dictionary = c.get("genome") if typeof(c.get("genome")) == TYPE_DICTIONARY else {}
	var ctx := ctx_of(c)
	var out: Array = []
	for locus in trait_order():
		var e := express_trait(g, locus, ctx)
		if str(e["tier"]) == "none":
			continue
		if str(e["tier"]) == "latent" and not include_latent:
			continue
		out.append(e)
	return out

static func _age_word(age: int) -> String:
	return CKGenomePortrait.stage_for_age(age)

## Young copy before the trait is grown, the prime line in youth and middle age, the elder line last.
## Age-awakened traits never reach this function before their age_min, because they stay latent.
static func trait_prompt(state: String, age: int) -> String:
	var sd := signature_def(state)
	var stage := _age_word(age)
	var young := str(sd.get("prompt_young", ""))
	if young == "":
		young = str(sd.get("prompt", ""))
	var prime := str(sd.get("prompt", ""))
	var elder := str(sd.get("prompt_elder", ""))
	if elder == "":
		elder = prime
	match stage:
		"infant":
			return ("only a faint infant hint of " + young) if young != "" else ""
		"youth":
			return young
		"middle":
			return (prime + ", a little deeper in middle age") if prime != "" else ""
		"elder":
			return elder
		_:
			return prime

## Canonical genotypes for tests and full-line portraits. mode: full / carrier / clear / noble.
## Pure-line expression stays off unless include_pure, because it is rare.
static func stamp_traits(g: Dictionary, nid: String, mode: String, sex: String, include_pure: bool = false) -> void:
	if typeof(g) != TYPE_DICTIONARY:
		return
	if typeof(g.get("sig")) != TYPE_DICTIONARY:
		g["sig"] = {"pen": {}}
	var s: Dictionary = g["sig"]
	if typeof(s.get("pen")) != TYPE_DICTIONARY:
		s["pen"] = {}
	for locus in trait_order():
		var ld := locus_def(locus)
		if str(ld.get("nation", "")) != nid or str(ld.get("scope", "")) != "royal":
			continue
		var use := mode
		if str(ld.get("law", "")) == "pureblood" and mode == "full" and not include_pure:
			use = "clear"
		_write_stamp(s, locus, ld, use, sex)

static func _write_stamp(s: Dictionary, locus: String, ld: Dictionary, mode: String, sex: String) -> void:
	var kind := str(ld.get("kind", "diploid"))
	var R := str(ld.get("royal", ""))
	var N := str(ld.get("noble", ""))
	var law := str(ld.get("law", ""))
	if kind == "value":
		s[locus] = {"full": 0.92, "noble": 0.56, "carrier": float(ld.get("latent_min", 0.4)) + 0.02, "clear": 0.02}.get(mode, 0.02)
		return
	var pair: Array = ["none", "none"]
	if mode == "full":
		pair = [R, R]
	elif mode == "carrier":
		pair = [R, "none"]
	elif mode == "noble":
		pair = [N if N != "" else "none", "none"]
	if kind == "x":
		s[locus] = [pair[0], "-"] if sex == "m" else pair
	elif kind == "y":
		s[locus] = [pair[0]] if sex == "m" else []
	else:
		s[locus] = pair
	if law == "penetrance":
		s["pen"][locus] = 0.05 if mode == "full" else 0.99

static func battle_bark(c: Object) -> String:
	for t in expressed_traits(c, false):
		if str(t.get("slot", "")) != "bearing":
			continue
		var bark := str(signature_def(str(t.get("state", ""))).get("bark", ""))
		if bark != "":
			return bark
	return ""

## Palette hexes and regalia module ids only. No meshes. Pretenders and paper patents stay empty.
static func unit_model_hints(c: Object) -> Dictionary:
	var out := {"palette": {}, "regalia_modules": [], "bark_zh": ""}
	if c == null:
		return out
	out["bark_zh"] = battle_bark(c)
	for t in expressed_traits(c, false):
		if str(t.get("slot", "")) != "regalia":
			continue
		var sd := signature_def(str(t.get("state", "")))
		if typeof(sd.get("palette")) == TYPE_DICTIONARY and not (sd["palette"] as Dictionary).is_empty():
			out["palette"] = sd["palette"]
		for m in sd.get("modules", []):
			out["regalia_modules"].append(str(m))
	return out

## Subtle catch-traits a claimed royal line should carry. Alleles are what the shrine reads;
## visible misses are what a perceptive NPC can see are absent.
static func missed_tells(c: Object) -> Dictionary:
	var empty := {"alleles": [], "visible": []}
	_ensure(c)
	var meta: Dictionary = c.get("blood_meta") if typeof(c.get("blood_meta")) == TYPE_DICTIONARY else {}
	var pretend: Dictionary = meta.get("pretend", {})
	var claimed := ""
	if not pretend.is_empty() and not bool(pretend.get("exposed", false)):
		claimed = str(pretend.get("claimed", ""))
	else:
		var pb: String = c.call("primary_bloodline") if c.has_method("primary_bloodline") else ""
		if tier_of(pb) == "royal":
			claimed = pb
	if claimed == "" or tier_of(claimed) != "royal":
		return empty
	var nid := nation_of_line(claimed)
	var g: Dictionary = c.get("genome") if typeof(c.get("genome")) == TYPE_DICTIONARY else {}
	var ctx := ctx_of(c)
	var alleles: Array = []
	var visible: Array = []
	for sid in nation(nid).get("catch_traits", []):
		var sd := signature_def(str(sid))
		var locus := str(sd.get("locus", ""))
		if locus == "":
			continue
		var ld := locus_def(locus)
		var carried := false
		if str(ld.get("kind", "")) == "value":
			carried = _value(g, locus) >= float(ld.get("latent_min", 0.4))
		else:
			carried = _has_allele(g, locus, str(ld.get("royal", "")))
		var e := express_trait(g, locus, ctx)
		var shown := str(e.get("state", "")) == str(sid) and str(e.get("tier", "")) != "none" and str(e.get("tier", "")) != "latent"
		var zh := str(sd.get("zh", sid))
		if not carried:
			alleles.append(zh)
		if not shown:
			visible.append(zh)
	return {"alleles": alleles, "visible": visible}

static func observe_zh(c: Object, level: int = -1) -> String:
	if level < 0:
		level = inspect_level()
	if level < 1:
		return ""
	var vis: Array = missed_tells(c).get("visible", [])
	if vis.is_empty():
		return ""
	return "近看缺隐征：" + "、".join(vis)

# ── Plan A portrait clause (registered on CKGenomePortrait) ─────────────────────
static func _parents_of(c: Object) -> Array:
	var pids: Array = c.get("parent_ids") if typeof(c.get("parent_ids")) == TYPE_ARRAY else []
	var chars: Dictionary = {}
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs != null:
		chars = gs.characters
	var fa: Object = _person(str(pids[0]), chars) if pids.size() > 0 else null
	var mo: Object = _person(str(pids[1]), chars) if pids.size() > 1 else null
	return [fa, mo]

## "the Iron Gorge royal line" for a parent, from their primary bloodline
static func _line_en(c: Object) -> String:
	var pb: String = c.call("primary_bloodline") if c.has_method("primary_bloodline") else ""
	if not has_line(pb):
		return ""
	return "the %s %s line" % [str(nation(nation_of_line(pb)).get("name_en", "")), {"royal": "royal", "noble": "noble", "folk": "common"}.get(tier_of(pb), "common")]

## The bloodline clause of the Plan A prompt: shown signs, forgery tells, regional styling, regalia or its
## absence, and for heirs which parent's line each sign and visible trait came from.
static func portrait_clause(c: Object) -> String:
	_ensure(c)
	var parts: Array = []
	for e in signatures(c, false):
		var sd := signature_def(str(e.get("state", "")))
		var pr := str(sd.get("prompt", ""))
		if pr != "":
			parts.append(pr)
	var age_i := int(c.get("age"))
	var stage := _age_word(age_i)
	var by_nat := {}
	var nat_order: Array = []
	for t in expressed_traits(c, false):
		var tn := str(t.get("nation", ""))
		var bit := trait_prompt(str(t.get("state", "")), age_i)
		if bit == "":
			continue
		if not by_nat.has(tn):
			by_nat[tn] = []
			nat_order.append(tn)
		(by_nat[tn] as Array).append(bit)
	for tn in nat_order:
		var bits: Array = by_nat[tn]
		if bits.is_empty():
			continue
		parts.append("%s trait set, %s: %s" % [str(nation(tn).get("name_en", tn)), stage, "; ".join(bits)])
	if nat_order.size() >= 2:
		parts.append("mixed blood, both houses visible on the same face")
	if not nat_order.is_empty():
		parts.append("matte technical cloth, frosted metal, cool white key light, a small mint stitch at most")
	var meta: Dictionary = c.get("blood_meta") if typeof(c.get("blood_meta")) == TYPE_DICTIONARY else {}
	var pb: String = c.call("primary_bloodline") if c.has_method("primary_bloodline") else ""
	var pnat := nation_of_line(pb)
	var pretend: Dictionary = meta.get("pretend", {})
	if not pretend.is_empty() and not bool(pretend.get("exposed", false)):
		var fp := str(nation(nation_of_line(str(pretend.get("claimed", "")))).get("forgery", {}).get("prompt", ""))
		if fp != "":
			parts.append(fp)
	var look := str(line(pb).get("look", ""))
	if look != "":
		parts.append(look)
	var honors: Array = c.get("honors") if typeof(c.get("honors")) == TYPE_ARRAY else []
	var paper: Dictionary = nation("lantern").get("paper", {})
	if str(paper.get("honor", "paper_patent")) in honors:
		parts.append(str(paper.get("prompt", "")))
	elif str(meta.get("exile", "")) != "":
		parts.append("travel-worn clothes without any house insignia")
	elif tier_of(pb) in ["royal", "noble"] and RANKS.find(str(c.get("rank"))) >= 1 and pnat != "":
		var rg := str(nation(pnat).get("regalia", ""))
		if rg != "":
			parts.append(rg)
	var heir := _heir_clause(c)
	if heir != "":
		parts.append(heir)
	if parts.is_empty():
		return ""
	return "Bloodline: " + "; ".join(parts) + "."

static func _heir_clause(c: Object) -> String:
	var ps := _parents_of(c)
	var fa: Object = ps[0]
	var mo: Object = ps[1]
	if fa == null and mo == null:
		return ""
	var who: Array = []
	if fa != null and _line_en(fa) != "":
		who.append("a father from %s" % _line_en(fa))
	if mo != null and _line_en(mo) != "":
		who.append("a mother from %s" % _line_en(mo))
	var from: Array = []
	for e in signatures(c, false):
		var nid := str(e["nation"])
		var zh_en := str(signature_def(str(e.get("state", ""))).get("name_en", ""))
		var src := ""
		var law := str(e["law"])
		if law == "maternal":
			src = "mother"
		elif law == "y_linked":
			src = "father"
		else:
			var f_has := fa != null and _parent_has(fa, nid)
			var m_has := mo != null and _parent_has(mo, nid)
			src = "both parents" if f_has and m_has else ("father" if f_has else ("mother" if m_has else ""))
		if src != "" and zh_en != "":
			from.append("the %s from the %s" % [zh_en, src if src == "both parents" else src + "'s line"])
	var trait_word := {"hair": "hair colour", "eyes": "eye colour", "brow": "brow shape"}
	for locus in ["hair", "eyes", "brow"]:
		var mine := str(CKGenome.express(c.get("genome"), locus).get("id", ""))
		var f_id := str(CKGenome.express(fa.get("genome"), locus).get("id", "")) if fa != null else ""
		var m_id := str(CKGenome.express(mo.get("genome"), locus).get("id", "")) if mo != null else ""
		if mine == f_id and mine != m_id:
			from.append("the father's %s" % trait_word[locus])
		elif mine == m_id and mine != f_id:
			from.append("the mother's %s" % trait_word[locus])
	var s := "heir of " + " and ".join(who) if not who.is_empty() else "heir of the house"
	if not from.is_empty():
		s += ", with " + ", ".join(from)
	return s + ", a clear family resemblance"

static func _parent_has(p: Object, nid: String) -> bool:
	_ensure(p)
	var e := express_nation(p.get("genome"), nid, ctx_of(p))
	return e["tier"] != "none" or bool(e.get("carrier", false))
