class_name CKFamilyState
extends RefCounted
## Marriage candidates and the small family helpers that used to live on GameState.
## Merged ownership moves to the dynasty stream.

static func family_members(host) -> Array:
	var out: Array = []
	for c in host.characters.values():
		if c.alive and (c.is_leader or c.spouse_id != "" or c.is_child or c.parent_ids.size() > 0):
			out.append(c)
	return out

static func refresh_marriage_candidates(host) -> void:
	host.marriage_candidates.clear()
	for i in 3:
		host.marriage_candidates.append(CharacterFactory.make_marriage_candidate(host.rng))

static func tick_doctrine_and_marriage_month(host) -> Array:
	var msgs: Array = []
	host.tick_patrol_month()
	if host.patrol_boost_months > 0:
		msgs.append("巡防仍在：抗劫剩余 %d 月" % host.patrol_boost_months)
	var doctrine = str(host.house_mods.get("doctrine", ""))
	if doctrine != "":
		host.doctrine_months += 1
		var mul = 2 if bool(host.house_mods.get("doctrine_mature", false)) else 1
		match doctrine:
			"strict":
				host.morale = mini(100, host.morale + 1 * mul)
				msgs.append("家训·严教：士气+%d（第 %d 月）" % [1 * mul, host.doctrine_months])
			"mercy":
				host.food += 1 * mul
				host.morale = mini(100, host.morale + 1 * mul)
				msgs.append("家训·仁恤：粮+%d 士气+%d（第 %d 月）" % [1 * mul, 1 * mul, host.doctrine_months])
			"trade", "commerce":
				host.silver += 2 * mul
				msgs.append("家训·商本：银+%d（第 %d 月）" % [2 * mul, host.doctrine_months])
			_:
				msgs.append("家训仍在：第 %d 月" % host.doctrine_months)
		var amb = host.check_ambitions()
		for a in amb:
			msgs.append(a)
	# 联姻月结：配偶在花名册则微升士气/声望
	var leader = host.get_leader()
	if leader and leader.spouse_id != "" and host.characters.has(leader.spouse_id):
		var sp: CKCharacter = host.characters[leader.spouse_id]
		if sp.alive:
			host.morale = mini(100, host.morale + 1)
			if sp.in_roster:
				host.silver += 1
				msgs.append("联姻月结：%s 同席 → 士气+1 银+1" % sp.name)
			else:
				msgs.append("联姻月结：%s 守堡 → 士气+1" % sp.name)
			host.add_lineage_event(msgs[-1] if msgs else "联姻月结")
	# 血胤月泽：子嗣/配偶血胤浓度带来永久感的微收益
	var blood_bonus = 0
	for c in host.characters.values():
		if not c.alive:
			continue
		if c.is_child or c.spouse_id != "" or c.is_leader:
			for bk in c.blood_mix.keys():
				if float(c.blood_mix[bk]) >= 0.45:
					blood_bonus += 1
					break
	if blood_bonus > 0:
		var gain = mini(3, blood_bonus)
		host.silver += gain
		msgs.append("血胤月泽：族谱浓度 → 银+%d" % gain)
		if blood_bonus >= 3:
			host.morale = mini(100, host.morale + 1)
	for m in host.tick_caravan_month():
		msgs.append(m)
	for m2 in host.tick_alliance_duty_month():
		msgs.append(m2)
	host.mark_dirty()
	return msgs

static func build_dynasty_journal(host) -> String:
	var leader = host.get_leader()
	var spouse_name = "（未成婚）"
	var child_summary = "（无子嗣）"
	if leader and leader.spouse_id != "" and host.characters.has(leader.spouse_id):
		spouse_name = host.characters[leader.spouse_id].name
	var kids: Array = []
	for c in host.characters.values():
		if c.is_child or (leader and c.id in leader.children_ids):
			kids.append("%s〔%s〕" % [c.name, c.bloodline_display()])
	if kids.size() > 0:
		child_summary = "、".join(kids)
	host.dynasty_journal = "【王朝手记·第零章】\n团长：%s\n配偶：%s\n子嗣：%s\n岁时：%s\n声望：灰烬邦 %s / 河卫邦 %s\n\n破旗立团，隘口一战，酒馆添人，春令成婚，初啼入谱，秋收簿清。灰烬旗的第一页，已用血与粮写就。" % [
		leader.name if leader else "?",
		spouse_name,
		child_summary,
		Calendar.label(),
		host.get_rep_name("ashland"),
		host.get_rep_name("riverland"),
	]
	host.set_flag("chapter0_done")
	host.mark_dirty()
	return host.dynasty_journal


const STAT_ZH := {"str": "力", "vit": "体", "skl": "技", "agi": "敏", "per": "感", "wil": "志"}
const TIER_ZH := {1: "残响", 2: "正冕", 3: "满冕"}


