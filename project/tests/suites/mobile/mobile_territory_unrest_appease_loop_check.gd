extends Node
## Mobile twin: assault → Todo_territory_unrest → ledger UnrestBanner/Appease under CK_FORCE_MOBILE.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY UNREST APPEASE LOOP PASS"
const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory unrest appease loop: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	_own_with_unrest()
	World.pos = "ash_capital"
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	for _i in 16:
		await get_tree().process_frame
	var chip: Node = castle.find_child("Todo_territory_unrest", true, false)
	if chip == null:
		castle.queue_free()
		return "mobile Todo_territory_unrest missing"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	var ledger: Node = LEDGER_SCN.instantiate()
	add_child(ledger)
	for _k in 20:
		await get_tree().process_frame
	var banner: Node = ledger.find_child("TerritoryUnrestBanner", true, false)
	if banner == null or not bool(banner.visible):
		ledger.queue_free()
		return "mobile TerritoryUnrestBanner missing/hidden"
	var btn: Button = ledger.find_child("TerritoryAppease", true, false) as Button
	if btn == null:
		ledger.queue_free()
		return "mobile TerritoryAppease missing"
	var list: ItemList = ledger.find_child("TerritoryList", true, false) as ItemList
	if list == null or list.item_count < 1:
		ledger.queue_free()
		return "mobile TerritoryList empty"
	list.select(0)
	if ledger.has_method("_on_pick"):
		ledger.call("_on_pick", 0)
	for _m in 4:
		await get_tree().process_frame
	if bool(btn.disabled):
		ledger.queue_free()
		return "mobile TerritoryAppease still disabled after pick"
	GameState.house_mods.erase("month_echo")
	var cost := CKTerritory.appease_cost(SITE)
	GameState.silver = maxi(GameState.silver, cost + 10)
	btn.emit_signal("pressed")
	for _n in 8:
		await get_tree().process_frame
	if int(CKTerritory.state(SITE).unrest) != 0:
		ledger.queue_free()
		return "mobile ledger appease did not clear unrest"
	if bool(banner.visible):
		ledger.queue_free()
		return "mobile TerritoryUnrestBanner still visible after appease"
	var echo := str(CKEconomyState.month_echo_snapshot().get("appease", ""))
	if echo == "":
		ledger.queue_free()
		return "mobile missing month_echo.appease"
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_unrest" and int(item.get("count", 0)) > 0:
			ledger.queue_free()
			return "mobile chip still on after appease"
	ledger.queue_free()
	return ""


func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	for _i in 4:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("移动安抚整链", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	GameState.food = 80
	World.active.clear()
	GameState.house_mods.erase("month_echo")
	Todo.reset_for_tests()


func _own_with_unrest() -> void:
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.unrest = 0
	st.threat = {}
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "assault")
	st = CKTerritory.state(SITE)
	st.garrison = 2
	CKTerritory._put(SITE, st)
