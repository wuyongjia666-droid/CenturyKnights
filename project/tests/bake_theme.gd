extends Node
## v8.6: bake UIKit.frost_theme() into the project theme (project.godot theme/custom). Run:
##   godot --headless --path . res://tests/bake_theme.tscn
func _ready() -> void:
	var t: Theme = UIKit.frost_theme()
	var err := ResourceSaver.save(t, "res://assets/ui/theme.tres")
	print("BAKE_FROST_THEME ", err)
	get_tree().quit(err)
