extends Node
## Fat knife: mobile buff-art preview ↔ confirm/cancel ↔ Tab cycle
## across two real battle maps. No telegraph residue. Algebra first, then
## Scene A (ch0_pass) + Scene B (ch1_hill). Quits 1 on miss.

const PHONE := Vector2i(2400, 1080)
const SID := "chart_rally"

var _battle: Control
var _caster_i := -1
var _ally_i := -1
var _foe_i := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL skill/buff feel fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT SKILL BUFF FEEL FAT PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra()
	if err != "":
		return err
	err = await _boot("ch0_pass")
	if err == "":
		err = await _scene_a_arm_cancel_confirm()
	await _free_battle()
	if err != "":
		return err
	err = await _boot("ch1_hill")
	if err == "":
		err = await _scene_b_tab_cycle_frame()
	await _free_battle()
	return err


func _algebra() -> String:
	var err := _algebra_buffable()
	if err == "":
		err = _algebra_locale()
	if err == "":
		err = _algebra_source()
	return err


func _algebra_buffable() -> String:
	if BattleSkillBuffPreview.META != "m_skill_buff_preview":
		return "META want m_skill_buff_preview"
	var sk: Dictionary = GameState.get_skill(SID)
	if str(sk.get("type", "")) != "buff":
		return "chart_rally not buff"
	if int(sk.get("party_def_buff", 0)) < 1:
		return "chart_rally party_def_buff missing"
	return ""



func _algebra_locale() -> String:
	for key in ["ux_buff_preview_armed", "ux_confirm_buff", "ux_confirm_dest_buff"]:
		if Locale.t(key) == key:
			return "locale %s missing" % key
	return ""


func _algebra_source() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var skills := FileAccess.get_file_as_string("res://scripts/battle/battle_skills_ui.gd")
	var touch := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	var bar := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_mobile_bar.gd")
	var aff := FileAccess.get_file_as_string("res://scripts/battle/battle_confirm_affordance.gd")
	var need := {
		"BattleSkillBuffPreview.draw(self, overlay)": ctrl,
		"BattleSkillBuffPreview.latched(self)": ctrl,
		"BattleSkillBuffPreview.arm(host, sid)": skills,
		"BattleSkillBuffPreview.clear(host)": touch,
		"_rebuild_buff_confirm": bar,
		"BattleSkillBuffPreview.latched(host)": aff,
	}
	for needle in need:
		if str(need[needle]).find(str(needle)) < 0:
			return "missing wire: %s" % needle
	for path in [
		"res://scripts/battle/battle_skill_buff_preview.gd",
		"res://scripts/battle/battle_skills_ui.gd",
		"res://scripts/battle/battle_controller.gd",
	]:
		var body := FileAccess.get_file_as_string(path)
		if body.find("EmptyHost") >= 0:
			return "%s EmptyHost theater" % path
		# Do not revive telegraph fragment knives in this fat.
		if path.ends_with("battle_skill_buff_preview.gd") and (body.find("telegraph") >= 0 or body.find("Telegraph") >= 0):
			return "%s dragged telegraph residue" % path
	return ""


