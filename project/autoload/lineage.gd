extends Node
## 联姻 · 血胤 · 遗传 · 子嗣期望（X1/X2）

const _Ambitions := preload("res://scripts/characters/ambitions.gd")


func _ready() -> void:
	Calendar.register("post", Callable(_Ambitions, "on_month"), 80)

const REP_RANK_NEED := {
	"knight": "known",
	"baron": "friendly",
	"viscount": "trusted",
	"count": "trusted",
	"duke": "respected",
}
const REP_ORDER := ["none", "known", "friendly", "trusted", "respected"]
const REP_NAMES := {
	"none": "陌生", "known": "认识", "friendly": "友善",
	"trusted": "信赖", "respected": "尊敬",
}

func can_propose(suitor: CKCharacter, target: CKCharacter, realm: String = "ashland") -> Dictionary:
	var need = REP_RANK_NEED.get(target.rank, "known")
	var have = GameState.get_rep_tier(realm)
	var need_i = REP_ORDER.find(need)
	var have_i = REP_ORDER.find(have)
	if have_i < need_i:
		var missing: Array = []
		for i in range(have_i + 1, need_i + 1):
			missing.append(REP_NAMES[REP_ORDER[i]])
		return {
			"ok": false,
			"need": need,
			"have": have,
			"msg": Locale.t("not_enough_rep", [" → ".join(missing)]),
		}
	if suitor.spouse_id != "" or target.spouse_id != "":
		return {"ok": false, "msg": "已有配偶（MVP 不可重婚）"}
	if not suitor.alive or not target.alive:
		return {"ok": false, "msg": "当事人不在"}
	var bar := CKBloodline.marriage_barrier(suitor, target, GameState.characters)
	if bar != "":
		return {"ok": false, "need": need, "have": have, "msg": bar}
	return {"ok": true, "need": need, "have": have, "msg": "可表白"}

## accepted_rites == null keeps the old vow (smoke / full-chain). An explicit list gates 入牒礼 / 从母居 / 萤约 / 携霜契.
func marry(suitor: CKCharacter, target: CKCharacter, bride_price: int = 40, accepted_rites = null, paced: bool = false) -> Dictionary:
	var check = can_propose(suitor, target)
	if not check.get("ok", false):
		return check
	var rite_cost := 0
	if accepted_rites is Array:
		var block := CKCourt.rite_block(suitor, target, accepted_rites)
		if block != "":
			return {"ok": false, "msg": block}
		for r in CKCourt.required_rites(suitor, target):
			if str(r.get("id", "")) in accepted_rites:
				rite_cost += int(r.get("cost", 0))
	if GameState.silver < bride_price + rite_cost:
		return {"ok": false, "msg": Locale.t("not_enough_silver")}
	GameState.silver -= bride_price + rite_cost
	suitor.spouse_id = target.id
	target.spouse_id = suitor.id
	# 婚宴声望
	GameState.add_rep("ashland", 8)
	GameState.add_rep("riverland", 4)
	# 配偶入家族（不入战花名册除非已招募）
	if not GameState.characters.has(target.id):
		target.in_roster = false
		GameState.characters[target.id] = target
	# v8.9 联姻外交：配偶血胤所属之国的邦交，灯市嫁妆
	var fx := CKBloodline.marriage_effects(suitor, target)
	var dip: Array = []
	for nid in fx.rep.keys():
		World.add_nation_rep(str(nid), int(fx.rep[nid]))
		dip.append("%s%+d" % [World.nations.get(str(nid), {}).get("name", nid), int(fx.rep[nid])])
	if int(fx.dowry) > 0:
		GameState.silver += int(fx.dowry)
		dip.append("嫁妆 %d 银" % int(fx.dowry))
	if accepted_rites is Array:
		CKCourt.apply_rites(suitor, target, accepted_rites)
		if rite_cost > 0:
			dip.append("婚仪 %d 银" % rite_cost)
	# Seed 91's century sim calls marry() and must keep the old 2-tick countdown
	# with no extra draw. Player weddings pass paced=true for the 3-month term.
	var mother = target if target.gender == "f" else suitor
	var conceived := true
	var due := 2
	if paced:
		conceived = CKFamilyState.begin_pregnancy(GameState, mother)
		due = CKFamilyState.term_months(GameState)
	else:
		mother.pregnant_months = 1
	GameState.chapter0_flags["married"] = true
	GameState.mark_dirty()
	var dip_s := ("邦交 " + "、".join(dip) + "。") if not dip.is_empty() else ""
	var joy := Locale.t("fertility_none", [mother.name])
	if conceived:
		joy = Locale.t("fertility_due", [mother.name, due])
	return {"ok": true, "msg": "婚宴已成，声望小增。%s%s" % [dip_s, joy]}

