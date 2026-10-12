class_name AIPlanner
extends RefCounted
## One-turn enemy plan: threat, shared kills, objective steps, boss phase.
## Tier 0 ignores focus fire. Tiers 1 and 2 share a kill and play the objective.
## WS-D #48: tier >= 1 also focus-fires the weakest reachable foe (healers first), wounded units
## retreat to low-threat cover, and guards screen their own healers instead of rushing.

const RETREAT_FRAC := 0.35
## Optional board fields: units[].healer (bool), cover {"x,y": def_bonus}.

static func tier_of(host) -> int:
	if host == null:
		return 1
	var mode := str(host.settings.get("battle_mode", "standard"))
	if mode == "casual":
		return 0
	if mode == "classic":
		return 2
	return 1


static func threat_map(board: Dictionary) -> Dictionary:
	var out := {}
	var w := int(board.get("w", 12))
	var h := int(board.get("h", 9))
	for u in board.get("units", []):
		if str(u.get("team", "")) == "enemy" or int(u.get("hp", 0)) <= 0:
			continue
		var pos := _pos(u)
		var budget := int(u.get("move", 0)) + int(u.get("reach", 1))
		for y in h:
			for x in w:
				var cell := Vector2i(x, y)
				if _manhattan(pos, cell) <= budget:
					var key := _key(cell)
					out[key] = int(out.get(key, 0)) + 1
	return out


static func plan(board: Dictionary) -> Array:
	var w := int(board.get("w", 12))
	var h := int(board.get("h", 9))
	var tier := int(board.get("tier", 1))
	var players: Array = []
	var enemies: Array = []
	var blocked := {}
	for u in board.get("units", []):
		if int(u.get("hp", 0)) <= 0:
			continue
		blocked[_pos(u)] = true
		if str(u.get("team", "")) == "enemy":
			enemies.append(u)
		else:
			players.append(u)
	var kills := {}
	for e in enemies:
		var row: Array = []
		for p in players:
			if _can_reach(e, p) and int(e.get("power", 0)) >= int(p.get("hp", 1)):
				row.append(str(p.get("id", "")))
		kills[str(e.get("id", ""))] = row
	var focus := _focus_id(kills, players, tier)
	if focus == "" and tier >= 1:
		focus = _soft_focus(enemies, players)
	var threat := threat_map(board) if tier >= 1 else {}
	var actions: Array = []
	var guarded := {}
	for e in enemies:
		var act := {}
		if tier >= 1:
			act = _retreat(e, kills, board, threat, blocked, w, h)
			if act.is_empty():
				act = _healer_hold(e, enemies, players, kills, board, threat, blocked, w, h)
			if act.is_empty():
				act = _guard(e, enemies, players, kills, guarded, blocked, w, h)
		if act.is_empty():
			act = _act(e, players, board, kills, focus, tier, blocked, w, h)
		if str(act.get("action", "")) in ["move", "retreat", "guard"]:
			blocked.erase(_pos(e))
			blocked[act.get("cell", _pos(e))] = true
		actions.append(act)
	return actions


## No shared kill: the foe most enemies can reach, healers first, then lowest hp.
static func _soft_focus(enemies: Array, players: Array) -> String:
	var best := ""
	var best_s := -1.0
	for p in players:
		var n := 0
		for e in enemies:
			if _can_reach(e, p):
				n += 1
		if n < 2:
			continue
		var frac := float(p.get("hp", 0)) / float(maxi(1, int(p.get("max_hp", 1))))
		var s := float(n) * 2.0 + (1.0 - frac) * 3.0 + (2.5 if bool(p.get("healer", false)) else 0.0)
		if s > best_s:
			best_s = s
			best = str(p.get("id", ""))
	return best


static func _cover(board: Dictionary, cell: Vector2i) -> float:
	return float((board.get("cover", {}) as Dictionary).get(_key(cell), 0.0))


static func _cells_within(pos: Vector2i, steps: int, blocked: Dictionary, w: int, h: int) -> Array:
	var out: Array = [pos]
	var seen := {pos: 0}
	var frontier: Array = [pos]
	for _i in steps:
		var nxt: Array = []
		for c in frontier:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n) or blocked.has(n):
					continue
				seen[n] = true
				nxt.append(n)
				out.append(n)
		frontier = nxt
	return out


## Wounded and cannot finish anyone: fall back to the safest cover in move range.
static func _retreat(e: Dictionary, kills: Dictionary, board: Dictionary, threat: Dictionary, blocked: Dictionary, w: int, h: int) -> Dictionary:
	if bool(e.get("boss", false)):
		return {}
	var frac := float(e.get("hp", 0)) / float(maxi(1, int(e.get("max_hp", 1))))
	if frac >= RETREAT_FRAC or not (kills.get(str(e.get("id", "")), []) as Array).is_empty():
		return {}
	var pos := _pos(e)
	var best := pos
	var best_s := float(int(threat.get(_key(pos), 0))) * 10.0 - _cover(board, pos)
	for c in _cells_within(pos, int(e.get("move", 0)), blocked, w, h):
		var s := float(int(threat.get(_key(c), 0))) * 10.0 - _cover(board, c)
		if s < best_s:
			best_s = s
			best = c
	return {"id": str(e.get("id", "")), "action": "retreat", "target": "", "cell": best}


