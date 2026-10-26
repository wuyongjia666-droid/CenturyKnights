extends Node
## Phone E2E of the winter-seal detour. Named mobile_* so CI sets CK_FORCE_MOBILE=1.

const PHONE := Vector2i(2400, 1080)

func _ready() -> void:
	var err := ""
	if not DeviceProfile.is_mobile():
		err = "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	if err == "":
		await _set_phone_window()
		var driver := preload("res://tests/suites/company/atlas_road_seal_loop_driver.gd").new()
		add_child(driver)
		await driver.run_all()
		if not driver.fails.is_empty():
			err = ", ".join(driver.fails)
	if err != "":
		print("FAIL mobile road seal: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ROAD SEAL LOOP PASS")
		get_tree().quit(0)

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame
