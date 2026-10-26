class_name BattleFormationCycle
extends RefCounted
## Y1-A T-P12: cycle next/prev ready player unit (编队切换).
## Ready = player team, living (hp>0), not done this turn. Wrap. Never picks enemy.

static func ready_indices(units, require_not_done: bool = true) -> Array[int]:
	var out: Array[int] = []
	if units == null:
		return out
	for i in range(units.size()):
		var u = units[i]
		if typeof(u) != TYPE_DICTIONARY:
			continue
		if str(u.get("team", "")) != "player":
			continue
		var ch = u.get("char", null)
		var hp := 0
		if typeof(ch) == TYPE_DICTIONARY:
			hp = int(ch.get("hp", 0))
		elif ch != null and "hp" in ch:
			hp = int(ch.hp)
		if hp <= 0:
			continue
		if require_not_done and bool(u.get("done", false)):
			continue
		out.append(i)
	return out


static func next_idx(units, from_selected: int, require_not_done: bool = true) -> int:
	var ready: Array[int] = ready_indices(units, require_not_done)
	if ready.is_empty():
		return -1
	if from_selected < 0:
		return ready[0]
	var best := -1
	for i in ready:
		if i > from_selected:
			best = i
			break
	if best >= 0:
		return best
	return ready[0]


static func prev_idx(units, from_selected: int, require_not_done: bool = true) -> int:
	var ready: Array[int] = ready_indices(units, require_not_done)
	if ready.is_empty():
		return -1
	if from_selected < 0:
		return ready[ready.size() - 1]
	var best := -1
	for j in range(ready.size() - 1, -1, -1):
		if ready[j] < from_selected:
			best = ready[j]
			break
	if best >= 0:
		return best
	return ready[ready.size() - 1]


## Select next ready player via host._select_player. Returns new index or -1.
## Duck-types host.units / selected / turn_team / battle_over (Node.get is child path).
static func apply_next(host) -> int:
	if host == null:
		return -1
	if bool(host.battle_over) or str(host.turn_team) != "player":
		return -1
	var n: int = next_idx(host.units, int(host.selected), true)
	if n < 0:
		return -1
	if host.has_method("_select_player"):
		host._select_player(n)
	else:
		host.selected = n
	return n


static func apply_prev(host) -> int:
	if host == null:
		return -1
	if bool(host.battle_over) or str(host.turn_team) != "player":
		return -1
	var n: int = prev_idx(host.units, int(host.selected), true)
	if n < 0:
		return -1
	if host.has_method("_select_player"):
		host._select_player(n)
	else:
		host.selected = n
	return n
