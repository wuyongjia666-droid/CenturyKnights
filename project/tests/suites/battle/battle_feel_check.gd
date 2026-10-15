extends Node
## Mobile battle feel: soft pick, skill chip labels, end-turn confirm, camera focus hooks.

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var err := _check()
	if err == "":
		print("BATTLE FEEL PASS")
		get_tree().quit(0)
	else:
		push_error(err)
		print("FAIL ", err)
		get_tree().quit(1)

func _check() -> String:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := ""
	if not DeviceProfile.is_mobile():
		err = "CK_FORCE_MOBILE did not flip DeviceProfile"
	if err == "":
		err = _source_contracts()
	if err == "":
		err = _soft_pick()
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return err

func _source_contracts() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if ctrl.find("BattlePick.resolve(self, pos)") < 0:
		return "tap arm missing soft pick"
	if ctrl.find("BattlePick.focus_selected(self)") < 0:
		return "select missing camera focus"
	if ctrl.find("skill_pressed.connect(_arm_skill)") < 0:
		return "unit card skill chip not wired"
	if ctrl.find("BattleSkillsUi.cycle(self)") < 0:
		return "cycle_skill not delegated"
	if ctrl.split("\n").size() > 3000:
		return "battle_controller over 3000 lines"
	var bar := FileAccess.get_file_as_string("res://scripts/battle/ui/battle_mobile_bar.gd")
	if bar.find("shell_41ec1a25") < 0 or bar.find("shell_4faa58f5") < 0:
		return "mobile bar missing Art / End turn"
	if bar.find("request_end_turn") < 0:
		return "mobile bar end turn not gated"
	var card := FileAccess.get_file_as_string("res://scripts/ui/unit_card.gd")
	if card.find("signal skill_pressed") < 0 or card.find("skill_pressed.emit") < 0:
		return "unit_card skill press incomplete"
	if card.find("chip, desc") < 0:
		return "unit_card mobile chip text not full name+desc"
	var conf := FileAccess.get_file_as_string("res://scripts/battle/battle_touch_confirm.gd")
	if conf.find("request_end_turn") < 0 or conf.find("EndTurnConfirm") < 0:
		return "end-turn confirm missing"
	if conf.find("BattlePick.focus_cell") < 0:
		return "confirm move/attack missing camera focus"
	return ""

func _soft_pick() -> String:
	var origin := Vector2(40, 80)
	var cell_px := 56.0
	var units: Array = [
		{"char": {"hp": 10}, "pos": Vector2i(2, 2)},
		{"char": {"hp": 10}, "pos": Vector2i(5, 3)},
	]
	# Empty cell (3,2) near the shared edge with unit at (2,2).
	var near := origin + Vector2(3.05, 2.5) * cell_px
	var got: Vector2i = BattlePick.nearest_unit_pos(origin, cell_px, units, near)
	if got != Vector2i(2, 2):
		return "soft pick missed nearby unit: %s" % str(got)
	var far := origin + Vector2(7.5, 5.5) * cell_px
	var empty: Vector2i = BattlePick.nearest_unit_pos(origin, cell_px, units, far)
	if empty == Vector2i(2, 2) or empty == Vector2i(5, 3):
		return "soft pick falsely snapped far tap to a unit"
	return ""
