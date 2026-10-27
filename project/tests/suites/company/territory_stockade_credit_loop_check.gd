extends Node
## Territory fat §20: grant credit → HubTodo chip → ledger free build → month_echo closed loop.

const CASTLE_SCN := preload("res://scenes/hub/castle_hub.tscn")
const LEDGER_SCN := preload("res://scenes/hub/territory_ledger.tscn")
const Todo := preload("res://scripts/ui/widgets/todo_center.gd")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY STOCKADE CREDIT LOOP PASS"


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory stockade credit loop: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_grant_echo()
	if err != "":
		return err
	err = await _ui_chip_to_ledger_free_build()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("免费屯营整链", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 40
	GameState.food = 80
	GameState.morale = 80
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	CKTerritory._st().stockade_credit = 0
	GameState.house_mods.erase("month_echo")


func _own(id: String) -> void:
	var st: Dictionary = CKTerritory.state(id)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.cache_food = 0
	CKTerritory._put(id, st)
	var anchor := str(CKTerritory.site(id).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(id, "chain")
	st = CKTerritory.state(id)
	st.garrison = 1
	st.stockade = false
	st.cache_food = 2
	st.threat = {}
	CKTerritory._put(id, st)


func _api_grant_echo() -> String:
	var err := _api_grant_chip()
	if err != "":
		return err
	err = _api_spend_free()
	if err != "":
		return err
	print("api grant/spend echo ok")
	return ""


func _api_grant_chip() -> String:
	_setup()
	if CKTerritory.stockade_credit_count() != 0:
		return "credit want 0 before grant"
	CKTerritory.grant_stockade_credit("chain_ash")
	if CKTerritory.stockade_credit_count() != 1:
		return "credit want 1 after grant"
	var echo := str(CKEconomyState.month_echo_snapshot().get("stockade_credit", ""))
	if echo == "":
		return "month_echo.stockade_credit missing"
	var found := false
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "stockade_credit":
			found = true
			if int(item.get("count", 0)) != 1:
				return "chip count want 1 got %d" % int(item.get("count", 0))
			if Todo.link_for(item) != "res://scenes/hub/territory_ledger.tscn":
				return "chip link not ledger"
	if not found:
		return "stockade_credit chip missing after grant"
	return ""


func _api_spend_free() -> String:
	# Spend path at API: free build with silver too low for paid stockade.
	_own(SITE)
	GameState.silver = 10
	var prev: Dictionary = CKTerritory.stockade_preview(SITE)
	if not bool(prev.get("credit", false)):
		return "preview credit false: %s" % str(prev)
	if int(prev.get("cost", -1)) != 0:
		return "preview cost want 0: %s" % str(prev)
	if not bool(prev.get("craftable", false)):
		return "preview not craftable with credit"
	GameState.house_mods.erase("month_echo")
	var r: Dictionary = CKTerritory.build_stockade(SITE)
	if not bool(r.get("ok", false)):
		return "free build fail: %s" % str(r)
	if CKTerritory.stockade_credit_count() != 0:
		return "credit not spent"
	if not bool(CKTerritory.state(SITE).stockade):
		return "stockade flag missing after free build"
	if GameState.silver != 10:
		return "silver changed on free build"
	var se := str(CKEconomyState.month_echo_snapshot().get("stockade", ""))
	if se == "":
		return "month_echo.stockade missing after free build"
	for item in Todo.snapshot():
		if str(item.get("category", "")) == "stockade_credit" and int(item.get("count", 0)) > 0:
			return "chip still up after spend"
	return ""


func _ui_chip_to_ledger_free_build() -> String:
	_setup()
	_own(SITE)
	GameState.silver = 10
	CKTerritory.grant_stockade_credit("chain_ash")
	World.pos = "ash_capital"
	var castle: Node = CASTLE_SCN.instantiate()
	add_child(castle)
	for _i in 16:
		await get_tree().process_frame
	var chip: Node = castle.find_child("Todo_stockade_credit", true, false)
	if chip == null:
		castle.queue_free()
		return "Todo_stockade_credit missing on castle"
	castle.queue_free()
	for _j in 4:
		await get_tree().process_frame
	var ledger: Node = LEDGER_SCN.instantiate()
	add_child(ledger)
	for _k in 20:
		await get_tree().process_frame
	var banner: Node = ledger.find_child("TerritoryCreditBanner", true, false)
	if banner == null or not bool(banner.visible):
		ledger.queue_free()
		return "TerritoryCreditBanner missing/hidden"
	var btn: Button = ledger.find_child("TerritoryStockade", true, false) as Button
	if btn == null:
		ledger.queue_free()
		return "TerritoryStockade missing"
	if btn.disabled:
		ledger.queue_free()
		return "TerritoryStockade disabled with credit"
	var want_free := Locale.t("ux_territory_stockade_free")
	if str(btn.text) != want_free:
		ledger.queue_free()
		return "stockade btn want free label got %s" % str(btn.text)
	btn.pressed.emit()
	for _m in 8:
		await get_tree().process_frame
	if not bool(CKTerritory.state(SITE).stockade):
		ledger.queue_free()
		return "UI free build did not raise stockade"
	if CKTerritory.stockade_credit_count() != 0:
		ledger.queue_free()
		return "UI free build did not spend credit"
	if bool(banner.visible):
		# refresh should hide
		ledger.queue_free()
		return "banner still visible after spend"
	ledger.queue_free()
	print("ui chip→ledger free build ok")
	return ""
