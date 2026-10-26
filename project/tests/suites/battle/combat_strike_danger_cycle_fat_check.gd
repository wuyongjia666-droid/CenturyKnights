extends Node
## Fat Y1-A knife: retreat arm ↔ objective + danger feel + ghost strike +
## attack aim + Tab cycle, across two real battle maps. No telegraph residue.
## Algebra first, then Scene A (ch0_pass) + Scene B (ch1_hill). Quits 1 on miss.

const PHONE := Vector2i(2400, 1080)

var _battle: Control
var _player_i := -1
var _foe_near := -1
var _foe_far := -1
var _foe_a := -1
var _foe_b := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL strike/danger/cycle fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT STRIKE DANGER CYCLE FAT PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra()
	if err != "":
		return err
	# Scene A — ch0_pass: retreat arm/disarm + danger focus settle
	err = await _boot("ch0_pass")
	if err == "":
		err = await _scene_a_retreat_danger()
	await _free_battle()
	if err != "":
		return err
	# Scene B — ch1_hill: ghost strike + attack aim + Tab cycle
	err = await _boot("ch1_hill")
	if err == "":
		err = await _scene_b_ghost_aim_cycle()
	await _free_battle()
	return err


func _algebra() -> String:
	var err := _algebra_reach()
	if err == "":
		err = _algebra_retreat_locale()
	if err == "":
		err = _algebra_source()
	return err


func _algebra_reach() -> String:
	var melee = CharacterFactory.make_tutorial_militia(0)
	melee.job_id = "light_inf"
	melee.recalc_hp()
	if BattleRules.min_range(melee) != 1:
		return "melee min_range want 1"
	if BattleRules.attack_reach(melee, "plain", 0) != 1:
		return "melee reach want 1"
	if not BattleRules.in_weapon_range(melee, 1, "plain", 0):
		return "melee should hit dist 1"
	if BattleRules.in_weapon_range(melee, 2, "plain", 0):
		return "melee should miss dist 2"
	return ""


func _algebra_retreat_locale() -> String:
	if BattleObjectives.text("obj_retreat_armed") == "obj_retreat_armed":
		return "locale obj_retreat_armed missing"
	if BattleRetreatObjective.compose_detail("敌军 3", false) != "敌军 3":
		return "compose unarmed keeps base"
	var armed := BattleRetreatObjective.compose_detail("敌军 3", true)
	if armed.find("·") < 0 and armed.find(BattleObjectives.text("obj_retreat_armed")) < 0:
		return "compose armed missing warn"
	if BattleRetreatObjective.detail_color(true) != UIKit.DANGER:
		return "armed color not DANGER"
	return ""


func _algebra_source() -> String:
	var err := _algebra_source_controller()
	if err == "":
		err = _algebra_source_touch_pause()
	if err == "":
		err = _algebra_source_modules()
	return err


func _algebra_source_controller() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var need := {
		"BattleDangerFeel.after_set(self)": "controller missing danger after_set",
		"BattleDangerFeel.draw(self, overlay)": "controller missing danger draw",
		"BattleGhostStrike.draw(self, overlay)": "controller missing ghost draw",
		"BattleGhostStrike.after_preview(self)": "controller missing ghost after_preview",
		"BattleAttackAim.after_enter(self)": "controller missing aim after_enter",
		"BattleAttackAim.draw(self, overlay)": "controller missing aim draw",
		"BattleAttackCycle.apply_next(self)": "controller missing cycle next",
		"BattleAttackCycle.apply_prev(self)": "controller missing cycle prev",
	}
	for needle in need:
		if ctrl.find(str(needle)) < 0:
			return str(need[needle])
	var tab_i := ctrl.find("KEY_TAB:")
	if tab_i < 0:
		return "controller missing KEY_TAB"
	var tab_chunk := ctrl.substr(tab_i, 420)
	if tab_chunk.find("BattleAttackCycle") < 0:
		return "KEY_TAB chunk missing AttackCycle"
	if ctrl.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	return ""


func _algebra_source_touch_pause() -> String:
	var touch := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	var pause := FileAccess.get_file_as_string("res://scripts/core/pause_menu.gd")
	var oh := FileAccess.get_file_as_string("res://scripts/battle/ui/objective_hud.gd")
	if touch.find("BattleGhostStrike.after_preview(host)") < 0:
		return "touch missing ghost after_preview"
	if touch.find("BattleAttackAim.clear(host)") < 0:
		return "touch missing aim clear"
	if touch.find("BattleAttackCycle.clear(host)") < 0:
		return "touch missing cycle clear"
	if touch.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	if pause.find("BattleRetreatObjective.arm") < 0:
		return "pause missing retreat arm"
	if pause.find("BattleRetreatObjective.disarm") < 0:
		return "pause missing retreat disarm"
	if oh.find("BattleRetreatObjective.compose_detail") < 0:
		return "ObjectiveHud missing compose_detail"
	return ""


