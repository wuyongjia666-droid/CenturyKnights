class_name BattleTouchConfirm
extends RefCounted
## Mobile touch-confirm helpers. Kept out of battle_controller to stay under the line cap.
##
## Y1-A T-P0-3: louder preview rings; drag-to-cell release can commit when
## settings.touch_drag_commit is on (default true on mobile). Confirm buttons
## stay on the thumb rail via BattleMobileBar.

static func enabled() -> bool:
	if not (GameState.settings is Dictionary):
		return DeviceProfile.is_mobile()
	if GameState.settings.has("touch_confirm"):
		return bool(GameState.settings["touch_confirm"])
	return DeviceProfile.is_mobile()


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
	if host.overlay:
		host.overlay.queue_redraw()
	ForecastPanel.refresh(host)


static func confirm_move(host) -> void:
	if host.preview_move_cell.x < 0 or host.selected < 0 or host.selected >= host.units.size():
		clear(host)
		return
	var cell: Vector2i = host.preview_move_cell
	clear(host)
	commit_move(host, cell)
	BattlePick.focus_cell(host, cell)


static func confirm_attack(host) -> void:
	var ui: int = int(host.preview_attack_ui)
	clear(host)
	if host.selected < 0 or ui < 0 or ui >= host.units.size():
		return
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


## Y1-A T-P1-2: decide once per gesture (keyed by the press origin) whether a drag is
## "move the selected unit" or "pan the map". Only a drag whose press landed on the
## selected player unit (soft pick, SOFT_R) is a unit drag; everything else pans and
## never commits on release. Pinch fingers ("multi") are always pans.
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
	return BattlePick.resolve(host, origin) == su.pos


## While dragging with a selected unit, ghost the legal landing cell under the finger.
static func on_drag(host, screen_pos: Vector2) -> void:
	if not drag_commit_enabled() or not enabled():
		return
	if host.selected < 0 or host.selected >= host.units.size():
		return
	var su = host.units[host.selected]
	if su.team != "player" or su.done:
		return
	var cell: Vector2i = BattlePick.resolve(host, screen_pos)
	if cell.x < 0:
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
	var cell: Vector2i = BattlePick.resolve(host, screen_pos)
	if cell.x < 0:
		return false
	var ui: int = host._unit_at(cell)
	if host.attack_mode or int(host.preview_attack_ui) >= 0:
		if ui >= 0 and str(host.units[ui].team) == "enemy" and host.units[ui].char.hp > 0 and host._can_attack_from(su, cell):
			host.preview_attack_ui = ui
			confirm_attack(host)
			return true
	if ui < 0 and not host.moved_this_select and host.move_cells.has(cell):
		host.preview_move_cell = cell
		confirm_move(host)
		return true
	return false


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
		var ap: Vector2i = host.units[host.preview_attack_ui].pos
		var ar := Rect2(origin + Vector2(ap) * cell, Vector2(cell - 2, cell - 2))
		overlay.draw_rect(ar, Color(UIKit.DANGER, 0.36))
		overlay.draw_rect(ar, Color(UIKit.DANGER, 1.0), false, 5.0)
		overlay.draw_rect(ar.grow(-3.0), Color(1, 1, 1, 0.45), false, 2.0)
