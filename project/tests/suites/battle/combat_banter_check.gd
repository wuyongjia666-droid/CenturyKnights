extends Node
## Y1-A: BattleBanter extract — source contracts + real escort-map start line.

const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL combat banter: ", err)
		get_tree().quit(1)
		return
	print("COMBAT BANTER PASS")
	get_tree().quit(0)


func _run() -> String:
	var err := _source_contracts()
	if err != "":
		return err
	return await _e2e_start_line()


func _source_contracts() -> String:
	var ctrl := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	var mod := FileAccess.get_file_as_string("res://scripts/battle/battle_banter.gd")
	if ctrl.split("\n").size() > 3000:
		return "battle_controller over 3000 lines"
	if ctrl.find("BattleBanter.play(self, \"start\")") < 0:
		return "controller deploy missing BattleBanter.play start"
	if ctrl.find("BattleBanter.play(self, \"kill\")") < 0:
		return "controller kill missing BattleBanter.play kill"
	if ctrl.find("BattleBanter.play(self, \"turn\")") < 0:
		return "controller turn missing BattleBanter.play turn"
	if ctrl.find("func _theme_banter") >= 0:
		return "controller still has _theme_banter — extract incomplete"
	if ctrl.find("var _banter_pack") >= 0:
		return "controller still has banter state vars"
	if mod.find("class_name BattleBanter") < 0:
		return "battle_banter.gd missing class_name"
	if mod.find("EmptyHost") >= 0:
		return "EmptyHost theater forbidden"
	# i18n ratchet: no CJK literals in new module
	for ch in mod:
		var o := ch.unicode_at(0)
		if o >= 0x4E00 and o <= 0x9FFF:
			return "battle_banter.gd has CJK literal"
	return ""


func _e2e_start_line() -> String:
	BattleBanter.reset()
	OS.set_environment("CK_FORCE_MOBILE", "1")
	DisplayServer.window_set_size(PHONE)
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", "#%02x%02x%02x" % [110, 212, 255])
	GameState.set_meta("battle_map", "ch112_yard")
	var battle: Control = load("res://scenes/battle/battle.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	for _i in range(10):
		await get_tree().process_frame
	if BattleBanter.played_count() < 1:
		battle.queue_free()
		OS.set_environment("CK_FORCE_MOBILE", "0")
		return "escort start banter never played (theme/play wiring)"
	# Second play of same start key must no-op (dedupe)
	var before: int = BattleBanter.played_count()
	BattleBanter.play(battle, "start")
	if BattleBanter.played_count() != before:
		battle.queue_free()
		OS.set_environment("CK_FORCE_MOBILE", "0")
		return "start banter dedupe broken"
	battle.queue_free()
	for _j in range(4):
		await get_tree().process_frame
	OS.set_environment("CK_FORCE_MOBILE", "0")
	return ""
