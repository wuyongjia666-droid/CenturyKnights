extends Node
## Territory fat: evacuate_preview → reject → evacuate_cache → month_echo.convoy
## → SiegeAlertModal EchoLine_convoy E2E. Not a thin CTA knife.

const ATLAS_SCN := preload("res://scenes/hub/atlas_view.tscn")
const SITE := "t_ash_cinderpit"
const DEST := "t_ash_millrun"
const MARKER := "TERRITORY SIEGE CONVOY ECHO PASS"

func _ready() -> void:
	var err := await _run()
	if err != "":
		print("FAIL territory siege convoy echo: ", err)
		get_tree().quit(1)
	else:
		print(MARKER)
		get_tree().quit(0)


func _run() -> String:
	await get_tree().process_frame
	var err := _api_rejects()
	if err != "":
		return err
	err = _api_evacuate_echo()
	if err != "":
		return err
	err = await _ui_echo()
	if err != "":
		return err
	return ""


func _setup() -> void:
	GameState.new_game("围城疏仓回读", "灰旗", GameState.crest_color)
	GameState.chapter0_flags["chapter0_done"] = true
	GameState.chapter0_flags["ch0_playing"] = false
	UnlockSchedule.install()
	World.events_enabled = false
	World.rivals_enabled = false
	for nid in World.nations.keys():
		World.rep_nation[str(nid)] = 50
	GameState.silver = 9000
	GameState.food = 40
	GameState.morale = 80
	World.travel = {}
	World.pending_event = {}
	World.encounter = {}
	World.last_siege_alert = {}
	World.last_siege_convoy = {}
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
	_own_stockade(SITE, 2, 10)
	var prev: Dictionary = CKTerritory.evacuate_preview(SITE)
	if bool(prev.get("ok", false)):
		return "preview should need threat"
	var r: Dictionary = CKTerritory.evacuate_cache(SITE)
	if bool(r.get("ok", false)):
		return "evacuate should reject without threat"
	if str(CKEconomyState.month_echo_snapshot().get("convoy", "")) != "":
		return "echo leaked on reject"
	_setup()
	_own_stockade(SITE, 2, 0)
	CKTerritory.start_threat(SITE)
	prev = CKTerritory.evacuate_preview(SITE)
	if bool(prev.get("ok", false)):
		return "preview should need cache"
	r = CKTerritory.evacuate_cache(SITE)
	if bool(r.get("ok", false)):
		return "evacuate should reject empty cache"
	print("api convoy preview rejects ok")
	return ""


func _api_evacuate_echo() -> String:
	_setup()
	_own_stockade(DEST, 1, 0)
	_own_stockade(SITE, 2, 12)
	CKTerritory.start_threat(SITE)
	var prev: Dictionary = CKTerritory.evacuate_preview(SITE)
	if not bool(prev.get("ok", false)):
		return "preview want ok: %s" % str(prev)
	if str(prev.get("via", "")) != "stockade":
		return "preview via want stockade"
	if str(prev.get("dest_id", "")) != DEST:
		return "preview dest want sister"
	World.last_siege_convoy = {}
	var r: Dictionary = CKTerritory.evacuate_cache(SITE)
	if not bool(r.get("ok", false)):
		return "evacuate fail: %s" % str(r)
	if CKTerritory.cache_food(SITE) != 0:
		return "source not emptied"
	if CKTerritory.cache_food(DEST) != int(r.get("delivered", -1)):
		return "dest cache mismatch"
	var echo := str(CKEconomyState.month_echo_snapshot().get("convoy", ""))
	if echo == "":
		return "month_echo.convoy missing"
	var found := false
	for row in CKEconomyState.month_echo_lines():
		if str(row.get("kind", "")) == "convoy":
			found = true
			break
	if not found:
		return "month_echo_lines missing convoy"
	print("api convoy echo ok text=%s" % echo)
	return ""


func _ui_echo() -> String:
	_setup()
	_own_stockade(DEST, 1, 0)
	_own_stockade(SITE, 2, 14)
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
	var btn := panel.find_child("SiegeEvacuate", true, false) as Button
	if btn == null or btn.disabled:
		atlas.queue_free()
		return "SiegeEvacuate missing/disabled"
	btn.pressed.emit()
	for _k in 10:
		await get_tree().process_frame
	if CKTerritory.cache_food(SITE) != 0:
		atlas.queue_free()
		return "UI source not emptied"
	if str(CKEconomyState.month_echo_snapshot().get("convoy", "")) == "":
		atlas.queue_free()
		return "UI missing month_echo.convoy"
	panel = atlas.find_child("SiegeAlertModal", true, false) as Control
	if panel == null:
		atlas.queue_free()
		return "SiegeAlertModal gone after evacuate"
	var el := panel.find_child("EchoLine_convoy", true, false) as Label
	if el == null:
		atlas.queue_free()
		return "EchoLine_convoy missing"
	print("ui convoy echo ok text=%s" % el.text)
	atlas.queue_free()
	await get_tree().process_frame
	return ""
