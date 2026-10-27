extends Node
## Fat Y1-A knife: select + range keep + confirm/cancel + camera share one
## BoardInset (notch + info + edge). Two real maps. No telegraph residue.
## Algebra → Scene A (ch0_pass) → Scene B (ch1_hill). Quit 1 on miss.

const PHONE := Vector2i(2400, 1080)
const NOTCH := "400,0,0,48"

var _battle: Control
var _player_i := -1
var _buddy_i := -1
var _foe_i := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL select/range/confirm/camera fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT SELECT RANGE CONFIRM CAMERA FAT PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra()
	if err != "":
		return err
	err = await _boot("ch0_pass")
	if err == "":
		err = await _scene_a()
	await _free_battle()
	if err != "":
		return err
	err = await _boot("ch1_hill")
	if err == "":
		err = await _scene_b()
	await _free_battle()
	return err


func _algebra() -> String:
	var err := _algebra_wiring()
	if err == "":
		err = _algebra_shared_inset()
	if err == "":
		err = _algebra_no_telegraph()
	return err


func _algebra_wiring() -> String:
	var inset := FileAccess.get_file_as_string("res://scripts/battle/battle_board_inset.gd")
	if inset.find("class_name BattleBoardInset") < 0:
		return "BattleBoardInset missing"
	if inset.find("clip_notch") < 0:
		return "BoardInset must call RangePreview.clip_notch"
	var range_src := FileAccess.get_file_as_string("res://scripts/battle/battle_range_preview.gd")
	if range_src.find("BattleBoardInset.for_host") < 0:
		return "playable_inset must use BoardInset"
	if range_src.find("static func clip_notch") < 0:
		return "clip_notch public export missing"
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_confirm_affordance.gd")
	if conf.find("BattleBoardInset.for_host") < 0:
		return "confirm chips/settle must use BoardInset"
	var depth := FileAccess.get_file_as_string("res://scripts/battle/battle_attack_cancel_depth.gd")
	if depth.find("BattleRangePreview.keep_selected") < 0:
		return "mode-exit cancel must keep_selected on shared inset"
	if depth.find("telegraph") >= 0 or depth.find("Telegraph") >= 0:
		return "cancel depth dragged telegraph"
	return ""


func _algebra_shared_inset() -> String:
	# Pure rect algebra: edge cut + blocker cut shrink, never grow.
	var stage := Rect2(0, 0, 800, 500)
	var edge := BattleBoardInset._cut_edge(stage, 48.0)
	if edge.size.x >= stage.size.x or edge.size.y >= stage.size.y:
		return "edge cut did not shrink"
	var right_block := Rect2(600, 0, 200, 500)
	var cut := BattleBoardInset._cut_blocker(stage, right_block)
	if cut.end.x > right_block.position.x + 1.0:
		return "right blocker must shave inset end"
	return ""


func _algebra_no_telegraph() -> String:
	for path in [
		"res://scripts/battle/battle_board_inset.gd",
		"res://scripts/battle/battle_confirm_affordance.gd",
		"res://scripts/battle/battle_attack_cancel_depth.gd",
		"res://scripts/battle/battle_range_preview.gd",
	]:
		var body := FileAccess.get_file_as_string(path)
		# Range preview historically mentions no telegraph; ban new residue.
		if body.find("foe_opening_telegraph") >= 0 or body.find("BattleLinkTelegraph") >= 0:
			return "%s dragged telegraph residue" % path
	return ""


func _boot(map_id: String) -> String:
	await _set_window()
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
	GameState.settings["touch_confirm"] = true
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
	_battle.set_meta("mobile_origin", fitted.get("position", Vector2.ZERO))
	_battle.set_meta("mobile_insets", insets)
	MobileLayout.apply_root(_battle, fitted)
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(8)
	if str(_battle.map_id) != map_id:
		return "map_id want %s got %s" % [map_id, _battle.map_id]
	if not _battle._mobile_landscape():
		return "battle did not enter landscape on %s" % map_id
	return _arrange()


func _arrange() -> String:
	_player_i = -1
	_buddy_i = -1
	_foe_i = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player":
			if _player_i < 0:
				_player_i = i
				u.pos = Vector2i(3, 3)
				u.done = false
				u.char.temp_ignore_zoc = true
				u.char.set_meta("battle_move_mod", 8)
			elif _buddy_i < 0:
				_buddy_i = i
				u.pos = Vector2i(1, 1)
				u.done = false
			else:
				u.done = true
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
			u.pos = Vector2i(5, 3)
			u.char.hp = maxi(int(u.char.hp), 12)
	if _player_i < 0 or _foe_i < 0:
		return "deploy missing player/enemy"
	if _buddy_i < 0:
		var buddy = CharacterFactory.make_tutorial_militia(0)
		buddy.hp = buddy.max_hp
		_battle.units.append({"char": buddy, "pos": Vector2i(1, 1), "team": "player", "done": false, "tag": ""})
		_buddy_i = _battle.units.size() - 1
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
	BattleLandStrike.clear(_battle)
	return ""


func _scene_a() -> String:
	_battle._select_player(_player_i)
	await _settle(4)
	var err := _scene_a_range_shared()
	if err == "":
		err = await _scene_a_chips_cancel()
	if err == "":
		err = await _scene_a_mode_cancel()
	return err


