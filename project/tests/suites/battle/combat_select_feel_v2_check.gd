extends Node
## Y1-A T-P11: select-feel v2 fail-suite.
## Algebra: chest below an occupant's feet resolves to the south unit on mobile,
## exact cell on desktop, diagonal contour does not steal.
## Chrome: foot disc / mid ring / body rect share BattlePick's figure span.
## E2E on a real battle (CK_FORCE_MOBILE, landscape): chest tap selects the
## south unit, info panel stays on that unit through invalid taps, move confirm
## and attack confirm still commit, #465 Cancel→hint→Confirm stack stays sunk.
## No EmptyHost. Quits 1 on the first broken contract.

const PHONE := Vector2i(2400, 1080)

var _battle: Control
var _player_i := -1
var _foe_i := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if err != "":
		print("FAIL select feel v2: ", err)
		get_tree().quit(1)
		return
	print("COMBAT SELECT FEEL V2 PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra_body()
	if err == "":
		err = _algebra_chrome()
	if err == "":
		err = _algebra_desktop_exact()
	if err == "":
		err = _source_contracts()
	if err != "":
		return err
	OS.set_environment("CK_FORCE_MOBILE", "1")
	err = await _boot_battle()
	if err != "":
		return err
	err = await _e2e_select_confirm()
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
	return err


func _algebra_body() -> String:
	var origin := Vector2(10, 20)
	var cell := 64.0
	var units: Array = [
		{"char": {"hp": 8}, "pos": Vector2i(3, 2), "team": "bandit"},
		{"char": {"hp": 9}, "pos": Vector2i(3, 3), "team": "player"},
		{"char": {"hp": 7}, "pos": Vector2i(4, 3), "team": "bandit"},
	]
	# Chest of the south unit: upper-cell rel_y 0.90, past the occupant's feet (0.62).
	var chest := origin + Vector2(3.5, 2.90) * cell
	var finger := BattlePick.cell_at_local(origin, cell, chest, 16, 12)
	if finger != Vector2i(3, 2):
		return "chest fixture cell %s" % str(finger)
	var hit: Vector2i = BattlePick.body_over_occupant(origin, cell, units, chest, finger)
	if hit != Vector2i(3, 3):
		return "chest past feet must select south unit, got %s" % str(hit)
	# Corner of the same strip also overlaps the diagonal fat contour — same column wins.
	var corner := origin + Vector2(3.98, 2.90) * cell
	var corner_cell := BattlePick.cell_at_local(origin, cell, corner, 16, 12)
	if corner_cell != Vector2i(3, 2):
		return "corner fixture cell %s" % str(corner_cell)
	var corner_hit: Vector2i = BattlePick.body_over_occupant(origin, cell, units, corner, corner_cell)
	if corner_hit != Vector2i(3, 3):
		return "diagonal contour stole the chest strip, got %s" % str(corner_hit)
	var center := origin + Vector2(3.5, 2.50) * cell
	var center_cell := BattlePick.cell_at_local(origin, cell, center, 16, 12)
	if BattlePick.body_over_occupant(origin, cell, units, center, center_cell).x >= 0:
		return "cell-centre tap must stay on the occupant"
	var alone: Array = [{"char": {"hp": 8}, "pos": Vector2i(3, 2), "team": "bandit"}]
	if BattlePick.body_over_occupant(origin, cell, alone, chest, finger).x >= 0:
		return "bottom strip without a south unit must keep the occupant"
	var host := _PickHost.new()
	host.units = units
	var resolved: Vector2i = BattlePick.resolve(host, chest)
	if resolved != Vector2i(3, 3):
		return "resolve must use body_over_occupant, got %s" % str(resolved)
	var strict: Vector2i = BattlePick.strict_unit_pos(origin, cell, units, chest, finger)
	if strict != Vector2i(3, 3):
		return "strict drag origin must grab the south chest, got %s" % str(strict)
	return ""


func _algebra_chrome() -> String:
	var cell := 80.0
	var half := BattlePick.contour_half_w()
	var marks: Dictionary = BattleSelectChrome.chrome_marks(Vector2.ZERO, cell, Vector2i(3, 3), half, 1.0)
	var body: Rect2 = marks.body
	var foot: Vector2 = marks.foot
	var mid: Vector2 = marks.mid
	var foot_y := (3.0 + BattlePick.FIG_FEET) * cell
	var mid_y := (3.0 + (BattlePick.FIG_TOP + BattlePick.FIG_FEET) * 0.5) * cell
	var err := ""
	if absf(foot.y - foot_y) > 0.01:
		err = "foot disc not on FIG_FEET"
	elif absf(mid.y - mid_y) > 0.01:
		err = "mid ring not on figure midline"
	elif mid.y >= foot.y:
		err = "mid ring must sit above the foot disc"
	elif not body.has_point(mid):
		err = "body rect must contain the mid ring"
	elif absf(foot.y - body.end.y) > 0.01:
		err = "foot disc must sit on the body rect bottom"
	elif foot.x < body.position.x or foot.x > body.end.x:
		err = "foot disc outside the body column"
	elif float(marks.foot_r) < cell * 0.44:
		err = "foot disc too small to read"
	elif float(marks.mid_r) < cell * 0.36:
		err = "mid ring too small to read"
	elif float(marks.body_fill_a) < 0.18:
		err = "body fill too faint"
	elif float(marks.line_w) < 3.0:
		err = "chrome stroke too thin"
	elif body.size.y <= cell:
		err = "body rect must cover the figure, taller than one cell"
	else:
		var wide: Dictionary = BattleSelectChrome.chrome_marks(Vector2.ZERO, cell, Vector2i(3, 3), half, 1.4)
		if float(wide.foot_r) <= float(marks.foot_r):
			err = "select burst must enlarge the foot disc"
	return err


func _algebra_desktop_exact() -> String:
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if DeviceProfile.is_mobile():
		OS.set_environment("CK_FORCE_MOBILE", "1")
		return "desktop force flag did not clear"
	var origin := Vector2(10, 20)
	var cell := 64.0
	var units: Array = [
		{"char": {"hp": 8}, "pos": Vector2i(3, 2), "team": "bandit"},
		{"char": {"hp": 9}, "pos": Vector2i(3, 3), "team": "player"},
	]
	var chest := origin + Vector2(3.5, 2.90) * cell
	var finger := BattlePick.cell_at_local(origin, cell, chest, 16, 12)
	if BattlePick.body_over_occupant(origin, cell, units, chest, finger).x >= 0:
		OS.set_environment("CK_FORCE_MOBILE", "1")
		return "desktop body_over_occupant must not steal the exact cell"
	var host := _PickHost.new()
	host.units = units
	var resolved: Vector2i = BattlePick.resolve(host, chest)
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		return "failed to restore CK_FORCE_MOBILE"
	if resolved != Vector2i(3, 2):
		return "desktop resolve must keep the occupied cell, got %s" % str(resolved)
	return ""


func _source_contracts() -> String:
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	var info := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_info_panel.gd")
	var bar := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_mobile_bar.gd")
	if pick.find("body_over_occupant(") < 0:
		return "resolve missing body_over_occupant"
	if ctrl.find("mobile_direct_attack") < 0:
		return "in-range foe tap not wired"
	if ctrl.find("BattleSelectChrome.draw_selected(self, overlay)") < 0:
		return "overlay missing select chrome"
	if ctrl.split("\n").size() > 3000:
		return "battle_controller over 3000 lines"
	if conf.find("draw_line") < 0 or conf.find("_refresh_info") < 0:
		return "invalid tap missing cross flash or panel resync"
	if info.find("ux_confirm_dest_move") < 0 or info.find("reveal_landscape") < 0:
		return "info panel not tied to select / confirm state"
	if bar.find("0.58") < 0 or bar.find("landscape_confirm_stack") < 0:
		return "#465 confirm stack regressed"
	var stack := BattleMobileBar.landscape_confirm_stack()
	if stack.size() != 3 or stack[0] != "cancel" or stack[1] != "hint" or stack[2] != "confirm":
		return "landscape confirm order changed: %s" % str(stack)
	return ""


func _boot_battle() -> String:
	await _set_phone_window()
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	var insets := {"left": 80.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
	var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
	MobileLayout.apply_root(_battle, fitted)
	_battle.set_meta("mobile_insets", insets)
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(8)
	if not _battle._mobile_landscape():
		return "battle did not enter landscape"
	if _battle.get_node_or_null("MobileSideCol") == null:
		return "landscape side column missing"
	return _arrange_units()


func _arrange_units() -> String:
	_player_i = -1
	_foe_i = -1
	var extra_p := 0
	var extra_f := 0
	for i in _battle.units.size():
		var u = _battle.units[i]
		if u.char.hp <= 0:
			continue
		if str(u.team) == "player":
			if _player_i < 0:
				_player_i = i
				u.pos = Vector2i(3, 3)
				u.done = false
			else:
				extra_p += 1
				u.pos = Vector2i(1, mini(6, extra_p))
				u.done = true
		elif str(u.team) == "enemy":
			if _foe_i < 0:
				_foe_i = i
				u.pos = Vector2i(3, 2)
			else:
				extra_f += 1
				u.pos = Vector2i(9, mini(6, extra_f))
	if _player_i < 0 or _foe_i < 0:
		return "deploy missing player/enemy"
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	_battle.attack_mode = false
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	return ""


func _e2e_select_confirm() -> String:
	var err := await _e2e_chest_select()
	if err == "":
		err = _e2e_invalid_targets()
	if err == "":
		err = _e2e_move_confirm()
	if err == "":
		err = _e2e_attack_confirm()
	return err


func _e2e_chest_select() -> String:
	var chest := _cell_local(Vector2i(3, 2), Vector2(0.5, 0.90))
	var resolved: Vector2i = BattlePick.resolve(_battle, _screen(chest))
	if resolved != Vector2i(3, 3):
		return "live resolve chest got %s (want south unit)" % str(resolved)
	_tap(chest)
	if _battle.selected != _player_i:
		return "chest tap selected %s not the south player" % str(_battle.selected)
	if not _battle.has_meta("m_select_burst_msec"):
		return "select did not stamp burst chrome"
	if _battle.overlay:
		_battle.overlay.queue_redraw()
	await _settle(6)
	var info := str(_battle.info_label.text)
	var name := str(_battle.units[_player_i].char.name)
	if info.find(name) < 0:
		return "info panel missing selected name"
	if not _select_state(info):
		return "info panel missing select-state line: %s" % info
	var sc := _battle.get_node_or_null("MobileSideCol") as ScrollContainer
	if sc == null:
		return "side column gone after select"
	if str(_battle._unit_panel.get_parent().name) != "Stack":
		return "unit info panel left the landscape column"
	await _settle(4)
	var y := int(_battle._unit_panel.position.y)
	var want := maxi(0, y - 4)
	if absi(int(sc.scroll_vertical) - want) > 2:
		return "landscape column not pinned to the selected card (scroll %s want %s)" % [sc.scroll_vertical, want]
	return ""


func _e2e_invalid_targets() -> String:
	_battle.move_cells = {Vector2i(3, 4): 1}
	_battle.units[_foe_i].pos = Vector2i(0, 0)
	if _battle._can_attack_from(_battle.units[_player_i], Vector2i(0, 0)):
		return "far foe still inside weapon range — fixture too close"
	var name := str(_battle.units[_player_i].char.name)
	_tap(_cell_local(Vector2i(2, 5), Vector2(0.5, 0.5)))
	if _battle.selected != _player_i:
		return "illegal empty cleared the selection"
	if BattleTouchConfirm.reject_flash_cell(_battle) != Vector2i(2, 5):
		return "illegal empty did not flash the tapped cell"
	if BattleTouchConfirm.reject_flash_alpha(_battle) <= 0.0:
		return "reject flash alpha dead"
	if float(_battle._shake) < 1.0:
		return "reject shake too weak to feel"
	var info := str(_battle.info_label.text)
	if info.find(name) < 0 or not _select_state(info):
		return "illegal empty rewrote the info panel off the selection: %s" % info
	_tap(_cell_local(Vector2i(0, 0), Vector2(0.5, 0.5)))
	if _battle.selected != _player_i:
		return "out-of-range foe tap changed selection"
	if BattleTouchConfirm.reject_flash_cell(_battle) != Vector2i(0, 0):
		return "out-of-range foe was a silent no-op"
	info = str(_battle.info_label.text)
	if not _select_state(info) or info.find(name) < 0:
		return "foe tap swapped the panel off the selected unit: %s" % info
	return ""


func _e2e_move_confirm() -> String:
	_battle.move_cells = {Vector2i(3, 4): 1}
	_battle.moved_this_select = false
	_battle.preview_move_cell = Vector2i(-1, -1)
	_tap(_cell_local(Vector2i(3, 4), Vector2(0.5, 0.5)))
	if _battle.preview_move_cell != Vector2i(3, 4):
		return "first move tap did not latch preview %s" % str(_battle.preview_move_cell)
	if _battle.units[_player_i].pos != Vector2i(3, 3):
		return "preview tap committed the move early"
	var err := _assert_confirm_stack()
	if err != "":
		return err
	var dest := Locale.t("ux_confirm_dest_move") % [3, 4]
	if str(_battle.info_label.text).find(dest) < 0:
		return "info panel missing move confirm dest: %s" % str(_battle.info_label.text)
	_tap(_cell_local(Vector2i(3, 4), Vector2(0.5, 0.5)))
	if _battle.units[_player_i].pos != Vector2i(3, 4):
		return "second move tap did not confirm, pos %s" % str(_battle.units[_player_i].pos)
	return ""


func _e2e_attack_confirm() -> String:
	var from: Vector2i = _battle.units[_player_i].pos
	var spot := _attack_spot(from)
	if spot.x < 0:
		return "no in-range cell for attack confirm"
	_battle.units[_foe_i].pos = spot
	_battle.attack_mode = false
	_battle.preview_attack_ui = -1
	var hp0 := int(_battle.units[_foe_i].char.hp)
	_tap(_cell_local(spot, Vector2(0.5, 0.5)))
	if int(_battle.preview_attack_ui) != _foe_i:
		return "in-range foe tap did not preview attack (ui %s)" % str(_battle.preview_attack_ui)
	var err := _assert_confirm_stack()
	if err != "":
		return err
	var foe_name := str(_battle.units[_foe_i].char.name)
	var dest := Locale.t("ux_confirm_dest_attack") % foe_name
	var info := str(_battle.info_label.text)
	if info.find(dest) < 0 and info.find(foe_name) < 0:
		return "info panel missing attack confirm target"
	if info.find(str(_battle.units[_player_i].char.name)) < 0:
		return "attack preview dropped the selected unit from the panel"
	_tap(_cell_local(spot, Vector2(0.5, 0.5)))
	var foe_hp := int(_battle.units[_foe_i].char.hp)
	var committed: bool = bool(_battle.units[_player_i].done) or _battle.selected < 0 or foe_hp < hp0
	if not committed and _battle._combat_rec.is_empty():
		return "second attack tap did not confirm"
	return ""


func _attack_spot(from: Vector2i) -> Vector2i:
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
	]
	for off in offsets:
		var cell: Vector2i = from + off
		if not _battle._in_bounds(cell) or cell == from:
			continue
		if _battle._can_attack_from(_battle.units[_player_i], cell):
			return cell
	return Vector2i(-1, -1)


func _assert_confirm_stack() -> String:
	if _battle._mobile_bar == null:
		return "mobile command bar missing"
	var row := _battle._mobile_bar.get_node_or_null("CmdRow") as BoxContainer
	if row == null:
		return "confirm row missing"
	var names: PackedStringArray = PackedStringArray()
	for c in row.get_children():
		names.append(str(c.name))
	if names.size() < 3:
		return "confirm stack short: %s" % str(names)
	if names[0] != "ConfirmCancel" or names[1] != "ConfirmHint" or names[2] != "ConfirmPrimary":
		return "#465 stack order regressed: %s" % str(names)
	var primary := row.get_node_or_null("ConfirmPrimary") as Control
	if primary == null or primary.custom_minimum_size.y < 108.0:
		return "Confirm primary under 108px"
	var vp_h := _battle.get_viewport().get_visible_rect().size.y
	if _battle._mobile_bar.position.y < vp_h * 0.50:
		return "confirm bar not sunk into the thumb zone (y %.0f vp %.0f)" % [_battle._mobile_bar.position.y, vp_h]
	return ""


func _select_state(info: String) -> bool:
	var marker := Locale.t("shell_31067370")
	return info.find(marker.substr(0, mini(6, marker.length()))) >= 0


func _cell_local(cell: Vector2i, rel: Vector2) -> Vector2:
	return _battle.ORIGIN + Vector2(cell) * float(_battle.CELL) + rel * float(_battle.CELL)


func _screen(local_board: Vector2) -> Vector2:
	var zoom := float(_battle._board_zoom)
	var screen_in: Vector2 = local_board * zoom + _battle._board_pan
	return _battle.get_global_transform() * screen_in


func _tap(local_board: Vector2) -> void:
	_battle._apply_board_gesture({"kind": "tap", "pos": _screen(local_board)})


func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(n: int) -> void:
	var i := 0
	while i < n:
		await get_tree().process_frame
		i += 1


class _PickHost extends RefCounted:
	var units: Array = []
	var attack_mode: bool = false
	var _board_pan: Vector2 = Vector2.ZERO
	var _board_zoom: float = 1.0
	var _origin: Vector2 = Vector2(10, 20)
	var _cell: int = 64

	func _get(property: StringName) -> Variant:
		if property == &"ORIGIN":
			return _origin
		if property == &"CELL":
			return _cell
		return null

	func _screen_to_local(p: Vector2) -> Vector2:
		return p

	func _pointer_to_cell(screen_pos: Vector2) -> Vector2i:
		var local := BattlePick.local_after_pan_zoom(_screen_to_local(screen_pos), _board_pan, _board_zoom)
		return BattlePick.cell_at_local(_origin, float(_cell), local, 16, 12)

	func _unit_at(pos: Vector2i) -> int:
		for i in units.size():
			if units[i].char.hp > 0 and units[i].pos == pos:
				return i
		return -1
