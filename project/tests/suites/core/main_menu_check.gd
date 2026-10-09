extends Node
## CORE-06: continue summary, empty state, load list, credits, single version source.

func _ready() -> void:
	await get_tree().process_frame
	var fails: Array = []
	_wipe_saves()
	await _open_menu()
	_assert_empty(fails)
	_assert_version(fails)
	_assert_entries(fails)
	await _seed_two_slots()
	await _open_menu()
	_assert_latest(fails)
	await _open_slots(fails)
	if fails.is_empty():
		print("MAIN MENU PASS")
		get_tree().quit(0)
		return
	for f in fails:
		print("FAIL main menu: ", f)
	get_tree().quit(1)

func _wipe_saves() -> void:
	for slot in CKSaveService.SLOTS:
		for suffix in ["", ".meta.json", ".bak1", ".bak2", ".bak3", ".tmp"]:
			var path: String = CKSaveService.body_path(slot) + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _open_menu() -> void:
	await _mount("res://scenes/ui/main_menu.tscn")

func _mount(path: String) -> Node:
	for child in get_children():
		child.free()
	var node := (load(path) as PackedScene).instantiate()
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	return node

func _menu() -> Control:
	return get_child(0) as Control

func _assert_empty(fails: Array) -> void:
	var cont := _menu().find_child("MenuContinue", true, false) as Button
	var summary := _menu().find_child("ContinueSummary", true, false) as Label
	if cont == null or not cont.disabled:
		fails.append("continue should be disabled")
	if summary == null or summary.text != Locale.t("menu_no_save"):
		fails.append("missing empty explanation")

func _assert_version(fails: Array) -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var expect := Locale.t("menu_footer_plain")
	if version != "":
		expect = Locale.t("menu_footer", [version])
	var foot := _menu().find_child("VersionLabel", true, false) as Label
	if foot == null or foot.text != expect:
		fails.append("version label %s" % (foot.text if foot else "missing"))
	if foot != null and foot.text.find("v8.6") >= 0:
		fails.append("hardcoded version")

func _assert_entries(fails: Array) -> void:
	if _menu().find_child("MenuLoad", true, false) == null:
		fails.append("no load")
	if _menu().find_child("MenuCredits", true, false) == null:
		fails.append("no credits")
	if not ResourceLoader.exists("res://scenes/ui/credits.tscn"):
		fails.append("credits scene missing")

func _seed_two_slots() -> void:
	GameState.new_game("甲", "灰旗", GameState.crest_color)
	var leader = GameState.get_leader()
	leader.name = "测名甲"
	GameState.save_to_slot("manual_0")
	OS.delay_msec(1100)
	leader.name = "测名乙"
	GameState.save_to_slot("manual_1")

func _assert_latest(fails: Array) -> void:
	var cont := _menu().find_child("MenuContinue", true, false) as Button
	var summary := _menu().find_child("ContinueSummary", true, false) as Label
	if cont == null or cont.disabled:
		fails.append("continue stayed disabled")
	if summary == null or summary.text.find("测名乙") < 0:
		fails.append("summary %s" % (summary.text if summary else "missing"))

func _open_slots(fails: Array) -> void:
	var scene := await _mount("res://scenes/ui/save_slots.tscn")
	var rows := 0
	for slot in CKSaveService.SLOTS:
		var row := scene.find_child("SlotRow_%s" % slot, true, false)
		var load := scene.find_child("Load_%s" % slot, true, false) as Button
		if row == null or load == null:
			fails.append("row %s" % slot)
			continue
		rows += 1
		if load.custom_minimum_size.y < 44.0:
			fails.append("hit %s" % slot)
	if rows != CKSaveService.SLOTS.size():
		fails.append("rows %d" % rows)
	var newer := scene.find_child("Load_manual_1", true, false) as Button
	var older := scene.find_child("Load_manual_0", true, false) as Button
	var empty := scene.find_child("Load_manual_2", true, false) as Button
	if newer == null or newer.disabled or older == null or older.disabled:
		fails.append("filled slots locked")
	if empty == null or not empty.disabled:
		fails.append("empty slot clickable")
	_wipe_saves()
