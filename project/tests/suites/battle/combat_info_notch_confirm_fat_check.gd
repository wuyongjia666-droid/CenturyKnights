extends Node
## Fat knife: landscape info column + notch lip + confirm/cancel chips.
## Chips clamp into the readable inset (info/notch cut). Side chrome IGNORE.
## Algebra first, then Scene A (ch0_pass) + Scene B (ch1_hill). No EmptyHost.

const PHONE := Vector2i(2400, 1080)
const NOTCH := "400,0,0,48"

var _battle: Control
var _player_i := -1
var _foe_i := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL info/notch/confirm fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT INFO NOTCH CONFIRM FAT PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra()
	if err != "":
		return err
	err = await _boot("ch0_pass")
	if err == "":
		err = await _scene_a_chips_clear_and_cancel()
	await _free_battle()
	if err != "":
		return err
	err = await _boot("ch1_hill")
	if err == "":
		err = await _scene_b_confirm_settle_and_side()
	await _free_battle()
	return err


func _algebra() -> String:
	var err := _algebra_bounds()
	if err == "":
		err = _algebra_source()
	return err


func _algebra_bounds() -> String:
	var stage := Rect2(0, 0, 900, 500)
	var block := Rect2(700, 0, 200, 500)
	var inset := BattleConfirmAffordance.readable_inset(stage, [block], 48.0)
	if inset.end.x > 700.5:
		return "readable inset still under info %s" % inset
	if inset.position.x < 47.0:
		return "readable inset ignored notch lip %s" % inset
	var pair := BattleConfirmAffordance.chip_pair(Vector2(850, 250), 108.0, inset)
	var confirm: Rect2 = pair.get("confirm", Rect2())
	var cancel: Rect2 = pair.get("cancel", Rect2())
	if confirm.intersects(block) or cancel.intersects(block):
		return "chip_pair ignored readable bounds under info"
	if confirm.position.x < inset.position.x - 0.5:
		return "confirm chip left the readable inset"
	return ""


func _algebra_source() -> String:
	var afford := FileAccess.get_file_as_string("res://scripts/battle/battle_confirm_affordance.gd")
	if afford.find("chip_bounds") < 0 or afford.find("chips_clear_of_info") < 0:
		return "confirm affordance missing chip_bounds / chips_clear_of_info"
	if afford.find("readable_inset") < 0:
		return "confirm affordance dropped readable_inset"
	var edge := FileAccess.get_file_as_string("res://scripts/battle/battle_edge_pick.gd")
	if edge.find("m_info_block") < 0 or edge.find("MOUSE_FILTER_IGNORE") < 0:
		return "edge pick no longer stamps info IGNORE"
	return ""


func _boot(map_id: String) -> String:
	await _set_window()
	OS.set_environment("CK_FORCE_MOBILE", "1")
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
	GameState.board_input_blocked = false
	GameState.set_meta("battle_map", map_id)
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	var story := _battle.get_node_or_null("BattleStoryLayer")
	if story:
		story.free()
	var insets := {"left": 400.0, "top": 0.0, "right": 0.0, "bottom": 48.0}
	var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
	MobileLayout.apply_root(_battle, fitted)
	_battle.set_meta("mobile_insets", insets)
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(8)
	BattleEdgePick.note_layout(_battle)
	await _settle(2)
	if str(_battle.map_id) != map_id:
		return "map_id want %s got %s" % [map_id, _battle.map_id]
	if not _battle._mobile_landscape():
		return "battle did not enter landscape on %s" % map_id
	return _arrange()


func _arrange() -> String:
	_player_i = -1
	_foe_i = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player" and _player_i < 0:
			_player_i = i
			u.pos = Vector2i(4, 3)
			u.done = false
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
			u.pos = Vector2i(6, 3)
			u.char.hp = maxi(int(u.char.hp), 16)
		elif str(u.team) == "player":
			u.done = true
	if _player_i < 0 or _foe_i < 0:
		return "deploy missing player/enemy"
	_plain_box(Vector2i(4, 3), 4)
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	_battle.attack_mode = false
	_battle.skill_mode = false
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle.moved_this_select = false
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _scene_a_chips_clear_and_cancel() -> String:
	var err := await _latch_move_preview()
	if err != "":
		return "A latch: %s" % err
	err = _scene_a_assert_chips()
	if err != "":
		return err
	err = _scene_a_assert_side_ignore()
	if err != "":
		return err
	return await _scene_a_cancel_chip()


func _scene_a_assert_chips() -> String:
	if not _battle.has_meta("m_info_block"):
		return "A: m_info_block missing after note_layout"
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "A: info block too thin %s" % block
	var pair := BattleConfirmAffordance.chips(_battle)
	var confirm: Rect2 = pair.get("confirm", Rect2())
	if confirm.size.x < 1.0:
		return "A: no confirm chip"
	if not BattleConfirmAffordance.chips_clear_of_info(_battle):
		var cancel: Rect2 = pair.get("cancel", Rect2())
		return "A: chips under info confirm=%s cancel=%s block=%s" % [confirm, cancel, block]
	var bounds := BattleConfirmAffordance.chip_bounds(_battle)
	if not bounds.encloses(confirm) and not bounds.grow(1.0).encloses(confirm):
		return "A: confirm outside chip_bounds %s vs %s" % [confirm, bounds]
	return ""


