extends Node
## Y1-A T-P23: enter attack mode → nearest in-reach foe framed + body chrome. Real battle E2E.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

var _battle: Control
var _player_i := -1
var _foe_near := -1
var _foe_far := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL attack aim: ", err)
		get_tree().quit(1)
		return
	print("COMBAT ATTACK AIM PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _source_contracts()
	if err != "":
		return err
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	err = await _boot(true)
	if err == "":
		err = await _e2e_aim()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if err != "":
		return err
	err = await _boot(false)
	if err == "":
		err = await _e2e_aim()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err


func _source_contracts() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var aim := FileAccess.get_file_as_string("res://scripts/battle/battle_attack_aim.gd")
	var touch := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if ctrl.find("BattleAttackAim.after_enter(self)") < 0:
		return "controller _enter_attack_mode missing after_enter"
	if ctrl.find("BattleAttackAim.draw(self, overlay)") < 0:
		return "controller overlay does not paint attack aim"
	if touch.find("BattleAttackAim.clear(host)") < 0:
		return "touch clear does not drop attack aim"
	if aim.find("BattleRules.in_weapon_range") < 0:
		return "attack aim must use BattleRules.in_weapon_range"
	if aim.find("BattleCombatFrame.follow_cells") < 0:
		return "attack aim must use BattleCombatFrame"
	if aim.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	return ""


func _boot(mobile: bool) -> String:
	await _set_window(PHONE if mobile else DESK)
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.set_meta("battle_map", "obj_rout")
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(_battle)
	get_tree().current_scene = _battle
	await _settle(8)
	if not _battle.has_method("_click_cell") or not ("units" in _battle):
		return "battle controller script failed to attach"
	if mobile:
		var insets := {"left": 80.0, "top": 0.0, "right": 0.0, "bottom": 24.0}
		var fitted: Dictionary = MobileLayout.fit(Vector2(PHONE), insets)
		MobileLayout.apply_root(_battle, fitted)
		_battle.set_meta("mobile_insets", insets)
		if _battle.has_method("apply_mobile_layout"):
			_battle.apply_mobile_layout()
		await _settle(8)
	return _arrange()


func _arrange() -> String:
	_battle.turn_team = "player"
	_battle.battle_over = false
	_player_i = -1
	_foe_near = -1
	_foe_far = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player" and _player_i < 0:
			_player_i = i
		elif str(u.team) == "enemy":
			if _foe_near < 0:
				_foe_near = i
			elif _foe_far < 0:
				_foe_far = i
	if _player_i < 0 or _foe_near < 0:
		return "deploy missing player/enemy"
	var th: int = _battle.terrain.size()
	var tw: int = _battle.terrain[0].size() if th > 0 else 8
	var stand := Vector2i(mini(3, tw - 1), mini(2, th - 1))
	var near := Vector2i(mini(stand.x + 1, tw - 1), stand.y)
	var far := Vector2i(mini(stand.x + 3, tw - 1), stand.y)
	if near == stand:
		near = Vector2i(stand.x, mini(stand.y + 1, th - 1))
	_battle.units[_player_i].pos = stand
	_battle.units[_player_i].done = false
	_battle.units[_player_i].char.job_id = "light_inf"
	_battle.units[_player_i].char.recalc_hp()
	_battle.units[_player_i].char.hp = _battle.units[_player_i].char.max_hp
	_battle.units[_foe_near].pos = near
	_battle.units[_foe_near].char.hp = maxi(int(_battle.units[_foe_near].char.hp), 10)
	if _foe_far >= 0:
		_battle.units[_foe_far].pos = far
		_battle.units[_foe_far].char.hp = maxi(int(_battle.units[_foe_far].char.hp), 10)
	_battle.selected = _player_i
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle.attack_mode = false
	_battle.moved_this_select = false
	_battle.move_cells = {}
	# Park camera so near foe may be off-play until after_enter pulls.
	var stage: Rect2 = BattlePick._stage_rect(_battle)
	if stage.size.x < 8.0:
		return "stage missing"
	var origin: Vector2 = _battle.ORIGIN
	var zoom := float(_battle._board_zoom)
	var cell_px: float = float(_battle.CELL) * zoom
	var pan: Vector2 = _battle._board_pan
	var shown: float = origin.x * zoom + float(near.x) * cell_px + pan.x
	var need: float = stage.end.x + 160.0 - shown
	_battle._board_pan = Vector2(pan.x + need, pan.y)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	if _battle.has_method("_apply_board_xform"):
		_battle._apply_board_xform()
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _e2e_aim() -> String:
	_battle._select_player(_player_i)
	await _settle(3)
	_battle.units[_player_i].char.job_id = "light_inf"
	_battle.units[_player_i].char.recalc_hp()
	_battle.units[_player_i].char.hp = _battle.units[_player_i].char.max_hp
	var before: Vector2 = _battle._board_pan
	_battle._enter_attack_mode()
	await _settle(8)
	if not BattleAttackAim.active(_battle):
		return "attack aim not active after _enter_attack_mode"
	var idxs: Array[int] = BattleAttackAim.threatened_indices(_battle)
	if not idxs.has(_foe_near):
		return "near foe not threatened in attack aim: %s" % idxs
	if _foe_far >= 0 and idxs.has(_foe_far):
		return "far foe incorrectly threatened: %s" % idxs
	var nearest := BattleAttackAim.nearest_index(_battle)
	if nearest != _foe_near:
		return "nearest should be near foe got %s" % nearest
	if not _battle.has_meta(BattleAttackAim.META):
		return "after_enter did not stamp meta"
	var info = _battle.get_meta(BattleAttackAim.META)
	if int(info.get("nearest", -2)) != _foe_near:
		return "meta nearest wrong: %s" % info
	var after: Vector2 = _battle._board_pan
	if after.x >= before.x - 0.5:
		var stage: Rect2 = BattlePick._stage_rect(_battle)
		var origin: Vector2 = _battle.ORIGIN
		var zoom := float(_battle._board_zoom)
		var cell_px: float = float(_battle.CELL) * zoom
		var inset := BattleCombatFrame.play_inset(stage, BattleCombatFrame.forecast_band(DeviceProfile.is_mobile()), 0.0)
		var near_pos: Vector2i = _battle.units[_foe_near].pos
		if not BattleCombatFrame.figure_inside(origin, cell_px, near_pos, after, zoom, inset, 12.0):
			return "aim settle did not bring near foe into inset (before %s after %s)" % [before, after]
	# Leaving attack mode via clear drops meta.
	BattleTouchConfirm.clear(_battle, false)
	if _battle.has_meta(BattleAttackAim.META):
		return "clear left attack aim meta"
	# Re-enter then flip attack_mode off → active() false even if meta lingered.
	_battle._enter_attack_mode()
	await _settle(2)
	_battle.attack_mode = false
	if BattleAttackAim.active(_battle):
		return "attack_mode=false should suppress attack aim"
	return ""


func _set_window(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
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