## 子嗣期望面板（X1）
func heir_expectation(a: CKCharacter, b: CKCharacter) -> Dictionary:
	var mix = _mix_blood(a.blood_mix, b.blood_mix)
	var apt = _expected_apt(mix)
	var trait_probs = _trait_probs(a, b)
	var look_probs = _appearance_probs(a, b)
	var father: CKCharacter = b if a.gender == "f" and b.gender == "m" else a
	var mother: CKCharacter = a if father == b else b
	var combat: Dictionary = CKFamilyState.combat_expectation(a, b)
	return {
		"blood_mix": mix,
		"apt_min": apt["min"],
		"apt_max": apt["max"],
		"trait_probs": trait_probs,
		"appearance_probs": look_probs,
		"rank_hint": _child_rank(a, b),
		"sig_probs": CKBloodline.forecast(father, mother),
		"sig_zh": CKBloodline.forecast_zh(father, mother),
		"combat": combat,
		"apt_zh": str(combat.get("apt_zh", "")),
		"tactics": combat.get("tactics", []),
		"royal_tiers": combat.get("royal_tiers", []),
	}

func birth_child(mother: CKCharacter) -> CKCharacter:
	var father_id = mother.spouse_id
	var father: CKCharacter = GameState.characters.get(father_id)
	if father == null:
		father = GameState.get_leader()
	var child := CKCharacter.new()
	child.id = CharacterFactory.next_id("child")
	var rng = GameState.rng
	child.gender = "m" if rng.randf() < 0.5 else "f"
	var given_list = GameState.data_names.get("given_m" if child.gender == "m" else "given_f", ["旗嗣"])
	child.name = GameState.surname + given_list[rng.randi() % given_list.size()]
	child.age = 0
	child.is_child = true
	child.in_roster = false
	child.birthday_month = Calendar.month
	child.parent_ids = [father.id if father else "", mother.id]
	child.blood_mix = _mix_blood(
		father.blood_mix if father else {"common_ash": 1.0},
		mother.blood_mix
	)
	var apt = _expected_apt(child.blood_mix)
	child.apt_min = apt["min"]
	child.apt_max = apt["max"]
	# 实际六维：lerp 区间中段 + 突变
	child.stats = {}
	for k in CKCharacter.STAT_KEYS:
		var mid = int((child.apt_min[k] + child.apt_max[k]) / 2)
		var mut = rng.randi_range(-2, 2)
		if bool(GameState.house_mods.get("vow_prayer", false)) and k == "wil":
			mut += 1
			child.apt_max[k] = mini(20, int(child.apt_max[k]) + 1)
		# 早教路径偏向（未授旗前可选）
		var path = str(GameState.lineage_path.get(child.id, ""))
		if path == "martial" and k in ["str", "vit"]:
			mut += 1
		elif path == "scholar" and k in ["wil", "per"]:
			mut += 1
		elif path == "merchant" and k in ["agi", "skl"]:
			mut += 1
		child.stats[k] = clampi(mid + mut, child.apt_min[k], child.apt_max[k])
	child.traits = _inherit_traits(father, mother, rng)
	# 粮饷不足负面
	if GameState.morale < 40 or GameState.food < 5:
		if rng.randf() < 0.55 and "malnourished" not in child.traits:
			child.traits.append("malnourished")
			GameState.log_event("儿童因粮饷紧张获得禀性：营养不良")
	# v8.7 genome: Mendelian loci (recessives can skip a generation) + polygenic face/body (family resemblance)
	mother.ensure_genome()
	if father:
		father.ensure_genome()
	child.genome = CKGenome.cross(father.genome if father else mother.genome, mother.genome, child.blood_mix, rng, child.gender)
	CKGenome.sync_appearance(child)
	CKBloodFusion.apply_birth(child)
	for note in CKBloodline.on_birth(child, father, mother):
		GameState.lineage_log.append(note)
		GameState.log_event(note)
	for note in CKCourt.stamp_child(child, father, mother):
		GameState.lineage_log.append(note)
		GameState.log_event(note)
	child.rank = _child_rank(father if father else mother, mother)
	child.job_id = "light_inf"
	child.recalc_hp()
	GameState.characters[child.id] = child
	mother.children_ids.append(child.id)
	if father:
		father.children_ids.append(child.id)
	GameState.chapter0_flags["child_born"] = true
	GameState.log_event("初啼入谱：%s。血胤 %s。族谱新页已开，旅馆闲话会传『灰旗有后』。" % [child.name, child.bloodline_display()])
	GameState.mark_dirty()
	return child

