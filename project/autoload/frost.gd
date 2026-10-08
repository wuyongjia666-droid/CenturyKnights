extends Node
## v8.6: applies the project-wide Frost Theme (Stitch tokens) to the root window.
func _ready() -> void:
	get_tree().root.theme = UIKit.frost_theme()
