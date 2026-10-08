class_name CKEconomyState
extends RefCounted
## Company economy: holdings, castle tasks, upkeep, harvest, recruit price, building upgrades.
## Every function takes the GameState host so the singleton keeps the same numbers.

static func recruit_price(_host, candidate) -> int:
	return 25 + candidate.rank_index() * 15


const HOLDING_DEFS := {
	"reed_ford": {"name": "苇原渡", "desc": "护商旧道属地", "food": 3, "silver": 3, "quest": "q_escort"},
	"stone_slope": {"name": "石垒坡", "desc": "清匪后的丘地佃庄", "food": 2, "silver": 5, "quest": "q_bandit"},
	"fog_vale": {"name": "雾谷药田", "desc": "药草租佃", "food": 1, "silver": 3, "herb": 1, "quest": "q_herb"},
	"tide_bridge": {"name": "断潮渡哨", "desc": "河卫守桥契约地", "food": 2, "silver": 4, "rep": 1, "quest": "q_bridge"},
}
const BUILDING_NAMES := {
	"hall": "议事厅",
	"barracks": "校场",
	"market": "市集",
	"forge": "工坊",
	"shrine": "祠堂",
}
const BUILDING_MAX := 5
const BUILDING_COST := {
	# level -> cost to upgrade TO that level
	2: {"silver": 80, "iron": 3, "food": 10},
	3: {"silver": 160, "iron": 6, "food": 20},
	4: {"silver": 280, "iron": 10, "food": 35},
	5: {"silver": 450, "iron": 16, "food": 55},
}

static func _init_quests(host) -> void:
	host.quests = [
		{"id": "q_escort", "name": "护商·苇原道", "stars": 1, "months": 1, "silver": 30, "rep": 6, "battle": false,
			"desc": "商队要走苇原旧道。旗帜一亮，劫匪多半让路——自动结算，换银与灰烬邦声望。"},
		{"id": "q_bandit", "name": "清匪·石垒坡", "stars": 2, "months": 1, "silver": 45, "rep": 10, "battle": true, "map": "quest_bandit",
			"desc": "石垒坡有人收「过路银」。真实战棋清剿：编队出战，打赢才算。"},
		{"id": "q_drill", "name": "演习·灰场", "stars": 1, "months": 1, "silver": 20, "rep": 4, "battle": false,
			"desc": "堡内灰场拉练。耗时一月，全员小额经验，士气微升。"},
		{"id": "q_herb", "name": "采药·雾谷", "stars": 1, "months": 1, "silver": 15, "rep": 3, "battle": false,
			"desc": "雾谷药草正旺。归来药材+2（自动），并得薄银。"},
		{"id": "q_bridge", "name": "守桥·断潮渡", "stars": 2, "months": 1, "silver": 40, "rep": 8, "battle": false,
			"desc": "河卫邦请人值夜守桥。不必开战，换声望与银——陆桥耳目会记住灰旗。"},
		{"id": "q_rumor", "name": "探听·烽火夜话", "stars": 1, "months": 1, "silver": 10, "rep": 5, "battle": false,
			"desc": "酒馆夜话里有春令与匪线的碎片。耗时换声望，偶得铁料线索（银少）。"},
		{"id": "q_hill_war", "name": "主线支援·石垒坡", "stars": 3, "months": 1, "silver": 60, "rep": 12, "battle": true, "map": "ch1_hill",
			"desc": "第一章：丘林交错的石垒坡清剿。打赢记入陆桥烽火。"},
		{"id": "q_ford_war", "name": "主线支援·断潮渡", "stars": 3, "months": 1, "silver": 55, "rep": 12, "battle": true, "map": "ch1_ford",
			"desc": "第一章：宽滩断潮渡值夜战。河卫邦会记住灰旗。"},
		{"id": "q_fog_war", "name": "主线支援·雾谷", "stars": 3, "months": 1, "silver": 58, "rep": 12, "battle": true, "map": "ch1_fog",
			"desc": "第一章：密林雾谷夜袭。弓手危险，阵型勿散。"},
		{"id": "q_forge_war", "name": "主线支援·炉火关", "stars": 3, "months": 1, "silver": 65, "rep": 12, "battle": true, "map": "ch3_forge",
			"desc": "第三章：炉火关试锋。可用战技破旗斩/穿林箭。"},
		{"id": "q_shrine_war", "name": "主线支援·祠堂外廊", "stars": 3, "months": 1, "silver": 65, "rep": 12, "battle": true, "map": "ch3_shrine",
			"desc": "第三章：祠堂外廊。适合铁壁与灰焰祷言。"},
	]

static func building_level(host, id: String) -> int:
	return int(host.buildings.get(id, 1))

static func upgrade_annex(host, id: String) -> Dictionary:
	return CKCastleServices.upgrade_annex(host, id)

static func max_deploy(host) -> int:
	# 厅堂 Lv1–5 → 4–8 人
	return 3 + CKEconomyState.building_level(host, "hall")

static func train_cost(host) -> int:
	var base = 15
	var disc = (CKEconomyState.building_level(host, "barracks") - 1) * 3
	if bool(host.house_mods.get("drill_discount", false)):
		disc += 2
	return maxi(8, base - disc)

static func forge_craft_cost(host) -> Dictionary:
	var lv = CKEconomyState.building_level(host, "forge")
	return {"iron": maxi(1, 3 - mini(lv, 3)), "silver": maxi(8, 24 - lv * 4)}

static func market_buy_prices(host) -> Dictionary:
	var lv = CKEconomyState.building_level(host, "market")
	var cut = lv - 1
	if bool(host.house_mods.get("trade_route", false)):
		cut += 1
	if bool(host.house_mods.get("market_edge", false)):
		cut += 1
	return {"food": maxi(1, 2 - cut), "iron": maxi(5, 8 - cut), "herb": maxi(4, 6 - cut)}

static func market_sell_prices(host) -> Dictionary:
	var lv = CKEconomyState.building_level(host, "market")
	var bump = lv - 1
	if bool(host.house_mods.get("trade_route", false)):
		bump += 1
	return {"food": 1 + bump, "iron": 5 + bump, "herb": 4 + bump}

static func _all_buildings_at_least(host, lv: int) -> bool:
	for id in BUILDING_NAMES.keys():
		if CKEconomyState.building_level(host, id) < lv:
			return false
	return true

