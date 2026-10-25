class_name BattleTouchConfirm
extends RefCounted
## Mobile touch-confirm helpers. Kept out of battle_controller to stay under the line cap.
##
## Y1-A T-P0-3: louder preview rings; drag-to-cell release can commit when
## settings.touch_drag_commit is on (default true on mobile). Confirm buttons
## stay on the thumb rail via BattleMobileBar.
## Y1-A T-P1-4: move/place drag uses exact finger cell; attack still soft-resolves.
## Leaving a legal cell clears the stale ghost; illegal release clears preview.
## Y1-A T-P2: re-tap selected / empty-board deselect (no right-click on phone).
## Y1-A T-P3: unit-drag origin is strict figure hit (exact/bias/contour); soft-empty
## beside the selected piece pans the map instead of stealing the gesture.
## Y1-A T-P4: soft-follow settles on confirm/select (not mid unit-drag — keeps pan!=drag);
## attack ghost gets aim line + pulse juice.
## Y1-A T-P6: confirm_attack stamps m_attack_confirm_msec for settle juice path.
## Y1-A T-P5: select-lock on try_deselect; clear() re-focuses selection after cancel;
## invalid-target reject pulse lives here (keeps battle_controller under the line gate).

static func enabled() -> bool:
	if not (GameState.settings is Dictionary):
		return DeviceProfile.is_mobile()
	if GameState.settings.has("touch_confirm"):
		return bool(GameState.settings["touch_confirm"])
	return DeviceProfile.is_mobile()



## T-P2 mobile: re-tap the selected ally OR tap empty board (no preview / not attack)
## deselects — phones have no right-click cancel. Pure policy + host cancel.
static func try_deselect(host, ui: int) -> bool:
	if not enabled():
		return false
	if host.selected < 0 or host.selected >= host.units.size():
		return false
	# T-P5: ignore re-tap / empty deselect during the post-select lock window so a
	# fat-finger double-tap does not undo the select that just landed.
	if BattlePick.select_lock_active(host):
		return false
	if ui == host.selected:
		host._cancel_selection()
		return true
	if ui < 0 and not host.attack_mode and host.preview_move_cell.x < 0 and int(host.preview_attack_ui) < 0:
		host._cancel_selection()
		return true
	return false


## T-P5: illegal empty / out-of-range tap while a player piece is selected.
## Stamps a short reject flash + trauma nudge; keeps selection (does not deselect).
## Returns true when the tap was handled as a reject.
static func reject_invalid_tap(host, cell: Vector2i) -> bool:
	if not enabled():
		return false
	if host.selected < 0 or host.selected >= host.units.size():
		return false
	var su = host.units[host.selected]
	if str(su.team) != "player" or bool(su.done):
		return false
	# Preview already latched — clear path owns those taps.
	if host.preview_move_cell.x >= 0 or int(host.preview_attack_ui) >= 0:
		return false
	if bool(host.attack_mode):
		note_reject(host, cell, "attack")
		return true
	if host.move_cells.has(cell):
		return false
	note_reject(host, cell, "move")
	return true


static func note_reject(host, cell: Vector2i, reason: String = "move") -> void:
	host.set_meta("m_reject_flash", {"cell": cell, "msec": Time.get_ticks_msec(), "reason": reason})
	# Trauma nudge (BattleController / suite duck declare _shake).
	host._shake = maxf(float(host._shake), 0.55)
	var key := "ux_invalid_attack_tap" if reason == "attack" else "ux_invalid_move_tap"
	if host.has_method("_log"):
		host._log(Locale.t(key))
	if host.overlay:
		host.overlay.queue_redraw()


static func reject_flash_alpha(host, now_msec: int = -1) -> float:
	if not host.has_meta("m_reject_flash"):
		return 0.0
	var info = host.get_meta("m_reject_flash")
	if not (info is Dictionary):
		return 0.0
	var t0: int = int(info.get("msec", 0))
	var now: int = Time.get_ticks_msec() if now_msec < 0 else now_msec
	var elapsed: float = float(now - t0) / 1000.0
	if elapsed < 0.0 or elapsed >= 0.42:
		return 0.0
	return 1.0 - (elapsed / 0.42)


