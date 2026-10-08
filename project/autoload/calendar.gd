extends Node
## 岁月轴：年月推进、预告、生日、节庆

signal month_advanced(year: int, month: int, events: Array)
signal festival(name: String)

const ADULT_AGE := 15
const RETIRE_AGE := 55
const DEATH_AGE := 70
const HARVEST_MONTH := 8
const SPRING_MONTH := 5

var year: int = 1
var month: int = 1

func reset() -> void:
	year = 1
	month = 1

func label() -> String:
	return Locale.t("year_month", [year, month])

## 推进前预告（X5）
func forecast(months: int = 1) -> Array:
	var events: Array = []
	var y = year
	var m = month
	for i in months:
		m += 1
		if m > 12:
			m = 1
			y += 1
		events.append_array(_events_for(y, m))
	return events

func _events_for(y: int, m: int) -> Array:
	var ev: Array = []
	ev.append({"type": "payroll", "text": "军饷与粮耗结算"})
	for c in GameState.characters.values():
		if not c.alive:
			continue
		if c.birthday_month == m:
			ev.append({"type": "birthday", "text": "%s 生日 → 年龄+1（将满 %d）" % [c.name, c.age + 1], "cid": c.id})
		if c.pregnant_months >= 0:
			var left = c.pregnant_months - 1
			if left <= 0:
				ev.append({"type": "birth", "text": "%s 产期将至" % c.name, "cid": c.id})
			else:
				ev.append({"type": "pregnancy", "text": "%s 妊娠中（余约 %d 月）" % [c.name, left], "cid": c.id})
	if m == SPRING_MONTH:
		ev.append({"type": "festival", "text": "春令节：联姻池刷新"})
	if m == HARVEST_MONTH:
		ev.append({"type": "festival", "text": "丰收月：城堡产出与粮饷总账"})
	return ev

func advance(months: int = 1) -> Array:
	var all_events: Array = []
	for _i in months:
		month += 1
		if month > 12:
			month = 1
			year += 1
		var evs = _apply_month()
		all_events.append_array(evs)
		month_advanced.emit(year, month, evs)
	GameState.mark_dirty()
	return all_events

