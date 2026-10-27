extends Node
## 联姻 · 血胤 · 遗传 · 子嗣期望（X1/X2）

const _Ambitions := preload("res://scripts/characters/ambitions.gd")


func _ready() -> void:
	Calendar.register("post", Callable(_Ambitions, "on_month"), 80)
	Calendar.register("pre", Callable(self, "note_deaths"), 80)

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

## A spouse that died (or vanished from the save) no longer blocks a new match.
func has_living_spouse(c: CKCharacter) -> bool:
	if c == null or str(c.spouse_id) == "":
		return false
	var sp: CKCharacter = GameState.characters.get(str(c.spouse_id))
	return sp != null and sp.alive

## marriage-all-cast A8: when someone dies, the partner is widowed. spouse_id clears so the
## marriage court treats them as single again; the late spouse is kept in blood_meta.late_spouses.
func widow_partner(dead: CKCharacter) -> void:
	if dead == null or str(dead.spouse_id) == "":
		return
	var sp: CKCharacter = GameState.characters.get(str(dead.spouse_id))
	if sp == null or not sp.alive or str(sp.spouse_id) != dead.id:
		return
	_mark_widowed(sp, dead.id)
	GameState.add_lineage_event(Locale.t("lineage_widowed", [sp.name, dead.name]))

## Old saves: anyone whose spouse is dead or missing is widowed on load.
func release_widowed() -> int:
	var n := 0
	for c in GameState.characters.values():
		if c == null or not c.alive or str(c.spouse_id) == "":
			continue
		if has_living_spouse(c):
			continue
		_mark_widowed(c, str(c.spouse_id))
		n += 1
	return n

func _mark_widowed(c: CKCharacter, late_id: String) -> void:
	if typeof(c.blood_meta) != TYPE_DICTIONARY:
		c.blood_meta = {}
	var late: Array = []
	var raw = c.blood_meta.get("late_spouses", [])
	if typeof(raw) == TYPE_ARRAY:
		late = raw
	if late_id not in late:
		late.append(late_id)
	c.blood_meta["late_spouses"] = late
	c.blood_meta["marriage_phase"] = "widowed"
	c.spouse_id = ""
	GameState.mark_dirty()

func can_propose(suitor: CKCharacter, target: CKCharacter, realm: String = "ashland") -> Dictionary:
	## marriage-all-cast A4: roster×roster skips nation-rep gate; bond / 相识 instead.
	if CKFamilyState.is_internal_pair(suitor, target):
		return CKFamilyState.can_internal_propose(suitor, target)
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
	if has_living_spouse(suitor) or has_living_spouse(target):
		return {"ok": false, "msg": "已有配偶（MVP 不可重婚）"}
	if not suitor.alive or not target.alive:
		return {"ok": false, "msg": "当事人不在"}
	if int(suitor.age) < Calendar.ADULT_AGE or int(target.age) < Calendar.ADULT_AGE:
		return {"ok": false, "msg": Locale.t("ux_marry_underage")}
	var bar := CKBloodline.marriage_barrier(suitor, target, GameState.characters)
	if bar != "":
		return {"ok": false, "need": need, "have": have, "msg": bar}
	return {"ok": true, "need": need, "have": have, "msg": "可表白"}

