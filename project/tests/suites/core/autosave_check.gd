extends Node
## CORE-04: background autosave, monthly throttle, pause menu hit size, frozen board input.

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_background(fails)
	_months(fails)
	await _pause(fails)
	if fails.is_empty():
		print("AUTOSAVE PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL autosave: ", f)
	get_tree().quit(1)

func _background(fails: Array) -> void:
	GameState.new_game("灯影", "灰旗", GameState.crest_color)
	if not GameState.save_to_slot("auto"):
		fails.append("seed auto")
		return
	var path := CKSaveService.body_path("auto")
	var before := int(FileAccess.get_modified_time(path))
	OS.delay_msec(1100)
	GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var after := int(FileAccess.get_modified_time(path))
	if after <= before:
		fails.append("paused mtime %d -> %d" % [before, after])

func _months(fails: Array) -> void:
	CKAutosave.reset_throttle()
	Calendar.advance(12)
	if CKAutosave.month_writes < 1 or CKAutosave.month_writes > 12:
		fails.append("month writes %d" % CKAutosave.month_writes)

func _pause(fails: Array) -> void:
	CKPauseMenu.toggle()
	await get_tree().process_frame
	var menu := CKPauseMenu.current
	if menu == null:
		fails.append("pause missing")
		return
	var hit := DeviceProfile.hit_px()
	for spec in CKPauseMenu.BUTTONS:
		var b := menu.find_child(spec[0], true, false) as Button
		if b == null:
			fails.append("missing %s" % spec[0])
			continue
		if b.custom_minimum_size.y + 0.01 < hit or b.custom_minimum_size.y < 44.0:
			fails.append("%s hit %.1f want %.1f" % [spec[0], b.custom_minimum_size.y, hit])
	var router := InputRouter.new()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(32, 32)
	if not CKPauseMenu.board_events(router, click, 0).is_empty():
		fails.append("board click leaked while paused")
	CKPauseMenu.toggle()
	await get_tree().process_frame
	if CKPauseMenu.board_events(router, click, 1).is_empty():
		fails.append("board click swallowed after resume")
