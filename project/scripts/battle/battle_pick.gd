class_name BattlePick
extends RefCounted
## Soft hit-test for fat-finger taps. Prefer the nearest living unit when the
## finger lands near a cell edge or slightly off the token.
##
## Y1-A T-P0-2: SOFT_R raised from 0.62 → 0.90 so eccentric fat-finger taps on
## a neighbouring empty cell still resolve to the unit.
## Y1-A T-P1-2: pure pan/zoom → cell helpers for device-free contract tests.
## Y1-A T-P1-3: 3D figure visual bias — tap on empty cell above a unit's face/head
## snaps to that unit (FIG_CELLS=1.30, feet at 0.62 → y ∈ [FIG_TOP, FIG_FEET]).
## Y1-A T-P1-4: move/place drag lands on the exact finger cell (soft-pick must not
## steal empty legal landings beside living units).
## Y1-A T-P1-5: contour rect hit — fat finger on the figure body (not just cell centre /
## cell-above bias) still selects; tap-again confirm is in battle_controller.
## Y1-A T-P3: strict unit-drag origin (exact/bias/contour, not soft-empty) + selected-only sticky.
## Y1-A T-P4: smooth camera focus + margin follow for unit/preview; attack juice lives
## in BattleTouchConfirm (keeps battle_controller under the 3000-line gate).
## Y1-A T-P13: select / attack-pair framing lives in BattleCombatFrame. focus_cell
## stays desktop-inert unless force, so player phase lead does not pan.
## Y1-A T-P5: war-chess select feel — team-prefer soft+contour resolve in scrums;
## select-burst chrome; deselect lock; invalid-target reject pulse (via TouchConfirm).
## Y1-A T-P11: mobile chest/head of the unit below sticks past the occupant's feet.
## That strip is not the occupant's body — body_over_occupant returns the south unit.
## Desktop keeps the exact cell so mouse clicks do not move.
## Y1-A T-P24: board-tap resolve keeps empty exact cells (move/deselect) when soft/contour
## would only snap back onto the armed selected unit; sticky near_selected uses strict
## figure hit (not soft halo) so adjacent empty pans; portrait/info column must not steal.

## Fraction of a cell: anything closer than this counts as that unit.
const SOFT_R := 0.90
## 3D figure vertical span in cell units relative to the unit cell's top edge.
## Matches unit_layer_3d.FIG_CELLS (1.30) and board_units.feet_px (0.62).
const FIG_TOP := -0.68
const FIG_FEET := 0.62
## Y1-A T-P1-5: figure screen AABB in cell units (centred on the token column).
## Half-width 0.42 ≈ fat-finger on torso/arms without stealing the neighbour column.
## T-P2/T-P5: mobile widens past 0.5 so adjacent figure AABBs overlap under a fat
## finger (desktop stays 0.42) via contour_half_w(). Overlap lets prefer_team
## resolve scrum body taps; ≤0.50 left a gap between neighbours.
const CONTOUR_HALF_W := 0.42
const CONTOUR_HALF_W_MOBILE := 0.55


static func contour_half_w() -> float:
	return CONTOUR_HALF_W_MOBILE if DeviceProfile.is_mobile() else CONTOUR_HALF_W
## Y1-A T-P1-2: camera limits shared by pinch / wheel / pan (real transform, not just contracts).
const ZOOM_MIN := 0.65
const ZOOM_MAX := 2.4
## Board pixels that must stay inside the stage on every side after a pan.
const PAN_KEEP_PX := 64.0
## T-P4: smooth focus duration + stage inset fraction for soft follow nudges.
const FOCUS_SMOOTH_SEC := 0.22
const FOCUS_MARGIN_FRAC := 0.18
## Y1-A T-P5: select-burst window (seconds) + deselect lock (msec) after a fresh select.
## Y1-A T-P6: focus_cell(force) for enemy-turn / phase-lead follow on desktop+mobile.
const SELECT_BURST_SEC := 0.38
const SELECT_LOCK_MSEC := 280



## Clamp a board pan so at least PAN_KEEP_PX of the (zoomed) board stays inside stage.
static func clamp_pan(pan: Vector2, zoom: float, origin: Vector2, map_px: Vector2, stage: Rect2) -> Vector2:
	var z: float = zoom if zoom > 0.001 else 1.0
	var board: Vector2 = map_px * z
	var o: Vector2 = origin * z
	return Vector2(
		clampf(pan.x, stage.position.x + PAN_KEEP_PX - o.x - board.x, stage.end.x - PAN_KEEP_PX - o.x),
		clampf(pan.y, stage.position.y + PAN_KEEP_PX - o.y - board.y, stage.end.y - PAN_KEEP_PX - o.y))


