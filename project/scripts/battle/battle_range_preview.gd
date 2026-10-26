class_name BattleRangePreview
extends RefCounted
## Y1-A T-P17: move-range / attack-range preview, illegal-destination flash,
## and a camera that keeps the selected figure inside the playable area.
##
## Root cause:
## - Range washes are painted on exact cells. Taps go through BattlePick.resolve,
##   which soft-snaps a finger on a painted destination onto a neighbour. The
##   legal tile never previews, and the reject mark lands on the snapped unit.
##   Body hits (figure AABB) still resolve; only empty painted tiles do not.
## - Attack "range" was a red rect on enemies already in weapon range from the
##   current stand. Empty reach tiles were invisible, and a move ghost did not
##   move the ring to the landing.
## - reject_invalid_tap is behind touch-confirm. A latched preview clears on an
##   off-range tap before note_reject, so the aimed tile never flashes. Desktop
##   with confirm off never flashes a bad move.
## - Preview follow tracks the destination, and an oversized pair is centered.
##   The selected figure slides out of the playable area, including under a
##   landscape notch. The pan here keeps the selected figure inside first.
##   A destination is included only when the selected figure still fits.
##   Unit drag (ck_unit_drag) does not pan.


const HELD_SLOP := 2.0
const _UNRESOLVED := Vector2i(-99999, -99999)


static func attack_from(host, stand: Vector2i) -> Dictionary:
	var out := {}
	var ui := int(host.selected)
	if ui < 0 or ui >= host.units.size():
		return out
	if stand.y < 0 or stand.y >= host.terrain.size():
		return out
	var row = host.terrain[stand.y]
	if stand.x < 0 or stand.x >= row.size():
		return out
	var u = host.units[ui]
	var tid := str(row[stand.x])
	var height := 0
	if host.has_method("_height_at"):
		height = int(host._height_at(stand))
	var reach := BattleRules.attack_reach(u.char, tid, height)
	var min_r := BattleRules.min_range(u.char)
	var w := int(host.MAP_W)
	var h := int(host.MAP_H)
	var y0 := maxi(0, stand.y - reach)
	var y1 := mini(h, stand.y + reach + 1)
	var x0 := maxi(0, stand.x - reach)
	var x1 := mini(w, stand.x + reach + 1)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dist := absi(x - stand.x) + absi(y - stand.y)
			if dist < min_r or dist > reach:
				continue
			out[Vector2i(x, y)] = true
	return out


## Ring the player is being shown: the move ghost's stand when one is latched,
## otherwise the selected unit. Empty when nobody actionable is selected.
static func shown_attack(host) -> Dictionary:
	if not _aiming(host):
		return {}
	var stand: Vector2i = host.units[int(host.selected)].pos
	if host.preview_move_cell.x >= 0:
		stand = host.preview_move_cell
	return attack_from(host, stand)


static func publish(host) -> void:
	var attack := shown_attack(host)
	var moves: Dictionary = {}
	if host.get("move_cells") is Dictionary:
		moves = host.move_cells
	var only := 0
	for key in attack.keys():
		if not moves.has(key):
			only += 1
	var stand := Vector2i(-1, -1)
	if _aiming(host):
		stand = host.units[int(host.selected)].pos
		if host.preview_move_cell.x >= 0:
			stand = host.preview_move_cell
	host.set_meta("m_range_preview", {
		"move": moves.size(),
		"attack": attack.size(),
		"attack_only": only,
		"stand": stand,
	})


## Tap cell while a player piece is aimed.
## Figure hits keep BattlePick.resolve (chest / head / contour).
## A painted move or attack tile that is not on a figure uses the exact cell,
## so a soft neighbour cannot steal the destination. An empty miss uses the
## aimed cell too, so the flash lands on the tile under the finger.
static func tap_cell(host, screen_pos: Vector2, resolved: Vector2i = _UNRESOLVED) -> Vector2i:
	if resolved == _UNRESOLVED:
		resolved = BattlePick.resolve(host, screen_pos)
	if not _aiming(host):
		return resolved
	var exact: Vector2i = host._pointer_to_cell(screen_pos)
	if exact.x < 0:
		return resolved
	if _on_living_figure(host, screen_pos):
		return resolved
	if host.move_cells.has(exact) or shown_attack(host).has(exact):
		return exact
	if host._in_bounds(exact) and int(host._unit_at(exact)) < 0:
		return exact
	if int(host._unit_at(exact)) >= 0:
		return exact
	return resolved


