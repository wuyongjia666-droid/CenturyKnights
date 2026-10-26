extends Node
## Mobile twin: market CaravanStart_/Escort + EchoLine_caravan under CK_FORCE_MOBILE.

const KIND := "grain"
const MARKER := "MOBILE CARAVAN ECHO LOOP PASS"
const MARKET_SCN := preload("res://scenes/hub/market.tscn")

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile caravan echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await get_tree().process_frame
	GameState.new_game("商队回读", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 80000
	GameState.food = 10
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")
	GameState.house_mods.erase("month_echo")

	var mkt: Control = MARKET_SCN.instantiate()
	get_tree().root.add_child(mkt)
	mkt.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mkt.position = Vector2.ZERO
	mkt.size = Vector2(390, 844)
	for _i in 12:
		await get_tree().process_frame

	var start_btn := mkt.find_child("CaravanStart_" + KIND, true, false) as Button
	if start_btn == null or start_btn.disabled:
		mkt.queue_free()
		return "mobile CaravanStart_grain missing/disabled"
	start_btn.pressed.emit()
	for _j in 8:
		await get_tree().process_frame
	if int(GameState.caravan.get("turns_left", 0)) != 3:
		mkt.queue_free()
		return "mobile UI start turns_left != 3"

	var esc := mkt.find_child("CaravanEscort", true, false) as Button
	if esc == null or esc.disabled:
		mkt.queue_free()
		return "mobile CaravanEscort missing/disabled"
	esc.pressed.emit()
	for _k in 8:
		await get_tree().process_frame
	if not bool(GameState.caravan.get("escorted", false)):
		mkt.queue_free()
		return "mobile UI escort not applied"

	for _n in 3:
		GameState.tick_caravan_month()
		await get_tree().process_frame
	if mkt.has_method("_render"):
		mkt.call("_render")
	for _p in 6:
		await get_tree().process_frame

	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("caravan", "")) == "":
		mkt.queue_free()
		return "mobile missing month_echo.caravan"
	var echo := mkt.find_child("EchoLine_caravan", true, false) as Label
	if echo == null:
		mkt.queue_free()
		return "mobile EchoLine_caravan missing"
	print("ui mobile caravan+echo ok text=%s" % echo.text)
	mkt.queue_free()
	await get_tree().process_frame
	return ""
