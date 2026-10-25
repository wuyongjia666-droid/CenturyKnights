extends Node
## Mobile E2E: food=0 → SupplyHaltModal → SupplyForage.

const PHONE := Vector2i(2400, 1080)
const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas supply halt: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE ATLAS SUPPLY FORCED HALT PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	GameState.food = 0
	World.begin_travel("stone_slope")
	World._mark_supply_halt(2)
	World.cancel_travel()
	var page := await _mount_atlas()
	var modal: Node = page.find_child("SupplyHaltModal", true, false)
	if modal == null and page.has_method("_check_supply_halt"):
		if World.last_supply_halt.is_empty():
			World.last_supply_halt = {
				"pos": World.pos, "dest": "stone_slope", "morale": GameState.morale,
				"starved_days": 2, "food": 0,
			}
		page.call("_check_supply_halt")
		for _j in 8:
			await get_tree().process_frame
		modal = page.find_child("SupplyHaltModal", true, false)
	if modal == null:
		page.queue_free()
		return "SupplyHaltModal missing"
	var forage: Button = modal.get_node_or_null("SupplyForage") as Button
	if forage == null:
		page.queue_free()
		return "SupplyForage missing"
	var food0 := GameState.food
	forage.pressed.emit()
	for _k in 12:
		await get_tree().process_frame
	if GameState.food <= food0:
		page.queue_free()
		return "forage did not raise food"
	if page.find_child("SupplyHaltModal", true, false) != null:
		page.queue_free()
		return "modal still open"
	page.queue_free()
	return ""

func _boot() -> void:
	GameState.new_game("手机断粮", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.food = 2
	GameState.silver = 8000
	GameState.morale = 70
	World.pos = "ash_capital"
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_supply_halt.clear()

func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	get_tree().root.content_scale_size = PHONE
	await get_tree().process_frame

func _mount_atlas() -> Control:
	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 14:
		await get_tree().process_frame
	return page