## Zoom about focal (battle-local px): the board point under focal stays under it.
## Returns {"zoom", "pan"}; zoom is clamped to [ZOOM_MIN, ZOOM_MAX]. Pan is not clamped here.
static func zoom_about(pan: Vector2, zoom: float, factor: float, focal: Vector2) -> Dictionary:
	var old: float = zoom if zoom > 0.001 else 1.0
	var next: float = clampf(old * factor, ZOOM_MIN, ZOOM_MAX)
	return {"zoom": next, "pan": focal - (focal - pan) * (next / old)}


## Y1-A T-P1-2: pure pan/zoom invert (no Control / safe-area). screen_in_control is
## already in the battle root's local space (caller handles get_global_transform).
static func local_after_pan_zoom(screen_in_control: Vector2, pan: Vector2, zoom: float) -> Vector2:
	var z: float = zoom if zoom > 0.001 else 1.0
	return (screen_in_control - pan) / z


static func cell_at_local(origin: Vector2, cell_px: float, local: Vector2, map_w: int, map_h: int) -> Vector2i:
	if cell_px < 1.0:
		return Vector2i(-1, -1)
	var c := Vector2i(int((local.x - origin.x) / cell_px), int((local.y - origin.y) / cell_px))
	if c.x < 0 or c.y < 0 or c.x >= map_w or c.y >= map_h:
		return Vector2i(-1, -1)
	return c


## Algebra of focus_cell without a live host: pan delta that centres cell in stage
## (with the same left bias as focus_cell).
static func focus_pan_delta(origin: Vector2, cell_px_unscaled: float, cell: Vector2i, pan: Vector2, zoom: float, stage: Rect2) -> Vector2:
	var z: float = zoom if zoom > 0.001 else 1.0
	var cell_px: float = cell_px_unscaled * z
	var origin_z: Vector2 = origin * z
	var center: Vector2 = origin_z + Vector2(cell) * cell_px + Vector2(cell_px, cell_px) * 0.5
	var target: Vector2 = stage.get_center() + Vector2(-stage.size.x * 0.08, 0.0)
	return target - (center + pan)


## T-P4 soft follow: pan delta that pulls cell centre onto the stage inset edge when
## it sits outside; ZERO when already inside. Does not full-re-centre (unlike focus_pan_delta).
static func focus_nudge_delta(origin: Vector2, cell_px_unscaled: float, cell: Vector2i, pan: Vector2, zoom: float, stage: Rect2, margin_frac: float = FOCUS_MARGIN_FRAC) -> Vector2:
	var z: float = zoom if zoom > 0.001 else 1.0
	var cell_px: float = cell_px_unscaled * z
	var origin_z: Vector2 = origin * z
	var center: Vector2 = origin_z + Vector2(cell) * cell_px + Vector2(cell_px, cell_px) * 0.5
	var shown: Vector2 = center + pan
	var mx: float = stage.size.x * margin_frac
	var my: float = stage.size.y * margin_frac
	var inset := Rect2(stage.position + Vector2(mx, my), stage.size - Vector2(mx, my) * 2.0)
	if inset.size.x < cell_px or inset.size.y < cell_px:
		return focus_pan_delta(origin, cell_px_unscaled, cell, pan, zoom, stage)
	if inset.has_point(shown):
		return Vector2.ZERO
	var clamped_pt := Vector2(
		clampf(shown.x, inset.position.x, inset.end.x),
		clampf(shown.y, inset.position.y, inset.end.y))
	return clamped_pt - shown


## Pure lerp used by the focus tween (and by device-free contracts).
static func focus_pan_lerp(from: Vector2, to: Vector2, t: float) -> Vector2:
	return from.lerp(to, clampf(t, 0.0, 1.0))


## Prefer m_board_area meta; fall back to BOARD_AREA via duck get().
## Empty Rect2 when neither is present (device-free FakeHosts that skip focus).
static func _stage_rect(host) -> Rect2:
	if host.has_meta("m_board_area"):
		return host.get_meta("m_board_area")
	var stage = host.get("BOARD_AREA")
	if stage is Rect2:
		return stage
	return Rect2()


