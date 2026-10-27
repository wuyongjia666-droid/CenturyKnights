extends Node
## Mobile twin: grant → Todo_stockade_credit → ledger free CTA under CK_FORCE_MOBILE.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "MOBILE TERRITORY STOCKADE CREDIT LOOP PASS"
const PHONE := Vector2i(2400, 1080)


func _ready() -> void:
	OS.set_environment("CK_FORCE_MOBILE", "1")
	var err := await _run()
	OS.set_environment("CK_FORCE_MOBILE", "")
	if err != "":
		print("FAIL mobile territory stockade credit loop: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	if not DeviceProfile.is_mobile():
		return "DeviceProfile.is_mobile() false — need CK_FORCE_MOBILE=1"
	await _set_phone_window()
	_boot()
	World.pos = "ash_capital"
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	for _i in 16:
		await get_tree().process_frame
	var chip: Node = castle.find_child("Todo_stockade_credit", true, false)
	if chip == null:
		castle.queue_free()
		return "mobile Todo_stockade_credit missing"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	var row := {}
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "stockade_credit":
			row = item
	if int(row.get("count", 0)) < 1:
		return "mobile snapshot missing credit"
	if Todo.link_for(row) != "res://scenes/hub/territory_ledger.tscn":
		return "mobile chip link not ledger"
	var ledger: Node = LEDGER_SCN.instantiate()
	add_child(ledger)
	for _k in 20:
		await get_tree().process_frame
	var banner: Node = ledger.find_child("TerritoryCreditBanner", true, false)
	if banner == null or not bool(banner.visible):
		ledger.queue_free()
		return "mobile TerritoryCreditBanner missing"
	var btn: Button = ledger.find_child("TerritoryStockade", true, false) as Button
	if btn == null or btn.disabled:
		ledger.queue_free()
		return "mobile TerritoryStockade not ready"
	if str(btn.text) != Locale.t("ux_territory_stockade_free"):
		ledger.queue_free()
		return "mobile free label missing"
	btn.pressed.emit()
	for _m in 8:
		await get_tree().process_frame
	if not bool(CKTerritory.state(SITE).stockade):
		ledger.queue_free()
		return "mobile free build failed"
	if CKTerritory.stockade_credit_count() != 0:
		ledger.queue_free()
		return "mobile credit not spent"
	ledger.queue_free()
	return ""


func _boot() -> void:
	GameState.new_game("免费屯营移动", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	GameState.silver = 10
	CKTerritory._st().stockade_credit = 0
	GameState.house_mods.erase("month_echo")
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.threat = {}
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	st = CKTerritory.state(SITE)
	st.garrison = 1
	st.stockade = false
	st.threat = {}
	CKTerritory._put(SITE, st)
	CKTerritory.grant_stockade_credit("chain_ash")


func _set_phone_window() -> void:
	DisplayServer.window_set_size(PHONE)
	for _i in 4:
		await get_tree().process_frame
