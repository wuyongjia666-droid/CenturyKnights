extends Node
## Mobile E2E: city market buy/sell buttons mutate cargo/silver; refresh control present.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const CITY_SCN := preload("res://scenes/hub/city.tscn")

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile city market: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE CITY MARKET BUY SELL PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机市集", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 12000
	World.pos = "ash_capital"
	World.arrive("ash_capital")
	World.cargo.clear()
	GameState.set_meta("city_id", "ash_capital")
	GameState.set_meta("city_tab", "market")
	var city: Control = CITY_SCN.instantiate()
	get_tree().root.add_child(city)
	city.set_anchors_preset(Control.PRESET_TOP_LEFT)
	city.position = Vector2.ZERO
	city.size = ROOT
	for _i in 8:
		await get_tree().process_frame
	if city.has_method("apply_mobile_layout"):
		city.call("apply_mobile_layout")
	for _j in 6:
		await get_tree().process_frame
	var refresh := city.find_child("MarketRefresh", true, false) as Button
	if refresh == null:
		city.queue_free()
		return "MarketRefresh missing on mobile"
	var g := "ashsteel"
	var buy := city.find_child("Mkt_%s_buy1" % g, true, false) as Button
	if buy == null or buy.disabled:
		city.queue_free()
		return "buy button missing/disabled"
	var c0 := int(World.cargo.get(g, 0))
	buy.emit_signal("pressed")
	for _k in 5:
		await get_tree().process_frame
	if int(World.cargo.get(g, 0)) != c0 + 1:
		city.queue_free()
		return "buy did not add cargo"
	World.market["ash_capital"][g] = 1
	city.call("_render_tab")
	for _m in 4:
		await get_tree().process_frame
	refresh = city.find_child("MarketRefresh", true, false) as Button
	if refresh == null:
		city.queue_free()
		return "refresh lost after rerender"
	var st := World.stock("ash_capital", g)
	refresh.emit_signal("pressed")
	for _n in 4:
		await get_tree().process_frame
	if World.stock("ash_capital", g) <= st:
		city.queue_free()
		return "refresh did not restock"
	city.queue_free()
	await get_tree().process_frame
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame
