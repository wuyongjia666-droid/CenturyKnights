extends Node
## Fat Y1-A: dual-ledger readable deepen — ready count + injured foot marks
## across two real maps (ch0_pass + ch1_hill). Algebra first. No telegraph.

const PHONE := Vector2i(2400, 1080)

var _battle: Control
var _player_i := -1
var _buddy_i := -1


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	OS.set_environment("CK_SAFE_INSETS", "")
	if err != "":
		print("FAIL dual ledger readable fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT DUAL LEDGER READABLE FAT PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra()
	if err != "":
		return err
	err = await _boot("ch0_pass")
	if err == "":
		err = await _scene_a_ready_injured()
	await _free_battle()
	if err != "":
		return err
	err = await _boot("ch1_hill")
	if err == "":
		err = await _scene_b_turn_and_done()
	await _free_battle()
	return err


func _algebra() -> String:
	var err := _algebra_counts()
	if err == "":
		err = _algebra_source()
	return err


func _algebra_counts() -> String:
	var units: Array = [
		{"team": "player", "done": false, "alive": true, "pos": Vector2i(1, 2), "char": {"hp": 10, "injured": true}},
		{"team": "enemy", "done": false, "alive": true, "pos": Vector2i(3, 3), "char": {"hp": 8, "injured": true}},
		{"team": "player", "done": true, "alive": true, "pos": Vector2i(2, 2), "char": {"hp": 9, "injured": false}},
		{"team": "player", "done": false, "alive": true, "pos": Vector2i(4, 1), "char": {"hp": 0, "injured": true}},
		{"team": "player", "done": false, "alive": true, "pos": Vector2i(0, 0), "char": {"hp": 7, "injured": false}},
	]
	if BattleDualLedger.count_ready(units) != 2:
		return "algebra ready want 2"
	var ready: Array[int] = BattleDualLedger.ready_indices(units)
	if ready.size() != 2 or ready[0] != 0 or ready[1] != 4:
		return "algebra ready_indices %s" % ready
	var cells: Array[Vector2i] = BattleDualLedger.injured_cells(units)
	if cells.size() != 2:
		return "algebra injured_cells size %d" % cells.size()
	if cells[0] != Vector2i(1, 2) or cells[1] != Vector2i(4, 1):
		return "algebra injured_cells %s" % cells
	if BattleDualLedger.count_injured(units) != 2:
		return "algebra count_injured"
	if BattleObjectives.text("dual_ledger_ready") == "dual_ledger_ready":
		return "locale dual_ledger_ready missing"
	return ""


func _algebra_source() -> String:
	var led := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_dual_ledger.gd")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	for needle in ["count_ready", "injured_cells", "draw_injured_marks", "dual_ledger_ready"]:
		if led.find(needle) < 0 and needle != "dual_ledger_ready":
			return "ledger missing %s" % needle
	if led.find("EmptyHost") >= 0 or ctrl.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	if ctrl.find("BattleDualLedger.draw_injured_marks") < 0:
		return "controller missing draw_injured_marks"
	if led.find("telegraph") >= 0 or led.find("Telegraph") >= 0:
		return "ledger dragged telegraph residue"
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
	return await _arrange()


func _arrange() -> String:
	_player_i = -1
	_buddy_i = -1
	for i in _battle.units.size():
		var u = _battle.units[i]
		if int(u.char.hp) <= 0:
			continue
		if str(u.team) != "player":
			continue
		if _player_i < 0:
			_player_i = i
			u.pos = Vector2i(3, 3)
			u.done = false
			u.char.injured = true
		elif _buddy_i < 0:
			_buddy_i = i
			u.pos = Vector2i(1, 1)
			u.done = false
			u.char.injured = false
		else:
			u.done = true
	if _player_i < 0:
		return "deploy missing player"
	if _buddy_i < 0:
		var buddy = CharacterFactory.make_tutorial_militia(0)
		buddy.hp = buddy.max_hp
		buddy.injured = false
		_battle.units.append({"char": buddy, "pos": Vector2i(1, 1), "team": "player", "done": false, "tag": ""})
		_buddy_i = _battle.units.size() - 1
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	_battle._lamp_charges = 1
	_battle._lamp_max = 2
	BattleDualLedger.attach(_battle)
	BattleDualLedger.place(_battle)
	if _battle.overlay:
		_battle.overlay.queue_redraw()
	await _settle(4)
	return ""


func _scene_a_ready_injured() -> String:
	var hud := BattleDualLedger._hud(_battle)
	if hud == null:
		return "scene A: ledger HUD missing"
	if int(hud.get_meta("ready_n")) < 2:
		return "scene A: ready_n want ≥2 got %s" % hud.get_meta("ready_n")
	if int(hud.get_meta("injured_n")) < 1:
		return "scene A: injured_n want ≥1 got %s" % hud.get_meta("injured_n")
	var ready_lbl := hud.get_node_or_null("Row/Ready") as Label
	if ready_lbl == null or not ready_lbl.visible:
		return "scene A: Ready label hidden on player turn"
	if ready_lbl.text.find(str(int(hud.get_meta("ready_n")))) < 0:
		return "scene A: Ready text %s" % ready_lbl.text
	var cells: Array[Vector2i] = BattleDualLedger.injured_cells(_battle.units)
	if cells.is_empty():
		return "scene A: injured_cells empty after mark"
	# Foot marks draw path — probe via CanvasItem helper.
	var ov := _DrawProbe.new()
	ov.host = _battle
	_battle.add_child(ov)
	ov.queue_redraw()
	await _settle(3)
	if not ov.drew:
		ov.queue_free()
		return "scene A: draw_injured_marks did not run"
	ov.queue_free()
	return ""


func _scene_b_turn_and_done() -> String:
	var hud := BattleDualLedger._hud(_battle)
	if hud == null:
		return "scene B: ledger HUD missing"
	var ready_lbl := hud.get_node_or_null("Row/Ready") as Label
	if ready_lbl == null:
		return "scene B: Ready label missing"
	var before := int(hud.get_meta("ready_n"))
	_battle.units[_player_i].done = true
	BattleDualLedger.refresh(_battle)
	await _settle(2)
	var after := int(hud.get_meta("ready_n"))
	if after != before - 1:
		return "scene B: ready_n after done want %d got %d" % [before - 1, after]
	_battle.turn_team = "enemy"
	BattleDualLedger.refresh(_battle)
	await _settle(2)
	if ready_lbl.visible:
		return "scene B: Ready must hide on enemy turn"
	# Re-show on player turn
	_battle.turn_team = "player"
	BattleDualLedger.refresh(_battle)
	await _settle(2)
	if not ready_lbl.visible:
		return "scene B: Ready must reappear on player turn"
	var cells: Array[Vector2i] = BattleDualLedger.injured_cells(_battle.units)
	if cells.is_empty():
		return "scene B: injured foot cells empty on ch1_hill"
	return ""


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
	_battle = null
	await _settle(4)


func _set_window() -> void:
	DisplayServer.window_set_size(PHONE)
	OS.set_environment("CK_SAFE_INSETS", "48,0,0,24")
	await _settle(2)


func _settle(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame


class _DrawProbe extends Node2D:
	var host = null
	var drew := false

	func _draw() -> void:
		BattleDualLedger.draw_injured_marks(host, self)
		drew = true
