extends Node
## Fat Y1-A: stance readable — done count + done foot marks + moved chip
## across two real maps (ch0_pass + ch1_hill). Algebra first. Ban aim telegraphs.

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
		print("FAIL stance readable fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT STANCE READABLE FAT PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra()
	if err != "":
		return err
	err = await _boot("ch0_pass")
	if err == "":
		err = await _scene_a_done_marks()
	await _free_battle()
	if err != "":
		return err
	err = await _boot("ch1_hill")
	if err == "":
		err = await _scene_b_moved_chip()
	await _free_battle()
	return err


func _algebra() -> String:
	var err := _algebra_counts()
	if err == "":
		err = _algebra_locale()
	if err == "":
		err = _algebra_source()
	return err


func _algebra_counts() -> String:
	var units: Array = [
		{"team": "player", "done": false, "alive": true, "pos": Vector2i(1, 2), "char": {"hp": 10, "injured": false}},
		{"team": "player", "done": true, "alive": true, "pos": Vector2i(2, 2), "char": {"hp": 9, "injured": false}},
		{"team": "player", "done": true, "alive": true, "pos": Vector2i(3, 1), "char": {"hp": 0, "injured": false}},
		{"team": "enemy", "done": true, "alive": true, "pos": Vector2i(4, 4), "char": {"hp": 8, "injured": false}},
		{"team": "player", "done": true, "alive": true, "pos": Vector2i(0, 0), "char": {"hp": 7, "injured": false}},
	]
	if BattleDualLedger.count_done(units) != 2:
		return "algebra done want 2"
	var cells: Array[Vector2i] = BattleDualLedger.done_cells(units)
	if cells.size() != 2:
		return "algebra done_cells size %d" % cells.size()
	return ""


func _algebra_locale() -> String:
	if BattleObjectives.text("dual_ledger_done") == "dual_ledger_done":
		return "locale dual_ledger_done missing"
	if BattleObjectives.text("stance_moved") == "stance_moved":
		return "locale stance_moved missing"
	if BattleStanceReadable.chip_text() == "stance_moved":
		return "chip_text unresolved"
	return ""


func _algebra_source() -> String:
	var led := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_dual_ledger.gd")
	var st := FileAccess.get_file_as_string("res://scripts/battle/battle_stance_readable.gd")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	for needle in ["count_done", "done_cells", "draw_done_marks"]:
		if led.find(needle) < 0:
			return "ledger missing %s" % needle
	if st.find("draw_moved_chip") < 0 or st.find("moved_open") < 0:
		return "stance module incomplete"
	if ctrl.find("BattleDualLedger.draw_done_marks") < 0:
		return "controller missing draw_done_marks"
	if ctrl.find("BattleStanceReadable.draw_moved_chip") < 0:
		return "controller missing draw_moved_chip"
	if led.find("BattleLinkTelegraph") >= 0 or st.find("BattleLinkTelegraph") >= 0:
		return "telegraph residue forbidden"
	if led.find("BattleFoeOpeningTelegraph") >= 0 or st.find("BattleFoeOpeningTelegraph") >= 0:
		return "telegraph residue forbidden"
	if led.find("EmptyHost") >= 0 or st.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
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
	for i in range(_battle.units.size()):
		var u = _battle.units[i]
		if str(u.get("team", "")) != "player":
			continue
		if _player_i < 0:
			_player_i = i
		elif _buddy_i < 0:
			_buddy_i = i
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
	_battle.moved_this_select = false
	_battle._lamp_charges = 1
	_battle._lamp_max = 2
	BattleDualLedger.attach(_battle)
	BattleDualLedger.place(_battle)
	if _battle.overlay:
		_battle.overlay.queue_redraw()
	await _settle(4)
	return ""


func _scene_a_done_marks() -> String:
	var hud := BattleDualLedger._hud(_battle)
	if hud == null:
		return "scene A: ledger HUD missing"
	_battle.units[_player_i].done = true
	BattleDualLedger.refresh(_battle)
	await _settle(2)
	if int(hud.get_meta("done_n")) < 1:
		return "scene A: done_n want ≥1 got %s" % hud.get_meta("done_n")
	var done_lbl := hud.get_node_or_null("Row/Done") as Label
	if done_lbl == null or not done_lbl.visible:
		return "scene A: Done label hidden on player turn"
	if done_lbl.text.find(str(int(hud.get_meta("done_n")))) < 0:
		return "scene A: Done text %s" % done_lbl.text
	var cells: Array[Vector2i] = BattleDualLedger.done_cells(_battle.units)
	if cells.is_empty():
		return "scene A: done_cells empty"
	var ov := _DoneProbe.new()
	ov.host = _battle
	_battle.add_child(ov)
	ov.queue_redraw()
	await _settle(3)
	if not ov.drew:
		ov.queue_free()
		return "scene A: draw_done_marks did not run"
	ov.queue_free()
	_battle.turn_team = "enemy"
	BattleDualLedger.refresh(_battle)
	await _settle(2)
	if done_lbl.visible:
		return "scene A: Done must hide on enemy turn"
	_battle.turn_team = "player"
	BattleDualLedger.refresh(_battle)
	await _settle(2)
	if not done_lbl.visible:
		return "scene A: Done must reappear on player turn"
	return ""


func _scene_b_moved_chip() -> String:
	_battle.units[_player_i].done = false
	_battle.selected = _player_i
	_battle.moved_this_select = true
	_battle.turn_team = "player"
	if not BattleStanceReadable.moved_open(_battle):
		return "scene B: moved_open false after move"
	var ov := _ChipProbe.new()
	ov.host = _battle
	_battle.add_child(ov)
	ov.queue_redraw()
	await _settle(3)
	if not ov.drew:
		ov.queue_free()
		return "scene B: draw_moved_chip did not run"
	ov.queue_free()
	_battle.moved_this_select = false
	if BattleStanceReadable.moved_open(_battle):
		return "scene B: moved_open should clear without moved_this_select"
	_battle.units[_buddy_i].done = true
	BattleDualLedger.refresh(_battle)
	await _settle(2)
	var hud := BattleDualLedger._hud(_battle)
	if hud == null or int(hud.get_meta("done_n")) < 1:
		return "scene B: done_n after buddy done"
	var cells: Array[Vector2i] = BattleDualLedger.done_cells(_battle.units)
	if cells.is_empty():
		return "scene B: done foot cells empty on ch1_hill"
	return ""


func _free_battle() -> void:
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
	_battle = null
	await _settle(4)


func _set_window() -> void:
	# Match range-preview: disable content-scale so visible_rect tracks PHONE
	# (otherwise _mobile_landscape sees design 1280×720 and flakes in headless).
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	DisplayServer.window_set_size(PHONE)
	OS.set_environment("CK_SAFE_INSETS", "48,0,0,24")
	await _settle(2)


func _settle(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame


class _DoneProbe extends Node2D:
	var host = null
	var drew := false

	func _draw() -> void:
		BattleDualLedger.draw_done_marks(host, self)
		drew = true


class _ChipProbe extends Node2D:
	var host = null
	var drew := false

	func _draw() -> void:
		BattleStanceReadable.draw_moved_chip(host, self)
		drew = true