## accepted_rites == null keeps the old vow (smoke / full-chain). An explicit list gates 入牒礼 / 从母居 / 萤约 / 携霜契.
func marry(suitor: CKCharacter, target: CKCharacter, bride_price: int = 40, accepted_rites = null, paced: bool = false) -> Dictionary:
	var check = can_propose(suitor, target)
	if not check.get("ok", false):
		return check
	## UI / tests that pass the court default still get the cheaper 同袍价.
	if CKFamilyState.is_internal_pair(suitor, target) and bride_price == CKFamilyState.COURT_BRIDE_PRICE:
		bride_price = CKFamilyState.INTERNAL_BRIDE_PRICE
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
	GameState.claim_id(target)
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
	# with no extra draw. Player weddings pass paced=true for the 9–11 month term.
	var mother = target if target.gender == "f" else suitor
	var sire = suitor if mother == target else target
	var conceived := true
	var due := 2
	if str(mother.gender) != "f":
		conceived = false
		due = 0
	elif int(mother.pregnant_months) >= 0:
		conceived = true
		due = int(mother.blood_meta.get("gestation_term", int(mother.pregnant_months) + 1))
		if str(mother.blood_meta.get("sire_id", "")) == "":
			mother.blood_meta["sire_id"] = str(sire.id)
	elif paced:
		conceived = CKFamilyState.begin_pregnancy(GameState, mother)
		due = int(mother.blood_meta.get("gestation_term", CKFamilyState.TERM_MONTHS)) if conceived else 0
	else:
		mother.pregnant_months = 1
		mother.blood_meta["sire_id"] = str(sire.id)
	## Teaching flag stays captain-only; other cast weddings must not trip chapter0 gates.
	if bool(suitor.is_leader):
		GameState.chapter0_flags["married"] = true
	suitor.blood_meta["marriage_phase"] = "wed"
	target.blood_meta["marriage_phase"] = "wed"
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
	# Birth does not grant a title. Keep the historical draw so this panel does not shift later rolls.
	_child_rank(a, b)
	return {
		"blood_mix": mix,
		"apt_min": apt["min"],
		"apt_max": apt["max"],
		"trait_probs": trait_probs,
		"appearance_probs": look_probs,
		"rank_hint": "knight",
		"sig_probs": CKBloodline.forecast(father, mother),
		"sig_zh": CKBloodline.forecast_zh(father, mother),
		"combat": combat,
		"apt_zh": str(combat.get("apt_zh", "")),
		"tactics": combat.get("tactics", []),
		"royal_tiers": combat.get("royal_tiers", []),
	}

func _sire_of(mother: CKCharacter) -> CKCharacter:
	if mother == null or typeof(mother.blood_meta) != TYPE_DICTIONARY:
		return null
	var sid := str(mother.blood_meta.get("sire_id", ""))
	if sid == "":
		sid = str(mother.spouse_id)
	if sid == "":
		return null
	return GameState.characters.get(sid)


func _blank_sire() -> CKCharacter:
	var blank := CKCharacter.new()
	blank.gender = "m"
	blank.rank = "knight"
	blank.blood_mix = {"common_ash": 1.0}
	blank.traits = []
	return blank


func _teaching_birth(mother: CKCharacter, father: CKCharacter) -> bool:
	var lead := GameState.get_leader()
	if lead == null:
		return false
	if mother != null and mother.id == lead.id:
		return true
	if father != null and father.id == lead.id:
		return true
	return false


func birth_child(mother: CKCharacter) -> CKCharacter:
	## Biological father is the sire stamped at conception. A dead spouse stays the parent.
	## Never substitute the current leader — that wrote the captain onto a mercenary's child.
	var recorded := _sire_of(mother)
	var father: CKCharacter = recorded if recorded != null else _blank_sire()
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
	child.parent_ids = [recorded.id if recorded != null else "", mother.id]
	# Family arms: child joins its own family line (father's if he has one, else mother's). Families never merge.
	if recorded != null and str(recorded.family_id) != "":
		child.family_id = str(recorded.family_id)
	else:
		child.family_id = str(mother.family_id)
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
	child.blood_meta["birth_ym"] = "%d-%d" % [Calendar.year, Calendar.month]
	# v9.2 出生习痕（可为 0）；用孩子 id 种子，读档复现
	var marks := CKLifeMarks.roll_birth(child)
	if marks.is_empty():
		GameState.log_event(Locale.t("ux_mark_birth_empty") % child.name)
	else:
		var zhmarks: Array = []
		for mid in marks:
			zhmarks.append(CKLifeMarks.zh(str(mid)))
		GameState.log_event(Locale.t("ux_mark_birth") % [child.name, " / ".join(zhmarks)])
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
	for note in CKCourt.stamp_child(child, recorded if recorded != null else father, mother):
		GameState.lineage_log.append(note)
		GameState.log_event(note)
	# Same draw as the old birth rank, then discard it. Only the succession heir receives a title.
	_child_rank(father, mother)
	child.rank = "knight"
	child.blood_meta.erase("title")
	child.blood_meta.erase("title_from")
	child.job_id = "light_inf"
	child.recalc_hp()
	GameState.claim_id(child)
	GameState.characters[child.id] = child
	mother.children_ids.append(child.id)
	if recorded != null:
		recorded.children_ids.append(child.id)
	if _teaching_birth(mother, recorded):
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

