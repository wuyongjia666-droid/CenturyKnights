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
			evs.append({"type": "birthday", "text": "%s 现年 %d 岁" % [c.name, c.age], "cid": c.id})
			if c.age >= RETIRE_AGE and not c.retired and c.in_roster:
				c.retired = true
				c.in_roster = false
				evs.append({"type": "retire", "text": "%s 退役，可任顾问" % c.name, "cid": c.id})
			if c.age >= DEATH_AGE:
				c.alive = false
				c.in_roster = false
				evs.append({"type": "death", "text": "%s 辞世，入族谱碑" % c.name, "cid": c.id})
			if c.is_child and c.age >= ADULT_AGE:
				var am = "%s 已达授旗年龄——可入花名册授旗；陆桥传『灰旗有嗣』。" % c.name
				evs.append({"type": "adult", "text": am, "cid": c.id})
				GameState.add_lineage_event(am)
				GameState.add_skill_point(1)
	# 月结粮饷
	var pay = GameState.apply_monthly_upkeep()
	evs.append({"type": "payroll", "text": pay})
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
	return evs
