extends Node

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	GameState.new_game("灰", "旗", "frost")
	CKTodoCenter.reset_for_tests()
	# no todos initially ideally
	var snap := CKTodoCenter.snapshot()
	for row in snap:
		if str(row.get("category", "")) == "train":
			fails.append("train chip still present")
		if str(row.get("category", "")) == "festival":
			fails.append("festival chip without card")
	# inject pending sui ke
	GameState.house_mods["sui_pending"] = [{"cid": "x", "id": "ill_tooth"}]
	var snap2 := CKTodoCenter.snapshot()
	var found := false
	for row2 in snap2:
		if str(row2.get("category", "")) == "sui_ke" and int(row2.get("count", 0)) == 1:
			found = true
	if not found:
		fails.append("sui_ke chip missing %s" % str(snap2))
	var empty := CKTodoCenter.snapshot_or_empty_label()
	GameState.house_mods["sui_pending"] = []
	var empty2 := CKTodoCenter.snapshot_or_empty_label()
	# may still have tutor chips etc — just ensure helper works
	if typeof(empty2) != TYPE_DICTIONARY:
		fails.append("empty helper")
	if fails.is_empty():
		print("TODO V92 PASS")
		get_tree().quit(0)
	else:
		for f in fails:
			print("FAIL todo: ", f)
		get_tree().quit(1)