static func nearest_unit_pos(origin: Vector2, cell_px: float, units: Array, local: Vector2, soft_r: float = SOFT_R, prefer_team: String = "") -> Vector2i:
	if cell_px < 1.0:
		return Vector2i(-1, -1)
	var radius2 := (soft_r * cell_px) * (soft_r * cell_px)
	var best_i := -1
	var best_d2 := radius2
	var best_rank := 99
	for i in units.size():
		var u = units[i]
		if u.char.hp <= 0:
			continue
		var center: Vector2 = origin + Vector2(u.pos) * cell_px + Vector2(cell_px, cell_px) * 0.5
		var d2: float = center.distance_squared_to(local)
		if d2 > radius2:
			continue
		var rank := 1
		if prefer_team == "player":
			rank = 0 if str(u.team) == "player" else 1
		elif prefer_team == "foe":
			rank = 0 if str(u.team) != "player" else 1
		# Prefer team first, then closer centre (scrum soft-pick).
		if best_i < 0 or rank < best_rank or (rank == best_rank and d2 < best_d2):
			best_d2 = d2
			best_rank = rank
			best_i = i
	if best_i >= 0:
		return units[best_i].pos
	return Vector2i(-1, -1)



## Pure T-P1-4 policy: move/place drag always uses the exact finger cell.
## `soft` / `soft_has_living` document the failure mode tests prove — when soft-pick
## would have snapped onto a neighbouring unit, we still keep `exact`.
static func drag_move_cell(exact: Vector2i, soft: Vector2i, soft_has_living: bool) -> Vector2i:
	if exact.x < 0:
		return Vector2i(-1, -1)
	# soft_has_living + soft unused on purpose: callers pass them so suites can
	# assert soft would steal while exact remains the landing.
	if soft_has_living and soft.x >= 0 and soft != exact:
		return exact
	return exact


## Pure math T-P1-3: when finger_cell is empty and the cell below has a living
## unit whose 3D figure spans into finger_cell, return that unit's cell.
## Does not steal when finger_cell already has a unit (caller checks that).
static func visual_bias_unit_pos(origin: Vector2, cell_px: float, units: Array, local: Vector2, finger_cell: Vector2i) -> Vector2i:
	if cell_px < 1.0 or finger_cell.x < 0:
		return Vector2i(-1, -1)
	var below := Vector2i(finger_cell.x, finger_cell.y + 1)
	var living := false
	for u in units:
		if u.pos == below and u.char.hp > 0:
			living = true
			break
	if not living:
		return Vector2i(-1, -1)
	var rel_y: float = (local.y - origin.y) / cell_px - float(below.y)
	if rel_y < FIG_TOP or rel_y > FIG_FEET:
		return Vector2i(-1, -1)
	# Stay in the unit's column (finger already on the cell above).
	var rel_x: float = (local.x - origin.x) / cell_px - float(below.x)
	if rel_x < 0.0 or rel_x > 1.0:
		return Vector2i(-1, -1)
	return below



## Pure T-P1-5: finger inside a living unit's figure AABB (width 2*CONTOUR_HALF_W ×
## [FIG_TOP, FIG_FEET] relative to that unit's cell). Overlaps pick nearest feet.
## Does not steal when finger_cell already has a living unit (caller checks that).
static func contour_unit_pos(origin: Vector2, cell_px: float, units: Array, local: Vector2, prefer_team: String = "") -> Vector2i:
	if cell_px < 1.0:
		return Vector2i(-1, -1)
	var best_i := -1
	var best_d2 := INF
	var best_rank := 99
	var lx: float = (local.x - origin.x) / cell_px
	var ly: float = (local.y - origin.y) / cell_px
	for i in units.size():
		var u = units[i]
		if u.char.hp <= 0:
			continue
		var ux := float(u.pos.x)
		var uy := float(u.pos.y)
		var half_w: float = contour_half_w()
		if lx < ux + 0.5 - half_w or lx > ux + 0.5 + half_w:
			continue
		if ly < uy + FIG_TOP or ly > uy + FIG_FEET:
			continue
		var feet: Vector2 = origin + Vector2(u.pos) * cell_px + Vector2(cell_px * 0.5, cell_px * FIG_FEET)
		var d2: float = feet.distance_squared_to(local)
		var rank := 1
		if prefer_team == "player":
			rank = 0 if str(u.team) == "player" else 1
		elif prefer_team == "foe":
			rank = 0 if str(u.team) != "player" else 1
		# T-P5: overlapping body rects prefer the team the gesture cares about.
		if best_i < 0 or rank < best_rank or (rank == best_rank and d2 < best_d2):
			best_d2 = d2
			best_rank = rank
			best_i = i
	if best_i >= 0:
		return units[best_i].pos
	return Vector2i(-1, -1)