static func _enlisted_children_count(host) -> int:
	var n = 0
	for c in host.characters.values():
		if not c.alive or not c.in_roster:
			continue
		if c.parent_ids.size() > 0 or str(c.id).begins_with("child"):
			n += 1
	return n

static func holding_unlocked(host, hid: String) -> bool:
	return host.holdings.has(hid)

static func holding_level(host, hid: String) -> int:
	if not host.holdings.has(hid):
		return 0
	return int(host.holdings[hid].get("level", 1))

static func unlock_holding(host, hid: String) -> String:
	if hid not in HOLDING_DEFS:
		return ""
	if host.holdings.has(hid):
		return ""
	host.holdings[hid] = {"level": 1, "steward_id": ""}
	var nm = str(HOLDING_DEFS[hid].get("name", hid))
	host.add_lineage_event("属地开垦：%s" % nm)
	host.mark_dirty()
	return "属地解锁：%s（月结产出）" % nm

static func upgrade_holding(host, hid: String) -> Dictionary:
	if not host.holdings.has(hid):
		return {"ok": false, "msg": "尚未拥有此属地"}
	var lv = CKEconomyState.holding_level(host, hid)
	if lv >= 3:
		return {"ok": false, "msg": "属地已满级"}
	var cost_s = 40 * lv
	var cost_f = 8 * lv
	if host.silver < cost_s or host.food < cost_f:
		return {"ok": false, "msg": "需 %d银/%d粮" % [cost_s, cost_f]}
	host.silver -= cost_s
	host.food -= cost_f
	host.holdings[hid]["level"] = lv + 1
	host.log_event("属地升级：%s → Lv%d" % [HOLDING_DEFS[hid].name, lv + 1])
	var amb = CKEconomyState.check_ambitions(host)
	host.mark_dirty()
	return {"ok": true, "msg": "%s 升至 Lv%d%s" % [HOLDING_DEFS[hid].name, lv + 1, ("；" + " / ".join(amb)) if amb else ""]}

static func assign_steward(host, hid: String, cid: String) -> Dictionary:
	if not host.holdings.has(hid):
		return {"ok": false, "msg": "属地未开垦"}
	var c: CKCharacter = host.characters.get(cid)
	if c == null or not c.alive or not c.in_roster:
		return {"ok": false, "msg": "须选花名册成员"}
	# 一人一属地
	for other in host.holdings.keys():
		if str(host.holdings[other].get("steward_id", "")) == cid:
			host.holdings[other]["steward_id"] = ""
	host.holdings[hid]["steward_id"] = cid
	host.log_event("%s 出任 %s 庄头" % [c.name, HOLDING_DEFS[hid].name])
	host.mark_dirty()
	return {"ok": true, "msg": "%s 就任 %s 庄头（月结+成，且本月抗劫）" % [c.name, HOLDING_DEFS[hid].name]}

static func clear_steward(host, hid: String) -> void:
	if host.holdings.has(hid):
		host.holdings[hid]["steward_id"] = ""
		host.mark_dirty()

static func holding_patrol_boost(host, hid: String) -> int:
	if not host.holdings.has(hid):
		return 0
	return int(host.holdings[hid].get("patrol_boost", 0))

static func holding_patrol_cd(host, hid: String) -> int:
	if not host.holdings.has(hid):
		return 0
	return int(host.holdings[hid].get("patrol_cd", 0))

static func patrol_holding(host, hid: String) -> Dictionary:
	## 单属地巡防路线：花费较少，仅强化该地抗劫，并返回 vignette 标记
	if not host.holdings.has(hid):
		return {"ok": false, "msg": "属地未开垦"}
	var def = HOLDING_DEFS.get(hid, {})
	var nm = str(def.get("name", hid))
	if CKEconomyState.holding_patrol_cd(host, hid) > 0:
		return {"ok": false, "msg": "%s 巡防冷却中（%d 月）" % [nm, CKEconomyState.holding_patrol_cd(host, hid)]}
	var cost_s = 18 + CKEconomyState.holding_level(host, hid) * 6
	var cost_f = 3 + CKEconomyState.holding_level(host, hid)
	if host.silver < cost_s or host.food < cost_f:
		return {"ok": false, "msg": "需 %d 银 / %d 粮" % [cost_s, cost_f]}
	host.silver -= cost_s
	host.food -= cost_f
	host.holdings[hid]["patrol_boost"] = maxi(CKEconomyState.holding_patrol_boost(host, hid), 2)
	host.holdings[hid]["patrol_cd"] = 2
	host.holdings[hid]["last_patrol"] = Calendar.label() if Calendar else ""
	host.estate_quiet_months += 1
	host.morale = mini(100, host.morale + 1)
	host.log_event("巡防路线·%s：-%d银/-%d粮，抗劫 2 月" % [nm, cost_s, cost_f])
	host.add_lineage_event("巡防路线抵达%s——田埂灯火一夜未熄" % nm)
	var amb = CKEconomyState.check_ambitions(host)
	host.mark_dirty()
	var extra = ("；" + " / ".join(amb)) if amb else ""
	return {"ok": true, "msg": "%s 巡防完成%s" % [nm, extra], "hid": hid, "vignette": true}

static func patrol_holdings(host) -> Dictionary:
	## 全堡巡防：所有已开垦属地各走一圈（贵），全局抗劫
	if host.holdings.is_empty():
		return {"ok": false, "msg": "尚无开垦属地"}
	if host.patrol_cooldown > 0:
		return {"ok": false, "msg": "全堡巡防休息中（尚余 %d 月）" % host.patrol_cooldown}
	var cost_s = 25 + CKEconomyState.unlocked_holdings_count(host) * 8
	var cost_f = 4 + CKEconomyState.unlocked_holdings_count(host)
	if host.silver < cost_s or host.food < cost_f:
		return {"ok": false, "msg": "需 %d 银 / %d 粮" % [cost_s, cost_f]}
	host.silver -= cost_s
	host.food -= cost_f
	host.patrol_boost_months = maxi(host.patrol_boost_months, 2)
	host.patrol_cooldown = 2
	for hid in host.holdings.keys():
		host.holdings[hid]["patrol_boost"] = maxi(CKEconomyState.holding_patrol_boost(host, hid), 2)
		host.holdings[hid]["last_patrol"] = Calendar.label() if Calendar else ""
	host.estate_quiet_months += 1
	host.morale = mini(100, host.morale + 2)
	host.log_event("四野巡防：花费 %d银/%d粮，各属地抗劫强化 2 月" % [cost_s, cost_f])
	host.add_lineage_event("主动巡防：旗丁走田埂，劫影暂避")
	var amb = CKEconomyState.check_ambitions(host)
	host.mark_dirty()
	var extra = ("；" + " / ".join(amb)) if amb else ""
	return {"ok": true, "msg": "全堡巡防完成：抗劫 2 月，安静%d%s" % [host.estate_quiet_months, extra], "vignette": true, "hid": ""}

