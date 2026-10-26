extends Node
## Y1-A T-P12: 编队切换 next/prev ready player. Algebra + apply E2E.
## Fail-suite. No EmptyHost theater; no device gate.

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	if _fails.is_empty():
		print("COMBAT FORMATION CYCLE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL combat formation cycle: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("战旗", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false


func _run() -> void:
	_boot()
	_algebra()
	await _apply_host()
	_source_contracts()


func _units() -> Array:
	return [
		{"team": "player", "done": false, "char": {"hp": 10, "name": "A"}},
		{"team": "enemy", "done": false, "char": {"hp": 8, "name": "E"}},
		{"team": "player", "done": true, "char": {"hp": 10, "name": "B-done"}},
		{"team": "player", "done": false, "char": {"hp": 0, "name": "C-dead"}},
		{"team": "player", "done": false, "char": {"hp": 7, "name": "D"}},
	]


func _algebra() -> void:
	var u: Array = _units()
	var ready: Array[int] = BattleFormationCycle.ready_indices(u, true)
	_ok(ready.size() == 2 and ready[0] == 0 and ready[1] == 4, "ready = living undoned players [0,4]")
	_ok(BattleFormationCycle.ready_indices([], true).is_empty(), "empty → []")
	_ok(BattleFormationCycle.ready_indices(null, true).is_empty(), "null → []")
	_ok(BattleFormationCycle.next_idx(u, -1) == 0, "next from none → first")
	_ok(BattleFormationCycle.next_idx(u, 0) == 4, "next from 0 → 4")
	_ok(BattleFormationCycle.next_idx(u, 4) == 0, "next from 4 wraps → 0")
	_ok(BattleFormationCycle.prev_idx(u, -1) == 4, "prev from none → last")
	_ok(BattleFormationCycle.prev_idx(u, 4) == 0, "prev from 4 → 0")
	_ok(BattleFormationCycle.prev_idx(u, 0) == 4, "prev from 0 wraps → 4")
	# All done → -1
	var all_done: Array = [
		{"team": "player", "done": true, "char": {"hp": 5}},
		{"team": "enemy", "done": false, "char": {"hp": 5}},
	]
	_ok(BattleFormationCycle.next_idx(all_done, 0) < 0, "all done → no next")
	_ok(Locale.t("formation_next") != "formation_next", "locale formation_next")
	_ok(Locale.t("formation_prev") != "formation_prev", "locale formation_prev")


func _apply_host() -> void:
	var host := _FakeHost.new()
	host.units = _units()
	host.selected = -1
	host.turn_team = "player"
	host.battle_over = false
	add_child(host)
	await _settle()
	var n1: int = BattleFormationCycle.apply_next(host)
	_ok(n1 == 0, "apply_next from none → 0")
	_ok(host.selected == 0, "host.selected=0")
	_ok(host.select_calls == [0], "select called with 0")
	var n2: int = BattleFormationCycle.apply_next(host)
	_ok(n2 == 4 and host.selected == 4, "apply_next → 4")
	var n3: int = BattleFormationCycle.apply_prev(host)
	_ok(n3 == 0 and host.selected == 0, "apply_prev → 0")
	host.battle_over = true
	_ok(BattleFormationCycle.apply_next(host) < 0, "battle_over blocks cycle")
	host.battle_over = false
	host.turn_team = "enemy"
	_ok(BattleFormationCycle.apply_next(host) < 0, "enemy turn blocks cycle")
	host.queue_free()
	await _settle()


func _source_contracts() -> void:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	_ok(ctrl.find("BattleFormationCycle.apply_next") >= 0, "controller Tab → apply_next")
	_ok(ctrl.find("BattleFormationCycle.apply_prev") >= 0, "controller Shift+Tab → apply_prev")
	_ok(ctrl.find("KEY_TAB") >= 0, "controller binds KEY_TAB")
	_ok(ctrl.find("EmptyHost") < 0, "no EmptyHost in controller")
	var bar := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_mobile_bar.gd")
	_ok(bar.find("BattleFormationCycle.apply_next") >= 0, "mobile bar Next button")
	_ok(bar.find("formation_next") >= 0, "mobile bar uses formation_next locale")
	var fc := FileAccess.get_file_as_string("res://scripts/battle/battle_formation_cycle.gd")
	_ok(fc.find("ready_indices") >= 0, "formation cycle has ready_indices")
	_ok(fc.find("next_idx") >= 0 and fc.find("prev_idx") >= 0, "formation cycle has next/prev")


class _FakeHost extends Node:
	var units: Array = []
	var selected: int = -1
	var turn_team: String = "player"
	var battle_over: bool = false
	var select_calls: Array = []

	func _select_player(ui: int) -> void:
		selected = ui
		select_calls.append(ui)
