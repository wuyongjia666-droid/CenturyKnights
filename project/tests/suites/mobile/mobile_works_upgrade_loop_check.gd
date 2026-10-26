extends Node
## Mobile twin: works WorksUpgrade_market under CK_FORCE_MOBILE.

const BID := "market"
const MARKER := "MOBILE WORKS UPGRADE LOOP PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile works upgrade: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await get_tree().process_frame
	GameState.new_game("烬行", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.buildings[BID] = 1
	var cost: Dictionary = CKEconomyState.building_cost(GameState, BID, 2)
	GameState.silver = int(cost.silver) + 50
	GameState.iron = int(cost.iron) + 10
	GameState.food = int(cost.food) + 20
	GameState.house_mods.erase("month_echo")

	var page: Control = load("res://scenes/hub/works.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(390, 844)
	for _i in 12:
		await get_tree().process_frame

	var btn := page.find_child("WorksUpgrade_%s" % BID, true, false) as Button
	if btn == null:
		page.queue_free()
		return "WorksUpgrade_%s missing on mobile" % BID
	if btn.disabled:
		page.queue_free()
		return "mobile WorksUpgrade disabled unexpectedly"
	var before_lv := int(GameState.building_level(BID))
	btn.pressed.emit()
	for _i in 10:
		await get_tree().process_frame
	if int(GameState.building_level(BID)) != before_lv + 1:
		page.queue_free()
		return "mobile upgrade level stuck"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("works", "")) == "":
		page.queue_free()
		return "mobile missing month_echo.works"
	print("ui mobile works ok echo=%s" % str(snap.get("works", "")))
	page.queue_free()
	await get_tree().process_frame
	return ""
