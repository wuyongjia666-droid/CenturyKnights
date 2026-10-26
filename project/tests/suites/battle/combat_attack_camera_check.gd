extends Node
## Y1-A T-P13: attack-preview camera + select follow.
## Algebra for the play inset, then a real battle on phone landscape and on
## desktop. Player phase lead must still not force-pan the desktop board.
## No EmptyHost. Quits 1 on the first broken contract.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

var _battle: Control
var _player_i := -1
var _foe_i := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL attack camera: ", err)
		get_tree().quit(1)
		return
	print("COMBAT ATTACK CAMERA PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _algebra_frame()
	if err == "":
		err = _algebra_juice()
	if err == "":
		err = _algebra_source()
	if err != "":
		return err
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	err = await _boot(true)
	if err == "":
		err = await _e2e_select_follow()
	if err == "":
		err = await _e2e_drag_does_not_pan()
	if err == "":
		err = await _e2e_attack_preview(true)
	await _free_battle()
	if err != "":
		OS.set_environment("CK_FORCE_MOBILE", "0")
		return err
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if DeviceProfile.is_mobile():
		return "desktop flag did not clear"
	err = await _boot(false)
	if err == "":
		err = _desktop_phase_lead_stays()
	if err == "":
		err = await _e2e_select_follow()
	if err == "":
		err = await _e2e_attack_preview(false)
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err


func _algebra_frame() -> String:
	var stage := Rect2(24, 76, 856, 620)
	var inset := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	if inset.position.y <= stage.position.y or inset.end.y >= stage.end.y:
		return "play inset must shrink the stage"
	var reserved := BattleCombatFrame.play_inset(stage, 180.0, 0.0)
	if reserved.position.y < stage.position.y + 180.0 - 0.1:
		return "forecast reserve did not push the play inset down"
	var origin := Vector2(40, 80)
	var cell_px := 64.0
	var cell := Vector2i(3, 2)
	var inside_pan := Vector2.ZERO
	var fig := BattleCombatFrame.figure_rect(origin, cell_px, cell, inside_pan, 1.0)
	var wide := fig.grow(80.0)
	if BattleCombatFrame.frame_delta_for_rect(fig, wide).length() > 0.01:
		return "rect already inside must not move"
	var shoved := fig
	shoved.position.x = wide.end.x + 40.0
	var dx := BattleCombatFrame.frame_delta_for_rect(shoved, wide).x
	if dx >= -1.0:
		return "overflow on the right must pan left, got %s" % dx
	var huge := Rect2(0, 0, wide.size.x + 400.0, 40.0)
	var centered := BattleCombatFrame.frame_delta_for_rect(huge, wide)
	var mid_after := huge.get_center() + centered
	if absf(mid_after.x - wide.get_center().x) > 1.0:
		return "oversized bounds must center on the inset"
	var slot_left := BattleCombatFrame.forecast_slot(stage, Vector2(300, 140), stage.position + Vector2(30, 200))
	var slot_right := BattleCombatFrame.forecast_slot(stage, Vector2(300, 140), stage.end - Vector2(30, 200))
	if slot_left.x <= slot_right.x:
		return "forecast must sit opposite the pair"
	return ""


func _algebra_juice() -> String:
	var lines := BattleCombatFrame.chip_lines({"hit": 72, "dmg_lo": 4, "dmg_hi": 9, "counter": true, "counter_hit": 31})
	if lines.size() != 3 or lines[0] != "72%" or lines[1] != "4-9" or lines[2] != "C31%":
		return "chip lines wrong: %s" % str(lines)
	if not BattleCombatFrame.chip_lines({}).is_empty():
		return "empty forecast must not draw a chip"
	var quiet: Dictionary = BattleTouchConfirm.attack_preview_juice(80.0, 0.0)
	var loud: Dictionary = BattleTouchConfirm.attack_preview_juice(80.0, 1.0)
	if float(loud.ring_r) <= float(quiet.ring_r) or float(loud.halo_a) <= float(quiet.halo_a):
		return "pulse must grow the ring and the halo"
	if float(loud.ribbon_w) <= float(quiet.ribbon_w) or float(loud.bracket) <= float(quiet.bracket):
		return "pulse must grow the ribbon and the brackets"
	if float(quiet.aim_w) < 3.5 or float(quiet.chev_len) < 8.0:
		return "aim ribbon too thin to read"
	var host := Node.new()
	BattleTouchConfirm.note_confirm_strike(host, Vector2i(2, 2))
	var stamp: Dictionary = host.get_meta("m_confirm_strike")
	var t0 := int(stamp.get("msec", 0))
	if BattleTouchConfirm.confirm_strike_alpha(host, t0) < 0.99:
		return "confirm strike must be opaque at t0"
	if BattleTouchConfirm.confirm_strike_alpha(host, t0 + BattleTouchConfirm.CONFIRM_STRIKE_MSEC + 5) > 0.01:
		return "confirm strike must end"
	if BattleTouchConfirm.confirm_strike_cell(host) != Vector2i(2, 2):
		return "confirm strike cell lost"
	host.free()
	return ""


func _algebra_source() -> String:
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	var cast := FileAccess.get_file_as_string("res://scripts/battle/ui/forecast_panel.gd")
	if pick.find("BattleCombatFrame.follow_selected") < 0:
		return "select does not frame through BattleCombatFrame"
	if pick.find("not force and not DeviceProfile.is_mobile()") < 0:
		return "desktop focus_cell force gate was removed"
	if conf.find("ck_unit_drag") < 0 or conf.find("do not soft-follow mid unit-drag") < 0:
		return "unit-drag pan guard missing"
	if conf.find("clear(host, false)") < 0 or conf.find("note_confirm_strike") < 0:
		return "confirm still refocuses the attacker or lacks the strike"
	if conf.find("ribbon_w") < 0 or conf.find("draw_line") < 0:
		return "attack ribbon missing"
	if cast.find("BattleCombatFrame.follow_attack") < 0 or cast.find("forecast_slot") < 0:
		return "forecast does not frame or park opposite the pair"
	if conf.find("EmptyHost") >= 0 or pick.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	return ""


func _boot(mobile: bool) -> String:
	await _set_window(PHONE if mobile else DESK)
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
	if not mobile:
		GameState.settings["touch_confirm"] = true
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	if mobile:
		var insets := {"left": 80.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
		var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
		MobileLayout.apply_root(_battle, fitted)
		_battle.set_meta("mobile_insets", insets)
		if _battle.has_method("apply_mobile_layout"):
			_battle.apply_mobile_layout()
		await _settle(8)
		if not _battle._mobile_landscape():
			return "battle did not enter landscape"
	elif not _battle.has_meta("m_board_area"):
		return "desktop board stage missing"
	return _arrange()


func _arrange() -> String:
	_player_i = -1
	_foe_i = -1
	var extra_p := 0
	var extra_f := 0
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player":
			if _player_i < 0:
				_player_i = i
				u.pos = Vector2i(4, 3)
				u.done = false
			else:
				extra_p += 1
				u.pos = Vector2i(0, mini(1, extra_p))
				u.done = true
		elif str(u.team) == "enemy":
			if _foe_i < 0:
				_foe_i = i
				u.pos = Vector2i(8, 3)
			else:
				extra_f += 1
				u.pos = Vector2i(mini(_battle.MAP_W - 1, 9), mini(_battle.MAP_H - 1, extra_f))
				u.char.hp = 0
	if _player_i < 0 or _foe_i < 0:
		return "deploy missing player/enemy"
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	_battle.attack_mode = false
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _e2e_select_follow() -> String:
	var cell: Vector2i = _battle.units[_player_i].pos
	var parked := _park_right(cell)
	if parked != "":
		return parked
	var before: Vector2 = _battle._board_pan
	_tap(_cell_local(cell, Vector2(0.5, 0.55)))
	if _battle.selected != _player_i:
		return "select tap missed the parked unit (selected %s)" % str(_battle.selected)
	var delta := _frame_delta()
	if delta.x >= -1.0:
		return "select follow did not pull the offscreen unit back (delta %s pan %s)" % [delta, _battle._board_pan]
	await _wait_pan(before + delta)
	var stage: Rect2 = _battle.get_meta("m_board_area")
	var inset := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	if not BattleCombatFrame.figure_inside(_battle.ORIGIN, float(_battle.CELL), cell, _battle._board_pan, float(_battle._board_zoom), inset, 3.0):
		return "selected figure still outside the play inset"
	return ""


func _e2e_drag_does_not_pan() -> String:
	if _battle.selected != _player_i:
		_battle._select_player(_player_i)
		await _settle(4)
	BattlePick.cancel_focus_tween(_battle)
	var origin: Vector2 = _screen(_cell_local(_battle.units[_player_i].pos, Vector2(0.5, 0.55)))
	var armed := BattleTouchConfirm.is_unit_drag(_battle, {"origin": origin, "kind": "pan"})
	if not armed:
		return "press on the selected figure did not arm a unit drag"
	var pan_before: Vector2 = _battle._board_pan
	var far := _screen(_cell_local(Vector2i(1, 1), Vector2(0.5, 0.5)))
	_battle._hover_at(far)
	BattleTouchConfirm.on_drag(_battle, far)
	if _battle._board_pan.distance_to(pan_before) > 0.5:
		return "unit drag panned the board (%s -> %s)" % [pan_before, _battle._board_pan]
	BattleTouchConfirm.end_gesture(_battle)
	return ""


func _e2e_attack_preview(mobile: bool) -> String:
	var spot := _attack_spot(_battle.units[_player_i].pos)
	if spot.x < 0:
		return "no in-range cell for the attack preview"
	_battle.units[_foe_i].pos = spot
	_battle.units[_foe_i].char.hp = maxi(int(_battle.units[_foe_i].char.hp), 8)
	if _battle.selected != _player_i:
		_battle._select_player(_player_i)
	_battle.attack_mode = false
	_battle.preview_attack_ui = -1
	_battle._hover_cell = Vector2i(-1, -1)
	await _settle(2)
	if not mobile:
		_battle._enter_attack_mode()
	var parked := _park_into_band([_battle.units[_player_i].pos, spot])
	if parked != "":
		return parked
	var before: Vector2 = _battle._board_pan
	var hp0 := int(_battle.units[_foe_i].char.hp)
	_tap(_cell_local(spot, Vector2(0.5, 0.5)))
	if int(_battle.preview_attack_ui) != _foe_i:
		return "foe tap did not latch attack preview (ui %s mode %s)" % [_battle.preview_attack_ui, _battle.attack_mode]
	var delta := _frame_delta()
	if delta.length() < 1.0:
		return "attack preview did not frame the pair out of the forecast band (delta %s)" % delta
	await _wait_pan(before + delta)
	var reserve := BattleCombatFrame.forecast_band(mobile)
	var stage: Rect2 = _battle.get_meta("m_board_area")
	var inset := BattleCombatFrame.play_inset(stage, reserve, 0.0)
	if not BattleCombatFrame.figure_inside(_battle.ORIGIN, float(_battle.CELL), spot, _battle._board_pan, float(_battle._board_zoom), inset, 4.0):
		return "defender figure still under the forecast band"
	var panel := _battle.get_node_or_null("ForecastPanel") as Control
	if panel == null or not panel.visible:
		return "attack preview did not show ForecastPanel"
	var body := panel.get_node_or_null("Cols/Ours/Body") as Label
	if body == null or body.text.find("%") < 0:
		return "forecast chip missing a hit rate"
	var covered := _panel_covers(panel, spot) or _panel_covers(panel, _battle.units[_player_i].pos)
	if covered:
		return "forecast panel covers a fighter"
	if _battle.overlay:
		_battle.overlay.queue_redraw()
	await _settle(2)
	_tap(_cell_local(spot, Vector2(0.5, 0.5)))
	if BattleTouchConfirm.confirm_strike_cell(_battle) != spot:
		return "confirm did not stamp the strike cell %s" % str(BattleTouchConfirm.confirm_strike_cell(_battle))
	if float(_battle._shake) + 0.01 < BattleTouchConfirm.CONFIRM_STRIKE_SHAKE:
		return "confirm shake %.2f below the strike punch" % float(_battle._shake)
	var foe_hp := int(_battle.units[_foe_i].char.hp)
	var committed: bool = bool(_battle.units[_player_i].done) or _battle.selected < 0 or foe_hp < hp0
	if not committed and _battle._combat_rec.is_empty():
		return "second attack tap did not confirm"
	return ""


func _desktop_phase_lead_stays() -> String:
	var pan: Vector2 = _battle._board_pan
	BattlePhaseFeel.note_phase_switch(_battle, "player")
	if _battle._board_pan.distance_to(pan) > 0.5:
		return "player phase lead moved the desktop camera"
	BattlePick.focus_cell(_battle, _battle.units[_player_i].pos, false, false)
	if _battle._board_pan.distance_to(pan) > 0.5:
		return "focus_cell without force panned the desktop board"
	return ""


func _park_right(cell: Vector2i) -> String:
	BattlePick.cancel_focus_tween(_battle)
	var stage: Rect2 = _battle.get_meta("m_board_area")
	var attempt := 0
	while attempt < 4:
		var inset := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
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
	return "could not park %s off the right (pan %s zoom %.2f)" % [cell, _battle._board_pan, _battle._board_zoom]


func _park_into_band(cells: Array) -> String:
	BattlePick.cancel_focus_tween(_battle)
	var stage: Rect2 = _battle.get_meta("m_board_area")
	var reserve := BattleCombatFrame.forecast_band(DeviceProfile.is_mobile())
	var attempt := 0
	while attempt < 4:
		var inset := BattleCombatFrame.play_inset(stage, reserve, 0.0)
		var top := 100000.0
		for c in cells:
			var base := BattleCombatFrame.figure_rect(_battle.ORIGIN, float(_battle.CELL), c, Vector2.ZERO, float(_battle._board_zoom))
			top = minf(top, base.position.y)
		_battle._board_pan.y = stage.position.y + 12.0 - top
		_battle._clamp_board_pan()
		_battle._apply_board_xform()
		var outside := false
		for c in cells:
			var fig := BattleCombatFrame.figure_rect(_battle.ORIGIN, float(_battle.CELL), c, _battle._board_pan, float(_battle._board_zoom))
			if fig.position.y < inset.position.y - 4.0:
				outside = true
		if outside:
			return ""
		_battle._zoom_board_at(stage.get_center(), 1.65)
		BattlePick.cancel_focus_tween(_battle)
		attempt += 1
	return "could not park the pair under the forecast band (pan %s zoom %.2f)" % [_battle._board_pan, _battle._board_zoom]


func _panel_covers(panel: Control, cell: Vector2i) -> bool:
	var fig := BattleCombatFrame.figure_rect(_battle.ORIGIN, float(_battle.CELL), cell, _battle._board_pan, float(_battle._board_zoom))
	var global_pt: Vector2 = _battle.get_global_transform() * fig.get_center()
	return panel.get_global_rect().grow(2.0).has_point(global_pt)


func _frame_delta() -> Vector2:
	if not _battle.has_meta("m_combat_frame"):
		return Vector2.ZERO
	var info = _battle.get_meta("m_combat_frame")
	if not (info is Dictionary):
		return Vector2.ZERO
	return info.get("delta", Vector2.ZERO)


func _attack_spot(from: Vector2i) -> Vector2i:
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(3, 0),
	]
	for off in offsets:
		var cell: Vector2i = from + off
		if not _battle._in_bounds(cell) or cell == from:
			continue
		if _battle._can_attack_from(_battle.units[_player_i], cell):
			return cell
	return Vector2i(-1, -1)


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


func _wait_pan(target: Vector2) -> void:
	var i := 0
	while i < 45:
		if _battle._board_pan.distance_to(target) < 2.0:
			return
		await get_tree().process_frame
		i += 1


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
