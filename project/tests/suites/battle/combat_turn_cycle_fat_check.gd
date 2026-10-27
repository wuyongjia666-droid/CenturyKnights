extends Node
## 回合整链手感 fat: handoff → end turn → enemy → player return.
## Dual real maps (ch0_pass + ch1_hill). No telegraph / EmptyHost / BoardInset-only thin cut.

const PHONE := Vector2i(2400, 1080)
const NOTCH := "400,0,0,48"
const MARKER := "COMBAT TURN CYCLE FAT PASS"

var _battle: Control
var _p0 := -1
var _p1 := -1
var _foe := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	OS.set_environment("CK_SAFE_INSETS", NOTCH)
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL turn-cycle fat: ", err)
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
	var err := _algebra_api()
	if err == "":
		err = _algebra_wait_wiring()
	if err == "":
		err = _algebra_bridge_wiring()
	if err == "":
		err = _algebra_controller_wiring()
	if err == "":
		err = _algebra_no_telegraph()
	return err


func _algebra_api() -> String:
	var body := FileAccess.get_file_as_string("res://scripts/battle/battle_turn_cycle_feel.gd")
	if body.find("class_name BattleTurnCycleFeel") < 0:
		return "BattleTurnCycleFeel missing"
	for fn in [
		"static func before_handoff",
		"static func after_handoff",
		"static func before_enemy_phase",
		"static func after_player_return",
		"static func clear_peek_chrome",
	]:
		if body.find(fn) < 0:
			return "%s missing" % fn
	if body.find("BattleLandStrike.clear") < 0:
		return "must clear LandStrike"
	if body.find("BattleAttackAim.clear") < 0:
		return "must clear AttackAim"
	if body.find("BattleFeelLoop.clear") < 0:
		return "before_enemy_phase must clear FeelLoop"
	return ""


func _algebra_wait_wiring() -> String:
	var wait := FileAccess.get_file_as_string("res://scripts/battle/battle_wait_handoff.gd")
	if wait.find("BattleTurnCycleFeel.before_handoff") < 0:
		return "WaitHandoff must call before_handoff"
	if wait.find("BattleTurnCycleFeel.after_handoff") < 0:
		return "WaitHandoff must call after_handoff"
	var fn := wait.find("static func after_unit_done")
	if fn < 0:
		return "WaitHandoff.after_unit_done missing"
	var body := wait.substr(fn, 900)
	var before_at := body.find("BattleTurnCycleFeel.before_handoff")
	var select_at := body.find("_select_player")
	if before_at < 0 or select_at < 0 or before_at > select_at:
		return "before_handoff must run before _select_player"
	return ""


func _algebra_bridge_wiring() -> String:
	var bridge := FileAccess.get_file_as_string("res://scripts/battle/battle_turn_bridge.gd")
	if bridge.find("BattleTurnCycleFeel.after_player_return") < 0:
		return "TurnBridge.note_player_return must stamp after_player_return"
	return ""


func _algebra_controller_wiring() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("BattleTurnCycleFeel.before_enemy_phase") < 0:
		return "_end_player_turn must call before_enemy_phase"
	var end_at := ctrl.find("func _end_player_turn")
	if end_at < 0:
		return "_end_player_turn missing"
	var chunk := ctrl.substr(end_at, 700)
	var clear_at := chunk.find("BattleTurnCycleFeel.before_enemy_phase")
	var enemy_at := chunk.find('turn_team = "enemy"')
	if clear_at < 0 or enemy_at < 0 or clear_at > enemy_at:
		return "before_enemy_phase must run before turn_team=enemy"
	return ""


func _algebra_no_telegraph() -> String:
	var body := FileAccess.get_file_as_string("res://scripts/battle/battle_turn_cycle_feel.gd")
	var live := ""
	for line in body.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("##") or s.begins_with("#"):
			continue
		live += line + "\n"
	if (
		live.find("foe_opening_telegraph") >= 0
		or live.find("BattleLinkTelegraph") >= 0
		or live.find("BattleFoeOpeningTelegraph") >= 0
		or live.find("EmptyHost") >= 0
	):
		return "battle_turn_cycle_feel.gd dragged telegraph/EmptyHost residue"
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
	_p0 = -1
	_p1 = -1
	_foe = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player":
			if _p0 < 0:
				_p0 = i
				u.pos = Vector2i(3, 3)
				u.done = false
			elif _p1 < 0:
				_p1 = i
				u.pos = Vector2i(2, 3)
				u.done = false
			else:
				u.done = true
		elif str(u.team) == "enemy" and _foe < 0:
			_foe = i
			u.pos = Vector2i(5, 3)
			u.char.hp = maxi(int(u.char.hp), 12)
	if _p0 < 0 or _p1 < 0 or _foe < 0:
		return "deploy need 2 players + 1 enemy"
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	_battle.attack_mode = false
	_battle.skill_mode = false
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle.moved_this_select = false
	# Round >1 so note_player_return auto-selects.
	_battle._round_no = 2
	BattlePick.cancel_focus_tween(_battle)
	BattleLandStrike.clear(_battle)
	BattleAttackAim.clear(_battle)
	BattleFeelLoop.clear(_battle)
	BattleTurnCycleFeel.clear(_battle)
	if _battle.has_meta(BattleWaitHandoff.META):
		_battle.remove_meta(BattleWaitHandoff.META)
	return ""


