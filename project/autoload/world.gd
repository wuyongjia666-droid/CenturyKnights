extends Node
## v8.7 — playable atlas: 10 nations + 朔澜陆桥, 74 settlements, road graph, overworld travel (days → Calendar),
## road events → SRPG encounters, city markets (buy low / sell high), smiths with signature arms, regional taverns,
## per-city commission boards with reputation gating. Persisted via to_save()/from_save() inside GameState's save.

signal world_changed
signal travel_step(info: Dictionary)

const DATA_PATH := "res://data/world_v87.json"
const ITEMS_PATH := "res://data/world_items_v87.json"
const ATLAS_SCENE := "res://scenes/hub/atlas_view.tscn"
const KIND_ZH := {"capital": "都城", "city": "城", "town": "镇", "port": "港", "fortress": "要塞", "village": "村", "castle": "本堡"}
const QUEST_KIND_ZH := {"deliver": "递送", "escort": "护送", "hunt": "追缉", "clear": "清剿", "defend": "防守", "gather": "收购", "scout": "探查"}
## CMP-04 remainder: battle contracts whose maps carry a BTL-02 objective.
## Kept off the board RNG so the original seven kinds, and seed 91, stay put.
const OBJECTIVE_KINDS := ["siege_aid", "bounty", "rescue", "convoy", "intel_race"]
const OBJECTIVE_VICTORY := {
	"siege_aid": "defend",
	"bounty": "boss",
	"rescue": "protect",
	"convoy": "escort",
	"intel_race": "seize",
}
const STAT_ZH := {"atk": "攻", "def": "防", "hit": "命中", "avo": "回避", "crit": "暴击", "move": "移动", "hp": "生命"}
const SLOT_ZH := {"weapon": "武器", "armor": "护具", "charm": "饰品"}
const REP_TIER_ZH := ["陌生", "认识", "友善", "信赖", "盟誓"]
## what each city-reputation tier opens (shown on the city 概览 ladder; enforced below)
const CITY_UNLOCKS := [
	"基础货品 · 一阶委托",
	"本城签名兵器 · 二阶委托 · 委托榜 +1",
	"铁匠铺扩建 · 三阶与名誉委托 · 买卖价优 2.5%",
	"铁匠铺再扩建 · 传奇兵器（须名誉委托）· 委托榜 +1 · 价优 5%",
	"城中贵胄投效（酒馆 +1 爵位候选）· 价优 7.5% · 名誉委托报酬 +20%",
]
## nation-reputation tiers (邦交)
const NATION_UNLOCKS := [
	"敌对 / 戒备之邦不接外人委托",
	"可接该国全部委托 · 关税 -3",
	"关税全免 · 该国二阶以上委托开放",
	"该国全境市集价优 5% · 巡逻放行",
	"该国都城酒馆出现本国最高血脉",
]
const CHAIN_NEXT := {"deliver": "escort", "escort": "defend", "scout": "hunt", "hunt": "clear", "clear": "defend", "gather": "deliver", "defend": "hunt"}
signal rep_milestone(kind: String, id: String, tier: int)

var data: Dictionary = {}
var nodes: Dictionary = {}      # id -> node
var nations: Dictionary = {}
var goods: Dictionary = {}
var items: Dictionary = {}      # id -> item
var adj: Dictionary = {}        # id -> [road]
var rules: Dictionary = {}
var _biome_maps: Dictionary = {}  # biome -> [map ids] from maps.json

# ── persistent state ─────────────────────────────────
var pos: String = "hq"
var day: int = 1                # day within the current month (1..30)
var days_total: int = 0
var visited: Dictionary = {}
var rep_city: Dictionary = {}
var rep_nation: Dictionary = {}
var cargo: Dictionary = {}      # non-store goods
var market: Dictionary = {}     # city -> {good: stock}
var fairs: Dictionary = {}      # city -> days_total expiry
var intel: Dictionary = {}      # city -> days_total when prices were last seen
var tips: Array = []
var boards: Dictionary = {}     # city -> {"epoch": int, "offers": [quest]}
var active: Array = []          # accepted quests
var done_sig: Dictionary = {}   # sig quest id -> true
var quest_log: Array = []
var stats_done: Dictionary = {} # kind -> count
var armory: Dictionary = {}     # item id -> qty
var gear: Dictionary = {}       # cid -> {"armor": id, "charm": id}
var recruits: Dictionary = {}   # city -> {"epoch": int, "list": [char dict]}
var travel: Dictionary = {}     # {"route": [ids], "leg": int, "dest": id}
var pending_event: Dictionary = {}
var road_flags: Dictionary = {}  # CMP-09: choice flags set by road events
var encounter: Dictionary = {}
var travel_log: Array = []
var month_reports: Array = []
var royal_courts: Dictionary = {}  # v9.0 NPC royal houses (CKCourt)
var _qseq: int = 0
var _enc_seq: int = 0
var _in_travel_month := false
var milestones: Array = []      # UI toasts: {"kind": "city"|"nation", "id", "tier", "text"}
var events_enabled := true       # tests may disable random road events
var rivals_enabled := true       # CMP-04: rival companies move, steal offers, raise prices. Century sim turns this off.
var rivals: Array = []           # {id, name, pos, home, stolen, price_mul}
var rival_thefts: Array = []
var chain_progress: Dictionary = {}  # chain id -> {step, status}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_load()
	if not Calendar.month_advanced.is_connected(_on_month):
		Calendar.month_advanced.connect(_on_month)

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _load() -> void:
	data = _read(DATA_PATH)
	nations = data.get("nations", {})
	goods = data.get("goods", {})
	rules = data.get("rules", {})
	nodes.clear()
	adj.clear()
	for n in data.get("nodes", []):
		nodes[str(n.id)] = n
		adj[str(n.id)] = []
	for r in data.get("roads", []):
		adj[str(r.a)].append(r)
		adj[str(r.b)].append(r)
	items.clear()
	for it in _read(ITEMS_PATH).get("items", []):
		items[str(it.id)] = it
	_biome_maps.clear()
	var maps: Dictionary = _read("res://data/maps.json").get("maps", {})
	for mid in maps.keys():
		var m: Dictionary = maps[mid]
		if bool(m.get("tutorial_militia", false)) or str(mid).find("heir") >= 0:
			continue
		if m.get("enemy_spots", []).size() < 3:
			continue
		var b := AtlasArt.biome_for_map(str(mid))
		if not _biome_maps.has(b):
			_biome_maps[b] = []
		_biome_maps[b].append(str(mid))

# ── lifecycle ─────────────────────────────────────────
func reset() -> void:
	pos = str(data.get("home", "hq"))
	day = 1
	days_total = 0
	visited = {pos: true}
	rep_city = {}
	rep_nation = {}
	for nid in nations.keys():
		rep_nation[nid] = 0
	rep_nation["ashbanner"] = 12
	rep_nation["landbridge"] = 5
	for id in nodes.keys():
		var n: Dictionary = nodes[id]
		rep_city[id] = 0
		if str(n.nation) == "ashbanner":
			rep_city[id] = 10
	rep_city[pos] = 40
	cargo = {}
	market = {}
	for id in nodes.keys():
		_init_market(id)
	fairs = {}
	intel = {pos: 0}
	tips = []
	boards = {}
	active = []
	done_sig = {}
	quest_log = []
	stats_done = {}
	armory = {}
	gear = {}
	recruits = {}
	travel = {}
	pending_event = {}
	road_flags = {}
	encounter = {}
	travel_log = []
	month_reports = []
	royal_courts = {}
	_qseq = 0
	_enc_seq = 0
	chain_progress = {}
	_init_rivals()
	world_changed.emit()

func to_save() -> Dictionary:
	var rc := {}
	for k in recruits.keys():
		rc[k] = recruits[k]
	return {
		"v": 1, "pos": pos, "day": day, "days_total": days_total, "visited": visited, "rep_city": rep_city, "rep_nation": rep_nation,
		"cargo": cargo, "market": market, "fairs": fairs, "intel": intel, "tips": tips, "boards": boards, "active": active,
		"done_sig": done_sig, "quest_log": quest_log, "stats_done": stats_done, "armory": armory, "gear": gear, "recruits": rc,
		"travel": travel, "pending_event": pending_event, "road_flags": road_flags, "encounter": encounter, "travel_log": travel_log, "qseq": _qseq, "enc_seq": _enc_seq,
		"royal_courts": royal_courts, "rivals": rivals, "rival_thefts": rival_thefts, "chain_progress": chain_progress,
	}

func from_save(d: Dictionary) -> void:
	if d.is_empty():
		reset()
		return
	pos = str(d.get("pos", "hq"))
	if not nodes.has(pos):
		pos = "hq"
	day = int(d.get("day", 1))
	days_total = int(d.get("days_total", 0))
	visited = d.get("visited", {pos: true})
	rep_city = _int_dict(d.get("rep_city", {}))
	rep_nation = _int_dict(d.get("rep_nation", {}))
	cargo = _int_dict(d.get("cargo", {}))
	market = {}
	var m: Dictionary = d.get("market", {})
	for id in nodes.keys():
		if m.has(id):
			market[id] = _int_dict(m[id])
		else:
			_init_market(id)
	fairs = _int_dict(d.get("fairs", {}))
	intel = _int_dict(d.get("intel", {}))
	tips = d.get("tips", [])
	boards = d.get("boards", {})
	active = d.get("active", [])
	done_sig = d.get("done_sig", {})
	quest_log = d.get("quest_log", [])
	stats_done = _int_dict(d.get("stats_done", {}))
	armory = _int_dict(d.get("armory", {}))
	gear = d.get("gear", {})
	recruits = d.get("recruits", {})
	travel = d.get("travel", {})
	pending_event = d.get("pending_event", {})
	road_flags = {}
	var saved_flags = d.get("road_flags", {})
	if typeof(saved_flags) == TYPE_DICTIONARY:
		for fk in saved_flags.keys():
			road_flags[str(fk)] = bool(saved_flags[fk])
	encounter = d.get("encounter", {})
	travel_log = d.get("travel_log", [])
	royal_courts = d.get("royal_courts", {}) if typeof(d.get("royal_courts", {})) == TYPE_DICTIONARY else {}
	_qseq = int(d.get("qseq", 0))
	_enc_seq = int(d.get("enc_seq", 0))
	chain_progress = d.get("chain_progress", {}) if typeof(d.get("chain_progress", {})) == TYPE_DICTIONARY else {}
	_restore_rivals(d.get("rivals", []))
	rival_thefts = d.get("rival_thefts", []) if typeof(d.get("rival_thefts", [])) == TYPE_ARRAY else []
	world_changed.emit()

func _int_dict(src) -> Dictionary:
	var out := {}
	if typeof(src) != TYPE_DICTIONARY:
		return out
	for k in src.keys():
		out[str(k)] = int(src[k])
	return out

# ── queries ───────────────────────────────────────────
func node(id: String) -> Dictionary:
	return nodes.get(id, {})

func nation_of(id: String) -> String:
	return str(nodes.get(id, {}).get("nation", ""))

