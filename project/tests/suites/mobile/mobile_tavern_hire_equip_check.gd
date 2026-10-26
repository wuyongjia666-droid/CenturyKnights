extends Node
## Mobile E2E: tavern Hire0 → armory Equip_ on the hired face.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const CITY_SCN := preload("res://scenes/hub/city.tscn")
const CAP := "ash_capital"
const WEAPON := "ashbanner_sword_1"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile tavern hire equip: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE TAVERN HIRE EQUIP PASS")
		get_tree().quit(0)

func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机酒馆", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 80000
	World.pos = CAP
	World.arrive(CAP)
	World.armory.clear()
	World.armory[WEAPON] = 1
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
	city.call("_set_tab", "tavern")
	for _t in 6:
		await get_tree().process_frame
	var roster0 := GameState.roster().size()
	var hire0 := city.find_child("Hire0", true, false) as Button
	if hire0 == null or hire0.disabled:
		city.queue_free()
		return "Hire0 missing/disabled on mobile"
	hire0.emit_signal("pressed")
	for _k in 6:
		await get_tree().process_frame
	if GameState.roster().size() != roster0 + 1:
		city.queue_free()
		return "mobile hire did not grow roster"
	var hired_id := str(city.get("_sel_char"))
	if hired_id == "" or hired_id == GameState.get_leader().id:
		city.queue_free()
		return "mobile did not select hired"
	var hired: CKCharacter = GameState.characters.get(hired_id)
	hired.job_id = "squire"
	city.call("_set_tab", "armory")
	for _n in 4:
		await get_tree().process_frame
	city.set("_sel_char", hired_id)
	city.call("_render_tab")
	for _p in 5:
		await get_tree().process_frame
	var eq := city.find_child("Equip_" + WEAPON, true, false) as Button
	if eq == null or eq.disabled:
		city.queue_free()
		return "Equip_%s missing/disabled on mobile hire" % WEAPON
	eq.emit_signal("pressed")
	for _q in 5:
		await get_tree().process_frame
	hired = GameState.characters.get(hired_id)
	if World.equipped(hired, "weapon") != WEAPON:
		city.queue_free()
		return "mobile equip on hire failed"
	city.queue_free()
	await get_tree().process_frame
	return ""

func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
	await get_tree().process_frame
