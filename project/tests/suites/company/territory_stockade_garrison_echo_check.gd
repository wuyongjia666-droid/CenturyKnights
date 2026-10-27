extends Node
## Territory fat: reinforce/stockade_preview → short/full/have reject → reinforce/stockade
## → month_echo.garrison/stockade → yield bump → atlas TerritoryModal EchoLine_ E2E.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY STOCKADE GARRISON ECHO PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory stockade/garrison echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	_setup()
	var err := _api_preview_rejects()
	if err != "":
		return err
	err = _api_reinforce_echo()
	if err != "":
		return err
	err = _api_stockade_echo_and_yield()
	if err != "":
		return err
	err = await _ui_desktop()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("屯营回读", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 5000
	GameState.food = 80
	GameState.morale = 80
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.active.clear()
	GameState.house_mods.erase("month_echo")
	CKTerritory.last_month_report = {}
	World.last_territory_month = {}


func _reset_own(garrison: int = 1, stockade: bool = false) -> void:
	var st: Dictionary = CKTerritory.state(SITE)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	CKTerritory._put(SITE, st)
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(SITE, "chain")
	st = CKTerritory.state(SITE)
	st.garrison = garrison
	st.stockade = stockade
	CKTerritory._put(SITE, st)


func _api_preview_rejects() -> String:
	_reset_own(1, false)
	GameState.silver = 5
	var rp: Dictionary = CKTerritory.reinforce_preview(SITE)
	if not bool(rp.get("short", false)):
		return "reinforce preview want short: %s" % str(rp)
	var bad: Dictionary = CKTerritory.reinforce(SITE)
	if bool(bad.get("ok", false)):
		return "short reinforce should reject"
	if int(CKTerritory.state(SITE).garrison) != 1:
		return "garrison leaked on short reject"

	_reset_own(3, false)  # max without stockade
	GameState.silver = 5000
	rp = CKTerritory.reinforce_preview(SITE)
	if not bool(rp.get("full", false)):
		return "reinforce preview want full at max: %s" % str(rp)
	bad = CKTerritory.reinforce(SITE)
	if bool(bad.get("ok", false)):
		return "full reinforce should reject"

	_reset_own(1, true)
	GameState.silver = 5
	var sp: Dictionary = CKTerritory.stockade_preview(SITE)
	if not bool(sp.get("have", false)):
		return "stockade preview want have: %s" % str(sp)
	bad = CKTerritory.build_stockade(SITE)
	if bool(bad.get("ok", false)):
		return "have stockade should reject"

	_reset_own(1, false)
	GameState.silver = 5
	# clear credit so cost is real
	CKTerritory._st().stockade_credit = 0
	sp = CKTerritory.stockade_preview(SITE)
	if not bool(sp.get("short", false)):
		return "stockade preview want short: %s" % str(sp)
	bad = CKTerritory.build_stockade(SITE)
	if bool(bad.get("ok", false)):
		return "short stockade should reject"
	if bool(CKTerritory.state(SITE).stockade):
		return "stockade leaked on short reject"
	print("api preview rejects ok")
	return ""


func _api_reinforce_echo() -> String:
	_reset_own(1, false)
	GameState.silver = 5000
	GameState.house_mods.erase("month_echo")
	var prev: Dictionary = CKTerritory.reinforce_preview(SITE)
	if not bool(prev.get("craftable", false)):
		return "reinforce not craftable: %s" % str(prev)
	var cost := int(prev.get("cost", 0))
	var sil0 := GameState.silver
	var r: Dictionary = CKTerritory.reinforce(SITE)
	if not bool(r.get("ok", false)):
		return "reinforce fail: %s" % str(r)
	if int(CKTerritory.state(SITE).garrison) != 2:
		return "garrison want 2 got %d" % int(CKTerritory.state(SITE).garrison)
	if GameState.silver != sil0 - cost:
		return "silver not deducted reinforce"
	var echo := str(CKEconomyState.month_echo_snapshot().get("garrison", ""))
	if echo == "":
		return "month_echo.garrison missing"
	print("api reinforce echo ok text=%s" % echo)
	return ""


func _api_stockade_echo_and_yield() -> String:
	_reset_own(1, false)
	CKTerritory._st().stockade_credit = 0
	GameState.silver = 5000
	GameState.food = 80
	GameState.house_mods.erase("month_echo")
	# baseline month yield without stockade (food lands in site cache_food, not GameState.food)
	GameState.silver = 5000
	var sil_a := GameState.silver
	var cache_a := int(CKTerritory.state(SITE).get("cache_food", 0))
	CKTerritory.apply_month(0.99)
	var d_sil := GameState.silver - sil_a
	var d_food := int(CKTerritory.state(SITE).get("cache_food", 0)) - cache_a
	# rebuild owned (apply_month may not lose ownership)
	_reset_own(1, false)
	CKTerritory._st().stockade_credit = 0
	GameState.house_mods.erase("month_echo")
	GameState.silver = 5000
	var prev: Dictionary = CKTerritory.stockade_preview(SITE)
	if not bool(prev.get("craftable", false)):
		return "stockade not craftable: %s" % str(prev)
	var cost := int(prev.get("cost", 0))
	var sil0 := GameState.silver
	var r: Dictionary = CKTerritory.build_stockade(SITE)
	if not bool(r.get("ok", false)):
		return "stockade fail: %s" % str(r)
	if not bool(CKTerritory.state(SITE).stockade):
		return "stockade flag missing"
	if GameState.silver != sil0 - cost:
		return "silver not deducted stockade"
	var echo := str(CKEconomyState.month_echo_snapshot().get("stockade", ""))
	if echo == "":
		return "month_echo.stockade missing"
	# yield bump after stockade (+12银 to company, +6粮 to cache)
	var sil_b := GameState.silver
	var cache_b := int(CKTerritory.state(SITE).get("cache_food", 0))
	CKTerritory.apply_month(0.99)
	var d2_sil := GameState.silver - sil_b
	var d2_food := int(CKTerritory.state(SITE).get("cache_food", 0)) - cache_b
	if d2_sil < d_sil + 10:
		return "stockade silver yield bump weak base=%d after=%d" % [d_sil, d2_sil]
	if d2_food < d_food + 4:
		return "stockade food cache bump weak base=%d after=%d" % [d_food, d2_food]
	# garrison max +1 after stockade
	_reset_own(3, true)
	GameState.silver = 5000
	var rp: Dictionary = CKTerritory.reinforce_preview(SITE)
	if bool(rp.get("full", false)):
		return "stockade should raise garrison max beyond 3"
	print("api stockade echo+yield ok text=%s d_sil %d→%d d_food %d→%d" % [echo, d_sil, d2_sil, d_food, d2_food])
	return ""



func _wait_terr_modal(page: Control, anchor: String) -> Control:
	for _i in 24:
		await get_tree().process_frame
		var m := page.find_child("TerritoryModal", true, false) as Control
		if m != null and is_instance_valid(m) and not m.is_queued_for_deletion():
			return m
	if page.has_method("_open_territory"):
		page.call("_open_territory", anchor)
	for _j in 12:
		await get_tree().process_frame
		var m2 := page.find_child("TerritoryModal", true, false) as Control
		if m2 != null and is_instance_valid(m2) and not m2.is_queued_for_deletion():
			return m2
	return null


func _ui_desktop() -> String:
	_reset_own(1, false)
	CKTerritory._st().stockade_credit = 0
	GameState.silver = 5000
	GameState.house_mods.erase("month_echo")
	var anchor := str(CKTerritory.site(SITE).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)

	var page: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(page)
	for _i in 12:
		await get_tree().process_frame

	if page.has_method("_open_territory"):
		page.call("_open_territory", anchor)
	var modal: Control = await _wait_terr_modal(page, anchor)
	if modal == null:
		page.queue_free()
		return "TerritoryModal missing"
	var rf := modal.find_child("Terr_reinforce_%s" % SITE, true, false) as Button
	if rf == null or rf.disabled:
		page.queue_free()
		return "Terr_reinforce missing/disabled"
	var gar0 := int(CKTerritory.state(SITE).garrison)
	rf.pressed.emit()
	for _k in 6:
		await get_tree().process_frame
	if int(CKTerritory.state(SITE).garrison) != gar0 + 1:
		page.queue_free()
		return "UI reinforce garrison not +1"
	if str(CKEconomyState.month_echo_snapshot().get("garrison", "")) == "":
		page.queue_free()
		return "UI missing month_echo.garrison"
	# modal re-opens after act; EchoLine should show
	modal = await _wait_terr_modal(page, anchor)
	if modal == null:
		page.queue_free()
		return "TerritoryModal missing after reinforce"
	var eg := modal.find_child("EchoLine_garrison", true, false) as Label
	if eg == null:
		page.queue_free()
		return "EchoLine_garrison missing"
	var g_txt := eg.text
	var sk := modal.find_child("Terr_stockade_%s" % SITE, true, false) as Button
	if sk == null or sk.disabled:
		page.queue_free()
		return "Terr_stockade missing/disabled"
	sk.pressed.emit()
	for _m in 6:
		await get_tree().process_frame
	if not bool(CKTerritory.state(SITE).stockade):
		page.queue_free()
		return "UI stockade not built"
	if str(CKEconomyState.month_echo_snapshot().get("stockade", "")) == "":
		page.queue_free()
		return "UI missing month_echo.stockade"
	modal = await _wait_terr_modal(page, anchor)
	if modal == null:
		page.queue_free()
		return "TerritoryModal missing after stockade"
	var es := modal.find_child("EchoLine_stockade", true, false) as Label
	if es == null:
		page.queue_free()
		return "EchoLine_stockade missing"
	var s_txt := es.text
	# have-gate: stockade button disabled after build
	sk = modal.find_child("Terr_stockade_%s" % SITE, true, false) as Button
	if sk == null or not sk.disabled:
		page.queue_free()
		return "Terr_stockade should disable after have"
	print("ui desktop reinforce+stockade+echo ok g=%s s=%s" % [g_txt, s_txt])
	page.queue_free()
	await get_tree().process_frame
	return ""