func nodes_in(nation_id: String) -> Array:
	var out: Array = []
	for n in data.get("nodes", []):
		if str(n.nation) == nation_id:
			out.append(n)
	return out

func nation_ids() -> Array:
	return nations.keys()

func kind_zh(id: String) -> String:
	return KIND_ZH.get(str(node(id).get("kind", "")), "")

func roads_from(id: String) -> Array:
	return adj.get(id, [])

func other_end(r: Dictionary, id: String) -> String:
	return str(r.b) if str(r.a) == id else str(r.a)

func road_between(a: String, b: String) -> Dictionary:
	for r in adj.get(a, []):
		if other_end(r, a) == b:
			return r
	return {}

func party_size() -> int:
	return maxi(1, GameState.roster().size())

func food_per_day() -> int:
	return int(ceil(party_size() * float(rules.get("food_per_member_day", 0.5))))

func cargo_cap() -> int:
	return int(rules.get("cargo_base", 30)) + int(rules.get("cargo_per_member", 6)) * party_size()

func cargo_used() -> int:
	var n := 0
	for k in cargo.keys():
		n += int(cargo[k])
	for q in active:
		if str(q.get("kind", "")) == "deliver" and str(q.get("state", "")) == "active":
			n += 2
	return n

func good_name(g: String) -> String:
	return str(goods.get(g, {}).get("name", g))

func have_good(g: String) -> int:
	var store := str(goods.get(g, {}).get("store", ""))
	if store != "":
		return int(GameState.get(store))
	return int(cargo.get(g, 0))

func _add_good(g: String, q: int) -> void:
	var store := str(goods.get(g, {}).get("store", ""))
	if store != "":
		GameState.set(store, maxi(0, int(GameState.get(store)) + q))
	else:
		cargo[g] = maxi(0, int(cargo.get(g, 0)) + q)
		if int(cargo[g]) == 0:
			cargo.erase(g)

func world_tier() -> int:
	var n := 0
	for i in range(0, 235):
		if GameState.flag("chapter%d_done" % i):
			n += 1
	return clampi(1 + n / 12, 1, 5)

# ── reputation ────────────────────────────────────────
func rep_of(city: String) -> int:
	return int(rep_city.get(city, 0))

func nation_rep(nid: String) -> int:
	return int(rep_nation.get(nid, 0))

func rep_tier_index(v: int) -> int:
	var tiers: Array = rules.get("rep_tiers", [0, 10, 30, 55, 80])
	var t := 0
	for i in tiers.size():
		if v >= int(tiers[i]):
			t = i
	return t

func rep_tier_name(v: int) -> String:
	return str(REP_TIER_ZH[rep_tier_index(v)])

func add_city_rep(city: String, amt: int) -> void:
	if not nodes.has(city):
		return
	var t0 := rep_tier_index(rep_of(city))
	rep_city[city] = clampi(rep_of(city) + amt, 0, 100)
	var t1 := rep_tier_index(rep_of(city))
	if t1 > t0:
		var txt := "%s声望升至「%s」：%s" % [node(city).get("name", ""), REP_TIER_ZH[t1], CITY_UNLOCKS[t1]]
		milestones.append({"kind": "city", "id": city, "tier": t1, "text": txt})
		_tlog(txt)
		GameState.log_event(txt)
		boards.erase(city)  # board grows / new tiers appear right away
		rep_milestone.emit("city", city, t1)
	add_nation_rep(nation_of(city), int(round(amt * 0.5)))

func add_nation_rep(nid: String, amt: int) -> void:
	if nid == "":
		return
	var t0 := rep_tier_index(nation_rep(nid))
	rep_nation[nid] = clampi(nation_rep(nid) + amt, 0, 100)
	var t1 := rep_tier_index(nation_rep(nid))
	if t1 > t0:
		var txt := "%s邦交升至「%s」：%s" % [nations.get(nid, {}).get("name", ""), REP_TIER_ZH[t1], NATION_UNLOCKS[t1]]
		milestones.append({"kind": "nation", "id": nid, "tier": t1, "text": txt})
		_tlog(txt)
		rep_milestone.emit("nation", nid, t1)
		var oath := CKBloodline.on_nation_milestone(nid, t1)
		if oath != "":
			_tlog(oath)
	# mirror into the legacy realm reputation (castle / story systems read these)
	if nid == "ashbanner":
		GameState.add_rep("ashland", int(round(amt * 0.5)))
	elif nid == "qinghe":
		GameState.add_rep("riverland", int(round(amt * 0.5)))

func toll_for(nid: String) -> int:
	var base := int(nations.get(nid, {}).get("toll", 0))
	var cut := rep_tier_index(nation_rep(nid))
	if cut >= 2:
		return 0  # 友善邦交：关税全免
	return maxi(0, base - cut * 3)

func nation_stance(nid: String) -> String:
	return str(nations.get(nid, {}).get("stance", "neutral"))

func board_size(city: String) -> int:
	var n := node(city)
	var sz := int(rules.get("board_size", {}).get(str(n.get("kind", "")), 3))
	var t := rep_tier_index(rep_of(city))
	return sz + (1 if t >= 1 else 0) + (1 if t >= 3 else 0)

# ── pathfinding / travel preview ──────────────────────
func route(from_id: String, to_id: String) -> Dictionary:
	if not nodes.has(from_id) or not nodes.has(to_id):
		return {}
	if from_id == to_id:
		return {"path": [from_id], "days": 0, "legs": []}
	var dist := {from_id: 0}
	var prev := {}
	var open := [from_id]
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if int(dist[open[i]]) < int(dist[open[best]]):
				best = i
		var cur: String = open[best]
		open.remove_at(best)
		if cur == to_id:
			break
		for r in adj.get(cur, []):
			var nx := other_end(r, cur)
			var nd := int(dist[cur]) + int(r.days) + (2 if str(r.kind) == "sea" else 0)
			if not dist.has(nx) or nd < int(dist[nx]):
				dist[nx] = nd
				prev[nx] = cur
				if nx not in open:
					open.append(nx)
	if not dist.has(to_id):
		return {}
	var path: Array = [to_id]
	while path[0] != from_id:
		path.push_front(prev[path[0]])
	var legs: Array = []
	var days := 0
	for i in range(path.size() - 1):
		var r := road_between(path[i], path[i + 1])
		legs.append(r)
		days += int(r.days)
	return {"path": path, "days": days, "legs": legs}

func travel_preview(to_id: String) -> Dictionary:
	var r := route(pos, to_id)
	if r.is_empty():
		return {"ok": false, "msg": "无路可达"}
	var tolls := 0
	var fare := 0
	var danger := 0
	var borders: Array = []
	for i in r.legs.size():
		var leg: Dictionary = r.legs[i]
		danger = maxi(danger, int(leg.danger))
		if str(leg.kind) == "border":
			var into := nation_of(r.path[i + 1])
			tolls += toll_for(into)
			borders.append(str(nations.get(into, {}).get("name", into)))
		if str(leg.kind) == "sea":
			fare += int(leg.get("fare", 30))
	var food := food_per_day() * int(r.days)
	return {"ok": true, "path": r.path, "legs": r.legs, "days": r.days, "food": food, "tolls": tolls, "fare": fare,
			"danger": danger, "borders": borders, "short_food": GameState.food < food}

func is_traveling() -> bool:
	return not travel.is_empty()

func begin_travel(to_id: String) -> Dictionary:
	if is_traveling():
		return {"ok": false, "msg": "行军中"}
	if not pending_event.is_empty() or not encounter.is_empty():
		return {"ok": false, "msg": "先处理眼前的事件"}
	if to_id == pos:
		return {"ok": false, "msg": "已在此地"}
	var pv := travel_preview(to_id)
	if not pv.ok:
		return pv
	if GameState.silver < int(pv.fare):
		return {"ok": false, "msg": "船资不足（需 %d 银）" % int(pv.fare)}
	travel = {"route": pv.path, "leg": 0, "dest": to_id}
	_tlog("启程 → %s（预计 %d 日）" % [node(to_id).get("name", to_id), int(pv.days)])
	world_changed.emit()
	return {"ok": true, "preview": pv}

func cancel_travel() -> void:
	travel = {}
	world_changed.emit()

## Executes the next road leg. Returns {"arrived": bool, "pos": id, "event": {}, "encounter": {}, "msg": ""}.
func step_travel() -> Dictionary:
	if travel.is_empty():
		return {"arrived": true, "pos": pos}
	if not pending_event.is_empty():
		return {"event": pending_event, "pos": pos}
	if not encounter.is_empty():
		return {"encounter": encounter, "pos": pos}
	var path: Array = travel.route
	var i := int(travel.leg)
	if i >= path.size() - 1:
		travel = {}
		return {"arrived": true, "pos": pos}
	var a: String = path[i]
	var b: String = path[i + 1]
	var r := road_between(a, b)
	var msg := ""
	if str(r.kind) == "border":
		var t := toll_for(nation_of(b))
		if t > 0:
			GameState.silver = maxi(0, GameState.silver - t)
			msg = "过境%s，关税 %d 银" % [nations.get(nation_of(b), {}).get("name", ""), t]
	if str(r.kind) == "sea":
		GameState.silver = maxi(0, GameState.silver - int(r.get("fare", 30)))
		msg = "登船出海，船资 %d 银" % int(r.get("fare", 30))
	advance_days(int(r.days))
	if msg != "":
		_tlog(msg)
	# quest trigger on the edge itself (清剿 a—b)
	var qe := _quest_edge_trigger(a, b)
	if not qe.is_empty():
		travel.leg = i  # the leg resumes after the fight
		travel["pending_arrive"] = b
		return _emit_step({"encounter": qe, "pos": pos})
	var ev := _roll_event(r, a, b)
	if not ev.is_empty():
		travel["pending_arrive"] = b
		return _emit_step({"event": ev, "pos": pos})
	return _emit_step(_arrive_leg(b))

func _emit_step(info: Dictionary) -> Dictionary:
	world_changed.emit()
	travel_step.emit(info)
	return info

var _last_from := ""

func _arrive_leg(b: String) -> Dictionary:
	_last_from = pos
	pos = b
	travel.erase("pending_arrive")
	if not travel.is_empty():
		travel.leg = int(travel.leg) + 1
	var info := arrive(b)
	if not travel.is_empty() and (b == str(travel.dest) or int(travel.leg) >= travel.route.size() - 1):
		travel = {}
		info["arrived"] = true
	if not info.get("encounter", {}).is_empty():
		travel = {}
		info["arrived"] = true
	info["pos"] = pos
	return info

## Runs legs until arrival / event / encounter (UI animates one leg at a time; tests use this).
func travel_to(to_id: String) -> Dictionary:
	var st := begin_travel(to_id)
	if not st.ok:
		return st
	var info := {}
	for _i in 64:
		info = step_travel()
		if not info.get("event", {}).is_empty() or not info.get("encounter", {}).is_empty() or bool(info.get("arrived", false)):
			break
	info["ok"] = true
	return info

