extends Node
## Fat knife: BoardInset.for_host live-refreshes m_info_block from
## MobileSideCol before cutting blockers — select focus / follow_selected /
## wait handoff share notch+info+edge without a stale side-col.
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
		print("FAIL BoardInset live-info refresh fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT BOARDINSET LIVE INFO REFRESH FAT PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra()
	if err != "":
		return err
	err = await _boot("ch0_pass")
	if err == "":
		err = await _scene("A")
	await _free_battle()
	if err != "":
		return err
	err = await _boot("ch1_hill")
	if err == "":
		err = await _scene("B")
	await _free_battle()
	return err


func _algebra() -> String:
	var path := "res://scripts/battle/battle_board_inset.gd"
	var body := FileAccess.get_file_as_string(path)
	if body.find("static func refresh_info_block") < 0:
		return "%s missing refresh_info_block" % path
	if body.find("MobileSideCol") < 0:
		return "%s refresh must read MobileSideCol" % path
	var fh := body.find("static func for_host")
	if fh < 0:
		return "%s missing for_host" % path
	var fh_end := body.find("static func from_parts", fh)
	if fh_end < 0:
		fh_end = fh + 900
	var fh_body := body.substr(fh, fh_end - fh)
	var ref_i := fh_body.find("refresh_info_block(host)")
	var blk_i := fh_body.find("_blockers(host)")
	if ref_i < 0 or blk_i < 0 or ref_i > blk_i:
		return "%s for_host must refresh_info_block before _blockers" % path
	if body.find("live-refreshes") < 0 and body.find("live-refresh") < 0:
		return "%s header must mention for_host live-refresh" % path
	if body.find("clip_notch") < 0:
		return "BoardInset must still clip_notch"
	if (
		body.find("foe_opening_telegraph") >= 0
		or body.find("BattleLinkTelegraph") >= 0
		or body.find("EmptyHost") >= 0
	):
		return "%s dragged telegraph/EmptyHost residue" % path
	# Select / wait handoff paths must still route through BoardInset.
	var pick := FileAccess.get_file_as_string("res://scripts/battle/battle_pick.gd")
	if pick.find("BattleBoardInset.for_host") < 0:
		return "BattlePick focus must still use BoardInset.for_host"
	var frame := FileAccess.get_file_as_string("res://scripts/battle/battle_combat_frame.gd")
	var fc_i := frame.find("static func follow_cells")
	if fc_i < 0:
		return "CombatFrame.follow_cells missing"
	var fc_body := frame.substr(fc_i, 900)
	if fc_body.find("BattleBoardInset.for_host") < 0:
		return "follow_cells must use BoardInset.for_host"
	var wait := FileAccess.get_file_as_string("res://scripts/battle/battle_wait_handoff.gd")
	if wait.find("follow_selected") < 0:
		return "WaitHandoff must still follow_selected"
	if wait.find("foe_opening_telegraph") >= 0 or wait.find("BattleLinkTelegraph") >= 0:
		return "WaitHandoff dragged telegraph residue"
	if pick.find("EmptyHost") >= 0 or frame.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
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
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
	if _player_i < 0 or _foe_i < 0:
		return "deploy missing player/enemy"
	var th: int = _battle.terrain.size()
	var tw: int = _battle.terrain[0].size() if th > 0 else 8
	var stand := Vector2i(mini(3, tw - 1), mini(2, th - 1))
	var near := Vector2i(mini(stand.x + 1, tw - 1), stand.y)
	if near == stand:
		near = Vector2i(stand.x, mini(stand.y + 1, th - 1))
	_battle.units[_player_i].pos = stand
	_battle.units[_player_i].done = false
	_battle.units[_player_i].char.hp = maxi(int(_battle.units[_player_i].char.hp), 10)
	_battle.units[_foe_i].pos = near
	_battle.units[_foe_i].char.hp = maxi(int(_battle.units[_foe_i].char.hp), 10)
	for i in _battle.units.size():
		if i == _player_i or i == _foe_i:
			continue
		if str(_battle.units[i].team) == "player" and int(_battle.units[i].char.hp) > 0:
			_battle.units[i].pos = Vector2i(10, 8)
			_battle.units[i].done = true
		elif str(_battle.units[i].team) == "enemy" and int(_battle.units[i].char.hp) > 0:
			_battle.units[i].pos = Vector2i(11, 8)
	_plain_box(stand, 3)
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	_battle.attack_mode = false
	_battle.skill_mode = false
	_battle.active_skill_id = ""
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle.moved_this_select = false
	_battle.move_cells = {}
	_battle.danger_on = false
	_battle.danger_focus = -1
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _scene(tag: String) -> String:
	var err := _assert_layout(tag)
	if err != "":
		return err
	err = await _assert_for_host_refresh(tag)
	if err != "":
		return err
	err = await _assert_follow_selected(tag)
	if err != "":
		return err
	return await _assert_focus_selected(tag)


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
	if shared.position.x <= raw.position.x + 4.0 and shared.size.x >= raw.size.x - 4.0:
		if shared.end.x >= raw.end.x - 4.0:
			return "%s: BoardInset did not cut notch/info vs raw (%s vs %s)" % [tag, shared, raw]
	return ""


func _assert_for_host_refresh(tag: String) -> String:
	# Stale the info block; for_host must rewrite from MobileSideCol.
	_battle.set_meta("m_info_block", Rect2(0, 0, 8, 8))
	var live: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: for_host left stale m_info_block %s" % [tag, block]
	if live.size.x < 72.0:
		return "%s: live BoardInset too small %s" % [tag, live]
	# Live blockers must still cut notch/info vs raw stage play inset.
	var stage: Rect2 = _stage()
	var raw := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	if live.position.x <= raw.position.x + 4.0 and live.size.x >= raw.size.x - 4.0:
		if live.end.x >= raw.end.x - 4.0:
			return "%s: refreshed BoardInset did not cut notch/info (%s vs %s)" % [tag, live, raw]
	return ""


func _assert_follow_selected(tag: String) -> String:
	_battle.selected = _player_i
	_battle.set_meta("m_info_block", Rect2(0, 0, 8, 8))
	BattleCombatFrame.follow_selected(_battle)
	_finish_focus_tween()
	await _settle(2)
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: follow_selected left stale m_info_block %s" % [tag, block]
	var err := _assert_frame_meta("%s follow_selected" % tag)
	BattlePick.cancel_focus_tween(_battle)
	return err


func _assert_focus_selected(tag: String) -> String:
	_battle.selected = _player_i
	_battle.set_meta("m_info_block", Rect2(0, 0, 8, 8))
	BattlePick.focus_selected(_battle)
	_finish_focus_tween()
	await _settle(2)
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: focus_selected left stale m_info_block %s" % [tag, block]
	# focus_selected → follow_selected should stamp combat frame with live inset.
	var err := _assert_frame_meta("%s focus_selected" % tag)
	BattlePick.cancel_focus_tween(_battle)
	return err


func _assert_frame_meta(tag: String) -> String:
	if not _battle.has_meta("m_combat_frame"):
		return "%s: m_combat_frame missing after follow" % tag
	var info = _battle.get_meta("m_combat_frame")
	if not info is Dictionary:
		return "%s: m_combat_frame not dict" % tag
	var reserve := float(info.get("reserve_top", -1.0))
	if absf(reserve) > 0.01:
		return "%s: reserve_top want 0 got %s" % [tag, reserve]
	var inset: Rect2 = info.get("inset", Rect2())
	var shared: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	if (
		absf(inset.position.x - shared.position.x) > 1.0
		or absf(inset.position.y - shared.position.y) > 1.0
		or absf(inset.size.x - shared.size.x) > 1.0
		or absf(inset.size.y - shared.size.y) > 1.0
	):
		return "%s: follow inset != BoardInset@0 (%s vs %s)" % [tag, inset, shared]
	return ""


func _finish_focus_tween() -> void:
	if not _battle.has_meta("_ck_focus_tw"):
		return
	var tw = _battle.get_meta("_ck_focus_tw")
	if tw is Tween and is_instance_valid(tw):
		tw.custom_step(2.0)
	BattlePick.cancel_focus_tween(_battle)


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