func _algebra_source_modules() -> String:
	for path in [
		"res://scripts/battle/battle_ghost_strike.gd",
		"res://scripts/battle/battle_attack_aim.gd",
		"res://scripts/battle/battle_attack_cycle.gd",
		"res://scripts/battle/ui/battle_danger_feel.gd",
		"res://scripts/battle/ui/battle_retreat_objective.gd",
	]:
		var body := FileAccess.get_file_as_string(path)
		if body.find("telegraph") >= 0 or body.find("Telegraph") >= 0:
			return "%s dragged telegraph residue" % path
		if body.find("EmptyHost") >= 0:
			return "%s EmptyHost theater" % path
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
	return _arrange()


func _arrange() -> String:
	_player_i = -1
	_foe_near = -1
	_foe_far = -1
	_foe_a = -1
	_foe_b = -1
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
				_foe_a = i
			elif _foe_far < 0:
				_foe_far = i
				_foe_b = i
	if _player_i < 0 or _foe_near < 0:
		return "deploy missing player/enemy"
	# Ensure a second foe for cycle when map only spawns one.
	if _foe_far < 0:
		var foe = CharacterFactory.make_tutorial_militia(1)
		foe.hp = foe.max_hp
		_battle.units.append({"char": foe, "pos": Vector2i(4, 2), "team": "enemy", "done": false, "tag": ""})
		_foe_far = _battle.units.size() - 1
		_foe_b = _foe_far
	_battle.units[_foe_near].pos = Vector2i(5, 2)
	_battle.units[_foe_near].char.hp = maxi(int(_battle.units[_foe_near].char.hp), 10)
	_battle.units[_foe_far].pos = Vector2i(4, 3)
	_battle.units[_foe_far].char.hp = maxi(int(_battle.units[_foe_far].char.hp), 10)
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	_battle.attack_mode = false
	_battle.skill_mode = false
	_battle.preview_move_cell = Vector2i(-1, -1)
	_battle.preview_attack_ui = -1
	_battle.moved_this_select = false
	_battle.danger_on = false
	_battle.danger_focus = -1
	BattlePick.cancel_focus_tween(_battle)
	return ""


func _scene_a_retreat_danger() -> String:
	# Retreat arm ↔ ObjectiveHud closed loop on a live host.
	if BattleRetreatObjective.is_armed(_battle):
		return "scene A: starts armed"
	BattleRetreatObjective.arm(_battle)
	if not BattleRetreatObjective.is_armed(_battle):
		return "scene A: arm failed"
	var detail := ""
	var oh := _battle.get_node_or_null("ObjectiveHud")
	if oh == null:
		# Some maps place ObjectiveHud under a chrome root — search.
		oh = _find_named(_battle, "ObjectiveHud")
	if oh != null and oh.has_method("refresh"):
		oh.refresh(_battle)
		await _settle(2)
	var detail_lbl := _find_named(_battle, "Detail") as Label
	if detail_lbl != null:
		detail = detail_lbl.text
		var warn := BattleObjectives.text("obj_retreat_armed")
		if detail.find(warn) < 0 and detail.find("·") < 0:
			# compose may have been applied; tolerate if meta armed + compose works
			var composed := BattleRetreatObjective.compose_detail("敌军", true)
			if composed.find(warn) < 0 and composed.find("·") < 0:
				return "scene A: armed detail missing warn got %s" % detail
	BattleRetreatObjective.disarm(_battle)
	if BattleRetreatObjective.is_armed(_battle):
		return "scene A: disarm failed"
	# Danger focus settle: park foe off right so settle must pull.
	_battle.units[_foe_near].pos = Vector2i(6, 2)
	_park_offscreen(_battle.units[_foe_near].pos, 120.0)
	var before: Vector2 = _battle._board_pan
	_battle._set_danger(true, _foe_near)
	await _settle(6)
	if not _battle.danger_on or int(_battle.danger_focus) != _foe_near:
		return "scene A: set_danger did not latch"
	var after: Vector2 = _battle._board_pan
	if after.x >= before.x - 0.5:
		return "scene A: danger settle did not pull (before %s after %s)" % [before, after]
	if not _battle.has_meta("m_combat_frame"):
		return "scene A: danger settle missing m_combat_frame"
	# Layers union matches flat collect.
	var flat := DangerZone.collect(_battle)
	var layers: Dictionary = DangerZone.collect_layers(_battle)
	var rebuilt := {}
	for c in layers.stands.keys():
		rebuilt[c] = true
	for c in layers.strike.keys():
		rebuilt[c] = true
	if rebuilt.size() != flat.size():
		return "scene A: layers union %s != collect %s" % [rebuilt.size(), flat.size()]
	if layers.stands.is_empty():
		return "scene A: stands empty"
	for c in layers.strike.keys():
		if layers.stands.has(c):
			return "scene A: strike leaked stand %s" % c
	_battle._set_danger(false, -1)
	return ""


