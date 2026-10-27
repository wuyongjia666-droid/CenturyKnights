class_name CKTerritory
extends RefCounted
## v9.3 territory: neutral sites on the atlas the company can capture.
## State lives in World.territory. Design: docs/design/territory.md.
## The home castle (World.data.home) is never a site and can never be lost.

const DATA_PATH := "res://data/territory_v93.json"
const OWN := "company"
const NEUTRAL := ""
const SCHEMA := 1

static var _data: Dictionary = {}
static var _sites: Dictionary = {}
static var rng := RandomNumberGenerator.new()
## Last apply_month structured report for Atlas TerritoryMonthModal.
static var last_month_report: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		if FileAccess.file_exists(DATA_PATH):
			var d = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
			if typeof(d) == TYPE_DICTIONARY:
				_data = d
		_sites.clear()
		for s in _data.get("sites", []):
			_sites[str(s.id)] = s
		rng.randomize()
	return _data

static func rule(key: String, fallback: float = 0.0) -> float:
	return float(data().get("rules", {}).get(key, fallback))

static func site_ids() -> Array:
	data()
	var ids: Array = _sites.keys()
	ids.sort()
	return ids

static func site(id: String) -> Dictionary:
	data()
	return _sites.get(id, {})

static func kind_zh(kind: String) -> String:
	return str(data().get("kinds", {}).get(kind, {}).get("zh", kind))

static func sites_at(anchor: String) -> Array:
	var out: Array = []
	for id in site_ids():
		if str(_sites[id].anchor) == anchor:
			out.append(id)
	return out

static func sites_in(nation: String) -> Array:
	var out: Array = []
	for id in site_ids():
		if str(_sites[id].nation) == nation:
			out.append(id)
	return out

static func is_home(id: String) -> bool:
	return id == str(World.data.get("home", "hq"))

# ── state ─────────────────────────────────────────────
static func fresh() -> Dictionary:
	return {"v": SCHEMA, "sites": {}, "log": [], "stockade_credit": 0, "news": []}

static func _st() -> Dictionary:
	if typeof(World.territory) != TYPE_DICTIONARY or not World.territory.has("sites"):
		World.territory = fresh()
	return World.territory

static func state(id: String) -> Dictionary:
	var row = _st().sites.get(id, {})
	var d: Dictionary = row if typeof(row) == TYPE_DICTIONARY else {}
	return {
		"owner": str(d.get("owner", NEUTRAL)), "garrison": int(d.get("garrison", 0)),
		"unrest": int(d.get("unrest", 0)), "stockade": bool(d.get("stockade", false)), "contract": bool(d.get("contract", false)),
		"threat": d.get("threat", {}) if typeof(d.get("threat", {})) == TYPE_DICTIONARY else {},
		"cache_food": int(d.get("cache_food", 0)),
		"contest": d.get("contest", {}) if typeof(d.get("contest", {})) == TYPE_DICTIONARY else {},
	}

static func _put(id: String, s: Dictionary) -> void:
	var empty_threat := (s.threat as Dictionary).is_empty()
	var empty_cache := int(s.get("cache_food", 0)) <= 0
	var cont: Dictionary = s.get("contest", {}) if typeof(s.get("contest", {})) == TYPE_DICTIONARY else {}
	if str(s.owner) == NEUTRAL and int(s.garrison) == 0 and int(s.unrest) == 0 and empty_threat and empty_cache and cont.is_empty() and not bool(s.get("stockade", false)):
		_st().sites.erase(id)
	else:
		_st().sites[id] = s

static func owner(id: String) -> String:
	return str(state(id).owner)

static func owned(id: String) -> bool:
	return owner(id) == OWN

static func owned_ids() -> Array:
	var out: Array = []
	for id in site_ids():
		if owned(id):
			out.append(id)
	return out

## Save payload: only sites that differ from neutral are stored.
static func to_save() -> Dictionary:
	return _st().duplicate(true)

## Migration: old saves have no territory key -> everything neutral.
static func from_save(raw) -> Dictionary:
	var out := fresh()
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var rows = raw.get("sites", {})
	if typeof(rows) == TYPE_DICTIONARY:
		for id in rows.keys():
			var sid := str(id)
			if site(sid).is_empty() or is_home(sid) or typeof(rows[id]) != TYPE_DICTIONARY:
				continue
			var r: Dictionary = rows[id]
			var th = r.get("threat", {})
			var stockade := bool(r.get("stockade", false))
			var ct = r.get("contest", {})
			out.sites[sid] = {
				"owner": str(r.get("owner", NEUTRAL)),
				"garrison": clampi(int(r.get("garrison", 0)), 0, int(rule("garrison_max", 3)) + (1 if stockade else 0)),
				"stockade": stockade, "contract": bool(r.get("contract", false)),
				"unrest": maxi(0, int(r.get("unrest", 0))),
				"threat": th if typeof(th) == TYPE_DICTIONARY else {},
				"cache_food": maxi(0, int(r.get("cache_food", 0))),
				"contest": ct if typeof(ct) == TYPE_DICTIONARY else {},
			}
	out.stockade_credit = maxi(0, int(raw.get("stockade_credit", 0)))
	var nw = raw.get("news", [])
	if typeof(nw) == TYPE_ARRAY:
		for e in nw:
			if typeof(e) == TYPE_DICTIONARY and not site(str(e.get("id", ""))).is_empty():
				out.news.append(e)
	var lg = raw.get("log", [])
	if typeof(lg) == TYPE_ARRAY:
		out.log = lg.slice(0, 20)
	return out

static func _log(t: String) -> void:
	var lg: Array = _st().log
	lg.push_front("%s · %s" % [World.date_label(), t])
	if lg.size() > 20:
		lg.resize(20)
	World._tlog(t)
	GameState.log_event(t)

# ── capture ───────────────────────────────────────────
static func req_rep(id: String) -> int:
	var nid := str(site(id).get("nation", ""))
	if World.nation_stance(nid) == "hostile":
		return int(rule("req_nation_rep_hostile", 30))
	return int(rule("req_nation_rep", 10))

## "" when the company may try to take this site now, else the reason.
static func capture_block(id: String, need_presence: bool = true) -> String:
	var s := site(id)
	if s.is_empty() or is_home(id):
		return Locale.t("terr_01")
	if owned(id):
		return Locale.t("terr_02")
	if World.nation_rep(str(s.nation)) < req_rep(id):
		return Locale.t("terr_03") % req_rep(id)
	if owned_ids().size() >= int(rule("max_sites", 8)):
		return Locale.t("terr_04") % int(rule("max_sites", 8))
	if need_presence and World.pos != str(s.anchor):
		return Locale.t("terr_05") % World.node(str(s.anchor)).get("name", "")
	if not World.encounter.is_empty():
		return Locale.t("terr_06")
	return ""

static func assault_danger(id: String) -> int:
	var d := int(site(id).get("danger", 1)) + 1
	if owner(id).begins_with("rival:"):
		d += 1
	return clampi(d, 1, 4)

static func assault(id: String) -> Dictionary:
	var why := capture_block(id)
	if why != "":
		return {"ok": false, "msg": why}
	var s := site(id)
	var enc := World.start_encounter("territory_assault", {"node": str(s.anchor), "from": str(s.anchor), "site": id, "danger": assault_danger(id)})
	return {"ok": true, "encounter": enc}

static func capture(id: String, how: String) -> Dictionary:
	if is_home(id) or site(id).is_empty():
		return {"ok": false, "msg": Locale.t("terr_01")}
	var st := state(id)
	st.owner = OWN
	st.threat = {}
	st.contest = {}
	st.garrison = maxi(1, int(st.garrison)) if how == "chain" or how == "reclaim" or how == "contest" else 0
	if how == "assault":
		st.unrest = int(rule("unrest_months", 2))
	elif how == "reclaim" or how == "contest":
		st.unrest = 1
	else:
		st.unrest = 0
	_put(id, st)
	_log(Locale.t("terr_07") % [site(id).name, Locale.t("terr_08") if how == "assault" else Locale.t("terr_09")])
	if how == "contest":
		var ys := int(site(id).yield_silver)
		CKEconomyState.month_echo_note("contest", Locale.t("terr_echo_contest_win",
			[str(site(id).name), ys, int(st.garrison)]))
	elif how == "reclaim":
		var ys2 := int(site(id).yield_silver)
		CKEconomyState.month_echo_note("reclaim", Locale.t("terr_echo_reclaim",
			[str(site(id).name), ys2, int(st.garrison)]))
	elif how == "assault":
		var ys3 := int(site(id).yield_silver)
		CKEconomyState.month_echo_note("assault", Locale.t("terr_echo_assault",
			[str(site(id).name), ys3, int(st.unrest)]))
	elif how == "chain":
		var ys4 := int(site(id).yield_silver)
		CKEconomyState.month_echo_note("chain", Locale.t("terr_echo_chain",
			[str(site(id).name), ys4, int(st.garrison)]))
	GameState.mark_dirty()
	World.world_changed.emit()
	return {"ok": true, "msg": Locale.t("terr_10") % site(id).name}

