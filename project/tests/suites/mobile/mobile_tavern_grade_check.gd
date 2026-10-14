extends Node
## Recruit roster (招募名册): both the desktop/_card path and landscape _card_mobile
## show 综合评级. Run with CK_FORCE_MOBILE=1 so DeviceProfile.is_mobile() is true.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL tavern grade: ", err)
		get_tree().quit(1)
	else:
		print("TAVERN GRADE PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — run as mobile_* suite (CK_FORCE_MOBILE=1)"
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	if GameState.tavern_candidates.is_empty():
		GameState.refresh_tavern()
	if GameState.tavern_candidates.is_empty():
		return "no candidates"
	# Portrait: MobilePage.active is false → _card (same grade chip as desktop).
	var portrait := await _open(Vector2i(1080, 1920), false)
	if portrait != "":
		return "portrait/_card: " + portrait
	# Landscape: apply_mobile_layout → _card_mobile must also show the grade.
	var landscape := await _open(Vector2i(2400, 1080), true)
	if landscape != "":
		return "landscape/_card_mobile: " + landscape
	return ""

func _open(size: Vector2i, call_mobile_layout: bool) -> String:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = size
	await get_tree().process_frame
	await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/hub/tavern.tscn")
	if packed == null:
		return "load failed"
	var page: Control = packed.instantiate()
	win.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(size)
	for _i in 3:
		await get_tree().process_frame
	if call_mobile_layout:
		if not page.has_method("apply_mobile_layout"):
			page.queue_free()
			return "no apply_mobile_layout"
		page.apply_mobile_layout()
		for _j in 2:
			await get_tree().process_frame
		if page.find_child("MobileTopBar", true, false) == null:
			page.queue_free()
			return "MobileTopBar missing (landscape mobile layout not applied)"
	var grades: Array = []
	_collect_grades(page, grades)
	page.queue_free()
	await get_tree().process_frame
	if grades.is_empty():
		return "OverallGrade missing"
	if grades.size() < mini(3, GameState.tavern_candidates.size()):
		return "expected one grade per card, got %d" % grades.size()
	for t in grades:
		if not str(t).begins_with("综合评级："):
			return "bad label %s" % t
		var g := str(t).substr("综合评级：".length())
		if g not in ["S", "A", "B", "C"]:
			return "bad letter %s" % t
	return ""

func _collect_grades(n: Node, out: Array) -> void:
	if n is Label and str(n.name) == "OverallGrade":
		out.append((n as Label).text)
	for c in n.get_children():
		_collect_grades(c, out)
