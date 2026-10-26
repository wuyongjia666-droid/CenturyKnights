extends Node
## Fat Y1-A: turn-bridge + dual-ledger ready tap — auto-select first ready,
## ready foot pulse, Ready HUD cycles FormationCycle. Multi-scene (ch0_pass + ch1_hill).
## No telegraph residue.

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
		print("FAIL turn bridge ledger fat: ", err)
		get_tree().quit(1)
		return
	print("COMBAT TURN BRIDGE LEDGER FAT PASS")
	get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "CK_FORCE_MOBILE did not flip DeviceProfile"
	var err := _algebra()
	if err != "":
		return err
	err = await _boot("ch0_pass")
	if err == "":
		err = await _scene_a_return_and_tap()
	await _free_battle()
	if err != "":
		return err
	err = await _boot("ch1_hill")
	if err == "":
		err = await _scene_b_pulse_and_hide()
	await _free_battle()
	return err


func _algebra() -> String:
	var err := _algebra_pulse()
	if err == "":
		err = _algebra_source()
	return err


func _algebra_pulse() -> String:
	var host := _HostStub.new()
	add_child(host)
	host.turn_team = "player"
	host.battle_over = false
	host.selected = -1
	host.units = [
		{"team": "player", "done": false, "pos": Vector2i(2, 2), "char": {"hp": 10}},
		{"team": "player", "done": true, "pos": Vector2i(3, 3), "char": {"hp": 8}},
		{"team": "player", "done": false, "pos": Vector2i(1, 4), "char": {"hp": 9}},
		{"team": "enemy", "done": false, "pos": Vector2i(5, 5), "char": {"hp": 6}},
	]
	BattleTurnBridge.note_player_return(host)
	var sel := int(host.selected)
	var pulse := BattleTurnBridge.pulse_alpha(host)
	var cells: Array[Vector2i] = BattleTurnBridge._ready_cells(host.units)
	var n := BattleTurnBridge.tap_ready(host)
	var hint := BattleObjectives.text("dual_ledger_ready_hint")
	host.queue_free()
	if sel != 0:
		return "algebra auto-select want 0 got %d" % sel
	if pulse <= 0.0:
		return "algebra pulse_alpha after note"
	if cells.size() != 2:
		return "algebra ready_cells want 2 got %d" % cells.size()
	if n != 2:
		return "algebra tap_ready wrap/next want 2 got %d" % n
	if hint == "dual_ledger_ready_hint":
		return "locale dual_ledger_ready_hint missing"
	return ""


func _algebra_source() -> String:
	var bridge := FileAccess.get_file_as_string("res://scripts/battle/battle_turn_bridge.gd")
	var led := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_dual_ledger.gd")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	for needle in ["note_player_return", "draw_ready_pulse", "tap_ready", "pulse_alpha", "after_unit_done"]:
		if bridge.find(needle) < 0:
			return "bridge missing %s" % needle
	if led.find("_on_ready_input") < 0:
		return "ledger missing ready input"
	if led.find("MOUSE_FILTER_STOP") < 0:
		return "ledger Ready not STOP"
	if ctrl.find("BattleTurnBridge.note_player_return") < 0:
		return "controller missing note_player_return"
	if ctrl.find("BattleTurnBridge.draw_ready_pulse") < 0:
		return "controller missing draw_ready_pulse"
	if ctrl.find("BattleTurnBridge.after_unit_done") < 0:
		return "controller missing after_unit_done"
	for bad in ["telegraph", "Telegraph", "EmptyHost"]:
		if bridge.find(bad) >= 0:
			return "bridge dragged %s" % bad
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
		elif _buddy_i < 0:
			_buddy_i = i
			u.pos = Vector2i(1, 1)
			u.done = false
		else:
			u.done = true
	if _player_i < 0:
		return "deploy missing player"
	if _buddy_i < 0:
		var buddy = CharacterFactory.make_tutorial_militia(0)
		buddy.hp = buddy.max_hp
		_battle.units.append({"char": buddy, "pos": Vector2i(1, 1), "team": "player", "done": false, "tag": ""})
		_buddy_i = _battle.units.size() - 1
	_battle.selected = -1
	_battle.turn_team = "player"
	_battle.battle_over = false
	_battle._cut_playing = false
	BattleDualLedger.attach(_battle)
	BattleDualLedger.place(_battle)
	if _battle.overlay:
		_battle.overlay.queue_redraw()
	await _settle(4)
	return ""


func _scene_a_return_and_tap() -> String:
	BattleTurnBridge.note_player_return(_battle)
	await _settle(3)
	if int(_battle.selected) != _player_i and int(_battle.selected) != _buddy_i:
		return "scene A: auto-select not a ready player got %d" % int(_battle.selected)
	if BattleTurnBridge.pulse_alpha(_battle) <= 0.0:
		return "scene A: pulse_alpha dead after return"
	var hud := BattleDualLedger._hud(_battle)
	if hud == null:
		return "scene A: ledger HUD missing"
	var ready_lbl := hud.get_node_or_null("Row/Ready") as Label
	if ready_lbl == null or ready_lbl.mouse_filter != Control.MOUSE_FILTER_STOP:
		return "scene A: Ready not STOP"
	var before := int(_battle.selected)
	var nxt := BattleTurnBridge.tap_ready(_battle)
	await _settle(2)
	if nxt < 0:
		return "scene A: tap_ready failed"
	if nxt == before:
		return "scene A: tap_ready did not advance"
	# Simulate wait handoff: mark current done, clear select, after_unit_done
	_battle.units[nxt].done = true
	_battle.selected = -1
	BattleTurnBridge.after_unit_done(_battle)
	await _settle(2)
	var hand := int(_battle.selected)
	if hand < 0 or bool(_battle.units[hand].done):
		return "scene A: after_unit_done handoff failed got %d" % hand
	var ov := _DrawProbe.new()
	ov.host = _battle
	_battle.add_child(ov)
	ov.queue_redraw()
	await _settle(3)
	if not ov.drew:
		ov.queue_free()
		return "scene A: draw_ready_pulse did not run"
	ov.queue_free()
	return ""


func _scene_b_pulse_and_hide() -> String:
	BattleTurnBridge.note_player_return(_battle)
	await _settle(2)
	if BattleTurnBridge.pulse_alpha(_battle) <= 0.0:
		return "scene B: pulse missing on ch1_hill"
	var hud := BattleDualLedger._hud(_battle)
	if hud == null:
		return "scene B: ledger HUD missing"
	var ready_lbl := hud.get_node_or_null("Row/Ready") as Label
	if ready_lbl == null or not ready_lbl.visible:
		return "scene B: Ready hidden on player turn"
	_battle.turn_team = "enemy"
	BattleDualLedger.refresh(_battle)
	await _settle(2)
	if ready_lbl.visible:
		return "scene B: Ready must hide on enemy turn"
	if BattleTurnBridge.tap_ready(_battle) != -1:
		return "scene B: tap_ready must no-op on enemy turn"
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


class _HostStub extends Node:
	var turn_team := "player"
	var battle_over := false
	var selected := -1
	var units: Array = []
	var overlay = null

	func _select_player(ui: int) -> void:
		selected = ui


class _DrawProbe extends Node2D:
	var host = null
	var drew := false

	func _draw() -> void:
		BattleTurnBridge.draw_ready_pulse(host, self)
		drew = true