func _mix_blood(a: Dictionary, b: Dictionary) -> Dictionary:
	var keys: Dictionary = {}
	for k in a.keys():
		keys[k] = true
	for k in b.keys():
		keys[k] = true
	var out := {}
	var total := 0.0
	for k in keys.keys():
		var w = float(a.get(k, 0)) * 0.5 + float(b.get(k, 0)) * 0.5
		out[k] = w
		total += w
	if total <= 0:
		return {"common_ash": 1.0}
	for k in out.keys():
		out[k] = out[k] / total
	return out

func _expected_apt(mix: Dictionary) -> Dictionary:
	var amin := {}
	var amax := {}
	for k in CKCharacter.STAT_KEYS:
		amin[k] = 0.0
		amax[k] = 0.0
	var tw := 0.0
	for bl_id in mix.keys():
		var w = float(mix[bl_id])
		tw += w
		var bl = GameState.get_bloodline(bl_id)
		for k in CKCharacter.STAT_KEYS:
			amin[k] += float(bl.get("stat_min", {}).get(k, 4)) * w
			amax[k] += float(bl.get("stat_max", {}).get(k, 14)) * w
	if tw <= 0:
		tw = 1.0
	var out_min := {}
	var out_max := {}
	for k in CKCharacter.STAT_KEYS:
		out_min[k] = int(round(amin[k] / tw))
		out_max[k] = int(round(amax[k] / tw))
	return {"min": out_min, "max": out_max}

func _trait_probs(a: CKCharacter, b: CKCharacter) -> Array:
	var weights: Dictionary = {}
	for tid in a.traits:
		weights[tid] = weights.get(tid, 0.0) + 0.55
	for tid in b.traits:
		weights[tid] = weights.get(tid, 0.0) + 0.55
	# 库内通用正向小概率
	for t in GameState.data_traits.get("traits", []):
		var id = t["id"]
		if id not in weights and t.get("polarity") == "pos":
			weights[id] = 0.12 * float(t.get("weight", 1.0))
	var arr: Array = []
	for id in weights.keys():
		var tr = GameState.get_trait(id)
		arr.append({
			"id": id,
			"name": tr.get("name", id),
			"prob": clampf(float(weights[id]), 0.0, 0.95),
		})
	arr.sort_custom(func(x, y): return x["prob"] > y["prob"])
	return arr.slice(0, mini(8, arr.size()))