static func playable_inset(host) -> Rect2:
	var stage: Rect2 = BattlePick._stage_rect(host)
	var reserve := 0.0
	if int(host.get("preview_attack_ui")) >= 0 or bool(host.get("attack_mode")):
		reserve = BattleCombatFrame.forecast_band(DeviceProfile.is_mobile())
	var inset := BattleCombatFrame.play_inset(stage, reserve, 0.0)
	return _clip_notch(host, inset)


## Minimum pan that brings `primary` inside `inset`. `extras` (ghost / defender)
## are included only when the primary figure is still inside afterwards.
## An oversized pair therefore does not center the selected unit out of view.
static func delta_keeping_primary(origin: Vector2, cell_px: float, primary: Vector2i, extras: Array, pan: Vector2, zoom: float, inset: Rect2) -> Vector2:
	var primary_delta := BattleCombatFrame.frame_delta(origin, cell_px, [primary], pan, zoom, inset)
	if extras.is_empty():
		return primary_delta
	var cells: Array = [primary]
	for extra in extras:
		if extra is Vector2i and int((extra as Vector2i).x) >= 0:
			cells.append(extra)
	if cells.size() < 2:
		return primary_delta
	var joint := BattleCombatFrame.frame_delta(origin, cell_px, cells, pan, zoom, inset)
	var after := pan + joint
	if BattleCombatFrame.figure_inside(origin, cell_px, primary, after, zoom, inset, 1.0):
		return joint
	return primary_delta


## Pull the selected figure into the notch-safe playable inset.
## Returns the applied pan delta. Zero leaves an in-flight follow tween alone
## when the planned pan (attack pair frame, same frame) already holds the figure.
static func keep_selected(host) -> Vector2:
	if host.has_meta("ck_unit_drag"):
		host.set_meta("m_range_keep", {"delta": Vector2.ZERO, "held": false})
		return Vector2.ZERO
	if not _aiming(host):
		return Vector2.ZERO
	var pan: Vector2 = host._board_pan
	var zoom := float(host._board_zoom) if float(host._board_zoom) > 0.001 else 1.0
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var primary: Vector2i = host.units[int(host.selected)].pos
	var inset := playable_inset(host)
	var planned := pan
	if int(host.get("preview_attack_ui")) >= 0 and host.has_meta("m_combat_frame"):
		var info = host.get_meta("m_combat_frame")
		if info is Dictionary:
			planned = pan + info.get("delta", Vector2.ZERO)
	if BattleCombatFrame.figure_inside(origin, cell_px, primary, planned, zoom, inset, HELD_SLOP):
		host.set_meta("m_range_keep", {"delta": Vector2.ZERO, "held": true, "inset": inset})
		return Vector2.ZERO
	var extras: Array = []
	if host.preview_move_cell.x >= 0:
		extras.append(host.preview_move_cell)
	elif int(host.preview_attack_ui) >= 0 and int(host.preview_attack_ui) < host.units.size():
		extras.append(host.units[int(host.preview_attack_ui)].pos)
	var raw := delta_keeping_primary(origin, cell_px, primary, extras, pan, zoom, inset)
	var applied := _apply_pan(host, pan + raw)
	host.set_meta("m_range_keep", {"delta": applied, "held": true, "inset": inset})
	return applied


static func flash_destination(host, cell: Vector2i, reason: String = "move") -> void:
	BattleTouchConfirm.note_reject(host, cell, reason)
	keep_selected(host)


## Desktop (touch-confirm off) illegal empty tile. Mobile policy stays in
## BattleTouchConfirm.reject_invalid_tap, which the controller calls first.
static func reject_empty(host, cell: Vector2i) -> bool:
	if not _aiming(host):
		return false
	if BattleTouchConfirm.enabled():
		return false
	if bool(host.attack_mode):
		return false
	if host.move_cells.has(cell):
		return false
	if host.preview_move_cell.x >= 0 or int(host.preview_attack_ui) >= 0:
		return false
	if cell.x < 0:
		return false
	flash_destination(host, cell, "move")
	return true


static func draw_ranges(host, overlay) -> void:
	if overlay == null:
		return
	publish(host)
	if not _aiming(host):
		return
	var attack := shown_attack(host)
	var moves: Dictionary = host.move_cells if host.get("move_cells") is Dictionary else {}
	var origin: Vector2 = host.ORIGIN
	var cell := float(host.CELL)
	var pulse := 0.65 + 0.35 * sin(float(host._sel_pulse) * 5.0)
	for key in attack.keys():
		var pos: Vector2i = key
		var rect := Rect2(origin + Vector2(pos) * cell, Vector2(cell - 2.0, cell - 2.0))
		if moves.has(pos):
			overlay.draw_rect(rect.grow(-5.0), Color(UIKit.DANGER, 0.55 + 0.35 * pulse), false, 2.0)
		else:
			overlay.draw_rect(rect, Color(UIKit.DANGER, 0.22 + 0.12 * pulse))
			overlay.draw_rect(rect, Color(UIKit.DANGER, 0.75 + 0.2 * pulse), false, 2.5)