func arrive(id: String) -> Dictionary:
	var first := not visited.has(id)
	visited[id] = true
	intel[id] = days_total
	var n := node(id)
	_tlog("抵达 %s%s" % [n.get("name", id), "（初次踏足）" if first else ""])
	if first:
		add_city_rep(id, 2)
	_ensure_board(id)
	var out := {"arrived_at": id, "first": first}
	# arrival objectives
	for q in active:
		if str(q.state) != "active":
			continue
		var k := str(q.kind)
		if k in ["deliver", "escort"] and str(q.target) == id:
			q.state = "ready"
			_tlog("委托「%s」目标达成，可在此交付" % q.title)
		elif k == "scout" and str(q.target) == id:
			q.state = "ready"
			q["scouted"] = true
			_tlog("委托「%s」已探明，回 %s 复命" % [q.title, node(str(q.issuer)).get("name", "")])
		elif _arrives_in_battle(k) and str(q.target) == id and encounter.is_empty():
			out["encounter"] = start_encounter("quest", {"quest": str(q.id), "node": id, "from": _last_from if _last_from != "" else id})
			break
	_check_gather_ready()
	return out

# ── days / calendar ───────────────────────────────────
func advance_days(n: int) -> Array:
	var reports: Array = []
	for _d in n:
		days_total += 1
		day += 1
		# rations
		var need := food_per_day()
		if GameState.food >= need:
			GameState.food -= need
		else:
			GameState.food = 0
			GameState.morale = maxi(0, GameState.morale - int(rules.get("starve_morale_per_day", 4)))
			_tlog("断粮！士气下降")
		if day > int(rules.get("days_per_month", 30)):
			day = 1
			_in_travel_month = true
			var evs := Calendar.advance(1)
			_in_travel_month = false
			reports.append(evs)
			month_reports.append({"label": Calendar.label(), "events": evs})
			if month_reports.size() > 6:
				month_reports = month_reports.slice(month_reports.size() - 6)
	_expire_quests()
	return reports

func _on_month(_y: int, _m: int, _evs: Array) -> void:
	if not _in_travel_month:
		day = 1  # castle-side month advance resets the road calendar
	for id in market.keys():
		_regen_market(id)
	if rivals_enabled:
		tick_rivals()

func date_label() -> String:
	return "%s %d 日" % [Calendar.label(), day]

# ── markets ───────────────────────────────────────────
func _target_stock(city: String, g: String) -> int:
	var n := node(city)
	var sz := int(n.get("size", 2))
	if g in n.get("produce", []):
		return 24 + sz * 8
	if g in n.get("demand", []):
		return 3 + sz
	return 8 + sz * 2

func _init_market(city: String) -> void:
	var m := {}
	for g in goods.keys():
		m[g] = _target_stock(city, g)
	market[city] = m

func _regen_market(city: String) -> void:
	var m: Dictionary = market.get(city, {})
	for g in goods.keys():
		var t := _target_stock(city, g)
		var s := int(m.get(g, t))
		m[g] = s + int(round((t - s) * 0.35))
	market[city] = m

func price(city: String, g: String, side: String = "buy") -> int:
	var gd: Dictionary = goods.get(g, {})
	var base := float(gd.get("base", 5))
	var n := node(city)
	var local := 1.0
	if g in n.get("produce", []):
		local = 0.62
	elif g in n.get("demand", []):
		local = 1.55
	var nat: Dictionary = nations.get(str(n.get("nation", "")), {})
	if str(nat.get("mat", "")) == g and not (g in n.get("produce", [])):
		local *= 0.85
	var t := float(_target_stock(city, g))
	var s := float(maxi(1, int(market.get(city, {}).get(g, t))))
	var supply := clampf(pow(t / s, 0.35), 0.6, 1.9)
	var mid := base * local * supply
	if fairs.has(city) and int(fairs[city]) >= days_total and side == "sell":
		mid *= 1.15
	mid *= rival_price_mul(city)
	var spread := float(rules.get("price_spread", 0.08))
	var cut := float(rules.get("rep_price_cut", 0.10)) * rep_tier_index(rep_of(city)) / 4.0
	if rep_tier_index(nation_rep(str(n.get("nation", "")))) >= 3:
		cut += 0.05
	if side == "buy":
		return maxi(1, int(round(mid * (1.0 + spread) * (1.0 - cut))))
	return maxi(1, int(round(mid * (1.0 - spread) * (1.0 + cut * 0.5))))

func stock(city: String, g: String) -> int:
	return int(market.get(city, {}).get(g, 0))

func market_buy(city: String, g: String, qty: int = 1) -> Dictionary:
	if city != pos:
		return {"ok": false, "msg": "须身在此城"}
	if stock(city, g) < qty:
		return {"ok": false, "msg": "存货不足"}
	if str(goods.get(g, {}).get("store", "")) == "" and cargo_used() + qty > cargo_cap():
		return {"ok": false, "msg": "货舱已满（%d/%d）" % [cargo_used(), cargo_cap()]}
	var cost := quote_buy(city, g, qty)
	if GameState.silver < cost:
		return {"ok": false, "msg": "银币不足（需 %d）" % cost}
	market[city][g] = stock(city, g) - qty
	GameState.silver -= cost
	_add_good(g, qty)
	GameState.mark_dirty()
	world_changed.emit()
	return {"ok": true, "msg": "购入 %s ×%d（-%d 银）" % [good_name(g), qty, cost], "cost": cost}

## price walks with supply: every unit bought raises the next unit's price
func quote_buy(city: String, g: String, qty: int) -> int:
	var s0 := stock(city, g)
	var cost := 0
	for i in qty:
		market[city][g] = s0 - i
		cost += price(city, g, "buy")
	market[city][g] = s0
	return cost

func quote_sell(city: String, g: String, qty: int) -> int:
	var s0 := stock(city, g)
	var gain := 0
	for i in qty:
		market[city][g] = s0 + i
		gain += price(city, g, "sell")
	market[city][g] = s0
	return gain

func market_sell(city: String, g: String, qty: int = 1) -> Dictionary:
	if city != pos:
		return {"ok": false, "msg": "须身在此城"}
	if have_good(g) < qty:
		return {"ok": false, "msg": "持有不足"}
	var gain := quote_sell(city, g, qty)
	market[city][g] = stock(city, g) + qty
	_add_good(g, -qty)
	GameState.silver += gain
	if g in node(city).get("demand", []) and qty >= 5:
		add_city_rep(city, qty / 5)  # 供货解困：每 5 份求购货 +1 城声望
	_check_gather_ready()
	GameState.mark_dirty()
	world_changed.emit()
	return {"ok": true, "msg": "卖出 %s ×%d（+%d 银）" % [good_name(g), qty, gain], "gain": gain}

## Best known sell price elsewhere (only cities visited/tipped count — 情报即利润)
func best_known_sell(g: String, exclude: String = "") -> Dictionary:
	var best := {"city": "", "price": 0}
	for c in intel.keys():
		if c == exclude or not nodes.has(c):
			continue
		var p := price(c, g, "sell")
		if p > int(best.price):
			best = {"city": c, "price": p, "age": days_total - int(intel[c])}
	return best

# ── smith ─────────────────────────────────────────────
func smith_tier(city: String) -> int:
	var n := node(city)
	var t := int(n.get("smith_tier", 0))
	if t <= 0:
		return 0
	var bonus: Array = rules.get("smith_rep_bonus", [30, 55])
	for th in bonus:
		if rep_of(city) >= int(th):
			t += 1
	return mini(4, t)

func smith_stock(city: String) -> Array:
	var out: Array = []
	var n := node(city)
	var nid := str(n.get("nation", ""))
	var tier := smith_tier(city)
	if tier <= 0:
		return out
	for it in items.values():
		if str(it.nation) != nid or it.has("signature"):
			continue
		var ok := int(it.tier) <= tier
		out.append({"item": it, "available": ok, "reason": "" if ok else "铁匠铺需 %d 阶（声望提升可扩建）" % int(it.tier)})
	for sid in n.get("sig_items", []):
		var it2: Dictionary = items.get(str(sid), {})
		if it2.is_empty():
			continue
		var av := true
		var why := ""
		if int(it2.signature) == 1:
			if rep_of(city) < int(it2.rep_req):
				av = false
				why = "需本城声望「%s」（%d）" % [rep_tier_name(int(it2.rep_req)), int(it2.rep_req)]
		else:
			var sq := str(n.get("sig_quest", {}).get("id", ""))
			if not done_sig.has(sq):
				av = false
				why = "完成本城名誉委托「%s」后解锁" % str(n.get("sig_quest", {}).get("title", ""))
			elif rep_of(city) < int(it2.rep_req):
				av = false
				why = "需本城声望「信赖」（%d）" % int(it2.rep_req)
		out.append({"item": it2, "available": av, "reason": why, "signature": int(it2.signature)})
	out.sort_custom(func(x, y):
		var sx := int(x.item.get("signature", 0))
		var sy := int(y.item.get("signature", 0))
		if sx != sy:
			return sx > sy
		return int(x.item.tier) < int(y.item.tier))
	return out

func _stock_entry(city: String, iid: String) -> Dictionary:
	for e in smith_stock(city):
		if str(e.item.id) == iid:
			return e
	return {}

func smith_price(city: String, iid: String) -> int:
	var it: Dictionary = items.get(iid, {})
	var cut := 0.04 * rep_tier_index(rep_of(city))
	return int(round(int(it.get("price", 0)) * (1.0 - cut)))

func mats_ok(it: Dictionary) -> Dictionary:
	var missing := {}
	for g in it.get("mats", {}).keys():
		var need := int(it.mats[g])
		if have_good(str(g)) < need:
			missing[g] = need - have_good(str(g))
	return missing

func buy_item(city: String, iid: String) -> Dictionary:
	if city != pos:
		return {"ok": false, "msg": "须身在此城"}
	var e := _stock_entry(city, iid)
	if e.is_empty():
		return {"ok": false, "msg": "此铺不卖"}
	if not bool(e.available):
		return {"ok": false, "msg": str(e.reason)}
	var cost := smith_price(city, iid)
	if GameState.silver < cost:
		return {"ok": false, "msg": "银币不足（需 %d）" % cost}
	GameState.silver -= cost
	armory[iid] = int(armory.get(iid, 0)) + 1
	add_city_rep(city, 1)
	GameState.log_event("在%s购入「%s」" % [node(city).get("name", ""), items[iid].name])
	GameState.mark_dirty()
	world_changed.emit()
	return {"ok": true, "msg": "购入「%s」（-%d 银）" % [items[iid].name, cost]}