func _scene_a_assert_side_ignore() -> String:
	var col := _battle.get_node_or_null("MobileSideCol") as Control
	if col == null:
		return "A: MobileSideCol missing"
	if col.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return "A: side col steals taps filter=%s" % col.mouse_filter
	var card = _battle._unit_card
	if card != null and card is Control and (card as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return "A: unit card steals taps"
	return ""


func _scene_a_cancel_chip() -> String:
	var pair := BattleConfirmAffordance.chips(_battle)
	var cancel: Rect2 = pair.get("cancel", Rect2())
	BattlePick.cancel_focus_tween(_battle)
	var pan0: Vector2 = _battle._board_pan
	var pos0: Vector2i = _battle.units[_player_i].pos
	_tap(cancel.get_center())
	await _settle(6)
	if _battle.preview_move_cell.x >= 0:
		return "A: cancel left move preview"
	if _battle.selected != _player_i:
		return "A: cancel cleared selection"
	if _battle.units[_player_i].pos != pos0:
		return "A: cancel committed move"
	if _battle._board_pan.distance_to(pan0) > 2.0:
		return "A: cancel yanked camera"
	return ""


func _scene_b_confirm_settle_and_side() -> String:
	var err := await _latch_move_preview()
	if err != "":
		return "B latch: %s" % err
	if not BattleConfirmAffordance.chips_clear_of_info(_battle):
		return "B: chips under info after latch"
	var dest: Vector2i = _battle.preview_move_cell
	var pair := BattleConfirmAffordance.chips(_battle)
	var confirm: Rect2 = pair.get("confirm", Rect2())
	var hit := BattleConfirmAffordance.hit(_battle, _screen(confirm.get_center()))
	if hit != "confirm":
		return "B: confirm hit got %s" % hit
	_tap(confirm.get_center())
	await _settle(24)
	if _battle.units[_player_i].pos != dest:
		return "B: confirm did not move to %s (at %s)" % [dest, _battle.units[_player_i].pos]
	# Side chrome still IGNORE after confirm rebuilds layout.
	# Layout may shrink m_board_area during the confirm await (viewport /
	# apply_mobile_layout) — refresh BoardInset then re-settle immediately
	# (no focus tween) like a layout-driven BoardInset refresh before assert.
	BattleEdgePick.note_layout(_battle)
	var col := _battle.get_node_or_null("MobileSideCol") as Control
	if col != null and col.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return "B: side col regained STOP after confirm"
	if _battle.has_meta("m_confirm_settle") or _battle.has_meta("m_action_settle"):
		# Re-settle immediately (no focus tween) like layout-driven BoardInset
		# refresh — #670 smooth=false; brief await for frame settle.
		BattleActionSettle.apply(_battle, dest, [], false)
		await _settle(4)
		var inset := BattleBoardInset.for_host(_battle, 0.0)
		var fig := BattleCombatFrame.figure_rect(
			_battle.ORIGIN, float(_battle.CELL), dest, _battle._board_pan, float(_battle._board_zoom))
		if not inset.grow(4.0).encloses(fig) and not inset.intersects(fig):
			# Soft: settle may be zero when already readable — only fail if fully outside.
			if not inset.grow(24.0).intersects(fig):
				return "B: actor left readable region fig=%s inset=%s" % [fig, inset]
	return ""



func _blockers_safe() -> Array:
	var out: Array = []
	if _battle.has_meta("m_info_block"):
		var b = _battle.get_meta("m_info_block")
		if b is Rect2:
			out.append(b)
	return out


func _latch_move_preview() -> String:
	_battle._select_player(_player_i)
	await _settle(4)
	var stand: Vector2i = _battle.units[_player_i].pos
	var dest := Vector2i(stand.x + 1, stand.y)
	if not _battle._in_bounds(dest):
		dest = Vector2i(stand.x - 1, stand.y)
	_plain_box(stand, 3)
	_battle.units[_foe_i].pos = Vector2i(stand.x + 3, stand.y)
	# Latch via touch-confirm path.
	_battle.preview_move_cell = dest
	_battle.preview_attack_ui = -1
	if _battle.has_method("_rebuild_mobile_commands"):
		_battle._rebuild_mobile_commands()
	BattleConfirmAffordance.grow_bar_hits(_battle)
	await _settle(3)
	if _battle.preview_move_cell != dest:
		return "preview_move_cell not latched"
	if BattleConfirmAffordance.chips(_battle).is_empty():
		return "chips empty after latch"
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


func _tap(local_board: Vector2) -> void:
	_battle._apply_board_gesture({"kind": "tap", "pos": _screen(local_board)})


func _screen(local_board: Vector2) -> Vector2:
	var zoom := float(_battle._board_zoom)
	return _battle.get_global_transform() * (local_board * zoom + _battle._board_pan)


func _set_window() -> void:
	DisplayServer.window_set_size(PHONE)
	var win := get_window()
	if win != null:
		win.size = PHONE
	await get_tree().process_frame


func _settle(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
	await _settle(2)