static func reject_flash_cell(host) -> Vector2i:
	if not host.has_meta("m_reject_flash"):
		return Vector2i(-1, -1)
	var info = host.get_meta("m_reject_flash")
	if not (info is Dictionary):
		return Vector2i(-1, -1)
	return info.get("cell", Vector2i(-1, -1))


static func draw_reject_flash(host, overlay) -> void:
	var a: float = reject_flash_alpha(host)
	if a <= 0.0 or overlay == null:
		return
	var cell: Vector2i = reject_flash_cell(host)
	if cell.x < 0:
		return
	var origin: Vector2 = host.ORIGIN
	var cell_px: float = float(host.CELL)
	var r := Rect2(origin + Vector2(cell) * cell_px, Vector2(cell_px - 2.0, cell_px - 2.0))
	overlay.draw_rect(r, Color(UIKit.DANGER, 0.22 * a))
	overlay.draw_rect(r, Color(UIKit.DANGER, 0.85 * a), false, 2.5)


## Drag finger to a legal cell / enemy and release to commit (skips the extra bar tap).
## Default on for mobile; respects an explicit settings key when present.
static func drag_commit_enabled() -> bool:
	if not (GameState.settings is Dictionary):
		return DeviceProfile.is_mobile()
	if GameState.settings.has("touch_drag_commit"):
		return bool(GameState.settings["touch_drag_commit"])
	return DeviceProfile.is_mobile()


static func clear(host) -> void:
	host.preview_move_cell = Vector2i(-1, -1)
	host.preview_attack_ui = -1
	if DeviceProfile.is_mobile():
		BattleMobileBar.rebuild(host)
		# T-P5: cancelling a preview keeps the piece selected — settle camera on it.
		if host.selected >= 0:
			BattlePick.focus_selected(host)
	if host.overlay:
		host.overlay.queue_redraw()
	ForecastPanel.refresh(host)


static func confirm_move(host) -> void:
	if host.preview_move_cell.x < 0 or host.selected < 0 or host.selected >= host.units.size():
		clear(host)
		return
	var cell: Vector2i = host.preview_move_cell
	# T-P4 soft-follow settles on confirm (never mid unit-drag — pan!=drag contract).
	BattlePick.focus_follow_preview(host)
	clear(host)
	commit_move(host, cell)
	BattlePick.focus_cell(host, cell)


static func confirm_attack(host) -> void:
	var ui: int = int(host.preview_attack_ui)
	# T-P4 soft-follow settles on confirm (never mid unit-drag — pan!=drag contract).
	if ui >= 0:
		BattlePick.focus_follow_preview(host)
	clear(host)
	if host.selected < 0 or ui < 0 or ui >= host.units.size():
		return
	# T-P6: confirm→hit settle path — stamp confirm; resolve refreshes hit/miss/kill juice.
	host.set_meta("m_attack_confirm_msec", Time.get_ticks_msec())
	host._do_attack(host.selected, ui)
	if ui < host.units.size() and host.units[ui].char.hp > 0:
		BattlePick.focus_cell(host, host.units[ui].pos)


static func overflow_menu(host) -> void:
	var popup := PopupMenu.new()
	popup.name = "MobileOverflow"
	popup.add_item(Locale.t("shell_4d0b4688"), 0)  # cancel
	popup.add_item(Locale.t("ux_end_turn_ask"), 1)
	host.add_child(popup)
	popup.id_pressed.connect(func(id: int):
		if id == 0:
			host._cancel_selection()
		elif id == 1:
			request_end_turn(host)
		popup.queue_free()
	)
	popup.popup_hide.connect(func(): popup.queue_free())
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	popup.position = Vector2i(int(vp.x * 0.5 - 80), int(vp.y - host._command_bar_px() - 140))
	popup.popup()


