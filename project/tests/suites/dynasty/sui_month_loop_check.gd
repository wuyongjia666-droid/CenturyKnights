extends Node
## Y1-B endurance: birthday month → auto-resolve 岁课 → inbox → yearcard UI → ack
## clears todo. End-to-end month-loop smoke (no content-season novel).

func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL sui month loop: ", err)
		get_tree().quit(1)
	else:
		print("SUI MONTH LOOP PASS")
		get_tree().quit(0)


func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	CKSuiKe.ensure()
	GameState.house_mods["sui_inbox"] = []
	GameState.house_mods["sui_pending"] = []

	var leader := GameState.get_leader()
	if leader == null:
		return "no leader"
	leader.in_roster = true
	leader.alive = true

	# advance() ticks the NEXT month; aim birthday at that month.
	var target_m := Calendar.month + 1
	var target_y := Calendar.year
	if target_m > 12:
		target_m = 1
		target_y += 1

	var kid := CKCharacter.new()
	kid.id = "kid_loop"
	kid.name = "岁课孩"
	kid.alive = true
	kid.is_child = true
	kid.age = 4
	kid.birthday_month = target_m
	kid.parent_ids = [leader.id]
	kid.traits = ["scholar"]
	kid.apt_max = {"str": 20, "vit": 20, "skl": 20, "agi": 20, "per": 20, "wil": 20}
	kid.stats = {"str": 6, "vit": 7, "skl": 10, "agi": 6, "per": 11, "wil": 12}
	kid.blood_meta = {"purse": 40}
	kid.in_roster = false
	GameState.characters[kid.id] = kid
	GameState.lineage_path[kid.id] = "scholar"

	var before := CKSuiKe.inbox_count()
	Calendar.advance(1)
	await get_tree().process_frame
	if Calendar.month != target_m or Calendar.year != target_y:
		return "calendar landed %d-%d want %d-%d" % [Calendar.year, Calendar.month, target_y, target_m]
	if int(kid.age) != 5:
		return "age after birthday %d" % int(kid.age)
	var n := CKSuiKe.inbox_count()
	if n < 1:
		return "inbox empty after birthday (before=%d pending=%s)" % [
			before, str(GameState.house_mods.get("sui_pending", []))]
	var todo_n := _todo_sui_count()
	if todo_n < 1:
		return "todo sui_ke count %d" % todo_n

	var packed: PackedScene = load("res://scenes/hub/sui_yearcard.tscn")
	if packed == null:
		return "yearcard load failed"
	var page: Control = packed.instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame
	if page.has_method("apply_mobile_layout"):
		page.apply_mobile_layout()
		for _j in 3:
			await get_tree().process_frame
	var list := page.find_child("SuiRows", true, false) as VBoxContainer
	if list == null:
		page.queue_free()
		return "no SuiRows"
	if list.get_child_count() < 1:
		page.queue_free()
		return "yearcard empty rows"
	# Ack every inbox item (UI path uses the same CKSuiKe.ack).
	var rows: Array = CKSuiKe.inbox().duplicate()
	for item in rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		CKSuiKe.ack(str(item.get("cid", "")), str(item.get("id", "")))
	if page.has_method("_fill"):
		page.call("_fill")
	for _k in 3:
		await get_tree().process_frame
	page.queue_free()
	await get_tree().process_frame

	if CKSuiKe.inbox_count() != 0:
		return "inbox not cleared after ack (%d)" % CKSuiKe.inbox_count()
	if _todo_sui_count() != 0:
		return "todo sui_ke still %d" % _todo_sui_count()
	return ""


func _todo_sui_count() -> int:
	for item in CKTodoCenter.snapshot():
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("category", "")) == "sui_ke":
			return int(item.get("count", 0))
	return 0