static func lose(id: String, to: String) -> Dictionary:
	if is_home(id) or site(id).is_empty():
		return {"ok": false, "msg": Locale.t("terr_11")}
	var st := state(id)
	var gar := int(st.garrison)
	var hold_pct := int(round(hold_chance(id) * 100.0))
	var ys := int(site(id).yield_silver)
	var who := Locale.t("terr_12") if to == NEUTRAL else _rival_name(to.trim_prefix("rival:"))
	st.owner = to
	st.garrison = 0
	st.contract = false
	st.unrest = 0
	st.threat = {}
	st.contest = {}
	_put(id, st)
	_log(Locale.t("terr_13") % [site(id).name, who])
	# Improve-plan #1: contest report card + auto「反夺」commission on the anchor board.
	var report := Locale.t("terr_47") % [gar, hold_pct, who, ys]
	_push_news(id, who, {"garrison": gar, "hold_pct": hold_pct, "yield_silver": ys, "report": report})
	_post_reclaim(id, who)
	GameState.mark_dirty()
	World.world_changed.emit()
	return {"ok": true}

## WS-C #45: losses wait here until the atlas shows them as a modal (survives save/load).
## Improve-plan #1: optional report fields ride along for the loss card.
static func _push_news(id: String, who: String, extra: Dictionary = {}) -> void:
	var st := _st()
	if not st.has("news") or typeof(st.news) != TYPE_ARRAY:
		st.news = []
	var row := {"id": id, "who": who, "date": World.date_label()}
	for k in extra.keys():
		row[k] = extra[k]
	st.news.append(row)
	if st.news.size() > 6:
		st.news = st.news.slice(st.news.size() - 6)


static func take_news() -> Array:
	var st := _st()
	var out: Array = st.get("news", []) if typeof(st.get("news", [])) == TYPE_ARRAY else []
	st.news = []
	return out


## Peaceful route: two ordinary commissions on the anchor's board (gather, then hunt).
static func post_chain(id: String) -> Dictionary:
	var why := capture_block(id)
	if why != "":
		return {"ok": false, "msg": why}
	for q in World.active:
		if str(q.get("territory", "")) == id:
			return {"ok": false, "msg": Locale.t("terr_14")}
	var q := _chain_step(id, 0)
	if q.is_empty():
		return {"ok": false, "msg": Locale.t("terr_15")}
	World._post_chain_offer(q)
	World.world_changed.emit()
	return {"ok": true, "quest": q, "msg": Locale.t("terr_16") % [World.node(str(site(id).anchor)).get("name", ""), q.title]}

static func _chain_step(id: String, step: int) -> Dictionary:
	var s := site(id)
	var anchor := str(s.anchor)
	var n := World.node(anchor)
	var q := {"id": "terr_%s_%d" % [id, step], "issuer": anchor, "tier": 1, "state": "offer", "sig": false,
		"reward_rep": 4, "req_rep": 0, "chain": true, "territory": id, "territory_step": step}
	if step == 0:
		var dem: Array = n.get("demand", [])
		var g := str(dem[0]) if not dem.is_empty() else "grain"
		q.merge({"kind": "gather", "target": anchor, "good": g, "qty": 10 if g == "grain" else 4,
			"title": Locale.t("terr_17") % s.name, "battle": false, "danger": 1, "days_budget": 40, "route_days": 0,
			"reward_silver": 20,
			"desc": Locale.t("terr_18") % [s.name, World.good_name(g), 10 if g == "grain" else 4, n.get("name", "")]})
	else:
		var target := World._near(anchor, 1, 1, rng)
		if target == "":
			target = anchor
		var rt := World.route(anchor, target)
		q.merge({"kind": "hunt", "target": target, "title": Locale.t("terr_19") % World.node(target).get("name", ""),
			"battle": true, "danger": int(s.danger), "route_days": int(rt.get("days", 1)), "foe_name": Locale.t("terr_20"),
			"days_budget": int(rt.get("days", 1)) * 2 + 10, "reward_silver": 30,
			"desc": Locale.t("terr_21") % [World.node(target).get("name", ""), s.name, n.get("name", "")]})
	return q

## Called by World.turn_in for quests that carry a territory field.
static func on_quest_done(q: Dictionary) -> String:
	var id := str(q.get("territory", ""))
	if id == "" or site(id).is_empty():
		return ""
	if bool(q.get("territory_reclaim", false)):
		return _finish_reclaim(id)
	if int(q.get("territory_step", 0)) == 0:
		var nq := _chain_step(id, 1)
		World._post_chain_offer(nq)
		return Locale.t("terr_22") % [World.node(str(nq.issuer)).get("name", ""), nq.title]
	if capture_block(id, false) != "" and not owned(id):
		return Locale.t("terr_23") % [site(id).name, capture_block(id, false)]
	capture(id, "chain")
	World.add_city_rep(str(site(id).anchor), 4)
	return Locale.t("terr_24") % site(id).name

static func _finish_reclaim(id: String) -> String:
	if owned(id):
		return Locale.t("terr_49") % site(id).name
	var block := capture_block(id, false)
	if block != "":
		return Locale.t("terr_23") % [site(id).name, block]
	capture(id, "reclaim")
	World.add_city_rep(str(site(id).anchor), 4)
	return Locale.t("terr_50") % site(id).name

## Improve-plan #1: after a loss, post a one-shot「反夺」hunt on the anchor board.
static func _post_reclaim(id: String, who: String) -> void:
	if site(id).is_empty():
		return
	if _has_reclaim(id):
		return
	var q := _reclaim_quest(id, who)
	if q.is_empty():
		return
	World._post_chain_offer(q)
	_log(Locale.t("terr_48") % [World.node(str(q.issuer)).get("name", ""), q.title])

static func _has_reclaim(id: String) -> bool:
	for q in World.active:
		if str(q.get("territory", "")) == id and bool(q.get("territory_reclaim", false)):
			return true
	var anchor := str(site(id).anchor)
	for q in World.board(anchor):
		if str(q.get("territory", "")) == id and bool(q.get("territory_reclaim", false)):
			return true
	return false

static func _reclaim_quest(id: String, who: String) -> Dictionary:
	var s := site(id)
	var anchor := str(s.anchor)
	var n := World.node(anchor)
	if n.is_empty():
		return {}
	var target := World._near(anchor, 1, 1, rng)
	if target == "":
		target = anchor
	var rt := World.route(anchor, target)
	var days := int(rt.get("days", 1))
	return {
		"id": "terr_reclaim_%s_%d" % [id, World.days_total],
		"issuer": anchor, "tier": 2, "state": "offer", "sig": false,
		"kind": "hunt", "target": target, "battle": true,
		"danger": clampi(int(s.danger) + 1, 1, 4),
		"route_days": days, "days_budget": days * 2 + 14,
		"reward_silver": 40, "reward_rep": 6, "req_rep": 0,
		"foe_name": who, "chain": false,
		"territory": id, "territory_reclaim": true,
		"title": Locale.t("terr_51") % s.name,
		"desc": Locale.t("terr_52") % [who, s.name, World.node(target).get("name", ""), n.get("name", "")],
	}

# ── garrison ──────────────────────────────────────────
static func garrison_cost(id: String) -> int:
	return int(rule("garrison_cost", 40)) * (int(state(id).garrison) + 1)

static func garrison_max(id: String) -> int:
	return int(rule("garrison_max", 3)) + (1 if bool(state(id).stockade) else 0)

static func stockade_cost() -> int:
	return 0 if int(_st().get("stockade_credit", 0)) > 0 else int(rule("stockade_cost", 120))

## Territory fat: cost / gate readout for reinforce (UI + E2E).
static func reinforce_preview(id: String) -> Dictionary:
	if not owned(id):
		return {"ok": false, "owned": false, "cost": 0, "short": false, "full": false, "garrison": 0, "max": 0, "reason": "owned"}
	var g := int(state(id).garrison)
	var mx := garrison_max(id)
	var cost := garrison_cost(id)
	var full := g >= mx
	var short := (not full) and GameState.silver < cost
	var reason := ""
	if full:
		reason = "full"
	elif short:
		reason = "short"
	return {
		"ok": true,
		"owned": true,
		"cost": cost,
		"short": short,
		"full": full,
		"garrison": g,
		"max": mx,
		"craftable": (not full) and (not short),
		"reason": reason,
	}

