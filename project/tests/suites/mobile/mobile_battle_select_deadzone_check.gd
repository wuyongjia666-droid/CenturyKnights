extends Node
## Mobile gate alias for Y1-A T-P24 select deadzone (real suite lives under battle/).
## Loads and runs the battle suite script so mobile/ CI lane also owns the contract.

func _ready() -> void:
	var suite = load("res://tests/suites/battle/combat_select_deadzone_check.gd")
	if suite == null:
		print("FAIL mobile select deadzone: battle suite missing")
		get_tree().quit(1)
		return
	var node: Node = suite.new()
	add_child(node)
	# The child suite quits the tree itself on pass/fail.
