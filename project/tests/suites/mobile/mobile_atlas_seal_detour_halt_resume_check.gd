extends Node
## Phone twin of atlas_seal_detour_halt_resume_check.

func _ready() -> void:
	await get_tree().process_frame
	var Desk = load("res://tests/suites/company/atlas_seal_detour_halt_resume_check.gd")
	var d = Desk.new()
	# Parent is this node (not root) so desk _ready no-ops; we drive run_all.
	add_child(d)
	await d.run_all()
