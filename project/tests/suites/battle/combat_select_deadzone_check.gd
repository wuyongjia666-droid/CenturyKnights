extends Node
## Y1-A T-P24: select/move tap deadzone + sticky figure + portrait-panel steal.
## Algebra first (device-free), then a real landscape battle under CK_FORCE_MOBILE.
## Fail-suite — no EmptyHost / how CTA. Quits 1 on the first broken contract.

const PHONE := Vector2i(2400, 1080)

var _battle: Control
var _player_i := -1
var _foe_i := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL select deadzone: ", err)
		get_tree().quit(1)
		return
	print("COMBAT SELECT DEADZONE PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra_soft_steal()
	if err == "":
		err = _algebra_sticky_strict()
	if err == "":
		err = _algebra_face_kept()
	if err == "":
		err = _algebra_other_unit_soft()
	if err == "":
		err = _algebra_source()
	if err != "":
		return err
	OS.set_environment("CK_FORCE_MOBILE", "1")
	err = await _boot()
	if err == "":
		err = await _e2e_adjacent_move()
	if err == "":
		err = await _e2e_sticky_pan_empty()
	if err == "":
		err = _e2e_panel_ignore()
	if err == "":
		err = await _e2e_right_notch_select()
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
	return err


## Soft_R=0.90 steals the near half of an adjacent empty cell onto the selected unit.
## resolve_board_tap must keep the empty exact cell so move preview can latch.
func _algebra_soft_steal() -> String:
	var host := _TapHost.new()
	host.setup_armed(Vector2i(2, 2))
	var origin: Vector2 = host.get("ORIGIN")
	var cell := float(host.get("CELL"))
	# Finger in the east neighbour, 0.70 cells from selected centre (inside SOFT_R).
	var finger := origin + Vector2(2.5 + 0.70, 2.5) * cell
	var exact: Vector2i = BattlePick.cell_at_local(origin, cell, finger, 16, 12)
	if exact != Vector2i(3, 2):
		return "soft-steal fixture exact %s" % str(exact)
	var soft: Vector2i = BattlePick.nearest_unit_pos(origin, cell, host.units, finger, BattlePick.SOFT_R, "player")
	if soft != Vector2i(2, 2):
		return "control: soft should still prefer selected (got %s)" % str(soft)
	var raw: Vector2i = BattlePick.resolve(host, finger)
	if raw != Vector2i(2, 2):
		return "control: resolve soft-steals onto selected (got %s)" % str(raw)
	var tap: Vector2i = BattlePick.resolve_board_tap(host, finger)
	if tap != Vector2i(3, 2):
		return "board tap must keep empty exact %s, got %s" % [Vector2i(3, 2), tap]
	return ""


## Sticky while selected must be strict figure — soft halo is not sticky.
func _algebra_sticky_strict() -> String:
	var host := _TapHost.new()
	host.setup_armed(Vector2i(2, 2))
	var origin: Vector2 = host.get("ORIGIN")
	var cell := float(host.get("CELL"))
	var halo := origin + Vector2(2.5 + 0.70, 2.5) * cell
	if BattlePick.near_selected_unit(host, halo, 0):
		return "soft halo must not count as sticky near_selected"
	var torso := origin + Vector2(2.5, 2.5) * cell
	if not BattlePick.near_selected_unit(host, torso, 0):
		return "figure centre must stay sticky"
	if not BattlePick.strict_hits_selected(host, torso, 0):
		return "strict_hits_selected missed torso"
	return ""


## Face/head tap above the figure (visual bias) still selects — board tap must not
## flatten that into the empty exact cell above.
func _algebra_face_kept() -> String:
	var host := _TapHost.new()
	host.setup_armed(Vector2i(2, 2))
	var origin: Vector2 = host.get("ORIGIN")
	var cell := float(host.get("CELL"))
	# Empty cell above the unit, inside the figure face band (FIG_TOP..).
	var face := origin + Vector2(2.5, 2.0 + BattlePick.FIG_TOP + 0.15) * cell
	var exact: Vector2i = BattlePick.cell_at_local(origin, cell, face, 16, 12)
	if exact != Vector2i(2, 1):
		return "face fixture exact %s" % str(exact)
	if host._unit_at(exact) >= 0:
		return "face fixture cell must be empty"
	var tap: Vector2i = BattlePick.resolve_board_tap(host, face)
	if tap != Vector2i(2, 2):
		return "face bias must keep selected, got %s" % str(tap)
	return ""


## Soft may still pick a *different* living unit from an empty exact cell.
func _algebra_other_unit_soft() -> String:
	var host := _TapHost.new()
	host.setup_armed(Vector2i(2, 2))
	host.units.append({"char": {"hp": 8}, "pos": Vector2i(4, 2), "team": "bandit"})
	var origin: Vector2 = host.get("ORIGIN")
	var cell := float(host.get("CELL"))
	# Empty cell between selected (2,2) and foe (4,2), nearer the foe.
	var finger := origin + Vector2(3.5 + 0.20, 2.5) * cell
	var exact: Vector2i = BattlePick.cell_at_local(origin, cell, finger, 16, 12)
	if exact != Vector2i(3, 2):
		return "other-soft fixture exact %s" % str(exact)
	host.attack_mode = true
	var tap: Vector2i = BattlePick.resolve_board_tap(host, finger)
	if tap != Vector2i(4, 2):
		return "attack soft must still reach the foe, got %s" % str(tap)
	return ""


func _algebra_source() -> String:
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var edge := FileAccess.get_file_as_string("res://scripts/battle/battle_edge_pick.gd")
	if pick.find("resolve_board_tap") < 0:
		return "resolve_board_tap missing"
	if pick.find("strict_hits_selected(host, screen_pos, selected_idx)") < 0:
		return "near_selected must delegate to strict_hits_selected"
	if ctrl.find("resolve_board_tap") < 0:
		return "tap path not wired to resolve_board_tap"
	if edge.find("T-P24") < 0:
		return "portrait column pass-through missing T-P24"
	if edge.find("not (n is ScrollContainer)") >= 0:
		return "ScrollContainer still excluded from IGNORE pass"
	if pick.find("EmptyHost") >= 0 or ctrl.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	return ""


func _boot() -> String:
	await _set_phone_window()
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
	GameState.board_input_blocked = false
	OS.set_environment("CK_SAFE_INSETS", "80,0,0,24")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(6)
	var story := _battle.get_node_or_null("BattleStoryLayer")
	if story:
		story.free()
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
				u.pos = Vector2i(3, 3)
				u.done = false
			else:
				extra_p += 1
				u.pos = Vector2i(0, mini(1, extra_p))
				u.done = true
				u.char.hp = 0
		elif str(u.team) == "enemy":
			if _foe_i < 0:
				_foe_i = i
				u.pos = Vector2i(7, 3)
			else:
				extra_f += 1
				u.pos = Vector2i(mini(_battle.MAP_W - 1, 8), mini(_battle.MAP_H - 1, extra_f))
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
	_battle.moved_this_select = false
	return ""


## Select player, tap the near half of an east move cell — must preview, not deselect.
func _e2e_adjacent_move() -> String:
	_battle._cancel_selection()
	_battle.units[_player_i].pos = Vector2i(3, 3)
	_battle.units[_player_i].done = false
	_battle.moved_this_select = false
	_tap(_cell_local(Vector2i(3, 3), Vector2(0.5, 0.55)))
	await _settle(3)
	if _battle.selected != _player_i:
		return "setup select failed (sel %s)" % str(_battle.selected)
	_battle.move_cells = {Vector2i(4, 3): 1, Vector2i(3, 4): 1, Vector2i(2, 3): 1}
	_battle.preview_move_cell = Vector2i(-1, -1)
	# Near-edge of east neighbour (soft would steal onto selected).
	var near := _cell_local(Vector2i(4, 3), Vector2(0.18, 0.5))
	var screen := _screen(near)
	var board_tap: Vector2i = BattlePick.resolve_board_tap(_battle, screen)
	if board_tap != Vector2i(4, 3):
		return "live board_tap east near-edge got %s" % str(board_tap)
	_tap(near)
	await _settle(3)
	if _battle.selected != _player_i:
		return "adjacent move tap deselected the unit"
	if _battle.preview_move_cell != Vector2i(4, 3):
		return "adjacent move preview not latched (got %s)" % str(_battle.preview_move_cell)
	return ""


## Soft-empty beside selected is not sticky — a small drag becomes a pan, not a tap.
func _e2e_sticky_pan_empty() -> String:
	_battle._cancel_selection()
	_battle.units[_player_i].pos = Vector2i(3, 3)
	_battle.units[_player_i].done = false
	_tap(_cell_local(Vector2i(3, 3), Vector2(0.5, 0.55)))
	await _settle(2)
	if _battle.selected != _player_i:
		return "sticky setup select failed"
	# Expire select-lock so a misclassified tap would deselect.
	_battle.set_meta("m_select_burst_msec", Time.get_ticks_msec() - 1000)
	# Select focus-pan can park `_board_pan` on a clamp edge; +x drift then looks
	# like sticky swallow. Park mid-stage with headroom, then recompute halo.
	BattlePick.cancel_focus_tween(_battle)
	BattleTouchConfirm.end_gesture(_battle)
	_battle._board_pan = Vector2.ZERO
	_battle._board_zoom = 1.0
	_battle._clamp_board_pan()
	_battle._apply_board_xform()
	await _settle(2)
	var halo := _screen(_cell_local(Vector2i(4, 3), Vector2(0.18, 0.5)))
	if BattlePick.near_selected_unit(_battle, halo, _player_i):
		return "live soft halo still sticky"
	var pan0: Vector2 = _battle._board_pan
	var base: float = _battle._board_router._slop()
	# Drift past base slop but under sticky*1.55 — if sticky wrongly applied, stays tap.
	var drift := base * 1.40
	_touch(0, true, halo)
	await get_tree().process_frame
	await get_tree().process_frame
	_drag(halo + Vector2(drift, 0), Vector2(drift, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	_touch(0, false, halo + Vector2(drift, 0))
	await _settle(6)
	if absf(_battle._board_pan.x - pan0.x) < 1.0:
		return "empty soft halo did not pan (sticky still swallowing) pan %s->%s drift %.1f" % [pan0, _battle._board_pan, drift]
	if _battle.selected != _player_i:
		return "pan from soft halo deselected"
	return ""


func _e2e_panel_ignore() -> String:
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	var col := _battle.get_node_or_null("MobileSideCol") as Control
	if col == null:
		return "side column missing for panel check"
	if col.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return "MobileSideCol still steals taps (filter %s)" % col.mouse_filter
	var card = _battle._unit_card
	if card != null and card.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return "unit card steals taps (filter %s)" % card.mouse_filter
	var board: Rect2 = _battle.get_meta("m_board_area")
	if col.position.x < board.end.x - 1.0:
		return "info column covers the board"
	return ""


## Right-notch landscape: crown/lip on the right board edge still selects.
func _e2e_right_notch_select() -> String:
	OS.set_environment("CK_SAFE_INSETS", "0,0,120,24")
	var insets := {"left": 0.0, "top": 0.0, "right": 120.0, "bottom": 24.0}
	var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
	MobileLayout.apply_root(_battle, fitted)
	_battle.set_meta("mobile_insets", insets)
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(6)
	_battle._cancel_selection()
	_battle.units[_player_i].pos = Vector2i(mini(_battle.MAP_W - 1, 5), 2)
	_battle.units[_player_i].done = false
	_battle._board_pan = Vector2.ZERO
	_battle._board_zoom = 1.0
	_battle._apply_board_xform()
	BattlePick.cancel_focus_tween(_battle)
	# Park the figure against the right lip of the board stage.
	var board: Rect2 = _battle.get_meta("m_board_area")
	var safe: Rect2 = _battle.get_meta("m_touch_safe")
	var lips: Dictionary = BattleEdgePick.facing_lips(safe, board)
	if not bool(lips.right) and not bool(lips.left) and not bool(lips.top):
		# Even without a facing lip after fit, centre select must still work.
		_tap(_cell_local(_battle.units[_player_i].pos, Vector2(0.5, 0.55)))
		await _settle(3)
		if _battle.selected != _player_i:
			return "right-notch centre select failed"
		return ""
	# Prefer a torso tap that still resolves; then a lip-side sliver if facing right.
	_tap(_cell_local(_battle.units[_player_i].pos, Vector2(0.5, 0.55)))
	await _settle(3)
	if _battle.selected != _player_i:
		return "right-notch select failed (sel %s lips %s)" % [_battle.selected, lips]
	return ""


func _cell_local(cell: Vector2i, rel: Vector2) -> Vector2:
	return _battle.ORIGIN + Vector2(cell) * float(_battle.CELL) + rel * float(_battle.CELL)


func _screen(local_board: Vector2) -> Vector2:
	var zoom := float(_battle._board_zoom)
	var screen_in: Vector2 = local_board * zoom + _battle._board_pan
	return _battle.get_global_transform() * screen_in


func _tap(local_board: Vector2) -> void:
	_battle._apply_board_gesture({"kind": "tap", "pos": _screen(local_board)})


func _touch(idx: int, pressed: bool, screen: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.pressed = pressed
	ev.position = screen
	_battle._gui_input(ev)


func _drag(screen: Vector2, relative: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = screen
	ev.relative = relative
	_battle._gui_input(ev)


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


class _TapHost extends RefCounted:
	var units: Array = []
	var selected: int = -1
	var attack_mode: bool = false
	var _board_pan: Vector2 = Vector2.ZERO
	var _board_zoom: float = 1.0
	var _board_origin: Vector2 = Vector2(40, 80)
	var _board_cell: int = 56

	func _get(property: StringName) -> Variant:
		# Duck-type battle_controller ORIGIN/CELL for BattlePick without gdlint class-variable-name.
		if property == &"ORIGIN":
			return _board_origin
		if property == &"CELL":
			return _board_cell
		return null

	func setup_armed(pos: Vector2i) -> void:
		units = [{"char": {"hp": 10}, "pos": pos, "team": "player"}]
		selected = 0
		attack_mode = false

	func _screen_to_local(p: Vector2) -> Vector2:
		return p

	func _pointer_to_cell(screen_pos: Vector2) -> Vector2i:
		var local := BattlePick.local_after_pan_zoom(_screen_to_local(screen_pos), _board_pan, _board_zoom)
		return BattlePick.cell_at_local(_board_origin, float(_board_cell), local, 16, 12)

	func _unit_at(pos: Vector2i) -> int:
		for i in units.size():
			if units[i].char.hp > 0 and units[i].pos == pos:
				return i
		return -1
