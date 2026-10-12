extends Node
## 属地 → 田册：空态、派工、重复派工、满员失败、交还、按钮高度 ≥48。

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	GameState.new_game("灰", "旗", "frost")
	var scene: Node = load("res://scenes/hub/estates.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	scene.open_field_book()
	await get_tree().process_frame
	var list: Node = scene.find_child("FieldList", true, false)
	if list == null:
		fails.append("no list")
	else:
		var any_open := false
		for hid in GameState.HOLDING_DEFS.keys():
			if GameState.holding_unlocked(hid):
				any_open = true
		if not any_open and not _has_text(list, "还没有开垦"):
			fails.append("empty-land state missing")
	# open a level-1 holding, add a kid
	var hid := str(GameState.HOLDING_DEFS.keys()[0])
	GameState.holdings[hid] = {"level": 1, "steward_id": "", "focus": "cash", "focus_cd": 0}
	var kid := CKCharacter.new()
	kid.id = "fk1"; kid.name = "阿禾"; kid.alive = true; kid.is_child = true; kid.age = 10; kid.blood_meta = {}
	GameState.characters[kid.id] = kid
	var kid2 := CKCharacter.new()
	kid2.id = "fk2"; kid2.name = "阿麦"; kid2.alive = true; kid2.is_child = true; kid2.age = 11; kid2.blood_meta = {}
	GameState.characters[kid2.id] = kid2
	var r1 := CKPurse.assign_field(kid, hid)
	var r1b := CKPurse.assign_field(kid, hid)
	if not bool(r1.get("ok", false)) or not bool(r1b.get("ok", false)):
		fails.append("assign/repeat %s %s" % [r1, r1b])
	var r2 := CKPurse.assign_field(kid2, hid)
	if bool(r2.get("ok", false)):
		fails.append("lv1 should be full")
	CKPurse.set_purse(kid, 5)
	scene._fill_field_list()
	await get_tree().process_frame
	await get_tree().process_frame
	var small := 0
	for b in list.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.get_combined_minimum_size().y < 48:
			small += 1
	if small > 0:
		fails.append("%d buttons under 48px" % small)
	if not _has_text(list, "阿禾"):
		fails.append("kid row missing")
	var s0 := int(GameState.silver)
	scene._field_do(CKPurse.remit_to_flag(kid))
	if int(GameState.silver) != s0 + 5:
		fails.append("remit silver")
	scene.close_field_book()
	if fails.is_empty():
		print("FIELD BOOK PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL field_book: ", f)
	get_tree().quit(1)


func _has_text(n: Node, needle: String) -> bool:
	for l in n.find_children("*", "Label", true, false):
		if needle in str(l.text):
			return true
	return false
