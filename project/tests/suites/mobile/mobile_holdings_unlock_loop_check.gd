extends Node
## Mobile twin: estates HoldingUnlock_ under CK_FORCE_MOBILE.

const HID := "stone_slope"
const QID := "q_bandit"
const MARKER := "MOBILE HOLDINGS UNLOCK LOOP PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile holdings unlock: ", err)
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
	GameState.holdings.erase(HID)
	GameState.quest_done[QID] = true
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

	var btn := page.find_child("HoldingUnlock_%s" % HID, true, false) as Button
	if btn == null:
		page.queue_free()
		return "HoldingUnlock_%s missing on mobile" % HID
	if btn.disabled:
		page.queue_free()
		return "mobile HoldingUnlock disabled unexpectedly"
	btn.pressed.emit()
	for _i in 8:
		await get_tree().process_frame
	if not GameState.holdings.has(HID):
		page.queue_free()
		return "mobile claim did not unlock"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("unlock", "")) == "":
		page.queue_free()
		return "mobile missing month_echo.unlock"
	print("ui mobile unlock ok echo=%s" % str(snap.get("unlock", "")))
	page.queue_free()
	await get_tree().process_frame
	return ""
