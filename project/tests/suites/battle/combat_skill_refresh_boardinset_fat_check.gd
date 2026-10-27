extends Node
## Fat knife: skill buff/heal soft-confirm arm/_aim refreshes m_info_block
## then shares BattleBoardInset (notch + info + edge, reserve_top 0) — no stale side-col.
## Algebra → Scene A (ch0_pass) → Scene B (ch1_hill). No telegraph residue.

const PHONE := Vector2i(2400, 1080)
const NOTCH := "400,0,0,48"
const BUFF_SID := "chart_rally"
const HEAL_SID := "ward_chant"

var _battle: Control
var _caster_i := -1
var _ally_i := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL skill refresh BoardInset fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT SKILL REFRESH BOARDINSET FAT PASS")
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
	var err := _algebra_sources()
	if err != "":
		return err
	return _algebra_skills()


func _algebra_sources() -> String:
	for path in [
		"res://scripts/battle/battle_skill_buff_preview.gd",
		"res://scripts/battle/battle_skill_heal_preview.gd",
	]:
		var err := _algebra_one_preview(path)
		if err != "":
			return err
	return _algebra_inset_header()


func _algebra_one_preview(path: String) -> String:
	var body := FileAccess.get_file_as_string(path)
	if body.find("_refresh_info_block") < 0:
		return "%s missing _refresh_info_block" % path
	if body.find("m_info_block") < 0 or body.find("follow_cells") < 0:
		return "%s missing m_info_block refresh or follow_cells" % path
	if body.find("forecast_band(") >= 0:
		return "%s still reserves forecast_band for follow" % path
	var i := 0
	while true:
		var hit := body.find("follow_cells(", i)
		if hit < 0:
			break
		var slice := body.substr(hit, 120)
		if slice.find("0.0") < 0:
			return "%s follow_cells must pass reserve_top 0.0 got %s" % [path, slice]
		i = hit + 12
	# Every follow_cells call site must be preceded by a refresh in the same function body.
	var ref_arm := body.find("_refresh_info_block(host)")
	var fol_arm := body.find("follow_cells(host, cells, 0.0)")
	if ref_arm < 0 or fol_arm < 0 or ref_arm > fol_arm:
		return "%s arm must refresh m_info_block before follow_cells" % path
	var aim_slice_start := body.find("static func _aim")
	if aim_slice_start < 0:
		return "%s missing _aim" % path
	var aim_body := body.substr(aim_slice_start, 600)
	var ref_aim := aim_body.find("_refresh_info_block(host)")
	var fol_aim := aim_body.find("follow_cells(")
	if ref_aim < 0 or fol_aim < 0 or ref_aim > fol_aim:
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
	if inset.find("buff/heal") < 0 and inset.find("skill buff") < 0:
		return "BoardInset header must mention skill buff/heal"
	if inset.find("Skill buff/heal soft-confirm arm/_aim") < 0:
		return "BoardInset header must mention skill buff/heal refresh"
	if inset.find("clip_notch") < 0:
		return "BoardInset must still clip_notch"
	if inset.find("foe_opening_telegraph") >= 0 or inset.find("BattleLinkTelegraph") >= 0:
		return "BoardInset dragged telegraph residue"
	return ""


func _algebra_skills() -> String:
	var buff: Dictionary = GameState.get_skill(BUFF_SID)
	if str(buff.get("type", "")) != "buff":
		return "chart_rally not buff"
	var heal: Dictionary = GameState.get_skill(HEAL_SID)
	if str(heal.get("type", "")) != "support":
		return "ward_chant not support"
	if int(heal.get("heal_min", 0)) < 1:
		return "ward_chant heal_min missing"
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
	_caster_i = -1
	_ally_i = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player":
			if _caster_i < 0:
				_caster_i = i
			elif _ally_i < 0:
				_ally_i = i
	if _caster_i < 0:
		return "deploy missing player"
	if _ally_i < 0:
		var ally = CharacterFactory.make_tutorial_militia(2)
		ally.hp = maxi(1, int(ally.max_hp) - 6)
		_battle.units.append(
			{"char": ally, "pos": Vector2i(5, 3), "team": "player", "done": false, "tag": ""}
		)
		_ally_i = _battle.units.size() - 1
	_battle.units[_caster_i].pos = Vector2i(4, 3)
	_battle.units[_caster_i].done = false
	_battle.units[_ally_i].pos = Vector2i(5, 3)
	_battle.units[_ally_i].done = false
	_battle.units[_ally_i].char.hp = maxi(1, int(_battle.units[_ally_i].char.max_hp) - 8)
	for i in _battle.units.size():
		if i == _caster_i or i == _ally_i:
			continue
		if str(_battle.units[i].team) == "player" and int(_battle.units[i].char.hp) > 0:
			_battle.units[i].pos = Vector2i(10, 8)
			_battle.units[i].done = true
	_seed_skill(_battle.units[_caster_i].char, BUFF_SID)
	_seed_skill(_battle.units[_caster_i].char, HEAL_SID)
	_plain_box(Vector2i(4, 3), 4)
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
	BattleSkillBuffPreview.clear(_battle)
	BattleSkillHealPreview.clear(_battle)
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _seed_skill(c: CKCharacter, sid: String) -> void:
	if sid not in c.skills:
		c.skills.append(sid)
	c.skill_uses[sid] = 2
	c.skill_cd[sid] = 0