static func draw_illegal(host, overlay) -> void:
	if overlay == null:
		return
	var alpha := BattleTouchConfirm.reject_flash_alpha(host)
	if alpha <= 0.0:
		return
	var cell := BattleTouchConfirm.reject_flash_cell(host)
	if cell.x < 0:
		return
	var origin: Vector2 = host.ORIGIN
	var cell_px := float(host.CELL)
	var rect := Rect2(origin + Vector2(cell) * cell_px, Vector2(cell_px - 2.0, cell_px - 2.0))
	overlay.draw_rect(rect, Color(UIKit.DANGER, 0.50 * alpha))
	var center := rect.get_center()
	var radius := cell_px * lerpf(0.18, 0.78, 1.0 - alpha)
	overlay.draw_arc(center, radius, 0.0, TAU, 36, Color(UIKit.DANGER, 0.95 * alpha), 5.0)
	overlay.draw_arc(center, radius * 0.55, 0.0, TAU, 28, Color(1, 1, 1, 0.55 * alpha), 2.0)


static func _aiming(host) -> bool:
	if str(host.get("turn_team")) != "player":
		return false
	if bool(host.get("battle_over")):
		return false
	var ui := int(host.selected)
	if ui < 0 or ui >= host.units.size():
		return false
	var u = host.units[ui]
	if str(u.team) != "player" or bool(u.done) or int(u.char.hp) <= 0:
		return false
	return true


static func _on_living_figure(host, screen_pos: Vector2) -> bool:
	var cell_px := float(host.CELL)
	if cell_px < 1.0:
		return false
	var local: Vector2 = BattlePick._board_local(host, screen_pos)
	var origin: Vector2 = host.ORIGIN
	var lx: float = (local.x - origin.x) / cell_px
	var ly: float = (local.y - origin.y) / cell_px
	var half_w: float = BattlePick.contour_half_w()
	for u in host.units:
		if int(u.char.hp) <= 0:
			continue
		var ux := float(u.pos.x)
		var uy := float(u.pos.y)
		if lx < ux + 0.5 - half_w or lx > ux + 0.5 + half_w:
			continue
		if ly < uy + BattlePick.FIG_TOP or ly > uy + BattlePick.FIG_FEET:
			continue
		return true
	return false


## Clip only the part of the stage that actually sits in the unsafe band.
## A root already shifted by mobile_origin maps this inset into the safe rect,
## so the intersection stays put. A root left at the origin still loses the lip.
static func _clip_notch(host, inset: Rect2) -> Rect2:
	if not DeviceProfile.is_mobile():
		return inset
	if not (host is CanvasItem):
		return inset
	var item := host as CanvasItem
	if not item.is_inside_tree():
		return inset
	# Headless CI can keep a stale global transform after position/mobile_origin
	# were intentionally moved; refresh before any origin / xform read.
	item.force_update_transform()
	var vp := item.get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	# CK_SAFE_INSETS is authored in the sized-root (viewport) space. Suites and
	# shots set the root size; parallel CI headless often reports a non-zero but
	# wrong DisplayServer window, which scales the notch into empty intersection
	# and silently skips the clip. Prefer viewport whenever the sim env is set.
	# On device CK_SAFE_INSETS is empty — real window + get_display_safe_area win.
	var sim := OS.get_environment("CK_SAFE_INSETS") != ""
	if sim and vp.x >= 2.0 and vp.y >= 2.0:
		win = vp
	elif win.x < 2.0 or win.y < 2.0:
		win = vp
	if win.x < 2.0 or win.y < 2.0:
		return _clip_notch_sim(host, inset) if sim else inset
	var safe := DeviceProfile.safe_area(win)
	var sx := vp.x / win.x
	var sy := vp.y / win.y
	var safe_vp := Rect2(safe.position.x * sx, safe.position.y * sy, safe.size.x * sx, safe.size.y * sy)
	var xform := _host_xform_for_clip(host, item)
	var shown := _norm_rect(xform * inset.position, xform * inset.end)
	var clipped := shown.intersection(safe_vp)
	if clipped.size.x < 64.0 or clipped.size.y < 64.0:
		return _clip_notch_sim(host, inset) if sim else inset
	var inv := xform.affine_inverse()
	var local := _norm_rect(inv * clipped.position, inv * clipped.end)
	var both := inset.intersection(local)
	if both.size.x < 64.0 or both.size.y < 64.0:
		return _clip_notch_sim(host, inset) if sim else inset
	return both


