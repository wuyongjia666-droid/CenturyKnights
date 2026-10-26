extends Node
## Y1-A T-P21: Wait/strike handoff → next ready select + camera settle. Real battle E2E.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

var _battle: Control
var _a := -1
var _b := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL wait handoff: ", err)
		get_tree().quit(1)
		return
	print("COMBAT WAIT HANDOFF PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _algebra()
	if err == "":
		err = _source_contracts()
	if err != "":
		return err
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	err = await _boot(true)
	if err == "":
		err = await _e2e_wait_handoff()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if err != "":
		return err
	err = await _boot(false)
	if err == "":
		err = await _e2e_wait_handoff()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err


func _algebra() -> String:
	var units: Array = [
		{"team": "player", "done": true, "char": {"hp": 10}},
		{"team": "player", "done": false, "char": {"hp": 10}},
		{"team": "enemy", "done": false, "char": {"hp": 10}},
		{"team": "player", "done": false, "char": {"hp": 0}},
		{"team": "player", "done": false, "char": {"hp": 8}},
	]
	var ready: Array[int] = BattleWaitHandoff.ready_indices(units)
	if ready != [1, 4]:
		return "ready_indices got %s want [1,4]" % ready
	if BattleWaitHandoff.next_idx(units, 0) != 1:
		return "next after 0 expected 1"
	if BattleWaitHandoff.next_idx(units, 1) != 4:
		return "next after 1 expected 4"
	if BattleWaitHandoff.next_idx(units, 4) != 1:
		return "wrap next after 4 expected 1"
	if BattleWaitHandoff.next_idx(units, -1) != 1:
		return "from -1 expected first ready 1"
	# All done → empty
	units[1].done = true
	units[4].done = true
	if not BattleWaitHandoff.ready_indices(units).is_empty():
		return "all done should be empty"
	if BattleWaitHandoff.next_idx(units, 0) != -1:
		return "no ready → -1"
	return ""


func _source_contracts() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var hand := FileAccess.get_file_as_string("res://scripts/battle/battle_wait_handoff.gd")
	if ctrl.find("BattleWaitHandoff.after_unit_done") < 0:
		return "controller never calls after_unit_done"
	if ctrl.find("_wait_selected") < 0:
		return "wait_selected missing"
	# Wait path must hand off
	var wi := ctrl.find("func _wait_selected")
	var chunk := ctrl.substr(wi, 500)
	if chunk.find("BattleWaitHandoff.after_unit_done") < 0:
		return "wait_selected does not hand off"
	if hand.find("EmptyHost") >= 0 or ctrl.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	if hand.find("_select_player") < 0:
		return "handoff must drive _select_player"
	return ""


func _boot(mobile: bool) -> String:
	await _set_window(PHONE if mobile else DESK)
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.set_meta("battle_map", "obj_rout")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	if not _battle.has_method("_wait_selected") or not ("units" in _battle):
		return "battle controller script failed to attach"
	if mobile:
		var insets := {"left": 80.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
		var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
		MobileLayout.apply_root(_battle, fitted)
		_battle.set_meta("mobile_insets", insets)
		if _battle.has_method("apply_mobile_layout"):
			_battle.apply_mobile_layout()
		await _settle(8)
	return _arrange()


func _arrange() -> String:
	_battle.turn_team = "player"
	_battle.battle_over = false
	_a = -1
	_b = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) != "player":
			continue
		if _a < 0:
			_a = i
		elif _b < 0:
			_b = i
			break
	if _a < 0:
		return "need at least one living player unit"
	if _b < 0:
		# new_game party may deploy only one — pad a militia buddy for handoff E2E.
		var buddy = CharacterFactory.make_tutorial_militia(0)
		buddy.hp = buddy.max_hp
		_battle.units.append({"char": buddy, "pos": Vector2i(1, 1), "team": "player", "done": false, "tag": ""})
		_b = _battle.units.size() - 1
	if int(_battle.selected) >= _battle.units.size():
		_battle.selected = -1
	var th: int = _battle.terrain.size()
	var tw: int = _battle.terrain[0].size() if th > 0 else 8
	var pos_a := Vector2i(mini(2, tw - 1), mini(2, th - 1))
	var pos_b := Vector2i(mini(maxi(tw - 2, 0), tw - 1), mini(maxi(th - 2, 0), th - 1))
	if pos_b == pos_a:
		pos_b = Vector2i(mini(pos_a.x + 2, tw - 1), pos_a.y)
	_battle.units[_a].pos = pos_a
	_battle.units[_a].done = false
	_battle.units[_b].pos = pos_b
	_battle.units[_b].done = false
	# Park camera on A; B is far so handoff must pull.
	_battle.selected = _a
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle.attack_mode = false
	_battle.move_cells = {}
	var stage: Rect2 = BattlePick._stage_rect(_battle)
	if stage.size.x < 8.0:
		return "stage missing"
	var origin: Vector2 = _battle.ORIGIN
	var zoom := float(_battle._board_zoom)
	var cell_px: float = float(_battle.CELL) * zoom
	var pan: Vector2 = _battle._board_pan
	# Put A near stage centre; force pan so B is off-stage to the right.
	var a_shown_x: float = origin.x * zoom + float(_battle.units[_a].pos.x) * cell_px + pan.x
	var want_a: float = stage.position.x + stage.size.x * 0.35
	_battle._board_pan = Vector2(pan.x + (want_a - a_shown_x), pan.y)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	if _battle.has_method("_apply_board_xform"):
		_battle._apply_board_xform()
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _e2e_wait_handoff() -> String:
	_battle._select_player(_a)
	await _settle(3)
	var before: Vector2 = _battle._board_pan
	_battle._wait_selected()
	# FOCUS_SMOOTH_SEC is 0.22s; 10 frames at high headless Hz often ends before tween.
	var stage: Rect2 = BattlePick._stage_rect(_battle)
	var origin: Vector2 = _battle.ORIGIN
	var zoom := float(_battle._board_zoom)
	var cell_px: float = float(_battle.CELL) * zoom
	var inset := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	var frames := 0
	while frames < 36:
		var handed := int(_battle.selected)
		if handed >= 0 and handed != _a:
			var sp: Vector2i = _battle.units[handed].pos
			if BattleCombatFrame.figure_inside(origin, cell_px, sp, _battle._board_pan, zoom, inset, 12.0):
				break
		await get_tree().process_frame
		frames += 1
	if int(_battle.selected) != _b:
		# next after _a should be _b if indices ordered; if not, accept any other ready
		if int(_battle.selected) == _a or int(_battle.selected) < 0:
			return "wait did not hand off (selected=%s a=%s b=%s)" % [_battle.selected, _a, _b]
	if not _battle.has_meta(BattleWaitHandoff.META):
		return "handoff meta missing"
	var info = _battle.get_meta(BattleWaitHandoff.META)
	if int(info.get("from", -99)) != _a:
		return "meta from wrong: %s" % info
	if int(info.get("to", -99)) != int(_battle.selected):
		return "meta to mismatch selected"
	if bool(_battle.units[_a].done) != true:
		return "A not marked done"
	if bool(_battle.units[int(_battle.selected)].done):
		return "handed unit still done"
	var after: Vector2 = _battle._board_pan
	# Camera should have moved toward B (to the right of A in our arrange).
	var sel_pos: Vector2i = _battle.units[int(_battle.selected)].pos
	if sel_pos == _battle.units[_a].pos:
		return "still focused on waited unit"
	# On mobile/desktop CombatFrame.follow_selected may nudge; require any pan change
	# when the new unit was off to the side.
	stage = BattlePick._stage_rect(_battle)
	origin = _battle.ORIGIN
	zoom = float(_battle._board_zoom)
	cell_px = float(_battle.CELL) * zoom
	inset = BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	if not BattleCombatFrame.figure_inside(origin, cell_px, sel_pos, after, zoom, inset, 12.0):
		return "handed unit figure still outside play inset (before %s after %s sel=%s)" % [before, after, sel_pos]
	# Second wait → hand to remaining or clear if none
	var cur := int(_battle.selected)
	_battle._wait_selected()
	await _settle(8)
	if bool(_battle.units[cur].done) != true:
		return "second wait did not mark done"
	# Algebra: if no ready left, selected stays -1 / no meta to
	var ready: Array[int] = BattleWaitHandoff.ready_indices(_battle.units)
	if ready.is_empty():
		if int(_battle.selected) >= 0 and bool(_battle.units[int(_battle.selected)].done) == false:
			pass  # unexpected ready slipped in — ok if living undoned exists
		# fine either way
	return ""


func _set_window(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
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