## Unborn child: aptitude band, tactical-trait odds, royal-skill tier odds.
## Reads the two parents' genomes. Does not draw.
static func combat_expectation(a: Object, b: Object) -> Dictionary:
	if a == null or b == null:
		return {
			"apt_min": {}, "apt_max": {},
			"apt_zh": "资质区间：选定双方后显示。",
			"tactics": [], "tactics_zh": "战术禀性：选定双方后显示。",
			"royal_tiers": [], "royal_zh": "王技阶：选定双方后显示。",
			"line": "战斗投影：选定双方后显示子嗣的资质、战术禀性与王技阶。",
		}
	var father: Object = b if str(a.get("gender")) == "f" and str(b.get("gender")) == "m" else a
	var mother: Object = a if father == b else b
	var mix: Dictionary = Lineage._mix_blood(father.blood_mix, mother.blood_mix)
	var apt: Dictionary = Lineage._expected_apt(mix)
	var tactics: Array = CKBloodPayoff.combat_forecast(father, mother)
	var tiers: Array = CKBloodPayoff.royal_tier_forecast(father, mother)
	var apt_zh := _apt_band_zh(apt.get("min", {}), apt.get("max", {}))
	var tactics_zh := _tactics_zh(tactics, 3)
	var royal_zh := CKBloodPayoff.royal_tier_forecast_zh(father, mother, 1)
	return {
		"father_id": str(father.get("id")),
		"mother_id": str(mother.get("id")),
		"apt_min": apt.get("min", {}),
		"apt_max": apt.get("max", {}),
		"apt_zh": apt_zh,
		"tactics": tactics,
		"tactics_zh": tactics_zh,
		"royal_tiers": tiers,
		"royal_zh": royal_zh,
		"line": "战斗投影：%s。%s。%s。" % [apt_zh, tactics_zh, royal_zh],
	}


## Living offspring sheet. Parents come from the family roster on host.
static func child_archive(host, child: Object) -> Dictionary:
	var blank := {
		"parents": [],
		"apt_zh": "资质区间：谱上还没有这个人。",
		"tactics_now": {},
		"tactics_zh": "战术禀性：—",
		"royal_tier": 0,
		"royal_zh": "王技阶：—",
		"forecast": {},
		"line": "子嗣档案：谱上还没有这个人。",
	}
	if host == null or child == null:
		return blank
	var parents: Array = []
	var chars: Dictionary = host.characters if host.get("characters") is Dictionary else {}
	for pid in child.parent_ids:
		if chars.has(str(pid)):
			parents.append(chars[str(pid)])
	var apt_zh := _apt_band_zh(child.apt_min, child.apt_max)
	if apt_zh == "":
		apt_zh = "资质区间：已成年，区间写在出生页。"
	var mods: Dictionary = CKBloodPayoff.tactical_mods(child)
	var tier := CKBloodPayoff.royal_skill_tier(child)
	var forecast := {}
	var tactics_zh := _mods_zh(mods)
	var royal_zh := "王技阶 现为 %s" % (TIER_ZH.get(tier, "未显") if tier > 0 else "未显")
	if parents.size() >= 2:
		forecast = combat_expectation(parents[0], parents[1])
		tactics_zh = str(forecast.get("tactics_zh", tactics_zh))
		royal_zh = str(forecast.get("royal_zh", royal_zh))
	return {
		"parents": parents,
		"apt_zh": apt_zh,
		"tactics_now": mods,
		"tactics_zh": tactics_zh,
		"royal_tier": tier,
		"royal_zh": royal_zh,
		"forecast": forecast,
		"line": "子嗣档案：%s。%s。%s。" % [apt_zh, tactics_zh, royal_zh],
	}


static func _apt_band_zh(amin, amax) -> String:
	if typeof(amin) != TYPE_DICTIONARY or typeof(amax) != TYPE_DICTIONARY or amin.is_empty():
		return ""
	var bits: Array = []
	for k in CKCharacter.STAT_KEYS:
		if not amin.has(k):
			continue
		bits.append("%s%d-%d" % [STAT_ZH.get(k, k), int(amin[k]), int(amax.get(k, amin[k]))])
	if bits.is_empty():
		return ""
	return "资质区间 " + " ".join(bits)


static func _tactics_zh(rows: Array, limit: int) -> String:
	if rows.is_empty():
		return "战术禀性：没有可预期的条目"
	var bits: Array = []
	for t in rows.slice(0, limit):
		bits.append("%s %d%%（%s）" % [str(t.get("zh", "")), int(round(float(t.get("p", 0.0)) * 100.0)), str(t.get("effect", ""))])
	return "战术禀性 " + "、".join(bits)


static func _mods_zh(mods: Dictionary) -> String:
	if mods.is_empty():
		return "战术禀性：尚未显出"
	var bits: Array = []
	for k in mods.keys():
		bits.append("%s +%s" % [str(k), str(mods[k])])
	return "战术禀性 " + "、".join(bits)

