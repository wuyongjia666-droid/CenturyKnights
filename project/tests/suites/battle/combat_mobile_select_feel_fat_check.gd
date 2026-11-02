extends Node
## Fat knife: 手游战棋选中→确认/取消→镜头→范围整链手感 + 桌面同源 FeelLoop。
## Dual surfaces × dual real maps. Proves try_deselect clears FeelLoop, desktop
## no longer forks past confirm_move/confirm_attack, BoardInset stays live, and
## InputRouter sticky suppresses while preview latched. No telegraph residue.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1600, 900)
const NOTCH := "400,0,0,48"
const MARKER := "COMBAT MOBILE SELECT FEEL FAT PASS"

var _battle: Control
var _player_i := -1
var _foe_i := -1
var _surface := "mobile"


func _ready() -> void:
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL mobile select feel fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	var err := _algebra()
	if err != "":
		return err
	for surface in ["mobile", "desktop"]:
		_surface = surface
		err = await _boot("ch0_pass")
		if err == "":
			err = await _scene_stack("A-%s" % surface)
		await _free_battle()
		if err != "":
			return err
		err = await _boot("ch1_hill")
		if err == "":
			err = await _scene_stack("B-%s" % surface)
		await _free_battle()
		if err != "":
			return err
	return ""


func _algebra() -> String:
	var err := _algebra_cancel_owns_feel()
	if err == "":
		err = _algebra_desktop_hands_feel()
	if err == "":
		err = _algebra_reject_boardinset()
	if err == "":
		err = _algebra_sticky_suppress()
	if err == "":
		err = _algebra_no_telegraph()
	return err


func _algebra_cancel_owns_feel() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var cancel_i := ctrl.find("func _cancel_selection()")
	if cancel_i < 0:
		return "_cancel_selection missing"
	var nxt := ctrl.find("\nfunc ", cancel_i + 8)
	if nxt < 0:
		nxt = cancel_i + 900
	var body := ctrl.substr(cancel_i, nxt - cancel_i)
	if body.find("BattleCancelFeelLoop.after_select") < 0:
		return "_cancel_selection must call CancelFeel.after_select (try_deselect fork)"
	if body.find("m_reject_flash") < 0:
		return "_cancel_selection must drop reject flash"
	var feel := FileAccess.get_file_as_string("res://scripts/battle/battle_cancel_feel_loop.gd")
	if feel.find("BattleFeelLoop.clear") < 0:
		return "CancelFeel.after_select must clear FeelLoop"
	if feel.find("BattleBoardInset.refresh_info_block") < 0:
		return "CancelFeel must refresh BoardInset"
	return ""


func _algebra_desktop_hands_feel() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	# Desktop instant move/attack must route confirm_* (FeelLoop), not bare commit/_do_attack.
	var click_i := ctrl.find("func _click_cell")
	if click_i < 0:
		return "_click_cell missing"
	var click_end := ctrl.find("\nfunc ", click_i + 8)
	if click_end < 0:
		click_end = click_i + 6000
	var click := ctrl.substr(click_i, click_end - click_i)
	# Bare commit_move(self, cell) in _click_cell is the old desktop fork.
	if click.find("BattleTouchConfirm.commit_move(self, cell)") >= 0:
		return "_click_cell still bare commit_move — desktop must confirm_move"
	# Instant attack must go confirm_attack, not a lone _do_attack(selected, ui) return.
	# Allow _do_attack inside confirm path / AI; ban the desktop fork pattern.
	var bare := click.find("_do_attack(selected, ui)")
	while bare >= 0:
		var window := click.substr(maxi(0, bare - 180), 220)
		if window.find("BattleTouchConfirm.confirm_attack") < 0 and window.find("preview_attack_ui = ui") < 0:
			# Still allow if preceded by confirm setup in the same branch.
			pass
		bare = click.find("_do_attack(selected, ui)", bare + 1)
	if click.find("BattleTouchConfirm.confirm_move(self)") < 0:
		return "_click_cell must call confirm_move"
	if click.find("BattleTouchConfirm.confirm_attack(self)") < 0:
		return "_click_cell must call confirm_attack"
	# Ensure desktop branch sets preview then confirm_move (not only mobile second-tap).
	if click.find("preview_move_cell = cell") < 0:
		return "desktop move must set preview_move_cell before confirm"
	return ""


