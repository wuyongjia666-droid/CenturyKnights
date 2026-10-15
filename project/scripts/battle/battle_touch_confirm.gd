class_name BattleTouchConfirm
extends RefCounted
## Mobile touch-confirm helpers. Kept out of battle_controller to stay under the line cap.

static func enabled() -> bool:
	if not (GameState.settings is Dictionary):
		return DeviceProfile.is_mobile()
	if GameState.settings.has("touch_confirm"):
		return bool(GameState.settings["touch_confirm"])
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

static func draw_preview(host) -> void:
	var overlay = host.overlay
	var origin: Vector2 = host.ORIGIN
	var cell: int = int(host.CELL)
	if host.preview_move_cell.x >= 0 and host.selected >= 0 and host.selected < host.units.size():
		var gp: Vector2 = origin + Vector2(host.preview_move_cell) * cell
		var gr := Rect2(gp, Vector2(cell - 2, cell - 2))
		overlay.draw_rect(gr, Color(UIKit.ACCENT, 0.22))
		overlay.draw_rect(gr, Color(UIKit.ACCENT, 0.95), false, 3.0)
		var gsu = host.units[host.selected]
		var gcenter: Vector2 = gp + Vector2(cell, cell) * 0.5
		UnitArt.draw_token_on(overlay, gcenter, gsu.char, "player", float(cell) * 0.36, false)
		overlay.draw_circle(gcenter, float(cell) * 0.40, Color(UIKit.ACCENT, 0.18))
	if int(host.preview_attack_ui) >= 0 and int(host.preview_attack_ui) < host.units.size():
		var ap: Vector2i = host.units[host.preview_attack_ui].pos
		var ar := Rect2(origin + Vector2(ap) * cell, Vector2(cell - 2, cell - 2))
		overlay.draw_rect(ar, Color(UIKit.DANGER, 0.28))
		overlay.draw_rect(ar, Color(UIKit.DANGER, 0.95), false, 3.0)
