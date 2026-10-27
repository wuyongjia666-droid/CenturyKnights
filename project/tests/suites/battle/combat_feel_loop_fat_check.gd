extends Node
## 战棋手感整块 fat: select → move → attack → info → camera one closed loop.
## Dual real maps (ch0_pass + ch1_hill). No telegraph / EmptyHost / BoardInset-only thin cut.

const PHONE := Vector2i(2400, 1080)
const NOTCH := "400,0,0,48"
const MARKER := "COMBAT FEEL LOOP FAT PASS"

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
		print("FAIL feel-loop fat: ", err)
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
	var err := _algebra_feel_api()
	if err == "":
		err = _algebra_confirm_wiring()
	if err == "":
		err = _algebra_controller_wiring()
	if err == "":
		err = _algebra_no_telegraph()
	if err == "":
		err = _algebra_move_hands_foes()
	return err


func _algebra_feel_api() -> String:
	var loop := FileAccess.get_file_as_string("res://scripts/battle/battle_feel_loop.gd")
	if loop.find("class_name BattleFeelLoop") < 0:
		return "BattleFeelLoop missing"
	if loop.find("static func after_select") < 0:
		return "after_select missing"
	if loop.find("static func after_move") < 0:
		return "after_move missing"
	if loop.find("static func after_attack_enter") < 0:
		return "after_attack_enter missing"
	if loop.find("static func after_attack_confirm") < 0:
		return "after_attack_confirm missing"
	if loop.find("BattleLandStrike.after_land") < 0:
		return "after_move must call LandStrike.after_land"
	if loop.find("threatened_cells") < 0:
		return "after_move must gather threatened_cells for settle also"
	return ""


func _algebra_confirm_wiring() -> String:
	var touch := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if touch.find("BattleFeelLoop.after_move") < 0:
		return "confirm_move must hand to FeelLoop.after_move"
	if touch.find("BattleFeelLoop.after_attack_confirm") < 0:
		return "confirm_attack must hand to FeelLoop.after_attack_confirm"
	var cm := touch.find("static func confirm_move")
	var ca := touch.find("static func confirm_attack")
	if cm < 0 or ca < 0 or ca <= cm:
		return "confirm_move/attack order broken"
	var cm_body := touch.substr(cm, ca - cm)
	if cm_body.find("settle_camera(host, cell, [])") >= 0:
		return "confirm_move still settles mover-only [] — FeelLoop owns also=foes"
	if cm_body.find("BattleLandStrike.after_land") >= 0 and cm_body.find("BattleFeelLoop.after_move") < 0:
		return "confirm_move must not call LandStrike outside FeelLoop"
	return ""


func _algebra_controller_wiring() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("BattleFeelLoop.after_select") < 0:
		return "select must stamp FeelLoop.after_select"
	if ctrl.find("BattleFeelLoop.after_attack_enter") < 0:
		return "enter attack must stamp FeelLoop.after_attack_enter"
	return ""


func _algebra_no_telegraph() -> String:
	# FeelLoop must not grow telegraph / EmptyHost. Pre-existing clear/refresh
	# in touch_confirm chrome is out of this knife's scope.
	var body := FileAccess.get_file_as_string("res://scripts/battle/battle_feel_loop.gd")
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
		return "battle_feel_loop.gd dragged telegraph/EmptyHost residue"
	return ""


func _algebra_move_hands_foes() -> String:
	var loop := FileAccess.get_file_as_string("res://scripts/battle/battle_feel_loop.gd")
	var am := loop.find("static func after_move")
	if am < 0:
		return "after_move missing for also-contract"
	var am_end := loop.find("static func after_attack_enter", am)
	if am_end < 0:
		am_end = am + 1200
	var body := loop.substr(am, am_end - am)
	if body.find("settle_camera(host, landed, also)") < 0:
		return "after_move must settle_camera(..., also) with foes"
	if body.find("ActionSettle.apply(host, landed, also)") < 0:
		return "after_move desktop path must ActionSettle.apply(..., also)"
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
			u.done = false
		elif str(u.team) == "enemy" and _foe_i < 0:
			_foe_i = i
			u.pos = Vector2i(5, 3)
			u.char.hp = maxi(int(u.char.hp), 12)
		elif str(u.team) == "player":
			u.done = true
	if _player_i < 0 or _foe_i < 0:
		return "deploy missing player/enemy"
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
	BattleLandStrike.clear(_battle)
	BattleAttackAim.clear(_battle)
	BattleFeelLoop.clear(_battle)
	return ""


