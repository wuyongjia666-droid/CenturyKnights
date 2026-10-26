extends Control
## Live battle initiative strip. CKHeraldryField owns the shields.
## Repaints when turn, wounds, or done flags change. Never takes taps.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var host := get_parent()
	if host == null:
		return
	CKHeraldryField.fill_battle_order(self, host)