static func tick_patrol_month(host) -> void:
	if host.patrol_cooldown > 0:
		host.patrol_cooldown -= 1
	if host.patrol_boost_months > 0:
		host.patrol_boost_months -= 1
	for hid in host.holdings.keys():
		var b = int(host.holdings[hid].get("patrol_boost", 0))
		if b > 0:
			host.holdings[hid]["patrol_boost"] = b - 1
		var cd = int(host.holdings[hid].get("patrol_cd", 0))
		if cd > 0:
			host.holdings[hid]["patrol_cd"] = cd - 1

static func steward_of(host, hid: String) -> CKCharacter:
	if not host.holdings.has(hid):
		return null
	var cid = str(host.holdings[hid].get("steward_id", ""))
	if cid == "":
		return null
	return host.characters.get(cid)

static func holding_focus(host, hid: String) -> String:
	if not host.holdings.has(hid):
		return "grain"
	var f = str(host.holdings[hid].get("focus", "grain"))
	if f == "":
		return "grain"
	return f

static func set_holding_focus(host, hid: String, focus: String) -> Dictionary:
	## 属地经营偏向：粮作 / 钱作 / 戍卫 — 真代价决策
	if not host.holdings.has(hid):
		return {"ok": false, "msg": "属地未开垦"}
	if focus not in ["grain", "cash", "fortify"]:
		return {"ok": false, "msg": "未知偏向"}
	var cd = int(host.holdings[hid].get("focus_cd", 0))
	if cd > 0:
		return {"ok": false, "msg": "改作冷却中（余%d月）" % cd}
	if host.silver < 10:
		return {"ok": false, "msg": "改作需 10 银"}
	host.silver -= 10
	host.holdings[hid]["focus"] = focus
	host.holdings[hid]["focus_cd"] = 2
	var cn = {"grain": "粮作", "cash": "钱作", "fortify": "戍卫"}.get(focus, focus)
	host.log_event("%s 改作 → %s" % [HOLDING_DEFS[hid].name, cn])
	host.add_lineage_event("属地改作：%s→%s" % [HOLDING_DEFS[hid].name, cn])
	host.mark_dirty()
	return {"ok": true, "msg": "%s 改为「%s」（月结结构变化；冷却2月）" % [HOLDING_DEFS[hid].name, cn]}

static func start_caravan(host, kind: String) -> Dictionary:
	## 陆桥商队：投资上路，月结检定，到期交割
	if int(host.caravan.get("turns_left", 0)) > 0:
		return {"ok": false, "msg": "已有商队在途"}
	if kind not in ["grain", "iron", "spice"]:
		return {"ok": false, "msg": "航线：grain/iron/spice"}
	var cost = {"grain": 35, "iron": 45, "spice": 55}.get(kind, 40)
	if host.silver < cost:
		return {"ok": false, "msg": "需 %d 银上路" % cost}
	host.silver -= cost
	host.caravan = {"kind": kind, "turns_left": 3, "invested": cost}
	host.house_mods["caravan_active"] = true
	var cn = {"grain": "粮运", "iron": "铁运", "spice": "香料险运"}.get(kind, kind)
	host.log_event("商队出发：%s（投资%d）" % [cn, cost])
	host.add_lineage_event("陆桥商队：%s 上路" % cn)
	host.mark_dirty()
	return {"ok": true, "msg": "商队「%s」上路，约 3 月交割（途中有劫险）" % cn}

static func escort_caravan(host) -> Dictionary:
	## 商队护运：花银买平安——中长环真决策
	if int(host.caravan.get("turns_left", 0)) <= 0:
		return {"ok": false, "msg": "无在途商队"}
	if bool(host.caravan.get("escorted", false)):
		return {"ok": false, "msg": "已雇护运"}
	if host.silver < 12:
		return {"ok": false, "msg": "护运需 12 银"}
	host.silver -= 12
	host.caravan["escorted"] = true
	host.add_lineage_event("商队护运：花 12 银买路平安")
	host.mark_dirty()
	return {"ok": true, "msg": "护运已雇：途中遇劫大降"}

static func tick_caravan_month(host) -> Array:
	var msgs: Array = []
	# focus cd tick
	for hid in host.holdings.keys():
		var cd = int(host.holdings[hid].get("focus_cd", 0))
		if cd > 0:
			host.holdings[hid]["focus_cd"] = cd - 1
	if int(host.caravan.get("turns_left", 0)) <= 0:
		return msgs
	host.caravan["turns_left"] = int(host.caravan["turns_left"]) - 1
	var kind = str(host.caravan.get("kind", "grain"))
	var invested = int(host.caravan.get("invested", 40))
	# mid risk
	var raid = 0.12
	if bool(host.house_mods.get("trade_route", false)):
		raid *= 0.6
	if bool(host.house_mods.get("market_edge", false)):
		raid *= 0.75
	if host.alliance_duty_months > 0:
		raid *= 0.7  # 义役护路
	if bool(host.caravan.get("escorted", false)):
		raid *= 0.25
	if host.rng.randf() < raid:
		var loss = int(invested * 0.45)
		host.silver = maxi(0, host.silver - loss)
		msgs.append("商队遇劫：损银 %d（航线仍在）" % loss)
		host.add_lineage_event(msgs[-1])
		host.morale = maxi(0, host.morale - 2)
	else:
		msgs.append("商队平安过月：余 %d 月" % int(host.caravan["turns_left"]))
	if int(host.caravan["turns_left"]) <= 0:
		var payout = int(invested * {"grain": 1.7, "iron": 1.9, "spice": 2.3}.get(kind, 1.8))
		host.silver += payout
		if kind == "grain":
			host.food += 8
		elif kind == "iron":
			host.iron += 4
		elif kind == "spice":
			host.herb += 3
			host.add_rep("riverland", 1)
		msgs.append("商队交割：收回约 %d 银并卸货" % payout)
		host.add_lineage_event(msgs[-1])
		host.caravan = {}
		host.house_mods.erase("caravan_active")
	host.mark_dirty()
	return msgs