func _scene(tag: String) -> String:
	var err := _assert_layout(tag)
	if err != "":
		return err
	err = await _assert_buff_follow(tag)
	if err != "":
		return err
	return await _assert_heal_follow(tag)


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


func _assert_buff_follow(tag: String) -> String:
	_battle._select_player(_caster_i)
	await _settle(3)
	BattleSkillHealPreview.clear(_battle)
	# Stale the info block so refresh must rewrite it from MobileSideCol.
	_battle.set_meta("m_info_block", Rect2(0, 0, 8, 8))
	BattleSkillsUi.arm(_battle, BUFF_SID)
	if not BattleSkillBuffPreview.latched(_battle):
		return "%s: buff arm did not latch" % tag
	_finish_focus_tween()
	await _settle(2)
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: buff follow left stale m_info_block %s" % [tag, block]
	var err := _assert_frame_meta("%s buff" % tag)
	# Also cover _aim refresh path via Tab cycle.
	_battle.set_meta("m_info_block", Rect2(0, 0, 8, 8))
	var aimed := BattleSkillBuffPreview.apply_next(_battle)
	if aimed < 0:
		return "%s: buff apply_next failed" % tag
	_finish_focus_tween()
	await _settle(2)
	block = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: buff _aim left stale m_info_block %s" % [tag, block]
	err = _assert_frame_meta("%s buff aim" % tag) if err == "" else err
	BattleSkillBuffPreview.clear(_battle)
	_battle.skill_mode = false
	_battle.active_skill_id = ""
	BattlePick.cancel_focus_tween(_battle)
	return err


func _assert_heal_follow(tag: String) -> String:
	_battle._select_player(_caster_i)
	await _settle(3)
	BattleSkillBuffPreview.clear(_battle)
	_battle.set_meta("m_info_block", Rect2(0, 0, 8, 8))
	BattleSkillsUi.arm(_battle, HEAL_SID)
	if not BattleSkillHealPreview.latched(_battle):
		return "%s: heal arm did not latch" % tag
	_finish_focus_tween()
	await _settle(2)
	var block: Rect2 = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: heal follow left stale m_info_block %s" % [tag, block]
	var err := _assert_frame_meta("%s heal" % tag)
	_battle.set_meta("m_info_block", Rect2(0, 0, 8, 8))
	var aimed := BattleSkillHealPreview.apply_next(_battle)
	if aimed < 0:
		return "%s: heal apply_next failed" % tag
	_finish_focus_tween()
	await _settle(2)
	block = _battle.get_meta("m_info_block")
	if block.size.x < 40.0:
		return "%s: heal _aim left stale m_info_block %s" % [tag, block]
	err = _assert_frame_meta("%s heal aim" % tag) if err == "" else err
	BattleSkillHealPreview.clear(_battle)
	_battle.skill_mode = false
	_battle.active_skill_id = ""
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
	var banded: Rect2 = BattleBoardInset.for_host(
		_battle, BattleCombatFrame.forecast_band(DeviceProfile.is_mobile())
	)
	if (
		absf(inset.size.y - banded.size.y) < 4.0
		and absf(inset.position.y - banded.position.y) < 4.0
	):
		return "%s: follow still looks like forecast-band inset %s" % [tag, inset]
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
