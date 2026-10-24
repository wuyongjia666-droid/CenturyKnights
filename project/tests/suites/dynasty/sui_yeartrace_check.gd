extends Node
## Y1-B season-01 deepen: birthday resolve → durable 岁课年迹 survives inbox ack;
## unit dossier exposes YeartracePanel with at least one line.

func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL sui_yeartrace: ", err)
		get_tree().quit(1)
	else:
		print("SUI YEARTRACE PASS")
		get_tree().quit(0)


func _run() -> String:
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	CKSuiKe.ensure()
	GameState.house_mods["sui_inbox"] = []
	GameState.house_mods["sui_pending"] = []
	GameState.house_mods["sui_yeartrace"] = []

	var leader := GameState.get_leader()
	if leader == null:
		return "no leader"
	leader.in_roster = true
	leader.alive = true

	var target_m := Calendar.month + 1
	var target_y := Calendar.year
	if target_m > 12:
		target_m = 1
		target_y += 1

	var kid := CKCharacter.new()
	kid.id = "kid_yt"
	kid.name = "年迹孩"
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

	Calendar.advance(1)
	await get_tree().process_frame
	if Calendar.month != target_m or Calendar.year != target_y:
		return "calendar landed %d-%d want %d-%d" % [Calendar.year, Calendar.month, target_y, target_m]
	var seed_err := _assert_seeded(kid.id)
	if seed_err != "":
		return seed_err
	var card_id := str(CKSuiKe.yeartrace_for(kid.id)[0].get("id", ""))

	# Ack clears inbox; yeartrace must remain.
	var rows: Array = CKSuiKe.inbox().duplicate()
	for item in rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		CKSuiKe.ack(str(item.get("cid", "")), str(item.get("id", "")))
	var persist_err := _assert_persists(kid.id, card_id)
	if persist_err != "":
		return persist_err
	return await _assert_dossier(kid.id)


func _assert_seeded(kid_id: String) -> String:
	if CKSuiKe.inbox_count() < 1:
		return "inbox empty after birthday"
	if CKSuiKe.yeartrace_count() < 1:
		return "yeartrace empty after resolve"
	var for_kid: Array = CKSuiKe.yeartrace_for(kid_id)
	if for_kid.is_empty():
		return "yeartrace_for kid empty"
	if str(for_kid[0].get("title", "")) == "":
		return "yeartrace title empty"
	return ""


func _assert_persists(kid_id: String, card_id: String) -> String:
	if CKSuiKe.inbox_count() != 0:
		return "inbox not cleared after ack (%d)" % CKSuiKe.inbox_count()
	if CKSuiKe.yeartrace_for(kid_id).is_empty():
		return "yeartrace wiped by ack"
	for it in CKSuiKe.yeartrace_for(kid_id):
		if str(it.get("id", "")) == card_id:
			return ""
	return "yeartrace lost card_id %s" % card_id


func _assert_dossier(kid_id: String) -> String:
	GameState.set_meta("dossier_id", kid_id)
	var packed: PackedScene = load("res://scenes/hub/unit_dossier.tscn")
	if packed == null:
		return "dossier load failed"
	var page: Control = packed.instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 8:
		await get_tree().process_frame
	var panel := page.find_child("YeartracePanel", true, false)
	if panel == null:
		page.queue_free()
		return "YeartracePanel missing"
	var line := page.find_child("Yeartrace_0", true, false)
	if line == null:
		page.queue_free()
		return "Yeartrace_0 missing"
	page.queue_free()
	await get_tree().process_frame
	return ""
