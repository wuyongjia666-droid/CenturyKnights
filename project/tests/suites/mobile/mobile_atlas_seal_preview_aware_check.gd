extends Node
## Phone twin of atlas_seal_preview_aware_check.

func _ready() -> void:
	await get_tree().process_frame
	var Desk = load("res://tests/suites/company/atlas_seal_preview_aware_check.gd")
	var d = Desk.new()
	add_child(d)
	await d.run_all()