func _apply_month() -> Array:
	var evs: Array = []
	# 妊娠倒计时
	for c in GameState.characters.values():
		if not c.alive:
			continue
		if c.pregnant_months >= 0:
			c.pregnant_months -= 1
			if c.pregnant_months < 0:
				var child = Lineage.birth_child(c)
				evs.append({"type": "birth", "text": "%s 诞下 %s" % [c.name, child.name], "cid": child.id})
				GameState.chapter0_flags["child_born"] = true
		if c.birthday_month == month:
			c.age += 1
			var btxt = "%s 现年 %d 岁" % [c.name, c.age]
			if c.is_child and c.alive:
				var path = str(GameState.lineage_path.get(c.id, ""))
				if path != "":
					var keys = {"martial": ["str", "vit"], "scholar": ["wil", "per"], "merchant": ["agi", "skl"]}.get(path, [])
					if keys:
						var k2 = keys[GameState.rng.randi() % keys.size()]
						c.stats[k2] = mini(int(c.apt_max.get(k2, 20)), int(c.stats.get(k2, 8)) + 1)
						btxt += "（早教·%s +1）" % Locale.t("stat_" + k2)
			evs.append({"type": "birthday", "text": btxt, "cid": c.id})
			if c.age >= RETIRE_AGE and not c.retired and c.in_roster:
				c.retired = true
				c.in_roster = false
				# 顾问：取其最高六维写入家族顾问加成
				var best_k = "wil"
				var best_v = -1
				for k in CKCharacter.STAT_KEYS:
					if int(c.stats.get(k, 0)) > best_v:
						best_v = int(c.stats.get(k, 0))
						best_k = k
				GameState.advisor_bonus[best_k] = maxi(int(GameState.advisor_bonus.get(best_k, 0)), 1)
				GameState.add_lineage_event("%s 退役任顾问：偏向 %s" % [c.name, Locale.t("stat_" + best_k)])
				evs.append({"type": "retire", "text": "%s 退役任顾问（%s 偏向）" % [c.name, Locale.t("stat_" + best_k)], "cid": c.id})
			if c.age >= DEATH_AGE:
				c.alive = false
				c.in_roster = false
				evs.append({"type": "death", "text": "%s 辞世，入族谱碑" % c.name, "cid": c.id})
			if c.is_child and c.age >= ADULT_AGE:
				# Adults leave the child ration. They can still be enlisted; they no longer eat as infants for life.
				c.is_child = false
				var am = "%s 已达授旗年龄——可入花名册授旗；陆桥传『灰旗有嗣』。" % c.name
				evs.append({"type": "adult", "text": am, "cid": c.id})
				GameState.add_lineage_event(am)
				GameState.add_skill_point(1)
			if c.is_leader and (not c.alive or c.retired):
				var handed: Dictionary = Lineage.transfer_banner("death" if not c.alive else "retire")
				if bool(handed.get("ok", false)):
					evs.append({"type": "succession", "text": str(handed.get("msg", "")), "cid": str(handed.get("heir_id", ""))})
	# 月结粮饷
	var pay = GameState.apply_monthly_upkeep()
	evs.append({"type": "payroll", "text": pay})
	# 属地收成 / 劫掠
	var hy = GameState.holdings_monthly_yield()
	if hy != "":
		evs.append({"type": "holdings", "text": hy})
		GameState.log_event(hy)
	# 家训月份累计 + 联姻月结
	var dm = GameState.tick_doctrine_and_marriage_month()
	for m in dm:
		evs.append({"type": "doctrine", "text": m})
	if month == SPRING_MONTH:
		festival.emit("春令节")
		evs.append({"type": "festival", "text": "春令节到来"})
		GameState.refresh_marriage_candidates()
		# deeper lineage: spring matchmaking gossip + spouse affinity
		var leader = GameState.get_leader()
		if leader and leader.spouse_id != "":
			var sp = GameState.characters.get(leader.spouse_id)
			if sp:
				GameState.add_rep("ashland", 1)
				var msg = "春令联姻廷议：%s 与 %s 的双姓席被记入『可托孤』旁注。" % [leader.name, sp.name]
				evs.append({"type": "lineage_banquet", "text": msg})
				GameState.add_lineage_event(msg)
		for c in GameState.characters.values():
			if c.is_child and c.alive and c.age >= 5 and c.age < ADULT_AGE and c.age % 5 == 0:
				var m2 = "族谱评议：%s（%d岁）血胤条被旅馆抄手临摹——护印压力上升。" % [c.name, c.age]
				evs.append({"type": "lineage_scrutiny", "text": m2, "cid": c.id})
				GameState.add_lineage_event(m2)
				GameState.add_rep("riverland", 1)
	if month == HARVEST_MONTH:
		festival.emit("丰收")
		var h = GameState.apply_harvest()
		evs.append({"type": "harvest", "text": h})
		GameState.chapter0_flags["harvest_done"] = true
	# rival house seasonal rumor
	if month == 3 or month == 9:
		var st = GameState.get_rival_stance("shuoying") if GameState.has_method("get_rival_stance") else "hostile"
		var rum = "朔影家流言：立场仍为「%s」。可去敌宅交涉或推进余波战役。" % st
		evs.append({"type": "rival_rumor", "text": rum})
		GameState.add_lineage_event(rum)
	if GameState.has_method("tick_rival_deals"):
		for msg in GameState.tick_rival_deals():
			evs.append({"type": "rival_deal", "text": msg})
	# NPC royal houses age once each January after the opening year, so the first month of a new game stays quiet.
	if month == 1 and year > 1:
		for line in CKCourt.tick_live(year):
			evs.append({"type": "court", "text": line})
	return evs