func _scene_a_range_shared() -> String:
	BattleRangePreview.publish(_battle)
	var shared: Rect2 = BattleBoardInset.for_host(_battle)
	var playable: Rect2 = BattleRangePreview.playable_inset(_battle)
	if absf(shared.position.x - playable.position.x) > 1.0 or absf(shared.size.x - playable.size.x) > 1.0:
		return "scene A: range inset != BoardInset (%s vs %s)" % [playable, shared]
	BattleRangePreview.keep_selected(_battle)
	if not _battle.has_meta("m_range_keep"):
		return "scene A: keep_selected did not stamp m_range_keep"
	var keep_info = _battle.get_meta("m_range_keep")
	if keep_info is Dictionary and keep_info.has("inset"):
		var ki: Rect2 = keep_info["inset"]
		if absf(ki.position.x - shared.position.x) > 1.0:
			return "scene A: keep inset drifted from BoardInset"
	return ""


func _scene_a_chips_cancel() -> String:
	var dest := await _latch_move()
	if dest.x < 0:
		return "scene A: no legal move to latch"
	if not BattleConfirmAffordance.preview_latched(_battle):
		return "scene A: preview not latched"
	var chips_bounds: Rect2 = BattleConfirmAffordance.chip_bounds(_battle)
	var chip_shared: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	if absf(chips_bounds.position.x - chip_shared.position.x) > 1.0 \
			or absf(chips_bounds.size.x - chip_shared.size.x) > 1.0:
		return "scene A: chip_bounds != BoardInset (%s vs %s)" % [chips_bounds, chip_shared]
	var pan0: Vector2 = _battle._board_pan
	var kind := BattleAttackCancelDepth.step(_battle)
	await _settle(4)
	if kind != "preview":
		return "scene A: first cancel want preview got %s" % kind
	if _battle.preview_move_cell.x >= 0:
		return "scene A: preview survived cancel"
	if int(_battle.selected) != _player_i:
		return "scene A: cancel cleared selection"
	if _battle._board_pan.distance_to(pan0) > 2.0:
		return "scene A: preview-cancel yanked camera"
	return ""


func _scene_a_mode_cancel() -> String:
	_battle.attack_mode = true
	BattleRangePreview.publish(_battle)
	if DeviceProfile.is_mobile():
		BattleMobileBar.rebuild(_battle)
	var pan1: Vector2 = _battle._board_pan
	var kind := BattleAttackCancelDepth.step(_battle)
	await _settle(4)
	if kind != "mode":
		return "scene A: mode cancel want mode got %s" % kind
	if bool(_battle.attack_mode):
		return "scene A: attack_mode survived cancel"
	if int(_battle.selected) != _player_i:
		return "scene A: mode-cancel cleared selection"
	if _battle._board_pan.distance_to(pan1) > 240.0:
		return "scene A: mode-cancel yanked camera hard (%s → %s)" % [pan1, _battle._board_pan]
	return ""


func _scene_b() -> String:
	_battle.units[_player_i].pos = Vector2i(3, 3)
	_battle.units[_foe_i].pos = Vector2i(5, 3)
	_battle.units[_buddy_i].pos = Vector2i(1, 5)
	_battle.units[_player_i].done = false
	_battle._select_player(_player_i)
	await _settle(3)
	# Notch identity when fitted; bare-at-zero still clips.
	var stage: Rect2 = _battle.get_meta("m_board_area")
	var raw := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	var notch_fitted := BattleRangePreview.clip_notch(_battle, raw)
	if absf(notch_fitted.position.x - raw.position.x) > 6.0:
		return "scene B: fitted double-counted notch"
	var saved_pos: Vector2 = _battle.position
	var saved_mo: Vector2 = _battle.get_meta("mobile_origin")
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
	_battle.set_meta("mobile_origin", Vector2.ZERO)
	_battle.position = Vector2.ZERO
	_battle.force_update_transform()
	var bare := BattleRangePreview.clip_notch(_battle, raw)
	_battle.set_meta("mobile_origin", saved_mo)
	_battle.position = saved_pos
	_battle.force_update_transform()
	if bare.position.x < raw.position.x + 40.0:
		return "scene B: bare notch did not clip lip (bare %s raw %s)" % [bare, raw]
	# Confirm settle uses BoardInset (notch-safe).
	_battle.preview_move_cell = Vector2i(4, 3)
	_battle.preview_attack_ui = -1
	if DeviceProfile.is_mobile():
		BattleMobileBar.rebuild(_battle)
	BattleTouchConfirm.confirm_move(_battle)
	await _settle(8)
	if DeviceProfile.is_mobile() and not _battle.has_meta("m_confirm_settle") \
			and not _battle.has_meta("m_land_strike"):
		return "scene B: missing settle/land meta after confirm"
	if _battle.has_meta("m_confirm_settle"):
		var settle = _battle.get_meta("m_confirm_settle")
		if settle is Dictionary and settle.has("inset"):
			var si: Rect2 = settle["inset"]
			var expect: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
			# Settle stamped at confirm time; allow small drift if layout shifted.
			if absf(si.position.x - expect.position.x) > 48.0:
				return "scene B: settle inset far from BoardInset (%s vs %s)" % [si, expect]
	return ""


func _latch_move() -> Vector2i:
	_battle._select_player(_player_i)
	await _settle(2)
	var best := Vector2i(-1, -1)
	var best_d := -1
	var stand: Vector2i = _battle.units[_player_i].pos
	for key in _battle.move_cells.keys():
		var cell: Vector2i = key
		if cell == stand or _battle._unit_at(cell) >= 0:
			continue
		var dist := absi(cell.x - stand.x) + absi(cell.y - stand.y)
		if dist > best_d:
			best_d = dist
			best = cell
	if best.x < 0:
		return best
	_battle.preview_move_cell = best
	_battle.preview_attack_ui = -1
	if DeviceProfile.is_mobile():
		BattleMobileBar.rebuild(_battle)
	BattleRangePreview.publish(_battle)
	await _settle(2)
	return best


func _set_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	DisplayServer.window_set_size(PHONE)
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
		await _settle(2)
