class_name BattleTurnBridge
extends RefCounted
## Y1-A turn-bridge fat: player-phase return → ready pulse + auto-select first ready.
## After unit done / wait → handoff next ready. Steady ready feet + pulse.
## Ready HUD tap cycles FormationCycle. No telegraph / aim tips.

const META_PULSE := "m_turn_bridge_pulse_msec"
const PULSE_MS := 1400
const READY_FOOT_R := 0.22
const READY_FOOT_A := 0.55


static func note_player_return(host) -> void:
	if host == null:
		return
	if bool(host.battle_over):
		return
	if str(host.turn_team) != "player":
		return
	host.set_meta(META_PULSE, Time.get_ticks_msec())
	BattleDualLedger.refresh(host)
	_auto_select_first_ready(host)
	_queue_overlay(host)


static func _auto_select_first_ready(host) -> void:
	if int(host.selected) >= 0:
		return
	var n: int = BattleFormationCycle.next_idx(host.units, -1, true)
	if n < 0:
		return
	if host.has_method("_select_player"):
		host._select_player(n)
	else:
		host.selected = n


static func pulse_alpha(host) -> float:
	if host == null or not host.has_meta(META_PULSE):
		return 0.0
	var age_ms := Time.get_ticks_msec() - int(host.get_meta(META_PULSE))
	if age_ms < 0 or age_ms >= PULSE_MS:
		return 0.0
	var t := 1.0 - float(age_ms) / float(PULSE_MS)
	return clampf(t, 0.0, 1.0)


static func tap_ready(host) -> int:
	if host == null:
		return -1
	if bool(host.battle_over) or str(host.turn_team) != "player":
		return -1
	return BattleFormationCycle.apply_next(host)


static func after_unit_done(host) -> void:
	if host == null:
		return
	if bool(host.battle_over) or str(host.turn_team) != "player":
		return
	BattleDualLedger.refresh(host)
	# selected already cleared by caller — pick next ready
	if int(host.selected) >= 0:
		return
	var n: int = BattleFormationCycle.next_idx(host.units, -1, true)
	if n < 0:
		return
	if host.has_method("_select_player"):
		host._select_player(n)
	else:
		host.selected = n
	host.set_meta(META_PULSE, Time.get_ticks_msec())
	_queue_overlay(host)


static func draw_ready_pulse(host, overlay: CanvasItem) -> void:
	if host == null or overlay == null:
		return
	if str(host.turn_team) != "player":
		return
	var cells: Array[Vector2i] = _ready_cells(host.units)
	if cells.is_empty():
		return
	var pulse := pulse_alpha(host)
	var base := 0.35
	var a := clampf(base + pulse * 0.65, 0.0, 1.0)
	_paint_ready_feet(host, overlay, cells, a)


static func _ready_cells(units) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if units == null:
		return out
	for u in units:
		if typeof(u) != TYPE_DICTIONARY:
			continue
		if str(u.get("team", "")) != "player":
			continue
		if bool(u.get("done", false)):
			continue
		var ch = u.get("char", null)
		var hp := 0
		if typeof(ch) == TYPE_DICTIONARY:
			hp = int(ch.get("hp", 0))
		elif ch != null and "hp" in ch:
			hp = int(ch.hp)
		if hp <= 0:
			continue
		var pos = u.get("pos", null)
		if typeof(pos) == TYPE_VECTOR2I:
			out.append(pos)
		elif typeof(pos) == TYPE_VECTOR2:
			out.append(Vector2i(int(pos.x), int(pos.y)))
	return out


static func _paint_ready_feet(host, overlay: CanvasItem, cells: Array[Vector2i], a: float) -> void:
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pan: Vector2 = host._board_pan if "_board_pan" in host else Vector2.ZERO
	var zoom := float(host._board_zoom) if "_board_zoom" in host else 1.0
	if zoom < 0.001:
		zoom = 1.0
	var cpx := cell_px * zoom
	var tone := Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, READY_FOOT_A * a)
	var ring := Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.9 * a)
	for cell in cells:
		var top_left := origin * zoom + Vector2(cell) * cpx + pan
		var foot := top_left + Vector2(cpx * 0.5, cpx * BattlePick.FIG_FEET)
		var r := cpx * READY_FOOT_R * (0.85 + 0.15 * a)
		overlay.draw_circle(foot, r, tone)
		overlay.draw_arc(foot, r * 1.15, 0.0, TAU, 28, ring, 2.0)


static func _queue_overlay(host) -> void:
	var ov = host.get("overlay")
	if ov != null and ov.has_method("queue_redraw"):
		ov.queue_redraw()
