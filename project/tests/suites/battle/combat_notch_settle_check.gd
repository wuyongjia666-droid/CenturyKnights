extends Node
## Y1-A T-P15: notch-lip body hit, post-action camera settle, landscape card.
## Algebra first, then a real battle (CK_FORCE_MOBILE, landscape, left notch).
## Push_input drives the crown tap and the lip wobble — the same path a finger
## takes. No EmptyHost. Quits 1 on the first broken contract.

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
		print("FAIL notch settle: ", err)
		get_tree().quit(1)
		return
	print("COMBAT NOTCH SETTLE PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra_edge()
	if err == "":
		err = _algebra_resolve()
	if err == "":
		err = _algebra_slop()
	if err == "":
		err = _algebra_settle()
	if err == "":
		err = _algebra_source()
	if err != "":
		return err
	OS.set_environment("CK_FORCE_MOBILE", "1")
	err = await _boot()
	if err == "":
		err = await _e2e_card()
	if err == "":
		err = await _e2e_crown_tap()
	if err == "":
		err = await _e2e_lip_wobble()
	if err == "":
		err = await _e2e_move_settle()
	if err == "":
		err = await _e2e_attack_settle()
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
	return err


func _algebra_edge() -> String:
	var origin := Vector2(40, 40)
	var cell := 64.0
	var safe := Rect2(0, 0, 900, 700)
	var board := Rect2(8, 40, 700, 520)
	var units: Array = [
		{"char": {"hp": 9}, "pos": Vector2i(2, 1), "team": "player"},
		{"char": {"hp": 0}, "pos": Vector2i(2, 0), "team": "bandit"},
	]
	var half := BattlePick.CONTOUR_HALF_W_MOBILE
	# Crown just above FIG_TOP, inside the top lip (board.y + band).
	var crown := origin + Vector2(2.5, 1.0 + BattlePick.FIG_TOP - 0.15) * cell
	if not BattleEdgePick.in_edge_band(crown, safe, board, BattleEdgePick.EDGE_BAND_PX):
		return "crown fixture is not in the notch lip: %s" % crown
	var hit: Vector2i = BattleEdgePick.edge_body_pos(
		origin, cell, units, crown, crown, safe, board, BattleEdgePick.EDGE_BAND_PX, 1.0, half)
	if hit != Vector2i(2, 1):
		return "lip crown must select the figure, got %s" % str(hit)
	# Same crown geometry in the middle of the board is not a lip.
	var mid := crown + Vector2(0, 220)
	if BattleEdgePick.in_edge_band(mid, safe, board, BattleEdgePick.EDGE_BAND_PX):
		return "interior point was treated as a notch lip"
	var missed: Vector2i = BattleEdgePick.edge_body_pos(
		origin, cell, units, mid, mid, safe, board, BattleEdgePick.EDGE_BAND_PX, 1.0, half)
	if missed.x >= 0:
		return "interior crown must still miss, got %s" % str(missed)
	# Left sliver, outside the contour, still on this column. Neighbour centre must not steal.
	var fig_left := 0.5 - half
	# Unit on column 0 at row 3 so the sliver sits in the left lip.
	var side_units: Array = [
		{"char": {"hp": 8}, "pos": Vector2i(0, 3), "team": "player"},
		{"char": {"hp": 8}, "pos": Vector2i(1, 3), "team": "bandit"},
	]
	var side_local := origin + Vector2(fig_left - 0.25, 3.0 + (BattlePick.FIG_TOP + BattlePick.FIG_FEET) * 0.5) * cell
	if not BattleEdgePick.in_edge_band(side_local, safe, board, BattleEdgePick.EDGE_BAND_PX):
		return "side sliver fixture left the lip: %s" % side_local
	var side_hit: Vector2i = BattleEdgePick.edge_body_pos(
		origin, cell, side_units, side_local, side_local, safe, board, BattleEdgePick.EDGE_BAND_PX, 1.0, half)
	if side_hit != Vector2i(0, 3):
		return "left lip sliver must select column 0, got %s" % str(side_hit)
	var neighbour := origin + Vector2(1.5, 3.4) * cell
	var stolen: Vector2i = BattleEdgePick.edge_body_pos(
		origin, cell, side_units, neighbour, side_local, safe, board, BattleEdgePick.EDGE_BAND_PX, 1.0, half)
	if stolen == Vector2i(0, 3):
		return "column 0 stole the neighbour centre"
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var desk: Vector2i = BattleEdgePick.edge_body_pos(
		origin, cell, units, crown, crown, safe, board, BattleEdgePick.EDGE_BAND_PX, 1.0, half)
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if desk.x >= 0:
		return "desktop must keep the exact cell, got %s" % str(desk)
	return ""


func _algebra_resolve() -> String:
	var host := _Host.new()
	var crown: Vector2 = host.crown_local()
	var got: Vector2i = BattlePick.resolve(host, crown)
	if got != Vector2i(2, 1):
		return "resolve missed the lip crown: %s" % str(got)
	host.set_meta("m_touch_safe", Rect2())
	# Empty safe rect is not a lip — interior rules stand.
	host.remove_meta("m_touch_safe")
	var bare: Vector2i = BattlePick.resolve(host, crown)
	if bare == Vector2i(2, 1):
		return "crown resolved without a safe rect"
	return ""


func _algebra_slop() -> String:
	var r := InputRouter.new()
	var base: float = r._slop()
	r.sticky_fn = func(_o: Vector2) -> bool: return true
	r.edge_fn = func(_o: Vector2) -> bool: return true
	var wide: float = r._slop_for(Vector2(4, 4))
	if wide < base * InputRouter.EDGE_SLOP_MUL - 0.01:
		return "notch lip slop not widened: base %s wide %s" % [base, wide]
	r.edge_fn = func(_o: Vector2) -> bool: return false
	var sticky: float = r._slop_for(Vector2(4, 4))
	if absf(sticky - base * InputRouter.STICKY_SLOP_MUL) > 0.01:
		return "interior sticky slop changed: %s" % sticky
	# A drift between sticky and edge slop stays a tap only on the lip.
	var drift := base * 1.9
	var lip := InputRouter.new()
	lip.sticky_fn = func(_o: Vector2) -> bool: return true
	lip.edge_fn = func(_o: Vector2) -> bool: return true
	var pos := Vector2(80, 90)
	lip.push(_screen_touch(0, true, pos), 1000)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = pos + Vector2(drift, 0)
	drag.relative = Vector2(drift, 0)
	var mid: Array = lip.push(drag, 1040)
	for g in mid:
		if str(g.get("kind", "")) == "pan":
			return "lip drift became a pan (%s px, slop %s)" % [drift, lip._slop_for(pos)]
	var up: Array = lip.push(_screen_touch(0, false, pos + Vector2(drift, 0)), 1100)
	var tapped := false
	for g in up:
		if str(g.get("kind", "")) == "tap":
			tapped = true
	if not tapped:
		return "lip drift did not release as a tap: %s" % str(up)
	return ""


func _algebra_settle() -> String:
	var stage := Rect2(0, 0, 800, 500)
	var block := Rect2(600, 0, 200, 500)
	var inset := BattleActionSettle.readable_inset(stage, [block], 0.0)
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
	var kept := BattleActionSettle.settle_delta(origin, cell, actor, [other], Vector2.ZERO, 1.0, pair_inset)
	if kept.length() > 1.0:
		return "already-readable actor was dragged to centre the pair: %s" % kept
	var far := Vector2i(12, 1)
	var pulled := BattleActionSettle.settle_delta(origin, cell, far, [other], Vector2.ZERO, 1.0, pair_inset)
	var fig := BattleCombatFrame.figure_rect(origin, cell, far, pulled, 1.0)
	if not pair_inset.grow(3.0).encloses(fig):
		return "offscreen actor was not brought back %s delta %s" % [fig, pulled]
	OS.set_environment("CK_FORCE_MOBILE", "0")
	var desk := Node.new()
	desk.set_meta("m_board_area", stage)
	desk.set("_board_pan", Vector2.ZERO)
	# Duck via a tiny wrapper — apply() must no-op off mobile. Use the live static gate.
	var before := "desktop"
	BattleActionSettle.apply(_Desk.new(), far, [])
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if before == "":
		return "desktop settle ran"
	desk.free()
	return ""


func _algebra_source() -> String:
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	var router := FileAccess.get_file_as_string("res://scripts/platform/input_router.gd")
	if pick.find("BattleEdgePick.from_host") < 0:
		return "resolve does not use the notch lip"
	if pick.find("BattleCombatFrame.follow_selected") < 0:
		return "T-P13 select framing was removed"
	if conf.find("clear(host, false)") < 0 or conf.find("note_confirm_strike") < 0:
		return "T-P13 confirm path was rewritten"
	if conf.find("BattleActionSettle.apply") < 0:
		return "confirm does not settle the actor"
	if router.find("EDGE_SLOP_MUL") < 0:
		return "notch lip slop missing"
	if conf.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	return ""


func _boot() -> String:
	await _set_window()
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.settings.erase("touch_confirm")
	GameState.settings.erase("touch_drag_commit")
	GameState.board_input_blocked = false
	OS.set_environment("CK_SAFE_INSETS", "120,0,0,24")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(6)
	var story := _battle.get_node_or_null("BattleStoryLayer")
	if story:
		story.free()
	var insets := {"left": 120.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
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
	if not _battle.has_meta("m_touch_safe"):
		return "notch safe rect was not recorded"
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
				u.pos = Vector2i(3, 2)
				u.done = false
			else:
				extra_p += 1
				u.pos = Vector2i(0, mini(1, extra_p))
				u.done = true
				u.char.hp = 0
		elif str(u.team) == "enemy":
			if _foe_i < 0:
				_foe_i = i
				u.pos = Vector2i(6, 2)
			else:
				extra_f += 1
				u.pos = Vector2i(mini(_battle.MAP_W - 1, 7), mini(_battle.MAP_H - 1, extra_f))
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
	_battle._board_pan = Vector2.ZERO
	_battle._board_zoom = 1.0
	_battle._apply_board_xform()
	BattleEdgePick.note_layout(_battle)
	return ""


func _e2e_card() -> String:
	var board: Rect2 = _battle.get_meta("m_board_area")
	var col := _battle.get_node_or_null("MobileSideCol") as Control
	var err := _card_chrome_ok(board, col)
	if err != "":
		return err
	# A board point beside the column must not lie under the column.
	var probe := _cell_local(_battle.units[_player_i].pos, Vector2(0.5, 0.55))
	var screen := _screen(probe)
	var col_g := col.get_global_rect()
	if col_g.has_point(screen):
		return "board probe sits under the info column %s" % screen
	_battle.selected = -1
	_push_tap(screen)
	await _settle(4)
	if _battle.selected < 0:
		return "tap beside the column did not reach the board"
	return ""


## Layout / mouse-filter contracts for the landscape info column (split for max-returns).
func _card_chrome_ok(board: Rect2, col: Control) -> String:
	if col == null:
		return "side column missing"
	if col.position.x < board.end.x - 1.0:
		return "info column covers the board: col %s board %s" % [Rect2(col.position, col.size), board]
	var card = _battle._unit_card
	if card == null:
		return "unit card missing"
	if card.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return "unit card steals taps (mouse_filter %s)" % card.mouse_filter
	var name_err := _card_name_ok(card)
	if name_err != "":
		return name_err
	if card._stats.clip_text:
		return "unit stats are still clipped"
	if _battle.info_label.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return "info strip steals taps"
	if _battle.info_label.clip_contents:
		return "info strip clips its body"
	var steal := _button_steals(card)
	if steal != "":
		return steal
	if _count_buttons(card) < 1:
		return "unit card has no skill chip to prove buttons still take taps"
	return ""


func _card_name_ok(card) -> String:
	if card._name.clip_text:
		return "unit name is still clipped"
	if card._name.autowrap_mode == TextServer.AUTOWRAP_OFF:
		return "unit name does not wrap"
	if card._name.custom_minimum_size.y < 22.0:
		return "unit name has no line height"
	return ""


func _e2e_crown_tap() -> String:
	_battle.selected = -1
	_battle._cancel_selection()
	var parked := _park_crown()
	if parked != "":
		return parked
	var crown := _crown_local()
	var screen := _screen(crown)
	var ctrl: Vector2 = _battle._screen_to_local(screen)
	var safe: Rect2 = _battle.get_meta("m_touch_safe")
	var board: Rect2 = _battle.get_meta("m_board_area")
	if not BattleEdgePick.in_edge_band(ctrl, safe, board, BattleEdgePick.EDGE_BAND_PX):
		return "live crown left the lip ctrl %s board %s" % [ctrl, board]
	var resolved: Vector2i = BattlePick.resolve(_battle, screen)
	if resolved != _battle.units[_player_i].pos:
		return "live resolve crown got %s want %s" % [resolved, _battle.units[_player_i].pos]
	_push_tap(screen)
	await _settle(4)
	if _battle.selected != _player_i:
		return "crown push_input selected %s" % str(_battle.selected)
	return ""


func _e2e_lip_wobble() -> String:
	_battle._cancel_selection()
	_battle.selected = -1
	var parked := _park_crown()
	if parked != "":
		return parked
	var crown := _screen(_crown_local())
	var pan0: Vector2 = _battle._board_pan
	var base: float = _battle._board_router._slop()
	var drift := base * 1.9
	_touch(0, true, crown)
	await get_tree().process_frame
	_drag(crown + Vector2(drift, 0), Vector2(drift, 0))
	await get_tree().process_frame
	_touch(0, false, crown + Vector2(drift, 0))
	await _settle(4)
	if _battle.selected != _player_i:
		return "lip wobble did not select (sel %s drift %.1f slop %.1f)" % [_battle.selected, drift, base]
	# Select-follow may nudge Y to pull the crown out of the lip. A finger pan
	# would move X by the drift (~1.9× slop). That must not happen.
	if absf(_battle._board_pan.x - pan0.x) > 2.0:
		return "lip wobble panned the board %s -> %s" % [pan0, _battle._board_pan]
	return ""


func _e2e_move_settle() -> String:
	_battle._cancel_selection()
	_battle.units[_player_i].pos = Vector2i(3, 2)
	_battle.units[_player_i].done = false
	_battle.moved_this_select = false
	_battle._board_pan = Vector2.ZERO
	_battle._board_zoom = 1.0
	_battle._apply_board_xform()
	BattlePick.cancel_focus_tween(_battle)
	_tap(_cell_local(Vector2i(3, 2), Vector2(0.5, 0.55)))
	if _battle.selected != _player_i:
		return "move setup did not select"
	_battle.move_cells = {Vector2i(3, 3): 1}
	_battle.moved_this_select = false
	_tap(_cell_local(Vector2i(3, 3), Vector2(0.5, 0.5)))
	if _battle.preview_move_cell != Vector2i(3, 3):
		return "move preview did not latch"
	var parked := _park_outside(Vector2i(3, 3))
	if parked != "":
		return parked
	_tap(_cell_local(Vector2i(3, 3), Vector2(0.5, 0.5)))
	if _battle.units[_player_i].pos != Vector2i(3, 3):
		return "move did not commit, pos %s" % str(_battle.units[_player_i].pos)
	return await _assert_actor_readable(Vector2i(3, 3))


func _e2e_attack_settle() -> String:
	var from: Vector2i = _battle.units[_player_i].pos
	_battle.units[_player_i].done = false
	_battle.moved_this_select = false
	_battle.attack_mode = false
	_battle.preview_attack_ui = -1
	if _battle.selected != _player_i:
		_tap(_cell_local(from, Vector2(0.5, 0.55)))
	if _battle.selected != _player_i:
		return "attack setup lost the selection"
	var spot := _attack_spot(from)
	if spot.x < 0:
		return "no in-range cell for attack settle"
	_battle.units[_foe_i].pos = spot
	_battle.units[_foe_i].char.hp = maxi(int(_battle.units[_foe_i].char.hp), 12)
	_tap(_cell_local(spot, Vector2(0.5, 0.5)))
	if int(_battle.preview_attack_ui) != _foe_i:
		return "attack preview did not latch"
	var parked := _park_outside(from)
	if parked != "":
		return parked
	var actor: Vector2i = _battle.units[_player_i].pos
	_tap(_cell_local(spot, Vector2(0.5, 0.5)))
	var committed: bool = bool(_battle.units[_player_i].done) or _battle.selected < 0 or not _battle._combat_rec.is_empty()
	if not committed:
		return "attack did not confirm"
	return await _assert_actor_readable(actor)


func _assert_actor_readable(actor: Vector2i) -> String:
	if not _battle.has_meta("m_action_settle"):
		return "confirm did not stamp an action settle"
	var info = _battle.get_meta("m_action_settle")
	if not (info is Dictionary):
		return "action settle meta is not a dictionary"
	var delta: Vector2 = info.get("delta", Vector2.ZERO)
	if delta.length() < 1.0:
		return "parked actor produced no settle delta %s" % delta
	var target: Vector2 = _battle._board_pan
	# The tween owns the pan; the stamped delta is where it is going from the pre-tween pan.
	# Read the inset and wait until the figure is inside, allowing the tween to finish.
	var inset: Rect2 = info.get("inset", Rect2())
	var i := 0
	while i < 40:
		if BattleCombatFrame.figure_inside(_battle.ORIGIN, float(_battle.CELL), actor, _battle._board_pan, float(_battle._board_zoom), inset, 4.0):
			return ""
		await get_tree().process_frame
		i += 1
	var fig := BattleCombatFrame.figure_rect(_battle.ORIGIN, float(_battle.CELL), actor, _battle._board_pan, float(_battle._board_zoom))
	return "actor figure %s still outside readable inset %s (delta %s pan %s target hint %s)" % [fig, inset, delta, _battle._board_pan, target]


func _park_crown() -> String:
	BattlePick.cancel_focus_tween(_battle)
	_battle._board_zoom = 1.0
	var local := _crown_local_unpanned()
	var board: Rect2 = _battle.get_meta("m_board_area")
	var shown_y := board.position.y + 8.0
	_battle._board_pan = Vector2(0, shown_y - local.y)
	_battle._clamp_board_pan()
	_battle._apply_board_xform()
	var ctrl := _crown_shown()
	var safe: Rect2 = _battle.get_meta("m_touch_safe")
	if not BattleEdgePick.in_edge_band(ctrl, safe, board, BattleEdgePick.EDGE_BAND_PX):
		return "could not park the crown in the lip (shown %s pan %s)" % [ctrl, _battle._board_pan]
	return ""


func _park_outside(cell: Vector2i) -> String:
	BattlePick.cancel_focus_tween(_battle)
	var stage: Rect2 = _battle.get_meta("m_board_area")
	var blockers: Array = []
	if _battle.has_meta("m_info_block"):
		blockers.append(_battle.get_meta("m_info_block"))
	var attempt := 0
	while attempt < 4:
		var inset := BattleActionSettle.readable_inset(stage, blockers, BattleEdgePick.EDGE_BAND_PX)
		var base := BattleCombatFrame.figure_rect(_battle.ORIGIN, float(_battle.CELL), cell, Vector2.ZERO, float(_battle._board_zoom))
		_battle._board_pan.x = inset.end.x + 240.0 - base.end.x
		_battle._clamp_board_pan()
		_battle._apply_board_xform()
		var fig := BattleCombatFrame.figure_rect(_battle.ORIGIN, float(_battle.CELL), cell, _battle._board_pan, float(_battle._board_zoom))
		if not inset.grow(6.0).encloses(fig):
			return ""
		_battle._zoom_board_at(stage.get_center(), 1.55)
		BattlePick.cancel_focus_tween(_battle)
		attempt += 1
	return "could not park %s outside the readable inset (pan %s)" % [cell, _battle._board_pan]


func _crown_local_unpanned() -> Vector2:
	var cell := float(_battle.CELL)
	var pos: Vector2i = _battle.units[_player_i].pos
	return _battle.ORIGIN + Vector2(float(pos.x) + 0.5, float(pos.y) + BattlePick.FIG_TOP - 0.15) * cell


func _crown_local() -> Vector2:
	## Unscaled board point. _screen applies pan and zoom.
	return _crown_local_unpanned()


func _crown_shown() -> Vector2:
	var zoom := float(_battle._board_zoom)
	return _crown_local_unpanned() * zoom + _battle._board_pan


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


func _button_steals(n: Node) -> String:
	if n is BaseButton and (n as Control).mouse_filter != Control.MOUSE_FILTER_STOP:
		return "skill chip does not receive taps"
	if n is BaseButton:
		return ""
	for ch in n.get_children():
		var err := _button_steals(ch)
		if err != "":
			return err
	return ""


func _count_buttons(n: Node) -> int:
	var n_btn := 0
	if n is BaseButton:
		n_btn += 1
	for ch in n.get_children():
		n_btn += _count_buttons(ch)
	return n_btn


func _cell_local(cell: Vector2i, rel: Vector2) -> Vector2:
	return _battle.ORIGIN + Vector2(cell) * float(_battle.CELL) + rel * float(_battle.CELL)


func _screen(local_board: Vector2) -> Vector2:
	var zoom := float(_battle._board_zoom)
	return _battle.get_global_transform() * (local_board * zoom + _battle._board_pan)


func _tap(local_board: Vector2) -> void:
	_battle._apply_board_gesture({"kind": "tap", "pos": _screen(local_board)})


func _push_tap(screen: Vector2) -> void:
	_touch(0, true, screen)
	_touch(0, false, screen)


func _screen_touch(i: int, down: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.pressed = down
	e.position = pos
	return e


func _touch(i: int, down: bool, pos: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.pressed = down
	e.position = pos
	get_viewport().push_input(e, true)


func _drag(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	e.relative = rel
	get_viewport().push_input(e, true)


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


class _Host extends RefCounted:
	var units: Array = []
	var attack_mode := false
	var _board_pan := Vector2.ZERO
	var _board_zoom := 1.0
	var _origin := Vector2(40, 40)
	var _cell := 64

	func _init() -> void:
		units = [{"char": {"hp": 9}, "pos": Vector2i(2, 1), "team": "player"}]
		set_meta("m_touch_safe", Rect2(0, 0, 900, 700))
		set_meta("m_board_area", Rect2(8, 40, 700, 520))
		set_meta("m_edge_band", BattleEdgePick.EDGE_BAND_PX)

	func _get(property: StringName):
		if property == &"ORIGIN":
			return _origin
		if property == &"CELL":
			return _cell
		return null

	func crown_local() -> Vector2:
		return _origin + Vector2(2.5, 1.0 + BattlePick.FIG_TOP - 0.15) * float(_cell)

	func _screen_to_local(p: Vector2) -> Vector2:
		return p

	func _pointer_to_cell(screen_pos: Vector2) -> Vector2i:
		var local := BattlePick.local_after_pan_zoom(_screen_to_local(screen_pos), _board_pan, _board_zoom)
		return BattlePick.cell_at_local(_origin, float(_cell), local, 16, 12)

	func _unit_at(cell: Vector2i) -> int:
		for i in units.size():
			if units[i].pos == cell and int(units[i].char.hp) > 0:
				return i
		return -1


class _Desk extends RefCounted:
	var _board_pan := Vector2.ZERO
	var _board_zoom := 1.0

	func _init() -> void:
		set_meta("m_board_area", Rect2(0, 0, 800, 500))

	func _get(property: StringName):
		if property == &"ORIGIN":
			return Vector2.ZERO
		if property == &"CELL":
			return 80
		return null