func _scene(tag: String) -> String:
	var err := await _scene_select(tag)
	if err == "":
		err = await _scene_move(tag)
	if err == "":
		err = await _scene_attack_enter(tag)
	if err == "":
		err = await _scene_attack_confirm(tag)
	return err


func _scene_select(tag: String) -> String:
	_battle._select_player(_player_i)
	await _settle(4)
	if BattleFeelLoop.stage_of(_battle) != "select":
		return "%s: after select stage want select got %s" % [tag, BattleFeelLoop.stage_of(_battle)]
	if not _battle.has_meta("m_info_block"):
		var col := _battle.get_node_or_null("MobileSideCol")
		if col == null:
			col = _battle.find_child("MobileSideCol", true, false)
		if col != null and (col as Control).size.x > 1.0:
			return "%s: select must refresh m_info_block" % tag
	return ""


func _scene_move(tag: String) -> String:
	var dest := Vector2i(4, 3)
	_battle.preview_move_cell = dest
	_battle.preview_attack_ui = -1
	_battle.units[_foe_i].pos = Vector2i(5, 3)
	_battle.units[_player_i].pos = Vector2i(3, 3)
	BattleTouchConfirm.confirm_move(_battle)
	await _settle(4)
	if BattleFeelLoop.stage_of(_battle) != "move":
		return "%s: after move stage want move got %s" % [tag, BattleFeelLoop.stage_of(_battle)]
	var loop_info = _battle.get_meta(BattleFeelLoop.META)
	if not (loop_info is Dictionary):
		return "%s: m_feel_loop missing after move" % tag
	var foes: Array = (loop_info as Dictionary).get("foes", [])
	if foes.is_empty() and BattleLandStrike.active(_battle):
		return "%s: land peek active but FeelLoop foes empty" % tag
	if not foes.is_empty():
		if not _battle.has_meta(BattleLandStrike.META) and not BattleLandStrike.active(_battle):
			return "%s: move with foes must keep land-strike peek" % tag
		if not _battle.has_meta("m_confirm_settle") and not _battle.has_meta("m_action_settle"):
			return "%s: move settle stamp missing (confirm/action)" % tag
	return ""


func _scene_attack_enter(tag: String) -> String:
	_battle._enter_attack_mode()
	await _settle(4)
	if BattleFeelLoop.stage_of(_battle) != "attack_enter":
		return "%s: after enter attack stage want attack_enter got %s" % [
			tag, BattleFeelLoop.stage_of(_battle)
		]
	if _battle.has_meta(BattleLandStrike.META):
		return "%s: land-strike META must clear on attack enter" % tag
	if not _battle.has_meta(BattleAttackAim.META):
		return "%s: attack aim META missing after enter" % tag
	return ""


func _scene_attack_confirm(tag: String) -> String:
	_battle.preview_attack_ui = _foe_i
	_battle.preview_move_cell = Vector2i(-1, -1)
	BattleTouchConfirm.confirm_attack(_battle)
	await _settle(6)
	if BattleFeelLoop.stage_of(_battle) != "attack":
		return "%s: after attack stage want attack got %s" % [tag, BattleFeelLoop.stage_of(_battle)]
	if _battle.has_meta(BattleAttackAim.META):
		return "%s: attack aim META must clear after confirm" % tag
	if not _battle.has_meta("m_attack_confirm_msec"):
		return "%s: attack confirm msec stamp missing" % tag
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
