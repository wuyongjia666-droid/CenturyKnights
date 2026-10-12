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
static var _banner_cache: Dictionary = {}
static var rng := RandomNumberGenerator.new()

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
	return {"v": SCHEMA, "sites": {}, "log": []}

static func _st() -> Dictionary:
	if typeof(World.territory) != TYPE_DICTIONARY or not World.territory.has("sites"):
		World.territory = fresh()
	return World.territory

static func state(id: String) -> Dictionary:
	var row = _st().sites.get(id, {})
	var d: Dictionary = row if typeof(row) == TYPE_DICTIONARY else {}
	return {
		"owner": str(d.get("owner", NEUTRAL)), "garrison": int(d.get("garrison", 0)),
		"unrest": int(d.get("unrest", 0)), "threat": d.get("threat", {}) if typeof(d.get("threat", {})) == TYPE_DICTIONARY else {},
	}

static func _put(id: String, s: Dictionary) -> void:
	if str(s.owner) == NEUTRAL and int(s.garrison) == 0 and int(s.unrest) == 0 and (s.threat as Dictionary).is_empty():
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
			out.sites[sid] = {
				"owner": str(r.get("owner", NEUTRAL)),
				"garrison": clampi(int(r.get("garrison", 0)), 0, int(rule("garrison_max", 3))),
				"unrest": maxi(0, int(r.get("unrest", 0))),
				"threat": th if typeof(th) == TYPE_DICTIONARY else {},
			}
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
		return "无此领地"
	if owned(id):
		return "已是我方领地"
	if World.nation_rep(str(s.nation)) < req_rep(id):
		return "邦交声望不足（需 %d）" % req_rep(id)
	if owned_ids().size() >= int(rule("max_sites", 8)):
		return "领地已达上限 %d" % int(rule("max_sites", 8))
	if need_presence and World.pos != str(s.anchor):
		return "需身处%s" % World.node(str(s.anchor)).get("name", "")
	if not World.encounter.is_empty():
		return "战事未了"
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
		return {"ok": false, "msg": "无此领地"}
	var st := state(id)
	st.owner = OWN
	st.threat = {}
	st.garrison = maxi(1, int(st.garrison)) if how == "chain" else 0
	st.unrest = int(rule("unrest_months", 2)) if how == "assault" else 0
	_put(id, st)
	_log("团旗升起：占领%s%s" % [site(id).name, "（民心未附）" if how == "assault" else "（寨民归附）"])
	GameState.mark_dirty()
	World.world_changed.emit()
	return {"ok": true, "msg": "占领%s" % site(id).name}

static func lose(id: String, to: String) -> Dictionary:
	if is_home(id) or site(id).is_empty():
		return {"ok": false, "msg": "本堡永不失守"}
	var st := state(id)
	st.owner = to
	st.garrison = 0
	st.unrest = 0
	st.threat = {}
	_put(id, st)
	var who := "匪帮" if to == NEUTRAL else _rival_name(to.trim_prefix("rival:"))
	_log("%s失守，落入%s之手" % [site(id).name, who])
	GameState.mark_dirty()
	World.world_changed.emit()
	return {"ok": true}

