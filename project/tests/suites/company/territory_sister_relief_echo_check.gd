extends Node
## Territory fat: sister_relief_preview → reject → call_sister → month_echo.sister
## → SiegeAlertModal EchoLine_sister E2E. Not a thin CTA knife.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const SISTER := "t_ash_millrun"
const MARKER := "TERRITORY SISTER RELIEF ECHO PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory sister relief echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_rejects()
	if err != "":
		return err
	err = _api_call_echo()
	if err != "":
		return err
	err = await _ui_echo()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("姊妹回读", "灰旗", GameState.crest_color)
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
	World.last_siege_sister = {}
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
	_own_stockade(SISTER, 3)
	_own_stockade(SITE, 1)
	var prev: Dictionary = CKTerritory.sister_relief_preview(SITE)
	if bool(prev.get("ok", false)):
		return "preview should need threat"
	var r: Dictionary = CKTerritory.call_sister_garrison(SITE)
	if bool(r.get("ok", false)):
		return "call should reject without threat"
	if str(CKEconomyState.month_echo_snapshot().get("sister", "")) != "":
		return "echo leaked on reject"
	# no sister stockade spare
	_setup()
	_own_stockade(SITE, 1)
	CKTerritory.start_threat(SITE)
	prev = CKTerritory.sister_relief_preview(SITE)
	if bool(prev.get("ok", false)):
		return "preview should need sister"
	r = CKTerritory.call_sister_garrison(SITE)
	if bool(r.get("ok", false)):
		return "call should reject without sister"
	print("api sister preview rejects ok")
	return ""


func _api_call_echo() -> String:
	_setup()
	_own_stockade(SISTER, 3)
	_own_stockade(SITE, 1)
	CKTerritory.start_threat(SITE)
	var prev: Dictionary = CKTerritory.sister_relief_preview(SITE)
	if not bool(prev.get("ok", false)):
		return "preview want ok: %s" % str(prev)
	if str(prev.get("from_id", "")) != SISTER:
		return "preview from want sister"
	var r: Dictionary = CKTerritory.call_sister_garrison(SITE)
	if not bool(r.get("ok", false)):
		return "call fail: %s" % str(r)
	if int(CKTerritory.state(SITE).garrison) != 2:
		return "target garrison want 2"
	if int(CKTerritory.state(SISTER).garrison) != 2:
		return "sister garrison want 2"
	var echo := str(CKEconomyState.month_echo_snapshot().get("sister", ""))
	if echo == "":
		return "month_echo.sister missing"
	var lines := CKEconomyState.month_echo_lines()
	var found := false
	for row in lines:
		if str(row.get("kind", "")) == "sister":
			found = true
			break
	if not found:
		return "month_echo_lines missing sister"
	print("api sister call echo ok text=%s" % echo)
	return ""


func _ui_echo() -> String:
	_setup()
	_own_stockade(SISTER, 3)
	_own_stockade(SITE, 1, 5)
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
	var btn := panel.find_child("SiegeSisterCall", true, false) as Button
	if btn == null or btn.disabled:
		atlas.queue_free()
		return "SiegeSisterCall missing/disabled"
	btn.pressed.emit()
	for _k in 10:
		await get_tree().process_frame
	if int(CKTerritory.state(SITE).garrison) != 2:
		atlas.queue_free()
		return "UI target garrison not +1"
	if str(CKEconomyState.month_echo_snapshot().get("sister", "")) == "":
		atlas.queue_free()
		return "UI missing month_echo.sister"
	# panel may still be live; EchoLine_sister attached in-place
	panel = atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null:
		atlas.queue_free()
		return "SiegeAlertModal gone after sister"
	var el := panel.find_child("EchoLine_sister", true, false) as Label
	if el == null:
		atlas.queue_free()
		return "EchoLine_sister missing"
	print("ui sister echo ok text=%s" % el.text)
	atlas.queue_free()
	await get_tree().process_frame
	return ""