func forge_item(city: String, iid: String) -> Dictionary:
	if city != pos:
		return {"ok": false, "msg": "须身在此城"}
	var e := _stock_entry(city, iid)
	if e.is_empty() or not bool(e.available):
		return {"ok": false, "msg": str(e.get("reason", "此铺不能打造"))}
	var it: Dictionary = items[iid]
	var miss := mats_ok(it)
	if not miss.is_empty():
		var parts: Array = []
		for g in miss.keys():
			parts.append("%s×%d" % [good_name(str(g)), int(miss[g])])
		return {"ok": false, "msg": "缺材料：" + "、".join(parts)}
	var cost := int(it.get("forge_silver", 0))
	if GameState.silver < cost:
		return {"ok": false, "msg": "工钱不足（需 %d 银）" % cost}
	GameState.silver -= cost
	for g in it.mats.keys():
		_add_good(str(g), -int(it.mats[g]))
	armory[iid] = int(armory.get(iid, 0)) + 1
	add_city_rep(city, 2)
	GameState.log_event("%s铁匠为灰旗打造「%s」" % [node(city).get("name", ""), it.name])
	GameState.mark_dirty()
	world_changed.emit()
	return {"ok": true, "msg": "打造完成：「%s」（工钱 %d 银 + 材料）" % [it.name, cost]}

func item(iid: String) -> Dictionary:
	return items.get(iid, {})

func item_stats_text(it: Dictionary) -> String:
	var parts: Array = []
	for k in ["atk", "def", "hit", "avo", "crit", "move", "hp"]:
		if it.get("stats", {}).has(k):
			var v := int(it.stats[k])
			parts.append("%s%s%d" % [STAT_ZH[k], "+" if v >= 0 else "", v])
	return " ".join(parts)

func can_equip(c: CKCharacter, it: Dictionary) -> String:
	if c == null or it.is_empty():
		return "无效"
	var jobs: Array = it.get("jobs", [])
	if not jobs.is_empty() and c.job_id not in jobs:
		return "%s 无法使用%s" % [GameState.get_job(c.job_id).get("name", c.job_id), it.get("type_name", "")]
	return ""

func equipped(c: CKCharacter, slot: String) -> String:
	if c == null:
		return ""
	if slot == "weapon":
		return c.weapon_id
	return str(gear.get(c.id, {}).get(slot, ""))

func equip(cid: String, iid: String) -> Dictionary:
	var c: CKCharacter = GameState.characters.get(cid)
	var it := item(iid)
	if c == null or it.is_empty():
		return {"ok": false, "msg": "选择角色与装备"}
	if int(armory.get(iid, 0)) <= 0:
		return {"ok": false, "msg": "军械库中没有「%s」" % it.name}
	var why := can_equip(c, it)
	if why != "":
		return {"ok": false, "msg": why}
	var slot := str(it.slot)
	unequip(cid, slot)
	armory[iid] = int(armory[iid]) - 1
	if int(armory[iid]) <= 0:
		armory.erase(iid)
	if slot == "weapon":
		c.weapon_id = iid
	else:
		var g: Dictionary = gear.get(cid, {})
		g[slot] = iid
		gear[cid] = g
	c.recalc_hp()
	GameState.mark_dirty()
	world_changed.emit()
	return {"ok": true, "msg": "%s 装备「%s」" % [c.name, it.name]}

func unequip(cid: String, slot: String) -> void:
	var c: CKCharacter = GameState.characters.get(cid)
	if c == null:
		return
	var cur := equipped(c, slot)
	if cur == "":
		return
	if items.has(cur):
		armory[cur] = int(armory.get(cur, 0)) + 1
	if slot == "weapon":
		c.weapon_id = ""
	else:
		var g: Dictionary = gear.get(cid, {})
		g.erase(slot)
		gear[cid] = g
	c.recalc_hp()
	world_changed.emit()

## Stat bonus from world gear (weapon via c.weapon_id + armor/charm slots). Called from CKCharacter.derived_*.
func gear_bonus(c, stat: String) -> int:
	if c == null or items.is_empty():
		return 0
	var total := 0
	var ids: Array = []
	if items.has(str(c.weapon_id)):
		ids.append(str(c.weapon_id))
	var g: Dictionary = gear.get(str(c.id), {})
	for s in ["armor", "charm"]:
		if items.has(str(g.get(s, ""))):
			ids.append(str(g[s]))
	for iid in ids:
		total += int(items[iid].get("stats", {}).get(stat, 0))
	return total

func is_world_item(iid: String) -> bool:
	return items.has(iid)

func grant_gear_skills(c) -> void:
	if c == null:
		return
	var ids: Array = [str(c.weapon_id)]
	var g: Dictionary = gear.get(str(c.id), {})
	ids.append(str(g.get("armor", "")))
	ids.append(str(g.get("charm", "")))
	for iid in ids:
		var it: Dictionary = items.get(iid, {})
		var sk := str(it.get("skill", ""))
		if sk != "" and not GameState.get_skill(sk).is_empty() and sk not in c.skills:
			c.skills.append(sk)

# ── tavern ────────────────────────────────────────────
func _epoch() -> int:
	return days_total / int(rules.get("board_refresh_days", 30))

func city_recruits(city: String) -> Array:
	var n := node(city)
	var slots := int(n.get("tavern_slots", 0))
	if slots <= 0:
		return []
	var noble := rep_tier_index(rep_of(city)) >= 4
	if noble:
		slots += 1
	var rec: Dictionary = recruits.get(city, {})
	if rec.is_empty() or int(rec.get("epoch", -1)) != _epoch() or int(rec.get("slots", slots)) != slots:
		var lst: Array = []
		var nat: Dictionary = nations.get(str(n.nation), {})
		var r := RandomNumberGenerator.new()
		r.seed = hash("%s#%d" % [city, _epoch()])
		for i in slots:
			# v8.9 nation pools (CKBloodline): folk / noble / gated royal, wanderers, pretenders; 盟誓 seats the royal line
			var roll := CKBloodline.roll_recruit(str(n.nation), str(n.kind), r, {"city_rep": rep_of(city), "nation_rep": nation_rep(str(n.nation)), "slot": i})
			var c := CharacterFactory.make_tavern_candidate(r, roll)
			if r.randf() < 0.5:
				var jb: Array = nat.get("jobs", ["light_inf"])
				c.job_id = str(jb[r.randi() % jb.size()])
			if noble and i == slots - 1:
				c.rank = "baron"  # 盟誓：城中贵胄投效
			c.salary = 6 + c.rank_index() * 3 + c.level + CKBloodline.salary_premium(c)
			c.recalc_hp()
			lst.append(c.to_dict())
		rec = {"epoch": _epoch(), "list": lst, "slots": slots}
		recruits[city] = rec
	var out: Array = []
	for d in rec.list:
		out.append(CKCharacter.from_dict(d))
	return out

func hire_cost(c: CKCharacter) -> int:
	return 28 + c.rank_index() * 15 + CKBloodline.hire_premium(c, nation_of(pos))

func hire(city: String, idx: int) -> Dictionary:
	if city != pos:
		return {"ok": false, "msg": "须身在此城"}
	var lst := city_recruits(city)
	if idx < 0 or idx >= lst.size():
		return {"ok": false, "msg": "无此人"}
	var c: CKCharacter = lst[idx]
	var r := GameState.recruit(c, hire_cost(c))
	if r.ok:
		recruits[city].list.remove_at(idx)
		add_city_rep(city, 1)
		world_changed.emit()
	return r

# ── commissions ───────────────────────────────────────
func board(city: String) -> Array:
	_ensure_board(city)
	return boards.get(city, {}).get("offers", [])

func _ensure_board(city: String) -> void:
	var n := node(city)
	if n.is_empty() or str(n.kind) == "castle":
		return
	var b: Dictionary = boards.get(city, {})
	if not b.is_empty() and int(b.get("epoch", -1)) == _epoch():
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash("board:%s#%d" % [city, _epoch()])
	var size := board_size(city)
	var offers: Array = []
	var kinds: Array = ["deliver", "escort", "hunt", "clear", "defend", "gather", "scout"]
	for i in size:
		var tier := 1
		if i >= 2:
			tier = 2
		if i >= 4:
			tier = 3
		var q := _make_quest(city, str(kinds[r.randi() % kinds.size()]), tier, r)
		if not q.is_empty():
			offers.append(q)
	var sq: Dictionary = n.get("sig_quest", {})
	if not sq.is_empty() and not done_sig.has(str(sq.id)) and not _is_active(str(sq.id)):
		var q2 := _make_quest(city, str(sq.kind), 3, r, sq)
		if not q2.is_empty():
			offers.push_front(q2)
	# follow-up commissions carried over from the previous board survive the refresh
	for q3 in b.get("offers", []):
		if bool(q3.get("chain", false)):
			offers.push_front(q3)
	# Separate seed. The loop above is the v9.1 board draw and must stay byte-for-byte.
	_append_objective_offer(city, offers)
	boards[city] = {"epoch": _epoch(), "offers": offers}

func quest_kind_label(kind: String) -> String:
	if QUEST_KIND_ZH.has(kind):
		return str(QUEST_KIND_ZH[kind])
	var key := ""
	match kind:
		"siege_aid":
			key = "quest_siege_aid"
		"bounty":
			key = "quest_bounty"
		"rescue":
			key = "quest_rescue"
		"convoy":
			key = "quest_convoy"
		"intel_race":
			key = "quest_intel_race"
	if key == "":
		return kind
	return Locale.t(key)

func _arrives_in_battle(kind: String) -> bool:
	return kind == "hunt" or kind == "defend" or OBJECTIVE_KINDS.has(kind)

func _append_objective_offer(city: String, offers: Array) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("objboard:%s#%d" % [city, _epoch()])
	var kind := str(OBJECTIVE_KINDS[r.randi() % OBJECTIVE_KINDS.size()])
	var tier := 1 + int(r.randi() % 2)
	var q := _make_quest(city, kind, tier, r)
	if q.is_empty():
		return
	q.id = "wq_obj_%s_%d_%d" % [city, _epoch(), r.randi() % 100000]
	offers.append(q)

func _is_active(qid: String) -> bool:
	for q in active:
		if str(q.id) == qid:
			return true
	return false

func _near(city: String, min_h: int, max_h: int, r: RandomNumberGenerator, same_nation: bool = true) -> String:
	var seen := {city: 0}
	var fr: Array = [city]
	while not fr.is_empty():
		var x: String = fr.pop_front()
		if int(seen[x]) >= max_h:
			continue
		for rd in adj.get(x, []):
			var y := other_end(rd, x)
			if not seen.has(y):
				seen[y] = int(seen[x]) + 1
				fr.append(y)
	var cands: Array = []
	for k in seen.keys():
		var h := int(seen[k])
		if h < min_h or h > max_h or k == city or str(node(k).kind) == "castle":
			continue
		if same_nation and nation_of(k) != nation_of(city):
			continue
		cands.append(k)
	cands.sort()
	if cands.is_empty():
		return ""
	return str(cands[r.randi() % cands.size()])

