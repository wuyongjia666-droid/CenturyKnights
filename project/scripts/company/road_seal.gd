extends RefCounted
class_name CKRoadSeal
## Winter seal on dangerous land roads, and the detour / wait / force choices
## around them. Pathfinding stays beside World.route so the atlas page can
## offer a real alternate without rewriting the march autoload.

const WINDOW_DAYS := 8
const SEAL_DANGER := 3
const FORCE_MORALE := 6
## U+00D7. The map draws its own cross; this mark only tags the sealed hop in
## path text, and it has to be a glyph already in the Noto CJK subset.
const MARK := "×"

static func seal_active() -> bool:
	return Calendar.season_id() == "winter" and World.day <= WINDOW_DAYS

static func days_until_clear() -> int:
	if not seal_active():
		return 0
	return WINDOW_DAYS + 1 - World.day

static func edge_key(a: String, b: String) -> String:
	if a <= b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]

static func open_key(a: String, b: String) -> String:
	return "seal_open:%d-%02d:%s" % [Calendar.year, Calendar.month, edge_key(a, b)]

static func is_open(a: String, b: String) -> bool:
	return bool(World.road_flags.get(open_key(a, b), false))

static func is_sealed(a: String, b: String) -> bool:
	if not seal_active() or is_open(a, b):
		return false
	var road := World.road_between(a, b)
	if road.is_empty():
		return false
	if str(road.get("kind", "road")) == "sea":
		return false
	return int(road.get("danger", 1)) >= SEAL_DANGER

static func view_has_seal(nation: String) -> bool:
	if nation == "" or not seal_active():
		return false
	for road in World.data.get("roads", []):
		var a := str(road.get("a", ""))
		var b := str(road.get("b", ""))
		if World.nation_of(a) != nation or World.nation_of(b) != nation:
			continue
		if is_sealed(a, b):
			return true
	return false

static func sealed_count() -> int:
	var seen := {}
	var n := 0
	for road in World.data.get("roads", []):
		var a := str(road.get("a", ""))
		var b := str(road.get("b", ""))
		var key := edge_key(a, b)
		if seen.has(key):
			continue
		seen[key] = true
		if is_sealed(a, b):
			n += 1
	return n

static func path_text(path: Array) -> String:
	var bits: Array = []
	for i in path.size():
		var id := str(path[i])
		var name := str(World.node(id).get("name", id))
		if i > 0 and is_sealed(str(path[i - 1]), id):
			bits.append("%s %s" % [MARK, name])
		else:
			bits.append(name)
	return " › ".join(bits)

static func food_for(days: int) -> int:
	return World.food_per_day() * maxi(0, days)

## Shortest path that refuses sealed edges. Days are the sum of road days
## (the same number advance_days will consume), not the sea-weighted search cost.
static func route_around(from_id: String, to_id: String) -> Dictionary:
	if not World.nodes.has(from_id) or not World.nodes.has(to_id):
		return {}
	if from_id == to_id:
		return {"path": [from_id], "days": 0, "legs": []}
	var dist := {from_id: 0}
	var prev := {}
	var open: Array = [from_id]
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if int(dist[open[i]]) < int(dist[open[best]]):
				best = i
		var cur: String = str(open[best])
		open.remove_at(best)
		if cur == to_id:
			break
		for road in World.roads_from(cur):
			var nxt := World.other_end(road, cur)
			if is_sealed(cur, nxt):
				continue
			var step := int(road.get("days", 1)) + (2 if str(road.get("kind", "")) == "sea" else 0)
			var nd := int(dist[cur]) + step
			if not dist.has(nxt) or nd < int(dist[nxt]):
				dist[nxt] = nd
				prev[nxt] = cur
				if nxt not in open:
					open.append(nxt)
	if not dist.has(to_id):
		return {}
	var path: Array = [to_id]
	while str(path[0]) != from_id:
		path.push_front(prev[path[0]])
	var legs: Array = []
	var days := 0
	for i in range(path.size() - 1):
		var road := World.road_between(str(path[i]), str(path[i + 1]))
		legs.append(road)
		days += int(road.get("days", 1))
	return {"path": path, "days": days, "legs": legs}

