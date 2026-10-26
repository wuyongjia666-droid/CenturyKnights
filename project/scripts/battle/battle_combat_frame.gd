class_name BattleCombatFrame
extends RefCounted
## Y1-A T-P13: mid-battle camera + attack-preview framing.
##
## Root cause (desktop and phone landscape):
## - BattlePick.focus_cell / focus_follow_cell return immediately on desktop
##   unless force=true. That flag is reserved for enemy-turn follow so player
##   phase lead does not move _board_pan (tactics / full_chain framing).
##   Selecting a unit therefore never followed the piece on desktop, and a
##   zoomed-out unit sitting past the play inset stayed there.
## - Attack preview only called focus_follow_preview on confirm, and confirm
##   then clear() → focus_selected, which yanked the camera back to the
##   attacker before focus_cell ran on the defender. The preview itself never
##   framed the pair. The forecast panel was pinned to the top-left of the
##   stage and covered the fight.
##
## This frames the figure AABB (head through feet) with the smallest pan that
## lands it inside the play inset. Already-visible pieces are not recentered.
## Attack preview reserves the forecast band so the pair sits below the panel.
## Unit-drag (ck_unit_drag) must not pan — the caller suppresses follow.


const EDGE_FRAC := 0.08
const FORECAST_BAND_MOBILE := 220.0
const FORECAST_BAND_DESK := 156.0


static func forecast_band(mobile: bool) -> float:
	return FORECAST_BAND_MOBILE if mobile else FORECAST_BAND_DESK


## Shown-space figure AABB. Head uses FIG_TOP, feet FIG_FEET, width the desktop contour.
static func figure_rect(origin: Vector2, cell_px: float, cell: Vector2i, pan: Vector2, zoom: float) -> Rect2:
	var z := zoom if zoom > 0.001 else 1.0
	var cpx := cell_px * z
	var top_left := origin * z + Vector2(cell) * cpx + pan
	var half_w := cpx * BattlePick.CONTOUR_HALF_W
	var left := top_left.x + cpx * 0.5 - half_w
	var top := top_left.y + cpx * BattlePick.FIG_TOP
	var height := cpx * (BattlePick.FIG_FEET - BattlePick.FIG_TOP)
	return Rect2(left, top, half_w * 2.0, height)


## Stage inset the fight must occupy. reserve_top keeps the forecast band clear.
static func play_inset(stage: Rect2, reserve_top: float, reserve_bottom: float) -> Rect2:
	var pad_x := stage.size.x * EDGE_FRAC
	var pad_y := stage.size.y * EDGE_FRAC
	var top := stage.position.y + maxf(pad_y, reserve_top)
	var bottom := stage.end.y - maxf(pad_y, reserve_bottom)
	var left := stage.position.x + pad_x
	var right := stage.end.x - pad_x
	if bottom - top < 72.0:
		top = stage.position.y + 8.0
		bottom = stage.end.y - 8.0
	if right - left < 72.0:
		left = stage.position.x + 8.0
		right = stage.end.x - 8.0
	return Rect2(left, top, right - left, bottom - top)


## Minimum pan delta that brings bounds into inset. Oversized bounds are centered.
static func frame_delta_for_rect(bounds: Rect2, inset: Rect2) -> Vector2:
	if inset.size.x < 8.0 or inset.size.y < 8.0 or bounds.size.x < 1.0:
		return Vector2.ZERO
	return Vector2(
		_axis_delta(bounds.position.x, bounds.end.x, inset.position.x, inset.end.x),
		_axis_delta(bounds.position.y, bounds.end.y, inset.position.y, inset.end.y))


static func _axis_delta(lo: float, hi: float, inset_lo: float, inset_hi: float) -> float:
	var span := hi - lo
	var room := inset_hi - inset_lo
	if span >= room - 0.5:
		return (inset_lo + inset_hi) * 0.5 - (lo + hi) * 0.5
	if lo < inset_lo:
		return inset_lo - lo
	if hi > inset_hi:
		return inset_hi - hi
	return 0.0


static func frame_delta(origin: Vector2, cell_px: float, cells: Array, pan: Vector2, zoom: float, inset: Rect2) -> Vector2:
	var bounds := Rect2()
	var any := false
	for c in cells:
		if not (c is Vector2i):
			continue
		var cell: Vector2i = c
		if cell.x < 0:
			continue
		var fig := figure_rect(origin, cell_px, cell, pan, zoom)
		if not any:
			bounds = fig
			any = true
		else:
			bounds = bounds.merge(fig)
	if not any:
		return Vector2.ZERO
	return frame_delta_for_rect(bounds, inset)


