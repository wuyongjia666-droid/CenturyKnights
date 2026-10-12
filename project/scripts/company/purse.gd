class_name CKPurse
extends RefCounted
## v9.2 私囊与月俸（提案 4.10）。工钱进口袋；岁课只读在场本人或父母私囊。

const CAP_CHILD := 12
const CAP_FIELD := 24
const CAP_STEWARD := 36
const CAP_COMBAT := 40
const FIELD_WAGE := 2
const CHILD_WAGE := 1
const STEWARD_WAGE := 3
const RETAIN_WAGE := 4
const LEADER_WAGE := 10


static func get_purse(c: CKCharacter) -> int:
	if c == null:
		return 0
	return int(c.blood_meta.get("purse", 0))


static func set_purse(c: CKCharacter, v: int) -> void:
	if c == null:
		return
	c.blood_meta["purse"] = maxi(0, v)


static func cap_for(c: CKCharacter, role: String) -> int:
	match role:
		"child":
			return CAP_CHILD
		"field":
			return CAP_FIELD
		"steward":
			return CAP_STEWARD
		_:
			return CAP_COMBAT


static func deposit(c: CKCharacter, amount: int, role: String) -> int:
	## Returns overflow that stays at source (estate remainder / flag treasury).
	if c == null or amount <= 0:
		return amount
	var cap := cap_for(c, role)
	var cur := get_purse(c)
	var room := maxi(0, cap - cur)
	var take := mini(room, amount)
	set_purse(c, cur + take)
	return amount - take


static func pay_for_child(child: CKCharacter, amount: int) -> Dictionary:
	## Only self or a present living parent. Flag treasury never pays.
	if child == null or amount <= 0:
		return {"ok": true, "payer": "", "msg": ""}
	var candidates: Array = [child]
	for pid in child.parent_ids:
		var p: CKCharacter = GameState.characters.get(str(pid))
		if p != null and p.alive and _same_node(child, p):
			candidates.append(p)
	var best: CKCharacter = null
	for cand in candidates:
		if get_purse(cand) >= amount:
			best = cand
			break
	if best == null:
		var have := get_purse(child)
		for cand2 in candidates:
			have = maxi(have, get_purse(cand2))
		var absent := false
		for pid2 in child.parent_ids:
			var p2: CKCharacter = GameState.characters.get(str(pid2))
			if p2 != null and p2.alive and get_purse(p2) >= amount and not _same_node(child, p2):
				absent = true
				break
		if absent:
			return {"ok": false, "payer": "", "msg": Locale.t("purse_absent_pay") % [have, amount]}
		return {"ok": false, "payer": "", "msg": Locale.t("purse_short") % [have, amount]}
	set_purse(best, get_purse(best) - amount)
	return {"ok": true, "payer": best.id, "msg": ""}


static func _same_node(a: CKCharacter, b: CKCharacter) -> bool:
	return _node_of(a) == _node_of(b)


static func _node_of(c: CKCharacter) -> String:
	var follow = GameState.house_mods.get("follow_banner", [])
	if typeof(follow) == TYPE_ARRAY and c.id in follow:
		return "field"
	if bool(c.blood_meta.get("follow_banner", false)) or (c.in_roster and c.id in GameState.deploy_ids):
		return "field"
	var job := str(c.blood_meta.get("estate_job", ""))
	if job != "":
		return "estate:%s" % job
	if bool(c.blood_meta.get("retinue", false)):
		return "field"
	return "home"


static func on_death(c: CKCharacter) -> void:
	if c == null:
		return
	var bag := get_purse(c)
	if bag <= 0:
		return
	set_purse(c, 0)
	var sp: CKCharacter = null
	if str(c.spouse_id) != "":
		sp = GameState.characters.get(str(c.spouse_id))
	if sp != null and sp.alive:
		var over := deposit(sp, bag, "combat")
		if over > 0:
			GameState.silver += over
	else:
		GameState.silver += bag


