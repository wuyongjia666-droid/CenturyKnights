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

