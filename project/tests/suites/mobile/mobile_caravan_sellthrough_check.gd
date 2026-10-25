extends Node
## Mobile E2E: market CaravanStart_grain → CaravanEscort → tick×3 sell-through.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const MARKET_SCN := preload("res://scenes/hub/market.tscn")
const KIND := "grain"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile caravan sellthrough: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE CARAVAN SELLTHROUGH PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机商队", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 80000
	GameState.food = 10
	GameState.caravan = {}
	GameState.house_mods.erase("caravan_active")
	var food0 := GameState.food
	var mkt: Control = MARKET_SCN.instantiate()
	add_child(mkt)
	mkt.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mkt.position = Vector2.ZERO
	mkt.size = ROOT
	for _i in 10:
		await get_tree().process_frame
	if mkt.has_method("apply_mobile_layout"):
		mkt.call("apply_mobile_layout")
	for _j in 6:
		await get_tree().process_frame
	if mkt.has_method("_m_render"):
		mkt.call("_m_render")
	elif mkt.has_method("_render"):
		mkt.call("_render")
	for _t in 6:
		await get_tree().process_frame
	var start_btn := mkt.find_child("CaravanStart_" + KIND, true, false) as Button
	if start_btn == null or start_btn.disabled:
		mkt.queue_free()
		return "CaravanStart_grain missing/disabled on mobile"
	start_btn.emit_signal("pressed")
	for _k in 6:
		await get_tree().process_frame
	if int(GameState.caravan.get("turns_left", 0)) != 3:
		mkt.queue_free()
		return "mobile start did not set turns_left"
	var esc := mkt.find_child("CaravanEscort", true, false) as Button
	if esc == null or esc.disabled:
		mkt.queue_free()
		return "CaravanEscort missing/disabled on mobile"
	esc.emit_signal("pressed")
	for _n in 5:
		await get_tree().process_frame
	if not bool(GameState.caravan.get("escorted", false)):
		mkt.queue_free()
		return "mobile escort failed"
	for _p in 3:
		GameState.tick_caravan_month()
		await get_tree().process_frame
	if int(GameState.caravan.get("turns_left", 0)) != 0:
		mkt.queue_free()
		return "mobile settle left caravan active"
	if GameState.food != food0 + 8:
		mkt.queue_free()
		return "mobile grain unload food got %d" % GameState.food
	mkt.queue_free()
	await get_tree().process_frame
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame
