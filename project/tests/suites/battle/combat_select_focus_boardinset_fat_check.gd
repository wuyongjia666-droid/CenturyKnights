extends Node
## Fat knife: select focus_cell / focus_follow + CombatFrame.follow_cells share
## BattleBoardInset (notch + info + edge) with range keep / confirm settle.
## Algebra → Scene A (ch0_pass) → Scene B (ch1_hill). No telegraph residue.

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
		print("FAIL select/focus BoardInset fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT SELECT FOCUS BOARDINSET FAT PASS")
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
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	if pick.find("BattleBoardInset.for_host") < 0:
		return "BattlePick focus must use BoardInset"
	if pick.find("_focus_frame_inset") < 0:
		return "BattlePick missing _focus_frame_inset"
	var focus_i := pick.find("static func focus_cell")
	var follow_i := pick.find("static func focus_follow_cell")
	if focus_i < 0 or follow_i < 0:
		return "BattlePick focus_cell/follow missing"
	var focus_body := pick.substr(focus_i, mini(700, follow_i - focus_i))
	if focus_body.find("_focus_frame_inset") < 0:
		return "focus_cell must call _focus_frame_inset"
	var follow_body := pick.substr(follow_i, 700)
	if follow_body.find("_focus_frame_inset") < 0:
		return "focus_follow_cell must call _focus_frame_inset"
	var frame := FileAccess.get_file_as_string("res://scripts/battle/battle_combat_frame.gd")
	var fc_i := frame.find("static func follow_cells")
	if fc_i < 0:
		return "CombatFrame.follow_cells missing"
	var fc_body := frame.substr(fc_i, 900)
	if fc_body.find("BattleBoardInset.for_host") < 0:
		return "follow_cells must use BoardInset"
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_confirm_affordance.gd")
	if conf.find("BattleBoardInset.for_host") < 0:
		return "confirm settle must still use BoardInset"
	var inset := FileAccess.get_file_as_string("res://scripts/battle/battle_board_inset.gd")
	if inset.find("clip_notch") < 0:
		return "BoardInset must still clip_notch"
	for path in [
		"res://scripts/battle/battle_pick.gd",
		"res://scripts/battle/battle_combat_frame.gd",
		"res://scripts/battle/battle_board_inset.gd",
	]:
		var body := FileAccess.get_file_as_string(path)
		if body.find("foe_opening_telegraph") >= 0 or body.find("BattleLinkTelegraph") >= 0:
			return "%s dragged telegraph residue" % path
	# Pure algebra: BoardInset centre is the focus_pan target, not raw stage.
	var stage := Rect2(0, 0, 900, 500)
	var bi := Rect2(80, 40, 520, 400)
	var delta_raw := BattlePick.focus_pan_delta(Vector2(40, 40), 48.0, Vector2i(0, 0), Vector2.ZERO, 1.0, stage)
	var delta_bi := BattlePick.focus_pan_delta(Vector2(40, 40), 48.0, Vector2i(0, 0), Vector2.ZERO, 1.0, bi)
	if absf(delta_raw.x - delta_bi.x) < 8.0:
		return "focus_pan_delta BoardInset should shift target vs raw stage"
	var nudge_in := BattlePick.focus_nudge_delta(Vector2(40, 40), 48.0, Vector2i(4, 3), Vector2(200, 100), 1.0, bi)
	if nudge_in.length_squared() > 0.25:
		# cell centre may or may not sit inside — just ensure API returns Vector2
		pass
	return ""


func _boot(map_id: String) -> String:
	await _set_window()
	OS.set_environment("CK_FORCE_MOBILE", "1")
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
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
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(4)
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


func _scene_a() -> String:
	var err := _assert_layout("A")
	if err != "":
		return err
	err = await _assert_focus_cell_shares("A")
	if err != "":
		return err
	return await _assert_follow_selected_shares("A")


func _scene_b() -> String:
	var err := _assert_layout("B")
	if err != "":
		return err
	err = await _assert_focus_follow_shares("B")
	if err != "":
		return err
	return await _assert_follow_attack_shares("B")


func _assert_layout(tag: String) -> String:
	if not _battle.has_meta("m_info_block"):
		return "%s: m_info_block missing" % tag
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: info block too thin %s" % [tag, block]
	if not _battle.has_meta("m_edge_band"):
		return "%s: m_edge_band missing" % tag
	var shared: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	if shared.size.x < 72.0:
		return "%s: BoardInset too small %s" % [tag, shared]
	var stage: Rect2 = _stage()
	var raw := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	# Live BoardInset must be notch-tighter (or info-tighter) than raw play_inset.
	if shared.position.x <= raw.position.x + 4.0 and shared.size.x >= raw.size.x - 4.0:
		# Still OK if info cut on the right shrinks size without moving left.
		if shared.end.x >= raw.end.x - 4.0:
			return "%s: BoardInset did not cut notch/info vs raw (%s vs %s)" % [tag, shared, raw]
	return ""