static func start_alliance_duty(host) -> Dictionary:
	## 联姻义役：6 月每月付 5 银，换护路+声望+士气
	if host.alliance_duty_months > 0:
		return {"ok": false, "msg": "义役进行中（余%d月）" % host.alliance_duty_months}
	var leader = host.get_leader()
	if leader == null or leader.spouse_id == "":
		return {"ok": false, "msg": "需先联姻"}
	host.alliance_duty_months = 6
	host.house_mods["alliance_duty"] = true
	host.add_lineage_event("联姻义役：六个月护路共济")
	host.mark_dirty()
	return {"ok": true, "msg": "义役起誓：每月 5 银，护商路、升声望（共 6 月）"}

static func tick_alliance_duty_month(host) -> Array:
	var msgs: Array = []
	if host.alliance_duty_months <= 0:
		return msgs
	if host.silver >= 5:
		host.silver -= 5
		host.morale = mini(100, host.morale + 1)
		host.add_rep("ashland", 1)
		msgs.append("联姻义役：付 5 银 → 士气+1 声望+（余%d月）" % (host.alliance_duty_months - 1))
	else:
		host.morale = maxi(0, host.morale - 3)
		msgs.append("联姻义役欠缴：士气-3（余%d月）" % (host.alliance_duty_months - 1))
		host.add_lineage_event("义役欠缴")
	host.alliance_duty_months -= 1
	if host.alliance_duty_months <= 0:
		host.house_mods.erase("alliance_duty")
		host.house_mods["alliance_duty_done"] = true
		host.add_rep("riverland", 2)
		msgs.append("义役圆满：河卫声望+2，商路更稳")
		host.add_lineage_event(msgs[-1])
	host.mark_dirty()
	return msgs

static func holding_yield_preview(host, hid: String) -> Dictionary:
	var def = HOLDING_DEFS.get(hid, {})
	var lv = maxi(1, CKEconomyState.holding_level(host, hid))
	var mul = lv
	var st = CKEconomyState.steward_of(host, hid)
	var trait_bonus = 0
	if st != null:
		mul += 1  # 庄头加成一档产出
		# 能干庄头：指挥/技术高或正面禀性再加产
		if int(st.stats.get("ldr", 0)) >= 12 or int(st.stats.get("skl", 0)) >= 12:
			trait_bonus += 1
		for tr in st.traits:
			if str(tr) in ["diligent", "iron_gut", "brave", "shrewd", "loyal"]:
				trait_bonus += 1
				break
		mul += trait_bonus
	if bool(host.house_mods.get("estate_bonus", false)):
		mul += 1  # 四野旗庄：属地月结+1成
	if bool(host.house_mods.get("estate_patrol", false)):
		mul += 0  # 巡逻主要抗劫，产出在 monthly 另记
	var food_v = int(def.get("food", 0)) * mul
	var sil_v = int(def.get("silver", 0)) * mul
	var herb_v = int(def.get("herb", 0)) * mul
	var focus = CKEconomyState.holding_focus(host, hid)
	if focus == "grain":
		food_v = int(food_v * 1.5)
		sil_v = int(sil_v * 0.75)
	elif focus == "cash":
		sil_v = int(sil_v * 1.5)
		food_v = int(food_v * 0.75)
	elif focus == "fortify":
		food_v = int(food_v * 0.8)
		sil_v = int(sil_v * 0.8)
		herb_v = int(herb_v * 0.8)
	return {
		"food": food_v,
		"silver": sil_v,
		"herb": herb_v,
		"rep": int(def.get("rep", 0)) * mul,
		"steward": st != null,
		"trait_bonus": trait_bonus,
		"focus": focus,
	}

static func holdings_monthly_yield(host) -> String:
	if host.holdings.is_empty():
		return ""
	var sf = 0
	var ss = 0
	var sh = 0
	var sr = 0
	var names: Array = []
	var raids: Array = []
	for hid in host.holdings.keys():
		var def = HOLDING_DEFS.get(hid, {})
		var pv = CKEconomyState.holding_yield_preview(host, hid)
		# 劫掠检定：无庄头且士气偏低时有风险
		var st = CKEconomyState.steward_of(host, hid)
		var raid_chance = 0.0
		if st == null:
			raid_chance = 0.28 if host.morale < 55 else 0.08
		else:
			# 庄头抗劫：基础很低；忠勇/精干更低
			raid_chance = 0.03
			if int(st.stats.get("ldr", 0)) >= 12:
				raid_chance *= 0.5
			if "loyal" in st.traits or "brave" in st.traits:
				raid_chance *= 0.5
		if bool(host.house_mods.get("estate_patrol", false)):
			raid_chance *= 0.35
		if CKEconomyState.holding_focus(host, hid) == "fortify":
			raid_chance *= 0.4
		if host.patrol_boost_months > 0:
			raid_chance *= 0.25  # 全堡巡防期
		if CKEconomyState.holding_patrol_boost(host, hid) > 0:
			raid_chance *= 0.3  # 本属地巡防路线
		if raid_chance > 0.0 and host.rng.randf() < raid_chance:
			raids.append(str(def.get("name", hid)))
			continue  # 本月无收成
		sf += int(pv.food)
		ss += int(pv.silver)
		sh += int(pv.herb)
		sr += int(pv.rep)
		var tag = "庄" if st else ""
		names.append("%sLv%d%s" % [def.get("name", hid), CKEconomyState.holding_level(host, hid), tag])
	host.food += sf
	host.silver += ss
	host.herb += sh
	if sr > 0:
		host.add_rep("ashland", sr)
		host.add_rep("riverland", maxi(0, sr - 1))
	var msg = "属地收成：%s → 粮+%d 银+%d%s" % ["、".join(names) if names else "无", sf, ss, (" 药+%d" % sh) if sh else ""]
	if raids:
		msg += "；劫掠：%s（无庄头/士气不稳）" % "、".join(raids)
		host.morale = maxi(0, host.morale - 3 * raids.size())
		host.add_lineage_event("属地劫掠：" + "、".join(raids))
		host.estate_quiet_months = 0
	elif not host.holdings.is_empty():
		host.estate_quiet_months += 1
		if host.estate_quiet_months >= 3:
			msg += "；四野安静（连续%d月无劫）" % host.estate_quiet_months
			# 戍卫偏向属地：安静期微加银（中长经营反馈）
			var fort_n = 0
			for hid2 in host.holdings.keys():
				if CKEconomyState.holding_focus(host, hid2) == "fortify":
					fort_n += 1
			if fort_n > 0 and host.estate_quiet_months % 3 == 0:
				var bonus = fort_n
				host.silver += bonus
				msg += "；戍卫安境银+%d" % bonus
	return msg

