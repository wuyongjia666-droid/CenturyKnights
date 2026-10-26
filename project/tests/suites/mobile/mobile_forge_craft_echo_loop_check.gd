extends Node
## Mobile twin: forge ForgeCraft → month_echo.forge + EchoLine_forge under CK_FORCE_MOBILE.

const MARKER := "MOBILE FORGE CRAFT ECHO LOOP PASS"
const FORGE_SCN := preload("res://scenes/hub/forge.tscn")
const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile forge craft echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机工坊回读", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.buildings["forge"] = 1
	GameState.house_mods.erase("sundry_forge_iron")
	GameState.house_mods.erase("month_echo")
	GameState.silver = 80000
	GameState.iron = 40
	for c in GameState.roster():
		c.weapon_id = ""

	var forge: Control = FORGE_SCN.instantiate()
	get_tree().root.add_child(forge)
	forge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	forge.position = Vector2.ZERO
	forge.size = ROOT
	for _i in 10:
		await get_tree().process_frame
	if forge.has_method("apply_mobile_layout"):
		forge.call("apply_mobile_layout")
	for _j in 6:
		await get_tree().process_frame

	var lead: CKCharacter = GameState.roster()[0]
	var craft := forge.find_child("ForgeCraft", true, false) as Button
	if craft == null or craft.disabled:
		forge.queue_free()
		return "mobile ForgeCraft missing/disabled bare"
	craft.pressed.emit()
	for _k in 8:
		await get_tree().process_frame
	if lead.weapon_id != "ash_blade":
		forge.queue_free()
		return "mobile craft not ash_blade got %s" % lead.weapon_id
	var snap: Dictionary = CKEconomyState.month_echo_snapshot()
	if str(snap.get("forge", "")) == "":
		forge.queue_free()
		return "mobile missing month_echo.forge"
	if forge.has_method("_m_render_all"):
		forge.call("_m_render_all")
	for _p in 6:
		await get_tree().process_frame
	var echo := forge.find_child("EchoLine_forge", true, false) as Label
	if echo == null:
		forge.queue_free()
		return "mobile EchoLine_forge missing"
	print("ui mobile forge+echo ok text=%s" % echo.text)
	forge.queue_free()
	await get_tree().process_frame
	return ""


func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
