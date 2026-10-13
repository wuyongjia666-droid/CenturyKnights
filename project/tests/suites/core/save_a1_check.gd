extends Node

const SAVE_SCENE := preload("res://scenes/ui/save_slots.tscn")
## Audit #10/#57: slot cards (empty disabled, real info), failed load says so, autosave flashes.

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL save a1: ", err)
		get_tree().quit(1)
	else:
		print("SAVE A1 PASS")
		get_tree().quit(0)

func _run() -> String:
	for slot in CKSaveService.SLOTS:
		for p in [CKSaveService.body_path(slot), CKSaveService.meta_path(slot)]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var page = SAVE_SCENE.instantiate()
	add_child(page)
	await get_tree().process_frame
	if (page.find_child("SlotMsg", true, false) as Label).text == "":
		return "no-saves state missing"
	if not (page.find_child("Load_manual_0", true, false) as Button).disabled:
		return "empty slot tappable"
	page.queue_free()
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	if not GameState.save_to_slot("manual_1"):
		return "save failed"
	var info: Dictionary = CKSaveSlots.card_info("manual_1")
	if info.state != "ok" or str(info.house) != "灰旗" or str(info.when) == "":
		return "card info %s" % str(info)
	var before := CKAutosave.flashes
	CKAutosave.before_battle()
	if CKAutosave.flashes != before + 1:
		return "autosave did not flash"
	await get_tree().process_frame
	if get_tree().root.get_node_or_null("AutosaveFlash") == null:
		return "flash not on screen"
	# corrupt the body: load must fail with a message, not silently
	var f := FileAccess.open(CKSaveService.body_path("quick"), FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	page = SAVE_SCENE.instantiate()
	add_child(page)
	await get_tree().process_frame
	if (page.find_child("Load_manual_1", true, false) as Button).disabled:
		return "real slot disabled"
	page._load("quick")
	if (page.find_child("SlotMsg", true, false) as Label).text != Locale.t("a1_slot_fail"):
		return "failed load silent"
	if page._loading:
		return "stuck loading after failure"
	return ""
