extends Node
## Fat knife: 战棋手感收口 — 终局清全戳 / 桌面+手游 BoardInset 整链闭环
## Dual surfaces × dual real maps. No telegraph / EmptyHost / BoardInset-only thin cut.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1600, 900)
const NOTCH := "400,0,0,48"
const MARKER := "COMBAT FEEL CLOSEOUT FAT PASS"

var _battle: Control
var _player_i := -1
var _foe_i := -1
var _surface := "mobile"


func _ready() -> void:
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL feel closeout fat: ", err)
		get_tree().quit(1)
		return
	print(MARKER)
	get_tree().quit(0)


func _run() -> String:
	var err := _algebra()
	if err != "":
		return err
	for surface in ["mobile", "desktop"]:
		_surface = surface
		err = await _boot("ch0_pass")
		if err == "":
			err = await _scene_stack("A-%s" % surface)
		await _free_battle()
		if err != "":
			return err
		err = await _boot("ch1_hill")
		if err == "":
			err = await _scene_stack("B-%s" % surface)
		await _free_battle()
		if err != "":
			return err
	return ""


func _algebra() -> String:
	var err := _algebra_api()
	if err == "":
		err = _algebra_wiring()
	if err == "":
		err = _algebra_no_telegraph()
	if err == "":
		err = _algebra_clear_drops_chain()
	return err


func _algebra_api() -> String:
	if BattleFeelCloseout.META != "m_feel_closeout":
		return "META want m_feel_closeout"
	var body := FileAccess.get_file_as_string("res://scripts/battle/battle_feel_closeout.gd")
	for fn in [
		"static func clear_all_chrome",
		"static func after_battle_end",
		"static func clear",
		"static func stage_of",
	]:
		if body.find(fn) < 0:
			return "%s missing" % fn
	if body.find("BattleBoardInset.refresh_info_block") < 0:
		return "Closeout must refresh BoardInset"
	if body.find("BattleFeelLoop.clear") < 0:
		return "Closeout must clear FeelLoop"
	if body.find("BattleEnemyActFeel.clear") < 0:
		return "Closeout must clear EnemyActFeel"
	if body.find("BattleCancelFeelLoop.clear") < 0:
		return "Closeout must clear CancelFeel"
	if body.find("BattleSkillFeelLoop.clear_all") < 0:
		return "Closeout must clear_all SkillFeel"
	if body.find("BattleLandStrike.clear") < 0:
		return "Closeout must clear LandStrike"
	if body.find("BattleAttackAim.clear") < 0:
		return "Closeout must clear AttackAim"
	return ""


func _algebra_wiring() -> String:
	var phase := FileAccess.get_file_as_string("res://scripts/battle/battle_phase_feel.gd")
	if phase.find("BattleFeelCloseout.after_battle_end") < 0:
		return "PhaseFeel.note_battle_end must call FeelCloseout.after_battle_end"
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("BattlePhaseFeel.note_battle_end") < 0:
		return "controller must note_battle_end"
	return ""