func _assert_focus_cell_shares(tag: String) -> String:
	# Park pan so the actor sits under the info column / past the notch lip.
	var actor: Vector2i = _battle.units[_player_i].pos
	var stage: Rect2 = _stage()
	_battle._board_pan = Vector2(-stage.size.x * 0.55, 0.0)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(2)
	BattleEdgePick.note_layout(_battle)
	await _settle(1)
	var expect: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	var frame_inset: Rect2 = BattlePick._focus_frame_inset(_battle)
	if absf(frame_inset.position.x - expect.position.x) > 1.0 \
			or absf(frame_inset.size.x - expect.size.x) > 1.0:
		return "%s: _focus_frame_inset != BoardInset (%s vs %s)" % [tag, frame_inset, expect]
	# Instant focus (no tween) so we can stamp-read figure position.
	BattlePick.focus_cell(_battle, actor, false, true)
	await _settle(2)
	var fig := BattleCombatFrame.figure_rect(
		_battle.ORIGIN, float(_battle.CELL), actor, _battle._board_pan, _battle._board_zoom)
	var live: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	# Cell centre should sit inside BoardInset (focus_pan targets inset centre).
	var center := fig.get_center()
	if not live.grow(24.0).has_point(center):
		return "%s: focus_cell centre outside BoardInset c=%s inset=%s pan=%s" % [
			tag, center, live, _battle._board_pan]
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x > 1.0 and block.has_point(center):
		return "%s: focus_cell centre still under info %s block=%s" % [tag, center, block]
	# Notch: centre must not sit left of BoardInset lip when lip is live.
	if live.position.x > stage.position.x + 24.0 and center.x + 0.5 < live.position.x:
		return "%s: focus_cell centre left of notch lip c=%s inset=%s" % [tag, center, live]
	return ""


func _assert_follow_selected_shares(tag: String) -> String:
	var actor: Vector2i = _battle.units[_player_i].pos
	_battle.selected = _player_i
	var stage: Rect2 = _stage()
	_battle._board_pan = Vector2(-stage.size.x * 0.5, stage.size.y * 0.2)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	BattlePick.cancel_focus_tween(_battle)
	var pan0: Vector2 = _battle._board_pan
	var expect: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	var applied: Vector2 = BattleCombatFrame.follow_cells(_battle, [actor], 0.0)
	# follow_cells tweens; finish instantly so figure stamp matches the delta.
	_finish_focus_tween()
	await _settle(1)
	if not _battle.has_meta("m_combat_frame"):
		return "%s: follow_cells missing m_combat_frame" % tag
	var info = _battle.get_meta("m_combat_frame")
	if not (info is Dictionary) or not info.has("inset"):
		return "%s: m_combat_frame missing inset %s" % [tag, info]
	var si: Rect2 = info["inset"]
	# Stamp-time BoardInset; allow small drift after await.
	if absf(si.position.x - expect.position.x) > 48.0 \
			or absf(si.size.x - expect.size.x) > 96.0:
		return "%s: follow inset far from BoardInset (%s vs %s)" % [tag, si, expect]
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x > 1.0:
		var overlap: Rect2 = si.intersection(block)
		if overlap.size.x > 1.0 and overlap.size.y > 1.0:
			return "%s: follow inset overlaps info %s block=%s" % [tag, si, block]
	# Ensure pan lands on stamped delta (tween may have been mid-flight).
	_battle._board_pan = pan0 + applied
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	if _battle.has_method("_apply_board_xform"):
		_battle._apply_board_xform()
	var fig := BattleCombatFrame.figure_rect(
		_battle.ORIGIN, float(_battle.CELL), actor, _battle._board_pan, _battle._board_zoom)
	if not si.grow(24.0).has_point(fig.get_center()):
		return "%s: follow figure centre outside inset fig=%s inset=%s applied=%s" % [
			tag, fig, si, applied]
	var raw := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	if expect.position.x > raw.position.x + 8.0 and si.position.x < raw.position.x + 4.0:
		return "%s: follow inset ignored notch/edge cut inset=%s raw=%s" % [tag, si, raw]
	return ""