static func compare(to_id: String) -> Dictionary:
	var direct: Dictionary = World.travel_preview(to_id)
	var out := {
		"ok": bool(direct.get("ok", false)),
		"dest": to_id,
		"dest_name": str(World.node(to_id).get("name", to_id)),
		"sealed": false,
		"direct": direct,
		"detour": {},
		"wait_days": days_until_clear(),
		"force_morale": FORCE_MORALE,
		"per_day": World.food_per_day(),
		"food_now": GameState.food,
	}
	if not bool(direct.get("ok", false)):
		return out
	var sealed_legs: Array = []
	var readouts: Array = direct.get("leg_readouts", [])
	for leg in readouts:
		if is_sealed(str(leg.get("from", "")), str(leg.get("to", ""))):
			sealed_legs.append(leg)
	out["sealed_legs"] = sealed_legs
	out["sealed"] = not sealed_legs.is_empty()
	out["direct_text"] = path_text(direct.get("path", []))
	out["direct_days"] = int(direct.get("days", 0))
	out["direct_food"] = food_for(int(direct.get("days", 0)))
	var around := route_around(World.pos, to_id) if out["sealed"] else {}
	if not around.is_empty():
		var same := str(around.get("path", [])) == str(direct.get("path", []))
		if not same:
			var extra := int(around.get("days", 0)) - int(direct.get("days", 0))
			around["text"] = path_text(around.get("path", []))
			around["food"] = food_for(int(around.get("days", 0)))
			around["extra_days"] = extra
			around["ok"] = true
			out["detour"] = around
	out["wait_food"] = food_for(int(out["wait_days"]))
	out["force_food"] = food_for(1)
	out["short_direct"] = GameState.food < int(out["direct_food"])
	var detour_food := int(around.get("food", 0)) if not around.is_empty() else 0
	out["short_detour"] = detour_food > 0 and GameState.food < detour_food
	out["short_wait"] = int(out["wait_days"]) > 0 and GameState.food < int(out["wait_food"]) + int(out["direct_food"])
	return out

static func commit_wait() -> Dictionary:
	var n := days_until_clear()
	if n <= 0:
		return {"ok": false, "msg": Locale.t("seal_wait_none")}
	var food0 := GameState.food
	var day0 := World.days_total
	World.advance_days(n)
	World._tlog(Locale.t("seal_log_wait") % n)
	return {
		"ok": true,
		"days": World.days_total - day0,
		"food_before": food0,
		"food_after": GameState.food,
	}

## Pay one day and a morale hit, then mark every sealed leg on the direct
## road open for this winter month. The march itself is still World's route.
static func commit_force(to_id: String) -> Dictionary:
	var direct: Dictionary = World.travel_preview(to_id)
	if not bool(direct.get("ok", false)):
		return {"ok": false, "msg": str(direct.get("msg", ""))}
	var opened := 0
	for leg in direct.get("leg_readouts", []):
		var a := str(leg.get("from", ""))
		var b := str(leg.get("to", ""))
		if not is_sealed(a, b):
			continue
		World.road_flags[open_key(a, b)] = true
		opened += 1
	if opened == 0:
		return {"ok": false, "msg": Locale.t("seal_force_none")}
	var food0 := GameState.food
	var morale0 := GameState.morale
	GameState.morale = maxi(0, GameState.morale - FORCE_MORALE)
	World.advance_days(1)
	World._tlog(Locale.t("seal_log_force") % FORCE_MORALE)
	return {
		"ok": true,
		"opened": opened,
		"days": 1,
		"morale": morale0 - GameState.morale,
		"food_before": food0,
		"food_after": GameState.food,
	}

## Headless march along the detour, one adjacent hop at a time, so World's
## shortest path cannot step back onto a sealed edge.
static func march_detour(to_id: String) -> Dictionary:
	var plan := compare(to_id)
	var detour: Dictionary = plan.get("detour", {})
	if not bool(plan.get("sealed", false)) or not bool(detour.get("ok", false)):
		return {"ok": false, "msg": Locale.t("seal_detour_none")}
	var path: Array = detour.get("path", [])
	if path.is_empty() or str(path[0]) != World.pos:
		return {"ok": false, "msg": Locale.t("seal_detour_none")}
	var food0 := GameState.food
	var day0 := World.days_total
	World._tlog(Locale.t("seal_log_detour") % str(plan.get("dest_name", to_id)))
	for i in range(1, path.size()):
		var nxt := str(path[i])
		var hop: Dictionary = World.route(World.pos, nxt)
		var hp: Array = hop.get("path", [])
		if hp.size() != 2 or str(hp[1]) != nxt:
			return {"ok": false, "msg": Locale.t("seal_hop_fail") % nxt, "pos": World.pos}
		if is_sealed(World.pos, nxt):
			return {"ok": false, "msg": Locale.t("seal_hop_sealed") % nxt, "pos": World.pos}
		World.travel_to(nxt)
		if World.pos != nxt or World.is_traveling():
			return {"ok": false, "msg": Locale.t("seal_hop_fail") % nxt, "pos": World.pos}
	return {
		"ok": World.pos == to_id,
		"days": World.days_total - day0,
		"food_before": food0,
		"food_after": GameState.food,
		"path": path,
		"plan_days": int(detour.get("days", 0)),
	}