## Succession order (user ruling 2026-10-17; no outside heirs):
##   1. living adult direct descendant of the leader (existing _heir_score: merit + age, heir_mark);
##   2. else a living adult on the roster, ranked by title (rank_index) → merit (CKCourt.merit_of) →
##      age → id, so the order is readable and deterministic;
##   3. else (transfer_banner only, not abdication) the eldest living child in the house under a
##      regency of the house elders until they come of age — see pick_minor_heir.
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
	return pick_roster_heir(leader)

## Rule 2: adult company member. Title, then merit, then age, then id.
func pick_roster_heir(leader: CKCharacter) -> CKCharacter:
	var pool: Array = []
	for c in GameState.characters.values():
		if c == leader or not c.in_roster or _heir_score(c) < 0.0:
			continue
		pool.append(c)
	if pool.is_empty():
		return null
	pool.sort_custom(func(a: CKCharacter, b: CKCharacter) -> bool:
		if a.rank_index() != b.rank_index():
			return a.rank_index() > b.rank_index()
		var ma := int(CKCourt.merit_of(a))
		var mb := int(CKCourt.merit_of(b))
		if ma != mb:
			return ma > mb
		if int(a.age) != int(b.age):
			return int(a.age) > int(b.age)
		return str(a.id) < str(b.id))
	return pool[0]

## Rule 3: nobody adult left. The eldest living child of the house takes the banner; on a tie a
## direct descendant first, then the earlier birthday month, then id.
func pick_minor_heir(leader: CKCharacter) -> CKCharacter:
	var pool: Array = []
	for c in GameState.characters.values():
		if c == leader or c == null or not c.alive or c.retired:
			continue
		if not c.is_child and int(c.age) >= Calendar.ADULT_AGE:
			continue
		var meta: Dictionary = c.blood_meta if typeof(c.blood_meta) == TYPE_DICTIONARY else {}
		if str(meta.get("succession_bar", "")) == "player" or bool(meta.get("return_grove", false)):
			continue
		pool.append(c)
	if pool.is_empty():
		return null
	var lid := str(leader.id) if leader != null else ""
	pool.sort_custom(func(a: CKCharacter, b: CKCharacter) -> bool:
		if int(a.age) != int(b.age):
			return int(a.age) > int(b.age)
		var da := _is_descendant(a, lid)
		var db := _is_descendant(b, lid)
		if da != db:
			return da
		if int(a.birthday_month) != int(b.birthday_month):
			return int(a.birthday_month) < int(b.birthday_month)
		return str(a.id) < str(b.id))
	return pool[0]

## Regency state lives in house_mods.regency = {ward, since, until_age}; empty dict = none.
func regency() -> Dictionary:
	var r = GameState.house_mods.get("regency", {})
	return r if typeof(r) == TYPE_DICTIONARY else {}

func is_regency() -> bool:
	return str(regency().get("ward", "")) != ""

## One-line status for the hall header; "" when no regency.
func regency_status() -> String:
	if not is_regency():
		return ""
	var ward: CKCharacter = GameState.characters.get(str(regency().get("ward", "")))
	if ward == null or not ward.alive:
		return ""
	var line := Locale.t("lineage_regency_status", [ward.name, int(ward.age), Calendar.ADULT_AGE])
	var names: Array = []
	var ids = regency().get("elders", [])
	if typeof(ids) == TYPE_ARRAY:
		for eid in ids:
			var elder: CKCharacter = GameState.characters.get(str(eid))
			if elder != null and elder.alive and elder != ward:
				names.append(elder.name)
	if names.is_empty():
		return line
	return "%s (%s)" % [line, ", ".join(names)]

