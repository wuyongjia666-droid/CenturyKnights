extends Node
## Mobile E2E: road merc hire → MarchMusterModal (true play via EventOpt0).

const PHONE := Vector2i(2400, 1080)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas road merc muster: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS ROAD MERC MUSTER PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	World.make_event("merc", "ash_capital", "stone_slope")
	var p_before := World.party_size()
	var page := await _mount_atlas()
	var opt: Button = page.find_child("EventOpt0", true, false) as Button
	if opt == null:
		page.queue_free()
		return "EventOpt0 missing"
	opt.pressed.emit()
	var saw := false
	for _i in 90:
		await get_tree().process_frame
		var af: Button = page.find_child("AftermathContinue", true, false) as Button
		if af != null:
			af.pressed.emit()
			continue
		var modal: Node = page.find_child("MarchMusterModal", true, false)
		if modal != null:
			saw = true
			var ok_btn: Button = modal.find_child("MarchMusterOk", true, false) as Button
			if ok_btn == null:
				page.queue_free()
				return "MarchMusterOk missing"
			ok_btn.pressed.emit()
			for _j in 10:
				await get_tree().process_frame
			break
	if not saw:
		page.queue_free()
		return "MarchMusterModal missing"
	if World.party_size() != p_before + 1:
		page.queue_free()
		return "party did not grow"
	page.queue_free()
	return ""

func _boot() -> void:
	GameState.new_game("MobMercMuster", "AshBanner", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.food = 100
	GameState.silver = 500
	GameState.morale = 70
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_march_muster = {}

func _mount_atlas() -> Node:
	var page: Node = ATLAS_SCN.instantiate()
	add_child(page)
	for _i in 16:
		await get_tree().process_frame
	return page

func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	await get_tree().process_frame