static func reinforce(id: String) -> Dictionary:
	var prev: Dictionary = reinforce_preview(id)
	if not bool(prev.get("owned", false)):
		return {"ok": false, "msg": Locale.t("terr_25"), "preview": prev}
	if bool(prev.get("full", false)):
		return {"ok": false, "msg": Locale.t("terr_26"), "preview": prev}
	var cost := int(prev.get("cost", 0))
	if bool(prev.get("short", false)):
		return {"ok": false, "msg": Locale.t("terr_27") % cost, "preview": prev}
	var st := state(id)
	GameState.silver -= cost
	st.garrison = int(st.garrison) + 1
	_put(id, st)
	var nm := str(site(id).name)
	CKEconomyState.month_echo_note("garrison", Locale.t("terr_echo_garrison", [nm, int(st.garrison), cost]))
	GameState.mark_dirty()
	World.world_changed.emit()
	return {"ok": true, "msg": Locale.t("terr_28") % [nm, int(st.garrison), cost], "preview": prev}

## Territory fat: cost / gate readout for stockade (UI + E2E).
static func stockade_preview(id: String) -> Dictionary:
	if not owned(id):
		return {"ok": false, "owned": false, "cost": 0, "short": false, "have": false, "credit": false, "reason": "owned"}
	var have := bool(state(id).stockade)
	var cost := stockade_cost()
	var credit := cost == 0
	var short := (not have) and (not credit) and GameState.silver < cost
	var reason := ""
	if have:
		reason = "have"
	elif short:
		reason = "short"
	return {
		"ok": true,
		"owned": true,
		"cost": cost,
		"short": short,
		"have": have,
		"credit": credit,
		"craftable": (not have) and (not short),
		"reason": reason,
	}

## Stockade (屯营): the second seat's value as a site upgrade. +12 silver, +6 food, garrison cap +1.
static func build_stockade(id: String) -> Dictionary:
	var prev: Dictionary = stockade_preview(id)
	if not bool(prev.get("owned", false)):
		return {"ok": false, "msg": Locale.t("terr_st_owned"), "preview": prev}
	if bool(prev.get("have", false)):
		return {"ok": false, "msg": Locale.t("terr_st_have"), "preview": prev}
	var cost := int(prev.get("cost", 0))
	if bool(prev.get("short", false)):
		return {"ok": false, "msg": Locale.t("terr_27") % cost, "preview": prev}
	var st := state(id)
	GameState.silver -= cost
	if cost == 0:
		_st().stockade_credit = int(_st().stockade_credit) - 1
	st.stockade = true
	_put(id, st)
	var nm := str(site(id).name)
	_log(Locale.t("terr_st_done") % [nm, cost])
	CKEconomyState.month_echo_note("stockade", Locale.t("terr_echo_stockade", [nm, cost]))
	GameState.mark_dirty()
	World.world_changed.emit()
	return {"ok": true, "msg": Locale.t("terr_st_done") % [nm, cost], "preview": prev}

## A finished scripted nation chain used to offer a second seat. Now it pays for one stockade.
static func grant_stockade_credit(chain_id: String) -> void:
	if chain_id == "":
		return
	_st().stockade_credit = int(_st().get("stockade_credit", 0)) + 1
	_log(Locale.t("terr_st_credit"))

## Save migration: holdings.second_seat -> owned site next to the same settlement,
## with a stockade, the seat's garrison, and a contract floor so its value never drops.
static func migrate_second_seat(host) -> String:
	var row = host.holdings.get("second_seat", null)
	if row == null:
		return ""
	host.holdings.erase("second_seat")
	if typeof(row) != TYPE_DICTIONARY or not bool(row.get("owned", false)):
		return ""
	var city := str(row.get("city", ""))
	var id := _seat_site(city)
	if id == "":
		return ""
	var st := state(id)
	st.owner = OWN
	st.threat = {}
	st.unrest = 0
	st.stockade = true
	st.contract = true
	st.garrison = clampi(int(row.get("garrison_away", 2)), 1, int(rule("garrison_max", 3)) + 1)
	_put(id, st)
	_log(Locale.t("terr_seat_moved") % site(id).name)
	return id

static func _seat_site(city: String) -> String:
	var best := ""
	var best_d := 1 << 30
	var nat := World.nation_of(city) if World.nodes.has(city) else ""
	for id in site_ids():
		if owned(id):
			continue
		var s := site(id)
		var d := 0
		if str(s.anchor) != city:
			var rt: Dictionary = World.route(city, str(s.anchor)) if World.nodes.has(city) else {}
			d = 10 + int(rt.get("days", 999))
			if str(s.nation) != nat:
				d += 1000
		if d < best_d:
			best_d = d
			best = id
	return best

static func upkeep(id: String) -> int:
	return int(site(id).get("upkeep", 0)) + int(state(id).garrison) * int(rule("garrison_upkeep", 4))

# ── month ─────────────────────────────────────────────
static func contest_chance(id: String) -> float:
	var s := site(id)
	var st := state(id)
	var p := rule("contest_base", 0.05) + rule("contest_per_danger", 0.02) * int(s.danger)
	p -= rule("contest_per_garrison", 0.02) * int(st.garrison)
	for other in sites_in(str(s.nation)):
		if other != id and owned(other) and str(site(other).kind) == "watchtower":
			p -= rule("contest_watchtower", 0.03)
			break
	if not _rival_in(str(s.nation)).is_empty():
		p += rule("contest_rival_near", 0.04)
	return clampf(p, 0.0, rule("contest_cap", 0.2))

static func hold_chance(id: String) -> float:
	return clampf(rule("hold_base", 0.1) + rule("hold_per_garrison", 0.25) * int(state(id).garrison), 0.0, 0.95)

static func _rival_in(nation: String) -> Dictionary:
	if not World.rivals_enabled:
		return {}
	for rv in World.rivals:
		if World.nation_of(str(rv.get("pos", ""))) == nation:
			return rv
	return {}

static func _rival_name(rid: String) -> String:
	for rv in World.rivals:
		if str(rv.get("id", "")) == rid:
			return str(rv.get("name", rid))
	return rid

## Food stored at an owned stockade (屯营粮仓).
static func cache_food(id: String) -> int:
	return maxi(0, int(state(id).get("cache_food", 0)))


## Nearest owned stockade with cache>0 (or any stockade). Empty if none.
static func nearest_stockade(from_pos: String = "") -> Dictionary:
	var here := from_pos if from_pos != "" else str(World.pos)
	var best: Dictionary = {}
	var best_score := 999999
	for id in owned_ids():
		var st := state(id)
		if not bool(st.stockade):
			continue
		var s := site(id)
		var anch := str(s.get("anchor", ""))
		if anch == "" or not World.nodes.has(anch):
			continue
		var dist := 0
		if here != anch:
			# Prefer travel_preview when from current World.pos; else treat as far.
			if here == str(World.pos):
				var pv: Dictionary = World.travel_preview(anch)
				if not bool(pv.get("ok", false)):
					continue
				dist = int(pv.get("days", 99))
			else:
				dist = 50
		var cache := int(st.get("cache_food", 0))
		var row := {
			"id": id,
			"name": str(s.get("name", id)),
			"anchor": anch,
			"anchor_name": str(World.node(anch).get("name", anch)),
			"cache": cache,
			"days": dist,
		}
		# Prefer stockades that hold food; among those, nearer.
		var score := dist - (1000 if cache > 0 else 0)
		if best.is_empty() or score < best_score:
			best = row
			best_score = score
	return best


static func open_cache(id: String) -> Dictionary:
	if not owned(id):
		return {"ok": false, "msg": Locale.t("atlas_cache_not_ours")}
	var st := state(id)
	if not bool(st.stockade):
		return {"ok": false, "msg": Locale.t("atlas_cache_no_stockade")}
	var anchor := str(site(id).get("anchor", ""))
	if World.pos != anchor:
		return {"ok": false, "need_travel": true, "anchor": anchor,
			"msg": Locale.t("atlas_cache_need_travel") % World.node(anchor).get("name", "")}
	var qty := maxi(0, int(st.get("cache_food", 0)))
	if qty <= 0:
		return {"ok": false, "msg": Locale.t("atlas_cache_empty") % str(site(id).get("name", id))}
	st.cache_food = 0
	_put(id, st)
	GameState.food += qty
	_log(Locale.t("atlas_cache_open_log") % [str(site(id).get("name", id)), qty])
	World.world_changed.emit()
	return {"ok": true, "qty": qty, "food": GameState.food,
		"msg": Locale.t("atlas_cache_open_ok") % [str(site(id).get("name", id)), qty]}


