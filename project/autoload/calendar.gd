extends Node
## 岁月轴：年月推进、预告、生日、节庆

signal month_advanced(year: int, month: int, events: Array)
signal month_ticked(ctx)
signal festival(name: String)

const ADULT_AGE := 15
const RETIRE_AGE := 55
const DEATH_AGE := 70
const HARVEST_MONTH := 8
const SPRING_MONTH := 5
## Year 1 has no January settlement (the game opens in month 1), so the founding muster
## lands on the third month, after the opening errand has paid out.
const MUSTER_MONTH_Y1 := 3

var year: int = 1
var month: int = 1

var _bus_ready := false

func reset() -> void:
	year = 1
	month = 1

func _ready() -> void:
	_install_month_bus()

## Modules subscribe here. Phases always run pre, economy, family, court, world, post.
func register(phase: String, cb: Callable, order: int = 0) -> void:
	_install_month_bus()
	CKMonthBus.register(phase, cb, order)

func _install_month_bus() -> void:
	if _bus_ready:
		return
	_bus_ready = true
	register("pre", Callable(self, "_tick_life"), 10)
	register("economy", Callable(self, "_tick_holdings"), 10)
	register("economy", Callable(self, "_tick_payroll"), 20)
	register("economy", Callable(self, "_tick_epoch_dues"), 30)
	register("family", Callable(self, "_tick_doctrine"), 10)
	register("family", Callable(self, "_tick_spring"), 20)
	register("family", Callable(self, "_tick_conception"), 30)
	register("post", Callable(self, "_tick_harvest"), 10)
	register("post", Callable(self, "_tick_rival_rumor"), 20)
	register("post", Callable(self, "_tick_rival_deals"), 30)
	register("post", Callable(self, "_tick_court"), 40)

func label() -> String:
	return Locale.t("year_month", [year, month])

## March season band from month (spring 3–5 … winter 12/1/2).
func season_id() -> String:
	if month >= 3 and month <= 5:
		return "spring"
	if month >= 6 and month <= 8:
		return "summer"
	if month >= 9 and month <= 11:
		return "autumn"
	return "winter"

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
	if _is_dues_month(y, m):
		var q: Dictionary = CKEconomyState.epoch_pressure_quote(GameState, y)
		if int(q.get("silver", 0)) > 0:
			ev.append({"type": "epoch_dues", "text": Locale.t("pressure_forecast", [str(q.get("note", "")), int(q.get("silver", 0))])})
	if y == 1 and m == 4:
		ev.append({"type": "spring_purse", "text": Locale.t("pressure_spring")})
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
		CKAutosave.on_month()
	GameState.mark_dirty()
	return all_events

func _apply_month() -> Array:
	var ctx := {"year": year, "month": month, "events": []}
	month_ticked.emit(ctx)
	CKMonthBus.run(ctx)
	return ctx["events"]

func _events(ctx: Dictionary) -> Array:
	return ctx["events"]

