extends Node
## Mobile E2E: city sundry SundryBuy_ → SundryUse_ → abroad SundrySell_.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const CITY_SCN := preload("res://scenes/hub/city.tscn")
const ASH := "ash_capital"
const SY := "sy_capital"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile sundry buy use sell: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE SUNDRY BUY USE SELL PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机杂货", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 80000
	CKSundries.bag().clear()
	World.cargo.clear()
	var food := ""
	for o in CKSundries.shelf_for_city(ASH):
		var k := CKSundries._kind_of(str(o.id))
		if k == "food" or k == "food_morale_only":
			food = str(o.id)
			break
	if food == "":
		return "no ash food"
	World.pos = ASH
	World.arrive(ASH)
	GameState.set_meta("city_id", ASH)
	var city: Control = CITY_SCN.instantiate()
	add_child(city)
	city.set_anchors_preset(Control.PRESET_TOP_LEFT)
	city.position = Vector2.ZERO
	city.size = ROOT
	for _i in 10:
		await get_tree().process_frame
	if not city.has_method("_set_tab"):
		city.queue_free()
		return "city.gd failed to load"
	if city.has_method("apply_mobile_layout"):
		city.call("apply_mobile_layout")
	for _j in 6:
		await get_tree().process_frame
	city.call("_set_tab", "sundry")
	for _t in 6:
		await get_tree().process_frame
	var buy := city.find_child("SundryBuy_" + food, true, false) as Button
	if buy == null or buy.disabled:
		city.queue_free()
		return "SundryBuy_%s missing/disabled" % food
	buy.emit_signal("pressed")
	for _k in 6:
		await get_tree().process_frame
	if CKSundries.owned(food) < 1:
		city.queue_free()
		return "mobile buy did not fill bag"
	var use := city.find_child("SundryUse_" + food, true, false) as Button
	if use == null or use.disabled:
		city.queue_free()
		return "SundryUse_%s missing/disabled after buy" % food
	use.emit_signal("pressed")
	for _m in 5:
		await get_tree().process_frame
	# restock one for abroad sell
	buy = city.find_child("SundryBuy_" + food, true, false) as Button
	if buy and not buy.disabled:
		buy.emit_signal("pressed")
		for _n in 4:
			await get_tree().process_frame
	city.queue_free()
	await get_tree().process_frame
	World.pos = SY
	World.arrive(SY)
	GameState.set_meta("city_id", SY)
	var city2: Control = CITY_SCN.instantiate()
	add_child(city2)
	city2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	city2.position = Vector2.ZERO
	city2.size = ROOT
	for _p in 10:
		await get_tree().process_frame
	if city2.has_method("apply_mobile_layout"):
		city2.call("apply_mobile_layout")
	for _q in 4:
		await get_tree().process_frame
	city2.call("_set_tab", "sundry")
	for _r in 6:
		await get_tree().process_frame
	var sell := city2.find_child("SundrySell_" + food, true, false) as Button
	if sell == null or sell.disabled:
		city2.queue_free()
		return "SundrySell_%s missing/disabled abroad" % food
	var o0 := CKSundries.owned(food)
	sell.emit_signal("pressed")
	for _s in 5:
		await get_tree().process_frame
	if CKSundries.owned(food) != o0 - 1:
		city2.queue_free()
		return "mobile sell did not drop bag"
	city2.queue_free()
	await get_tree().process_frame
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame
