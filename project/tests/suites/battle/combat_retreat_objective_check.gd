extends Node
## Y1-A T-P18: 撤退确认 + 目标条闭环. Algebra + ObjectiveHud arm/disarm E2E.
## Fail-suite (assertions red). No EmptyHost theater; no device gate.

var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	if _fails.is_empty():
		print("COMBAT RETREAT OBJECTIVE PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			print("FAIL combat retreat objective: ", f)
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
	await _arm_disarm_hud()
	_source_contracts()
	OS.set_environment("CK_FORCE_MOBILE", "0")


func _algebra() -> void:
	_ok(BattleRetreatObjective.compose_detail("敌军 3", false) == "敌军 3", "compose unarmed keeps base")
	_ok(BattleRetreatObjective.compose_detail("", false) == "", "compose empty unarmed")
	var armed_empty := BattleRetreatObjective.compose_detail("", true)
	_ok(armed_empty.find("撤退") >= 0 or armed_empty.find("retreat") >= 0 or armed_empty != "", "compose empty armed → warn")
	var armed_base := BattleRetreatObjective.compose_detail("敌军 3", true)
	_ok(armed_base.find("敌军 3") >= 0, "compose armed keeps objective")
	_ok(armed_base.find("·") >= 0, "compose armed joins with ·")
	_ok(BattleRetreatObjective.detail_color(true) == UIKit.DANGER, "armed color DANGER")
	_ok(BattleRetreatObjective.detail_color(false) == UIKit.ACCENT, "idle color ACCENT")
	_ok(BattleObjectives.text("obj_retreat_armed") != "obj_retreat_armed", "locale obj_retreat_armed present")
	_ok(not BattleRetreatObjective.is_armed(null), "null host not armed")
	var ghost := Node.new()
	_ok(not BattleRetreatObjective.is_armed(ghost), "fresh node not armed")
	ghost.queue_free()


func _arm_disarm_hud() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	_ok(DeviceProfile.is_mobile(), "CK_FORCE_MOBILE")
	var root := _FakeBattleHost.new()
	root.name = "BattleRoot"
	root.size = Vector2(720, 1280)
	root.set_meta("mobile_insets", {"top": 40.0, "left": 0.0, "right": 0.0, "bottom": 0.0})
	root.map_id = "ch0_pass"
	root._round_no = 1
	root.units = [
		{"team": "player", "alive": true, "char": {"hp": 10, "max_hp": 10}},
		{"team": "enemy", "alive": true, "char": {"hp": 8, "max_hp": 8}},
		{"team": "enemy", "alive": true, "char": {"hp": 8, "max_hp": 8}},
	]
	add_child(root)
	await _settle(2)
	ObjectiveHud.attach(root)
	await _settle(2)
	var hud := root.get_node_or_null("ObjectiveHud") as Control
	_ok(hud != null, "ObjectiveHud attached")
	_ok(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ObjectiveHud ignores mouse")
	var detail := hud.get_node_or_null("Row/Detail") as Label
	_ok(detail != null, "Detail label present")
	var base_text := detail.text
	_ok(not BattleRetreatObjective.is_armed(root), "starts unarmed")
	_ok(not bool(hud.get_meta("retreat_armed", false)), "hud meta unarmed")

	BattleRetreatObjective.arm(root)
	_ok(BattleRetreatObjective.is_armed(root), "arm sets meta")
	_ok(bool(hud.get_meta("retreat_armed", false)), "hud meta armed after refresh")
	_ok(detail.text != base_text or base_text.find("撤退") >= 0 or detail.text.find("·") >= 0, "detail changes or already warn")
	_ok(detail.text.find("·") >= 0 or detail.text == BattleObjectives.text("obj_retreat_armed"), "armed detail has warn")
	_ok(detail.get_theme_color("font_color") == UIKit.DANGER, "armed detail DANGER")

	# Re-arm idempotent
	BattleRetreatObjective.arm(root)
	_ok(BattleRetreatObjective.is_armed(root), "re-arm stays armed")

	BattleRetreatObjective.disarm(root)
	_ok(not BattleRetreatObjective.is_armed(root), "disarm clears meta")
	_ok(not bool(hud.get_meta("retreat_armed", false)), "hud meta cleared")
	_ok(detail.get_theme_color("font_color") == UIKit.ACCENT, "disarm restores ACCENT")
	_ok(detail.text.find(BattleObjectives.text("obj_retreat_armed")) < 0, "warn gone after disarm")

	# Close-without-confirm: arm then disarm restores strip (pause _exit_tree path).
	BattleRetreatObjective.arm(root)
	_ok(BattleRetreatObjective.is_armed(root), "armed before cancel-close")
	BattleRetreatObjective.disarm(root)
	_ok(not BattleRetreatObjective.is_armed(root), "cancel-close disarms")
	_ok(detail.get_theme_color("font_color") == UIKit.ACCENT, "cancel-close restores ACCENT")

	# Confirm-path algebra: arm → DefeatReturn.retreat sets verdict (FakeHost stubs _finish)
	BattleRetreatObjective.arm(root)
	_ok(BattleRetreatObjective.is_armed(root), "re-arm before confirm")
	root.battle_over = false
	var ok_retreat: bool = BattleDefeat.retreat(root)
	_ok(ok_retreat, "BattleDefeat.retreat accepts FakeHost")
	_ok(root.battle_over, "retreat finishes battle")
	var verdict: Dictionary = root.get_meta("battle_verdict", {})
	_ok(str(verdict.get("reason", "")) == "retreat", "verdict reason=retreat")
	_ok(str(verdict.get("result", "")) == "lose", "verdict result=lose")
	# After confirmed retreat, strip may stay armed until scene teardown — battle_over gates disarm.
	_ok(root.battle_over, "confirm path leaves battle_over so pause exit skips disarm")

	root.queue_free()
	await _settle(2)


func _source_contracts() -> void:
	var pause := FileAccess.get_file_as_string("res://scripts/core/pause_menu.gd")
	_ok(pause.find("BattleRetreatObjective.arm") >= 0, "pause arms on first retreat tap")
	_ok(pause.find("BattleRetreatObjective.disarm") >= 0, "pause disarms on close")
	_ok(pause.find("retreat_confirmed") >= 0, "pause uses retreat_confirmed gate")
	_ok(pause.find("set_meta(\"retreat_confirmed\", true)") >= 0, "confirm sets retreat_confirmed on self")
	_ok(pause.find("EmptyHost") < 0, "no EmptyHost in pause")
	var oh := FileAccess.get_file_as_string("res://scripts/battle/ui/objective_hud.gd")
	_ok(oh.find("BattleRetreatObjective.compose_detail") >= 0, "ObjectiveHud composes retreat detail")
	_ok(oh.find("BattleRetreatObjective.detail_color") >= 0, "ObjectiveHud uses retreat color")
	_ok(oh.find("MOUSE_FILTER_IGNORE") >= 0, "ObjectiveHud ignores mouse")
	var ro := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_retreat_objective.gd")
	_ok(ro.find("compose_detail") >= 0, "retreat helper has compose_detail")
	_ok(ro.find("META") >= 0, "retreat helper has META")
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	_ok(ctrl.find("EmptyHost") < 0, "no EmptyHost in controller")


class _FakeBattleHost extends Control:
	signal battle_finished(result)
	var map_id: String = "ch0_pass"
	var units: Array = []
	var _round_no: int = 1
	var battle_over: bool = false

	func _finish(win: bool) -> void:
		battle_over = true
		battle_finished.emit({"win": win})
