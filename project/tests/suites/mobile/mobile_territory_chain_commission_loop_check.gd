extends Node
## Mobile twin: post_chain → Todo_territory_chain → ledger banner under CK_FORCE_MOBILE.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY CHAIN COMMISSION LOOP PASS"
const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory chain commission loop: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	var err := _post()
	if err != "":
		return err
	World.pos = "ash_capital"
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	for _i in 16:
		await get_tree().process_frame
	var chip: Node = castle.find_child("Todo_territory_chain", true, false)
	if chip == null:
		castle.queue_free()
		return "mobile Todo_territory_chain missing"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	var ledger: Node = LEDGER_SCN.instantiate()
	add_child(ledger)
	for _k in 20:
		await get_tree().process_frame
	var banner: Node = ledger.find_child("TerritoryChainBanner", true, false)
	if banner == null or not bool(banner.visible):
		ledger.queue_free()
		return "mobile TerritoryChainBanner missing/hidden"
	var btn: Button = ledger.find_child("TerritoryChainGoto", true, false) as Button
	if btn == null or not bool(btn.visible):
		ledger.queue_free()
		return "mobile TerritoryChainGoto missing/hidden"
	if GameState.has_meta("atlas_territory_site"):
		GameState.remove_meta("atlas_territory_site")
	var focused := CKTerritory.hub_focus_chain()
	if focused != SITE:
		ledger.queue_free()
		return "mobile hub_focus_chain want %s got %s" % [SITE, focused]
	if str(GameState.get_meta("atlas_territory_site", "")) != SITE:
		ledger.queue_free()
		return "mobile ledger focus did not set atlas_territory_site"
	CKTerritory.capture(SITE, "chain")
	ledger.queue_free()
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "territory_chain" and int(item.get("count", 0)) > 0:
			return "mobile chip still on after capture"
	return ""


func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	for _i in 4:
		await get_tree().process_frame


func _boot() -> void:
	GameState.new_game("移动归附整链", "灰旗", GameState.crest_color)
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


func _post() -> String:
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.threat = {}
	st.unrest = 0
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	var r := CKTerritory.post_chain(SITE)
	if not bool(r.get("ok", false)):
		return "post_chain failed: %s" % str(r.get("msg", ""))
	return ""