## Y1-A T-P3: strict figure hit for unit-drag / selected sticky.
## Exact cell, face bias, or contour — NOT soft-nearest on an empty neighbour.
## Soft-empty beside the selected piece must remain map-pan (drag/pan conflict).
static func strict_unit_pos(origin: Vector2, cell_px: float, units: Array, local: Vector2, finger_cell: Vector2i) -> Vector2i:
	if cell_px < 1.0:
		return Vector2i(-1, -1)
	if finger_cell.x >= 0:
		var occupied := false
		for u in units:
			if u.pos == finger_cell and u.char.hp > 0:
				occupied = true
				break
		if occupied:
			var body: Vector2i = body_over_occupant(origin, cell_px, units, local, finger_cell)
			if body.x >= 0:
				return body
			return finger_cell
	var bias: Vector2i = visual_bias_unit_pos(origin, cell_px, units, local, finger_cell)
	if bias.x >= 0:
		return bias
	return contour_unit_pos(origin, cell_px, units, local)


## True when finger strictly hits the selected living unit (T-P3 unit-drag origin).
static func strict_hits_selected(host, screen_pos: Vector2, selected_idx: int) -> bool:
	if selected_idx < 0 or selected_idx >= host.units.size():
		return false
	var su = host.units[selected_idx]
	if su.char.hp <= 0:
		return false
	var exact: Vector2i = host._pointer_to_cell(screen_pos)
	var local: Vector2 = _board_local(host, screen_pos)
	if strict_unit_pos(host.ORIGIN, float(host.CELL), host.units, local, exact) == su.pos:
		return true
	# T-P15: pressing the notch-lip sliver of the selected figure is still a unit drag.
	return BattleEdgePick.from_host(host, screen_pos, local) == su.pos


## T-P3 + T-P24: sticky slop only on the selected figure (strict exact/bias/contour/edge).
## Soft-empty beside the armed piece must stay a pan, not a fat sticky tap/deselect.
static func near_selected_unit(host, screen_pos: Vector2, selected_idx: int) -> bool:
	return strict_hits_selected(host, screen_pos, selected_idx)


static func resolve(host, screen_pos: Vector2) -> Vector2i:
	var exact: Vector2i = host._pointer_to_cell(screen_pos)
	var local: Vector2 = _board_local(host, screen_pos)
	if exact.x >= 0 and host._unit_at(exact) >= 0:
		# T-P11: mobile only — chest of the unit south of this cell, past the occupant's feet.
		var body: Vector2i = body_over_occupant(host.ORIGIN, float(host.CELL), host.units, local, exact)
		if body.x >= 0:
			return body
		return exact
	# T-P1-3 before soft-R: face/head taps land in the empty cell above the figure.
	var bias: Vector2i = visual_bias_unit_pos(host.ORIGIN, float(host.CELL), host.units, local, exact)
	if bias.x >= 0:
		return bias
	# T-P5: in a soft scrum, prefer the team the gesture cares about (player select /
	# enemy attack) so an overlapping foe does not steal the ally pick.
	var prefer := _resolve_prefer_team(host)
	var hit: Vector2i = nearest_unit_pos(host.ORIGIN, float(host.CELL), host.units, local, SOFT_R, prefer)
	if hit.x >= 0:
		return hit
	# T-P1-5/T-P5: figure body AABB; scrum overlap uses same team prefer as soft.
	var contour: Vector2i = contour_unit_pos(host.ORIGIN, float(host.CELL), host.units, local, prefer)
	if contour.x >= 0:
		return contour
	# T-P15: notch-lip crown / torso sliver. Interior taps stay on the contour.
	var edge: Vector2i = BattleEdgePick.from_host(host, screen_pos, local)
	if edge.x >= 0:
		return edge
	return exact