## Calendar calls this when a child comes of age; hands the banner back if they are the ward.
func end_regency_if_ward(c: CKCharacter) -> String:
	if c == null or not c.alive or not is_regency() or str(regency().get("ward", "")) != c.id:
		return ""
	GameState.house_mods.erase("regency")
	c.is_child = false
	c.in_roster = true
	c.retired = false
	c.salary = 0
	var msg := Locale.t("lineage_regency_end", [c.name])
	GameState.add_lineage_event(msg)
	GameState.mark_dirty()
	return msg

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

## Pass the banner. Abdication requires an adult descendant. Death or retirement follows the
## in-house order in pick_heir; with no adult left, the eldest child inherits under a regency.
## A roster with no living person at all (not even a child) still returns ok=false.

## Y1-B stub: mid-run「王朝终结」when succession finds no heir (roadmap §7).
## Persists in house_mods.dynasty_end; hub/hourglass/estates re-read + ToTitle CTA.
func is_dynasty_ended() -> bool:
	var d: Variant = GameState.house_mods.get("dynasty_end", {})
	if typeof(d) != TYPE_DICTIONARY:
		return false
	return str((d as Dictionary).get("reason", "")) != ""


func dynasty_end_snapshot() -> Dictionary:
	var d: Variant = GameState.house_mods.get("dynasty_end", {})
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return d


func note_dynasty_end(reason: String, msg: String = "", last_id: String = "", heir_id: String = "") -> Dictionary:
	if reason == "":
		return dynasty_end_snapshot()
	## First stamp wins; later fails keep the original closing.
	if is_dynasty_ended():
		return dynasty_end_snapshot()
	var text := msg if msg != "" else Locale.t("lineage_no_heir")
	var lid := last_id
	var hid := heir_id
	if lid == "":
		var lead := GameState.get_leader()
		if lead != null:
			lid = str(lead.id)
	var d := {
		"reason": reason,
		"msg": text,
		"label": Calendar.label(),
		"at": int(Calendar.year) * 12 + int(Calendar.month),
		"last_id": lid,
		"heir_id": hid,
	}
	GameState.house_mods["dynasty_end"] = d
	## Dynasty end supersedes a pending banner-handoff tip.
	GameState.house_mods.erase("banner_handoff")
	GameState.add_lineage_event(text)
	GameState.mark_dirty()
	return d


## Hub feel: DynastyEndPanel + named ToTitle → main menu (replace, clears stack).
func attach_dynasty_end_feel(parent: Node, width: float = 520.0) -> Control:
	if parent == null or not is_dynasty_ended():
		return null
	var snap := dynasty_end_snapshot()
	var panel := VBoxContainer.new()
	panel.name = "DynastyEndPanel"
	panel.add_theme_constant_override("separation", 8)
	panel.custom_minimum_size = Vector2(width, 0)
	parent.add_child(panel)
	var last_c = GameState.characters.get(str(snap.get("last_id", "")), null)
	var heir_c = GameState.characters.get(str(snap.get("heir_id", "")), null)
	if last_c == null:
		last_c = GameState.get_leader()
	CKHeraldryField.place_dynasty_end_crest_strip(panel, last_c, heir_c, Vector2.ZERO, Vector2(32, 38), Vector2(20, 28))
	panel.add_child(UIKit.mono(Locale.t("lb_dynasty_end_head"), 11, UIKit.DANGER, false))
	var why := Locale.t("lb_dynasty_end_why_no_heir")
	var reason := str(snap.get("reason", ""))
	if reason == "no_leader":
		why = Locale.t("lb_dynasty_end_why_no_leader")
	elif reason == "wipeout":
		why = Locale.t("lb_dynasty_end_why_wipeout")
	panel.add_child(CKPageKit.empty(Locale.t("lb_dynasty_end_title"), why, str(snap.get("msg", "")), maxf(280.0, width - 24.0)))
	var to_t := CKPageKit.button(Locale.t("lb_dynasty_end_to_title"), true, mini(280.0, width))
	to_t.name = "ToTitle"
	to_t.pressed.connect(func(): CKNav.replace(CKNav.TITLE))
	panel.add_child(to_t)
	UIFX.wire_button(to_t)
	return panel


