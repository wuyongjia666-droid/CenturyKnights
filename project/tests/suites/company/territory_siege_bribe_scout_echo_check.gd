extends Node
## Territory fat: bribe_threat / scout_threat → month_echo → SiegeAlertModal EchoLine_* E2E.
## Not a thin CTA knife.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const MARKER := "TERRITORY SIEGE BRIBE SCOUT ECHO PASS"


func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory siege bribe/scout echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_rejects()
	if err != "":
		return err
	err = _api_bribe_echo()
	if err != "":
		return err
	err = _api_scout_echo()
	if err != "":
		return err
	err = await _ui_bribe_echo()
	if err != "":
		return err
	err = await _ui_scout_echo()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("围城收买斥候回读", "灰旗", GameState.crest_color)
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


func _own(id: String, garrison: int = 2) -> void:
	_reset(id)
	var anchor := str(CKTerritory.site(id).get("anchor", ""))
	World.pos = anchor
	World.arrive(anchor)
	CKTerritory.capture(id, "chain")
	var st := CKTerritory.state(id)
	st.garrison = garrison
	st.stockade = true
	st.cache_food = 4
	st.threat = {}
	CKTerritory._put(id, st)


func _api_rejects() -> String:
	_setup()
	_own(SITE)
	var r: Dictionary = CKTerritory.bribe_threat(SITE)
	if bool(r.get("ok", false)):
		return "bribe should reject without threat"
	if str(CKEconomyState.month_echo_snapshot().get("bribe", "")) != "":
		return "bribe echo leaked on reject"
	r = CKTerritory.scout_threat(SITE)
	if bool(r.get("ok", false)):
		return "scout should reject without threat"
	if str(CKEconomyState.month_echo_snapshot().get("scout", "")) != "":
		return "scout echo leaked on reject"
	_setup()
	_own(SITE)
	CKTerritory.start_threat(SITE)
	GameState.silver = 0
	r = CKTerritory.bribe_threat(SITE)
	if bool(r.get("ok", false)):
		return "bribe should reject short silver"
	if str(CKEconomyState.month_echo_snapshot().get("bribe", "")) != "":
		return "bribe echo leaked on short silver"
	r = CKTerritory.scout_threat(SITE)
	if bool(r.get("ok", false)):
		return "scout should reject short silver"
	if str(CKEconomyState.month_echo_snapshot().get("scout", "")) != "":
		return "scout echo leaked on short silver"
	print("api bribe/scout rejects ok")
	return ""


func _api_bribe_echo() -> String:
	_setup()
	_own(SITE)
	CKTerritory.start_threat(SITE)
	var cost := CKTerritory.bribe_cost(SITE)
	GameState.silver = cost + 40
	var r: Dictionary = CKTerritory.bribe_threat(SITE)
	if not bool(r.get("ok", false)):
		return "bribe fail: %s" % str(r)
	if not bool(CKTerritory.state(SITE).threat.get("bribed", false)):
		return "threat not bribed"
	if int(CKTerritory.state(SITE).threat.get("months", 1)) != 0:
		return "bribe months want 0"
	var echo := str(CKEconomyState.month_echo_snapshot().get("bribe", ""))
	if echo == "":
		return "month_echo.bribe missing"
	var found := false
	for row in CKEconomyState.month_echo_lines():
		if str(row.get("kind", "")) == "bribe":
			found = true
			break
	if not found:
		return "month_echo_lines missing bribe"
	# once-per-threat: second call rejects, echo stays
	var silver_after := GameState.silver
	r = CKTerritory.bribe_threat(SITE)
	if bool(r.get("ok", false)):
		return "second bribe should reject"
	if GameState.silver != silver_after:
		return "second bribe spent silver"
	if str(CKEconomyState.month_echo_snapshot().get("bribe", "")) != echo:
		return "bribe echo mutated on reject"
	print("api bribe echo ok text=%s" % echo)
	return ""


func _api_scout_echo() -> String:
	_setup()
	_own(SITE)
	CKTerritory.start_threat(SITE)
	var cost := CKTerritory.scout_cost(SITE)
	GameState.silver = cost + 40
	var r: Dictionary = CKTerritory.scout_threat(SITE)
	if not bool(r.get("ok", false)):
		return "scout fail: %s" % str(r)
	if not bool(CKTerritory.state(SITE).threat.get("scouted", false)):
		return "threat not scouted"
	var echo := str(CKEconomyState.month_echo_snapshot().get("scout", ""))
	if echo == "":
		return "month_echo.scout missing"
	var found := false
	for row in CKEconomyState.month_echo_lines():
		if str(row.get("kind", "")) == "scout":
			found = true
			break
	if not found:
		return "month_echo_lines missing scout"
	var silver_after := GameState.silver
	r = CKTerritory.scout_threat(SITE)
	if not bool(r.get("ok", false)):
		return "re-scout should ok with cached intel"
	if GameState.silver != silver_after:
		return "re-scout charged silver"
	if str(CKEconomyState.month_echo_snapshot().get("scout", "")) != echo:
		return "scout echo mutated on re-scout"
	print("api scout echo ok text=%s" % echo)
	return ""


func _ui_bribe_echo() -> String:
	_setup()
	_own(SITE)
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
		return "SiegeAlertModal missing (bribe)"
	var btn := panel.find_child("SiegeBribe", true, false) as Button
	if btn == null or btn.disabled:
		atlas.queue_free()
		return "SiegeBribe missing/disabled"
	btn.pressed.emit()
	for _k in 10:
		await get_tree().process_frame
	if not bool(CKTerritory.state(SITE).threat.get("bribed", false)):
		atlas.queue_free()
		return "UI threat not bribed"
	if str(CKEconomyState.month_echo_snapshot().get("bribe", "")) == "":
		atlas.queue_free()
		return "UI missing month_echo.bribe"
	panel = atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null:
		atlas.queue_free()
		return "SiegeAlertModal gone after bribe"
	var el := panel.find_child("EchoLine_bribe", true, false) as Label
	if el == null:
		atlas.queue_free()
		return "EchoLine_bribe missing"
	print("ui bribe echo ok text=%s" % el.text)
	atlas.queue_free()
	await get_tree().process_frame
	return ""


func _ui_scout_echo() -> String:
	_setup()
	_own(SITE)
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
		return "SiegeAlertModal missing (scout)"
	var btn := panel.find_child("SiegeScout", true, false) as Button
	if btn == null or btn.disabled:
		atlas.queue_free()
		return "SiegeScout missing/disabled"
	btn.pressed.emit()
	for _k in 10:
		await get_tree().process_frame
	if not bool(CKTerritory.state(SITE).threat.get("scouted", false)):
		atlas.queue_free()
		return "UI threat not scouted"
	if str(CKEconomyState.month_echo_snapshot().get("scout", "")) == "":
		atlas.queue_free()
		return "UI missing month_echo.scout"
	panel = atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null:
		atlas.queue_free()
		return "SiegeAlertModal gone after scout"
	var el := panel.find_child("EchoLine_scout", true, false) as Label
	if el == null:
		atlas.queue_free()
		return "EchoLine_scout missing"
	print("ui scout echo ok text=%s" % el.text)
	atlas.queue_free()
	await get_tree().process_frame
	return ""
