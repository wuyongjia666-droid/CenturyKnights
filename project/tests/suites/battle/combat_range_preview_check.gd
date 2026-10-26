extends Node
## Y1-A T-P17: move/attack range preview, illegal-destination flash,
## and a camera that keeps the selected figure in the playable area.
## Algebra first, then a real battle on phone landscape (notch-safe) and desktop.
## Flow: select → show ranges → illegal tap flash → legal move confirm.
## Quits 1 on the first broken contract. No EmptyHost.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)
const NOTCH := "400,0,0,48"

var _battle: Control
var _player_i := -1
var _foe_i := -1
var _anchor := Vector2i(4, 3)
var _foe_cell := Vector2i(5, 3)
var _east := Vector2i(6, 3)


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL range preview: ", err)
		get_tree().quit(1)
		return
	print("COMBAT RANGE PREVIEW PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _algebra_keep()
	if err == "":
		err = _algebra_source()
	if err != "":
		return err
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	err = await _boot(true)
	if err == "":
		err = await _notch_clip_contract()
	if err == "":
		err = await _e2e_flow(true)
	if err == "":
		err = _drag_does_not_pan()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		return err
	if DeviceProfile.is_mobile():
		return "desktop flag did not clear"
	err = await _boot(false)
	if err == "":
		err = _desktop_inset_is_unclipped()
	if err == "":
		err = await _e2e_flow(false)
	if err == "":
		err = await _desktop_confirm_off_flash()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	return err


func _algebra_keep() -> String:
	var origin := Vector2.ZERO
	var cell_px := 64.0
	var inset := Rect2(0, 80, 500, 400)
	var primary := Vector2i(2, 2)
	var far := Vector2i(30, 2)
	var pan := Vector2.ZERO
	if not BattleCombatFrame.figure_inside(origin, cell_px, primary, pan, 1.0, inset, 1.0):
		return "algebra fixture: primary should start inside the inset"
	var joint := BattleCombatFrame.frame_delta(origin, cell_px, [primary, far], pan, 1.0, inset)
	if BattleCombatFrame.figure_inside(origin, cell_px, primary, pan + joint, 1.0, inset, 1.0):
		return "algebra fixture: oversized pair should center the selected unit out"
	var kept := BattleRangePreview.delta_keeping_primary(origin, cell_px, primary, [far], pan, 1.0, inset)
	if kept.length() > 1.0:
		return "far destination must not drag the selected unit, got %s" % kept
	if not BattleCombatFrame.figure_inside(origin, cell_px, primary, pan + kept, 1.0, inset, 1.0):
		return "keeping the primary ejected it"
	var shoved := Vector2(520, 0)
	var back := BattleRangePreview.delta_keeping_primary(origin, cell_px, primary, [], shoved, 1.0, inset)
	if back.x >= -1.0:
		return "primary parked to the right must pan left, got %s" % back
	if not BattleCombatFrame.figure_inside(origin, cell_px, primary, shoved + back, 1.0, inset, 2.0):
		return "primary-only delta did not bring the figure back"
	var near := Vector2i(3, 2)
	var both := BattleRangePreview.delta_keeping_primary(origin, cell_px, primary, [near], shoved, 1.0, inset)
	if not BattleCombatFrame.figure_inside(origin, cell_px, primary, shoved + both, 1.0, inset, 2.0):
		return "a nearby extra must not be allowed to eject the primary"
	return ""


func _algebra_source() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var preview := FileAccess.get_file_as_string("res://scripts/battle/battle_range_preview.gd")
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	if ctrl.split("\n").size() > 3000:
		return "battle_controller over 3000 lines"
	var has_tap_cell := ctrl.find("BattleRangePreview.tap_cell(self, pos, cell)") >= 0
	var has_board := ctrl.find("var cell := BattlePick.resolve_board_tap(self, pos)") >= 0
	var has_raw := ctrl.find("var cell := BattlePick.resolve(self, pos)") >= 0
	if not has_tap_cell or not (has_board or has_raw):
		return "tap still uses raw resolve for destinations"
	if ctrl.find("lp_cell := BattlePick.resolve(self, pos)") < 0:
		return "long-press resolve was removed"
	if ctrl.find("reject_invalid_tap") < 0 or ctrl.find("draw_reject_flash") < 0:
		return "mobile reject policy was dropped"
	if ctrl.find("BattleRangePreview.draw_ranges") < 0 or ctrl.find("BattleRangePreview.draw_illegal") < 0:
		return "range / illegal overlay not drawn"
	if ctrl.find("BattleRangePreview.keep_selected") < 0 or ctrl.find("BattleRangePreview.flash_destination") < 0:
		return "preview camera or illegal flash not wired"
	if ctrl.find("not force and not DeviceProfile.is_mobile()") >= 0:
		return "desktop focus_cell force gate was copied into the controller"
	if pick.find("not force and not DeviceProfile.is_mobile()") < 0:
		return "desktop focus_cell force gate was removed"
	if preview.find("EmptyHost") >= 0 or ctrl.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	if preview.find("month_echo") >= 0:
		return "month_echo residue forbidden"
	if preview.find("delta_keeping_primary") < 0 or preview.find("_clip_notch") < 0:
		return "keep-primary or notch clip missing"
	return ""


func _boot(mobile: bool) -> String:
	await _set_window(PHONE if mobile else DESK)
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
	GameState.settings["touch_confirm"] = true
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	if mobile:
		var insets := {"left": 400.0, "top": 0.0, "right": 0.0, "bottom": 48.0}
		var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
		# _process pins position to mobile_origin every frame. Without the meta,
		# apply_root's shift is wiped and the notch is counted twice.
		_battle.set_meta("mobile_origin", fitted.get("position", Vector2.ZERO))
		_battle.set_meta("mobile_insets", insets)
		MobileLayout.apply_root(_battle, fitted)
		if _battle.has_method("apply_mobile_layout"):
			_battle.apply_mobile_layout()
		await _settle(8)
		if not _battle._mobile_landscape():
			return "battle did not enter landscape"
	elif not _battle.has_meta("m_board_area"):
		return "desktop board stage missing"
	var arranged := _arrange()
	if arranged != "":
		return arranged
	await _settle(6)
	BattlePick.cancel_focus_tween(_battle)
	if not _battle.move_cells.has(_east):
		return "east tile %s not in move range (move %s count %s)" % [
			_east, _battle.units[_player_i].char.derived_move(), _battle.move_cells.size()]
	return ""


func _arrange() -> String:
	_player_i = -1
	_foe_i = -1
	if _battle.MAP_W < 7 or _battle.MAP_H < 4:
		_anchor = Vector2i(1, 1)
	else:
		_anchor = Vector2i(4, 3)
	_foe_cell = _anchor + Vector2i(1, 0)
	_east = _anchor + Vector2i(2, 0)
	if not _battle._in_bounds(_east):
		return "map too small for the range fixture %s" % _battle.MAP_W
	var extra_p := 0
	var extra_f := 0
	for i in _battle.units.size():
		var u = _battle.units[i]
		if str(u.team) == "player":
			if _player_i < 0:
				_player_i = i
				u.pos = _anchor
				u.done = false
				u.char.hp = maxi(int(u.char.hp), 8)
				u.char.temp_ignore_zoc = true
				u.char.set_meta("battle_move_mod", 8)
			else:
				extra_p += 1
				u.pos = Vector2i(0, mini(_battle.MAP_H - 1, extra_p))
				u.done = true
		elif str(u.team) == "enemy":
			if _foe_i < 0:
				_foe_i = i
				u.pos = _foe_cell
				u.char.hp = maxi(int(u.char.hp), 8)
			else:
				extra_f += 1
				u.pos = Vector2i(mini(_battle.MAP_W - 1, _anchor.x), mini(_battle.MAP_H - 1, extra_f + 1))
				u.char.hp = 0
	if _player_i < 0 or _foe_i < 0:
		return "deploy missing player/enemy"
	_plain_box(_anchor, 4)
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	_battle.attack_mode = false
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle._select_player(_player_i)
	if _battle.selected != _player_i:
		return "select did not stick"
	return ""


func _plain_box(origin: Vector2i, radius: int) -> void:
	for y in range(origin.y - radius, origin.y + radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			var cell := Vector2i(x, y)
			if not _battle._in_bounds(cell):
				continue
			_battle.terrain[cell.y][cell.x] = "plain"
			if cell.y >= 0 and cell.y < _battle.height_grid.size():
				var row: Array = _battle.height_grid[cell.y]
				if cell.x >= 0 and cell.x < row.size():
					row[cell.x] = 0


func _e2e_flow(mobile: bool) -> String:
	var err := await _e2e_ranges()
	if err == "":
		err = _e2e_hits()
	if err == "":
		err = await _e2e_preview_pull()
	if err == "":
		err = await _e2e_illegal()
	if err == "":
		err = _e2e_confirm()
	if err == "" and mobile and not _battle._mobile_landscape():
		return "left landscape during the flow"
	return err


func _e2e_ranges() -> String:
	var shown: Variant = _battle.get_meta("m_range_preview")
	if not (shown is Dictionary):
		return "select did not publish the range preview"
	if int(shown.get("move", 0)) < 2:
		return "move range not shown (%s)" % shown
	if int(shown.get("attack", 0)) < 1 or int(shown.get("attack_only", 0)) < 1:
		return "attack range not shown beside the move wash (%s)" % shown
	var attack: Dictionary = BattleRangePreview.shown_attack(_battle)
	if not attack.has(_foe_cell):
		return "foe %s missing from the attack ring" % _foe_cell
	if _battle.move_cells.has(_foe_cell):
		return "occupied foe was painted as a move tile"
	if _battle.overlay == null:
		return "battle overlay missing"
	return await _paint_preview()


func _e2e_hits() -> String:
	var body := _cell_local(_foe_cell, Vector2(0.5, 0.40))
	var body_screen := _screen(body)
	if BattleRangePreview.tap_cell(_battle, body_screen) != _foe_cell:
		return "chest tap left the foe figure"
	if BattlePick.resolve(_battle, body_screen) != _foe_cell:
		return "resolve no longer hits the foe chest"
	var soft_local := _cell_local(_east, Vector2(0.22, 0.50))
	var soft_screen := _screen(soft_local)
	var resolved: Vector2i = BattlePick.resolve(_battle, soft_screen)
	var aimed: Vector2i = BattleRangePreview.tap_cell(_battle, soft_screen)
	if resolved != _foe_cell:
		return "soft pick did not steal %s toward the foe (got %s)" % [_east, resolved]
	if aimed != _east:
		return "painted move tile was still stolen (aimed %s)" % aimed
	return ""


func _e2e_preview_pull() -> String:
	var parked := _park_right(_battle.units[_player_i].pos)
	if parked != "":
		return parked
	var before: Vector2 = _battle._board_pan
	_tap(_cell_local(_east, Vector2(0.22, 0.50)))
	if _battle.preview_move_cell != _east:
		return "soft tap did not preview the painted tile (preview %s attack %s)" % [
			_battle.preview_move_cell, _battle.preview_attack_ui]
	if _battle.units[_player_i].pos != _anchor:
		return "preview tap moved the unit"
	var pulled := await _wait_inside(_battle.units[_player_i].pos)
	if pulled != "":
		return pulled
	if _battle._board_pan.distance_to(before) < 1.0:
		return "parked selected unit was not pulled back during the move preview"
	return ""


func _e2e_illegal() -> String:
	var illegal := _illegal_cell()
	if illegal.x < 0:
		return "no illegal empty tile on this map"
	var pos_before: Vector2i = _battle.units[_player_i].pos
	_tap(_cell_local(illegal, Vector2(0.5, 0.5)))
	if BattleTouchConfirm.reject_flash_cell(_battle) != illegal:
		return "illegal flash landed on %s, aimed %s" % [BattleTouchConfirm.reject_flash_cell(_battle), illegal]
	var info = _battle.get_meta("m_reject_flash")
	if not (info is Dictionary) or str(info.get("reason", "")) != "move":
		return "illegal flash reason missing"
	if BattleTouchConfirm.reject_flash_alpha(_battle) < 0.9:
		return "illegal flash was already dead"
	var painted := await _paint_preview()
	if painted != "":
		return painted
	if _battle.selected != _player_i:
		return "illegal tap dropped the selection"
	if _battle.units[_player_i].pos != pos_before:
		return "illegal tap moved the unit"
	if _battle.preview_move_cell.x >= 0 or int(_battle.preview_attack_ui) >= 0:
		return "illegal tap left a ghost up"
	return ""


func _e2e_confirm() -> String:
	var legal := _legal_cell()
	if legal.x < 0:
		return "no legal move tile"
	var pos_before: Vector2i = _battle.units[_player_i].pos
	_tap(_cell_local(legal, Vector2(0.55, 0.55)))
	if _battle.preview_move_cell != legal:
		return "legal tap did not latch the preview (%s)" % _battle.preview_move_cell
	if _battle.units[_player_i].pos != pos_before:
		return "first legal tap committed early"
	var ring: Dictionary = BattleRangePreview.shown_attack(_battle)
	if ring.is_empty():
		return "move ghost did not grow an attack ring"
	_tap(_cell_local(legal, Vector2(0.55, 0.55)))
	if _battle.units[_player_i].pos != legal:
		return "second tap did not confirm the move (pos %s want %s)" % [_battle.units[_player_i].pos, legal]
	if not bool(_battle.moved_this_select):
		return "confirm did not mark the move spent"
	return ""


func _paint_preview() -> String:
	var overlay = _battle.overlay
	if overlay == null:
		return "battle overlay missing"
	var gate := {"done": false}
	var cb := func() -> void:
		if bool(gate.done):
			return
		gate.done = true
		BattleRangePreview.draw_ranges(_battle, overlay)
		BattleRangePreview.draw_illegal(_battle, overlay)
	overlay.draw.connect(cb, CONNECT_ONE_SHOT)
	overlay.queue_redraw()
	await get_tree().process_frame
	if not bool(gate.done):
		await get_tree().process_frame
	if not bool(gate.done):
		if overlay.draw.is_connected(cb):
			overlay.draw.disconnect(cb)
		return "overlay did not draw the range preview"
	return ""


func _desktop_confirm_off_flash() -> String:
	GameState.settings["touch_confirm"] = false
	if BattleTouchConfirm.enabled():
		return "touch_confirm false still enabled"
	_battle._select_player(_player_i)
	await _settle(4)
	BattlePick.cancel_focus_tween(_battle)
	var illegal := _illegal_cell()
	if illegal.x < 0:
		return "confirm-off: no illegal tile"
	var pos_before: Vector2i = _battle.units[_player_i].pos
	_tap(_cell_local(illegal, Vector2(0.4, 0.6)))
	if BattleTouchConfirm.reject_flash_cell(_battle) != illegal:
		return "desktop confirm-off did not flash %s (got %s)" % [illegal, BattleTouchConfirm.reject_flash_cell(_battle)]
	if _battle.selected != _player_i or _battle.units[_player_i].pos != pos_before:
		return "desktop confirm-off flash changed the selection"
	GameState.settings["touch_confirm"] = true
	return ""


func _notch_clip_contract() -> String:
	var stage: Rect2 = _battle.get_meta("m_board_area")
	var raw := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	if _battle.position.x < 200.0:
		return "fitted root lost mobile_origin (pos %s origin %s)" % [_battle.position, _battle._ui_origin()]
	var fitted := BattleRangePreview.playable_inset(_battle)
	if absf(fitted.position.x - raw.position.x) > 6.0 or absf(fitted.size.x - raw.size.x) > 6.0:
		return "fitted root double-counted the notch (fitted %s raw %s pos %s)" % [fitted, raw, _battle.position]
	var saved_pos: Vector2 = _battle.position
	var saved_origin: Vector2 = _battle._ui_origin()
	_battle.set_meta("mobile_origin", Vector2.ZERO)
	_battle.position = Vector2.ZERO
	await get_tree().process_frame
	var bare := BattleRangePreview.playable_inset(_battle)
	_battle.set_meta("mobile_origin", saved_origin)
	_battle.position = saved_pos
	await get_tree().process_frame
	if bare.position.x < raw.position.x + 40.0:
		return "root on the notch did not clip the lip (bare %s raw %s pos %s)" % [bare, raw, _battle.position]
	return ""


func _desktop_inset_is_unclipped() -> String:
	var stage: Rect2 = _battle.get_meta("m_board_area")
	var raw := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	var got := BattleRangePreview.playable_inset(_battle)
	if absf(got.position.x - raw.position.x) > 2.0 or absf(got.size.x - raw.size.x) > 2.0:
		return "desktop inset was clipped (%s vs %s)" % [got, raw]
	return ""


func _drag_does_not_pan() -> String:
	BattlePick.cancel_focus_tween(_battle)
	_battle.set_meta("ck_unit_drag", true)
	var pan: Vector2 = _battle._board_pan
	var delta := BattleRangePreview.keep_selected(_battle)
	if delta.length() > 0.01 or _battle._board_pan.distance_to(pan) > 0.01:
		_battle.remove_meta("ck_unit_drag")
		return "unit drag panned during range preview"
	_battle.remove_meta("ck_unit_drag")
	return ""


func _illegal_cell() -> Vector2i:
	var origin: Vector2i = _battle.units[_player_i].pos
	var best := Vector2i(-1, -1)
	var best_d := -1
	for y in _battle.MAP_H:
		for x in _battle.MAP_W:
			var cell := Vector2i(x, y)
			if _battle.move_cells.has(cell) or _battle._unit_at(cell) >= 0:
				continue
			var dist := absi(cell.x - origin.x) + absi(cell.y - origin.y)
			if dist > best_d:
				best_d = dist
				best = cell
	if best.x >= 0:
		return best
	var wall := Vector2i(0, _battle.MAP_H - 1)
	if wall == origin:
		wall = Vector2i(_battle.MAP_W - 1, 0)
	_battle.terrain[wall.y][wall.x] = "wall"
	_battle._select_player(_player_i)
	if _battle.move_cells.has(wall) or _battle._unit_at(wall) >= 0:
		return Vector2i(-1, -1)
	return wall


func _legal_cell() -> Vector2i:
	var origin: Vector2i = _battle.units[_player_i].pos
	var best := Vector2i(-1, -1)
	var best_d := -1
	for key in _battle.move_cells.keys():
		var cell: Vector2i = key
		if cell == origin or _battle._unit_at(cell) >= 0:
			continue
		var dist := absi(cell.x - origin.x) + absi(cell.y - origin.y)
		if dist > best_d:
			best_d = dist
			best = cell
	return best


func _park_right(cell: Vector2i) -> String:
	BattlePick.cancel_focus_tween(_battle)
	var stage: Rect2 = _battle.get_meta("m_board_area")
	var attempt := 0
	while attempt < 4:
		var inset := BattleRangePreview.playable_inset(_battle)
		var base := BattleCombatFrame.figure_rect(_battle.ORIGIN, float(_battle.CELL), cell, Vector2.ZERO, float(_battle._board_zoom))
		_battle._board_pan.x = inset.end.x + 220.0 - base.end.x
		_battle._clamp_board_pan()
		_battle._apply_board_xform()
		var fig := BattleCombatFrame.figure_rect(_battle.ORIGIN, float(_battle.CELL), cell, _battle._board_pan, float(_battle._board_zoom))
		if fig.position.x > inset.end.x + 6.0:
			return ""
		_battle._zoom_board_at(stage.get_center(), 1.65)
		BattlePick.cancel_focus_tween(_battle)
		attempt += 1
	return "could not park %s off the playable area (pan %s zoom %.2f)" % [cell, _battle._board_pan, _battle._board_zoom]


func _wait_inside(cell: Vector2i) -> String:
	var i := 0
	while i < 50:
		var inset: Rect2 = BattleRangePreview.playable_inset(_battle)
		if BattleCombatFrame.figure_inside(_battle.ORIGIN, float(_battle.CELL), cell, _battle._board_pan, float(_battle._board_zoom), inset, 3.0):
			return ""
		await get_tree().process_frame
		i += 1
	return "selected figure stayed outside the playable inset (pan %s)" % _battle._board_pan


func _cell_local(cell: Vector2i, rel: Vector2) -> Vector2:
	return _battle.ORIGIN + Vector2(cell) * float(_battle.CELL) + rel * float(_battle.CELL)


func _screen(local_board: Vector2) -> Vector2:
	var zoom := float(_battle._board_zoom)
	return _battle.get_global_transform() * (local_board * zoom + _battle._board_pan)


func _tap(local_board: Vector2) -> void:
	_battle._apply_board_gesture({"kind": "tap", "pos": _screen(local_board)})


func _set_window(size: Vector2i) -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = size
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(n: int) -> void:
	var i := 0
	while i < n:
		await get_tree().process_frame
		i += 1


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
		await _settle(2)
