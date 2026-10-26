extends Node
## Y1-A T-P14: dual-ledger ready count + injured map cells/marks.
## Fail-suite. No EmptyHost; no device gate.

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	if _fails.is_empty():
		print("COMBAT DUAL LEDGER READY PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL combat dual ledger ready: ", f)
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
	await _place()
	_source_contracts()


func _algebra() -> void:
	var units: Array = [
		{"team": "player", "done": false, "alive": true, "pos": Vector2i(1, 2), "char": {"hp": 10, "injured": true}},
		{"team": "enemy", "done": false, "alive": true, "pos": Vector2i(3, 3), "char": {"hp": 8, "injured": true}},
		{"team": "player", "done": true, "alive": true, "pos": Vector2i(2, 2), "char": {"hp": 9, "injured": false}},
		{"team": "player", "done": false, "alive": true, "pos": Vector2i(4, 1), "char": {"hp": 0, "injured": true}},
		{"team": "player", "done": false, "alive": true, "pos": Vector2i(0, 0), "char": {"hp": 7, "injured": false}},
	]
	_ok(BattleDualLedger.count_ready(units) == 2, "ready = living undoned players (idx 0,4)")
	var ready: Array[int] = BattleDualLedger.ready_indices(units)
	_ok(ready.size() == 2 and ready[0] == 0 and ready[1] == 4, "ready_indices [0,4]")
	_ok(BattleDualLedger.count_ready([]) == 0, "empty ready → 0")
	_ok(BattleDualLedger.count_ready(null) == 0, "null ready → 0")
	var cells: Array[Vector2i] = BattleDualLedger.injured_cells(units)
	_ok(cells.size() == 2, "injured_cells living injured players (idx0+idx3)")
	_ok(cells[0] == Vector2i(1, 2) and cells[1] == Vector2i(4, 1), "injured_cells positions")
	_ok(BattleDualLedger.count_injured(units) == 2, "count_injured = 2")
	_ok(BattleObjectives.text("dual_ledger_ready") != "dual_ledger_ready", "locale dual_ledger_ready")


func _place() -> void:
	var root := _Fake.new()
	root.name = "BattleRoot"
	root.size = Vector2(1280, 720)
	root.units = [
		{"team": "player", "done": false, "alive": true, "pos": Vector2i(1, 1), "char": {"hp": 10, "injured": true}},
		{"team": "player", "done": false, "alive": true, "pos": Vector2i(2, 1), "char": {"hp": 8, "injured": false}},
	]
	root._lamp_charges = 1
	root._lamp_max = 2
	root.turn_team = "player"
	root._board_origin = Vector2(40, 40)
	root._board_cell = 48
	root._board_pan = Vector2.ZERO
	root._board_zoom = 1.0
	add_child(root)
	await _settle()
	BattleDualLedger.attach(root)
	await _settle()
	var hud := root.get_node_or_null(BattleDualLedger.NAME)
	_ok(hud != null, "ledger attached")
	_ok(int(hud.get_meta("ready_n")) == 2, "meta ready_n=2")
	_ok(int(hud.get_meta("injured_n")) == 1, "meta injured_n=1")
	var ready_lbl := hud.get_node_or_null("Row/Ready") as Label
	_ok(ready_lbl != null and ready_lbl.visible and ready_lbl.text.find("2") >= 0, "Ready label shows 2")
	root.turn_team = "enemy"
	BattleDualLedger.refresh(root)
	await _settle()
	_ok(not ready_lbl.visible, "Ready hidden on enemy turn")
	var ov := _DrawProbe.new()
	ov.host = root
	root.add_child(ov)
	ov.queue_redraw()
	await _settle()
	_ok(ov.drew, "draw_injured_marks ran in _draw")
	ov.queue_free()
	root.queue_free()
	await _settle()


func _source_contracts() -> void:
	var led := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_dual_ledger.gd")
	_ok(led.find("count_ready") >= 0, "ledger has count_ready")
	_ok(led.find("injured_cells") >= 0, "ledger has injured_cells")
	_ok(led.find("draw_injured_marks") >= 0, "ledger has draw_injured_marks")
	_ok(led.find("func _hud") >= 0, "ledger has _hud for MobileSide adopt")
	_ok(led.find("EmptyHost") < 0, "no EmptyHost in ledger")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	_ok(ctrl.find("BattleDualLedger.draw_injured_marks") >= 0, "controller draws injured marks")
	_ok(ctrl.find("EmptyHost") < 0, "no EmptyHost in controller")


class _Fake extends Control:
	var units: Array = []
	var turn_team: String = "player"
	var _lamp_charges: int = 0
	var _lamp_max: int = 0
	var _board_origin: Vector2 = Vector2.ZERO
	var _board_cell: int = 48
	var _board_pan: Vector2 = Vector2.ZERO
	var _board_zoom: float = 1.0

	func _get(property: StringName) -> Variant:
		# Duck-type battle_controller ORIGIN/CELL without gdlint class-variable-name.
		if property == &"ORIGIN":
			return _board_origin
		if property == &"CELL":
			return _board_cell
		return null


class _DrawProbe extends Node2D:
	var host = null
	var drew := false

	func _draw() -> void:
		BattleDualLedger.draw_injured_marks(host, self)
		drew = true