func _boot(map_id: String) -> String:
	await _set_window()
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
	var insets := {"left": 48.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
	var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
	MobileLayout.apply_root(_battle, fitted)
	_battle.set_meta("mobile_insets", insets)
	if _battle.has_method("apply_mobile_layout"):
		_battle.apply_mobile_layout()
	await _settle(8)
	if str(_battle.map_id) != map_id:
		return "map_id want %s got %s" % [map_id, _battle.map_id]
	if not _battle._mobile_landscape():
		return "battle did not enter landscape on %s" % map_id
	if not BattleTouchConfirm.enabled():
		return "touch_confirm not enabled on mobile"
	if not BattleSkillBuffPreview.wants_soft_confirm():
		return "soft buff confirm policy off"
	return _arrange()


func _arrange() -> String:
	_caster_i = -1
	_ally_i = -1
	_foe_i = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player":
			if _caster_i < 0:
				_caster_i = i
			elif _ally_i < 0:
				_ally_i = i
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
	if _caster_i < 0:
		return "deploy missing player"
	# Ensure a second ally in heal range for Tab cycle.
	if _ally_i < 0:
		var ally = CharacterFactory.make_tutorial_militia(2)
		ally.hp = maxi(1, int(ally.max_hp) - 6)
		_battle.units.append({"char": ally, "pos": Vector2i(3, 2), "team": "player", "done": false, "tag": ""})
		_ally_i = _battle.units.size() - 1
	_battle.units[_caster_i].pos = Vector2i(2, 2)
	_battle.units[_caster_i].done = false
	_battle.units[_ally_i].pos = Vector2i(3, 2)
	_battle.units[_ally_i].done = false
	# Park other living players far so focus_nearest picks ally.
	for i in _battle.units.size():
		if i == _caster_i or i == _ally_i:
			continue
		if str(_battle.units[i].team) == "player" and int(_battle.units[i].char.hp) > 0:
			_battle.units[i].pos = Vector2i(10, 8)
	_seed_buff(_battle.units[_caster_i].char)
	if _foe_i >= 0:
		_battle.units[_foe_i].pos = Vector2i(6, 2)
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
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _seed_buff(c: CKCharacter) -> void:
	if SID not in c.skills:
		c.skills.append(SID)
	c.skill_uses[SID] = 2
	c.skill_cd[SID] = 0


func _scene_a_arm_cancel_confirm() -> String:
	_battle._select_player(_caster_i)
	await _settle(3)
	var err := _scene_a_arm_and_cancel()
	if err != "":
		return err
	return await _scene_a_confirm()


func _scene_a_arm_and_cancel() -> String:
	var uses0 := int(_battle.units[_caster_i].char.skill_uses.get(SID, 0))
	if uses0 < 1:
		return "scene A: no uses after seed"
	BattleSkillsUi.arm(_battle, SID)
	if not BattleSkillBuffPreview.latched(_battle):
		return "scene A: arm did not latch buff preview"
	if not bool(_battle.skill_mode) or str(_battle.active_skill_id) != SID:
		return "scene A: skill_mode/id miss after arm"
	if int(_battle.units[_caster_i].char.skill_uses.get(SID, 0)) != uses0:
		return "scene A: arm consumed uses early"
	var idxs: Array[int] = BattleSkillBuffPreview.buffable_indices(_battle)
	if not idxs.has(_caster_i) or not idxs.has(_ally_i):
		return "scene A: healable miss caster/ally got %s" % idxs
	var focus0 := BattleSkillBuffPreview.preview_ui(_battle)
	if focus0 != _ally_i and focus0 == _caster_i:
		return "scene A: focus stuck on caster"
	if focus0 < 0:
		return "scene A: focus missing"
	if not _battle.has_meta(BattleSkillBuffPreview.META):
		return "scene A: missing buff meta after arm"
	var kind := BattleAttackCancelDepth.step(_battle)
	if kind != "preview":
		return "scene A: cancel want preview got %s" % kind
	if BattleSkillBuffPreview.latched(_battle):
		return "scene A: cancel left latch"
	if int(_battle.units[_caster_i].char.skill_uses.get(SID, 0)) != uses0:
		return "scene A: cancel burned uses"
	return ""


func _scene_a_confirm() -> String:
	var uses0 := int(_battle.units[_caster_i].char.skill_uses.get(SID, 0))
	BattleSkillsUi.arm(_battle, SID)
	if not BattleSkillBuffPreview.latched(_battle):
		return "scene A: re-arm miss"
	var def0 := int(_battle.units[_ally_i].char.temp_def_buff)
	if not BattleSkillBuffPreview.confirm(_battle):
		return "scene A: confirm failed"
	if BattleSkillBuffPreview.latched(_battle):
		return "scene A: confirm left latch"
	if int(_battle.units[_caster_i].char.skill_uses.get(SID, 0)) != uses0 - 1:
		return "scene A: confirm did not consume use"
	if int(_battle.units[_ally_i].char.temp_def_buff) < def0 + 3:
		return "scene A: confirm did not apply party buff got %s" % _battle.units[_ally_i].char.temp_def_buff
	return ""


func _scene_b_tab_cycle_frame() -> String:
	_battle._select_player(_caster_i)
	await _settle(3)
	_park_offscreen(_battle.units[_ally_i].pos, 140.0)
	var err := _scene_b_cycle()
	if err != "":
		return err
	return await _scene_b_bar_confirm()


func _scene_b_cycle() -> String:
	BattleSkillsUi.arm(_battle, SID)
	if not BattleSkillBuffPreview.latched(_battle):
		return "scene B: arm miss"
	var before: Vector2 = _battle._board_pan
	var idxs: Array[int] = BattleSkillBuffPreview.buffable_indices(_battle)
	if idxs.size() < 2:
		return "scene B: need ≥2 healable got %s" % idxs
	var first: int = BattleSkillBuffPreview.apply_next(_battle)
	if first < 0 or int(BattleSkillBuffPreview.preview_ui(_battle)) != first:
		return "scene B: apply_next did not seed focus"
	var second: int = BattleSkillBuffPreview.apply_next(_battle)
	if second == first and idxs.size() >= 2:
		return "scene B: next did not advance"
	var back: int = BattleSkillBuffPreview.apply_prev(_battle)
	if back != first:
		return "scene B: prev want %s got %s" % [first, back]
	var after: Vector2 = _battle._board_pan
	if after == before and not _battle.has_meta("m_combat_frame"):
		return "scene B: no camera frame after cycle"
	return ""


func _scene_b_bar_confirm() -> String:
	BattleMobileBar.rebuild(_battle)
	var bar = _battle.get("_mobile_bar")
	if bar == null:
		return "scene B: mobile bar missing"
	if _find_named(bar, "ConfirmPrimary") == null:
		return "scene B: buff ConfirmPrimary missing"
	if not BattleConfirmAffordance.preview_latched(_battle):
		return "scene B: affordance not latched"
	var uses0 := int(_battle.units[_caster_i].char.skill_uses.get(SID, 0))
	BattleSkillBuffPreview.confirm(_battle)
	if BattleSkillBuffPreview.latched(_battle):
		return "scene B: confirm left latch"
	if int(_battle.units[_caster_i].char.skill_uses.get(SID, 0)) != uses0 - 1:
		return "scene B: confirm did not consume"
	return ""


func _park_offscreen(cell: Vector2i, pad: float) -> void:
	var stage: Rect2 = BattlePick._stage_rect(_battle)
	if stage.size.x < 8.0:
		return
	var origin: Vector2 = _battle.ORIGIN
	var zoom := float(_battle._board_zoom)
	var cell_px: float = float(_battle.CELL) * zoom
	var pan: Vector2 = _battle._board_pan
	var shown_x: float = origin.x * zoom + float(cell.x) * cell_px + pan.x
	var need: float = stage.end.x + pad - shown_x
	_battle._board_pan = Vector2(pan.x + need, pan.y)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	if _battle.has_method("_apply_board_xform"):
		_battle._apply_board_xform()
	BattlePick.cancel_focus_tween(_battle)


func _find_named(root: Node, name: String) -> Node:
	if root == null:
		return null
	if root.name == name:
		return root
	for c in root.get_children():
		var hit := _find_named(c, name)
		if hit != null:
			return hit
	return null


func _set_window() -> void:
	# Disable content-scale so visible_rect tracks PHONE for _mobile_landscape.
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	DisplayServer.window_set_size(PHONE)
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