static func unlocked_holdings_count(host) -> int:
	return host.holdings.size()

static func total_holding_levels(host) -> int:
	var n = 0
	for hid in host.holdings.keys():
		n += CKEconomyState.holding_level(host, hid)
	return n

static func ambition_list(host) -> Array:
	## UI：列出堡志与完成状态
	return [
		{"id": "fort_tier3", "name": "灰旗威仪", "desc": "全部工事达到 Lv3", "done": bool(host.ambition_done.get("fort_tier3", false)), "reward": "战技点+2，丰收声望"},
		{"id": "fort_tier5", "name": "百年旗堡", "desc": "全部工事达到 Lv5", "done": bool(host.ambition_done.get("fort_tier5", false)), "reward": "战技点+3，月结旗堡俸"},
		{"id": "warlord", "name": "陆桥战勋", "desc": "战棋委任首通累计 5 次", "done": bool(host.ambition_done.get("warlord", false)), "reward": "战技点+1，开战银+10"},
		{"id": "warlord_x", "name": "百战旗影", "desc": "战棋委任首通累计 10 次", "done": bool(host.ambition_done.get("warlord_x", false)), "reward": "战技点+2，开战银再+10"},
		{"id": "heirs_two", "name": "双嗣承旗", "desc": "至少两名子嗣授旗入队", "done": bool(host.ambition_done.get("heirs_two", false)), "reward": "声望+8，战技点+1"},
		{"id": "vow_house", "name": "家训既立", "desc": "完成联姻誓约并选定家训", "done": bool(host.ambition_done.get("vow_house", false)), "reward": "家训永久生效"},
		{"id": "estate_two", "name": "两岸租佃", "desc": "解锁至少 2 处属地", "done": bool(host.ambition_done.get("estate_two", false)), "reward": "战技点+1，银+40"},
		{"id": "estate_all", "name": "四野旗庄", "desc": "解锁全部 4 处属地", "done": bool(host.ambition_done.get("estate_all", false)), "reward": "战技点+2，属地月结+1成"},
		{"id": "estate_deep", "name": "深耕三稔", "desc": "属地总等级合计 ≥ 8", "done": bool(host.ambition_done.get("estate_deep", false)), "reward": "战技点+1，粮+30"},
		{"id": "silver_hoard", "name": "库银盈柜", "desc": "银币一度达到 300", "done": bool(host.ambition_done.get("silver_hoard", false)), "reward": "战技点+1，市集永久微利"},
		{"id": "roster_six", "name": "六旗同升", "desc": "花名册满员达 6 人", "done": bool(host.ambition_done.get("roster_six", false)), "reward": "战技点+1，士气+10"},
		{"id": "skill_adept", "name": "战技通识", "desc": "任意一人解锁 3 个二阶及以上战技", "done": bool(host.ambition_done.get("skill_adept", false)), "reward": "战技点+2"},
		{"id": "estate_steward", "name": "庄头遍野", "desc": "至少 2 处属地派驻庄头", "done": bool(host.ambition_done.get("estate_steward", false)), "reward": "战技点+1，士气+5"},
		{"id": "estate_patrol", "name": "四野巡防", "desc": "属地连续 3 月无劫掠（须已开垦）", "done": bool(host.ambition_done.get("estate_patrol", false)), "reward": "战技点+1，属地抗劫强化"},
		{"id": "doctrine_year", "name": "家训周岁", "desc": "立家训后度过 12 个月", "done": bool(host.ambition_done.get("doctrine_year", false)), "reward": "家训月结翻倍一个月记"},
		{"id": "forge_fine", "name": "精刃满匣", "desc": "花名册至少 3 人持精灰刃", "done": bool(host.ambition_done.get("forge_fine", false)), "reward": "战技点+1，铁+4"},
	]