func _tick_life(ctx: Dictionary) -> void:
	var evs: Array = _events(ctx)
	# 妊娠倒计时
	for c in GameState.characters.values():
		if not c.alive:
			continue
		if c.pregnant_months >= 0:
			c.pregnant_months -= 1
			if c.pregnant_months < 0:
				_deliver(c, evs)
		if c.birthday_month == month:
			c.age += 1
			var btxt = "%s 现年 %d 岁" % [c.name, c.age]
			# v9.2：生日静默 +1 并进岁课；孩子不再另加早教点。
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
				var rtxt := Locale.t("lb_echo_retire", [c.name, Locale.t("stat_" + best_k)])
				GameState.add_lineage_event(rtxt)
				evs.append({"type": "retire", "text": rtxt, "cid": c.id})
				CKEconomyState.month_echo_note("retire", rtxt)
			if c.age >= DEATH_AGE:
				c.alive = false
				c.in_roster = false
				CKPurse.on_death(c)
				Lineage.widow_partner(c)
				var dtxt := Locale.t("lb_echo_death", [c.name])
				evs.append({"type": "death", "text": dtxt, "cid": c.id})
				CKEconomyState.month_echo_note("death", dtxt)
			if c.is_child and c.age >= ADULT_AGE:
				# Adults leave the child ration. They can still be enlisted; they no longer eat as infants for life.
				c.is_child = false
				var am = "%s 已达授旗年龄——可入花名册授旗；陆桥传『灰旗有嗣』。" % c.name
				evs.append({"type": "adult", "text": am, "cid": c.id})
				GameState.add_lineage_event(am)
				GameState.add_skill_point(1)
				## Y1-B: 授旗年龄 → month_echo.adult；属地/沙漏回读（耐玩传代可感）.
				CKEconomyState.month_echo_note("adult", Locale.t("lb_echo_adult", [c.name]))
				var back := Lineage.end_regency_if_ward(c)
				if back != "":
					evs.append({"type": "regency_end", "text": back, "cid": c.id})
			if c.is_leader and (not c.alive or c.retired):
				var handed: Dictionary = Lineage.transfer_banner("death" if not c.alive else "retire")
				if bool(handed.get("ok", false)):
					var stxt := str(handed.get("msg", ""))
					evs.append({"type": "succession", "text": stxt, "cid": str(handed.get("heir_id", ""))})
					CKEconomyState.month_echo_note("succession", stxt)
				else:
					push_warning("succession failed: %s" % str(handed.get("msg", "")))

func _tick_payroll(ctx: Dictionary) -> void:
	var pay = GameState.apply_monthly_upkeep()
	_events(ctx).append({"type": "payroll", "text": pay})

## balance-v92 三截消耗: each January from year 2 the company pays the era dues (drill /
## castle, dowry and heirlooms / lamp, title and embassy). Shown in the month report and the X5 forecast.
## Year 1 follows the same doc: the first settlement after founding (month 2) pays the muster
## down to three months of wages minus one, and April pays the one-time spring purse back.
func _tick_epoch_dues(ctx: Dictionary) -> void:
	if year == 1 and month == 4:
		var purse: Dictionary = CKEconomyState.apply_spring_purse(GameState)
		GameState.house_mods["spring_purse"] = int(purse.get("silver", 0))
		var purse_tx := Locale.t("pressure_spring_paid") % int(purse.get("silver", 0))
		_events(ctx).append({"type": "spring_purse", "text": purse_tx})
		## Y1-B: 春令预付 → month_echo.dues；属地/沙漏回读（时代压力可感）.
		CKEconomyState.month_echo_note("dues", purse_tx)
		return
	if not _is_dues_month(year, month):
		return
	var paid: Dictionary = CKEconomyState.apply_epoch_pressure(GameState, year)
	var due := int(paid.get("silver", 0))
	GameState.house_mods["epoch_dues"] = {
		"year": year, "month": month, "silver": due, "left": int(GameState.silver),
		"wage": CKEconomyState.monthly_wage(GameState),
		"phase": str(paid.get("phase", "")), "note": str(paid.get("note", "")),
	}
	if due > 0:
		var dues_tx := Locale.t("pressure_month_report", [str(paid.get("note", "")), due, int(GameState.silver)])
		_events(ctx).append({"type": "epoch_dues", "text": dues_tx})
		## Y1-B: 正月/点卯开销 → month_echo.dues；属地/沙漏回读.
		CKEconomyState.month_echo_note("dues", dues_tx)

static func _is_dues_month(y: int, m: int) -> bool:
	return (y == 1 and m == MUSTER_MONTH_Y1) or (y >= 2 and m == 1)

## Births of one term: a litter of 2+ is rare luck rolled at conception (CKFamilyState.roll_litter).
func _deliver(mother: CKCharacter, evs: Array) -> void:
	var litter := maxi(1, int(mother.blood_meta.get("litter", 1)))
	mother.blood_meta.erase("litter")
	mother.blood_meta["last_birth_abs"] = year * 12 + month
	var before := CKFamilyState.born_to(GameState, mother)
	var names: Array = []
	for _i in litter:
		var child = Lineage.birth_child(mother)
		names.append(child.name)
		evs.append({"type": "birth", "text": "%s 诞下 %s" % [mother.name, child.name], "cid": child.id})
	mother.blood_meta["children_born"] = before + litter
	var echo := ""
	if litter > 1:
		var line := Locale.t("birth_multi", [mother.name, litter, "、".join(names)])
		evs.append({"type": "birth", "text": line})
		GameState.add_lineage_event(line)
		echo = line
	elif not names.is_empty():
		echo = Locale.t("lb_echo_birth", [mother.name, str(names[0])])
	if echo != "":
		CKEconomyState.month_echo_note("birth", echo)