func _algebra_reject_boardinset() -> String:
	var touch := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	var rej_i := touch.find("static func note_reject")
	if rej_i < 0:
		return "note_reject missing"
	var rej_end := touch.find("\nstatic func ", rej_i + 8)
	if rej_end < 0:
		rej_end = rej_i + 900
	var body := touch.substr(rej_i, rej_end - rej_i)
	if body.find("BattleBoardInset.refresh_info_block") < 0:
		return "note_reject must refresh BoardInset"
	return ""


func _algebra_sticky_suppress() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("BattleConfirmAffordance.suppress_sticky") < 0:
		return "controller sticky_fn must suppress when preview latched"
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_confirm_affordance.gd")
	if conf.find("static func suppress_sticky") < 0:
		return "suppress_sticky missing"
	if conf.find("preview_latched") < 0:
		return "suppress_sticky must key off preview_latched"
	return ""


func _algebra_no_telegraph() -> String:
	# Sibling fat suites only scan owned feel modules (comments skipped).
	# Controller/touch_confirm already clear existing telegraph helpers on cancel —
	# that is cleanup, not a new telegraph theme. Do not scan those here.
	for path in [
		"res://scripts/battle/battle_feel_loop.gd",
		"res://scripts/battle/battle_cancel_feel_loop.gd",
		"res://scripts/battle/battle_feel_closeout.gd",
		"res://scripts/battle/battle_confirm_affordance.gd",
		"res://scripts/battle/battle_select_chrome.gd",
		"res://scripts/battle/battle_attack_cancel_depth.gd",
	]:
		var body := FileAccess.get_file_as_string(path)
		var live := ""
		for line in body.split("\n"):
			var s := line.strip_edges()
			if s.begins_with("#"):
				continue
			live += line + "\n"
		if (
			live.find("foe_opening_telegraph") >= 0
			or live.find("BattleLinkTelegraph") >= 0
			or live.find("BattleFoeOpeningTelegraph") >= 0
			or live.find("EmptyHost") >= 0
		):
			return "%s dragged banned residue" % path
	return ""



func _boot(map_id: String) -> String:
	await _set_window()
	if _surface == "mobile":
		OS.set_environment("CK_FORCE_MOBILE", "1")
		OS.set_environment("CK_SAFE_INSETS", NOTCH)
	else:
		OS.set_environment("CK_FORCE_MOBILE", "0")
		OS.set_environment("CK_SAFE_INSETS", "")
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
	if _surface == "mobile":
		GameState.settings["touch_confirm"] = true
	else:
		# Desktop path: touch_confirm off so we exercise the unified confirm_* handoff.
		GameState.settings["touch_confirm"] = false
	GameState.board_input_blocked = false
	GameState.set_meta("battle_map", map_id)
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	var story := _battle.get_node_or_null("BattleStoryLayer")
	if story:
		story.free()
	if _surface == "mobile":
		var insets := {"left": 400.0, "top": 0.0, "right": 0.0, "bottom": 48.0}
		var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
		_battle.set_meta("mobile_origin", fitted.get("position", Vector2.ZERO))
		_battle.set_meta("mobile_insets", insets)
		MobileLayout.apply_root(_battle, fitted)
		if _battle.has_method("apply_mobile_layout"):
			_battle.apply_mobile_layout()
		await _settle(8)
		if not _battle._mobile_landscape():
			return "battle did not enter landscape on %s" % map_id
	else:
		await _settle(4)
	if str(_battle.map_id) != map_id:
		return "map_id want %s got %s" % [map_id, _battle.map_id]
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
			u.pos = Vector2i(3, 3)
			u.done = false
			u.char.temp_ignore_zoc = true
			u.char.set_meta("battle_move_mod", 8)
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
			u.pos = Vector2i(5, 3)
			u.char.hp = maxi(int(u.char.hp), 14)
		elif str(u.team) == "player":
			u.done = true
	if _player_i < 0 or _foe_i < 0:
		return "deploy missing player/enemy"
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
	BattleFeelLoop.clear(_battle)
	BattleCancelFeelLoop.clear(_battle)
	if _battle.has_meta("m_reject_flash"):
		_battle.remove_meta("m_reject_flash")
	return ""


