extends Node
## Fat knife: AttackAim after_enter / AttackCycle _aim refreshes m_info_block
## then shares BattleBoardInset (notch + info + edge; forecast_band while
## ForecastPanel is up) — no stale side-col. Algebra → Scene A (ch0_pass) →
## Scene B (ch1_hill). No telegraph residue.

const PHONE := Vector2i(2400, 1080)
const NOTCH := "400,0,0,48"

var _battle: Control
var _player_i := -1
var _foe_a := -1
var _foe_b := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL attack aim/cycle BoardInset fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT ATTACK AIM CYCLE BOARDINSET FAT PASS")
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
	var err := _algebra_one("res://scripts/battle/battle_attack_aim.gd", true)
	if err != "":
		return err
	err = _algebra_one("res://scripts/battle/battle_attack_cycle.gd", false)
	if err != "":
		return err
	return _algebra_inset_header()


func _algebra_one(path: String, is_aim: bool) -> String:
	var body := FileAccess.get_file_as_string(path)
	if body.find("BattleBoardInset.refresh_info_block") < 0:
		return "%s missing BattleBoardInset.refresh_info_block" % path
	if body.find("m_info_block") < 0 or body.find("follow_cells") < 0:
		return "%s missing m_info_block refresh or follow_cells" % path
	# Attack keep forecast_band when ForecastPanel is up (unlike skill refresh).
	if body.find("forecast_band(") < 0:
		return "%s must keep forecast_band for attack ForecastPanel" % path
	if is_aim:
		# after_enter foes path: refresh then follow with forecast_band
		var enter_i := body.find("static func after_enter")
		if enter_i < 0:
			return "%s missing after_enter" % path
		var enter_body := body.substr(enter_i, 1200)
		var ref_i := enter_body.find("BattleBoardInset.refresh_info_block(host)")
		var fol_i := enter_body.find("follow_cells(host, cells,")
		if ref_i < 0 or fol_i < 0 or ref_i > fol_i:
			return "%s after_enter must refresh before follow_cells" % path
		# empty-range path also refreshes
		var empty_i := enter_body.find("idxs.is_empty()")
		if empty_i < 0:
			return "%s after_enter missing empty path" % path
		var empty_slice := enter_body.substr(empty_i, 280)
		if empty_slice.find("BattleBoardInset.refresh_info_block(host)") < 0:
			return "%s empty after_enter must refresh before follow" % path
	else:
		var aim_i := body.find("static func _aim")
		if aim_i < 0:
			return "%s missing _aim" % path
		var aim_body := body.substr(aim_i, 700)
		var ref_i := aim_body.find("BattleBoardInset.refresh_info_block(host)")
		var fol_i := aim_body.find("follow_cells(")
		if ref_i < 0 or fol_i < 0 or ref_i > fol_i:
			return "%s _aim must refresh m_info_block before follow_cells" % path
	if (
		body.find("foe_opening_telegraph") >= 0
		or body.find("BattleLinkTelegraph") >= 0
		or body.find("telegraph") >= 0
		or body.find("Telegraph") >= 0
	):
		return "%s dragged telegraph residue" % path
	if body.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	return ""


func _algebra_inset_header() -> String:
	var inset := FileAccess.get_file_as_string("res://scripts/battle/battle_board_inset.gd")
	if inset.find("AttackAim after_enter") < 0 and inset.find("AttackCycle _aim") < 0:
		return "BoardInset header must mention AttackAim/AttackCycle refresh"
	if inset.find("clip_notch") < 0:
		return "BoardInset must still clip_notch"
	if inset.find("foe_opening_telegraph") >= 0 or inset.find("BattleLinkTelegraph") >= 0:
		return "BoardInset dragged telegraph residue"
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
	if not BattleTouchConfirm.enabled():
		return "touch_confirm not enabled on mobile"
	return _arrange()