## Under siege: haul the granary out before the raid. Prefer another owned stockade; else company food.
## Road spoilage: lose ~1 food per 2 travel-days (min 0). Clears cache on the threatened site.
## Territory fat: gate readout for siege convoy evacuate (UI + E2E).
static func evacuate_preview(id: String) -> Dictionary:
	if not owned(id):
		return {"ok": false, "msg": Locale.t("atlas_cache_not_ours"), "reason": "owned"}
	var st := state(id)
	if not bool(st.stockade):
		return {"ok": false, "msg": Locale.t("atlas_cache_no_stockade"), "reason": "stockade"}
	if (st.threat as Dictionary).is_empty():
		return {"ok": false, "msg": Locale.t("atlas_convoy_need_threat"), "reason": "threat"}
	var qty := maxi(0, int(st.get("cache_food", 0)))
	if qty <= 0:
		return {"ok": false, "msg": Locale.t("atlas_cache_empty") % str(site(id).get("name", id)),
			"reason": "empty"}
	var from_name := str(site(id).get("name", id))
	var from_anchor := str(site(id).get("anchor", ""))
	var dest_id := ""
	var dest_anchor := ""
	var dest_name := ""
	var days := 0
	var best := 999999
	for oid in owned_ids():
		if oid == id:
			continue
		var ost := state(oid)
		if not bool(ost.stockade):
			continue
		var oanch := str(site(oid).get("anchor", ""))
		if oanch == "" or not World.nodes.has(oanch):
			continue
		var dist := 3
		if from_anchor != "" and from_anchor == str(World.pos):
			var pv: Dictionary = World.travel_preview(oanch)
			if bool(pv.get("ok", false)):
				dist = int(pv.get("days", 3))
		elif from_anchor != "" and oanch != from_anchor:
			dist = 4
		else:
			dist = 1
		if dist < best:
			best = dist
			dest_id = oid
			dest_anchor = oanch
			dest_name = str(site(oid).get("name", oid))
			days = dist
	var spoilage := mini(qty - 1, int(days / 2)) if qty > 1 else 0
	var delivered := qty - spoilage
	var via := "stockade" if dest_id != "" else "company"
	if via == "company":
		dest_name = Locale.t("atlas_convoy_via_company")
	return {
		"ok": true, "qty": qty, "delivered": delivered, "spoilage": spoilage,
		"from_name": from_name, "dest_id": dest_id, "dest_name": dest_name,
		"dest_anchor": dest_anchor, "via": via, "days": days,
	}


static func evacuate_cache(id: String) -> Dictionary:
	var prev: Dictionary = evacuate_preview(id)
	if not bool(prev.get("ok", false)):
		return prev
	var qty := int(prev.get("qty", 0))
	var delivered := int(prev.get("delivered", 0))
	var spoilage := int(prev.get("spoilage", 0))
	var dest_id := str(prev.get("dest_id", ""))
	var dest_name := str(prev.get("dest_name", ""))
	var dest_anchor := str(prev.get("dest_anchor", ""))
	var via := str(prev.get("via", "company"))
	var days := int(prev.get("days", 0))
	var from_name := str(prev.get("from_name", site(id).get("name", id)))
	var st := state(id)
	st.cache_food = 0
	_put(id, st)
	if via == "stockade" and dest_id != "":
		var dst := state(dest_id)
		dst.cache_food = int(dst.get("cache_food", 0)) + delivered
		_put(dest_id, dst)
	else:
		GameState.food += delivered
		via = "company"
	var msg := ""
	if via == "stockade":
		msg = Locale.t("atlas_convoy_ok_stockade") % [from_name, delivered, dest_name, spoilage]
	else:
		msg = Locale.t("atlas_convoy_ok_company") % [from_name, delivered, spoilage]
	_log(msg)
	World.mark_siege_convoy({
		"from_id": id,
		"from_name": from_name,
		"qty": qty,
		"delivered": delivered,
		"spoilage": spoilage,
		"dest_id": dest_id,
		"dest_name": dest_name,
		"dest_anchor": dest_anchor,
		"via": via,
		"days": days,
	})
	CKEconomyState.month_echo_note("convoy", Locale.t("terr_echo_convoy",
		[from_name, dest_name, delivered, spoilage]))
	GameState.mark_dirty()
	World.world_changed.emit()
	return {"ok": true, "qty": qty, "delivered": delivered, "spoilage": spoilage,
		"dest_id": dest_id, "via": via, "msg": msg, "preview": prev}


## Under siege: spend stockade cache food to raise +1 garrison (no silver).
## Cost = rule("muster_cache_cost", 4). Needs hanging threat, stockade, room under garrison_max.
static func muster_cache_cost(_id: String = "") -> int:
	return maxi(1, int(rule("muster_cache_cost", 4)))


## Territory fat: gate readout for siege muster (UI + E2E).
static func muster_preview(id: String) -> Dictionary:
	if not owned(id):
		return {"ok": false, "msg": Locale.t("atlas_cache_not_ours"), "reason": "owned"}
	var st := state(id)
	if not bool(st.stockade):
		return {"ok": false, "msg": Locale.t("atlas_cache_no_stockade"), "reason": "stockade"}
	if (st.threat as Dictionary).is_empty():
		return {"ok": false, "msg": Locale.t("atlas_muster_need_threat"), "reason": "threat"}
	var cost := muster_cache_cost(id)
	var cache := maxi(0, int(st.get("cache_food", 0)))
	if cache < cost:
		return {"ok": false, "msg": Locale.t("atlas_muster_need_food") % [cost, cache],
			"reason": "food", "cost": cost, "cache": cache}
	var gmax := garrison_max(id)
	var gar := int(st.garrison)
	if gar >= gmax:
		return {"ok": false, "msg": Locale.t("atlas_muster_full") % gmax,
			"reason": "full", "cost": cost, "cache": cache, "garrison": gar, "gmax": gmax}
	return {"ok": true, "cost": cost, "cache": cache, "garrison": gar, "gmax": gmax}


static func muster_from_cache(id: String) -> Dictionary:
	var prev: Dictionary = muster_preview(id)
	if not bool(prev.get("ok", false)):
		return prev
	var cost := int(prev.get("cost", muster_cache_cost(id)))
	var st := state(id)
	var cache := maxi(0, int(st.get("cache_food", 0)))
	var gar := int(st.garrison)
	st.cache_food = cache - cost
	st.garrison = gar + 1
	_put(id, st)
	var site_name := str(site(id).get("name", id))
	var msg := Locale.t("atlas_muster_ok") % [site_name, cost, int(st.garrison)]
	_log(msg)
	World.mark_siege_muster({
		"id": id,
		"name": site_name,
		"spent": cost,
		"garrison": int(st.garrison),
		"cache_left": int(st.cache_food),
		"hold_pct": int(round(hold_chance(id) * 100.0)),
	})
	CKEconomyState.month_echo_note("muster", Locale.t("terr_echo_muster", [site_name, cost, int(st.garrison)]))
	GameState.mark_dirty()
	World.world_changed.emit()
	return {"ok": true, "spent": cost, "garrison": int(st.garrison),
		"cache_left": int(st.cache_food), "msg": msg, "preview": prev}


## Month phase "world". Returns a summary line (empty when the company holds nothing).
## Under siege: pull +1 garrison from the nearest sister stockade that can spare one (leave ≥1).
static func sister_relief_preview(id: String) -> Dictionary:
	if not owned(id):
		return {"ok": false, "msg": Locale.t("atlas_cache_not_ours")}
	var st := state(id)
	if (st.threat as Dictionary).is_empty():
		return {"ok": false, "msg": Locale.t("atlas_sister_need_threat")}
	if int(st.garrison) >= garrison_max(id):
		return {"ok": false, "msg": Locale.t("atlas_sister_full") % garrison_max(id)}
	var from_anchor := str(site(id).get("anchor", ""))
	var best_id := ""
	var best_name := ""
	var best_days := 999999
	var best_gar := 0
	for oid in owned_ids():
		if oid == id:
			continue
		var ost := state(oid)
		if not bool(ost.stockade):
			continue
		var og := int(ost.garrison)
		if og < 2:
			continue
		var oanch := str(site(oid).get("anchor", ""))
		var dist := 3
		if from_anchor != "" and from_anchor == str(World.pos):
			var pv: Dictionary = World.travel_preview(oanch)
			if bool(pv.get("ok", false)):
				dist = int(pv.get("days", 3))
		elif from_anchor != "" and oanch != from_anchor:
			dist = 4
		else:
			dist = 1
		if dist < best_days:
			best_days = dist
			best_id = oid
			best_name = str(site(oid).get("name", oid))
			best_gar = og
	if best_id == "":
		return {"ok": false, "msg": Locale.t("atlas_sister_none")}
	return {"ok": true, "from_id": best_id, "from_name": best_name,
		"from_garrison": best_gar, "days": best_days}


