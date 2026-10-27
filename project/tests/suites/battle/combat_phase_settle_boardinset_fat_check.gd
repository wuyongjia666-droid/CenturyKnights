extends Node
## Fat knife: phase/end banners + action/engage settle share BattleBoardInset
## (notch + info + edge) with range keep / confirm settle. Algebra → Scene A
## (ch0_pass) → Scene B (ch1_hill). No telegraph residue.

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
		print("FAIL phase/settle BoardInset fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT PHASE SETTLE BOARDINSET FAT PASS")
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
		err = _algebra_banner_in_inset()
	if err == "":
		err = _algebra_no_telegraph()
	return err


func _algebra_wiring() -> String:
	var settle := FileAccess.get_file_as_string("res://scripts/battle/battle_action_settle.gd")
	if settle.find("BattleBoardInset.for_host") < 0:
		return "ActionSettle.apply must use BoardInset"
	if settle.find("static func readable_inset") < 0:
		return "ActionSettle.readable_inset algebra helper missing"
	var feel := FileAccess.get_file_as_string("res://scripts/battle/battle_phase_feel.gd")
	if feel.find("banner_rect_for_host") < 0:
		return "PhaseFeel missing banner_rect_for_host"
	if feel.find("BattleBoardInset.for_host") < 0:
		return "PhaseFeel live banners must use BoardInset"
	if feel.find("banner_rect_in_inset") < 0:
		return "PhaseFeel missing banner_rect_in_inset"
	# draw_turn / draw_end must call for_host, not the pure readable path alone.
	var draw_turn_i := feel.find("static func draw_turn_banner")
	var draw_end_i := feel.find("static func draw_end_banner")
	if draw_turn_i < 0 or draw_end_i < 0:
		return "PhaseFeel draw_turn/end missing"
	var turn_body := feel.substr(draw_turn_i, mini(900, draw_end_i - draw_turn_i))
	if turn_body.find("banner_rect_for_host") < 0:
		return "draw_turn_banner must call banner_rect_for_host"
	var end_body := feel.substr(draw_end_i, 900)
	if end_body.find("banner_rect_for_host") < 0:
		return "draw_end_banner must call banner_rect_for_host"
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_confirm_affordance.gd")
	if conf.find("BattleBoardInset.for_host") < 0:
		return "confirm settle must still use BoardInset"
	var inset := FileAccess.get_file_as_string("res://scripts/battle/battle_board_inset.gd")
	if inset.find("clip_notch") < 0:
		return "BoardInset must still clip_notch"
	return ""


func _algebra_banner_in_inset() -> String:
	var stage := Rect2(0, 0, 900, 500)
	var inset := Rect2(48, 48, 600, 400)
	var band := BattlePhaseFeel.banner_rect_in_inset(inset, stage, true, true)
	if band.position.x + 0.5 < inset.position.x:
		return "banner_in_inset left of inset %s" % band
	if band.end.x > inset.end.x + 0.5:
		return "banner_in_inset past inset end %s" % band
	if band.position.y + 0.5 < inset.position.y:
		return "banner_in_inset above inset %s" % band
	if band.end.y > inset.end.y + 0.5:
		return "banner_in_inset below inset %s" % band
	var block := Rect2(700, 0, 200, 500)
	var readable := BattlePhaseFeel.banner_rect_readable(stage, [block], 48.0, true, true)
	if not BattlePhaseFeel.banner_clear_of_info(readable, [block]):
		return "readable banner still under info %s" % readable
	if readable.position.x < 47.0:
		return "readable banner ignored edge lip %s" % readable
	return ""


func _algebra_no_telegraph() -> String:
	for path in [
		"res://scripts/battle/battle_action_settle.gd",
		"res://scripts/battle/battle_phase_feel.gd",
		"res://scripts/battle/battle_board_inset.gd",
	]:
		var body := FileAccess.get_file_as_string(path)
		if body.find("foe_opening_telegraph") >= 0 or body.find("BattleLinkTelegraph") >= 0:
			return "%s dragged telegraph residue" % path
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
	err = await _assert_phase_banner_shares("A")
	if err != "":
		return err
	return await _assert_engage_settle_shares("A")


func _scene_b() -> String:
	var err := _assert_layout("B")
	if err != "":
		return err
	err = await _assert_end_banner_shares("B")
	if err != "":
		return err
	return await _assert_action_settle_shares("B")


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
	return ""


func _assert_phase_banner_shares(tag: String) -> String:
	var shared: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	var band: Rect2 = BattlePhaseFeel.banner_rect_for_host(_battle, true, true)
	if band.position.x + 0.5 < shared.position.x:
		return "%s: phase banner left of BoardInset band=%s inset=%s" % [tag, band, shared]
	if band.end.x > shared.end.x + 0.5:
		return "%s: phase banner past BoardInset end band=%s inset=%s" % [tag, band, shared]
	var blockers: Array = [_battle.get_meta("m_info_block")]
	if not BattlePhaseFeel.banner_clear_of_info(band, blockers):
		return "%s: phase banner under info %s" % [tag, band]
	_battle._turn_flash = BattlePhaseFeel.TURN_FLASH_SEC
	_battle.turn_team = "player"
	_battle.set_meta("m_phase_team", "player")
	BattlePhaseFeel.focus_phase_lead(_battle, "player")
	# ActionSettle.apply refreshes m_info_block from MobileSideCol — capture
	# expect after the stamp so we compare the same BoardInset algebra.
	var expect: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	await _settle(2)
	if not _battle.has_meta("m_action_settle"):
		return "%s: phase lead did not stamp m_action_settle" % tag
	var settle: Dictionary = _battle.get_meta("m_action_settle")
	var si = settle.get("inset", Rect2())
	if not (si is Rect2) or (si as Rect2).size.x < 72.0:
		return "%s: phase settle inset missing %s" % [tag, settle]
	# Stamp-time BoardInset; layout may drift after await.
	if absf((si as Rect2).position.x - expect.position.x) > 48.0 \
			or absf((si as Rect2).size.x - expect.size.x) > 96.0:
		return "%s: phase settle inset far from BoardInset (%s vs %s)" % [tag, si, expect]
	var block: Rect2 = settle.get("block", blockers[0])
	if block.size.x > 1.0:
		var overlap: Rect2 = (si as Rect2).intersection(block)
		if overlap.size.x > 1.0 and overlap.size.y > 1.0:
			return "%s: phase settle overlaps info %s block=%s" % [tag, si, block]
	return ""