static func request_end_turn(host) -> void:
	## Two-step end-turn so a fat-finger tap cannot skip the player phase.
	if host.battle_over:
		return
	if not DeviceProfile.is_mobile():
		host._end_player_turn()
		return
	var old: Node = host.get_node_or_null("EndTurnConfirm")
	if old:
		old.queue_free()
	var dlg := ConfirmationDialog.new()
	dlg.name = "EndTurnConfirm"
	dlg.title = Locale.t("ux_end_turn_title")
	dlg.dialog_text = Locale.t("ux_end_turn_body")
	dlg.ok_button_text = Locale.t("ux_end_turn_yes")
	dlg.get_cancel_button().text = Locale.t("shell_4d0b4688")
	host.add_child(dlg)
	dlg.confirmed.connect(func():
		dlg.queue_free()
		host._end_player_turn()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.close_requested.connect(func(): dlg.queue_free())
	dlg.popup_centered()


static func commit_move(host, cell: Vector2i) -> void:
	if host.selected < 0 or host.selected >= host.units.size():
		return
	var su = host.units[host.selected]
	if su.team != "player" or su.done or host.moved_this_select:
		return
	if not host.move_cells.has(cell):
		return
	host._move_undo = BattleSnapshot.capture(host)
	var origin_cell: Vector2i = su.pos
	su.pos = cell
	host._spend_zoc(su, origin_cell, cell)
	host.moved_this_select = true
	Sfx.play_footstep(str(host.terrain[cell.y][cell.x]))
	host.move_cells.clear()
	host._spawn_move_dust(cell)
	host._refresh_info()
	host.map_draw.queue_redraw()
	host.overlay.queue_redraw()
	host._log(Locale.t("ux_moved_to_log") % [su.char.name, cell.x, cell.y])
	host._sync_objectives()
	RewindBar.refresh(host)
	if DeviceProfile.is_mobile():
		BattleMobileBar.rebuild(host)


## Y1-A T-P1-2 / T-P3: decide once per gesture (keyed by the press origin) whether a
## drag is "move the selected unit" or "pan the map". Only a press that strictly hits
## the selected player figure (exact / face bias / contour — not soft-empty neighbour)
## is a unit drag; soft-empty beside the piece pans and never commits. Pinch ("multi")
## is always a pan.
static func is_unit_drag(host, g: Dictionary) -> bool:
	if bool(g.get("multi", false)) or not g.has("origin"):
		return false
	var origin: Vector2 = g.get("origin", Vector2.ZERO)
	if host.has_meta("drag_origin") and host.get_meta("drag_origin") == origin:
		return bool(host.get_meta("drag_unit", false))
	var unit := _press_on_selected(host, origin)
	host.set_meta("drag_origin", origin)
	host.set_meta("drag_unit", unit)
	return unit


static func end_gesture(host) -> void:
	for k in ["drag_origin", "drag_unit"]:
		if host.has_meta(k):
			host.remove_meta(k)


static func _press_on_selected(host, origin: Vector2) -> bool:
	if not drag_commit_enabled() or not enabled():
		return false
	if host.turn_team != "player" or host.battle_over or host._cut_playing:
		return false
	if host.selected < 0 or host.selected >= host.units.size():
		return false
	var su = host.units[host.selected]
	if su.team != "player" or su.done:
		return false
	if host.moved_this_select and not host.attack_mode:
		return false
	# T-P3: soft-empty beside selected must pan — only exact/bias/contour arms unit-drag.
	return BattlePick.strict_hits_selected(host, origin, host.selected)



## T-P1-4: land cell under a unit-drag finger.
## Move/place → exact cell (soft-pick must not steal empty landings beside units).
## Attack → soft resolve so fat-finger can latch onto an enemy.
static func drag_land_cell(host, screen_pos: Vector2) -> Vector2i:
	if host.attack_mode or int(host.preview_attack_ui) >= 0:
		return BattlePick.resolve(host, screen_pos)
	return host._pointer_to_cell(screen_pos)


## Drop a stale move/attack ghost when the finger leaves a legal landing.
static func _clear_stale_preview(host) -> void:
	if host.preview_move_cell.x < 0 and int(host.preview_attack_ui) < 0:
		return
	host.preview_move_cell = Vector2i(-1, -1)
	host.preview_attack_ui = -1
	if DeviceProfile.is_mobile():
		BattleMobileBar.rebuild(host)
	if host.overlay:
		host.overlay.queue_redraw()
	ForecastPanel.refresh(host)


## While dragging with a selected unit, ghost the legal landing cell under the finger.
static func on_drag(host, screen_pos: Vector2) -> void:
	if not drag_commit_enabled() or not enabled():
		return
	if host.selected < 0 or host.selected >= host.units.size():
		return
	var su = host.units[host.selected]
	if su.team != "player" or su.done:
		return
	var cell: Vector2i = drag_land_cell(host, screen_pos)
	if cell.x < 0:
		_clear_stale_preview(host)
		return
	var ui: int = host._unit_at(cell)
	if host.attack_mode and ui >= 0 and str(host.units[ui].team) == "enemy" and host.units[ui].char.hp > 0:
		if host._can_attack_from(su, cell):
			host.preview_attack_ui = ui
			host.preview_move_cell = Vector2i(-1, -1)
			if DeviceProfile.is_mobile():
				BattleMobileBar.rebuild(host)
			if host.overlay:
				host.overlay.queue_redraw()
			ForecastPanel.refresh(host)
			# T-P4: do not soft-follow mid unit-drag (mobile_safe_area: unit drag must not pan).
			# Camera settles on confirm_attack / focus_selected instead.
		else:
			_clear_stale_preview(host)
		return
	if ui < 0 and not host.attack_mode and not host.moved_this_select and host.move_cells.has(cell):
		if host.preview_move_cell == cell:
			return
		host.preview_move_cell = cell
		host.preview_attack_ui = -1
		if DeviceProfile.is_mobile():
			BattleMobileBar.rebuild(host)
		if host.overlay:
			host.overlay.queue_redraw()
		# T-P4: soft-follow deferred to confirm_move (unit drag must not pan the board).
		return
	# Finger left a legal landing — drop the ghost so release cannot surprise-commit.
	_clear_stale_preview(host)


## Finger-up after a pan: commit preview / legal cell under the finger when drag-commit is on.
static func on_drag_end(host, screen_pos: Vector2) -> bool:
	if not drag_commit_enabled() or not enabled():
		return false
	if host.turn_team != "player" or host.battle_over or host._cut_playing:
		return false
	if host.selected < 0 or host.selected >= host.units.size():
		return false
	var su = host.units[host.selected]
	if su.team != "player" or su.done:
		return false
	var cell: Vector2i = drag_land_cell(host, screen_pos)
	if cell.x < 0:
		_clear_stale_preview(host)
		return false
	var ui: int = host._unit_at(cell)
	if host.attack_mode or int(host.preview_attack_ui) >= 0:
		if ui >= 0 and str(host.units[ui].team) == "enemy" and host.units[ui].char.hp > 0 and host._can_attack_from(su, cell):
			host.preview_attack_ui = ui
			confirm_attack(host)
			return true
		_clear_stale_preview(host)
		return false
	if ui < 0 and not host.moved_this_select and host.move_cells.has(cell):
		host.preview_move_cell = cell
		confirm_move(host)
		return true
	# Illegal release: clear ghost so the bar does not keep a dead Confirm.
	_clear_stale_preview(host)
	return false


## T-P4 attack ghost chrome. `pulse` in [0,1] (typically 0.55+0.45*sin).
static func attack_preview_juice(cell_px: float, pulse: float) -> Dictionary:
	var p: float = clampf(pulse, 0.0, 1.0)
	return {
		"fill_a": 0.36,
		"ring_r": cell_px * (0.50 + 0.04 * p),
		"ring_w": 3.0,
		"halo_r": cell_px * 0.30,
		"halo_a": 0.55 + 0.35 * p,
		"aim_a": 0.50 + 0.30 * p,
		"aim_w": 2.5,
		"chev_len": cell_px * 0.22,
	}


static func attack_preview_pulse() -> float:
	return 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) * 0.006)


