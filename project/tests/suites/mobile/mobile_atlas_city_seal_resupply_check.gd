extends Node
## Phone twin of atlas_city_seal_resupply_check.

func _ready() -> void:
	await get_tree().process_frame
	var Desk = load("res://tests/suites/company/atlas_city_seal_resupply_check.gd")
	var d = Desk.new()
	add_child(d)
	await d.run_all()
