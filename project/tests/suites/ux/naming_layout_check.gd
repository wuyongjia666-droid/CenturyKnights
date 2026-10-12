extends Node
## Audit #8: naming page fits the design frame; empty names say why instead of doing nothing.

func _ready() -> void:
	var err := await _run()
	print("NAMING LAYOUT PASS" if err == "" else "NAMING LAYOUT FAIL " + err)
	get_tree().quit(0 if err == "" else 1)

func _run() -> String:
	var page: Control = load("res://scenes/story/naming.tscn").instantiate()
	page.size = Vector2(1280, 720)
	add_child(page)
	await get_tree().process_frame
	await get_tree().process_frame
	var frame := Rect2(0, 0, 1280, 720)
	for n in ["StartButton", "FormCard", "PreviewCard", "RandomNation"]:
		var c := page.find_child(n, true, false) as Control
		if c == null:
			return "missing " + n
		if not frame.encloses(c.get_global_rect()):
			return "%s off frame %s" % [n, c.get_global_rect()]
	page._surname.text = ""
	page._on_start()
	if str(page._warn.text) == "":
		return "empty name gave no reason"
	return ""