## A healer with no kill stays out of reach behind its line, close to the most hurt ally.
static func _healer_hold(e: Dictionary, enemies: Array, players: Array, kills: Dictionary, board: Dictionary, threat: Dictionary, blocked: Dictionary, w: int, h: int) -> Dictionary:
	if not bool(e.get("healer", false)) or not (kills.get(str(e.get("id", "")), []) as Array).is_empty():
		return {}
	var anchor := {}
	var low := 2.0
	for o in enemies:
		if o == e:
			continue
		var f := float(o.get("hp", 0)) / float(maxi(1, int(o.get("max_hp", 1))))
		if f < low:
			low = f
			anchor = o
	if anchor.is_empty():
		return {}
	var apos := _pos(anchor)
	var pos := _pos(e)
	var best := pos
	var best_s := INF
	for c in _cells_within(pos, int(e.get("move", 0)), blocked, w, h):
		var s := float(int(threat.get(_key(c), 0))) * 6.0 + float(absi(_manhattan(c, apos) - 1)) - _cover(board, c) * 0.5
		if s < best_s:
			best_s = s
			best = c
	return {"id": str(e.get("id", "")), "action": "move" if best != pos else "wait", "target": str(anchor.get("id", "")), "cell": best}


## One fighter without a kill steps between each own healer and the nearest foe.
static func _guard(e: Dictionary, enemies: Array, players: Array, kills: Dictionary, guarded: Dictionary, blocked: Dictionary, w: int, h: int) -> Dictionary:
	if bool(e.get("healer", false)) or bool(e.get("boss", false)) or not (kills.get(str(e.get("id", "")), []) as Array).is_empty():
		return {}
	var pos := _pos(e)
	for hl in enemies:
		var hid := str(hl.get("id", ""))
		if not bool(hl.get("healer", false)) or guarded.has(hid):
			continue
		var hpos := _pos(hl)
		var foe := _nearest(hpos, players)
		if foe.is_empty() or _manhattan(hpos, _pos(foe)) > int(foe.get("move", 0)) + int(foe.get("reach", 1)) + 1:
			continue
		if _manhattan(pos, hpos) > int(e.get("move", 0)) + 2:
			continue
		var fpos := _pos(foe)
		var best := pos
		var best_s := INF
		for c in _cells_within(pos, int(e.get("move", 0)), blocked, w, h):
			var s := float(_manhattan(c, hpos)) * 2.0 + float(_manhattan(c, fpos))
			if _manhattan(c, hpos) == 0:
				continue
			if s < best_s:
				best_s = s
				best = c
		guarded[hid] = true
		return {"id": str(e.get("id", "")), "action": "guard", "target": hid, "cell": best}
	return {}


static func _focus_id(kills: Dictionary, players: Array, tier: int) -> String:
	if tier < 1:
		return ""
	var votes := {}
	for eid in kills.keys():
		for pid in kills[eid]:
			votes[str(pid)] = int(votes.get(str(pid), 0)) + 1
	var best := ""
	var best_n := 1
	var best_hp := 1 << 30
	for p in players:
		var pid := str(p.get("id", ""))
		var n := int(votes.get(pid, 0))
		if n < 2:
			continue
		var hp := int(p.get("hp", 0))
		if n > best_n or (n == best_n and hp < best_hp):
			best = pid
			best_n = n
			best_hp = hp
	return best


static func _act(e: Dictionary, players: Array, board: Dictionary, kills: Dictionary, focus: String, tier: int, blocked: Dictionary, w: int, h: int) -> Dictionary:
	var eid := str(e.get("id", ""))
	var pos := _pos(e)
	var phase := float(board.get("boss_phase", 0.5))
	var max_hp := maxi(1, int(e.get("max_hp", 1)))
	if bool(e.get("boss", false)) and float(e.get("hp", 0)) / float(max_hp) <= phase and not bool(board.get("summoned", false)):
		return {"id": eid, "action": "summon", "target": "", "cell": pos}
	var mine: Array = kills.get(eid, [])
	if tier >= 1 and focus != "" and focus in mine:
		return {"id": eid, "action": "attack", "target": focus, "cell": pos}
	if tier >= 1 and mine.is_empty():
		var obj := _objective(e, board, blocked, w, h)
		if not obj.is_empty():
			return obj
	if tier >= 1 and not mine.is_empty():
		var kill_id := _lowest(players, mine)
		return {"id": eid, "action": "attack", "target": kill_id, "cell": pos}
	if tier >= 1 and focus != "":
		for p in players:
			if str(p.get("id", "")) == focus and _can_reach(e, p):
				return {"id": eid, "action": "attack", "target": focus, "cell": pos}
	var near := _nearest(pos, players)
	if near.is_empty():
		return {"id": eid, "action": "wait", "target": "", "cell": pos}
	var npos := _pos(near)
	if _manhattan(pos, npos) <= int(e.get("reach", 1)):
		return {"id": eid, "action": "attack", "target": str(near.get("id", "")), "cell": pos}
	var step := _step(pos, npos, blocked, w, h)
	if step == pos:
		return {"id": eid, "action": "wait", "target": "", "cell": pos}
	return {"id": eid, "action": "move", "target": str(near.get("id", "")), "cell": step}


