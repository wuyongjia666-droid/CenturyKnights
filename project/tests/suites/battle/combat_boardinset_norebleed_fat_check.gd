extends Node
## Fat knife: BoardInset blocker cut no longer re-bleeds a 72px floor into the
## info column / notch. ConfirmAffordance + ActionSettle.readable_inset share
## BoardInset.from_parts. Algebra → Scene A (ch0_pass) → Scene B (ch1_hill).
## No telegraph residue.

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
		print("FAIL BoardInset no-rebleed fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT BOARDINSET NO-REBLEED FAT PASS")
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
	var err := _algebra_sources_inset()
	if err != "":
		return err
	err = _algebra_sources_readers()
	if err != "":
		return err
	err = _algebra_no_rebleed()
	if err != "":
		return err
	err = _algebra_from_parts_shared()
	if err != "":
		return err
	return _algebra_no_telegraph()


## Split for gdlint max-returns.
func _algebra_sources_inset() -> String:
	var inset := FileAccess.get_file_as_string("res://scripts/battle/battle_board_inset.gd")
	if inset.find("static func from_parts") < 0:
		return "BoardInset.from_parts missing"
	if inset.find("re-bleed") < 0 and inset.find("no-rebleed") < 0:
		return "BoardInset header must mention no-rebleed"
	var cut_i := inset.find("static func _cut_blocker")
	if cut_i < 0:
		return "BoardInset._cut_blocker missing"
	var cut_body := inset.substr(cut_i, 900)
	if cut_body.find("maxf(72") >= 0:
		return "BoardInset._cut_blocker still inflates 72px floor"
	if cut_body.find("w < 8.0") < 0:
		return "BoardInset._cut_blocker missing no-rebleed 8px floor"
	if inset.find("clip_notch") < 0:
		return "BoardInset must still clip_notch"
	return ""


## Split for gdlint max-returns.
func _algebra_sources_readers() -> String:
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_confirm_affordance.gd")
	if conf.find("BattleBoardInset.from_parts") < 0:
		return "ConfirmAffordance.readable_inset must call from_parts"
	if conf.find("static func _cut_blocker") >= 0:
		return "ConfirmAffordance must drop private _cut_blocker"
	if conf.find("BattleBoardInset.for_host") < 0:
		return "confirm live chips/settle must still use for_host"
	var settle := FileAccess.get_file_as_string("res://scripts/battle/battle_action_settle.gd")
	if settle.find("BattleBoardInset.from_parts") < 0:
		return "ActionSettle.readable_inset must call from_parts"
	if settle.find("static func _cut_blocker") >= 0:
		return "ActionSettle must drop private _cut_blocker"
	if settle.find("static func readable_inset") < 0:
		return "ActionSettle.readable_inset algebra helper missing"
	if settle.find("BattleBoardInset.for_host") < 0:
		return "ActionSettle.apply must still use for_host"
	return ""


func _algebra_no_rebleed() -> String:
	# Narrow remaining strip: old 72px floor re-bled into the right info block.
	var inset := Rect2(0, 0, 100, 500)
	var block := Rect2(50, 0, 200, 500)
	var cut := BattleBoardInset._cut_blocker(inset, block)
	if cut.end.x > block.position.x + 0.5:
		return "right blocker re-bleed: cut %s still overlaps block at %s" % [cut, block.position.x]
	if cut.size.x > 50.5:
		return "right blocker inflated past cut edge %s" % cut
	# Wide cut still shaves (select-range algebra contract).
	var stage := Rect2(0, 0, 800, 500)
	var right := Rect2(600, 0, 200, 500)
	var wide := BattleBoardInset._cut_blocker(stage, right)
	if wide.end.x > right.position.x + 1.0:
		return "right blocker must shave inset end got %s" % wide
	# Top notch-like block: no inflate past cut.
	var top_block := Rect2(0, 0, 800, 40)
	var top_cut := BattleBoardInset._cut_blocker(stage, top_block)
	if top_cut.position.y < top_block.end.y - 0.5:
		return "top blocker re-bleed: cut %s" % top_cut
	return ""


