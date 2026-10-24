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
	if CKSuiKe.inbox_count() < 1:
		return "inbox empty after birthday"
	if CKSuiKe.yeartrace_count() < 1:
		return "yeartrace empty after resolve"
	var for_kid: Array = CKSuiKe.yeartrace_for(kid.id)
	if for_kid.is_empty():
		return "yeartrace_for kid empty"
	var entry: Dictionary = for_kid[0]
	if str(entry.get("title", "")) == "":
		return "yeartrace title empty"
	var card_id := str(entry.get("id", ""))

	# Ack clears inbox; yeartrace must remain.
	var rows: Array = CKSuiKe.inbox().duplicate()
	for item in rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		CKSuiKe.ack(str(item.get("cid", "")), str(item.get("id", "")))
	if CKSuiKe.inbox_count() != 0:
		return "inbox not cleared after ack (%d)" % CKSuiKe.inbox_count()
	if CKSuiKe.yeartrace_for(kid.id).is_empty():
		return "yeartrace wiped by ack"
	# Same card id still present.
	var still := false
	for it in CKSuiKe.yeartrace_for(kid.id):
		if str(it.get("id", "")) == card_id:
			still = true
			break
	if not still:
		return "yeartrace lost card_id %s" % card_id

	# Dossier UI: YeartracePanel + Yeartrace_0
	GameState.set_meta("dossier_id", kid.id)
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