func _arrange() -> String:
	_player_i = -1
	_foe_a = -1
	_foe_b = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player" and _player_i < 0:
			_player_i = i
		elif str(u.team) == "enemy":
			if _foe_a < 0:
				_foe_a = i
			elif _foe_b < 0:
				_foe_b = i
	if _player_i < 0 or _foe_a < 0:
		return "deploy missing player/enemy"
	_battle.units[_player_i].pos = Vector2i(4, 3)
	_battle.units[_player_i].done = false
	_battle.units[_player_i].char.job_id = "light_inf"
	_battle.units[_player_i].char.recalc_hp()
	_battle.units[_player_i].char.hp = _battle.units[_player_i].char.max_hp
	_battle.units[_foe_a].pos = Vector2i(5, 3)
	_battle.units[_foe_a].char.hp = maxi(int(_battle.units[_foe_a].char.hp), 10)
	if _foe_b >= 0:
		_battle.units[_foe_b].pos = Vector2i(4, 4)
		_battle.units[_foe_b].char.hp = maxi(int(_battle.units[_foe_b].char.hp), 10)
	_plain_box(Vector2i(4, 3), 4)
	_battle.selected = _player_i
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
	BattleAttackAim.clear(_battle)
	BattleAttackCycle.clear(_battle)
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _scene(tag: String) -> String:
	var err := _assert_layout(tag)
	if err != "":
		return err
	err = await _assert_aim_enter(tag)
	if err != "":
		return err
	return await _assert_cycle(tag)


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
	var banded := BattleBoardInset.for_host(
		_battle, BattleCombatFrame.forecast_band(DeviceProfile.is_mobile())
	)
	if banded.size.y >= shared.size.y - 1.0:
		return (
			"%s: forecast_band reserve should shrink BoardInset (%s vs %s)" % [tag, banded, shared]
		)
	return ""


func _assert_aim_enter(tag: String) -> String:
	_battle._select_player(_player_i)
	await _settle(3)
	# Stale the info block so refresh must rewrite it from MobileSideCol.
	_battle.set_meta("m_info_block", Rect2(0, 0, 8, 8))
	_battle._enter_attack_mode()
	_finish_focus_tween()
	await _settle(4)
	if not BattleAttackAim.active(_battle):
		return "%s: attack aim not active after enter" % tag
	var idxs: Array[int] = BattleAttackAim.threatened_indices(_battle)
	if not idxs.has(_foe_a):
		return "%s: foe_a not threatened got %s" % [tag, idxs]
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: aim enter left stale m_info_block %s" % [tag, block]
	var err := _assert_frame_meta("%s aim" % tag, true)
	return err


func _assert_cycle(tag: String) -> String:
	if not BattleAttackCycle.active(_battle):
		return "%s: attack cycle not active" % tag
	var idxs: Array[int] = BattleAttackCycle.threatened_indices(_battle)
	if idxs.is_empty():
		return "%s: cycle threatened empty" % tag
	_battle.set_meta("m_info_block", Rect2(0, 0, 8, 8))
	var first: int = BattleAttackCycle.apply_next(_battle)
	_finish_focus_tween()
	await _settle(2)
	if first < 0:
		return "%s: cycle next failed" % tag
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: cycle left stale m_info_block %s" % [tag, block]
	var err := _assert_frame_meta("%s cycle" % tag, true)
	if err != "":
		return err
	if idxs.size() >= 2:
		_battle.set_meta("m_info_block", Rect2(0, 0, 8, 8))
		var second: int = BattleAttackCycle.apply_next(_battle)
		_finish_focus_tween()
		await _settle(2)
		if second < 0 or second == first:
			# wrap may land on same if only one — already guarded by size>=2
			if second == first:
				return "%s: cycle next did not advance (%s)" % [tag, second]
		block = _battle.get_meta("m_info_block")
		if block.size.x < 40.0:
			return "%s: cycle2 left stale m_info_block %s" % [tag, block]
		err = _assert_frame_meta("%s cycle2" % tag, true)
		if err != "":
			return err
	BattleTouchConfirm.clear(_battle, false)
	BattleAttackAim.clear(_battle)
	BattleAttackCycle.clear(_battle)
	BattlePick.cancel_focus_tween(_battle)
	_battle.attack_mode = false
	_battle.preview_attack_ui = -1
	return ""


func _assert_frame_meta(tag: String, expect_band: bool) -> String:
	if not _battle.has_meta("m_combat_frame"):
		return "%s: m_combat_frame missing after follow" % tag
	var info = _battle.get_meta("m_combat_frame")
	if not info is Dictionary:
		return "%s: m_combat_frame not dict" % tag
	var reserve := float(info.get("reserve_top", -1.0))
	var want := (
		BattleCombatFrame.forecast_band(DeviceProfile.is_mobile()) if expect_band else 0.0
	)
	if absf(reserve - want) > 0.01:
		return "%s: reserve_top want %s got %s" % [tag, want, reserve]
	var inset: Rect2 = info.get("inset", Rect2())
	var shared: Rect2 = BattleBoardInset.for_host(_battle, want)
	if (
		absf(inset.position.x - shared.position.x) > 1.0
		or absf(inset.position.y - shared.position.y) > 1.0
		or absf(inset.size.x - shared.size.x) > 1.0
		or absf(inset.size.y - shared.size.y) > 1.0
	):
		return "%s: follow inset != BoardInset@%s (%s vs %s)" % [tag, want, inset, shared]
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