static func figure_inside(origin: Vector2, cell_px: float, cell: Vector2i, pan: Vector2, zoom: float, inset: Rect2, slop: float = 2.0) -> bool:
	return inset.grow(slop).encloses(figure_rect(origin, cell_px, cell, pan, zoom))


## Forecast corner farthest from the pair, staying inside the stage.
static func forecast_slot(stage: Rect2, panel_size: Vector2, pair_mid: Vector2) -> Vector2:
	var pad := 8.0
	var left_x := stage.position.x + pad
	var right_x := maxf(left_x, stage.end.x - panel_size.x - pad)
	var top_y := stage.position.y + pad
	var bot_y := maxf(top_y, stage.end.y - panel_size.y - pad)
	var place_left := pair_mid.x >= stage.get_center().x
	var x := left_x if place_left else right_x
	var y := top_y
	var top_band := Rect2(x, y, panel_size.x, panel_size.y)
	if top_band.has_point(pair_mid):
		y = bot_y
	var placed := Rect2(x, y, panel_size.x, panel_size.y)
	if placed.has_point(pair_mid):
		y = top_y
	return Vector2(x, y)


static func chip_lines(info: Dictionary) -> PackedStringArray:
	if info.is_empty() or not info.has("hit"):
		return PackedStringArray()
	var lines := PackedStringArray([
		"%d%%" % int(info.get("hit", 0)),
		"%d-%d" % [int(info.get("dmg_lo", 0)), int(info.get("dmg_hi", 0))],
	])
	if bool(info.get("counter", false)):
		lines.append("C%d%%" % int(info.get("counter_hit", 0)))
	return lines


static func attack_cells(host) -> Array:
	var cells: Array = []
	var atk := int(host.selected)
	if atk >= 0 and atk < host.units.size():
		cells.append(host.units[atk].pos)
	var def := int(host.get("preview_attack_ui"))
	if def < 0 and bool(host.get("attack_mode")) and host.has_method("_unit_at"):
		def = int(host._unit_at(host.get("_hover_cell")))
	if def >= 0 and def < host.units.size():
		var pos: Vector2i = host.units[def].pos
		if cells.is_empty() or cells[0] != pos:
			cells.append(pos)
	return cells


static func pair_mid_shown(host) -> Vector2:
	var pan: Vector2 = host._board_pan
	if host.has_meta("m_combat_frame"):
		var info = host.get_meta("m_combat_frame")
		if info is Dictionary:
			pan += info.get("delta", Vector2.ZERO)
	var cells: Array = attack_cells(host)
	if cells.is_empty() and int(host.selected) >= 0 and int(host.selected) < host.units.size():
		cells = [host.units[int(host.selected)].pos]
	var stage: Rect2 = BattlePick._stage_rect(host)
	if cells.is_empty():
		return stage.get_center()
	var acc := Vector2.ZERO
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var zoom := float(host._board_zoom) if host.get("_board_zoom") != null else 1.0
	for c in cells:
		acc += figure_rect(origin, cell_px, c, pan, zoom).get_center()
	return acc / float(cells.size())


## Apply the minimum pan. Returns the clamped delta. Zero cancels a hard recenter.
static func follow_cells(host, cells: Array, reserve_top: float) -> Vector2:
	var stage: Rect2 = BattlePick._stage_rect(host)
	if stage.size.x < 8.0 or cells.is_empty():
		return Vector2.ZERO
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var pan: Vector2 = host._board_pan
	var zoom := float(host._board_zoom) if host.get("_board_zoom") != null else 1.0
	var inset := play_inset(stage, reserve_top, 0.0)
	var raw := frame_delta(origin, cell_px, cells, pan, zoom, inset)
	var saved: Vector2 = host._board_pan
	host._board_pan = pan + raw
	if host.has_method("_clamp_board_pan"):
		host._clamp_board_pan()
	var clamped: Vector2 = host._board_pan
	host._board_pan = saved
	var applied: Vector2 = clamped - saved
	host.set_meta("m_combat_frame", {"delta": applied, "inset": inset, "reserve_top": reserve_top})
	if applied.length_squared() < 0.25:
		BattlePick.cancel_focus_tween(host)
		return applied
	BattlePick._apply_focus_pan(host, clamped, true)
	return applied


static func follow_selected(host) -> void:
	if int(host.selected) < 0 or int(host.selected) >= host.units.size():
		return
	follow_cells(host, [host.units[int(host.selected)].pos], 0.0)


static func follow_attack(host) -> void:
	if host.has_meta("ck_unit_drag"):
		return
	var cells: Array = attack_cells(host)
	if cells.is_empty():
		return
	follow_cells(host, cells, forecast_band(DeviceProfile.is_mobile()))
