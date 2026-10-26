extends Node
## Y1-A T-P20: move-ghost strike peek — enemies in weapon reach from the ghost
## stand get figure chrome; camera frames ghost + nearest foe. Real battle E2E.

const PHONE := Vector2i(2400, 1080)
const DESK := Vector2i(1280, 720)

var _battle: Control
var _player_i := -1
var _foe_near := -1
var _foe_far := -1


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL ghost strike: ", err)
		get_tree().quit(1)
		return
	print("COMBAT GHOST STRIKE PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _algebra()
	if err == "":
		err = _source_contracts()
	if err != "":
		return err
	OS.set_environment("CK_FORCE_MOBILE", "1")
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	err = await _boot(true)
	if err == "":
		err = await _e2e_ghost_marks_and_settle()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	if err != "":
		return err
	err = await _boot(false)
	if err == "":
		err = await _e2e_ghost_marks_and_settle()
	await _free_battle()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err


func _algebra() -> String:
	# Pure reach algebra via BattleRules — melee from ghost hits N1, not N2.
	var melee := CKCharacter.new()
	melee.id = "ghost_melee"
	melee.job_id = "light_inf"
	melee.level = 3
	melee.stats = {"str": 8, "vit": 8, "skl": 8, "agi": 8, "per": 8, "wil": 8}
	melee.recalc_hp()
	melee.hp = melee.max_hp
	if BattleRules.min_range(melee) != 1:
		return "melee min_range expected 1"
	if BattleRules.attack_reach(melee, "plain", 0) != 1:
		return "melee reach expected 1"
	if not BattleRules.in_weapon_range(melee, 1, "plain", 0):
		return "melee d=1 must be in range"
	if BattleRules.in_weapon_range(melee, 2, "plain", 0):
		return "melee d=2 must be out of range"
	var marksman := CKCharacter.new()
	marksman.id = "ghost_mark"
	marksman.job_id = "marksman"
	marksman.level = 5
	marksman.stats = {"str": 8, "vit": 8, "skl": 10, "agi": 8, "per": 10, "wil": 8}
	marksman.recalc_hp()
	marksman.hp = marksman.max_hp
	if BattleRules.min_range(marksman) != 2:
		return "marksman min_range expected 2"
	if BattleRules.in_weapon_range(marksman, 1, "plain", 0):
		return "marksman d=1 must be out (min 2)"
	if not BattleRules.in_weapon_range(marksman, 2, "plain", 0):
		return "marksman d=2 must be in range"
	return ""


func _source_contracts() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var touch := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	var ghost := FileAccess.get_file_as_string("res://scripts/battle/battle_ghost_strike.gd")
	var misses: Array = []
	if ctrl.find("BattleGhostStrike.draw(self, overlay)") < 0:
		misses.append("controller overlay does not paint ghost strike")
	if ctrl.find("BattleGhostStrike.after_preview(self)") < 0:
		misses.append("controller preview latch does not settle ghost strike")
	if touch.find("BattleGhostStrike.after_preview(host)") < 0:
		misses.append("touch confirm preview does not settle ghost strike")
	if ghost.find("BattleRules.in_weapon_range") < 0:
		misses.append("ghost strike must use BattleRules.in_weapon_range")
	if ghost.find("BattleCombatFrame.follow_cells") < 0:
		misses.append("ghost strike settle must use BattleCombatFrame")
	if ghost.find("EmptyHost") >= 0 or ctrl.find("EmptyHost") >= 0:
		misses.append("EmptyHost theater forbidden")
	return "" if misses.is_empty() else str(misses[0])


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
	_player_i = -1
	_foe_near = -1
	_foe_far = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) == "player" and _player_i < 0:
			_player_i = i
			u.pos = Vector2i(2, 2)
			u.done = false
		elif str(u.team) == "enemy":
			if _foe_near < 0:
				_foe_near = i
			elif _foe_far < 0:
				_foe_far = i
	if _player_i < 0 or _foe_near < 0:
		return "deploy missing player/enemy"
	# Feet at (2,2). Ghost will latch to (4,2). Near foe adjacent to ghost;
	# far foe two steps beyond melee reach from ghost.
	_battle.units[_foe_near].pos = Vector2i(5, 2)
	_battle.units[_foe_near].char.hp = maxi(int(_battle.units[_foe_near].char.hp), 10)
	if _foe_far >= 0:
		_battle.units[_foe_far].pos = Vector2i(7, 2)
		_battle.units[_foe_far].char.hp = maxi(int(_battle.units[_foe_far].char.hp), 10)
	_battle.selected = _player_i
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle.attack_mode = false
	_battle.move_cells = {Vector2i(4, 2): 1, Vector2i(3, 2): 1}
	# Park ghost off the right so settle must pull.
	var stage: Rect2 = BattlePick._stage_rect(_battle)
	if stage.size.x < 8.0:
		return "stage missing"
	var ghost := Vector2i(4, 2)
	var origin: Vector2 = _battle.ORIGIN
	var zoom := float(_battle._board_zoom)
	var cell_px: float = float(_battle.CELL) * zoom
	var pan: Vector2 = _battle._board_pan
	var shown_x: float = origin.x * zoom + float(ghost.x) * cell_px + pan.x
	var need: float = stage.end.x + 140.0 - shown_x
	_battle._board_pan = Vector2(pan.x + need, pan.y)
	if _battle.has_method("_clamp_board_pan"):
		_battle._clamp_board_pan()
	if _battle.has_method("_apply_board_xform"):
		_battle._apply_board_xform()
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _e2e_ghost_marks_and_settle() -> String:
	_battle._select_player(_player_i)
	await _settle(3)
	# Force light_inf so reach is exactly 1 from the ghost.
	_battle.units[_player_i].char.job_id = "light_inf"
	_battle.units[_player_i].char.recalc_hp()
	_battle.units[_player_i].char.hp = _battle.units[_player_i].char.max_hp
	_battle.move_cells = {Vector2i(4, 2): 1}
	_battle.preview_move_cell = Vector2i(4, 2)
	var before: Vector2 = _battle._board_pan
	BattleGhostStrike.after_preview(_battle)
	await _settle(8)
	var stand := BattleGhostStrike.stand_of(_battle)
	if stand != Vector2i(4, 2):
		return "stand_of missed ghost %s" % stand
	var idxs: Array[int] = BattleGhostStrike.threatened_indices(_battle)
	if not idxs.has(_foe_near):
		return "near foe not threatened from ghost: %s" % idxs
	if _foe_far >= 0 and idxs.has(_foe_far):
		return "far foe incorrectly threatened: %s" % idxs
	if not _battle.has_meta(BattleGhostStrike.META):
		return "after_preview did not stamp meta"
	var info = _battle.get_meta(BattleGhostStrike.META)
	if not (info is Dictionary):
		return "meta not a dictionary"
	var foes: Array = info.get("foes", [])
	if foes.is_empty() or foes[0] != _battle.units[_foe_near].pos:
		return "meta foes wrong: %s" % foes
	var after: Vector2 = _battle._board_pan
	if after.x >= before.x - 0.5:
		return "ghost settle did not pull (before %s after %s)" % [before, after]
	# Clear ghost → meta gone, no threatened.
	_battle.preview_move_cell = Vector2i(-1, -1)
	BattleGhostStrike.after_preview(_battle)
	if _battle.has_meta(BattleGhostStrike.META):
		return "clearing ghost left meta"
	if not BattleGhostStrike.threatened_indices(_battle).is_empty():
		return "clearing ghost left threats"
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
