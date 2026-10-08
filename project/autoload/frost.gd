extends Node
## v8.6: applies the project-wide Frost Theme (Stitch tokens) to the root window.
## Headless CI does not spawn lamp tips; a windowed session does, once per id.
func _ready() -> void:
	get_tree().root.theme = UIKit.frost_theme()
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if node != get_tree().current_scene:
		return
	call_deferred("_present_tip")

func _present_tip() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	CKTips.maybe_present(scene)