static func call_sister_garrison(id: String) -> Dictionary:
	var prev: Dictionary = sister_relief_preview(id)
	if not bool(prev.get("ok", false)):
		return prev
	var from_id := str(prev.get("from_id", ""))
	var st := state(id)
	var src := state(from_id)
	src.garrison = int(src.garrison) - 1
	st.garrison = int(st.garrison) + 1
	_put(from_id, src)
	_put(id, st)
	var to_name := str(site(id).get("name", id))
	var from_name := str(prev.get("from_name", from_id))
	var msg := Locale.t("atlas_sister_ok") % [from_name, to_name, int(st.garrison), int(src.garrison)]
	_log(msg)
	World.mark_siege_sister({
		"to_id": id,
		"to_name": to_name,
		"from_id": from_id,
		"from_name": from_name,
		"garrison": int(st.garrison),
		"from_garrison": int(src.garrison),
		"days": int(prev.get("days", 0)),
		"hold_pct": int(round(hold_chance(id) * 100.0)),
	})
	CKEconomyState.month_echo_note("sister", Locale.t("terr_echo_sister", [from_name, to_name, int(st.garrison), int(src.garrison)]))
	GameState.mark_dirty()
	World.world_changed.emit()
	return {"ok": true, "from_id": from_id, "garrison": int(st.garrison),
		"from_garrison": int(src.garrison), "msg": msg, "preview": prev}


## Chance a neutral site draws multi-faction tug-of-war this month.
static func neutral_contest_chance(id: String) -> float:
	var s := site(id)
	if s.is_empty() or owned(id) or owner(id) != NEUTRAL:
		return 0.0
	var st := state(id)
	if not (st.contest as Dictionary).is_empty() or not (st.threat as Dictionary).is_empty():
		return 0.0
	var p := rule("neutral_contest_base", 0.04) + rule("contest_per_danger", 0.02) * int(s.danger)
	if not _rival_in(str(s.nation)).is_empty():
		p += rule("contest_rival_near", 0.04)
	return clampf(p, 0.0, rule("neutral_contest_cap", 0.18))


## Start a multi-faction race on a still-neutral site (rivals ± bandits).
static func start_neutral_contest(id: String, force_factions: Array = []) -> Dictionary:
	var s := site(id)
	if s.is_empty() or is_home(id):
		return {}
	if owner(id) != NEUTRAL:
		return {}
	var st := state(id)
	if not (st.contest as Dictionary).is_empty():
		return st.contest
	var factions: Array = []
	if not force_factions.is_empty():
		for f in force_factions:
			if typeof(f) == TYPE_DICTIONARY:
				factions.append(f.duplicate(true))
	else:
		var rv := _rival_in(str(s.nation))
		if not rv.is_empty():
			factions.append({
				"id": "rival:%s" % str(rv.id),
				"name": str(rv.name),
				"pressure": 2 + int(s.danger),
			})
		# Second pressure: another rival company if any, else local bandits.
		var other: Dictionary = {}
		for r2 in World.rivals:
			if str(r2.get("id", "")) == str(rv.get("id", "")):
				continue
			other = r2
			break
		if not other.is_empty():
			factions.append({
				"id": "rival:%s" % str(other.id),
				"name": str(other.name),
				"pressure": 1 + int(s.danger),
			})
		else:
			factions.append({
				"id": "bandit",
				"name": Locale.t("atlas_contest_bandit") % World.nations.get(str(s.nation), {}).get("name", ""),
				"pressure": 1 + int(s.danger),
			})
	if factions.is_empty():
		factions.append({
			"id": "bandit",
			"name": Locale.t("atlas_contest_bandit") % World.nations.get(str(s.nation), {}).get("name", ""),
			"pressure": 1,
		})
	st.contest = {
		"factions": factions,
		"months": 0,
		"day": World.days_total,
		"id": id,
		"name": str(s.name),
		"anchor": str(s.anchor),
		"anchor_name": str(World.node(str(s.anchor)).get("name", s.anchor)),
		"nation": str(s.nation),
	}
	_put(id, st)
	_log(Locale.t("atlas_contest_log") % [str(s.name), _faction_names(factions)])
	World.world_changed.emit()
	_emit_neutral_contest(id)
	return st.contest


static func _faction_names(factions: Array) -> String:
	var bits: Array = []
	for f in factions:
		bits.append(str(f.get("name", "")))
	return " / ".join(bits)


static func _emit_neutral_contest(id: String) -> void:
	var st := state(id)
	var c: Dictionary = st.contest
	if c.is_empty():
		return
	var payload := {
		"id": id,
		"name": str(c.get("name", site(id).get("name", id))),
		"anchor": str(c.get("anchor", site(id).get("anchor", ""))),
		"anchor_name": str(c.get("anchor_name", "")),
		"nation": str(c.get("nation", site(id).get("nation", ""))),
		"factions": (c.get("factions", []) as Array).duplicate(true),
		"months": int(c.get("months", 0)),
		"phase": "imminent" if int(c.get("months", 0)) >= 1 else "declared",
	}
	# New tug supersedes a stale settle modal for this site.
	if str(World.last_contest_resolve.get("id", "")) == id:
		World.last_contest_resolve = {}
	World.mark_neutral_contest(payload)


## Advance / resolve open neutral contests. Returns list of resolved rows.
static func tick_neutral_contests(force_resolve: bool = false) -> Array:
	var resolved: Array = []
	for id in site_ids():
		if owner(id) != NEUTRAL:
			continue
		var st := state(id)
		var c: Dictionary = st.contest
		if c.is_empty():
			continue
		if force_resolve or int(c.get("months", 0)) >= 1:
			var winner: Dictionary = _contest_winner(c.get("factions", []))
			var wid := str(winner.get("id", "bandit"))
			var wname := str(winner.get("name", ""))
			var ys := int(site(id).yield_silver)
			st.contest = {}
			_put(id, st)
			if wid == "company":
				# Company stake won the race — claim with short unrest (产出半额至民心附).
				var cap: Dictionary = capture(id, "contest")
				if not bool(cap.get("ok", false)):
					# Fallback if capture blocked (rep/cap): leave neutral + unrest.
					st = state(id)
					st.owner = NEUTRAL
					st.garrison = 0
					st.unrest = maxi(int(st.unrest), 1)
					_put(id, st)
					CKEconomyState.month_echo_note("contest", Locale.t("terr_echo_contest_miss",
						[str(site(id).name), wname, ys]))
			elif wid.begins_with("rival:"):
				st = state(id)
				st.owner = wid
				st.garrison = 1
				_put(id, st)
				CKEconomyState.month_echo_note("contest", Locale.t("terr_echo_contest_loss",
					[str(site(id).name), wname, ys]))
			else:
				# Bandits scatter the hold — site stays free but unrest spikes.
				st = state(id)
				st.owner = NEUTRAL
				st.garrison = 0
				st.unrest = maxi(int(st.unrest), 1)
				_put(id, st)
				CKEconomyState.month_echo_note("contest", Locale.t("terr_echo_contest_miss",
					[str(site(id).name), wname, ys]))
			_log(Locale.t("atlas_contest_resolved") % [site(id).name, wname])
			var company_won := wid == "company" and owned(id)
			var outcome := "won" if company_won else ("lost" if wid.begins_with("rival:") else "miss")
			if wid == "company" and not company_won:
				outcome = "miss"
			var srow := site(id)
			var anchor := str(srow.get("anchor", ""))
			resolved.append({
				"id": id,
				"name": str(srow.name),
				"winner": wid,
				"winner_name": wname,
				"yield_silver": ys,
				"company_won": company_won,
				"outcome": outcome,
			})
			# Stale tug payload for this site is no longer actionable.
			if str(World.last_neutral_contest.get("id", "")) == id:
				World.last_neutral_contest = {}
			World.mark_contest_resolve({
				"id": id,
				"name": str(srow.name),
				"anchor": anchor,
				"anchor_name": str(World.node(anchor).get("name", anchor)) if anchor != "" else "",
				"winner": wid,
				"winner_name": wname,
				"yield_silver": ys,
				"company_won": company_won,
				"outcome": outcome,
				"garrison": int(state(id).garrison) if company_won else 0,
			})
			World.world_changed.emit()
		else:
			c["months"] = 1
			st.contest = c
			_put(id, st)
			_emit_neutral_contest(id)
	return resolved


