class_name CKFamilyState
extends RefCounted
## Marriage candidates and the small family helpers that used to live on GameState.
## Merged ownership moves to the dynasty stream.

const LifeEvents := preload("res://scripts/characters/life_events.gd")
const COMPANIONS_PATH := "res://data/cast/companions_v92.json"
## 后招佣兵「再议」廷帖：每次 15 银，每月最多 2 次。主角团禁用再议。
const COURT_REROLL_SILVER := 15
const COURT_REROLL_MONTHLY_CAP := 2

static var _hero_cast_keys: Dictionary = {}
static var _hero_cast_ready := false

static func hero_cast_keys() -> Dictionary:
	if _hero_cast_ready:
		return _hero_cast_keys
	_hero_cast_ready = true
	_hero_cast_keys = {"leader": true}
	if not FileAccess.file_exists(COMPANIONS_PATH):
		return _hero_cast_keys
	var f := FileAccess.open(COMPANIONS_PATH, FileAccess.READ)
	if f == null:
		return _hero_cast_keys
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return _hero_cast_keys
	for row in parsed.get("companions", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var ck := str(row.get("cast_key", ""))
		if ck != "":
			_hero_cast_keys[ck] = true
	return _hero_cast_keys

## 主角团：团长 + 十二具名同伴。姻缘对象主线固定，不可当普通廷帖刷。
static func is_hero_party(c: CKCharacter) -> bool:
	if c == null:
		return false
	if bool(c.is_leader) or str(c.cast_key) == "leader":
		return true
	var ck := str(c.cast_key)
	if ck == "":
		return false
	return hero_cast_keys().has(ck)

## 团长可持教学/外交廷帖快照；其他主角团成员不进随机廷帖池。
static func uses_court_posts(suitor: CKCharacter) -> bool:
	if suitor == null:
		return true
	if not is_hero_party(suitor):
		return true
	return bool(suitor.is_leader) or str(suitor.cast_key) == "leader"

static func can_reroll_court(suitor: CKCharacter) -> bool:
	return suitor != null and not is_hero_party(suitor)

static func family_members(host) -> Array:
	var out: Array = []
	for c in host.characters.values():
		if c.alive and (c.is_leader or c.spouse_id != "" or c.is_child or c.parent_ids.size() > 0):
			out.append(c)
	return out

static func active_marriage_nation(host) -> String:
	## The court posts whoever lives where the party is standing: castle, city, or that nation's keep.
	var world = Engine.get_main_loop().root.get_node_or_null("World") if Engine.get_main_loop() else null
	if world != null:
		var at := str(world.nation_of(str(world.pos)))
		if _nation_ok(at):
			return at
	if host != null and host.has_meta("marriage_nation"):
		var forced := str(host.get_meta("marriage_nation"))
		if _nation_ok(forced):
			return forced
	return "ashbanner"

static func _nation_ok(nid: String) -> bool:
	return nid != "" and not CKBloodline.nation(nid).is_empty()

static func candidate_nation(c) -> String:
	if c == null:
		return ""
	var mix = c.get("blood_mix") if c.get("blood_mix") != null else {}
	if typeof(mix) != TYPE_DICTIONARY or mix.is_empty():
		return ""
	var best := ""
	var best_w := -1.0
	for k in mix.keys():
		if float(mix[k]) > best_w:
			best_w = float(mix[k])
			best = str(k)
	return CKBloodline.nation_of_line(best)

static func posts_match_nation(host, nid: String) -> bool:
	if nid == "" or host.marriage_candidates.is_empty():
		return false
	for c in host.marriage_candidates:
		if candidate_nation(c) != nid:
			return false
		var mix = c.get("blood_mix")
		if typeof(mix) != TYPE_DICTIONARY:
			continue
		for k in mix.keys():
			var home := CKBloodline.nation_of_line(str(k))
			if home != "" and home != nid:
				return false
	return true


static func _resolve_suitor(host, suitor):
	var who = suitor
	if who == null and host != null:
		var fid := str(host.get("marriage_focus_id") if host.get("marriage_focus_id") != null else "")
		if fid != "" and host.characters.has(fid):
			who = host.characters[fid]
	return who

static func refresh_marriage_candidates(host, nation_id: String = "", suitor = null) -> void:
	## A blank nation keeps the diplomacy-weighted draw. The marriage screen passes the
	## court it is standing in. Calendar, new game, and the century sim pass nothing,
	## so their shared RNG and the portrait bank stay on the previous sequence.
	## suitor (提亲方) drives candidate sex; blank falls back to captain / marriage_focus_id.
	var who = _resolve_suitor(host, suitor)
	## Non-captain hero party: no random court posts (story-named only).
	if who != null and is_hero_party(who) and not uses_court_posts(who):
		host.marriage_nation = nation_id
		host.marriage_candidates.clear()
		return
	host.marriage_nation = nation_id
	host.marriage_candidates.clear()
	for i in 3:
		host.marriage_candidates.append(CharacterFactory.make_marriage_candidate(host.rng, "baron", nation_id, who))
	if who != null and can_reroll_court(who):
		stamp_court_posts_month(host)
	elif who != null and uses_court_posts(who):
		## Captain teaching snapshot: stamp so we do not treat it as "merc stale".
		stamp_court_posts_month(host)

## Fill only when empty / wrong nation / wrong sex / (non-hero) new calendar month.
## Does not spend silver or monthly 再议 quota.
static func ensure_marriage_candidates(host, nation_id: String = "", suitor = null) -> void:
	var who = _resolve_suitor(host, suitor)
	if who != null and is_hero_party(who) and not uses_court_posts(who):
		host.marriage_nation = nation_id
		host.marriage_candidates.clear()
		return
	var need: bool = host.marriage_candidates.is_empty()
	if not need and nation_id != "" and str(host.marriage_nation) != nation_id:
		need = true
	if not need and nation_id != "" and not posts_match_nation(host, nation_id):
		need = true
	if not need and who != null:
		var want := CharacterFactory.spouse_gender_for(who)
		for c in host.marriage_candidates:
			if str(c.gender) != want:
				need = true
				break
	## 后招：上个月三人到了下个月自动作废换新。
	if not need and who != null and can_reroll_court(who) and court_posts_stale(host):
		need = true
	if need:
		refresh_marriage_candidates(host, nation_id, who)

static func court_rerolls_used(host) -> int:
	return int(host.get("marriage_rerolls_used") if host.get("marriage_rerolls_used") != null else 0)

static func court_rerolls_left(host) -> int:
	return maxi(0, COURT_REROLL_MONTHLY_CAP - court_rerolls_used(host))

static func reset_court_rerolls_month(host) -> void:
	if host == null:
		return
	host.marriage_rerolls_used = 0

static func court_month_key() -> int:
	return int(Calendar.year) * 12 + int(Calendar.month)

static func stamp_court_posts_month(host) -> void:
	if host == null:
		return
	host.marriage_posts_month = court_month_key()

static func court_posts_stale(host) -> bool:
	if host == null:
		return true
	return int(host.get("marriage_posts_month") if host.get("marriage_posts_month") != null else -1) != court_month_key()

## 历月推进：后招三人廷帖整批换新（不占再议次数、不扣银）；主角团不动。
static func rotate_court_posts_for_new_month(host) -> String:
	if host == null:
		return ""
	reset_court_rerolls_month(host)
	var who = _resolve_suitor(host, null)
	## Invalidate stamp so a later switch to a merc still gets a fresh draw this month.
	host.marriage_posts_month = -1
	if who != null and can_reroll_court(who):
		var nid := str(host.marriage_nation) if str(host.marriage_nation) != "" else active_marriage_nation(host)
		refresh_marriage_candidates(host, nid, who)
		stamp_court_posts_month(host)
		return Locale.t("ux_court_season_rotate")
	return ""

## Paid court reroll for non-hero suiters only (silver + monthly cap).
static func reroll_marriage_candidates(host, nation_id: String = "", suitor = null) -> Dictionary:
	var who = _resolve_suitor(host, suitor)
	if not can_reroll_court(who):
		return {"ok": false, "msg": Locale.t("ux_hero_no_reroll")}
	var used := court_rerolls_used(host)
	if used >= COURT_REROLL_MONTHLY_CAP:
		return {"ok": false, "msg": Locale.t("ux_reroll_month_cap", [COURT_REROLL_MONTHLY_CAP])}
	if int(host.silver) < COURT_REROLL_SILVER:
		return {"ok": false, "msg": Locale.t("not_enough_silver")}
	host.silver -= COURT_REROLL_SILVER
	host.marriage_rerolls_used = used + 1
	refresh_marriage_candidates(host, nation_id, who)
	host.mark_dirty()
	var left := court_rerolls_left(host)
	return {
		"ok": true,
		"msg": Locale.t("ux_reroll_done", [COURT_REROLL_SILVER, left]),
		"cost": COURT_REROLL_SILVER,
		"left": left,
	}

## Adults who may stand as 提亲方: captain, roster mercs, and keep kin.
static func is_marriage_suitor(c: CKCharacter) -> bool:
	if c == null or not c.alive or bool(c.retired):
		return false
	if int(c.age) < Calendar.ADULT_AGE:
		return false
	if c.is_leader or c.in_roster:
		return true
	if str(c.spouse_id) != "" or not c.parent_ids.is_empty() or bool(c.is_child) or str(c.family_id) != "":
		return true
	return false

static func marriage_suitors(host) -> Array:
	var out: Array = []
	if host == null:
		return out
	for c in host.characters.values():
		if is_marriage_suitor(c):
			out.append(c)
	out.sort_custom(func(a, b):
		var sa := 0 if a.is_leader else (1 if a.in_roster else 2)
		var sb := 0 if b.is_leader else (1 if b.in_roster else 2)
		if sa != sb:
			return sa < sb
		return str(a.name) < str(b.name)
	)
	return out

static func tick_doctrine_and_marriage_month(host) -> Array:
	var msgs: Array = []
	## 后招：再议次数清零 + 上月三人廷帖整批换新（不占再议额度）。
	var rotate_msg := rotate_court_posts_for_new_month(host)
	if rotate_msg != "":
		msgs.append(rotate_msg)
		host.add_lineage_event(rotate_msg)
	host.tick_patrol_month()
	if host.patrol_boost_months > 0:
		msgs.append("巡防仍在：抗劫剩余 %d 月" % host.patrol_boost_months)
	var doctrine = str(host.house_mods.get("doctrine", ""))
	if doctrine != "":
		host.doctrine_months += 1
		var mul = 2 if bool(host.house_mods.get("doctrine_mature", false)) else 1
		var dline := ""
		match doctrine:
			"strict":
				host.morale = mini(100, host.morale + 1 * mul)
				dline = "家训·严教：士气+%d（第 %d 月）" % [1 * mul, host.doctrine_months]
			"mercy":
				host.food += 1 * mul
				host.morale = mini(100, host.morale + 1 * mul)
				dline = "家训·仁恤：粮+%d 士气+%d（第 %d 月）" % [1 * mul, 1 * mul, host.doctrine_months]
			"trade", "commerce":
				host.silver += 2 * mul
				dline = "家训·商本：银+%d（第 %d 月）" % [2 * mul, host.doctrine_months]
			_:
				dline = "家训仍在：第 %d 月" % host.doctrine_months
		if dline != "":
			msgs.append(dline)
			## Y1-B: 家训月结 → month_echo.doctrine；属地/沙漏回读.
			CKEconomyState.month_echo_note("doctrine", dline)
	## Y1-B: 堡志月结不再门闩家训——无家训时库银/属地/花名册目标仍可月结达成并写入 month_echo.ambition.
	var amb = host.check_ambitions()
	for a in amb:
		msgs.append(a)
	# 联姻月结：全员成婚对涨士气（封顶）；银仍只跟团长配偶同席，保住战役经济锁
	var seen_pairs: Dictionary = {}
	var morale_gain := 0
	var names: Array = []
	for c in host.characters.values():
		if c == null or not c.alive or str(c.spouse_id) == "":
			continue
		var sid := str(c.spouse_id)
		if not host.characters.has(sid):
			continue
		var sp: CKCharacter = host.characters[sid]
		if sp == null or not sp.alive:
			continue
		var a := str(c.id)
		var b := sid
		var key := a + "|" + b if a < b else b + "|" + a
		if seen_pairs.has(key):
			continue
		seen_pairs[key] = true
		morale_gain += 1
		names.append(sp.name if bool(c.is_leader) else c.name)
	const MARRIAGE_MONTH_MORALE_CAP := 3
	var silver_gain := 0
	var leader = host.get_leader()
	if leader != null and str(leader.spouse_id) != "" and host.characters.has(str(leader.spouse_id)):
		var lsp: CKCharacter = host.characters[str(leader.spouse_id)]
		if lsp != null and lsp.alive and bool(lsp.in_roster):
			silver_gain = 1
	if morale_gain > 0 or silver_gain > 0:
		var m := mini(MARRIAGE_MONTH_MORALE_CAP, morale_gain)
		host.morale = mini(100, host.morale + m)
		host.silver += silver_gain
		var who := "、".join(names.slice(0, 3)) if not names.is_empty() else ""
		if names.size() > 3:
			who += Locale.t("ux_marriage_month_etc")
		var line := Locale.t("ux_marriage_month_line", [who if who != "" else "—", m])
		if silver_gain > 0:
			line += Locale.t("ux_marriage_month_silver", [silver_gain])
		msgs.append(line)
		host.add_lineage_event(line)
		CKEconomyState.month_echo_note("marriage", line)
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
	LifeEvents.ensure()
	CKSuiKe.ensure()
	host.mark_dirty()
	return msgs

static func build_dynasty_journal(host) -> String:
	## G-06: closing hand-note assembled from prologue pro_* flags (opening-chain-review §示例 C).
	var leader = host.get_leader()
	var spouse_name = "（未成婚）"
	var child_summary = "（无子嗣）"
	var heir_name := ""
	if leader and leader.spouse_id != "" and host.characters.has(leader.spouse_id):
		spouse_name = host.characters[leader.spouse_id].name
	var kids: Array = []
	for c in host.characters.values():
		if c.is_child or (leader and c.id in leader.children_ids):
			kids.append("%s〔%s〕" % [c.name, c.bloodline_display()])
			if heir_name == "" and str(c.name).strip_edges() != "":
				heir_name = str(c.name)
	if kids.size() > 0:
		child_summary = "、".join(kids)
	var arcs: PackedStringArray = PackedStringArray()
	if host.flag("pro_merit_own"):
		arcs.append(Locale.t("pro_journal_merit_own"))
	elif host.flag("pro_merit_patron"):
		arcs.append(Locale.t("pro_journal_merit_patron"))
	if host.flag("pro_lease_pawned"):
		arcs.append(Locale.t("pro_journal_lease_pawned"))
	elif host.flag("pro_lease_kept"):
		arcs.append(Locale.t("pro_journal_lease_kept"))
	if host.flag("pro_roster_wantan"):
		arcs.append(Locale.t("pro_journal_roster_wantan"))
	elif host.flag("pro_roster_blank"):
		arcs.append(Locale.t("pro_journal_roster_blank"))
	if host.flag("pro_rival_spared") or host.flag("pro_survivor_kept"):
		arcs.append(Locale.t("pro_journal_rival_spared"))
	elif host.flag("pro_rival_exposed") or host.flag("pro_survivor_handed"):
		arcs.append(Locale.t("pro_journal_rival_exposed"))
	var arc_block := "\n".join(arcs)
	if arc_block != "":
		arc_block = "\n" + arc_block
	var heir_bit := heir_name if heir_name != "" else Locale.t("pro_journal_heir_none")
	var closing := Locale.t("pro_journal_closing", [heir_bit])
	host.dynasty_journal = Locale.t("pro_journal_body", [
		leader.name if leader else "?",
		spouse_name,
		child_summary,
		Calendar.label(),
		host.get_rep_name("ashland"),
		host.get_rep_name("riverland"),
		arc_block,
		closing,
	])
	host.set_flag("chapter0_done")
	host.mark_dirty()
	return host.dynasty_journal


static func _zh(key: String, args: Array = []) -> String:
	return CKFamilyState.new().tr(Locale.t(key, args))


static func _tier_zh(tier: int) -> String:
	if tier <= 0:
		return _zh("tier_hidden")
	return _zh("tier_%d" % tier)

## Player-facing gestation, in month ticks. The stored counter is one less,
## because Calendar births on the tick that steps below zero.
## Peak term ~10 months (random 9–11). Fast-family debug stays at 1.
const TERM_MONTHS_MIN := 9
const TERM_MONTHS_MAX := 11
const TERM_MONTHS := 10  ## display default / mid-band
const FAST_TERM_MONTHS := 1
## Even at peak fertility, marriage/conception is not certain.
const PEAK_CONCEPTION_CHANCE := 0.72


## Unborn child: aptitude band, tactical-trait odds, royal-skill tier odds.
## Reads the two parents' genomes. Does not draw.
static func combat_expectation(a: Object, b: Object) -> Dictionary:
	if a == null or b == null:
		return {
			"apt_min": {}, "apt_max": {},
			"apt_zh": _zh("expect_apt_empty"),
			"tactics": [], "tactics_zh": _zh("expect_tactic_empty"),
			"royal_tiers": [], "royal_zh": _zh("expect_royal_empty"),
			"line": _zh("expect_line_empty"),
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
		"line": _zh("expect_line", _clauses([apt_zh, tactics_zh, royal_zh])),
	}


## Living offspring sheet. Parents come from the family roster on host.
static func child_archive(host, child: Object) -> Dictionary:
	var blank := {
		"parents": [],
		"apt_zh": _zh("archive_apt_missing"),
		"tactics_now": {},
		"tactics_zh": _zh("archive_tactic_dash"),
		"royal_tier": 0,
		"royal_zh": _zh("archive_royal_dash"),
		"forecast": {},
		"line": _zh("archive_line_missing"),
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
		apt_zh = _zh("archive_apt_grown")
	var mods: Dictionary = CKBloodPayoff.tactical_mods(child)
	var tier := CKBloodPayoff.royal_skill_tier(child)
	var forecast := {}
	var tactics_zh := _mods_zh(mods)
	var royal_zh := _zh("archive_royal_now", [_tier_zh(tier)])
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
		"line": _zh("archive_line", _clauses([apt_zh, tactics_zh, royal_zh])),
	}


static func _apt_band_zh(amin, amax) -> String:
	if typeof(amin) != TYPE_DICTIONARY or typeof(amax) != TYPE_DICTIONARY or amin.is_empty():
		return ""
	var bits: Array = []
	for k in CKCharacter.STAT_KEYS:
		if not amin.has(k):
			continue
		bits.append("%s%d-%d" % [_zh("apt_stat_" + str(k)), int(amin[k]), int(amax.get(k, amin[k]))])
	if bits.is_empty():
		return ""
	return _zh("archive_apt_band", [" ".join(bits)])


static func _tactics_zh(rows: Array, limit: int) -> String:
	if rows.is_empty():
		return _zh("archive_tactic_none")
	var bits: Array = []
	for t in rows.slice(0, limit):
		bits.append("%s %d%%（%s）" % [str(t.get("zh", "")), int(round(float(t.get("p", 0.0)) * 100.0)), str(t.get("effect", ""))])
	return _zh("archive_tactic_list", ["、".join(bits)])


static func fast_family(host) -> bool:
	if host == null:
		return false
	var mods = host.house_mods if host.get("house_mods") is Dictionary else {}
	return bool(mods.get("fast_family", false))


static func set_fast_family(host, on: bool) -> void:
	if host == null:
		return
	host.house_mods["fast_family"] = on
	if host.has_method("mark_dirty"):
		host.mark_dirty()


static func term_months(host) -> int:
	if fast_family(host):
		return FAST_TERM_MONTHS
	var rng = host.rng if host != null else null
	if rng != null:
		return rng.randi_range(TERM_MONTHS_MIN, TERM_MONTHS_MAX)
	return TERM_MONTHS


## 16–32 peak, then a decline, none before 16 or after 48.
## A rate of 1 does not roll, so a young wedding spends no extra RNG.
static func fertility_of(age: int) -> float:
	if age < 16 or age > 48:
		return 0.0
	if age <= 32:
		return 1.0
	if age <= 40:
		return 0.55
	return 0.20


static func conception_rate(person) -> float:
	if person == null:
		return 0.0
	if CKBloodFusion.is_sterile(person):
		return 0.0
	return fertility_of(int(person.age))


## ── Repeat natural conception (user decision 2026-10-17) ──
## A married, fertile couple can conceive again every month after a postpartum rest. The first two
## children use a fertility floor, so a normal marriage almost always reaches two; later children
## get rarer by parity but never reach zero (no cap). Multiples are near-real odds, pure luck:
## no trait, rite, bloodline or vow changes them.
const BASE_MONTHLY := 0.10
const POSTPARTUM_MONTHS := 12
const PARITY := [1.0, 1.0, 0.15, 0.10, 0.05]
const PARITY_TAIL := 0.7
const FLOOR_FERTILITY := 0.55
const FLOOR_AGE := 45
## Checked rarest first: quadruplets 1/700000, triplets 1/8000, twins 1/85.
const LITTER_ODDS := [[4, 1.0 / 700000.0], [3, 1.0 / 8000.0], [2, 1.0 / 85.0]]


static func parity_factor(born: int) -> float:
	if born < PARITY.size():
		return float(PARITY[born])
	return float(PARITY[PARITY.size() - 1]) * pow(PARITY_TAIL, born - PARITY.size() + 1)


## Children this mother has borne (alive or not). Cached in blood_meta.children_born, which
## Calendar bumps per birth; a save without it is counted from parent_ids once.
static func born_to(host, mother) -> int:
	if mother.blood_meta.has("children_born"):
		return int(mother.blood_meta["children_born"])
	var n := 0
	for c in host.characters.values():
		if mother.id in c.parent_ids:
			n += 1
	mother.blood_meta["children_born"] = n
	return n


static func monthly_conception_chance(age: int, born: int) -> float:
	var fert := fertility_of(age)
	if born < 2 and age >= 16 and age <= FLOOR_AGE:
		fert = maxf(fert, FLOOR_FERTILITY)
	return BASE_MONTHLY * fert * parity_factor(born)


static func roll_litter(rng) -> int:
	if rng == null:
		return 1
	var r: float = rng.randf()
	for row in LITTER_ODDS:
		if r < float(row[1]):
			return int(row[0])
	return 1


## The living, linked spouse when `mother` can conceive this month, else null.
static func conceiving_partner(host, mother, abs_month: int):
	if mother == null or not mother.alive or str(mother.gender) != "f" or mother.pregnant_months >= 0:
		return null
	if str(mother.spouse_id) == "":
		return null
	var father = host.characters.get(str(mother.spouse_id))
	if father == null or not father.alive or str(father.spouse_id) != str(mother.id) or int(father.age) < 16:
		return null
	if CKBloodFusion.is_sterile(mother) or CKBloodFusion.is_sterile(father):
		return null
	var last := int(mother.blood_meta.get("last_birth_abs", -9999))
	if abs_month - last < POSTPARTUM_MONTHS:
		return null
	return father


## One monthly pass over every married woman. Returns the mothers who conceived.
static func tick_conception(host, abs_month: int) -> Array:
	var out: Array = []
	for c in host.characters.values():
		if conceiving_partner(host, c, abs_month) == null:
			continue
		var p := monthly_conception_chance(int(c.age), born_to(host, c))
		if p <= 0.0 or host.rng.randf() >= p:
			continue
		_start_term(host, c)
		out.append(c)
	return out


static func _start_term(host, mother) -> void:
	var term := term_months(host)
	mother.pregnant_months = maxi(0, term - 1)
	mother.blood_meta["gestation_term"] = term
	var litter := roll_litter(host.rng if host != null else null)
	if litter > 1:
		mother.blood_meta["litter"] = litter
	else:
		mother.blood_meta.erase("litter")


static func begin_pregnancy(host, mother) -> bool:
	if mother == null:
		return false
	var rate := conception_rate(mother)
	if rate <= 0.0:
		mother.pregnant_months = -1
		return false
	var rng = host.rng if host != null else null
	## Peak fertility used to skip the roll (rate==1); still roll PEAK_CONCEPTION_CHANCE.
	var chance := rate if rate < 1.0 else PEAK_CONCEPTION_CHANCE
	if rng != null and rng.randf() >= chance:
		mother.pregnant_months = -1
		return false
	if rng == null and chance < 1.0:
		mother.pregnant_months = -1
		return false
	_start_term(host, mother)
	## Y1-B: 婚仪/验血起孕 → month_echo.pregnancy（与 Calendar tick_conception 同槽）.
	CKEconomyState.month_echo_note("pregnancy", Locale.t("lb_echo_pregnancy", [mother.name]))
	return true


static func _mods_zh(mods: Dictionary) -> String:
	if mods.is_empty():
		return _zh("archive_tactic_unshown")
	var bits: Array = []
	for k in mods.keys():
		bits.append("%s +%s" % [str(k), str(mods[k])])
	return _zh("archive_tactic_list", ["、".join(bits)])


## Each clause is joined with "。" by the template; drop a clause's own trailing stop so lines never read "。。".
static func _clauses(parts: Array) -> Array:
	var out: Array = []
	for p in parts:
		out.append(str(p).strip_edges().rstrip("。."))
	return out