## Hub tip after a successful 传旗: BannerHandoffPanel + crest strip + dismiss.
## Cleared on dismiss or when dynasty_end stamps.
func is_banner_handoff_pending() -> bool:
	var raw: Variant = GameState.house_mods.get("banner_handoff", {})
	return typeof(raw) == TYPE_DICTIONARY and not (raw as Dictionary).is_empty()


func banner_handoff_snapshot() -> Dictionary:
	var raw: Variant = GameState.house_mods.get("banner_handoff", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


func attach_banner_handoff_feel(parent: Node, width: float = 520.0) -> Control:
	if parent == null or is_dynasty_ended() or not is_banner_handoff_pending():
		return null
	var snap := banner_handoff_snapshot()
	var outgoing = GameState.characters.get(str(snap.get("from_id", "")), null)
	var heir = GameState.characters.get(str(snap.get("heir_id", "")), null)
	var panel := VBoxContainer.new()
	panel.name = "BannerHandoffPanel"
	panel.add_theme_constant_override("separation", 8)
	panel.custom_minimum_size = Vector2(width, 0)
	parent.add_child(panel)
	CKHeraldryField.place_banner_handoff_crest_strip(panel, outgoing, heir, Vector2.ZERO, Vector2(32, 38), Vector2(20, 28))
	panel.add_child(UIKit.mono(Locale.t("lb_handoff_head"), 11, UIKit.ACCENT, false))
	panel.add_child(CKPageKit.text(str(snap.get("msg", "")), UIKit.TEXT, 14, maxf(280.0, width - 24.0)))
	var dismiss := CKPageKit.button(Locale.t("lb_handoff_dismiss"), false, mini(280.0, width))
	dismiss.name = "DismissHandoff"
	dismiss.pressed.connect(func():
		GameState.house_mods.erase("banner_handoff")
		GameState.mark_dirty()
		if is_instance_valid(panel):
			panel.queue_free()
	)
	panel.add_child(dismiss)
	UIFX.wire_button(dismiss)
	return panel


## After battle casualties: if no living captain remains, try succession once;
## on fail stamp wipeout (battle flavour of the same dynasty_end stub).
func close_after_battle() -> Dictionary:
	if is_dynasty_ended():
		return dynasty_end_snapshot()
	var leader := GameState.get_leader()
	if leader != null and leader.alive:
		return {"ok": true, "leader": leader.id}
	## Dead or missing captain — hand off if anyone can still take the banner.
	if leader != null:
		var heir := pick_heir(leader, false)
		if heir == null:
			heir = pick_minor_heir(leader)
		if heir != null:
			return transfer_banner("death")
	var msg := Locale.t("lineage_wipeout")
	var last_id := str(leader.id) if leader != null else ""
	note_dynasty_end("wipeout", msg, last_id, "")
	return {"ok": false, "msg": msg, "dynasty_end": true, "reason": "wipeout"}


func _can_take_banner(c: CKCharacter, leader_id: String) -> bool:
	if c == null or _heir_score(c) < 0.0:
		return false
	if c.in_roster:
		return true
	return _is_descendant(c, leader_id)


## Living adults who cannot take the banner sit as regents. Oldest first, two seats.
func pick_regents(leader: CKCharacter, heir: CKCharacter) -> Array:
	var lid := str(leader.id) if leader != null else ""
	var pool: Array = []
	for c in GameState.characters.values():
		if c == null or not c.alive or c == heir or c == leader:
			continue
		if int(c.age) < Calendar.ADULT_AGE or bool(c.is_child):
			continue
		if _can_take_banner(c, lid):
			continue
		pool.append(c)
	pool.sort_custom(func(a: CKCharacter, b: CKCharacter) -> bool:
		if int(a.age) != int(b.age):
			return int(a.age) > int(b.age)
		return str(a.id) < str(b.id))
	return pool.slice(0, 2)


func _pass_title(from: CKCharacter, heir: CKCharacter) -> void:
	if from == null or heir == null:
		return
	if typeof(heir.blood_meta) != TYPE_DICTIONARY:
		heir.blood_meta = {}
	var office := CKCourt.current_title(from)
	var have := CKCourt.current_title(heir)
	var oi := CKCharacter.RANK_ORDER.find(office)
	var hi := CKCharacter.RANK_ORDER.find(have)
	if oi < 0:
		oi = 0
	if hi < 0:
		hi = 0
	var kept := office if oi >= hi else have
	heir.blood_meta["title"] = kept
	heir.blood_meta["title_from"] = from.id
	heir.rank = kept


func transfer_banner(reason: String) -> Dictionary:
	var leader := GameState.get_leader()
	if leader == null:
		var nl := Locale.t("lineage_no_leader")
		note_dynasty_end("no_leader", nl)
		return {"ok": false, "msg": nl, "dynasty_end": true}
	var descendants_only := reason == "abdicate"
	var heir := pick_heir(leader, descendants_only)
	var via := "descendant"
	if heir != null and not _is_descendant(heir, leader.id):
		via = "roster"
	var minor := false
	if heir == null and not descendants_only:
		heir = pick_minor_heir(leader)
		minor = heir != null
		via = "minor"
	if heir == null:
		var nh := Locale.t("lineage_no_heir")
		note_dynasty_end("no_heir", nh, str(leader.id), "")
		return {"ok": false, "msg": nh, "dynasty_end": true}
	leader.is_leader = false
	if reason == "abdicate" or reason == "retire":
		leader.retired = true
		leader.in_roster = false
	heir.is_leader = true
	heir.retired = false
	heir.alive = true
	heir.salary = 0
	if minor:
		# Existing minor rule: under ADULT_AGE nobody is enlisted, so the ward stays off the roster
		# (cannot deploy) until they come of age; the player still makes the house decisions.
		heir.is_child = true
		heir.in_roster = false
		var elders := pick_regents(leader, heir)
		var elder_ids: Array = []
		var elder_names: Array = []
		for elder in elders:
			elder_ids.append(elder.id)
			elder_names.append(elder.name)
		GameState.house_mods["regency"] = {
			"ward": heir.id,
			"since": Calendar.label(),
			"until_age": Calendar.ADULT_AGE,
			"elders": elder_ids,
		}
		GameState.house_mods["regency_names"] = elder_names
	else:
		heir.is_child = false
		heir.in_roster = true
		if is_regency():
			GameState.house_mods.erase("regency")
	if via == "roster":
		# Joins the house even when the house still flies the plain castle banner (family_id "").
		heir.family_id = str(leader.family_id)
		if typeof(heir.blood_meta) != TYPE_DICTIONARY:
			heir.blood_meta = {}
		heir.blood_meta["joined_house"] = true
	_pass_title(leader, heir)
	var verbs := {"abdicate": "传旗", "retire": "退役交旗", "death": "辞世，旗交"}
	var verb := str(verbs.get(reason, "交旗"))
	var msg := "%s %s %s。" % [leader.name, verb, heir.name]
	if via == "roster":
		msg = Locale.t("lineage_roster_heir", [leader.name, heir.name])
	elif minor:
		msg = Locale.t("lineage_regency_begin", [leader.name, heir.name, int(heir.age), Calendar.ADULT_AGE])
		var named: Array = GameState.house_mods.get("regency_names", [])
		if typeof(named) == TYPE_ARRAY and not named.is_empty():
			msg = "%s (%s)" % [msg, ", ".join(named)]
		GameState.house_mods.erase("regency_names")
	GameState.add_lineage_event(msg)
	_Ambitions.on_banner(heir)
	## Hub tip: castle / hourglass / estates show 传旗 crest strip until dismissed or dynasty ends.
	GameState.house_mods["banner_handoff"] = {
		"from_id": str(leader.id),
		"heir_id": str(heir.id),
		"msg": msg,
		"reason": reason,
		"via": via,
		"label": Calendar.label(),
	}
	GameState.mark_dirty()
	return {"ok": true, "msg": msg, "heir_id": heir.id, "heir": heir.name, "reason": reason, "via": via, "regency": minor}

## After Calendar ages the living, copy the dead onto the stele. Battle rows already
## carry CMP-01 words; old age is filled here. This does not spend silver, food, or morale.
func note_deaths(_ctx: Dictionary = {}) -> void:
	for c in GameState.characters.values():
		if c == null or c.alive:
			continue
		_inscribe(c)

func ancestor_rows() -> Array:
	note_deaths()
	var rows: Array = []
	for c in GameState.characters.values():
		if c == null or c.alive:
			continue
		rows.append(_row_for(c))
	rows.sort_custom(Callable(self, "_by_death"))
	return rows

## Family honor is a read for the stele and for whoever applies the bonus. The month tick does not.
func honor_bonus() -> int:
	return mini(3, ancestor_rows().size())

func _inscribe(c: CKCharacter) -> void:
	if typeof(c.blood_meta) != TYPE_DICTIONARY:
		c.blood_meta = {}
	var raw = c.blood_meta.get("stele", {})
	var stele: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	if str(stele.get("cause", "")) == "":
		stele["cause"] = "age"
		stele["words"] = Locale.t("ancestor_age_words")
		stele["when"] = Calendar.label() if Calendar else ""
		stele["name"] = c.name
	if not stele.has("born_year"):
		var death_year := _year_of(str(stele.get("when", "")))
		stele["death_year"] = death_year
		stele["born_year"] = death_year - int(c.age)
	c.blood_meta["stele"] = stele

func _year_of(when: String) -> int:
	var found := ""
	for i in when.length():
		var ch := when.substr(i, 1)
		if ch >= "0" and ch <= "9":
			found += ch
			continue
		if found != "":
			return int(found)
	if found != "":
		return int(found)
	return Calendar.year if Calendar else 0

func _deeds(c: CKCharacter) -> String:
	var hits: PackedStringArray = []
	for row in GameState.lineage_log:
		var text := ""
		if typeof(row) == TYPE_DICTIONARY:
			text = str(row.get("text", ""))
		else:
			text = str(row)
		if c.name != "" and text.find(c.name) >= 0:
			hits.append(text)
		if hits.size() >= 2:
			break
	if hits.is_empty():
		return Locale.t("ancestor_no_deed")
	return " / ".join(hits)

func _titles(c: CKCharacter) -> String:
	var hits: PackedStringArray = []
	for item in c.honors:
		var token := str(item)
		if token.begins_with("dyn:"):
			hits.append(_title_label(token.substr(4)))
	if hits.is_empty():
		return Locale.t("ancestor_no_title")
	return " / ".join(hits)

func _title_label(suffix: String) -> String:
	var key := "amb_%s_title" % suffix
	var label := Locale.t(key)
	var missing := Locale.t("locale_missing")
	if label == "" or label == "..." or label == missing or label == key:
		return suffix
	return label

func _row_for(c: CKCharacter) -> Dictionary:
	var stele: Dictionary = {}
	if typeof(c.blood_meta) == TYPE_DICTIONARY:
		var raw = c.blood_meta.get("stele", {})
		if typeof(raw) == TYPE_DICTIONARY:
			stele = raw
	var cause := str(stele.get("cause", "age"))
	var cause_key := "ancestor_cause_battle" if cause == "battle" else "ancestor_cause_age"
	return {
		"id": c.id,
		"name": c.name,
		"born_year": int(stele.get("born_year", 0)),
		"death_year": int(stele.get("death_year", 0)),
		"cause": cause,
		"cause_zh": Locale.t(cause_key),
		"words": str(stele.get("words", "")),
		"deeds": _deeds(c),
		"titles": _titles(c),
	}

func _by_death(a: Dictionary, b: Dictionary) -> bool:
	var ay := int(a.get("death_year", 0))
	var by := int(b.get("death_year", 0))
	if ay == by:
		return str(a.get("id", "")) < str(b.get("id", ""))
	return ay < by