## Algebraic notch clip for CK_SAFE_INSETS suites when transform×safe
## intersection collapses in headless CI. Host already shifted by mobile_origin
## has origin_g.x ≈ left inset → need=0 (no double count). Origin at 0 still
## loses the lip.
static func _clip_notch_sim(host, inset: Rect2) -> Rect2:
	var sim := OS.get_environment("CK_SAFE_INSETS")
	if sim == "":
		return inset
	var parts := sim.split(",")
	if parts.size() != 4:
		return inset
	if not (host is CanvasItem) or not (host as CanvasItem).is_inside_tree():
		return inset
	var item := host as CanvasItem
	item.force_update_transform()
	var origin_g: Vector2 = _host_origin_for_clip(host, item)
	var left := maxf(0.0, float(parts[0]) - origin_g.x)
	var top := maxf(0.0, float(parts[1]) - origin_g.y)
	var vp := item.get_viewport().get_visible_rect().size
	var right_limit := vp.x - float(parts[2]) - origin_g.x
	var bottom_limit := vp.y - float(parts[3]) - origin_g.y
	var out := inset
	if left > 0.5:
		var x0 := maxf(out.position.x, left)
		out = Rect2(Vector2(x0, out.position.y), Vector2(maxf(0.0, out.end.x - x0), out.size.y))
	if top > 0.5:
		var y0 := maxf(out.position.y, top)
		out = Rect2(Vector2(out.position.x, y0), Vector2(out.size.x, maxf(0.0, out.end.y - y0)))
	if vp.x >= 2.0 and right_limit + 0.5 < out.end.x:
		out.size.x = maxf(0.0, right_limit - out.position.x)
	if vp.y >= 2.0 and bottom_limit + 0.5 < out.end.y:
		out.size.y = maxf(0.0, bottom_limit - out.position.y)
	if out.size.x < 64.0 or out.size.y < 64.0:
		return inset
	return out


## Authored local offset for notch math. Prefer position when it agrees with
## mobile_origin; otherwise the meta (battle _process pins position to it).
static func _host_local_origin(host) -> Vector2:
	var local := Vector2.ZERO
	if host is Control:
		local = (host as Control).position
	elif host is Node2D:
		local = (host as Node2D).position
	if not host.has_meta("mobile_origin"):
		return local
	var meta = host.get_meta("mobile_origin")
	if not (meta is Vector2):
		return local
	var meta_o: Vector2 = meta
	# Suite / layout intentionally moved both; trust that pair.
	if local.distance_to(meta_o) <= 8.0:
		return local
	# _process may not have re-pinned position yet — meta is the source of truth.
	return meta_o


## Global origin used by algebraic sim. After force_update_transform, fall back
## to position / mobile_origin when global still shows a prior mobile shift
## (CI FAIL: left = notch - stale_400 → 0 → bare==raw).
static func _host_origin_for_clip(host, item: CanvasItem) -> Vector2:
	var origin_g: Vector2 = item.get_global_transform() * Vector2.ZERO
	var local := _host_local_origin(host)
	if origin_g.distance_to(local) > 8.0:
		return local
	return origin_g


## Transform for safe-area intersection. Same stale-global fallback as the sim:
## rebuild a translation from the authored local origin when global lags.
static func _host_xform_for_clip(host, item: CanvasItem) -> Transform2D:
	var xform := item.get_global_transform()
	var origin_g: Vector2 = xform * Vector2.ZERO
	var local := _host_local_origin(host)
	if origin_g.distance_to(local) <= 8.0:
		return xform
	var fixed := xform
	fixed.origin = local
	return fixed


static func _norm_rect(a: Vector2, b: Vector2) -> Rect2:
	var pos := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	return Rect2(pos, Vector2(absf(b.x - a.x), absf(b.y - a.y)))


static func _apply_pan(host, target: Vector2) -> Vector2:
	var saved: Vector2 = host._board_pan
	host._board_pan = target
	if host.has_method("_clamp_board_pan"):
		host._clamp_board_pan()
	var clamped: Vector2 = host._board_pan
	host._board_pan = saved
	var applied: Vector2 = clamped - saved
	if applied.length_squared() < 0.25:
		return Vector2.ZERO
	BattlePick._apply_focus_pan(host, clamped, true)
	return applied