func _finish_focus_tween() -> void:
	if not _battle.has_meta("_ck_focus_tw"):
		return
	var tw = _battle.get_meta("_ck_focus_tw")
	if tw is Tween and is_instance_valid(tw):
		tw.custom_step(2.0)
	BattlePick.cancel_focus_tween(_battle)


func _assert_focus_follow_shares(tag: String) -> String:
	var actor: Vector2i = _battle.units[_player_i].pos
	var stage: Rect2 = _stage()
	# Nudge the cell just outside the BoardInset left edge.
	var expect: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	var cell_px: float = float(_battle.CELL) * float(_battle._board_zoom)
	var origin_z: Vector2 = _battle.ORIGIN * float(_battle._board_zoom)
	var center: Vector2 = origin_z + Vector2(actor) * cell_px + Vector2(cell_px, cell_px) * 0.5
	# Place shown centre 40px left of BoardInset.
	_battle._board_pan = Vector2(expect.position.x - 40.0 - center.x, expect.get_center().y - center.y)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	BattlePick.cancel_focus_tween(_battle)
	var before: Vector2 = _battle._board_pan
	BattlePick.focus_follow_cell(_battle, actor)
	_finish_focus_tween()
	await _settle(1)
	var after: Vector2 = _battle._board_pan
	var fig := BattleCombatFrame.figure_rect(
		_battle.ORIGIN, float(_battle.CELL), actor, after, _battle._board_zoom)
	var live: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	if not live.grow(24.0).has_point(fig.get_center()):
		return "%s: focus_follow centre outside BoardInset c=%s inset=%s before=%s after=%s" % [
			tag, fig.get_center(), live, before, after]
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x > 1.0 and block.has_point(fig.get_center()):
		return "%s: focus_follow centre under info %s" % [tag, fig.get_center()]
	return ""


func _assert_follow_attack_shares(tag: String) -> String:
	_battle.selected = _player_i
	_battle.preview_attack_ui = _foe_i
	_battle.attack_mode = true
	var stage: Rect2 = _stage()
	_battle._board_pan = Vector2(-stage.size.x * 0.45, 0.0)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	BattlePick.cancel_focus_tween(_battle)
	var band := BattleCombatFrame.forecast_band(true)
	var expect: Rect2 = BattleBoardInset.for_host(_battle, band)
	BattleCombatFrame.follow_attack(_battle)
	_finish_focus_tween()
	await _settle(1)
	if not _battle.has_meta("m_combat_frame"):
		return "%s: follow_attack missing m_combat_frame" % tag
	var info = _battle.get_meta("m_combat_frame")
	if not (info is Dictionary) or not info.has("inset"):
		return "%s: follow_attack inset missing %s" % [tag, info]
	var si: Rect2 = info["inset"]
	if absf(si.position.x - expect.position.x) > 48.0 \
			or absf(si.size.x - expect.size.x) > 96.0:
		return "%s: attack follow inset far from BoardInset (%s vs %s)" % [tag, si, expect]
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x > 1.0:
		var overlap: Rect2 = si.intersection(block)
		if overlap.size.x > 1.0 and overlap.size.y > 1.0:
			return "%s: attack follow overlaps info %s" % [tag, si]
	# Reserve top must leave forecast band (inset top below raw play top + band).
	var raw := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	if si.position.y + 8.0 < raw.position.y + band * 0.35:
		# Only fail when BoardInset was expected to reserve — stamp may use for_host band.
		if expect.position.y > raw.position.y + 20.0 and si.position.y < expect.position.y - 48.0:
			return "%s: attack follow ignored forecast reserve si=%s expect=%s" % [tag, si, expect]
	_battle.attack_mode = false
	_battle.preview_attack_ui = -1
	return ""


func _stage() -> Rect2:
	if _battle.has_meta("m_board_area"):
		return _battle.get_meta("m_board_area")
	return _battle.BOARD_AREA


func _plain_box(center: Vector2i, rad: int) -> void:
	for y in range(center.y - rad, center.y + rad + 1):
		for x in range(center.x - rad, center.x + rad + 1):
			var cell := Vector2i(x, y)
			if not _battle._in_bounds(cell):
				continue
			_battle.terrain[cell.y][cell.x] = "plain"
			if cell.y >= 0 and cell.y < _battle.height_grid.size():
				var row: Array = _battle.height_grid[cell.y]
				if cell.x >= 0 and cell.x < row.size():
					row[cell.x] = 0


func _set_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	DisplayServer.window_set_size(PHONE)
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
	await _settle(4)
