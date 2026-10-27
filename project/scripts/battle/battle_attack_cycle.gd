class_name BattleAttackCycle
extends RefCounted
## Y1-A T-P25: in attack mode, Tab / Shift+Tab cycle in-reach foes
## (preview_attack_ui + camera frame). Formation cycle stays for non-attack.
## BoardInset: refresh m_info_block from MobileSideCol before follow_cells
## so cycle settle shares notch+info+edge (same as AttackAim / ActionSettle /
## skill buff-heal refresh). Keeps forecast_band while ForecastPanel is up.

const META := "m_attack_cycle"


static func active(host) -> bool:
	if host == null:
		return false
	if str(host.get("turn_team")) != "player" or bool(host.get("battle_over")):
		return false
	if not bool(host.get("attack_mode")):
		return false
	var ui := int(host.get("selected"))
	var units = host.get("units")
	if units == null or ui < 0 or ui >= units.size():
		return false
	var u = units[ui]
	if str(u.team) != "player" or bool(u.done) or int(u.char.hp) <= 0:
		return false
	return true


static func threatened_indices(host) -> Array[int]:
	var out: Array[int] = []
	if not active(host):
		return out
	var su = host.units[int(host.selected)]
	var stand: Vector2i = su.pos
	var tid := "plain"
	var height := 0
	if host.has_method("_in_bounds") and host._in_bounds(stand):
		tid = str(host.terrain[stand.y][stand.x])
	if host.has_method("_height_at"):
		height = int(host._height_at(stand))
	for i in host.units.size():
		var foe = host.units[i]
		if str(foe.team) != "enemy" or int(foe.char.hp) <= 0:
			continue
		var d: int = absi(foe.pos.x - stand.x) + absi(foe.pos.y - stand.y)
		if BattleRules.in_weapon_range(su.char, d, tid, height):
			out.append(i)
	return out


static func next_idx(host, from_preview: int) -> int:
	var ready: Array[int] = threatened_indices(host)
	if ready.is_empty():
		return -1
	if from_preview < 0:
		return ready[0]
	for i in ready:
		if i > from_preview:
			return i
	return ready[0]


static func prev_idx(host, from_preview: int) -> int:
	var ready: Array[int] = threatened_indices(host)
	if ready.is_empty():
		return -1
	if from_preview < 0:
		return ready[ready.size() - 1]
	for j in range(ready.size() - 1, -1, -1):
		if ready[j] < from_preview:
			return ready[j]
	return ready[ready.size() - 1]


static func _aim(host, foe_i: int) -> int:
	if foe_i < 0:
		return -1
	host.preview_attack_ui = foe_i
	var stand: Vector2i = host.units[int(host.selected)].pos
	var foe_pos: Vector2i = host.units[foe_i].pos
	# Refresh live info column so BoardInset cuts the same chrome as
	# AttackAim / ActionSettle / skill refresh (stale m_info_block left
	# figures under the side col).
	_refresh_info_block(host)
	BattleCombatFrame.follow_cells(host, [stand, foe_pos], BattleCombatFrame.forecast_band(DeviceProfile.is_mobile()))
	host.set_meta(META, {"foe": foe_i, "msec": Time.get_ticks_msec()})
	if host.has_method("_refresh_info"):
		host._refresh_info()
	ForecastPanel.refresh(host)
	if host.overlay:
		host.overlay.queue_redraw()
	return foe_i


static func apply_next(host) -> int:
	if not active(host):
		return -1
	var cur := int(host.get("preview_attack_ui"))
	var n: int = next_idx(host, cur)
	return _aim(host, n)


static func apply_prev(host) -> int:
	if not active(host):
		return -1
	var cur := int(host.get("preview_attack_ui"))
	var n: int = prev_idx(host, cur)
	return _aim(host, n)



static func _refresh_info_block(host) -> void:
	if host == null:
		return
	var col := host.get_node_or_null("MobileSideCol") as Control
	if col == null:
		col = host.find_child("MobileSideCol", true, false) as Control
	if col == null:
		col = host.get_node_or_null("SideCol") as Control
	if col != null and col.size.x > 1.0 and col.size.y > 1.0:
		host.set_meta("m_info_block", Rect2(col.position, col.size))


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)
