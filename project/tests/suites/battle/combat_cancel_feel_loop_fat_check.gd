extends Node
## Fat knife: 取消整链手感 — preview→mode→select→敌方清戳
## Dual real maps. No telegraph / EmptyHost / BoardInset-only thin cut.

const PHONE := Vector2i(2400, 1080)
const NOTCH := "400,0,0,48"
const MARKER := "COMBAT CANCEL FEEL LOOP FAT PASS"
const BUFF_SID := "chart_rally"

var _battle: Control
var _caster_i := -1
var _ally_i := -1
var _foe_i := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL cancel feel loop fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra()
	if err != "":
		return err
	err = await _boot("ch0_pass")
	if err == "":
		err = await _scene_stack("A")
	await _free_battle()
	if err != "":
		return err
	err = await _boot("ch1_hill")
	if err == "":
		err = await _scene_stack("B")
	await _free_battle()
	return err


## Split for gdlint max-returns.
func _algebra() -> String:
	var err := _algebra_api()
	if err == "":
		err = _algebra_wiring()
	if err == "":
		err = _algebra_no_telegraph()
	return err


func _algebra_api() -> String:
	if BattleCancelFeelLoop.META != "m_cancel_feel":
		return "META want m_cancel_feel"
	var body := FileAccess.get_file_as_string("res://scripts/battle/battle_cancel_feel_loop.gd")
	for fn in [
		"static func after_preview",
		"static func after_mode",
		"static func after_select",
		"static func clear",
	]:
		if body.find(fn) < 0:
			return "%s missing" % fn
	if body.find("BattleBoardInset.refresh_info_block") < 0:
		return "CancelFeel must refresh BoardInset"
	if body.find("BattleFeelLoop.clear") < 0:
		return "after_select must clear FeelLoop"
	return ""


func _algebra_wiring() -> String:
	var depth := FileAccess.get_file_as_string("res://scripts/battle/battle_attack_cancel_depth.gd")
	if depth.find("BattleCancelFeelLoop.after_preview") < 0:
		return "CancelDepth preview must stamp CancelFeel"
	if depth.find("BattleCancelFeelLoop.after_mode") < 0:
		return "CancelDepth mode must stamp CancelFeel"
	if depth.find("BattleCancelFeelLoop.after_select") < 0:
		return "CancelDepth select must stamp CancelFeel"
	if depth.find("BattleBoardInset.refresh_info_block") < 0:
		return "CancelDepth mode exit must refresh BoardInset"
	var cycle := FileAccess.get_file_as_string("res://scripts/battle/battle_turn_cycle_feel.gd")
	if cycle.find("BattleCancelFeelLoop.clear") < 0:
		return "TurnCycle before_enemy must clear CancelFeel"
	return ""


func _algebra_no_telegraph() -> String:
	for path in [
		"res://scripts/battle/battle_cancel_feel_loop.gd",
		"res://scripts/battle/battle_attack_cancel_depth.gd",
	]:
		var body := FileAccess.get_file_as_string(path)
		var live := ""
		for line in body.split("\n"):
			var s := line.strip_edges()
			if s.begins_with("#"):
				continue
			live += line + "\n"
		if (
			live.find("foe_opening_telegraph") >= 0
			or live.find("BattleLinkTelegraph") >= 0
			or live.find("BattleFoeOpeningTelegraph") >= 0
			or live.find("EmptyHost") >= 0
		):
			return "%s dragged telegraph/EmptyHost residue" % path
	return ""


func _boot(map_id: String) -> String:
	await _set_window()
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
				u.pos = Vector2i(3, 3)
				u.done = false
			elif _ally_i < 0:
				_ally_i = i
				u.pos = Vector2i(2, 3)
				u.done = false
			else:
				u.done = true
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
			u.pos = Vector2i(6, 3)
	if _caster_i < 0 or _ally_i < 0 or _foe_i < 0:
		return "deploy need caster+ally+foe"
	_seed_buff(_battle.units[_caster_i].char)
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
	_battle._round_no = 2
	BattleSkillBuffPreview.clear(_battle)
	BattleSkillHealPreview.clear(_battle)
	BattleSkillFeelLoop.clear(_battle)
	BattleFeelLoop.clear(_battle)
	BattleCancelFeelLoop.clear(_battle)
	BattleTurnCycleFeel.clear(_battle)
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _seed_buff(c: CKCharacter) -> void:
	if BUFF_SID not in c.skills:
		c.skills.append(BUFF_SID)
	c.skill_uses[BUFF_SID] = 2
	c.skill_cd[BUFF_SID] = 0


