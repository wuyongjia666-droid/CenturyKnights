extends Node
## Battle scene writes the auto slot around a fight and routes board input through the pause menu.

var _battle


func _ready() -> void:
	var err := _source()
	if err == "":
		err = await _runtime()
	if err != "":
		print("FAIL autosave wire: ", err)
		get_tree().quit(1)
		return
	print("AUTOSAVE WIRE PASS")
	get_tree().quit(0)


func _source() -> String:
	var src := FileAccess.get_file_as_string("res://scripts/battle/battle_controller.gd")
	if src.find("CKPauseMenu.board_events(_board_router, event, Time.get_ticks_msec())") < 0:
		return "board_events call"
	if src.find("_board_router.push(") >= 0:
		return "raw push remains"
	var before_at := src.find("CKAutosave.before_battle()")
	var deploy_at := src.find("\t_deploy()")
	if before_at < 0 or deploy_at < 0 or before_at > deploy_at:
		return "before_battle order"
	var save_at := src.find("GameState.save_game()")
	var after_at := src.find("CKAutosave.after_battle()")
	if save_at < 0 or after_at < save_at:
		return "after_battle order"
	return ""


func _runtime() -> String:
	var auto_path := "user://saves/auto.json"
	var manual_path := "user://century_knights_save.json"
	var backup := ""
	var had := FileAccess.file_exists(auto_path)
	if had:
		backup = FileAccess.get_file_as_string(auto_path)
	var manual_backup := ""
	var had_manual := FileAccess.file_exists(manual_path)
	if had_manual:
		manual_backup = FileAccess.get_file_as_string(manual_path)
	GameState.new_game("探针", "灰旗", "#" + "6ED4FF")
	GameState.set_meta("battle_map", "obj_rout")
	GameState.set_meta("cutscenes_on", false)
	GameState.settings["cutscenes"] = false
	var silver0 := int(GameState.silver)
	_battle = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if not FileAccess.file_exists(auto_path):
		_restore(auto_path, had, backup)
		_restore(manual_path, had_manual, manual_backup)
		return "missing auto slot before battle"
	var before_silver := _silver_in(auto_path)
	if before_silver != silver0:
		_restore(auto_path, had, backup)
		_restore(manual_path, had_manual, manual_backup)
		return "before silver %s" % before_silver
	GameState.board_input_blocked = true
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = Vector2(240, 240)
	var swallowed: Array = CKPauseMenu.board_events(_battle._board_router, ev, Time.get_ticks_msec())
	GameState.board_input_blocked = false
	if not swallowed.is_empty():
		_restore(auto_path, had, backup)
		_restore(manual_path, had_manual, manual_backup)
		return "pause did not swallow board input"
	_battle._finish(true)
	var after_silver := _silver_in(auto_path)
	_restore(auto_path, had, backup)
	_restore(manual_path, had_manual, manual_backup)
	if after_silver <= silver0:
		return "after silver %s" % after_silver
	return ""


func _silver_in(path: String) -> int:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return -1
	return int(parsed.get("silver", -1))


func _restore(path: String, had: bool, backup: String) -> void:
	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(backup)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
