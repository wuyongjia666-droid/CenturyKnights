extends Node
## Y1-A T-P16: confirm/cancel chips, preview back-out, post-confirm settle.
## Algebra first, then a real battle with CK_FORCE_MOBILE. Quits 1 on the first miss.
## No EmptyHost. Does not raise screenshot baselines.

const PHONE := Vector2i(2400, 1080)

var _battle: Control
var _player_i := -1
var _foe_i := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL confirm affordance: ", err)
		get_tree().quit(1)
		return
	print("COMBAT CONFIRM AFFORDANCE PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _algebra_chips()
	if err == "":
		err = _algebra_settle()
	if err == "":
		err = _algebra_sticky()
	if err == "":
		err = _algebra_source()
	if err != "":
		return err
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	err = await _boot()
	if err == "":
		err = await _e2e_cancel_chip()
	if err == "":
		err = await _e2e_back_key()
	if err == "":
		err = await _e2e_pan_not_commit()
	if err == "":
		err = await _e2e_confirm_chip_move()
	if err == "":
		err = await _e2e_confirm_attack_settle()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err


func _algebra_chips() -> String:
	var shown := BattleConfirmAffordance.board_span(1.0, 0.5, 108.0) * 1.0 * 0.5
	if absf(shown - 108.0) > 0.2:
		return "landscape chip collapsed on screen: %.2f" % shown
	if BattleConfirmAffordance.screen_hit(true) + 0.01 < BattleConfirmAffordance.LANDSCAPE_HIT:
		return "landscape hit floor under 108"
	var pair := BattleConfirmAffordance.chip_pair(Vector2(400, 300), 108.0)
	var confirm: Rect2 = pair.get("confirm", Rect2())
	var cancel: Rect2 = pair.get("cancel", Rect2())
	if confirm.size.x < 108.0 - 0.1 or confirm.size.y < 108.0 - 0.1:
		return "confirm chip under the landscape hit %s" % confirm
	if not confirm.has_point(Vector2(400, 300)):
		return "confirm chip missed its centre"
	if cancel.intersects(confirm):
		return "cancel chip overlaps confirm"
	if not cancel.has_point(cancel.get_center()):
		return "cancel chip has no interior"
	var tight := BattleConfirmAffordance.chip_pair(Vector2(20, 200), 80.0, Rect2(0, 0, 400, 400))
	var moved: Rect2 = tight.get("cancel", Rect2())
	var kept: Rect2 = tight.get("confirm", Rect2())
	if moved.intersects(kept):
		return "left-edge cancel still overlaps confirm"
	if moved.position.x < 0.0:
		return "left-edge cancel stayed off the board %s" % moved
	var owned := Node.new()
	owned.set_meta("m_action_settle", {"actor": Vector2i(1, 0), "delta": Vector2(8, 0), "inset": Rect2()})
	BattleConfirmAffordance.settle_camera(owned, Vector2i(1, 0), [Vector2i(9, 0)])
	if owned.has_meta("m_confirm_settle"):
		owned.free()
		return "post-confirm camera fought an existing T-P15 settle"
	owned.free()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var desk := Node.new()
	if BattleConfirmAffordance.yields_post_camera(desk):
		desk.free()
		return "desktop confirm must keep the T-P13 camera path"
	desk.free()
	return ""


func _algebra_settle() -> String:
	var stage := Rect2(0, 0, 800, 500)
	var block := Rect2(600, 0, 200, 500)
	var inset := BattleConfirmAffordance.readable_inset(stage, [block], 0.0)
	if inset.end.x > 600.5:
		return "info strip still covers the readable inset %s" % inset
	var origin := Vector2.ZERO
	var cell := 80.0
	var pair_inset := Rect2(0, 0, 200, 400)
	var actor := Vector2i(0, 1)
	var other := Vector2i(10, 1)
	var merged := BattleCombatFrame.frame_delta(origin, cell, [actor, other], Vector2.ZERO, 1.0, pair_inset)
	if merged.length() < 1.0:
		return "fixture pair already fit the inset"
	var kept := BattleConfirmAffordance.settle_delta(origin, cell, actor, [other], Vector2.ZERO, 1.0, pair_inset)
	if kept.length() > 1.0:
		return "already-readable actor was dragged to centre the pair: %s" % kept
	var far := Vector2i(12, 1)
	var pulled := BattleConfirmAffordance.settle_delta(origin, cell, far, [other], Vector2.ZERO, 1.0, pair_inset)
	var fig := BattleCombatFrame.figure_rect(origin, cell, far, pulled, 1.0)
	if not pair_inset.grow(3.0).encloses(fig):
		return "offscreen actor was not brought back %s delta %s" % [fig, pulled]
	var actor_only := BattleCombatFrame.figure_rect(origin, cell, actor, kept, 1.0)
	if not pair_inset.grow(3.0).encloses(actor_only):
		return "readable actor left the settle region"
	return ""


func _algebra_sticky() -> String:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var r := InputRouter.new()
	r.sticky_fn = func(_o: Vector2) -> bool: return true
	var base: float = r._slop()
	var between := base * 1.25
	if between <= base or between >= base * InputRouter.STICKY_SLOP_MUL:
		return "probe distance is not between base and sticky slop"
	r.push(_touch(0, true, Vector2(80, 80)), 1000)
	var sticky_drag := _drag(Vector2(80, 80), Vector2(between, 0))
	var sticky_g: Array = r.push(sticky_drag, 1100)
	var sticky_pan := false
	for g in sticky_g:
		if str(g.get("kind", "")) == "pan":
			sticky_pan = true
	if sticky_pan:
		return "sticky slop let a 1.25× drag become a pan"
	var open := InputRouter.new()
	open.sticky_fn = func(_o: Vector2) -> bool: return false
	open.push(_touch(0, true, Vector2(80, 80)), 2000)
	var free_g: Array = open.push(_drag(Vector2(80, 80), Vector2(between, 0)), 2100)
	var freed := false
	for g2 in free_g:
		if str(g2.get("kind", "")) == "pan":
			freed = true
	if not freed:
		return "suppressed sticky still swallowed the back-out drag"
	var duck := _Duck.new()
	if BattleConfirmAffordance.suppress_sticky(duck):
		return "empty preview suppressed sticky"
	duck.preview_move_cell = Vector2i(3, 4)
	if not BattleConfirmAffordance.suppress_sticky(duck):
		return "move preview did not suppress sticky"
	if BattleTouchConfirm.is_unit_drag(duck, {"origin": Vector2(10, 10), "kind": "pan"}):
		return "latched preview armed a unit drag"
	duck.preview_move_cell = Vector2i(-1, -1)
	duck.preview_attack_ui = 1
	if not BattleConfirmAffordance.preview_latched(duck):
		return "attack preview was not latched"
	return ""


func _algebra_source() -> String:
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var afford := FileAccess.get_file_as_string("res://scripts/battle/battle_confirm_affordance.gd")
	if conf.find("clear(host, false)") < 0 or conf.find("note_confirm_strike") < 0:
		return "T-P13 confirm path was rewritten"
	if conf.find("BattlePick.focus_follow_preview(host)") < 0:
		return "confirm missing focus_follow_preview"
	if conf.find("BattlePick.focus_cell") < 0:
		return "desktop confirm lost focus_cell"
	if conf.find("BattleConfirmAffordance.settle_camera") < 0:
		return "confirm does not settle into the readable region"
	if conf.find("preview_latched") < 0:
		return "unit drag still commits over a latched preview"
	if ctrl.find("suppress_sticky") < 0 or ctrl.find("near_selected_unit") < 0:
		return "sticky gate missing"
	if ctrl.find("consume_tap") < 0 or ctrl.find("is_cancel_key") < 0:
		return "chip tap or cancel key not wired"
	if afford.find("m_action_settle") < 0 or afford.find("readable_inset") < 0:
		return "post-confirm camera ignores the T-P15 settle region"
	if conf.find("EmptyHost") >= 0 or afford.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	if afford.find("BattleEdgePick") >= 0 or afford.find("BattleFormationCycle") >= 0:
		return "T-P16 stepped into notch or formation scope"
	return ""


func _boot() -> String:
	await _set_window()
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
	GameState.board_input_blocked = false
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(6)
	var story := _battle.get_node_or_null("BattleStoryLayer")
	if story:
		story.free()
	var insets := {"left": 48.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
	var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
	MobileLayout.apply_root(_battle, fitted)
	_battle.set_meta("mobile_insets", insets)
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(8)
	if not _battle._mobile_landscape():
		return "battle did not enter landscape"
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
				u.char.hp = maxi(int(u.char.hp), 12)
			else:
				extra_f += 1
				u.pos = Vector2i(mini(_battle.MAP_W - 1, 10), mini(_battle.MAP_H - 1, extra_f))
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


func _e2e_cancel_chip() -> String:
	var dest := await _latch_move()
	if dest.x < 0:
		return "no legal move cell for cancel"
	var pair := BattleConfirmAffordance.chips(_battle)
	var confirm: Rect2 = pair.get("confirm", Rect2())
	if confirm.size.x < 1.0:
		return "move preview did not publish a confirm chip"
	var on_screen := confirm.size.x * float(_battle._board_zoom) * _battle.get_global_transform().get_scale().x
	if on_screen + 0.5 < BattleConfirmAffordance.LANDSCAPE_HIT:
		return "confirm chip on-screen size %.1f under 108" % on_screen
	var primary := _battle._mobile_bar.find_child("ConfirmPrimary", true, false) as Control
	if primary == null or primary.custom_minimum_size.y + 0.5 < BattleConfirmAffordance.LANDSCAPE_HIT:
		return "landscape confirm button under 108"
	BattlePick.cancel_focus_tween(_battle)
	var pan: Vector2 = _battle._board_pan
	var pos_before: Vector2i = _battle.units[_player_i].pos
	var cancel: Rect2 = pair.get("cancel", Rect2())
	_tap(cancel.get_center())
	await _settle(6)
	if _battle.preview_move_cell.x >= 0:
		return "cancel chip left the move preview"
	if _battle.selected != _player_i:
		return "cancel chip cleared the selection"
	if _battle.units[_player_i].pos != pos_before:
		return "cancel chip committed the move"
	if _battle._board_pan.distance_to(pan) > 1.5:
		return "cancel chip yanked the camera %s -> %s" % [pan, _battle._board_pan]
	return ""


func _e2e_back_key() -> String:
	var dest := await _latch_move()
	if dest.x < 0:
		return "no legal move cell for back key"
	BattlePick.cancel_focus_tween(_battle)
	var pan: Vector2 = _battle._board_pan
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	_battle._unhandled_key_input(ev)
	await _settle(4)
	if _battle.preview_move_cell.x >= 0:
		return "escape left the move preview"
	if _battle.selected != _player_i:
		return "escape cleared the selection"
	if _battle._board_pan.distance_to(pan) > 1.5:
		return "escape yanked the camera"
	return ""


func _e2e_pan_not_commit() -> String:
	var dest := await _latch_move()
	if dest.x < 0:
		return "no legal move cell for pan"
	var origin := _screen(_cell_local(_battle.units[_player_i].pos, Vector2(0.5, 0.55)))
	if BattleTouchConfirm.is_unit_drag(_battle, {"origin": origin, "kind": "pan"}):
		return "preview press armed a unit drag"
	BattlePick.cancel_focus_tween(_battle)
	var pan: Vector2 = _battle._board_pan
	var pos_before: Vector2i = _battle.units[_player_i].pos
	_battle._apply_board_gesture({
		"kind": "pan",
		"pos": origin + Vector2(48, 0),
		"origin": origin,
		"delta": Vector2(48, 0),
	})
	if _battle._board_pan.distance_to(pan) < 1.0:
		return "preview pan was swallowed (sticky fight)"
	if _battle.units[_player_i].pos != pos_before:
		return "preview pan committed the move"
	if _battle.preview_move_cell != dest:
		return "preview pan dropped the ghost"
	BattleTouchConfirm.end_gesture(_battle)
	BattleConfirmAffordance.back_out(_battle)
	return ""


func _e2e_confirm_chip_move() -> String:
	var dest := await _latch_move()
	if dest.x < 0:
		return "no legal move cell for confirm chip"
	var pair := BattleConfirmAffordance.chips(_battle)
	var confirm: Rect2 = pair.get("confirm", Rect2())
	if not confirm.has_point(confirm.get_center()):
		return "confirm chip centre is not a hit"
	var screen_hit := BattleConfirmAffordance.hit(_battle, _screen(confirm.get_center()))
	if screen_hit != "confirm":
		return "confirm chip hit resolved as %s" % screen_hit
	_tap(confirm.get_center())
	await _settle(20)
	if _battle.units[_player_i].pos != dest:
		return "confirm chip did not move the unit to %s (at %s)" % [dest, _battle.units[_player_i].pos]
	return _actor_inside(dest)


func _e2e_confirm_attack_settle() -> String:
	_battle._select_player(_player_i)
	await _settle(3)
	var spot := _attack_spot(_battle.units[_player_i].pos)
	if spot.x < 0:
		return "no in-range cell for attack confirm"
	_battle.units[_foe_i].pos = spot
	_battle.units[_foe_i].char.hp = maxi(int(_battle.units[_foe_i].char.hp), 20)
	_battle.attack_mode = false
	_battle.preview_attack_ui = -1
	_battle.preview_move_cell = Vector2i(-1, -1)
	var stage: Rect2 = _battle.get_meta("m_board_area")
	_battle.set_meta("m_info_block", Rect2(stage.end.x - 80.0, stage.position.y, 80.0, stage.size.y))
	_tap(_cell_local(spot, Vector2(0.5, 0.5)))
	if int(_battle.preview_attack_ui) != _foe_i:
		return "foe tap did not latch attack preview"
	var pair := BattleConfirmAffordance.chips(_battle)
	var confirm: Rect2 = pair.get("confirm", Rect2())
	var on_screen := confirm.size.x * float(_battle._board_zoom) * _battle.get_global_transform().get_scale().x
	if on_screen + 0.5 < BattleConfirmAffordance.LANDSCAPE_HIT:
		return "attack confirm chip on-screen %.1f under 108" % on_screen
	var actor_before: Vector2i = _battle.units[_player_i].pos
	var hp0 := int(_battle.units[_foe_i].char.hp)
	_tap(confirm.get_center())
	await _settle(30)
	var foe_hp := int(_battle.units[_foe_i].char.hp)
	var committed: bool = bool(_battle.units[_player_i].done) or foe_hp < hp0 or not _battle._combat_rec.is_empty()
	if not committed:
		return "attack confirm chip did not commit"
	if not _battle.has_meta("m_confirm_settle"):
		return "attack confirm did not stamp a settle"
	if _battle.units[_player_i].pos != actor_before:
		return "attack moved the actor off %s" % str(actor_before)
	return _actor_inside(_battle.units[_player_i].pos)


func _actor_inside(cell: Vector2i) -> String:
	if not _battle.has_meta("m_confirm_settle"):
		return "confirm did not stamp a settle"
	var info = _battle.get_meta("m_confirm_settle")
	if not (info is Dictionary):
		return "settle meta is not a dictionary"
	var inset: Rect2 = info.get("inset", Rect2())
	var fig := BattleCombatFrame.figure_rect(
		_battle.ORIGIN, float(_battle.CELL), cell, _battle._board_pan, float(_battle._board_zoom))
	if inset.size.x > 8.0 and not inset.grow(12.0).encloses(fig):
		return "actor left the readable inset %s fig %s" % [inset, fig]
	return ""


func _latch_move() -> Vector2i:
	_battle.units[_player_i].pos = Vector2i(4, 3)
	_battle.units[_player_i].done = false
	if _battle.selected != _player_i:
		_battle._select_player(_player_i)
		await _settle(3)
	var dest := Vector2i(5, 3)
	_battle.moved_this_select = false
	_battle.attack_mode = false
	_battle.preview_attack_ui = -1
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.move_cells = {dest: 1}
	_tap(_cell_local(dest, Vector2(0.5, 0.5)))
	await _settle(2)
	if _battle.preview_move_cell != dest:
		return Vector2i(-1, -1)
	return dest


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


func _touch(index: int, pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	return e


func _drag(origin: Vector2, delta: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = origin + delta
	e.relative = delta
	return e


func _set_window() -> void:
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


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
		await _settle(2)


class _Duck extends RefCounted:
	var preview_move_cell := Vector2i(-1, -1)
	var preview_attack_ui := -1
	var selected := 0
	var units: Array = [{"team": "player", "done": false, "pos": Vector2i(2, 2), "char": {"hp": 10}}]
	var _board_pan := Vector2.ZERO
	var _board_zoom := 1.0
	var attack_mode := false
	var turn_team := "player"
	var battle_over := false
	var _cut_playing := false
	var moved_this_select := false
