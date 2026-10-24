extends Node
## Y1-B: lineage_view info + bloodline_codex expose clickable YeartracePanel rows.

func _ready() -> void:
	await get_tree().process_frame
	var err := await _run()
	if err != "":
		print("FAIL sui_yeartrace_lineage: ", err)
		get_tree().quit(1)
	else:
		print("SUI YEARTRACE LINEAGE PASS")
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
	kid.id = "kid_yt_lin"
	kid.name = "族谱年迹孩"
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
	if CKSuiKe.yeartrace_for(kid.id).is_empty():
		return "yeartrace not seeded"

	var lin_err := await _assert_lineage(kid.id)
	if lin_err != "":
		return lin_err
	return await _assert_codex(kid.id)


func _assert_lineage(kid_id: String) -> String:
	var packed: PackedScene = load("res://scenes/hub/lineage_view.tscn")
	if packed == null:
		return "lineage_view load failed"
	var page: Control = packed.instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame
	var avatar := page.find_child("Avatar_%s" % kid_id, true, false)
	if avatar == null:
		# Some builds name cards differently — select via script API.
		if page.has_method("select"):
			var ch = GameState.characters.get(kid_id)
			if ch != null:
				page.select(ch)
				for _j in 6:
					await get_tree().process_frame
		else:
			page.queue_free()
			await get_tree().process_frame
			return "Avatar_%s missing" % kid_id
	else:
		if avatar.has_signal("pressed"):
			avatar.emit_signal("pressed")
		elif avatar is BaseButton:
			(avatar as BaseButton).pressed.emit()
		else:
			# Fallback: click via select
			if page.has_method("select"):
				page.select(GameState.characters[kid_id])
		for _j in 6:
			await get_tree().process_frame
	var panel := page.find_child("YeartracePanel", true, false)
	if panel == null:
		page.queue_free()
		await get_tree().process_frame
		return "lineage YeartracePanel missing"
	var line := page.find_child("Yeartrace_0", true, false)
	if line == null:
		page.queue_free()
		await get_tree().process_frame
		return "lineage Yeartrace_0 missing"
	if not (line is BaseButton):
		page.queue_free()
		await get_tree().process_frame
		return "lineage Yeartrace_0 not clickable"
	page.queue_free()
	await get_tree().process_frame
	return ""


func _assert_codex(kid_id: String) -> String:
	var packed: PackedScene = load("res://scenes/hub/bloodline_codex.tscn")
	if packed == null:
		return "bloodline_codex load failed"
	var page: Control = packed.instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1280, 720)
	for _i in 10:
		await get_tree().process_frame
	var panel := page.find_child("YeartracePanel", true, false)
	if panel == null:
		page.queue_free()
		await get_tree().process_frame
		return "codex YeartracePanel missing"
	var head := page.find_child("YeartraceHouseHead", true, false)
	if head == null:
		page.queue_free()
		await get_tree().process_frame
		return "codex YeartraceHouseHead missing"
	var line := page.find_child("Yeartrace_0", true, false)
	if line == null:
		page.queue_free()
		await get_tree().process_frame
		return "codex Yeartrace_0 missing"
	if not (line is BaseButton):
		page.queue_free()
		await get_tree().process_frame
		return "codex Yeartrace_0 not clickable"
	if str(line.get_meta("yeartrace_cid", "")) != kid_id:
		page.queue_free()
		await get_tree().process_frame
		return "codex Yeartrace_0 cid mismatch"
	page.queue_free()
	await get_tree().process_frame
	return ""