func _algebra_from_parts_shared() -> String:
	var stage := Rect2(0, 0, 900, 500)
	var block := Rect2(700, 0, 200, 500)
	var edge := 48.0
	var parts := BattleBoardInset.from_parts(stage, 0.0, [block], edge)
	var conf := BattleConfirmAffordance.readable_inset(stage, [block], edge)
	var settle := BattleActionSettle.readable_inset(stage, [block], edge)
	if (
		absf(parts.position.x - conf.position.x) > 0.01
		or absf(parts.size.x - conf.size.x) > 0.01
		or absf(parts.position.y - conf.position.y) > 0.01
		or absf(parts.size.y - conf.size.y) > 0.01
	):
		return "Confirm readable_inset != from_parts (%s vs %s)" % [conf, parts]
	if (
		absf(parts.position.x - settle.position.x) > 0.01
		or absf(parts.size.x - settle.size.x) > 0.01
		or absf(parts.position.y - settle.position.y) > 0.01
		or absf(parts.size.y - settle.size.y) > 0.01
	):
		return "ActionSettle readable_inset != from_parts (%s vs %s)" % [settle, parts]
	if parts.end.x > block.position.x + 0.5:
		return "from_parts still under info %s" % parts
	if parts.position.x < edge - 1.0:
		return "from_parts ignored edge band %s" % parts
	return ""


func _algebra_no_telegraph() -> String:
	for path in [
		"res://scripts/battle/battle_board_inset.gd",
		"res://scripts/battle/battle_confirm_affordance.gd",
		"res://scripts/battle/battle_action_settle.gd",
	]:
		var body := FileAccess.get_file_as_string(path)
		if body.find("foe_opening_telegraph") >= 0 or body.find("BattleLinkTelegraph") >= 0:
			return "%s dragged telegraph residue" % path
		if body.find("telegraph") >= 0 or body.find("Telegraph") >= 0:
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


func _scene(tag: String) -> String:
	var err := _assert_layout(tag)
	if err != "":
		return err
	err = await _assert_select_keep(tag)
	if err != "":
		return err
	return await _assert_confirm_settle(tag)


func _assert_layout(tag: String) -> String:
	if not _battle.has_meta("m_info_block"):
		return "%s: m_info_block missing" % tag
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: info block too thin %s" % [tag, block]
	if not _battle.has_meta("m_edge_band"):
		return "%s: m_edge_band missing" % tag
	var edge := float(_battle.get_meta("m_edge_band"))
	var shared: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	if shared.size.x < 72.0:
		return "%s: BoardInset too small %s" % [tag, shared]
	# Live inset must not re-bleed into the info column.
	var overlap := shared.intersection(block)
	if overlap.size.x > 1.0 and overlap.size.y > 1.0:
		return "%s: BoardInset re-bleeds into info (%s ∩ %s = %s)" % [tag, shared, block, overlap]
	var stage: Rect2 = _stage()
	var parts := BattleBoardInset.from_parts(stage, 0.0, [block], edge)
	# from_parts is pre-notch; for_host must be at least as tight on the left (notch).
	if shared.position.x + 1.0 < parts.position.x:
		return "%s: for_host looser left than from_parts (%s vs %s)" % [tag, shared, parts]
	if shared.end.x > parts.end.x + 1.0:
		return "%s: for_host re-bleeds past from_parts right (%s vs %s)" % [tag, shared, parts]
	var raw := BattleCombatFrame.play_inset(stage, 0.0, 0.0)
	if shared.position.x <= raw.position.x + 4.0 and shared.size.x >= raw.size.x - 4.0:
		if shared.end.x >= raw.end.x - 4.0:
			return "%s: BoardInset did not cut notch/info vs raw (%s vs %s)" % [tag, shared, raw]
	return ""


