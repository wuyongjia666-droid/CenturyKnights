extends Node
## Desktop E2E: winter-sealed pass, detour march, arrival sheet, city market.

func _ready() -> void:
	await get_tree().process_frame
	var driver := preload("res://tests/suites/company/atlas_road_seal_loop_driver.gd").new()
	add_child(driver)
	await driver.run_all()
	if driver.fails.is_empty():
		print("ROAD SEAL LOOP PASS")
		get_tree().quit(0)
	else:
		for f in driver.fails:
			print("FAIL road seal: ", f)
		get_tree().quit(1)