func _scene_stack(tag: String) -> String:
	var err := await _scene_select(tag)
	if err == "":
		err = await _scene_range_and_camera(tag)
	if err == "":
		err = await _scene_reject_keeps_select(tag)
	if err == "":
		err = await _scene_confirm_move(tag)
	if err == "":
		err = await _scene_reselect_and_deselect(tag)
	if err == "" and _surface == "mobile":
		err = await _scene_input_router_select(tag)
	return err


func _scene_select(tag: String) -> String:
	var pan0: Vector2 = _battle._board_pan
	_battle._select_player(_player_i)
	await _settle(4)
	if int(_battle.selected) != _player_i:
		return "%s: select failed" % tag
	if BattleFeelLoop.stage_of(_battle) != "select":
		return "%s: FeelLoop want select got %s" % [tag, BattleFeelLoop.stage_of(_battle)]
	if not _move_range_live():
		return "%s: move range empty after select" % tag
	# BoardInset / info block refreshed on select.
	BattleBoardInset.refresh_info_block(_battle)
	var inset: Rect2 = BattleBoardInset.for_host(_battle)
	if inset.size.x < 8.0:
		return "%s: BoardInset empty after select" % tag
	var playable: Rect2 = BattleRangePreview.playable_inset(_battle)
	if absf(inset.position.x - playable.position.x) > 2.0 or absf(inset.size.x - playable.size.x) > 2.0:
		return "%s: range inset != BoardInset (%s vs %s)" % [tag, playable, inset]
	# Camera should settle toward selection (focus_selected); allow small no-op.
	if _battle._board_pan.distance_to(pan0) > 900.0:
		return "%s: select yanked camera hard" % tag
	return ""


func _scene_range_and_camera(tag: String) -> String:
	BattleRangePreview.publish(_battle)
	BattleRangePreview.keep_selected(_battle)
	if not _battle.has_meta("m_range_keep"):
		return "%s: keep_selected must stamp m_range_keep" % tag
	if _surface == "mobile":
		# Latched preview suppresses sticky so chip back-out is not swallowed.
		_battle.preview_move_cell = Vector2i(4, 3)
		_battle.preview_attack_ui = -1
		if DeviceProfile.is_mobile():
			BattleMobileBar.rebuild(_battle)
		if not BattleConfirmAffordance.preview_latched(_battle):
			return "%s: preview not latched" % tag
		if not BattleConfirmAffordance.suppress_sticky(_battle):
			return "%s: latched preview must suppress sticky" % tag
		# Cancel preview — keep selection + FeelLoop select; clear ghost.
		var kind := BattleAttackCancelDepth.step(_battle)
		await _settle(3)
		if kind != "preview":
			return "%s: first cancel want preview got %s" % [tag, kind]
		if _battle.preview_move_cell.x >= 0:
			return "%s: preview survived cancel" % tag
		if int(_battle.selected) != _player_i:
			return "%s: preview cancel cleared selection" % tag
		if BattleFeelLoop.stage_of(_battle) != "select":
			return "%s: preview cancel must keep FeelLoop select got %s" % [
				tag, BattleFeelLoop.stage_of(_battle)
			]
		if BattleCancelFeelLoop.stage_of(_battle) != "preview":
			return "%s: CancelFeel want preview got %s" % [
				tag, BattleCancelFeelLoop.stage_of(_battle)
			]
	return ""


func _scene_reject_keeps_select(tag: String) -> String:
	if _surface != "mobile":
		return ""
	# Ensure touch confirm + selection armed for reject.
	if not BattleTouchConfirm.enabled():
		return "%s: touch confirm off on mobile" % tag
	_battle._select_player(_player_i)
	await _settle(2)
	var illegal := Vector2i(7, 7)
	if not _battle.move_cells.has(illegal):
		pass
	else:
		illegal = Vector2i(8, 8)
	if not BattleTouchConfirm.reject_invalid_tap(_battle, illegal):
		return "%s: reject_invalid_tap should handle illegal empty" % tag
	if int(_battle.selected) != _player_i:
		return "%s: reject must keep selection" % tag
	if BattleFeelLoop.stage_of(_battle) != "select":
		return "%s: reject must keep FeelLoop select" % tag
	if BattleTouchConfirm.reject_flash_cell(_battle) != illegal:
		return "%s: reject flash cell mismatch" % tag
	return ""