## Peaceful route: two ordinary commissions on the anchor's board (gather, then hunt).
static func post_chain(id: String) -> Dictionary:
	var why := capture_block(id)
	if why != "":
		return {"ok": false, "msg": why}
	for q in World.active:
		if str(q.get("territory", "")) == id:
			return {"ok": false, "msg": "归附委托已在进行"}
	var q := _chain_step(id, 0)
	if q.is_empty():
		return {"ok": false, "msg": "此地无人发委托"}
	World._post_chain_offer(q)
	World.world_changed.emit()
	return {"ok": true, "quest": q, "msg": "%s的委托榜贴出「%s」" % [World.node(str(site(id).anchor)).get("name", ""), q.title]}

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
			"title": "%s的口粮与药" % s.name, "battle": false, "danger": 1, "days_budget": 40, "route_days": 0,
			"reward_silver": 20,
			"desc": "%s的人不信刀，信东西。带 %s ×%d 来%s交付，他们才肯听我们说话。（领地归附 1/2）" % [s.name, World.good_name(g), 10 if g == "grain" else 4, n.get("name", "")]})
	else:
		var target := World._near(anchor, 1, 1, rng)
		if target == "":
			target = anchor
		var rt := World.route(anchor, target)
		q.merge({"kind": "hunt", "target": target, "title": "清掉%s外的匪窝" % World.node(target).get("name", ""),
			"battle": true, "danger": int(s.danger), "route_days": int(rt.get("days", 1)), "foe_name": "盘踞的匪帮",
			"days_budget": int(rt.get("days", 1)) * 2 + 10, "reward_silver": 30,
			"desc": "匪帮在%s一带勒索%s。赶到即开战，得胜后回%s交付，团旗就能挂上去。（领地归附 2/2）" % [World.node(target).get("name", ""), s.name, n.get("name", "")]})
	return q

## Called by World.turn_in for quests that carry a territory field.
static func on_quest_done(q: Dictionary) -> String:
	var id := str(q.get("territory", ""))
	if id == "" or site(id).is_empty():
		return ""
	if int(q.get("territory_step", 0)) == 0:
		var nq := _chain_step(id, 1)
		World._post_chain_offer(nq)
		return "；%s贴出下一步「%s」" % [World.node(str(nq.issuer)).get("name", ""), nq.title]
	if capture_block(id, false) != "" and not owned(id):
		return "；%s暂不能归附：%s" % [site(id).name, capture_block(id, false)]
	capture(id, "chain")
	World.add_city_rep(str(site(id).anchor), 4)
	return "；%s归附，团旗升起" % site(id).name

# ── garrison ──────────────────────────────────────────
static func garrison_cost(id: String) -> int:
	return int(rule("garrison_cost", 40)) * (int(state(id).garrison) + 1)

static func reinforce(id: String) -> Dictionary:
	if not owned(id):
		return {"ok": false, "msg": "不是我方领地"}
	var st := state(id)
	if int(st.garrison) >= int(rule("garrison_max", 3)):
		return {"ok": false, "msg": "驻军已满"}
	var cost := garrison_cost(id)
	if GameState.silver < cost:
		return {"ok": false, "msg": "银不足（需 %d）" % cost}
	GameState.silver -= cost
	st.garrison = int(st.garrison) + 1
	_put(id, st)
	GameState.mark_dirty()
	World.world_changed.emit()
	return {"ok": true, "msg": "%s驻军升至 %d 级（-%d 银）" % [site(id).name, int(st.garrison), cost]}

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

## Month phase "world". Returns a summary line (empty when the company holds nothing).
static func apply_month(force_roll: float = -1.0) -> String:
	var ids := owned_ids()
	if ids.is_empty():
		return ""
	var silver := 0
	var notes: Array = []
	for id in ids:
		var s := site(id)
		var st := state(id)
		# threats posted last month resolve now if nobody came
		if not (st.threat as Dictionary).is_empty():
			if int(st.threat.get("months", 0)) >= 1:
				_resolve_unanswered(id, force_roll)
				if not owned(id):
					continue
				st = state(id)
			else:
				st.threat["months"] = 1
		var half := int(st.unrest) > 0 or not (st.threat as Dictionary).is_empty()
		var ys := int(s.yield_silver)
		var yq := int(s.yield_qty)
		if half:
			ys /= 2
			yq /= 2
		silver += ys
		if yq > 0 and str(s.good) != "":
			silver += _deliver_good(str(s.good), yq)
		var up := upkeep(id)
		silver -= up
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
				notes.append("%s欠饷，驻军降至 %d 级" % [site(id).name, int(st2.garrison)])
	for id in owned_ids():
		var st3 := state(id)
		if (st3.threat as Dictionary).is_empty():
			var roll := rng.randf() if force_roll < 0.0 else force_roll
			if roll < contest_chance(id):
				start_threat(id)
	var line := "领地月结：%+d 银（%d 处）" % [silver, owned_ids().size()]
	for n in notes:
		line += "；" + str(n)
	return line

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
	var by_name := "%s匪帮" % World.nations.get(str(s.nation), {}).get("name", "") if rv.is_empty() else str(rv.name)
	var st := state(id)
	st.threat = {"by": by, "name": by_name, "day": World.days_total, "months": 0}
	_put(id, st)
	_log("%s来犯%s！一月内赶到%s守卫，否则只能靠驻军" % [by_name, s.name, World.node(str(s.anchor)).get("name", "")])
	World.world_changed.emit()
	return st.threat

