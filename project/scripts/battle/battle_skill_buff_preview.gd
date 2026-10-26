class_name BattleSkillBuffPreview
extends RefCounted
## Y1-A skill/buff feel: on mobile touch-confirm, arming a buff art latches
## a party-target preview (amber chrome + camera frame) instead of auto-casting.
## Confirm consumes; cancel keeps uses. Tab cycles party allies for focus.

const META := "m_skill_buff_preview"
const BODY_FILL_A := 0.22
const LINE_W := 3.4


static func wants_soft_confirm() -> bool:
	return DeviceProfile.is_mobile() and BattleTouchConfirm.enabled()


static func latched(host) -> bool:
	if host == null or not host.has_meta(META):
		return false
	var m = host.get_meta(META)
	return m is Dictionary and str(m.get("sid", "")) != ""


static func preview_ui(host) -> int:
	if not latched(host):
		return -1
	return int(host.get_meta(META).get("focus", -1))


static func active_sid(host) -> String:
	if not latched(host):
		return ""
	return str(host.get_meta(META).get("sid", ""))


static func clear(host) -> void:
	if host != null and host.has_meta(META):
		host.remove_meta(META)


## Party living allies (chart_rally-style party_def_buff targets the whole side).
static func buffable_indices(host) -> Array[int]:
	var out: Array[int] = []
	if host == null:
		return out
	var units = host.get("units")
	if units == null:
		return out
	for i in units.size():
		var o = units[i]
		if str(o.team) != "player" or int(o.char.hp) <= 0:
			continue
		out.append(i)
	return out


static func _focus_nearest(host, idxs: Array[int]) -> int:
	if idxs.is_empty():
		return -1
	var ui := int(host.selected)
	# Prefer a non-self ally nearest the caster; else self.
	var best := -1
	var best_d := 9999
	for i in idxs:
		if i == ui:
			continue
		var d: int = absi(host.units[i].pos.x - host.units[ui].pos.x) + absi(host.units[i].pos.y - host.units[ui].pos.y)
		if d < best_d or (d == best_d and i < best):
			best_d = d
			best = i
	if best >= 0:
		return best
	if idxs.has(ui):
		return ui
	return idxs[0]


## Arm buff skill into preview instead of casting. Caller already validated sid.
static func arm(host, sid: String) -> bool:
	if host == null or sid == "" or not wants_soft_confirm():
		return false
	var sk: Dictionary = GameState.get_skill(sid)
	if str(sk.get("type", "")) != "buff":
		return false
	var idxs: Array[int] = buffable_indices(host)
	if idxs.is_empty():
		return false
	host.active_skill_id = sid
	host.skill_mode = true
	host.attack_mode = false
	host.move_cells.clear()
	host.preview_move_cell = Vector2i(-1, -1)
	host.preview_attack_ui = -1
	var focus := _focus_nearest(host, idxs)
	var stand: Vector2i = host.units[int(host.selected)].pos
	var cells: Array = [stand]
	for i in idxs:
		cells.append(host.units[i].pos)
	var applied := BattleCombatFrame.follow_cells(host, cells, BattleCombatFrame.forecast_band(true))
	host.set_meta(META, {
		"sid": sid,
		"focus": focus,
		"targets": idxs.duplicate(),
		"delta": applied,
		"msec": Time.get_ticks_msec(),
	})
	if host.has_method("_update_skill_hint"):
		host._update_skill_hint()
	if host.has_method("_refresh_info"):
		host._refresh_info()
	if host.has_method("_log"):
		host._log(Locale.t("ux_buff_preview_armed") % str(sk.get("name", sid)))
	if DeviceProfile.is_mobile():
		BattleMobileBar.rebuild(host)
	if host.overlay:
		host.overlay.queue_redraw()
	return true


static func confirm(host) -> bool:
	if not latched(host):
		return false
	var sid := active_sid(host)
	var ui := int(host.get("selected"))
	clear(host)
	if ui < 0 or ui >= host.units.size() or sid == "":
		return false
	if host.has_method("_cast_buff_skill"):
		host._cast_buff_skill(ui, sid)
		return true
	return false


static func next_idx(host, from_focus: int) -> int:
	var ready: Array[int] = buffable_indices(host)
	if ready.is_empty():
		return -1
	if from_focus < 0:
		return ready[0]
	for i in ready:
		if i > from_focus:
			return i
	return ready[0]


static func prev_idx(host, from_focus: int) -> int:
	var ready: Array[int] = buffable_indices(host)
	if ready.is_empty():
		return -1
	if from_focus < 0:
		return ready[ready.size() - 1]
	for j in range(ready.size() - 1, -1, -1):
		if ready[j] < from_focus:
			return ready[j]
	return ready[ready.size() - 1]


static func _aim(host, ally_i: int) -> int:
	if ally_i < 0 or not latched(host):
		return -1
	var m: Dictionary = host.get_meta(META)
	m["focus"] = ally_i
	m["msec"] = Time.get_ticks_msec()
	host.set_meta(META, m)
	var stand: Vector2i = host.units[int(host.selected)].pos
	var ally_pos: Vector2i = host.units[ally_i].pos
	BattleCombatFrame.follow_cells(host, [stand, ally_pos], BattleCombatFrame.forecast_band(true))
	if host.has_method("_refresh_info"):
		host._refresh_info()
	if host.overlay:
		host.overlay.queue_redraw()
	if DeviceProfile.is_mobile():
		BattleMobileBar.rebuild(host)
	return ally_i


static func apply_next(host) -> int:
	if not latched(host):
		return -1
	return _aim(host, next_idx(host, preview_ui(host)))


static func apply_prev(host) -> int:
	if not latched(host):
		return -1
	return _aim(host, prev_idx(host, preview_ui(host)))


static func draw(host, overlay) -> void:
	if overlay == null or host == null or not latched(host):
		return
	var idxs: Array[int] = buffable_indices(host)
	if idxs.is_empty():
		return
	var focus := preview_ui(host)
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pulse := 0.72 + 0.28 * sin(float(host.get("_sel_pulse")) * 5.5)
	var half_w: float = BattlePick.contour_half_w()
	var tone: Color = UIKit.ACCENT
	for i in idxs:
		var cell: Vector2i = host.units[i].pos
		var marks := BattleSelectChrome.chrome_marks(origin, cell_px, cell, half_w, 1.0)
		var thick: float = LINE_W + (1.1 if i == focus else 0.0)
		var fill_a: float = BODY_FILL_A * pulse * (1.2 if i == focus else 1.0)
		overlay.draw_arc(marks.mid, float(marks.mid_r) * (1.06 if i == focus else 1.0), 0.0, TAU, 40, Color(tone, 0.95 * pulse), thick)
		var body: Rect2 = marks.body
		overlay.draw_rect(body, Color(tone, fill_a))
		overlay.draw_rect(body, Color(tone, 0.92 * pulse), false, thick)
