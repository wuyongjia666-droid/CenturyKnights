extends Node
## Territory fat: muster_preview → reject → muster_from_cache → month_echo.muster
## → SiegeAlertModal EchoLine_muster E2E. Not a thin CTA knife.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY SIEGE MUSTER ECHO PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory siege muster echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_rejects()
	if err != "":
		return err
	err = _api_muster_echo()
	if err != "":
		return err
	err = await _ui_echo()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("围城募兵回读", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	GameState.food = 80
	GameState.morale = 80
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_siege_alert = {}
	World.last_siege_muster = {}
	World.last_territory_month = {}
	CKTerritory.last_month_report = {}
	GameState.house_mods.erase("month_echo")


func _reset(id: String) -> void:
	var st: Dictionary = CKTerritory.state(id)
	st.owner = CKTerritory.NEUTRAL
	st.garrison = 0
	st.stockade = false
	st.unrest = 0
	st.threat = {}
	st.cache_food = 0
	CKTerritory._put(id, st)


func _own_stockade(id: String, garrison: int, cache: int = 0) -> void:
	_reset(id)
	var anchor := str(CKTerritory.site(id).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(id, "chain")
	var st := CKTerritory.state(id)
	st.garrison = garrison
	st.stockade = true
	st.cache_food = cache
	st.threat = {}
	CKTerritory._put(id, st)


func _api_rejects() -> String:
	_setup()
	var cost := CKTerritory.muster_cache_cost(SITE)
	_own_stockade(SITE, 1, cost + 2)
	var prev: Dictionary = CKTerritory.muster_preview(SITE)
	if bool(prev.get("ok", false)):
		return "preview should need threat"
	var r: Dictionary = CKTerritory.muster_from_cache(SITE)
	if bool(r.get("ok", false)):
		return "muster should reject without threat"
	if str(CKEconomyState.month_echo_snapshot().get("muster", "")) != "":
		return "echo leaked on reject"
	_setup()
	_own_stockade(SITE, 1, maxi(0, cost - 1))
	CKTerritory.start_threat(SITE)
	prev = CKTerritory.muster_preview(SITE)
	if bool(prev.get("ok", false)):
		return "preview should need food"
	r = CKTerritory.muster_from_cache(SITE)
	if bool(r.get("ok", false)):
		return "muster should reject short cache"
	if str(CKEconomyState.month_echo_snapshot().get("muster", "")) != "":
		return "echo leaked on short cache"
	print("api muster preview rejects ok")
	return ""


func _api_muster_echo() -> String:
	_setup()
	var cost := CKTerritory.muster_cache_cost(SITE)
	_own_stockade(SITE, 1, cost + 3)
	CKTerritory.start_threat(SITE)
	var prev: Dictionary = CKTerritory.muster_preview(SITE)
	if not bool(prev.get("ok", false)):
		return "preview want ok: %s" % str(prev)
	if int(prev.get("cost", 0)) != cost:
		return "preview cost mismatch"
	World.last_siege_muster = {}
	var r: Dictionary = CKTerritory.muster_from_cache(SITE)
	if not bool(r.get("ok", false)):
		return "muster fail: %s" % str(r)
	if int(CKTerritory.state(SITE).garrison) != 2:
		return "garrison want 2"
	if CKTerritory.cache_food(SITE) != 3:
		return "cache left want 3"
	var echo := str(CKEconomyState.month_echo_snapshot().get("muster", ""))
	if echo == "":
		return "month_echo.muster missing"
	var lines := CKEconomyState.month_echo_lines()
	var found := false
	for row in lines:
		if str(row.get("kind", "")) == "muster":
			found = true
			break
	if not found:
		return "month_echo_lines missing muster"
	print("api muster echo ok text=%s" % echo)
	return ""


func _ui_echo() -> String:
	_setup()
	var cost := CKTerritory.muster_cache_cost(SITE)
	_own_stockade(SITE, 1, cost + 5)
	World.last_siege_alert = {}
	CKTerritory.start_threat(SITE)
	var atlas: Control = ATLAS_SCN.instantiate()
	get_tree().root.add_child(atlas)
	for _i in 8:
		await get_tree().process_frame
	if atlas.has_method("_check_siege_alert"):
		atlas.call("_check_siege_alert")
	for _j in 8:
		await get_tree().process_frame
	var panel := atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null:
		atlas.queue_free()
		return "SiegeAlertModal missing"
	var btn := panel.find_child("SiegeMuster", true, false) as Button
	if btn == null or btn.disabled:
		atlas.queue_free()
		return "SiegeMuster missing/disabled"
	btn.pressed.emit()
	for _k in 10:
		await get_tree().process_frame
	if int(CKTerritory.state(SITE).garrison) != 2:
		atlas.queue_free()
		return "UI garrison not +1"
	if str(CKEconomyState.month_echo_snapshot().get("muster", "")) == "":
		atlas.queue_free()
		return "UI missing month_echo.muster"
	panel = atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null:
		atlas.queue_free()
		return "SiegeAlertModal gone after muster"
	var el := panel.find_child("EchoLine_muster", true, false) as Label
	if el == null:
		atlas.queue_free()
		return "EchoLine_muster missing"
	print("ui muster echo ok text=%s" % el.text)
	atlas.queue_free()
	await get_tree().process_frame
	return ""