func _make_quest(city: String, kind: String, tier: int, r: RandomNumberGenerator, sig: Dictionary = {}) -> Dictionary:
	var tpl: Dictionary = {}
	for t in data.get("commissions", []):
		if str(t.kind) == kind:
			tpl = t
	if tpl.is_empty():
		return {}
	var n := node(city)
	var nat: Dictionary = nations.get(str(n.nation), {})
	var q := {"id": "", "kind": kind, "issuer": city, "tier": tier, "state": "offer", "sig": not sig.is_empty()}
	var hops := 1
	var target := ""
	match kind:
		"deliver", "escort", "scout":
			target = _near(city, 1, 2 + (1 if tier >= 2 else 0), r, tier < 3)
			if target == "":
				return {}
			q.target = target
		"hunt", "defend", "siege_aid", "bounty", "rescue", "convoy", "intel_race":
			target = _near(city, 1, 2, r)
			if target == "":
				target = _near(city, 1, 3, r, false)
			if target == "":
				return {}
			q.target = target
		"clear":
			var rds: Array = []
			for rd in adj.get(city, []):
				if str(rd.kind) != "sea":
					rds.append(rd)
			var nb := _near(city, 1, 1, r, false)
			if nb != "":
				for rd2 in adj.get(nb, []):
					if str(rd2.kind) == "road":
						rds.append(rd2)
			if rds.is_empty():
				return {}
			var pick: Dictionary = rds[r.randi() % rds.size()]
			q.edge = [str(pick.a), str(pick.b)]
			q.target = str(pick.a) if str(pick.a) != city else str(pick.b)
		"gather":
			var dem: Array = n.get("demand", ["grain"])
			q.good = str(dem[r.randi() % dem.size()])
			q.qty = 8 + tier * 4 if q.good == "grain" else 3 + tier * 2
			q.target = city
	if q.has("target") and kind != "gather":
		var rt := route(city, str(q.target))
		hops = maxi(1, rt.get("path", [city, city]).size() - 1)
		q.route_days = int(rt.get("days", 2))
	else:
		q.route_days = 0
	var titles: Array = tpl.get("titles", ["委托"])
	var title := str(titles[r.randi() % titles.size()])
	var tname := str(node(str(q.get("target", city))).get("name", ""))
	var foes: Array = tpl.get("foe_names", ["匪徒"])
	var parcels: Array = tpl.get("parcels", ["包裹"])
	var clients: Array = tpl.get("clients", ["旅人"])
	q.parcel = str(parcels[r.randi() % parcels.size()])
	q.client = str(clients[r.randi() % clients.size()])
	q.foe_name = str(foes[r.randi() % foes.size()])
	var road_name := ""
	if q.has("edge"):
		road_name = "%s—%s道" % [node(q.edge[0]).get("name", ""), node(q.edge[1]).get("name", "")]
	title = title.replace("{target}", tname).replace("{parcel}", q.parcel).replace("{client}", q.client).replace("{foe_name}", q.foe_name)
	title = title.replace("{road}", road_name).replace("{good}", good_name(str(q.get("good", ""))))
	title = title.replace("{issuer}", str(n.get("name", "")))
	var desc := ""
	match kind:
		"deliver": desc = "把%s从%s送到%s。占用 2 格货舱，交付地点：%s。" % [q.parcel, n.name, tname, tname]
		"escort": desc = "护送%s前往%s。沿途伏击概率上升；若战败，委托失败。到达后在%s交付。" % [q.client, tname, tname]
		"hunt": desc = "%s藏身于%s一带。前往目标地点即触发战斗，得胜后回%s复命。" % [q.foe_name, tname, n.name]
		"clear": desc = "%s上盘踞着%s营地。行经此道即触发清剿战，得胜后回%s复命。" % [road_name, nat.get("name", ""), n.name]
		"defend": desc = "%s告急！在期限内赶到即开战，守住后在%s领赏。" % [tname, tname]
		"gather": desc = "%s急需%s ×%d。备齐货物后回%s交付（交付即消耗）。" % [n.name, good_name(q.good), int(q.qty), n.name]
		"scout": desc = "走一趟%s，探明当地虚实，回%s复命。抵达时同步当地市价情报。" % [tname, n.name]
	if OBJECTIVE_KINDS.has(kind):
		desc = _quest_brief(tpl, q, str(n.get("name", "")), tname, road_name)
		q.victory = str(OBJECTIVE_VICTORY.get(kind, ""))
	var base_silver := int(tpl.get("silver", 30))
	var mult := 1.0 + 0.3 * (hops - 1) + 0.45 * (tier - 1) + 0.15 * (world_tier() - 1)
	q.reward_silver = int(round(base_silver * mult / 5.0)) * 5
	q.reward_rep = int(tpl.get("rep", 5)) + (tier - 1) * 3
	q.req_rep = [0, 0, 10, 30][tier]
	q.battle = bool(tpl.get("battle", false))
	q.danger = clampi(tier + (1 if kind in ["defend", "clear", "siege_aid", "bounty"] else 0), 1, 4)
	var rushed := kind == "defend" or kind == "siege_aid"
	var budget := int(q.route_days) + 4 if rushed else int(q.route_days) * 2 + 8
	if kind == "gather":
		budget = 40
	q.days_budget = budget
	q.title = title
	q.desc = desc
	var prod: Array = n.get("produce", [])
	if tier >= 2 and not prod.is_empty():
		q.reward_good = str(prod[r.randi() % prod.size()])
		q.reward_qty = 2 * tier
	if not sig.is_empty():
		q.id = str(sig.id)
		q.title = "【名誉】" + str(sig.title)
		q.desc = str(sig.brief) + "\n" + desc
		q.req_rep = 30
		q.reward_silver = int(round(q.reward_silver * 1.8 / 5.0)) * 5 + 40
		q.reward_rep = 15
		q.unlock = "%s_sig2" % city
	else:
		q.id = "wq_%s_%d_%d" % [city, _epoch(), r.randi() % 100000]
	return q

func _quest_brief(tpl: Dictionary, q: Dictionary, issuer_name: String, target_name: String, road_name: String) -> String:
	var desc := str(tpl.get("brief", ""))
	desc = desc.replace("{target}", target_name).replace("{issuer}", issuer_name)
	desc = desc.replace("{parcel}", str(q.get("parcel", ""))).replace("{client}", str(q.get("client", "")))
	desc = desc.replace("{foe_name}", str(q.get("foe_name", ""))).replace("{road}", road_name)
	desc = desc.replace("{good}", good_name(str(q.get("good", ""))))
	return desc

func quest_req_nation(q: Dictionary) -> int:
	var st := nation_stance(nation_of(str(q.issuer)))
	if st == "hostile":
		return 10 if int(q.tier) <= 1 else 30
	if st == "wary" and int(q.tier) >= 2:
		return 10
	if int(q.tier) >= 3 and not bool(q.get("sig", false)):
		return 10
	return 0

func quest_locked_reason(q: Dictionary) -> String:
	if rep_of(str(q.issuer)) < int(q.get("req_rep", 0)):
		return "需本城声望「%s」（%d）" % [rep_tier_name(int(q.req_rep)), int(q.req_rep)]
	var rn := quest_req_nation(q)
	var nid := nation_of(str(q.issuer))
	if nation_rep(nid) < rn:
		return "需%s邦交「%s」（%d）" % [nations.get(nid, {}).get("name", ""), rep_tier_name(rn), rn]
	if active.size() >= int(rules.get("active_limit", 5)):
		return "同时最多接 %d 个委托" % int(rules.get("active_limit", 5))
	if str(q.kind) == "deliver" and cargo_used() + 2 > cargo_cap():
		return "货舱不足"
	return ""

func accept_quest(city: String, qid: String) -> Dictionary:
	if city != pos:
		return {"ok": false, "msg": "须在发布委托的城中接取"}
	var offers: Array = board(city)
	for i in offers.size():
		var q: Dictionary = offers[i]
		if str(q.id) != qid:
			continue
		var why := quest_locked_reason(q)
		if why != "":
			return {"ok": false, "msg": why}
		q.state = "active"
		q.accepted_day = days_total
		q.deadline = days_total + int(q.days_budget)
		offers.remove_at(i)
		active.append(q)
		_tlog("接下委托「%s」" % q.title)
		_check_gather_ready()
		GameState.mark_dirty()
		world_changed.emit()
		return {"ok": true, "msg": "接下委托「%s」——期限 %d 日" % [q.title, int(q.days_budget)], "quest": q}
	return {"ok": false, "msg": "委托已不在榜上"}

func quest_by_id(qid: String) -> Dictionary:
	for q in active:
		if str(q.id) == qid:
			return q
	return {}

func turn_in_city(q: Dictionary) -> String:
	var tpl_turn := "issuer"
	for t in data.get("commissions", []):
		if str(t.kind) == str(q.kind):
			tpl_turn = str(t.get("turn_in", "issuer"))
	return str(q.target) if tpl_turn == "target" else str(q.issuer)

func can_turn_in(q: Dictionary, city: String) -> bool:
	return str(q.get("state", "")) == "ready" and turn_in_city(q) == city

func _check_gather_ready() -> void:
	for q in active:
		if str(q.kind) == "gather" and str(q.state) in ["active", "ready"]:
			q.state = "ready" if have_good(str(q.good)) >= int(q.qty) else "active"

func turn_in(qid: String) -> Dictionary:
	var q := quest_by_id(qid)
	if q.is_empty():
		return {"ok": false, "msg": "无此委托"}
	_check_gather_ready()
	if not can_turn_in(q, pos):
		return {"ok": false, "msg": "需在%s交付（当前：%s）" % [node(turn_in_city(q)).get("name", ""), "目标未达成" if str(q.state) != "ready" else "地点不符"]}
	if str(q.kind) == "gather":
		_add_good(str(q.good), -int(q.qty))
	var silver := int(q.reward_silver)
	if bool(q.get("sig", false)) and rep_tier_index(rep_of(str(q.issuer))) >= 4:
		silver = int(round(silver * 1.2))
	GameState.silver += silver
	add_city_rep(str(q.issuer), int(q.reward_rep))
	if turn_in_city(q) != str(q.issuer):
		add_city_rep(turn_in_city(q), int(q.reward_rep) / 2)
	var extra := ""
	if q.has("reward_good"):
		_add_good(str(q.reward_good), int(q.reward_qty))
		extra = "，%s ×%d" % [good_name(str(q.reward_good)), int(q.reward_qty)]
	for c in GameState.roster():
		c.exp += 6 * int(q.tier)
		GameState.settle_exp(c)
	if bool(q.get("sig", false)):
		done_sig[str(q.id)] = true
		extra += "；解锁传奇装备「%s」" % items.get(str(q.get("unlock", "")), {}).get("name", "")
		GameState.add_lineage_event("灰旗完成%s名誉委托「%s」" % [node(str(q.issuer)).get("name", ""), q.title])
	q.state = "done"
	active.erase(q)
	var follow := _spawn_follow_up(q)
	if not follow.is_empty():
		extra += "；%s 有后续委托「%s」" % [node(str(follow.issuer)).get("name", ""), follow.title]
	stats_done[str(q.kind)] = int(stats_done.get(str(q.kind), 0)) + 1
	quest_log.push_front("%s · %s（+%d 银）" % [date_label(), q.title, silver])
	if quest_log.size() > 20:
		quest_log.resize(20)
	GameState.log_event("交付委托「%s」+%d 银%s" % [q.title, silver, extra])
	GameState.mark_dirty()
	world_changed.emit()
	return {"ok": true, "msg": "交付「%s」：+%d 银，声望 +%d%s" % [q.title, silver, int(q.reward_rep), extra]}