static func check_ambitions(host) -> Array:
	var msgs: Array = []
	if not bool(host.ambition_done.get("fort_tier3", false)) and CKEconomyState._all_buildings_at_least(host, 3):
		host.ambition_done["fort_tier3"] = true
		host.house_mods["ash_prestige"] = true
		host.add_skill_point(2)
		msgs.append("堡志「灰旗威仪」达成：战技点+2")
		host.add_lineage_event("堡志：灰旗威仪")
	if not bool(host.ambition_done.get("fort_tier5", false)) and CKEconomyState._all_buildings_at_least(host, 5):
		host.ambition_done["fort_tier5"] = true
		host.house_mods["century_fort"] = true
		host.add_skill_point(3)
		host.silver += 80
		msgs.append("堡志「百年旗堡」达成：战技点+3，银+80")
		host.add_lineage_event("堡志：百年旗堡")
	if not bool(host.ambition_done.get("warlord", false)) and int(host.house_mods.get("war_memory", 0)) >= 5:
		host.ambition_done["warlord"] = true
		host.house_mods["warlord_purse"] = true
		host.add_skill_point(1)
		msgs.append("堡志「陆桥战勋」达成：战技点+1")
		host.add_lineage_event("堡志：陆桥战勋")
	if not bool(host.ambition_done.get("heirs_two", false)) and CKEconomyState._enlisted_children_count(host) >= 2:
		host.ambition_done["heirs_two"] = true
		host.add_rep("ashland", 8)
		host.add_skill_point(1)
		msgs.append("堡志「双嗣承旗」达成：声望与战技点")
		host.add_lineage_event("堡志：双嗣承旗")
	if not bool(host.ambition_done.get("vow_house", false)) and str(host.house_mods.get("doctrine", "")) != "":
		host.ambition_done["vow_house"] = true
		msgs.append("堡志「家训既立」达成")
		host.add_lineage_event("堡志：家训既立·%s" % host.house_mods.get("doctrine", ""))
	if not bool(host.ambition_done.get("warlord_x", false)) and int(host.house_mods.get("war_memory", 0)) >= 10:
		host.ambition_done["warlord_x"] = true
		host.house_mods["warlord_purse"] = true
		host.house_mods["warlord_purse2"] = true
		host.add_skill_point(2)
		msgs.append("堡志「百战旗影」达成：战技点+2")
		host.add_lineage_event("堡志：百战旗影")
	if not bool(host.ambition_done.get("estate_two", false)) and CKEconomyState.unlocked_holdings_count(host) >= 2:
		host.ambition_done["estate_two"] = true
		host.add_skill_point(1)
		host.silver += 40
		msgs.append("堡志「两岸租佃」达成：银+40，战技点+1")
		host.add_lineage_event("堡志：两岸租佃")
	if not bool(host.ambition_done.get("estate_all", false)) and CKEconomyState.unlocked_holdings_count(host) >= 4:
		host.ambition_done["estate_all"] = true
		host.house_mods["estate_bonus"] = true
		host.add_skill_point(2)
		msgs.append("堡志「四野旗庄」达成：属地月结增强")
		host.add_lineage_event("堡志：四野旗庄")
	if not bool(host.ambition_done.get("estate_deep", false)) and CKEconomyState.total_holding_levels(host) >= 8:
		host.ambition_done["estate_deep"] = true
		host.add_skill_point(1)
		host.food += 30
		msgs.append("堡志「深耕三稔」达成：粮+30")
		host.add_lineage_event("堡志：深耕三稔")
	if not bool(host.ambition_done.get("silver_hoard", false)) and host.silver >= 300:
		host.ambition_done["silver_hoard"] = true
		host.house_mods["market_edge"] = true
		host.add_skill_point(1)
		msgs.append("堡志「库银盈柜」达成：市集微利")
		host.add_lineage_event("堡志：库银盈柜")
	if not bool(host.ambition_done.get("roster_six", false)) and host.roster().size() >= 6:
		host.ambition_done["roster_six"] = true
		host.add_skill_point(1)
		host.morale = mini(100, host.morale + 10)
		msgs.append("堡志「六旗同升」达成")
		host.add_lineage_event("堡志：六旗同升")
	if not bool(host.ambition_done.get("skill_adept", false)):
		for c in host.roster():
			var n2 = 0
			for sid in c.unlocked_skills:
				var sk = host.get_skill(sid)
				if int(sk.get("tier", 1)) >= 2:
					n2 += 1
			if n2 >= 3:
				host.ambition_done["skill_adept"] = true
				host.add_skill_point(2)
				msgs.append("堡志「战技通识」达成：%s" % c.name)
				host.add_lineage_event("堡志：战技通识·%s" % c.name)
				break
	if not bool(host.ambition_done.get("estate_steward", false)):
		var sc = 0
		for hid in host.holdings.keys():
			if str(host.holdings[hid].get("steward_id", "")) != "":
				sc += 1
		if sc >= 2:
			host.ambition_done["estate_steward"] = true
			host.add_skill_point(1)
			host.morale = mini(100, host.morale + 5)
			msgs.append("堡志「庄头遍野」达成")
			host.add_lineage_event("堡志：庄头遍野")
	if not bool(host.ambition_done.get("estate_patrol", false)) and host.estate_quiet_months >= 3 and not host.holdings.is_empty():
		host.ambition_done["estate_patrol"] = true
		host.house_mods["estate_patrol"] = true
		host.add_skill_point(1)
		host.morale = mini(100, host.morale + 4)
		msgs.append("堡志「四野巡防」达成：属地抗劫强化")
		host.add_lineage_event("堡志：四野巡防")
	if not bool(host.ambition_done.get("doctrine_year", false)) and host.doctrine_months >= 12:
		host.ambition_done["doctrine_year"] = true
		host.house_mods["doctrine_mature"] = true
		host.add_skill_point(1)
		msgs.append("堡志「家训周岁」达成：家训月结增强")
		host.add_lineage_event("堡志：家训周岁")
	if not bool(host.ambition_done.get("forge_fine", false)):
		var nf = 0
		for c in host.roster():
			if c.weapon_id == "ash_blade_fine":
				nf += 1
		if nf >= 3:
			host.ambition_done["forge_fine"] = true
			host.add_skill_point(1)
			host.iron += 4
			msgs.append("堡志「精刃满匣」达成")
			host.add_lineage_event("堡志：精刃满匣")
	if msgs:
		host.mark_dirty()
	return msgs

static func upgrade_building(host, id: String) -> Dictionary:
	if id not in BUILDING_NAMES:
		return {"ok": false, "msg": "无此工事"}
	var lv = CKEconomyState.building_level(host, id)
	if lv >= BUILDING_MAX:
		return {"ok": false, "msg": "%s 已至满级" % BUILDING_NAMES[id]}
	var next_lv = lv + 1
	var cost: Dictionary = BUILDING_COST.get(next_lv, {})
	var need_s = int(cost.get("silver", 0))
	var need_i = int(cost.get("iron", 0))
	var need_f = int(cost.get("food", 0))
	if bool(host.house_mods.get("hall_discount", false)) and id == "hall":
		need_s = int(need_s * 0.75)
	if host.silver < need_s or host.iron < need_i or host.food < need_f:
		return {"ok": false, "msg": "不足：需 %d银/%d铁/%d粮" % [need_s, need_i, need_f]}
	host.silver -= need_s
	host.iron -= need_i
	host.food -= need_f
	host.buildings[id] = next_lv
	if id == "shrine":
		host.shrine_level = next_lv
	var fx = ""
	match id:
		"hall":
			fx = "出战编队上限 → %d" % CKEconomyState.max_deploy(host)
			if next_lv >= 4:
				fx += "；月结厅堂津贴"
		"barracks":
			fx = "演武花费 → %d 银；月结士气" % CKEconomyState.train_cost(host)
			if next_lv >= 4:
				fx += "；演武双加更易"
		"market":
			fx = "市集买卖价改善"
			if next_lv >= 4:
				fx += "；月结商税"
		"forge":
			fx = "打造更省料"
			if next_lv >= 4:
				fx += "；精灰刃"
		"shrine":
			fx = "丰收与祈愈增强"
			if next_lv >= 4:
				fx += "；月结微愈"
	host.log_event("工事升级：%s → Lv%d（%s）" % [BUILDING_NAMES[id], next_lv, fx])
	var amb = CKEconomyState.check_ambitions(host)
	var amb_s = ("；" + " / ".join(amb)) if amb else ""
	host.mark_dirty()
	return {"ok": true, "msg": "%s 升至 Lv%d。%s%s" % [BUILDING_NAMES[id], next_lv, fx, amb_s]}

