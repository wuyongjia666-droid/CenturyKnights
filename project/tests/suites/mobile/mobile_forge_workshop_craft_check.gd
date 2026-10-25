extends Node
## Mobile E2E: castle forge ForgeKnight_ → ForgeCraft ash_blade / fine, same-tier gate.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const FORGE_SCN := preload("res://scenes/hub/forge.tscn")


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile forge workshop craft: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE FORGE WORKSHOP CRAFT PASS")
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机工坊", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 80000
	GameState.iron = 40
	GameState.buildings["forge"] = 1
	GameState.house_mods.erase("sundry_forge_iron")
	for c in GameState.roster():
		c.weapon_id = ""
	var forge: Control = FORGE_SCN.instantiate()
	add_child(forge)
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
	var slot := forge.find_child("ForgeKnight_" + lead.id, true, false) as Button
	if slot == null:
		forge.queue_free()
		return "ForgeKnight_%s missing" % lead.id
	var craft := forge.find_child("ForgeCraft", true, false) as Button
	if craft == null or craft.disabled:
		forge.queue_free()
		return "ForgeCraft missing/disabled bare"
	var atk0 := lead.derived_atk()
	craft.emit_signal("pressed")
	for _k in 8:
		await get_tree().process_frame
	if lead.weapon_id != "ash_blade":
		forge.queue_free()
		return "mobile craft not ash_blade got %s" % lead.weapon_id
	if lead.derived_atk() != atk0 + 2:
		forge.queue_free()
		return "mobile atk not +2"
	craft = forge.find_child("ForgeCraft", true, false) as Button
	if craft == null or not craft.disabled:
		forge.queue_free()
		return "mobile ForgeCraft should disable same-tier"
	# second knight
	var other: CKCharacter = null
	for c in GameState.roster():
		if c.id != lead.id:
			other = c
			break
	if other == null:
		forge.queue_free()
		return "no second knight"
	var slot2 := forge.find_child("ForgeKnight_" + other.id, true, false) as Button
	if slot2 == null:
		forge.queue_free()
		return "ForgeKnight_%s missing" % other.id
	slot2.emit_signal("pressed")
	for _m in 6:
		await get_tree().process_frame
	craft = forge.find_child("ForgeCraft", true, false) as Button
	if craft == null or craft.disabled:
		forge.queue_free()
		return "ForgeCraft disabled for bare second"
	craft.emit_signal("pressed")
	for _n in 8:
		await get_tree().process_frame
	if other.weapon_id != "ash_blade":
		forge.queue_free()
		return "second knight not crafted"
	forge.queue_free()
	await get_tree().process_frame
	# Lv4 fine
	GameState.buildings["forge"] = 4
	for c in GameState.roster():
		c.weapon_id = ""
	GameState.silver = 80000
	GameState.iron = 40
	var forge2: Control = FORGE_SCN.instantiate()
	add_child(forge2)
	forge2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	forge2.position = Vector2.ZERO
	forge2.size = ROOT
	for _p in 10:
		await get_tree().process_frame
	if forge2.has_method("apply_mobile_layout"):
		forge2.call("apply_mobile_layout")
	for _q in 6:
		await get_tree().process_frame
	craft = forge2.find_child("ForgeCraft", true, false) as Button
	if craft == null or craft.disabled:
		forge2.queue_free()
		return "lv4 ForgeCraft missing/disabled"
	craft.emit_signal("pressed")
	for _r in 8:
		await get_tree().process_frame
	if lead.weapon_id != "ash_blade_fine":
		forge2.queue_free()
		return "lv4 not ash_blade_fine got %s" % lead.weapon_id
	forge2.queue_free()
	await get_tree().process_frame
	return ""


func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
