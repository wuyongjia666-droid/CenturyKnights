extends Node
## Fat knife: phase/end banners + engage settle clamp into readable inset
## (info column + notch lip). Algebra first, then Scene A (ch0_pass) +
## Scene B (ch1_hill). No EmptyHost; no telegraph.

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
		print("FAIL phase/end/notch fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT PHASE END NOTCH FAT PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra()
	if err != "":
		return err
	err = await _boot("ch0_pass")
	if err == "":
		err = await _scene_a_phase_banner_and_engage()
	await _free_battle()
	if err != "":
		return err
	err = await _boot("ch1_hill")
	if err == "":
		err = await _scene_b_end_banner_and_side()
	await _free_battle()
	return err


func _algebra() -> String:
	var err := _algebra_banner()
	if err == "":
		err = _algebra_source()
	return err


func _algebra_banner() -> String:
	var stage := Rect2(0, 0, 900, 500)
	var block := Rect2(700, 0, 200, 500)
	var band := BattlePhaseFeel.banner_rect_readable(stage, [block], 48.0, true, true)
	if band.end.x > 700.5:
		return "readable banner still under info %s" % band
	if band.position.x < 47.0:
		return "readable banner ignored notch lip %s" % band
	if not BattlePhaseFeel.banner_clear_of_info(band, [block]):
		return "banner_clear_of_info false on clamped band"
	var fat := BattlePhaseFeel.banner_rect(stage, Vector2.ZERO, stage.size, true, true)
	if fat.end.x <= 700.5:
		return "baseline banner_rect unexpectedly clear of info (fixture broken)"
	var local := BattlePhaseFeel.banner_rect_local_readable(
		stage, Vector2(20, 10), 1.0, [block], 48.0, true, true)
	if local.size.x < 40.0 or local.size.y < 20.0:
		return "banner_rect_local_readable too small %s" % local
	return ""


func _algebra_source() -> String:
	var feel := FileAccess.get_file_as_string("res://scripts/battle/battle_phase_feel.gd")
	if feel.find("banner_rect_readable") < 0 or feel.find("banner_clear_of_info") < 0:
		return "phase_feel missing readable banner helpers"
	if feel.find("BattleActionSettle.apply") < 0:
		return "phase_feel focus no longer settles into readable inset"
	var engage := FileAccess.get_file_as_string("res://scripts/battle/battle_engage_cutscene.gd")
	if engage.find("BattleActionSettle.apply") < 0:
		return "engage bridge no longer settles into readable inset"
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


func _scene_a_phase_banner_and_engage() -> String:
	var err := _assert_layout_meta("A")
	if err != "":
		return err
	err = await _assert_phase_banner_clear("A")
	if err != "":
		return err
	return await _assert_engage_settle("A")


func _scene_b_end_banner_and_side() -> String:
	var err := _assert_layout_meta("B")
	if err != "":
		return err
	err = await _assert_end_banner_clear("B")
	if err != "":
		return err
	return _assert_side_ignore("B")


func _assert_layout_meta(tag: String) -> String:
	if not _battle.has_meta("m_info_block"):
		return "%s: m_info_block missing after note_layout" % tag
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: info block too thin %s" % [tag, block]
	if not _battle.has_meta("m_edge_band"):
		return "%s: m_edge_band missing" % tag
	return ""


func _assert_phase_banner_clear(tag: String) -> String:
	var stage: Rect2 = _stage()
	var blockers: Array = [_battle.get_meta("m_info_block")]
	var edge := float(_battle.get_meta("m_edge_band"))
	var band := BattlePhaseFeel.banner_rect_readable(stage, blockers, edge, true, true)
	if not BattlePhaseFeel.banner_clear_of_info(band, blockers):
		return "%s: phase banner under info %s block=%s" % [tag, band, blockers[0]]
	if band.position.x + 0.5 < stage.position.x + edge:
		return "%s: phase banner into notch lip %s edge=%s" % [tag, band, edge]
	_battle._turn_flash = BattlePhaseFeel.TURN_FLASH_SEC
	_battle.turn_team = "player"
	_battle.set_meta("m_phase_team", "player")
	BattlePhaseFeel.focus_phase_lead(_battle, "player")
	await _settle(4)
	if not _battle.has_meta("m_action_settle"):
		return "%s: phase lead did not stamp m_action_settle" % tag
	return ""


func _assert_end_banner_clear(tag: String) -> String:
	var stage: Rect2 = _stage()
	var blockers: Array = [_battle.get_meta("m_info_block")]
	var edge := float(_battle.get_meta("m_edge_band"))
	var band := BattlePhaseFeel.banner_rect_readable(stage, blockers, edge, true, true)
	band.size.y *= 1.12
	if not BattlePhaseFeel.banner_clear_of_info(band, blockers):
		return "%s: end banner under info %s" % [tag, band]
	BattlePhaseFeel.note_battle_end(_battle, true)
	await _settle(2)
	if not _battle.has_meta("m_end_flash"):
		return "%s: note_battle_end missing m_end_flash" % tag
	var a: float = BattlePhaseFeel.end_alpha(_battle)
	if a <= 0.0:
		return "%s: end_alpha dead right after note" % tag
	return ""


func _assert_engage_settle(tag: String) -> String:
	var atk: Vector2i = _battle.units[_player_i].pos
	var deff: Vector2i = _battle.units[_foe_i].pos
	var stage: Rect2 = _stage()
	_battle._board_pan = Vector2(-stage.size.x * 0.55, 0.0)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	BattleEngageCutscene.note_engage_bridge(_battle, atk, deff)
	await _settle(4)
	if not _battle.has_meta("m_engage_bridge"):
		return "%s: engage bridge meta missing" % tag
	if not _battle.has_meta("m_action_settle"):
		return "%s: engage settle missing m_action_settle" % tag
	var settle: Dictionary = _battle.get_meta("m_action_settle")
	var inset = settle.get("inset", Rect2())
	if not (inset is Rect2) or (inset as Rect2).size.x < 72.0:
		return "%s: engage settle inset missing %s" % [tag, settle]
	var block: Rect2 = _battle.get_meta("m_info_block")
	if (inset as Rect2).intersects(block):
		return "%s: engage settle inset still overlaps info" % tag
	return ""


func _assert_side_ignore(tag: String) -> String:
	var side := _battle.find_child("MobileSideCol", true, false)
	if side == null:
		side = _battle.find_child("SideCol", true, false)
	if side is Control and (side as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return "%s: side col not IGNORE (steals board taps)" % tag
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
	DisplayServer.window_set_size(PHONE)
	await _settle(2)


func _settle(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
	await _settle(4)
