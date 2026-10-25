extends Node
## Y1-A T-P10: 伤兵/旗灯双账战斗内可读. Algebra + place E2E.
## Fail-suite (assertions red). No EmptyHost theater; no device gate.

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	if _fails.is_empty():
		print("COMBAT DUAL LEDGER PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL combat dual ledger: ", f)
		get_tree().quit(1)


func _ok(cond: bool, msg: String) -> void:
	print("ROW %s %s" % ["PASS" if cond else "FAIL", msg])
	if not cond:
		_fails.append(msg)


func _settle(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("战旗", "霜旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false


func _run() -> void:
	_boot()
	_algebra()
	await _place_refresh()
	_source_contracts()
	OS.set_environment("CK_FORCE_MOBILE", "0")


func _algebra() -> void:
	var units: Array = [
		{"team": "player", "alive": true, "char": {"injured": true}},
		{"team": "player", "alive": true, "char": {"injured": false}},
		{"team": "player", "alive": false, "char": {"injured": true}},
		{"team": "enemy", "alive": true, "char": {"injured": true}},
	]
	_ok(BattleDualLedger.count_injured(units) == 1, "count only living player injured")
	_ok(BattleDualLedger.count_injured([]) == 0, "empty units → 0")
	_ok(BattleDualLedger.count_injured(null) == 0, "null units → 0")
	var host := _FakeLedgerHost.new()
	host._lamp_charges = 2
	host._lamp_max = 3
	var pair: Vector2i = BattleDualLedger.lamp_pair(host)
	_ok(pair.x == 2 and pair.y == 3, "lamp_pair reads charges/max")
	var line := BattleDualLedger.line_text(1, 2, 3)
	_ok(line.find("1") >= 0 and line.find("2") >= 0 and line.find("3") >= 0, "line_text embeds counts")
	_ok(BattleObjectives.text("dual_ledger_eyebrow") != "dual_ledger_eyebrow", "locale eyebrow present")
	_ok(BattleObjectives.text("dual_ledger_injured") != "dual_ledger_injured", "locale injured present")
	_ok(BattleObjectives.text("dual_ledger_lamp") != "dual_ledger_lamp", "locale lamp present")


func _place_refresh() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE")
	var root := _FakeLedgerHost.new()
	root.name = "BattleRoot"
	root.size = Vector2(720, 1280)
	root.set_meta("mobile_insets", {"top": 40.0, "left": 0.0, "right": 0.0, "bottom": 0.0})
	root.units = [
		{"team": "player", "alive": true, "char": {"injured": true}},
		{"team": "player", "alive": true, "char": {"injured": true}},
		{"team": "player", "alive": true, "char": {"injured": false}},
	]
	root._lamp_charges = 1
	root._lamp_max = 2
	add_child(root)
	await _settle(2)
	BattleDualLedger.attach(root)
	await _settle(2)
	var hud := root.get_node_or_null("BattleDualLedger") as Control
	_ok(hud != null, "attached BattleDualLedger")
	_ok(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ledger ignores mouse")
	_ok(hud.position.y >= 40.0, "mobile respects top inset")
	var inj := hud.get_node_or_null("Row/Injured") as Label
	var lamp := hud.get_node_or_null("Row/Lamp") as Label
	_ok(inj != null and lamp != null, "Injured + Lamp labels")
	_ok(int(hud.get_meta("injured_n", -1)) == 2, "meta injured_n=2")
	_ok(int(hud.get_meta("lamp_cur", -1)) == 1, "meta lamp_cur=1")
	_ok(int(hud.get_meta("lamp_max", -1)) == 2, "meta lamp_max=2")
	_ok(inj.text.find("2") >= 0, "Injured label shows 2")
	_ok(lamp.text.find("1") >= 0 and lamp.text.find("2") >= 0, "Lamp label shows 1/2")
	# Refresh after injury change
	root.units[2]["char"]["injured"] = true
	root._lamp_charges = 0
	BattleDualLedger.refresh(root)
	_ok(int(hud.get_meta("injured_n", -1)) == 3, "refresh injured → 3")
	_ok(int(hud.get_meta("lamp_cur", -1)) == 0, "refresh lamp → 0")
	# Re-attach is idempotent
	BattleDualLedger.attach(root)
	_ok(root.get_node_or_null("BattleDualLedger") == hud, "re-attach keeps same node")
	root.queue_free()
	await _settle(2)


func _source_contracts() -> void:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	_ok(ctrl.find("BattleDualLedger.attach") >= 0, "controller attaches dual ledger")
	_ok(ctrl.find("BattleDualLedger.refresh") >= 0, "controller refreshes dual ledger")
	_ok(ctrl.find("EmptyHost") < 0, "no EmptyHost in controller")
	var snap := FileAccess.get_file_as_string("res://scripts/battle/battle_snapshot.gd")
	_ok(snap.find("BattleDualLedger.refresh") >= 0, "snapshot refreshes dual ledger")
	var led := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_dual_ledger.gd")
	_ok(led.find("MOUSE_FILTER_IGNORE") >= 0, "ledger script ignores mouse")
	_ok(led.find("count_injured") >= 0, "ledger has count_injured")
	_ok(led.find("lamp_pair") >= 0, "ledger has lamp_pair")


class _FakeLedgerHost extends Control:
	var units: Array = []
	var _lamp_charges: int = 0
	var _lamp_max: int = 0
