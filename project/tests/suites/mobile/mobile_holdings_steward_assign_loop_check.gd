extends Node
## Mobile twin: estates HoldingStewardAssign_/StewardPick_/Clear under CK_FORCE_MOBILE.

const HID := "reed_ford"
const MARKER := "MOBILE HOLDINGS STEWARD ASSIGN LOOP PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile holdings steward assign: ", err)
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
	GameState.holdings[HID]["steward_id"] = ""
	GameState.house_mods.erase("month_echo")

	var cid := ""
	for c in GameState.roster():
		if c != null and c.alive:
			cid = str(c.id)
			break
	if cid == "":
		return "no roster"

	var page: Control = load("res://scenes/hub/estates.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(390, 844)
	for _i in 12:
		await get_tree().process_frame

	var assign_btn := page.find_child("HoldingStewardAssign_%s" % HID, true, false) as Button
	if assign_btn == null:
		page.queue_free()
		return "HoldingStewardAssign_%s missing (mobile)" % HID
	assign_btn.pressed.emit()
	for _i in 10:
		await get_tree().process_frame
	var pick := page.find_child("StewardPick_%s" % cid, true, false) as Button
	if pick == null:
		page.queue_free()
		return "StewardPick_%s missing (mobile)" % cid
	pick.pressed.emit()
	for _i in 10:
		await get_tree().process_frame
	if GameState.steward_of(HID) == null:
		page.queue_free()
		return "mobile assign failed"
	var clear_btn := page.find_child("HoldingStewardClear_%s" % HID, true, false) as Button
	if clear_btn == null:
		page.queue_free()
		return "HoldingStewardClear missing after assign (mobile)"
	clear_btn.pressed.emit()
	for _i in 8:
		await get_tree().process_frame
	if GameState.steward_of(HID) != null:
		page.queue_free()
		return "mobile clear failed"
	print("mobile steward assign+clear ok")
	page.queue_free()
	await get_tree().process_frame
	return ""
