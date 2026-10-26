extends Node
## Phone twin of atlas_seal_bypass_chip_check.

func _ready() -> void:
	if get_parent() != get_tree().root and get_parent() != null:
		return
	var Desk = load("res://tests/suites/company/atlas_seal_bypass_chip_check.gd")
	var n: Node = Desk.new()
	add_child(n)
	await n.run_all()