func _tick_conception(ctx: Dictionary) -> void:
	for mother in CKFamilyState.tick_conception(GameState, year * 12 + month):
		var line := Locale.t("conceived_again", [mother.name])
		_events(ctx).append({"type": "pregnancy", "text": line, "cid": mother.id})
		## Y1-B: 月结有喜 → month_echo.pregnancy；属地/沙漏回读（诞育已有 birth 回响）.
		CKEconomyState.month_echo_note("pregnancy", Locale.t("lb_echo_pregnancy", [mother.name]))

func _tick_holdings(ctx: Dictionary) -> void:
	var hy = GameState.holdings_monthly_yield()
	if hy != "":
		_events(ctx).append({"type": "holdings", "text": hy})
		GameState.log_event(hy)
		CKEconomyState.month_echo_note("holdings", hy)

func _tick_doctrine(ctx: Dictionary) -> void:
	var dm = GameState.tick_doctrine_and_marriage_month()
	for m in dm:
		_events(ctx).append({"type": "doctrine", "text": m})

func _tick_spring(ctx: Dictionary) -> void:
	if month != SPRING_MONTH:
		return
	var evs: Array = _events(ctx)
	festival.emit("春令节")
	evs.append({"type": "festival", "text": "春令节到来"})
	GameState.refresh_marriage_candidates()
	## Y1-B: 春令联姻池刷新 → month_echo.spring；属地/沙漏回读（耐玩联姻闭环可感）.
	var pool_n := GameState.marriage_candidates.size() if typeof(GameState.marriage_candidates) == TYPE_ARRAY else 0
	var sline := Locale.t("lb_echo_spring", [pool_n])
	evs.append({"type": "spring", "text": sline})
	CKEconomyState.month_echo_note("spring", sline)
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

func _tick_harvest(ctx: Dictionary) -> void:
	if month != HARVEST_MONTH:
		return
	festival.emit("丰收")
	var h = GameState.apply_harvest()
	_events(ctx).append({"type": "harvest", "text": h})
	## Y1-B: 丰收月结 → month_echo.harvest；属地/沙漏回读（耐玩岁课闭环可感）.
	if h != "":
		CKEconomyState.month_echo_note("harvest", h)
	GameState.chapter0_flags["harvest_done"] = true

func _tick_rival_rumor(ctx: Dictionary) -> void:
	if month != 3 and month != 9:
		return
	var st = GameState.get_rival_stance("shuoying") if GameState.has_method("get_rival_stance") else "hostile"
	var rum = "朔影家流言：立场仍为「%s」。可去敌宅交涉或推进余波战役。" % st
	_events(ctx).append({"type": "rival_rumor", "text": rum})
	GameState.add_lineage_event(rum)
	## Y1-B: 敌宅流言月结 → month_echo.rival；属地/沙漏回读（耐玩敌宅闭环可感）.
	CKEconomyState.month_echo_note("rival", rum)

func _tick_rival_deals(ctx: Dictionary) -> void:
	if not GameState.has_method("tick_rival_deals"):
		return
	for msg in GameState.tick_rival_deals():
		_events(ctx).append({"type": "rival_deal", "text": msg})
		## Y1-B: 敌约到期/中段 → 同槽 month_echo.rival（同月；追加）.
		if str(msg) != "":
			CKEconomyState.month_echo_note("rival", str(msg))

func _tick_court(ctx: Dictionary) -> void:
	# NPC royal houses age once each January after the opening year, so the first month of a new game stays quiet.
	if month == 1 and year > 1:
		for line in CKCourt.tick_live(year):
			_events(ctx).append({"type": "court", "text": line})