static func _resolve_unanswered(id: String, force_roll: float) -> void:
	var st := state(id)
	var by := str(st.threat.get("by", NEUTRAL))
	var roll := rng.randf() if force_roll < 0.0 else force_roll
	if roll < hold_chance(id):
		st.threat = {}
		st.garrison = maxi(0, int(st.garrison) - 1)
		_put(id, st)
		_log("%s驻军独力守住，折损一级" % site(id).name)
	else:
		lose(id, by)

static func threatened_at(anchor: String) -> Array:
	var out: Array = []
	for id in sites_at(anchor):
		if owned(id) and not (state(id).threat as Dictionary).is_empty():
			out.append(id)
	return out

static func defend(id: String) -> Dictionary:
	if not owned(id) or (state(id).threat as Dictionary).is_empty():
		return {"ok": false, "msg": "此地无战事"}
	var s := site(id)
	if World.pos != str(s.anchor):
		return {"ok": false, "msg": "需身处%s" % World.node(str(s.anchor)).get("name", "")}
	if not World.encounter.is_empty():
		return {"ok": false, "msg": "战事未了"}
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
				return "；团旗升起：%s" % site(id).name
		"territory_defend":
			if win:
				var st := state(id)
				st.threat = {}
				_put(id, st)
				World.add_city_rep(str(site(id).anchor), 3)
				_log("守住%s" % site(id).name)
				return "；守住%s" % site(id).name
			var by := str(state(id).threat.get("by", NEUTRAL))
			lose(id, by)
			return "；%s失守" % site(id).name
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
	var spec: Dictionary = GameState.banner_spec if not GameState.banner_spec.is_empty() else CKHeraldry.from_crest(str(GameState.crest_color))
	var key := "%s_%d_%d" % [CKHeraldry.cache_key(spec), w, h]
	if not _banner_cache.has(key):
		_banner_cache[key] = CKHeraldryRender.compose_texture(spec, w, h, 0.0, "banner")
	return _banner_cache[key]

static func map_markers(nation: String) -> Array:
	var out: Array = []
	for id in sites_in(nation):
		var s := site(id)
		var st := state(id)
		out.append({"id": id, "name": s.name, "kind": s.kind, "pos": s.pos, "anchor": s.anchor, "owner": st.owner,
			"threat": not (st.threat as Dictionary).is_empty(), "garrison": st.garrison})
	return out

static func summary(id: String) -> String:
	var s := site(id)
	var st := state(id)
	var own := "中立"
	if owned(id):
		own = "我方 · 驻军 %d" % int(st.garrison)
	elif str(st.owner).begins_with("rival:"):
		own = _rival_name(str(st.owner).trim_prefix("rival:"))
	var prod := "%d 银" % int(s.yield_silver)
	if str(s.good) != "":
		prod += " + %s ×%d" % [World.good_name(str(s.good)), int(s.yield_qty)]
	var t := "%s · %s · %s\n月产 %s · 维护 %d 银" % [s.name, kind_zh(str(s.kind)), own, prod, upkeep(id)]
	if int(st.unrest) > 0:
		t += " · 民心未附 %d 月" % int(st.unrest)
	if not (st.threat as Dictionary).is_empty():
		t += "\n⚠ %s来犯" % st.threat.get("name", "")
	return t