func _scene(tag: String) -> String:
	var err := await _scene_move_land(tag)
	if err == "":
		err = await _scene_handoff(tag)
	if err == "":
		err = await _scene_enemy_phase(tag)
	if err == "":
		err = await _scene_player_return(tag)
	return err


func _scene_move_land(tag: String) -> String:
	_battle._select_player(_p0)
	await _settle(4)
	if BattleFeelLoop.stage_of(_battle) != "select":
		return "%s: select stage want select got %s" % [tag, BattleFeelLoop.stage_of(_battle)]
	var dest := Vector2i(4, 3)
	_battle.preview_move_cell = dest
	_battle.preview_attack_ui = -1
	_battle.units[_foe].pos = Vector2i(5, 3)
	_battle.units[_p0].pos = Vector2i(3, 3)
	BattleTouchConfirm.confirm_move(_battle)
	await _settle(4)
	if BattleFeelLoop.stage_of(_battle) != "move":
		return "%s: after move stage want move got %s" % [tag, BattleFeelLoop.stage_of(_battle)]
	if not _battle.has_meta(BattleLandStrike.META) and not BattleLandStrike.active(_battle):
		# Land peek may be inactive if foe out of reach after land; force stamp for handoff test.
		_battle.set_meta(BattleLandStrike.META, {
			"stand": dest,
			"foes": [Vector2i(5, 3)],
			"msec": Time.get_ticks_msec(),
		})
	if not _battle.has_meta(BattleLandStrike.META):
		return "%s: need land-strike META before handoff seam" % tag
	return ""


func _scene_handoff(tag: String) -> String:
	# Mimic wait: mark done, clear select, hand off.
	_battle.units[_p0].done = true
	var from_i: int = _p0
	_battle.selected = -1
	_battle.move_cells.clear()
	_battle.attack_mode = false
	_battle.moved_this_select = false
	BattleTurnBridge.after_unit_done(_battle)
	var nxt: int = BattleWaitHandoff.after_unit_done(_battle, from_i)
	await _settle(4)
	if nxt != _p1:
		return "%s: handoff want p1=%d got %d" % [tag, _p1, nxt]
	if _battle.has_meta(BattleLandStrike.META):
		return "%s: land-strike META must clear on handoff" % tag
	if BattleTurnCycleFeel.stage_of(_battle) != "handoff":
		return "%s: cycle stage want handoff got %s" % [tag, BattleTurnCycleFeel.stage_of(_battle)]
	var info = _battle.get_meta(BattleTurnCycleFeel.META)
	if not (info is Dictionary) or int((info as Dictionary).get("to", -1)) != _p1:
		return "%s: handoff stamp to mismatch" % tag
	if BattleFeelLoop.stage_of(_battle) != "select":
		return "%s: after handoff FeelLoop want select got %s" % [
			tag, BattleFeelLoop.stage_of(_battle)
		]
	if int(_battle.selected) != _p1:
		return "%s: selected want p1 got %d" % [tag, int(_battle.selected)]
	return ""


func _scene_enemy_phase(tag: String) -> String:
	# Leave a fake aim META to prove before_enemy_phase clears it.
	_battle.set_meta(BattleAttackAim.META, {
		"stand": Vector2i(2, 3),
		"foes": [],
		"nearest": -1,
		"msec": Time.get_ticks_msec(),
	})
	_battle.set_meta(BattleFeelLoop.META, {"stage": "select", "msec": Time.get_ticks_msec()})
	BattleTurnCycleFeel.before_enemy_phase(_battle)
	_battle.turn_team = "enemy"
	await _settle(2)
	if _battle.has_meta(BattleAttackAim.META):
		return "%s: AttackAim must clear on enemy phase" % tag
	if _battle.has_meta(BattleLandStrike.META):
		return "%s: LandStrike must clear on enemy phase" % tag
	if _battle.has_meta(BattleFeelLoop.META):
		return "%s: FeelLoop must clear on enemy phase" % tag
	if _battle.has_meta(BattleWaitHandoff.META):
		return "%s: WaitHandoff META must clear on enemy phase" % tag
	if BattleTurnCycleFeel.stage_of(_battle) != "enemy":
		return "%s: cycle stage want enemy got %s" % [tag, BattleTurnCycleFeel.stage_of(_battle)]
	return ""


func _scene_player_return(tag: String) -> String:
	# Reset done flags like _start_player_turn, then bridge return.
	for u in _battle.units:
		if str(u.team) == "player":
			u.done = false
	_battle.turn_team = "player"
	_battle.selected = -1
	_battle._round_no = 3
	# Leave stale peek to prove after_player_return clears.
	_battle.set_meta(BattleLandStrike.META, {
		"stand": Vector2i(4, 3),
		"foes": [Vector2i(5, 3)],
		"msec": Time.get_ticks_msec(),
	})
	BattleTurnBridge.note_player_return(_battle)
	await _settle(4)
	if BattleTurnCycleFeel.stage_of(_battle) != "return":
		return "%s: cycle stage want return got %s" % [tag, BattleTurnCycleFeel.stage_of(_battle)]
	if _battle.has_meta(BattleLandStrike.META):
		return "%s: land peek must clear on player return" % tag
	if int(_battle.selected) < 0:
		return "%s: player return should auto-select a ready unit" % tag
	if BattleFeelLoop.stage_of(_battle) != "select":
		return "%s: return select should stamp FeelLoop select got %s" % [
			tag, BattleFeelLoop.stage_of(_battle)
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