func _appearance_probs(a: CKCharacter, b: CKCharacter) -> Dictionary:
	# v8.7: exact Punnett squares from the genomes (shows recessive returns the old 45/45 table could not)
	a.ensure_genome()
	b.ensure_genome()
	var pun := {}
	var alleles_all: Dictionary = GameState.data_appearance.get("alleles", {})
	for key in ["hair", "eyes", "brow"]:
		var rows: Array = []
		for e in CKGenome.punnett(a.genome, b.genome, key):
			var nm := str(e["id"])
			for al in alleles_all.get(key, []):
				if al["id"] == e["id"]:
					nm = al.get("name", nm)
			rows.append({"id": e["id"], "name": nm, "prob": e["prob"]})
		pun[key] = rows
	pun["scar"] = [{"id": "none", "name": "无疤", "prob": 1.0}]
	return pun

func _appearance_probs_legacy(a: CKCharacter, b: CKCharacter) -> Dictionary:
	var out := {}
	for key in ["hair", "eyes", "brow", "scar"]:
		var counts: Dictionary = {}
		var av = str(a.appearance.get(key, "none"))
		var bv = str(b.appearance.get(key, "none"))
		counts[av] = counts.get(av, 0.0) + 0.45
		counts[bv] = counts.get(bv, 0.0) + 0.45
		# 突变
		var alleles: Array = GameState.data_appearance.get("alleles", {}).get(key, [])
		for al in alleles:
			var aid = al["id"]
			if aid not in counts:
				counts[aid] = 0.05
			else:
				counts[aid] += 0.02
		var total := 0.0
		for v in counts.values():
			total += float(v)
		var probs: Array = []
		for id in counts.keys():
			var nm = id
			for al in alleles:
				if al["id"] == id:
					nm = al.get("name", id)
			probs.append({"id": id, "name": nm, "prob": float(counts[id]) / total})
		probs.sort_custom(func(x, y): return x["prob"] > y["prob"])
		out[key] = probs
	return out

func _inherit_traits(father: CKCharacter, mother: CKCharacter, rng: RandomNumberGenerator) -> Array:
	var pool: Dictionary = {}
	for tid in father.traits:
		pool[tid] = pool.get(tid, 0.0) + 0.6
	for tid in mother.traits:
		pool[tid] = pool.get(tid, 0.0) + 0.6
	var chosen: Array = []
	var ids: Array = pool.keys()
	ids.sort()
	# Order is deterministic. Every parent trait still draws once, so the genome RNG that follows is not shifted by a global shuffle.
	var fork := RandomNumberGenerator.new()
	fork.seed = hash("%s|%s|traits" % [father.id if father else "", mother.id if mother else ""])
	for i in range(ids.size() - 1, 0, -1):
		var j := fork.randi_range(0, i)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	for tid in ids:
		var take := rng.randf() < clampf(float(pool[tid]), 0.2, 0.85)
		if take and chosen.size() < 4:
			chosen.append(tid)
	while chosen.size() < 2:
		var all_t: Array = GameState.data_traits.get("traits", [])
		var t = all_t[rng.randi() % all_t.size()]
		if t["id"] not in chosen and t.get("polarity") == "pos":
			chosen.append(t["id"])
		if chosen.size() >= 2:
			break
	return chosen