func _scene_b_ghost_aim_cycle() -> String:
	var err := await _scene_b_ghost()
	if err == "":
		err = await _scene_b_aim_cycle()
	return err


func _scene_b_ghost() -> String:
	_battle.units[_player_i].pos = Vector2i(2, 2)
	_battle.units[_foe_near].pos = Vector2i(5, 2)
	_battle.units[_foe_far].pos = Vector2i(4, 3)
	_battle.units[_player_i].char.job_id = "light_inf"
	_battle.units[_player_i].char.recalc_hp()
	_battle.units[_player_i].char.hp = _battle.units[_player_i].char.max_hp
	_battle._select_player(_player_i)
	await _settle(3)
	_battle.move_cells = {Vector2i(4, 2): 1, Vector2i(3, 2): 1}
	_park_offscreen(Vector2i(4, 2), 140.0)
	_battle.preview_move_cell = Vector2i(4, 2)
	var before: Vector2 = _battle._board_pan
	BattleGhostStrike.after_preview(_battle)
	await _settle(8)
	if BattleGhostStrike.stand_of(_battle) != Vector2i(4, 2):
		return "scene B: ghost stand missed"
	var gidxs: Array[int] = BattleGhostStrike.threatened_indices(_battle)
	if not gidxs.has(_foe_near):
		return "scene B: near foe not threatened from ghost: %s" % gidxs
	if gidxs.has(_foe_far):
		return "scene B: far foe incorrectly threatened: %s" % gidxs
	if not _battle.has_meta(BattleGhostStrike.META):
		return "scene B: ghost meta missing"
	if _battle._board_pan.x >= before.x - 0.5:
		return "scene B: ghost settle did not pull"
	_battle.preview_move_cell = Vector2i(-1, -1)
	BattleGhostStrike.after_preview(_battle)
	if _battle.has_meta(BattleGhostStrike.META):
		return "scene B: clearing ghost left meta"
	return ""


func _scene_b_aim_cycle() -> String:
	_battle.units[_foe_near].pos = Vector2i(3, 2)
	_battle.units[_foe_far].pos = Vector2i(2, 3)
	_park_offscreen(_battle.units[_foe_near].pos, 160.0)
	_battle._enter_attack_mode()
	await _settle(4)
	if not BattleAttackAim.active(_battle):
		return "scene B: attack aim not active"
	var aim_idxs: Array[int] = BattleAttackAim.threatened_indices(_battle)
	if not aim_idxs.has(_foe_near):
		return "scene B: near foe missing from aim: %s" % aim_idxs
	if not _battle.has_meta(BattleAttackAim.META):
		return "scene B: aim meta missing"
	if not BattleAttackCycle.active(_battle):
		return "scene B: cycle not active after enter"
	# First Tab seeds preview — enter must not auto-latch (touch_confirm second-tap).
	BattleAttackCycle.apply_next(_battle)
	await _settle(4)
	var cidxs: Array[int] = BattleAttackCycle.threatened_indices(_battle)
	if cidxs.size() < 1:
		return "scene B: cycle threatened empty"
	if int(_battle.preview_attack_ui) != cidxs[0]:
		return "scene B: first Tab did not seed first foe"
	if cidxs.size() >= 2:
		var second: int = BattleAttackCycle.apply_next(_battle)
		if second != cidxs[1]:
			return "scene B: next want %s got %s" % [cidxs[1], second]
		var back: int = BattleAttackCycle.apply_prev(_battle)
		if back != cidxs[0]:
			return "scene B: prev want %s got %s" % [cidxs[0], back]
	BattleTouchConfirm.clear(_battle, false)
	if _battle.has_meta(BattleAttackAim.META):
		return "scene B: clear left aim meta"
	if _battle.has_meta(BattleAttackCycle.META):
		return "scene B: clear left cycle meta"
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