static func _contest_winner(factions) -> Dictionary:
	var best: Dictionary = {}
	var best_p := -1
	if typeof(factions) != TYPE_ARRAY:
		return {"id": "bandit", "name": "?", "pressure": 0}
	for f in factions:
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var pr := int(f.get("pressure", 0))
		if pr > best_p:
			best_p = pr
			best = f
	if best.is_empty():
		return {"id": "bandit", "name": "?", "pressure": 0}
	return best



static func clear_contest(id: String) -> void:
	var st := state(id)
	st.contest = {}
	_put(id, st)


static func contested_ids() -> Array:
	var out: Array = []
	for id in site_ids():
		if owner(id) == NEUTRAL and not (state(id).contest as Dictionary).is_empty():
			out.append(id)
	return out


## Territory fat: gate readout for neutral contest stake / seize (UI + E2E).
static func contest_stake_cost(id: String) -> int:
	return int(rule("contest_stake_cost", 40)) + int(site(id).get("danger", 1)) * 12


static func contest_preview(id: String) -> Dictionary:
	var s := site(id)
	if s.is_empty() or is_home(id):
		return {"ok": false, "msg": Locale.t("terr_01"), "reason": "site"}
	var st := state(id)
	var c: Dictionary = st.contest if typeof(st.contest) == TYPE_DICTIONARY else {}
	if c.is_empty():
		return {"ok": false, "msg": Locale.t("atlas_contest_gone"), "reason": "gone"}
	if owner(id) != NEUTRAL:
		return {"ok": false, "msg": Locale.t("atlas_contest_gone"), "reason": "owned"}
	var anchor := str(s.anchor)
	var factions: Array = c.get("factions", []) if typeof(c.get("factions", [])) == TYPE_ARRAY else []
	var staked := false
	var top_p := 0
	for f in factions:
		if typeof(f) != TYPE_DICTIONARY:
			continue
		top_p = maxi(top_p, int(f.get("pressure", 0)))
		if str(f.get("id", "")) == "company":
			staked = true
	var cost := contest_stake_cost(id)
	var can_stake := not staked and GameState.silver >= cost
	var stake_reason := ""
	if staked:
		stake_reason = "staked"
	elif GameState.silver < cost:
		stake_reason = "silver"
	return {
		"ok": true,
		"id": id,
		"name": str(s.name),
		"anchor": anchor,
		"at_anchor": World.pos == anchor and anchor != "",
		"phase": "imminent" if int(c.get("months", 0)) >= 1 else "declared",
		"months": int(c.get("months", 0)),
		"factions": factions.duplicate(true),
		"yield_silver": int(s.yield_silver),
		"stake_cost": cost,
		"can_stake": can_stake,
		"staked": staked,
		"stake_reason": stake_reason,
		"top_pressure": top_p,
		"msg": Locale.t("atlas_contest_summary") % _faction_names(factions),
	}


## Spend silver to plant company pressure in the race (加码). Highest pressure claims on resolve.
static func contest_stake(id: String) -> Dictionary:
	var prev: Dictionary = contest_preview(id)
	if not bool(prev.get("ok", false)):
		return prev
	if bool(prev.get("staked", false)):
		return {"ok": false, "msg": Locale.t("atlas_contest_staked"), "reason": "staked", "preview": prev}
	var cost := int(prev.get("stake_cost", contest_stake_cost(id)))
	if GameState.silver < cost:
		return {"ok": false, "msg": Locale.t("terr_27") % cost, "reason": "silver", "preview": prev}
	var st := state(id)
	var c: Dictionary = st.contest
	var factions: Array = c.get("factions", []) if typeof(c.get("factions", [])) == TYPE_ARRAY else []
	var top_p := int(prev.get("top_pressure", 0))
	var company_p := top_p + 1
	var cname := Locale.t("atlas_contest_company") % str(GameState.surname)
	factions.append({"id": "company", "name": cname, "pressure": company_p})
	c["factions"] = factions
	c["staked"] = true
	st.contest = c
	_put(id, st)
	GameState.silver -= cost
	var msg := Locale.t("atlas_contest_stake_ok") % [str(site(id).name), cost, company_p]
	_log(msg)
	CKEconomyState.month_echo_note("contest", Locale.t("terr_echo_contest_stake",
		[str(site(id).name), cost, company_p]))
	_emit_neutral_contest(id)
	GameState.mark_dirty()
	World.world_changed.emit()
	return {
		"ok": true,
		"msg": msg,
		"cost": cost,
		"pressure": company_p,
		"factions": factions.duplicate(true),
		"preview": contest_preview(id),
	}


## Player cuts into a neutral race: assault if on the anchor, else signal travel.
static func intervene_contest(id: String) -> Dictionary:
	var s := site(id)
	if s.is_empty():
		return {"ok": false, "msg": Locale.t("terr_01")}
	var st := state(id)
	if (st.contest as Dictionary).is_empty() and owner(id) == NEUTRAL:
		# race already resolved / cleared — still allow assault if free
		pass
	elif (st.contest as Dictionary).is_empty():
		return {"ok": false, "msg": Locale.t("atlas_contest_gone")}
	var anchor := str(s.anchor)
	if World.pos != anchor:
		return {"ok": false, "need_travel": true, "anchor": anchor,
			"msg": Locale.t("terr_05") % World.node(anchor).get("name", "")}
	clear_contest(id)
	World.dismiss_neutral_contest()
	var r: Dictionary = assault(id)
	if bool(r.get("ok", false)):
		CKEconomyState.month_echo_note("contest", Locale.t("terr_echo_contest_seize",
			[str(s.name), int(s.yield_silver)]))
		r["echo"] = str(CKEconomyState.month_echo_snapshot().get("contest", ""))
	return r


## Stand aside; contest keeps ticking on next months.
static func watch_contest(id: String) -> Dictionary:
	var st := state(id)
	if (st.contest as Dictionary).is_empty():
		World.dismiss_neutral_contest()
		return {"ok": true, "msg": Locale.t("atlas_contest_gone")}
	World.dismiss_neutral_contest()
	return {"ok": true, "msg": Locale.t("atlas_contest_watch_ok") % str(site(id).name)}



