extends Node
## Mobile E2E: infirmary InnKnight_ → InnRest light clear + silver sink.

const PHONE := Vector2i(2400, 1080)
const ROOT := Vector2(1600, 720)
const ANNEX_SCN := preload("res://scenes/hub/annex.tscn")


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL mobile infirmary rest heal: ", err)
		get_tree().quit(1)
	else:
		print("MOBILE INFIRMARY REST HEAL PASS")
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	GameState.new_game("手机医所", "灰旗", GameState.crest_color)
	GameState.set_flag("chapter0_done", true)
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 80000
	GameState.buildings["infirmary"] = 1
	var c: CKCharacter = null
	for x in GameState.roster():
		if not x.is_leader:
			c = x
			break
	if c == null:
		c = GameState.roster()[0]
	if typeof(c.blood_meta) != TYPE_DICTIONARY:
		c.blood_meta = {}
	c.blood_meta["injury"] = {
		"tier": "light", "months_left": 2, "skl_applied": 0, "move": 0,
		"id": "bruise", "name": Locale.t("轻伤"),
	}
	c.injured = true
	c.hp = maxi(1, int(c.max_hp / 3))
	var page = ANNEX_SCN.instantiate()
	page.set_meta("annex", "infirmary")
	add_child(page)
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.position = Vector2.ZERO
	page.size = ROOT
	for _i in 10:
		await get_tree().process_frame
	if page.has_method("apply_mobile_layout"):
		page.call("apply_mobile_layout")
	for _j in 6:
		await get_tree().process_frame
	var slot := page.find_child("InnKnight_" + c.id, true, false) as Button
	if slot == null:
		page.queue_free()
		return "InnKnight_%s missing" % c.id
	var rest := page.find_child("InnRest", true, false) as Button
	if rest == null or rest.disabled:
		page.queue_free()
		return "InnRest missing/disabled"
	var sil0 := GameState.silver
	rest.emit_signal("pressed")
	for _k in 8:
		await get_tree().process_frame
	if not CKInjury.record(c).is_empty() or c.injured:
		page.queue_free()
		return "mobile did not clear light"
	if c.hp != c.max_hp:
		page.queue_free()
		return "mobile HP not full"
	if GameState.silver >= sil0:
		page.queue_free()
		return "mobile did not sink silver"
	rest = page.find_child("InnRest", true, false) as Button
	if rest == null or not rest.disabled:
		page.queue_free()
		return "mobile InnRest should disable after heal"
	page.queue_free()
	await get_tree().process_frame
	return ""


func _set_phone_window() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = PHONE
	await get_tree().process_frame