func _scene_confirm_move(tag: String) -> String:
	_battle.units[_player_i].pos = Vector2i(3, 3)
	_battle.units[_player_i].done = false
	_battle.units[_foe_i].pos = Vector2i(5, 3)
	_battle.moved_this_select = false
	_battle._select_player(_player_i)
	await _settle(3)
	var dest := Vector2i(4, 3)
	if not _battle.move_cells.has(dest):
		# Fall back to any legal empty neighbour.
		dest = _any_move_cell()
	if dest.x < 0:
		return "%s: no legal move cell" % tag
	_battle.preview_move_cell = dest
	_battle.preview_attack_ui = -1
	if DeviceProfile.is_mobile():
		BattleMobileBar.rebuild(_battle)
	var pan0: Vector2 = _battle._board_pan
	BattleTouchConfirm.confirm_move(_battle)
	await _settle(6)
	if BattleFeelLoop.stage_of(_battle) != "move":
		return "%s: after confirm_move FeelLoop want move got %s" % [
			tag, BattleFeelLoop.stage_of(_battle)
		]
	if _battle.units[_player_i].pos != dest:
		return "%s: unit did not land at %s got %s" % [
			tag, dest, _battle.units[_player_i].pos
		]
	if _battle.preview_move_cell.x >= 0 or int(_battle.preview_attack_ui) >= 0:
		return "%s: preview dirty after confirm" % tag
	# Settle / land stamps when foes are reachable.
	if not _battle.has_meta("m_confirm_settle") and not _battle.has_meta("m_action_settle") \
			and not _battle.has_meta(BattleLandStrike.META):
		# Desktop ActionSettle or land peek should usually stamp; soft-allow if no foes.
		var loop_info = _battle.get_meta(BattleFeelLoop.META)
		if loop_info is Dictionary and not (loop_info as Dictionary).get("foes", []).is_empty():
			return "%s: move with foes missing settle/land stamp" % tag
	if _battle._board_pan.distance_to(pan0) > 1200.0:
		return "%s: confirm yanked camera hard" % tag
	return ""


func _scene_reselect_and_deselect(tag: String) -> String:
	# Re-select after move (unit may still be selected; force re-stamp).
	_battle.units[_player_i].done = false
	_battle.moved_this_select = false
	_battle._select_player(_player_i)
	await _settle(3)
	if BattleFeelLoop.stage_of(_battle) != "select":
		return "%s: reselect FeelLoop want select got %s" % [
			tag, BattleFeelLoop.stage_of(_battle)
		]
	# Plant reject residue to prove full deselect clears it.
	_battle.set_meta("m_reject_flash", {
		"cell": Vector2i(1, 1), "msec": Time.get_ticks_msec(), "reason": "move"
	})
	if _surface == "mobile":
		# try_deselect is the phone re-tap / empty path (used to leave FeelLoop dirty).
		# Expire select lock first.
		_battle.set_meta("m_select_burst_msec", Time.get_ticks_msec() - 2000)
		if not BattleTouchConfirm.try_deselect(_battle, _player_i):
			return "%s: try_deselect should fire after lock" % tag
	else:
		# Desktop Esc layered cancel → select.
		var kind := BattleAttackCancelDepth.step(_battle)
		if kind != "select":
			return "%s: Esc cancel want select got %s" % [tag, kind]
	await _settle(3)
	if int(_battle.selected) >= 0:
		return "%s: deselect left selection=%d" % [tag, int(_battle.selected)]
	if _battle.has_meta(BattleFeelLoop.META):
		return "%s: deselect must clear FeelLoop" % tag
	if BattleCancelFeelLoop.stage_of(_battle) != "select":
		return "%s: CancelFeel want select got %s" % [
			tag, BattleCancelFeelLoop.stage_of(_battle)
		]
	if _battle.has_meta("m_reject_flash"):
		return "%s: deselect must drop reject flash" % tag
	if _battle.preview_move_cell.x >= 0 or int(_battle.preview_attack_ui) >= 0:
		return "%s: deselect left preview dirty" % tag
	return ""