static func apply_month(force_roll: float = -1.0) -> String:
	var resolved_contests: Array = tick_neutral_contests(false)
	var ids := owned_ids()
	if ids.is_empty():
		# Still tick/start neutral races even with zero holdings.
		_roll_neutral_contests(force_roll)
		# Territory fat: surface resolved / open contests even with no holdings
		# (company stake → claim can be the first capture of the month).
		last_month_report = {
			"silver": 0,
			"food": 0,
			"owned": owned_ids().size(),
			"owned_before": 0,
			"drains": [],
			"lost": [],
			"held": [],
			"threats": [],
			"contests": resolved_contests,
			"contest_open": contested_ids(),
			"line": "",
			"reclaims": [],
		}
		return ""
	var silver := 0
	var food_gain := 0
	var notes: Array = []
	var drains: Array = []
	var lost: Array = []
	var held: Array = []
	var threats: Array = []
	for id in ids:
		var s := site(id)
		var st := state(id)
		# threats posted last month resolve now if nobody came
		if not (st.threat as Dictionary).is_empty():
			if int(st.threat.get("months", 0)) >= 1:
				var g_before := int(st.garrison)
				_resolve_unanswered(id, force_roll)
				var loot_qty := 0
				if not World.last_siege_loot.is_empty() and str(World.last_siege_loot.get("id", "")) == id:
					loot_qty = int(World.last_siege_loot.get("looted", 0))
				if not owned(id):
					lost.append({"id": id, "name": str(s.name), "garrison_before": g_before, "cache_looted": loot_qty})
					continue
				st = state(id)
				var g_after := int(st.garrison)
				if g_after < g_before or loot_qty > 0:
					held.append({"id": id, "name": str(s.name), "garrison_before": g_before, "garrison": g_after, "cache_looted": loot_qty})
			else:
				st.threat["months"] = 1
				_put(id, st)
				_emit_siege_alert(id, "imminent")
		var half := int(st.unrest) > 0 or not (st.threat as Dictionary).is_empty()
		var ys := int(s.yield_silver)
		var yq := int(s.yield_qty)
		var yf := 0
		if bool(st.stockade):
			ys += int(rule("stockade_silver", 12))
			yf = int(rule("stockade_food", 6))
		if half:
			ys /= 2
			yq /= 2
			yf /= 2
		var net := ys - upkeep(id)
		if yq > 0 and str(s.good) != "":
			net += _deliver_good(str(s.good), yq)
		if bool(st.contract):
			# old second-seat contract: never worse than the seat's net +6 silver / +6 food
			net = maxi(net, int(rule("contract_silver", 6)))
			yf = maxi(yf, int(rule("contract_food", 6)))
		silver += net
		food_gain += yf
		if yf > 0:
			st.cache_food = int(st.get("cache_food", 0)) + yf
			# 屯营月粮入据点粮仓，行军断粮时再开仓 — 不再直灌 GameState.food
		if int(st.unrest) > 0:
			st.unrest = int(st.unrest) - 1
		_put(id, st)
	GameState.silver += silver
	if GameState.silver < 0:
		GameState.silver = 0
		for id in ids:
			var st2 := state(id)
			if owned(id) and int(st2.garrison) > 0:
				st2.garrison = int(st2.garrison) - 1
				_put(id, st2)
				var drain_line := Locale.t("terr_29") % [site(id).name, int(st2.garrison)]
				notes.append(drain_line)
				drains.append({"id": id, "name": str(site(id).name), "garrison": int(st2.garrison), "text": drain_line})
	for id in owned_ids():
		var st3 := state(id)
		if (st3.threat as Dictionary).is_empty():
			# Just held this month — do not re-threaten and wipe ThreatResolveModal.
			var just_held := false
			for h in held:
				if str(h.get("id", "")) == id:
					just_held = true
					break
			if just_held:
				continue
			var roll := rng.randf() if force_roll < 0.0 else force_roll
			if roll < contest_chance(id):
				var th := start_threat(id)
				if not th.is_empty():
					threats.append({"id": id, "name": str(site(id).name), "by": str(th.get("name", ""))})
	var line := Locale.t("terr_30") % [silver, owned_ids().size()]
	for n in notes:
		line += "；" + str(n)
	var reclaim_ids: Array = []
	for row in lost:
		var rid := str(row.get("id", ""))
		if rid != "" and _has_reclaim(rid):
			reclaim_ids.append(rid)
	_roll_neutral_contests(force_roll)
	last_month_report = {
		"silver": silver,
		"food": food_gain,
		"owned": owned_ids().size(),
		"owned_before": ids.size(),
		"drains": drains,
		"lost": lost,
		"held": held,
		"threats": threats,
		"contests": resolved_contests,
		"contest_open": contested_ids(),
		"line": line,
		"reclaims": reclaim_ids,
	}
	return line


static func _roll_neutral_contests(force_roll: float) -> void:
	## force_roll >= 0 is used by tests for owned-site contests; skip random neutral races then.
	if force_roll >= 0.0:
		return
	for id in site_ids():
		if owner(id) != NEUTRAL:
			continue
		var roll := rng.randf()
		if roll < neutral_contest_chance(id):
			start_neutral_contest(id)

static func _deliver_good(g: String, q: int) -> int:
	var gd: Dictionary = World.goods.get(g, {})
	if str(gd.get("store", "")) != "" or World.cargo_used() + q <= World.cargo_cap():
		World._add_good(g, q)
		return 0
	return int(round(float(gd.get("base", 4)) * q * rule("sell_rate", 0.7)))

static func start_threat(id: String) -> Dictionary:
	if not owned(id) or is_home(id):
		return {}
	var s := site(id)
	var rv := _rival_in(str(s.nation))
	var by := NEUTRAL if rv.is_empty() else "rival:%s" % rv.id
	var by_name := Locale.t("terr_31") % World.nations.get(str(s.nation), {}).get("name", "") if rv.is_empty() else str(rv.name)
	var st := state(id)
	st.threat = {"by": by, "name": by_name, "day": World.days_total, "months": 0}
	_put(id, st)
	# Fresh siege — drop stale aftermath so ThreatResolveModal does not replay.
	if str(World.last_threat_resolve.get("id", "")) == id:
		World.dismiss_threat_resolve()
	_log(Locale.t("terr_32") % [by_name, s.name, World.node(str(s.anchor)).get("name", "")])
	World.world_changed.emit()
	_emit_siege_alert(id, "declared")
	return st.threat


## Raid the stockade granary. Returns food taken (0 if none). fraction 1.0 = empty the cache.
static func loot_cache(id: String, fraction: float = 1.0) -> int:
	var st := state(id)
	if not bool(st.stockade):
		return 0
	var cache := maxi(0, int(st.get("cache_food", 0)))
	if cache <= 0:
		return 0
	var taken := cache if fraction >= 1.0 else maxi(1, int(ceili(float(cache) * fraction)))
	taken = mini(taken, cache)
	st.cache_food = cache - taken
	_put(id, st)
	return taken


static func _resolve_unanswered(id: String, force_roll: float) -> void:
	var st := state(id)
	var by := str(st.threat.get("by", NEUTRAL))
	var by_name := str(st.threat.get("name", ""))
	var roll := rng.randf() if force_roll < 0.0 else force_roll
	var hold_pct := int(round(hold_chance(id) * 100.0))
	var site_name := str(site(id).name)
	var anchor := str(site(id).get("anchor", ""))
	if roll < hold_chance(id):
		# Held the site — raiders still sack half the granary if any.
		var looted := loot_cache(id, 0.5)
		st = state(id)
		var before := int(st.garrison)
		st.threat = {}
		st.garrison = maxi(0, before - 1)
		_put(id, st)
		_log(Locale.t("terr_53") % [site_name, before, int(st.garrison), hold_pct])
		if looted > 0:
			_log(Locale.t("atlas_siege_loot_hold_log") % [site_name, looted])
			World.mark_siege_loot({
				"id": id,
				"name": site_name,
				"by_name": by_name,
				"looted": looted,
				"cache_left": int(state(id).get("cache_food", 0)),
				"outcome": "held",
				"anchor": anchor,
			})
		# Aftermath modal (SiegeLoot stays for cache; this is hold/garrison).
		World.mark_threat_resolve({
			"id": id,
			"name": site_name,
			"by_name": by_name,
			"outcome": "held",
			"garrison_before": before,
			"garrison_after": int(st.garrison),
			"hold_pct": hold_pct,
			"looted": looted,
			"anchor": anchor,
		})
	else:
		# Lost — empty the granary into the attackers before ownership flips.
		var looted2 := loot_cache(id, 1.0)
		if looted2 > 0:
			_log(Locale.t("atlas_siege_loot_lost_log") % [site_name, looted2])
			World.mark_siege_loot({
				"id": id,
				"name": site_name,
				"by_name": by_name,
				"looted": looted2,
				"cache_left": 0,
				"outcome": "lost",
				"anchor": anchor,
			})
		World.mark_threat_resolve({
			"id": id,
			"name": site_name,
			"by_name": by_name,
			"outcome": "lost",
			"garrison_before": int(st.garrison),
			"garrison_after": 0,
			"hold_pct": hold_pct,
			"looted": looted2,
			"anchor": anchor,
		})
		lose(id, by)

static func threatened_at(anchor: String) -> Array:
	var out: Array = []
	for id in sites_at(anchor):
		if owned(id) and not (state(id).threat as Dictionary).is_empty():
			out.append(id)
	return out

## Owned sites currently under rival threat (castle HubTodo / J14).
static func threatened_owned() -> Array:
	var out: Array = []
	for id in owned_ids():
		if not (state(id).threat as Dictionary).is_empty():
			out.append(id)
	return out

## Castle Todo chip deep-link: re-queue SiegeAlert for the most urgent threatened site.
## Returns the site id queued, or "" if none.
static func hub_requeue_siege_alert() -> String:
	var ids := threatened_owned()
	if ids.is_empty():
		return ""
	var pick := str(ids[0])
	var best_m := -1
	for id in ids:
		var m := int(state(str(id)).threat.get("months", 0))
		if m > best_m:
			best_m = m
			pick = str(id)
	var phase := "imminent" if best_m >= 1 else "declared"
	# Clear so mark_siege_alert always accepts the castle deep-link payload.
	World.last_siege_alert = {}
	_emit_siege_alert(pick, phase)
	return pick