## Y1-A T-P24: board action taps (select / move preview / deselect). Soft+contour may
## still pick *other* living units from an empty exact cell, but must not yank that
## empty cell back onto the currently armed selected piece — that stole the near half
## of every adjacent move cell (SOFT_R=0.90 vs centre distance 1.0) and turned the
## soft halo into a deselect trap. Face bias / strict figure / notch-lip still keep
## the selected unit. Desktop and unarmed boards fall through to resolve().
static func resolve_board_tap(host, screen_pos: Vector2) -> Vector2i:
	var raw: Vector2i = resolve(host, screen_pos)
	if not DeviceProfile.is_mobile():
		return raw
	if host.selected < 0 or host.selected >= host.units.size():
		return raw
	var su = host.units[host.selected]
	if su.char.hp <= 0:
		return raw
	var exact: Vector2i = host._pointer_to_cell(screen_pos)
	if exact.x < 0:
		return raw
	# Occupied exact cell: body_over / inspect path already correct.
	if host._unit_at(exact) >= 0:
		return raw
	if raw != su.pos:
		return raw
	# Empty exact resolved onto selected — keep it unless the finger is truly on the figure.
	if strict_hits_selected(host, screen_pos, host.selected):
		return raw
	return exact


## T-P11 pure: finger in an occupied cell but below that occupant's feet (outside
## their figure AABB) and inside the living unit directly south. That band is the
## south figure's chest/head (FIG span crosses the cell edge). Same column only —
## a diagonal neighbour's fat contour must not steal. Desktop returns invalid so
## the exact cell stays the mouse hit. Invalid Vector2i(-1,-1) means "keep exact".
static func body_over_occupant(origin: Vector2, cell_px: float, units: Array, local: Vector2, finger_cell: Vector2i) -> Vector2i:
	if not DeviceProfile.is_mobile():
		return Vector2i(-1, -1)
	if cell_px < 1.0 or finger_cell.x < 0:
		return Vector2i(-1, -1)
	var occupied := false
	for u in units:
		if u.pos == finger_cell and u.char.hp > 0:
			occupied = true
			break
	if not occupied:
		return Vector2i(-1, -1)
	if _point_in_unit_contour(origin, cell_px, finger_cell, local):
		return Vector2i(-1, -1)
	var below := Vector2i(finger_cell.x, finger_cell.y + 1)
	for u in units:
		if u.pos != below or u.char.hp <= 0:
			continue
		if _point_in_unit_contour(origin, cell_px, below, local):
			return below
		return Vector2i(-1, -1)
	return Vector2i(-1, -1)


static func _point_in_unit_contour(origin: Vector2, cell_px: float, unit_pos: Vector2i, local: Vector2) -> bool:
	var lx: float = (local.x - origin.x) / cell_px
	var ly: float = (local.y - origin.y) / cell_px
	var half_w: float = contour_half_w()
	var ux := float(unit_pos.x)
	var uy := float(unit_pos.y)
	if lx < ux + 0.5 - half_w or lx > ux + 0.5 + half_w:
		return false
	if ly < uy + FIG_TOP or ly > uy + FIG_FEET:
		return false
	return true


## Mobile soft-resolve team preference. "" | "player" | "foe".
static func _resolve_prefer_team(host) -> String:
	if not DeviceProfile.is_mobile():
		return ""
	if bool(host.attack_mode):
		return "foe"
	return "player"


## True when a soft-pick would land on a living unit (used by InputRouter sticky_fn).
static func near_living_unit(host, screen_pos: Vector2) -> bool:
	var cell: Vector2i = resolve(host, screen_pos)
	if cell.x < 0:
		return false
	return host._unit_at(cell) >= 0


static func _board_local(host, screen_pos: Vector2) -> Vector2:
	return local_after_pan_zoom(host._screen_to_local(screen_pos), host._board_pan, host._board_zoom)


static func focus_cell(host, cell: Vector2i, smooth: bool = true, force: bool = false) -> void:
	# T-P6: `force` lets enemy-turn / phase-lead follow work on desktop too.
	if not force and not DeviceProfile.is_mobile():
		return
	if host.has_method("_in_bounds") and not host._in_bounds(cell):
		return
	var stage: Rect2 = _stage_rect(host)
	if stage.size.x < 1.0 or stage.size.y < 1.0:
		return
	var delta: Vector2 = focus_pan_delta(host.ORIGIN, float(host.CELL), cell, host._board_pan, host._board_zoom, stage)
	if delta.length_squared() < 0.25:
		return
	_apply_focus_pan(host, host._board_pan + delta, smooth)


