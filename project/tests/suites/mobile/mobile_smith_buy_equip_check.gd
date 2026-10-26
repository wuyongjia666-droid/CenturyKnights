extends Node
## Mobile E2E: smith BuyItem → armory Equip_ on phone layout.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const CITY_SCN := preload("res://scenes/hub/city.tscn")
const CAP := "ash_capital"
const REGIONAL := "ashbanner_sword_1"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile smith buy equip: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE SMITH BUY EQUIP PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机铁匠", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 20000
	World.pos = CAP
	World.arrive(CAP)
	World.rep_city[CAP] = 20
	World.armory.clear()
	for e in World.smith_stock(CAP):
		if int(e.get("signature", 0)) >= 1:
			World.mark_smith_revealed(str(e.item.id))
	GameState.set_meta("city_id", CAP)
	GameState.set_meta("city_tab", "smith")
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
	# Force smith tab even if meta was consumed
	city.call("_set_tab", "smith")
	for _t in 6:
		await get_tree().process_frame
	var skip := city.find_child("SmithRevealSkip", true, false) as Button
	if skip:
		skip.emit_signal("pressed")
		for _s in 4:
			await get_tree().process_frame
	var row := city.find_child("Item_" + REGIONAL, true, false) as Button
	if row == null:
		city.queue_free()
		return "Item_%s missing on mobile" % REGIONAL
	row.emit_signal("pressed")
	for _k in 4:
		await get_tree().process_frame
	var buy := city.find_child("BuyItem", true, false) as Button
	if buy == null or buy.disabled:
		city.queue_free()
		return "BuyItem missing/disabled on mobile"
	var a0 := int(World.armory.get(REGIONAL, 0))
	buy.emit_signal("pressed")
	for _m in 5:
		await get_tree().process_frame
	if int(World.armory.get(REGIONAL, 0)) != a0 + 1:
		city.queue_free()
		return "mobile buy did not fill armory"
	city.call("_set_tab", "armory")
	for _n in 4:
		await get_tree().process_frame
	var leader: CKCharacter = GameState.get_leader()
	city.set("_sel_char", leader.id)
	city.call("_render_tab")
	for _p in 4:
		await get_tree().process_frame
	var eq := city.find_child("Equip_" + REGIONAL, true, false) as Button
	if eq == null or eq.disabled:
		city.queue_free()
		return "Equip_%s missing/disabled on mobile" % REGIONAL
	eq.emit_signal("pressed")
	for _q in 5:
		await get_tree().process_frame
	if World.equipped(leader, "weapon") != REGIONAL:
		city.queue_free()
		return "mobile equip failed"
	city.queue_free()
	await get_tree().process_frame
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame
