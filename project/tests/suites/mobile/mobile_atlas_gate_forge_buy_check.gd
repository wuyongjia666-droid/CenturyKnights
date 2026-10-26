extends Node
## Mobile twin: GateForgeBuy under CK_FORCE_MOBILE.

const CITY_SCN := preload("res://scenes/hub/city.tscn")
const CAP := "ash_capital"
const SIG := "ash_capital_sig1"
const MARKER := "MOBILE ATLAS GATE FORGE BUY PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile atlas gate forge: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await get_tree().process_frame
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(2400, 1080)
	await get_tree().process_frame
	GameState.new_game("城门铁匠", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 50000
	World.armory.clear()
	World.cargo.clear()
	World.done_sig.clear()
	World.city_gate = {}
	GameState.house_mods.erase("month_echo")
	GameState.settings.erase("smith_revealed")
	World.pos = CAP
	World.arrive(CAP)
	World.rep_city[CAP] = 40
	for sid in World.list_signature_ids():
		World.mark_smith_revealed(str(sid))
	GameState.set_meta("city_id", CAP)
	GameState.set_meta("city_tab", "smith")
	var city: Control = CITY_SCN.instantiate()
	city.position = Vector2.ZERO
	city.size = Vector2(2400, 1080)
	get_tree().root.add_child(city)
	for _i in 14:
		await get_tree().process_frame
	if city.has_method("_set_tab"):
		city.call("_set_tab", "smith")
	for _j in 8:
		await get_tree().process_frame
	var reveal: Button = city.find_child("SmithRevealSkip", true, false) as Button
	if reveal:
		reveal.pressed.emit()
		await get_tree().process_frame
	var item_b: Button = city.find_child("Item_" + SIG, true, false) as Button
	if item_b == null:
		city.queue_free()
		return "Item_%s missing on mobile" % SIG
	item_b.pressed.emit()
	for _k in 8:
		await get_tree().process_frame
	var gb: Button = city.find_child("GateForgeBuy", true, false) as Button
	if gb == null:
		city.queue_free()
		return "GateForgeBuy missing on mobile"
	if gb.disabled:
		city.queue_free()
		return "GateForgeBuy disabled on mobile"
	gb.pressed.emit()
	for _n in 10:
		await get_tree().process_frame
	if int(World.armory.get(SIG, 0)) < 1:
		city.queue_free()
		return "mobile armory missing sig"
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("smith", "")) == "":
		city.queue_free()
		return "mobile missing month_echo.smith"
	print("ui mobile gate forge ok echo=%s" % str(snap.get("smith", "")))
	city.queue_free()
	await get_tree().process_frame
	return ""