static func remit_to_flag(c: CKCharacter) -> Dictionary:
	## 属事处交还：整笔倒回旗库。岁课开着时禁止。
	if c == null:
		return {"ok": false, "msg": Locale.t("purse_nobody")}
	var pending = GameState.house_mods.get("sui_pending", [])
	if typeof(pending) == TYPE_ARRAY and pending.size() > 0:
		return {"ok": false, "msg": Locale.t("purse_sui_open")}
	var bag := get_purse(c)
	if bag <= 0:
		return {"ok": false, "msg": Locale.t("purse_empty")}
	set_purse(c, 0)
	GameState.silver += bag
	GameState.log_event(Locale.t("purse_remit_log") % [c.name, bag])
	return {"ok": true, "msg": Locale.t("purse_remit_ok") % bag, "silver": bag}


static func is_care_locked(c: CKCharacter) -> bool:
	if c == null:
		return false
	if bool(c.blood_meta.get("care_lock", false)):
		return true
	var key := "care_lock_%s" % c.id
	return str(GameState.house_mods.get(key, "")) != ""


static func clear_care_locks_after_pay() -> void:
	for c in GameState.characters.values():
		if c == null:
			continue
		c.blood_meta["care_lock"] = false
	var drop: Array = []
	for k in GameState.house_mods.keys():
		if str(k).begins_with("care_lock_"):
			drop.append(k)
	for k2 in drop:
		GameState.house_mods.erase(k2)


static func follow_ids(host) -> Array:
	## 玩家没手动排过随旗名单时，每次按花名册自动填（年满 16，旗主在前，到出战席为止），
	## 这样新入册的人也领得到出战俸。手动排过之后只剔除死者。
	var raw = host.house_mods.get("follow_banner", null)
	if bool(host.house_mods.get("follow_banner_manual", false)) and typeof(raw) == TYPE_ARRAY:
		var alive: Array = []
		for id in raw:
			var c0: CKCharacter = host.characters.get(str(id))
			if c0 != null and c0.alive:
				alive.append(str(id))
		if alive.size() != raw.size():
			host.house_mods["follow_banner"] = alive
		return alive
	var auto: Array = []
	var cap := CKEconomyState.max_deploy(host)
	var leader: CKCharacter = host.get_leader()
	if leader != null and leader.alive and leader.in_roster:
		auto.append(leader.id)
	for c in host.roster():
		if c == null or not c.alive or int(c.age) < 16 or str(c.id) in auto:
			continue
		if auto.size() < cap:
			auto.append(c.id)
	host.house_mods["follow_banner"] = auto
	return auto


static func set_follow(host, ids: Array) -> void:
	var cap := CKEconomyState.max_deploy(host)
	var cleaned: Array = []
	for id in ids:
		if cleaned.size() >= cap:
			break
		var c: CKCharacter = host.characters.get(str(id))
		if c == null or not c.alive or int(c.age) < 16:
			continue
		if str(id) in cleaned:
			continue
		cleaned.append(str(id))
	host.house_mods["follow_banner"] = cleaned
	host.house_mods["follow_banner_manual"] = true


static func is_following(host, cid: String) -> bool:
	return cid in follow_ids(host)


static func assign_field(c: CKCharacter, holding_id: String) -> Dictionary:
	if c == null:
		return {"ok": false, "msg": Locale.t("purse_nobody")}
	if is_care_locked(c):
		return {"ok": false, "msg": Locale.t("purse_care_lock")}
	if is_following(GameState, c.id):
		return {"ok": false, "msg": Locale.t("purse_follow_block")}
	if bool(c.blood_meta.get("retinue", false)):
		return {"ok": false, "msg": Locale.t("purse_retinue_block")}
	if int(c.age) < 8:
		return {"ok": false, "msg": Locale.t("purse_too_young")}
	if c.in_roster and _is_hireling(c):
		return {"ok": false, "msg": Locale.t("purse_hire_no_field")}
	if holding_id == "":
		c.blood_meta["estate_job"] = ""
		return {"ok": true, "msg": Locale.t("purse_left_field")}
	if not CKEconomyState.holding_unlocked(GameState, holding_id):
		return {"ok": false, "msg": Locale.t("purse_holding_locked")}
	var slots := CKEconomyState.holding_level(GameState, holding_id)
	var used := 0
	for x in GameState.characters.values():
		if x != null and str(x.blood_meta.get("estate_job", "")) == holding_id:
			used += 1
	# steward counts as one slot when present on this holding
	var st = CKEconomyState.steward_of(GameState, holding_id)
	if st != null and str(st.blood_meta.get("estate_job", "")) != holding_id and not is_following(GameState, st.id):
		# steward on site occupies a slot conceptually; count if assigned as steward
		used += 1
	if used >= slots and str(c.blood_meta.get("estate_job", "")) != holding_id:
		return {"ok": false, "msg": Locale.t("purse_slots_full") % [slots, slots]}
	c.blood_meta["estate_job"] = holding_id
	return {"ok": true, "msg": Locale.t("purse_assigned") % c.name}