static func _objective(e: Dictionary, board: Dictionary, blocked: Dictionary, w: int, h: int) -> Dictionary:
	var obj: Dictionary = board.get("objective", {})
	var kind := str(obj.get("type", "rout"))
	var eid := str(e.get("id", ""))
	var pos := _pos(e)
	if kind == "seize":
		var tile := _pair(obj.get("tile", [0, 0]))
		if pos == tile:
			return {"id": eid, "action": "wait", "target": "", "cell": pos}
		var step := _step(pos, tile, blocked, w, h)
		if step == pos:
			return {"id": eid, "action": "wait", "target": "", "cell": pos}
		return {"id": eid, "action": "move", "target": "tile", "cell": step}
	if kind == "defend":
		var tiles: Array = obj.get("tiles", [])
		for raw in tiles:
			if _pair(raw) == pos:
				return {"id": eid, "action": "wait", "target": "", "cell": pos}
		if tiles.is_empty():
			return {}
		var best: Vector2i = _pair(tiles[0])
		var best_d := _manhattan(pos, best)
		for raw in tiles:
			var tile := _pair(raw)
			var d := _manhattan(pos, tile)
			if d < best_d:
				best = tile
				best_d = d
		var step := _step(pos, best, blocked, w, h)
		if step == pos:
			return {"id": eid, "action": "wait", "target": "", "cell": pos}
		return {"id": eid, "action": "move", "target": "tile", "cell": step}
	if kind == "escort":
		var tag := str(obj.get("npc", ""))
		var npc := {}
		for u in board.get("units", []):
			if str(u.get("tag", "")) == tag and int(u.get("hp", 0)) > 0:
				npc = u
				break
		if npc.is_empty():
			return {}
		var npos := _pos(npc)
		if _manhattan(pos, npos) <= 1:
			return {"id": eid, "action": "wait", "target": str(npc.get("id", "")), "cell": pos}
		var step := _step(pos, npos, blocked, w, h)
		if step == pos:
			return {"id": eid, "action": "wait", "target": str(npc.get("id", "")), "cell": pos}
		return {"id": eid, "action": "move", "target": str(npc.get("id", "")), "cell": step}
	return {}


static func _lowest(players: Array, ids: Array) -> String:
	var best := str(ids[0])
	var hp := 1 << 30
	for p in players:
		var pid := str(p.get("id", ""))
		if pid in ids and int(p.get("hp", 0)) < hp:
			hp = int(p.get("hp", 0))
			best = pid
	return best


static func _nearest(pos: Vector2i, players: Array) -> Dictionary:
	var best := {}
	var dist := 1 << 30
	for p in players:
		var d := _manhattan(pos, _pos(p))
		if d < dist:
			dist = d
			best = p
	return best


static func _can_reach(e: Dictionary, p: Dictionary) -> bool:
	var dist := _manhattan(_pos(e), _pos(p))
	return dist >= 1 and dist <= int(e.get("move", 0)) + int(e.get("reach", 1))


static func _step(frm: Vector2i, to: Vector2i, blocked: Dictionary, w: int, h: int) -> Vector2i:
	var dx := signi(to.x - frm.x)
	var dy := signi(to.y - frm.y)
	var opts: Array[Vector2i] = []
	if absi(to.x - frm.x) >= absi(to.y - frm.y):
		if dx != 0:
			opts.append(frm + Vector2i(dx, 0))
		if dy != 0:
			opts.append(frm + Vector2i(0, dy))
	else:
		if dy != 0:
			opts.append(frm + Vector2i(0, dy))
		if dx != 0:
			opts.append(frm + Vector2i(dx, 0))
	for cell in opts:
		if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h:
			continue
		if blocked.has(cell) and cell != to:
			continue
		return cell
	return frm


static func _pos(u: Dictionary) -> Vector2i:
	var raw = u.get("pos", [0, 0])
	return _pair(raw)


static func _pair(raw) -> Vector2i:
	if raw is Vector2i:
		return raw
	var a: Array = raw
	return Vector2i(int(a[0]), int(a[1]))


static func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func code_of(act: Dictionary) -> String:
	var kind := str(act.get("action", "wait"))
	if kind == "attack":
		return "attack:%s" % str(act.get("target", ""))
	if kind in ["move", "retreat", "guard"]:
		var cell: Vector2i = act.get("cell", Vector2i.ZERO)
		return "%s:%d,%d" % [kind, cell.x, cell.y]
	return kind