## Split for gdlint max-returns.
func _scene_stack(tag: String) -> String:
	var err := await _scene_preview_cancel(tag)
	if err == "":
		err = await _scene_mode_cancel(tag)
	if err == "":
		err = await _scene_select_enemy_clear(tag)
	return err


func _scene_preview_cancel(tag: String) -> String:
	_battle._select_player(_caster_i)
	await _settle(3)
	BattleSkillsUi.arm(_battle, BUFF_SID)
	if not BattleSkillBuffPreview.latched(_battle):
		return "%s: buff arm did not latch" % tag
	if BattleSkillFeelLoop.stage_of(_battle) != "arm":
		return "%s: skill feel want arm got %s" % [tag, BattleSkillFeelLoop.stage_of(_battle)]
	var kind := BattleAttackCancelDepth.step(_battle)
	if kind != "preview":
		return "%s: cancel want preview got %s" % [tag, kind]
	if BattleSkillBuffPreview.latched(_battle):
		return "%s: preview cancel left buff latch" % tag
	if BattleSkillFeelLoop.stage_of(_battle) != "":
		return "%s: preview cancel must clear SkillFeel got %s" % [
			tag, BattleSkillFeelLoop.stage_of(_battle)
		]
	if BattleCancelFeelLoop.stage_of(_battle) != "preview":
		return "%s: CancelFeel want preview got %s" % [
			tag, BattleCancelFeelLoop.stage_of(_battle)
		]
	if not bool(_battle.skill_mode):
		return "%s: preview cancel must keep skill_mode" % tag
	return ""


func _scene_mode_cancel(tag: String) -> String:
	# skill_mode still on from preview cancel; next step exits mode.
	if not bool(_battle.skill_mode):
		_battle.skill_mode = true
		_battle.active_skill_id = BUFF_SID
	var kind := BattleAttackCancelDepth.step(_battle)
	if kind != "mode":
		return "%s: cancel want mode got %s" % [tag, kind]
	if bool(_battle.skill_mode) or bool(_battle.attack_mode):
		return "%s: mode cancel left attack/skill mode" % tag
	if BattleCancelFeelLoop.stage_of(_battle) != "mode":
		return "%s: CancelFeel want mode got %s" % [tag, BattleCancelFeelLoop.stage_of(_battle)]
	if int(_battle.selected) != _caster_i:
		return "%s: mode cancel must keep selection" % tag
	return ""


func _scene_select_enemy_clear(tag: String) -> String:
	# Plant FeelLoop residue so after_select clears it.
	_battle.set_meta(BattleFeelLoop.META, {"stage": "select", "msec": Time.get_ticks_msec()})
	var kind := BattleAttackCancelDepth.step(_battle)
	if kind != "select":
		return "%s: cancel want select got %s" % [tag, kind]
	if int(_battle.selected) >= 0:
		return "%s: select cancel must deselect" % tag
	if BattleCancelFeelLoop.stage_of(_battle) != "select":
		return "%s: CancelFeel want select got %s" % [
			tag, BattleCancelFeelLoop.stage_of(_battle)
		]
	if _battle.has_meta(BattleFeelLoop.META):
		return "%s: select cancel must clear FeelLoop" % tag
	BattleTurnCycleFeel.before_enemy_phase(_battle)
	if BattleCancelFeelLoop.stage_of(_battle) != "":
		return "%s: CancelFeel must clear on enemy got %s" % [
			tag, BattleCancelFeelLoop.stage_of(_battle)
		]
	if BattleTurnCycleFeel.stage_of(_battle) != "enemy":
		return "%s: cycle stage want enemy got %s" % [
			tag, BattleTurnCycleFeel.stage_of(_battle)
		]
	return ""


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
	await _settle(2)


func _set_window() -> void:
	DisplayServer.window_set_size(PHONE)
	await _settle(2)


func _settle(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