static func building_summary(host) -> String:
	var parts: Array = []
	for id in ["hall", "barracks", "market", "forge", "shrine"]:
		parts.append("%s Lv%d" % [BUILDING_NAMES[id], CKEconomyState.building_level(host, id)])
	return " · ".join(parts)

static func accept_quest(host, qid: String) -> Dictionary:
	var q = null
	for item in host.quests:
		if item["id"] == qid:
			q = item
			break
	if q == null:
		return {"ok": false, "msg": "任务不存在"}
	if q.get("battle", false):
		if q.get("map"):
			host.set_meta("battle_map", str(q.get("map")))
		host.set_meta("active_quest_id", qid)
		return {"ok": true, "battle": true, "quest": q}
	# 自动任务
	var evs = Calendar.advance(int(q.get("months", 1)))
	host.silver += int(q["silver"])
	host.add_rep("ashland", int(q["rep"]))
	if str(q.get("id", "")) == "q_herb":
		host.herb += 2
	if str(q.get("id", "")) == "q_drill":
		host.morale = mini(100, host.morale + 3 + CKEconomyState.building_level(host, "barracks"))
	if str(q.get("id", "")) == "q_bridge":
		host.add_rep("riverland", 4)
	for c in host.roster():
		c.exp += 8 * int(q["stars"])
		host.settle_exp(c)
	var first = CKEconomyState.apply_quest_first_clear(host, qid)
	host.log_event("完成任务「%s」+ %d 银%s" % [q["name"], q["silver"], ("；" + first) if first else ""])
	host.mark_dirty()
	return {"ok": true, "battle": false, "quest": q, "events": evs, "first_clear": first}

static func apply_quest_first_clear(host, qid: String) -> String:
	if bool(host.quest_done.get(qid, false)):
		return ""
	host.quest_done[qid] = true
	var msg := ""
	match qid:
		"q_escort":
			host.house_mods["hall_discount"] = true
			var uh = CKEconomyState.unlock_holding(host, "reed_ford")
			msg = "首通：议事厅升级费用 -25%" + (("；" + uh) if uh else "")
		"q_bridge":
			host.house_mods["trade_route"] = true
			var uh2 = CKEconomyState.unlock_holding(host, "tide_bridge")
			msg = "首通：开通河卫商路（市集更划算，丰收+银）" + (("；" + uh2) if uh2 else "")
		"q_drill":
			host.house_mods["drill_discount"] = true
			msg = "首通：校场演武再减价"
		"q_rumor":
			host.house_mods["spring_insight"] = true
			host.add_skill_point(1)
			msg = "首通：春令耳目 +1 战技点"
		"q_herb":
			host.house_mods["herb_garden"] = true
			var uh3 = CKEconomyState.unlock_holding(host, "fog_vale")
			msg = "首通：雾谷药圃（丰收+药）" + (("；" + uh3) if uh3 else "")
		"q_bandit":
			host.house_mods["war_memory"] = int(host.house_mods.get("war_memory", 0)) + 1
			host.morale = mini(100, host.morale + 2)
			var uh4 = CKEconomyState.unlock_holding(host, "stone_slope")
			msg = "首通战勋：士气+2" + (("；" + uh4) if uh4 else "")
		"q_hill_war", "q_ford_war", "q_fog_war", "q_forge_war", "q_shrine_war":
			host.house_mods["war_memory"] = int(host.house_mods.get("war_memory", 0)) + 1
			host.morale = mini(100, host.morale + 2)
			msg = "首通战勋：士气+2，战勋记 %d" % int(host.house_mods["war_memory"])
		_:
			msg = "首通记入陆桥簿"
	if msg != "":
		host.add_lineage_event("委任首通：「%s」——%s" % [qid, msg])
	for am in CKEconomyState.check_ambitions(host):
		if msg:
			msg += "；" + am
		else:
			msg = am
	return msg

static func on_battle_quest_victory(host) -> void:
	var qid = str(host.get_meta("active_quest_id", ""))
	if qid == "":
		return
	var first = CKEconomyState.apply_quest_first_clear(host, qid)
	if first:
		host.log_event(first)
	host.remove_meta("active_quest_id")

static func apply_monthly_upkeep(host) -> String:
	var wage = 0
	var mouths = 0
	for c in host.characters.values():
		if not c.alive:
			continue
		if c.in_roster:
			wage += c.salary
			mouths += 1
		elif c.is_child:
			mouths += 1
	host.silver -= wage
	var food_need = maxi(1, mouths)
	host.food -= food_need
	# A century of harvests with no sink became a grain ocean. Surplus above two years of rations spoils.
	var granary := maxi(120, mouths * 24)
	if host.food > granary:
		host.food = granary + int(float(host.food - granary) * 0.82)
	var msg = "月结：工资 -%d 银，粮 -%d" % [wage, food_need]
	var paid: bool = int(host.silver) >= 0
	if not paid:
		host.morale = maxi(0, host.morale - 15)
		msg += "；银币见红，士气下降"
		host.silver = 0
	var pay_note: String = CKMorale.on_payday(host, paid)
	if pay_note != "":
		msg += "；" + pay_note
	if host.food < 0:
		host.morale = maxi(0, host.morale - 20)
		host.food = 0
		msg += "；缺粮，士气大降"
		# 儿童负面
		for c in host.characters.values():
			if c.is_child and c.alive and host.rng.randf() < 0.4:
				if "malnourished" not in c.traits:
					c.traits.append("malnourished")
					host.log_event("%s 因缺粮获得「营养不良」" % c.name)
	elif host.food >= 10 and host.morale < 90:
		host.morale = mini(100, host.morale + 2)
	# 校场常训
	if CKEconomyState.building_level(host, "barracks") >= 2:
		host.morale = mini(100, host.morale + CKEconomyState.building_level(host, "barracks") - 1)
		msg += "；校场鼓点士气+%d" % (CKEconomyState.building_level(host, "barracks") - 1)
	# 退役顾问暗助
	for k in host.advisor_bonus.keys():
		var leader = host.get_leader()
		if leader and k in CKCharacter.STAT_KEYS and host.rng.randf() < 0.15:
			leader.stats[k] = mini(int(leader.apt_max.get(k, 20)), int(leader.stats[k]) + 1)
			msg += "；顾问指点 %s+1" % Locale.t("stat_" + k)
			leader.recalc_hp()
			break
	var healed := CKInjury.tick_month(host)
	if healed != "":
		msg += "；" + healed
	return msg

