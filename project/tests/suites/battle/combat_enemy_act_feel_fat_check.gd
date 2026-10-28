extends Node
## Fat knife: 敌方行动整链手感 — act→move→strike→done→回场清戳
## Dual real maps. No telegraph / EmptyHost / BoardInset-only thin cut.

const PHONE := Vector2i(2400, 1080)
const NOTCH := "400,0,0,48"
const MARKER := "COMBAT ENEMY ACT FEEL FAT PASS"

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
		print("FAIL enemy act feel fat: ", err)
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


func _algebra() -> String:
	var err := _algebra_api()
	if err == "":
		err = _algebra_wiring()
	if err == "":
		err = _algebra_no_telegraph()
	return err


func _algebra_api() -> String:
	if BattleEnemyActFeel.META != "m_enemy_act_feel":
		return "META want m_enemy_act_feel"
	var body := FileAccess.get_file_as_string("res://scripts/battle/battle_enemy_act_feel.gd")
	for fn in [
		"static func after_act_start",
		"static func after_move",
		"static func after_strike",
		"static func after_unit_done",
		"static func threat_cells",
		"static func clear",
	]:
		if body.find(fn) < 0:
			return "%s missing" % fn
	if body.find("BattleBoardInset.refresh_info_block") < 0:
		return "EnemyActFeel must refresh BoardInset"
	if body.find("BattleActionSettle.apply") < 0:
		return "EnemyActFeel must ActionSettle"
	if body.find("ActionSettle.apply(host, cell, [])") >= 0 or body.find("apply(host, stand, [])") >= 0:
		return "EnemyActFeel must not settle mover-only []"
	if body.find("BattlePhaseFeel.note_enemy_acting") < 0:
		return "after_act_start must call note_enemy_acting"
	return ""


func _algebra_wiring() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("BattleEnemyActFeel.after_act_start") < 0:
		return "controller must after_act_start"
	if ctrl.find("BattleEnemyActFeel.after_move") < 0:
		return "controller must after_move"
	if ctrl.find("BattleEnemyActFeel.after_strike") < 0:
		return "controller must after_strike"
	if ctrl.find("BattleEnemyActFeel.after_unit_done") < 0:
		return "controller must after_unit_done"
	# note_enemy_acting only via EnemyActFeel in _enemy_ai loop
	var cycle := FileAccess.get_file_as_string("res://scripts/battle/battle_turn_cycle_feel.gd")
	if cycle.find("BattleEnemyActFeel.clear") < 0:
		return "TurnCycle must clear EnemyActFeel"
	if cycle.count("BattleEnemyActFeel.clear") < 2:
		return "TurnCycle must clear EnemyAct on enemy+return"
	return ""


func _algebra_no_telegraph() -> String:
	for path in [
		"res://scripts/battle/battle_enemy_act_feel.gd",
		"res://scripts/battle/battle_turn_cycle_feel.gd",
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
	_player_i = -1
	_foe_i = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player" and _player_i < 0:
			_player_i = i
			u.pos = Vector2i(3, 3)
			u.done = true
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
			u.pos = Vector2i(5, 3)
			u.done = false
		elif str(u.team) == "player":
			u.done = true
	if _player_i < 0 or _foe_i < 0:
		return "deploy need player+foe"
	# Place foe adjacent so melee threat_cells non-empty at act start.
	_battle.units[_foe_i].pos = Vector2i(4, 3)
	_battle.selected = -1
	_battle.turn_team = "enemy"
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
	BattleEnemyActFeel.clear(_battle)
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _scene_stack(tag: String) -> String:
	var err := await _scene_act_start(tag)
	if err == "":
		err = await _scene_move(tag)
	if err == "":
		err = await _scene_strike_done(tag)
	if err == "":
		err = await _scene_return_clear(tag)
	return err


func _scene_act_start(tag: String) -> String:
	BattleEnemyActFeel.after_act_start(_battle, _foe_i)
	await _settle(3)
	if BattleEnemyActFeel.stage_of(_battle) != "act":
		return "%s: stage want act got %s" % [tag, BattleEnemyActFeel.stage_of(_battle)]
	var info = _battle.get_meta(BattleEnemyActFeel.META)
	if not (info is Dictionary):
		return "%s: act meta missing" % tag
	var foes = (info as Dictionary).get("foes", [])
	if not (foes is Array) or (foes as Array).is_empty():
		return "%s: act settle also must include player threat" % tag
	if not _battle.has_meta("m_enemy_actor_cell"):
		return "%s: note_enemy_acting must stamp enemy actor ring" % tag
	if not _battle.has_meta("m_action_settle"):
		return "%s: act must stamp ActionSettle" % tag
	var settle = _battle.get_meta("m_action_settle")
	if settle is Dictionary:
		# actor should be foe cell
		var actor = (settle as Dictionary).get("actor", Vector2i(-1, -1))
		if actor != _battle.units[_foe_i].pos:
			return "%s: settle actor want foe pos" % tag
	return ""


func _scene_move(tag: String) -> String:
	var landed := Vector2i(5, 3)
	_battle.units[_foe_i].pos = landed
	BattleEnemyActFeel.after_move(_battle, landed, _foe_i)
	await _settle(3)
	if BattleEnemyActFeel.stage_of(_battle) != "move":
		return "%s: stage want move got %s" % [tag, BattleEnemyActFeel.stage_of(_battle)]
	# After move: stamped move + ActionSettle on landed (threat also may be empty at range 2).
	if not _battle.has_meta("m_action_settle"):
		return "%s: move must stamp ActionSettle" % tag
	var settle = _battle.get_meta("m_action_settle")
	if settle is Dictionary and (settle as Dictionary).get("actor", Vector2i(-1, -1)) != landed:
		return "%s: move settle actor want landed" % tag
	# Pull back adjacent for strike scene
	_battle.units[_foe_i].pos = Vector2i(4, 3)
	return ""


func _scene_strike_done(tag: String) -> String:
	var actor: Vector2i = _battle.units[_foe_i].pos
	var target: Vector2i = _battle.units[_player_i].pos
	BattleEnemyActFeel.after_strike(_battle, actor, target, _foe_i)
	await _settle(2)
	if BattleEnemyActFeel.stage_of(_battle) != "strike":
		return "%s: stage want strike got %s" % [tag, BattleEnemyActFeel.stage_of(_battle)]
	BattleEnemyActFeel.after_unit_done(_battle, _foe_i)
	await _settle(2)
	if BattleEnemyActFeel.stage_of(_battle) != "done":
		return "%s: stage want done got %s" % [tag, BattleEnemyActFeel.stage_of(_battle)]
	return ""


func _scene_return_clear(tag: String) -> String:
	# Simulate player return clearing EnemyAct via TurnCycle.
	_battle.turn_team = "player"
	BattleTurnCycleFeel.after_player_return(_battle)
	await _settle(2)
	if BattleEnemyActFeel.stage_of(_battle) != "":
		return "%s: EnemyAct must clear on return got %s" % [
			tag, BattleEnemyActFeel.stage_of(_battle)
		]
	if BattleTurnCycleFeel.stage_of(_battle) != "return":
		return "%s: cycle stage want return got %s" % [
			tag, BattleTurnCycleFeel.stage_of(_battle)
		]
	# before_enemy also clears leftover
	_battle.set_meta(BattleEnemyActFeel.META, {"stage": "done", "msec": 1})
	BattleTurnCycleFeel.before_enemy_phase(_battle)
	if BattleEnemyActFeel.stage_of(_battle) != "":
		return "%s: EnemyAct must clear on enemy phase" % tag
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
