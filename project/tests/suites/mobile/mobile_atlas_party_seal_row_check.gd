extends Node
## Phone twin of atlas_party_seal_row_check.

func _ready() -> void:
	if get_parent() != get_tree().root and get_parent() != null:
		return
	var Desk = load("res://tests/suites/company/atlas_party_seal_row_check.gd")
	var n: Node = Desk.new()
	add_child(n)
	await n.run_all()