## 委托链：二阶以下普通委托完成后，交付城可能递来更难的后续（报酬 +25%，跨刷新保留）
func _spawn_follow_up(q: Dictionary) -> Dictionary:
	if str(q.get("scripted_chain", "")) != "":
		return _advance_scripted_chain(q)
	if bool(q.get("sig", false)) or int(q.tier) >= 3:
		return {}
	var r := RandomNumberGenerator.new()
	r.seed = hash("chain:%s" % str(q.id))
	if r.randf() > 0.45 and not bool(q.get("chain", false)):
		return {}
	var at := turn_in_city(q)
	if node(at).is_empty() or str(node(at).kind) == "castle":
		return {}
	var nq := _make_quest(at, str(CHAIN_NEXT.get(str(q.kind), "deliver")), int(q.tier) + 1, r)
	if nq.is_empty():
		return {}
	nq.id = "wq_chain_%s_%d" % [at, r.randi() % 100000]
	nq.title = "续·" + str(nq.title)
	nq.desc = "（承接「%s」）%s" % [q.title, nq.desc]
	nq.reward_silver = int(round(int(nq.reward_silver) * 1.25 / 5.0)) * 5
	nq.chain = true
	nq.chain_from = str(q.id)
	_ensure_board(at)
	boards[at].offers.push_front(nq)
	_tlog("%s 递来后续委托「%s」" % [node(at).get("name", ""), nq.title])
	return nq

