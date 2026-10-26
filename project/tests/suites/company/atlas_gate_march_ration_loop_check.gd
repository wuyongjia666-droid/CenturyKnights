extends Node
## Desktop E2E host. The driver lives on the root so city/atlas scene changes survive.

func _ready() -> void:
	await get_tree().process_frame
	var d := Node.new()
	d.name = "GateMarchDriver"
	d.set_script(load("res://tests/suites/company/atlas_gate_march_ration_driver.gd"))
	d.set_meta("phone", false)
	get_tree().root.add_child(d)
