class_name BattleWaitHandoff
extends RefCounted
## Y1-A T-P21: after Wait / strike / skill ends a unit, hand off to the next
## ready player and settle the camera on their figure. Self-contained ready
## algebra (same contract as T-P12 FormationCycle; no hard dep so this lands
## without waiting on that PR).

const META := "m_wait_handoff"


static func ready_indices(units) -> Array[int]:
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
		if bool(u.get("done", false)):
			continue
		out.append(i)
	return out


static func next_idx(units, from_idx: int) -> int:
	var ready: Array[int] = ready_indices(units)
	if ready.is_empty():
		return -1
	if from_idx < 0:
		return ready[0]
	for i in ready:
		if i > from_idx:
			return i
	return ready[0]


## Call AFTER the finished unit is marked done and selected is cleared.
## Returns the new selected index, or -1 when no ready unit / not player turn.
static func after_unit_done(host, from_idx: int = -1) -> int:
	if host == null:
		return -1
	if bool(host.get("battle_over")):
		return -1
	if str(host.get("turn_team")) != "player":
		return -1
	var units = host.get("units")
	var n: int = next_idx(units, from_idx)
	if n < 0:
		if host.has_meta(META):
			host.remove_meta(META)
		return -1
	if host.has_method("_select_player"):
		host._select_player(n)
	else:
		host.selected = n
		BattleCombatFrame.follow_selected(host)
	host.set_meta(META, {
		"from": from_idx,
		"to": n,
		"msec": Time.get_ticks_msec(),
	})
	return n