# ── CMP-04 scripted chains and rival companies ─────────
func _init_rivals() -> void:
	rivals = []
	rival_thefts = []
	for row in data.get("rival_companies", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		rivals.append({
			"id": str(row.get("id", "")),
			"name": str(row.get("name", "")),
			"home": str(row.get("home", "")),
			"pos": str(row.get("home", "")),
			"stolen": 0,
			"price_mul": float(row.get("price_mul", 1.2)),
		})

func _restore_rivals(saved) -> void:
	_init_rivals()
	if typeof(saved) != TYPE_ARRAY:
		return
	var by_id := {}
	for row in saved:
		if typeof(row) == TYPE_DICTIONARY:
			by_id[str(row.get("id", ""))] = row
	for rv in rivals:
		if not by_id.has(str(rv.id)):
			continue
		var row: Dictionary = by_id[str(rv.id)]
		rv.pos = str(row.get("pos", rv.pos))
		rv.stolen = int(row.get("stolen", 0))

func rival_price_mul(city: String) -> float:
	if not rivals_enabled:
		return 1.0
	var mul := 1.0
	for rv in rivals:
		if str(rv.get("pos", "")) == city:
			mul = maxf(mul, float(rv.get("price_mul", 1.2)))
	return mul

func tick_rivals() -> Dictionary:
	## One beat: each company steals a posted offer where it stands, or steps toward one.
	## Uses no World.rng, so the century sim stays put when rivals_enabled is false.
	if not rivals_enabled:
		return {"ok": true, "stolen": 0, "total": _rival_stolen_total()}
	var stolen_now := 0
	for rv in rivals:
		if _rival_steal(rv):
			stolen_now += 1
		else:
			_rival_step(rv)
	return {"ok": true, "stolen": stolen_now, "total": _rival_stolen_total()}

func _rival_stolen_total() -> int:
	var n := 0
	for rv in rivals:
		n += int(rv.get("stolen", 0))
	return n

func _rival_steal(rv: Dictionary) -> bool:
	var city := str(rv.get("pos", ""))
	var idx := _stealable_index(city)
	if idx < 0:
		return false
	var offers: Array = boards[city].offers
	var q: Dictionary = offers[idx]
	offers.remove_at(idx)
	rv.stolen = int(rv.get("stolen", 0)) + 1
	rival_thefts.append({"by": str(rv.id), "city": city, "quest": str(q.get("id", "")), "title": str(q.get("title", ""))})
	_tlog("%s截走了%s的委托「%s」" % [rv.get("name", ""), node(city).get("name", city), q.get("title", "")])
	return true

func _stealable_index(city: String) -> int:
	var offers: Array = boards.get(city, {}).get("offers", [])
	for i in offers.size():
		var q: Dictionary = offers[i]
		if bool(q.get("sig", false)) or str(q.get("scripted_chain", "")) != "":
			continue
		return i
	return -1

func _rival_step(rv: Dictionary) -> void:
	var here := str(rv.get("pos", ""))
	if here == "" or not nodes.has(here):
		return
	var best := ""
	var best_len := 9999
	var cities: Array = boards.keys()
	cities.sort()
	for c in cities:
		if str(c) == here or _stealable_index(str(c)) < 0:
			continue
		var path: Array = route(here, str(c)).get("path", [])
		if path.size() >= 2 and path.size() < best_len:
			best_len = path.size()
			best = str(path[1])
	if best != "":
		rv.pos = best

func rival_here() -> Dictionary:
	for rv in rivals:
		if str(rv.get("pos", "")) == pos:
			return rv
	return {}

func rival_clash() -> Dictionary:
	## Opt-in encounter. Travel does not start this by itself.
	var rv := rival_here()
	if rv.is_empty():
		return {}
	return start_encounter("road", {"node": pos, "from": pos, "event": "rival_%s" % str(rv.id)})

func scripted_chains() -> Array:
	return data.get("contract_chains", [])

func start_scripted_chain(chain_id: String) -> Dictionary:
	if str(chain_progress.get(chain_id, {}).get("status", "")) == "active":
		return {"ok": false, "msg": "这条委托链还没走完"}
	var chain := _scripted_chain(chain_id)
	if chain.is_empty():
		return {"ok": false, "msg": "没有这条委托链"}
	var steps: Array = chain.get("steps", [])
	if steps.is_empty():
		return {"ok": false, "msg": "委托链没有步骤"}
	chain_progress[chain_id] = {"step": 0, "status": "active"}
	var q := _quest_from_chain_step(chain, 0)
	_post_chain_offer(q)
	return {"ok": true, "msg": "接下委托链「%s」" % str(chain.get("title", "")), "quest": q}

func chain_status(chain_id: String) -> Dictionary:
	var prog: Dictionary = chain_progress.get(chain_id, {})
	var status := str(prog.get("status", "idle"))
	var out := {"id": chain_id, "status": status, "step": int(prog.get("step", 0))}
	if status != "active":
		return out
	var live := _chain_quest(chain_id)
	if live.is_empty():
		return out
	out["quest_id"] = str(live.get("id", ""))
	out["issuer"] = str(live.get("issuer", ""))
	out["state"] = str(live.get("state", ""))
	out["on_board"] = str(live.get("state", "")) == "offer"
	return out

func chain_done(chain_id: String) -> bool:
	return str(chain_progress.get(chain_id, {}).get("status", "")) == "done"

func _scripted_chain(chain_id: String) -> Dictionary:
	for row in data.get("contract_chains", []):
		if str(row.get("id", "")) == chain_id:
			return row
	return {}

func _quest_from_chain_step(chain: Dictionary, step_idx: int) -> Dictionary:
	var steps: Array = chain.get("steps", [])
	var step: Dictionary = steps[step_idx]
	var issuer := str(step.get("issuer", ""))
	var target := str(step.get("target", issuer))
	return {
		"id": "chain_%s_%d" % [str(chain.get("id", "")), step_idx],
		"kind": str(step.get("kind", "deliver")),
		"issuer": issuer,
		"target": target,
		"tier": 1,
		"state": "offer",
		"sig": false,
		"title": str(step.get("title", "")),
		"desc": str(step.get("brief", "")),
		"reward_silver": 40 + step_idx * 10,
		"reward_rep": 4,
		"req_rep": 0,
		"battle": false,
		"danger": 1,
		"days_budget": 40,
		"route_days": 2,
		"chain": true,
		"scripted_chain": str(chain.get("id", "")),
		"scripted_step": step_idx,
	}

func _post_chain_offer(q: Dictionary) -> void:
	var issuer := str(q.get("issuer", ""))
	_ensure_board(issuer)
	if not boards.has(issuer):
		boards[issuer] = {"epoch": _epoch(), "offers": []}
	boards[issuer].offers.push_front(q)

func _chain_quest(chain_id: String) -> Dictionary:
	for q in active:
		if str(q.get("scripted_chain", "")) == chain_id:
			return q
	for city in boards.keys():
		for q in boards[city].get("offers", []):
			if str(q.get("scripted_chain", "")) == chain_id:
				return q
	return {}

func _advance_scripted_chain(q: Dictionary) -> Dictionary:
	var chain_id := str(q.get("scripted_chain", ""))
	var chain := _scripted_chain(chain_id)
	var steps: Array = chain.get("steps", [])
	var nxt := int(q.get("scripted_step", 0)) + 1
	if chain.is_empty() or nxt >= steps.size():
		chain_progress[chain_id] = {"step": nxt, "status": "done"}
		_tlog("委托链「%s」走完" % str(chain.get("title", chain_id)))
		return {}
	chain_progress[chain_id] = {"step": nxt, "status": "active"}
	var nq := _quest_from_chain_step(chain, nxt)
	_post_chain_offer(nq)
	_tlog("委托链续上「%s」" % str(nq.title))
	return nq

func abandon(qid: String) -> Dictionary:
	var q := quest_by_id(qid)
	if q.is_empty():
		return {"ok": false, "msg": "无此委托"}
	active.erase(q)
	add_city_rep(str(q.issuer), -4)
	world_changed.emit()
	return {"ok": true, "msg": "放弃委托「%s」（声望 -4）" % q.title}

func _expire_quests() -> void:
	for q in active.duplicate():
		if str(q.state) == "active" and days_total > int(q.get("deadline", 999999)):
			active.erase(q)
			add_city_rep(str(q.issuer), -5)
			_tlog("委托「%s」逾期失败（声望 -5）" % q.title)
			quest_log.push_front("%s · 失败：%s" % [date_label(), q.title])

## Fight an objective at the party's current location (hunt / defend target reached earlier, or retry after a defeat)
func quest_engage(qid: String) -> Dictionary:
	var q := quest_by_id(qid)
	if q.is_empty() or str(q.state) != "active" or not _arrives_in_battle(str(q.kind)) or str(q.target) != pos:
		return {}
	return start_encounter("quest", {"quest": qid, "node": pos, "from": pos})

func quest_markers() -> Dictionary:
	## node id -> [{"kind": "objective"|"turnin", "quest": q}] for map overlays
	var out := {}
	for q in active:
		var t := ""
		var k := "objective"
		if str(q.state) == "ready":
			t = turn_in_city(q)
			k = "turnin"
		elif str(q.kind) == "gather":
			continue
		else:
			t = str(q.target)
		if not out.has(t):
			out[t] = []
		out[t].append({"kind": k, "quest": q})
	return out

func _quest_edge_trigger(a: String, b: String) -> Dictionary:
	for q in active:
		if str(q.kind) == "clear" and str(q.state) == "active" and q.has("edge"):
			var e: Array = q.edge
			if (str(e[0]) == a and str(e[1]) == b) or (str(e[0]) == b and str(e[1]) == a):
				return start_encounter("quest", {"quest": str(q.id), "node": b, "from": a})
	return {}

# ── road events ───────────────────────────────────────
func _roll_event(r: Dictionary, a: String, b: String) -> Dictionary:
	if not events_enabled:
		return {}
	var danger := int(r.get("danger", 1))
	var chance := float(rules.get("event_base_chance", 0.22)) + float(rules.get("event_danger_chance", 0.12)) * danger
	for q in active:
		if str(q.kind) == "escort" and str(q.state) == "active":
			chance += 0.15
	if rng.randf() > chance:
		return {}
	var biome := str(node(b).get("biome", "plain"))
	var nid := nation_of(b)
	var pool: Array = []
	var total := 0.0
	for ev in data.get("events", []):
		if str(r.kind) not in ev.get("kinds", []):
			continue
		if danger < int(ev.get("min_danger", 0)):
			continue
		if ev.has("biomes") and biome not in ev.biomes:
			continue
		if ev.has("nations") and nid not in ev.nations:
			continue
		var w := float(ev.get("weight", 1))
		if str(ev.id) == "ambush":
			w *= 0.6 + 0.5 * danger
		pool.append([ev, w])
		total += w
	if pool.is_empty():
		return {}
	var x := rng.randf() * total
	var pick: Dictionary = pool[0][0]
	for p in pool:
		x -= float(p[1])
		if x <= 0:
			pick = p[0]
			break
	return _instantiate_event(pick, r, a, b)

func make_event(ev_id: String, a: String = "", b: String = "") -> Dictionary:
	## deterministic event injection (tests / scripted beats)
	for ev in data.get("events", []):
		if str(ev.id) == ev_id:
			var r := road_between(a, b) if a != "" else {"danger": 1, "kind": "road"}
			return _instantiate_event(ev, r, a if a != "" else pos, b if b != "" else pos)
	return {}

func _instantiate_event(ev: Dictionary, r: Dictionary, a: String, b: String) -> Dictionary:
	var nid := nation_of(b)
	var nat: Dictionary = nations.get(nid, {})
	var danger := int(r.get("danger", 1))
	var toll := 8 + 6 * danger
	var gpool: Array = node(a).get("produce", ["grain"])
	var g := str(gpool[rng.randi() % gpool.size()])
	var weather := str(rules.get("weather", {}).get(str(node(b).get("biome", "")), "暴雨"))
	var tipd := _make_tip()
	var tip := str(tipd.text)
	var omens := ["流星划过陆桥", "极光垂到地平线", "一颗新星出现在东方"]
	var foe_names := {"bandit": "劫道匪帮", "escort": "劫镖悍匪", "shadow": "朔影刺客", "snow": "雪原马贼"}
	var foes: Array = nat.get("foes", ["bandit"])
	var foe := str(foe_names.get(str(foes[0]), "%s匪徒" % nat.get("name", "")))
	var hire := 30 + 10 * world_tier()
	var text := str(ev.text).replace("{foe}", foe).replace("{toll}", str(toll)).replace("{good}", good_name(g)).replace("{weather}", weather)
	text = text.replace("{nation}", str(nat.get("name", ""))).replace("{tip}", tip).replace("{omen}", omens[rng.randi() % omens.size()])
	text = text.replace("{dest}", str(node(str(travel.get("dest", b))).get("name", "")))
	var opts: Array = []
	for o in ev.options:
		opts.append({"label": str(o.label).replace("{hire}", str(hire)), "fx": o.fx})
	pending_event = {"id": str(ev.id), "title": str(ev.title), "text": text, "options": opts, "a": a, "b": b,
		"ctx": {"toll": toll, "good": g, "tip": tipd, "hire": hire, "danger": danger}}
	_tlog("路遇：%s" % ev.title)
	return pending_event

func _make_tip() -> Dictionary:
	var keys := goods.keys()
	keys.sort()
	var g := str(keys[rng.randi() % keys.size()])
	var best := ""
	var bp := 0
	var cities := nodes.keys()
	cities.sort()
	for c in cities:
		var p := price(c, g, "sell")
		if p > bp:
			bp = p
			best = c
	return {"text": "%s的%s能卖到 %d 银一份。" % [node(best).get("name", ""), good_name(g), bp], "city": best}

func choose_event(idx: int) -> Dictionary:
	if pending_event.is_empty():
		return {"ok": false, "msg": "没有待处理事件"}
	var ev := pending_event
	var opts: Array = ev.options
	if idx < 0 or idx >= opts.size():
		return {"ok": false, "msg": "无效选项"}
	var fx: Dictionary = opts[idx].fx
	var ctx: Dictionary = ev.ctx
	var lines: Array = []
	pending_event = {}
	for k in fx.keys():
		var v = fx[k]
		match k:
			"silver":
				var amt := -int(ctx.toll) if str(v) == "-toll" else int(v)
				GameState.silver = maxi(0, GameState.silver + amt)
				lines.append("银 %+d" % amt)
			"food":
				GameState.food = maxi(0, GameState.food + int(v))
				lines.append("粮 %+d" % int(v))
			"herb":
				GameState.herb += int(v)
				lines.append("药材 +%d" % int(v))
			"morale":
				GameState.morale = clampi(GameState.morale + int(v), 0, 100)
				lines.append("士气 %+d" % int(v))
			"days":
				advance_days(int(v))
				lines.append("耽搁 %d 日" % int(v))
			"heal":
				for c in GameState.roster():
					c.hp = mini(c.max_hp, c.hp + int(c.max_hp * float(v)))
					c.injured = false
				lines.append("全员疗伤")
			"rep_nation":
				add_nation_rep(nation_of(str(ev.b)), int(v))
				lines.append("%s声望 %+d" % [nations.get(nation_of(str(ev.b)), {}).get("name", ""), int(v)])
			"rep_dest":
				add_city_rep(str(ev.b), int(v))
				lines.append("%s声望 +%d" % [node(str(ev.b)).get("name", ""), int(v)])
			"lose_cargo":
				var lost := 0
				for g in cargo.keys():
					var q := int(ceil(int(cargo[g]) * float(v)))
					cargo[g] = int(cargo[g]) - q
					lost += q
				for g2 in cargo.keys().duplicate():
					if int(cargo[g2]) <= 0:
						cargo.erase(g2)
				lines.append("损失货物 %d 份" % lost)
			"gain_good":
				_add_good(str(ctx.good), int(v))
				lines.append("%s +%d" % [good_name(str(ctx.good)), int(v)])
			"buy_deal":
				var g3 := str(ctx.good)
				var p := maxi(1, int(round(price(str(ev.a), g3, "buy") * float(v))))
				var qn := mini(5, maxi(0, cargo_cap() - cargo_used()))
				if str(goods.get(g3, {}).get("store", "")) != "":
					qn = 5
				qn = mini(qn, GameState.silver / p)
				if qn > 0:
					GameState.silver -= p * qn
					_add_good(g3, qn)
					lines.append("以 %d 银/份购入%s ×%d" % [p, good_name(g3), qn])
				else:
					lines.append("钱或货舱不够，只能作罢")
			"patrol":
				if nation_rep(nation_of(str(ev.b))) >= 10:
					lines.append("巡逻队认得灰旗，放行并透露了消息")
					_apply_tip(_make_tip())
				else:
					var t2 := 10 + toll_for(nation_of(str(ev.b)))
					GameState.silver = maxi(0, GameState.silver - t2)
					lines.append("文书不全，罚银 %d" % t2)
			"recruit":
				var cost := int(ctx.hire)
				if GameState.silver >= cost:
					var road_roll := CKBloodline.roll_recruit(nation_of(str(ev.b)), "road", rng, {"folk_only": true})
					var c2 := CharacterFactory.make_tavern_candidate(rng, road_roll)
					var rr := GameState.recruit(c2, cost)
					lines.append("%s 加入灰旗（-%d 银）" % [c2.name, cost] if rr.ok else str(rr.msg))
				else:
					lines.append("银两不够，佣兵摇头离去")
			"tip":
				_apply_tip(ctx.tip)
				lines.append("记下了市价情报")
			"fair":
				var dst := str(travel.get("dest", ev.b))
				fairs[dst] = days_total + 10
				lines.append("%s集会：卖价 +15%%（10 日）" % node(dst).get("name", ""))
			"risk":
				if rng.randf() < float(v):
					lines.append("商队引来了伏兵！")
					fx = {"battle": "ambush"}
			"sp":
				GameState.add_skill_point(int(v))
				lines.append("战技点 %+d" % int(v))
			"iron":
				GameState.iron = maxi(0, GameState.iron + int(v))
				lines.append("铁 %+d" % int(v))
			"flag":
				road_flags[str(v)] = true
				lines.append("记下了旗标")
	if fx.has("battle"):
		var enc := start_encounter("road", {"node": str(ev.b), "from": str(ev.a), "event": str(ev.id), "rep_win": int(fx.get("rep_nation_win", 0))})
		return {"ok": true, "msg": "，".join(lines), "encounter": enc}
	var out := {"ok": true, "msg": "，".join(lines) if not lines.is_empty() else "无事发生"}
	if travel.has("pending_arrive"):
		var info := _arrive_leg(str(travel.pending_arrive))
		out.merge(info)
	world_changed.emit()
	return out

func _apply_tip(tip: Dictionary) -> void:
	if nodes.has(str(tip.get("city", ""))):
		intel[str(tip.city)] = days_total
	tips.push_front(str(tip.get("text", "")))
	if tips.size() > 8:
		tips.resize(8)

# ── encounters → SRPG battle ──────────────────────────
func start_encounter(kind: String, ctx: Dictionary) -> Dictionary:
	var at := str(ctx.get("node", pos))
	var n := node(at)
	var nid := str(n.get("nation", "ashbanner"))
	var biome := str(n.get("biome", "plain"))
	var q := quest_by_id(str(ctx.get("quest", "")))
	var danger := int(q.get("danger", 0)) if not q.is_empty() else int(road_between(str(ctx.get("from", at)), at).get("danger", 1))
	danger = clampi(danger, 1, 4)
	var pool: Array = _biome_maps.get(biome, [])
	if pool.is_empty():
		pool = _biome_maps.get("plain", ["ch1_hill"])
	_enc_seq += 1
	var base_id := str(pool[absi(hash(at) + _enc_seq) % pool.size()])
	var base: Dictionary = BattleMaps.get_map(base_id).duplicate(true)
	var foes: Array = nations.get(nid, {}).get("foes", ["bandit"])
	var row: Array = data.get("foe_templates", {}).get(str(foes[_enc_seq % foes.size()]), ["bandit_weak", "bandit", "bandit_archer", "bandit_chief"])
	var spots: Array = base.get("enemy_spots", [])
	var count := clampi(2 + danger + (world_tier() - 1) / 2, 3, spots.size())
	var tmpl: Array = []
	for i in count:
		if i == 0 and (danger >= 3 or (not q.is_empty() and bool(q.get("sig", false)))):
			tmpl.append(row[3])
		elif i % 3 == 2:
			tmpl.append(row[2])
		elif danger <= 1 and i % 2 == 1:
			tmpl.append(row[0])
		else:
			tmpl.append(row[1])
	base.enemy_templates = tmpl
	base.enemy_spots = spots.slice(0, count)
	if not q.is_empty():
		_stamp_objective(base, q, spots)
	var label := ""
	if not q.is_empty():
		label = str(q.title)
	else:
		label = "%s·遭遇战" % n.get("name", "")
	base.name = label
	base.tutorial_militia = false
	var kw := str(data.get("biome_keyword", {}).get(biome, "plain"))
	var mid := "wenc_%s_%d" % [kw, _enc_seq]
	BattleMaps.register_map(mid, base)
	encounter = {"id": mid, "kind": kind, "node": at, "from": str(ctx.get("from", at)), "quest": str(ctx.get("quest", "")),
		"label": label, "base": base_id, "nation": nid, "danger": danger, "event": str(ctx.get("event", "")), "rep_win": int(ctx.get("rep_win", 0)),
		"map": base}
	_tlog("遭遇战：%s" % label)
	world_changed.emit()
	return encounter

func _stamp_objective(base: Dictionary, q: Dictionary, full_spots: Array) -> void:
	var kind := str(q.get("kind", ""))
	if not OBJECTIVE_VICTORY.has(kind):
		return
	var players: Array = base.get("player_spots", [])
	var enemies: Array = base.get("enemy_spots", [])
	if players.is_empty():
		return
	var home: Array = players[0]
	var width := int(base.get("w", 10))
	var height := int(base.get("h", 8))
	var far: Array = [mini(int(home[0]) + 4, width - 1), int(home[1])]
	if not enemies.is_empty():
		far = enemies[0]
	var blocked: Array = []
	for s in players:
		blocked.append(s)
	for s in enemies:
		blocked.append(s)
	match kind:
		"siege_aid":
			base.objective = {"type": "defend", "tiles": [[int(home[0]), int(home[1])]], "turns": 3}
			base.failure = {"turn_limit": 6}
			var wave: Array = far
			if full_spots.size() > enemies.size():
				wave = full_spots[enemies.size()]
			var wave_tmpl := "bandit"
			var templates: Array = base.get("enemy_templates", [])
			if not templates.is_empty():
				wave_tmpl = str(templates[0])
			base.reinforcements = [{
				"id": "siege_wave",
				"turn": 2,
				"team": "enemy",
				"spots": [[int(wave[0]), int(wave[1])]],
				"templates": [wave_tmpl],
				"tags": [""],
			}]
		"bounty":
			base.objective = {"type": "boss", "unit_tag": "mark"}
			var tags: Array = []
			for i in base.get("enemy_templates", []).size():
				tags.append("mark" if i == 0 else "")
			base.enemy_tags = tags
		"rescue":
			var spot := _open_spot(home, far, blocked, width, height)
			base.npcs = [{"name": str(q.get("client", "")), "tag": "captive", "spot": spot, "team": "ally"}]
			base.objective = {"type": "protect", "unit_tag": "captive"}
			base.failure = {"turn_limit": 12}
		"convoy":
			var spot2 := _open_spot(home, far, blocked, width, height)
			var exit_tile: Array = spot2
			if not enemies.is_empty():
				exit_tile = [int(enemies[enemies.size() - 1][0]), int(enemies[enemies.size() - 1][1])]
			if int(exit_tile[0]) == int(spot2[0]) and int(exit_tile[1]) == int(spot2[1]):
				exit_tile = [int(far[0]), int(far[1])]
			base.npcs = [{"name": str(q.get("client", "")), "tag": "wagon", "spot": spot2, "team": "player"}]
			base.objective = {"type": "escort", "npc": "wagon", "exit_tile": exit_tile}
			base.failure = {"turn_limit": 12}
		"intel_race":
			var tile := _mid_tile(home, far, players, enemies, width, height)
			base.objective = {"type": "seize", "tile": tile}
			base.failure = {"turn_limit": 10}

func _spot_taken(spots: Array, x: int, y: int) -> bool:
	for s in spots:
		if typeof(s) != TYPE_ARRAY or s.size() < 2:
			continue
		if int(s[0]) == x and int(s[1]) == y:
			return true
	return false

func _open_spot(origin: Array, toward: Array, blocked: Array, width: int, height: int) -> Array:
	var ox := int(origin[0])
	var oy := int(origin[1])
	var sx := signi(int(toward[0]) - ox)
	var sy := signi(int(toward[1]) - oy)
	var cands: Array = []
	if sx != 0:
		cands.append([ox + sx, oy])
	if sy != 0:
		cands.append([ox, oy + sy])
	cands.append([ox + sx, oy + sy])
	cands.append([ox + 1, oy])
	cands.append([ox - 1, oy])
	cands.append([ox, oy + 1])
	cands.append([ox, oy - 1])
	for c in cands:
		var x := int(c[0])
		var y := int(c[1])
		if x < 0 or y < 0 or x >= width or y >= height:
			continue
		if _spot_taken(blocked, x, y):
			continue
		return [x, y]
	return [clampi(ox, 0, width - 1), clampi(oy, 0, height - 1)]

func _mid_tile(home: Array, far: Array, players: Array, enemies: Array, width: int, height: int) -> Array:
	var x := clampi((int(home[0]) + int(far[0])) / 2, 0, width - 1)
	var y := clampi((int(home[1]) + int(far[1])) / 2, 0, height - 1)
	var sx := signi(int(far[0]) - int(home[0]))
	var sy := signi(int(far[1]) - int(home[1]))
	if sx == 0 and sy == 0:
		sx = 1
	for _i in 8:
		if not _spot_taken(players, x, y) and not _spot_taken(enemies, x, y):
			return [x, y]
		var nx := clampi(x + sx, 0, width - 1)
		var ny := clampi(y + sy, 0, height - 1)
		if nx == x and ny == y:
			break
		x = nx
		y = ny
	return [x, y]

func ensure_encounter_map() -> void:
	## after a load, the generated map must be re-registered before the battle scene reads it
	if not encounter.is_empty() and encounter.has("map"):
		BattleMaps.register_map(str(encounter.id), encounter.map)

func launch_encounter(tree: SceneTree) -> void:
	if encounter.is_empty():
		return
	ensure_encounter_map()
	GameState.set_meta("battle_map", str(encounter.id))
	GameState.set_meta("battle_return", ATLAS_SCENE)
	GameState.set_meta("world_encounter", true)
	if GameState.has_meta("active_quest_id"):
		GameState.remove_meta("active_quest_id")
	tree.change_scene_to_file("res://scenes/battle/battle.tscn")

## Called by battle_controller._finish when GameState has meta "world_encounter".
func on_battle_end(win: bool) -> Dictionary:
	if GameState.has_meta("world_encounter"):
		GameState.remove_meta("world_encounter")
	if encounter.is_empty():
		return {}
	var enc := encounter
	encounter = {}
	var msg := ""
	var q := quest_by_id(str(enc.quest))
	if win:
		var loot := 10 + 8 * int(enc.danger)
		GameState.silver += loot
		var nat: Dictionary = nations.get(str(enc.nation), {})
		var mat := str(nat.get("mat", "iron"))
		var mq := 1 + int(enc.danger) / 2
		if str(goods.get(mat, {}).get("store", "")) != "" or cargo_used() + mq <= cargo_cap():
			_add_good(mat, mq)
		msg = "得胜：缴获 %d 银、%s ×%d" % [loot, good_name(mat), mq]
		if int(enc.get("rep_win", 0)) > 0:
			add_nation_rep(str(enc.nation), int(enc.rep_win))
		if not q.is_empty():
			q.state = "ready"
			q.battle_won = true
			msg += "；委托「%s」目标达成" % q.title
		add_city_rep(str(enc.node), 2)
		if travel.has("pending_arrive"):
			var info := _arrive_leg(str(travel.pending_arrive))
			if not info.get("encounter", {}).is_empty():
				msg += "；前方又有战事"
	else:
		# retreat to where the fight started; lose some cargo and morale
		pos = str(enc.get("from", pos)) if nodes.has(str(enc.get("from", ""))) else pos
		travel = {}
		GameState.morale = maxi(0, GameState.morale - 5)
		for g in cargo.keys().duplicate():
			cargo[g] = int(cargo[g]) * 3 / 4
			if int(cargo[g]) <= 0:
				cargo.erase(g)
		msg = "败退至%s：士气 -5，货物折损四分之一" % node(pos).get("name", "")
		if not q.is_empty() and (str(q.kind) == "escort" or str(q.kind) == "rescue" or str(q.kind) == "convoy"):
			active.erase(q)
			add_city_rep(str(q.issuer), -6)
			if str(q.kind) == "escort":
				msg += "；护送委托失败"
			else:
				msg += Locale.t("quest_objective_failed")
	_tlog(msg)
	GameState.mark_dirty()
	world_changed.emit()
	return {"ok": true, "msg": msg, "win": win}

# ── campaign integration ──────────────────────────────
func mainline_chapter() -> int:
	for i in range(0, 235):
		var unlocked := i == 0 or GameState.flag("chapter%d_done" % (i - 1))
		if unlocked and not GameState.flag("chapter%d_done" % i):
			return i
	return 234

func chapter_volume(ch: int) -> int:
	if ch == 0:
		return 0
	if ch <= 15:
		return 1
	if ch <= 21:
		return 2
	return 3 + (ch - 22) / 6

func mainline_marker() -> Dictionary:
	var ch := mainline_chapter()
	var vn: Array = data.get("volume_nation", ["ashbanner"])
	var nid := str(vn[chapter_volume(ch) % vn.size()])
	var cands: Array = []
	for n in nodes_in(nid):
		if str(n.kind) != "castle":
			cands.append(str(n.id))
	cands.sort()
	var at := str(cands[ch % cands.size()]) if not cands.is_empty() else "hq"
	var path := "res://scenes/story/chapter%d.tscn" % ch
	return {"chapter": ch, "node": at, "path": path, "label": "主线 · 第 %d 章" % ch, "exists": ResourceLoader.exists(path)}

# ── misc ──────────────────────────────────────────────
func _tlog(t: String) -> void:
	travel_log.push_front("[%s] %s" % [date_label(), t])
	if travel_log.size() > 40:
		travel_log.resize(40)

func summary_counts() -> Dictionary:
	var sig := 0
	for it in items.values():
		if it.has("signature"):
			sig += 1
	var sq := 0
	for n in nodes.values():
		if n.has("sig_quest"):
			sq += 1
	return {"nodes": nodes.size(), "roads": data.get("roads", []).size(), "items": items.size(), "signature": sig,
		"sig_quests": sq, "goods": goods.size(), "events": data.get("events", []).size(), "nations": nations.size()}