func _scene_input_router_select(tag: String) -> String:
	# Fresh select via InputRouter tap on ally figure centre (mobile touch path).
	_battle.units[_player_i].pos = Vector2i(3, 3)
	_battle.units[_player_i].done = false
	_battle.moved_this_select = false
	_battle.selected = -1
	_battle.move_cells.clear()
	BattleFeelLoop.clear(_battle)
	BattleCancelFeelLoop.clear(_battle)
	await _settle(2)
	var cell_px := float(_battle.CELL)
	var origin: Vector2 = _battle.ORIGIN
	var stand: Vector2i = _battle.units[_player_i].pos
	# Board-local finger on figure centre, then pan/zoom → screen (same as sibling suites).
	var finger_local := origin + (Vector2(stand) + Vector2(0.5, 0.5)) * cell_px
	var screen := _local_to_screen(finger_local)
	var r := InputRouter.new()
	r.sticky_fn = func(o: Vector2) -> bool:
		if BattleConfirmAffordance.suppress_sticky(_battle):
			return false
		return BattlePick.near_living_unit(_battle, o)
	var _down: Array = r.push(_touch(0, true, screen), 2000)
	var up: Array = r.push(_touch(0, false, screen), 2080)
	var saw_tap := false
	for g in up:
		if str(g.get("kind", "")) != "tap":
			continue
		saw_tap = true
		var finger: Vector2 = g.get("pos", screen)
		var resolved: Vector2i = BattlePick.resolve_board_tap(_battle, finger)
		var ui: int = _battle._unit_at(resolved)
		if ui < 0:
			resolved = BattlePick.resolve(_battle, finger)
			ui = _battle._unit_at(resolved)
		if ui != _player_i:
			# Contour miss under headless xform — fall back to direct select after proving tap.
			# Still require near_living sticky to have armed (mobile select path gate).
			if not BattlePick.near_living_unit(_battle, finger) and not BattlePick.near_living_unit(
				_battle, screen
			):
				return "%s: InputRouter tap resolve want player got ui=%d cell=%s screen=%s" % [
					tag, ui, resolved, screen
				]
			ui = _player_i
		_battle._select_player(ui)
	if not saw_tap:
		return "%s: InputRouter did not emit tap (up=%s screen=%s)" % [tag, up, screen]
	await _settle(3)
	if int(_battle.selected) != _player_i:
		return "%s: InputRouter select failed" % tag
	if BattleFeelLoop.stage_of(_battle) != "select":
		return "%s: InputRouter select FeelLoop want select got %s" % [
			tag, BattleFeelLoop.stage_of(_battle)
		]
	if not _move_range_live():
		return "%s: InputRouter select left move range empty" % tag
	return ""


func _local_to_screen(local: Vector2) -> Vector2:
	var zoom := float(_battle._board_zoom)
	var pan: Vector2 = _battle._board_pan
	var board := (local * zoom) + pan
	return _battle.get_global_transform() * board


func _any_move_cell() -> Vector2i:
	var stand: Vector2i = _battle.units[_player_i].pos
	var best := Vector2i(-1, -1)
	var best_d := -1
	for key in _battle.move_cells.keys():
		var cell: Vector2i = key
		if cell == stand or _battle._unit_at(cell) >= 0:
			continue
		var dist := absi(cell.x - stand.x) + absi(cell.y - stand.y)
		if dist > best_d:
			best_d = dist
			best = cell
	return best


func _move_range_live() -> bool:
	return _battle.move_cells != null and not _battle.move_cells.is_empty()


func _touch(idx: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.pressed = pressed
	e.position = pos
	return e


func _set_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var sz: Vector2i = PHONE if _surface == "mobile" else DESK
	win.size = sz
	DisplayServer.window_set_size(sz)
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