static func _is_hireling(c: CKCharacter) -> bool:
	if c == null or c.is_leader or c.is_child:
		return false
	if not c.parent_ids.is_empty():
		return false
	if str(c.spouse_id) != "":
		return false
	return true


static func apply_monthly_wages(host) -> String:
	## Holdings already computed gross silver into host via holdings_monthly_yield path.
	## This pays field wages from per-holding silver (tracked in house_mods), then flag wages.
	var notes: Array = []
	var follow: Array = follow_ids(host)
	# 1) Field wages from this month's holding silver ledger
	var field_paid := 0
	var field_overflow := 0
	for hid in host.holdings.keys():
		if hid not in CKEconomyState.HOLDING_DEFS:
			continue
		var pot := int(host.house_mods.get("holding_silver_%s" % hid, 0))
		if pot <= 0:
			continue
		var workers: Array = []
		var steward = CKEconomyState.steward_of(host, hid)
		if steward != null and steward.alive and not is_following(host, steward.id) and not is_care_locked(steward):
			workers.append({"c": steward, "role": "steward", "wage": STEWARD_WAGE})
		for c in host.characters.values():
			if c == null or not c.alive:
				continue
			if is_care_locked(c) or is_following(host, c.id):
				continue
			if bool(c.blood_meta.get("retinue", false)):
				continue
			if str(c.blood_meta.get("estate_job", "")) != hid:
				continue
			if steward != null and c.id == steward.id:
				continue
			if int(c.age) >= 8 and int(c.age) <= 15 and not c.in_roster:
				workers.append({"c": c, "role": "child", "wage": CHILD_WAGE})
			elif int(c.age) >= 16 and not _is_hireling(c):
				workers.append({"c": c, "role": "field", "wage": FIELD_WAGE})
		var need := 0
		for w in workers:
			need += int(w["wage"])
		var scale := 1.0
		if need > pot and need > 0:
			scale = float(pot) / float(need)
			pot = 0
		else:
			pot -= need
		for w2 in workers:
			var pay := int(floor(float(w2["wage"]) * scale))
			if pay <= 0:
				continue
			var over := deposit(w2["c"], pay, str(w2["role"]))
			field_paid += pay - over
			field_overflow += over
		# remainder of this holding's silver → flag treasury
		host.silver += pot + field_overflow
		field_overflow = 0
		host.house_mods["holding_silver_%s" % hid] = 0
	if field_paid > 0:
		notes.append(Locale.t("purse_field_paid") % field_paid)
	# 2) Flag treasury: combat / leader / retain
	var combat_need := 0
	var retain_need := 0
	var leader_need := 0
	var combat_rows: Array = []
	var retain_rows: Array = []
	var leader: CKCharacter = host.get_leader()
	for c2 in host.characters.values():
		if c2 == null or not c2.alive or is_care_locked(c2):
			continue
		if bool(c2.blood_meta.get("retinue", false)):
			continue
		if leader != null and c2.id == leader.id:
			if c2.id in follow:
				leader_need = LEADER_WAGE
			continue
		if c2.id in follow and c2.in_roster:
			var sal := maxi(0, int(c2.salary))
			combat_need += sal
			combat_rows.append({"c": c2, "wage": sal})
		elif c2.in_roster and _is_hireling(c2) and c2.id not in follow:
			retain_need += RETAIN_WAGE
			retain_rows.append({"c": c2, "wage": RETAIN_WAGE})
	var flag_pool := int(host.silver)
	# Priority: combat + leader, then retain
	var high := combat_need + leader_need
	var high_scale := 1.0
	if high > flag_pool and high > 0:
		high_scale = float(flag_pool) / float(high)
		flag_pool = 0
	else:
		flag_pool -= high
	var paid_flag := 0
	if leader != null and leader_need > 0:
		var lp := int(floor(float(leader_need) * high_scale))
		var lo := deposit(leader, lp, "combat")
		paid_flag += lp - lo
		host.silver = maxi(0, int(host.silver) - (lp - lo))  # 旗主俸口袋满了那截留在旗库（§4.10）
		# overflow stays in treasury (already not removed beyond take)
		if lo > 0:
			pass
	for row in combat_rows:
		var cp := int(floor(float(row["wage"]) * high_scale))
		var co := deposit(row["c"], cp, "combat")
		var took := cp - co
		paid_flag += took
		host.silver = maxi(0, int(host.silver) - cp)  # 出战俸照常从旗库扣满；口袋满了那截算花在吃住上
	var retain_scale := 1.0
	flag_pool = int(host.silver)
	if retain_need > flag_pool and retain_need > 0:
		retain_scale = float(flag_pool) / float(retain_need)
	for row2 in retain_rows:
		var rp := int(floor(float(row2["wage"]) * retain_scale))
		var ro := deposit(row2["c"], rp, "combat")
		var took2 := rp - ro
		paid_flag += took2
		host.silver = maxi(0, int(host.silver) - rp)
	if paid_flag > 0:
		notes.append(Locale.t("purse_flag_paid") % paid_flag)
	# Clear care locks after this payday
	clear_care_locks_after_pay()
	# Food mouths (unchanged spirit)
	var mouths := 0
	for c3 in host.characters.values():
		if c3 != null and c3.alive and (c3.in_roster or c3.is_child):
			mouths += 1
	var food_need := maxi(1, mouths)
	host.food -= food_need
	var granary := maxi(120, mouths * 24)
	if host.food > granary:
		host.food = granary + int(float(host.food - granary) * 0.82)
	var msg := Locale.t("purse_month") % ["；".join(notes) if notes else Locale.t("purse_month_none"), food_need]
	## 发不足（按人摊薄）就算见红，和旧版「扣成负数」等价。
	var paid: bool = high_scale >= 1.0 and retain_scale >= 1.0
	if int(host.silver) < 0:
		host.silver = 0
		paid = false
	if not paid or (combat_need + leader_need > 0 and high_scale < 0.999):
		host.morale = maxi(0, host.morale - 15)
		msg += Locale.t("purse_red")
		paid = false
	var pay_note: String = CKMorale.on_payday(host, paid)
	if pay_note != "":
		msg += "；" + pay_note
	if host.food < 0:
		host.morale = maxi(0, host.morale - 20)
		host.food = 0
		msg += Locale.t("purse_starve")
		for c4 in host.characters.values():
			if c4.is_child and c4.alive and host.rng.randf() < 0.4:
				if "malnourished" not in c4.traits:
					c4.traits.append("malnourished")
					host.log_event(Locale.t("purse_mal") % c4.name)
	elif host.food >= 10 and host.morale < 90:
		host.morale = mini(100, host.morale + 2)
	if CKEconomyState.building_level(host, "barracks") >= 2:
		host.morale = mini(100, host.morale + CKEconomyState.building_level(host, "barracks") - 1)
		msg += Locale.t("purse_barracks") % (CKEconomyState.building_level(host, "barracks") - 1)
	for k in host.advisor_bonus.keys():
		var lead = host.get_leader()
		if lead and k in CKCharacter.STAT_KEYS and host.rng.randf() < 0.15:
			lead.stats[k] = mini(int(lead.apt_max.get(k, 20)), int(lead.stats[k]) + 1)
			msg += Locale.t("purse_advisor") % Locale.t("stat_" + k)
			lead.recalc_hp()
			break
	var healed := CKInjury.tick_month(host)
	if healed != "":
		msg += "；" + healed
	return msg


static func monthly_wage_pressure(host) -> int:
	## Era pressure: combat + leader + retain only (not field wages / purses).
	var follow: Array = follow_ids(host)
	var n := 0
	var leader = host.get_leader()
	for c in host.characters.values():
		if c == null or not c.alive:
			continue
		if leader != null and c.id == leader.id and c.id in follow:
			n += LEADER_WAGE
			continue
		if c.id in follow and c.in_roster:
			n += maxi(8, int(c.salary))
		elif c.in_roster and _is_hireling(c) and c.id not in follow:
			n += RETAIN_WAGE
	return n
