extends Node
## Mobile E2E host. CK_FORCE_MOBILE=1 is set by the suite runner.

func _ready() -> void:
	await get_tree().process_frame
	var d := Node.new()
	d.name = "GateMarchDriver"
	d.set_script(load("res://tests/suites/company/atlas_gate_march_ration_driver.gd"))
	d.set_meta("phone", true)
	get_tree().root.add_child(d)