static func draw_preview(host) -> void:
	var overlay = host.overlay
	var origin: Vector2 = host.ORIGIN
	var cell: int = int(host.CELL)
	if host.preview_move_cell.x >= 0 and host.selected >= 0 and host.selected < host.units.size():
		var gp: Vector2 = origin + Vector2(host.preview_move_cell) * cell
		var gr := Rect2(gp, Vector2(cell - 2, cell - 2))
		# T-P0-3: thicker, brighter preview so the landing cell reads at a glance.
		overlay.draw_rect(gr, Color(UIKit.ACCENT, 0.34))
		overlay.draw_rect(gr, Color(UIKit.ACCENT, 1.0), false, 5.0)
		overlay.draw_rect(gr.grow(-3.0), Color(1, 1, 1, 0.55), false, 2.0)
		var gsu = host.units[host.selected]
		var gcenter: Vector2 = gp + Vector2(cell, cell) * 0.5
		UnitArt.draw_token_on(overlay, gcenter, gsu.char, "player", float(cell) * 0.36, false)
		overlay.draw_circle(gcenter, float(cell) * 0.44, Color(UIKit.ACCENT, 0.22))
		overlay.draw_arc(gcenter, float(cell) * 0.46, 0.0, TAU, 48, Color(UIKit.ACCENT, 0.95), 2.5)
	if int(host.preview_attack_ui) >= 0 and int(host.preview_attack_ui) < host.units.size():
		var aui: int = int(host.preview_attack_ui)
		var ap: Vector2i = host.units[aui].pos
		var ar := Rect2(origin + Vector2(ap) * cell, Vector2(cell - 2, cell - 2))
		var juice: Dictionary = attack_preview_juice(float(cell), attack_preview_pulse())
		overlay.draw_rect(ar, Color(UIKit.DANGER, float(juice.fill_a)))
		overlay.draw_rect(ar, Color(UIKit.DANGER, 1.0), false, 5.0)
		overlay.draw_rect(ar.grow(-3.0), Color(1, 1, 1, 0.45), false, 2.0)
		var acenter: Vector2 = origin + Vector2(ap) * float(cell) + Vector2(cell, cell) * 0.5
		# Mid-figure halo + pulsing ring (mirrors selection chrome on the defender).
		var chest: Vector2 = acenter + Vector2(0.0, float(cell) * BattlePick.FIG_TOP * 0.5)
		overlay.draw_circle(acenter, float(juice.ring_r), Color(UIKit.DANGER, 0.16))
		overlay.draw_arc(acenter, float(juice.ring_r), 0.0, TAU, 48, Color(UIKit.DANGER, 0.95), float(juice.ring_w))
		overlay.draw_arc(chest, float(juice.halo_r), 0.0, TAU, 32, Color(UIKit.DANGER, float(juice.halo_a)), 2.0)
		# Aim line + chevron from attacker feet toward the target.
		if host.selected >= 0 and host.selected < host.units.size():
			var from: Vector2 = origin + Vector2(host.units[host.selected].pos) * float(cell) + Vector2(cell, cell) * 0.5
			var col := Color(UIKit.DANGER, float(juice.aim_a))
			overlay.draw_line(from, acenter, col, float(juice.aim_w), true)
			var dir: Vector2 = acenter - from
			if dir.length_squared() > 1.0:
				dir = dir.normalized()
				var tip: Vector2 = acenter - dir * float(cell) * 0.32
				var ortho := Vector2(-dir.y, dir.x) * float(juice.chev_len) * 0.55
				var back: Vector2 = tip - dir * float(juice.chev_len)
				overlay.draw_line(tip, back + ortho, col, float(juice.aim_w), true)
				overlay.draw_line(tip, back - ortho, col, float(juice.aim_w), true)
