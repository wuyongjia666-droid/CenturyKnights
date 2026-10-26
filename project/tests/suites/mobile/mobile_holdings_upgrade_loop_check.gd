extends Node
## Mobile twin: estates HoldingUpgrade_ under CK_FORCE_MOBILE.

const HID := "reed_ford"
const MARKER := "MOBILE HOLDINGS UPGRADE LOOP PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile holdings upgrade: ", err)
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
	GameState.holdings.clear()
	GameState.unlock_holding(HID)
	if not GameState.holdings.has(HID):
		GameState.holdings[HID] = {"level": 1, "focus": "grain", "steward_id": "", "patrol_boost": 0, "patrol_cd": 0}
	GameState.holdings[HID]["level"] = 1
	GameState.holdings[HID]["focus"] = "grain"
	GameState.silver = 200
	GameState.food = 80
	GameState.house_mods.erase("month_echo")

	var page: Control = load("res://scenes/hub/estates.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(390, 844)
	for _i in 12:
		await get_tree().process_frame

	var btn := page.find_child("HoldingUpgrade_%s" % HID, true, false) as Button
	if btn == null:
		page.queue_free()
		return "HoldingUpgrade_%s missing on mobile" % HID
	if btn.disabled:
		page.queue_free()
		return "mobile HoldingUpgrade disabled unexpectedly"
	var before_lv := int(GameState.holding_level(HID))
	btn.pressed.emit()
	for _i in 8:
		await get_tree().process_frame
	if int(GameState.holding_level(HID)) != before_lv + 1:
		page.queue_free()
		return "mobile upgrade level stuck"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("upgrade", "")) == "":
		page.queue_free()
		return "mobile missing month_echo.upgrade"
	print("ui mobile upgrade ok echo=%s" % str(snap.get("upgrade", "")))
	page.queue_free()
	await get_tree().process_frame
	return ""