## Push a SiegeAlertModal payload onto World (declared / imminent).
static func _emit_siege_alert(id: String, phase: String) -> void:
	var s := site(id)
	var st := state(id)
	var th: Dictionary = st.threat if typeof(st.threat) == TYPE_DICTIONARY else {}
	if th.is_empty():
		return
	var anchor_id := str(s.anchor)
	var scouted := bool(th.get("scouted", false))
	var payload := {
		"id": id,
		"name": str(s.name),
		"by": str(th.get("by", "")),
		"by_name": str(th.get("name", "")),
		"anchor": anchor_id,
		"anchor_name": str(World.node(anchor_id).get("name", anchor_id)),
		"garrison": int(st.garrison),
		"months": int(th.get("months", 0)),
		"phase": phase,
		"scouted": scouted,
		"bribed": bool(th.get("bribed", false)),
		"bribe_cost": bribe_cost(id),
		"scout_cost": scout_cost(id),
		"hold_pct": int(round(hold_chance(id) * 100.0)) if scouted else -1,
		"stockade": bool(st.stockade),
		"cache": int(st.get("cache_food", 0)),
	}
	World.mark_siege_alert(payload)


## Improve-plan #1 countermeasures while a threat hangs over an owned site.
static func bribe_cost(id: String) -> int:
	return int(rule("bribe_cost", 50)) + int(site(id).get("danger", 1)) * 15

static func scout_cost(_id: String) -> int:
	return int(rule("scout_cost", 20))

## Pay to push the threat back one month (months → 0). Once per threat.
static func bribe_threat(id: String) -> Dictionary:
	if not owned(id) or (state(id).threat as Dictionary).is_empty():
		return {"ok": false, "msg": Locale.t("terr_34")}
	var st := state(id)
	if bool(st.threat.get("bribed", false)):
		return {"ok": false, "msg": Locale.t("terr_55")}
	var cost := bribe_cost(id)
	if GameState.silver < cost:
		return {"ok": false, "msg": Locale.t("terr_27") % cost}
	GameState.silver -= cost
	st.threat["bribed"] = true
	st.threat["months"] = 0
	_put(id, st)
	_log(Locale.t("terr_56") % [site(id).name, cost])
	CKEconomyState.month_echo_note("bribe", Locale.t("terr_echo_bribe", [site(id).name, cost]))
	GameState.mark_dirty()
	World.world_changed.emit()
	return {"ok": true, "msg": Locale.t("terr_56") % [site(id).name, cost]}

## Spend a little silver to learn the exact hold chance and attacker.
static func scout_threat(id: String) -> Dictionary:
	if not owned(id) or (state(id).threat as Dictionary).is_empty():
		return {"ok": false, "msg": Locale.t("terr_34")}
	var st := state(id)
	if bool(st.threat.get("scouted", false)):
		return {"ok": true, "msg": Locale.t("terr_57") % [st.threat.get("name", ""), int(round(hold_chance(id) * 100.0))], "intel": st.threat.get("intel", {})}
	var cost := scout_cost(id)
	if GameState.silver < cost:
		return {"ok": false, "msg": Locale.t("terr_27") % cost}
	GameState.silver -= cost
	var hold_pct := int(round(hold_chance(id) * 100.0))
	var intel := {
		"hold_pct": hold_pct,
		"garrison": int(st.garrison),
		"by": str(st.threat.get("name", "")),
		"months": int(st.threat.get("months", 0)),
	}
	st.threat["scouted"] = true
	st.threat["intel"] = intel
	_put(id, st)
	var msg := Locale.t("terr_57") % [intel["by"], hold_pct]
	_log(msg)
	CKEconomyState.month_echo_note("scout", Locale.t("terr_echo_scout", [site(id).name, cost, hold_pct]))
	GameState.mark_dirty()
	World.world_changed.emit()
	return {"ok": true, "msg": msg, "intel": intel}

## Ambush the attackers from the anchor (small defend battle). Win clears the threat.
static func intercept(id: String) -> Dictionary:
	if not owned(id) or (state(id).threat as Dictionary).is_empty():
		return {"ok": false, "msg": Locale.t("terr_34")}
	var s := site(id)
	if World.pos != str(s.anchor):
		return {"ok": false, "msg": Locale.t("terr_05") % World.node(str(s.anchor)).get("name", "")}
	if not World.encounter.is_empty():
		return {"ok": false, "msg": Locale.t("terr_06")}
	var enc := World.start_encounter("territory_defend", {"node": str(s.anchor), "from": str(s.anchor), "site": id, "danger": int(s.danger) + 1, "intercept": true})
	return {"ok": true, "encounter": enc, "msg": Locale.t("terr_58") % s.name}

static func defend(id: String) -> Dictionary:
	if not owned(id) or (state(id).threat as Dictionary).is_empty():
		return {"ok": false, "msg": Locale.t("terr_34")}
	var s := site(id)
	if World.pos != str(s.anchor):
		return {"ok": false, "msg": Locale.t("terr_05") % World.node(str(s.anchor)).get("name", "")}
	if not World.encounter.is_empty():
		return {"ok": false, "msg": Locale.t("terr_06")}
	var enc := World.start_encounter("territory_defend", {"node": str(s.anchor), "from": str(s.anchor), "site": id, "danger": int(s.danger) + 1})
	return {"ok": true, "encounter": enc}

## World.on_battle_end hook for territory encounters.
static func on_battle(enc: Dictionary, win: bool) -> String:
	var id := str(enc.get("site", ""))
	if id == "" or site(id).is_empty():
		return ""
	match str(enc.get("kind", "")):
		"territory_assault":
			if win:
				capture(id, "assault")
				return Locale.t("terr_35") % site(id).name
		"territory_defend":
			if win:
				var st := state(id)
				var by_name := str(st.threat.get("name", ""))
				st.threat = {}
				_put(id, st)
				World.add_city_rep(str(site(id).anchor), 3)
				_log(Locale.t("terr_36") % site(id).name)
				CKEconomyState.month_echo_note("defend", Locale.t("terr_echo_defend",
					[str(site(id).name), by_name, int(st.garrison)]))
				return Locale.t("terr_37") % site(id).name
			var by := str(state(id).threat.get("by", NEUTRAL))
			lose(id, by)
			return Locale.t("terr_38") % site(id).name
	return ""

## Arrival at an anchor with a pending threat opens the defend battle.
static func on_arrive(anchor: String) -> Dictionary:
	for id in threatened_at(anchor):
		var r := defend(id)
		if bool(r.get("ok", false)):
			return r.encounter
	return {}

# ── map ───────────────────────────────────────────────
static func banner_texture(w: int = 28, h: int = 38) -> Texture2D:
	## Castle / atlas owned-site flags — company 团徽 via Field cache.
	return CKHeraldryField.company_banner_texture(w, h)

static func map_markers(nation: String) -> Array:
	var out: Array = []
	for id in sites_in(nation):
		var s := site(id)
		var st := state(id)
		out.append({"id": id, "name": s.name, "kind": s.kind, "pos": s.pos, "anchor": s.anchor, "owner": st.owner,
			"threat": not (st.threat as Dictionary).is_empty(),
			"contest": not (st.contest as Dictionary).is_empty(),
			"garrison": st.garrison})
	return out

static func summary(id: String) -> String:
	var s := site(id)
	var st := state(id)
	var own := Locale.t("terr_39")
	if owned(id):
		own = Locale.t("terr_40") % int(st.garrison)
		if bool(st.stockade):
			own += " · " + Locale.t("terr_st_label")
	elif str(st.owner).begins_with("rival:"):
		own = _rival_name(str(st.owner).trim_prefix("rival:"))
	var prod := Locale.t("terr_41") % int(s.yield_silver)
	if str(s.good) != "":
		prod += " + %s ×%d" % [World.good_name(str(s.good)), int(s.yield_qty)]
	var t := "%s · %s · %s" % [s.name, kind_zh(str(s.kind)), own] + "\n" + Locale.t("terr_42") % [prod, upkeep(id)]
	if int(st.unrest) > 0:
		t += Locale.t("terr_43") % int(st.unrest)
	if not (st.contest as Dictionary).is_empty():
		t += "\n！" + Locale.t("atlas_contest_summary") % _faction_names(st.contest.get("factions", []))
	if not (st.threat as Dictionary).is_empty():
		t += "\n！" + Locale.t("terr_44") % st.threat.get("name", "")
		if bool(st.threat.get("scouted", false)):
			var intel: Dictionary = st.threat.get("intel", {}) if typeof(st.threat.get("intel", {})) == TYPE_DICTIONARY else {}
			t += "\n" + Locale.t("terr_57") % [st.threat.get("name", ""), int(intel.get("hold_pct", int(round(hold_chance(id) * 100.0))))]
	return t