func _assert_select_keep(tag: String) -> String:
	_battle._select_player(_player_i)
	await _settle(3)
	BattleRangePreview.publish(_battle)
	await _settle(2)
	var shared: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	var playable: Rect2 = BattleRangePreview.playable_inset(_battle)
	if (
		absf(playable.position.x - shared.position.x) > 1.0
		or absf(playable.size.x - shared.size.x) > 1.0
	):
		return "%s: range playable != BoardInset (%s vs %s)" % [tag, playable, shared]
	BattleRangePreview.keep_selected(_battle)
	if not _battle.has_meta("m_range_keep"):
		return "%s: keep_selected did not stamp m_range_keep" % tag
	var keep_info = _battle.get_meta("m_range_keep")
	if keep_info is Dictionary and keep_info.has("inset"):
		var ki: Rect2 = keep_info["inset"]
		if absf(ki.position.x - shared.position.x) > 1.0 or absf(ki.size.x - shared.size.x) > 1.0:
			return "%s: keep inset != BoardInset (%s vs %s)" % [tag, ki, shared]
		var block: Rect2 = _battle.get_meta("m_info_block")
		var overlap := ki.intersection(block)
		if overlap.size.x > 1.0 and overlap.size.y > 1.0:
			return "%s: keep inset re-bleeds into info %s" % [tag, overlap]
	return ""


func _assert_confirm_settle(tag: String) -> String:
	_battle._select_player(_player_i)
	await _settle(2)
	# Latch a soft-confirm move preview so chips park in BoardInset.
	var actor: Vector2i = _battle.units[_player_i].pos
	var dest := actor + Vector2i(1, 0)
	_battle.preview_move_cell = dest
	_battle.preview_attack_ui = -1
	if DeviceProfile.is_mobile():
		BattleMobileBar.rebuild(_battle)
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(2)
	BattleEdgePick.note_layout(_battle)
	var shared: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	var chips: Rect2 = BattleConfirmAffordance.chip_bounds(_battle)
	if chips.size.x < 8.0:
		return "%s: chip_bounds empty" % tag
	if absf(chips.position.x - shared.position.x) > 1.0 or absf(chips.size.x - shared.size.x) > 1.0:
		return "%s: chip_bounds != BoardInset (%s vs %s)" % [tag, chips, shared]
	var block: Rect2 = _battle.get_meta("m_info_block")
	var overlap := chips.intersection(block)
	if overlap.size.x > 1.0 and overlap.size.y > 1.0:
		return "%s: chip_bounds re-bleeds into info %s" % [tag, overlap]
	# Camera settle after action uses shared BoardInset (no info re-bleed).
	var stage: Rect2 = _stage()
	_battle._board_pan = Vector2(-stage.size.x * 0.55, 0.0)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(2)
	BattleEdgePick.note_layout(_battle)
	var expect: Rect2 = BattleBoardInset.for_host(_battle, 0.0)
	BattleActionSettle.apply(_battle, actor, [])
	await _settle(1)
	if not _battle.has_meta("m_action_settle"):
		return "%s: ActionSettle.apply missing m_action_settle" % tag
	var settle: Dictionary = _battle.get_meta("m_action_settle")
	var sett_inset = settle.get("inset", Rect2())
	if not (sett_inset is Rect2) or (sett_inset as Rect2).size.x < 72.0:
		return "%s: action settle inset missing %s" % [tag, settle]
	var si: Rect2 = sett_inset
	if absf(si.position.x - expect.position.x) > 8.0 or absf(si.size.x - expect.size.x) > 24.0:
		return "%s: action settle inset != BoardInset (%s vs %s)" % [tag, si, expect]
	var ov2 := si.intersection(block)
	if ov2.size.x > 1.0 and ov2.size.y > 1.0:
		return "%s: action settle inset re-bleeds info %s" % [tag, ov2]
	_battle.preview_move_cell = Vector2i(-1, -1)
	BattlePick.cancel_focus_tween(_battle)
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