func _assert_engage_settle_shares(tag: String) -> String:
	var atk: Vector2i = _battle.units[_player_i].pos
	var deff: Vector2i = _battle.units[_foe_i].pos
	var stage: Rect2 = _stage()
	_battle._board_pan = Vector2(-stage.size.x * 0.55, 0.0)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	# Refresh chrome so for_host and apply see the same live column.
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(2)
	BattleEdgePick.note_layout(_battle)
	await _settle(1)
	BattleEngageCutscene.note_engage_bridge(_battle, atk, deff)
	# Capture expect after stamp (apply refreshes m_info_block from live col).
	var expect: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	await _settle(2)
	if not _battle.has_meta("m_engage_bridge"):
		return "%s: engage bridge meta missing" % tag
	if not _battle.has_meta("m_action_settle"):
		return "%s: engage settle missing m_action_settle" % tag
	var settle: Dictionary = _battle.get_meta("m_action_settle")
	var inset = settle.get("inset", Rect2())
	if not (inset is Rect2) or (inset as Rect2).size.x < 72.0:
		return "%s: engage settle inset missing %s" % [tag, settle]
	if absf((inset as Rect2).position.x - expect.position.x) > 48.0 \
			or absf((inset as Rect2).size.x - expect.size.x) > 96.0:
		return "%s: engage settle inset far from BoardInset (%s vs %s)" % [tag, inset, expect]
	var block: Rect2 = settle.get("block", _battle.get_meta("m_info_block"))
	if block.size.x < 1.0 and _battle.has_meta("m_info_block"):
		block = _battle.get_meta("m_info_block")
	var overlap: Rect2 = (inset as Rect2).intersection(block)
	if overlap.size.x > 1.0 and overlap.size.y > 1.0:
		return "%s: engage settle still overlaps info inset=%s block=%s" % [tag, inset, block]
	# Stamped inset must be notch-tighter than raw play_inset when lip is live.
	var raw := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	if expect.position.x > raw.position.x + 8.0 and (inset as Rect2).position.x < raw.position.x + 4.0:
		return "%s: engage settle ignored notch/edge cut inset=%s raw=%s" % [tag, inset, raw]
	return ""


func _assert_end_banner_shares(tag: String) -> String:
	var shared: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	var band: Rect2 = BattlePhaseFeel.banner_rect_for_host(_battle, true, true)
	band.size.y *= 1.12
	if band.position.x + 0.5 < shared.position.x:
		return "%s: end banner left of BoardInset %s" % [tag, band]
	if not BattlePhaseFeel.banner_clear_of_info(band, [_battle.get_meta("m_info_block")]):
		return "%s: end banner under info %s" % [tag, band]
	BattlePhaseFeel.note_battle_end(_battle, true)
	await _settle(2)
	if not _battle.has_meta("m_end_flash"):
		return "%s: note_battle_end missing m_end_flash" % tag
	if BattlePhaseFeel.end_alpha(_battle) <= 0.0:
		return "%s: end_alpha dead right after note" % tag
	return ""


func _assert_action_settle_shares(tag: String) -> String:
	# Park actor under a pan that would push the figure into the lip, then settle.
	var actor: Vector2i = _battle.units[_player_i].pos
	var stage: Rect2 = _stage()
	_battle._board_pan = Vector2(-stage.size.x * 0.6, 0.0)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(2)
	BattleEdgePick.note_layout(_battle)
	BattleActionSettle.apply(_battle, actor, [])
	var expect: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	await _settle(1)
	if not _battle.has_meta("m_action_settle"):
		return "%s: ActionSettle.apply missing m_action_settle" % tag
	var settle: Dictionary = _battle.get_meta("m_action_settle")
	var inset = settle.get("inset", Rect2())
	if not (inset is Rect2) or (inset as Rect2).size.x < 72.0:
		return "%s: action settle inset missing %s" % [tag, settle]
	if absf((inset as Rect2).position.x - expect.position.x) > 8.0 \
			or absf((inset as Rect2).size.x - expect.size.x) > 24.0:
		return "%s: action settle inset != BoardInset (%s vs %s)" % [tag, inset, expect]
	# Range playable must agree with the live BoardInset.
	var playable: Rect2 = BattleRangePreview.playable_inset(_battle)
	var live: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	if absf(playable.position.x - live.position.x) > 1.0 \
			or absf(playable.size.x - live.size.x) > 1.0:
		return "%s: range playable drifted from BoardInset (%s vs %s)" % [tag, playable, live]
	var block: Rect2 = settle.get("block", Rect2())
	if block.size.x > 1.0:
		var overlap: Rect2 = (inset as Rect2).intersection(block)
		if overlap.size.x > 1.0 and overlap.size.y > 1.0:
			return "%s: action settle overlaps info %s" % [tag, inset]
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
