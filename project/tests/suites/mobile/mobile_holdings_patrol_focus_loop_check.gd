extends Node
## Mobile twin: estates HoldingPatrol_/HoldingFocus_ under CK_FORCE_MOBILE.

const HID := "reed_ford"
const MARKER := "MOBILE HOLDINGS PATROL FOCUS LOOP PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile holdings patrol focus: ", err)
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
		GameState.holdings[HID] = {"level": 1, "focus": "grain", "patrol_boost": 0, "patrol_cd": 0}
	GameState.holdings[HID]["patrol_boost"] = 0
	GameState.holdings[HID]["patrol_cd"] = 0
	GameState.holdings[HID]["focus"] = "grain"
	GameState.holdings[HID]["focus_cd"] = 0
	GameState.silver = 200
	GameState.food = 80
	GameState.house_mods.erase("month_echo")

	var page: Control = load("res://scenes/hub/estates.tscn").instantiate()
	get_tree().root.add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = Vector2(1600, 720)
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
	for _i in 12:
		await get_tree().process_frame

	var all_btn := page.find_child("HoldingPatrolAll", true, false) as Button
	if all_btn == null:
		page.queue_free()
		return "HoldingPatrolAll missing (mobile)"
	var one := page.find_child("HoldingPatrol_%s" % HID, true, false) as Button
	if one == null:
		page.queue_free()
		return "HoldingPatrol_%s missing (mobile)" % HID
	var before_s := int(GameState.silver)
	one.pressed.emit()
	for _i in 8:
		await get_tree().process_frame
	if int(GameState.holding_patrol_boost(HID)) < 1:
		page.queue_free()
		return "mobile patrol no boost"
	if int(GameState.silver) >= before_s:
		page.queue_free()
		return "mobile patrol no spend"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("patrol", "")) == "":
		page.queue_free()
		return "mobile patrol missing month_echo"
	var focus_cash := page.find_child("HoldingFocus_%s_cash" % HID, true, false) as Button
	if focus_cash == null:
		page.queue_free()
		return "HoldingFocus cash missing (mobile)"
	focus_cash.pressed.emit()
	for _i in 8:
		await get_tree().process_frame
	if str(GameState.holding_focus(HID)) != "cash":
		page.queue_free()
		return "mobile focus cash not applied"
	print("mobile patrol+focus ok")
	page.queue_free()
	await get_tree().process_frame
	return ""