func _algebra_no_telegraph() -> String:
	for path in [
		"res://scripts/battle/battle_feel_closeout.gd",
		"res://scripts/battle/battle_phase_feel.gd",
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


func _algebra_clear_drops_chain() -> String:
	var host := _FakeCloseHost.new()
	host.set_meta(BattleFeelLoop.META, {"stage": "move", "msec": 1})
	host.set_meta(BattleCancelFeelLoop.META, {"stage": "preview", "msec": 1})
	host.set_meta(BattleEnemyActFeel.META, {"stage": "strike", "msec": 1})
	host.set_meta(BattleTurnCycleFeel.META, {"stage": "enemy", "msec": 1})
	host.set_meta(BattleSkillFeelLoop.META, {"stage": "arm", "msec": 1})
	host.set_meta(BattleLandStrike.META, {"stand": Vector2i(1, 1), "msec": 1})
	host.set_meta(BattleAttackAim.META, {"stand": Vector2i(1, 1), "foes": [], "msec": 1})
	host.set_meta(BattleGhostStrike.META, {"stand": Vector2i(2, 2), "msec": 1})
	host.set_meta(BattleWaitHandoff.META, {"from": 0, "to": 1, "msec": 1})
	host.set_meta(BattleTurnBridge.META_PULSE, 1)
	host.danger_on = true
	host.danger_focus = 2
	BattleFeelCloseout.clear_all_chrome(host)
	for key in [
		BattleFeelLoop.META,
		BattleCancelFeelLoop.META,
		BattleEnemyActFeel.META,
		BattleTurnCycleFeel.META,
		BattleSkillFeelLoop.META,
		BattleLandStrike.META,
		BattleAttackAim.META,
		BattleGhostStrike.META,
		BattleWaitHandoff.META,
		BattleTurnBridge.META_PULSE,
	]:
		if host.has_meta(key):
			return "clear_all_chrome left %s" % key
	if host.danger_on or host.danger_focus != -1:
		return "clear_all_chrome must drop danger"
	return ""


func _boot(map_id: String) -> String:
	if _surface == "mobile":
		OS.set_environment("CK_FORCE_MOBILE", "1")
		OS.set_environment("CK_SAFE_INSETS", NOTCH)
	else:
		OS.set_environment("CK_FORCE_MOBILE", "0")
		OS.set_environment("CK_SAFE_INSETS", "")
	await _set_window()
	if _surface == "mobile" and not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	if _surface == "desktop" and DeviceProfile.is_mobile():
		return "desktop surface still mobile"
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
	if _surface == "mobile":
		var insets := {"left": 48.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
		var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
		MobileLayout.apply_root(_battle, fitted)
		_battle.set_meta("mobile_insets", insets)
		if _battle.has_method("apply_mobile_layout"):
			_battle.apply_mobile_layout()
		await _settle(8)
		if not _battle._mobile_landscape():
			return "battle did not enter landscape on %s" % map_id
	else:
		await _settle(4)
	if str(_battle.map_id) != map_id:
		return "map_id want %s got %s" % [map_id, _battle.map_id]
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
			u.done = false
		elif str(u.team) == "player":
			u.done = true
	if _player_i < 0 or _foe_i < 0:
		return "deploy need player+foe"
	_battle.units[_foe_i].pos = Vector2i(4, 3)
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
	_battle.danger_on = false
	_battle.danger_focus = -1
	_battle._round_no = 2
	BattleSkillBuffPreview.clear(_battle)
	BattleSkillHealPreview.clear(_battle)
	BattleSkillFeelLoop.clear(_battle)
	BattleFeelLoop.clear(_battle)
	BattleCancelFeelLoop.clear(_battle)
	BattleTurnCycleFeel.clear(_battle)
	BattleEnemyActFeel.clear(_battle)
	BattleFeelCloseout.clear(_battle)
	BattleLandStrike.clear(_battle)
	BattleAttackAim.clear(_battle)
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _scene_stack(tag: String) -> String:
	var err := await _scene_select_move(tag)
	if err == "":
		err = await _scene_enemy_act(tag)
	if err == "":
		err = await _scene_return(tag)
	if err == "":
		err = await _scene_battle_end(tag)
	return err


func _scene_select_move(tag: String) -> String:
	_battle._select_player(_player_i)
	await _settle(4)
	if BattleFeelLoop.stage_of(_battle) != "select":
		return "%s: select stage want select got %s" % [tag, BattleFeelLoop.stage_of(_battle)]
	var inset_sel := BattleBoardInset.for_host(_battle, 0.0)
	if inset_sel.size.x < 64.0 or inset_sel.size.y < 64.0:
		return "%s: BoardInset after select too small %s" % [tag, inset_sel]
	_battle.preview_move_cell = Vector2i(4, 3)
	_battle.preview_attack_ui = -1
	_battle.units[_foe_i].pos = Vector2i(5, 3)
	_battle.units[_player_i].pos = Vector2i(3, 3)
	BattleTouchConfirm.confirm_move(_battle)
	await _settle(4)
	if BattleFeelLoop.stage_of(_battle) != "move":
		return "%s: move stage want move got %s" % [tag, BattleFeelLoop.stage_of(_battle)]
	var inset_mv := BattleBoardInset.for_host(_battle, 0.0)
	if inset_mv.size.x < 64.0 or inset_mv.size.y < 64.0:
		return "%s: BoardInset after move too small %s" % [tag, inset_mv]
	return ""


func _scene_enemy_act(tag: String) -> String:
	# Seed leftover player chrome that must die at end even if enemy path clears some.
	_battle.set_meta(BattleCancelFeelLoop.META, {"stage": "mode", "msec": 1})
	_battle.turn_team = "enemy"
	BattleTurnCycleFeel.before_enemy_phase(_battle)
	await _settle(2)
	# Place foe adjacent so act threat non-empty.
	_battle.units[_foe_i].pos = Vector2i(4, 3)
	_battle.units[_player_i].pos = Vector2i(3, 3)
	BattleEnemyActFeel.after_act_start(_battle, _foe_i)
	await _settle(3)
	if BattleEnemyActFeel.stage_of(_battle) != "act":
		return "%s: enemy act stage want act got %s" % [tag, BattleEnemyActFeel.stage_of(_battle)]
	var inset := BattleBoardInset.for_host(_battle, 0.0)
	if inset.size.x < 64.0 or inset.size.y < 64.0:
		return "%s: BoardInset during enemy act too small %s" % [tag, inset]
	BattleEnemyActFeel.after_move(_battle, Vector2i(5, 3), _foe_i)
	await _settle(2)
	BattleEnemyActFeel.after_strike(
		_battle, Vector2i(5, 3), _battle.units[_player_i].pos, _foe_i
	)
	await _settle(2)
	BattleEnemyActFeel.after_unit_done(_battle, _foe_i)
	await _settle(2)
	if BattleEnemyActFeel.stage_of(_battle) != "done":
		return "%s: enemy done stage want done got %s" % [
			tag, BattleEnemyActFeel.stage_of(_battle)
		]
	return ""


func _scene_return(tag: String) -> String:
	_battle.turn_team = "player"
	BattleTurnCycleFeel.after_player_return(_battle)
	await _settle(2)
	if BattleEnemyActFeel.stage_of(_battle) != "":
		return "%s: EnemyAct must clear on return" % tag
	if BattleTurnCycleFeel.stage_of(_battle) != "return":
		return "%s: cycle stage want return got %s" % [
			tag, BattleTurnCycleFeel.stage_of(_battle)
		]
	var inset := BattleBoardInset.for_host(_battle, 0.0)
	if inset.size.x < 64.0 or inset.size.y < 64.0:
		return "%s: BoardInset on return too small %s" % [tag, inset]
	return ""


func _scene_battle_end(tag: String) -> String:
	# Re-seed leftover chrome that end must wipe (player-visible seam).
	_battle.set_meta(BattleFeelLoop.META, {"stage": "attack", "msec": 1})
	_battle.set_meta(BattleCancelFeelLoop.META, {"stage": "select", "msec": 1})
	_battle.set_meta(BattleEnemyActFeel.META, {"stage": "done", "msec": 1})
	_battle.set_meta(BattleTurnCycleFeel.META, {"stage": "return", "msec": 1})
	_battle.set_meta(BattleSkillFeelLoop.META, {"stage": "cast", "msec": 1})
	_battle.set_meta(BattleLandStrike.META, {"stand": Vector2i(3, 3), "msec": 1})
	_battle.set_meta(BattleAttackAim.META, {"stand": Vector2i(3, 3), "foes": [], "msec": 1})
	_battle.set_meta(BattleGhostStrike.META, {"stand": Vector2i(4, 3), "msec": 1})
	_battle.set_meta(BattleWaitHandoff.META, {"from": 0, "to": 1, "msec": 1})
	_battle.set_meta(BattleTurnBridge.META_PULSE, Time.get_ticks_msec())
	_battle.danger_on = true
	_battle.danger_focus = _foe_i
	_battle.battle_over = false
	BattlePhaseFeel.note_battle_end(_battle, true)
	await _settle(3)
	if not _battle.has_meta("m_end_flash"):
		return "%s: end flash missing" % tag
	if BattleFeelCloseout.stage_of(_battle) != "end":
		return "%s: closeout stage want end got %s" % [
			tag, BattleFeelCloseout.stage_of(_battle)
		]
	for key in [
		BattleFeelLoop.META,
		BattleCancelFeelLoop.META,
		BattleEnemyActFeel.META,
		BattleTurnCycleFeel.META,
		BattleSkillFeelLoop.META,
		BattleLandStrike.META,
		BattleAttackAim.META,
		BattleGhostStrike.META,
		BattleWaitHandoff.META,
		BattleTurnBridge.META_PULSE,
	]:
		if _battle.has_meta(key):
			return "%s: end left chrome %s" % [tag, key]
	if _battle.danger_on or _battle.danger_focus != -1:
		return "%s: end must clear danger" % tag
	var inset := BattleBoardInset.for_host(_battle, 0.0)
	if inset.size.x < 64.0 or inset.size.y < 64.0:
		return "%s: BoardInset after end too small %s" % [tag, inset]
	# Banner must sit inside shared BoardInset (desktop + mobile).
	var mobile := DeviceProfile.is_mobile()
	var land: bool = mobile and _battle._mobile_landscape()
	var band: Rect2 = BattlePhaseFeel.banner_rect_for_host(_battle, mobile, land)
	if band.size.x < 8.0 or band.size.y < 8.0:
		return "%s: end banner rect empty" % tag
	if not inset.encloses(Rect2(band.position, Vector2(1, 1))) and not inset.intersects(band):
		return "%s: end banner must meet BoardInset" % tag
	return ""


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
	await _settle(2)


func _set_window() -> void:
	var sz := PHONE if _surface == "mobile" else DESK
	DisplayServer.window_set_size(sz)
	await _settle(2)


func _settle(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


class _FakeCloseHost:
	## RefCounted algebra host — built-in meta + danger fields.
	var danger_on: bool = false
	var danger_focus: int = -1