## Soft-follow a cell so it stays inside the stage inset (preview drag / attack latch).
static func focus_follow_cell(host, cell: Vector2i) -> void:
	if not DeviceProfile.is_mobile():
		return
	if host.has_method("_in_bounds") and not host._in_bounds(cell):
		return
	var stage: Rect2 = _stage_rect(host)
	if stage.size.x < 1.0 or stage.size.y < 1.0:
		return
	var delta: Vector2 = focus_nudge_delta(host.ORIGIN, float(host.CELL), cell, host._board_pan, host._board_zoom, stage)
	if delta.length_squared() < 0.25:
		return
	_apply_focus_pan(host, host._board_pan + delta, true)


## Follow move-preview cell or attack-preview unit when either is latched.
static func focus_follow_preview(host) -> void:
	if host.preview_move_cell.x >= 0:
		focus_follow_cell(host, host.preview_move_cell)
		return
	var ui: int = int(host.preview_attack_ui)
	if ui >= 0 and ui < host.units.size():
		focus_follow_cell(host, host.units[ui].pos)


static func _apply_focus_pan(host, target_pan: Vector2, smooth: bool) -> void:
	var saved: Vector2 = host._board_pan
	host._board_pan = target_pan
	if host.has_method("_clamp_board_pan"):
		host._clamp_board_pan()
	var clamped: Vector2 = host._board_pan
	host._board_pan = saved
	if smooth and host is CanvasItem and (host as CanvasItem).is_inside_tree():
		_tween_board_pan(host, clamped)
		return
	cancel_focus_tween(host)
	host._board_pan = clamped
	if host.has_method("_apply_board_xform"):
		host._apply_board_xform()


## Kill an in-flight focus tween so a finger pan / unit-drag owns `_board_pan`.
static func cancel_focus_tween(host) -> void:
	if not host.has_meta("_ck_focus_tw"):
		return
	var prev = host.get_meta("_ck_focus_tw")
	if prev is Tween and is_instance_valid(prev):
		prev.kill()
	host.remove_meta("_ck_focus_tw")


static func _tween_board_pan(host, target: Vector2) -> void:
	cancel_focus_tween(host)
	var from: Vector2 = host._board_pan
	var tw: Tween = host.create_tween()
	host.set_meta("_ck_focus_tw", tw)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(p: Vector2) -> void:
		host._board_pan = p
		host._apply_board_xform()
	, from, target, FOCUS_SMOOTH_SEC)


## Stamp select-burst + deselect-lock clock (T-P5). Safe on duck hosts.
static func note_select_burst(host) -> void:
	host.set_meta("m_select_burst_msec", Time.get_ticks_msec())


## 1.0 → ~1.4 decaying over SELECT_BURST_SEC (pure; device-free).
static func select_burst_scale(host, now_msec: int = -1) -> float:
	if not host.has_meta("m_select_burst_msec"):
		return 1.0
	var t0: int = int(host.get_meta("m_select_burst_msec"))
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	var elapsed: float = float(now - t0) / 1000.0
	if elapsed < 0.0 or elapsed >= SELECT_BURST_SEC:
		return 1.0
	var u: float = 1.0 - (elapsed / SELECT_BURST_SEC)
	return 1.0 + 0.40 * u * u


## True while fat-finger double-tap should NOT undo a fresh select (T-P5).
static func select_lock_active(host, now_msec: int = -1) -> bool:
	if not host.has_meta("m_select_burst_msec"):
		return false
	var t0: int = int(host.get_meta("m_select_burst_msec"))
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	return (now - t0) < SELECT_LOCK_MSEC


static func focus_selected(host) -> void:
	if host.selected < 0 or host.selected >= host.units.size():
		return
	note_select_burst(host)
	# Mobile still attempts a centre. T-P13 cancels that yank when the figure
	# (head included) is already inside the play inset, and replaces it with the
	# minimum nudge when it is not. Desktop focus_cell is a no-op without force
	# so phase lead stays put; select follow goes through BattleCombatFrame.
	if DeviceProfile.is_mobile():
		focus_cell(host, host.units[host.selected].pos)
	BattleCombatFrame.follow_selected(host)