static func apply_harvest(host) -> String:
	host.shrine_level = CKEconomyState.building_level(host, "shrine")
	var prod = 22 + host.shrine_level * 6 + CKEconomyState.building_level(host, "hall") * 2
	host.food += prod
	var sil = 22 + CKEconomyState.building_level(host, "market") * 6
	if bool(host.house_mods.get("trade_route", false)):
		sil += 10
	if bool(host.house_mods.get("vow_trade", false)):
		sil += 8
	host.silver += sil
	var extra := ""
	if bool(host.house_mods.get("herb_garden", false)):
		host.herb += 1
		extra += "，药+1"
	if bool(host.house_mods.get("vow_banner", false)):
		host.add_rep("ashland", 2)
		extra += "，旗饰声望+2"
	if bool(host.house_mods.get("ash_prestige", false)):
		host.add_rep("ashland", 2)
		extra += "，威仪声望+2"
	if bool(host.house_mods.get("century_fort", false)):
		host.silver += 12
		extra += "，旗堡+12银"
	var msg = "丰收结算：+%d 粮，+%d 银（祠堂 Lv%d / 厅 Lv%d）%s" % [prod, sil, host.shrine_level, CKEconomyState.building_level(host, "hall"), extra]
	host.log_event(msg)
	for c in host.roster():
		if CKInjury.on_harvest(c):
			c.injured = false
			host.log_event("祠堂治愈 %s 的临时伤" % c.name)
	return msg

static func heal_at_shrine(host) -> String:
	var n = 0
	var lv := CKEconomyState.building_level(host, "shrine")
	for c in host.roster():
		if c.injured or c.hp < c.max_hp or not CKInjury.record(c).is_empty():
			CKInjury.ease_at_shrine(c, lv)
			c.hp = c.max_hp
			n += 1
	host.log_event("祠堂祈愈：%d 人康复" % n)
	host.mark_dirty()
	return "已清临时伤并回满生命（%d 人）" % n

static func train(host, cid: String) -> Dictionary:
	var c: CKCharacter = host.characters.get(cid)
	if c == null:
		return {"ok": false, "msg": "无此人"}
	var cost = CKEconomyState.train_cost(host)
	if host.silver < cost:
		return {"ok": false, "msg": Locale.t("not_enough_silver")}
	host.silver -= cost
	Calendar.advance(1)
	var key = CKCharacter.STAT_KEYS[host.rng.randi() % CKCharacter.STAT_KEYS.size()]
	# 顾问偏向
	if not host.advisor_bonus.is_empty() and host.rng.randf() < 0.35:
		key = str(host.advisor_bonus.keys()[0])
	var gain = 1
	if CKEconomyState.building_level(host, "barracks") >= 3 and host.rng.randf() < (0.5 if CKEconomyState.building_level(host, "barracks") >= 4 else 0.35):
		gain = 2
	c.stats[key] = mini(int(c.apt_max.get(key, 20)), int(c.stats[key]) + gain)
	if host.rng.randf() < 0.25:
		var all_t = host.data_traits.get("traits", [])
		var t = all_t[host.rng.randi() % all_t.size()]
		if t["id"] not in c.traits and t.get("polarity") == "pos":
			c.traits.append(t["id"])
			host.log_event("%s 训练领悟禀性「%s」" % [c.name, t["name"]])
	c.recalc_hp()
	host.mark_dirty()
	return {"ok": true, "msg": "%s 的%s +%d（花费 %d 银）" % [c.name, Locale.t("stat_" + key), gain, cost]}

static func craft_weapon(host, cid: String) -> Dictionary:
	var cost = CKEconomyState.forge_craft_cost(host)
	if host.iron < int(cost.iron) or host.silver < int(cost.silver):
		return {"ok": false, "msg": "需要 %d 铁与 %d 银" % [cost.iron, cost.silver]}
	var c: CKCharacter = host.characters.get(cid)
	if c == null:
		return {"ok": false, "msg": "选择角色"}
	host.iron -= int(cost.iron)
	host.silver -= int(cost.silver)
	if World.is_world_item(c.weapon_id):  # v8.7: a world weapon goes back to the armory, not the scrap heap
		World.armory[c.weapon_id] = int(World.armory.get(c.weapon_id, 0)) + 1
	c.weapon_id = "ash_blade_fine" if CKEconomyState.building_level(host, "forge") >= 4 else "ash_blade"
	# 负重检查（简化）
	var burden = 4
	var cap = 5 + int(c.stats.get("vit", 8) / 2)
	var warn = ""
	if burden > cap:
		warn = "（负重超限警告）"
	host.log_event("%s 装备灰刃%s" % [c.name, warn])
	host.mark_dirty()
	return {"ok": true, "msg": "打造完成：灰刃 +2 攻" + warn}

static func market_buy(host, item: String, qty: int = 1) -> Dictionary:
	var prices = CKEconomyState.market_buy_prices(host)
	if item not in prices:
		return {"ok": false, "msg": "无此物资"}
	var cost = prices[item] * qty
	if host.silver < cost:
		return {"ok": false, "msg": Locale.t("not_enough_silver")}
	host.silver -= cost
	host.set(item, int(host.get(item)) + qty)
	host.mark_dirty()
	return {"ok": true, "msg": "购入 %s x%d" % [Locale.t(item), qty]}

static func market_sell(host, item: String, qty: int = 1) -> Dictionary:
	var prices = CKEconomyState.market_sell_prices(host)
	if int(host.get(item)) < qty:
		return {"ok": false, "msg": "库存不足"}
	host.set(item, int(host.get(item)) - qty)
	host.silver += prices[item] * qty
	host.mark_dirty()
	return {"ok": true, "msg": "卖出 %s x%d" % [Locale.t(item), qty]}