func _inherit_appearance(father: CKCharacter, mother: CKCharacter, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for key in ["hair", "eyes", "brow", "scar"]:
		if rng.randf() < 0.08:
			var alleles: Array = GameState.data_appearance.get("alleles", {}).get(key, [{"id": "none"}])
			out[key] = alleles[rng.randi() % alleles.size()]["id"]
		elif rng.randf() < 0.5:
			out[key] = father.appearance.get(key, "none")
		else:
			out[key] = mother.appearance.get(key, "none")
	return out

func _child_rank(a: CKCharacter, b: CKCharacter) -> String:
	var hi = maxi(a.rank_index(), b.rank_index())
	# 默认降一档，最低骑士
	var idx = maxi(0, hi - 1)
	if hi >= 2 and GameState.rng.randf() < 0.35:
		idx = hi  # 有时同档
	return CKCharacter.RANK_ORDER[idx]

## 授旗入队
func enlist_adult(child: CKCharacter) -> Dictionary:
	if not child.is_child and child.age < Calendar.ADULT_AGE:
		return {"ok": false, "msg": "尚未成年"}
	if child.age < Calendar.ADULT_AGE:
		return {"ok": false, "msg": "需满 %d 岁（当前 %d）" % [Calendar.ADULT_AGE, child.age]}
	child.is_child = false
	child.in_roster = true
	child.retired = false
	child.salary = 5 + child.rank_index() * 2
	GameState.mark_dirty()
	return {"ok": true, "msg": "%s 授旗入队" % child.name}

func _heir_score(c: CKCharacter) -> float:
	if c == null or not c.alive or c.retired:
		return -1.0
	if c.age < Calendar.ADULT_AGE:
		return -1.0
	var meta: Dictionary = c.blood_meta if typeof(c.blood_meta) == TYPE_DICTIONARY else {}
	if str(meta.get("succession_bar", "")) == "player":
		return -1.0
	if bool(meta.get("return_grove", false)):
		return -1.0
	return float(CKCourt.merit_of(c)) + float(c.age) * 0.15 + (8.0 if "heir_mark" in c.traits else 0.0)

func _is_descendant(c: CKCharacter, ancestor_id: String, guard: int = 0) -> bool:
	if c == null or guard > 8 or ancestor_id == "":
		return false
	if ancestor_id in c.parent_ids:
		return true
	for pid in c.parent_ids:
		var p: CKCharacter = GameState.characters.get(str(pid))
		if p != null and _is_descendant(p, ancestor_id, guard + 1):
			return true
	return false

## Living adult descendant, else any living adult still with the company.
func pick_heir(leader: CKCharacter, descendants_only: bool = false) -> CKCharacter:
	if leader == null:
		return null
	var best: CKCharacter = null
	var best_s := -1.0
	for c in GameState.characters.values():
		if c == leader or not _is_descendant(c, leader.id):
			continue
		var s := _heir_score(c)
		if s > best_s:
			best_s = s
			best = c
	if best != null or descendants_only:
		return best
	for c in GameState.characters.values():
		if c == leader or not c.in_roster:
			continue
		var s2 := _heir_score(c)
		if s2 > best_s:
			best_s = s2
			best = c
	return best

func generation_depth(c: CKCharacter) -> int:
	return _generation_depth(c, {}, 0)

## Depth follows the longer parent chain. A marriage candidate has no parents, so the first id in
## parent_ids is often the outsider; counting only that side made a five-generation house look like two.
func _generation_depth(c: CKCharacter, seen: Dictionary, guard: int) -> int:
	if c == null or guard > 12 or seen.has(c.id):
		return 0
	var best := 0
	for pid in c.parent_ids:
		var p: CKCharacter = GameState.characters.get(str(pid))
		if p == null:
			continue
		var branch := seen.duplicate()
		branch[c.id] = true
		best = maxi(best, 1 + _generation_depth(p, branch, guard + 1))
	return best

## Pass the banner. Abdication requires a descendant. Death or retirement may fall back to a captain.
func transfer_banner(reason: String) -> Dictionary:
	var leader := GameState.get_leader()
	if leader == null:
		return {"ok": false, "msg": "无团长"}
	var descendants_only := reason == "abdicate"
	var heir := pick_heir(leader, descendants_only)
	if heir == null:
		return {"ok": false, "msg": "无可承旗之人"}
	leader.is_leader = false
	if reason == "abdicate" or reason == "retire":
		leader.retired = true
		leader.in_roster = false
	heir.is_leader = true
	heir.is_child = false
	heir.retired = false
	heir.in_roster = true
	heir.alive = true
	heir.salary = 0
	var verbs := {"abdicate": "传旗", "retire": "退役交旗", "death": "辞世，旗交"}
	var verb := str(verbs.get(reason, "交旗"))
	var msg := "%s %s %s。" % [leader.name, verb, heir.name]
	GameState.add_lineage_event(msg)
	_Ambitions.on_banner(heir)
	GameState.mark_dirty()
	return {"ok": true, "msg": msg, "heir_id": heir.id, "heir": heir.name, "reason": reason}
